import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/text_field_bloc.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/testing_mode.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/alarm_manager.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/incoming_queue.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// [MethodChannelInterface] is a manager used to talk to native code via a flutter MethodChannel
///
/// This class is a singleton
class MethodChannelInterface {
  factory MethodChannelInterface() {
    return _interface;
  }

  static final MethodChannelInterface _interface = MethodChannelInterface._internal();

  MethodChannelInterface._internal();

  /// [platform] is the actual channel which can be used to talk to native code
  late MethodChannel platform;

  /// [headless] identifies if this MethodChannelInterface is used when the app is fully closed, in hich case some actions cannot be done
  bool headless = false;

  /// Initialize all of the platform channels
  ///
  /// @param [customChannel] an optional custom platform channel to use by the methodchannelinterface
  void init({MethodChannel? customChannel}) {
    // If a [customChannel] is set, then we should use that
    if (customChannel != null) {
      headless = true;
      platform = customChannel;
      // Otherwise, we set the [platform] as the default
    } else {
      platform = MethodChannel('com.bluebubbles.messaging');
    }

    // We set the handler for all of the method calls from the platform to be the [callHandler]
    platform.setMethodCallHandler(_callHandler);
    // If we are running in the background, inform Java that the method channel
    // has been initialized and it can start sending messages
    platform.invokeMethod<void>('MessagingBackground#initialized');
  }

  /// Helper method to invoke a method in the native code
  ///
  /// @param [method] is the tag to be recognized in native code
  /// @param [arguments] is an optional parameter which can be used to send other data along with the method call
  Future invokeMethod(String method, [dynamic arguments]) async {
    return platform.invokeMethod(method, arguments);
  }

  /// The handler used to handle all methods sent from native code to the dart vm
  ///
  /// @param [call] is the actual [MethodCall] sent from native code. It has data such as the method name and the arguments.
  Future<dynamic> _callHandler(MethodCall call) async {
    // call.method is the name of the call from native code
    switch (call.method) {
      case "new-server":
        if (!SettingsManager().settings.finishedSetup.value) return new Future.value("");

        // The arguments for a new server are formatted with the new server address inside square brackets
        // As such: [https://alksdjfoaehg.ngrok.io]
        String address = call.arguments.toString();

        // We remove the brackets from the formatting
        address = getServerAddress(address: address.substring(1, address.length - 1))!;

        // And then tell the socket to set the new server address
        await SocketManager().newServer(address);

        return new Future.value("");
      case "new-message":
        Logger.instance.log("Received new message from FCM");
        // Retreive the data for this message as a json
        Map<String, dynamic>? data = jsonDecode(call.arguments);

        // Add it to the queue with the data as the item
        IncomingQueue().add(new QueueItem(event: IncomingQueue.HANDLE_MESSAGE_EVENT, item: {"data": data}));

        return new Future.value("");
      case "updated-message":
        // Retreive the data for this message as a json
        Map<String, dynamic>? data = jsonDecode(call.arguments);

        // Add it to the queue with the data as the item
        IncomingQueue().add(new QueueItem(event: IncomingQueue.HANDLE_UPDATE_MESSAGE, item: {"data": data}));

        return new Future.value("");
      case "ChatOpen":
        debugPrint("Opening Chat with GUID: ${call.arguments}");
        openChat(call.arguments);

        return new Future.value("");
      case "socket-error-open":
        Get.toNamed("/settings/server-management-panel");
        return new Future.value("");
      case "reply":
        if (call.arguments["chat"] == "google-play-test-chat") {
          TestingModeController controller = Get.find<TestingModeController>();
          controller.mostRecentReply.value = call.arguments["text"];
          // If `reply` is called when the app is in a background isolate, then we need to close it once we are done
          closeThread();

          return new Future.value("");
        }
        // Find the chat to reply to
        Chat? chat = await Chat.findOne({"guid": call.arguments["chat"]});

        // If no chat is found, then we can't do anything
        if (chat == null) {
          // If `reply` is called when the app is in a background isolate, then we need to close it once we are done
          closeThread();

          return new Future.value("");
        }

        // Send the message to that chat
        ActionHandler.sendMessage(chat, call.arguments["text"]);

        return new Future.value("");
      case "markAsRead":
        // Find the chat to mark as read
        Chat? chat = await Chat.findOne({"guid": call.arguments["chat"]});

        // If no chat is found, then we can't do anything
        if (chat == null) {
          // If `markAsRead` is called when the app is in a background isolate, then we need to close it once we are done
          closeThread();

          return new Future.value("");
        }

        // Remove the notificaiton from that chat
        await SocketManager().removeChatNotification(chat);

        if (SettingsManager().settings.privateMarkChatAsRead.value) {
          SocketManager().sendMessage("mark-chat-read", {"chatGuid": chat.guid}, (data) {});
        }

        // In case this method is called when the app is in a background isolate
        closeThread();

        return new Future.value("");
      case "shareAttachments":
        if (!SettingsManager().settings.finishedSetup.value) return Future.value("");
        List<File> attachments = <File>[];

        // Get the path to where the temp files are stored
        String sharedFilesPath = SettingsManager().sharedFilesPath;

        debugPrint("shareAttachments " + sharedFilesPath);

        // Loop through all of the attachments sent by native code
        call.arguments["attachments"].forEach((element) {
          // Get the file in that directory
          File file = File(element);

          // Add each file to the attachment list
          attachments.add(file);
        });

        // Get the handle if it is a direct shortcut
        String? guid = call.arguments["id"];

        // If it is a direct shortcut, try and find the chat and navigate to it
        if (guid != null) {
          List<Chat?> chats = ChatBloc().chats.where((element) => element.guid == guid).toList();

          // If we did find a chat matching the criteria
          if (chats.length != 0) {
            // Get the most recent of our results
            chats.sort(Chat.sort);
            Chat chat = chats.first!;

            // Open the chat
            openChat(chat.guid!, existingAttachments: attachments);

            // Nothing else to do
            return new Future.value("");
          }
        }

        // Go to the new chat creator with all of these attachments to select a chat in case it wasn't a direct share
        Get.offUntil(
              ThemeSwitcher.buildPageRoute(
                builder: (context) => ConversationView(
                  existingAttachments: attachments,
                  isCreator: true,
                  // onTapGoToChat: true,
                ),
              ),
              (route) => route.isFirst,
            );
        return new Future.value("");

      case "shareText":
        if (!SettingsManager().settings.finishedSetup.value) return Future.value("");
        // Get the text that was shared to the app
        String? text = call.arguments["text"];

        // Get the handle if it is a direct shortcut
        String? guid = call.arguments["id"];

        // If it is a direct shortcut, try and find the chat and navigate to it
        if (guid != null) {
          List<Chat?> chats = ChatBloc().chats.where((element) => element.guid == guid).toList();

          // If we did find a chat matching the criteria
          if (chats.length != 0) {
            // Get the most recent of our results
            chats.sort(Chat.sort);
            Chat chat = chats.first!;

            // Open the chat
            openChat(chat.guid!, existingText: text);

            // Nothing else to do
            return new Future.value("");
          }
        }
        // Navigate to the new chat creator with the specified text
        Get.offUntil(
              ThemeSwitcher.buildPageRoute(
                builder: (context) => ConversationView(
                  existingText: text,
                  isCreator: true,
                ),
              ),
              (route) => route.isFirst,
            );

        return new Future.value("");
      case "alarm-wake":
        AlarmManager().onReceiveAlarm(call.arguments["id"]);
        return new Future.value("");
      default:
        return new Future.value("");
    }
  }

  /// [closeThread] closes the background isolate when the app is fully closed
  void closeThread() {
    // Only do this if we are indeed running in the background
    if (headless) {
      debugPrint("(CloseThread) -> Closing the background isolate...");

      // Tells the native code to close the isolate
      invokeMethod("close-background-isolate");
    }
  }

  Future<void> openChat(String id, {List<File> existingAttachments = const [], String? existingText}) async {
    if (id == "-1") {
      Get.until((route) => route.isFirst);
      return;
    }
    if (CurrentChat.activeChat?.chat.guid == id) {
      NotificationManager().switchChat(CurrentChat.activeChat!.chat);
      TextFieldData? data = TextFieldBloc().getTextField(id);
      if (existingAttachments.isNotEmpty && data != null) {
        data.attachments.addAll(existingAttachments);
        final ids = data.attachments.map((e) => e.path).toSet();
        data.attachments.retainWhere((element) => ids.remove(element.path));
        EventDispatcher.instance.emit("text-field-update-attachments", null);
      }
      if (existingText != null) {
        data?.controller.text = existingText;
        EventDispatcher.instance.emit("text-field-update-text", null);
      }
      return;
    }
    // Try to find the specified chat to open
    Chat? openedChat = await Chat.findOne({"GUID": id});

    // If we did find one, then we can move on
    if (openedChat != null) {
      // Get all of the participants of the chat so that it looks right when it is opened
      await openedChat.getParticipants();

      // Make sure that the title is set
      await openedChat.getTitle();

      // Clear all notifications for this chat
      NotificationManager().switchChat(openedChat);

      // if (!CurrentChat.isActive(openedChat.guid))
      // Actually navigate to the chat page
      Get.offUntil(
          ThemeSwitcher.buildPageRoute(
            builder: (context) => ConversationView(
              chat: openedChat,
              existingAttachments: existingAttachments,
              existingText: existingText,
            ),
          ),
          (route) => route.isFirst,
        );

      // We have a delay, because the first [switchChat] does not work.
      // Because we are pushing AND removing until it is the first route,
      // the [dispose] methods of the previous conversation views will be called and thus will override the switch chat we just called
      // Thus we need to add a delay here to wait for the animation to finish
      await Future.delayed(Duration(milliseconds: 500));
      NotificationManager().switchChat(openedChat);
    } else {
      debugPrint("(OpenChat) -> Failed to find chat");
    }
  }
}

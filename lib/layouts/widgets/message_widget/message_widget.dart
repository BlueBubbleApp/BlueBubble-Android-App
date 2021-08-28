import 'dart:async';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/group_event.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/url_preview_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_time_stamp_separator.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reactions_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/received_message.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/sent_message.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/stickers_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MessageWidgetController extends GetxController {
  Completer<void>? associatedMessageRequest;
  Completer<void>? attachmentsRequest;
  int lastRequestCount = -1;
  int attachmentCount = 0;
  int associatedCount = 0;
  late final CurrentChat? currentChat;
  late final StreamSubscription<NewMessageEvent> subscription;
  Message message;
  Message? newerMessage;
  Message? olderMessage;

  final BuildContext context;
  final Function? onUpdate;
  MessageWidgetController({
    required this.context,
    this.onUpdate,
    required this.message,
    this.newerMessage,
    this.olderMessage,
  });

  @override
  void onInit() {
    currentChat = CurrentChat.of(context);

    checkHandle();
    fetchAssociatedMessages();
    fetchAttachments();

    // Listen for new messages
    subscription = NewMessageManager().stream.listen((data) {
      // If the message doesn't apply to this chat, ignore it
      if (data.chatGuid != currentChat?.chat.guid) return;

      if (data.type == NewMessageType.ADD) {
        // Check if the new message has an associated GUID that matches this message
        bool fetchAssoc = false;
        bool fetchAttach = false;
        Message? message = data.event["message"];
        if (message == null) return;
        if (message.associatedMessageGuid == message.guid) fetchAssoc = true;
        if (message.hasAttachments) fetchAttach = true;

        // If the associated message GUID matches this one, fetch associated messages
        if (fetchAssoc) fetchAssociatedMessages();
        if (fetchAttach) fetchAttachments();
      } else if (data.type == NewMessageType.UPDATE) {
        String? oldGuid = data.event["oldGuid"];
        // If the guid does not match our current guid, then it's not meant for us
        if (oldGuid != message.guid && oldGuid != newerMessage?.guid) return;

        onUpdate?.call(data);

        if (message.guid == oldGuid) {
          message = data.event["message"];
        } else if (newerMessage!.guid == oldGuid) {
          newerMessage = data.event["message"];
        }
      }
      update();
    });

    ContactManager().colorStream.listen((event) {
      if (!event.containsKey(message.handle?.address)) return;

      Color? color = event[message.handle?.address];
      if (color == null) {
        message.handle!.color = null;
      } else {
        message.handle!.color = color.value.toRadixString(16);
      }

      update();
    });

    super.onInit();
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  Future<void> checkHandle() async {
    if (message.isFromMe! || message.handle != null) return;

    await message.getHandle();
  }

  Future<void> fetchAssociatedMessages() async {
    // If there is already a request being made, return that request
    if (associatedMessageRequest != null) return associatedMessageRequest!.future;

    // Create a new request and get the messages
    associatedMessageRequest = new Completer();

    try {
      await message.fetchAssociatedMessages();
    } catch (ex) {
      return associatedMessageRequest!.completeError(ex);
    }

    // If we don't think there are reactions, and we found reactions,
    // Update the DB so it saves that we have reactions
    if (!message.hasReactions && message.getReactions().length > 0) {
      message.hasReactions = true;
      message.update();
    }

    if (message.associatedMessages.length != associatedCount) {
      associatedCount = message.associatedMessages.length;
    }

    associatedMessageRequest!.complete();
  }

  Future<void> fetchAttachments() async {
    // If there is already a request being made, return that request
    if (attachmentsRequest != null) return attachmentsRequest!.future;

    // Create a new request and get the attachments
    attachmentsRequest = new Completer();

    try {
      await message.fetchAttachments(currentChat: currentChat);
    } catch (ex) {
      return attachmentsRequest!.completeError(ex);
    }

    // If this is a URL preview and we don't have attachments, we need to get them
    List<Attachment?> nullAttachments = message.getPreviewAttachments();
    if (message.hasUrl() && nullAttachments.isEmpty && lastRequestCount != nullAttachments.length) {
      lastRequestCount = nullAttachments.length;

      List<dynamic> msgs = (await SocketManager().getAttachments(currentChat!.chat.guid!, message.guid!)) ?? [];
      for (var msg in msgs) await ActionHandler.handleMessage(msg, forceProcess: true);
    }

    if (message.attachments!.length != this.attachmentCount) {
      this.attachmentCount = message.attachments!.length;
    }

    if (!attachmentsRequest!.isCompleted) attachmentsRequest!.complete();
  }
}

class MessageWidget extends StatelessWidget {
  MessageWidget({
    Key? key,
    required this.message,
    required this.olderMessage,
    required this.newerMessage,
    required this.showHandle,
    required this.isFirstSentMessage,
    required this.showHero,
    this.onUpdate,
  }) : super(key: key);

  final Message message;
  final Message? newerMessage;
  final Message? olderMessage;
  final bool showHandle;
  final bool isFirstSentMessage;
  final bool showHero;
  final Message? Function(NewMessageEvent event)? onUpdate;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MessageWidgetController>(
      init: MessageWidgetController(
        context: context,
        message: message,
        olderMessage: olderMessage,
        newerMessage: newerMessage,
        onUpdate: onUpdate,
      ),
      global: false,
      tag: message.guid!,
      builder: (controller) {
        bool showTail = true;
        if (controller.newerMessage != null) {
          if (controller.newerMessage!.isGroupEvent()) {
            showTail = true;
          } else if (SettingsManager().settings.skin.value == Skins.Samsung) {
            showTail = MessageHelper.getShowTailReversed(context, controller.message, controller.olderMessage);
          } else {
            showTail = MessageHelper.getShowTail(context, controller.message, controller.newerMessage);
          }
        }

        if (controller.message.isGroupEvent()) {
          return GroupEvent(key: Key("group-event-${controller.message.guid}"), message: controller.message);
        }

        ////////// READ //////////
        /// This widget and code below will handle building out the following:
        /// -> Attachments
        /// -> Reactions
        /// -> Stickers
        /// -> URL Previews
        /// -> Big Emojis??
        ////////// READ //////////

        // Build the attachments widget
        final widgetAttachments = MessageAttachments(
          message: controller.message,
          showTail: showTail,
          showHandle: showHandle,
        );

        final urlPreviewWidget = UrlPreviewWidget(
            key: new Key("preview-${controller.message.guid}"), linkPreviews: controller.message.getPreviewAttachments(), message: controller.message);
        final stickersWidget =
          StickersWidget(key: new Key("stickers-${controller.associatedCount.toString()}"), messages: controller.message.associatedMessages);
        final reactionsWidget = ReactionsWidget(
            key: new Key("reactions-${controller.associatedCount.toString()}"), associatedMessages: controller.message.associatedMessages);

        // Add the correct type of message to the message stack
        Widget message;
        if (controller.message.isFromMe!) {
          message = SentMessage(
            showTail: showTail,
            olderMessage: controller.olderMessage,
            newerMessage: controller.newerMessage,
            message: controller.message,
            urlPreviewWidget: urlPreviewWidget,
            stickersWidget: stickersWidget,
            attachmentsWidget: widgetAttachments,
            reactionsWidget: reactionsWidget,
            shouldFadeIn: (controller.message.dateCreated?.difference(DateTime.now()).inSeconds ?? 0) <= 1,
            showHero: showHero,
            showDeliveredReceipt: isFirstSentMessage,
          );
        } else {
          message = ReceivedMessage(
            showTail: showTail,
            olderMessage: controller.olderMessage,
            newerMessage: controller.newerMessage,
            message: controller.message,
            showHandle: showHandle,
            urlPreviewWidget: urlPreviewWidget,
            stickersWidget: stickersWidget,
            attachmentsWidget: widgetAttachments,
            reactionsWidget: reactionsWidget,
          );
        }

        return Column(
          children: [
            message,
            if (SettingsManager().settings.skin.value != Skins.Samsung)
              MessageTimeStampSeparator(
                newerMessage: controller.newerMessage,
                message: controller.message,
              )
          ],
        );
      }
    );
  }
}

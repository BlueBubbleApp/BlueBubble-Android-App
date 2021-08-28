import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/new_message_loader.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/typing_indicator.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class MessagesViewController extends GetxController with SingleGetTickerProviderMixin {
  Completer<LoadMessageResult>? loader;
  bool noMoreMessages = false;
  bool noMoreLocalMessages = false;
  GlobalKey<SliverAnimatedListState> listKey = GlobalKey<SliverAnimatedListState>();
  final Duration animationDuration = Duration(milliseconds: 400);
  final smartReply = GoogleMlKit.nlp.smartReply();
  List<int> loadedPages = [];
  RxList<String> smartReplies = <String>[].obs;
  List<Message> messages = [];

  final CurrentChat currentChat;
  final MessageBloc messageBloc;
  final bool showHandle;
  final Chat chat;
  final Function? initComplete;
  MessagesViewController({
    required this.messageBloc,
    required this.showHandle,
    required this.chat,
    this.initComplete,
    required this.currentChat,
  });

  bool get showSmartReplies =>
      SettingsManager().settings.smartReply.value &&
          (!SettingsManager().settings.redactedMode.value || !SettingsManager().settings.hideMessageContent.value);

  @override
  void onInit() {
    ever<MessageBlocEvent?>(messageBloc.event, (e) => handleNewMessage(e));

    // See if we need to load anything from the message bloc
    if (messages.isEmpty && messageBloc.messages.isEmpty) {
      messageBloc.getMessages();
    } else if (messages.isEmpty && messageBloc.messages.isNotEmpty) {
      messageBloc.emitLoaded();
    }

    EventDispatcher.instance.stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == "refresh-messagebloc" && event["data"].containsKey("chatGuid")) {
        // Handle event's that require a matching guid
        String? chatGuid = event["data"]["chatGuid"];
        if (chat.guid == chatGuid) {
          if (event["type"] == "refresh-messagebloc") {
            // Clear state items
            noMoreLocalMessages = false;
            noMoreMessages = false;
            messages = [];
            loadedPages = [];

            // Reload the state after refreshing
            messageBloc.refresh().then((_) {
              update();
            });
          }
        }
      }
    });
    if (initComplete != null) initComplete!();
    super.onInit();
  }

  @override
  void dispose() {
    smartReply.close();
    super.dispose();
  }

  void handleNewMessage(MessageBlocEvent? event) async {
    if (event == null) return;

    // Skip deleted messages
    if (event.message != null && event.message!.dateDeleted != null) return;
    event.messages.retainWhere((element) => element.dateDeleted == null);

    if (event.type == MessageBlocEventType.insert) {
      if (LifeCycleManager.instance.isAlive && !event.outGoing) {
        NotificationManager().switchChat(chat);
      }

      bool isNewMessage = messages.firstWhereOrNull((e) => e.guid == event.message?.guid) == null;

      messages = event.messages;
      if (listKey.currentState != null) {
        listKey.currentState!.insertItem(
          event.index != null ? event.index! : 0,
          duration: isNewMessage
              ? event.outGoing
              ? Duration(milliseconds: 300)
              : animationDuration
              : Duration(milliseconds: 0),
        );
      }

      if (event.outGoing) await Future.delayed(Duration(milliseconds: 300));

      //todo
      /*currentChat.getAttachmentsForMessage(event.message);

      if (event.message!.hasAttachments) {
        await currentChat.updateChatAttachments();
      }*/

      if (isNewMessage && this.showSmartReplies) {
        updateReplies();
      }
    } else if (event.type == MessageBlocEventType.remove) {
      messages.removeWhere((element) => element.guid == event.remove);
      // we do this to force the listview to update once
      listKey = GlobalKey<SliverAnimatedListState>();
    } else {
      int originalMessageLength = messages.length;
      messages = event.messages;

      //todo
      /*messages.forEach((message) {
        currentChat.getAttachmentsForMessage(message);
        currentChat.messageMarkers.updateMessageMarkers(message);
      });*/

      // This needs to be in reverse so that the oldest message gets added first
      // We also only want to grab the last 5, so long as there are at least 5 results
      List<Message> reversed = messages.reversed.toList();
      int sampleSize = min(5, messages.length);
      reversed.sublist(reversed.length - sampleSize).forEach((message) {
        if (!isEmptyString(message.fullText, stripWhitespace: true)) {
          if (message.isFromMe ?? false) {
            smartReply.addConversationForLocalUser(message.fullText!);
          } else {
            smartReply.addConversationForRemoteUser(message.fullText!, message.handle?.address ?? "participant");
          }
        }
      });

      // We only want to update smart replies on the intial message fetch
      if (originalMessageLength == 0 && showSmartReplies && messages.length > 0) {
        updateReplies();
      }

      // we do this to force the listview to update once
      listKey = GlobalKey<SliverAnimatedListState>();
    }

    update();
  }

  void updateReplies() async {
    // If there are no messages, reset the replies
    if (isNullOrEmpty(messages)!) {
      smartReplies.clear();
      return;
    }

    debugPrint("Getting smart replies...");
    Map<String, dynamic> results = await smartReply.suggestReplies();

    if (results.containsKey('suggestions')) {
      List<SmartReplySuggestion> suggestions = results['suggestions'];
      debugPrint("Smart Replies found: ${suggestions.length}");
      smartReplies.value = suggestions.map((e) => e.getText()).toList().toSet().toList();
    }
  }
}

class MessagesView extends StatelessWidget {
  final MessageBloc messageBloc;
  final bool showHandle;
  final Chat chat;
  final Function? initComplete;
  final CurrentChat currentChat;

  MessagesView({
    Key? key,
    required this.messageBloc,
    required this.showHandle,
    required this.chat,
    this.initComplete,
    required this.currentChat,
  }) : super(key: key);

  Future<void>? loadNextChunk(MessagesViewController controller, ) {
    if (controller.noMoreMessages || controller.loadedPages.contains(controller.messages.length)) return null;
    int messageCount = controller.messages.length;

    // If we already are loading a chunk, don't load again
    if (controller.loader != null && !controller.loader!.isCompleted) {
      return controller.loader!.future;
    }

    // Create a new completer
    controller.loader = new Completer();
    controller.loadedPages.add(messageCount);

    // Start loading the next chunk of messages
    messageBloc
        .loadMessageChunk(controller.messages.length, checkLocal: !controller.noMoreLocalMessages)
        .then((LoadMessageResult val) {
      if (val != LoadMessageResult.FAILED_TO_RETREIVE) {
        if (val == LoadMessageResult.RETREIVED_NO_MESSAGES) {
          controller.noMoreMessages = true;
          debugPrint("(CHUNK) No more messages to load");
        } else if (val == LoadMessageResult.RETREIVED_LAST_PAGE) {
          // Mark this chat saying we have no more messages to load
          controller.noMoreLocalMessages = true;
        }
      }

      // Complete the future
      controller.loader!.complete(val);

      // Only update the state if there are messages that were added
      if (val != LoadMessageResult.FAILED_TO_RETREIVE) {
        controller.update();
      }
    }).catchError((ex) {
      controller.loader!.complete(LoadMessageResult.FAILED_TO_RETREIVE);
    });

    return controller.loader!.future;
  }

  /// All message update events are handled within the message widgets, to prevent top level setstates
  Message? onUpdateMessage(MessagesViewController controller, NewMessageEvent event) {
    if (event.type != NewMessageType.UPDATE) return null;
    currentChat.updateExistingAttachments(event);

    String? oldGuid = event.event["oldGuid"];
    Message? message = event.event["message"];

    for (int i = 0; i < controller.messages.length; i++) {
      if (controller.messages[i].guid == oldGuid) {
        debugPrint("(Message status) Update message: [${message!.text}] - [${message.guid}] - [$oldGuid]");
        controller.messages[i] = message;
        break;
      } else {
        debugPrint(
            "(Message status) Message not updated (not found): [${message!.text}] - [${message.guid}] - [$oldGuid]");
      }
    }

    return message;
  }

  Widget _buildReply(BuildContext context, String text) => Container(
        margin: EdgeInsets.all(5),
        decoration: BoxDecoration(
          border: Border.all(
            width: 2,
            style: BorderStyle.solid,
            color: Theme.of(context).accentColor,
          ),
          borderRadius: BorderRadius.circular(19),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
          ),
          onTap: () {
            ActionHandler.sendMessage(currentChat.chat, text);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 13.0),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyText1,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MessagesViewController>(
      global: false,
      init: MessagesViewController(
        messageBloc: messageBloc,
        showHandle: showHandle,
        chat: chat,
        initComplete: initComplete,
        currentChat: currentChat,
      ),
      builder: (controller) {
        return GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onHorizontalDragStart: (details) {},
            onHorizontalDragUpdate: (details) {
              if (SettingsManager().settings.skin.value != Skins.Samsung)
                CurrentChat.of(context)!.timeStampOffset.value += details.delta.dx * 0.3;
            },
            onHorizontalDragEnd: (details) {
              if (SettingsManager().settings.skin.value != Skins.Samsung) CurrentChat.of(context)!.timeStampOffset.value = 0;
            },
            onHorizontalDragCancel: () {
              if (SettingsManager().settings.skin.value != Skins.Samsung) CurrentChat.of(context)!.timeStampOffset.value = 0;
            },
            child: CustomScrollView(
              controller: CurrentChat.of(context)!.scrollController,
              reverse: true,
              physics: ThemeSwitcher.getScrollPhysics(),
              slivers: <Widget>[
                if (controller.showSmartReplies)
                  Obx(() => SliverToBoxAdapter(
                    child: AnimatedSize(
                      duration: Duration(milliseconds: 250),
                      vsync: controller,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: controller.smartReplies.map((e) => _buildReply(context, e)).toList()),
                    ),
                  )),
                if (SettingsManager().settings.enablePrivateAPI.value || chat.guid == "theme-selector")
                  SliverToBoxAdapter(
                    child: Row(
                      children: <Widget>[
                        if (chat.guid == "theme-selector" ||
                            (currentChat.showTypingIndicator.value && SettingsManager().settings.alwaysShowAvatars.value))
                          Padding(
                            padding: EdgeInsets.only(left: 10.0),
                            child: ContactAvatarWidget(
                              key: Key("${chat.participants[0].address}-messages-view"),
                              handle: chat.participants[0],
                              size: 30,
                              fontSize: 14,
                              borderThickness: 0.1,
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: TypingIndicator(
                            visible: chat.guid == "theme-selector" ? true : currentChat.showTypingIndicator.value,
                          ),
                        ),
                      ],
                    ),
                  ),
                SliverAnimatedList(
                  initialItemCount: controller.messages.length + 1,
                  key: controller.listKey,
                  itemBuilder: (BuildContext context, int index, Animation<double> animation) {
                    // Load more messages if we are at the top and we aren't alrady loading
                    // and we have more messages to load
                    if (index == controller.messages.length) {
                      if (!controller.noMoreMessages &&
                          (controller.loader == null || !controller.loader!.isCompleted || !controller.loadedPages.contains(controller.messages.length))) {
                        loadNextChunk(controller);
                        return NewMessageLoader();
                      }

                      return Container();
                    } else if (index > controller.messages.length) {
                      return Container();
                    }

                    Message? olderMessage;
                    Message? newerMessage;
                    if (index + 1 < controller.messages.length) {
                      olderMessage = controller.messages[index + 1];
                    }
                    if (index - 1 >= 0) {
                      newerMessage = controller.messages[index - 1];
                    }

                    bool fullAnimation =
                        index == 0 && (!controller.messages[index].isFromMe!
                            || controller.messages[index].originalROWID == null);

                    final messageWidget = Padding(
                        padding: EdgeInsets.only(left: 5.0, right: 5.0),
                        child: MessageWidget(
                          key: Key(controller.messages[index].guid!),
                          message: controller.messages[index],
                          olderMessage: olderMessage,
                          newerMessage: newerMessage,
                          showHandle: showHandle,
                          isFirstSentMessage: messageBloc.firstSentMessage == controller.messages[index].guid,
                          showHero: fullAnimation,
                          onUpdate: (event) => onUpdateMessage(controller, event),
                        ));

                    if (fullAnimation) {
                      return SizeTransition(
                        axis: Axis.vertical,
                        sizeFactor: animation
                            .drive(Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut))),
                        child: SlideTransition(
                          position: animation.drive(
                            Tween(
                              begin: Offset(0.0, 1),
                              end: Offset(0.0, 0.0),
                            ).chain(
                              CurveTween(
                                curve: Curves.easeInOut,
                              ),
                            ),
                          ),
                          child: Opacity(
                            opacity: animation.isCompleted || !controller.messages[index].isFromMe! ? 1 : 0,
                            child: messageWidget,
                          ),
                        ),
                      );
                    }

                    return messageWidget;
                  }
                ),
                SliverPadding(
                  padding: EdgeInsets.all(70),
                ),
              ],
            )
        );
      }
    );
  }
}

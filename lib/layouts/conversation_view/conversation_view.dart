import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/attachment_sender.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/conversation_view/messages_view.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/chat_selector_text_field.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/sent_message.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/outgoing_queue.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:slugify/slugify.dart';

abstract class ChatSelectorTypes {
  static const String ALL = "ALL";
  static const String ONLY_EXISTING = "ONLY_EXISTING";
  static const String ONLY_CONTACTS = "ONLY_CONTACTS";
}

class ConversationView extends StatefulWidget {
  final List<File> existingAttachments;
  final String? existingText;
  final List<UniqueContact> selected;

  ConversationView({
    Key? key,
    this.chat,
    this.existingAttachments = const [],
    this.existingText,
    this.isCreator = false,
    this.onSelect,
    this.selectIcon,
    this.customHeading,
    this.customMessageBloc,
    this.onMessagesViewComplete,
    this.selected = const [],
    this.type = ChatSelectorTypes.ALL,
    this.showSnackbar = false,
  }) : super(key: key);

  final Chat? chat;
  final Function(List<UniqueContact> items)? onSelect;
  final Widget? selectIcon;
  final String? customHeading;
  final String type;
  final bool isCreator;
  final MessageBloc? customMessageBloc;
  final Function? onMessagesViewComplete;
  final bool showSnackbar;

  @override
  ConversationViewState createState() => ConversationViewState();
}

class ConversationViewState extends State<ConversationView> with ConversationViewMixin, WidgetsBindingObserver {
  List<File> existingAttachments = [];
  String? existingText;
  Brightness? brightness;
  Color? previousBackgroundColor;
  bool gotBrightness = false;
  Message? message;
  Tween<double> tween = Tween<double>(begin: 1, end: 0);
  double offset = 0;
  CustomAnimationControl controller = CustomAnimationControl.stop;
  bool wasCreator = false;
  GlobalKey key = GlobalKey();

  @override
  void initState() {
    super.initState();

    this.selected = widget.selected.isEmpty ? [] : widget.selected;
    this.existingAttachments = widget.existingAttachments.isEmpty ? [] : widget.existingAttachments;
    this.existingText = widget.existingText;

    // Initialize the current chat state
    if (widget.chat != null) {
      initCurrentChat(widget.chat!);
    }

    isCreator = widget.isCreator;
    chat = widget.chat;

    if (widget.selected.isEmpty) {
      initChatSelector();
    }
    initConversationViewState();

    LifeCycleManager.instance.stream.listen((event) {
      if (!this.mounted) return;
      currentChat?.isAlive = true;
    });

    ever(ChatBloc().chats, (List<Chat> chats) async {
      if (currentChat == null) {
        currentChat = CurrentChat.getCurrentChat(widget.chat);
      }

      if (currentChat != null) {
        Chat? _chat = chats.firstWhereOrNull((e) => e.guid == widget.chat?.guid);
        if (_chat != null) {
          await _chat.getParticipants();
          currentChat!.chat = _chat;
          if (this.mounted) setState(() {});
        }
      }
    });

    KeyboardVisibilityController().onChange.listen((bool visible) async {
      await Future.delayed(Duration(milliseconds: 500));
      final textFieldSize = (key.currentContext?.findRenderObject() as RenderBox?)?.size.height;
      if (mounted) {
        try {
          setState(() {
            offset = (textFieldSize ?? 0) > 300 ? 300 : 0;
          });
        } catch (_) {
          offset = (textFieldSize ?? 0) > 300 ? 300 : 0;
        }
      }
    });

    if (widget.chat != null && messageBloc == null) {
      messageBloc = MessageBloc(widget.chat);
    }
    if (messageBloc != null) {
      ever<MessageBlocEvent?>(messageBloc!.event, (event) async {
        // Get outta here if we don't have a chat "open"
        if (CurrentChat.activeChat == null) return;
        if (event == null) return;

        // Skip deleted messages
        if (event.message != null && event.message!.dateDeleted != null) return;

        if (event.type == MessageBlocEventType.insert && this.mounted && event.outGoing) {
          final constraints = BoxConstraints(
            maxWidth: context.width * MessageWidgetHelper.MAX_SIZE,
            minHeight: Theme.of(context).textTheme.bodyText2!.fontSize!,
            maxHeight: Theme.of(context).textTheme.bodyText2!.fontSize!,
          );
          final renderParagraph = RichText(
            text: TextSpan(
              text: event.message!.text,
              style: Theme.of(context).textTheme.bodyText2!.apply(color: Colors.white),
            ),
            maxLines: 1,
          ).createRenderObject(context);
          final size = renderParagraph.getDryLayout(constraints);
          if (!(message?.hasAttachments ?? false) && !(message?.text?.isEmpty ?? false))
            setState(() {
              tween = Tween<double>(begin: context.width - 30, end: min(size.width + 68, context.width * MessageWidgetHelper.MAX_SIZE + 40));
              controller = CustomAnimationControl.play;
              message = event.message;
            });
        }
      });
    }

    SchedulerBinding.instance!.addPostFrameCallback((_) {
      if (widget.showSnackbar) {
        showSnackbar('Warning',
            'Support for creating chats is currently limited on MacOS 11 (Big Sur) and up due to limitations imposed by Apple');
      }
    });

    // Bind the lifecycle events
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    didChangeDependenciesConversationView();
  }

  /// Called when the app is either closed or opened or paused
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && mounted) {
      debugPrint("Removing CurrentChat imageData");
      CurrentChat.activeChat?.imageData.clear();
    }
  }

  @override
  void dispose() {
    if (currentChat != null) {
      currentChat!.disposeControllers();
    }

    // Switching chat to null will clear the currently active chat
    NotificationManager().switchChat(null);
    super.dispose();
  }

  Future<bool> send(List<File> attachments, String text) async {
    bool isDifferentChat = currentChat == null || currentChat?.chat.guid != chat?.guid;

    if (isCreator!) {
      if (chat == null && selected.length == 1) {
        try {
          chat = await Chat.findOne({"chatIdentifier": slugify(selected[0].address!, delimiter: '')});
        } catch (ex) {}
      }

      // If the chat is null, create it
      if (chat == null) chat = await createChat();

      // If the chat is still null, return false
      if (chat == null) return false;

      // If the current chat is null, set it
      if (isDifferentChat) {
        initCurrentChat(chat!);
      }

      bool isDifferentBloc = messageBloc == null || messageBloc?.currentChat?.guid != chat!.guid;

      // Fetch messages
      if (isDifferentBloc) {
        // Init the states
        messageBloc = initMessageBloc();
        messageBloc!.getMessages();
      }
    } else {
      if (isDifferentChat) {
        initCurrentChat(chat!);
      }
    }

    if (attachments.length > 0 && chat != null) {
      for (int i = 0; i < attachments.length; i++) {
        OutgoingQueue().add(
          new QueueItem(
            event: "send-attachment",
            item: new AttachmentSender(
              attachments[i],
              chat!,
              // This means to send the text when the last attachment is sent
              // If we switched this to i == 0, then it will be send with the first attachment
              i == attachments.length - 1 ? text : "",
            ),
          ),
        );
      }
    } else if (chat != null) {
      // We include messageBloc here because the bloc listener may not be instantiated yet
      ActionHandler.sendMessage(chat!, text, messageBloc: messageBloc);
    }

    if (isCreator!) {
      isCreator = false;
      wasCreator = true;
      this.existingText = "";
      this.existingAttachments = [];
      setState(() {});
    }

    return true;
  }

  Widget buildFAB() {
    if (widget.onSelect != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 55.0),
        child: FloatingActionButton(
          onPressed: () => widget.onSelect!(selected),
          child: widget.selectIcon ??
              Icon(
                Icons.check,
                color: Theme.of(context).textTheme.bodyText1!.color,
              ),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }

    return Container();
  }

  Widget buildScrollToBottomFAB(BuildContext context) {
    if (CurrentChat.forGuid(chat!.guid!) != null &&
        CurrentChat.forGuid(chat!.guid!)!.showScrollDown.value &&
        (SettingsManager().settings.skin.value == Skins.Material ||
            SettingsManager().settings.skin.value == Skins.Samsung)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 15.0),
        child: FloatingActionButton(
          onPressed: currentChat!.scrollToBottom,
          child: Icon(
            Icons.arrow_downward,
            color: Theme.of(context).textTheme.bodyText1!.color,
          ),
          backgroundColor: Theme.of(context).accentColor,
        ),
      );
    } else if (CurrentChat.forGuid(chat!.guid!) != null &&
        CurrentChat.forGuid(chat!.guid!)!.showScrollDown.value &&
        SettingsManager().settings.skin.value == Skins.iOS) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Padding(
          padding: EdgeInsets.only(left: 25.0, bottom: 15),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: Container(
                  height: 35,
                  decoration: BoxDecoration(
                    color: Theme.of(context).accentColor.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    child: GestureDetector(
                      onTap: CurrentChat.forGuid(chat!.guid!)!.scrollToBottom,
                      child: Text(
                        "\u{2193} Scroll to bottom \u{2193}",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]);
    }
    return Container();
  }

  void loadBrightness() {
    Color now = Theme.of(context).backgroundColor;
    bool themeChanged = previousBackgroundColor == null || previousBackgroundColor != now;
    if (!themeChanged && gotBrightness) return;

    previousBackgroundColor = now;

    bool isDark = now.computeLuminance() < 0.179;
    brightness = isDark ? Brightness.dark : Brightness.light;
    gotBrightness = true;
    if (this.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    loadBrightness();
    currentChat?.isAlive = true;

    if (widget.customMessageBloc != null && messageBloc == null) {
      messageBloc = widget.customMessageBloc;
    }

    if (messageBloc == null) {
      messageBloc = initMessageBloc();
      messageBloc!.getMessages();
    }

    Widget textField = BlueBubblesTextField(
      key: key,
      onSend: send,
      wasCreator: wasCreator,
      isCreator: isCreator,
      existingAttachments: this.existingAttachments,
      existingText: this.existingText,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        extendBodyBehindAppBar: !isCreator!,
        appBar: !isCreator!
            ? buildConversationViewHeader() as PreferredSizeWidget?
            : buildChatSelectorHeader() as PreferredSizeWidget?,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            if (isCreator!)
              ChatSelectorTextField(
                controller: chatSelectorController,
                onRemove: (UniqueContact item) {
                  if (item.isChat) {
                    selected.removeWhere((e) => (e.chat?.guid ?? null) == item.chat!.guid);
                  } else {
                    selected.removeWhere((e) => e.address == item.address);
                  }
                  fetchCurrentChat();
                  filterContacts();
                  resetCursor();
                  if (this.mounted) setState(() {});
                },
                onSelected: onSelected,
                isCreator: widget.isCreator,
                allContacts: contacts,
                selectedContacts: selected,
              ),
            Obx(() {
              if (!ChatBloc().hasChats.value) {
                return Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Loading existing chats...",
                            style: Theme.of(context).textTheme.subtitle1,
                          ),
                        ),
                        buildProgressIndicator(context, size: 15),
                      ],
                    ),
                  ),
                );
              } else
                return SizedBox.shrink();
            }),
            Expanded(
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Obx(
                                () => fetchingCurrentChat.value
                                ? Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 20.0),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        "Loading chat...",
                                        style: Theme.of(context).textTheme.subtitle1,
                                      ),
                                    ),
                                    buildProgressIndicator(context, size: 15),
                                  ],
                                ),
                              ),
                            )
                                : (searchQuery.length == 0 || !isCreator!) && chat != null
                                ? GetBuilder<CurrentChat>(
                                  init: CurrentChat(
                                    chat: chat!,
                                  ),
                                  autoRemove: false,
                                  initState: (state) {
                                    ChatBloc().currentChatGuids.add(chat!.guid!);
                                  },
                                  dispose: (state) {
                                    ChatBloc().currentChatGuids.remove(chat!.guid!);
                                  },
                                  tag: chat!.guid,
                                  builder: (controller) => CurrentChatInheritedWidget(
                                    currentChat: controller,
                                    child: Stack(
                                      alignment: Alignment.bottomCenter,
                                      children: [
                                        MessagesView(
                                          key: new Key(chat?.guid ?? "unknown-chat"),
                                          messageBloc: messageBloc!,
                                          currentChat: controller,
                                          showHandle: chat!.participants.length > 1,
                                          chat: chat!,
                                          initComplete: widget.onMessagesViewComplete,
                                        ),
                                        CurrentChat.forGuid(chat!.guid!) != null
                                            ? Obx(() => AnimatedOpacity(
                                          duration: Duration(milliseconds: 250),
                                          opacity: CurrentChat.forGuid(chat!.guid!)!.showScrollDown.value ? 1 : 0,
                                          curve: Curves.easeInOut,
                                          child: buildScrollToBottomFAB(context),
                                        ))
                                            : Container(),
                                      ],
                                    ),
                                  )
                                )
                                : buildChatSelectorBody(),
                          ),
                        ),
                        widget.onSelect == null
                            ? SettingsManager().settings.swipeToCloseKeyboard.value ||
                            SettingsManager().settings.swipeToOpenKeyboard.value
                            ? GestureDetector(
                            onPanUpdate: (details) {
                              if (SettingsManager().settings.swipeToCloseKeyboard.value &&
                                  details.delta.dy > 0 &&
                                  (currentChat?.keyboardOpen ?? false)) {
                                EventDispatcher.instance.emit("unfocus-keyboard", null);
                              } else if (SettingsManager().settings.swipeToOpenKeyboard.value &&
                                  details.delta.dy < 0 &&
                                  !(currentChat?.keyboardOpen ?? false)) {
                                EventDispatcher.instance.emit("focus-keyboard", null);
                              }
                            },
                            child: textField) : textField : Container(),
                      ]
                    ),
                    AnimatedPositioned(
                      duration: Duration(milliseconds: 300),
                      bottom: message != null ? 62 + offset : 10 + offset,
                      right: 5,
                      curve: Curves.easeIn,
                      onEnd: () {
                        setState(() {
                          tween = Tween<double>(begin: 1, end: 0);
                          controller = CustomAnimationControl.stop;
                          message = null;
                        });
                      },
                      child: Visibility(
                        visible: message != null,
                        child: CustomAnimation<double>(
                            control: controller,
                            tween: tween,
                            duration: Duration(milliseconds: 200),
                            builder: (context, child, value) {
                              return SentMessageHelper.buildMessageWithTail(
                                context,
                                message,
                                true,
                                false,
                                message?.isBigEmoji() ?? false,
                                currentChat: currentChat,
                                customWidth: (message?.hasAttachments ?? false)
                                    && (message?.text?.isEmpty ?? true) ? null : value,
                                customColor: (message?.hasAttachments ?? false)
                                    && (message?.text?.isEmpty ?? true) ?
                                Colors.transparent : null,
                                customContent: child,
                              );
                            },
                            child: (message?.hasAttachments ?? false)
                                && (message?.text?.isEmpty ?? true) ?
                            MessageAttachments(
                              message: message,
                              showTail: true,
                              showHandle: false,
                            ) : null
                        ),
                      ),
                    ),
                  ]
                ),
            ),
          ],
        ),
        floatingActionButton: currentChat != null
            ? AnimatedOpacity(
                duration: Duration(milliseconds: 250), opacity: 1, curve: Curves.easeInOut, child: buildFAB())
            : null,
      ),
    );
  }
}

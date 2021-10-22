import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/redacted_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/setup/theme_selector/theme_selector.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/balloon_bundle_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_tail.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_time_stamp.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_popup_holder.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reply_line_painter.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:collection/src/iterable_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'message_content/delivered_receipt.dart';

class ReceivedMessage extends StatefulWidget {
  final bool showTail;
  final Message message;
  final Message? olderMessage;
  final Message? newerMessage;
  final bool showHandle;
  final MessageBloc? messageBloc;
  final bool hasTimestampAbove;
  final bool hasTimestampBelow;
  final bool showReplies;

  // Sub-widgets
  final Widget stickersWidget;
  final Widget attachmentsWidget;
  final Widget reactionsWidget;
  final Widget urlPreviewWidget;

  final bool showTimeStamp;

  ReceivedMessage({
    Key? key,
    required this.showTail,
    required this.olderMessage,
    required this.newerMessage,
    required this.message,
    required this.showHandle,
    required this.messageBloc,
    required this.hasTimestampAbove,
    required this.hasTimestampBelow,
    required this.showReplies,

    // Sub-widgets
    required this.stickersWidget,
    required this.attachmentsWidget,
    required this.reactionsWidget,
    required this.urlPreviewWidget,
    this.showTimeStamp = false,
  }) : super(key: key);

  @override
  _ReceivedMessageState createState() => _ReceivedMessageState();
}

class _ReceivedMessageState extends State<ReceivedMessage> with MessageWidgetMixin {
  bool checkedHandle = false;
  late String contactTitle;
  final Rx<Skins> skin = Rx<Skins>(SettingsManager().settings.skin.value);
  late final spanFuture = MessageWidgetMixin.buildMessageSpansAsync(context, widget.message,
      colors: widget.message.handle?.color != null ? getBubbleColors() : null);
  Size? threadOriginatorSize;
  Size? messageSize;
  bool showReplies = false;

  @override
  initState() {
    super.initState();
    showReplies = widget.showReplies;
    initMessageState(widget.message, widget.showHandle).then((value) => {if (this.mounted) setState(() {})});
    contactTitle = ContactManager().getContactTitle(widget.message.handle) ?? "";

    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'refresh-avatar' && event["data"][0] == widget.message.handle?.address && mounted) {
        widget.message.handle?.color = event['data'][1];
        setState(() {});
      }
    });
  }

  List<Color> getBubbleColors() {
    List<Color> bubbleColors = [context.theme.accentColor, context.theme.accentColor];
    if (SettingsManager().settings.colorfulBubbles.value) {
      if (widget.message.handle?.color == null) {
        bubbleColors = toColorGradient(widget.message.handle?.address);
      } else {
        bubbleColors = [
          HexColor(widget.message.handle!.color!),
          HexColor(widget.message.handle!.color!).lightenAmount(0.02),
        ];
      }
    }
    return bubbleColors;
  }

  /// Builds the message bubble with teh tail (if applicable)
  Widget _buildMessageWithTail(Message message) {
    if (message.isBigEmoji()) {
      final bool hideContent =
          SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideEmojis.value;

      bool hasReactions = message.getReactions().isNotEmpty;
      return Padding(
        padding: EdgeInsets.only(
          left: CurrentChat.of(context)!.chat.participants.length > 1 ? 5.0 : 0.0,
          right: (hasReactions) ? 15.0 : 0.0,
          top: widget.message.getReactions().isNotEmpty ? 15 : 0,
        ),
        child: hideContent
            ? ClipRRect(
                borderRadius: BorderRadius.circular(25.0),
                child: Container(
                    width: 70,
                    height: 70,
                    color: Theme.of(context).accentColor,
                    child: Center(
                      child: Text(
                        "emoji",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                    )),
              )
            : Text(
                message.text!,
                style: Theme.of(context).textTheme.bodyText2!.apply(fontSizeFactor: 4),
              ),
      );
    }

    return Stack(
      alignment: AlignmentDirectional.bottomStart,
      children: [
        if (widget.showTail && skin.value == Skins.iOS)
          Obx(() => MessageTail(
                isFromMe: false,
                color: getBubbleColors()[0],
              )),
        Container(
          margin: EdgeInsets.only(
            top: widget.message.getReactions().isNotEmpty && !widget.message.hasAttachments
                ? 18
                : (widget.message.isFromMe != widget.olderMessage?.isFromMe)
                    ? 5.0
                    : 0,
            left: 10,
            right: 10,
          ),
          constraints: BoxConstraints(
            maxWidth: CustomNavigator.width(context) * MessageWidgetMixin.maxSize,
          ),
          padding: EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: skin.value == Skins.iOS
                ? BorderRadius.only(
                    bottomLeft: Radius.circular(17),
                    bottomRight: Radius.circular(20),
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  )
                : (skin.value == Skins.Material)
                    ? BorderRadius.only(
                        topLeft: widget.olderMessage == null ||
                                MessageHelper.getShowTail(context, widget.olderMessage, widget.message)
                            ? Radius.circular(20)
                            : Radius.circular(5),
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                        bottomLeft: Radius.circular(widget.showTail ? 20 : 5),
                      )
                    : (skin.value == Skins.Samsung)
                        ? BorderRadius.only(
                            topLeft: Radius.circular(17.5),
                            topRight: Radius.circular(17.5),
                            bottomRight: Radius.circular(17.5),
                            bottomLeft: Radius.circular(17.5),
                          )
                        : null,
            gradient: LinearGradient(
              begin: AlignmentDirectional.bottomCenter,
              end: AlignmentDirectional.topCenter,
              colors: getBubbleColors(),
            ),
          ),
          child: FutureBuilder<List<InlineSpan>>(
              future: spanFuture,
              initialData: MessageWidgetMixin.buildMessageSpans(context, widget.message,
                  colors: widget.message.handle?.color != null ? getBubbleColors() : null),
              builder: (context, snapshot) {
                return RichText(
                  text: TextSpan(
                    children: snapshot.data ??
                        MessageWidgetMixin.buildMessageSpans(context, widget.message,
                            colors: widget.message.handle?.color != null ? getBubbleColors() : null),
                    style: Theme.of(context).textTheme.bodyText2,
                  ),
                );
              }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Skin.of(context) != null) {
      skin.value = Skin.of(context)!.skin;
    }
    // The column that holds all the "messages"
    List<Widget> messageColumn = [];
    final msg =
        widget.message.associatedMessages.firstWhereOrNull((e) => e.guid == widget.message.threadOriginatorGuid);

    // First, add the message sender (if applicable)
    bool isGroup = CurrentChat.of(context)?.chat.isGroup() ?? false;
    bool addedSender = false;
    bool showSender = SettingsManager().settings.alwaysShowAvatars.value ||
        isGroup ||
        widget.message.guid == "redacted-mode-demo" ||
        widget.message.guid!.contains("theme-selector");
    if (widget.message.guid == "redacted-mode-demo" ||
        widget.message.guid!.contains("theme-selector") ||
        (isGroup &&
            (!sameSender(widget.message, widget.olderMessage) ||
                !widget.message.dateCreated!.isWithin(widget.olderMessage!.dateCreated!, minutes: 30)))) {
      messageColumn.add(
        Padding(
          padding: EdgeInsets.only(left: 15.0, top: 5.0, bottom: widget.message.getReactions().isNotEmpty ? 0.0 : 3.0),
          child: Text(
            getContactName(context, contactTitle, widget.message.handle?.address),
            style: Theme.of(context).textTheme.subtitle1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
      addedSender = true;
    }

    // Second, add the attachments
    if (widget.message.getRealAttachments().isNotEmpty) {
      messageColumn.add(
        MessageWidgetMixin.addStickersToWidget(
          message: MessageWidgetMixin.addReactionsToWidget(
              messageWidget: widget.attachmentsWidget,
              reactions: widget.reactionsWidget,
              message: widget.message,
              shouldShow: widget.message.hasAttachments),
          stickers: widget.stickersWidget,
          isFromMe: widget.message.isFromMe!,
        ),
      );
    }

    // Third, let's add the actual message we want to show
    Widget? message;
    if (widget.message.isInteractive()) {
      message = Padding(padding: EdgeInsets.only(left: 10.0), child: BalloonBundleWidget(message: widget.message));
    } else if (widget.message.hasText()) {
      message = _buildMessageWithTail(widget.message);
      if (widget.message.fullText.replaceAll("\n", " ").hasUrl) {
        message = widget.message.fullText.isURL
            ? Padding(
                padding: EdgeInsets.only(left: 10.0),
                child: widget.urlPreviewWidget,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Padding(
                      padding: EdgeInsets.only(left: 10.0),
                      child: widget.urlPreviewWidget,
                    ),
                    message,
                  ]);
      }
    }

    // Fourth, let's add any reactions or stickers to the widget
    if (message != null) {
      // only show the line if it is going to either connect up or down
      if (showReplies &&
          msg != null &&
          (widget.message.shouldConnectLower(widget.olderMessage, widget.newerMessage, msg) ||
              widget.message.shouldConnectUpper(widget.olderMessage, msg))) {
        // get the correct size for the message being replied to
        if (widget.message.upperIsThreadOriginatorBubble(widget.olderMessage)) {
          threadOriginatorSize ??= msg.getBubbleSize(context);
        } else {
          threadOriginatorSize ??= widget.olderMessage?.getBubbleSize(context);
        }
        messageSize ??= widget.message.getBubbleSize(context);
        messageColumn.add(
          StreamBuilder<double>(
              stream: CurrentChat.of(context)?.timeStampOffsetStream.stream,
              builder: (context, snapshot) {
                final offset = (-(snapshot.data ?? 0)).clamp(0, 70).toDouble();
                final originalWidth = max(
                    min(CustomNavigator.width(context) - messageSize!.width - 125, CustomNavigator.width(context) / 3),
                    10);
                final width = max(
                    min(CustomNavigator.width(context) - messageSize!.width - 125, CustomNavigator.width(context) / 3) -
                        offset,
                    10);
                return AnimatedContainer(
                  duration: Duration(milliseconds: offset == 0 ? 150 : 0),
                  width: CustomNavigator.width(context) - 45 - offset,
                  padding: EdgeInsets.only(right: max(30 - (width == 10 ? offset - (originalWidth - width) : 0), 0)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MessageWidgetMixin.addStickersToWidget(
                        message: MessageWidgetMixin.addReactionsToWidget(
                            messageWidget: message!,
                            reactions: widget.reactionsWidget,
                            message: widget.message,
                            shouldShow: widget.message.getRealAttachments().isEmpty),
                        stickers: widget.stickersWidget,
                        isFromMe: widget.message.isFromMe!,
                      ),
                      AnimatedContainer(
                        duration: Duration(milliseconds: offset == 0 ? 150 : 0),
                        // to make sure the bounds do not overflow, and so we
                        // dont draw an ugly long line)
                        width: width.toDouble(),
                        height: messageSize!.height / 2,
                        child: CustomPaint(
                          painter: LinePainter(
                            context,
                            widget.message,
                            widget.olderMessage,
                            widget.newerMessage,
                            msg,
                            threadOriginatorSize!,
                            messageSize!,
                            widget.olderMessage?.threadOriginatorGuid == widget.message.threadOriginatorGuid &&
                                widget.hasTimestampAbove,
                            widget.hasTimestampBelow,
                            addedSender,
                            offset,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
        );
      } else {
        messageColumn.add(
          MessageWidgetMixin.addStickersToWidget(
            message: MessageWidgetMixin.addReactionsToWidget(
                messageWidget: message,
                reactions: widget.reactionsWidget,
                message: widget.message,
                shouldShow: widget.message.getRealAttachments().isEmpty),
            stickers: widget.stickersWidget,
            isFromMe: widget.message.isFromMe!,
          ),
        );
      }
    }

    if (widget.showTimeStamp) {
      messageColumn.add(
        DeliveredReceipt(
          message: widget.message,
          showDeliveredReceipt: widget.showTimeStamp,
          shouldAnimate: true,
        ),
      );
    }

    List<Widget> messagePopupColumn = List<Widget>.from(messageColumn);
    if (!addedSender && isGroup) {
      messagePopupColumn.insert(
        0,
        Padding(
          padding: EdgeInsets.only(left: 15.0, top: 5.0, bottom: widget.message.getReactions().isNotEmpty ? 0.0 : 3.0),
          child: Text(
            getContactName(context, contactTitle, widget.message.handle!.address),
            style: Theme.of(context).textTheme.subtitle1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    // Now, let's create a row that will be the row with the following:
    // -> Contact avatar
    // -> Message
    List<Widget> msgRow = [];
    bool addedAvatar = false;
    if (widget.showTail && (showSender || skin.value == Skins.Samsung)) {
      double topPadding = (isGroup) ? 5 : 0;
      if (skin.value == Skins.Samsung) {
        topPadding = 5.0;
        if (showSender) topPadding += 18;
        if (widget.message.hasReactions) topPadding += 20;
      }

      msgRow.add(
        Padding(
          padding: EdgeInsets.only(left: 5.0, top: topPadding, bottom: widget.showTimeStamp ? 20 : 0),
          child: ContactAvatarWidget(
            handle: widget.message.handle,
            size: 30,
            fontSize: 14,
            borderThickness: 0.1,
          ),
        ),
      );
      addedAvatar = true;
    }

    List<Widget> msgPopupRow = List<Widget>.from(msgRow);
    if (!addedAvatar && (showSender || skin.value == Skins.Samsung)) {
      double topPadding = (isGroup) ? 5 : 0;
      if (skin.value == Skins.Samsung) {
        topPadding = 5.0;
        if (showSender) topPadding += 18;
        if (widget.message.hasReactions) topPadding += 20;
      }

      msgPopupRow.add(
        Padding(
          padding: EdgeInsets.only(left: 5.0, top: topPadding),
          child: ContactAvatarWidget(
            handle: widget.message.handle,
            size: 30,
            fontSize: 14,
            borderThickness: 0.1,
          ),
        ),
      );
    }

    // Add the message column to the row
    msgRow.add(
      Padding(
        // Padding to shift the bubble up a bit, relative to the avatar
        padding: EdgeInsets.only(bottom: widget.showTail ? 0.0 : 5.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: messageColumn,
        ),
      ),
    );

    msgPopupRow.add(
      Padding(
        // Padding to shift the bubble up a bit, relative to the avatar
        padding: EdgeInsets.only(bottom: 0.0),
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: messagePopupColumn,
          ),
        ),
      ),
    );

    // Finally, create a container row so we can have the swipe timestamp
    return Column(
      children: [
        if (showReplies &&
            widget.message.threadOriginatorGuid != null &&
            widget.olderMessage?.threadOriginatorGuid != widget.message.threadOriginatorGuid &&
            msg != null &&
            widget.olderMessage?.guid != msg.guid)
          GestureDetector(
            onTap: () {
              List<Message> _messages = [];
              if (widget.message.threadOriginatorGuid != null) {
                _messages = widget.messageBloc?.messages.values
                        .where((e) =>
                            e.threadOriginatorGuid == widget.message.threadOriginatorGuid ||
                            e.guid == widget.message.threadOriginatorGuid)
                        .toList() ??
                    [];
              } else {
                _messages = widget.messageBloc?.messages.values
                        .where((e) => e.threadOriginatorGuid == widget.message.guid || e.guid == widget.message.guid)
                        .toList() ??
                    [];
              }
              _messages.sort((a, b) => a.id!.compareTo(b.id!));
              _messages.sort((a, b) => a.dateCreated!.compareTo(b.dateCreated!));
              final controller = ScrollController();
              Navigator.push(
                context,
                PageRouteBuilder(
                  settings: RouteSettings(arguments: {"hideTail": true}),
                  transitionDuration: Duration(milliseconds: 150),
                  pageBuilder: (context, animation, secondaryAnimation) {
                    Future.delayed(Duration.zero, () => controller.jumpTo(controller.position.maxScrollExtent));
                    return FadeTransition(
                        opacity: animation,
                        child: GestureDetector(
                          onTap: () {
                            Get.back();
                          },
                          child: AnnotatedRegion<SystemUiOverlayStyle>(
                            value: SystemUiOverlayStyle(
                              systemNavigationBarColor: Theme.of(context).backgroundColor, // navigation bar color
                              systemNavigationBarIconBrightness:
                                  Theme.of(context).backgroundColor.computeLuminance() > 0.5
                                      ? Brightness.dark
                                      : Brightness.light,
                              statusBarColor: Colors.transparent, // status bar color
                            ),
                            child: Scaffold(
                              backgroundColor: Colors.transparent,
                              body: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                                child: SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Center(
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        controller: controller,
                                        itemBuilder: (context, index) {
                                          return AbsorbPointer(
                                            absorbing: true,
                                            child: Padding(
                                                padding: EdgeInsets.only(left: 5.0, right: 5.0),
                                                child: MessageWidget(
                                                  key: Key(_messages[index].guid!),
                                                  message: _messages[index],
                                                  olderMessage: null,
                                                  newerMessage: null,
                                                  showHandle: true,
                                                  isFirstSentMessage:
                                                      widget.messageBloc!.firstSentMessage == _messages[index].guid,
                                                  showHero: false,
                                                  showReplies: false,
                                                  bloc: widget.messageBloc!,
                                                )),
                                          );
                                        },
                                        itemCount: _messages.length,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ));
                  },
                  fullscreenDialog: true,
                  opaque: false,
                ),
              );
            },
            child: Container(
              width: CustomNavigator.width(context) - 10,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: msg.isFromMe ?? false ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    if ((CurrentChat.of(context)?.chat.isGroup() ?? false) && !msg.isFromMe!)
                      Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: ContactAvatarWidget(
                          handle: msg.handle,
                          size: 25,
                          fontSize: 10,
                          borderThickness: 0.1,
                        ),
                      ),
                    Stack(
                      alignment: AlignmentDirectional.bottomStart,
                      children: [
                        if (skin.value == Skins.iOS)
                          Obx(() => MessageTail(
                                isFromMe: false,
                                color: getBubbleColors()[0],
                                isReply: true,
                              )),
                        Container(
                          margin: EdgeInsets.only(
                            left: 6,
                            right: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: CustomNavigator.width(context) * MessageWidgetMixin.maxSize - 30,
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: getBubbleColors()[0]),
                            borderRadius: skin.value == Skins.iOS
                                ? BorderRadius.only(
                                    bottomLeft: Radius.circular(17),
                                    bottomRight: Radius.circular(20),
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  )
                                : (skin.value == Skins.Material)
                                    ? BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        topRight: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
                                        bottomLeft: Radius.circular(20),
                                      )
                                    : (skin.value == Skins.Samsung)
                                        ? BorderRadius.only(
                                            topLeft: Radius.circular(17.5),
                                            topRight: Radius.circular(17.5),
                                            bottomRight: Radius.circular(17.5),
                                            bottomLeft: Radius.circular(17.5),
                                          )
                                        : null,
                          ),
                          child: FutureBuilder<List<InlineSpan>>(
                              future: MessageWidgetMixin.buildMessageSpansAsync(context, msg,
                                  colorOverride: getBubbleColors()[0].lightenOrDarken(30)),
                              initialData: MessageWidgetMixin.buildMessageSpans(context, msg,
                                  colorOverride: getBubbleColors()[0].lightenOrDarken(30)),
                              builder: (context, snapshot) {
                                return RichText(
                                  text: TextSpan(
                                    children: snapshot.data ??
                                        MessageWidgetMixin.buildMessageSpans(context, msg,
                                            colorOverride: getBubbleColors()[0].lightenOrDarken(30)),
                                  ),
                                );
                              }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          // Add padding when we are showing the avatar
          padding: EdgeInsets.only(
              top: (skin.value != Skins.iOS && widget.message.isFromMe == widget.olderMessage?.isFromMe) ? 3.0 : 0.0,
              left: (!widget.showTail && (showSender || skin.value == Skins.Samsung)) ? 35.0 : 0.0,
              bottom: (widget.showTail && skin.value == Skins.iOS) ? 10.0 : 0.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: (skin.value == Skins.iOS || skin.value == Skins.Material)
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MessagePopupHolder(
                message: widget.message,
                olderMessage: widget.olderMessage,
                newerMessage: widget.newerMessage,
                popupPushed: (pushed) {
                  if (mounted) {
                    setState(() {
                      showReplies = !pushed;
                    });
                  }
                },
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: msgRow,
                  ),
                  Obx(() {
                    final list = widget.messageBloc?.threadOriginators.values.where((e) => e == widget.message.guid) ??
                        [].obs.reversed;
                    if (list.isNotEmpty) {
                      return GestureDetector(
                        onTap: () {
                          List<Message> _messages = [];
                          if (widget.message.threadOriginatorGuid != null) {
                            _messages = widget.messageBloc?.messages.values
                                    .where((e) =>
                                        e.threadOriginatorGuid == widget.message.threadOriginatorGuid ||
                                        e.guid == widget.message.threadOriginatorGuid)
                                    .toList() ??
                                [];
                          } else {
                            _messages = widget.messageBloc?.messages.values
                                    .where((e) =>
                                        e.threadOriginatorGuid == widget.message.guid || e.guid == widget.message.guid)
                                    .toList() ??
                                [];
                          }
                          _messages.sort((a, b) => a.id == null || b.id == null ? -1 : a.id!.compareTo(b.id!));
                          _messages.sort((a, b) => a.dateCreated!.compareTo(b.dateCreated!));
                          final controller = ScrollController();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              settings: RouteSettings(arguments: {"hideTail": true}),
                              transitionDuration: Duration(milliseconds: 150),
                              pageBuilder: (context, animation, secondaryAnimation) {
                                Future.delayed(
                                    Duration.zero, () => controller.jumpTo(controller.position.maxScrollExtent));
                                return FadeTransition(
                                    opacity: animation,
                                    child: GestureDetector(
                                      onTap: () {
                                        Get.back();
                                      },
                                      child: AnnotatedRegion<SystemUiOverlayStyle>(
                                        value: SystemUiOverlayStyle(
                                          systemNavigationBarColor:
                                              Theme.of(context).backgroundColor, // navigation bar color
                                          systemNavigationBarIconBrightness:
                                              Theme.of(context).backgroundColor.computeLuminance() > 0.5
                                                  ? Brightness.dark
                                                  : Brightness.light,
                                          statusBarColor: Colors.transparent, // status bar color
                                        ),
                                        child: Scaffold(
                                          backgroundColor: Colors.transparent,
                                          body: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                                            child: SafeArea(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                child: Center(
                                                  child: ListView.builder(
                                                    shrinkWrap: true,
                                                    controller: controller,
                                                    itemBuilder: (context, index) {
                                                      return AbsorbPointer(
                                                        absorbing: true,
                                                        child: Padding(
                                                            padding: EdgeInsets.only(left: 5.0, right: 5.0),
                                                            child: MessageWidget(
                                                              key: Key(_messages[index].guid!),
                                                              message: _messages[index],
                                                              olderMessage: null,
                                                              newerMessage: null,
                                                              showHandle: true,
                                                              isFirstSentMessage:
                                                                  widget.messageBloc!.firstSentMessage ==
                                                                      _messages[index].guid,
                                                              showHero: false,
                                                              showReplies: false,
                                                              bloc: widget.messageBloc!,
                                                            )),
                                                      );
                                                    },
                                                    itemCount: _messages.length,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ));
                              },
                              fullscreenDialog: true,
                              opaque: false,
                            ),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.only(left: addedAvatar ? 50 : 18, right: 8.0, top: 2, bottom: 4),
                          child: Text(
                            "${list.length} Repl${list.length > 1 ? "ies" : "y"}",
                            style: Theme.of(context)
                                .textTheme
                                .subtitle2!
                                .copyWith(fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                      );
                    } else {
                      return Container();
                    }
                  }),
                  // Add the timestamp for the samsung theme
                  if (skin.value == Skins.Samsung &&
                      widget.message.dateCreated != null &&
                      (widget.newerMessage?.dateCreated == null ||
                          widget.message.isFromMe != widget.newerMessage?.isFromMe ||
                          widget.message.handleId != widget.newerMessage?.handleId ||
                          !widget.message.dateCreated!.isWithin(widget.newerMessage!.dateCreated!, minutes: 5)))
                    Padding(
                      padding: EdgeInsets.only(top: 5, left: (isGroup) ? 60 : 20),
                      child: MessageTimeStamp(
                        message: widget.message,
                        singleLine: true,
                        useYesterday: true,
                      ),
                    )
                ]),
                popupChild: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: msgPopupRow,
                ),
              ),
              if (!kIsDesktop &&
                  !kIsWeb &&
                  skin.value != Skins.Samsung &&
                  widget.message.guid != widget.olderMessage?.guid)
                MessageTimeStamp(
                  message: widget.message,
                )
            ],
          ),
        ),
      ],
    );
  }
}

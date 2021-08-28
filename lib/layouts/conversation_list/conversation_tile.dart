import 'dart:async';
import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/socket_singletons.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/typing_indicator.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class ConversationTile extends StatefulWidget {
  final Chat chat;
  final List<File> existingAttachments;
  final String? existingText;
  final Function(bool)? onSelect;
  final bool inSelectMode;
  final List<Chat> selected;

  ConversationTile({
    Key? key,
    required this.chat,
    this.existingAttachments = const [],
    this.existingText,
    this.onSelect,
    this.inSelectMode = false,
    this.selected = const [],
  }) : super(key: key);

  @override
  _ConversationTileState createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile> with AutomaticKeepAliveClientMixin {
  bool isFetching = false;
  Brightness? brightness;
  Color? previousBackgroundColor;
  bool gotBrightness = false;

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

  bool get selected {
    if (widget.selected.isEmpty) return false;
    return widget.selected.where((element) => widget.chat.guid == element.guid).isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    fetchParticipants();
  }

  Future<void> fetchParticipants() async {
    if (isFetching) return;
    isFetching = true;

    // If our chat does not have any participants, get them
    if (isNullOrEmpty(widget.chat.participants)!) {
      await widget.chat.getParticipants();
      if (!isNullOrEmpty(widget.chat.participants)! && this.mounted) {
        setState(() {});
      }
    }

    isFetching = false;
  }

  void onTapUp(details) {
    if (widget.inSelectMode && widget.onSelect != null) {
      onSelect();
    } else {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (BuildContext context) {
            return ConversationView(
              chat: widget.chat,
              existingAttachments: widget.existingAttachments,
              existingText: widget.existingText,
            );
          },
        ),
      );
    }
  }

  void onTapUpBypass() {
    this.onTapUp(TapUpDetails(kind: PointerDeviceKind.touch));
  }

  Widget buildSlider(Widget child) {
    return Obx(() => Slidable(
          actionPane: SlidableStrechActionPane(),
          actionExtentRatio: 0.2,
          actions: [
            if (SettingsManager().settings.iosShowPin.value)
              IconSlideAction(
                caption: widget.chat.isPinned! ? 'Unpin' : 'Pin',
                color: Colors.yellow[800],
                foregroundColor: Colors.white,
                icon: widget.chat.isPinned! ? Icons.star_outline : Icons.star,
                onTap: () async {
                  await widget.chat.togglePin(!widget.chat.isPinned!);
                  EventDispatcher.instance.emit("refresh", null);
                  if (this.mounted) setState(() {});
                },
              ),
          ],
          secondaryActions: <Widget>[
            if (!widget.chat.isArchived! && SettingsManager().settings.iosShowAlert.value)
              IconSlideAction(
                caption: widget.chat.isMuted! ? 'Show Alerts' : 'Hide Alerts',
                color: Colors.purple[700],
                icon: widget.chat.isMuted! ? Icons.notifications_active : Icons.notifications_off,
                onTap: () async {
                  await widget.chat.toggleMute(!widget.chat.isMuted!);
                  if (this.mounted) setState(() {});
                },
              ),
            if (SettingsManager().settings.iosShowDelete.value)
              IconSlideAction(
                caption: "Delete",
                color: Colors.red,
                icon: Icons.delete_forever,
                onTap: () async {
                  ChatBloc().deleteChat(widget.chat);
                  Chat.deleteChat(widget.chat);
                },
              ),
            if (SettingsManager().settings.iosShowMarkRead.value)
              IconSlideAction(
                caption: widget.chat.hasUnreadMessage! ? 'Mark Read' : 'Mark Unread',
                color: Colors.blue,
                icon: widget.chat.hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread,
                onTap: () {
                  ChatBloc().toggleChatUnread(widget.chat, !widget.chat.hasUnreadMessage!);
                },
              ),
            if (SettingsManager().settings.iosShowArchive.value)
              IconSlideAction(
                caption: widget.chat.isArchived! ? 'UnArchive' : 'Archive',
                color: widget.chat.isArchived! ? Colors.blue : Colors.red,
                icon: widget.chat.isArchived! ? Icons.unarchive : Icons.archive,
                onTap: () {
                  if (widget.chat.isArchived!) {
                    ChatBloc().unArchiveChat(widget.chat);
                  } else {
                    ChatBloc().archiveChat(widget.chat);
                  }
                },
              ),
          ],
          child: child,
        ));
  }

  Widget buildTitle() {
    final hideInfo = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideContactInfo.value;
    final generateNames =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeContactNames.value;

    TextStyle? style = Theme.of(context).textTheme.bodyText1;
    String? title = widget.chat.title != null ? widget.chat.title : "";

    if (generateNames)
      title = widget.chat.fakeParticipants.length == 1 ? widget.chat.fakeParticipants[0] : "Group Chat";
    else if (hideInfo) style = style!.copyWith(color: Colors.transparent);

    return TextOneLine(title!, style: style, overflow: TextOverflow.ellipsis);
  }

  Widget buildSubtitle() {
    return GetBuilder<CurrentChat>(
      init: CurrentChat(
        chat: widget.chat,
      ),
      autoRemove: false,
      tag: widget.chat.guid,
      builder: (controller) {
        return Obx(() {
          if (controller.showTypingIndicator.value) {
            double height = Theme.of(context).textTheme.subtitle1!.fontSize!;
            double indicatorHeight = (height * 2).clamp(height, height + 13);
            return Container(
              transform: Matrix4.translationValues(SettingsManager().settings.skin.value == Skins.iOS ? 0 : -5, 0, 0),
              height: height,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxHeight: indicatorHeight,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: indicatorHeight),
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    child: TypingIndicator(
                      visible: true,
                    ),
                  ),
                ),
              ),
            );
          }

          final hideContent =
              SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideMessageContent.value;
          final generateContent = SettingsManager().settings.redactedMode.value &&
              SettingsManager().settings.generateFakeMessageContent.value;

          TextStyle style = Theme.of(context).textTheme.subtitle1!.apply(
            color: Theme.of(context).textTheme.subtitle1!.color!.withOpacity(
              0.85,
            ),
          );
          String? message = widget.chat.latestMessageText != null ? widget.chat.latestMessageText : "";

          if (generateContent)
            message = widget.chat.fakeLatestMessageText;
          else if (hideContent) style = style.copyWith(color: Colors.transparent);

          return widget.chat.latestMessageText != null && !(widget.chat.latestMessageText is String)
              ? widget.chat.latestMessageText as Widget
              : TextOneLine(message ?? "", style: style, overflow: TextOverflow.ellipsis);
        });
      },
    );
  }

  Widget buildLeading() {
    return Padding(
        padding: EdgeInsets.only(top: 2, right: 2),
        child: !selected
            ? ContactAvatarGroupWidget(
                chat: widget.chat,
                size: 40,
                editable: false,
                onTap: this.onTapUpBypass,
              )
            : Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Theme.of(context).primaryColor,
                ),
                width: 40,
                height: 40,
                child: Center(
                  child: Icon(
                    Icons.check,
                    color: Theme.of(context).textTheme.bodyText1!.color,
                    size: 20,
                  ),
                ),
              ));
  }

  Widget _buildDate() => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 100.0),
        child: FutureBuilder<Message>(
          future: widget.chat.latestMessage,
          builder: (context, snapshot) {
            return Obx(() => Text((snapshot.data?.error.value ?? 0) > 0 ? "Error" : buildDate(widget.chat.latestMessageDate),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.subtitle2!.copyWith(
                      color: (snapshot.data?.error.value ?? 0) > 0 ? Colors.red : Theme.of(context).textTheme.subtitle2!.color!.withOpacity(0.85),
                    ),
                overflow: TextOverflow.clip));
          }
        ),
      );

  void onTap() {
    Navigator.of(context).pushAndRemoveUntil(
      ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) {
          return ConversationView(
            chat: widget.chat,
            existingAttachments: widget.existingAttachments,
            existingText: widget.existingText,
          );
        },
      ),
      (route) => route.isFirst,
    );
  }

  void onSelect() {
    if (widget.onSelect != null) {
      widget.onSelect!(!selected);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    loadBrightness();
    return ThemeSwitcher(
      iOSSkin: _Cupertino(
        parent: this,
        parentProps: widget,
      ),
      materialSkin: _Material(
        parent: this,
        parentProps: widget,
      ),
      samsungSkin: _Samsung(
        parent: this,
        parentProps: widget,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _Cupertino extends StatefulWidget {
  _Cupertino({Key? key, required this.parent, required this.parentProps}) : super(key: key);
  final _ConversationTileState parent;
  final ConversationTile parentProps;

  @override
  __CupertinoState createState() => __CupertinoState();
}

class __CupertinoState extends State<_Cupertino> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return widget.parent.buildSlider(
      Material(
        color: !isPressed ? Theme.of(context).backgroundColor : Theme.of(context).backgroundColor.lightenOrDarken(30),
        child: GestureDetector(
          onTapDown: (details) {
            if (!this.mounted) return;

            setState(() {
              isPressed = true;
            });
          },
          onTapUp: (details) {
            this.widget.parent.onTapUp(details);

            Future.delayed(Duration(milliseconds: 200), () {
              if (this.mounted)
                setState(() {
                  isPressed = false;
                });
            });
          },
          onTapCancel: () {
            if (!this.mounted) return;

            setState(() {
              isPressed = false;
            });
          },
          onLongPress: () async {
            HapticFeedback.mediumImpact();
            await ChatBloc().toggleChatUnread(widget.parent.widget.chat, !widget.parent.widget.chat.hasUnreadMessage!);
            if (this.mounted) setState(() {});
          },
          child: Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 20.0),
                child: Obx(
                  () => Container(
                    decoration: BoxDecoration(
                      border: (!SettingsManager().settings.hideDividers.value)
                          ? Border(
                              bottom: BorderSide(
                                color: Theme.of(context).dividerColor,
                                width: 0.5,
                              ),
                            )
                          : null,
                    ),
                    child: ListTile(
                      dense: SettingsManager().settings.denseChatTiles.value,
                      contentPadding: EdgeInsets.only(left: 0),
                      title: widget.parent.buildTitle(),
                      subtitle: widget.parent.buildSubtitle(),
                      leading: widget.parent.buildLeading(),
                      trailing: Container(
                        padding: EdgeInsets.only(right: 8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              Container(
                                padding: EdgeInsets.only(right: 3),
                                child: widget.parent._buildDate(),
                              ),
                              Icon(
                                SettingsManager().settings.skin.value == Skins.iOS
                                    ? Icons.arrow_forward_ios
                                    : Icons.arrow_forward,
                                color: Theme.of(context).textTheme.subtitle1!.color,
                                size: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: Container(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Stack(
                        alignment: AlignmentDirectional.centerStart,
                        children: [
                          (!widget.parent.widget.chat.isMuted! && widget.parent.widget.chat.hasUnreadMessage!)
                              ? Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(35),
                                    color: Theme.of(context).primaryColor.withOpacity(0.8),
                                  ),
                                  width: 10,
                                  height: 10,
                                )
                              : Container(),
                          widget.parent.widget.chat.isPinned!
                              ? Icon(
                                  Icons.star,
                                  size: 10,
                                  color: Colors
                                      .yellow[AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark ? 100 : 700],
                                )
                              : Container(),
                        ],
                      ),
                      widget.parent.widget.chat.isMuted!
                          ? SvgPicture.asset(
                              "assets/icon/moon.svg",
                              color: widget.parentProps.chat.hasUnreadMessage!
                                  ? Theme.of(context).primaryColor.withOpacity(0.8)
                                  : Theme.of(context).textTheme.subtitle1!.color,
                              width: 10,
                              height: 10,
                            )
                          : Container()
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Material extends StatelessWidget {
  const _Material({Key? key, required this.parent, required this.parentProps}) : super(key: key);
  final _ConversationTileState parent;
  final ConversationTile parentProps;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: parent.selected ? Theme.of(context).primaryColor.withAlpha(120) : Theme.of(context).backgroundColor,
      child: InkWell(
        onTap: () {
          if (parent.selected) {
            parent.onSelect();
            HapticFeedback.lightImpact();
          } else if (parent.widget.inSelectMode) {
            parent.onSelect();
            HapticFeedback.lightImpact();
          } else {
            parent.onTap();
          }
        },
        onLongPress: () {
          parent.onSelect();
        },
        child: Obx(
          () => Container(
            decoration: BoxDecoration(
              border: (!SettingsManager().settings.hideDividers.value)
                  ? Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 0.5,
                      ),
                    )
                  : null,
            ),
            child: ListTile(
              dense: SettingsManager().settings.denseChatTiles.value,
              title: parent.buildTitle(),
              subtitle: parent.buildSubtitle(),
              leading: Stack(
                alignment: Alignment.topRight,
                children: [
                  parent.buildLeading(),
                  if (!parent.widget.chat.isMuted!)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color:
                            parent.widget.chat.hasUnreadMessage! ? Theme.of(context).primaryColor : Colors.transparent,
                      ),
                    ),
                ],
              ),
              trailing: Container(
                padding: EdgeInsets.only(right: 3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      if (parent.widget.chat.isPinned!) Icon(Icons.star, size: 15, color: Colors.yellow),
                      if (parent.widget.chat.isMuted!)
                        Icon(
                          Icons.notifications_off,
                          color: parent.widget.chat.hasUnreadMessage!
                              ? Theme.of(context).primaryColor.withOpacity(0.8)
                              : Theme.of(context).textTheme.subtitle1!.color,
                          size: 15,
                        ),
                      Container(
                        padding: EdgeInsets.only(right: 2, left: 2),
                        child: parent._buildDate(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Samsung extends StatelessWidget {
  const _Samsung({Key? key, required this.parent, required this.parentProps}) : super(key: key);
  final _ConversationTileState parent;
  final ConversationTile parentProps;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        hoverColor: Colors.red,
        onTap: () {
          if (parent.selected) {
            parent.onSelect();
            HapticFeedback.lightImpact();
          } else if (parent.widget.inSelectMode) {
            parent.onSelect();
            HapticFeedback.lightImpact();
          } else {
            parent.onTap();
          }
        },
        onLongPress: () {
          parent.onSelect();
        },
        child: Obx(
          () => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).accentColor,
              border: (!SettingsManager().settings.hideDividers.value)
                  ? Border(
                      top: BorderSide(
                        //
                        color: new Color(0xff2F2F2F),
                        width: 0.5,
                      ),
                    )
                  : null,
            ),
            child: ListTile(
              dense: SettingsManager().settings.denseChatTiles.value,
              title: parent.buildTitle(),
              subtitle: parent.buildSubtitle(),
              leading: Stack(
                alignment: Alignment.topRight,
                children: [
                  parent.buildLeading(),
                  if (!parent.widget.chat.isMuted!)
                    Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color:
                            parent.widget.chat.hasUnreadMessage! ? Theme.of(context).primaryColor : Colors.transparent,
                      ),
                    ),
                ],
              ),
              trailing: Container(
                padding: EdgeInsets.only(right: 3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      if (parent.widget.chat.isPinned!) Icon(Icons.star, size: 15, color: Colors.yellow),
                      if (parent.widget.chat.isMuted!)
                        Icon(
                          Icons.notifications_off,
                          color: Theme.of(context).textTheme.subtitle1!.color,
                          size: 15,
                        ),
                      Container(
                        padding: EdgeInsets.only(right: 2, left: 2),
                        child: parent._buildDate(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@override
bool get wantKeepAlive => true;

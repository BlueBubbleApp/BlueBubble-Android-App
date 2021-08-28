import 'dart:async';
import 'dart:io';

import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/pinned_tile_text_bubble.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reactions_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/typing_indicator.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class PinnedConversationTile extends StatefulWidget {
  final Chat chat;
  final List<File> existingAttachments;
  final String? existingText;

  PinnedConversationTile({
    Key? key,
    required this.chat,
    this.existingAttachments = const [],
    this.existingText,
  }) : super(key: key);

  @override
  _PinnedConversationTileState createState() => _PinnedConversationTileState();
}

class _PinnedConversationTileState extends State<PinnedConversationTile> with AutomaticKeepAliveClientMixin {

  @override
  void initState() {
    super.initState();
    fetchParticipants();
  }

  Future<void> fetchParticipants() async {
    // If our chat does not have any participants, get them
    if (isNullOrEmpty(widget.chat.participants)!) {
      await widget.chat.getParticipants();
      if (!isNullOrEmpty(widget.chat.participants)! && this.mounted) {
        setState(() {});
      }
    }
  }

  void onTapUp(details) {
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(
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

  void onTapUpBypass() {
    this.onTapUp(TapUpDetails(kind: PointerDeviceKind.touch));
  }

  Widget buildSubtitle() {
    final hideInfo = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideContactInfo.value;
    final generateNames =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeContactNames.value;

    TextStyle? style = context.textTheme.subtitle1!.apply(fontSizeFactor: 0.85);
    String? title = widget.chat.title != null ? widget.chat.title : "";

    if (generateNames)
      title = widget.chat.fakeParticipants.length == 1 ? widget.chat.fakeParticipants[0] : "Group Chat";
    else if (hideInfo) style = style.copyWith(color: Colors.transparent);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (!(widget.chat.isMuted ?? false) && (widget.chat.hasUnreadMessage ?? false))
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: context.theme.primaryColor.withOpacity(0.8),
              ),
              margin: EdgeInsets.only(right: 3)),
        if (widget.chat.isMuted ?? false)
          Container(
            margin: EdgeInsets.only(right: 3),
            child: SvgPicture.asset(
              "assets/icon/moon.svg",
              color: widget.chat.hasUnreadMessage!
                  ? context.theme.primaryColor.withOpacity(0.8)
                  : context.textTheme.subtitle1!.color,
              width: 8,
              height: 8,
            ),
          ),
        Flexible(
          child: TextOneLine(
            title!,
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    late Offset _tapPosition;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) {
        _tapPosition = details.globalPosition;
      },
      onTap: onTapUpBypass,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showMenu(
          color: Get.theme.accentColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          context: context,
          position: RelativeRect.fromLTRB(
            _tapPosition.dx,
            _tapPosition.dy,
            _tapPosition.dx,
            _tapPosition.dy,
          ),
          items: <PopupMenuEntry>[
            PopupMenuItem(
              padding: EdgeInsets.zero,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await widget.chat.togglePin(!widget.chat.isPinned!);
                  if (this.mounted) setState(() {});
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
                  child: Row(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(
                          widget.chat.isPinned! ? Icons.star_outline : Icons.star,
                          color: context.textTheme.bodyText1!.color,
                        ),
                      ),
                      Text(
                        widget.chat.isPinned! ? "Unpin" : "Pin",
                        style: context.textTheme.bodyText1!,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuItem(
              padding: EdgeInsets.zero,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await widget.chat.toggleMute(!widget.chat.isMuted!);
                  if (this.mounted) setState(() {});
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
                  child: Row(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(
                          widget.chat.isMuted! ? Icons.notifications_active : Icons.notifications_off,
                          color: context.textTheme.bodyText1!.color,
                        ),
                      ),
                      Text(widget.chat.isMuted! ? 'Show Alerts' : 'Hide Alerts', style: context.textTheme.bodyText1!),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuItem(
              padding: EdgeInsets.zero,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  widget.chat.toggleHasUnread(!widget.chat.hasUnreadMessage!);
                  if (this.mounted) setState(() {});
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
                  child: Row(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(
                          widget.chat.hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread,
                          color: context.textTheme.bodyText1!.color,
                        ),
                      ),
                      Text(widget.chat.hasUnreadMessage! ? 'Mark Read' : 'Mark Unread',
                          style: context.textTheme.bodyText1!),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuItem(
              padding: EdgeInsets.zero,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (widget.chat.isArchived!) {
                    ChatBloc().unArchiveChat(widget.chat);
                  } else {
                    ChatBloc().archiveChat(widget.chat);
                  }
                  if (this.mounted) setState(() {});
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
                  child: Row(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(
                          widget.chat.isArchived! ? Icons.unarchive : Icons.archive,
                          color: context.textTheme.bodyText1!.color,
                        ),
                      ),
                      Text(widget.chat.isArchived! ? 'Unarchive' : 'Archive', style: context.textTheme.bodyText1!),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuItem(
              padding: EdgeInsets.zero,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  ChatBloc().deleteChat(widget.chat);
                  Chat.deleteChat(widget.chat);
                  if (this.mounted) setState(() {});
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
                  child: Row(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(
                          Icons.delete_forever,
                          color: context.textTheme.bodyText1!.color,
                        ),
                      ),
                      Text('Delete', style: context.textTheme.bodyText1!),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: Padding(
        padding: EdgeInsets.only(
          top: 20,
          left: 10,
          right: 10,
          bottom: 10,
        ),
        child: Obx(
          () {
            int colCount = SettingsManager().settings.pinColumnsPortrait.value;
            if (context.mediaQuery.orientation != Orientation.portrait) {
              colCount = (colCount / context.mediaQuerySize.height * context.mediaQuerySize.width).floor();
            }
            int spaceBetween = (colCount - 1) * 20;
            int spaceAround = 20;

            // Great math right here
            double maxWidth = ((context.mediaQuerySize.width - spaceBetween - spaceAround) / colCount).floorToDouble();
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: <Widget>[
                  Column(
                    children: [
                      ContactAvatarGroupWidget(
                        chat: widget.chat,
                        size: (context.mediaQueryShortestSide - 150) / 3,
                        editable: false,
                        onTap: this.onTapUpBypass,
                      ),
                      Container(
                        padding: EdgeInsets.only(
                          top: 10,
                          left: 10,
                          right: 10,
                        ),
                        child: buildSubtitle(),
                      ),
                    ],
                  ),
                  GetBuilder<CurrentChat>(
                    init: CurrentChat(
                    chat: widget.chat,
                    ),
                    autoRemove: false,
                    tag: widget.chat.guid,
                    builder: (controller) {
                      if (controller.showTypingIndicator.value) {
                        return Positioned(
                          top: -11,
                          right: -13,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 32),
                            child: FittedBox(
                              child: TypingIndicator(
                                visible: true,
                              ),
                            ),
                          ),
                        );
                      }
                      return Container();
                    },
                  ),
                  FutureBuilder<Message>(
                    future: widget.chat.latestMessage,
                    builder: (BuildContext context, AsyncSnapshot snapshot) {
                      if (!(widget.chat.hasUnreadMessage ?? false)) return Container();
                      if (CurrentChat.forGuid(widget.chat.guid!)?.showTypingIndicator.value ?? false) return Container();
                      if (!snapshot.hasData) return Container();
                      Message message = snapshot.data;
                      if ([null, ""].contains(message.associatedMessageGuid) || (message.isFromMe ?? false)) {
                        return Container();
                      }
                      return Positioned(
                        top: -12,
                        right: -8,
                        child: ReactionsWidget(
                          associatedMessages: [message],
                          bigPin: true,
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 20,
                    width: maxWidth,
                    child: PinnedTileTextBubble(
                      chat: widget.chat,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

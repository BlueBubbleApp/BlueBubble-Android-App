import 'dart:io';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// When adding a new [DetailsMenuAction], make sure to add corresponding entries to
/// the [_actionPlatformSupport], [_actionToIcon], and [_actionToText] Maps
enum DetailsMenuAction {
  SelectMultiple,
  Reply,
  Save,
  OpenInBrowser,
  OpenInNewTab,
  CopyText,
  SaveOriginal,
  SaveLivePhoto,
  OpenDirectMessage,
  ViewThread,
  Share,
  ReDownloadFromServer,
  RemindLater,
  CreateContact,
  UndoSend,
  Edit,
  Forward,
  StartConversation,
  CopySelection,
  JumpToMessage,
  Delete,
  Bookmark,
  MessageInfo
}

class PlatformSupport {
  final bool android;
  final bool windows;
  final bool linux;
  final bool web;

  const PlatformSupport(this.android, this.windows, this.linux, this.web);
}

const Map<DetailsMenuAction, PlatformSupport> _actionPlatformSupport = {
  DetailsMenuAction.SelectMultiple: PlatformSupport(true, true, true, true),
  DetailsMenuAction.Reply: PlatformSupport(true, true, true, true),
  DetailsMenuAction.Save: PlatformSupport(true, true, true, true),
  DetailsMenuAction.OpenInBrowser: PlatformSupport(true, false, false, false),
  DetailsMenuAction.OpenInNewTab: PlatformSupport(false, false, false, true),
  DetailsMenuAction.CopyText: PlatformSupport(true, true, true, true),
  DetailsMenuAction.SaveOriginal: PlatformSupport(true, true, true, true),
  DetailsMenuAction.SaveLivePhoto: PlatformSupport(true, true, true, true),
  DetailsMenuAction.OpenDirectMessage: PlatformSupport(true, true, true, true),
  DetailsMenuAction.ViewThread: PlatformSupport(true, true, true, true),
  DetailsMenuAction.Share: PlatformSupport(true, false, false, false),
  DetailsMenuAction.ReDownloadFromServer: PlatformSupport(true, true, true, true),
  DetailsMenuAction.RemindLater: PlatformSupport(true, false, false, false),
  DetailsMenuAction.CreateContact: PlatformSupport(true, false, false, false),
  DetailsMenuAction.UndoSend: PlatformSupport(true, true, true, true),
  DetailsMenuAction.Edit: PlatformSupport(true, true, true, true),
  DetailsMenuAction.Forward: PlatformSupport(true, true, true, true),
  DetailsMenuAction.StartConversation: PlatformSupport(true, true, true, true),
  DetailsMenuAction.CopySelection: PlatformSupport(false, true, true, true),
  DetailsMenuAction.Delete: PlatformSupport(true, true, true, true),
  DetailsMenuAction.Bookmark: PlatformSupport(true, true, true, true),
  DetailsMenuAction.MessageInfo: PlatformSupport(true, true, true, true),
  DetailsMenuAction.JumpToMessage: PlatformSupport(true, true, true, true),
};

const Map<DetailsMenuAction, (IconData, IconData)> _actionToIcon = {
  DetailsMenuAction.SelectMultiple: (CupertinoIcons.checkmark_square, Icons.check_box_outlined),
  DetailsMenuAction.Reply: (CupertinoIcons.reply, Icons.reply),
  DetailsMenuAction.Save: (CupertinoIcons.cloud_download, Icons.file_download),
  DetailsMenuAction.OpenInBrowser: (CupertinoIcons.macwindow, Icons.open_in_browser),
  DetailsMenuAction.OpenInNewTab: (CupertinoIcons.macwindow, Icons.open_in_browser),
  DetailsMenuAction.CopyText: (CupertinoIcons.doc_on_clipboard, Icons.content_copy),
  DetailsMenuAction.SaveOriginal: (CupertinoIcons.cloud_download, Icons.file_download),
  DetailsMenuAction.SaveLivePhoto: (CupertinoIcons.photo, Icons.motion_photos_on_outlined),
  DetailsMenuAction.OpenDirectMessage: (CupertinoIcons.arrow_up_right_square, Icons.open_in_new),
  DetailsMenuAction.ViewThread: (CupertinoIcons.bubble_left_bubble_right, Icons.forum),
  DetailsMenuAction.Share: (CupertinoIcons.share, Icons.share),
  DetailsMenuAction.ReDownloadFromServer: (CupertinoIcons.refresh, Icons.refresh),
  DetailsMenuAction.RemindLater: (CupertinoIcons.alarm, Icons.alarm),
  DetailsMenuAction.CreateContact: (CupertinoIcons.person_crop_circle_badge_plus, Icons.contact_page_outlined),
  DetailsMenuAction.UndoSend: (CupertinoIcons.arrow_uturn_left, Icons.undo),
  DetailsMenuAction.Edit: (CupertinoIcons.pencil, Icons.edit_outlined),
  DetailsMenuAction.Forward: (CupertinoIcons.arrow_right, Icons.forward),
  DetailsMenuAction.StartConversation: (CupertinoIcons.chat_bubble, Icons.message),
  DetailsMenuAction.CopySelection: (CupertinoIcons.text_cursor, Icons.content_copy),
  DetailsMenuAction.Delete: (CupertinoIcons.trash, Icons.delete_outlined),
  DetailsMenuAction.Bookmark: (CupertinoIcons.bookmark, Icons.bookmark_outlined),
  DetailsMenuAction.MessageInfo: (CupertinoIcons.info, Icons.info),
  DetailsMenuAction.JumpToMessage: (CupertinoIcons.chat_bubble_text, Icons.message),
};

const Map<DetailsMenuAction, String> _actionToText = {
  DetailsMenuAction.SelectMultiple: "Select Multiple",
  DetailsMenuAction.Reply: "Reply",
  DetailsMenuAction.Save: "Save",
  DetailsMenuAction.OpenInBrowser: "Open In Browser",
  DetailsMenuAction.OpenInNewTab: "Open In New Tab",
  DetailsMenuAction.CopyText: "Copy",
  DetailsMenuAction.SaveOriginal: "Save Original",
  DetailsMenuAction.SaveLivePhoto: "Save Live Photo",
  DetailsMenuAction.OpenDirectMessage: "Open Direct Message",
  DetailsMenuAction.ViewThread: "View Thread",
  DetailsMenuAction.Share: "Share",
  DetailsMenuAction.ReDownloadFromServer: "Re-download From Server",
  DetailsMenuAction.RemindLater: "Remind Later",
  DetailsMenuAction.CreateContact: "Create Contact",
  DetailsMenuAction.UndoSend: "Undo Send",
  DetailsMenuAction.Edit: "Edit",
  DetailsMenuAction.Forward: "Forward",
  DetailsMenuAction.StartConversation: "Start Conversation",
  DetailsMenuAction.CopySelection: "Copy Selection",
  DetailsMenuAction.Delete: "Delete",
  DetailsMenuAction.Bookmark: "Add/Remove Bookmark",
  DetailsMenuAction.MessageInfo: "Message Info",
  DetailsMenuAction.JumpToMessage: "Jump To Message",
};

class _DetailsMenuActionUtils {
  static final List<DetailsMenuAction> _androidActions =
      DetailsMenuAction.values.where((action) => _actionPlatformSupport[action]!.android).toList();

  static final List<DetailsMenuAction> _windowsActions =
      DetailsMenuAction.values.where((action) => _actionPlatformSupport[action]!.windows).toList();

  static final List<DetailsMenuAction> _linuxActions =
      DetailsMenuAction.values.where((action) => _actionPlatformSupport[action]!.linux).toList();

  static final List<DetailsMenuAction> _webActions =
      DetailsMenuAction.values.where((action) => _actionPlatformSupport[action]!.web).toList();
}

extension DetailsMenuActionExtension on List<DetailsMenuAction> {
  List<DetailsMenuAction> get platformSupportedActions => (kIsWeb
      ? where((action) => _DetailsMenuActionUtils._webActions.contains(action))
      : Platform.isAndroid
          ? where((action) => _DetailsMenuActionUtils._androidActions.contains(action))
          : Platform.isWindows
              ? where((action) => _DetailsMenuActionUtils._windowsActions.contains(action))
              : where((action) => _DetailsMenuActionUtils._linuxActions.contains(action))).toList();
}

class CustomDetailsMenuActionWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final String title;
  final IconData iosIcon;
  final IconData nonIosIcon;
  final bool? shouldDisable;

  CustomDetailsMenuActionWidget({
    super.key,
    this.onTap,
    required this.title,
    required this.iosIcon,
    required this.nonIosIcon,
    this.shouldDisable,
  });

  @override
  Widget build(BuildContext context) {
    bool isDisabled = shouldDisable ?? false;
    Color color = isDisabled ? Colors.grey : context.theme.colorScheme.properOnSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        child: ListTile(
          mouseCursor: SystemMouseCursors.click,
          dense: !kIsDesktop && !kIsWeb,
          title: Text(
            title,
            style: context.theme.textTheme.bodyLarge!.copyWith(color: color),
          ),
          trailing: Icon(
            ss.settings.skin.value == Skins.iOS ? iosIcon : nonIosIcon,
            color: color,
          ),
        ),
      ),
    );
  }
}

class DetailsMenuActionWidget extends CustomDetailsMenuActionWidget {
  final DetailsMenuAction action;
  final String? customTitle;
  final bool? shouldDisableBtn;

  DetailsMenuActionWidget({
    super.key,
    super.onTap,
    this.customTitle,
    required this.action,
    this.shouldDisableBtn,
  }) : super(
            title: customTitle ?? _actionToText[action]!,
            iosIcon: _actionToIcon[action]!.$1,
            nonIosIcon: _actionToIcon[action]!.$2,
            shouldDisable: shouldDisableBtn);
}

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_details_popup.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';

class MessagePopupHolder extends StatelessWidget {
  final Widget child;
  final Widget popupChild;
  final Message message;
  final Message? olderMessage;
  final Message? newerMessage;
  final GlobalKey containerKey = GlobalKey();

  MessagePopupHolder({
    Key? key,
    required this.child,
    required this.popupChild,
    required this.message,
    required this.olderMessage,
    required this.newerMessage,
  }) : super(key: key);

  Tuple2<Offset, Size> getOffset(BuildContext context) {
    RenderBox renderBox = containerKey.currentContext!.findRenderObject() as RenderBox;
    Size size = renderBox.size;
    Offset offset = renderBox.localToGlobal(Offset.zero);
    bool increaseWidth = !MessageHelper.getShowTail(context, message, newerMessage)
        && (SettingsManager().settings.alwaysShowAvatars.value || (CurrentChat.of(context)?.chat.isGroup() ?? false));
    bool doNotIncreaseHeight = ((message.isFromMe ?? false)
        || !(CurrentChat.of(context)?.chat.isGroup() ?? false)
        || !sameSender(message, olderMessage)
        || !message.dateCreated!.isWithin(olderMessage!.dateCreated!, minutes: 30));
    return Tuple2(Offset(offset.dx - (increaseWidth ? 35 : 0),
        offset.dy - (doNotIncreaseHeight ? 0 : message.getReactions().length > 0 ? 20.0 : 23.0)),
        Size(size.width + (increaseWidth ? 35 : 0),
        size.height + (doNotIncreaseHeight ? 0 : message.getReactions().length > 0 ? 20.0 : 23.0)));
  }

  void openMessageDetails(BuildContext context) async {
    HapticFeedback.lightImpact();
    Tuple2<Offset, Size> data = getOffset(context);

    CurrentChat? currentChat = CurrentChat.of(context);

    await Navigator.push(
      context,
      PageRouteBuilder(
        settings: RouteSettings(arguments: {"hideTail": true}),
        transitionDuration: Duration(milliseconds: 150),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
              opacity: animation,
              child: MessageDetailsPopup(
                currentChat: currentChat,
                child: popupChild,
                childOffset: data.item1,
                childSize: data.item2,
                message: message,
              ));
        },
        fullscreenDialog: true,
        opaque: false,
      ),
    );
  }

  void sendReaction(String type, BuildContext context) {
    debugPrint("Sending reaction type: " + type);
    ActionHandler.sendReaction(CurrentChat.of(context)!.chat, message, type);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: containerKey,
      onDoubleTap: () => SettingsManager().settings.doubleTapForDetails.value && !message.guid!.startsWith('temp')
          ? this.openMessageDetails(context)
          : SettingsManager().settings.enableQuickTapback.value
              ? () {
                  HapticFeedback.lightImpact();
                  this.sendReaction(SettingsManager().settings.quickTapbackType.value, context);
                }
              : null,
      onLongPress: () => this.openMessageDetails(context),
      child: child,
    );
  }
}

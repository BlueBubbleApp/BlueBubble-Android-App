import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Widget buildBackButton(BuildContext context,
    {EdgeInsets padding = EdgeInsets.zero, double? iconSize, Skins? skin, Function()? callback}) {
  return Container(
    padding: padding,
    width: 25,
    child: IconButton(
      iconSize: iconSize ?? 24,
      icon: skin != null
          ? Icon(skin == Skins.iOS ? Icons.arrow_back_ios : Icons.arrow_back, color: Theme.of(context).primaryColor)
          : Obx(() => Icon(SettingsManager().settings.skin.value == Skins.iOS ? Icons.arrow_back_ios : Icons.arrow_back,
              color: Theme.of(context).primaryColor)),
      onPressed: () {
        callback?.call();
        Get.back(closeOverlays: true);
      },
    ),
  );
}

Widget buildProgressIndicator(BuildContext context, {double size = 20, double strokeWidth = 2}) {
  return SettingsManager().settings.skin.value == Skins.iOS
      ? Theme(
          data: ThemeData(
            cupertinoOverrideTheme:
                CupertinoThemeData(brightness: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor)),
          ),
          child: CupertinoActivityIndicator(
            radius: size / 2,
          ),
        )
      : Container(
          constraints: BoxConstraints(maxHeight: size, maxWidth: size),
          child: CircularProgressIndicator(
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ));
}

Widget buildImagePlaceholder(BuildContext context, Attachment attachment, Widget child, {bool isLoaded = false}) {
  double placeholderWidth = 200;
  double placeholderHeight = 150;

  // If the image doesn't have a valid size, show the loader with static height/width
  if (!attachment.hasValidSize) {
    return Container(
        width: placeholderWidth, height: placeholderHeight, color: Theme.of(context).accentColor, child: child);
  }

  // If we have a valid size, we want to calculate the aspect ratio so the image doesn't "jitter" when loading
  // Calculate the aspect ratio for the placeholders
  double ratio = AttachmentHelper.getAspectRatio(attachment.height, attachment.width, context: context);
  double height = attachment.height?.toDouble() ?? placeholderHeight;
  double width = attachment.width?.toDouble() ?? placeholderWidth;

  // YES, this countainer surrounding the AspectRatio is needed.
  // If not there, the box may be too large
  return Container(
      constraints: BoxConstraints(maxHeight: height, maxWidth: width),
      child: AspectRatio(
          aspectRatio: ratio,
          child: Container(width: width, height: height, color: Theme.of(context).accentColor, child: child)));
}

Widget addReactionsToWidget(
    {required Widget messageWidget, required Widget reactions, required Message? message, bool shouldShow = true}) {
  if (!shouldShow) return messageWidget;

  return Stack(
    alignment: message!.isFromMe! ? AlignmentDirectional.topStart : AlignmentDirectional.topEnd,
    children: [
      messageWidget,
      reactions,
    ],
  );
}

/// Adds reacts to a [message] widget
Widget addStickersToWidget({required Widget message, required Widget stickers, required bool isFromMe}) {
  return Stack(
    alignment: (isFromMe) ? AlignmentDirectional.bottomEnd : AlignmentDirectional.bottomStart,
    children: [
      message,
      stickers,
    ],
  );
}

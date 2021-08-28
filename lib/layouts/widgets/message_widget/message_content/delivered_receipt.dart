import 'package:bluebubbles/helpers/message_marker.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Placeholder class so we can get vsync support in the stateless widget
class DeliveredReceiptController extends GetxController with SingleGetTickerProviderMixin {}

class DeliveredReceipt extends StatelessWidget {
  DeliveredReceipt({
    Key? key,
    required this.message,
    required this.showDeliveredReceipt,
    required this.shouldAnimate,
  }) : super(key: key);
  final bool showDeliveredReceipt;
  final bool shouldAnimate;
  final Message message;
  final DeliveredReceiptController controller = DeliveredReceiptController();

  bool shouldShow(BuildContext context, Message? myLastMessage, Message? lastReadMessage, Message? lastDeliveredMessage) {
    // If we have no delivered date, don't show anything
    if (message.dateDelivered == null) return false;

    if (CurrentChat.of(context) != null) {
      if (lastReadMessage == null) lastReadMessage = CurrentChat.of(context)?.messageMarkers.lastReadMessage;
      if (lastDeliveredMessage == null)
        lastDeliveredMessage = CurrentChat.of(context)?.messageMarkers.lastDeliveredMessage;
      if (myLastMessage == null) myLastMessage = CurrentChat.of(context)?.messageMarkers.myLastMessage;
    }

    // If the message is the same as the last read message, we want to show it
    if (!showDeliveredReceipt &&
        message.dateRead != null &&
        lastReadMessage != null &&
        message.guid == lastReadMessage.guid) {
      return true;
    }

    // If the message is the same as the last delivered message, we want to show it
    if (!showDeliveredReceipt &&
        message.dateDelivered != null &&
        lastDeliveredMessage != null &&
        message.guid == lastDeliveredMessage.guid) {
      return true;
    }

    // This is logic so that we can have both a read receipt on an older message
    // As well as a delivered receipt on the newest message
    // if (!widget.showDeliveredReceipt! &&
    //     myLastMessage != null &&
    //     widget.message!.dateRead != null &&
    //     myLastMessage.dateRead == null &&
    //     lastReadMessage != null &&
    //     lastReadMessage.guid == widget.message!.guid &&
    //     lastDeliveredMessage != null &&
    //     lastDeliveredMessage.guid == widget.message!.guid) {
    //   return true;
    // }

    // If all else fails, return what our parent wants
    return showDeliveredReceipt;
  }

  String getText() {
    String text = "Delivered";
    if (message.dateRead != null) {
      text = "Read " + buildDate(message.dateRead);
    } else if (SettingsManager().settings.showDeliveryTimestamps.value && message.dateDelivered != null) {
      text = "Delivered " + buildDate(message.dateDelivered);
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    Widget timestampWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Obx(() {
        MessageMarkers? markers = CurrentChat.of(context)?.messageMarkers.markers.value ?? null.obs.value;
        if (shouldShow(context, markers?.myLastMessage, markers?.lastReadMessage, markers?.lastDeliveredMessage)) {
          return Text(
            getText(),
            style: Theme.of(context).textTheme.subtitle2,
          );
        } else {
          return Container();
        }
      }),
    );

    Widget item;
    if (shouldAnimate) {
      item = AnimatedSize(
          vsync: controller,
          curve: Curves.easeInOut,
          alignment: Alignment.bottomLeft,
          duration: Duration(milliseconds: 250),
          child: timestampWidget);
    } else {
      item = timestampWidget;
    }

    return Padding(
      padding: EdgeInsets.only(top: 2, bottom: 4),
      child: item,
    );
  }
}

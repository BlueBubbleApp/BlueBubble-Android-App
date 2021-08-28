import 'package:get/get.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';

Map<String, IconData> iconMap = {
  'com.apple.Handwriting.HandwritingProvider': Icons.brush,
  'com.apple.DigitalTouchBalloonProvider': Icons.touch_app
};

class BalloonBundleWidget extends StatelessWidget {
  BalloonBundleWidget({
    Key? key,
    required this.message,
  }) : super(key: key);
  final Message? message;

  IconData getIcon() {
    if (message!.balloonBundleId == null) return Icons.device_unknown;
    if (nameMap.containsKey(message!.balloonBundleId)) {
      return iconMap[message!.balloonBundleId!]!;
    }

    String val = message!.balloonBundleId!.toLowerCase();
    if (val.contains("gamepigeon")) {
      return Icons.games;
    } else if (val.contains("contextoptional")) {
      return Icons.phone_android;
    } else if (val.contains("mobileslideshow")) {
      return Icons.slideshow;
    } else if (val.contains("PeerPayment")) {
      return Icons.monetization_on;
    }

    return Icons.apps;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
          constraints: BoxConstraints(
            maxWidth: context.width * 3 / 4,
          ),
          child: Container(
            width: 200,
            color: Theme.of(context).accentColor,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(MessageHelper.getInteractiveText(message!),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headline1),
                  Text("Interactive Message",
                      textAlign: TextAlign.center, maxLines: 1, style: Theme.of(context).textTheme.subtitle1),
                  Container(height: 10.0),
                  Icon(getIcon(), color: Theme.of(context).textTheme.bodyText1!.color, size: 48),
                  Container(height: 10.0),
                  Text("(Cannot open on Android)",
                      textAlign: TextAlign.center, maxLines: 1, style: Theme.of(context).textTheme.subtitle2),
                ],
              ),
            ),
          )),
    );
  }
}

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';

enum ItemTypes {
  participantAdded,
  participantRemoved,
  nameChanged,
  participantLeft,
}

class GroupEvent extends StatelessWidget {
  const GroupEvent({
    Key? key,
    required this.message,
  }) : super(key: key);
  final Message? message;

  @override
  Widget build(BuildContext context) {
    List<Widget> extras = [];
    // if (text == 'Unknown group event') {
    //   extras.addAll([
    //     Text(
    //       "ACTUAL TEXT: '${widget.message.fullText}'",
    //       style: Theme.of(context).textTheme.subtitle2.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "IS EMPTY: ${isEmptyString(widget.message.fullText)}",
    //       style: Theme.of(context).textTheme.subtitle2.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "IS EMPTY (WITH STRIP): ${isEmptyString(widget.message.fullText, stripWhitespace: true)}",
    //       style: Theme.of(context).textTheme.subtitle2.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "BALLOON BUNDLE ID: ${widget.message.balloonBundleId ?? "NULL"}",
    //       style: Theme.of(context).textTheme.subtitle2.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "HAS ATTACHMENTS: ${widget.message.hasAttachments}",
    //       style: Theme.of(context).textTheme.subtitle2.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "ATTACHMENTS LENGTH: ${widget.message.attachments.length}",
    //       style: Theme.of(context).textTheme.subtitle2.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "HAS DD RESULTS: ${widget.message.hasDdResults}",
    //       style: Theme.of(context).textTheme.subtitle2.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "METADATA: ${widget.message.metadata.toString()}",
    //       style: Theme.of(context).textTheme.subtitle2.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //     Text(
    //       "SUBJECT: ${widget.message.subject}",
    //       style: Theme.of(context).textTheme.subtitle2.apply(color: Colors.red),
    //       overflow: TextOverflow.ellipsis,
    //       maxLines: 2,
    //       textAlign: TextAlign.center,
    //     ),
    //   ]);
    // }

    return Flex(direction: Axis.horizontal, children: [
      Flexible(
        fit: FlexFit.tight,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FutureBuilder<String>(
                future: getGroupEventText(message!),
                  builder: (context, snapshot) => Text(
                    snapshot.data ?? "",
                    style: Theme.of(context).textTheme.subtitle2,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
                ...extras
              ],
            )),
      ),
    ]);
  }
}

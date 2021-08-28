import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class ReactionsWidget extends StatefulWidget {
  ReactionsWidget({
    Key? key,
    required this.associatedMessages,
    this.bigPin = false,
  }) : super(key: key);
  final List<Message> associatedMessages;
  final bool bigPin;

  @override
  _ReactionsWidgetState createState() => _ReactionsWidgetState();
}

class _ReactionsWidgetState extends State<ReactionsWidget> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    // Filter associated messages down to just the sticker
    List<Message> reactions =
        widget.associatedMessages.where((item) => ReactionTypes.toList().contains(item.associatedMessageType)).toList();

    final bool hideReactions =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideReactions.value;

    // If the reactions are empty, return nothing
    if (reactions.isEmpty || hideReactions) {
      return Container();
    }

    // Filter down the reactions by the newest for each user
    final reactionsMap = Reaction.getLatestReactionMap(reactions);

    reactionsMap.removeWhere((key, value) => value.getSmallWidget(context, bigPin: widget.bigPin) == null);

    // Build the widget list from the map
    final reactionWidgets = reactionsMap.values.mapIndexed((int index, Reaction item) => Padding(
      padding: EdgeInsets.fromLTRB(
        index.toDouble() * 15.0,
        1.0,
        0,
        0,
      ),
      child: item.getSmallWidget(
        context,
        bigPin: widget.bigPin,
      ),
    )).toList();

    // Build the actual reaction bubbles
    return AnimatedSize(
      duration: Duration(milliseconds: 200),
      reverseDuration: Duration(milliseconds: 200),
      vsync: this,
      curve: Curves.bounceInOut,
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        fit: StackFit.passthrough,
        alignment: Alignment.bottomLeft,
        children: reactionWidgets,
      ),
    );
  }
}

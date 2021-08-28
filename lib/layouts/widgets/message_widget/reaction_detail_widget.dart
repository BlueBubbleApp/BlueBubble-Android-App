import 'package:bluebubbles/helpers/redacted_helper.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ReactionDetailWidget extends StatefulWidget {
  ReactionDetailWidget({
    Key? key,
    required this.handle,
    required this.message,
  }) : super(key: key);
  final Handle? handle;
  final Message message;

  @override
  _ReactionDetailWidgetState createState() => _ReactionDetailWidgetState();
}

class _ReactionDetailWidgetState extends State<ReactionDetailWidget> {
  String? contactTitle;

  @override
  void initState() {
    super.initState();

    contactTitle = widget.message.isFromMe! ? "You" : widget.handle!.address;
    if (widget.message.isFromMe! || widget.handle == null) return;

    ContactManager().getContactTitle(widget.handle).then((String? title) {
      if (title != contactTitle) {
        contactTitle = title;
        if (this.mounted) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool hide = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideReactions.value;
    if (hide) return Container();

    Color iconColor = Colors.white;
    if (Theme.of(context).accentColor.computeLuminance() >= 0.179) {
      iconColor = Colors.black.withAlpha(95);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
          child: ContactAvatarWidget(
            handle: widget.message.isFromMe! ? null : widget.handle,
            borderThickness: 0.1,
            editable: false,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            getContactName(context, contactTitle, widget.handle?.address),
            style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeDelta: -5),
          ),
        ),
        Container(
          height: 28,
          width: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: Theme.of(context).accentColor,
            boxShadow: [
              new BoxShadow(
                blurRadius: 1.0,
                color: Colors.black,
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 7.0, right: 7.0, bottom: 7.0),
            child: SvgPicture.asset(
              'assets/reactions/${widget.message.associatedMessageType}-black.svg',
              color: widget.message.associatedMessageType == "love" ? Colors.pink : iconColor,
            ),
          ),
        )
      ],
    );
  }
}

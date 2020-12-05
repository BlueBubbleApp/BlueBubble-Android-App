import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';

class PrepareToDownload extends StatefulWidget {
  PrepareToDownload({Key key, @required this.controller}) : super(key: key);
  final PageController controller;

  @override
  _PrepareToDownloadState createState() => _PrepareToDownloadState();
}

class _PrepareToDownloadState extends State<PrepareToDownload> {
  double numberOfMessages = 25;
  bool downloadAttachments = false;
  bool skipEmptyChats = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).accentColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "For the final step, BlueBubbles will download the first 25 messages for each of your chats.",
                style: Theme.of(context)
                    .textTheme
                    .bodyText1
                    .apply(fontSizeFactor: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            Container(height: 10.0),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "Don't worry, you can see your chat history by scrolling up in a chat.",
                style: Theme.of(context)
                    .textTheme
                    .bodyText1
                    .apply(fontSizeFactor: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            Container(height: 50.0),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "Number of Messages to Sync Per Chat: $numberOfMessages",
                style: Theme.of(context).textTheme.bodyText1,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Slider(
                value: numberOfMessages,
                onChanged: (double value) {
                  if (!this.mounted) return;

                  setState(() {
                    numberOfMessages = value == 0 ? 1 : value;
                  });
                },
                label: numberOfMessages == 0 ? "1" : numberOfMessages.toString(),
                divisions: 50,
                min: 0,
                max: 250,
              ),
            ),
            Container(height: 20.0),
            // Padding(
            //   padding: EdgeInsets.symmetric(horizontal: 40.0),
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //     mainAxisSize: MainAxisSize.max,
            //     children: [
            //       Text(
            //         "Download Attachments (long sync)",
            //         style: Theme.of(context).textTheme.bodyText1,
            //         textAlign: TextAlign.center,
            //       ),
            //       Switch(
            //         value: downloadAttachments,
            //         activeColor: Theme.of(context).primaryColor,
            //         activeTrackColor:
            //             Theme.of(context).primaryColor.withAlpha(200),
            //         inactiveTrackColor:
            //             Theme.of(context).primaryColor.withAlpha(75),
            //         inactiveThumbColor:
            //             Theme.of(context).textTheme.bodyText1.color,
            //         onChanged: (bool value) {
            //           if (!this.mounted) return;

            //           setState(() {
            //             downloadAttachments = value;
            //           });
            //         },
            //       )
            //     ],
            //   ),
            // ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    "Skip empty chats",
                    style: Theme.of(context).textTheme.bodyText1,
                    textAlign: TextAlign.center,
                  ),
                  Switch(
                    value: skipEmptyChats,
                    activeColor: Theme.of(context).primaryColor,
                    activeTrackColor:
                        Theme.of(context).primaryColor.withAlpha(200),
                    inactiveTrackColor:
                        Theme.of(context).primaryColor.withAlpha(75),
                    inactiveThumbColor:
                        Theme.of(context).textTheme.bodyText1.color,
                    onChanged: (bool value) {
                      if (!this.mounted) return;

                      setState(() {
                        skipEmptyChats = value;
                      });
                    },
                  )
                ],
              ),
            ),
            Container(height: 20.0),
            ClipOval(
              child: Material(
                color: Colors.green.withAlpha(200), // button color
                child: InkWell(
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Icon(
                      Icons.cloud_download,
                      color: Colors.white,
                    ),
                  ),
                  onTap: () async {
                    // Set the number of messages to sync
                    SocketManager().setup.numberOfMessagesPerPage =
                        numberOfMessages;
                    SocketManager().setup.downloadAttachments =
                        downloadAttachments;
                    SocketManager().setup.skipEmptyChats = skipEmptyChats;

                    // Start syncing
                    SocketManager().setup.startSync(
                          SettingsManager().settings,
                        );
                    widget.controller.nextPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

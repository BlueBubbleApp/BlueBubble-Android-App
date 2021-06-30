import 'package:bluebubbles/layouts/setup/connecting_alert/failed_to_connect_dialog.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';

class ConnectingAlert extends StatefulWidget {
  ConnectingAlert({Key key, @required this.onConnect}) : super(key: key);
  final Function(bool) onConnect;

  @override
  _ConnectingAlertState createState() => _ConnectingAlertState();
}

class _ConnectingAlertState extends State<ConnectingAlert> {
  @override
  void initState() {
    super.initState();

    // If we are already connected, continue
    if (SocketManager().state == SocketState.CONNECTED) {
      widget.onConnect(true);
      return;
    }

    // Setup a listener to wait for connect events
    SocketManager().connectionStateStream.listen((event) {
      if (!this.mounted) return;
      debugPrint("Connection Status Changed");
      if (event == SocketState.CONNECTED) {
        widget.onConnect(true);
      } else if (event == SocketState.ERROR || event == SocketState.DISCONNECTED) {
        widget.onConnect(false);
      }

      if (this.mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (SocketManager().state == SocketState.FAILED) {
      return FailedToConnectDialog(
        onDismiss: () => Navigator.of(context).pop(),
      );
    } else {
      return WillPopScope(
        onWillPop: () async {
          return false;
        },
        child: AlertDialog(
          title: Text("Connecting..."),
          content: LinearProgressIndicator(
            backgroundColor: Colors.grey,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
        ),
      );
    }
  }
}

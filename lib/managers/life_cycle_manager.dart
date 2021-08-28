import 'dart:async';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:get/get.dart';

/// [LifeCycleManager] is responsible for keeping track of when the app is open and when it is closed
///
/// It helps with managing the [SocketManager] socket by closing it and opening it when the app is closed and when it isn't
/// This class is a singleton
class LifeCycleManager extends GetxService {

  static LifeCycleManager get instance => Get.find<LifeCycleManager>();

  /// Private variable for whether the app is closed or open
  bool _isAlive = false;

  bool get isAlive => _isAlive;

  StreamController<bool> _stream = new StreamController.broadcast();
  Stream<bool> get stream => _stream.stream;

  @override
  void onInit() {
    SocketManager().socketProcessUpdater.listen((event) {
      // If there are no more socket processes, then we can safely close the socket
      if (event.isEmpty && !_isAlive) {
        SocketManager().closeSocket();
      }
    });
    super.onInit();
  }

  @override
  void onClose() {
    _stream.close();
    super.onClose();
  }

  /// Public method called from [Home] when the app is opened or resumed
  void opened() {
    // If the app is not alive (was previously closed) and the curent chat is not null (a chat is already open)
    // Then mark the current chat as read.
    if (!_isAlive && CurrentChat.activeChat != null) {
      NotificationManager().switchChat(CurrentChat.activeChat!.chat);
    }

    // Set the app as open and start the socket
    updateStatus(true);
    SocketManager().startSocketIO();

    // Refresh all the chats assuming that the app has already finished setup
    if (SettingsManager().settings.finishedSetup.value) {
      ChatBloc().refreshChats();
    }
  }

  /// Public method called from [Home] when the app is closed or paused
  void close() {
    if (SettingsManager().settings.finishedSetup.value) {
      // Close the socket and set the isAlive to false
      //
      // NOTE: [closeSocket] does not necessarily close the socket, it simply requests the SocketManager to attempt to do so
      // If there are socket processes using the socket, then it will not close, and will wait until those tasks are done
      updateStatus(false);
      SocketManager().closeSocket();

      // Closes the backgroun thread when the app is fully closed
      // This does not necessarily mean that the isolate will be closed (such as if the app is not fully closed), but it will attempt to do so
      MethodChannelInterface().closeThread();
    }
  }

  /// Helper method to update the alive status and send the new status to the stream
  void updateStatus(bool newStatus) {
    // We don't want to send things to the stream unless they are new
    if (_isAlive != newStatus) {
      _isAlive = newStatus;
      _stream.sink.add(_isAlive);
    }
  }
}

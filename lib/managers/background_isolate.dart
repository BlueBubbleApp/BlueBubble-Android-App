import 'dart:ui';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

abstract class BackgroundIsolateInterface {
  static void initialize() {
    // get callback handle for the callback function
    CallbackHandle callbackHandle =
        PluginUtilities.getCallbackHandle(callbackHandler)!;
    // pass the handle down to Java
    MethodChannelInterface().invokeMethod("initialize-background-handle",
        {"handle": callbackHandle.toRawHandle()});
  }
}

/// This function is called from Java when the [FlutterEngine] is null
void callbackHandler() async {
  debugPrint("(ISOLATE) Starting up...");
  // we initialize the [MethodChannel] to receive new messages from Java
  MethodChannel _backgroundChannel = MethodChannel("com.bluebubbles.messaging");
  WidgetsFlutterBinding.ensureInitialized();
  // don't run this if the app is active to avoid double-initializing our managers
  if (!Get.isRegistered<LifeCycleManager>() || !LifeCycleManager.instance.isAlive) {
    await DBProvider.db.initDB();
    await SettingsManager().init();
    await SettingsManager().getSavedSettings();
    Get.put(AttachmentDownloadService());
    Get.put(Logger());
    Get.put(EventDispatcher());
    Get.put(LifeCycleManager());
    await ContactManager().getContacts(headless: true);
    MethodChannelInterface().init(customChannel: _backgroundChannel);
    await SocketManager().refreshConnection(connectToSocket: false);
  }
}

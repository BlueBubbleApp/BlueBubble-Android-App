import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class Logger extends GetxService {
  late bool shouldPrint;
  Logger({this.shouldPrint = kDebugMode});

  static Logger get instance => Get.find<Logger>();

  void log(String log, {String title = "[BlueBubblesApp]"}) {
    if (shouldPrint) {
      debugPrint(title + " " + log);
    }
  }
}
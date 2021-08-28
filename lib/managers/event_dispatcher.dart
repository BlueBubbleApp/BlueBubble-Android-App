import 'dart:async';

import 'package:get/get.dart';


class EventDispatcher extends GetxService {

  static EventDispatcher get instance => Get.find<EventDispatcher>();

  StreamController<Map<String, dynamic>> _stream = new StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _stream.stream;

  @override
  void onClose() {
    _stream.close();
    super.onClose();
  }

  void emit(String type, dynamic data) {
    _stream.sink.add({
      "type": type,
      "data": data
    });
  }
}

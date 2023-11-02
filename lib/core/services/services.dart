import 'package:bluebubbles/core/abstractions/network/network_service.dart';
import 'package:bluebubbles/core/abstractions/storage/database_service.dart';
import 'package:bluebubbles/core/abstractions/device_service.dart';
import 'package:bluebubbles/core/abstractions/server_service.dart';
import 'package:bluebubbles/core/abstractions/storage/settings_service.dart';
import 'package:bluebubbles/core/abstractions/storage/shared_preference_service.dart';
import 'package:bluebubbles/core/abstractions/update_service.dart';
import 'package:bluebubbles/core/services/github_update_service.dart';
import 'package:bluebubbles/core/services/default/default_device_service.dart';
import 'package:bluebubbles/core/services/default/default_server_service.dart';
import 'package:bluebubbles/core/services/default/default_settings_service.dart';
import 'package:bluebubbles/core/services/network/dio/dio_network_service.dart';
import 'package:bluebubbles/core/services/objectbox_database_service.dart';
import 'package:bluebubbles/core/services/default/default_shared_prefs_service.dart';
import 'package:get/get.dart';

NetworkService network = Get.isRegistered<DioNetworkService>() ? Get.find<DioNetworkService>() : Get.put(DioNetworkService());
DatabaseService db = Get.isRegistered<ObjectBoxDatabaseService>() ? Get.find<ObjectBoxDatabaseService>() : Get.put(ObjectBoxDatabaseService());
SettingsService settings = Get.isRegistered<DefaultSettingsService>() ? Get.find<DefaultSettingsService>() : Get.put(DefaultSettingsService());
SharedPreferenceService prefs = Get.isRegistered<DefaultSharedPrefsService>() ? Get.find<DefaultSharedPrefsService>() : Get.put(DefaultSharedPrefsService());
ServerService server = Get.isRegistered<DefaultServerService>() ? Get.find<DefaultServerService>() : Get.put(DefaultServerService());
DeviceService device = Get.isRegistered<DefaultDeviceService>() ? Get.find<DefaultDeviceService>() : Get.put(DefaultDeviceService());
UpdateService updateService = Get.isRegistered<GithubUpdateService>() ? Get.find<GithubUpdateService>() : Get.put(GithubUpdateService());
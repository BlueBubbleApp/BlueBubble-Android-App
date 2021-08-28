import 'dart:async';

import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/config_entry.dart';
import 'package:sqflite/sqflite.dart';

class FCMData {
  dynamic projectID;
  dynamic storageBucket;
  dynamic apiKey;
  dynamic firebaseURL;
  dynamic clientID;
  dynamic applicationID;

  FCMData({
    this.projectID,
    this.storageBucket,
    this.apiKey,
    this.firebaseURL,
    this.clientID,
    this.applicationID,
  });

  factory FCMData.fromMap(Map<String, dynamic> json) {
    Map<String, dynamic> projectInfo = json["project_info"];
    Map<String, dynamic> client = json["client"][0];
    String clientID = client["oauth_client"][0]["client_id"];
    return FCMData(
      projectID: projectInfo["project_id"],
      storageBucket: projectInfo["storage_bucket"],
      apiKey: client["api_key"][0]["current_key"],
      firebaseURL: projectInfo["firebase_url"],
      clientID: clientID.contains("-") ? clientID.substring(0, clientID.indexOf("-")) : clientID,
      applicationID: client["client_info"]["mobilesdk_app_id"],
    );
  }

  factory FCMData.fromConfigEntries(List<ConfigEntry> entries) {
    FCMData data = new FCMData();
    for (ConfigEntry entry in entries) {
      if (entry.name == "projectID") {
        data.projectID = entry.value;
      } else if (entry.name == "storageBucket") {
        data.storageBucket = entry.value;
      } else if (entry.name == "apiKey") {
        data.apiKey = entry.value;
      } else if (entry.name == "firebaseURL") {
        data.firebaseURL = entry.value;
      } else if (entry.name == "clientID") {
        data.clientID = entry.value;
      } else if (entry.name == "applicationID") {
        data.applicationID = entry.value;
      }
    }
    return data;
  }

  Future<FCMData> save({Database? database}) async {
    List<ConfigEntry> entries = this.toEntries();
    for (ConfigEntry entry in entries) {
      await entry.save("fcm", database: database);
    }
    return this;
  }

  static Future<FCMData> getFCM() async {
    Database? db = await DBProvider.db.database;

    List<Map<String, dynamic>> result = await db.query("fcm");
    if (result.isEmpty) return new FCMData();
    List<ConfigEntry> entries = [];
    for (Map<String, dynamic> setting in result) {
      entries.add(ConfigEntry.fromMap(setting));
    }
    return FCMData.fromConfigEntries(entries);
  }

  Map<String, dynamic> toMap() => {
        "project_id": this.projectID,
        "storage_bucket": this.storageBucket,
        "api_key": this.apiKey,
        "firebase_url": this.firebaseURL,
        "client_id": this.clientID,
        "application_id": this.applicationID,
      };

  List<ConfigEntry> toEntries() => [
        ConfigEntry(name: "projectID", value: this.projectID, type: this.projectID.runtimeType),
        ConfigEntry(name: "storageBucket", value: this.storageBucket, type: this.storageBucket.runtimeType),
        ConfigEntry(name: "apiKey", value: this.apiKey, type: this.apiKey.runtimeType),
        ConfigEntry(name: "firebaseURL", value: this.firebaseURL, type: this.firebaseURL.runtimeType),
        ConfigEntry(name: "clientID", value: this.clientID, type: this.clientID.runtimeType),
        ConfigEntry(name: "applicationID", value: this.applicationID, type: this.applicationID.runtimeType),
      ];

  bool get isNull =>
      this.projectID == null ||
      this.storageBucket == null ||
      this.apiKey == null ||
      this.firebaseURL == null ||
      this.clientID == null ||
      this.applicationID == null;
}

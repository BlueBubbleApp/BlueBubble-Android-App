import 'package:bluebubbles/core/services/services.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:flutter/foundation.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class FCMData {
  int? id;
  String? projectID;
  String? storageBucket;
  String? apiKey;
  String? firebaseURL;
  String? clientID;
  String? applicationID;

  FCMData({
    this.id,
    this.projectID,
    this.storageBucket,
    this.apiKey,
    this.firebaseURL,
    this.clientID,
    this.applicationID,
  });

  factory FCMData.fromCredentials(Map<String, dynamic> json) {
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

  FCMData save() {
    if (kIsWeb) return this;
    List<FCMData> data = db.fcm.getAll();
    if (data.length > 1) data.removeRange(1, data.length); // These were being ignored anyway
    id = !db.fcm.isEmpty() ? data.first.id : null;
    db.fcm.put(this);
    Future(() async {
      if (projectID != null) {
        await ss.prefs.setString('projectID', projectID!);
      } else {
        await ss.prefs.remove('projectID');
      }
      if (storageBucket != null) {
        await ss.prefs.setString('storageBucket', storageBucket!);
      } else {
        await ss.prefs.remove('storageBucket');
      }
      if (apiKey != null) {
        await ss.prefs.setString('apiKey', apiKey!);
      } else {
        await ss.prefs.remove('apiKey');
      }
      if (firebaseURL != null) {
        await ss.prefs.setString('firebaseURL', firebaseURL!);
      } else {
        await ss.prefs.remove('firebaseURL');
      }
      if (clientID != null) {
        await ss.prefs.setString('clientID', clientID!);
      } else {
        await ss.prefs.remove('clientID');
      }
      if (applicationID != null) {
        await ss.prefs.setString('applicationID', applicationID!);
      } else {
        await ss.prefs.remove('applicationID');
      }
    });
    ss.fcmData = this;
    return this;
  }

  clear() {
    id = null;
    projectID = null;
    storageBucket = null;
    apiKey = null;
    firebaseURL = null;
    clientID = null;
    applicationID = null;
  }

  static void deleteFcmData() async {
    db.fcm.removeAll();
    await prefs.config.remove('projectID');
    await prefs.config.remove('storageBucket');
    await prefs.config.remove('apiKey');
    await prefs.config.remove('firebaseURL');
    await prefs.config.remove('clientID');
    await prefs.config.remove('applicationID');
    ss.fcmData = FCMData();
  }

  static FCMData getFCM() {
    final result = db.fcm.getAll();
    if (result.isEmpty) {
      return FCMData(
        projectID: prefs.config.getString('projectID'),
        storageBucket: prefs.config.getString('storageBucket'),
        apiKey: prefs.config.getString('apiKey'),
        firebaseURL: prefs.config.getString('firebaseURL'),
        clientID: prefs.config.getString('clientID'),
        applicationID: prefs.config.getString('applicationID'),
      );
    }
    return result.first;
  }

  Map<String, dynamic> toMap() => {
    "project_id": projectID,
    "storage_bucket": storageBucket,
    "api_key": apiKey,
    "firebase_url": firebaseURL,
    "client_id": clientID,
    "application_id": applicationID,
  };

  bool get isNull =>
      projectID == null ||
      storageBucket == null ||
      apiKey == null ||
      clientID == null ||
      applicationID == null;
}

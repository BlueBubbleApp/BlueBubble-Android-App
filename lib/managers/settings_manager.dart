import 'dart:async';
import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/fcm_data.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/repository/models/theme_object.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';

/// [SettingsManager] is responsible for making the current settings accessible to other managers and for saving new settings
///
/// The class also holds miscelaneous stuff such as the [appDocDir] which is used a lot throughout the app
/// This class is a singleton
class SettingsManager {
  factory SettingsManager() {
    return _manager;
  }

  static final SettingsManager _manager = SettingsManager._internal();

  SettingsManager._internal();

  /// [appDocDir] is just a directory that is commonly used
  /// It cannot be accessed by the user, and is private to the app
  late Directory appDocDir;

  /// [sharedFilesPath] is the path where most temporary files like those inserted from the keyboard or shared to the app are stored
  /// The getter simply is a helper to that path
  String get sharedFilesPath => "${appDocDir.path}/sharedFiles";

  /// [settings] is just an instance of the current settings that are saved
  late Settings settings;
  FCMData? fcmData;
  late List<ThemeObject> themes;
  String? countryCode;
  int? _macOSVersion;
  bool canAuthenticate = false;

  int get compressionQuality {
    if (settings.lowMemoryMode.value) {
      return 10;
    }

    return SettingsManager().settings.previewCompressionQuality.value;
  }

  /// [init] is run at start and fetches both the [appDocDir] and sets the [settings] to a default value
  Future<void> init() async {
    settings = new Settings();
    appDocDir = await getApplicationSupportDirectory();
    canAuthenticate = await LocalAuthentication().isDeviceSupported();
  }

  /// Retreives files from disk and stores them in [settings]
  ///
  ///
  /// @param [headless] determines whether the socket will be started automatically and fcm will be initialized.
  ///
  /// @param [context] is an optional parameter to be used for setting the adaptive theme based on the settings.
  /// Setting to null will prevent the theme from being set and will be set to null in the background isolate
  Future<void> getSavedSettings({BuildContext? context}) async {
    await DBProvider.setupConfigRows();
    settings = await Settings.getSettings();

    fcmData = await FCMData.getFCM();
    // await DBProvider.setupDefaultPresetThemes(await DBProvider.db.database);
    themes = await ThemeObject.getThemes();
    for (ThemeObject theme in themes) {
      await theme.fetchData();
    }

    // // If [context] is null, then we can't set the theme, and we shouldn't anyway
    if (context != null) {
      await loadTheme(context);
    }

    try {
      // Set the [displayMode] to that saved in settings
      FlutterDisplayMode.setPreferredMode(await settings.getDisplayMode());
    } catch (e) {}

    // Change the [finishedSetup] status to that of the settings
    if (!settings.finishedSetup.value) {
      await DBProvider.deleteDB();
    }
    SocketManager().finishedSetup.sink.add(settings.finishedSetup.value);
  }

  /// Saves a [Settings] instance to disk
  ///
  /// @param [newSettings] are the settings to save
  Future<void> saveSettings(Settings newSettings) async {
    // Set the new settings as the current settings in the manager
    settings = newSettings;
    await settings.save();
  }

  /// Updates the selected theme for the app
  ///
  /// @param [selectedLightTheme] is the [ThemeObject] of the light theme to save and set as light theme in the db
  ///
  /// @param [selectedDarkTheme] is the [ThemeObject] of the dark theme to save and set as dark theme in the db
  ///
  /// @param [context] is the [BuildContext] used to set the theme of the new settings
  Future<void> saveSelectedTheme(
    BuildContext context, {
    ThemeObject? selectedLightTheme,
    ThemeObject? selectedDarkTheme,
  }) async {
    selectedLightTheme?.save();
    selectedDarkTheme?.save();
    ThemeObject.setSelectedTheme(light: selectedLightTheme?.id ?? null, dark: selectedDarkTheme?.id ?? null);

    ThemeData lightTheme = (selectedLightTheme ?? (await ThemeObject.getLightTheme())).themeData;
    ThemeData darkTheme = (selectedDarkTheme ?? (await ThemeObject.getDarkTheme())).themeData;
    AdaptiveTheme.of(context).setTheme(
      light: lightTheme,
      dark: darkTheme,
      isDefault: true,
    );
  }

  /// Updates FCM data and saves to disk. It will also run [authFCM] automatically
  ///
  /// @param [data] is the [FCMData] to save
  Future<void> saveFCMData(FCMData data) async {
    fcmData = data;
    await fcmData!.save();
    SocketManager().authFCM();
  }

  Future<void> resetConnection() async {
    if (SocketManager().socket != null && SocketManager().socket!.connected) {
      SocketManager().socket!.disconnect();
    }

    Settings temp = this.settings;
    temp.finishedSetup.value = false;
    temp.guidAuthKey.value = "";
    temp.serverAddress.value = "";
    temp.lastIncrementalSync.value = 0;
    await this.saveSettings(temp);
  }

  FutureOr<int?> getMacOSVersion() async {
    if (_macOSVersion == null) {
      var res = await SocketManager().sendMessage("get-server-metadata", {}, (_) {});
      _macOSVersion = int.tryParse(res['data']['os_version'].split(".")[0]);
    }
    return _macOSVersion;
  }
}

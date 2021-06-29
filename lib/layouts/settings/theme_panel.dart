import 'dart:async';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/layouts/settings/custom_avatar_panel.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/theming/theming_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';

class ThemePanel extends StatefulWidget {
  ThemePanel({Key key}) : super(key: key);

  @override
  _ThemePanelState createState() => _ThemePanelState();
}

class _ThemePanelState extends State<ThemePanel> {
  Settings _settingsCopy;
  List<DisplayMode> modes;
  DisplayMode currentMode;

  @override
  void initState() {
    super.initState();
    _settingsCopy = SettingsManager().settings;

    // Listen for any incoming events
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'theme-update' && this.mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    modes = await FlutterDisplayMode.supported;
    currentMode = await _settingsCopy.getDisplayMode();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(systemNavigationBarColor: Theme.of(context).backgroundColor),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: PreferredSize(
          preferredSize: Size(Get.mediaQuery.size.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(SettingsManager().settings.skin == Skins.IOS ? Icons.arrow_back_ios : Icons.arrow_back,
                      color: Theme.of(context).primaryColor),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
                title: Text(
                  "Theming & Styles",
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: CustomScrollView(
          physics: ThemeSwitcher.getScrollPhysics(),
          slivers: <Widget>[
            SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[
                  Container(padding: EdgeInsets.only(top: 5.0)),
                  SettingsOptions<AdaptiveThemeMode>(
                    initial: AdaptiveTheme.of(context).mode,
                    onChanged: (val) {
                      AdaptiveTheme.of(context).setThemeMode(val);

                      // This needs to be on a delay so the background color has time to change
                      Timer(Duration(seconds: 1), () => EventDispatcher().emit('theme-update', null));
                    },
                    options: AdaptiveThemeMode.values,
                    textProcessing: (dynamic val) => val.toString().split(".").last,
                    title: "App Theme",
                    showDivider: false,
                  ),
                  SettingsTile(
                    title: "Theming",
                    trailing: Icon(
                        SettingsManager().settings.skin == Skins.IOS ? Icons.arrow_forward_ios : Icons.arrow_forward,
                        color: Theme.of(context).primaryColor),
                    onTap: () async {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => ThemingPanel(),
                        ),
                      );
                    },
                  ),
                  SettingsOptions<Skins>(
                    initial: _settingsCopy.skin,
                    onChanged: (val) {
                      _settingsCopy.skin = val;
                      if (val == Skins.Material) {
                        _settingsCopy.hideDividers = true;
                      } else if (val == Skins.Samsung) {
                        _settingsCopy.hideDividers = true;
                      } else {
                        _settingsCopy.hideDividers = false;
                      }
                      ChatBloc().refreshChats();
                      setState(() {});
                    },
                    options: Skins.values.where((item) => item != Skins.Samsung).toList(),
                    textProcessing: (dynamic val) => val.toString().split(".").last,
                    title: "App Skin",
                    showDivider: false,
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.colorfulAvatars = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.colorfulAvatars,
                    title: "Colorful Avatars",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.colorfulBubbles = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.colorfulBubbles,
                    title: "Colorful Bubbles",
                  ),
                  SettingsTile(
                    title: "Custom Avatar Colors",
                    trailing: Icon(
                        SettingsManager().settings.skin == Skins.IOS ? Icons.arrow_forward_ios : Icons.arrow_forward,
                        color: Theme.of(context).primaryColor),
                    onTap: () async {
                      Get.toNamed("/settings/custom-avatar-panel");
                    },
                  ),
                  if (SettingsManager().settings.skin != Skins.Samsung)
                    SettingsSwitch(
                      onChanged: (bool val) {
                        _settingsCopy.hideDividers = val;
                        saveSettings();
                      },
                      initialVal: _settingsCopy.hideDividers,
                      title: "Hide Dividers",
                    ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.denseChatTiles = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.denseChatTiles,
                    title: "Dense Conversation Tiles",
                  ),
                  if (SettingsManager().settings.skin == Skins.IOS)
                    SettingsSwitch(
                      onChanged: (bool val) {
                        _settingsCopy.reducedForehead = val;
                        saveSettings();
                      },
                      initialVal: _settingsCopy.reducedForehead,
                      title: "Reduced Forehead",
                    ),

                  // For whatever fucking reason, this needs to be down here, otherwise all of the switch values are false
                  if (currentMode != null && modes != null)
                    SettingsOptions<DisplayMode>(
                      initial: currentMode,
                      showDivider: false,
                      onChanged: (val) async {
                        currentMode = val;
                        _settingsCopy.displayMode = currentMode.id;
                      },
                      options: modes,
                      textProcessing: (dynamic val) => val.toString(),
                      title: "Display",
                    ),
                  // SettingsOptions<String>(
                  //   initial: _settingsCopy.emojiFontFamily == null
                  //       ? "System"
                  //       : fontFamilyToString[_settingsCopy.emojiFontFamily],
                  //   onChanged: (val) {
                  //     _settingsCopy.emojiFontFamily = stringToFontFamily[val];
                  //   },
                  //   options: stringToFontFamily.keys.toList(),
                  //   textProcessing: (dynamic val) => val,
                  //   title: "Emoji Style",
                  //   showDivider: false,
                  // ),
                ],
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[],
              ),
            )
          ],
        ),
      ),
    );
  }

  void saveSettings() {
    SettingsManager().saveSettings(_settingsCopy);
  }

  @override
  void dispose() {
    saveSettings();
    super.dispose();
  }
}

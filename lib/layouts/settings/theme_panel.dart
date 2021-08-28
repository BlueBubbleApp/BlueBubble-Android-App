import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/theming/theming_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';

class ThemePanelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ThemePanelController>(() => ThemePanelController());
  }
}

class ThemePanelController extends GetxController {
  late Settings _settingsCopy;
  final RxList<DisplayMode> modes = <DisplayMode>[].obs;
  final RxList<int> refreshRates = <int>[].obs;
  final RxInt currentMode = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _settingsCopy = SettingsManager().settings;
  }

  @override
  void onReady() async {
    modes.value = await FlutterDisplayMode.supported;
    refreshRates.value = modes.map((e) => e.refreshRate.round()).toSet().toList();
    currentMode.value = (await _settingsCopy.getDisplayMode()).refreshRate.round();
    super.onReady();
  }

  @override
  void dispose() async {
    await SettingsManager().saveSettings(_settingsCopy);
    super.dispose();
  }
}

class ThemePanel extends GetView<ThemePanelController> {

  @override
  Widget build(BuildContext context) {
    Widget nextIcon = Obx(() => Icon(
      SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.chevron_right : Icons.arrow_forward,
      color: Colors.grey,
    ));

    /// for some reason we need a [GetBuilder] here otherwise the theme switching refuses to work right
    return GetBuilder<ThemePanelController>(builder: (_) {
      final iosSubtitle = Theme.of(context).textTheme.subtitle1?.copyWith(color: Colors.grey, fontWeight: FontWeight.w300);
      final materialSubtitle = Theme.of(context).textTheme.subtitle1?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold);
      Color headerColor;
      Color tileColor;
      if (Theme.of(context).accentColor.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance()
          || SettingsManager().settings.skin.value != Skins.iOS) {
        headerColor = Theme.of(context).accentColor;
        tileColor = Theme.of(context).backgroundColor;
      } else {
        headerColor = Theme.of(context).backgroundColor;
        tileColor = Theme.of(context).accentColor;
      }
      if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
        tileColor = headerColor;
      }

      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: headerColor, // navigation bar color
          systemNavigationBarIconBrightness:
          headerColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
          statusBarColor: Colors.transparent, // status bar color
        ),
        child: Scaffold(
          backgroundColor: SettingsManager().settings.skin.value != Skins.iOS ? tileColor : headerColor,
          appBar: PreferredSize(
            preferredSize: Size(context.width, 80),
            child: ClipRRect(
              child: BackdropFilter(
                child: AppBar(
                  brightness: ThemeData.estimateBrightnessForColor(headerColor),
                  toolbarHeight: 100.0,
                  elevation: 0,
                  leading: buildBackButton(context),
                  backgroundColor: headerColor.withOpacity(0.5),
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
                    Container(
                        height: SettingsManager().settings.skin.value == Skins.iOS ? 30 : 40,
                        alignment: Alignment.bottomLeft,
                        decoration: SettingsManager().settings.skin.value == Skins.iOS ? BoxDecoration(
                          color: headerColor,
                          border: Border(
                              bottom: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                          ),
                        ) : BoxDecoration(
                          color: tileColor,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, left: 15),
                          child: Text("Theme".psCapitalize, style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                        )
                    ),
                    SettingsOptions<AdaptiveThemeMode>(
                      initial: AdaptiveTheme.of(context).mode,
                      onChanged: (val) {
                        if (val == null) return;
                        AdaptiveTheme.of(context).setThemeMode(val);
                      },
                      options: AdaptiveThemeMode.values,
                      textProcessing: (val) => val.toString().split(".").last,
                      title: "App Theme",
                      backgroundColor: tileColor,
                      secondaryColor: headerColor,
                    ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
                      ),
                    ),
                    SettingsTile(
                      title: "Theming",
                      subtitle: "Edit existing themes and create custom themes",
                      trailing: nextIcon,
                      onTap: () async {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (context) => ThemingPanel(),
                          ),
                        );
                      },
                      backgroundColor: tileColor,
                    ),
                    SettingsHeader(
                        headerColor: headerColor,
                        tileColor: tileColor,
                        iosSubtitle: iosSubtitle,
                        materialSubtitle: materialSubtitle,
                        text: "Skin"
                    ),
                    Obx(() => SettingsOptions<Skins>(
                      initial: controller._settingsCopy.skin.value,
                      onChanged: (val) {
                        if (val == null) return;
                        controller._settingsCopy.skin.value = val;
                        if (val == Skins.Material) {
                          controller._settingsCopy.hideDividers.value = true;
                        } else if (val == Skins.Samsung) {
                          controller._settingsCopy.hideDividers.value = true;
                        } else {
                          controller._settingsCopy.hideDividers.value = false;
                        }
                        ChatBloc().refreshChats();
                        saveSettings();
                        controller.update();
                      },
                      options: Skins.values.where((item) => item != Skins.Samsung).toList(),
                      textProcessing: (val) => val.toString().split(".").last,
                      capitalize: false,
                      title: "App Skin",
                      backgroundColor: tileColor,
                      secondaryColor: headerColor,
                    )),
                    SettingsHeader(
                        headerColor: headerColor,
                        tileColor: tileColor,
                        iosSubtitle: iosSubtitle,
                        materialSubtitle: materialSubtitle,
                        text: "Colors"
                    ),
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        controller._settingsCopy.colorfulAvatars.value = val;
                        saveSettings();
                      },
                      initialVal: controller._settingsCopy.colorfulAvatars.value,
                      title: "Colorful Avatars",
                      backgroundColor: tileColor,
                      subtitle: "Gives letter avatars a splash of color",
                    )),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
                      ),
                    ),
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        controller._settingsCopy.colorfulBubbles.value = val;
                        saveSettings();
                      },
                      initialVal: controller._settingsCopy.colorfulBubbles.value,
                      title: "Colorful Bubbles",
                      backgroundColor: tileColor,
                      subtitle: "Gives received message bubbles a splash of color",
                    )),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
                      ),
                    ),
                    SettingsTile(
                      title: "Custom Avatar Colors",
                      trailing: nextIcon,
                      onTap: () async {
                        Get.toNamed("/settings/custom-avatar-color-panel");
                      },
                      backgroundColor: tileColor,
                      subtitle: "Customize the color for different avatars",
                    ),
                    SettingsTile(
                      title: "Custom Avatars",
                      trailing: nextIcon,
                      onTap: () async {
                        Get.toNamed("/settings/custom-avatar-panel");
                      },
                      backgroundColor: tileColor,
                      subtitle: "Customize the avatar for different chats",
                    ),
                    Obx(() {
                      if (controller.refreshRates.length > 2)
                        return SettingsHeader(
                            headerColor: headerColor,
                            tileColor: tileColor,
                            iosSubtitle: iosSubtitle,
                            materialSubtitle: materialSubtitle,
                            text: "Refresh Rate"
                        );
                      else return SizedBox.shrink();
                    }),
                    Obx(() {
                      if (controller.refreshRates.length > 2)
                        return SettingsOptions<int>(
                          initial: controller.currentMode.value,
                          onChanged: (val) async {
                            if (val == null) return;
                            controller.currentMode.value = val;
                            controller._settingsCopy.refreshRate.value = controller.currentMode.value;
                            await FlutterDisplayMode.setPreferredMode(await controller._settingsCopy.getDisplayMode());
                            saveSettings();
                          },
                          options: controller.refreshRates,
                          textProcessing: (val) => val == 0 ? "Auto" : val.toString() + " Hz",
                          title: "Display",
                          backgroundColor: tileColor,
                          secondaryColor: headerColor,
                        );
                      else return SizedBox.shrink();
                    }),
                    // SettingsOptions<String>(
                    //   initial: controller._settingsCopy.emojiFontFamily == null
                    //       ? "System"
                    //       : fontFamilyToString[controller._settingsCopy.emojiFontFamily],
                    //   onChanged: (val) {
                    //     controller._settingsCopy.emojiFontFamily = stringToFontFamily[val];
                    //   },
                    //   options: stringToFontFamily.keys.toList(),
                    //   textProcessing: (dynamic val) => val,
                    //   title: "Emoji Style",
                    //   showDivider: false,
                    // ),
                    Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                    Container(
                      height: 30,
                      decoration: SettingsManager().settings.skin.value == Skins.iOS ? BoxDecoration(
                        color: headerColor,
                        border: Border(
                            top: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                        ),
                      ) : null,
                    ),
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
    });
  }

  void saveSettings() {
    SettingsManager().saveSettings(controller._settingsCopy);
  }
}

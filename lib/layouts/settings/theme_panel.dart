import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/api_manager.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/custom_avatar_color_panel.dart';
import 'package:bluebubbles/layouts/settings/custom_avatar_panel.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/layouts/theming/theming_panel.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:dio/dio.dart';
import 'package:dynamic_cached_fonts/dynamic_cached_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart' hide Response;
import 'package:universal_io/io.dart';

class ThemePanelController extends GetxController {
  late Settings _settingsCopy;
  final RxList<DisplayMode> modes = <DisplayMode>[].obs;
  final RxList<int> refreshRates = <int>[].obs;
  final RxInt currentMode = 0.obs;
  final RxnBool gettingIcons = RxnBool();

  @override
  void onInit() {
    super.onInit();
    _settingsCopy = SettingsManager().settings;
  }

  @override
  void onReady() async {
    if (!kIsWeb && !kIsDesktop) {
      modes.value = await FlutterDisplayMode.supported;
      refreshRates.value = modes.map((e) => e.refreshRate.round()).toSet().toList();
      currentMode.value = (await _settingsCopy.getDisplayMode()).refreshRate.round();
    }
    super.onReady();
  }

  @override
  void dispose() async {
    await SettingsManager().saveSettings(_settingsCopy);
    super.dispose();
  }
}

class ThemePanel extends StatelessWidget {
  final controller = Get.put(ThemePanelController());

  @override
  Widget build(BuildContext context) {
    Widget nextIcon = Obx(() => Icon(
          SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.chevron_right : Icons.arrow_forward,
          color: Colors.grey,
        ));

    /// for some reason we need a [GetBuilder] here otherwise the theme switching refuses to work right
    return GetBuilder<ThemePanelController>(builder: (_) {
      final iosSubtitle =
          Theme.of(context).textTheme.subtitle1?.copyWith(color: Colors.grey, fontWeight: FontWeight.w300);
      final materialSubtitle = Theme.of(context)
          .textTheme
          .subtitle1
          ?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold);
      Color headerColor = context.theme.headerColor;
      Color tileColor = context.theme.tileColor;

      return SettingsScaffold(
        title: "Theming & Styles",
        initialHeader: "Appearance",
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        bodySlivers: [
          SliverList(
            delegate: SliverChildListDelegate(
              <Widget>[
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    SettingsOptions<AdaptiveThemeMode>(
                      initial: AdaptiveTheme.of(context).mode,
                      onChanged: (val) {
                        if (val == null) return;
                        AdaptiveTheme.of(context).setThemeMode(val);
                        controller.update();
                        EventDispatcher().emit('theme-update', null);
                      },
                      options: AdaptiveThemeMode.values,
                      textProcessing: (val) => val.toString().split(".").last,
                      title: "App Theme",
                      backgroundColor: tileColor,
                      secondaryColor: headerColor,
                    ),
                    if (!kIsWeb)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      ),
                    if (!kIsWeb)
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
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: tileColor,
                      ),
                      padding: EdgeInsets.only(left: 15),
                      child: Text("Avatar Scale Factor"),
                    ),
                    Obx(() => SettingsSlider(
                        text: "Avatar Scale Factor",
                        startingVal: SettingsManager().settings.avatarScale.value.toDouble(),
                        update: (double val) {
                          SettingsManager().settings.avatarScale.value = val;
                        },
                        onChangeEnd: (double val) {
                          saveSettings();
                        },
                        formatValue: ((double val) => val.toPrecision(2).toString()),
                        backgroundColor: tileColor,
                        min: 0.8,
                        max: 1.2,
                        divisions: 4
                    )),
                  ],
                ),
                SettingsHeader(
                    headerColor: headerColor,
                    tileColor: tileColor,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Skin and Layout"),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Obx(() => SettingsOptions<Skins>(
                      initial: controller._settingsCopy.skin.value,
                      onChanged: (val) {
                        if (val == null) return;
                        controller._settingsCopy.skin.value = val;
                        ChatBloc().refreshChats();
                        saveSettings();
                        controller.update();
                        EventDispatcher().emit('theme-update', null);
                      },
                      options: Skins.values,
                      textProcessing: (val) {
                        var output = val.toString().split(".").last;
                        return output == 'Samsung' ? 'Samsung (Beta)' : output;
                      },
                      capitalize: false,
                      title: "App Skin",
                      backgroundColor: tileColor,
                      secondaryColor: headerColor,
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
                        controller._settingsCopy.tabletMode.value = val;
                        saveSettings();
                      },
                      initialVal: controller._settingsCopy.tabletMode.value,
                      title: "Tablet Mode",
                      backgroundColor: tileColor,
                      subtitle: "Enables tablet mode (split view) depending on screen width",
                    )),
                    if (!kIsWeb && !kIsDesktop)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      ),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsSwitch(
                        onChanged: (bool val) {
                          controller._settingsCopy.immersiveMode.value = val;
                          saveSettings();
                          if (val) {
                            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                          } else {
                            SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top]);
                          }
                          EventDispatcher().emit('theme-update', null);
                        },
                        initialVal: controller._settingsCopy.immersiveMode.value,
                        title: "Immersive Mode",
                        backgroundColor: tileColor,
                        subtitle: "Makes the bottom navigation bar transparent. This option is best used with gesture navigation. Note: This option may cause slight choppiness in some animations due to an Android limitation",
                      )),
                  ],
                ),
                SettingsHeader(
                    headerColor: headerColor,
                    tileColor: tileColor,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Colors"),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    if (!kIsWeb && !kIsDesktop && monetPalette != null)
                      Obx(() {
                        if (SettingsManager().settings.skin.value == Skins.iOS) {
                          return SettingsTile(
                            backgroundColor: tileColor,
                            title: "Material You",
                            subtitle:
                            "Use Android 12's Monet engine to provide wallpaper-based coloring to your theme. Tap for more info.",
                            onTap: () {
                              showMonetDialog(context);
                            },
                          );
                        } else {
                          return SizedBox.shrink();
                        }
                      }),
                    if (!kIsWeb && !kIsDesktop && monetPalette != null)
                      GestureDetector(
                        onTap: () {
                          showMonetDialog(context);
                        },
                        child: SettingsOptions<Monet>(
                          initial: controller._settingsCopy.monetTheming.value,
                          onChanged: (val) {
                            controller._settingsCopy.monetTheming.value = val ?? Monet.none;
                            saveSettings();
                            loadTheme(context);
                          },
                          options: Monet.values,
                          textProcessing: (val) => val.toString().split(".").last,
                          title: "Material You",
                          subtitle:
                          "Use Android 12's Monet engine to provide wallpaper-based coloring to your theme. Tap for more info.",
                          backgroundColor: tileColor,
                          secondaryColor: headerColor,
                        ),
                      ),
                    if (!kIsWeb && !kIsDesktop && monetPalette != null)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      ),
                    SettingsSwitch(
                      initialVal: controller._settingsCopy.material3.value,
                      onChanged: (bool val) {
                        controller._settingsCopy.material3.value = val;
                        saveSettings();
                        loadTheme(context);
                      },
                      backgroundColor: tileColor,
                      title: "Material 3",
                      subtitle:
                      "Use Material 3 UI design and Android 12's stretchy overscroll indicator",
                    ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
                      ),
                    ),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(
                            () => SettingsSwitch(
                          onChanged: (bool val) async {
                            await MethodChannelInterface().invokeMethod("request-notif-permission");
                            try {
                              await MethodChannelInterface().invokeMethod("start-notif-listener");
                              if (val) {
                                var allThemes = ThemeObject.getThemes();
                                var currentLight = ThemeObject.getLightTheme();
                                var currentDark = ThemeObject.getDarkTheme();
                                currentLight.previousLightTheme = true;
                                currentDark.previousDarkTheme = true;
                                currentLight.save();
                                currentDark.save();
                                SettingsManager().saveSelectedTheme(context,
                                    selectedLightTheme:
                                    allThemes.firstWhere((element) => element.name == "Music Theme (Light)"),
                                    selectedDarkTheme:
                                    allThemes.firstWhere((element) => element.name == "Music Theme (Dark)"));
                              } else {
                                var allThemes = ThemeObject.getThemes();
                                var previousLight = allThemes.firstWhere((e) => e.previousLightTheme);
                                var previousDark = allThemes.firstWhere((e) => e.previousDarkTheme);
                                previousLight.previousLightTheme = false;
                                previousDark.previousDarkTheme = false;
                                previousLight.save();
                                previousDark.save();
                                SettingsManager().saveSelectedTheme(context,
                                    selectedLightTheme: previousLight, selectedDarkTheme: previousDark);
                              }
                              controller._settingsCopy.colorsFromMedia.value = val;
                              saveSettings();
                            } catch (e) {
                              showSnackbar(
                                  "Error", "Something went wrong, please ensure you granted the permission correctly!");
                            }
                          },
                          initialVal: controller._settingsCopy.colorsFromMedia.value,
                          title: "Colors from Media",
                          backgroundColor: tileColor,
                          subtitle:
                          "Pull app colors from currently playing media. Note: Requires full notification access & a custom theme to be set",
                        ),
                      ),
                    if (!kIsWeb && !kIsDesktop)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
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
                    if (!kIsWeb)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      ),
                    if (!kIsWeb)
                      SettingsTile(
                        title: "Custom Avatar Colors",
                        trailing: nextIcon,
                        onTap: () async {
                          CustomNavigator.pushSettings(
                            context,
                            CustomAvatarColorPanel(),
                            binding: CustomAvatarColorPanelBinding(),
                          );
                        },
                        backgroundColor: tileColor,
                        subtitle: "Customize the color for different avatars",
                      ),
                    if (!kIsWeb)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      ),
                    if (!kIsWeb)
                      SettingsTile(
                        title: "Custom Avatars",
                        trailing: nextIcon,
                        onTap: () async {
                          CustomNavigator.pushSettings(
                            context,
                            CustomAvatarPanel(),
                            binding: CustomAvatarPanelBinding(),
                          );
                        },
                        backgroundColor: tileColor,
                        subtitle: "Customize the avatar for different chats",
                      ),
                    if (!kIsWeb)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      ),
                    if (!kIsWeb)
                      SettingsTile(
                        title: "Sync Group Chat Icons",
                        trailing: Obx(() => controller.gettingIcons.value == null
                            ? SizedBox.shrink()
                            : controller.gettingIcons.value == true ? Container(
                            constraints: BoxConstraints(
                              maxHeight: 20,
                              maxWidth: 20,
                            ),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                            )) : Icon(Icons.check, color: Colors.grey)
                        ),
                        onTap: () async {
                          controller.gettingIcons.value = true;
                          for (Chat c in ChatBloc().chats.where((c) => c.isGroup())) {
                            final response = await api.getChatIcon(c.guid).catchError((err) async {
                              Logger.error("Failed to get chat icon for chat ${c.getTitle()}");
                              return Response(statusCode: 500, requestOptions: RequestOptions(path: ""));
                            });
                            if (response.statusCode != 200 || isNullOrEmpty(response.data)!) continue;
                            Logger.debug("Got chat icon for chat ${c.getTitle()}");
                            File file = File(c.customAvatarPath ?? "${SettingsManager().appDocDir.path}/avatars/${c.guid.characters.where((char) => char.isAlphabetOnly || char.isNumericOnly).join()}/avatar.jpg");
                            if (c.customAvatarPath == null) {
                              await file.create(recursive: true);
                            }
                            await file.writeAsBytes(response.data);
                            c.customAvatarPath = file.path;
                            c.save(updateCustomAvatarPath: true);
                          }
                          controller.gettingIcons.value = false;
                        },
                        backgroundColor: tileColor,
                        subtitle: "Get iMessage group chat icons. Note: Overrides any custom avatars set for group chats",
                      ),
                  ],
                ),
                if (!kIsWeb && !kIsDesktop)
                  Obx(() {
                    if (controller.refreshRates.length > 2) {
                      return SettingsHeader(
                          headerColor: headerColor,
                          tileColor: tileColor,
                          iosSubtitle: iosSubtitle,
                          materialSubtitle: materialSubtitle,
                          text: "Refresh Rate");
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
                if (!kIsWeb && !kIsDesktop)
                  SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      Obx(() {
                        if (controller.refreshRates.length > 2) {
                          return SettingsOptions<int>(
                            initial: controller.currentMode.value,
                            onChanged: (val) async {
                              if (val == null) return;
                              controller.currentMode.value = val;
                              controller._settingsCopy.refreshRate.value = controller.currentMode.value;
                              saveSettings();
                            },
                            options: controller.refreshRates,
                            textProcessing: (val) => val == 0 ? "Auto" : "$val Hz",
                            title: "Display",
                            backgroundColor: tileColor,
                            secondaryColor: headerColor,
                          );
                        } else {
                          return SizedBox.shrink();
                        }
                      }),
                    ],
                  ),
                if (!kIsWeb)
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Text and Font"),
                if (!kIsWeb)
                  SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      Obx(() {
                        if (!fontExistsOnDisk.value) {
                          return SettingsTile(
                            onTap: () async {
                              Get.defaultDialog(
                                backgroundColor: context.theme.colorScheme.secondary,
                                radius: 15.0,
                                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                                titlePadding: EdgeInsets.only(top: 15),
                                title: "Downloading font file...",
                                titleStyle: Theme.of(context).textTheme.headline1,
                                confirm: Obx(() => downloadingFont.value
                                  ? Container(height: 0, width: 0)
                                  : Container(
                                    margin: EdgeInsets.only(bottom: 10),
                                    child: TextButton(
                                      child: Text("CLOSE"),
                                      onPressed: () async {
                                        if (Get.isSnackbarOpen ?? false) {
                                          Get.close(1);
                                        }
                                        Get.back();
                                        Future.delayed(Duration(milliseconds: 400), ()
                                        {
                                          progress.value = null;
                                          totalSize.value = null;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                cancel: Container(height: 0, width: 0),
                                content: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: 300),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                                    Obx(
                                          () => Text(
                                          '${progress.value != null && totalSize.value != null ? getSizeString(progress.value! * totalSize.value! / 1000) : ""} / ${getSizeString((totalSize.value ?? 0).toDouble() / 1000)} (${((progress.value ?? 0) * 100).floor()}%)'),
                                    ),
                                    SizedBox(height: 10.0),
                                    Obx(
                                          () => ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: LinearProgressIndicator(
                                          backgroundColor: Colors.white,
                                          value: progress.value,
                                          minHeight: 5,
                                          valueColor:
                                          AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 15.0,
                                    ),
                                    Obx(() => Text(
                                      progress.value == 1 ? "Download Complete!" : "You can close this dialog. The font will continue to download in the background.",
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                    ),),
                                  ]),
                                ),
                              );
                              final DynamicCachedFonts dynamicCachedFont = DynamicCachedFonts(
                                fontFamily: "Apple Color Emoji",
                                url:
                                "https://github.com/tneotia/tneotia/releases/download/ios-font-2/AppleColorEmoji.ttf",
                              );
                              dynamicCachedFont.load().listen((data) {
                                if (data is FileInfo) {
                                  fontExistsOnDisk.value = true;
                                  showSnackbar("Notice", "Font loaded");
                                } else if (data is DownloadProgress) {
                                  downloadingFont.value = true;
                                  progress.value = data.progress;
                                  totalSize.value = data.totalSize;
                                  if (progress.value == 1.0) {
                                    downloadingFont.value = false;
                                  }
                                }
                              });
                            },
                            title:
                            "Download${downloadingFont.value ? "ing" : ""} iOS Emoji Font${downloadingFont.value ? " (${progress.value != null && totalSize.value != null ? getSizeString(progress.value! * totalSize.value! / 1000) : ""} / ${getSizeString((totalSize.value ?? 0).toDouble() / 1000)}) (${((progress.value ?? 0) * 100).floor()}%)" : ""}",
                            backgroundColor: tileColor,
                          );
                        } else {
                          return SizedBox.shrink();
                        }
                      }),
                      Obx(() {
                        if (fontExistsOnDisk.value) {
                          return SettingsTile(
                            onTap: () async {
                              await DynamicCachedFonts.removeCachedFont("https://github.com/tneotia/tneotia/releases/download/ios-font-2/AppleColorEmoji.ttf");
                              fontExistsOnDisk.value = false;
                              showSnackbar("Notice", "Font removed, restart the app for changes to take effect");
                            },
                            title: "Delete iOS Emoji Font",
                            backgroundColor: tileColor,
                          );
                        } else {
                          return SizedBox.shrink();
                        }
                      }),
                    ],
                  ),
              ],
            ),
          ),
        ]
      );
    });
  }

  void saveSettings() {
    SettingsManager().saveSettings(controller._settingsCopy);
  }

  void showMonetDialog(BuildContext context) {
    Get.defaultDialog(
        title: "Monet Theming Info",
        titleStyle: Theme.of(context).textTheme.headline1,
        backgroundColor: Theme.of(context).backgroundColor.lightenPercent(),
        buttonColor: Theme.of(context).primaryColor,
        content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(left: 10, right: 10),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        "Harmonize - Overwrites primary color, and blends background & accent color with the current theme colors\r\n"
                            "Full - Overwrites primary, background, and accent colors, along with other minor colors.\r\n"
                    )
                ),
              ),
            ]
        ),
        cancel: Container(
          height: 0,
          width: 0,
        ),
        textConfirm: "OK",
        confirmTextColor: context.theme.dialogBackgroundColor,
        barrierDismissible: false,
        onConfirm: () {
          Get.back();
        }
    );
  }
}

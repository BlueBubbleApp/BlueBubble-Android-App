import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_improved_scrolling/flutter_improved_scrolling.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:secure_application/secure_application.dart';

class MiscPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final iosSubtitle =
        Theme.of(context).textTheme.subtitle1?.copyWith(color: Colors.grey, fontWeight: FontWeight.w300);
    final materialSubtitle = Theme.of(context)
        .textTheme
        .subtitle1
        ?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold);
    Color headerColor;
    Color tileColor;
    if (Theme.of(context).accentColor.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() ||
        SettingsManager().settings.skin.value != Skins.iOS) {
      headerColor = Theme.of(context).accentColor;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).accentColor;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }

    final scrollController = ScrollController();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: headerColor, // navigation bar color
        systemNavigationBarIconBrightness: headerColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: SettingsManager().settings.skin.value != Skins.iOS ? tileColor : headerColor,
        appBar: PreferredSize(
          preferredSize: Size(CustomNavigator.width(context), 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: ThemeData.estimateBrightnessForColor(headerColor),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: headerColor.withOpacity(0.5),
                title: Text(
                  "Miscellaneous and Advanced",
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: ImprovedScrolling(
    enableMMBScrolling: true,
    enableKeyboardScrolling: true,
    mmbScrollConfig: MMBScrollConfig(
    customScrollCursor: DefaultCustomScrollCursor(
    cursorColor: context.textTheme.subtitle1!.color!,
    backgroundColor: Colors.white,
    borderColor: context.textTheme.headline1!.color!,
    ),
    ),
    scrollController: scrollController,
    child: CustomScrollView(
    controller: scrollController,
          physics: ThemeSwitcher.getScrollPhysics(),
          slivers: <Widget>[
            SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[
                  Container(
                      height: SettingsManager().settings.skin.value == Skins.iOS ? 30 : 40,
                      alignment: Alignment.bottomLeft,
                      decoration: SettingsManager().settings.skin.value == Skins.iOS
                          ? BoxDecoration(
                              color: headerColor,
                              border: Border(
                                  bottom: BorderSide(
                                      color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)),
                            )
                          : BoxDecoration(
                              color: tileColor,
                            ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 15),
                        child: Text("Notifications".psCapitalize,
                            style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                      )),
                  Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.hideTextPreviews.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.hideTextPreviews.value,
                        title: "Hide Message Text",
                        subtitle: "Replaces message text with 'iMessage' in notifications",
                        backgroundColor: tileColor,
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
                          SettingsManager().settings.showIncrementalSync.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.showIncrementalSync.value,
                        title: "Notify when incremental sync complete",
                        subtitle: "Show a snackbar whenever a message sync is completed",
                        backgroundColor: tileColor,
                      )),
                  if (SettingsManager().canAuthenticate)
                    SettingsHeader(
                        headerColor: headerColor,
                        tileColor: tileColor,
                        iosSubtitle: iosSubtitle,
                        materialSubtitle: materialSubtitle,
                        text: "Security"),
                  if (SettingsManager().canAuthenticate)
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) async {
                            var localAuth = LocalAuthentication();
                            bool didAuthenticate = await localAuth.authenticate(
                                localizedReason:
                                    'Please authenticate to ${val == true ? "enable" : "disable"} security',
                                stickyAuth: true);
                            if (didAuthenticate) {
                              SettingsManager().settings.shouldSecure.value = val;
                              if (val == false) {
                                SecureApplicationProvider.of(context, listen: false)!.open();
                              } else if (SettingsManager().settings.securityLevel.value ==
                                  SecurityLevel.locked_and_secured) {
                                SecureApplicationProvider.of(context, listen: false)!.secure();
                              }
                              saveSettings();
                            }
                          },
                          initialVal: SettingsManager().settings.shouldSecure.value,
                          title: "Secure App",
                          subtitle: "Secure app with a fingerprint or pin",
                          backgroundColor: tileColor,
                        )),
                  if (SettingsManager().canAuthenticate)
                    Obx(() {
                      if (SettingsManager().settings.shouldSecure.value) {
                        return Container(
                            color: tileColor,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(text: "Security Info", style: TextStyle(fontWeight: FontWeight.bold)),
                                    TextSpan(text: "\n\n"),
                                    TextSpan(
                                        text:
                                            "BlueBubbles will use the fingerprints and pin/password set on your device as authentication. Please note that BlueBubbles does not have access to your authentication information - all biometric checks are handled securely by your operating system. The app is only notified when the unlock is successful."),
                                    TextSpan(text: "\n\n"),
                                    TextSpan(text: "There are two different security levels you can choose from:"),
                                    TextSpan(text: "\n\n"),
                                    TextSpan(text: "Locked", style: TextStyle(fontWeight: FontWeight.bold)),
                                    TextSpan(text: " - Requires biometrics/pin only when the app is first started"),
                                    TextSpan(text: "\n\n"),
                                    TextSpan(text: "Locked and secured", style: TextStyle(fontWeight: FontWeight.bold)),
                                    TextSpan(
                                        text:
                                            " - Requires biometrics/pin any time the app is brought into the foreground, hides content in the app switcher, and disables screenshots & screen recordings"),
                                  ],
                                  style: Theme.of(context)
                                      .textTheme
                                      .subtitle1
                                      ?.copyWith(color: Theme.of(context).textTheme.bodyText1?.color),
                                ),
                              ),
                            ));
                      } else {
                        return SizedBox.shrink();
                      }
                    }),
                  if (SettingsManager().canAuthenticate)
                    Obx(() {
                      if (SettingsManager().settings.shouldSecure.value) {
                        return SettingsOptions<SecurityLevel>(
                          initial: SettingsManager().settings.securityLevel.value,
                          onChanged: (val) async {
                            var localAuth = LocalAuthentication();
                            bool didAuthenticate = await localAuth.authenticate(
                                localizedReason: 'Please authenticate to change your security level', stickyAuth: true);
                            if (didAuthenticate) {
                              if (val != null) {
                                SettingsManager().settings.securityLevel.value = val;
                                if (val == SecurityLevel.locked_and_secured) {
                                  SecureApplicationProvider.of(context, listen: false)!.secure();
                                } else {
                                  SecureApplicationProvider.of(context, listen: false)!.open();
                                }
                              }
                              saveSettings();
                            }
                          },
                          options: SecurityLevel.values,
                          textProcessing: (val) => val.toString().split(".")[1].replaceAll("_", " ").capitalizeFirst!,
                          title: "Security Level",
                          backgroundColor: tileColor,
                          secondaryColor: headerColor,
                        );
                      } else {
                        return SizedBox.shrink();
                      }
                    }),
                  if (SettingsManager().canAuthenticate)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
                      ),
                    ),
                  // Obx(() => SettingsSwitch(
                  //   onChanged: (bool val) async {
                  //     SettingsManager().settings.incognitoKeyboard.value = val;
                  //     saveSettings();
                  //   },
                  //   initialVal: SettingsManager().settings.incognitoKeyboard.value,
                  //   title: "Incognito Keyboard",
                  //   subtitle: "Disables keyboard suggestions and prevents the keyboard from learning or storing any words you type in the message text field",
                  //   backgroundColor: tileColor,
                  // )),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Speed & Responsiveness"),
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.lowMemoryMode.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.lowMemoryMode.value,
                        title: "Low Memory Mode",
                        subtitle:
                            "Reduces background processes and deletes cached storage items to improve performance on lower-end devices",
                        backgroundColor: tileColor,
                      )),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS) {
                      return Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS) {
                      return SettingsTile(
                        title: "Scroll Speed Multiplier",
                        subtitle: "Controls how fast scrolling occurs",
                        backgroundColor: tileColor,
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS) {
                      return SettingsSlider(
                          text: "Scroll Speed Multiplier",
                          startingVal: SettingsManager().settings.scrollVelocity.value,
                          update: (double val) {
                            SettingsManager().settings.scrollVelocity.value = double.parse(val.toStringAsFixed(2));
                            saveSettings();
                          },
                          formatValue: ((double val) => val.toStringAsFixed(2)),
                          backgroundColor: tileColor,
                          min: 0.20,
                          max: 1,
                          divisions: 8);
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
                  SettingsHeader(
                    headerColor: headerColor,
                    tileColor: tileColor,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Other",
                  ),
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.sendDelay.value = val ? 3 : 0;
                          saveSettings();
                        },
                        initialVal: !isNullOrZero(SettingsManager().settings.sendDelay.value),
                        title: "Send Delay",
                        backgroundColor: tileColor,
                      )),
                  Obx(() {
                    if (!isNullOrZero(SettingsManager().settings.sendDelay.value)) {
                      return SettingsSlider(
                          text: "Set send delay",
                          startingVal: SettingsManager().settings.sendDelay.toDouble(),
                          update: (double val) {
                            SettingsManager().settings.sendDelay.value = val.toInt();
                            saveSettings();
                          },
                          formatValue: ((double val) => val.toStringAsFixed(0) + " sec"),
                          backgroundColor: tileColor,
                          min: 1,
                          max: 10,
                          divisions: 9);
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.use24HrFormat.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.use24HrFormat.value,
                        title: "Use 24 Hour Format for Times",
                        backgroundColor: tileColor,
                      )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS) {
                      return SettingsTile(
                        title: "Maximum Group Avatar Size",
                        subtitle: "Controls the maximum number of contact avatars in a group chat's widget",
                        backgroundColor: tileColor,
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
                  Obx(
                    () {
                      if (SettingsManager().settings.skin.value == Skins.iOS) {
                        return SettingsSlider(
                          divisions: 3,
                          max: 5,
                          min: 3,
                          text: 'Maximum avatars in a group chat widget',
                          startingVal: SettingsManager().settings.maxAvatarsInGroupWidget.value.toDouble(),
                          update: (double val) {
                            SettingsManager().settings.maxAvatarsInGroupWidget.value = val.toInt();
                            saveSettings();
                          },
                          formatValue: ((double val) => val.toStringAsFixed(0)),
                          backgroundColor: tileColor,
                        );
                      } else {
                        return SizedBox.shrink();
                      }
                    },
                  ),
                  Container(
                    height: 30,
                    decoration: SettingsManager().settings.skin.value == Skins.iOS
                        ? BoxDecoration(
                            color: headerColor,
                            border: Border(
                                top: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)),
                          )
                        : null,
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
      ),),
    );
  }

  void saveSettings() {
    SettingsManager().saveSettings(SettingsManager().settings);
  }
}

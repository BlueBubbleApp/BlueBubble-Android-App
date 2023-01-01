import 'package:bluebubbles/api_manager.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:secure_application/secure_application.dart';
import 'package:universal_io/io.dart';

class MiscPanel extends StatelessWidget {
  final RxnBool refreshingContacts = RxnBool();

  @override
  Widget build(BuildContext context) {
    final iosSubtitle =
    context.theme.textTheme.labelLarge?.copyWith(color: ThemeManager().inDarkMode(context) ? context.theme.colorScheme.onBackground : context.theme.colorScheme.properOnSurface, fontWeight: FontWeight.w300);
    final materialSubtitle = context.theme
        .textTheme
        .labelLarge
        ?.copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold);
    // Samsung theme should always use the background color as the "header" color
    Color headerColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.background : context.theme.colorScheme.properSurface;
    Color tileColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background;
    
    // reverse material color mapping to be more accurate
    if (SettingsManager().settings.skin.value == Skins.Material && ThemeManager().inDarkMode(context)) {
      final temp = headerColor;
      headerColor = tileColor;
      tileColor = temp;
    }

    return SettingsScaffold(
      title: "Miscellaneous & Advanced",
      initialHeader: SettingsManager().canAuthenticate ? "Security" : "Speed & Responsiveness",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            <Widget>[
              if (SettingsManager().canAuthenticate)
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Obx(() =>
                        SettingsSwitch(
                          onChanged: (bool val) async {
                            var localAuth = LocalAuthentication();
                            bool didAuthenticate = await localAuth.authenticate(
                                localizedReason:
                                'Please authenticate to ${val == true ? "enable" : "disable"} security',
                                options: AuthenticationOptions(stickyAuth: true));
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
                                  style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
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
                                  localizedReason: 'Please authenticate to change your security level', options: AuthenticationOptions(stickyAuth: true));
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
                            textProcessing: (val) =>
                            val.toString().split(".")[1]
                                .replaceAll("_", " ")
                                .capitalizeFirst!,
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
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                        ),
                      ),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsSwitch(
                        onChanged: (bool val) async {
                          SettingsManager().settings.incognitoKeyboard.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.incognitoKeyboard.value,
                        title: "Incognito Keyboard",
                        subtitle: "Disables keyboard suggestions and prevents the keyboard from learning or storing any words you type in the message text field",
                        isThreeLine: true,
                        backgroundColor: tileColor,
                      )),
                  ],
                ),
              if (SettingsManager().canAuthenticate)
                SettingsHeader(
                    headerColor: headerColor,
                    tileColor: tileColor,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Speed & Responsiveness"),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(() =>
                      SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.lowMemoryMode.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.lowMemoryMode.value,
                        title: "Low Memory Mode",
                        subtitle:
                        "Reduces background processes and deletes cached storage items to improve performance on lower-end devices",
                        isThreeLine: true,
                        backgroundColor: tileColor,
                      )),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS) {
                      return Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
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
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS) {
                      return SettingsSlider(
                          startingVal: SettingsManager().settings.scrollVelocity.value,
                          update: (double val) {
                            SettingsManager().settings.scrollVelocity.value = double.parse(val.toStringAsFixed(2));
                          },
                          onChangeEnd: (double val) {
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
                ],
              ),
              SettingsHeader(
                  headerColor: headerColor,
                  tileColor: tileColor,
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "Networking"),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  SettingsTile(
                    title: "API Timeout Duration",
                    subtitle: "Controls the duration (in seconds) until a network request will time out.\nIncrease this setting if you have poor connection.",
                    isThreeLine: true,
                  ),
                  Obx(() =>
                      SettingsSlider(
                          startingVal: SettingsManager().settings.apiTimeout.value / 1000,
                          update: (double val) {
                            SettingsManager().settings.apiTimeout.value = val.toInt() * 1000;
                          },
                          onChangeEnd: (double val) {
                            saveSettings();
                            api.dio = Dio(BaseOptions(
                              connectTimeout: 15000,
                              receiveTimeout: SettingsManager().settings.apiTimeout.value,
                              sendTimeout: SettingsManager().settings.apiTimeout.value,
                            ));
                            api.dio.interceptors.add(ApiInterceptor());
                          },
                          backgroundColor: tileColor,
                          min: 5,
                          max: 60,
                          divisions: 11)),
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Obx(() => Text(
                      "Note: Attachment uploads will timeout after ${SettingsManager().settings.apiTimeout.value ~/ 1000 * 12} seconds",
                      style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
                    )),
                  )
                ],
              ),
              SettingsHeader(
                headerColor: headerColor,
                tileColor: tileColor,
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                text: "Other",),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(() =>
                      SettingsSwitch(
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
                          startingVal: SettingsManager().settings.sendDelay.toDouble(),
                          update: (double val) {
                            SettingsManager().settings.sendDelay.value = val.toInt();
                          },
                          onChangeEnd: (double val) {
                            saveSettings();
                          },
                          formatValue: ((double val) => "${val.toStringAsFixed(0)} sec"),
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
                      padding: const EdgeInsets.only(left: 15.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ),
                  Obx(() =>
                      SettingsSwitch(
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
                      padding: const EdgeInsets.only(left: 15.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ),
                  if (Platform.isAndroid)
                    Obx(() =>
                        SettingsSwitch(
                          onChanged: (bool val) {
                            SettingsManager().settings.allowUpsideDownRotation.value = val;
                            saveSettings();
                            SystemChrome.setPreferredOrientations([
                              DeviceOrientation.landscapeRight,
                              DeviceOrientation.landscapeLeft,
                              DeviceOrientation.portraitUp,
                              if (SettingsManager().settings.allowUpsideDownRotation.value)
                                DeviceOrientation.portraitDown,
                            ]);
                          },
                          initialVal: SettingsManager().settings.allowUpsideDownRotation.value,
                          title: "Allow Upside-Down Rotation",
                          backgroundColor: tileColor,
                        )),
                  if (Platform.isAndroid)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS) {
                      return SettingsTile(
                        title: "Maximum Group Avatar Count",
                        subtitle: "Controls the maximum number of contact avatars in a group chat's widget",
                        isThreeLine: true,
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
                          startingVal: SettingsManager().settings.maxAvatarsInGroupWidget.value.toDouble(),
                          update: (double val) {
                            SettingsManager().settings.maxAvatarsInGroupWidget.value = val.toInt();
                          },
                          onChangeEnd: (double val) {
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
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ),
                  SettingsTile(
                      title: "Refresh contacts",
                      onTap: () async {
                          refreshingContacts.value = true;
                          await ContactManager().loadContacts(force: true);
                          EventDispatcher().emit("refresh-all", null);
                          refreshingContacts.value = false;
                      },
                      trailing: Obx(() => refreshingContacts.value == null
                          ? SizedBox.shrink()
                          : refreshingContacts.value == true ? Container(
                          constraints: BoxConstraints(
                            maxHeight: 20,
                            maxWidth: 20,
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                          )) : Icon(Icons.check, color: context.theme.colorScheme.outline)
                      )),
                ],
              ),
            ],
          ),
        ),
      ]
    );
  }

  void saveSettings() {
    SettingsManager().saveSettings(SettingsManager().settings);
  }
}

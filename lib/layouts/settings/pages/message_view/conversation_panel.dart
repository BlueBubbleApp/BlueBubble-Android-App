import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/helpers/settings/theme_helpers_mixin.dart';
import 'package:bluebubbles/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/layouts/stateful_boilerplate.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/layouts/settings/pages/message_view/message_sounds_panel.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/constants.dart';

class ConversationPanel extends StatefulWidget {

  @override
  State<StatefulWidget> createState() => _ConversationPanelState();
}

class _ConversationPanelState extends OptimizedState<ConversationPanel> with ThemeHelpers {

  @override
  Widget build(BuildContext context) {

    Widget nextIcon = Obx(() => SettingsManager().settings.skin.value != Skins.Material ? Icon(
      SettingsManager().settings.skin.value != Skins.Material ? CupertinoIcons.chevron_right : Icons.arrow_forward,
      color: context.theme.colorScheme.outline,
      size: SettingsManager().settings.skin.value == Skins.iOS ? 18 : 24,
    ) : SizedBox.shrink());

    return SettingsScaffold(
      title: "Conversations",
      initialHeader: "Customization",
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
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      SettingsManager().settings.showDeliveryTimestamps.value = val;
                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.showDeliveryTimestamps.value,
                    title: "Show Delivery Timestamps",
                    backgroundColor: tileColor,
                  )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      SettingsManager().settings.recipientAsPlaceholder.value = val;
                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.recipientAsPlaceholder.value,
                    title: "Show Chat Name as Placeholder",
                    subtitle: "Changes the default hint text in the message box to display the recipient name",
                    backgroundColor: tileColor,
                    isThreeLine: true,
                  )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      SettingsManager().settings.alwaysShowAvatars.value = val;
                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.alwaysShowAvatars.value,
                    title: "Show Avatars in DM Chats",
                    subtitle: "Shows contact avatars in direct messages rather than just in group messages",
                    backgroundColor: tileColor,
                    isThreeLine: true,
                  )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.smartReply.value = val;
                        saveSettings();
                      },
                      initialVal: SettingsManager().settings.smartReply.value,
                      title: "Show Smart Replies",
                      subtitle: "Shows smart reply suggestions above the message text field",
                      backgroundColor: tileColor,
                      isThreeLine: true,
                    )),
                  if (!kIsWeb)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb)
                    SettingsTile(
                      title: "Send and Receive Sounds",
                      trailing: nextIcon,
                      onTap: () async {
                        CustomNavigator.pushSettings(
                          context,
                          MessageSoundsPanel(),
                        );
                      },
                      subtitle: "Customize message send and receive sounds",
                    ),
                ],
              ),
              SettingsHeader(
                  headerColor: headerColor,
                  tileColor: tileColor,
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "Gestures"),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.autoOpenKeyboard.value = val;
                        saveSettings();
                      },
                      initialVal: SettingsManager().settings.autoOpenKeyboard.value,
                      title: "Auto-open Keyboard",
                      subtitle: "Automatically open the keyboard when entering a chat",
                      backgroundColor: tileColor,
                    )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.swipeToCloseKeyboard.value = val;
                        saveSettings();
                      },
                      initialVal: SettingsManager().settings.swipeToCloseKeyboard.value,
                      title: "Swipe Message Box to Close Keyboard",
                      subtitle: "Swipe down on the message box to hide the keyboard",
                      backgroundColor: tileColor,
                    )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.swipeToOpenKeyboard.value = val;
                        saveSettings();
                      },
                      initialVal: SettingsManager().settings.swipeToOpenKeyboard.value,
                      title: "Swipe Message Box to Open Keyboard",
                      subtitle: "Swipe up on the message box to show the keyboard",
                      backgroundColor: tileColor,
                    )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.hideKeyboardOnScroll.value = val;
                        saveSettings();
                      },
                      initialVal: SettingsManager().settings.hideKeyboardOnScroll.value,
                      title: "Hide Keyboard When Scrolling",
                      backgroundColor: tileColor,
                    )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.openKeyboardOnSTB.value = val;
                        saveSettings();
                      },
                      initialVal: SettingsManager().settings.openKeyboardOnSTB.value,
                      title: "Open Keyboard After Tapping Scroll To Bottom",
                      backgroundColor: tileColor,
                    )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      SettingsManager().settings.doubleTapForDetails.value = val;
                      if (val && SettingsManager().settings.enableQuickTapback.value) {
                        SettingsManager().settings.enableQuickTapback.value = false;
                      }
                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.doubleTapForDetails.value,
                    title: "Double-${kIsWeb || kIsDesktop ? "Click" : "Tap"} Message for Details",
                    subtitle: "Opens the message details popup when double ${kIsWeb || kIsDesktop ? "click" : "tapp"}ing a message",
                    backgroundColor: tileColor,
                    isThreeLine: true,
                  )),
                  if (!kIsDesktop && !kIsWeb)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsDesktop && !kIsWeb)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.sendWithReturn.value = val;
                        saveSettings();
                      },
                      initialVal: SettingsManager().settings.sendWithReturn.value,
                      title: "Send Message with Enter",
                      backgroundColor: tileColor,
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
    SettingsManager().saveSettings();
  }
}

import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

class ChatListPanel extends StatelessWidget {
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: headerColor, // navigation bar color
        systemNavigationBarIconBrightness: headerColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
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
                  "Chat List",
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
                        child: Text("Indicators".psCapitalize,
                            style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                      )),
                  Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.showConnectionIndicator.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.showConnectionIndicator.value,
                        title: "Show Connection Indicator",
                        subtitle: "Enables a connection status indicator at the top left",
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
                          SettingsManager().settings.showSyncIndicator.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.showSyncIndicator.value,
                        title: "Show Sync Indicator in Chat List",
                        subtitle: "Enables a small indicator at the top left to show when the app is syncing messages",
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
                          SettingsManager().settings.colorblindMode.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.colorblindMode.value,
                        title: "Colorblind Mode",
                        subtitle: "Replaces the colored connection indicator with icons to aid accessibility",
                        backgroundColor: tileColor,
                      )),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Filtering"),
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.filteredChatList.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.filteredChatList.value,
                        title: "Filtered Chat List",
                        subtitle:
                            "Filters the chat list based on parameters set in iMessage (usually this removes old, inactive chats)",
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
                      SettingsManager().settings.filterUnknownSenders.value = val;
                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.filterUnknownSenders.value,
                    title: "Filter Unknown Senders",
                    subtitle:
                    "Turn off notifications for senders who aren't in your contacts and sort them into a separate chat list",
                    backgroundColor: tileColor,
                  )),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Appearance"),
                  Obx(() {
                    if (SettingsManager().settings.skin.value != Skins.Samsung)
                      return SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.hideDividers.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.hideDividers.value,
                        title: "Hide Dividers",
                        backgroundColor: tileColor,
                        subtitle: "Hides dividers between tiles",
                      );
                    else
                      return SizedBox.shrink();
                  }),
                  Obx(() {
                    if (SettingsManager().settings.skin.value != Skins.Samsung)
                      return Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      );
                    else
                      return SizedBox.shrink();
                  }),
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.denseChatTiles.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.denseChatTiles.value,
                        title: "Dense Conversation Tiles",
                        backgroundColor: tileColor,
                        subtitle: "Compresses chat tile size on the conversation list page",
                      )),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS)
                      return Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      );
                    else
                      return SizedBox.shrink();
                  }),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS)
                      return SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.reducedForehead.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.reducedForehead.value,
                        title: "Reduced Forehead",
                        backgroundColor: tileColor,
                        subtitle: "Reduces the appbar size on conversation pages",
                      );
                    else
                      return SizedBox.shrink();
                  }),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS)
                      return SettingsTile(
                        title: "Max Pin Rows",
                        subtitle:
                            "The maximum row count of pins displayed when using the app in the portrait orientation",
                        backgroundColor: tileColor,
                      );
                    else
                      return SizedBox.shrink();
                  }),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS)
                      return SettingsSlider(
                        min: 2,
                        max: 4,
                        divisions: 3,
                        update: (double val) {
                          SettingsManager().settings.pinRowsPortrait.value = val.toInt();
                          saveSettings();
                        },
                        startingVal: SettingsManager().settings.pinRowsPortrait.value.toDouble(),
                        text: "Maximum Pin Rows",
                        backgroundColor: tileColor,
                        formatValue: (val) =>
                            SettingsManager().settings.pinRowsPortrait.toString() +
                            " rows of " +
                            SettingsManager().settings.pinColumnsPortrait.toString(),
                      );
                    else
                      return SizedBox.shrink();
                  }),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS)
                      return Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      );
                    else
                      return SizedBox.shrink();
                  }),
                  // Obx(() {
                  //   if (SettingsManager().settings.skin.value == Skins.iOS)
                  //     return SettingsTile(
                  //       title: "Pinned Order",
                  //       subtitle:
                  //       "Set the order for your pinned chats",
                  //       backgroundColor: tileColor,
                  //       onTap: () {
                  //         Get.toNamed("/settings/pinned-order-panel");
                  //       },
                  //       trailing: Icon(
                  //         SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.chevron_right : Icons.arrow_forward,
                  //         color: Colors.grey,
                  //       ),
                  //     );
                  //   else
                  //     return SizedBox.shrink();
                  // }),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Swipe Actions"),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.Samsung ||
                        SettingsManager().settings.skin.value == Skins.Material)
                      return SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.swipableConversationTiles.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.swipableConversationTiles.value,
                        title: "Swipe Actions for Conversation Tiles",
                        subtitle: "Enables swipe actions for conversation tiles when using Material theme",
                        backgroundColor: tileColor,
                      );
                    else
                      return SizedBox.shrink();
                  }),
                  if (SettingsManager().settings.skin.value == Skins.iOS)
                    SettingsTile(
                      backgroundColor: tileColor,
                      title: "Customize Swipe Actions",
                      subtitle: "Enable or disable specific swipe actions",
                    ),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS)
                      return Container(
                        color: tileColor,
                        constraints: BoxConstraints(maxWidth: context.width),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15.0),
                          child: Row(
                            children: [
                              Column(children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text("Swipe Right"),
                                ),
                                Opacity(
                                  opacity: SettingsManager().settings.iosShowPin.value ? 1 : 0.7,
                                  child: Container(
                                    height: 60,
                                    width: context.width / 5 - 8,
                                    color: Colors.yellow[800],
                                    child: IconButton(
                                      icon: Icon(Icons.star, color: Colors.white),
                                      onPressed: () async {
                                        SettingsManager().settings.iosShowPin.value =
                                            !SettingsManager().settings.iosShowPin.value;
                                        saveSettings();
                                      },
                                    ),
                                  ),
                                ),
                                CupertinoButton(
                                    child: Container(
                                      decoration: BoxDecoration(
                                          color: SettingsManager().settings.iosShowPin.value
                                              ? Theme.of(context).primaryColor
                                              : tileColor,
                                          border: Border.all(
                                              color: SettingsManager().settings.iosShowPin.value
                                                  ? Theme.of(context).primaryColor
                                                  : CupertinoColors.systemGrey,
                                              style: BorderStyle.solid,
                                              width: 1),
                                          borderRadius: BorderRadius.all(Radius.circular(25))),
                                      child: Padding(
                                        padding: const EdgeInsets.all(3.0),
                                        child: Icon(CupertinoIcons.check_mark,
                                            size: 18,
                                            color: SettingsManager().settings.iosShowPin.value
                                                ? CupertinoColors.white
                                                : CupertinoColors.systemGrey),
                                      ),
                                    ),
                                    onPressed: () {
                                      SettingsManager().settings.iosShowPin.value =
                                          !SettingsManager().settings.iosShowPin.value;
                                      saveSettings();
                                    }),
                              ]),
                              Spacer(),
                              Column(children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text("Swipe Left"),
                                ),
                                Row(children: [
                                  Column(
                                    children: [
                                      Opacity(
                                        opacity: SettingsManager().settings.iosShowAlert.value ? 1 : 0.7,
                                        child: Container(
                                          height: 60,
                                          color: Colors.purple[700],
                                          width: context.width / 5 - 8,
                                          child: IconButton(
                                            icon: Icon(Icons.notifications_off, color: Colors.white),
                                            onPressed: () async {
                                              SettingsManager().settings.iosShowAlert.value =
                                                  !SettingsManager().settings.iosShowAlert.value;
                                              saveSettings();
                                            },
                                          ),
                                        ),
                                      ),
                                      CupertinoButton(
                                          child: Container(
                                            decoration: BoxDecoration(
                                                color: SettingsManager().settings.iosShowAlert.value
                                                    ? Theme.of(context).primaryColor
                                                    : tileColor,
                                                border: Border.all(
                                                    color: SettingsManager().settings.iosShowAlert.value
                                                        ? Theme.of(context).primaryColor
                                                        : CupertinoColors.systemGrey,
                                                    style: BorderStyle.solid,
                                                    width: 1),
                                                borderRadius: BorderRadius.all(Radius.circular(25))),
                                            child: Padding(
                                              padding: const EdgeInsets.all(3.0),
                                              child: Icon(CupertinoIcons.check_mark,
                                                  size: 18,
                                                  color: SettingsManager().settings.iosShowAlert.value
                                                      ? CupertinoColors.white
                                                      : CupertinoColors.systemGrey),
                                            ),
                                          ),
                                          onPressed: () {
                                            SettingsManager().settings.iosShowAlert.value =
                                                !SettingsManager().settings.iosShowAlert.value;
                                            saveSettings();
                                          }),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Opacity(
                                        opacity: SettingsManager().settings.iosShowDelete.value ? 1 : 0.7,
                                        child: Container(
                                          height: 60,
                                          color: Colors.red,
                                          width: context.width / 5 - 8,
                                          child: IconButton(
                                            icon: Icon(Icons.delete_forever, color: Colors.white),
                                            onPressed: () async {
                                              SettingsManager().settings.iosShowDelete.value =
                                                  !SettingsManager().settings.iosShowDelete.value;
                                              saveSettings();
                                            },
                                          ),
                                        ),
                                      ),
                                      CupertinoButton(
                                          child: Container(
                                            decoration: BoxDecoration(
                                                color: SettingsManager().settings.iosShowDelete.value
                                                    ? Theme.of(context).primaryColor
                                                    : tileColor,
                                                border: Border.all(
                                                    color: SettingsManager().settings.iosShowDelete.value
                                                        ? Theme.of(context).primaryColor
                                                        : CupertinoColors.systemGrey,
                                                    style: BorderStyle.solid,
                                                    width: 1),
                                                borderRadius: BorderRadius.all(Radius.circular(25))),
                                            child: Padding(
                                              padding: const EdgeInsets.all(3.0),
                                              child: Icon(CupertinoIcons.check_mark,
                                                  size: 18,
                                                  color: SettingsManager().settings.iosShowDelete.value
                                                      ? CupertinoColors.white
                                                      : CupertinoColors.systemGrey),
                                            ),
                                          ),
                                          onPressed: () {
                                            SettingsManager().settings.iosShowDelete.value =
                                                !SettingsManager().settings.iosShowDelete.value;
                                            saveSettings();
                                          }),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Opacity(
                                        opacity: SettingsManager().settings.iosShowMarkRead.value ? 1 : 0.7,
                                        child: Container(
                                          height: 60,
                                          color: Colors.blue,
                                          width: context.width / 5 - 8,
                                          child: IconButton(
                                            icon: Icon(Icons.mark_chat_read, color: Colors.white),
                                            onPressed: () {
                                              SettingsManager().settings.iosShowMarkRead.value =
                                                  !SettingsManager().settings.iosShowMarkRead.value;
                                              saveSettings();
                                              saveSettings();
                                            },
                                          ),
                                        ),
                                      ),
                                      CupertinoButton(
                                          child: Container(
                                            decoration: BoxDecoration(
                                                color: SettingsManager().settings.iosShowMarkRead.value
                                                    ? Theme.of(context).primaryColor
                                                    : tileColor,
                                                border: Border.all(
                                                    color: SettingsManager().settings.iosShowMarkRead.value
                                                        ? Theme.of(context).primaryColor
                                                        : CupertinoColors.systemGrey,
                                                    style: BorderStyle.solid,
                                                    width: 1),
                                                borderRadius: BorderRadius.all(Radius.circular(25))),
                                            child: Padding(
                                              padding: const EdgeInsets.all(3.0),
                                              child: Icon(CupertinoIcons.check_mark,
                                                  size: 18,
                                                  color: SettingsManager().settings.iosShowMarkRead.value
                                                      ? CupertinoColors.white
                                                      : CupertinoColors.systemGrey),
                                            ),
                                          ),
                                          onPressed: () {
                                            SettingsManager().settings.iosShowMarkRead.value =
                                                !SettingsManager().settings.iosShowMarkRead.value;
                                            saveSettings();
                                          }),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Opacity(
                                        opacity: SettingsManager().settings.iosShowArchive.value ? 1 : 0.7,
                                        child: Container(
                                          height: 60,
                                          color: Colors.red,
                                          width: context.width / 5 - 8,
                                          child: IconButton(
                                            icon: Icon(SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.tray_arrow_down : Icons.archive, color: Colors.white),
                                            onPressed: () {
                                              SettingsManager().settings.iosShowArchive.value =
                                                  !SettingsManager().settings.iosShowArchive.value;
                                              saveSettings();
                                            },
                                          ),
                                        ),
                                      ),
                                      CupertinoButton(
                                          child: Container(
                                            decoration: BoxDecoration(
                                                color: SettingsManager().settings.iosShowArchive.value
                                                    ? Theme.of(context).primaryColor
                                                    : tileColor,
                                                border: Border.all(
                                                    color: SettingsManager().settings.iosShowArchive.value
                                                        ? Theme.of(context).primaryColor
                                                        : CupertinoColors.systemGrey,
                                                    style: BorderStyle.solid,
                                                    width: 1),
                                                borderRadius: BorderRadius.all(Radius.circular(25))),
                                            child: Padding(
                                              padding: const EdgeInsets.all(3.0),
                                              child: Icon(CupertinoIcons.check_mark,
                                                  size: 18,
                                                  color: SettingsManager().settings.iosShowArchive.value
                                                      ? CupertinoColors.white
                                                      : CupertinoColors.systemGrey),
                                            ),
                                          ),
                                          onPressed: () {
                                            SettingsManager().settings.iosShowArchive.value =
                                                !SettingsManager().settings.iosShowArchive.value;
                                            saveSettings();
                                          }),
                                    ],
                                  ),
                                ]),
                              ]),
                            ],
                          ),
                        ),
                      );
                    else if (SettingsManager().settings.swipableConversationTiles.value)
                      return Container(
                        color: tileColor,
                        child: Column(
                          children: [
                            SettingsOptions<MaterialSwipeAction>(
                              initial: SettingsManager().settings.materialRightAction.value,
                              onChanged: (val) {
                                if (val != null) {
                                  SettingsManager().settings.materialRightAction.value = val;
                                  saveSettings();
                                }
                              },
                              options: MaterialSwipeAction.values,
                              textProcessing: (val) =>
                                  val.toString().split(".")[1].replaceAll("_", " ").capitalizeFirst!,
                              title: "Swipe Right Action",
                              backgroundColor: tileColor,
                              secondaryColor: headerColor,
                            ),
                            SettingsOptions<MaterialSwipeAction>(
                              initial: SettingsManager().settings.materialLeftAction.value,
                              onChanged: (val) {
                                if (val != null) {
                                  SettingsManager().settings.materialLeftAction.value = val;
                                  saveSettings();
                                }
                              },
                              options: MaterialSwipeAction.values,
                              textProcessing: (val) =>
                                  val.toString().split(".")[1].replaceAll("_", " ").capitalizeFirst!,
                              title: "Swipe Left Action",
                              backgroundColor: tileColor,
                              secondaryColor: headerColor,
                            ),
                          ],
                        ),
                      );
                    else
                      return SizedBox.shrink();
                  }),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Misc"),
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.moveChatCreatorToHeader.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.moveChatCreatorToHeader.value,
                        title: "Move Chat Creator Button to Header",
                        subtitle: "Replaces the floating button at the bottom to a fixed button at the top",
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
                          SettingsManager().settings.notifyOnChatList.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.notifyOnChatList.value,
                        title: "Send Notifications on Chat List",
                        subtitle: "Sends notifications for new messages while in the chat list or chat creator",
                        backgroundColor: tileColor,
                      )),
                  Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
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
      ),
    );
  }

  void saveSettings() {
    SettingsManager().saveSettings(SettingsManager().settings);
  }
}

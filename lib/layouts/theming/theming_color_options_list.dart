import 'dart:async';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/theming/theming_color_selector.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/theme_object.dart';
import 'package:get/get.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ThemingColorOptionsList extends StatefulWidget {
  ThemingColorOptionsList({Key? key, required this.isDarkMode, required this.controller}) : super(key: key);
  final bool isDarkMode;
  final StreamController controller;

  @override
  _ThemingColorOptionsListState createState() => _ThemingColorOptionsListState();
}

class _ThemingColorOptionsListState extends State<ThemingColorOptionsList> {
  ThemeObject? currentTheme;
  List<ThemeObject> allThemes = [];
  bool editable = false;

  @override
  void initState() {
    super.initState();
    widget.controller.stream.listen((event) {
      if (!currentTheme!.isPreset) {
        showSnackbar('Customization', "Click on an item to customize");
        return;
      }

      BuildContext _context = context;
      showDialog(
        context: context,
        builder: (context) => NewThemeCreateAlert(
          onCreate: (String name) async {
            Navigator.of(context).pop();
            ThemeObject newTheme = new ThemeObject(data: currentTheme!.themeData, name: name);
            allThemes.add(newTheme);
            currentTheme = newTheme;
            if (widget.isDarkMode) {
              await SettingsManager().saveSelectedTheme(_context, selectedDarkTheme: currentTheme);
            } else {
              await SettingsManager().saveSelectedTheme(_context, selectedLightTheme: currentTheme);
            }
            setState(() {});
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        ),
      );
      // }
    });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    if (widget.isDarkMode) {
      currentTheme = await ThemeObject.getDarkTheme();
    } else {
      currentTheme = await ThemeObject.getLightTheme();
    }
    await currentTheme!.fetchData();

    allThemes = await ThemeObject.getThemes();
    for (ThemeObject theme in allThemes) {
      await theme.fetchData();
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    editable = currentTheme != null && !currentTheme!.isPreset;
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
    return currentTheme != null
        ? CustomScrollView(
            physics: ThemeSwitcher.getScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                  child: Container(
                    child: Text(
                      widget.isDarkMode ? "Dark Theme" : "Light Theme",
                      style: Theme.of(context).textTheme.headline1,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        width: context.width - 16,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5.0),
                            color: headerColor,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<ThemeObject>(
                            dropdownColor: tileColor,
                            items: allThemes
                                .map(
                                  (e) => DropdownMenuItem(
                                    child: Text(
                                      e.name!.toUpperCase().replaceAll("_", " "),
                                      style: Theme.of(context).textTheme.bodyText1,
                                    ),
                                    value: e,
                                  ),
                                )
                                .toList(),
                            onChanged: (value) async {
                              value!.data = value.themeData;
                              await value.save();

                              if (widget.isDarkMode) {
                                SettingsManager().saveSelectedTheme(context, selectedDarkTheme: value);
                              } else {
                                SettingsManager().saveSelectedTheme(context, selectedLightTheme: value);
                              }
                              currentTheme = value;
                              editable = currentTheme != null && !currentTheme!.isPreset;
                              setState(() {});

                              EventDispatcher.instance.emit('theme-update', null);
                            },
                            value: currentTheme,
                            hint: Text(
                              "Preset",
                              style: Theme.of(context).textTheme.bodyText1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return ThemingColorSelector(
                      currentTheme: currentTheme!,
                      entry: currentTheme!.entries[index],
                      editable: editable,
                    );
                  },
                  childCount: ThemeColors.Colors.length, // ThemeColors.values.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                ),
              ),
              if (!currentTheme!.isPreset)
                SliverToBoxAdapter(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Theme.of(context).accentColor,
                    ),
                    child: Text(
                      "Delete",
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: () async {
                      allThemes.removeWhere((element) => element == this.currentTheme);
                      await this.currentTheme!.delete();
                      this.currentTheme =
                          widget.isDarkMode ? await ThemeObject.getDarkTheme() : await ThemeObject.getLightTheme();
                      allThemes = await ThemeObject.getThemes();
                      if (widget.isDarkMode) {
                        await SettingsManager().saveSelectedTheme(context, selectedDarkTheme: currentTheme);
                      } else {
                        await SettingsManager().saveSelectedTheme(context, selectedLightTheme: currentTheme);
                      }
                      setState(() {});
                    },
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.all(25),
              ),
            ],
          )
        : Center(
            child: LinearProgressIndicator(
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          );
  }
}

class NewThemeCreateAlert extends StatefulWidget {
  NewThemeCreateAlert({Key? key, required this.onCreate, required this.onCancel}) : super(key: key);
  final Function(String name) onCreate;
  final Function() onCancel;

  @override
  _NewThemeCreateAlertState createState() => _NewThemeCreateAlertState();
}

class _NewThemeCreateAlertState extends State<NewThemeCreateAlert> {
  TextEditingController controller = TextEditingController();
  bool showError = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actions: [
        TextButton(
          child: Text("OK"),
          onPressed: () async {
            if ((await ThemeObject.findOne({"name": controller.text})) != null || controller.text.isEmpty) {
              setState(() {
                showError = true;
              });
            } else {
              widget.onCreate(controller.text);
            }
          },
        ),
        TextButton(
          child: Text("Cancel"),
          onPressed: widget.onCancel,
        )
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: "Theme Name",
              border: OutlineInputBorder(),
            ),
          ),
          if (showError)
            Text(
              "Please select a name of a theme that has not already been used",
              style: TextStyle(color: Colors.red, fontSize: 14),
            )
        ],
      ),
      title: Text("Create a New Theme"),
    );
  }
}

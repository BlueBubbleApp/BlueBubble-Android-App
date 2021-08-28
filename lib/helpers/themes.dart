import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/repository/models/theme_object.dart';
import 'package:flutter/material.dart';

class Themes {
  /// List the default themes
  static List<ThemeObject> get themes => [
        ThemeObject.fromData(oledDarkTheme, "OLED Dark"),
        ThemeObject.fromData(whiteLightTheme, "Bright White"),
        ThemeObject.fromData(nordDarkTheme, "Nord Theme"),
      ];
}

/// Rough check if 2 themes are equal by comparing [accentColor] and [backgroundColor]
bool isEqual(ThemeData one, ThemeData two) {
  return one.accentColor == two.accentColor
      && one.backgroundColor == two.backgroundColor;
}

ThemeData oledDarkTheme = ThemeData(
  primarySwatch: Colors.blue,
  splashFactory: InkRipple.splashFactory,
  textTheme: TextTheme(
    headline1: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.normal,
      fontSize: 18,
    ),
    headline2: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.normal,
      fontSize: 14,
    ),
    bodyText1: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.normal,
      fontSize: 15,
    ),
    bodyText2: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.normal,
      fontSize: 15,
    ),
    subtitle1: TextStyle(
      color: HexColor('919191'),
      fontSize: 14,
      fontWeight: FontWeight.normal,
    ),
    subtitle2: TextStyle(
      color: HexColor('7d7d7d'),
      fontSize: 11,
      fontWeight: FontWeight.normal,
    ),
  ),
  accentColor: HexColor('26262a'),
  dividerColor: HexColor('27272a'),
  buttonColor: HexColor("666666"),
  backgroundColor: Colors.black,
  splashColor: Colors.white.withOpacity(0.35),
);

ThemeData nordDarkTheme = ThemeData(
  primarySwatch: Colors.blue,
  splashFactory: InkRipple.splashFactory,
  textTheme: TextTheme(
    headline1: TextStyle(
      color: HexColor('ECEFF4'),
      fontWeight: FontWeight.normal,
      fontSize: 18,
    ),
    headline2: TextStyle(
      color: HexColor('E5E9F0'),
      fontWeight: FontWeight.normal,
      fontSize: 14,
    ),
    bodyText1: TextStyle(
      color: HexColor('ECEFF4'),
      fontWeight: FontWeight.normal,
      fontSize: 15,
    ),
    bodyText2: TextStyle(
      color: HexColor('E5E9F0'),
      fontWeight: FontWeight.normal,
      fontSize: 15,
    ),
    subtitle1: TextStyle(
      color: HexColor('a5a5a5'),
      fontSize: 14,
      fontWeight: FontWeight.normal,
    ),
    subtitle2: TextStyle(
      color: HexColor('b9b9b9'),
      fontSize: 11,
      fontWeight: FontWeight.normal,
    ),
  ),
  accentColor: HexColor('4C566A'),
  dividerColor: HexColor('4C566A'),
  buttonColor: HexColor("4C566A"),
  backgroundColor: HexColor('2E3440'),
  splashColor: Colors.white.withOpacity(0.35),
);

ThemeData whiteLightTheme = ThemeData(
  primarySwatch: Colors.blue,
  splashFactory: InkRipple.splashFactory,
  textTheme: TextTheme(
    headline1: TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.normal,
      fontSize: 18,
    ),
    headline2: TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.normal,
      fontSize: 14,
    ),
    bodyText1: TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.normal,
      fontSize: 15,
    ),
    bodyText2: TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.normal,
      fontSize: 15,
    ),
    subtitle1: TextStyle(
      color: HexColor('9a9a9f'),
      fontSize: 14,
      fontWeight: FontWeight.normal,
    ),
    subtitle2: TextStyle(
      color: HexColor('9a9a9f'),
      fontSize: 11,
      fontWeight: FontWeight.normal,
    ),
  ),
  accentColor: HexColor('e5e5ea'),
  dividerColor: HexColor('e5e5ea').withOpacity(0.5),
  backgroundColor: Colors.white,
);

/// Set the current dark and light themes
Future<void> loadTheme(BuildContext context, {ThemeObject? lightOverride, ThemeObject? darkOverride}) async {
  // Set the theme to match those of the settings
  ThemeObject light = lightOverride ?? await ThemeObject.getLightTheme();
  ThemeObject dark = darkOverride ?? await ThemeObject.getDarkTheme();
  AdaptiveTheme.of(context).setTheme(
    light: light.themeData,
    dark: dark.themeData,
  );
}

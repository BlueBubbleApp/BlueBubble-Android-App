import 'dart:async';

import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/theme_object.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class ThemeEntry {
  int? id;
  int? themeId;
  String? name;
  Color? color;
  bool? isFont;
  int? fontSize;

  ThemeEntry({
    this.id,
    this.themeId,
    this.name,
    this.color,
    this.isFont,
    this.fontSize,
  });

  factory ThemeEntry.fromMap(Map<String, dynamic> json) {
    return ThemeEntry(
      id: json["ROWID"],
      themeId: json["themeId"],
      name: json["name"],
      color: HexColor(json["color"]),
      isFont: json["isFont"] == 1,
      fontSize: json["fontSize"],
    );
  }

  factory ThemeEntry.fromStyle(String title, TextStyle style) {
    return ThemeEntry(
      color: style.color,
      name: title,
      isFont: true,
      fontSize: style.fontSize != null ? style.fontSize!.toInt() : 14,
    );
  }

  dynamic get style => isFont!
      ? TextStyle(
          color: this.color,
          fontWeight: FontWeight.normal,
          fontSize: fontSize?.toDouble() ?? null,
        )
      : color;

  Future<ThemeEntry> save(ThemeObject theme, {bool updateIfAbsent = true}) async {
    final Database db = await DBProvider.db.database;

    assert(theme.id != null);
    this.themeId = theme.id;

    // Try to find an existing ConfigEntry before saving it
    ThemeEntry? existing = await ThemeEntry.findOne({"name": this.name, "themeId": this.themeId});
    if (existing != null) {
      this.id = existing.id;
    }

    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      var map = this.toMap();
      map.remove("ROWID");
      try {
        this.id = await db.insert("theme_values", map);
      } catch (e) {
        this.id = null;
      }

      if (this.id != null && theme.id != null) {
        await db.insert("theme_value_join", {"themeValueId": this.id, "themeId": theme.id});
      }
    } else if (updateIfAbsent) {
      await this.update(theme);
    }

    return this;
  }

  Future<ThemeEntry> update(ThemeObject theme) async {
    final Database db = await DBProvider.db.database;
    await db.update(
        "theme_values",
        {
          "name": this.name,
          "color": this.color!.value.toRadixString(16),
          "isFont": this.isFont! ? 1 : 0,
          "fontSize": this.fontSize,
        },
        where: "ROWID = ?",
        whereArgs: [this.id]);
    return this;
  }

  static Future<ThemeEntry?> findOne(Map<String, dynamic> filters, {Database? database}) async {
    final Database db = database != null ? database : await DBProvider.db.database;

    List<String> whereParams = [];
    filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    filters.values.forEach((filter) => whereArgs.add(filter));
    var res = await db.query("theme_values", where: whereParams.join(" AND "), whereArgs: whereArgs, limit: 1);

    if (res.isEmpty) {
      return null;
    }

    return ThemeEntry.fromMap(res.first);
  }

  Map<String, dynamic> toMap() => {
        "ROWID": this.id,
        "name": this.name,
        "themeId": this.themeId,
        "color": this.color!.value.toRadixString(16),
        "isFont": this.isFont! ? 1 : 0,
        "fontSize": this.fontSize,
      };
}

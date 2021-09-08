import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/repository/models/theme_object.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

enum Tables {
  chat,
  handle,
  message,
  attachment,
  chat_handle_join,
  chat_message_join,
  attachment_message_join,
  themes,
  theme_values,
  theme_value_join,
  config,
  fcm,
  scheduled
}

class DBUpgradeItem {
  int addedInVersion;
  Function(Database) upgrade;

  DBUpgradeItem({required this.addedInVersion, required this.upgrade});
}

class DBProvider {
  DBProvider._();
  static final DBProvider db = DBProvider._();

  static Database? _database;
  static String _path = "";
  static int currentVersion = 14;

  /// Contains list of functions to invoke when going from a previous to the current database verison
  /// The previous version is always [key - 1], for example for key 2, it will be the upgrade scheme from version 1 to version 2
  static final List<DBUpgradeItem> upgradeSchemes = [
    new DBUpgradeItem(
        addedInVersion: 2,
        upgrade: (Database db) {
          db.execute("ALTER TABLE message ADD COLUMN hasDdResults INTEGER DEFAULT 0;");
        }),
    new DBUpgradeItem(
        addedInVersion: 3,
        upgrade: (Database db) {
          db.execute("ALTER TABLE message ADD COLUMN balloonBundleId TEXT DEFAULT NULL;");
          db.execute("ALTER TABLE chat ADD COLUMN isFiltered INTEGER DEFAULT 0;");
        }),
    new DBUpgradeItem(
        addedInVersion: 4,
        upgrade: (Database db) {
          db.execute("ALTER TABLE message ADD COLUMN dateDeleted INTEGER DEFAULT NULL;");
          db.execute("ALTER TABLE chat ADD COLUMN isPinned INTEGER DEFAULT 0;");
        }),
    new DBUpgradeItem(
        addedInVersion: 5,
        upgrade: (Database db) {
          db.execute("ALTER TABLE handle ADD COLUMN originalROWID INTEGER DEFAULT NULL;");
          db.execute("ALTER TABLE chat ADD COLUMN originalROWID INTEGER DEFAULT NULL;");
          db.execute("ALTER TABLE attachment ADD COLUMN originalROWID INTEGER DEFAULT NULL;");
          db.execute("ALTER TABLE message ADD COLUMN otherHandle INTEGER DEFAULT NULL;");
        }),
    new DBUpgradeItem(
        addedInVersion: 6,
        upgrade: (Database db) {
          db.execute("ALTER TABLE attachment ADD COLUMN metadata TEXT DEFAULT NULL;");
        }),
    new DBUpgradeItem(
        addedInVersion: 7,
        upgrade: (Database db) {
          db.execute("ALTER TABLE message ADD COLUMN metadata TEXT DEFAULT NULL;");
        }),
    new DBUpgradeItem(
        addedInVersion: 8,
        upgrade: (Database db) {
          db.execute("ALTER TABLE handle ADD COLUMN color TEXT DEFAULT NULL;");
        }),
    new DBUpgradeItem(
        addedInVersion: 9,
        upgrade: (Database db) {
          db.execute("ALTER TABLE handle ADD COLUMN defaultPhone TEXT DEFAULT NULL;");
        }),
    new DBUpgradeItem(
        addedInVersion: 10,
        upgrade: (Database db) {
          db.execute("ALTER TABLE chat ADD COLUMN customAvatarPath TEXT DEFAULT NULL;");
        }),
    new DBUpgradeItem(
        addedInVersion: 11,
        upgrade: (Database db) {
          db.execute("ALTER TABLE chat ADD COLUMN pinIndex INTEGER DEFAULT NULL;");
        }),
    new DBUpgradeItem(
        addedInVersion: 12,
        upgrade: (Database db) async {
          db.execute("ALTER TABLE chat ADD COLUMN muteType TEXT DEFAULT NULL;");
          db.execute("ALTER TABLE chat ADD COLUMN muteArgs TEXT DEFAULT NULL;");
          await db.update("chat", {'muteType': 'mute'}, where: "isMuted = ?", whereArgs: [1]);
        }),
    new DBUpgradeItem(
        addedInVersion: 13,
        upgrade: (Database db) {
          db.execute("ALTER TABLE themes ADD COLUMN gradientBg INTEGER DEFAULT 0;");
        }),
    new DBUpgradeItem(
        addedInVersion: 14,
        upgrade: (Database db) async {
          db.execute("ALTER TABLE themes ADD COLUMN previousLightTheme INTEGER DEFAULT 0;");
          db.execute("ALTER TABLE themes ADD COLUMN previousDarkTheme INTEGER DEFAULT 0;");
          Settings s = await Settings.getSettingsOld(db);
          s.save();
          db.execute("DELETE FROM config");
        }),
  ];

  Future<Database> get database async {
    if (_database != null) return _database!;

    // if _database is null we instantiate it
    _database = await initDB();
    return _database!;
  }

  String get path => _path;

  Future<Database> initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    _path = join(documentsDirectory.path, "chat.db");
    return await openDatabase(_path, version: currentVersion, onUpgrade: _onUpgrade, onOpen: (Database db) async {
      Logger.info("Database Opened");
      _database = db;
      await checkTableExistenceAndCreate(db);
      _database = null;
    }, onCreate: (Database db, int version) async {
      Logger.info("creating database");
      _database = db;
      await this.buildDatabase(db);
      _database = null;
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Run each upgrade scheme for every difference in version.
    // If the user is on version 1 and they need to upgrade to version 3,
    // then we will run every single scheme from 1 -> 2 and 2 -> 3

    for (DBUpgradeItem item in upgradeSchemes) {
      if (oldVersion < item.addedInVersion) {
        Logger.info("Upgrading DB from version $oldVersion to version $newVersion");

        try {
          await item.upgrade(db);
        } catch (ex) {
          Logger.error("Failed to perform DB upgrade: ${ex.toString()}");
        }
      }
    }
  }

  static Future<void> deleteDB() async {
    Database db = await DBProvider.db.database;
    // Remove base tables
    await Handle.flush();
    await Chat.flush();
    await Attachment.flush();
    await Message.flush();

    // Remove join tables
    await db.execute("DELETE FROM chat_handle_join");
    await db.execute("DELETE FROM chat_message_join");
    await db.execute("DELETE FROM attachment_message_join");
  }

  Future<void> checkTableExistenceAndCreate(Database db) async {
    //this is to ensure that all tables are created on start
    //this will allow us to also add more tables and make it so that users will not have to
    for (Tables tableName in Tables.values) {
      var table = await db.rawQuery(
          "SELECT * FROM sqlite_master WHERE name ='${tableName.toString().split(".").last}' and type='table'; ");
      if (table.isEmpty) {
        switch (tableName) {
          case Tables.chat:
            await createChatTable(db);
            break;
          case Tables.handle:
            await createHandleTable(db);
            break;
          case Tables.message:
            await createMessageTable(db);
            break;
          case Tables.attachment:
            await createAttachmentTable(db);
            break;
          case Tables.chat_handle_join:
            await createChatHandleJoinTable(db);
            break;
          case Tables.chat_message_join:
            await createChatMessageJoinTable(db);
            break;
          case Tables.attachment_message_join:
            await createAttachmentMessageJoinTable(db);
            break;
          case Tables.themes:
            await createThemeTable(db);
            break;
          case Tables.theme_values:
            await createThemeValuesTable(db);
            break;
          case Tables.theme_value_join:
            await createThemeValueJoin(db);
            break;
          case Tables.config:
            await createConfigTable(db);
            break;
          case Tables.fcm:
            await createFCMTable(db);
            break;
          case Tables.scheduled:
            await createScheduledTable(db);
            break;
        }

        Logger.info("Creating missing table " + tableName.toString().split(".").last);
      }
    }
  }

  Future<void> buildDatabase(Database db) async {
    await createHandleTable(db);
    await createChatTable(db);
    await createMessageTable(db);
    await createAttachmentTable(db);
    await createAttachmentMessageJoinTable(db);
    await createChatHandleJoinTable(db);
    await createChatMessageJoinTable(db);
    await createIndexes(db);
    await createConfigTable(db);
    await createFCMTable(db);
    await createThemeTable(db);
    await createThemeValuesTable(db);
    await createThemeValueJoin(db);
    await createScheduledTable(db);
  }

  static Future<void> createHandleTable(Database db) async {
    await db.execute("CREATE TABLE handle ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "originalROWID INTEGER DEFAULT NULL,"
        "address TEXT UNIQUE NOT NULL,"
        "country TEXT DEFAULT NULL,"
        "color TEXT DEFAULT NULL,"
        "defaultPhone TEXT DEFAULT NULL,"
        "uncanonicalizedId TEXT DEFAULT NULL"
        ");");
  }

  static Future<void> createChatTable(Database db) async {
    await db.execute("CREATE TABLE chat ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "originalROWID INTEGER DEFAULT NULL,"
        "guid TEXT UNIQUE NOT NULL,"
        "style INTEGER NOT NULL,"
        "chatIdentifier TEXT NOT NULL,"
        "isArchived INTEGER DEFAULT 0,"
        "isFiltered INTEGER DEFAULT 0,"
        "isPinned INTEGER DEFAULT 0,"
        "muteType TEXT DEFAULT NULL,"
        "muteArgs TEXT DEFAULT NULL,"
        "hasUnreadMessage INTEGER DEFAULT 0,"
        "latestMessageDate INTEGER DEFAULT 0,"
        "latestMessageText TEXT,"
        "displayName TEXT DEFAULT NULL,"
        "customAvatarPath TEXT DEFAULT NULL,"
        "pinIndex INTEGER DEFAULT NULL"
        ");");
  }

  static Future<void> createMessageTable(Database db) async {
    await db.execute("CREATE TABLE message ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "originalROWID INTEGER DEFAULT NULL,"
        "handleId INTEGER NOT NULL,"
        "otherHandle INTEGER DEFAULT NULL,"
        "guid TEXT UNIQUE NOT NULL,"
        "text TEXT,"
        "subject TEXT DEFAULT NULL,"
        "country TEXT DEFAULT NULL,"
        "error INTEGER DEFAULT 0,"
        "dateCreated INTEGER,"
        "dateRead INTEGER DEFAULT 0,"
        "dateDelivered INTEGER DEFAULT 0,"
        "isFromMe INTEGER DEFAULT 0,"
        "isDelayed INTEGER DEFAULT 0,"
        "isAutoReply INTEGER DEFAULT 0,"
        "isSystemMessage INTEGER DEFAULT 0,"
        "isServiceMessage INTEGER DEFAULT 0,"
        "isForward INTEGER DEFAULT 0,"
        "isArchived INTEGER DEFAULT 0,"
        "hasDdResults INTEGER DEFAULT 0,"
        "cacheRoomnames TEXT DEFAULT NULL,"
        "isAudioMessage INTEGER DEFAULT 0,"
        "datePlayed INTEGER DEFAULT 0,"
        "itemType INTEGER NOT NULL,"
        "groupTitle TEXT DEFAULT NULL,"
        "groupActionType INTEGER DEFAULT 0,"
        "isExpired INTEGER DEFAULT 0,"
        "balloonBundleId INTEGER DEFAULT NULL,"
        "associatedMessageGuid TEXT DEFAULT NULL,"
        "associatedMessageType TEXT DEFAULT NULL,"
        "expressiveSendStyleId TEXT DEFAULT NULL,"
        "timeExpressiveSendStyleId INTEGER DEFAULT 0,"
        "hasAttachments INTEGER DEFAULT 0,"
        "hasReactions INTEGER DEFAULT 0,"
        "metadata TEXT DEFAULT NULL,"
        "dateDeleted INTEGER DEFAULT NULL,"
        "FOREIGN KEY(handleId) REFERENCES handle(ROWID)"
        ");");
  }

  static Future<void> createAttachmentTable(Database db) async {
    await db.execute("CREATE TABLE attachment ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "originalROWID INTEGER DEFAULT NULL,"
        "guid TEXT UNIQUE NOT NULL,"
        "uti TEXT NOT NULL,"
        "mimeType TEXT DEFAULT NULL,"
        "transferState INTEGER DEFAULT 0,"
        "isOutgoing INTEGER DEFAULT 0,"
        "transferName INTEGER NOT NULL,"
        "totalBytes INTEGER NOT NULL,"
        "isSticker INTEGER DEFAULT 0,"
        "hideAttachment INTEGER DEFAULT 0,"
        "blurhash VARCHAR(64) DEFAULT NULL,"
        "height INTEGER DEFAULT NULL,"
        "width INTEGER DEFAULT NULL,"
        "metadata TEXT DEFAULT NULL"
        ");");
  }

  static Future<void> createChatHandleJoinTable(Database db) async {
    await db.execute("CREATE TABLE chat_handle_join ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "chatId INTEGER NOT NULL,"
        "handleId INTEGER NOT NULL,"
        "FOREIGN KEY(chatId) REFERENCES chat(ROWID),"
        "FOREIGN KEY(handleId) REFERENCES handle(ROWID),"
        "UNIQUE (chatId, handleId)"
        ");");
  }

  static Future<void> createChatMessageJoinTable(Database db) async {
    await db.execute("CREATE TABLE chat_message_join ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "chatId INTEGER NOT NULL,"
        "messageId INTEGER NOT NULL,"
        "FOREIGN KEY(chatId) REFERENCES chat(ROWID),"
        "FOREIGN KEY(messageId) REFERENCES message(ROWID),"
        "UNIQUE (chatId, messageId)"
        ");");
  }

  static Future<void> createAttachmentMessageJoinTable(Database db) async {
    await db.execute("CREATE TABLE attachment_message_join ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "attachmentId INTEGER NOT NULL,"
        "messageId INTEGER NOT NULL,"
        "FOREIGN KEY(attachmentId) REFERENCES attachment(ROWID),"
        "FOREIGN KEY(messageId) REFERENCES message(ROWID),"
        "UNIQUE (attachmentId, messageId)"
        ");");
  }

  static Future<void> createIndexes(Database db) async {
    await db.execute("CREATE UNIQUE INDEX idx_handle_address ON handle (address);");
    await db.execute("CREATE UNIQUE INDEX idx_message_guid ON message (guid);");
    await db.execute("CREATE UNIQUE INDEX idx_chat_guid ON chat (guid);");
    await db.execute("CREATE UNIQUE INDEX idx_attachment_guid ON attachment (guid);");
  }

  static Future<void> createConfigTable(Database db) async {
    await db.execute("CREATE TABLE config ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "name TEXT,"
        "value TEXT,"
        "type TEXT NOT NULL"
        ");");
  }

  static Future<void> createFCMTable(Database db) async {
    await db.execute("CREATE TABLE fcm ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "name TEXT,"
        "value TEXT,"
        "type TEXT NOT NULL"
        ");");
  }

  static Future<void> createThemeValuesTable(Database db) async {
    await db.execute("CREATE TABLE theme_values ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "themeId INTEGER NOT NULL,"
        "name TEXT NOT NULL,"
        "color TEXT NOT NULL,"
        "isFont INTEGER DEFAULT 0,"
        "fontSize INTEGER"
        ");");
  }

  static Future<void> createThemeTable(Database db) async {
    await db.execute("CREATE TABLE themes ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "name TEXT UNIQUE,"
        "selectedLightTheme INTEGER DEFAULT 0,"
        "selectedDarkTheme INTEGER DEFAULT 0,"
        "gradientBg INTEGER DEFAULT 0,"
        "previousLightTheme INTEGER DEFAULT 0,"
        "previousDarkTheme INTEGER DEFAULT 0"
        ");");
  }

  static Future<void> createThemeValueJoin(Database db) async {
    await db.execute("CREATE TABLE theme_value_join ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "themeId INTEGER NOT NULL,"
        "themeValueId INTEGER NOT NULL,"
        "FOREIGN KEY(themeId) REFERENCES theme_values(ROWID),"
        "FOREIGN KEY(themeValueId) REFERENCES themes(ROWID),"
        "UNIQUE (themeId, themeValueId)"
        ");");
  }

  static Future<void> createScheduledTable(Database db) async {
    await db.execute("CREATE TABLE scheduled ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "chatGuid TEXT NOT NULL,"
        "message TEXT NOT NULL,"
        "epochTime INTEGER NOT NULL,"
        "completed INTEGER DEFAULT 0,"
        "UNIQUE (chatGuid, message, epochTime)"
        ");");
  }

  static Future<void> setupConfigRows() async {
    for (ThemeObject theme in Themes.themes) {
      await theme.save(updateIfAbsent: false);
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart' as crypto;

import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:get/get.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/utils.dart';
import '../database.dart';
import 'chat.dart';
import 'handle.dart';

Message messageFromJson(String str) {
  final jsonData = json.decode(str);
  return Message.fromMap(jsonData);
}

String messageToJson(Message data) {
  final dyn = data.toMap();
  return json.encode(dyn);
}

class Message {
  int? id;
  int? originalROWID;
  String? guid;
  int? handleId;
  int? otherHandle;
  String? text;
  String? subject;
  String? country;
  final RxInt error = RxInt(0);
  DateTime? dateCreated;
  DateTime? dateRead;
  DateTime? dateDelivered;
  bool? isFromMe;
  bool? isDelayed;
  bool? isAutoReply;
  bool? isSystemMessage;
  bool? isServiceMessage;
  bool? isForward;
  bool? isArchived;
  bool? hasDdResults;
  String? cacheRoomnames;
  bool? isAudioMessage;
  DateTime? datePlayed;
  int? itemType;
  String? groupTitle;
  int? groupActionType;
  bool? isExpired;
  String? balloonBundleId;
  String? associatedMessageGuid;
  String? associatedMessageType;
  String? expressiveSendStyleId;
  DateTime? timeExpressiveSendStyleId;
  Handle? handle;
  bool hasAttachments;
  bool hasReactions;
  DateTime? dateDeleted;
  Map<String, dynamic>? metadata;

  List<Attachment?>? attachments = [];
  List<Message> associatedMessages = [];
  bool? bigEmoji;

  Message(
      {this.id,
      this.originalROWID,
      this.guid,
      this.handleId,
      this.otherHandle,
      this.text,
      this.subject,
      this.country,
      int? error2,
      this.dateCreated,
      this.dateRead,
      this.dateDelivered,
      this.isFromMe = true,
      this.isDelayed = false,
      this.isAutoReply = false,
      this.isSystemMessage = false,
      this.isServiceMessage = false,
      this.isForward = false,
      this.isArchived = false,
      this.hasDdResults = false,
      this.cacheRoomnames,
      this.isAudioMessage = false,
      this.datePlayed,
      this.itemType = 0,
      this.groupTitle,
      this.groupActionType = 0,
      this.isExpired = false,
      this.balloonBundleId,
      this.associatedMessageGuid,
      this.associatedMessageType,
      this.expressiveSendStyleId,
      this.timeExpressiveSendStyleId,
      this.handle,
      this.hasAttachments = false,
      this.hasReactions = false,
      this.attachments = const [],
      this.associatedMessages = const [],
      this.dateDeleted,
      this.metadata}) {
    if (error2 != null) error.value = error2;
  }

  String? get fullText {
    String fullText = this.subject ?? "";
    if (fullText.isNotEmpty) {
      fullText += "\n";
    }

    fullText += this.text ?? "";

    return sanitizeString(fullText);
  }

  factory Message.fromMap(Map<String, dynamic> json) {
    bool hasAttachments = false;
    if (json.containsKey("hasAttachments")) {
      hasAttachments = json["hasAttachments"] == 1 ? true : false;
    } else if (json.containsKey("attachments")) {
      hasAttachments = (json['attachments'] as List).length > 0 ? true : false;
    }

    List<Attachment> attachments =
        json.containsKey("attachments") ? (json['attachments'] as List).map((a) => Attachment.fromMap(a)).toList() : [];

    // Load the metadata
    dynamic metadata = json.containsKey("metadata") ? json["metadata"] : null;
    if (!isNullOrEmpty(metadata)!) {
      // If the metadata is a string, convert it to JSON
      if (metadata is String) {
        try {
          metadata = jsonDecode(metadata);
        } catch (ex) {}
      }
    }

    String? associatedMessageGuid;
    if (json.containsKey("associatedMessageGuid") && json["associatedMessageGuid"] != null) {
      if ((json["associatedMessageGuid"] as String).contains("/")) {
        associatedMessageGuid = (json["associatedMessageGuid"] as String).split("/").last;
      } else {
        associatedMessageGuid = (json["associatedMessageGuid"] as String).split(":").last;
      }
    }

    var data = new Message(
      id: json.containsKey("ROWID") ? json["ROWID"] : null,
      originalROWID: json.containsKey("originalROWID") ? json["originalROWID"] : null,
      guid: json["guid"],
      handleId: (json["handleId"] != null) ? json["handleId"] : 0,
      otherHandle: (json["otherHandle"] != null) ? json["otherHandle"] : null,
      text: sanitizeString(json["text"]),
      subject: json.containsKey("subject") ? json["subject"] : null,
      country: json.containsKey("country") ? json["country"] : null,
      error2: json.containsKey("error") ? json["error"] : 0,
      dateCreated: json.containsKey("dateCreated") ? parseDate(json["dateCreated"]) : null,
      dateRead: json.containsKey("dateRead") ? parseDate(json["dateRead"]) : null,
      dateDelivered: json.containsKey("dateDelivered") ? parseDate(json["dateDelivered"]) : null,
      isFromMe: (json["isFromMe"] is bool) ? json['isFromMe'] : ((json['isFromMe'] == 1) ? true : false),
      isDelayed: (json["isDelayed"] is bool) ? json['isDelayed'] : ((json['isDelayed'] == 1) ? true : false),
      isAutoReply: (json["isAutoReply"] is bool) ? json['isAutoReply'] : ((json['isAutoReply'] == 1) ? true : false),
      isSystemMessage:
          (json["isSystemMessage"] is bool) ? json['isSystemMessage'] : ((json['isSystemMessage'] == 1) ? true : false),
      isServiceMessage: (json["isServiceMessage"] is bool)
          ? json['isServiceMessage']
          : ((json['isServiceMessage'] == 1) ? true : false),
      isForward: (json["isForward"] is bool) ? json['isForward'] : ((json['isForward'] == 1) ? true : false),
      isArchived: (json["isArchived"] is bool) ? json['isArchived'] : ((json['isArchived'] == 1) ? true : false),
      hasDdResults:
          (json["hasDdResults"] is bool) ? json['hasDdResults'] : ((json['hasDdResults'] == 1) ? true : false),
      cacheRoomnames: json.containsKey("cacheRoomnames") ? json["cacheRoomnames"] : null,
      isAudioMessage:
          (json["isAudioMessage"] is bool) ? json['isAudioMessage'] : ((json['isAudioMessage'] == 1) ? true : false),
      datePlayed: json.containsKey("datePlayed") ? parseDate(json["datePlayed"]) : null,
      itemType: json.containsKey("itemType") ? json["itemType"] : null,
      groupTitle: json.containsKey("groupTitle") ? json["groupTitle"] : null,
      groupActionType: (json["groupActionType"] != null) ? json["groupActionType"] : 0,
      isExpired: (json["isExpired"] is bool) ? json['isExpired'] : ((json['isExpired'] == 1) ? true : false),
      balloonBundleId: json.containsKey("balloonBundleId") ? json["balloonBundleId"] : null,
      associatedMessageGuid: associatedMessageGuid,
      associatedMessageType: json.containsKey("associatedMessageType") ? json["associatedMessageType"] : null,
      expressiveSendStyleId: json.containsKey("expressiveSendStyleId") ? json["expressiveSendStyleId"] : null,
      timeExpressiveSendStyleId: json.containsKey("timeExpressiveSendStyleId")
          ? DateTime.tryParse(json["timeExpressiveSendStyleId"].toString())?.toLocal()
          : null,
      handle: json.containsKey("handle") ? (json['handle'] != null ? Handle.fromMap(json['handle']) : null) : null,
      hasAttachments: hasAttachments,
      attachments: attachments,
      hasReactions: json.containsKey('hasReactions') ? ((json['hasReactions'] == 1) ? true : false) : false,
      dateDeleted: json.containsKey("dateDeleted") ? parseDate(json["dateDeleted"]) : null,
      metadata: metadata is String ? null : metadata,
    );

    // Adds fallback getter for the ID
    if (data.id == null) {
      data.id = json.containsKey("id") ? json["id"] : null;
    }

    return data;
  }

  Future<Message> save([bool updateIfAbsent = true]) async {
    final Database db = await DBProvider.db.database;
    // Try to find an existing chat before saving it
    Message? existing = await Message.findOne({"guid": this.guid});
    if (existing != null) {
      this.id = existing.id;
    }

    // Save the participant & set the handle ID to the new participant
    if (this.handle != null) {
      await this.handle!.save();
      this.handleId = this.handle!.id;
    }
    if (this.associatedMessageType != null && this.associatedMessageGuid != null) {
      Message? associatedMessage = await Message.findOne({"guid": this.associatedMessageGuid});
      if (associatedMessage != null) {
        associatedMessage.hasReactions = true;
        await associatedMessage.save();
      }
    } else if (!this.hasReactions) {
      Message? reaction = await Message.findOne({"associatedMessageGuid": this.guid});
      if (reaction != null) {
        this.hasReactions = true;
      }
    }

    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      if (this.handleId == null) this.handleId = 0;
      var map = this.toMap();
      if (map.containsKey("ROWID")) {
        map.remove("ROWID");
      }
      if (map.containsKey("handle")) {
        map.remove("handle");
      }

      this.id = await db.insert("message", map);
    } else if (updateIfAbsent) {
      await this.update();
    }

    return this;
  }

  static Future<Message?> replaceMessage(String? oldGuid, Message? newMessage,
      {bool awaitNewMessageEvent = true, Chat? chat}) async {
    final Database db = await DBProvider.db.database;
    Message? existing = await Message.findOne({"guid": oldGuid});

    if (existing == null) {
      if (awaitNewMessageEvent) {
        await Future.delayed(Duration(milliseconds: 500));
        return replaceMessage(oldGuid, newMessage, awaitNewMessageEvent: false, chat: chat);
      } else {
        if (chat != null) {
          await chat.addMessage(newMessage!);
          NewMessageManager().addMessage(chat, newMessage, outgoing: false);
          return newMessage;
        }
      }

      return newMessage;
    }

    Map<String, dynamic> params = newMessage!.toMap();
    if (params.containsKey("ROWID")) {
      params.remove("ROWID");
    }
    if (params.containsKey("handle")) {
      params.remove("handle");
    }

    var theMap = existing.toMap();
    if (theMap.containsKey("handleId")) {
      params["handleId"] = theMap["handleId"];
      newMessage.handleId = existing.handleId;
    }
    if (existing.hasAttachments) {
      params["hasAttachments"] = existing.hasAttachments ? 1 : 0;
      newMessage.hasAttachments = existing.hasAttachments;
    }
    if (theMap.containsKey("hasReactions")) {
      params["hasReactions"] = theMap["hasReactions"];
      newMessage.hasReactions = existing.hasReactions;
    }
    if (theMap.containsKey("metadata")) {
      params["metadata"] = theMap["metadata"];
      newMessage.metadata = existing.metadata;
    }

    await db.update("message", params, where: "ROWID = ?", whereArgs: [existing.id]);

    return newMessage;
  }

  Future<Message> updateMetadata(Metadata? metadata) async {
    final Database db = await DBProvider.db.database;
    if (this.id == null) return this;
    this.metadata = metadata!.toJson();

    await db.update("message", {"metadata": isNullOrEmpty(this.metadata)! ? null : jsonEncode(this.metadata)},
        where: "ROWID = ?", whereArgs: [this.id]);

    return this;
  }

  Future<Message> update() async {
    final Database db = await DBProvider.db.database;

    Map<String, dynamic> params = {
      "dateCreated": (this.dateCreated == null) ? null : this.dateCreated!.millisecondsSinceEpoch,
      "dateRead": (this.dateRead == null) ? null : this.dateRead!.millisecondsSinceEpoch,
      "dateDelivered": (this.dateDelivered == null) ? null : this.dateDelivered!.millisecondsSinceEpoch,
      "isArchived": this.isArchived! ? 1 : 0,
      "datePlayed": (this.datePlayed == null) ? null : this.datePlayed!.millisecondsSinceEpoch,
      "error": this.error.value,
      "hasReactions": this.hasReactions ? 1 : 0,
      "hasDdResults": this.hasDdResults! ? 1 : 0,
      "metadata": isNullOrEmpty(this.metadata)! ? null : jsonEncode(this.metadata)
    };

    if (this.originalROWID != null) {
      params["originalROWID"] = this.originalROWID;
    }

    // If it already exists, update it
    if (this.id != null) {
      await db.update("message", params, where: "ROWID = ?", whereArgs: [this.id]);
    } else {
      await this.save(false);
    }

    return this;
  }

  Future<List<Attachment?>?> fetchAttachments({CurrentChat? currentChat}) async {
    if (this.hasAttachments && this.attachments != null && this.attachments!.length != 0) {
      return this.attachments;
    }

    if (currentChat != null) {
      this.attachments = currentChat.getAttachmentsForMessage(this);
      if (this.attachments!.length != 0) return this.attachments;
    }

    final Database db = await DBProvider.db.database;
    if (this.id == null) return [];

    var res = await db.rawQuery(
        "SELECT"
        " attachment.ROWID AS ROWID,"
        " attachment.originalROWID AS originalROWID,"
        " attachment.guid AS guid,"
        " attachment.uti AS uti,"
        " attachment.mimeType AS mimeType,"
        " attachment.transferState AS transferState,"
        " attachment.isOutgoing AS isOutgoing,"
        " attachment.transferName AS transferName,"
        " attachment.totalBytes AS totalBytes,"
        " attachment.isSticker AS isSticker,"
        " attachment.hideAttachment AS hideAttachment,"
        " attachment.blurhash AS blurhash,"
        " attachment.metadata AS metadata,"
        " attachment.width AS width,"
        " attachment.height AS height"
        " FROM message"
        " JOIN attachment_message_join AS amj ON message.ROWID = amj.messageId"
        " JOIN attachment ON attachment.ROWID = amj.attachmentId"
        " WHERE message.ROWID = ?;",
        [this.id]);

    this.attachments = (res.isNotEmpty) ? res.map((c) => Attachment.fromMap(c)).toList() : [];

    return this.attachments;
  }

  static Future<Chat?> getChat(Message message) async {
    final Database db = await DBProvider.db.database;
    var res = await db.rawQuery(
        "SELECT"
        " chat.ROWID AS ROWID,"
        " chat.originalROWID AS originalROWID,"
        " chat.guid AS guid,"
        " chat.style AS style,"
        " chat.chatIdentifier AS chatIdentifier,"
        " chat.isArchived AS isArchived,"
        " chat.displayName AS displayName,"
        " chat.customAvatarPath AS customAvatarPath,"
        " chat.pinIndex AS pinIndex"
        " FROM chat"
        " JOIN chat_message_join AS cmj ON chat.ROWID = cmj.chatId"
        " JOIN message ON message.ROWID = cmj.messageId"
        " WHERE message.ROWID = ?;",
        [message.id]);

    return (res.isNotEmpty) ? Chat.fromMap(res[0]) : null;
  }

  Future<Message> fetchAssociatedMessages() async {
    if (this.associatedMessages.isNotEmpty &&
        this.associatedMessages.length == 1 &&
        this.associatedMessages[0].guid == this.guid) {
      return this;
    }
    associatedMessages = await Message.find({"associatedMessageGuid": this.guid});
    associatedMessages.sort((a, b) => a.originalROWID!.compareTo(b.originalROWID!));
    associatedMessages = MessageHelper.normalizedAssociatedMessages(associatedMessages);
    return this;
  }

  Future<Handle?> getHandle() async {
    final Database db = await DBProvider.db.database;
    var res = await db.rawQuery(
        "SELECT"
        " handle.ROWID AS ROWID,"
        " handle.originalROWID AS originalROWID,"
        " handle.address AS address,"
        " handle.country AS country,"
        " handle.color AS color,"
        " handle.defaultPhone AS defaultPhone,"
        " handle.uncanonicalizedId AS uncanonicalizedId"
        " FROM handle"
        " JOIN message ON message.handleId = handle.ROWID"
        " WHERE message.ROWID = ?;",
        [this.id]);

    this.handle = (res.isNotEmpty) ? res.map((c) => Handle.fromMap(c)).toList()[0] : null;
    return this.handle;
  }

  static Future<Message?> findOne(Map<String, dynamic> filters) async {
    final Database db = await DBProvider.db.database;
    List<String> whereParams = [];
    filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    filters.values.forEach((filter) => whereArgs.add(filter));
    var res = await db.query("message", where: whereParams.join(" AND "), whereArgs: whereArgs, limit: 1);

    if (res.isEmpty) {
      return null;
    }

    return Message.fromMap(res.elementAt(0));
  }

  static Future<List<Message>> find([Map<String, dynamic> filters = const {}]) async {
    final Database db = await DBProvider.db.database;

    List<String> whereParams = [];
    filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    filters.values.forEach((filter) => whereArgs.add(filter));

    var res = await db.query("message",
        where: (whereParams.length > 0) ? whereParams.join(" AND ") : null,
        whereArgs: (whereArgs.length > 0) ? whereArgs : null);
    return (res.isNotEmpty) ? res.map((c) => Message.fromMap(c)).toList() : [];
  }

  static Future<void> delete(Map<String, dynamic> where) async {
    final Database db = await DBProvider.db.database;

    List<String> whereParams = [];
    where.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    where.values.forEach((filter) => whereArgs.add(filter));

    List<Message> toDelete = await Message.find(where);
    for (Message msg in toDelete) {
      await db.delete("chat_message_join", where: "messageId = ?", whereArgs: [msg.id]);
      await db.delete("message", where: "ROWID = ?", whereArgs: [msg.id]);
    }
  }

  static Future<void> softDelete(Map<String, dynamic> where) async {
    final Database db = await DBProvider.db.database;

    List<String> whereParams = [];
    where.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    where.values.forEach((filter) => whereArgs.add(filter));

    List<Message> toDelete = await Message.find(where);
    for (Message msg in toDelete) {
      await db.update("message", {'dateDeleted': DateTime.now().toUtc().millisecondsSinceEpoch},
          where: "ROWID = ?", whereArgs: [msg.id]);
    }
  }

  static flush() async {
    final Database db = await DBProvider.db.database;
    await db.delete("message");
  }

  bool hasUrl() {
    if (text == null) return false;
    List<String> splits = this.text!.split(" ");
    return splits.firstWhereOrNull((element) => element.isURL) != null;
  }

  bool isUrlPreview() {
    // first condition is for macOS < 11 and second condition is for macOS >= 11
    return (this.balloonBundleId != null && this.balloonBundleId == "com.apple.messages.URLBalloonProvider" &&
        this.hasDdResults!) || (this.hasDdResults! && (this.text ?? "").isURL);
  }

  String? getUrl() {
    if (text == null) return null;
    List<String> splits = this.text!.split(" ");
    return splits.firstWhereOrNull((element) => element.isURL);
  }

  bool isInteractive() {
    return this.balloonBundleId != null && this.balloonBundleId != "com.apple.messages.URLBalloonProvider";
  }

  bool hasText({stripWhitespace = false}) {
    return !isEmptyString(this.fullText, stripWhitespace: stripWhitespace);
  }

  bool isGroupEvent() {
    return isEmptyString(this.fullText) && !this.hasAttachments && this.balloonBundleId == null;
  }

  bool isBigEmoji() {
    // We are checking the variable first because we want to
    // avoid processing twice for this as it won't change
    if (this.bigEmoji == null) {
      this.bigEmoji = MessageHelper.shouldShowBigEmoji(this.fullText ?? "");
    }

    return this.bigEmoji!;
  }

  List<Attachment?> getRealAttachments() {
    return this.attachments!.where((item) => item!.mimeType != null).toList();
  }

  List<Attachment?> getPreviewAttachments() {
    return this.attachments!.where((item) => item!.mimeType == null).toList();
  }

  List<Message> getReactions() {
    return this
        .associatedMessages
        .where((item) => ReactionTypes.toList().contains(item.associatedMessageType))
        .toList();
  }

  void generateTempGuid() {
    List<String> unique = [this.text ?? "", this.dateCreated?.millisecondsSinceEpoch.toString() ?? ""];

    String preHashed;
    if (unique.every((element) => element.trim().length == 0)) {
      preHashed = randomString(8);
    } else {
      preHashed = unique.join(":");
    }

    String hashed = crypto.sha1.convert(utf8.encode(preHashed)).toString();
    this.guid = "temp-$hashed";
  }

  static Future<int?> countForChat(Chat? chat) async {
    final Database db = await DBProvider.db.database;
    if (chat == null || chat.id == null) return 0;

    String query = ("SELECT"
        " count(message.ROWID) AS count"
        " FROM message"
        " JOIN chat_message_join AS cmj ON cmj.messageId = message.ROWID"
        " JOIN chat ON chat.ROWID = cmj.chatId"
        " WHERE chat.ROWID = ?");

    // Execute the query
    var res = await db.rawQuery("$query;", [chat.id]);
    if (res.length == 0) return 0;

    return res[0]["count"] as int?;
  }

  void merge(Message otherMessage) {
    if (this.dateCreated == null && otherMessage.dateCreated != null) {
      this.dateCreated = otherMessage.dateCreated;
    }
    if (this.dateDelivered == null && otherMessage.dateDelivered != null) {
      this.dateDelivered = otherMessage.dateDelivered;
    }
    if (this.dateRead == null && otherMessage.dateRead != null) {
      this.dateRead = otherMessage.dateRead;
    }
    if (this.dateDeleted == null && otherMessage.dateDeleted != null) {
      this.dateDeleted = otherMessage.dateDeleted;
    }
    if (this.datePlayed == null && otherMessage.datePlayed != null) {
      this.datePlayed = otherMessage.datePlayed;
    }
    if (this.metadata == null && otherMessage.metadata != null) {
      this.metadata = otherMessage.metadata;
    }
    if (this.originalROWID == null && otherMessage.originalROWID != null) {
      this.originalROWID = otherMessage.originalROWID;
    }
    if (!this.hasAttachments && otherMessage.hasAttachments) {
      this.hasAttachments = otherMessage.hasAttachments;
    }
    if (!this.hasReactions && otherMessage.hasReactions) {
      this.hasReactions = otherMessage.hasReactions;
    }
    if (this.error.value == 0 && otherMessage.error.value != 0) {
      this.error.value = otherMessage.error.value;
    }
  }

  Map<String, dynamic> toMap() => {
        "ROWID": id,
        "originalROWID": originalROWID,
        "guid": guid,
        "handleId": handleId,
        "otherHandle": otherHandle,
        "text": sanitizeString(text),
        "subject": subject,
        "country": country,
        "error": error.value,
        "dateCreated": (dateCreated == null) ? null : dateCreated!.millisecondsSinceEpoch,
        "dateRead": (dateRead == null) ? null : dateRead!.millisecondsSinceEpoch,
        "dateDelivered": (dateDelivered == null) ? null : dateDelivered!.millisecondsSinceEpoch,
        "isFromMe": isFromMe! ? 1 : 0,
        "isDelayed": isDelayed! ? 1 : 0,
        "isAutoReply": isAutoReply! ? 1 : 0,
        "isSystemMessage": isSystemMessage! ? 1 : 0,
        "isServiceMessage": isServiceMessage! ? 1 : 0,
        "isForward": isForward! ? 1 : 0,
        "isArchived": isArchived! ? 1 : 0,
        "hasDdResults": hasDdResults! ? 1 : 0,
        "cacheRoomnames": cacheRoomnames,
        "isAudioMessage": isAudioMessage! ? 1 : 0,
        "datePlayed": (datePlayed == null) ? null : datePlayed!.millisecondsSinceEpoch,
        "itemType": itemType,
        "groupTitle": groupTitle,
        "groupActionType": groupActionType,
        "isExpired": isExpired! ? 1 : 0,
        "balloonBundleId": balloonBundleId,
        "associatedMessageGuid": associatedMessageGuid,
        "associatedMessageType": associatedMessageType,
        "expressiveSendStyleId": expressiveSendStyleId,
        "timeExpressiveSendStyleId":
            (timeExpressiveSendStyleId == null) ? null : timeExpressiveSendStyleId!.millisecondsSinceEpoch,
        "handle": (handle != null) ? handle!.toMap() : null,
        "hasAttachments": hasAttachments ? 1 : 0,
        "hasReactions": hasReactions ? 1 : 0,
        "dateDeleted": (dateDeleted == null) ? null : dateDeleted!.millisecondsSinceEpoch,
        "metadata": jsonEncode(metadata),
      };
}

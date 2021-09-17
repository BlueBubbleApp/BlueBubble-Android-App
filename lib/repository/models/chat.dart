import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/repository/models/join_tables.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:objectbox/objectbox.dart';
import 'package:universal_io/io.dart';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/metadata_helper.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:get/get.dart';
import 'package:faker/faker.dart';
import 'package:metadata_fetch/metadata_fetch.dart';


import '../../helpers/utils.dart';
import '../database.dart';
import 'handle.dart';
import 'message.dart';

Chat chatFromJson(String str) {
  final jsonData = json.decode(str);
  return Chat.fromMap(jsonData);
}

String chatToJson(Chat data) {
  final dyn = data.toMap();
  return json.encode(dyn);
}

Future<String> getFullChatTitle(Chat _chat) async {
  String? title = "";
  if (isNullOrEmpty(_chat.displayName)!) {
    Chat chat = await _chat.getParticipants();

    // If there are no participants, try to get them from the server
    if (chat.participants.isEmpty) {
      await ActionHandler.handleChat(chat: chat);
      chat = await chat.getParticipants();
    }

    List<String> titles = [];
    for (int i = 0; i < chat.participants.length; i++) {
      String? name = await ContactManager().getContactTitle(chat.participants[i]);

      if (chat.participants.length > 1 && !name!.isPhoneNumber) {
        name = name.trim().split(" ")[0];
      } else {
        name = name!.trim();
      }

      titles.add(name);
    }

    if (titles.isEmpty) {
      title = _chat.chatIdentifier;
    } else if (titles.length == 1) {
      title = titles[0];
    } else if (titles.length <= 4) {
      title = titles.join(", ");
      int pos = title.lastIndexOf(", ");
      if (pos != -1) title = "${title.substring(0, pos)} & ${title.substring(pos + 2)}";
    } else {
      title = titles.sublist(0, 3).join(", ");
      title = "$title & ${titles.length - 3} others";
    }
  } else {
    title = _chat.displayName;
  }

  return title!;
}

Future<String?> getShortChatTitle(Chat _chat) async {
  if (_chat.participants.length == 1) {
    return await ContactManager().getContactTitle(_chat.participants[0]);
  } else if (_chat.displayName != null && _chat.displayName!.length != 0) {
    return _chat.displayName;
  } else {
    return "${_chat.participants.length} people";
  }
}

@Entity()
class Chat {
  int? id;
  int? originalROWID;
  @Unique()
  String? guid;
  int? style;
  String? chatIdentifier;
  bool? isArchived;
  bool? isFiltered;
  String? muteType;
  String? muteArgs;
  bool? isPinned;
  bool? hasUnreadMessage;
  DateTime? latestMessageDate;
  String? latestMessageText;
  String? fakeLatestMessageText;
  String? title;
  String? displayName;
  List<Handle> participants = [];
  List<String> fakeParticipants = [];
  Message? latestMessage;
  final RxnString _customAvatarPath = RxnString();
  String? get customAvatarPath => _customAvatarPath.value;
  set customAvatarPath(String? s) => _customAvatarPath.value = s;
  final RxnInt _pinIndex = RxnInt();
  int? get pinIndex => _pinIndex.value;
  set pinIndex(int? i) => _pinIndex.value = i;

  Chat({
    this.id,
    this.originalROWID,
    this.guid,
    this.style,
    this.chatIdentifier,
    this.isArchived,
    this.isFiltered,
    this.isPinned,
    this.muteType,
    this.muteArgs,
    this.hasUnreadMessage,
    this.displayName,
    String? customAvatar,
    int? pinnedIndex,
    this.participants = const [],
    this.fakeParticipants = const [],
    this.latestMessage,
    this.latestMessageDate,
    this.latestMessageText,
    this.fakeLatestMessageText,
  }) {
    customAvatarPath = customAvatar;
    pinIndex = pinnedIndex;
  }

  factory Chat.fromMap(Map<String, dynamic> json) {
    List<Handle> participants = [];
    List<String> fakeParticipants = [];
    if (json.containsKey('participants')) {
      (json['participants'] as List<dynamic>).forEach((item) {
        participants.add(Handle.fromMap(item));
        fakeParticipants.add(ContactManager().handleToFakeName[participants.last.address] ?? "Unknown");
      });
    }
    Message? message;
    if (json['lastMessage'] != null) {
      message = Message.fromMap(json['lastMessage']);
    }
    var data = new Chat(
      id: json.containsKey("ROWID") ? json["ROWID"] : null,
      originalROWID: json.containsKey("originalROWID") ? json["originalROWID"] : null,
      guid: json["guid"],
      style: json['style'],
      chatIdentifier: json.containsKey("chatIdentifier") ? json["chatIdentifier"] : null,
      isArchived: (json["isArchived"] is bool) ? json['isArchived'] : ((json['isArchived'] == 1) ? true : false),
      isFiltered: json.containsKey("isFiltered")
          ? (json["isFiltered"] is bool)
              ? json['isFiltered']
              : ((json['isFiltered'] == 1) ? true : false)
          : false,
      muteType: json["muteType"],
      muteArgs: json["muteArgs"],
      isPinned: json.containsKey("isPinned")
          ? (json["isPinned"] is bool)
              ? json['isPinned']
              : ((json['isPinned'] == 1) ? true : false)
          : false,
      hasUnreadMessage: json.containsKey("hasUnreadMessage")
          ? (json["hasUnreadMessage"] is bool)
              ? json['hasUnreadMessage']
              : ((json['hasUnreadMessage'] == 1) ? true : false)
          : false,
      latestMessage: message,
      latestMessageText: json.containsKey("latestMessageText") ? json["latestMessageText"] : message != null ? MessageHelper.getNotificationTextSync(message) : null,
      fakeLatestMessageText: json.containsKey("latestMessageText")
          ? faker.lorem.words((json["latestMessageText"] ?? "").split(" ").length).join(" ")
          : null,
      latestMessageDate: json.containsKey("latestMessageDate") && json['latestMessageDate'] != null
          ? new DateTime.fromMillisecondsSinceEpoch(json['latestMessageDate'] as int)
          : message?.dateCreated,
      displayName: json.containsKey("displayName") ? json["displayName"] : null,
      customAvatar: json['_customAvatarPath'],
      pinnedIndex: json['_pinIndex'],
      participants: participants,
      fakeParticipants: fakeParticipants,
    );

    // Adds fallback getter for the ID
    if (data.id == null) {
      data.id = json.containsKey("id") ? json["id"] : null;
    }

    return data;
  }

  Future<Chat> save({bool updateIfAbsent = true, bool updateLocalVals = false}) async {
    Chat? existing = await Chat.findOne({"guid": this.guid});
    this.id = existing?.id ?? this.id;
    try {
      chatBox.put(this);
    } on UniqueViolationException catch (_) {}
    /*final Database? db = await DBProvider.db.database;

    // Try to find an existing chat before saving it
    Chat? existing = await Chat.findOne({"guid": this.guid});
    if (existing != null) {
      this.id = existing.id;
      if (!updateLocalVals) {
        this.muteType = existing.muteType;
        this.muteArgs = existing.muteArgs;
        this.isPinned = existing.isPinned;
        this.isArchived = existing.isArchived;
        this.hasUnreadMessage = existing.hasUnreadMessage;
      }
    }

    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      var map = this.toMap();
      if (map.containsKey("ROWID")) {
        map.remove("ROWID");
      }
      if (map.containsKey("participants")) {
        map.remove("participants");
      }

      this.id = await db?.insert("chat", map);
    } else if (updateIfAbsent) {
      await this.update();
    }*/

    // Save participants to the chat
    for (int i = 0; i < this.participants.length; i++) {
      await this.addParticipant(this.participants[i]);
    }

    return this;
  }

  Future<Chat> changeName(String? name) async {
    Chat? c = chatBox.get(this.id!);
    c?.displayName = name;
    if (c != null) chatBox.put(c);
    /*final Database? db = await DBProvider.db.database;
    await db?.update("chat", {'displayName': name}, where: "ROWID = ?", whereArgs: [this.id]);
    this.displayName = name;*/
    return this;
  }

  Future<String?> getTitle() async {
    this.title = await getFullChatTitle(this);
    return this.title;
  }

  String getDateText() {
    return buildDate(this.latestMessageDate);
  }

  Future<bool> shouldMuteNotification(Message? message) async {
    if (SettingsManager().settings.filterUnknownSenders.value
        && this.participants.length == 1
        && ContactManager().handleToContact[this.participants[0].address] == null) {
      return true;
    } else if (SettingsManager().settings.globalTextDetection.value.isNotEmpty) {
      List<String> text = SettingsManager().settings.globalTextDetection.value.split(",");
      for (String s in text) {
        if (message?.text?.toLowerCase().contains(s.toLowerCase()) ?? false) {
          return false;
        }
      }
      return true;
    } else if (muteType == "mute") {
      return true;
    } else if (muteType == "mute_individuals") {
      List<String> individuals = muteArgs!.split(",");
      return individuals.contains(message?.handle?.address ?? "");
    } else if (muteType == "temporary_mute") {
      DateTime time = DateTime.parse(muteArgs!);
      bool shouldMute = DateTime.now().toLocal().difference(time).inSeconds.isNegative;
      if (!shouldMute) {
        await this.toggleMute(false);
        this.muteType = null;
        this.muteArgs = null;
        await this.update();
      }
      return shouldMute;
    } else if (muteType == "text_detection") {
      List<String> text = muteArgs!.split(",");
      for (String s in text) {
        if (message?.text?.toLowerCase().contains(s.toLowerCase()) ?? false) {
          return false;
        }
      }
      return true;
    }
    return !SettingsManager().settings.notifyReactions.value &&
        ReactionTypes.toList().contains(message?.associatedMessageType ?? "");
  }

  Future<Chat> update() async {
    /*final Database? db = await DBProvider.db.database;

    // isArchived, isMuted, and isPinned should only be updated by using the helper methods
    Map<String, dynamic> params = {"isFiltered": this.isFiltered! ? 1 : 0};

    if (this.originalROWID != null) {
      params["originalROWID"] = this.originalROWID;
    }

    // Only update the latestMessage info if it's not null,
    // and it's not some time in the future
    int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (this.latestMessageDate != null && now > this.latestMessageDate!.millisecondsSinceEpoch) {
      params["latestMessageText"] = this.latestMessageText;
      params["latestMessageDate"] = this.latestMessageDate!.millisecondsSinceEpoch;
    }

    // Add display name if it's been updated
    if (this.displayName != null) {
      params["displayName"] = this.displayName;
    }

    params["_customAvatarPath"] = this._customAvatarPath;
    params["_pinIndex"] = this._pinIndex.value;
    params["muteType"] = this.muteType;
    params["muteArgs"] = this.muteArgs;

    // If it already exists, update it
    if (this.id != null) {
      await db?.update("chat", params, where: "ROWID = ?", whereArgs: [this.id]);
    } else {
      await this.save(updateIfAbsent: false);
    }*/
    this.save();

    return this;
  }

  static Future<void> deleteChat(Chat chat) async {
    /*final Database? db = await DBProvider.db.database;
    await chat.save();
    if (db == null) return;*/
    List<Message> messages = await Chat.getMessages(chat);
    chatBox.remove(chat.id!);
    messageBox.removeMany(messages.map((e) => e.id!).toList());
    final query = chJoinBox.query(ChatHandleJoin_.chatId.equals(chat.id!)).build();
    final results = query.property(ChatHandleJoin_.id).find();
    query.close();
    chJoinBox.removeMany(results);
    final query2 = cmJoinBox.query(ChatMessageJoin_.chatId.equals(chat.id!)).build();
    final results2 = query2.property(ChatMessageJoin_.id).find();
    query2.close();
    cmJoinBox.removeMany(results2);
    /*for (Message message in messages) {
      await db.delete("message", where: "ROWID = ?", whereArgs: [message.id]);
    }
    await db.delete("chat", where: "ROWID = ?", whereArgs: [chat.id]);
    await db.delete("chat_handle_join", where: "chatId = ?", whereArgs: [chat.id]);
    await db.delete("chat_message_join", where: "chatId = ?", whereArgs: [chat.id]);*/
  }

  Future<Chat> toggleHasUnread(bool hasUnread) async {
    //final Database? db = await DBProvider.db.database;
    if (hasUnread) {
      if (CurrentChat.isActive(this.guid!)) {
        return this;
      }
    }

    this.hasUnreadMessage = hasUnread;

    this.save();

    if (hasUnread) {
      EventDispatcher().emit("add-unread-chat", {"chatGuid": this.guid});
    } else {
      EventDispatcher().emit("remove-unread-chat", {"chatGuid": this.guid});
    }

    ChatBloc().updateUnreads();
    return this;
  }

  Future<Chat> addMessage(Message message, {bool changeUnreadStatus: true, bool checkForMessageText = true}) async {
    //final Database? db = await DBProvider.db.database;

    // Save the message
    Message? existing = await Message.findOne({"guid": message.guid});
    Message? newMessage;

    try {
      newMessage = await message.save();
    } catch (ex, stacktrace) {
      newMessage = await Message.findOne({"guid": message.guid});
      if (newMessage == null) {
        Logger.error(ex.toString());
        Logger.error(stacktrace.toString());
      }
    }
    bool isNewer = false;

    // If the message was saved correctly, update this chat's latestMessage info,
    // but only if the incoming message's date is newer
    if ((newMessage!.id != null || kIsWeb) && checkForMessageText) {
      if (this.latestMessageDate == null) {
        isNewer = true;
      } else if (this.latestMessageDate!.millisecondsSinceEpoch < message.dateCreated!.millisecondsSinceEpoch) {
        isNewer = true;
      }
    }

    if (isNewer && checkForMessageText) {
      this.latestMessage = message;
      this.latestMessageText = await MessageHelper.getNotificationText(message);
      this.fakeLatestMessageText = faker.lorem.words((this.latestMessageText ?? "").split(" ").length).join(" ");
      this.latestMessageDate = message.dateCreated;
    }

    // Save any attachments
    for (Attachment? attachment in message.attachments ?? []) {
      await attachment!.save(newMessage);
    }

    // Save the chat.
    // This will update the latestMessage info as well as update some
    // other fields that we want to "mimic" from the server
    await this.save();

    try {
      // Add the relationship
      cmJoinBox.put(ChatMessageJoin(chatId: this.id!, messageId: message.id!));
    } catch (ex) {
      // Don't do anything if it already exists
    }

    // If the incoming message was newer than the "last" one, set the unread status accordingly
    if (checkForMessageText && changeUnreadStatus && isNewer && existing == null) {
      // If the message is from me, mark it unread
      // If the message is not from the same chat as the current chat, mark unread
      if (message.isFromMe!) {
        await this.toggleHasUnread(false);
      } else if (!CurrentChat.isActive(this.guid!)) {
        await this.toggleHasUnread(true);
      }
    }

    if (checkForMessageText) {
      // Update the chat position
      ChatBloc().updateChatPosition(this);
    }

    // If the message is for adding or removing participants,
    // we need to ensure that all of the chat participants are correct by syncing with the server
    if (isParticipantEvent(message) && checkForMessageText) {
      serverSyncParticipants();
    }

    // If this is a message preview and we don't already have metadata for this, get it
    if (message.fullText.replaceAll("\n", " ").hasUrl && !MetadataHelper.mapIsNotEmpty(message.metadata)) {
      MetadataHelper.fetchMetadata(message).then((Metadata? meta) async {
        // If the metadata is empty, don't do anything
        if (!MetadataHelper.isNotEmpty(meta)) return;

        // Save the metadata to the object
        message.metadata = meta!.toJson();

        // If pre-caching is enabled, fetch the image and save it
        if (SettingsManager().settings.preCachePreviewImages.value &&
            message.metadata!.containsKey("image") &&
            !isNullOrEmpty(message.metadata!["image"])!) {
          // Save from URL
          File? newFile = await saveImageFromUrl(message.guid!, message.metadata!["image"]);

          // If we downloaded a file, set the new metadata path
          if (newFile != null && newFile.existsSync()) {
            message.metadata!["image"] = newFile.path;
          }
        }

        message.update();
      });
    }

    // Return the current chat instance (with updated vals)
    return this;
  }

  void serverSyncParticipants() {
    // Send message to server to get the participants
    SocketManager().sendMessage("get-participants", {"identifier": this.guid}, (response) async {
      if (response["status"] == 200) {
        // Get all the participants from the server
        List data = response["data"];
        List<Handle> handles = data.map((e) => Handle.fromMap(e)).toList();

        // Make sure that all participants for our local chat are fetched
        await this.getParticipants();

        // We want to determine all the participants that exist in the response that are not already in our locally saved chat (AKA all the new participants)
        List<Handle> newParticipants = handles
            .where((a) => (this.participants.where((b) => b.address == a.address).toList().length == 0))
            .toList();

        // We want to determine all the participants that exist in the locally saved chat that are not in the response (AKA all the removed participants)
        List<Handle> removedParticipants = this
            .participants
            .where((a) => (handles.where((b) => b.address == a.address).toList().length == 0))
            .toList();

        // Add all participants that are missing from our local db
        for (Handle newParticipant in newParticipants) {
          await this.addParticipant(newParticipant);
        }

        // Remove all extraneous participants from our local db
        for (Handle removedParticipant in removedParticipants) {
          await removedParticipant.save();
          await this.removeParticipant(removedParticipant);
        }

        // Sync all changes with the chatbloc
        ChatBloc().updateChat(this);
      }
    });
  }

  static Future<int?> count() async {
    /*final Database? db = await DBProvider.db.database;

    List<Map<String, dynamic>>? test = await db?.rawQuery("SELECT COUNT(*) FROM chat;");
    return test?[0]['COUNT(*)'];*/
    return chatBox.count();
  }

  static Future<List<Attachment>> getAttachments(Chat chat, {int offset = 0, int limit = 25}) async {
    /*final Database? db = await DBProvider.db.database;
    if (db == null) return [];*/
    if (chat.id == null) return [];
    final amJoinValues = amJoinBox.getAll();
    final cmJoinValues = cmJoinBox.getAll().where((element) => element.chatId == chat.id).map((e) => e.messageId);
    final attachmentIds = amJoinValues.where((element) => cmJoinValues.contains(element.messageId)).map((e) => e.attachmentId).toList();
    final query = attachmentBox.query(Attachment_.id.oneOf(attachmentIds)).build();
    query
      ..limit = limit
      ..offset = offset;
    final attachments = query.find()..removeWhere((element) => element.mimeType == null);
    if (attachments.length > 0) {
      final guids = attachments.map((e) => e.guid).toSet();
      attachments.retainWhere((element) => guids.remove(element.guid));
    }
    query.close();
    return attachments;
    /*String query = ("SELECT"
        " attachment.ROWID AS ROWID,"
        " attachment.originalROWID AS originalROWID,"
        " attachment.guid AS guid,"
        " attachment.uti AS uti,"
        " attachment.mimeType AS mimeType,"
        " attachment.totalBytes AS totalBytes,"
        " attachment.transferName AS transferName,"
        " attachment.blurhash AS blurhash,"
        " attachment.metadata AS metadata"
        " FROM attachment"
        " JOIN attachment_message_join AS amj ON amj.attachmentId = attachment.ROWID"
        " JOIN message ON amj.messageId = message.ROWID"
        " JOIN chat_message_join AS cmj ON cmj.messageId = message.ROWID"
        " JOIN chat ON chat.ROWID = cmj.chatId"
        " WHERE chat.ROWID = ? AND attachment.mimeType IS NOT NULL");

    // Add pagination
    query += " ORDER BY message.dateCreated DESC LIMIT $limit OFFSET $offset";

    // Execute the query
    var res = await db.rawQuery("$query;", [chat.id]);
    List<Attachment> attachments = res.map((attachment) => Attachment.fromMap(attachment)).where((element) {
      String? mimeType = element.mimeType;
      if (mimeType == null) return false;
      mimeType = mimeType.substring(0, mimeType.indexOf("/"));
      return mimeType == "image" || mimeType == "video";
    }).toList();
    if (attachments.length > 0) {
      final guids = attachments.map((e) => e.guid).toSet();
      attachments.retainWhere((element) => guids.remove(element.guid));
    }
    return attachments;*/
  }

  static Map<String, Completer<List<Message>>> _getMessagesRequests = {};

  static Future<List<Message>> getMessagesSingleton(Chat? chat,
      {bool reactionsOnly = false, int offset = 0, int limit = 25, bool includeDeleted: false}) async {
    if (chat == null) return [];

    String req = "${chat.guid}-$offset-$limit-$reactionsOnly-$includeDeleted";

    // If a current request is in progress, return that future
    if (_getMessagesRequests.containsKey(req) && !_getMessagesRequests[req]!.isCompleted)
      return _getMessagesRequests[req]!.future;

    _getMessagesRequests[req] = new Completer();

    try {
      List<Message> messages = await Chat.getMessages(chat,
          reactionsOnly: reactionsOnly, offset: offset, limit: limit, includeDeleted: includeDeleted);

      if (_getMessagesRequests.containsKey(req) && !_getMessagesRequests[req]!.isCompleted)
        _getMessagesRequests[req]!.complete(messages);
    } catch (ex) {
      Logger.error(ex.toString());

      if (_getMessagesRequests.containsKey(req) && !_getMessagesRequests[req]!.isCompleted)
        _getMessagesRequests[req]!.completeError(ex);
    }

    // Remove the request from the "cache" after 10 seconds
    Future.delayed(new Duration(seconds: 10), () {
      if (_getMessagesRequests.containsKey(req)) {
        _getMessagesRequests.remove(req);
      }
    });

    if (_getMessagesRequests.containsKey(req)) {
      return _getMessagesRequests[req]!.future;
    } else {
      return [];
    }
  }

  static Future<List<Message>> getMessages(Chat chat,
      {bool reactionsOnly = false, int offset = 0, int limit = 25, bool includeDeleted: false}) async {
    /*final Database? db = await DBProvider.db.database;
    if (db == null) return [];*/
    if (chat.id == null) return [];
    final messageIds = cmJoinBox.getAll().where((element) => element.chatId == chat.id).map((e) => e.messageId).toList();
    final query = (messageBox.query(Message_.id.oneOf(messageIds))..order(Message_.dateCreated, flags: Order.descending)).build();
    query
      ..limit = limit
      ..offset = offset;
    final messages = query.find();
    query.close();
    final handles = handleBox.getMany(messages.map((e) => e.handleId!).toList()..removeWhere((element) => element == 0));
    messages.forEach((element) {
      if (handles.isNotEmpty && element.handleId != 0)
        element.handle = handles.firstWhere((e) => e?.id == element.handleId);
    });
    return messages;
    /*// String reactionQualifier = reactionsOnly ? "IS NOT" : "IS";
    String query = ("SELECT"
        " message.ROWID AS ROWID,"
        " message.originalROWID AS originalROWID,"
        " message.guid AS guid,"
        " message.handleId AS handleId,"
        " message.otherHandle AS otherHandle,"
        " message.text AS text,"
        " message.subject AS subject,"
        " message.country AS country,"
        " message.error AS error,"
        " message.dateCreated AS dateCreated,"
        " message.dateDelivered AS dateDelivered,"
        " message.dateDeleted AS dateDeleted,"
        " message.dateRead AS dateRead,"
        " message.isFromMe AS isFromMe,"
        " message.isDelayed AS isDelayed,"
        " message.isAutoReply AS isAutoReply,"
        " message.isSystemMessage AS isSystemMessage,"
        " message.isForward AS isForward,"
        " message.isArchived AS isArchived,"
        " message.cacheRoomnames AS cacheRoomnames,"
        " message.isAudioMessage AS isAudioMessage,"
        " message.datePlayed AS datePlayed,"
        " message.itemType AS itemType,"
        " message.groupTitle AS groupTitle,"
        " message.groupActionType AS groupActionType,"
        " message.isExpired AS isExpired,"
        " message.balloonBundleId AS balloonBundleId,"
        " message.associatedMessageGuid AS associatedMessageGuid,"
        " message.associatedMessageType AS associatedMessageType,"
        " message.expressiveSendStyleId AS texexpressiveSendStyleIdt,"
        " message.timeExpressiveSendStyleId AS timeExpressiveSendStyleId,"
        " message.hasAttachments AS hasAttachments,"
        " message.hasReactions AS hasReactions,"
        " message.metadata AS metadata,"
        " message.hasDdResults AS hasDdResults,"
        " handle.ROWID AS handleId,"
        " handle.originalROWID AS handleOriginalROWID,"
        " handle.address AS handleAddress,"
        " handle.country AS handleCountry,"
        " handle.color AS handleColor,"
        " handle.defaultPhone AS defaultPhone,"
        " handle.uncanonicalizedId AS handleUncanonicalizedId"
        " FROM message"
        " JOIN chat_message_join AS cmj ON message.ROWID = cmj.messageId"
        " JOIN chat ON cmj.chatId = chat.ROWID"
        " LEFT OUTER JOIN handle ON handle.ROWID = message.handleId"
        " WHERE chat.ROWID = ?");

    if (!includeDeleted) {
      query += " AND message.dateDeleted IS NULL";
    }

    // Add pagination
    String pagination = " ORDER BY message.originalROWID DESC LIMIT $limit OFFSET $offset;";

    // Execute the query
    var res = await db
        .rawQuery("$query" + " AND message.originalROWID IS NOT NULL GROUP BY message.ROWID" + pagination, [chat.id]);

    // Add the from/handle data to the messages
    List<Message> output = [];
    for (int i = 0; i < res.length; i++) {
      Message msg = Message.fromMap(res[i]);

      // If the handle is not null, load the handle data
      // The handle is null if the message.handleId is 0
      // the handleId is 0 when isFromMe is true and the chat is a group chat
      if (res[i].containsKey('handleAddress') && res[i]['handleAddress'] != null) {
        msg.handle = Handle.fromMap({
          'id': res[i]['handleId'],
          'originalROWID': res[i]['handleOriginalROWID'],
          'address': res[i]['handleAddress'],
          'country': res[i]['handleCountry'],
          'color': res[i]['handleColor'],
          'uncanonicalizedId': res[i]['handleUncanonicalizedId']
        });
      }

      output.add(msg);
    }

    var res2 = await db.rawQuery("$query" + " AND message.originalROWID IS NULL GROUP BY message.ROWID;", [chat.id]);
    for (int i = 0; i < res2.length; i++) {
      Message msg = Message.fromMap(res2[i]);

      // If the handle is not null, load the handle data
      // The handle is null if the message.handleId is 0
      // the handleId is 0 when isFromMe is true and the chat is a group chat
      if (res2[i].containsKey('handleAddress') && res2[i]['handleAddress'] != null) {
        msg.handle = Handle.fromMap({
          'id': res2[i]['handleId'],
          'originalROWID': res2[i]['handleOriginalROWID'],
          'address': res2[i]['handleAddress'],
          'country': res2[i]['handleCountry'],
          'color': res2[i]['handleColor'],
          'uncanonicalizedId': res2[i]['handleUncanonicalizedId']
        });
      }
      for (int j = 0; j < output.length; j++) {
        if (output[j].id! < msg.id!) {
          output.insert(j, msg);
          break;
        }
      }
    }

    return output;*/
  }

  Future<Chat> getParticipants() async {
    /*final Database? db = await DBProvider.db.database;
    if (db == null) return this;*/
    if (this.id == null) return this;
    final handleIds = chJoinBox.getAll().where((element) => element.chatId == this.id).map((e) => e.handleId);
    final handles = handleBox.getMany(handleIds.toList(), growableResult: true)..retainWhere((e) => e != null);
    final nonNullHandles = List<Handle>.from(handles);
    this.participants = nonNullHandles;
    this._deduplicateParticipants();
    this.fakeParticipants = this.participants.map((p) => ContactManager().handleToFakeName[p.address] ?? "Unknown").toList();
    /*var res = await db.rawQuery(
        "SELECT"
        " handle.ROWID AS ROWID,"
        " handle.originalROWID as originalROWID,"
        " handle.address AS address,"
        " handle.country AS country,"
        " handle.color AS color,"
        " handle.defaultPhone AS defaultPhone,"
        " handle.uncanonicalizedId AS uncanonicalizedId"
        " FROM chat"
        " JOIN chat_handle_join AS chj ON chat.ROWID = chj.chatId"
        " JOIN handle ON handle.ROWID = chj.handleId"
        " WHERE chat.ROWID = ?;",
        [this.id]);

    this.participants = (res.isNotEmpty) ? res.map((c) => Handle.fromMap(c)).toList() : [];
    this._deduplicateParticipants();
    this.fakeParticipants = this.participants.map((p) => ContactManager().handleToFakeName[p.address]).toList();*/
    return this;
  }

  Future<Chat> addParticipant(Handle participant) async {
    //final Database? db = await DBProvider.db.database;

    // Save participant and add to list
    await participant.save();
    if (participant.id == null) return this;

    try {
      chJoinBox.put(ChatHandleJoin(chatId: this.id!, handleId: participant.id!));
    } catch (ex) {
      // Don't do anything if it already exists
    }

    // Add to the class and deduplicate
    this.participants.add(participant);
    this._deduplicateParticipants();

    return this;
  }

  Future<Chat> removeParticipant(Handle participant) async {
    //final Database? db = await DBProvider.db.database;

    final query = chJoinBox.query(ChatHandleJoin_.handleId.equals(participant.id!).and(ChatHandleJoin_.chatId.equals(this.id!))).build();
    final result = query.find().first;
    query.close();
    chJoinBox.remove(result.id!);
    // First, remove from the JOIN table
    //await db?.delete("chat_handle_join", where: "chatId = ? AND handleId = ?", whereArgs: [this.id, participant.id]);

    // Second, remove from this object instance
    this.participants.removeWhere((element) => participant.id == element.id);
    this._deduplicateParticipants();

    return this;
  }

  void _deduplicateParticipants() {
    if (this.participants.length == 0) return;
    final ids = this.participants.map((e) => e.address).toSet();
    this.participants.retainWhere((element) => ids.remove(element.address));
  }

  Future<Chat> togglePin(bool isPinned) async {
    //final Database? db = await DBProvider.db.database;
    if (this.id == null) return this;

    this.isPinned = isPinned;
    this._pinIndex.value = null;
    //await db?.update("chat", {"isPinned": isPinned ? 1 : 0}, where: "ROWID = ?", whereArgs: [this.id]);
    this.save();
    ChatBloc().updateChat(this);
    return this;
  }

  Future<Chat> toggleMute(bool isMuted) async {
    //final Database? db = await DBProvider.db.database;
    if (this.id == null) return this;

    this.muteType = isMuted ? "mute" : null;
    this.muteArgs = null;
    //await db?.update("chat", {"muteType": muteType, "muteArgs": muteArgs}, where: "ROWID = ?", whereArgs: [this.id]);
    this.save();
    ChatBloc().updateChat(this);
    return this;
  }

  Future<Chat> toggleArchived(bool isArchived) async {
    //final Database? db = await DBProvider.db.database;
    if (this.id == null) return this;

    this.isArchived = isArchived;
    //await db?.update("chat", {"isArchived": isArchived ? 1 : 0}, where: "ROWID = ?", whereArgs: [this.id]);
    this.save();
    ChatBloc().updateChat(this);
    return this;
  }

  static Future<Chat?> findOne(Map<String, dynamic> filters) async {
    /*final Database? db = await DBProvider.db.database;
    if (db == null) {
      await ChatBloc().chatRequest!.future;
      if (filters['guid'] != null) {
        return ChatBloc().chats.firstWhere((e) => e.guid == filters['guid']);
      } else if (filters['chatIdentifier'] != null) {
        return ChatBloc().chats.firstWhereOrNull((e) => e.chatIdentifier == filters['chatIdentifier']);
      }
      return null;
    }*/

    if (filters['guid'] != null) {
      final query = chatBox.query(Chat_.guid.equals(filters['guid'])).build();
      final result = query.findFirst();
      query.close();
      return result;
    } else if (filters['chatIdentifier'] != null) {
      final query = chatBox.query(Chat_.chatIdentifier.equals(filters['chatIdentifier'])).build();
      final result = query.findFirst();
      query.close();
      return result;
    }
    return null;
/*
    List<String> whereParams = [];
    filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    filters.values.forEach((filter) => whereArgs.add(filter));
    var res = await db.query("chat", where: whereParams.join(" AND "), whereArgs: whereArgs, limit: 1);

    if (res.isEmpty) {
      return null;
    }

    return Chat.fromMap(res.elementAt(0));*/
  }

  static Future<List<Chat>> getChats({int limit = 15, int offset = 0}) async {
    final query = (chatBox.query()..order(Chat_.isPinned, flags: Order.descending)..order(Chat_.latestMessageDate, flags: Order.descending)).build();
    query
      ..limit = limit
      ..offset = offset;
    final chats = query.find();
    query.close();
    return chats;
    /*final Database? db = await DBProvider.db.database;
    if (db == null) return [];

    var res = await db.rawQuery(
      "SELECT"
      " chat.ROWID as ROWID,"
      " chat.originalROWID as originalROWID,"
      " chat.guid as guid,"
      " chat.style as style,"
      " chat.chatIdentifier as chatIdentifier,"
      " chat.isFiltered as isFiltered,"
      " chat.isPinned as isPinned,"
      " chat.isArchived as isArchived,"
      " chat.muteType as muteType,"
      " chat.muteArgs as muteArgs,"
      " chat.hasUnreadMessage as hasUnreadMessage,"
      " chat.latestMessageDate as latestMessageDate,"
      " chat.latestMessageText as latestMessageText,"
      " chat.displayName as displayName,"
      " chat._customAvatarPath as _customAvatarPath,"
      " chat._pinIndex as _pinIndex"
      " FROM chat"
      " ORDER BY chat.isPinned DESC, chat.latestMessageDate DESC LIMIT $limit OFFSET $offset;",
    );

    if (res.isEmpty) return [];

    Iterable<Chat> output = res.map((c) => Chat.fromMap(c));
    bool shouldFilter = SettingsManager().settings.filteredChatList.value;
    if (shouldFilter) {
      output = output.where((item) => !item.isFiltered!);
    }

    return output.toList();*/
  }

  bool isGroup() {
    return this.participants.length > 1;
  }

  Future<void> clearTranscript() async {
    //final Database? db = await DBProvider.db.database;
    final messageIds = cmJoinBox.getAll().where((element) => element.chatId == this.id!).map((e) => e.messageId);
    final messages = messageBox.getAll().where((element) => messageIds.contains(element.id)).toList();
    messages.forEach((element) {
      element.dateDeleted = DateTime.now().toUtc();
    });
    messageBox.putMany(messages);
   /* await db?.rawQuery(
        "UPDATE message "
        "SET dateDeleted = ${DateTime.now().toUtc().millisecondsSinceEpoch} "
        "WHERE ROWID IN ("
        "    SELECT m.ROWID "
        "    FROM message m"
        "    INNER JOIN chat_message_join cmj ON cmj.messageId = m.ROWID "
        "    INNER JOIN chat c ON cmj.chatId = c.ROWID "
        "    WHERE c.guid = ?"
        ");",
        [this.guid]);*/
  }

  Future<Message> get latestMessageFuture async {
    if (latestMessage != null) return latestMessage!;
    List<Message> latests = await Chat.getMessages(this, limit: 1);
    Message message = latests.first;
    latestMessage = message;
    if (message.hasAttachments) {
      await message.fetchAttachments();
    }
    return message;
  }

  static int sort(Chat? a, Chat? b) {
    if (a!._pinIndex.value != null && b!._pinIndex.value != null) return a._pinIndex.value!.compareTo(b._pinIndex.value!);
    if (b!._pinIndex.value != null) return 1;
    if (a._pinIndex.value != null) return -1;
    if (!a.isPinned! && b.isPinned!) return 1;
    if (a.isPinned! && !b.isPinned!) return -1;
    if (a.latestMessageDate == null && b.latestMessageDate == null) return 0;
    if (a.latestMessageDate == null) return 1;
    if (b.latestMessageDate == null) return -1;
    return -a.latestMessageDate!.compareTo(b.latestMessageDate!);
  }

  static flush() async {
    chatBox.removeAll();
    /*final Database? db = await DBProvider.db.database;
    await db?.delete("chat");*/
  }

  Map<String, dynamic> toMap() => {
        "ROWID": id,
        "originalROWID": originalROWID,
        "guid": guid,
        "style": style,
        "chatIdentifier": chatIdentifier,
        "isArchived": isArchived! ? 1 : 0,
        "isFiltered": isFiltered! ? 1 : 0,
        "muteType": muteType,
        "muteArgs": muteArgs,
        "isPinned": isPinned! ? 1 : 0,
        "displayName": displayName,
        "participants": participants.map((item) => item.toMap()),
        "hasUnreadMessage": hasUnreadMessage! ? 1 : 0,
        "latestMessageDate": latestMessageDate != null ? latestMessageDate!.millisecondsSinceEpoch : 0,
        "latestMessageText": latestMessageText,
        "_customAvatarPath": _customAvatarPath,
        "_pinIndex": _pinIndex.value,
      };
}

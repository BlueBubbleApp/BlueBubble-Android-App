import 'dart:async';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../repository/models/chat.dart';
import '../repository/models/handle.dart';

class ChatBloc {
  static StreamSubscription<NewMessageEvent>? _messageSubscription;

  final RxList<Chat> _chats = <Chat>[].obs;

  RxList<Chat> get chats => _chats;
  final RxInt _unreads = 0.obs;

  RxInt get unreads => _unreads;

  final RxBool hasChats = false.obs;
  final RxBool loadedChats = false.obs;

  final List<String> currentChatGuids = [];

  void updateUnreads() {
    _unreads.value = chats.where((element) => element.hasUnreadMessage ?? false).map((e) => e.guid).toList().length;
  }

  Completer<void>? chatRequest;

  static final ChatBloc _chatBloc = ChatBloc._internal();

  ChatBloc._internal();

  factory ChatBloc() {
    return _chatBloc;
  }

  int get pageSize {
    return (SettingsManager().settings.denseChatTiles.value || SettingsManager().settings.skin.value != Skins.iOS)
        ? 14
        : 12;
  }

  Future<Chat?> getChat(String? guid) async {
    if (guid == null) return null;
    if (_chats.isEmpty) {
      await this.refreshChats();
    }

    for (Chat? chat in _chats) {
      if (chat!.guid == guid) return chat;
    }

    return null;
  }

  Future<void> refreshChats({bool force = false}) async {
    // If we are fetching the contacts, return the current future so we can await it
    if (!force && chatRequest != null && !chatRequest!.isCompleted) {
      return chatRequest!.future;
    }

    // If we force a reload, we should wait until the previous one is finished
    if (force && chatRequest != null && !chatRequest!.isCompleted) {
      await chatRequest!.future;
    }

    chatRequest = new Completer<void>();

    debugPrint("[ChatBloc] -> Fetching chats (${force ? 'forced' : 'normal'})...");

    // Get the contacts in case we haven't
    await ContactManager().getContacts();

    if (_messageSubscription == null) {
      _messageSubscription = setupMessageListener();
    }

    // Fetch the first x chats
    getChatBatches();
  }

  /// Inserts a [chat] into the chat bloc based on the lastMessage data
  Future<void> updateChatPosition(Chat chat) async {
    if (isNullOrEmpty(_chats)!) {
      await this.refreshChats();
      if (isNullOrEmpty(_chats)!) return;
    }

    int currentIndex = -1;
    bool shouldUpdate = true;

    // Get the current index of the chat, (if there),
    // and figure out if we need to update the chat.
    for (int i = 0; i < _chats.length; i++) {
      // Skip over non-matching chats
      if (_chats[i].guid != chat.guid) continue;

      // Don't move/update the chat if the latest message for it is newer than the incoming one
      int latest = chat.latestMessageDate != null ? chat.latestMessageDate!.millisecondsSinceEpoch : 0;
      if (_chats[i].latestMessageDate != null && _chats[i].latestMessageDate!.millisecondsSinceEpoch > latest) {
        shouldUpdate = false;
      }

      // Save the current index and break out of the loop
      currentIndex = i;
      break;
    }

    // If we shouldn't update the bloc because the message is older, return here
    if (!shouldUpdate) return;

    if (isNullOrEmpty(chat.title)!) {
      await chat.getTitle();
    }

    // If the current chat isn't found in the bloc, let's insert it at the correct position
    if (currentIndex == -1) {
      for (int i = 0; i < _chats.length; i++) {
        // If the chat is older, that's where we want to insert
        if (_chats[i].latestMessageDate == null ||
            chat.latestMessageDate == null ||
            _chats[i].latestMessageDate!.millisecondsSinceEpoch < chat.latestMessageDate!.millisecondsSinceEpoch) {
          _chats.insert(i, chat);
          break;
        }
      }
      // If we have the index, let's replace it in the chatbloc
    } else {
      _chats[currentIndex] = chat;
    }

    for (int i = 0; i < _chats.length; i++) {
      if (isNullOrEmpty(_chats[i].participants)!) {
        await _chats[i].getParticipants();
      }
    }

    await updateShareTarget(chat);
    _chats.sort(Chat.sort);
  }

  Future<void> markAllAsRead() async {
    // Enumerate the unread chats
    List<Chat> unread = this.chats.where((element) => element.hasUnreadMessage!).toList();

    // Mark them as unread
    for (Chat chat in unread) {
      await chat.toggleHasUnread(false);

      // Remove from notification shade
      MethodChannelInterface().invokeMethod("clear-chat-notifs", {"chatGuid": chat.guid});
    }

    // Update their position in the chat list
    for (Chat chat in unread) {
      this.updateChatPosition(chat);
    }
  }

  Future<void> toggleChatUnread(Chat chat, bool isUnread) async {
    await chat.toggleHasUnread(isUnread);

    // Remove from notification shade
    MethodChannelInterface().invokeMethod("clear-chat-notifs", {"chatGuid": chat.guid});

    this.updateChatPosition(chat);
  }

  Future<void> updateAllShareTargets() async {
    List<Chat> chats = this.chats.sublist(0);
    chats.sort(Chat.sort);

    for (int i = 0; i < 4; i++) {
      if (i >= chats.length) break;
      await updateShareTarget(chats[i]);
    }
  }

  Future<void> updateShareTarget(Chat chat) async {
    Uint8List? icon;
    Contact? contact =
        chat.participants.length == 1 ? await ContactManager().getCachedContact(chat.participants.first) : null;
    try {
      // If there is a contact specified, we can use it's avatar
      if (contact != null && contact.avatar!.isNotEmpty) {
        icon = contact.avatar;
        // Otherwise if there isn't, we use the [defaultAvatar]
      } else {
        // If [defaultAvatar] is not loaded, load it from assets
        if (NotificationManager().defaultAvatar == null) {
          ByteData file = await loadAsset("assets/images/person64.png");
          NotificationManager().defaultAvatar = file.buffer.asUint8List();
        }

        icon = NotificationManager().defaultAvatar;
      }
    } catch (ex) {
      debugPrint("Failed to load contact avatar: ${ex.toString()}");
    }

    // If we don't have a title, try to get it
    if (isNullOrEmpty(chat.title)!) {
      await chat.getTitle();
    }

    // If we still don't have a title, bye felicia
    if (isNullOrEmpty(chat.title)!) return;

    try {
      await MethodChannelInterface().invokeMethod("push-share-targets", {
        "title": chat.title,
        "guid": chat.guid,
        "icon": icon,
      });
    } catch (ex) {
      // Ignore the error, cuz whatever
    }
  }

  Future<void> handleMessageAction(NewMessageEvent event) async {
    // Only handle the "add" action right now
    if (event.type == NewMessageType.ADD) {
      // Find the chat to update
      Chat updatedChat = event.event["chat"];

      // Update the tile values for the chat (basically just the title)
      await initTileValsForChat(updatedChat);

      // Insert/move the chat to the correct position
      await updateChatPosition(updatedChat);
    }
  }

  StreamSubscription<NewMessageEvent> setupMessageListener() {
    // Listen for new messages
    return NewMessageManager().stream.listen(handleMessageAction);
  }

  Future<void> getChatBatches({int batchSize = 10}) async {
    int count = (await Chat.count()) ?? 0;
    if (count == 0) {
      hasChats.value = false;
    } else {
      hasChats.value = true;
    }

    // Reset chat lists
    List<Chat> newChats = [];

    int batches = (count < batchSize) ? batchSize : (count / batchSize).ceil();
    for (int i = 0; i < batches; i++) {
      List<Chat> chats = await Chat.getChats(limit: batchSize, offset: i * batchSize);
      if (chats.length == 0) break;

      for (Chat chat in chats) {
        newChats.add(chat);

        await initTileValsForChat(chat);
      }

      for (int i = 0; i < newChats.length; i++) {
        if (isNullOrEmpty(newChats[i].participants)!) {
          await newChats[i].getParticipants();
        }
      }

      if (newChats.length != 0) {
        _chats.value = newChats;
        _chats.sort(Chat.sort);
      }
    }

    debugPrint("[ChatBloc] -> Finished fetching chats (${_chats.length}).");
    await updateAllShareTargets();

    if (chatRequest != null && !chatRequest!.isCompleted) {
      chatRequest!.complete();
      loadedChats.value = true;
    }
  }

  /// Get the values for the chat, specifically the title
  /// @param chat to initialize
  Future<void> initTileValsForChat(Chat chat) async {
    if (chat.title == null) {
      await chat.getTitle();
    }
    //AttachmentInfoBloc().initChat(chat);
  }

  void archiveChat(Chat chat) async {
    _chats.firstWhere((element) => element.guid == chat.guid).isArchived = true;
    await chat.toggleArchived(true);
    initTileValsForChat(chat);
  }

  void unArchiveChat(Chat chat) async {
    _chats.firstWhere((element) => element.guid == chat.guid).isArchived = false;
    await chat.toggleArchived(false);
    initTileValsForChat(chat);
  }

  void removePinIndices() async {
    _chats.bigPinHelper(true).forEach((element) {
      element.pinIndex.value = null;
      element.save();
    });
    _chats.sort(Chat.sort);
  }

  void updateChatPinIndex(int oldIndex, int newIndex) async {
    final item = _chats.bigPinHelper(true)[oldIndex];
    if (newIndex > oldIndex) {
      newIndex = newIndex - 1;
      _chats.bigPinHelper(true).where((p0) => p0.pinIndex.value != null && p0.pinIndex.value! <= newIndex).forEach((element) {
        element.pinIndex.value = element.pinIndex.value! - 1;
      });
      item.pinIndex.value = newIndex;
    } else {
      _chats.bigPinHelper(true).where((p0) => p0.pinIndex.value != null && p0.pinIndex.value! >= newIndex).forEach((element) {
        element.pinIndex.value = element.pinIndex.value! + 1;
      });
      item.pinIndex.value = newIndex;
    }
    _chats.sort(Chat.sort);
    await item.save();
  }

  void deleteChat(Chat chat) async {
    _chats.removeWhere((element) => element.id == chat.id);
  }

  void updateTileVals(Chat chat, Map<String, dynamic> chatMap, Map<String, Map<String, dynamic>> map) {
    if (map.containsKey(chat.guid)) {
      map.remove(chat.guid);
    }
    if (chat.guid != null) {
      map[chat.guid!] = chatMap;
    }
  }

  void updateChat(Chat chat) async {
    if (_chats.isEmpty) await refreshChats();

    for (int i = 0; i < _chats.length; i++) {
      Chat _chat = _chats[i];
      if (_chat.guid == chat.guid) {
        _chats[i] = chat;
        await initTileValsForChat(chats[i]);
      }
    }
    for (int i = 0; i < _chats.length; i++) {
      if (isNullOrEmpty(_chats[i].participants)!) {
        await _chats[i].getParticipants();
      }
    }
    _chats.sort(Chat.sort);
  }

  addChat(Chat chat) async {
    // Create the chat in the database
    await chat.save();
    refreshChats();
  }

  addParticipant(Chat chat, Handle participant) async {
    // Add the participant to the chat
    await chat.addParticipant(participant);
    refreshChats();
  }

  removeParticipant(Chat chat, Handle participant) async {
    // Add the participant to the chat
    await chat.removeParticipant(participant);
    chat.participants.remove(participant);
    refreshChats();
  }

  dispose() {
    _messageSubscription?.cancel();
  }
}

extension Helpers on RxList<Chat> {
  /// Helper to return archived chats or all chats depending on the bool passed to it
  /// This helps reduce a vast amount of code in build methods so the widgets can
  /// update without StreamBuilders
  RxList<Chat> archivedHelper(bool archived) {
    if (archived)
      return this.where((e) => e.isArchived ?? false).toList().obs;
    else
      return this.where((e) => !(e.isArchived ?? false)).toList().obs;
  }

  RxList<Chat> bigPinHelper(bool pinned) {
    if (pinned)
      return this
          .where((e) => SettingsManager().settings.skin.value == Skins.iOS ? (e.isPinned ?? false) : true)
          .toList()
          .obs;
    else
      return this
          .where((e) => SettingsManager().settings.skin.value == Skins.iOS ? !(e.isPinned ?? false) : true)
          .toList()
          .obs;
  }
}

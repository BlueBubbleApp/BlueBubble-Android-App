import 'dart:async';

import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';

import '../repository/models/handle.dart';
import '../repository/models/chat.dart';
import '../helpers/utils.dart';

class ChatBloc {
  //Stream controller is the 'Admin' that manages
  //the state of our stream of data like adding
  //new data, change the state of the stream
  //and broadcast it to observers/subscribers
  final _chatController = StreamController<List<Chat>>.broadcast();
  final _tileValController =
      StreamController<Map<String, Map<String, dynamic>>>.broadcast();

  Stream<List<Chat>> get chatStream => _chatController.stream;
  Stream<Map<String, Map<String, dynamic>>> get tileStream =>
      _tileValController.stream;

  final _archivedChatController = StreamController<List<Chat>>.broadcast();
  Stream<List<Chat>> get archivedChatStream => _archivedChatController.stream;

  List<Chat> _chats;
  List<Chat> get chats => _chats;

  Chat getChat(String guid) {
    if (_chats == null) return null;
    for (Chat chat in _chats) {
      if (chat.guid == guid) return chat;
    }
    return null;
  }
  // Map<String, Map<String, dynamic>> _tileVals = new Map();
  // Map<String, Map<String, dynamic>> get tileVals => _tileVals;

  // Map<String, Map<String, dynamic>> _archivedTileVals = new Map();
  // Map<String, Map<String, dynamic>> get archivedTiles => _archivedTileVals;

  List<Chat> _archivedChats;
  List<Chat> get archivedChats => _archivedChats;

  factory ChatBloc() {
    return _chatBloc;
  }

  static final ChatBloc _chatBloc = ChatBloc._internal();

  ChatBloc._internal();

  Future<List<Chat>> getChats() async {
    debugPrint("get chats");
    //sink is a way of adding data reactively to the stream
    //by registering a new event
    await ContactManager().getContacts();

    _chats = await Chat.getChats(archived: false, limit: 10);
    debugPrint("first chat is " + _chats.first.chatIdentifier);
    _archivedChats = await Chat.getChats(archived: true);

    NewMessageManager().stream.listen((event) async {
      if ((event.containsKey("oldGuid") && event["oldGuid"] != null) ||
          event.containsKey("remove")) return;
      if (event.keys.first != null) {
        //if there even is a chat specified in the newmessagemanager update
        for (int i = 0; i < _chats.length; i++) {
          if (_chats[i].guid == event.keys.first) {
            if (event.values.first != null) {
              if (!(event.values.first as Message).isFromMe) {
                await _chats[i].markReadUnread(true);
              }
              await initTileValsForChat(
                _chats[i],
                latestMessage: event.values.first,
              );
            } else {
              await initTileValsForChat(_chats[i]);
            }
          }
        }
      } else {
        await initTileVals(_chats);
      }
      _chatController.sink.add(_chats);
    });

    await initTileVals(_chats);
    recursiveGetChats();

    initTileVals(_archivedChats);

    return _chats;
  }

  void recursiveGetChats() async {
    List<Chat> newChats = await Chat.getChats(limit: 10, offset: _chats.length);
    if (newChats.length != 0) {
      _chats.addAll(newChats);
      await initTileVals(newChats);
      recursiveGetChats();
    }
  }

  Future<List<Chat>> moveChatToTop(Chat chat) async {
    for (int i = 0; i < _chats.length; i++)
      if (_chats[i].guid == chat.guid) {
        _chats.removeAt(i);
        break;
      }

    _chats.insert(0, chat);
    await initTileValsForChat(chat);
    _chatController.sink.add(_chats);
    return _chats;
  }

  Future<void> initTileVals(List<Chat> chats, [bool addToSink = true]) async {
    for (int i = 0; i < chats.length; i++) {
      await initTileValsForChat(chats[i]);
    }
    if (addToSink) _chatController.sink.add(_chats);

    // if (customMap == null) _tileValController.sink.add(_tileVals);
  }

  Future<void> initTileValsForChat(Chat chat, {Message latestMessage}) async {
    if (latestMessage != null) {
      chat.latestMessageText = latestMessage.text;
      chat.latestMessageDate = latestMessage.dateCreated;
      if (latestMessage.itemType != 0) {
        chat.latestMessageText = getGroupEventText(latestMessage);
      }
      await Message.getAttachments(
          latestMessage); // This will auto-store the attachments
      await chat.save();
    } else if (chat.latestMessageDate == null ||
        chat.latestMessageDate.millisecondsSinceEpoch == 0) {
      List<Message> messages = await Chat.getMessages(chat, limit: 1);
      Message message = messages.length > 0 ? messages[0] : null;
      if (message != null) {
        chat.latestMessageText = MessageHelper.getNotificationText(message);
        chat.latestMessageDate = message.dateCreated;
        if (message.itemType != 0) {
          chat.latestMessageText = getGroupEventText(message);
        }
        await Message.getAttachments(
            message); // This will auto-store the attachments
        await chat.save();
      }
    }

    if (chat.title == null) await chat.getTitle();
  }

  void archiveChat(Chat chat) async {
    _chats.removeWhere((element) => element.guid == chat.guid);
    _archivedChats.add(chat);
    chat.isArchived = true;
    await chat.save(updateLocalVals: true);
    initTileValsForChat(chat);
    _chatController.sink.add(_chats);
    _archivedChatController.sink.add(_archivedChats);
  }

  void unArchiveChat(Chat chat) async {
    _archivedChats.removeWhere((element) => element.guid == chat.guid);
    chat.isArchived = false;
    await chat.save(updateLocalVals: true);
    await initTileValsForChat(chat);
    _chats.add(chat);
    _archivedChatController.sink.add(_archivedChats);
    _chatController.sink.add(_chats);
  }

  void updateTileVals(Chat chat, Map<String, dynamic> chatMap,
      Map<String, Map<String, dynamic>> map) {
    if (map.containsKey(chat.guid)) {
      map.remove(chat.guid);
    }
    map[chat.guid] = chatMap;
  }

  void updateChat(Chat chat) {
    for (int i = 0; i < _chats.length; i++) {
      Chat _chat = _chats[i];
      if (_chat.guid == chat.guid) {
        _chats[i] = chat;
      }
    }
  }

  addChat(Chat chat) async {
    // Create the chat in the database
    await chat.save();
    getChats();
  }

  addParticipant(Chat chat, Handle participant) async {
    // Add the participant to the chat
    await chat.addParticipant(participant);
    getChats();
  }

  removeParticipant(Chat chat, Handle participant) async {
    // Add the participant to the chat
    await chat.removeParticipant(participant);
    chat.participants.remove(participant);
    getChats();
  }

  dispose() {
    _chatController.close();
    _tileValController.close();
    _archivedChatController.close();
  }
}

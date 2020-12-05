import 'dart:async';
import 'dart:collection';

import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../socket_manager.dart';

abstract class MessageBlocEventType {
  static String insert = "INSERT";
  static String update = "UPDATE";
  static String remove = "REMOVE";
  static String messageUpdate = "MESSAGEUPDATE";
}

class MessageBlocEvent {
  List<Message> messages;
  Message message;
  String remove;
  String oldGuid;
  bool outGoing = false;
  int index;
  String type;
}

class MessageBloc {
  final _messageController = StreamController<MessageBlocEvent>.broadcast();
  Stream<MessageBlocEvent> get stream => _messageController.stream;
  LinkedHashMap<String, Message> _allMessages = new LinkedHashMap();

  int _reactions = 0;
  bool showDeleted = false;

  LinkedHashMap<String, Message> get messages {
    if (!showDeleted) {
      _allMessages.removeWhere((key, value) => value.dateDeleted != null);
    }

    return _allMessages;
  }

  Chat _currentChat;
  

  Chat get currentChat => _currentChat;

  String get firstSentMessage {
    for (Message message in _allMessages.values) {
      if (message.isFromMe) {
        return message.guid;
      }
    }
    return "no sent message found";
  }

  MessageBloc(Chat chat) {
    _currentChat = chat;
    NewMessageManager().stream.listen((msgEvent) {
      if (_messageController.isClosed) return;

      // Ignore any events that don't have to do with the current chat
      if (msgEvent.chatGuid != currentChat.guid) return;

      // Iterate over each action that needs to take place on the chat
      bool addToSink = true;
      MessageBlocEvent baseEvent = new MessageBlocEvent();

      // If we want to remove something, set the event data correctly
      if (msgEvent.type == NewMessageType.REMOVE &&
          _allMessages.containsKey(msgEvent.event["guid"])) {
        _allMessages.remove(msgEvent.event["guid"]);
        baseEvent.remove = msgEvent.event["guid"];
        baseEvent.type = MessageBlocEventType.remove;
      } else if (msgEvent.type == NewMessageType.UPDATE &&
          _allMessages.containsKey(msgEvent.event["oldGuid"])) {
        // If we want to updating an existing message, remove the old one, and add the new one
        _allMessages.remove(msgEvent.event["oldGuid"]);
        insert(msgEvent.event["message"], addToSink: false);
        baseEvent.message = msgEvent.event["message"];
        baseEvent.oldGuid = msgEvent.event["oldGuid"];
        baseEvent.type = MessageBlocEventType.update;
      } else if (msgEvent.type == NewMessageType.ADD) {
        // If we want to add a message, just add it through `insert`
        addToSink = false;
        insert(msgEvent.event["message"],
            sentFromThisClient: msgEvent.event["outgoing"]);
        baseEvent.message = msgEvent.event["message"];
        baseEvent.type = MessageBlocEventType.insert;
      }

      // As long as the controller isn't closed and it's not an `add`, update the listeners
      if (addToSink && !_messageController.isClosed) {
        baseEvent.messages = _allMessages.values.toList();
        _messageController.sink.add(baseEvent);
      }
    });
  }

  void insert(Message message,
      {bool sentFromThisClient = false, bool addToSink = true}) {
    if (message.associatedMessageGuid != null) {
      if (_allMessages.containsKey(message.associatedMessageGuid)) {
        Message messageWithReaction =
            _allMessages[message.associatedMessageGuid];
        messageWithReaction.hasReactions = true;
        _allMessages.update(
            message.associatedMessageGuid, (value) => messageWithReaction);
        if (addToSink) {
          MessageBlocEvent event = MessageBlocEvent();
          event.messages = _allMessages.values.toList();
          event.oldGuid = message.associatedMessageGuid;
          event.message = _allMessages[message.associatedMessageGuid];
          event.type = MessageBlocEventType.update;
          _messageController.sink.add(event);
        }
      }
      return;
    }

    int index = 0;
    if (_allMessages.isEmpty) {
      _allMessages.addAll({message.guid: message});
      if (!_messageController.isClosed && addToSink) {
        MessageBlocEvent event = MessageBlocEvent();
        event.messages = _allMessages.values.toList();
        event.message = message;
        event.outGoing = sentFromThisClient;
        event.type = MessageBlocEventType.insert;
        event.index = index;
        _messageController.sink.add(event);
      }

      return;
    }

    if (sentFromThisClient) {
      _allMessages =
          linkedHashMapInsert(_allMessages, 0, message.guid, message);
    } else {
      List<Message> messages = _allMessages.values.toList();
      for (int i = 0; i < messages.length; i++) {
        //if _allMessages[i] dateCreated is earlier than the new message, insert at that index
        if ((messages[i].originalROWID != null &&
                message.originalROWID != null &&
                message.originalROWID > messages[i].originalROWID) ||
            ((messages[i].originalROWID == null ||
                    message.originalROWID == null) &&
                messages[i].dateCreated.compareTo(message.dateCreated) < 0)) {
          _allMessages =
              linkedHashMapInsert(_allMessages, i, message.guid, message);
          index = i;

          break;
        }
      }
    }

    if (!_messageController.isClosed && addToSink) {
      MessageBlocEvent event = MessageBlocEvent();
      event.messages = _allMessages.values.toList();
      event.message = message;
      event.outGoing = sentFromThisClient;
      event.type = MessageBlocEventType.insert;
      event.index = index;
      _messageController.sink.add(event);
    }
  }

  LinkedHashMap linkedHashMapInsert(map, int index, key, value) {
    List keys = map.keys.toList();
    List values = map.values.toList();
    keys.insert(index, key);
    values.insert(index, value);

    return LinkedHashMap<String, Message>.from(
        LinkedHashMap.fromIterables(keys, values));
  }

  Future<LinkedHashMap<String, Message>> getMessages() async {
    List<Message> messages = await Chat.getMessages(_currentChat);

    if (isNullOrEmpty(messages)) {
      _allMessages = new LinkedHashMap();
    } else {
      messages.forEach((element) {
        if (element.associatedMessageGuid == null) {
          _allMessages.addAll({element.guid: element});
        } else {
          _reactions++;
        }
      });
    }
    if (!_messageController.isClosed) {
      MessageBlocEvent event = MessageBlocEvent();
      event.messages = _allMessages.values.toList();
      _messageController.sink.add(event);
    }
    return _allMessages;
  }

  Future<LoadMessageResult> loadMessageChunk(int offset,
      {bool includeReactions = true,
      bool checkLocal = true,
      CurrentChat currentChat}) async {
    int reactionCnt = includeReactions ? _reactions : 0;
    Completer<LoadMessageResult> completer = new Completer();
    if (_currentChat != null) {
      List<Message> messages = [];
      int count = 0;

      // Should we check locally first?
      if (checkLocal)
        messages =
            await Chat.getMessages(_currentChat, offset: offset + reactionCnt);

      // Fetch messages from the socket
      count = messages.length;
      if (isNullOrEmpty(messages)) {
        try {
          // Fetch messages from the server
          List<dynamic> _messages = await SocketManager()
              .loadMessageChunk(_currentChat, offset + reactionCnt);
          count = _messages.length;

          // Handle the messages
          if (isNullOrEmpty(_messages)) {
            debugPrint("(CHUNK) No message chunks left from server");
            completer.complete(LoadMessageResult.RETREIVED_NO_MESSAGES);
          } else {
            debugPrint(
                "(CHUNK) Received ${_messages.length} messages from socket");

            messages = await MessageHelper.bulkAddMessages(
                _currentChat, _messages,
                notifyMessageManager: false);

            // If the handle is empty, load it
            for (Message msg in messages) {
              if (msg.isFromMe || msg.handle != null) continue;
              await msg.getHandle();
            }
          }
        } catch (ex) {
          debugPrint("(CHUNK) Failed to load message chunk!");
          debugPrint(ex.toString());
          completer.complete(LoadMessageResult.FAILED_TO_RETREIVE);
        }
      }

      // Save the messages to the bloc
      debugPrint("(CHUNK) Emitting ${messages.length} messages to listeners");
      for (Message element in messages) {
        if (element.associatedMessageGuid == null) {
          _allMessages.addAll({element.guid: element});
        } else {
          _reactions++;
        }
      }

      if (currentChat != null) {
        List<Message> messagesWithAttachment =
            messages.where((element) => element.hasAttachments).toList();
        await currentChat.preloadMessageAttachments(
            specificMessages: messagesWithAttachment);
      }

      // Emit messages to listeners
      if (!_messageController.isClosed) {
        MessageBlocEvent event = MessageBlocEvent();
        event.messages = _allMessages.values.toList();
        _messageController.sink.add(event);

        // Complete the execution
        if (count < 25 && !completer.isCompleted) {
          completer.complete(LoadMessageResult.RETREIVED_LAST_PAGE);
        } else if (count >= 25 && !completer.isCompleted) {
          completer.complete(LoadMessageResult.RETREIVED_MESSAGES);
        }
      }
    } else {
      debugPrint("(CHUNK) Failed to load message chunk! Unknown chat!");
      completer.complete(LoadMessageResult.FAILED_TO_RETREIVE);
    }

    return completer.future;
  }

  void dispose() {
    _allMessages = new LinkedHashMap();
    _messageController.close();
  }
}

enum LoadMessageResult {
  RETREIVED_MESSAGES,
  RETREIVED_NO_MESSAGES,
  FAILED_TO_RETREIVE,
  RETREIVED_LAST_PAGE
}

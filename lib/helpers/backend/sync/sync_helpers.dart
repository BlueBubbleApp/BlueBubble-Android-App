import 'package:bluebubbles/core/services/services.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:collection/collection.dart';

// UNUSED METHODS
// List<Handle> syncHandles(List<Handle> handles) {
//   // Get a list of the addresses
//   List<String> inputHandleAddresses = handles.map((element) => element.address).toList();
//
//   // Query the database for existing handles
//   QueryBuilder<Handle> query = db.handles.query(Handle_.address.oneOf(inputHandleAddresses));
//   List<Handle> existingHandles = query.build().find();
//   List<String> existingHandleAddresses = existingHandles.map((e) => e.address).toList();
//
//   // Insert any non-existing handles
//   List<Handle> newHandles = handles.where((element) => !existingHandleAddresses.contains(element.address)).toList();
//   db.handles.putMany(newHandles);
//
//   // Update any existing handles
//   if (existingHandles.isNotEmpty) {
//     int mods = 0;
//     for (var i = 0; i < existingHandles.length; i++) {
//       Handle? newHandle = handles.firstWhereOrNull((e) => e.address == existingHandles[i].address);
//       if (newHandle == null) continue;
//
//       // We put newHandle first because we want the new info to take precedence
//       existingHandles[i] = Handle.merge(newHandle, existingHandles[i]);
//       mods += 1;
//     }
//
//     if (mods > 0) {
//       db.handles.putMany(existingHandles);
//     }
//   }
//
//   // Return a list of the inserted/existing handles
//   QueryBuilder<Handle> query2 = db.handles.query(Handle_.address.oneOf(inputHandleAddresses));
//   List<Handle> syncedHandles = query2.build().find().toList();
//
//   // Insert the real IDs & other information
//   for (var i = 0; i < handles.length; i++) {
//     Handle? synced = syncedHandles.firstWhereOrNull((e) => e.address == handles[i].address);
//     if (synced == null) continue;
//
//     handles[i] = Handle.merge(handles[i], synced);
//   }
//
//   return handles;
// }
//
// List<Chat> syncChats(List<Chat> chats) {
//   // Get a list of the GUIDs
//   List<String> inputChatGuids = chats.map((element) => element.guid).toList();
//
//   // Query the database for existing chats
//   QueryBuilder<Chat> query = db.chats.query(Chat_.guid.oneOf(inputChatGuids));
//   List<Chat> existingChats = query.build().find();
//   List<String> existingChatGuids = existingChats.map((e) => e.guid).toList();
//
//   // Insert any non-existing chats
//   List<Chat> newChats = chats.where((element) => !existingChatGuids.contains(element.guid)).toList();
//   db.chats.putMany(newChats);
//
//   // Update any existing chats
//   if (existingChats.isNotEmpty) {
//     int mods = 0;
//     for (var i = 0; i < existingChats.length; i++) {
//       Chat? newChat = chats.firstWhereOrNull((e) => e.guid == existingChats[i].guid);
//       if (newChat == null) continue;
//
//       // We put newChat first because we want the new info to take precedence
//       existingChats[i] = Chat.merge(newChat, existingChats[i]);
//       mods += 1;
//     }
//
//     if (mods > 0) {
//       db.chats.putMany(existingChats);
//     }
//   }
//
//   // Return a list of the inserted/existing chats
//   QueryBuilder<Chat> query2 = db.chats.query(Chat_.guid.oneOf(inputChatGuids));
//   List<Chat> syncedChats = query2.build().find().toList();
//
//   // Insert the real ID
//   for (var i = 0; i < chats.length; i++) {
//     Chat? synced = syncedChats.firstWhereOrNull((e) => e.guid == chats[i].guid);
//     if (synced == null) continue;
//
//     chats[i] = Chat.merge(chats[i], synced);
//   }
//
//   return chats;
// }

List<Attachment> syncAttachments(List<Attachment> attachments) {
  // Get a list of the GUIDs
  List<String> inputAttachmentGuids = attachments.map((element) => element.guid!).toList();

  // Query the database for existing attachments
  final query = db.attachments.query(Attachment_.guid.oneOf(inputAttachmentGuids)).build();
  List<Attachment> existingAttachments = query.find();
  List<String> existingAttachmentGuids = existingAttachments.map((e) => e.guid!).toList();

  // Insert any non-existing attachments
  List<Attachment> newAttachments = attachments.where(
          (element) => !existingAttachmentGuids.contains(element.guid)).toList();
  db.attachments.putMany(newAttachments);

  // Update any existing attachments
  if (existingAttachments.isNotEmpty) {
    int mods = 0;
    for (var i = 0; i < existingAttachments.length; i++) {
      Attachment? newAttachment = attachments.firstWhereOrNull((e) => e.guid == existingAttachments[i].guid);
      if (newAttachment == null) continue;

      // We put newAttachment first because we want the new info to take precedence
      existingAttachments[i] = Attachment.merge(newAttachment, existingAttachments[i]);
      mods += 1;
    }

    if (mods > 0) {
      db.attachments.putMany(existingAttachments);
    }
  }

  // Return a list of the inserted/existing attachments
  final query2 = db.attachments.query(Attachment_.guid.oneOf(inputAttachmentGuids)).build();
  List<Attachment> syncedAttachments = query2.find().toList();

  // Insert the real ID
  for (var i = 0; i < attachments.length; i++) {
    Attachment? synced = syncedAttachments.firstWhereOrNull((e) => e.guid == attachments[i].guid);
    if (synced == null) continue;

    attachments[i] = Attachment.merge(attachments[i], synced);
  }

  return attachments;
}

List<Message> syncMessages(Chat c, List<Message> messages) {
  // Get a list of the GUIDs
  List<String> inputMessageGuids = messages.map((element) => element.guid!).toList();

  // Query the database for existing messages
  final query = db.messages.query(Message_.guid.oneOf(inputMessageGuids)).build();
  List<Message> existingMessages = query.find();
  List<String> existingMessageGuids = existingMessages.map((e) => e.guid!).toList();

  // Insert any non-existing messages
  List<Message> newMessages = messages.where((element) => !existingMessageGuids.contains(element.guid)).toList();
  db.messages.putMany(newMessages);

  // Update any existing messages
  if (existingMessages.isNotEmpty) {
    int mods = 0;
    for (var i = 0; i < existingMessages.length; i++) {
      Message? newMessage = messages.firstWhereOrNull((e) => e.guid == existingMessages[i].guid);
      if (newMessage == null) continue;

      // We put newMessage first because we want the new info to take precedence
      existingMessages[i] = Message.merge(newMessage, existingMessages[i]);
      mods += 1;
    }

    if (mods > 0) {
      db.messages.putMany(existingMessages, mode: PutMode.update);
    }
  }

  // Return a list of the inserted/existing messages
  final query2 = db.messages.query(Message_.guid.oneOf(inputMessageGuids)).build();
  List<Message> syncedMessages = query2.find().toList();

  // Insert the real ID & chat
  for (var i = 0; i < messages.length; i++) {
    Message? synced = syncedMessages.firstWhereOrNull((e) => e.guid == messages[i].guid);
    if (synced == null) continue;

    messages[i] = Message.merge(messages[i], synced);
    messages[i].chat.target = c;
  }

  // Apply the chats
  db.messages.putMany(messages, mode: PutMode.update);

  return messages;
}
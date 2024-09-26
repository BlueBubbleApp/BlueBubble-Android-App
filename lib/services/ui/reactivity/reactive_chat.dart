import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:get/get.dart';

class ReactiveChat {
  final Chat chat;

  final RxBool _isDeleted = false.obs;
  final RxBool _isArchived = false.obs;
  final RxBool _isUnread = false.obs;
  final RxBool _isPinned = false.obs;
  final RxnString _muteType = RxnString();
  final RxnString _title = RxnString();
  final RxnString _subtitle = RxnString();
  final RxnString _customAvatarPath = RxnString();
  final RxList<Handle> _participants = <Handle>[].obs;
  final Rxn<Message> _latestMessage = Rxn<Message>();
  final RxList<String> _pickedAttachments = <String>[].obs;
  final RxString _textFieldText = "".obs;
  final RxBool _isHighlighted = false.obs;
  final RxBool _isObscured = false.obs;

  RxnString get title {
    if (_title.value != null) {
      return _title;
    }

    _title.value = chat.getTitle();
    return _title;
  }

  RxnString get subtitle {
    if (_subtitle.value != null) {
      return _subtitle;
    }

    if (chat.latestMessage == null) {
      _subtitle.value = "[ No messages ]";
    } else {
      _subtitle.value = MessageHelper.getNotificationText(chat.latestMessage!);
    }

    return _subtitle;
  }

  RxBool get isDeleted => _isDeleted;

  RxBool get isArchived => _isArchived;

  RxBool get isUnread => _isUnread;

  RxBool get isPinned => _isPinned;

  RxnString get muteType => _muteType;

  RxList<Handle> get participants => _participants;

  Rxn<Message> get latestMessage => _latestMessage;

  RxnString get customAvatarPath => _customAvatarPath;

  RxList<String> get pickedAttachments => _pickedAttachments;

  RxString get textFieldText => _textFieldText;

  RxBool get isHighlighted => _isHighlighted;

  // The app currently has the chat opened
  bool get isOpen => GlobalChatService.activeGuid.value == chat.guid;

  // Active means it's in the foreground
  bool get isAlive => ls.isAlive && isOpen && !_isObscured.value;

  ReactiveChat(this.chat, {
    bool isUnread = false,
    bool isPinned = false,
    String? muteType,
    String? title,
    String? subtitle,
    String? customAvatarPath,
    bool isArchived = false,
    bool isDeleted = false,
    List<String> pickedAttachments = const [],
    String? textFieldText,
    List<Handle> participants = const [],
    Message? latestMessage,
  }) {
    _isUnread.value = isUnread;
    _isPinned.value = isPinned;
    _muteType.value = muteType;
    _title.value = title;
    _subtitle.value = subtitle;
    _customAvatarPath.value = customAvatarPath;
    _isArchived.value = isArchived;
    _isDeleted.value = isDeleted;
    _pickedAttachments.value = pickedAttachments;
    _textFieldText.value = textFieldText ?? "";

    _participants.value = participants;
    _latestMessage.value = latestMessage;
  }

  setIsUnread(bool value) {
    chat.hasUnreadMessage = value;
    _isUnread.value = value;
    chat.save(updateHasUnreadMessage: true);
  }

  setMuteType(String? value) {
    _muteType.value = value;
    chat.toggleMute(value == "mute");
  }

  setParticipants(List<Handle> value) {
    _participants.value = value;
  }

  setLatestMessage(Message value) {
    _latestMessage.value = value;
    chat.latestMessage = value;
    chat.save();
    GlobalChatService.sortChat(chat.guid);
  }

  setIsArchived(bool value) {
    _isArchived.value = value;
    _isPinned.value = false;
    chat.toggleArchived(value);
    GlobalChatService.sortChat(chat.guid);
  }

  setIsDeleted(bool value) {
    _isDeleted.value = value;
    _isPinned.value = false;
    chat.dateDeleted = value ? DateTime.now().toUtc() : null;
    chat.isPinned = false;
    chat.save(updateDateDeleted: true, updateIsPinned: true);
    GlobalChatService.sortChat(chat.guid);
  }

  setCustomAvatarPath(String? value) {
    _customAvatarPath.value = value;
    chat.customAvatarPath = value;
    chat.save(updateCustomAvatarPath: true);
  }

  setPinned(bool value) {
    _isPinned.value = value;
    chat.togglePin(value);
  }

  addPickedAttachment(String path) {
    _pickedAttachments.add(path);
    chat.textFieldAttachments.add(path);
    chat.save(updateTextFieldAttachments: true);
  }

  removePickedAttachment(String path) {
    _pickedAttachments.remove(path);
    chat.textFieldAttachments.remove(path);
    chat.save(updateTextFieldAttachments: true);
  }

  setTextFieldText(String value) {
    _textFieldText.value = value;
    chat.textFieldText = value;
    chat.save(updateTextFieldText: true);
  }

  setIsObscured(bool value) {
    _isObscured.value = value;
  }

  factory ReactiveChat.fromChat(Chat chat) {
    return ReactiveChat(
      chat,
      isUnread: chat.hasUnreadMessage ?? false,
      muteType: chat.muteType,
      title: null,
      subtitle: null,
      customAvatarPath: chat.customAvatarPath,
      isArchived: chat.isArchived ?? false,
      isDeleted: chat.dateDeleted != null,
      participants: chat.participants,
      latestMessage: chat.latestMessage
    );
  }
}
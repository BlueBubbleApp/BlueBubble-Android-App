import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/setup_bloc.dart';
import 'package:bluebubbles/helpers/attachment_sender.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/crypto.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/incoming_queue.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/fcm_data.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:socket_io_client/socket_io_client.dart';

enum SocketState {
  CONNECTED,
  DISCONNECTED,
  ERROR,
  CONNECTING,
  FAILED,
}

class SocketManager {
  factory SocketManager() {
    return _manager;
  }

  static final SocketManager _manager = SocketManager._internal();

  SocketManager._internal();

  Future<void> removeChatNotification(Chat chat) async {
    await chat.toggleHasUnread(false);
    ChatBloc().updateChat(chat);
  }

  List<String> processedGUIDS = <String>[];

  SetupBloc setup = new SetupBloc();
  StreamController<bool?> finishedSetup = StreamController<bool?>();
  bool isAuthingFcm = false;

  //Socket io
  IO.Socket? socket;

  Map<String, AttachmentSender> attachmentSenders = Map();
  Map<int, Function> socketProcesses = new Map();

  final Rx<SocketState> state = SocketState.DISCONNECTED.obs;

  int addSocketProcess(Function() cb) {
    int processId = Random().nextInt(10000);
    socketProcesses[processId] = cb;
    Future.delayed(Duration(milliseconds: Random().nextInt(100)), () {
      if (state.value == SocketState.DISCONNECTED || state.value == SocketState.FAILED) {
        _manager.startSocketIO();
      } else if (state.value == SocketState.CONNECTED) {
        cb();
      }
    });
    return processId;
  }

  void finishSocketProcess(int? processId) {
    socketProcesses.remove(processId);
    Future.delayed(Duration(milliseconds: Random().nextInt(100)), () {
      _socketProcessUpdater.sink.add(socketProcesses.keys.toList());
    });
  }

  StreamController<List<int>> _socketProcessUpdater = StreamController<List<int>>.broadcast();

  Stream<List<int>> get socketProcessUpdater => _socketProcessUpdater.stream;

  StreamController<String> _attachmentSenderCompleter = StreamController<String>.broadcast();
  Stream<String> get attachmentSenderCompleter => _attachmentSenderCompleter.stream;

  void addAttachmentSender(AttachmentSender sender) {
    if (sender.guid == null) return;
    attachmentSenders[sender.guid!] = sender;
  }

  void finishSender(String attachmentGuid) {
    attachmentSenders.remove(attachmentGuid);
    _attachmentSenderCompleter.sink.add(attachmentGuid);
  }

  Map<String, Function> disconnectSubscribers = new Map();

  String? token;

  void socketStatusUpdate(data) {
    debugPrint("[Socket] -> Socket status update: $data");

    switch (data) {
      case "connect":
        authFCM();
        NotificationManager().clearSocketWarning();
        _manager.disconnectSubscribers.forEach((key, value) {
          value();
          _manager.disconnectSubscribers.remove(key);
        });

        state.value = SocketState.CONNECTED;
        _manager.socketProcesses.values.forEach((element) {
          element();
        });
        if (SettingsManager().settings.finishedSetup.value)
          setup.startIncrementalSync(SettingsManager().settings, onConnectionError: (String err) {
            debugPrint("(SYNC) Error performing incremental sync. Not saving last sync date.");
            debugPrint(err);
          });
        return;
      case "connect_error":
        if (state.value != SocketState.ERROR && state.value != SocketState.FAILED) {
          state.value = SocketState.ERROR;
          Timer(Duration(seconds: 5), () {
            if (state.value != SocketState.ERROR) return;
            refreshConnection(connectToSocket: true);
          });
          Timer(Duration(seconds: 20), () {
            if (state.value != SocketState.ERROR) return;
            debugPrint("[Socket] -> Unable to connect");

            // Only show the notification if setup is finished
            if (SettingsManager().settings.finishedSetup.value) {
              NotificationManager().createSocketWarningNotification();
            }

            state.value = SocketState.FAILED;
            List processes = socketProcesses.values.toList();
            processes.forEach((value) {
              value(true);
            });
            socketProcesses = new Map();
            if (!LifeCycleManager.instance.isAlive) {
              closeSocket(force: true);
            }
          });
        }
        return;
      case "disconnect":
        if (state.value == SocketState.FAILED) return;
        _manager.disconnectSubscribers.values.forEach((f) {
          f();
        });

        state.value = SocketState.DISCONNECTED;
        Timer t;
        t = Timer(const Duration(seconds: 5), () {
          if (state.value == SocketState.DISCONNECTED && LifeCycleManager.instance.isAlive && !Get.isSnackbarOpen!) {
            showSnackbar('Socket Disconnected', 'You are not longer connected to the socket 🔌');
          }
        });
        LifeCycleManager.instance.stream.listen((event) {
          if (!event && t.isActive) {
            t.cancel();
          } else {
            t = Timer(const Duration(seconds: 5), () {
              if (state.value == SocketState.DISCONNECTED && LifeCycleManager.instance.isAlive && !Get.isSnackbarOpen!) {
                showSnackbar('Socket Disconnected', 'You are not longer connected to the socket 🔌');
              }
            });
          }
        });
        return;
      case "reconnect":
        debugPrint("RECONNECTED");
        state.value = SocketState.CONNECTING;
        _manager.socketProcesses.values.forEach((element) {
          element();
        });
        return;
      default:
        return;
    }
  }

  Future<String> handleNewMessage(_data) async {
    Map<String, dynamic>? data = _data;
    IncomingQueue().add(new QueueItem(event: "handle-message", item: {"data": data}));
    return new Future.value("");
  }

  Future<String> handleChatStatusChange(_data) async {
    if (!SettingsManager().settings.enablePrivateAPI.value) return new Future.value("");

    Map<String, dynamic>? data = _data;
    IncomingQueue().add(new QueueItem(event: IncomingQueue.HANDLE_CHAT_STATUS_CHANGE, item: {"data": data}));
    return new Future.value("");
  }

  Future<void> startSocketIO({bool forceNewConnection = false, bool catchException = true}) async {
    //removed check for settings being null here, could be an issue later but I doubt it (tneotia)
    if ((state.value == SocketState.CONNECTING || state.value == SocketState.CONNECTED) && !forceNewConnection) {
      debugPrint("[Socket] -> Already connected");
      return;
    }
    if (state.value == SocketState.FAILED) {
      state.value = SocketState.CONNECTING;
    }

    // If we already have a socket connection, kill it
    if (_manager.socket != null) {
      _manager.socket!.destroy();
    }

    String? serverAddress = getServerAddress();
    if (serverAddress == null) {
      debugPrint("[Socket] -> Server Address is not yet configured. Not connecting...");
      return;
    }

    debugPrint("[Socket] -> Starting socket io with the server: $serverAddress");

    try {
      // Create a new socket connection
      /*_manager.socket = SocketIOManager().createSocketIO(serverAddress, "/",
          query: "guid=${encodeUri(SettingsManager().settings.guidAuthKey)}",
          socketStatusCallback: (data) => socketStatusUpdate(data));*/
      _manager.socket = IO.io(
          serverAddress,
          OptionBuilder()
              .setQuery({"guid": encodeUri(SettingsManager().settings.guidAuthKey.value)})
              .setTransports(['websocket', 'polling'])
              .enableAutoConnect()
              .disableForceNewConnection()
              .enableReconnection()
              .build());

      if (_manager.socket == null) {
        debugPrint("[Socket] -> Socket was never created. Can't connect to server...");
        return;
      }

      _manager.socket!.clearListeners();

      _manager.socket!.onConnect((data) => socketStatusUpdate("connect"));
      _manager.socket!.onReconnect((data) => socketStatusUpdate("reconnect"));
      _manager.socket!.onDisconnect((data) => socketStatusUpdate("disconnect"));
      _manager.socket!.onConnectError((data) => socketStatusUpdate("connect_error"));
      _manager.socket!.onConnectTimeout((data) => socketStatusUpdate("connect_timeout"));
      _manager.socket!.onReconnectAttempt((data) => socketStatusUpdate("reconnect_attempt"));
      _manager.socket!.onConnecting((data) => socketStatusUpdate("connecting"));
      _manager.socket!.onReconnect((data) => socketStatusUpdate("reconnect"));
      _manager.socket!.onReconnecting((data) => socketStatusUpdate("reconnecting"));
      _manager.socket!.onError((data) => socketStatusUpdate("error"));

      /**
       * Callback event for when the server successfully added a new FCM device
       */
      _manager.socket!.on("fcm-device-id-added", (data) {
        // TODO: Possibly turn this into a notification for the user?
        // This could act as a "pseudo" security measure so they're alerted
        // when a new device is registered
        debugPrint("[Socket] -> FCM device added: " + data.toString());
      });

      /**
       * If the server sends us an error it ran into, handle it
       */
      _manager.socket!.on("error", (data) {
        debugPrint("[Socket] -> An error occurred: " + data.toString());
      });

      /**
       * Handle new messages detected by the server
       */
      _manager.socket!.on("new-message", handleNewMessage);
      _manager.socket!.on("group-name-change", handleNewMessage);
      _manager.socket!.on("participant-removed", handleNewMessage);
      _manager.socket!.on("participant-added", handleNewMessage);
      _manager.socket!.on("participant-left", handleNewMessage);

      /**
       * Handle Private API features
       */
      _manager.socket!.on("chat-read-status-changed", handleChatStatusChange);
      _manager.socket!.on("typing-indicator", (_data) {
        if (!SettingsManager().settings.enablePrivateAPI.value) return;

        Map<String, dynamic> data = _data;
        CurrentChat? currentChat = CurrentChat.forGuid(data["guid"]);
        if (currentChat == null) return;
        if (data["display"]) {
          currentChat.displayTypingIndicator();
        } else {
          currentChat.hideTypingIndicator();
        }
      });

      /**
       * Handle errors sent by the server
       */
      _manager.socket!.on("message-send-error", (_data) async {
        Map<String, dynamic> data = _data;
        Message message = Message.fromMap(data);

        // If there are no chats, try to find it in the DB via the message
        Chat? chat;
        if (isNullOrEmpty(data["chats"])!) {
          chat = await Message.getChat(message);
        } else {
          chat = Chat.fromMap(data['chats'][0]);
        }

        // Save the chat in-case is doesn't exist
        if (chat != null) {
          await chat.save();
        }

        // Lastly, find the message
        Message msg = (await Message.findOne({'guid': message.guid}))!;

        // Check if we already have an error, and save if we don't
        if (msg.error.value == 0) {
          // TODO: ADD NOTIFICATION TO USER IF FAILURE
          await message.save();
        }

        return new Future.value("");
      });

      /**
       * When the server detects a message timeout (aka, no match found),
       * handle it by replacing the temp-guid with error-guid so we can do
       * something about it (or at least just track it)
       */
      _manager.socket!.on("message-timeout", (_data) async {
        debugPrint("[Socket] -> Client received message timeout");
        Map<String, dynamic> data = _data;

        Message? message = await Message.findOne({"guid": data["tempGuid"]});
        if (message == null) return new Future.value("");
        message.error.value = 1003;
        message.guid = message.guid!.replaceAll("temp", "error-Message Timeout");
        await Message.replaceMessage(data["tempGuid"], message);
        return new Future.value("");
      });

      /**
       * When an updated message comes in, update it in the database.
       * This may be when a read/delivered date has been changed.
       */
      _manager.socket!.on("updated-message", (_data) async {
        IncomingQueue().add(new QueueItem(event: "handle-updated-message", item: {"data": _data}));
      });

      _manager.socket!.connect();
    } catch (e) {
      if (!catchException) {
        throw ("[Socket] -> " + e.toString());
      } else {
        debugPrint("[Socket] -> Failed to connect");
      }
    }
  }

  void closeSocket({bool force = false}) {
    if (!force && _manager.socketProcesses.length != 0) {
      debugPrint("won't close " + socketProcesses.length.toString());
      return;
    }
    if (_manager.socket != null) {
      _manager.socket!.disconnect();
      _manager.socket!.destroy();
    }
    _manager.socket = null;
    state.value = SocketState.DISCONNECTED;
    NotificationManager().clearSocketWarning();
  }

  Future<void> authFCM({bool catchException = true, bool force = false}) async {
    if (!SettingsManager().settings.finishedSetup.value) return;

    if (isAuthingFcm && !force) {
      debugPrint('Currently authenticating with FCM, not doing it again...');
      return;
    }

    isAuthingFcm = true;

    if (SettingsManager().fcmData!.isNull) {
      debugPrint("[FCM Auth] -> No FCM Auth data found. Skipping FCM authentication");
      isAuthingFcm = false;
      return;
    }

    String deviceName = await getDeviceName();
    if (token != null && !force) {
      debugPrint("[FCM Auth] -> Already authorized FCM device! Token: $token");
      await registerDevice(deviceName, token);
      isAuthingFcm = false;
      return;
    }

    String? result;

    try {
      // First, try to send what we currently have
      debugPrint('[FCM Auth] -> Authenticating with FCM');
      result = await MethodChannelInterface().invokeMethod('auth', SettingsManager().fcmData!.toMap());
    } on PlatformException catch (ex) {
      debugPrint('[FCM Auth] -> Failed to perform initial FCM authentication: ${ex.toString()}');
      debugPrint('[FCM Auth] -> Fetching FCM data from the server...');

      // If the first try fails, let's try again, but first, get the FCM data from the server
      Map<String, dynamic> fcmMeta = await this.getFcmClient();
      debugPrint('[FCM Auth] -> Received FCM data from the server. Attempting to re-authenticate');

      try {
        // Parse out the new FCM data
        FCMData fcmData = parseFcmJson(fcmMeta);

        // Save the FCM data in settings
        SettingsManager().saveFCMData(fcmData);

        // Retry authenticating with Firebase
        result = await MethodChannelInterface().invokeMethod('auth', SettingsManager().fcmData!.toMap());
      } on PlatformException catch (e) {
        if (!catchException) {
          isAuthingFcm = false;
          throw Exception("[FCM Auth] -> " + e.toString());
        } else {
          debugPrint("[FCM Auth] -> Failed to register with FCM: " + e.toString());
        }
      }
    }

    if (isNullOrEmpty(result)!) {
      debugPrint("[FCM Auth] -> Empty results, not registering device with the server.");
    }

    try {
      token = result;
      debugPrint('[FCM Auth] -> Registering device with server...');
      await registerDevice(deviceName, token);
    } catch (ex) {
      isAuthingFcm = false;
      debugPrint('[FCM Auth] -> Failed to register device with server: ${ex.toString()}');
      throw Exception("Failed to add FCM device to the server! Token: $token");
    }

    isAuthingFcm = false;
  }

  Future<dynamic>? registerDevice(String name, String? token) {
    if (name.trim().length == 0 || token == null || token.trim().length == 0) return null;
    dynamic params = {"deviceId": token.trim(), "deviceName": name.trim()};
    return request("add-fcm-device", params);
  }

  Future<List<Chat>> getChats(Map<String, dynamic> params, {Function(List<dynamic>?)? cb}) async {
    List<Chat> chats = [];
    List<dynamic> data = await request('get-chats', params, cb: cb);
    for (var item in data) {
      try {
        var chat = Chat.fromMap(item);
        chats.add(chat);
      } catch (ex) {
        chats.add(Chat(guid: "ERROR", displayName: item.toString()));
      }
    }
    return chats;
  }

  Future<dynamic>? getMessages(Map<String, dynamic> params, {Function(List<dynamic>?)? cb}) {
    return request('get-messages', params, cb: cb);
  }

  Future<dynamic>? getChatMessages(Map<String, dynamic> params, {Function(List<dynamic>?)? cb}) {
    return request('get-chat-messages', params, cb: cb);
  }

  Future<dynamic>? request(String path, Map<String, dynamic> params, {Function(List<dynamic>?)? cb}) {
    Completer<List<dynamic>?> completer = new Completer();
    if (_manager.socket == null) return null;

    debugPrint("[Socket] -> Sending request for '$path'");
    _manager.sendMessage(path, params, (Map<String, dynamic> data) async {
      if (data["status"] != 200) return completer.completeError(data);

      dynamic output;
      if (data.containsKey("data")) {
        output = data["data"];
      }

      if (!completer.isCompleted) completer.complete(output);
      if (cb != null) cb(output);
    });

    return completer.future;
  }

  Future<dynamic>? getAttachments(String chatGuid, String messageGuid, {Function(List<dynamic>?)? cb}) {
    Map<String, dynamic> params = {
      'after': 1,
      'identifier': chatGuid,
      'limit': 1,
      'withAttachments': true,
      'withChats': true,
      'where': [
        {
          'statement': 'message.guid = :guid',
          'args': {'guid': messageGuid}
        }
      ]
    };

    return request('get-messages', params);
  }

  Future<List<dynamic>> loadMessageChunk(Chat chat, int offset, {limit = 25}) async {
    Completer<List<dynamic>> completer = new Completer();

    Map<String, dynamic> params = Map();
    params["identifier"] = chat.guid;
    params["limit"] = limit;
    params["offset"] = offset;
    params["withBlurhash"] = false;
    params["where"] = [
      {"statement": "message.service = 'iMessage'", "args": null}
    ];

    SocketManager().sendMessage("get-chat-messages", params, (data) async {
      if (data['status'] != 200) {
        completer.completeError(data['error']);
      }

      if (!completer.isCompleted) completer.complete(data["data"]);
    });

    return completer.future;
  }

  Future<Chat?> fetchChat(String chatGuid, {withParticipants = true}) async {
    Completer<Chat?> completer = new Completer();
    debugPrint("[Fetch Chat] Fetching full chat metadata from server.");

    Map<String, dynamic> params = Map();
    params["chatGuid"] = chatGuid;
    params["withParticipants"] = withParticipants;
    SocketManager().sendMessage("get-chat", params, (data) async {
      if (data['status'] != 200 && !completer.isCompleted) {
        return completer.completeError(new Exception(data['error']['message']));
      }

      Map<String, dynamic>? chatData = data["data"];
      if (chatData == null) {
        debugPrint("[Fetch Chat] Server returned no metadata for chat.");
        return completer.complete(null);
      }

      debugPrint("[Fetch Chat] Got updated chat metadata from server. Saving.");
      Chat newChat = Chat.fromMap(chatData);

      // Resave the chat after we've got the participants
      await newChat.save();
      completer.complete(newChat);
    });

    return completer.future;
  }

  Future<dynamic>? fetchMessages(Chat? chat,
      {int offset: 0,
      int limit: 100,
      int? after,
      bool onlyAttachments: false,
      List<Map<String, dynamic>> where: const []}) async {
    debugPrint("(Fetch Messages) Fetching data.");

    Map<String, dynamic> params = Map();
    params["chatGuid"] = chat?.guid;
    params["offset"] = offset;
    params["limit"] = limit;
    params["withAttachments"] = true;
    params["withHandle"] = true;
    params["sort"] = "DESC";
    params["where"] = where;

    if (after != null) {
      params["after"] = after;
    }

    if (onlyAttachments) {
      params["where"].add({
        "statement": "message.cache_has_attachments = :flag",
        "args": {"flag": 1}
      });
    }

    return getMessages(params)!;
  }

  Future<Map<String, dynamic>> sendMessage(
      String event, Map<String, dynamic>? message, Function(Map<String, dynamic>) cb,
      {String? reason, bool awaitResponse = true, String? path}) {
    Completer<Map<String, dynamic>> completer = Completer();
    int _processId = 0;
    Function socketCB = ([bool finishWithError = false]) {
      if (finishWithError) {
        cb({
          'status': MessageError.NO_CONNECTION,
          'error': {'message': 'Failed to Connect'}
        });
        completer.complete({
          'status': MessageError.NO_CONNECTION,
          'error': {'message': 'Failed to Connect'}
        });
        if (awaitResponse) _manager.finishSocketProcess(_processId);
      } else {
        if (path == null) {
          _manager.socket!.emitWithAck(event, message, ack: (response) {
            if (response.containsKey('encrypted') && response['encrypted']) {
              try {
                response['data'] =
                    jsonDecode(decryptAESCryptoJS(response['data'], SettingsManager().settings.guidAuthKey.value));
              } catch (ex) {
                response['data'] = decryptAESCryptoJS(response['data'], SettingsManager().settings.guidAuthKey.value);
              }
            }

            cb(response);
            if (!completer.isCompleted) {
              completer.complete(response);
            }

            if (awaitResponse) _manager.finishSocketProcess(_processId);
          });
        } else {
          _manager.socket!.emitWithAck(event, message, ack: (response) async {
            await MethodChannelInterface().invokeMethod("download-file", {
              "data": response['data'],
              "path": path,
            });
            response['byteLength'] = base64.decode(response['data']).length;
            cb(response);
            completer.complete(response);
            if (awaitResponse) _manager.finishSocketProcess(_processId);
          });
        }
      }
    };

    if (awaitResponse) {
      _processId = _manager.addSocketProcess(socketCB as dynamic Function());
    } else {
      socketCB();
    }
    if (reason != null) debugPrint("added process with id " + _processId.toString() + " because $reason");

    return completer.future;
  }

  void toggleSetupFinished(bool isFinished, {bool applyToDb = true}) {
    finishedSetup.sink.add(isFinished);

    if (SettingsManager().settings.finishedSetup.value != isFinished) {
      SettingsManager().settings.finishedSetup.value = isFinished;
      SettingsManager().saveSettings(SettingsManager().settings);
    }
  }

  /// Updates and saves a new server address and then forces a new reconnection to the socket with this address
  ///
  /// @param [serverAddress] is the new address to update to
  Future<void> newServer(String serverAddress) async {
    // We copy the settings to a local variable
    Settings settingsCopy = SettingsManager().settings;
    if (settingsCopy.serverAddress.value == serverAddress) {
      debugPrint("Server address didn't actually change. Ignoring...");
      return;
    }

    // Update the address of the copied settings
    settingsCopy.serverAddress.value = getServerAddress(address: serverAddress) ?? settingsCopy.serverAddress.value;

    // And then save to disk
    // NOTE: we do not automatically connect to the socket or authorize fcm,
    //       because we need to do that manually with a forced connection
    await SettingsManager().saveSettings(settingsCopy);

    // Then we connect to the socket.
    // We force a connection because the socket may still be attempting to connect to the socket,
    // in which case it won't attempt to connect again.
    // We need to override this behavior.
    SocketManager().startSocketIO(forceNewConnection: true);
  }

  dispose() {
    _attachmentSenderCompleter.close();
    _socketProcessUpdater.close();
    finishedSetup.close();
  }

  Future<void> refreshConnection({bool connectToSocket = true}) async {
    debugPrint("Fetching new server URL from Firebase");

    // Get the server URL
    try {
      String? url = await MethodChannelInterface().invokeMethod("get-server-url");
      url = getServerAddress(address: url);

      debugPrint("New server URL: $url");

      // Set the server URL
      Settings _settingsCopy = SettingsManager().settings;
      if (_settingsCopy.serverAddress.value == url) return;
      _settingsCopy.serverAddress.value = url ?? _settingsCopy.serverAddress.value;
      await SettingsManager().saveSettings(_settingsCopy);
      if (connectToSocket) {
        startSocketIO(forceNewConnection: connectToSocket);
      }
    } catch (e) {}
  }

  Future<Map<String, dynamic>> getFcmClient() async {
    Completer<Map<String, dynamic>> completer = new Completer<Map<String, dynamic>>();

    SocketManager().sendMessage("get-fcm-client", {}, (data) {
      if (data["status"] == 200) {
        completer.complete(data["data"] as Map<String, dynamic>?);
      } else {
        String? msg = "Failed to get FCM client data";
        if (data.containsKey("error") && data["error"].containsKey("message")) {
          msg = data["error"]["message"];
        }

        completer.completeError(new Exception(msg));
      }
    }).catchError((err) {
      completer.completeError(err);
    });

    return completer.future;
  }
}

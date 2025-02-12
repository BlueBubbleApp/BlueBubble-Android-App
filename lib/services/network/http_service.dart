import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

/// Get an instance of our [HttpService]
HttpService http = Get.isRegistered<HttpService>() ? Get.find<HttpService>() : Get.put(HttpService());

/// Class that manages foreground network requests from client to server, using
/// GET or POST requests.
class HttpService extends GetxService {
  late Dio dio;
  String? originOverride;

  /// Get the URL origin from the current server address
  String get origin => originOverride ?? (Uri.parse(ss.settings.serverAddress.value).hasScheme ? Uri.parse(ss.settings.serverAddress.value).origin : '');
  String get apiRoot => "$origin/api/v1";

  /// Helper function to build query params, this way we only need to add the
  /// required guid auth param in one place
  Map<String, dynamic> buildQueryParams([Map<String, dynamic> params = const {}]) {
    // we can't add items to a const map
    if (params.isEmpty) {
      params = {};
    }
    params['guid'] = ss.settings.guidAuthKey.value;
    return params;
  }

  /// Global try-catch function
  Future<Response> runApiGuarded(Future<Response> Function() func, {bool checkOrigin = true}) async {
    if (http.origin.isEmpty && checkOrigin) {
      return Future.error("No server URL!");
    }
    try {
      return await func();
    } catch (e, s) {
      // try again if 502 error and Cloudflare
      if (e is Response && e.statusCode == 502 && apiRoot.contains("trycloudflare")) {
        try {
          return await func();
        } catch (e, s) {
          return Future.error(e, s);
        }
      }
      return Future.error(e, s);
    }
  }

  /// Return the future with either a value or error, depending on response from API
  Future<Response> returnSuccessOrError(Response r) {
    if (r.statusCode == 200) {
      return Future.value(r);
    } else {
      return Future.error(r);
    }
  }

  Map<String, String> get headers {
    if (ss.settings.serverAddress.contains('ngrok')) {
      ss.settings.customHeaders.addAll({'ngrok-skip-browser-warning': 'true'});
    } else if (ss.settings.serverAddress.contains('zrok')) {
      ss.settings.customHeaders.addAll({'skip_zrok_interstitial': 'true'});
    }

    return ss.settings.customHeaders;
  }

  /// Initialize dio with a couple options and intercept all requests for logging
  @override
  void onInit() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(milliseconds: 15000),
      receiveTimeout: Duration(milliseconds: ss.settings.apiTimeout.value),
      sendTimeout: Duration(milliseconds: ss.settings.apiTimeout.value),
      headers: headers,
    ));
    // Native Adapter will use the native http implementation on macOS, iOS and Android. 
    // Other platforms still use the Dart http stack.
    dio.httpClientAdapter = NativeAdapter();
    dio.interceptors.add(ApiInterceptor());
    // Uncomment to run tests on most API requests
    // testAPI();
    super.onInit();
  }

  /// Check ping time for server
  Future<Response> ping({String? customUrl, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          customUrl != null ? "$customUrl/api/v1/ping" : "$apiRoot/ping",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Lock Mac device
  Future<Response> lockMac({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/mac/lock",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Restart iMessage app
  Future<Response> restartImessage({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/mac/imessage/restart",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get server metadata like server version, macOS version, current URL, etc
  Response? _serverInfoCache;
  DateTime? _lastServerInfoFetch;
  Future<Response> serverInfo({CancelToken? cancelToken}) async {
    final now = DateTime.now();
    if (_serverInfoCache != null && _lastServerInfoFetch != null && now.difference(_lastServerInfoFetch!) < const Duration(minutes: 1)) {
      Logger.debug("Server info was recently fetched. Using cache...");
      return _serverInfoCache!;
    }

    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/server/info",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );

      if (response.statusCode == 200) {
        _serverInfoCache = response;
        _lastServerInfoFetch = now;
      }

      return returnSuccessOrError(response);
    });
  }

  /// Restart the server app services
  Future<Response> softRestart({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/server/restart/soft",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Restart the entire server app
  Future<Response> hardRestart({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/server/restart/hard",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Check for new server versions
  Future<Response> checkUpdate({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/server/update/check",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Check for new server versions
  Future<Response> installUpdate({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/server/update/install",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get server totals (number of handles, messages, chats, and attachments)
  Future<Response> serverStatTotals({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/server/statistics/totals",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get server media totals (number of images, videos, and locations)
  ///
  /// Optionally fetch totals split by chat
  Future<Response> serverStatMedia({bool byChat = false, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/server/statistics/media${byChat ? "/chat" : ""}",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get server logs, [count] defines the length of logs
  Future<Response> serverLogs({int count = 10000, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/server/logs",
          queryParameters: buildQueryParams({"count": count}),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Add a new FCM Device to the server. Must provide [name] and [identifier]
  Future<Response> addFcmDevice(String name, String identifier, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/fcm/device",
          data: {"name": name, "identifier": identifier},
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get the current FCM data from the server
  Future<Response> fcmClient({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/fcm/client",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get the attachemnt data for the specified [guid]
  Future<Response> attachment(String guid, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/attachment/$guid",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get the attachment data for the specified [guid]
  Future<Response> downloadAttachment(String guid, {void Function(int, int)? onReceiveProgress, bool original = false, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/attachment/$guid/download",
          queryParameters: buildQueryParams({"original": original}),
          options: Options(responseType: ResponseType.bytes, receiveTimeout: dio.options.receiveTimeout! * 12, headers: headers),
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get the live photo data for the specified [guid]
  Future<Response> downloadLivePhoto(String guid, {void Function(int, int)? onReceiveProgress, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
        "$apiRoot/attachment/$guid/live",
        queryParameters: buildQueryParams(),
        options: Options(responseType: ResponseType.bytes, receiveTimeout: dio.options.receiveTimeout! * 12, headers: headers),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get the attachment blurhash for the specified [guid]
  Future<Response> attachmentBlurhash(String guid, {void Function(int, int)? onReceiveProgress, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
        "$apiRoot/attachment/$guid/blurhash",
        queryParameters: buildQueryParams(),
        options: Options(responseType: ResponseType.bytes, receiveTimeout: dio.options.receiveTimeout! * 12, headers: headers),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get the number of attachments in the server iMessage DB
  Future<Response> attachmentCount({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/attachment/count",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Query the chat DB. Use [withQuery] to specify what you would like in the
  /// response or how to query the DB.
  ///
  /// [withQuery] options: `"participants"`, `"lastmessage"`, `"sms"`, `"archived"`
  Future<Response> chats({List<String> withQuery = const [], int offset = 0, int limit = 100, String? sort, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/chat/query",
          queryParameters: buildQueryParams(),
          data: {"with": withQuery, "offset": offset, "limit": limit, "sort": sort},
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get the messages for the specified chat (using [guid]). Use [withQuery]
  /// to specify what you would like in the response or how to query the DB.
  ///
  /// [withQuery] options: `"attachment"` / `"attachments"`, `"handle"` / `"handles"`
  /// `"sms"`, `"message.attributedbody"` (set as one string, comma separated, no spaces)
  Future<Response> chatMessages(String guid, {String withQuery = "", String sort = "DESC", int? before, int? after, int offset = 0, int limit = 100, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/chat/$guid/message",
          queryParameters: buildQueryParams({"with": withQuery, "sort": sort, "before": before, "after": after, "offset": offset, "limit": limit}),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Add / remove a participant to the specified chat (using [guid]). [method]
  /// tells whether to add or remove, and use [address] to specify the address
  /// of the participant to add / remove.
  Future<Response> chatParticipant(String method, String guid, String address, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/chat/$guid/participant/$method",
          queryParameters: buildQueryParams(),
          data: {"address": address},
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Leave a chat
  Future<Response> leaveChat(String guid, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/chat/$guid/leave",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Update the specified chat (using [guid]). Use [displayName] to specify the
  /// new chat name.
  Future<Response> updateChat(String guid, String displayName, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.put(
          "$apiRoot/chat/$guid",
          queryParameters: buildQueryParams(),
          data: {"displayName": displayName},
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Create a chat with the specified [addresses]. Requires an initial [message]
  /// to send.
  Future<Response> createChat(List<String> addresses, String? message, String service, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/chat/new",
          queryParameters: buildQueryParams(),
          data: {
            "addresses": addresses,
            "message": message,
            "service": service,
            "method": ss.settings.enablePrivateAPI.value ? 'private-api' : 'apple-script'
          },
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get the number of chats in the server iMessage DB
  Future<Response> chatCount({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/chat/count",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get a single chat by its [guid]. Use [withQuery] to specify what you would
  /// like in the response or how to query the DB.
  ///
  /// [withQuery] options: `"participants"`, `"lastmessage"`
  /// (set as one string, comma separated, no spaces)
  Future<Response> singleChat(String guid, {String withQuery = "", CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/chat/$guid",
          queryParameters: buildQueryParams({"with": withQuery}),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Mark a chat read by its [guid]
  Future<Response> markChatRead(String guid, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/chat/$guid/read",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken,
      );
      return returnSuccessOrError(response);
    });
  }

  /// Mark a chat read by its [guid]
  Future<Response> markChatUnread(String guid, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
        "$apiRoot/chat/$guid/unread",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken,
      );
      return returnSuccessOrError(response);
    });
  }

  /// Add or remove a participant (specify [method] as "add" or "remove")
  /// to a chat by its [guid]. Provide a participant [address].
  Future<Response> addRemoveParticipant(String method, String guid, String address, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/chat/$guid/participant/$method",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken,
          data: {"address": address}
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get a group chat icon by the chat [guid]
  Future<Response> getChatIcon(String guid, {void Function(int, int)? onReceiveProgress, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/chat/$guid/icon",
          queryParameters: buildQueryParams(),
          options: Options(responseType: ResponseType.bytes, receiveTimeout: dio.options.receiveTimeout! * 12, headers: headers),
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get a group chat icon by the chat [guid]
  Future<Response> setChatIcon(String guid, String path, {void Function(int, int)? onSendProgress, CancelToken? cancelToken}) async {
    final formData = FormData.fromMap({
      "icon": await MultipartFile.fromFile(path),
    });
    return runApiGuarded(() async {
      final response = await dio.post(
        "$apiRoot/chat/$guid/icon",
        queryParameters: buildQueryParams(),
        data: formData,
        options: Options(sendTimeout: dio.options.sendTimeout! * 12, receiveTimeout: dio.options.receiveTimeout! * 12, headers: headers),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get a group chat icon by the chat [guid]
  Future<Response> deleteChatIcon(String guid, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.delete(
        "$apiRoot/chat/$guid/icon",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken,
      );
      return returnSuccessOrError(response);
    });
  }

  /// Delete a chat by [guid]
  Future<Response> deleteChat(String guid, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.delete(
          "$apiRoot/chat/$guid",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Delete a message by [guid]
  Future<Response> deleteMessage(String guid, String messageGuid, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.delete(
          "$apiRoot/chat/$guid/$messageGuid",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get the number of messages in the server iMessage DB
  Future<Response> messageCount(
      {bool updated = false, bool onlyMe = false, DateTime? after, DateTime? before, CancelToken? cancelToken}) async {
    // we don't have a query that supports providing updated and onlyMe
    assert(updated != true && onlyMe != true);
    Map<String, dynamic> params = {};
    if (after != null) params['after'] = after.millisecondsSinceEpoch;
    if (before != null) params['before'] = before.millisecondsSinceEpoch;
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/message/count${updated ? "/updated" : onlyMe ? "/me" : ""}",
          queryParameters: buildQueryParams(params),
          cancelToken: cancelToken);
      return returnSuccessOrError(response);
    });
  }

  /// Query the messages DB. Use [withQuery] to specify what you would like in
  /// the response or how to query the DB.
  ///
  /// [withQuery] options: `"chats"` / `"chat"`, `"attachment"` / `"attachments"`,
  /// `"handle"`, `"chats.participants"` / `"chat.participants"`,  `"attachment.metadata"`, `"attributedBody"
  Future<Response> messages({List<String> withQuery = const [], List<dynamic> where = const [], String sort = "DESC", int? before, int? after, String? chatGuid, int offset = 0, int limit = 100, bool convertAttachments = true, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/message/query",
          queryParameters: buildQueryParams(),
          data: {"with": withQuery, "where": where, "sort": sort, "before": before, "after": after, "chatGuid": chatGuid, "offset": offset, "limit": limit, "convertAttachments": convertAttachments},
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get a single message by [guid]. Use [withQuery] to specify what you would
  /// like in the response or how to query the DB.
  ///
  /// [withQuery] options: `"chats"` / `"chat"`, `"attachment"` / `"attachments"`,
  /// `"chats.participants"` / `"chat.participants"`, `"attributedBody"` (set as one string, comma separated, no spaces)
  Future<Response> singleMessage(String guid, {String withQuery = "", CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/message/$guid",
          queryParameters: buildQueryParams({"with": withQuery}),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get embedded media for a single digital touch or handwritten message by [guid].
  Future<Response> embeddedMedia(String guid, {void Function(int, int)? onReceiveProgress, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/message/$guid/embedded-media",
          queryParameters: buildQueryParams(),
          options: Options(responseType: ResponseType.bytes, receiveTimeout: dio.options.receiveTimeout! * 12, headers: headers),
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
      );
      return returnSuccessOrError(response);
    });
  }

  /// Send a message. [chatGuid] specifies the chat, [tempGuid] specifies a
  /// temporary guid to avoid duplicate messages being sent, [message] is the
  /// body of the message. Optionally provide [method] to send via private API,
  /// [effectId] to send with an effect, or [subject] to send with a subject.
  Future<Response> sendMessage(String chatGuid, String tempGuid, String message, {String? method, String? effectId, String? subject, String? selectedMessageGuid, int? partIndex, bool? ddScan, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      Map<String, dynamic> data = {
        "chatGuid": chatGuid,
        "tempGuid": tempGuid,
        "message": message.isEmpty && (subject?.isNotEmpty ?? false) ? " " : message,
        "method": method,
      };

      data.addAllIf(ss.settings.enablePrivateAPI.value && ss.settings.privateAPISend.value, {
        "effectId": effectId,
        "subject": subject,
        "selectedMessageGuid": selectedMessageGuid,
        "partIndex": partIndex
      });

      if (ss.settings.enablePrivateAPI.value && ss.settings.privateAPISend.value && ss.isMinVenturaSync) {
        data["ddScan"] = ddScan;
      }

      final response = await dio.post(
          "$apiRoot/message/text",
          queryParameters: buildQueryParams(),
          data: data,
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Send an attachment. [chatGuid] specifies the chat, [tempGuid] specifies a
  /// temporary guid to avoid duplicate messages being sent, [file] is the
  /// body of the message.
  Future<Response> sendAttachment(String chatGuid, String tempGuid, PlatformFile file, {void Function(int, int)? onSendProgress, String? method, String? effectId, String? subject, String? selectedMessageGuid, int? partIndex, bool? isAudioMessage, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final fileName = file.name;
      final formData = FormData.fromMap({
        "attachment": kIsWeb ? MultipartFile.fromBytes(file.bytes!, filename: fileName) : await MultipartFile.fromFile(file.path!, filename: fileName),
        "chatGuid": chatGuid,
        "tempGuid": tempGuid,
        "name": fileName,
        "method": method
      });

      if (ss.settings.enablePrivateAPI.value && ss.settings.privateAPIAttachmentSend.value) {
        Map<String, dynamic> papiData = {
          "effectId": effectId,
          "subject": subject,
          "selectedMessageGuid": selectedMessageGuid,
          "partIndex": partIndex,
          "isAudioMessage": isAudioMessage,
        };

        papiData.removeWhere((key, value) => value == null);
        formData.fields.addAll(papiData.entries.map((entry) => MapEntry(entry.key, entry.value.toString())));
      }

      final response = await dio.post(
          "$apiRoot/message/attachment",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken,
          data: formData,
          onSendProgress: onSendProgress,
          options: Options(sendTimeout: dio.options.sendTimeout! * 12, receiveTimeout: dio.options.receiveTimeout! * 12, headers: headers),
      );
      return returnSuccessOrError(response);
    });
  }

  /// Send a message. [chatGuid] specifies the chat, [tempGuid] specifies a
  /// temporary guid to avoid duplicate messages being sent, [message] is the
  /// body of the message. Optionally provide [method] to send via private API,
  /// [effectId] to send with an effect, or [subject] to send with a subject.
  Future<Response> sendMultipart(String chatGuid, String tempGuid, List<Map<String, dynamic>> parts, {String? effectId, String? subject, String? selectedMessageGuid, int? partIndex, bool? ddScan, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      Map<String, dynamic> data = {
        "chatGuid": chatGuid,
        "tempGuid": tempGuid,
        "effectId": effectId,
        "subject": subject,
        "selectedMessageGuid": selectedMessageGuid,
        "partIndex": partIndex,
        "parts": parts
      };

      if (ss.isMinVenturaSync) {
        data["ddScan"] = ddScan;
      }

      final response = await dio.post(
          "$apiRoot/message/multipart",
          queryParameters: buildQueryParams(),
          data: data,
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Send a reaction. [chatGuid] specifies the chat, [selectedMessageText]
  /// specifies the text of the message being reacted on, [selectedMessageGuid]
  /// is the guid of the message, and [reaction] is the reaction type.
  Future<Response> sendTapback(String chatGuid, String selectedMessageText, String selectedMessageGuid, String reaction, {int? partIndex, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/message/react",
          queryParameters: buildQueryParams(),
          data: {
            "chatGuid": chatGuid,
            "selectedMessageText": selectedMessageText,
            "selectedMessageGuid": selectedMessageGuid,
            "reaction": reaction,
            "partIndex": partIndex,
          },
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  Future<Response> unsend(String selectedMessageGuid, {int? partIndex, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/message/$selectedMessageGuid/unsend",
          queryParameters: buildQueryParams(),
          data: {
            "partIndex": partIndex ?? 0,
          },
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  Future<Response> edit(String selectedMessageGuid, String edit, String backwardsCompatText, {int? partIndex, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/message/$selectedMessageGuid/edit",
          queryParameters: buildQueryParams(),
          data: {
            "editedMessage": edit,
            "backwardsCompatibilityMessage": backwardsCompatText,
            "partIndex": partIndex ?? 0,
          },
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  Future<Response> notify(String selectedMessageGuid, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/message/$selectedMessageGuid/notify",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get the number of handles in the server iMessage DB
  Future<Response> handleCount({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/handle/count",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Query the handles DB. Use [withQuery] to specify what you would like in
  /// the response or how to query the DB.
  ///
  /// [withQuery] options: `"chats"` / `"chat"`, `"chats.participants"` / `"chat.participants"`
  /// (set as one string, comma separated, no spaces)
  Future<Response> handles({List<String> withQuery = const [], String? address, int offset = 0, int limit = 100, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/handle/query",
          queryParameters: buildQueryParams(),
          data: {"with": withQuery, "address": address, "offset": offset, "limit": limit},
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get a single handle by [guid]
  Future<Response> handle(String guid, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/handle/$guid",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get a single handle's focus state by [address]
  Future<Response> handleFocusState(String address, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/handle/$address/focus",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get a single handle's iMessage state by [address]
  Future<Response> handleiMessageState(String address, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/handle/availability/imessage",
          queryParameters: buildQueryParams({
            "address": address,
          }),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get a single handle's FaceTime state by [address]
  Future<Response> handleFaceTimeState(String address, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/handle/availability/facetime",
          queryParameters: buildQueryParams({
            "address": address,
          }),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get all icloud contacts
  Future<Response> contacts({bool withAvatars = false, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/contact",
          queryParameters: buildQueryParams(withAvatars ? {"extraProperties": "avatar"} : {}),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get specific icloud contacts with a list of [addresses], either phone
  /// numbers or emails
  Future<Response> contactByAddresses(List<String> addresses, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/contact/query",
          queryParameters: buildQueryParams(),
          data: {"addresses": addresses},
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Add a contact to the server
  Future<Response> createContact(List<Map<String, dynamic>> contacts, {void Function(int, int)? onSendProgress, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/contact",
          queryParameters: buildQueryParams(),
          data: contacts,
          onSendProgress: onSendProgress,
          options: Options(sendTimeout: dio.options.sendTimeout! * 12, receiveTimeout: dio.options.receiveTimeout! * 12, headers: headers),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get backup theme JSON, if any
  Future<Response> getTheme({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/backup/theme",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Set theme backup with the provided [json]
  Future<Response> setTheme(String name, Map<String, dynamic> json, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/backup/theme",
          data: {"name": name, "data": json},
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Delete theme backup
  Future<Response> deleteTheme(String name, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.delete(
          "$apiRoot/backup/theme",
          queryParameters: buildQueryParams(),
          data: {"name": name},
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get settings backup, if any
  Future<Response> getSettings({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          "$apiRoot/backup/settings",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Delete settings backup
  Future<Response> deleteSettings(String name, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.delete(
          "$apiRoot/backup/settings",
          queryParameters: buildQueryParams(),
          data: {"name": name},
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Set settings backup with the provided [json]
  Future<Response> setSettings(String name, Map<String, dynamic> json, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/backup/settings",
          data: {"name": name, "data": json},
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Answers a facetime call with the given [callUuid].
  /// The response is a data object with a `link` key that contains the link to the call.
  Future<Response> answerFaceTime(String callUuid, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/facetime/answer/$callUuid",
          queryParameters: buildQueryParams(),
          data: {},
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Leave a facetime call with the given [callUuid].
  Future<Response> leaveFacetime(String callUuid, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
          "$apiRoot/facetime/leave/$callUuid",
          queryParameters: buildQueryParams(),
          data: {},
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get the basic landing page for the server URL
  Future<Response> landingPage({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          origin,
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get scheduled messages from server
  Future<Response> getScheduled({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
        "$apiRoot/message/schedule",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken,
      );
      return returnSuccessOrError(response);
    });
  }

  /// Create a scheduled message
  Future<Response> createScheduled(String chatGuid, String message, DateTime date, Map<String, dynamic> schedule, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
        "$apiRoot/message/schedule",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken,
        data: {
          "type": "send-message",
          "payload": {
            "chatGuid": chatGuid,
            "message": message,
            "method": ss.settings.privateAPISend.value ? 'private-api' : "apple-script"
          },
          "scheduledFor": date.millisecondsSinceEpoch,
          "schedule": schedule,
        }
      );
      return returnSuccessOrError(response);
    });
  }

  // Create a scheduled message
  Future<Response> updateScheduled(int id, String chatGuid, String message, DateTime date, Map<String, dynamic> schedule, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.put(
          "$apiRoot/message/schedule/$id",
          queryParameters: buildQueryParams(),
          cancelToken: cancelToken,
          data: {
            "type": "send-message",
            "payload": {
              "chatGuid": chatGuid,
              "message": message,
              "method": "apple-script"
            },
            "scheduledFor": date.millisecondsSinceEpoch,
            "schedule": schedule,
          }
      );
      return returnSuccessOrError(response);
    });
  }

  /// Delete a scheduled message
  Future<Response> deleteScheduled(int id, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.delete(
        "$apiRoot/message/schedule/$id",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get FindMy devices from server
  Future<Response> findMyDevices({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
        "$apiRoot/icloud/findmy/devices",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken,
      );
      return returnSuccessOrError(response);
    });
  }

  /// Refresh FindMy devices on server
  Future<Response> refreshFindMyDevices({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
        "$apiRoot/icloud/findmy/devices/refresh",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken,
        options: Options(receiveTimeout: dio.options.receiveTimeout! * 12, headers: headers),
      );
      return returnSuccessOrError(response);
    });
  }

  /// Get FindMy friends from server
  Future<Response> findMyFriends({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
        "$apiRoot/icloud/findmy/friends",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken,
      );
      return returnSuccessOrError(response);
    });
  }

  /// Refresh FindMy friends on server
  Future<Response> refreshFindMyFriends({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
        "$apiRoot/icloud/findmy/friends/refresh",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken,
      );
      return returnSuccessOrError(response);
    });
  }

  Future<Response> getAccountInfo({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
        "$apiRoot/icloud/account",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken,
      );
      return returnSuccessOrError(response);
    });
  }

  Future<Response> getAccountContact({CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
        "$apiRoot/icloud/contact",
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken,
      );
      return returnSuccessOrError(response);
    });
  }

  Future<Response> setAccountAlias(String alias, {CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.post(
        "$apiRoot/icloud/account/alias",
        data: {"alias": alias},
        queryParameters: buildQueryParams(),
        cancelToken: cancelToken,
      );
      return returnSuccessOrError(response);
    });
  }

  Future<Response> downloadFromUrl(String url, {Function(int, int)? progress, CancelToken? cancelToken}) async {
    return runApiGuarded(() async {
      final response = await dio.get(
          url,
          options: Options(responseType: ResponseType.bytes, receiveTimeout: dio.options.receiveTimeout! * 12, headers: headers),
          cancelToken: cancelToken,
          onReceiveProgress: progress,
      );
      return returnSuccessOrError(response);
    });
  }

  // The following methods are for Firebase only

  Future<Response> getFirebaseProjects(String accessToken) async {
    return runApiGuarded(() async {
      final response = await dio.get(
        "https://firebase.googleapis.com/v1beta1/projects",
        queryParameters: {
          "access_token": accessToken,
        },
      );
      return returnSuccessOrError(response);
    }, checkOrigin: false);
  }

  Future<Response> getGoogleInfo(String accessToken) async {
    return runApiGuarded(() async {
      final response = await dio.get(
        "https://www.googleapis.com/oauth2/v1/userinfo",
        queryParameters: {
          "access_token": accessToken,
        },
      );
      return returnSuccessOrError(response);
    }, checkOrigin: false);
  }

  Future<Response> getServerUrlRTDB(String rtdb, String accessToken) async {
    return runApiGuarded(() async {
      final response = await dio.get(
        "https://$rtdb.firebaseio.com/config.json",
        queryParameters: {
          "token": accessToken,
        },
      );
      return returnSuccessOrError(response);
    }, checkOrigin: false);
  }

  Future<Response> getServerUrlCF(String project, String accessToken) async {
    return runApiGuarded(() async {
      final response = await dio.get(
        "https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents/server/config",
        queryParameters: {
          "access_token": accessToken,
        },
      );
      return returnSuccessOrError(response);
    }, checkOrigin: false);
  }

  Future<Response> setRestartDateCF(String project) async {
    return runApiGuarded(() async {
      final response = await dio.patch(
        "https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents/server/commands?updateMask.fieldPaths=nextRestart",
        data: {"fields":{"nextRestart": {"integerValue": DateTime.now().toUtc().millisecondsSinceEpoch}}},
      );
      return returnSuccessOrError(response);
    }, checkOrigin: false);
  }

  /// Test most API GET requests (the ones that don't have required parameters)
  void testAPI() {
    Stopwatch s = Stopwatch();
    group("API Service Test", () {
      test("Ping", () async {
        s.start();
        var res = await ping();
        expect(res.data['message'], "pong");
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Info", () async {
        s.start();
        var res = await serverInfo();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Stat Totals", () async {
        s.start();
        var res = await serverStatTotals();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Stat Media", () async {
        s.start();
        var res = await serverStatMedia();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Server Logs", () async {
        s.start();
        var res = await serverLogs();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("FCM Client", () async {
        s.start();
        var res = await fcmClient();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Attachment Count", () async {
        s.start();
        var res = await attachmentCount();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Chats", () async {
        s.start();
        var res = await chats();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Chat Count", () async {
        s.start();
        var res = await chatCount();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Message Count", () async {
        s.start();
        var res = await messageCount();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("My Message Count", () async {
        s.start();
        var res = await messageCount(onlyMe: true);
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Messages", () async {
        s.start();
        var res = await messages();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Handle Count", () async {
        s.start();
        var res = await handleCount();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("iCloud Contacts", () async {
        s.start();
        var res = await contacts();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Theme Backup", () async {
        s.start();
        var res = await getTheme();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Settings Backup", () async {
        s.start();
        var res = await getSettings();
        expect(res.data['status'], 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
      test("Landing Page", () async {
        s.start();
        var res = await landingPage();
        expect(res.statusCode, 200);
        s.stop();
        Logger.info("Request took ${s.elapsedMilliseconds} ms");
      });
    });
  }
}

/// Intercepts API requests, responses, and errors and logs them to console
class ApiInterceptor extends Interceptor {

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    Logger.info("Request: [${options.method}] ${options.path}", tag: "HTTP Service");
    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    Logger.info("Response: [${response.statusCode}] ${response.requestOptions.path}", tag: "HTTP Service");
    return super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Get params without sensitive info
    final params = err.requestOptions.queryParameters;
    params.remove("guid");
    params.remove("password");

    // Make a nice log of what failed
    Logger.error("""Failed Request: [${err.requestOptions.method}] ${err.requestOptions.path}
  -> Error: ${err.error ?? 'No Error'}
  -> Request Params: ${params.toString()}
  -> Request Data: ${err.requestOptions.data ?? 'No Data'}
  -> Response Status: ${err.response?.statusCode ?? 'No Response'}
  -> Response Data: ${err.response?.data ?? 'No Data'}""", tag: "HTTP Service");

    if (err.response != null && err.response!.data is Map) return handler.resolve(err.response!);
    if (err.response != null) {
      return handler.resolve(Response(data: {
        'status': err.response!.statusCode,
        'error': {
          'type': 'Error',
          'error': err.response!.data.toString()
        }
      }, requestOptions: err.requestOptions, statusCode: err.response!.statusCode));
    }
    if (err.type.name.contains("Timeout")) {
      return handler.resolve(Response(data: {
        'status': 500,
        'error': {
          'type': 'timeout',
          'error': 'Failed to receive response from server.'
        }
      }, requestOptions: err.requestOptions, statusCode: 500));
    }
    return super.onError(err, handler);
  }
}
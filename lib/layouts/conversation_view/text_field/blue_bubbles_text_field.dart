import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bluebubbles/blocs/text_field_bloc.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/list/text_field_attachment_list.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/picker/text_field_attachment_picker.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoTextField.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:camera/camera.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mime_type/mime_type.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:record/record.dart';

enum CameraState { INACTIVE, STARTING, ACTIVE, DISPOSING }

class BlueBubblesTextField extends StatefulWidget {
  final List<File>? existingAttachments;
  final String? existingText;
  final bool? isCreator;
  final bool wasCreator;
  final Future<bool> Function(List<File> attachments, String text) onSend;

  BlueBubblesTextField({
    Key? key,
    this.existingAttachments,
    this.existingText,
    required this.isCreator,
    required this.wasCreator,
    required this.onSend,
  }) : super(key: key);

  static BlueBubblesTextFieldState? of(BuildContext context) {
    return context.findAncestorStateOfType<BlueBubblesTextFieldState>();
  }

  @override
  BlueBubblesTextFieldState createState() => BlueBubblesTextFieldState();
}

class BlueBubblesTextFieldState extends State<BlueBubblesTextField> with TickerProviderStateMixin {
  TextEditingController? controller;
  FocusNode? focusNode;
  List<File> pickedImages = <File>[];
  TextFieldData? textFieldData;
  StreamController _streamController = new StreamController.broadcast();
  CurrentChat? safeChat;

  // Camera Vars
  CameraState cameraState = CameraState.INACTIVE;
  CameraController? cameraController;
  int cameraIndex = 0;
  List<CameraDescription> cameras = [];

  bool selfTyping = false;
  int? sendCountdown;
  bool? stopSending;

  final RxString placeholder = "BlueBubbles".obs;
  final RxBool isRecording = false.obs;
  final RxBool canRecord = true.obs;

  // bool selfTyping = false;

  Stream get stream => _streamController.stream;

  bool get _canRecord => controller!.text.isEmpty && pickedImages.isEmpty;

  final RxBool showShareMenu = false.obs;

  final GlobalKey<FormFieldState<String>> _searchFormKey = GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    getPlaceholder();

    if (CurrentChat.activeChat != null) {
      textFieldData = TextFieldBloc().getTextField(CurrentChat.activeChat!.chat.guid!);
    }

    controller = textFieldData != null ? textFieldData!.controller : new TextEditingController();

    // Add the text listener to detect when we should send the typing indicators
    controller!.addListener(() {
      setCanRecord();
      if (!mounted || CurrentChat.activeChat?.chat == null) return;

      // If the private API features are disabled, or sending the indicators is disabled, return
      if (!SettingsManager().settings.enablePrivateAPI.value ||
          !SettingsManager().settings.privateSendTypingIndicators.value) {
        return;
      }

      if (controller!.text.length == 0 && pickedImages.length == 0 && selfTyping) {
        selfTyping = false;
        SocketManager().sendMessage("stopped-typing", {"chatGuid": CurrentChat.activeChat!.chat.guid}, (data) {});
      } else if (!selfTyping && (controller!.text.length > 0 || pickedImages.length > 0)) {
        selfTyping = true;
        if (SettingsManager().settings.privateSendTypingIndicators.value)
          SocketManager().sendMessage("started-typing", {"chatGuid": CurrentChat.activeChat!.chat.guid}, (data) {});
      }

      if (mounted) setState(() {});
    });

    // Create the focus node and then add a an event emitter whenever
    // the focus changes
    focusNode = new FocusNode();
    focusNode!.addListener(() {
      CurrentChat.activeChat?.keyboardOpen = focusNode?.hasFocus ?? false;

      if (focusNode!.hasFocus && this.mounted) {
        if (!showShareMenu.value) return;
        showShareMenu.value = false;
      }

      EventDispatcher.instance.emit("keyboard-status", focusNode!.hasFocus);
    });

    EventDispatcher.instance.stream.listen((event) {
      if (!event.containsKey("type")) return;
      if (event["type"] == "unfocus-keyboard" && focusNode!.hasFocus) {
        print("(EVENT) Unfocus Keyboard");
        focusNode!.unfocus();
      } else if (event["type"] == "focus-keyboard" && !focusNode!.hasFocus) {
        print("(EVENT) Focus Keyboard");
        focusNode!.requestFocus();
      } else if (event["type"] == "text-field-update-attachments") {
        addSharedAttachments();
        while (!(ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.of(context).pop();
        }
      } else if (event["type"] == "text-field-update-text") {
        while (!(ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.of(context).pop();
        }
      }
    });

    if (widget.existingText != null) {
      controller!.text = widget.existingText!;
    }

    if (widget.existingAttachments != null) {
      this.addAttachments(widget.existingAttachments!);
      updateTextFieldAttachments();
    }

    if (textFieldData != null) {
      this.addAttachments(textFieldData?.attachments ?? []);
    }

    setCanRecord();
  }

  void setCanRecord() {
    bool canRec = this._canRecord;
    if (canRec != canRecord.value) {
      canRecord.value = canRec;
    }
  }

  void addAttachments(List<File> attachments) {
    pickedImages.addAll(attachments);
    final ids = pickedImages.map((e) => e.path).toSet();
    pickedImages.retainWhere((element) => ids.remove(element.path));
    setCanRecord();
  }

  void updateTextFieldAttachments() {
    if (textFieldData != null) {
      textFieldData!.attachments = pickedImages.where((element) => mime(element.path) != null).toList();
      _streamController.sink.add(null);
    }

    setCanRecord();
  }

  void addSharedAttachments() {
    if (textFieldData != null && mounted) {
      pickedImages = textFieldData!.attachments;
      setState(() {});
    }

    setCanRecord();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    safeChat = CurrentChat.activeChat;
  }

  @override
  void dispose() {
    focusNode!.dispose();
    _streamController.close();
    this.disposeCameras();

    if (safeChat?.chat == null) controller!.dispose();

    String dir = SettingsManager().appDocDir.path;
    Directory tempAssets = Directory("$dir/tempAssets");
    tempAssets.exists().then((value) {
      if (value) {
        tempAssets.delete(recursive: true);
      }
    });
    pickedImages = [];
    super.dispose();
  }

  void disposeAudioFile(BuildContext context, File file) {
    // Dispose of the audio controller
    CurrentChat.activeChat?.audioPlayers[file.path]?.item1.dispose();
    CurrentChat.activeChat?.audioPlayers[file.path]?.item2.pause();
    CurrentChat.activeChat?.audioPlayers.removeWhere((key, _) => key == file.path);

    // Delete the file
    file.delete();
  }

  void onContentCommit(CommittedContent content) async {
    // Add some debugging logs
    debugPrint("[Content Commit] Keyboard received content");
    debugPrint("  -> Content Type: ${content.mimeType}");
    debugPrint("  -> URI: ${content.uri}");
    debugPrint("  -> Content Length: ${content.hasData ? content.data!.length : "null"}");

    // Parse the filename from the URI and read the data as a List<int>
    String filename = uriToFilename(content.uri, content.mimeType);

    // Save the data to a location and add it to the file picker
    if (content.hasData) {
      File file = AttachmentHelper.saveTempFile(filename, content.data!);
      this.addAttachments([file]);

      // Update the state
      updateTextFieldAttachments();
      if (this.mounted) setState(() {});
    } else {
      showSnackbar('Insertion Failed', 'Attachment has no data!');
    }
  }

  Future<void> reviewAudio(BuildContext originalContext, File file) async {
    showDialog(
      context: originalContext,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).accentColor,
          title: new Text("Send it?", style: Theme.of(context).textTheme.headline1),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Review your audio snippet before sending it", style: Theme.of(context).textTheme.subtitle1),
              Container(height: 10.0),
              AudioPlayerWidget(
                key: new Key("AudioMessage-${file.length().toString()}"),
                file: file,
              )
            ],
          ),
          actions: <Widget>[
            new TextButton(
                child: new Text("Discard", style: Theme.of(context).textTheme.subtitle1),
                onPressed: () {
                  // Dispose of the audio controller
                  this.disposeAudioFile(originalContext, file);

                  // Remove the OG alert dialog
                  Navigator.of(originalContext).pop();
                }),
            new TextButton(
              child: new Text(
                "Send",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              onPressed: () async {
                CurrentChat? thisChat = CurrentChat.of(originalContext);
                if (thisChat == null) {
                  this.addAttachments([file]);
                } else {
                  await widget.onSend([file], "");
                  this.disposeAudioFile(originalContext, file);
                }

                // Remove the OG alert dialog
                Navigator.of(originalContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> initializeCameraController() async {
    // If the state is active, we need to close it
    if (cameraState == CameraState.ACTIVE) {
      await this.disposeCameras();
    }

    debugPrint("[Camera Preview] -> Initializing camera preview");

    // Enumerate the cameras (if we don't have them)
    // We only need to do this once... it's not like it's gonna change very often
    if (cameras.length == 0) {
      cameras = await availableCameras();
    }

    if (cameras.length == 0) {
      debugPrint("[Camera Preview] -> No available cameras!");
      return;
    }

    // Update the camera state
    cameraState = CameraState.STARTING;

    // Re-initialize the camera controller
    // Disable audio so that background music doesn't stop playing
    cameraController = CameraController(cameras[cameraIndex], ResolutionPreset.max, enableAudio: false);

    // Initialize the camera (if not done already), then update the state
    if (!cameraController!.value.isInitialized) {
      await cameraController?.initialize();
    }

    cameraState = CameraState.ACTIVE;
    if (this.mounted) setState(() {});
    debugPrint("[Camera Preview] -> Finished initializing camera preview");
  }

  Future<void> disposeCameras() async {
    debugPrint("[Camera Preview] -> Disposing camera preview");
    cameraState = CameraState.DISPOSING;
    await cameraController?.dispose();
    cameraController = null;
    cameraState = CameraState.INACTIVE;
    debugPrint("[Camera Preview] -> Finished disposing camera preview");
  }

  Future<void> toggleShareMenu() async {
    bool showMenu = showShareMenu.value;

    // If the image picker is already open, close it, and return
    if (!showMenu) {
      focusNode!.unfocus();
    }
    if (!showMenu && !(await PhotoManager.requestPermission())) {
      showShareMenu.value = false;
      return;
    }

    // If we are closing, dispose the camera
    if (showMenu) {
      this.disposeCameras();
    }

    showShareMenu.value = !showMenu;
  }

  Future<bool> _onWillPop() async {
    if (showShareMenu.value) {
      if (this.mounted) {
        showShareMenu.value = false;
        disposeCameras();
      }
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return new WillPopScope(
        onWillPop: _onWillPop,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.only(left: 5, top: 5, bottom: 5, right: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    buildAttachmentList(),
                    buildTextFieldAlwaysVisible(),
                    buildAttachmentPicker(),
                  ],
                ),
              ),
            ),
          ],
        ));
  }

  Widget buildAttachmentList() => Padding(
        padding: const EdgeInsets.only(left: 50.0),
        child: TextFieldAttachmentList(
          attachments: pickedImages,
          onRemove: (File attachment) {
            pickedImages.removeWhere((element) => element.path == attachment.path);
            updateTextFieldAttachments();
            if (this.mounted) setState(() {});
          },
        ),
      );

  Widget buildTextFieldAlwaysVisible() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        buildShareButton(),
        buildActualTextField(),
        if (SettingsManager().settings.skin.value == Skins.Material ||
            SettingsManager().settings.skin.value == Skins.Samsung)
          buildSendButton(),
      ],
    );
  }

  Widget buildShareButton() {
    double size = SettingsManager().settings.skin.value == Skins.iOS ? 35 : 40;
    return Container(
      height: size,
      width: size,
      margin: EdgeInsets.only(left: 5.0, right: 5.0),
      child: ClipOval(
        child: Material(
          color: Theme.of(context).primaryColor,
          child: InkWell(
            onTap: toggleShareMenu,
            child: Padding(
              padding: EdgeInsets.only(right: 1),
              child: Icon(
                Icons.share,
                color: Colors.white.withAlpha(225),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> getPlaceholder() async {
    String placeholder = "BlueBubbles";

    try {
      // Don't do anything if this setting isn't enabled
      if (SettingsManager().settings.recipientAsPlaceholder.value) {
        // Redacted mode stuff
        final bool hideInfo =
            SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideContactInfo.value;
        final bool generateNames =
            SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeContactNames.value;

        // If it's a group chat, get the title of the chat
        if (CurrentChat.activeChat?.chat.isGroup() ?? false) {
          if (generateNames) {
            placeholder = "Group Chat";
          } else if (hideInfo) {
            placeholder = "BlueBubbles";
          } else {
            String? title = await CurrentChat.activeChat?.chat.getTitle();
            if (!isNullOrEmpty(title)!) {
              placeholder = title!;
            }
          }
        } else if (!isNullOrEmpty(CurrentChat.activeChat?.chat.participants)!) {
          if (generateNames) {
            placeholder = CurrentChat.activeChat!.chat.fakeParticipants[0] ?? "BlueBubbles";
          } else if (hideInfo) {
            placeholder = "BlueBubbles";
          } else {
            // If it's not a group chat, get the participant's contact info
            Handle? handle = CurrentChat.activeChat?.chat.participants[0];
            Contact? contact = ContactManager().getCachedContactSync(handle?.address ?? "");
            if (contact == null) {
              placeholder = await formatPhoneNumber(handle);
            } else {
              placeholder = contact.displayName ?? "BlueBubbles";
            }
          }
        }
      }
    } catch (ex) {
      debugPrint("Error setting Text Field Placeholder!");
      debugPrint(ex.toString());
    }

    if (placeholder != this.placeholder.value) {
      this.placeholder.value = placeholder;
    }
  }

  Widget buildActualTextField() {
    return Flexible(
      flex: 1,
      fit: FlexFit.loose,
      child: Container(
        child: Stack(
          alignment: AlignmentDirectional.centerEnd,
          children: <Widget>[
            AnimatedSize(
              duration: Duration(milliseconds: 100),
              vsync: this,
              curve: Curves.easeInOut,
              child: ThemeSwitcher(
                iOSSkin: CustomCupertinoTextField(
                  enabled: sendCountdown == null,
                  textInputAction:
                      SettingsManager().settings.sendWithReturn.value ? TextInputAction.send : TextInputAction.newline,
                  cursorColor: Theme.of(context).primaryColor,
                  onLongPressStart: () {
                    Feedback.forLongPress(context);
                  },
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (cameraState == CameraState.ACTIVE) {
                      disposeCameras();
                    }
                  },
                  key: _searchFormKey,
                  onSubmitted: (String value) {
                    if (!SettingsManager().settings.sendWithReturn.value || isNullOrEmpty(value)!) return;
                    sendMessage();
                  },
                  onContentCommitted: onContentCommit,
                  textCapitalization: TextCapitalization.sentences,
                  focusNode: focusNode,
                  autocorrect: true,
                  controller: controller,
                  scrollPhysics: CustomBouncingScrollPhysics(),
                  style: Theme.of(context).textTheme.bodyText1!.apply(
                        color:
                            ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) == Brightness.light
                                ? Colors.black
                                : Colors.white,
                        fontSizeDelta: -0.25,
                      ),
                  keyboardType: TextInputType.multiline,
                  maxLines: 14,
                  minLines: 1,
                  placeholder: SettingsManager().settings.recipientAsPlaceholder.value == true
                      ? placeholder.value
                      : "BlueBubbles",
                  padding: EdgeInsets.only(left: 10, top: 10, right: 40, bottom: 10),
                  placeholderStyle: Theme.of(context).textTheme.subtitle1,
                  autofocus: SettingsManager().settings.autoOpenKeyboard.value,
                  decoration: BoxDecoration(
                    color: Theme.of(context).backgroundColor,
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                materialSkin: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  autocorrect: true,
                  autofocus: SettingsManager().settings.autoOpenKeyboard.value,
                  cursorColor: Theme.of(context).primaryColor,
                  key: _searchFormKey,
                  style: Theme.of(context).textTheme.bodyText1!.apply(
                        color:
                            ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) == Brightness.light
                                ? Colors.black
                                : Colors.white,
                        fontSizeDelta: -0.25,
                      ),
                  onContentCommitted: onContentCommit,
                  decoration: InputDecoration(
                    isDense: true,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    hintText: SettingsManager().settings.recipientAsPlaceholder.value == true
                        ? placeholder.value
                        : "BlueBubbles",
                    hintStyle: Theme.of(context).textTheme.subtitle1,
                    contentPadding: EdgeInsets.only(
                      left: 10,
                      top: 15,
                      right: 10,
                      bottom: 10,
                    ),
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: 14,
                  minLines: 1,
                ),
                samsungSkin: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  autocorrect: true,
                  autofocus: SettingsManager().settings.autoOpenKeyboard.value,
                  cursorColor: Theme.of(context).primaryColor,
                  key: _searchFormKey,
                  style: Theme.of(context).textTheme.bodyText1!.apply(
                        color:
                            ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) == Brightness.light
                                ? Colors.black
                                : Colors.white,
                        fontSizeDelta: -0.25,
                      ),
                  onContentCommitted: onContentCommit,
                  decoration: InputDecoration(
                    isDense: true,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    hintText: SettingsManager().settings.recipientAsPlaceholder.value == true
                        ? placeholder.value
                        : "BlueBubbles",
                    hintStyle: Theme.of(context).textTheme.subtitle1,
                    contentPadding: EdgeInsets.only(
                      left: 10,
                      top: 15,
                      right: 10,
                      bottom: 10,
                    ),
                  ),
                ),
              ),
            ),
            if (SettingsManager().settings.skin.value == Skins.iOS) buildSendButton(),
          ],
        ),
      ),
    );
  }

  Future<void> startRecording() async {
    HapticFeedback.lightImpact();
    String appDocPath = SettingsManager().appDocDir.path;
    Directory directory = Directory("$appDocPath/attachments/");
    if (!await directory.exists()) {
      directory.createSync();
    }
    String pathName = "$appDocPath/attachments/OutgoingAudioMessage.m4a";
    File file = new File(pathName);
    if (file.existsSync()) file.deleteSync();

    if (!isRecording.value) {
      await Record().start(
        path: pathName, // required
        encoder: AudioEncoder.AAC, // by default
        bitRate: 196000, // by default
        samplingRate: 44100, // by default
      );

      if (this.mounted) {
        isRecording.value = true;
      }
    }
  }

  Future<void> stopRecording() async {
    HapticFeedback.lightImpact();

    if (isRecording.value) {
      await Record().stop();

      if (this.mounted) {
        isRecording.value = false;
      }

      String appDocPath = SettingsManager().appDocDir.path;
      String pathName = "$appDocPath/attachments/OutgoingAudioMessage.m4a";
      reviewAudio(context, new File(pathName));
    }
  }

  Future<void> sendMessage() async {
    // If send delay is enabled, delay the sending
    if (!isNullOrZero(SettingsManager().settings.sendDelay.value)) {
      // Break the delay into 1 second intervals
      for (var i = 0; i < SettingsManager().settings.sendDelay.value; i++) {
        if (i != 0 && sendCountdown == null) break;

        // Update UI with new state information
        if (this.mounted) {
          setState(() {
            sendCountdown = SettingsManager().settings.sendDelay.value - i;
          });
        }

        await Future.delayed(new Duration(seconds: 1));
      }

      if (this.mounted) {
        setState(() {
          sendCountdown = null;
        });
      }
    }

    if (stopSending != null && stopSending!) {
      stopSending = null;
      return;
    }

    if (await widget.onSend(pickedImages, controller!.text)) {
      controller!.text = "";
      pickedImages = <File>[];
      updateTextFieldAttachments();
    }
  }

  Future<void> sendAction() async {
    bool shouldUpdate = false;
    if (sendCountdown != null) {
      stopSending = true;
      sendCountdown = null;
      shouldUpdate = true;
    } else if (isRecording.value) {
      await stopRecording();
      shouldUpdate = true;
    } else if (canRecord.value && !isRecording.value && await Permission.microphone.request().isGranted) {
      await startRecording();
      shouldUpdate = true;
    } else {
      await sendMessage();
    }

    if (shouldUpdate && this.mounted) setState(() {});
  }

  Widget buildSendButton() => Align(
        alignment: Alignment.bottomRight,
        child: Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (sendCountdown != null) Text(sendCountdown.toString()),
          (SettingsManager().settings.skin.value == Skins.iOS)
              ? Container(
                  constraints: BoxConstraints(maxWidth: 38, maxHeight: 37),
                  padding: EdgeInsets.only(right: 4, top: 2, bottom: 2),
                  child: ButtonTheme(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.only(
                          right: 0,
                        ),
                        primary: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                      ),
                      onPressed: sendAction,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Obx(() => AnimatedOpacity(
                                opacity: sendCountdown == null && canRecord.value ? 1.0 : 0.0,
                                duration: Duration(milliseconds: 150),
                                child: Icon(
                                  Icons.mic,
                                  color: (isRecording.value) ? Colors.red : Colors.white,
                                  size: 20,
                                ),
                              )),
                          Obx(() => AnimatedOpacity(
                                opacity: (sendCountdown == null && !canRecord.value) && !isRecording.value ? 1.0 : 0.0,
                                duration: Duration(milliseconds: 150),
                                child: Icon(
                                  Icons.arrow_upward,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              )),
                          AnimatedOpacity(
                            opacity: sendCountdown != null ? 1.0 : 0.0,
                            duration: Duration(milliseconds: 50),
                            child: Icon(
                              Icons.cancel_outlined,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : GestureDetector(
                  onTapDown: (_) async {
                    if (canRecord.value && !isRecording.value) {
                      await startRecording();
                    }
                  },
                  onTapCancel: () async {
                    await stopRecording();
                  },
                  child: Container(
                    height: 40,
                    width: 40,
                    margin: EdgeInsets.only(left: 5.0),
                    child: ClipOval(
                      child: Material(
                        color: Theme.of(context).primaryColor,
                        child: InkWell(
                          onTap: sendAction,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Obx(() => AnimatedOpacity(
                                    opacity: sendCountdown == null && canRecord.value ? 1.0 : 0.0,
                                    duration: Duration(milliseconds: 150),
                                    child: Icon(
                                      Icons.mic,
                                      color: (isRecording.value) ? Colors.red : Colors.white,
                                      size: 20,
                                    ),
                                  )),
                              Obx(() => AnimatedOpacity(
                                    opacity:
                                        (sendCountdown == null && !canRecord.value) && !isRecording.value ? 1.0 : 0.0,
                                    duration: Duration(milliseconds: 150),
                                    child: Icon(
                                      Icons.send,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  )),
                              AnimatedOpacity(
                                opacity: sendCountdown != null ? 1.0 : 0.0,
                                duration: Duration(milliseconds: 50),
                                child: Icon(
                                  Icons.cancel_outlined,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
        ]),
      );

  Widget buildAttachmentPicker() => Obx(() => TextFieldAttachmentPicker(
        visible: showShareMenu.value,
        onAddAttachment: (File? file) {
          if (file == null) return;
          bool exists = file.existsSync();
          if (!exists) return;

          for (File image in pickedImages) {
            if (image.path == file.path) {
              pickedImages.removeWhere((element) => element.path == file.path);
              updateTextFieldAttachments();
              if (this.mounted) setState(() {});
              return;
            }
          }

          this.addAttachments([file]);
          updateTextFieldAttachments();
          if (this.mounted) setState(() {});
        },
      ));
}

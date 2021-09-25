import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:bluebubbles/blocs/text_field_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/share.dart';
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
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:dio_http/dio_http.dart';
import 'package:bluebubbles/repository/models/platform_file.dart';
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:file_picker/file_picker.dart' as pf;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:record/record.dart';
import 'package:transparent_pointer/transparent_pointer.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

class BlueBubblesTextField extends StatefulWidget {
  final List<PlatformFile>? existingAttachments;
  final String? existingText;
  final bool? isCreator;
  final bool wasCreator;
  final Future<bool> Function(List<PlatformFile> attachments, String text) onSend;

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
  List<PlatformFile> pickedImages = [];
  TextFieldData? textFieldData;
  StreamController _streamController = new StreamController.broadcast();
  DropzoneViewController? dropZoneController;
  CurrentChat? safeChat;

  bool selfTyping = false;
  int? sendCountdown;
  bool? stopSending;
  bool fileDragged = false;
  int? previousKeyCode;

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

    if (CurrentChat.of(context)?.chat != null) {
      textFieldData = TextFieldBloc().getTextField(CurrentChat.of(context)!.chat.guid!);
    }

    controller = textFieldData != null ? textFieldData!.controller : new TextEditingController();

    // Add the text listener to detect when we should send the typing indicators
    controller!.addListener(() {
      setCanRecord();
      if (!mounted || CurrentChat.of(context)?.chat == null) return;

      // If the private API features are disabled, or sending the indicators is disabled, return
      if (!SettingsManager().settings.enablePrivateAPI.value ||
          !SettingsManager().settings.privateSendTypingIndicators.value) {
        return;
      }

      if (controller!.text.length == 0 && pickedImages.length == 0 && selfTyping) {
        selfTyping = false;
        SocketManager().sendMessage("stopped-typing", {"chatGuid": CurrentChat.of(context)!.chat.guid}, (data) {});
      } else if (!selfTyping && (controller!.text.length > 0 || pickedImages.length > 0)) {
        selfTyping = true;
        if (SettingsManager().settings.privateSendTypingIndicators.value)
          SocketManager().sendMessage("started-typing", {"chatGuid": CurrentChat.of(context)!.chat.guid}, (data) {});
      }

      if (mounted) setState(() {});
    });

    // Create the focus node and then add a an event emitter whenever
    // the focus changes
    focusNode = new FocusNode();
    focusNode!.addListener(() {
      CurrentChat.of(context)?.keyboardOpen = focusNode?.hasFocus ?? false;

      if (focusNode!.hasFocus && this.mounted) {
        if (!showShareMenu.value) return;
        showShareMenu.value = false;
      }

      EventDispatcher().emit("keyboard-status", focusNode!.hasFocus);
    });

    if (kIsWeb) {
      html.document.onDragOver.listen((event) {
        var t = event.dataTransfer;
        if (t.types != null && t.types!.length == 1 && t.types!.first == "Files" && fileDragged == false) {
          setState(() {
            fileDragged = true;
          });
        }
      });

      html.document.onDragLeave.listen((event) {
        if (fileDragged == true) {
          setState(() {
            fileDragged = false;
          });
        }
      });
    }

    EventDispatcher().stream.listen((event) {
      if (!event.containsKey("type")) return;
      if (event["type"] == "unfocus-keyboard" && focusNode!.hasFocus) {
        Logger.info("(EVENT) Unfocus Keyboard");
        focusNode!.unfocus();
      } else if (event["type"] == "focus-keyboard" && !focusNode!.hasFocus) {
        Logger.info("(EVENT) Focus Keyboard");
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
      this.addAttachments(widget.existingAttachments ?? []);
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

  void addAttachments(List<PlatformFile> attachments) {
    pickedImages.addAll(attachments);
    if (!kIsWeb) pickedImages = pickedImages.toSet().toList();
    setCanRecord();
  }

  void updateTextFieldAttachments() {
    if (textFieldData != null) {
      textFieldData!.attachments = List<PlatformFile>.from(pickedImages);
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
    safeChat = CurrentChat.of(context);
  }

  @override
  void dispose() {
    focusNode!.dispose();
    _streamController.close();

    if (safeChat?.chat == null) controller!.dispose();

    if (!kIsWeb) {
      String dir = SettingsManager().appDocDir.path;
      Directory tempAssets = Directory("$dir/tempAssets");
      tempAssets.exists().then((value) {
        if (value) {
          tempAssets.delete(recursive: true);
        }
      });
    }
    pickedImages = [];
    super.dispose();
  }

  void disposeAudioFile(BuildContext context, PlatformFile file) {
    // Dispose of the audio controller
    CurrentChat.of(context)?.audioPlayers[file.path]?.item1.dispose();
    CurrentChat.of(context)?.audioPlayers[file.path]?.item2.pause();
    CurrentChat.of(context)?.audioPlayers.removeWhere((key, _) => key == file.path);
    if (file.path != null) {
      // Delete the file
      File(file.path!).delete();
    }
  }

  void onContentCommit(CommittedContent content) async {
    // Add some debugging logs
    Logger.info("[Content Commit] Keyboard received content");
    Logger.info("  -> Content Type: ${content.mimeType}");
    Logger.info("  -> URI: ${content.uri}");
    Logger.info("  -> Content Length: ${content.hasData ? content.data!.length : "null"}");

    // Parse the filename from the URI and read the data as a List<int>
    String filename = uriToFilename(content.uri, content.mimeType);

    // Save the data to a location and add it to the file picker
    if (content.hasData) {
      this.addAttachments([PlatformFile(
        name: filename,
        size: content.data!.length,
        bytes: content.data,
      )]);

      // Update the state
      updateTextFieldAttachments();
      if (this.mounted) setState(() {});
    } else {
      showSnackbar('Insertion Failed', 'Attachment has no data!');
    }
  }

  Future<void> reviewAudio(BuildContext originalContext, PlatformFile file) async {
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
              AudioPlayerWiget(
                key: new Key("AudioMessage-${file.size}"),
                file: file,
                context: originalContext,
              )
            ],
          ),
          actions: <Widget>[
            new TextButton(
                child: new Text("Discard", style: Theme.of(context).textTheme.subtitle1),
                onPressed: () {
                  // Dispose of the audio controller
                  if (!kIsWeb) this.disposeAudioFile(originalContext, file);

                  // Remove the OG alert dialog
                  Get.back();
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
                  if (!kIsWeb) this.disposeAudioFile(originalContext, file);
                }

                // Remove the OG alert dialog
                Get.back();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> toggleShareMenu() async {
    if (kIsDesktop) {
      final res = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
      if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

      for (pf.PlatformFile e in res.files) {
        addAttachment(PlatformFile(
          path: e.path,
          name: e.name,
          size: e.size,
          bytes: e.bytes,
        ));
      }
      Get.back();
      return;
    }
    if (kIsWeb) {
      Get.defaultDialog(
        title: "What would you like to do?",
        titleStyle: Theme.of(context).textTheme.headline1,
        confirm: Container(height: 0, width: 0),
        cancel: Container(height: 0, width: 0),
        content: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          ListTile(
            title: Text("Upload file", style: Theme.of(context).textTheme.bodyText1),
            onTap: () async {
              final res = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
              if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

              for (pf.PlatformFile e in res.files) {
                addAttachment(PlatformFile(
                  path: null,
                  name: e.name,
                  size: e.size,
                  bytes: e.bytes,
                ));
              }
              Get.back();
            },
          ),
          ListTile(
            title: Text("Send location", style: Theme.of(context).textTheme.bodyText1),
            onTap: () async {
              Share.location(CurrentChat.of(context)!.chat);
              Get.back();
            },
          ),
        ]),
        backgroundColor: Theme.of(context).backgroundColor,
      );
      return;
    }

    bool showMenu = showShareMenu.value;

    // If the image picker is already open, close it, and return
    if (!showMenu) {
      focusNode!.unfocus();
    }
    if (!showMenu && !(await PhotoManager.requestPermission())) {
      showShareMenu.value = false;
      return;
    }

    showShareMenu.value = !showMenu;
  }

  Future<bool> _onWillPop() async {
    if (showShareMenu.value) {
      if (this.mounted) {
        showShareMenu.value = false;
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
          onRemove: (PlatformFile attachment) {
            pickedImages
                .removeWhere((element) => kIsWeb ? element.bytes == element.bytes : element.path == attachment.path);
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
    return AnimatedSize(
      vsync: this,
      duration: Duration(milliseconds: 300),
      child: Container(
        height: size,
        width: fileDragged ? size * 3 : size,
        margin: EdgeInsets.only(left: 5.0, right: 5.0),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(fileDragged ? 5 : 40),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (kIsWeb)
              DropzoneView(
                operation: DragOperation.copy,
                cursor: CursorType.auto,
                onCreated: (c) {
                  dropZoneController = c;
                },
                onDrop: (ev) async {
                  fileDragged = false;
                  addAttachment(PlatformFile(
                      name: await dropZoneController!.getFilename(ev),
                      bytes: await dropZoneController!.getFileData(ev),
                      size: await dropZoneController!.getFileSize(ev)
                  ));
                },
              ),
            TransparentPointer(
              child: ClipRRect(
                child: InkWell(
                  onTap: toggleShareMenu,
                  child: Padding(
                    padding: EdgeInsets.only(right: SettingsManager().settings.skin.value == Skins.iOS ? 0 : 1, left: SettingsManager().settings.skin.value == Skins.iOS ? 0.5 : 0),
                    child: fileDragged
                        ? Center(child: Text("Drop file here"))
                        : Icon(
                            SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.share : Icons.share,
                            color: Colors.white.withAlpha(225),
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
          ],
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
        if (CurrentChat.of(context)?.chat.isGroup() ?? false) {
          if (generateNames) {
            placeholder = "Group Chat";
          } else if (hideInfo) {
            placeholder = "BlueBubbles";
          } else {
            String? title = await CurrentChat.of(context)?.chat.getTitle();
            if (!isNullOrEmpty(title)!) {
              placeholder = title!;
            }
          }
        } else if (!isNullOrEmpty(CurrentChat.of(context)?.chat.participants)!) {
          if (generateNames) {
            placeholder = CurrentChat.of(context)!.chat.fakeParticipants[0];
          } else if (hideInfo) {
            placeholder = "BlueBubbles";
          } else {
            // If it's not a group chat, get the participant's contact info
            Handle? handle = CurrentChat.of(context)?.chat.participants[0];
            Contact? contact = ContactManager().getCachedContactSync(handle?.address ?? "");
            if (contact == null) {
              placeholder = await formatPhoneNumber(handle);
            } else {
              placeholder = contact.displayName;
            }
          }
        }
      }
    } catch (ex) {
      Logger.error("Error setting Text Field Placeholder!");
      Logger.error(ex.toString());
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
              vsync: this,
              duration: Duration(milliseconds: 100),
              curve: Curves.easeInOut,
              child: FocusScope(
                child: Focus(
                  focusNode: FocusNode(),
                  onKey: (focus, event) {
                    if (!(event is RawKeyDownEvent)) return KeyEventResult.ignored;
                    Logger.info("Got key label ${event.data.keyLabel}, physical key ${event.data.physicalKey.toString()}, logical key ${event.data.logicalKey.toString()}", tag: "RawKeyboardListener");
                    if (event.data is RawKeyEventDataWindows) {
                      var data = event.data as RawKeyEventDataWindows;
                      if (data.keyCode == 13 && !event.isShiftPressed) {
                        sendMessage();
                        focusNode!.requestFocus();
                        return KeyEventResult.handled;
                      }
                      if (data.keyCode == 8 && event.isControlPressed) {
                        // Delete bad character (code 127)
                        String text = controller!.text;
                        text = text.characters.where((char) => char.codeUnits[0] != 127).join();
                        TextSelection selection = controller!.selection;
                        TextPosition base = selection.base;
                        int startPos = base.offset;
                        controller!.text = text;
                        controller!.selection = TextSelection.fromPosition(TextPosition(offset: startPos - 1));

                        if (text.isEmpty) return KeyEventResult.ignored;

                        // Get the word
                        List<String> words = text.trimRight().split(RegExp("[ \n]"));
                        RegExp punctuation = RegExp("[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\:\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~]");
                        int trailing = text.length - text.trimRight().length;
                        List<int> counts = words.map((word) => word.length).toList();
                        int end = startPos - 1 - trailing;
                        int start = 0;
                        if (punctuation.hasMatch(text.characters.toList()[end - 1])) {
                          start = end - 1;
                        } else {
                          for (int i = 0; i < counts.length; i++) {
                            int count = counts[i];
                            if (start + count < end)
                              start += count + (i == counts.length - 1 ? 0 : 1);
                            else
                              break;
                          }
                        }
                        end += trailing; // Account for trimming
                        start = max(0, start); // Make sure it's not negative
                        text = text.substring(0, start) + text.substring(end);
                        controller!.text = text; // Set the text
                        controller!.selection =
                            TextSelection.fromPosition(TextPosition(offset: start)); // Set the position
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    }
                    // TODO figure out the Linux keycode
                    if (event.data is RawKeyEventDataLinux) {
                      var data = event.data as RawKeyEventDataLinux;
                      if (data.keyCode == 13 && !event.isShiftPressed) {
                        sendMessage();
                        focusNode!.requestFocus();
                        return KeyEventResult.handled;
                      }
                      if (data.keyCode == 8 && event.isControlPressed) {
                        // Delete bad character (code 127)
                        String text = controller!.text;
                        text = text.characters.where((char) => char.codeUnits[0] != 127).join();
                        TextSelection selection = controller!.selection;
                        TextPosition base = selection.base;
                        int startPos = base.offset;
                        controller!.text = text;
                        controller!.selection = TextSelection.fromPosition(TextPosition(offset: startPos - 1));

                        // Check if at end of a word
                        if (startPos - 1 == text.length || text.characters.toList()[startPos - 1].isBlank!) {
                          // Get the word
                          int trailing = text.length - text.trimRight().length;
                          List<String> words = text.trimRight().split(" ");
                          print(words);
                          List<int> counts = words.map((word) => word.length).toList();
                          int end = startPos - 1 - trailing;
                          int start = 0;
                          for (int i = 0; i < counts.length; i++) {
                            int count = counts[i];
                            if (start + count < end)
                              start += count + (i == counts.length - 1 ? 0 : 1);
                            else
                              break;
                          }
                          end += trailing; // Account for trimming
                          start -= 1; // Remove the space after the previous word
                          start = max(0, start); // Make sure it's not negative
                          text = text.substring(0, start) + text.substring(end);
                          // Set the text
                          controller!.text = text;
                          // Set the position
                          controller!.selection = TextSelection.fromPosition(TextPosition(offset: start));
                        }
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    }
                    // TODO figure out the MacOs keycode
                    if (event.data is RawKeyEventDataMacOs) {
                      var data = event.data as RawKeyEventDataMacOs;
                      if (data.keyCode == 13 && !event.isShiftPressed) {
                        sendMessage();
                        focusNode!.requestFocus();
                        return KeyEventResult.handled;
                      }
                      if (data.keyCode == 8 && event.isControlPressed) {
                        // Delete bad character (code 127)
                        String text = controller!.text;
                        text = text.characters.where((char) => char.codeUnits[0] != 127).join();
                        TextSelection selection = controller!.selection;
                        TextPosition base = selection.base;
                        int startPos = base.offset;
                        controller!.text = text;
                        controller!.selection = TextSelection.fromPosition(TextPosition(offset: startPos - 1));

                        // Check if at end of a word
                        if (startPos - 1 == text.length || text.characters.toList()[startPos - 1].isBlank!) {
                          // Get the word
                          int trailing = text.length - text.trimRight().length;
                          List<String> words = text.trimRight().split(" ");
                          print(words);
                          List<int> counts = words.map((word) => word.length).toList();
                          int end = startPos - 1 - trailing;
                          int start = 0;
                          for (int i = 0; i < counts.length; i++) {
                            int count = counts[i];
                            if (start + count < end)
                              start += count + (i == counts.length - 1 ? 0 : 1);
                            else
                              break;
                          }
                          end += trailing; // Account for trimming
                          start -= 1; // Remove the space after the previous word
                          start = max(0, start); // Make sure it's not negative
                          text = text.substring(0, start) + text.substring(end);
                          // Set the text
                          controller!.text = text;
                          // Set the position
                          controller!.selection = TextSelection.fromPosition(TextPosition(offset: start));
                        }
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    }
                    if (event.data is RawKeyEventDataWeb) {
                      var data = event.data as RawKeyEventDataWeb;
                      if (data.code == "Enter" && !event.isShiftPressed) {
                        sendMessage();
                        focusNode!.requestFocus();
                        return KeyEventResult.handled;
                      }
                      if ((data.physicalKey == PhysicalKeyboardKey.keyV || data.logicalKey == LogicalKeyboardKey.keyV)
                          && (event.isControlPressed || previousKeyCode == 0x1700000000)) {
                        getPastedImageWeb().then((value) {
                          if (value != null) {
                            var r = html.FileReader();
                            r.readAsArrayBuffer(value);
                            r.onLoadEnd.listen((e) {
                              if (r.result != null && r.result is Uint8List) {
                                Uint8List data = r.result as Uint8List;
                                addAttachment(PlatformFile(
                                  name: randomString(8) + ".png",
                                  bytes: data,
                                  size: data.length,
                                ));
                              }
                            });
                          }
                        });
                      }
                      previousKeyCode = data.logicalKey.keyId;
                      return KeyEventResult.ignored;
                    }
                    if (event.physicalKey == PhysicalKeyboardKey.enter &&
                        SettingsManager().settings.sendWithReturn.value) {
                      if (!isNullOrEmpty(controller!.text)!) {
                        sendMessage();
                        focusNode!.previousFocus(); // I genuinely don't know why this works
                        return KeyEventResult.handled;
                      } else {
                        controller!.text = ""; // Stop pressing physical enter with enterIsSend from creating newlines
                        focusNode!.previousFocus(); // I genuinely don't know why this works
                        return KeyEventResult.handled;
                      }
                    }
                    // 99% sure this isn't necessary but keeping it for now
                    if (event.isKeyPressed(LogicalKeyboardKey.enter) &&
                        SettingsManager().settings.sendWithReturn.value &&
                        !isNullOrEmpty(controller!.text)!) {
                      sendMessage();
                      focusNode!.requestFocus();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: ThemeSwitcher(
                    iOSSkin: CustomCupertinoTextField(
                      enableIMEPersonalizedLearning: !SettingsManager().settings.incognitoKeyboard.value,
                      enabled: sendCountdown == null,
                      textInputAction: SettingsManager().settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                          ? TextInputAction.send
                          : TextInputAction.newline,
                      cursorColor: Theme.of(context).primaryColor,
                      onLongPressStart: () {
                        Feedback.forLongPress(context);
                      },
                      onTap: () {
                        HapticFeedback.selectionClick();
                      },
                      key: _searchFormKey,
                      onSubmitted: (String value) {
                        if (isNullOrEmpty(value)! && pickedImages.isEmpty) return;
                        focusNode!.requestFocus();
                        sendMessage();
                      },
                      onContentCommitted: onContentCommit,
                      textCapitalization: TextCapitalization.sentences,
                      focusNode: focusNode,
                      autocorrect: true,
                      controller: controller,
                      scrollPhysics: CustomBouncingScrollPhysics(),
                      style: Theme.of(context).textTheme.bodyText1!.apply(
                            color: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) ==
                                    Brightness.light
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
                      autofocus: SettingsManager().settings.autoOpenKeyboard.value || kIsWeb || kIsDesktop,
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
                      // enableIMEPersonalizedLearning: !SettingsManager().settings.incognitoKeyboard.value,
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      autocorrect: true,
                      textInputAction: SettingsManager().settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                          ? TextInputAction.send
                          : TextInputAction.newline,
                      autofocus: SettingsManager().settings.autoOpenKeyboard.value || kIsWeb || kIsDesktop,
                      cursorColor: Theme.of(context).primaryColor,
                      key: _searchFormKey,
                      onSubmitted: (String value) {
                        if (isNullOrEmpty(value)! && pickedImages.isEmpty) return;
                        focusNode!.requestFocus();
                        sendMessage();
                      },
                      style: Theme.of(context).textTheme.bodyText1!.apply(
                            color: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) ==
                                    Brightness.light
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
                      // enableIMEPersonalizedLearning: !SettingsManager().settings.incognitoKeyboard.value,
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      autocorrect: true,
                      textInputAction: SettingsManager().settings.sendWithReturn.value && !kIsWeb && !kIsDesktop
                          ? TextInputAction.send
                          : TextInputAction.newline,
                      autofocus: SettingsManager().settings.autoOpenKeyboard.value || kIsWeb || kIsDesktop,
                      cursorColor: Theme.of(context).primaryColor,
                      key: _searchFormKey,
                      onSubmitted: (String value) {
                        if (isNullOrEmpty(value)! && pickedImages.isEmpty) return;
                        focusNode!.requestFocus();
                        sendMessage();
                      },
                      style: Theme.of(context).textTheme.bodyText1!.apply(
                            color: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) ==
                                    Brightness.light
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
    String? pathName;
    if (!kIsWeb) {
      String appDocPath = SettingsManager().appDocDir.path;
      Directory directory = Directory("$appDocPath/attachments/");
      if (!await directory.exists()) {
        directory.createSync();
      }
      pathName = "$appDocPath/attachments/OutgoingAudioMessage.m4a";
      File file = new File(pathName);
      if (file.existsSync()) file.deleteSync();
    }

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
      String? pathName = await Record().stop();

      if (this.mounted) {
        isRecording.value = false;
      }

      if (pathName != null) reviewAudio(context, PlatformFile(
        name: "${randomString(8)}.m4a",
        path: kIsWeb ? null : pathName,
        size: 0,
        bytes: kIsWeb ? (await Dio().get(pathName, options: Options(responseType: ResponseType.bytes))).data : null,
      ));
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
      pickedImages.clear();
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
    } else if (canRecord.value &&
        !isRecording.value &&
        !kIsDesktop &&
        await Record().hasPermission()) {
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
                  constraints: BoxConstraints(maxWidth: 35, maxHeight: 34),
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
                          elevation: 0),
                      onPressed: sendAction,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Obx(() => AnimatedOpacity(
                                opacity: sendCountdown == null && canRecord.value && !kIsDesktop ? 1.0 : 0.0,
                                duration: Duration(milliseconds: 150),
                                child: Icon(
                                  CupertinoIcons.waveform,
                                  color: (isRecording.value) ? Colors.red : Colors.white,
                                  size: 22,
                                ),
                              )),
                          Obx(() => AnimatedOpacity(
                                opacity:
                                    (sendCountdown == null && (!canRecord.value || kIsDesktop)) && !isRecording.value
                                        ? 1.0
                                        : 0.0,
                                duration: Duration(milliseconds: 150),
                                child: Icon(
                                  CupertinoIcons.arrow_up,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              )),
                          AnimatedOpacity(
                            opacity: sendCountdown != null ? 1.0 : 0.0,
                            duration: Duration(milliseconds: 50),
                            child: Icon(
                              CupertinoIcons.xmark_circle,
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
                    if (canRecord.value && !isRecording.value && !kIsDesktop) {
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
                                    opacity: sendCountdown == null && canRecord.value && !kIsDesktop ? 1.0 : 0.0,
                                    duration: Duration(milliseconds: 150),
                                    child: Icon(
                                      Icons.mic,
                                      color: (isRecording.value) ? Colors.red : Colors.white,
                                      size: 20,
                                    ),
                                  )),
                              Obx(() => AnimatedOpacity(
                                    opacity: (sendCountdown == null && (!canRecord.value || kIsDesktop)) &&
                                            !isRecording.value
                                        ? 1.0
                                        : 0.0,
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
        onAddAttachment: addAttachment,
      ));

  void addAttachment(PlatformFile? file) {
    if (file == null) return;

    for (PlatformFile image in pickedImages) {
      if (image.bytes == file.bytes) {
        pickedImages.removeWhere((element) => element.bytes == file.bytes);
        updateTextFieldAttachments();
        if (this.mounted) setState(() {});
        return;
      }
    }

    this.addAttachments([file]);
    updateTextFieldAttachments();
    if (this.mounted) setState(() {});
  }
}

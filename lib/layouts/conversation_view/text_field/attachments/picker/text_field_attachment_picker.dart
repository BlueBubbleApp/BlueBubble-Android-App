import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/picker/attachment_picked.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class TextFieldAttachmentPicker extends StatefulWidget {
  TextFieldAttachmentPicker({
    Key? key,
    required this.visible,
    required this.onAddAttachment,
  }) : super(key: key);
  final bool visible;
  final Function(File?) onAddAttachment;

  @override
  _TextFieldAttachmentPickerState createState() => _TextFieldAttachmentPickerState();
}

class _TextFieldAttachmentPickerState extends State<TextFieldAttachmentPicker> with SingleTickerProviderStateMixin {
  List<AssetEntity> _images = <AssetEntity>[];

  @override
  void initState() {
    super.initState();
    getAttachments();
    // If the app is reopened, then update the attachments
    LifeCycleManager.instance.stream.listen((event) async {
      if (event && widget.visible) getAttachments();
    });
  }

  Future<void> getAttachments() async {
    if (!this.mounted) return;
    List<AssetPathEntity> list = await PhotoManager.getAssetPathList(onlyAll: true);
    if (list.length > 0) {
      List<AssetEntity> images = await list.first.getAssetListRange(start: 0, end: 60);
      _images = images;
    }

    if (this.mounted) setState(() {});
  }

  Future<void> openFullCamera({String type: 'camera'}) async {
    // Create a file that the camera can write to
    String appDocPath = SettingsManager().appDocDir.path;
    String ext = (type == 'video') ? ".mp4" : ".png";
    File file = new File("$appDocPath/attachments/" + randomString(16) + ext);
    await file.create(recursive: true);

    // Take the picture after opening the camera
    await MethodChannelInterface().invokeMethod("open-camera", {"path": file.path, "type": type});

    // If we don't get data back, return outta here
    if (!file.existsSync()) return;
    if (file.statSync().size == 0) {
      file.deleteSync();
      return;
    }

    widget.onAddAttachment(file);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Duration(milliseconds: 300),
      vsync: this,
      curve: Curves.easeInOut,
      child: widget.visible
          ? SizedBox(
              child: RefreshIndicator(
                onRefresh: () async {
                  getAttachments();
                },
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: 300,
                    child: CustomScrollView(
                      physics: ThemeSwitcher.getScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(left: 5, right: 5, top: 5, bottom: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: 90,
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        primary: Theme.of(context).accentColor,
                                      ),
                                      onPressed: () async {
                                        List<dynamic>? res = await MethodChannelInterface().invokeMethod("pick-file");
                                        if (res == null || res.isEmpty) return;

                                        for (dynamic path in res) {
                                          widget.onAddAttachment(File(path.toString()));
                                        }
                                      },
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              Icons.video_library,
                                              color: Theme.of(context).textTheme.bodyText1!.color,
                                            ),
                                          ),
                                          Text(
                                            "Files",
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodyText1!.color,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(height: 10),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: 90,
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        primary: Theme.of(context).accentColor,
                                      ),
                                      onPressed: () async {
                                        showDialog(
                                          context: context,
                                          builder: (buildContext) => AlertDialog(
                                            backgroundColor: Theme.of(context).accentColor,
                                            title: Text(
                                              "Send Current Location?",
                                              style: Theme.of(context).textTheme.headline1,
                                            ),
                                            actions: <Widget>[
                                              TextButton(
                                                style: TextButton.styleFrom(
                                                  backgroundColor: Colors.blue[600],
                                                ),
                                                child: Text(
                                                  "Send",
                                                  style: Theme.of(context).textTheme.bodyText1,
                                                ),
                                                onPressed: () async {
                                                  Share.location(CurrentChat.of(context)!.chat);
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                              TextButton(
                                                style: TextButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: Text(
                                                  "Cancel",
                                                  style: Theme.of(context).textTheme.bodyText1,
                                                ),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              Icons.location_on,
                                              color: Theme.of(context).textTheme.bodyText1!.color,
                                            ),
                                          ),
                                          Text(
                                            "Location",
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodyText1!.color,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(left: 5, right: 10, top: 5, bottom: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: 90,
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        primary: Theme.of(context).accentColor,
                                      ),
                                      onPressed: () async {
                                        openFullCamera();
                                      },
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              Icons.photo_camera,
                                              color: Theme.of(context).textTheme.bodyText1!.color,
                                            ),
                                          ),
                                          Text(
                                            "Camera",
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodyText1!.color,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(height: 10),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: 90,
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        primary: Theme.of(context).accentColor,
                                      ),
                                      onPressed: () async {
                                        openFullCamera(type: "video");
                                      },
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              Icons.videocam,
                                              color: Theme.of(context).textTheme.bodyText1!.color,
                                            ),
                                          ),
                                          Text(
                                            "Video",
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodyText1!.color,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                          ),
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              AssetEntity element = _images[index];
                              return GalleryAttachment(
                                key: Key("attachmentPicked" + _images[index].id),
                                data: element,
                                onTap: () async {
                                  widget.onAddAttachment(await element.file);
                                },
                              );
                            },
                            childCount: _images.length,
                          ),
                        ),
                      ],
                    ),
                  )
                ),
              ),
              height: 300,
            )
          : Container(),
    );
  }
}

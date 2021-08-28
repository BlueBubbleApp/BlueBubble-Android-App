import 'dart:typed_data';

import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:mime_type/mime_type.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryAttachment extends StatefulWidget {
  GalleryAttachment({Key? key, required this.onTap, required this.data}) : super(key: key);
  final AssetEntity data;
  final Function onTap;

  @override
  _GalleryAttachmentState createState() => _GalleryAttachmentState();
}

class _GalleryAttachmentState extends State<GalleryAttachment> with AutomaticKeepAliveClientMixin {
  Uint8List? image;
  String? path;

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    path = (await widget.data.file)!.path;

    BlueBubblesTextField.of(context)!.stream.listen((event) {
      if (this.mounted) setState(() {});
    });

    load();
  }

  Future<void> load() async {
    image = await widget.data.thumbDataWithSize(800, 800, quality: SettingsManager().compressionQuality);
    if (this.mounted) setState(() {});
  }

  bool get containsThis =>
      BlueBubblesTextField.of(context)!.pickedImages.where((element) => element.path == path).length > 0;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bool hideAttachments =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideAttachments.value;
    final bool hideAttachmentTypes =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideAttachmentTypes.value;
    return image != null
        ? AnimatedContainer(
            duration: Duration(milliseconds: 250),
            padding: EdgeInsets.all(containsThis ? 20 : 5),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: <Widget>[
                      Image.memory(
                        image!,
                        fit: BoxFit.cover,
                        width: 150,
                        height: 150,
                      ),
                      if (hideAttachments)
                        Positioned.fill(
                          child: Container(
                            color: Theme.of(context).accentColor,
                          ),
                        ),
                      if (hideAttachments && !hideAttachmentTypes)
                        Positioned.fill(
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              mime(path)!,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (containsThis)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      child: Center(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                        ),
                      ),
                      color: Colors.white.withAlpha(50),
                    ),
                  ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      child: widget.data.type == AssetType.video
                          ? Icon(
                              Icons.play_circle_filled,
                              color: Colors.white.withOpacity(0.5),
                              size: 50,
                            )
                          : Container(),
                      onTap: () async {
                        widget.onTap();
                      },
                    ),
                  ),
                ),
              ],
            ),
          )
        : SizedBox(
            width: 100,
            height: 100,
            child: Center(
              child: CircularProgressIndicator(
                backgroundColor: Theme.of(context).backgroundColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
          );
  }

  @override
  bool get wantKeepAlive => true;
}

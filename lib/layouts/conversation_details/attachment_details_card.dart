import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/layouts/image_viewer/attachmet_fullscreen_viewer.dart';
import 'package:bluebubbles/layouts/widgets/circle_progress_bar.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/regular_file_opener.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

class AttachmentDetailsCard extends StatefulWidget {
  AttachmentDetailsCard({Key? key, required this.attachment, required this.allAttachments}) : super(key: key);
  final Attachment attachment;
  final List<Attachment> allAttachments;

  @override
  _AttachmentDetailsCardState createState() => _AttachmentDetailsCardState();
}

class _AttachmentDetailsCardState extends State<AttachmentDetailsCard> {
  Uint8List? previewImage;
  double aspectRatio = 4 / 3;
  late PlatformFile attachmentFile;

  @override
  void initState() {
    super.initState();

    attachmentFile = new PlatformFile(
      name: widget.attachment.transferName!,
      path: kIsWeb ? null : widget.attachment.getPath(),
      bytes: widget.attachment.bytes,
      size: widget.attachment.totalBytes!,
    );
    subscribeToDownloadStream();
  }

  void subscribeToDownloadStream() {
    if (Get.find<AttachmentDownloadService>().downloaders.contains(widget.attachment.guid)) {
      AttachmentDownloadController controller = Get.find<AttachmentDownloadController>(tag: widget.attachment.guid);
      ever<PlatformFile?>(controller.file,
          (file) {
        if (file != null && this.mounted) {
          Future.delayed(Duration(milliseconds: 500), () {
            if (!this.mounted) return;
            setState(() {});
          });
        }
      });
    }
  }

  void getCompressedImage() {
    String path = AttachmentHelper.getAttachmentPath(widget.attachment);
    AttachmentHelper.compressAttachment(widget.attachment, path).then((data) {
      if (!this.mounted) return;
      setState(() {
        previewImage = data;
      });
    });
  }

  Widget buildReadyToDownload(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
      onPressed: () async {
        Get.put(AttachmentDownloadController(attachment: widget.attachment), tag: widget.attachment.guid);
        subscribeToDownloadStream();
        if (this.mounted) setState(() {});
      },
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            widget.attachment.getFriendlySize(),
            style: Theme.of(context).textTheme.bodyText1,
          ),
          Icon(SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.cloud_download : Icons.cloud_download, size: 28.0),
          (widget.attachment.mimeType != null)
              ? Text(
                  basename(this.attachmentFile.path),
                  style: Theme.of(context).textTheme.bodyText1,
                )
              : Container()
        ],
      ),
    );
  }

  Widget buildPreview(BuildContext context) => SizedBox(
        width: CustomNavigator.width(context) / 2,
        child: _buildPreview(this.attachmentFile, context),
      );

  @override
  Widget build(BuildContext context) {
    Attachment attachment = widget.attachment;
    final bool hideAttachments =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideAttachments.value;
    final bool hideAttachmentTypes =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideAttachmentTypes.value;
    if (hideAttachments && !hideAttachmentTypes)
      return Container(
        alignment: Alignment.center,
        color: Theme.of(context).accentColor,
        child: Text(
          widget.attachment.mimeType!,
          textAlign: TextAlign.center,
        ),
      );
    if (hideAttachments)
      return Container(
        color: Theme.of(context).accentColor,
      );
    if (kIsWeb) {
      return buildPreview(context);
    }
    File file = new File(
      "${SettingsManager().appDocDir.path}/attachments/${attachment.guid}/${attachment.transferName}",
    );
    if (!file.existsSync()) {
      return Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            color: Theme.of(context).accentColor,
          ),
          Center(
            child: !Get.find<AttachmentDownloadService>().downloaders.contains(attachment.guid)
                ? buildReadyToDownload(context)
                : Builder(
                    builder: (context) {
                      bool attachmentExists = kIsWeb ? false : File(this.attachmentFile.path).existsSync();

                      // If the attachment exists, build the preview
                      if (attachmentExists) return buildPreview(context);

                      // If the attachment is not being downloaded, show the downloader
                      if (!Get.find<AttachmentDownloadService>().downloaders.contains(attachment.guid)) {
                        return buildReadyToDownload(context);
                      }

                      return Obx(() {
                        AttachmentDownloadController controller = Get.find<AttachmentDownloadController>(tag: attachment.guid);
                        // If the download is complete, show the preview
                        if (controller.file.value != null) return buildPreview(context);

                        // If all else fails, show the downloader
                        return Container(
                            height: 40,
                            width: 40,
                            child: CircleProgressBar(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.grey,
                                value: controller.progress.value?.toDouble() ?? 0));
                      });
                    }),
          ),
        ],
      );
    } else {
      return buildPreview(context);
    }
  }

  Future<void> getVideoPreview(PlatformFile file) async {
    if (previewImage != null || kIsWeb) return;
    previewImage = await AttachmentHelper.getVideoThumbnail(file.path);
    Size size = await AttachmentHelper.getImageSizing("${file.path}.thumbnail");
    widget.attachment.width = size.width.toInt();
    widget.attachment.height = size.height.toInt();
    aspectRatio = size.width / size.height;
    if (this.mounted) setState(() {});
  }

  Widget _buildPreview(PlatformFile file, BuildContext context) {
    if (widget.attachment.mimeType!.startsWith("image/")) {
      if (previewImage == null) {
        if (file.bytes != null) previewImage = file.bytes;
        else getCompressedImage();
      }

      return Stack(
        children: <Widget>[
          SizedBox(
            child: Hero(
                tag: widget.attachment.guid!,
                child: (previewImage != null)
                    ? Image.memory(
                        previewImage!,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        alignment: Alignment.center,
                      )
                    : Container()),
            width: CustomNavigator.width(context) / 2,
            height: CustomNavigator.width(context) / 2,
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                CurrentChat? currentChat = CurrentChat.of(context);
                Navigator.of(context).push(
                  ThemeSwitcher.buildPageRoute(
                    builder: (context) => AttachmentFullscreenViewer(
                      currentChat: currentChat,
                      attachment: widget.attachment,
                      showInteractions: true,
                    ),
                  ),
                );
              },
            ),
          )
        ],
      );
    } else if (widget.attachment.mimeType!.startsWith("video/")) {
      getVideoPreview(file);

      return Stack(
        children: <Widget>[
          SizedBox(
            child: Hero(
              tag: widget.attachment.guid!,
              child: previewImage != null
                  ? Image.memory(
                      previewImage!,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                      alignment: Alignment.center,
                    )
                  : Container(),
            ),
            width: CustomNavigator.width(context) / 2,
            height: CustomNavigator.width(context) / 2,
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  ThemeSwitcher.buildPageRoute(
                    builder: (context) => AttachmentFullscreenViewer(
                      attachment: widget.attachment,
                      showInteractions: true,
                    ),
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(
              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.play : Icons.play_arrow,
              color: Colors.white,
            ),
          ),
        ],
      );
    } else {
      return Container(
        color: Theme.of(context).accentColor,
        child: Center(
          child: RegularFileOpener(
            file: file,
            attachment: widget.attachment,
          ),
        ),
      );
    }
  }
}

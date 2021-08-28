import 'dart:io';

import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/attachment_downloader_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_file.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/contact_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/image_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/location_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/regular_file_opener.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/video_widget.dart';
import 'package:bluebubbles/layouts/widgets/circle_progress_bar.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AttachmentLifecycleController extends GetxController {
  final Rxn<dynamic> content = Rxn<dynamic>();
  final Attachment attachment;
  AttachmentLifecycleController({required this.attachment});
  
  @override
  void onInit() {
    updateContent();
    super.onInit();
  }

  void updateContent() async {
    content.value = AttachmentHelper.getContent(attachment,
        path: attachment.guid == "redacted-mode-demo-attachment" ||
            attachment.guid!.contains("theme-selector")
            ? attachment.transferName
            : null);

    // If we can download it, do so
    if (await AttachmentHelper.canAutoDownload() && content.value is Attachment) {
      content.value = Get.put(AttachmentDownloadController(attachment: content.value), tag: content.value.guid);
    }
  }
}

class MessageAttachment extends StatelessWidget {
  MessageAttachment({
    Key? key,
    required this.attachment,
    required this.updateAttachment,
    required this.isFromMe,
  }) : super(key: key);
  final Attachment attachment;
  final Function() updateAttachment;
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttachmentLifecycleController>(
      init: AttachmentLifecycleController(
        attachment: attachment,
      ),
      global: false,
      tag: attachment.guid,
      builder: (controller) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: context.width * 0.5,
            maxHeight: context.height * 0.6,
          ),
          child: Obx(() => _buildAttachmentWidget(controller, context)),
        ),
      )
    );
  }

  Widget _buildAttachmentWidget(AttachmentLifecycleController controller, BuildContext context) {
    // If it's a file, it's already been downlaoded, so just display it
    if (controller.content.value is File || (controller.content.value is AttachmentDownloadController && controller.content.value.file.value != null)) {
      File file = controller.content.value is File ? controller.content.value : controller.content.value.file.value;
      String? mimeType = attachment.mimeType;
      if (mimeType != null) mimeType = mimeType.substring(0, mimeType.indexOf("/"));
      if (mimeType == "image" && !attachment.mimeType!.endsWith("tiff")) {
        return MediaFile(
          attachment: attachment,
          child: ImageWidget(
            file: file,
            attachment: attachment,
          ),
        );
      } else if (mimeType == "video") {
        return MediaFile(
          attachment: attachment,
          child: VideoWidget(
            attachment: attachment,
            file: file,
          ),
        );
      } else if (mimeType == "audio" && !attachment.mimeType!.contains("caf")) {
        return MediaFile(
          attachment: attachment,
          child: AudioPlayerWidget(file: file, width: 250, isFromMe: isFromMe),
        );
      } else if (attachment.mimeType == "text/x-vlocation" || attachment.uti == 'public.vlocation') {
        return MediaFile(
          attachment: attachment,
          child: LocationWidget(
            file: file,
            attachment: attachment,
          ),
        );
      } else if (attachment.mimeType == "text/vcard") {
        return MediaFile(
          attachment: attachment,
          child: ContactWidget(
            file: file,
            attachment: attachment,
          ),
        );
      } else if (attachment.mimeType == null) {
        return Container();
      } else {
        return MediaFile(
          attachment: attachment,
          child: RegularFileOpener(
            file: file,
            attachment: attachment,
          ),
        );
      }

      // If it's an attachment, then it needs to be manually downloaded
    } else if (controller.content.value is Attachment || (controller.content.value is AttachmentDownloadController && controller.content.value.error.value)) {
      Attachment attachment2 = controller.content.value is Attachment ? controller.content.value : attachment;
      return AttachmentDownloaderWidget(
        onPressed: () {
          controller.content.value = Get.put(AttachmentDownloadController(attachment: attachment2), tag: attachment2.guid);
        },
        attachment: attachment2,
        placeHolder: buildPlaceHolder(context),
      );

      // If it's an AttachmentDownloader, it is currently being downloaded
    } else if (controller.content.value is AttachmentDownloadController) {
      if (attachment.mimeType == null) return Container();
      return Stack(
        alignment: Alignment.center,
        children: <Widget>[
          buildPlaceHolder(context),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Center(
                    child: Container(
                      height: 40,
                      width: 40,
                      child: CircleProgressBar(
                        value: controller.content.value.progress.value?.toDouble() ?? 0,
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  ((controller.content.value as AttachmentDownloadController).attachment.mimeType != null)
                      ? Container(height: 5.0)
                      : Container(),
                  (controller.content.value.attachment.mimeType != null)
                      ? Text(
                    controller.content.value.attachment.mimeType,
                    style: Theme.of(context).textTheme.bodyText1,
                  )
                      : Container()
                ],
              ),
            ],
          ),
        ],
      );
    } else {
      return Text(
        "Error loading",
        style: Theme.of(context).textTheme.bodyText1,
      );
      //     return Container();
    }
  }

  Widget buildPlaceHolder(BuildContext context) {
    return buildImagePlaceholder(context, attachment, Container());
  }
}

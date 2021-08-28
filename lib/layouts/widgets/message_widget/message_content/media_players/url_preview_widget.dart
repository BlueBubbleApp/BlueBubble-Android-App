import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/metadata_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:metadata_fetch/metadata_fetch.dart';

class UrlPreviewController extends GetxController with SingleGetTickerProviderMixin {
  final List<Attachment?> linkPreviews;
  final Message message;
  final BuildContext context;
  final Rxn<Metadata> data = Rxn<Metadata>();
  final RxBool gotError = false.obs;
  UrlPreviewController({
    required this.linkPreviews,
    required this.message,
    required this.context,
  });

  @override
  void onInit() {
    fetchMissingAttachments();
    if (MetadataHelper.mapIsNotEmpty(message.metadata)) {
      data.value = Metadata.fromJson(message.metadata!);
    } else {
      fetchPreview();
    }
    super.onInit();
  }

  void fetchMissingAttachments() {
    for (Attachment? attachment in linkPreviews) {
      if (AttachmentHelper.attachmentExists(attachment!)) continue;
      Get.put(AttachmentDownloadController(attachment: attachment, onComplete: () {
        update();
      }), tag: attachment.guid);
    }
  }

  Future<void> fetchPreview() async {
    // Try to get any already loaded attachment data
    if (CurrentChat.of(context) != null && CurrentChat.of(context)!.urlPreviews.containsKey(message.text)) {
      data.value = CurrentChat.of(context)!.urlPreviews[message.text];
    }

    if (data.value != null || MetadataHelper.isNotEmpty(data.value)) return;

    Metadata? meta;

    try {
      // Fetch the metadata
      meta = await MetadataHelper.fetchMetadata(message);
    } catch (ex) {
      debugPrint("Failed to fetch metadata! Error: ${ex.toString()}");
      gotError.value = true;
      return;
    }

    // If the data isn't empty, save/update it in the DB
    if (MetadataHelper.isNotEmpty(meta)) {
      // If pre-caching is enabled, fetch the image and save it
      if (SettingsManager().settings.preCachePreviewImages.value && !isNullOrEmpty(meta!.image)!) {
        // Save from URL
        File? newFile = await saveImageFromUrl(message.guid!, meta.image!);

        // If we downloaded a file, set the new metadata path
        if (newFile != null && newFile.existsSync()) {
          meta.image = newFile.path;
        }
      }

      message.updateMetadata(meta);

      data.value = meta;
    }

    // Save the metadata
    if (data.value != null) {
      CurrentChat.of(context)!.urlPreviews[message.text!] = data.value!;
    }
  }
}

class UrlPreviewWidget extends StatelessWidget {
  UrlPreviewWidget({Key? key, required this.linkPreviews, required this.message}) : super(key: key);
  final List<Attachment?> linkPreviews;
  final Message message;
  final PageController pageController = PageController();

  /// Returns a File object representing the [attachment]
  File attachmentFile(Attachment attachment) {
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = "$appDocPath/attachments/${attachment.guid}/${attachment.transferName}";
    return new File(pathName);
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<UrlPreviewController>(
      global: false,
      init: UrlPreviewController(
        linkPreviews: linkPreviews,
        message: message,
        context: context,
      ),
      builder: (controller) {
        final bool hideContent = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideMessageContent.value;
        final bool hideType = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideAttachmentTypes.value;

        List<Widget> items = [
          Obx(() {
            if (controller.data.value?.image != null && controller.data.value!.image!.isNotEmpty && linkPreviews.length <= 1) {
              if (controller.data.value!.image!.startsWith("/")) {
                return Image.file(new File(controller.data.value!.image!),
                    filterQuality: FilterQuality.low, errorBuilder: (context, error, stackTrace) => Container());
              } else {
                return Image.network(controller.data.value!.image!,
                    filterQuality: FilterQuality.low, errorBuilder: (context, error, stackTrace) => Container());
              }
            } else if (linkPreviews.length > 1 && AttachmentHelper.attachmentExists(linkPreviews.last!)) {
              return Image.file(attachmentFile(linkPreviews.last!),
                  filterQuality: FilterQuality.low, errorBuilder: (context, error, stackTrace) => Container());
            }
            return Container();
          }),
          Padding(
            padding: EdgeInsets.only(left: 14.0, right: 14.0, top: 14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Flexible(
                  fit: FlexFit.tight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Obx(() {
                        if (controller.data.value == null && !controller.gotError.value) {
                          return Text("Loading Preview...", style: Theme.of(context).textTheme.bodyText1!.apply(fontWeightDelta: 2));
                        } else if (controller.data.value != null && controller.data.value!.title != null && controller.data.value!.title != "Image Preview") {
                          return Text(
                            controller.data.value?.title ?? "<No Title>",
                            style: Theme.of(context).textTheme.bodyText1!.apply(fontWeightDelta: 2),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          );
                        } else if (controller.data.value?.title == "Image Preview") {
                          return Container();
                        } else {
                          return Text("Unable to Load Preview",
                              style: Theme.of(context).textTheme.bodyText1!.apply(fontWeightDelta: 2));
                        }
                      }),
                      Obx(() => controller.data.value != null && controller.data.value!.description != null
                        ? Padding(
                          padding: EdgeInsets.only(top: 5.0),
                          child: Text(
                            controller.data.value!.description!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeDelta: -5),
                        )) : Container()),
                      Obx(() => Padding(
                        padding: EdgeInsets.only(top: (controller.data.value?.title == "Image Preview" ? 0 : 5.0), bottom: 10.0),
                        child: Text(
                          Uri.tryParse(message.text!)?.host ?? "",
                          style: Theme.of(context).textTheme.subtitle2,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      )),
                    ],
                  ),
                ),
                Obx(() => (controller.data.value?.image == null &&
                    linkPreviews.length == 1 &&
                    AttachmentHelper.attachmentExists(linkPreviews.last!))
                    ? Padding(
                      padding: EdgeInsets.only(left: 10.0, bottom: 10.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: Image.file(
                          attachmentFile(linkPreviews.first!),
                          width: 40,
                          fit: BoxFit.contain,
                          errorBuilder: (BuildContext context, Object test, StackTrace? trace) {
                            return Container();
                          },
                        ),
                      ),
                    ) : Container()),
              ],
            ),
          ),
          if (hideContent)
            Positioned.fill(
              child: Container(
                color: Theme.of(context).accentColor,
              ),
            ),
          if (hideContent && !hideType)
            Positioned.fill(
                child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      "link",
                      textAlign: TextAlign.center,
                    )))
        ];

        return AnimatedSize(
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          duration: Duration(milliseconds: 200),
          vsync: controller,
          child: Padding(
            padding: EdgeInsets.only(
              top: message.hasReactions ? 18.0 : 4,
              bottom: 4,
              right: !message.isFromMe! && message.hasReactions ? 10.0 : 5.0,
              left: message.isFromMe! && message.hasReactions ? 5.0 : 0,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                color: Theme.of(context).accentColor,
                child: InkResponse(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    MethodChannelInterface().invokeMethod(
                      "open-link",
                      {"link": controller.data.value?.url ?? message.text, "forceBrowser": false},
                    );
                  },
                  child: Container(
                    // The minus 5 here is so the timestamps show OK during swipe
                    width: (context.width * 2 / 3) - 5,
                    child: (hideContent || hideType) ? Stack(children: items) : Column(children: items),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}

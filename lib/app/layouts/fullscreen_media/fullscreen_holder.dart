import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/components/circle_progress_bar.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/fullscreen_image.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/fullscreen_video.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import "package:flutter/material.dart";
import 'package:flutter/services.dart';
import 'package:gesture_x_detector/gesture_x_detector.dart';
import 'package:get/get.dart';

class FullscreenMediaHolder extends StatefulWidget {
  FullscreenMediaHolder({
    super.key,
    required this.attachment,
    required this.showInteractions,
    this.currentChat,
    this.videoController,
    this.mute
  });

  final ChatLifecycleManager? currentChat;
  final Attachment attachment;
  final bool showInteractions;
  final VideoController? videoController;
  final RxBool? mute;

  @override
  FullscreenMediaHolderState createState() => FullscreenMediaHolderState();
}

class FullscreenMediaHolderState extends OptimizedState<FullscreenMediaHolder> {
  final focusNode = FocusNode();
  late final PageController controller;
  late final messageService = widget.currentChat == null ? null : ms(widget.currentChat!.chat.guid);
  late List<Attachment> attachments = widget.currentChat == null
      ? [attachment]
      : messageService!.struct.attachments.where((e) => e.mimeStart == "image" || e.mimeStart == "video").toList();

  int currentIndex = 0;
  ScrollPhysics? physics;
  Attachment get attachment => widget.attachment;
  bool showAppBar = true;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || !widget.showInteractions) {
      controller = PageController(initialPage: 0);
    } else {
      if (widget.currentChat != null) {
        currentIndex = attachments.indexWhere((e) => e.guid == attachment.guid);
        if (currentIndex == -1) {
          attachments.add(attachment);
          currentIndex = attachments.indexWhere((e) => e.guid == attachment.guid);
        }
      }
      controller = PageController(initialPage: currentIndex);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TitleBarWrapper(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: ss.settings.immersiveMode.value
              ? Colors.transparent
              : context.theme.colorScheme.background, // navigation bar color
          systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
          statusBarColor: Colors.transparent, // status bar color
          statusBarIconBrightness:
              ss.settings.skin.value != Skins.iOS ? Brightness.light : context.theme.colorScheme.brightness.opposite,
        ),
        child: Actions(
          actions: {
            GoBackIntent: GoBackAction(context),
          },
          child: Scaffold(
            appBar: !iOS || !showAppBar
                // AppBar placeholder to prevent shifting of content when toggling the app bar
                ? PreferredSize(preferredSize: Size.fromHeight(attachment.message.target == null ? 56 : 88), child: Container())
                : AppBar(
                    leading: XGestureDetector(
                      supportTouch: true,
                      onTap: !kIsDesktop
                          ? null
                          : (details) {
                              Navigator.of(context).pop();
                            },
                      child: TextButton(
                        child: Text("Done",
                            style:
                                context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                        onPressed: () {
                          if (kIsDesktop) return;
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    leadingWidth: 75,
                    title: Text(
                        kIsWeb || !widget.showInteractions || widget.currentChat == null
                            ? "Media"
                            : "${currentIndex + 1} of ${attachments.length}",
                        style: context.theme.textTheme.titleLarge!
                            .copyWith(color: context.theme.colorScheme.properOnSurface)),
                    centerTitle: iOS,
                    iconTheme: IconThemeData(color: context.theme.colorScheme.primary),
                    backgroundColor: context.theme.colorScheme.properSurface,
                    bottom: (attachment.message.target == null) ? null : PreferredSize(
                      preferredSize: const Size.fromHeight(32),
                      child: Column(
                          children : [
                            RawChip(
                              tapEnabled: true,
                              side: BorderSide(color: context.theme.colorScheme.outline.withOpacity(0.1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              avatar: (attachment.message.target?.isFromMe == true) ?
                                ContactAvatarWidget(contact: Contact(id : 'you', displayName : ss.settings.userName.value, emails : [ss.settings.iCloudAccount.value])) :
                                ContactAvatarWidget(handle: attachment.message.target?.handle ?? attachment.message.target?.getHandle()),
                              label: Wrap(
                                spacing : 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('From ${attachment.message.target?.isFromMe == true ? 'You' : attachment.message.target?.handle?.displayName}',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.normal,
                                          color: context.theme.colorScheme.onSurface
                                      )
                                  ),
                                  Icon(
                                    iOS ? CupertinoIcons.chevron_right : Icons.chevron_right,
                                    color: context.theme.colorScheme.onSurface.withOpacity(0.6),
                                    size: 14,
                                  ),
                                ],
                              ),
                              onSelected: (selected) {
                                if (attachment.message.target?.chat.target != null) {
                                  final attachmentChat = attachment.message.target!.chat.target!;
                                  final service = ms(attachmentChat.guid);
                                  service.method = "network";
                                  service.struct.addMessages([attachment.message.target!]);
                                  ns.pushAndRemoveUntil(
                                    context,
                                    ConversationView(
                                      chat: attachmentChat,
                                      customService: service,
                                    ),
                                    (route) => route.isFirst,
                                  );
                                } else {
                                  // Gracefully show a "Failed to jump to message" pill notification
                                }
                              },
                            )
                          ]
                      )
                    ),
                    systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark
                        ? SystemUiOverlayStyle.light
                        : SystemUiOverlayStyle.dark,
                  ),
            backgroundColor: Colors.black,
            body: FocusScope(
              child: Focus(
                focusNode: focusNode,
                autofocus: true,
                onKeyEvent: (node, event) {
                  Logger.info(
                      "Got device label ${event.deviceType.label}, physical key ${event.physicalKey.toString()}, logical key ${event.logicalKey.toString()}",
                      tag: "RawKeyboardListener");
                  if (event.physicalKey.debugName == "Arrow Right") {
                    if (ss.settings.fullscreenViewerSwipeDir.value == SwipeDirection.RIGHT) {
                      controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                    } else {
                      controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                    }
                  } else if (event.physicalKey.debugName == "Arrow Left") {
                    if (ss.settings.fullscreenViewerSwipeDir.value == SwipeDirection.LEFT) {
                      controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                    } else {
                      controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                    }
                  } else if (event.physicalKey.debugName == "Escape") {
                    Navigator.of(context).pop();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: PageView.builder(
                  physics: physics ??
                      (attachments.length == 1
                          ? const NeverScrollableScrollPhysics()
                          : ThemeSwitcher.getScrollPhysics()),
                  reverse: ss.settings.fullscreenViewerSwipeDir.value == SwipeDirection.RIGHT,
                  itemCount: attachments.length,
                  onPageChanged: (int val) {
                    widget.videoController?.player.pause();
                    setState(() {
                      currentIndex = val;
                    });
                  },
                  controller: controller,
                  itemBuilder: (BuildContext context, int index) {
                    final attachment = attachments[index];
                    dynamic content =
                        as.getContent(attachment, path: attachment.guid == null ? attachment.transferName : null);
                    final key = attachment.guid ?? attachment.transferName ?? randomString(8);

                    if (content is PlatformFile) {
                      if (attachment.mimeStart == "image") {
                        return FullscreenImage(
                          key: Key(key),
                          attachment: attachment,
                          file: content,
                          showInteractions: widget.showInteractions,
                          updatePhysics: (ScrollPhysics p) {
                            if (physics != p) {
                              setState(() {
                                physics = p;
                              });
                            }
                          },
                          onOverlayToggle: (show) {
                            if (showAppBar != show) {
                              setState(() {
                                showAppBar = show;
                              });
                            }
                          },
                        );
                      } else if (attachment.mimeStart == "video") {
                        return FullscreenVideo(
                          key: Key(key),
                          file: content,
                          attachment: attachment,
                          showInteractions: widget.showInteractions,
                          videoController: widget.videoController,
                          mute: widget.mute,
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    } else if (content is Attachment) {
                      final Attachment _content = content;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            content = attachmentDownloader.startDownload(content, onComplete: (file) {
                              setState(() {
                                content = file;
                              });
                            });
                          });
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            SizedBox(
                              height: 40,
                              width: 40,
                              child: Center(
                                  child: Icon(iOS ? CupertinoIcons.cloud_download : Icons.cloud_download_outlined,
                                      size: 30)),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              (_content.mimeType ?? ""),
                              style: context.theme.textTheme.bodyLarge!
                                  .copyWith(color: context.theme.colorScheme.properOnSurface),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _content.getFriendlySize(),
                              style: context.theme.textTheme.bodyMedium!
                                  .copyWith(color: context.theme.colorScheme.properOnSurface),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      );
                    } else if (content is AttachmentDownloadController) {
                      final AttachmentDownloadController _content = content;
                      return InkWell(
                        onTap: () {
                          final AttachmentDownloadController _content = content;
                          if (!_content.error.value) return;
                          Get.delete<AttachmentDownloadController>(tag: _content.attachment.guid);
                          content = attachmentDownloader.startDownload(_content.attachment, onComplete: (file) {
                            setState(() {
                              content = file;
                            });
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Obx(() {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                SizedBox(
                                  height: 40,
                                  width: 40,
                                  child: Center(
                                    child: _content.error.value
                                        ? Icon(iOS ? CupertinoIcons.arrow_clockwise : Icons.refresh, size: 30)
                                        : CircleProgressBar(
                                            value: _content.progress.value?.toDouble() ?? 0,
                                            backgroundColor: context.theme.colorScheme.outline,
                                            foregroundColor: context.theme.colorScheme.properOnSurface,
                                          ),
                                  ),
                                ),
                                _content.error.value ? const SizedBox(height: 10) : const SizedBox(height: 5),
                                Text(
                                  _content.error.value ? "Failed to download!" : (_content.attachment.mimeType ?? ""),
                                  style: context.theme.textTheme.bodyLarge!
                                      .copyWith(color: context.theme.colorScheme.properOnSurface),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              ],
                            );
                          }),
                        ),
                      );
                    } else {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Error loading attachment",
                            style: context.theme.textTheme.bodyLarge,
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

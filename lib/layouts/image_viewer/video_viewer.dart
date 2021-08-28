import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:chewie/chewie.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/video_widget.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoViewer extends StatefulWidget {
  VideoViewer({Key? key, required this.file, required this.attachment, required this.showInteractions})
      : super(key: key);
  final File file;
  final Attachment attachment;
  final bool showInteractions;

  @override
  _VideoViewerState createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  bool showPlayPauseOverlay = false;
  Timer? hideOverlayTimer;
  late VideoPlayerController controller;
  ChewieController? chewieController;
  PlayerStatus status = PlayerStatus.NONE;
  bool hasListener = false;
  final RxBool isReloading = false.obs;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    initControllers();
  }

  void initControllers() async {
    controller = new VideoPlayerController.file(widget.file);
    controller.setVolume(SettingsManager().settings.startVideosMutedFullscreen.value ? 0 : 1);
    await controller.initialize();
    chewieController = ChewieController(
      videoPlayerController: controller,
      aspectRatio: controller.value.aspectRatio,
      allowFullScreen: false,
      allowMuting: false,
      materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).primaryColor,
          handleColor: Theme.of(context).primaryColor,
          bufferedColor: Theme.of(context).backgroundColor,
          backgroundColor: Theme.of(context).disabledColor),
      cupertinoProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).primaryColor,
          handleColor: Theme.of(context).primaryColor,
          bufferedColor: Theme.of(context).backgroundColor,
          backgroundColor: Theme.of(context).disabledColor),
    );
    setState(() {});
    this.createListener(controller);
    showPlayPauseOverlay = !controller.value.isPlaying;
  }

  void createListener(VideoPlayerController? controller) {
    if (controller == null || hasListener) return;

    controller.addListener(() async {
      // Get the current status
      PlayerStatus currentStatus = await getControllerStatus(controller);

      // If the status hasn't changed, don't do anything
      if (currentStatus == status) return;
      this.status = currentStatus;

      // If the status is ended, restart
      if (this.status == PlayerStatus.ENDED) {
        showPlayPauseOverlay = true;
        await controller.pause();
        await controller.seekTo(Duration());
      }

      if (this.mounted) setState(() {});
    });

    hasListener = true;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget overlay = AnimatedOpacity(
      opacity: showPlayPauseOverlay ? 1.0 : 0.0,
      duration: Duration(milliseconds: 125),
      child: Container(
          height: 150.0,
          width: context.width,
          color: Colors.black.withOpacity(0.65),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Padding(
              padding: EdgeInsets.only(top: 40.0, left: 5),
              child: CupertinoButton(
                padding: EdgeInsets.symmetric(horizontal: 5),
                onPressed: () async {
                  Navigator.pop(context);
                },
                child: Icon(
                  SettingsManager().settings.skin.value == Skins.iOS ? Icons.arrow_back_ios : Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 40.0),
                  child: CupertinoButton(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    onPressed: () async {
                      List<Widget> metaWidgets = [];
                      for (var entry in widget.attachment.metadata?.entries ?? {}.entries) {
                        metaWidgets.add(RichText(
                            text: TextSpan(children: [
                              TextSpan(
                                  text: "${entry.key}: ",
                                  style: Theme.of(context).textTheme.bodyText1!.apply(fontWeightDelta: 2)),
                              TextSpan(text: entry.value.toString(), style: Theme.of(context).textTheme.bodyText1)
                            ])));
                      }

                      if (metaWidgets.length == 0) {
                        metaWidgets.add(Text(
                          "No metadata available",
                          style: Theme.of(context).textTheme.bodyText1!.apply(fontWeightDelta: 2),
                          textAlign: TextAlign.center,
                        ));
                      }

                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            "Metadata",
                            style: Theme.of(context).textTheme.headline1,
                            textAlign: TextAlign.center,
                          ),
                          backgroundColor: Theme.of(context).accentColor,
                          content: SizedBox(
                            width: context.width * 3 / 5,
                            height: context.height * 1 / 4,
                            child: Container(
                              padding: EdgeInsets.all(10.0),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).backgroundColor,
                                  borderRadius: BorderRadius.all(Radius.circular(10))),
                              child: ListView(
                                physics: AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                children: metaWidgets,
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              child: Text(
                                "Close",
                                style: Theme.of(context).textTheme.bodyText1!.copyWith(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Icon(
                      Icons.info,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 40.0),
                  child: CupertinoButton(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    onPressed: () async {
                      isReloading.value = true;
                      CurrentChat.of(context)?.clearImageData(widget.attachment);

                      showSnackbar('In Progress', 'Redownloading attachment. Please wait...');
                      AttachmentHelper.redownloadAttachment(widget.attachment, onComplete: () async {
                        controller.dispose();
                        chewieController?.dispose();
                        controller = new VideoPlayerController.file(widget.file);
                        await controller.initialize();
                        isReloading.value = false;
                        controller.setVolume(SettingsManager().settings.startVideosMutedFullscreen.value ? 0 : 1);
                        chewieController = ChewieController(
                          videoPlayerController: controller,
                          aspectRatio: controller.value.aspectRatio,
                          allowFullScreen: false,
                          allowMuting: false,
                          materialProgressColors: ChewieProgressColors(
                              playedColor: Theme.of(context).primaryColor,
                              handleColor: Theme.of(context).primaryColor,
                              bufferedColor: Theme.of(context).backgroundColor,
                              backgroundColor: Theme.of(context).disabledColor),
                          cupertinoProgressColors: ChewieProgressColors(
                              playedColor: Theme.of(context).primaryColor,
                              handleColor: Theme.of(context).primaryColor,
                              bufferedColor: Theme.of(context).backgroundColor,
                              backgroundColor: Theme.of(context).disabledColor),
                        );
                        this.createListener(controller);
                        showPlayPauseOverlay = !controller.value.isPlaying;
                      }, onError: () {
                        Navigator.pop(context);
                      });
                      if (this.mounted) setState(() {});
                    },
                    child: Icon(
                      Icons.refresh,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 40.0),
                  child: CupertinoButton(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    onPressed: () async {
                      await AttachmentHelper.saveToGallery(context, widget.file);
                    },
                    child: Icon(
                      Icons.file_download,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 40.0),
                  child: CupertinoButton(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    onPressed: () async {
                      Share.file(
                        "Shared ${widget.attachment.mimeType!.split("/")[0]} from BlueBubbles: ${widget.attachment.transferName}",
                        widget.file.path,
                      );
                    },
                    child: Icon(
                      Icons.share,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 40.0),
                  child: CupertinoButton(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    onPressed: () async {
                      controller.setVolume(controller.value.volume != 0.0 ? 0.0 : 1.0);
                    },
                    child: Icon(
                      controller.value.volume == 0.0 ? Icons.volume_mute : Icons.volume_up,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ])),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        body: Listener(
          onPointerUp: (_) async {
            setState(() {
              showPlayPauseOverlay = true;
            });
            debounceOverlay();
          },
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              Obx(() {
                if (!isReloading.value && chewieController != null)
                  return SafeArea(
                    child: Center(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                            platform: SettingsManager().settings.skin.value == Skins.iOS ? TargetPlatform.iOS : TargetPlatform.android,
                            dialogBackgroundColor: Theme.of(context).accentColor,
                            iconTheme: Theme.of(context).iconTheme.copyWith(color: Theme.of(context).textTheme.bodyText1?.color)),
                        child: Chewie(
                          controller: chewieController!,
                        ),
                      ),
                    ),
                  );
                else return Center(
                  child: CircularProgressIndicator(
                    backgroundColor: Theme.of(context).accentColor,
                    valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
                  ),
                );
              }),
              if (widget.showInteractions)
                Positioned(
                  top: 0,
                  left: 0,
                  child: AbsorbPointer(
                      absorbing: !showPlayPauseOverlay,
                      child: overlay),
                ),
            ],
          )
        ),
      ),
    );
  }

  debounceOverlay() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      setState(() {
        showPlayPauseOverlay = false;
      });
    });
  }
}

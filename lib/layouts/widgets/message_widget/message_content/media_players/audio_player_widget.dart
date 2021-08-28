import 'dart:io';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:chewie_audio/chewie_audio.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';
import 'package:video_player/video_player.dart';

class AudioPlayerWidgetController extends GetxController {
  late final ChewieAudioController controller;
  late final VideoPlayerController audioController;
  final BuildContext context;
  final File file;
  final bool isFromMe;
  AudioPlayerWidgetController({
    required this.context,
    required this.file,
    required this.isFromMe,
  });
  
  @override
  void onInit() {
    CurrentChat? thisChat = CurrentChat.of(context);
    if (thisChat != null && thisChat.audioPlayers.containsKey(file.path)) {
      audioController = thisChat.audioPlayers[file.path]!.item2;
      controller = thisChat.audioPlayers[file.path]!.item1;
    } else {
      audioController = VideoPlayerController.file(
        file,
      );
      controller = ChewieAudioController(
        videoPlayerController: audioController,
        autoPlay: false,
        looping: true,
        showSeekButtons: false,
        showControls: true,
        autoInitialize: true,
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
        cupertinoBackgroundColor: Theme.of(context).accentColor,
        cupertinoIconColor: Theme.of(context).textTheme.bodyText1?.color,
        cupertinoColumnAlignment: isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      );

      thisChat = CurrentChat.of(context);
      if (thisChat != null) {
        CurrentChat.of(context)!.audioPlayers[file.path] = Tuple2(controller, audioController);
      }
    }
    super.onInit();
  }
}

class AudioPlayerWidget extends StatelessWidget {
  AudioPlayerWidget({
    Key? key,
    required this.file,
    this.isFromMe = false,
    this.width,
  }) : super(key: key);

  final File file;
  final double? width;
  final bool isFromMe;

  String formatDuration(Duration duration) {
    String minutes = duration.inMinutes.toString();
    int sec = (duration.inSeconds - (duration.inMinutes * 60));
    String seconds = sec.isNaN || sec.isNegative ? "0" : sec.toString();
    minutes = (minutes.length == 1) ? "0$minutes" : minutes;
    seconds = (seconds.length == 1) ? "0$seconds" : seconds;
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AudioPlayerWidgetController>(
      init: AudioPlayerWidgetController(
        context: context,
        file: file,
        isFromMe: isFromMe,
      ),
      global: false,
      builder: (controller) {
        double maxWidth = width ?? context.width - 20;
        if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
          controller.controller.pause();
        }
        return Container(
          alignment: Alignment.center,
          color: Theme.of(context).accentColor,
          height: SettingsManager().settings.skin.value == Skins.iOS ? 75 : 48,
          constraints: new BoxConstraints(maxWidth: maxWidth),
          child: Theme(
            data: Theme.of(context).copyWith(
                platform: SettingsManager().settings.skin.value == Skins.iOS ? TargetPlatform.iOS : TargetPlatform.android,
                dialogBackgroundColor: Theme.of(context).accentColor,
                iconTheme: Theme.of(context).iconTheme.copyWith(color: Theme.of(context).textTheme.bodyText1?.color)),
            child: ChewieAudio(
              controller: controller.controller,
            ),
          ),
        );
      }
    );
  }
}

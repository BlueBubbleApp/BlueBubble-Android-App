import 'dart:io';

import 'package:get/get.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:flutter/material.dart';

class AudioPlayerWiget extends StatefulWidget {
  AudioPlayerWiget({
    Key? key,
    required this.file,
    required this.context,
    this.width,
  }) : super(key: key);

  final File file;
  final BuildContext context;
  final double? width;

  @override
  _AudioPlayerWigetState createState() => _AudioPlayerWigetState();
}

class _AudioPlayerWigetState extends State<AudioPlayerWiget> {
  bool isPlaying = false;
  late Duration current;

  late AssetsAudioPlayer player;

  @override
  void initState() {
    super.initState();

    if (CurrentChat.of(widget.context)!.audioPlayers.containsKey(widget.file.path)) {
      player = CurrentChat.of(widget.context)!.audioPlayers[widget.file.path]!;
    } else {
      player = new AssetsAudioPlayer();
      player.open(Audio.file(widget.file.path), autoStart: false);
      CurrentChat.of(widget.context)!.audioPlayers[widget.file.path] = player;
    }

    isPlaying = player.isPlaying.hasValue ? player.isPlaying.value : false;
    current = player.currentPosition.hasValue ? player.currentPosition.value : Duration(seconds: 0);

    // Listen for when the audio is finished
    player.playlistFinished.listen((bool finished) async {
      // We only care if it's finished
      if (!finished) return;

      // Restart the clip
      player.open(Audio.file(widget.file.path), autoStart: false).catchError((err) {
        // Do nothing
      });

      // Set isPlaying and re-render
      isPlaying = false;
      if (this.mounted) setState(() {});
    });

    // Listen for new play status
    player.isPlaying.listen((bool playing) {
      // Update the state with the correct isPlaying bool
      isPlaying = playing;
      if (this.mounted) setState(() {});
    });

    // Update the current position if it's changed
    player.currentPosition.listen((Duration position) {
      if (position.inSeconds != current.inSeconds && this.mounted) {
        current = position;
        setState(() {});
      }
    });

    player.onReadyToPlay.listen((PlayingAudio? _) {
      if (this.mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  String formatDuration(Duration? duration) {
    if (duration == null) return "00:00";
    String minutes = duration.inMinutes.toString();
    int sec = (duration.inSeconds - (duration.inMinutes * 60));
    String seconds = sec.isNaN || sec.isNegative ? "0" : sec.toString();
    minutes = (minutes.length == 1) ? "0$minutes" : minutes;
    seconds = (seconds.length == 1) ? "0$seconds" : seconds;
    return "$minutes:$seconds";
  }

  void seekToSecond(int second) {
    Duration newDuration = Duration(seconds: second);
    player.seek(newDuration);
  }

  @override
  Widget build(BuildContext context) {
    Playing? playing = player.current.hasValue ? player.current.value : null;
    double maxWidth = widget.width ?? context.width * 3 / 4;

    double currentValue = current.inSeconds.toDouble();
    double maxValue = (playing?.audio.duration ?? current).inSeconds.toDouble();
    if (maxValue < currentValue) {
      maxValue = currentValue;
    }

    return Container(
      alignment: Alignment.center,
      color: Theme.of(context).accentColor,
      constraints: new BoxConstraints(maxWidth: maxWidth),
      child: GestureDetector(
        onTap: () async {
          if (!isPlaying && this.mounted) {
            setState(() {
              isPlaying = true;
            });
            await player.play();
          } else {
            await player.pause();
          }
        },
        child: Padding(
          padding: EdgeInsets.only(left: 15.0, top: 15.0, bottom: 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsets.only(right: 20.0),
                child: (playing == null)
                    ? Text("00:00 / 00:00", style: Theme.of(context).textTheme.bodyText1)
                    : Text(
                        (playing.audio.duration.inSeconds == 0)
                            ? formatDuration(current)
                            : "${formatDuration(current)} / ${formatDuration(playing.audio.duration)}",
                        style: Theme.of(context).textTheme.bodyText1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  (isPlaying)
                      ? Icon(
                          Icons.pause_circle_outline,
                          size: 50.0,
                          color: Theme.of(context).textTheme.subtitle1!.color,
                        )
                      : Icon(
                          Icons.play_circle_filled,
                          size: 50.0,
                          color: Theme.of(context).textTheme.subtitle1!.color,
                        ),
                  Flexible(
                    child: Slider(
                      activeColor: Theme.of(context).primaryColor,
                      inactiveColor: Theme.of(context).backgroundColor,
                      value: currentValue,
                      min: 0.0,
                      max: maxValue,
                      onChanged: (double value) {
                        setState(() {
                          seekToSecond(value.toInt());
                          value = value;
                        });
                      },
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

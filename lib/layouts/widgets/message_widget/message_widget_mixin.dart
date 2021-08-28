import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:faker/faker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class MessageWidgetHelper {
  static const double MAX_SIZE = 3 / 5;

  static List<InlineSpan> buildMessageSpans(BuildContext context, Message? message, {List<Color>? colors: const []}) {
    List<InlineSpan> textSpans = <InlineSpan>[];

    final bool generateContent =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeMessageContent.value;
    final bool hideContent = (message?.guid?.contains("theme-selector") ?? false) ||
        (SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideMessageContent.value && !generateContent);

    if (message != null && !isEmptyString(message.text)) {
      RegExp exp = new RegExp(
          r'((https?://)|(www\.))[-a-zA-Z0-9@:%._+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}([-a-zA-Z0-9/()@:%_.~#?&=*\[\]]*)\b');
      List<RegExpMatch> matches = exp.allMatches(message.text!).toList();

      List<int> linkIndexMatches = <int>[];
      matches.forEach((match) {
        linkIndexMatches.add(match.start);
        linkIndexMatches.add(match.end);
      });

      TextStyle? textStyle = Theme.of(context).textTheme.bodyText2;
      if (!message.isFromMe!) {
        if (SettingsManager().settings.colorfulBubbles.value) {
          if (!isNullOrEmpty(colors)!) {
            bool dark = colors![0].computeLuminance() < 0.179;
            if (!dark) {
              textStyle = Theme.of(context)
                  .textTheme
                  .bodyText2!
                  .apply(color: hideContent ? Colors.transparent : colors[0].darkenAmount(0.35));
            } else {
              textStyle = Theme.of(context).textTheme.bodyText2;
              if (hideContent) textStyle = textStyle!.apply(color: Colors.transparent);
            }
          } else {
            textStyle = Theme.of(context).textTheme.bodyText2!.apply(
                color: hideContent
                    ? Colors.transparent
                    : toColorGradient(message.handle?.address ?? "")[0].darkenAmount(0.35));
          }
        } else if (hideContent) textStyle = textStyle!.apply(color: Colors.transparent);
      } else {
        textStyle = textStyle!.apply(color: hideContent ? Colors.transparent : Colors.white);
      }

      if (!isNullOrEmpty(message.subject)!) {
        TextStyle _textStyle = message.isFromMe!
            ? textStyle!.apply(color: Colors.white, fontWeightDelta: 2)
            : textStyle!.apply(fontWeightDelta: 2);
        if (hideContent) {
          _textStyle = _textStyle.apply(color: Colors.transparent);
        }
        textSpans.add(
          TextSpan(
            text: "${message.subject}\n",
            style: _textStyle,
          ),
        );
      }

      if (linkIndexMatches.length > 0) {
        for (int i = 0; i < linkIndexMatches.length + 1; i++) {
          if (i == 0) {
            textSpans.add(
              TextSpan(
                text: message.text!.substring(0, linkIndexMatches[i]),
                style: textStyle,
              ),
            );
          } else if (i == linkIndexMatches.length && i - 1 >= 0) {
            textSpans.add(
              TextSpan(
                text: message.text!.substring(linkIndexMatches[i - 1], message.text!.length),
                style: textStyle,
              ),
            );
          } else if (i - 1 >= 0) {
            String text = message.text!.substring(linkIndexMatches[i - 1], linkIndexMatches[i]);
            if (exp.hasMatch(text)) {
              textSpans.add(
                TextSpan(
                  text: text,
                  recognizer: new TapGestureRecognizer()
                    ..onTap = () async {
                      String url = text;
                      if (!url.startsWith("http://") && !url.startsWith("https://")) {
                        url = "http://" + url;
                      }

                      MethodChannelInterface().invokeMethod("open-link", {"link": url, "forceBrowser": false});
                    },
                  style: textStyle!.apply(decoration: TextDecoration.underline),
                ),
              );
            } else {
              textSpans.add(
                TextSpan(
                  text: text,
                  style: textStyle,
                ),
              );
            }
          }
        }
      } else {
        textSpans.add(
          TextSpan(
            text: message.text,
            style: textStyle,
          ),
        );
      }

      if (generateContent) {
        String generatedText = faker.lorem.words(message.text!.split(" ").length).join(" ");
        return [TextSpan(text: generatedText, style: textStyle)];
      }
    }

    return textSpans;
  }
}

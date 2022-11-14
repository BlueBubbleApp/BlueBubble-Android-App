
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/game_pigeon.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview.legacy.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/text/text_bubble.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class InteractiveHolder extends CustomStateful<MessageWidgetController> {
  InteractiveHolder({
    Key? key,
    required super.parentController,
    required this.message,
  }) : super(key: key);

  final MessagePart message;

  @override
  _InteractiveHolderState createState() => _InteractiveHolderState();
}

class _InteractiveHolderState extends CustomState<InteractiveHolder, void, MessageWidgetController> {
  MessagePart get part => widget.message;
  Message get message => controller.message;
  PayloadData? get payloadData => message.payloadData;
  Message? get olderMessage => controller.oldMwc?.message;
  Message? get newerMessage => controller.newMwc?.message;

  @override
  void initState() {
    forceDelete = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final bool showTail = message.showTail(newerMessage) && part.part == controller.parts.length - 1;
    return ClipPath(
      clipper: TailClipper(
        isFromMe: message.isFromMe!,
        showTail: showTail,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: payloadData == null ? null : () async {
            String? url;
            if (payloadData!.type == PayloadType.url) {
              url = payloadData!.urlData!.first.url ?? payloadData!.urlData!.first.originalUrl;
            } else {
              url = payloadData!.appData!.first.url;
            }
            if (url != null && Uri.tryParse(url) != null) {
              await launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              );
            }
          },
          child: Ink(
            color: context.theme.colorScheme.properSurface,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ns.width(context) * 0.6,
                maxHeight: context.height * 0.6,
                minHeight: 40,
                minWidth: 40,
              ),
              child: Padding(
                padding: EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 150),
                  child: Center(
                    heightFactor: 1,
                    widthFactor: 1,
                    child: Opacity(
                      opacity: message.guid!.startsWith("temp") ? 0.5 : 1,
                      child: Builder(
                        builder: (context) {
                          if (payloadData == null && !(message.isLegacyUrlPreview)) {
                            return TextBubble(
                              parentController: controller,
                              message: part,
                            );
                          } else if (payloadData?.type == PayloadType.url || message.isLegacyUrlPreview) {
                            if (payloadData == null) {
                              return LegacyUrlPreview(
                                message: message,
                              );
                            }
                            return UrlPreview(
                              data: payloadData!.urlData!.first,
                              message: message,
                            );
                          } else {
                            final data = payloadData!.appData!.first;
                            switch (message.interactiveText) {
                              case "Youtube":
                              case "Photos":
                              case "OpenTable":
                              case "iMessage Poll":
                              case "GamePigeon":
                                return GamePigeon(
                                  data: data,
                                  message: message,
                                );
                              case "Shazam":
                                return UrlPreview(
                                  data: UrlPreviewData(
                                    originalUrl: data.url,
                                    url: data.url,
                                    title: data.userInfo?.caption,
                                    summary: data.userInfo?.subcaption,
                                    siteName: data.appName,
                                  ),
                                  message: message,
                                  customPreview: true,
                                );
                              case "Apple Pay":
                              case "Handwritten Message":
                              case "Digital Touch Message":
                              default:
                                return Container();
                            }
                          }
                        }
                      )
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

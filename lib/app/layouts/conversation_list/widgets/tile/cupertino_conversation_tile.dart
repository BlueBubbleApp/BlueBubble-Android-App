import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/dialogs/conversation_peek_view.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CupertinoConversationTile extends CustomStateful<ConversationTileController> {
  const CupertinoConversationTile({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _CupertinoConversationTileState();
}

class _CupertinoConversationTileState extends CustomState<CupertinoConversationTile, void, ConversationTileController> {
  Offset? longPressPosition;

  @override
  void initState() {
    super.initState();
    tag = controller.chatGuid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    final leading = ChatLeading(
      controller: controller,
      unreadIcon: UnreadIcon(parentController: controller),
    );
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: MouseCursor.defer,
        onTap: () => controller.onTap(context),
        onSecondaryTapUp: (details) => controller.onSecondaryTap(Get.context!, details),
        onLongPress: kIsDesktop || kIsWeb
            ? null
            : () async {
                await peekChat(context, controller.chatGuid, longPressPosition ?? Offset.zero);
              },
        onTapDown: (details) {
          longPressPosition = details.globalPosition;
        },
        child: Obx(() => ListTile(
            mouseCursor: MouseCursor.defer,
            enableFeedback: true,
            dense: ss.settings.denseChatTiles.value,
            contentPadding: const EdgeInsets.only(left: 0),
            visualDensity: ss.settings.denseChatTiles.value ? VisualDensity.compact : null,
            minVerticalPadding: ss.settings.denseChatTiles.value ? 7.5 : 10,
            horizontalTitleGap: 10,
            title: Row(
              children: [
                Expanded(
                  child: ChatTitle(
                    parentController: controller,
                    style: context.theme.textTheme.bodyLarge!.copyWith(
                        fontWeight: controller.shouldHighlight.value ? FontWeight.w600 : FontWeight.w500,
                        color: controller.shouldHighlight.value ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage) : null),
                  ),
                ),
                CupertinoTrailing(parentController: controller),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: controller.subtitle ??
                  ChatSubtitle(
                    parentController: controller,
                    style: context.theme.textTheme.bodyMedium!.copyWith(
                      color: controller.shouldHighlight.value
                          ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage).withOpacity(0.85)
                          : context.theme.colorScheme.outline,
                      height: 1.5,
                    ),
                  ),
            ),
            leading: leading)),
      ),
    );

    return Obx(() {
      ns.listener.value;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: controller.shouldPartialHighlight.value
              ? context.theme.colorScheme.properSurface.lightenOrDarken(10)
              : controller.shouldHighlight.value
                  ? context.theme.colorScheme.bubble(context, controller.chat.isIMessage)
                  : controller.hoverHighlight.value
                      ? context.theme.colorScheme.properSurface.withOpacity(0.5)
                      : null,
          borderRadius: BorderRadius.circular(
              controller.shouldHighlight.value || controller.shouldPartialHighlight.value || controller.hoverHighlight.value ? 8 : 0),
        ),
        child: ns.isAvatarOnly(context)
            ? InkWell(
                mouseCursor: MouseCursor.defer,
                onTap: () => controller.onTap(context),
                onSecondaryTapUp: (details) => controller.onSecondaryTap(Get.context!, details),
                onLongPress: kIsDesktop || kIsWeb
                    ? null
                    : () async {
                        await peekChat(context, controller.chatGuid, longPressPosition ?? Offset.zero);
                      },
                onTapDown: (details) {
                  longPressPosition = details.globalPosition;
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: (ns.width(context) - 100) / 2).add(const EdgeInsets.only(right: 15)),
                  child: leading,
                ),
              )
            : child,
      );
    });
  }
}

class CupertinoTrailing extends CustomStateful<ConversationTileController> {
  const CupertinoTrailing({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _CupertinoTrailingState();
}

class _CupertinoTrailingState extends CustomState<CupertinoTrailing, void, ConversationTileController> {

  @override
  void initState() {
    super.initState();
    tag = controller.chatGuid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Obx(() {
            String indicatorText = "";
            final latestMessage = controller.chat.observables.latestMessage.value;
            final dateCreated = latestMessage?.dateCreated ?? DateTime.now();
            if (ss.settings.statusIndicatorsOnChats.value && (latestMessage?.isFromMe ?? false) && !controller.chat.isGroup) {
              Indicator show = latestMessage?.indicatorToShow ?? Indicator.NONE;
              if (show != Indicator.NONE) {
                indicatorText = show.name.toLowerCase().capitalizeFirst!;
              }
            }

            return Text(
              (latestMessage?.error ?? 0) > 0
                  ? "Error"
                  : "${indicatorText.isNotEmpty && indicatorText != "None" ? "$indicatorText\n" : ""}${buildDate(dateCreated)}",
              textAlign: TextAlign.right,
              style: context.theme.textTheme.bodySmall!
                  .copyWith(
                    color: (latestMessage?.error ?? 0) > 0
                        ? context.theme.colorScheme.error
                        : controller.shouldHighlight.value
                            ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage)
                            : context.theme.colorScheme.outline,
                    fontWeight: controller.shouldHighlight.value ? FontWeight.w500 : null,
                  )
                  .apply(fontSizeFactor: 1.1),
              overflow: TextOverflow.clip,
            );
          }),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.forward,
                color: controller.shouldHighlight.value
                    ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage)
                    : context.theme.colorScheme.outline,
                size: 15,
              ),
              if (controller.chat.muteType == "mute")
                Padding(
                    padding: const EdgeInsets.only(top: 5.0),
                    child: Icon(
                      CupertinoIcons.bell_slash_fill,
                      color: controller.shouldHighlight.value
                          ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage)
                          : context.theme.colorScheme.outline,
                      size: 12,
                    ))
            ],
          ),
        ],
      ),
    );
  }
}

class UnreadIcon extends CustomStateful<ConversationTileController> {
  const UnreadIcon({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _UnreadIconState();
}

class _UnreadIconState extends CustomState<UnreadIcon, void, ConversationTileController> {

  @override
  void initState() {
    super.initState();
    tag = controller.chatGuid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0, right: 5.0),
      child: Obx(() => controller.chat.observables.isUnread.value 
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(35),
                color: context.theme.colorScheme.primary,
              ),
              width: 10,
              height: 10,
            )
          : const SizedBox(width: 10),
      )
    );
  }
}

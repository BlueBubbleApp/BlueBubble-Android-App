import 'dart:async';
import 'dart:ui';

import 'package:bluebubbles/app/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/header_widgets.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:gesture_x_detector/gesture_x_detector.dart';
import 'package:flutter/material.dart' hide BackButton;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class CupertinoHeader extends StatelessWidget implements PreferredSizeWidget {
  const CupertinoHeader({Key? key, required this.controller});

  final ConversationViewController controller;

  Chat get chat => GlobalChatService.getChat(controller.chatGuid)!.chat;

  // simulate apple's saturatioon
  static const List<double> darkMatrix = <double>[
    1.385, -0.56, -0.112, 0.0, 0.3, //
    -0.315, 1.14, -0.112, 0.0, 0.3, //
    -0.315, -0.56, 1.588, 0.0, 0.3, //
    0.0, 0.0, 0.0, 1.0, 0.0
  ];

  static const List<double> lightMatrix = <double>[
    1.74, -0.4, -0.17, 0.0, 0.0, //
    -0.26, 1.6, -0.17, 0.0, 0.0, //
    -0.26, -0.4, 1.83, 0.0, 0.0, //
    0.0, 0.0, 0.0, 1.0, 0.0
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
          filter: ImageFilter.compose(
              outer: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              inner: ColorFilter.matrix(
                CupertinoTheme.maybeBrightnessOf(context) == Brightness.dark ? darkMatrix : lightMatrix,
              )),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.properSurface.withOpacity(0.7),
                  border: Border(
                    bottom: BorderSide(color: context.theme.colorScheme.properSurface.darkenAmount(0.25), width: 0.5),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: EdgeInsets.only(
                        left: 20.0,
                        right: 20,
                        top: (MediaQuery.of(context).viewPadding.top - 2).clamp(0, double.infinity)),
                    child: Stack(alignment: Alignment.center, children: [
                      Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: XGestureDetector(
                              supportTouch: true,
                              onTap: !kIsDesktop
                                  ? null
                                  : (details) {
                                      if (controller.inSelectMode.value) {
                                        controller.inSelectMode.value = false;
                                        controller.selected.clear();
                                        return;
                                      }
                                      if (ls.isBubble) {
                                        SystemNavigator.pop();
                                        return;
                                      }
                                      controller.close();
                                      if (Get.isSnackbarOpen) {
                                        Get.closeAllSnackbars();
                                      }
                                      Navigator.of(context).pop();
                                    },
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  if (kIsDesktop) return;
                                  if (controller.inSelectMode.value) {
                                    controller.inSelectMode.value = false;
                                    controller.selected.clear();
                                    return;
                                  }
                                  if (ls.isBubble) {
                                    SystemNavigator.pop();
                                    return;
                                  }
                                  controller.close();
                                  if (Get.isSnackbarOpen) {
                                    Get.closeAllSnackbars();
                                  }
                                  Navigator.of(context).pop();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(3.0),
                                  child: _UnreadIcon(controller: controller),
                                ),
                              ),
                            ),
                          )),
                      Align(
                        alignment: Alignment.center,
                        child: XGestureDetector(
                          supportTouch: true,
                          onTap: !kIsDesktop
                              ? null
                              : (details) {
                                  Navigator.of(context).push(
                                    ThemeSwitcher.buildPageRoute(
                                      builder: (context) => ConversationDetails(
                                        chatGuid: chat.guid,
                                      ),
                                    ),
                                  );
                                },
                          child: InkWell(
                            onTap: () {
                              if (kIsDesktop) return;
                              Navigator.of(context).push(
                                ThemeSwitcher.buildPageRoute(
                                  builder: (context) => ConversationDetails(
                                    chatGuid: chat.guid,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(3.0),
                              child: _ChatIconAndTitle(parentController: controller),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Align(alignment: Alignment.topRight, child: ManualMark(controller: controller))),
                    ]),
                  ),
                ),
              ),
              Positioned(
                child: Obx(() {
                  final rChat = GlobalChatService.getChat(controller.chatGuid)!;
                  return TweenAnimationBuilder<double>(
                    duration: rChat.sendProgress.value == 0
                        ? Duration.zero
                        : rChat.sendProgress.value == 1
                            ? const Duration(milliseconds: 250)
                            : const Duration(seconds: 10),
                    curve: rChat.sendProgress.value == 1 ? Curves.easeInOut : Curves.easeOutExpo,
                    tween: Tween<double>(
                      begin: 0,
                      end: rChat.sendProgress.value,
                    ),
                    builder: (context, value, _) => AnimatedOpacity(
                          opacity: value == 1 ? 0 : 1,
                          duration: const Duration(milliseconds: 250),
                          child: LinearProgressIndicator(
                            value: value,
                            backgroundColor: Colors.transparent,
                            minHeight: 3,
                          ),
                        )
                  );
                }),
                bottom: 0,
                left: 0,
                right: 0,
              ),
            ],
          )),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight((Get.context!.orientation == Orientation.landscape && Platform.isAndroid ? 55 : 75) *
          ss.settings.avatarScale.value);
}

class _UnreadIcon extends StatefulWidget {
  const _UnreadIcon({required this.controller});

  final ConversationViewController controller;

  @override
  State<StatefulWidget> createState() => _UnreadIconState();
}

class _UnreadIconState extends OptimizedState<_UnreadIcon> {
  late final StreamSubscription<Query<Chat>> sub;
  bool hasStream = false;

  @override
  void dispose() {
    if (!kIsWeb && hasStream) sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3.0, right: 3),
          child: Obx(() {
            final icon = widget.controller.inSelectMode.value ? CupertinoIcons.xmark : CupertinoIcons.back;
            return Text(
              String.fromCharCode(icon.codePoint),
              style: TextStyle(
                fontFamily: icon.fontFamily,
                package: icon.fontPackage,
                fontSize: 36,
                color: context.theme.colorScheme.primary,
              ),
            );
          }),
        ),
        const SizedBox(width: 2),
        Obx(() {
          final _count = widget.controller.inSelectMode.value ? widget.controller.selected.length : GlobalChatService.unreadCount.value;
          if (_count == 0) return const SizedBox.shrink();
          return Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                  height: 25.0,
                  width: 25.0,
                  constraints: const BoxConstraints(minWidth: 20),
                  decoration: BoxDecoration(
                    color: context.theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: Padding(
                    padding: _count > 99 ? const EdgeInsets.symmetric(horizontal: 2.5) : EdgeInsets.zero,
                    child: Text(
                      _count.toString(),
                      style: context.textTheme.bodyMedium!.copyWith(
                          color: context.theme.colorScheme.onPrimary,
                          fontSize: _count > 99
                              ? context.textTheme.bodyMedium!.fontSize! - 1.0
                              : context.textTheme.bodyMedium!.fontSize),
                    ),
                  )));
        }),
      ],
    );
  }
}

class _ChatIconAndTitle extends CustomStateful<ConversationViewController> {
  const _ChatIconAndTitle({required super.parentController});

  @override
  State<StatefulWidget> createState() => _ChatIconAndTitleState();
}

class _ChatIconAndTitleState extends CustomState<_ChatIconAndTitle, void, ConversationViewController> {

  Chat get chat => GlobalChatService.getChat(controller.chatGuid)!.chat;

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
    final children = [
      IgnorePointer(
        ignoring: true,
        child: ContactAvatarGroupWidget(
          chatGuid: chat.guid,
          size: 54,
        ),
      ),
      const SizedBox(height: 5, width: 5),
      Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ns.width(context) / 2.5,
          ),
          child: Obx(() {
            final hideInfo = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
            String title = controller.reactiveChat.title.value ?? "";
            if (hideInfo) {
              title = chat.participants.length > 1 ? "Group Chat" : chat.participants[0].fakeName;
            }

            return RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              text: TextSpan(
                style: context.theme.textTheme.bodyMedium,
                children: MessageHelper.buildEmojiText(
                  title,
                  context.theme.textTheme.bodyMedium!,
                ),
              ),
            );
          })
        ),
        Icon(
          CupertinoIcons.chevron_right,
          size: context.theme.textTheme.bodyMedium!.fontSize!,
          color: context.theme.colorScheme.outline,
        ),
      ]),
    ];

    if (context.orientation == Orientation.landscape && Platform.isAndroid) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }
  }
}

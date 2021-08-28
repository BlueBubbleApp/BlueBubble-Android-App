import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ContactAvatarGroupWidget extends StatelessWidget {
  ContactAvatarGroupWidget({Key? key, this.size = 40, this.editable = true, this.onTap, required this.chat})
      : super(key: key) {
    participants = RxList<Handle>(chat.participants);
    participants.sort((a, b) {
      bool avatarA = ContactManager().getCachedContactSync(a.address)?.avatar?.isNotEmpty ?? false;
      bool avatarB = ContactManager().getCachedContactSync(b.address)?.avatar?.isNotEmpty ?? false;
      if (!avatarA && avatarB) return 1;
      if (avatarA && !avatarB) return -1;
      return 0;
    });
  }
  final Chat chat;
  final double size;
  final bool editable;
  final Function()? onTap;
  late final RxList<Handle> participants;

  @override
  Widget build(BuildContext context) {
    if (participants.length == 0) {
      return Container(
        width: size,
        height: size,
      );
    }

    return Obx(
      () {
        if (chat.customAvatarPath.value != null) {
          return Stack(
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size / 2),
                ),
              ),
              CircleAvatar(
                key: Key("${participants.first.address}-avatar"),
                radius: size / 2,
                backgroundImage: FileImage(File(chat.customAvatarPath.value!)),
                backgroundColor: Colors.transparent,
              ),
            ]
          );
        }

        int maxAvatars = SettingsManager().settings.maxAvatarsInGroupWidget.value;

        return Container(
          width: size,
          height: size,
          child: participants.length > 1
              ? ThemeSwitcher(
                  iOSSkin: Stack(
                    children: [
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(size / 2),
                          color: context.theme.accentColor.withOpacity(0.6),
                        ),
                      ),
                      ...List.generate(
                        min(participants.length, maxAvatars),
                        (index) {
                          // Trig really paying off here
                          int realLength = min(participants.length, maxAvatars);
                          double padding = size * 0.08;
                          double angle = index / realLength * 2 * pi + pi / 4;
                          double adjustedWidth = size * (-0.07 * realLength + 1);
                          double innerRadius = size - adjustedWidth / 2 - 2 * padding;
                          double size2 = adjustedWidth * 0.65;
                          double top = (size / 2) + (innerRadius / 2) * sin(angle + pi) - size2 / 2;
                          double right = (size / 2) + (innerRadius / 2) * cos(angle + pi) - size2 / 2;
                          if (index == maxAvatars - 1 && participants.length > maxAvatars) {
                            return Positioned(
                              top: top,
                              right: right,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(size2),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 2,
                                    sigmaY: 2,
                                  ),
                                  child: Container(
                                    width: size2,
                                    height: size2,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(size2),
                                      color: context.theme.accentColor.withOpacity(0.8),
                                    ),
                                    child: Icon(
                                      Icons.people,
                                      size: size2 * 0.65,
                                      color: context.textTheme.subtitle1!.color!.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return Positioned(
                            top: top,
                            right: right,
                            child: ContactAvatarWidget(
                              key: Key("${participants[index].address}-contact-avatar-group-widget"),
                              handle: participants[index],
                              size: size2,
                              borderThickness: size * 0.01,
                              fontSize: adjustedWidth * 0.3,
                              editable: false,
                              onTap: onTap,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  materialSkin: Builder(
                    builder: (context) {
                      if (participants.length == 2) {
                        return Stack(
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: ContactAvatarWidget(
                                handle: participants[0],
                                size: 24.5,
                                fontSize: 10.5,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: ContactAvatarWidget(
                                handle: participants[1],
                                size: 24.5,
                                fontSize: 10.5,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                          ],
                        );
                      } else if (participants.length == 3) {
                        return Stack(
                          children: [
                            Align(
                              alignment: Alignment.bottomRight,
                              child: ContactAvatarWidget(
                                handle: participants[0],
                                size: 21.5,
                                fontSize: 9,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: ContactAvatarWidget(
                                handle: participants[1],
                                size: 21.5,
                                fontSize: 9,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                            Align(
                              alignment: Alignment.topCenter,
                              child: ContactAvatarWidget(
                                handle: participants[2],
                                size: 21.5,
                                fontSize: 9,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Stack(
                          children: [
                            Align(
                              alignment: Alignment.bottomRight,
                              child: ContactAvatarWidget(
                                handle: participants[0],
                                size: 20,
                                fontSize: 8.7,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: ContactAvatarWidget(
                                handle: participants[1],
                                size: 20,
                                fontSize: 8.7,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                            Align(
                              alignment: Alignment.topLeft,
                              child: ContactAvatarWidget(
                                handle: participants[2],
                                size: 20,
                                fontSize: 8.7,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: ContactAvatarWidget(
                                handle: participants[3],
                                size: 20,
                                fontSize: 8.7,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  samsungSkin: Builder(
                    builder: (context) {
                      if (participants.length == 2) {
                        return Stack(
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: ContactAvatarWidget(
                                handle: participants[0],
                                size: 24.5,
                                fontSize: 10.5,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: ContactAvatarWidget(
                                handle: participants[1],
                                size: 24.5,
                                fontSize: 10.5,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                          ],
                        );
                      } else if (participants.length == 3) {
                        return Stack(
                          children: [
                            Align(
                              alignment: Alignment.bottomRight,
                              child: ContactAvatarWidget(
                                handle: participants[0],
                                size: 21.5,
                                fontSize: 9,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: ContactAvatarWidget(
                                handle: participants[1],
                                size: 21.5,
                                fontSize: 9,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                            Align(
                              alignment: Alignment.topCenter,
                              child: ContactAvatarWidget(
                                handle: participants[2],
                                size: 21.5,
                                fontSize: 9,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Stack(
                          children: [
                            Align(
                              alignment: Alignment.bottomRight,
                              child: ContactAvatarWidget(
                                handle: participants[0],
                                size: 20,
                                fontSize: 8.7,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: ContactAvatarWidget(
                                handle: participants[1],
                                size: 20,
                                fontSize: 8.7,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                            Align(
                              alignment: Alignment.topLeft,
                              child: ContactAvatarWidget(
                                handle: participants[2],
                                size: 20,
                                fontSize: 8.7,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: ContactAvatarWidget(
                                handle: participants[3],
                                size: 20,
                                fontSize: 8.7,
                                editable: editable,
                                onTap: onTap,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                )
              : ContactAvatarWidget(
                  handle: participants.first,
                  borderThickness: 0.1,
                  size: size,
                  fontSize: size * 0.5,
                  editable: editable,
                  onTap: onTap,
                ),
        );
      },
    );
  }
}

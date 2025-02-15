import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_attachments/conversation_attachments.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/add_participant.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/chat_info.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/chat_options.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/attachments_title.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/media_gallery_card.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/contact_tile.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/* Max number of previews to show for each attachment type on the conversation_details page */
const maxAttachmentPreviews = 6;

class ConversationDetails extends StatefulWidget {
  final Chat chat;

  ConversationDetails({super.key, required this.chat});

  @override
  State<ConversationDetails> createState() => _ConversationDetailsState();
}

class _ConversationDetailsState extends OptimizedState<ConversationDetails> with WidgetsBindingObserver {
  List<Attachment> media = <Attachment>[];
  List<Attachment> docs = <Attachment>[];
  List<Attachment> locations = <Attachment>[];
  List<Message> links = [];
  bool showMoreParticipants = false;
  late Chat chat = widget.chat;
  late StreamSubscription sub;
  final RxList<String> selected = <String>[].obs;

  bool get shouldShowMore => chat.participants.length > 5;
  List<Handle> get clippedParticipants => showMoreParticipants
      ? chat.participants
      : chat.participants.take(5).toList();

  @override
  void initState() {
    super.initState();

    cm.setActiveToDead();

    if (!kIsWeb) {
      final chatQuery = Database.chats.query(Chat_.guid.equals(chat.guid)).watch();
      sub = chatQuery.listen((Query<Chat> query) async {
        final _chat = await runAsync(() {
          return Database.chats.get(chat.id!);
        });
        if (_chat != null) {
          final update = _chat.getTitle() != chat.title || _chat.participants.length != chat.participants.length;
          chat = _chat.merge(chat);
          if (update) {
            setState(() {});
          }
        }
      });
    } else {
      sub = WebListeners.chatUpdate.listen((_chat) {
        final update = _chat.getTitle() != chat.title || _chat.participants.length != chat.participants.length;
        chat = _chat.merge(chat);
        if (update) {
          setState(() {});
        }
      });
    }

    if (!kIsWeb) {
      updateObx(() {
        fetchAttachments();
        fetchLinks();
      });
    }
  }

  @override
  void dispose() {
    sub.cancel();
    if (cm.activeChat != null) {
      cm.setActiveToAlive();
      cvc(cm.activeChat!.chat).lastFocusedNode.requestFocus();
    }
    super.dispose();
  }

  void fetchAttachments() {
    if (kIsWeb) return;
    chat.getAttachmentsAsync().then((value) {
      final _media = value.where((e) => !(e.message.target?.isGroupEvent ?? true)
          && !(e.message.target?.isInteractive ?? true)
          && (e.mimeStart == "image" || e.mimeStart == "video"));
      final _docs = value.where((e) => !(e.message.target?.isGroupEvent ?? true)
          && !(e.message.target?.isInteractive ?? true)
          && e.mimeStart != "image" && e.mimeStart != "video" && !(e.mimeType ?? "").contains("location"));
      final _locations = value.where((e) => (e.mimeType ?? "").contains("location"));
      for (Attachment a in _media) {
        a.message.target?.handle = chat.participants.firstWhereOrNull((e) => e.originalROWID == a.message.target?.handleId);
      }
      for (Attachment a in _docs) {
        a.message.target?.handle = chat.participants.firstWhereOrNull((e) => e.originalROWID == a.message.target?.handleId);
      }
      for (Attachment a in _locations) {
        a.message.target?.handle = chat.participants.firstWhereOrNull((e) => e.originalROWID == a.message.target?.handleId);
      }
      setState(() {
        media = _media.toList();
        docs = _docs.toList();
        locations = _locations.toList();
      });
    });
  }

  void fetchLinks() {
    final query = (Database.messages.query(Message_.dateDeleted.isNull()
      & Message_.dbPayloadData.notNull()
      & Message_.balloonBundleId.contains("URLBalloonProvider"))
      ..link(Message_.chat, Chat_.id.equals(chat.id!))
      ..order(Message_.dateCreated, flags: Order.descending))
        .build();
    query.limit = 20;
    links = query.find();
    query.close();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Theme(
        data: context.theme.copyWith(
          // in case some components still use legacy theming
          primaryColor: context.theme.colorScheme.bubble(context, chat.isIMessage),
          colorScheme: context.theme.colorScheme.copyWith(
            primary: context.theme.colorScheme.bubble(context, chat.isIMessage),
            onPrimary: context.theme.colorScheme.onBubble(context, chat.isIMessage),
            surface: ss.settings.monetTheming.value == Monet.full
                ? null
                : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
            onSurface: ss.settings.monetTheming.value == Monet.full
                ? null
                : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
          ),
        ),
        child: Obx(() => SettingsScaffold(
          headerColor: headerColor,
          title: "Details",
          tileColor: tileColor,
          initialHeader: null,
          iosSubtitle: iosSubtitle,
          materialSubtitle: materialSubtitle,
          actions: [
            Obx(() {
              if (selected.isNotEmpty) {
                return IconButton(
                  icon: Icon(iOS ? CupertinoIcons.xmark : Icons.close, color: context.theme.colorScheme.onBackground),
                  onPressed: () {
                    selected.clear();
                  },
                );
              } else {
                return const SizedBox.shrink();
              }
            }),
            Obx(() {
              if (selected.isNotEmpty) {
                return IconButton(
                  icon: Icon(iOS ? CupertinoIcons.cloud_download : Icons.file_download, color: context.theme.colorScheme.onBackground),
                  onPressed: () {
                    final attachments = media.where((e) => selected.contains(e.guid!));
                    for (Attachment a in attachments) {
                      final file = as.getContent(a, autoDownload: false);
                      if (file is PlatformFile) {
                        as.saveToDisk(file);
                      }
                    }
                  },
                );
              } else {
                return const SizedBox.shrink();
              }
            }),
          ],
          bodySlivers: [
            SliverToBoxAdapter(
              child: ChatInfo(chat: chat),
            ),
            if (chat.isGroup)
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final addMember = ListTile(
                    mouseCursor: MouseCursor.defer,
                    title: Text("Add ${iOS ? "Member" : "people"}", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                    leading: Container(
                      width: 40 * ss.settings.avatarScale.value,
                      height: 40 * ss.settings.avatarScale.value,
                      decoration: BoxDecoration(
                        color: !iOS ? null : context.theme.colorScheme.properSurface,
                        shape: BoxShape.circle,
                        border: iOS ? null : Border.all(color: context.theme.colorScheme.primary, width: 3)
                      ),
                      child: Icon(
                        Icons.add,
                        color: context.theme.colorScheme.primary,
                        size: 20
                      ),
                    ),
                    onTap: () {
                      showAddParticipant(context, chat);
                    },
                  );

                  if (index > clippedParticipants.length) {
                    if (ss.settings.enablePrivateAPI.value && chat.isIMessage && chat.isGroup && shouldShowMore) {
                      return addMember;
                    } else {
                      return const SizedBox.shrink();
                    }
                  }
                  if (index == clippedParticipants.length) {
                    if (shouldShowMore) {
                      return ListTile(
                        mouseCursor: SystemMouseCursors.click,
                        onTap: () {
                          setState(() {
                            showMoreParticipants = !showMoreParticipants;
                          });
                        },
                        title: Text(
                          showMoreParticipants ? "Show less" : "Show more",
                          style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary),
                        ),
                        leading: Container(
                          width: 40 * ss.settings.avatarScale.value,
                          height: 40 * ss.settings.avatarScale.value,
                          decoration: BoxDecoration(
                              color: !iOS ? null : context.theme.colorScheme.properSurface,
                              shape: BoxShape.circle,
                              border: iOS ? null : Border.all(color: context.theme.colorScheme.primary, width: 3)
                          ),
                          child: Icon(
                            Icons.more_horiz,
                            color: context.theme.colorScheme.primary,
                            size: 20
                          ),
                        ),
                      );
                    } else if (ss.settings.enablePrivateAPI.value && chat.isIMessage && chat.isGroup) {
                      return addMember;
                    } else {
                      return const SizedBox.shrink();
                    }
                  }

                  return ContactTile(
                    key: Key(chat.participants[index].address),
                    handle: chat.participants[index],
                    chat: chat,
                    canBeRemoved: chat.isGroup
                        && ss.settings.enablePrivateAPI.value
                        && chat.isIMessage,
                  );
                }, childCount: clippedParticipants.length + 2),
              ),
            if (chat.participants.length > 2 && ss.settings.enablePrivateAPI.value && ss.serverDetailsSync().item4 >= 226)
              SliverToBoxAdapter(
                child: Builder(
                  builder: (context) {
                    return ListTile(
                      mouseCursor: MouseCursor.defer,
                      title: Text("Leave ${iOS ? "Chat" : "chat"}", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.error)),
                      leading: Container(
                        width: 40 * ss.settings.avatarScale.value,
                        height: 40 * ss.settings.avatarScale.value,
                        decoration: BoxDecoration(
                          color: !iOS ? null : context.theme.colorScheme.properSurface,
                          shape: BoxShape.circle,
                          border: iOS ? null : Border.all(color: context.theme.colorScheme.error, width: 3)
                        ),
                        child: Icon(
                          Icons.error_outline,
                          color: context.theme.colorScheme.error,
                          size: 20
                        ),
                      ),
                      onTap: () async {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: context.theme.colorScheme.properSurface,
                              title: Text(
                                "Leaving chat...",
                                style: context.theme.textTheme.titleLarge,
                              ),
                              content: Container(
                                height: 70,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    backgroundColor: context.theme.colorScheme.properSurface,
                                    valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                                  ),
                                ),
                              ),
                            );
                          }
                        );
                        final response = await http.leaveChat(chat.guid);
                        if (response.statusCode == 200) {
                          Get.back();
                          showSnackbar("Notice", "Left chat successfully!");
                        } else {
                          Get.back();
                          showSnackbar("Error", "Failed to leave chat!");
                        }
                      },
                    );
                  }
                ),
              ),
            const SliverPadding(
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            ChatOptions(chat: chat),
            if (!kIsWeb && media.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(top: 20, bottom: 0, left: 15),
                sliver: SliverToBoxAdapter(
                  child: AttachmentsTitle(
                    title: "PHOTOS & VIDEOS",
                    attachmentsType: AttachmentTypes.media,
                    attachments: media,
                    chat: chat,
                  ),
                ),
              ),
            if (!kIsWeb && media.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(top: 0, bottom: 10, left: 10, right: 10),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: max(2, ns.width(context) ~/ 200),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, int index) {
                      return Obx(() => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: EdgeInsets.all(selected.contains(media[index].guid) ? 10 : 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: GestureDetector(
                          onTap: selected.isNotEmpty ? () {
                            if (selected.contains(media[index].guid)) {
                              selected.remove(media[index].guid!);
                            } else {
                              selected.add(media[index].guid!);
                            }
                          } : null,
                          onLongPress: () {
                            if (selected.contains(media[index].guid)) {
                              selected.remove(media[index].guid!);
                            } else {
                              selected.add(media[index].guid!);
                            }
                          },
                          child: AbsorbPointer(
                            absorbing: selected.isNotEmpty,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                MediaGalleryCard(
                                  attachment: media[index],
                                ),
                                if (selected.contains(media[index].guid))
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: context.theme.colorScheme.primary
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(5.0),
                                      child: Icon(
                                        iOS ? CupertinoIcons.check_mark : Icons.check,
                                        color: context.theme.colorScheme.onPrimary,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ));
                    },
                    childCount: min(maxAttachmentPreviews, media.length),
                  ),
                ),
              ),
            if (!kIsWeb && links.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(top: 20, bottom: 0, left: 15),
                sliver: SliverToBoxAdapter(
                  child: AttachmentsTitle(
                    title: "LINKS",
                    attachmentsType: AttachmentTypes.links,
                    links : links,
                    chat: chat,
                  ),
                ),
              ),
            if (!kIsWeb && links.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(top: 0, bottom: 10, left: 10, right: 10),
                sliver: SliverToBoxAdapter(
                  child: MasonryGridView.count(
                    crossAxisCount: max(2, ns.width(context) ~/ 200),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      if (links[index].payloadData?.urlData?.firstOrNull == null) {
                        return const Text("Failed to load link!");
                      }
                      return Material(
                        color: context.theme.colorScheme.properSurface,
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            final data = links[index].payloadData!.urlData!.first;
                            if ((data.url ?? data.originalUrl) == null) return;
                            await launchUrl(
                                Uri.parse((data.url ?? data.originalUrl)!),
                                mode: LaunchMode.externalApplication
                            );
                          },
                          child: Center(
                            child: UrlPreview(
                              data: links[index].payloadData!.urlData!.first,
                              message: links[index],
                            ),
                          ),
                        ),
                      );
                    },
                    itemCount: min(maxAttachmentPreviews, links.length),
                  ),
                ),
              ),
            if (!kIsWeb && locations.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(top: 20, bottom: 0, left: 15),
                sliver: SliverToBoxAdapter(
                  child: AttachmentsTitle(
                    title: "LOCATIONS",
                    attachmentsType: AttachmentTypes.locations,
                    attachments: locations,
                    links : links,
                    chat: chat,
                  ),
                ),
              ),
            if (!kIsWeb && locations.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(top: 0, bottom: 10, left: 10, right: 10),
                sliver: SliverToBoxAdapter(
                  child: MasonryGridView.count(
                    crossAxisCount: max(2, ns.width(context) ~/ 200),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      if (as.getContent(locations[index]) is! PlatformFile) {
                        return const Text("Failed to load location!");
                      }
                      return Material(
                        color: context.theme.colorScheme.properSurface,
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            final data = links[index].payloadData!.urlData!.first;
                            if ((data.url ?? data.originalUrl) == null) return;
                            await launchUrl(
                                Uri.parse((data.url ?? data.originalUrl)!),
                                mode: LaunchMode.externalApplication
                            );
                          },
                          child: Center(
                            child: UrlPreview(
                              data: UrlPreviewData(
                                title: "Location from ${DateFormat.yMd().format(locations[index].message.target!.dateCreated!)}",
                                siteName: "Tap to open",
                              ),
                              message: locations[index].message.target!,
                              file: as.getContent(locations[index]),
                            ),
                          ),
                        ),
                      );
                    },
                    itemCount: min(maxAttachmentPreviews, locations.length),
                  ),
                ),
              ),
            if (!kIsWeb && docs.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(top: 20, bottom: 0, left: 15),
                sliver: SliverToBoxAdapter(
                  child: AttachmentsTitle(
                    title: "OTHER FILES",
                    attachmentsType: AttachmentTypes.documents,
                    attachments: docs,
                    chat: chat,
                  ),
                ),
              ),
            if (!kIsWeb && docs.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(top: 0, bottom: 10, left: 10, right: 10),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: max(2, ns.width(context) ~/ 200),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.75,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, int index) {
                      return MediaGalleryCard(
                        attachment: docs[index],
                      );
                    },
                    childCount: min(maxAttachmentPreviews, docs.length),
                  ),
                ),
              ),
            const SliverPadding(
              padding: EdgeInsets.only(top: 50),
            ),
          ],
        ))
      ),
    );
  }
}

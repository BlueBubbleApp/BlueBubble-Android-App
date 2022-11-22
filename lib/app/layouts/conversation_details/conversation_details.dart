import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_details/dialogs/add_participant.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/chat_info.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/chat_options.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/media_gallery_card.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/contact_tile.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ConversationDetails extends StatefulWidget {
  final Chat chat;

  ConversationDetails({Key? key, required this.chat}) : super(key: key);

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
  late StreamSubscription<Query<Chat>> sub;

  bool get shouldShowMore => chat.participants.length > 5;
  List<Handle> get clippedParticipants => showMoreParticipants
      ? chat.participants
      : chat.participants.take(5).toList();

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      final chatQuery = chatBox.query(Chat_.guid.equals(chat.guid)).watch();
      sub = chatQuery.listen((Query<Chat> query) {
        final _chat = chatBox.get(chat.id!);
        if (_chat != null) {
          final update = _chat.getTitle() != chat.title || _chat.participants.length != chat.participants.length;
          chat = _chat.merge(chat);
          if (update) {
            setState(() {});
          }
        }
      });
    }

    updateObx(() {
      fetchAttachments();
      fetchLinks();
    });
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  void fetchAttachments() {
    if (kIsWeb) return;
    chat.getAttachmentsAsync().then((value) {
      final _media = value.where((e) => !(e.message.target?.isGroupEvent ?? true)
          && !(e.message.target?.isInteractive ?? true)
          && (e.mimeStart == "image" || e.mimeStart == "video")).take(24);
      final _docs = value.where((e) => !(e.message.target?.isGroupEvent ?? true)
          && !(e.message.target?.isInteractive ?? true)
          && e.mimeStart != "image" && e.mimeStart != "video" && !(e.mimeType ?? "").contains("location")).take(24);
      final _locations = value.where((e) => (e.mimeType ?? "").contains("location")).take(10);
      for (Attachment a in _media) {
        a.message.target?.handle = chat.participants.firstWhereOrNull((e) => e.id == a.message.target?.handleId);
      }
      for (Attachment a in _docs) {
        a.message.target?.handle = chat.participants.firstWhereOrNull((e) => e.id == a.message.target?.handleId);
      }
      for (Attachment a in _locations) {
        a.message.target?.handle = chat.participants.firstWhereOrNull((e) => e.id == a.message.target?.handleId);
      }
      setState(() {
        media = _media.toList();
        docs = _docs.toList();
        locations = _locations.toList();
      });
    });
  }

  void fetchLinks() {
    final query = (messageBox.query(Message_.dateDeleted.isNull()
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
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
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
          bodySlivers: [
            SliverToBoxAdapter(
              child: ChatInfo(chat: chat),
            ),
            if (chat.isGroup)
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final addMember = ListTile(
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
                    canBeRemoved: chat.participants.length > 1
                        && ss.settings.enablePrivateAPI.value
                        && chat.isIMessage,
                  );
                }, childCount: clippedParticipants.length + 2),
              ),
            const SliverPadding(
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            ChatOptions(chat: chat),
            if (!kIsWeb && media.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(top: 20, bottom: 10, left: 15),
                sliver: SliverToBoxAdapter(
                  child: Text("IMAGES & VIDEOS", style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)),
                ),
              ),
            if (!kIsWeb && media.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(10),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: max(2, ns.width(context) ~/ 200),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, int index) {
                      return MediaGalleryCard(
                        attachment: media[index],
                      );
                    },
                    childCount: media.length,
                  ),
                ),
              ),
            if (!kIsWeb && links.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(top: 20, bottom: 10, left: 15),
                sliver: SliverToBoxAdapter(
                  child: Text("LINKS", style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)),
                ),
              ),
            if (!kIsWeb && links.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(10),
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
                    itemCount: links.length,
                  ),
                ),
              ),
            if (!kIsWeb && locations.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(top: 20, bottom: 10, left: 15),
                sliver: SliverToBoxAdapter(
                  child: Text("LOCATIONS", style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)),
                ),
              ),
            if (!kIsWeb && locations.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(10),
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
                    itemCount: locations.length,
                  ),
                ),
              ),
            if (!kIsWeb && docs.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(top: 20, bottom: 10, left: 15),
                sliver: SliverToBoxAdapter(
                  child: Text("OTHER FILES", style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)),
                ),
              ),
            if (!kIsWeb && docs.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(10),
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
                    childCount: docs.length,
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

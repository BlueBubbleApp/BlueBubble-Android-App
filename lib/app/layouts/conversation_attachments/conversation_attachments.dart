import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_attachments/widgets/attachment_popup_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_attachments/widgets/attachments_filter.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/media_gallery_card.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/window_effect.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';
import 'package:url_launcher/url_launcher.dart';

enum SenderFilterEnum { everyone, fromYou, fromOthers, handle}
enum AttachmentTypes { media, links, locations, documents }

// Specific filters for AttachmentTypes.media
enum PhotosVideosFilterEnum { all, photos, videos }

class ConversationAttachments extends StatefulWidget {
  final Chat chat;
  final AttachmentTypes attachmentsType;
  final List<Attachment>? attachments;
  final List<Message>? links;

  ConversationAttachments({super.key, required this.chat, required this.attachmentsType, required this.attachments, this.links});

  @override
  State<ConversationAttachments> createState() => _ConversationAttachmentsState();
}

class _ConversationAttachmentsState extends OptimizedState<ConversationAttachments> with WidgetsBindingObserver {
  
  late Chat chat = widget.chat;
  late AttachmentTypes attachmentsType = widget.attachmentsType;
  late List<Attachment>? attachments = widget.attachments;
  late List<Message>? links = widget.links;
  late StreamSubscription sub;

  final RxList<String> selected = <String>[].obs;

  final PanelController panelController = PanelController();
  final FocusNode focusNode = FocusNode();

  final Rx<SenderFilterEnum> senderFilter = SenderFilterEnum.everyone.obs;
  final Rxn<Handle> selectedHandle = Rxn<Handle>();
  final Rxn<DateTime> sinceDate = Rxn<DateTime>();
  final Rx<PhotosVideosFilterEnum> photosVideosFilter = PhotosVideosFilterEnum.all.obs;
  final Rx<String> searchTerm = Rx<String>("");
  final RxBool isFilterActive = RxBool(false);

  Rxn<Widget> materialDetailsMenu = Rxn<Widget>(null);
  void setMaterialDetailsMenu(Widget _materialDetailsMenu) {
    materialDetailsMenu.value = _materialDetailsMenu;
  }

  Color get backgroundColor => ss.settings.windowEffect.value == WindowEffect.disabled
    ? context.theme.colorScheme.background
    : Colors.transparent;

  // Filtering 'attachments' when attachmentsType is AttachmentTypes.media, AttachmentTypes.documents, AttachmentTypes.locations,  AttachmentTypes.other
  List<Attachment> filterAttachments([String? searchTerm]) {

    List<Attachment> filteredAttachments = attachments!;

    /* Filter based on sender - from me, from others, or from as specific `handle */
    if (senderFilter.value == SenderFilterEnum.fromYou) {
      filteredAttachments = filteredAttachments.where((e) => e.message.target!.isFromMe == true).toList();
    } else if (senderFilter.value == SenderFilterEnum.fromOthers) {
      filteredAttachments = filteredAttachments.where((e) => e.message.target!.isFromMe == false).toList();
    } else if (senderFilter.value == SenderFilterEnum.handle && selectedHandle.value != null) {
      filteredAttachments = filteredAttachments.where((e) => selectedHandle.value!.isEqual(e.message.target!.handle ?? e.message.target!.getHandle())).toList();
    }

    /* Filted based on date */
    if (sinceDate.value != null) {
      filteredAttachments = filteredAttachments.where((e) => e.message.target!.dateCreated!.compareTo(sinceDate.value!) >= 0).toList();
    }

    /* Additional filter for AttachmentTypes.media to filter between images or videos */
    if (attachmentsType == AttachmentTypes.media) {
      if (photosVideosFilter.value == PhotosVideosFilterEnum.photos) {
        filteredAttachments = filteredAttachments.where((e) => e.mimeStart == "image").toList();
      } else if (photosVideosFilter.value == PhotosVideosFilterEnum.videos) {
        filteredAttachments = filteredAttachments.where((e) => e.mimeStart == "video").toList();
      }
    }

    /* Filter based on searchbar */
    /* Specifically for documents */
    if (attachmentsType == AttachmentTypes.documents && searchTerm != null) {
      if (searchTerm.length >= 3) {
        filteredAttachments = filteredAttachments.where((e) => e.transferName != null && e.transferName!.toLowerCase().contains(searchTerm)).toList();
      }
    }

    return filteredAttachments;
  }

  // Filtering 'links' when attachmentsType is or AttachmentTypes.links or AttachmentTypes.locations
  List<Message> filterLinks([String? searchTerm]) {

    List<Message> filteredLinks = links!;

    /* Filter based on sender - from you, from others, or from as specific handle */
    if (senderFilter.value == SenderFilterEnum.fromYou) {
      filteredLinks = filteredLinks.where((e) => e.isFromMe == true).toList();
    } else if (senderFilter.value == SenderFilterEnum.fromOthers) {
      filteredLinks = filteredLinks.where((e) => e.isFromMe == false).toList();
    } else if (senderFilter.value == SenderFilterEnum.handle && selectedHandle.value != null) {
      filteredLinks = filteredLinks.where((e) => selectedHandle.value!.isEqual(e.handle ?? e.getHandle())).toList();
    }

    /* Filter based on date */
    if (sinceDate.value != null) {
      filteredLinks = filteredLinks.where((e) => e.dateCreated!.compareTo(sinceDate.value!) >= 0).toList();
    }

    /* Filter based on searchbar */
    /* Specifically for links */
    if (attachmentsType == AttachmentTypes.links && searchTerm != null) {
      if (searchTerm.length >= 3) {
        filteredLinks = filteredLinks.where((e) {
          if (e.payloadData?.urlData?.firstOrNull == null) return false;
          return e.payloadData?.urlData?.first.siteName?.toLowerCase().contains(searchTerm) == true
            || e.payloadData?.urlData?.first.url?.toLowerCase().contains(searchTerm) == true
            || e.payloadData?.urlData?.first.title?.toLowerCase().contains(searchTerm) == true
            || e.payloadData?.urlData?.first.summary?.toLowerCase().contains(searchTerm) == true;
        }).toList();

        filteredLinks.sort((Message a, Message b) {
          final aUrlData = a.payloadData?.urlData?.first;
          final bUrlData = b.payloadData?.urlData?.first;

          int priority(String? fieldA, String? fieldB) {
            final aMatch = fieldA?.toLowerCase().contains(searchTerm) == true ? 1 : 0;
            final bMatch = fieldB?.toLowerCase().contains(searchTerm) == true ? 1 : 0;
            return bMatch - aMatch;
          }

          // Compare by priority: SITE NAME > TITLE > SUMMARY > FULL URL
          int result = priority(aUrlData?.siteName, bUrlData?.siteName);
          if (result != 0) return result;

          result = priority(aUrlData?.title, bUrlData?.title);
          if (result != 0) return result;

          result = priority(aUrlData?.summary, bUrlData?.summary);
          if (result != 0) return result;

          return priority(aUrlData?.url, bUrlData?.url);

        });
      }
    }

    return filteredLinks;
  }


  @override
  void initState() {
      super.initState();
      senderFilter.value = SenderFilterEnum.everyone;
      selectedHandle.value = null;
      sinceDate.value = null;
      photosVideosFilter.value = PhotosVideosFilterEnum.all;
      searchTerm.value = "";
  }

  @override
  void dispose() {
    super.dispose();
  }

  String getTitle() {
    switch (attachmentsType) {
      case AttachmentTypes.media:
        return "Photos & Videos";
      case AttachmentTypes.links:
        return "Links";
      case AttachmentTypes.locations:
        return "Locations";
      case AttachmentTypes.documents:
        return "Other Files";
      default:
        return "Other Files";
    }
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
        child : PopScope(
          canPop: false,
          onPopInvoked: (bool didPop) {
            if (didPop) return;
            if (panelController.isPanelOpen) {
              panelController.close();
            } else {
              final NavigatorState navigator = Navigator.of(context);
              navigator.pop();
            }
          },
          child: Stack(
            children : [
              Obx(() => SettingsScaffold(
                headerColor: headerColor,
                title: getTitle(),
                tileColor: tileColor,
                initialHeader: null,
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                actions: [
                  Obx(() {
                    if (selected.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          icon: 
                            (senderFilter.value != SenderFilterEnum.everyone || selectedHandle.value != null || sinceDate.value != null ) ?
                              Badge(
                                // offset: const Offset(-4, -4),
                                // alignment: AlignmentDirectional.bottomEnd,
                                smallSize: 10,
                                backgroundColor: context.theme.colorScheme.primary,
                                child: Icon(iOS ? CupertinoIcons.slider_horizontal_3 : Icons.tune, color: context.theme.colorScheme.onBackground)
                              ) :
                              Icon(iOS ? CupertinoIcons.slider_horizontal_3 : Icons.tune, color: context.theme.colorScheme.onBackground)
                            ,
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            if (focusNode.hasFocus) {
                              focusNode.unfocus();
                            }
                        
                            if (panelController.isPanelOpen) {
                              panelController.close();
                            } else {
                              panelController.open();
                            }
                          },
                        ),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  }),
                  // <-- BEGIN MATERIAL DETAILS MENU -->
                  // When the theme is Material and just one item is selected, show the materialDetailsMenu options
                  // Obx(() {
                  //   if (selected.isNotEmpty && materialDetailsMenu.value != null && selected.length == 1) {
                  //     return materialDetailsMenu.value!;
                  //   }
                  //   return SizedBox.shrink(); // Return an empty widget if the condition is not met
                  // }),
                  // <-- END MATERIAL DETAILS MENU -->
                  Obx(() {
                    if (selected.isNotEmpty && attachments != null) {
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
                    if (selected.isNotEmpty && attachments != null) {
                      return IconButton(
                        icon: Icon(iOS ? CupertinoIcons.cloud_download : Icons.file_download, color: context.theme.colorScheme.onBackground),
                        onPressed: () {
                          final _attachments = attachments!.where((e) => selected.contains(e.guid!));
                          for (Attachment a in _attachments) {
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
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  AttachmentsFilterSelector(
                    attachmentsType : attachmentsType,
                    photosVideosFilter : photosVideosFilter,
                    selected : selected,
                    focusNode: focusNode,
                    searchTerm : searchTerm
                  ),
                  if (attachmentsType == AttachmentTypes.media && attachments != null)
                    Obx(() {
          
                      List<Attachment> filteredAttachments = filterAttachments();

                      if (filteredAttachments.isEmpty) {
                        return const NoResultsFoundBox();
                      }
          
                      return SliverPadding(
                        padding: const EdgeInsets.all(10),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: max(3, ns.width(context) ~/ 200),
                            mainAxisSpacing: 5,
                            crossAxisSpacing: 5
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, int index) {
                              return Obx(() => AnimatedContainer(
                                key: ValueKey(filteredAttachments[index].guid),
                                duration: const Duration(milliseconds: 250),
                                margin: EdgeInsets.all(selected.contains(filteredAttachments[index].guid) ? 10 : 0),
                                decoration: const BoxDecoration(
                                  borderRadius: BorderRadius.zero,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: AttachmentPopupHolder(
                                  key : ValueKey(filteredAttachments[index].guid),
                                  message : filteredAttachments[index].message.target!,
                                  attachment : filteredAttachments[index],
                                  focusNode : focusNode,
                                  selected : selected,
                                  setMaterialDetailsMenu : !iOS ? setMaterialDetailsMenu : null,
                                  child: GestureDetector(
                                    onTap: selected.isNotEmpty ? () {
                                      if (selected.contains(filteredAttachments[index].guid)) {
                                        selected.remove(filteredAttachments[index].guid!);
                                      } else {
                                        selected.add(filteredAttachments[index].guid!);
                                      }
                                    } : null,
                                    child: AbsorbPointer(
                                      absorbing: selected.isNotEmpty,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          MediaGalleryCard(
                                            attachment: filteredAttachments[index],
                                          ),
                                          if (selected.contains(filteredAttachments[index].guid))
                                            Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: context.theme.colorScheme.primary
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(2.0),
                                                child: Icon(
                                                  iOS ? CupertinoIcons.check_mark : Icons.check,
                                                  color: context.theme.colorScheme.onPrimary,
                                                  size: 14,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ));
                            },
                            childCount: filteredAttachments.length,
                          ),
                        ),
                      );
                    }),
                  if (attachmentsType == AttachmentTypes.links && links != null && links!.isNotEmpty)
                    Obx(() {

                      List<Message> filteredLinks = filterLinks(searchTerm.value);

                      if (filteredLinks.isEmpty) {
                        return const NoResultsFoundBox();
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.only(top: 0, bottom: 10, left: 10, right: 10),
                        sliver: SliverToBoxAdapter(
                          child: MasonryGridView.count(
                            crossAxisCount: max(2, ns.width(context) ~/ 200),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              if (filteredLinks[index].payloadData?.urlData?.firstOrNull == null) {
                                return const Text("Failed to load link!");
                              }
                              return AttachmentPopupHolder(
                                key : ValueKey(filteredLinks[index].guid),
                                message : filteredLinks[index],
                                url : filteredLinks[index].payloadData?.urlData?.first.url,
                                focusNode : focusNode,
                                selected : selected,
                                setMaterialDetailsMenu : !iOS ? setMaterialDetailsMenu : null,
                                child: Material(
                                  color: context.theme.colorScheme.properSurface,
                                  borderRadius: BorderRadius.circular(20),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () async {
                                      final data = filteredLinks[index].payloadData!.urlData!.first;
                                      if ((data.url ?? data.originalUrl) == null) return;
                                      await launchUrl(
                                          Uri.parse((data.url ?? data.originalUrl)!),
                                          mode: LaunchMode.externalApplication
                                      );
                                    },
                                    child: Center(
                                      child: UrlPreview(
                                        data: filteredLinks[index].payloadData!.urlData!.first,
                                        message: filteredLinks[index],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            itemCount: filteredLinks.length,
                          ),
                        ),
                      );
                    }),
                  if (attachmentsType == AttachmentTypes.locations)
                    Obx(() { 

                      List<Attachment> filteredAttachments = filterAttachments();
                      List<Message> filteredLinks = filterLinks();

                      if (filteredAttachments.isEmpty) {
                        return const NoResultsFoundBox();
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.all(10),
                        sliver: SliverToBoxAdapter(
                          child: MasonryGridView.count(
                            crossAxisCount: max(2, ns.width(context) ~/ 200),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              if (as.getContent(filteredAttachments[index]) is! PlatformFile) {
                                return const Text("Failed to load location!");
                              }
                              return AttachmentPopupHolder(
                                key : ValueKey(filteredAttachments[index].guid),
                                message : filteredAttachments[index].message.target!,
                                attachment : filteredAttachments[index],
                                url : filteredLinks[index].payloadData?.urlData?.first.url,
                                focusNode : focusNode,
                                selected : selected,
                                setMaterialDetailsMenu : !iOS ? setMaterialDetailsMenu : null,
                                child: Material(
                                  key: ValueKey(filteredAttachments[index].guid),
                                  color: context.theme.colorScheme.properSurface,
                                  borderRadius: BorderRadius.circular(20),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () async {
                                      final data = filteredLinks[index].payloadData!.urlData!.first;
                                      if ((data.url ?? data.originalUrl) == null) return;
                                      await launchUrl(
                                          Uri.parse((data.url ?? data.originalUrl)!),
                                          mode: LaunchMode.externalApplication
                                      );
                                    },
                                    child: Center(
                                      child: UrlPreview(
                                        data: UrlPreviewData(
                                          title: "Location from ${DateFormat.yMd().format(filteredAttachments[index].message.target!.dateCreated!)}",
                                          siteName: "Tap to open",
                                        ),
                                        message: filteredAttachments[index].message.target!,
                                        file: as.getContent(filteredAttachments[index]),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            itemCount: filteredAttachments.length,
                          ),
                        ),
                      );
                    }),
                  if (attachmentsType == AttachmentTypes.documents)
                    Obx(() {

                      List<Attachment> filteredAttachments = filterAttachments(searchTerm.value);

                      if (filteredAttachments.isEmpty) {
                        return const NoResultsFoundBox();
                      }

                      return SliverPadding(
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
                              return AttachmentPopupHolder(
                                key : ValueKey(filteredAttachments[index].guid),
                                message : filteredAttachments[index].message.target!,
                                attachment : filteredAttachments[index],
                                focusNode : focusNode,
                                selected : selected,
                                setMaterialDetailsMenu : !iOS ? setMaterialDetailsMenu : null,
                                child: MediaGalleryCard(
                                  key: ValueKey(filteredAttachments[index].guid),
                                  attachment: filteredAttachments[index],
                                ),
                              );
                            },
                            childCount: filteredAttachments.length,
                          ),
                        ),
                      );
                    }),
                ],
              )),
              AttachmentsFilterPanel(
                chat : chat,
                attachmentsType: attachmentsType,
                senderFilter : senderFilter,
                selectedHandle : selectedHandle,
                sinceDate : sinceDate,
                photosVideosFilter : photosVideosFilter,
                panelController: panelController,
                focusNode: focusNode
              )
            ]
          ),
        )
      ),
    );
  }

}

class NoResultsFoundBox extends StatelessWidget {
  const NoResultsFoundBox({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("No results found.", style: context.theme.textTheme.bodyLarge),
          Text("Try fetching more messages or changing your filters.", style: context.theme.textTheme.bodySmall),
          Container(
            height: MediaQuery.of(context).size.height * 0.25
          )
        ],
      ),
    );
  }

}
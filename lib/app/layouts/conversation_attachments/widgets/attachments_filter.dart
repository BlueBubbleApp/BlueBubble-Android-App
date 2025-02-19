import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/conversation_attachments/conversation_attachments.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/timeframe_picker.dart';  
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/io/chat.dart';
import 'package:bluebubbles/database/io/handle.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/window_effect.dart';
import 'package:get/get.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';

class AttachmentsFilterSelector extends StatefulWidget {

  final AttachmentTypes attachmentsType;
  final Rx<PhotosVideosFilterEnum> photosVideosFilter;

  final RxList<String> selected;

  final FocusNode focusNode;
  final Rx<String> searchTerm;

  const AttachmentsFilterSelector({
    super.key,
    required this.attachmentsType,
    required this.photosVideosFilter,
    required this.selected,
    required this.focusNode,
    required this.searchTerm
  });

  @override
  OptimizedState createState() => _AttachmentsFilterSelectorState();
}

class _AttachmentsFilterSelectorState extends OptimizedState<AttachmentsFilterSelector> {

  late Rx<PhotosVideosFilterEnum> photosVideosFilter = widget.photosVideosFilter;
  late AttachmentTypes attachmentsType = widget.attachmentsType;

  late RxList<String> selected = widget.selected;

  late FocusNode focusNode = widget.focusNode;
  late Rx<String> searchTerm = widget.searchTerm;

  final TextEditingController textEditingController = TextEditingController();

  search(String linksQuery) {
    selected.clear();
    searchTerm.value = linksQuery.trim().toLowerCase();
  }

    @override
  Widget build(BuildContext context) {

    return SliverToBoxAdapter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (attachmentsType == AttachmentTypes.media)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom : 10),
                  child: Obx(() {
                    return Container(
                      child : SettingsSection(
                        backgroundColor: tileColor,
                        children: [
                          SettingsOptions<PhotosVideosFilterEnum>(
                            initial: photosVideosFilter.value,
                            onChanged: (val) async {
                              if (val == null) return;
                              setState(() {
                                photosVideosFilter.value = val;
                                selected.clear();
                              });
                            },
                            options: PhotosVideosFilterEnum.values.toList(),
                            textProcessing: (val) => val.name,
                            capitalize: true,
                            title: "Filter",
                          )
                        ],
                      )
                    );
                  }),
                ),
              ),
            if (attachmentsType == AttachmentTypes.links || attachmentsType == AttachmentTypes.documents)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 15, right: 15, top: 5, bottom : 20),
                  child: CupertinoTextField(
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      search(textEditingController.text);
                    },
                    onChanged: (query) {
                      if (ss.settings.highPerfMode.value == true) return;
                      search(textEditingController.text);
                    },
                    focusNode: focusNode,
                    padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
                    controller: textEditingController,
                    placeholder: "Enter a search term...",
                    style: context.theme.textTheme.bodyLarge,
                    placeholderStyle:
                        context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.outline),
                    cursorColor: context.theme.colorScheme.primary,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.theme.colorScheme.primary),
                    ),
                    maxLines: 1,
                    prefix: Padding(
                      padding: const EdgeInsets.only(left: 15),
                      child: Icon(ss.settings.skin.value == Skins.iOS ? CupertinoIcons.search : Icons.search,
                          color: context.theme.colorScheme.outline),
                    ),
                    suffix: Padding(
                      padding: const EdgeInsets.only(right: 15),
                      child: InkWell(
                        child: Icon(Icons.arrow_forward, color: context.theme.colorScheme.primary),
                        onTap: () {
                          search(textEditingController.text);
                        })
                    ),
                    suffixMode: OverlayVisibilityMode.editing,
                  ),
                ),
              ),
          ],
        ),
      );
  }
}


/* Sliding up panel */

class AttachmentsFilterPanel extends StatefulWidget {

  final Chat chat;
  final AttachmentTypes attachmentsType;

  final PanelController panelController;
  final FocusNode focusNode;

  final Rx<SenderFilterEnum> senderFilter;
  final Rxn<Handle> selectedHandle;
  final Rxn<DateTime> sinceDate;
  final Rx<PhotosVideosFilterEnum> photosVideosFilter;

  const AttachmentsFilterPanel({super.key, required this.chat, required this.attachmentsType, required this.photosVideosFilter, required this.senderFilter, required this.selectedHandle, required this.sinceDate, required this.panelController, required this.focusNode});

  @override
  OptimizedState createState() => _AttachmentsFilterPanelState();
}

class _AttachmentsFilterPanelState extends OptimizedState<AttachmentsFilterPanel> {

  final TextEditingController textEditingController = TextEditingController();

  late AttachmentTypes attachmentsType = widget.attachmentsType;

  late Rx<SenderFilterEnum> senderFilter = widget.senderFilter;
  late Rxn<Handle> selectedHandle = widget.selectedHandle;
  late Rxn<DateTime> sinceDate = widget.sinceDate;
  late Rx<PhotosVideosFilterEnum> photosVideosFilter = widget.photosVideosFilter;
  
  late Chat chat = widget.chat;
  late PanelController panelController = widget.panelController;
  late FocusNode focusNode = widget.focusNode;

  Color get backgroundColor => ss.settings.windowEffect.value == WindowEffect.disabled
    ? context.theme.colorScheme.background
    : Colors.transparent;

    @override
  Widget build(BuildContext context) {

    return SlidingUpPanel(
      controller: panelController,
      defaultPanelState: PanelState.CLOSED,
      backdropEnabled: true,
      backdropTapClosesPanel: true,
      backdropColor: context.theme.colorScheme.properSurface,
      color: backgroundColor,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      isDraggable: false,
      parallaxEnabled: true,
      minHeight: 0,
      maxHeight: 400,
      panelBuilder: () {
        return Container(
          padding: const EdgeInsets.only(left: 10, right: 10, bottom: 20, top: 20),
          child: Column(children: [
            Center(
                child: Text(
              "Filters",
              style: context.theme.textTheme.headlineSmall,
            )),
            Material(
                child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Flexible(
                          fit: FlexFit.tight,
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sender',
                                style: context.theme.textTheme.bodyMedium!.copyWith(
                                  color: context.theme.colorScheme.outline,
                                ),
                              ),
                              Wrap(
                                direction: Axis.horizontal,
                                alignment: WrapAlignment.start,
                                spacing: 5,
                                children: [
                                  if (selectedHandle.value == null && senderFilter.value != SenderFilterEnum.fromOthers)
                                    RawChip(
                                      tapEnabled: true,
                                      showCheckmark: true,
                                      selected: senderFilter.value == SenderFilterEnum.fromYou,
                                      checkmarkColor: context.theme.colorScheme.primary,
                                      side: BorderSide(color: context.theme.colorScheme.outline.withOpacity(0.1)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      label: Text('From You',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                              color: context.theme.colorScheme.onSurface)),
                                      onSelected: (selected) {
                                        setState(() {
                                          senderFilter.value = selected ? SenderFilterEnum.fromYou : SenderFilterEnum.everyone;
                                        });
                                      },
                                    ),
                                  if (selectedHandle.value == null && senderFilter.value != SenderFilterEnum.fromYou)
                                    RawChip(
                                      tapEnabled: true,
                                      showCheckmark: true,
                                      selected: senderFilter.value == SenderFilterEnum.fromOthers,
                                      checkmarkColor: context.theme.colorScheme.primary,
                                      side: BorderSide(color: context.theme.colorScheme.outline.withOpacity(0.1)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      label: Text('From Others',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                              color: context.theme.colorScheme.onSurface)),
                                      onSelected: (selected) {
                                        setState(() {
                                          senderFilter.value = selected ? SenderFilterEnum.fromOthers : SenderFilterEnum.everyone;
                                        });
                                      },
                                    ),
                                ],
                              ),
                              if (chat.isGroup && senderFilter.value != SenderFilterEnum.fromYou && senderFilter.value != SenderFilterEnum.fromOthers)
                                /* 
                                  Builds a RawChip for each conversation participant.
                                  Conversations can have a maximum of 32 participants.
                                  At the moment, we just have a single-line scrolling list. That can be very tedious with 32 chips on screen.
                                  The solution for that would be to switch to a scrolling three-row horizontal masonry layout. So you have three rows of chips instead of one, building out horizontally.
                                */
                                SizedBox(
                                  height : 42,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    shrinkWrap: true,
                                    separatorBuilder: (BuildContext context, int index) {
                                        return const SizedBox(width: 5);
                                    },
                                    itemCount: chat.participants.length,
                                    itemBuilder: (context, index) {
                                      if (senderFilter.value == SenderFilterEnum.handle && selectedHandle.value != chat.participants[index]) {
                                        return const SizedBox(width: 0);
                                      }
                                      return RawChip(
                                        tapEnabled: true,
                                        showCheckmark: true,
                                        selected: (senderFilter.value == SenderFilterEnum.handle && selectedHandle.value == chat.participants[index]),
                                        checkmarkColor: context.theme.colorScheme.primary,
                                        side: BorderSide(color: context.theme.colorScheme.outline.withOpacity(0.1)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        avatar: ContactAvatarWidget(handle: chat.participants[index]),
                                        label: Text('From ${chat.participants[index].displayName}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.normal,
                                            color: context.theme.colorScheme.onSurface)),
                                        onSelected: (selected) {
                                          setState(() {
                                            if (selected) {
                                              senderFilter.value = SenderFilterEnum.handle;
                                              selectedHandle.value = chat.participants[index];
                                            } else {
                                              senderFilter.value = SenderFilterEnum.everyone;
                                              selectedHandle.value = null;
                                            }
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                              if (attachmentsType == AttachmentTypes.media) 
                                Text(
                                  'Type',
                                  style: context.theme.textTheme.bodyMedium!.copyWith(
                                    color: context.theme.colorScheme.outline,
                                  ),
                                ),
                              if (attachmentsType == AttachmentTypes.media) 
                                Wrap(
                                  direction: Axis.horizontal,
                                  alignment: WrapAlignment.start,
                                  spacing: 10,
                                  children: [
                                    if (photosVideosFilter.value == PhotosVideosFilterEnum.all || photosVideosFilter.value == PhotosVideosFilterEnum.photos)
                                      RawChip(
                                        tapEnabled: true,
                                        showCheckmark: (photosVideosFilter.value == PhotosVideosFilterEnum.photos),
                                        selected: (photosVideosFilter.value == PhotosVideosFilterEnum.photos),
                                        checkmarkColor: context.theme.colorScheme.primary,
                                        side: BorderSide(color: context.theme.colorScheme.outline.withOpacity(0.1)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        label: Text('Photos',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                                color: context.theme.colorScheme.onSurface)),
                                        onSelected: (selected) {
                                          setState(() {
                                            photosVideosFilter.value = (selected) ? PhotosVideosFilterEnum.photos : PhotosVideosFilterEnum.all;
                                          });
                                        },
                                      ),
                                    if (photosVideosFilter.value == PhotosVideosFilterEnum.all || photosVideosFilter.value == PhotosVideosFilterEnum.videos)
                                      RawChip(
                                        tapEnabled: true,
                                        showCheckmark: (photosVideosFilter.value == PhotosVideosFilterEnum.videos),
                                        selected: (photosVideosFilter.value == PhotosVideosFilterEnum.videos),
                                        checkmarkColor: context.theme.colorScheme.primary,
                                        side: BorderSide(color: context.theme.colorScheme.outline.withOpacity(0.1)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        label: Text('Videos',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                                color: context.theme.colorScheme.onSurface)),
                                        onSelected: (selected) {
                                          setState(() {
                                            photosVideosFilter.value = (selected) ? PhotosVideosFilterEnum.videos : PhotosVideosFilterEnum.all;
                                          });
                                        },
                                      ),
                                  ],
                                ),
                                // if (photosVideosFilter.value == PhotosVideosFilterEnum.photos)
                                //   Wrap(
                                //     direction: Axis.horizontal,
                                //     alignment: WrapAlignment.start,
                                //     spacing: 10,
                                //     children: [
                                //       RawChip(
                                //         tapEnabled: true,
                                //         showCheckmark: true,
                                //         selected: (photosVideosFilter.value == PhotosVideosFilterEnum.photos),
                                //         checkmarkColor: context.theme.colorScheme.primary,
                                //         side: BorderSide(color: context.theme.colorScheme.outline.withOpacity(0.1)),
                                //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                //         avatar: CircleAvatar(
                                //           backgroundColor: context.theme.colorScheme.primaryContainer,
                                //           child: Icon(
                                //             (iOS ? CupertinoIcons.smallcircle_circle : Icons.motion_photos_on),
                                //             color: context.theme.colorScheme.primary,
                                //             size: 12,
                                //           ),
                                //         ),
                                //         label: Text('Live',
                                //             style: TextStyle(
                                //                 fontSize: 14,
                                //                 fontWeight: FontWeight.normal,
                                //                 color: context.theme.colorScheme.onSurface)),
                                //         onSelected: (selected) {
                                //           if (selected) {
                                //             photosVideosFilter.value = PhotosVideosFilterEnum.all;
                                //           } else {
                                //             photosVideosFilter.value = PhotosVideosFilterEnum.photos;
                                //           }
                                //         },
                                //       ),
                                //       RawChip(
                                //         tapEnabled: true,
                                //         showCheckmark: true,
                                //         selected: (photosVideosFilter.value == PhotosVideosFilterEnum.videos),
                                //         checkmarkColor: context.theme.colorScheme.primary,
                                //         side: BorderSide(color: context.theme.colorScheme.outline.withOpacity(0.1)),
                                //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                //         avatar: CircleAvatar(
                                //           backgroundColor: context.theme.colorScheme.primaryContainer,
                                //           child: Icon(
                                //             (iOS ? CupertinoIcons.camera_viewfinder : Icons.center_focus_weak),
                                //             color: context.theme.colorScheme.primary,
                                //             size: 12,
                                //           ),
                                //         ),
                                //         label: Text('Screenshots',
                                //             style: TextStyle(
                                //                 fontSize: 14,
                                //                 fontWeight: FontWeight.normal,
                                //                 color: context.theme.colorScheme.onSurface)),
                                //         onSelected: (selected) {
                                //           if (selected) {
                                //             photosVideosFilter.value = PhotosVideosFilterEnum.all;
                                //           } else {
                                //             photosVideosFilter.value = PhotosVideosFilterEnum.videos;
                                //           }
                                //         },
                                //       ),
                                //       RawChip(
                                //         tapEnabled: true,
                                //         showCheckmark: true,
                                //         selected: (photosVideosFilter.value == PhotosVideosFilterEnum.videos),
                                //         checkmarkColor: context.theme.colorScheme.primary,
                                //         side: BorderSide(color: context.theme.colorScheme.outline.withOpacity(0.1)),
                                //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                //         avatar: CircleAvatar(
                                //           backgroundColor: context.theme.colorScheme.primaryContainer,
                                //           child: Icon(
                                //             Icons.gif, // Could not find a Cupertino Icon to represent a GIF
                                //             color: context.theme.colorScheme.primary,
                                //             size: 12,
                                //           ),
                                //         ),
                                //         label: Text('Gifs',
                                //             style: TextStyle(
                                //                 fontSize: 14,
                                //                 fontWeight: FontWeight.normal,
                                //                 color: context.theme.colorScheme.onSurface)),
                                //         onSelected: (selected) {
                                //           if (selected) {
                                //             photosVideosFilter.value = PhotosVideosFilterEnum.all;
                                //           } else {
                                //             photosVideosFilter.value = PhotosVideosFilterEnum.videos;
                                //           }
                                //         },
                                //       ),
                                //     ],
                                //   ),
                              Text(
                                'Date',
                                style: context.theme.textTheme.bodyMedium!.copyWith(
                                  color: context.theme.colorScheme.outline,
                                ),
                              ),
                              Wrap(
                                direction: Axis.horizontal,
                                alignment: WrapAlignment.start,
                                spacing: 10,
                                children: [
                                  RawChip(
                                    tapEnabled: true,
                                    deleteIcon: const Icon(Icons.close, size: 16),
                                    side: BorderSide(color: context.theme.colorScheme.outline.withOpacity(0.1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    avatar: CircleAvatar(
                                      backgroundColor: context.theme.colorScheme.primaryContainer,
                                      child: Icon(
                                        Icons.calendar_today_outlined,
                                        color: context.theme.colorScheme.primary,
                                        size: 12,
                                      ),
                                    ),
                                    label: sinceDate.value != null
                                        ? Text(
                                            "Since ${buildFullDate(sinceDate.value!, includeTime: sinceDate.value!.isToday(), useTodayYesterday: true)}",
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                                color: context.theme.colorScheme.onSurface),
                                            overflow: TextOverflow.ellipsis)
                                        : Text('Filter by Date',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                                color: context.theme.colorScheme.onSurface)),
                                    onDeleted: sinceDate.value == null
                                        ? null
                                        : () {
                                            setState(() {
                                              sinceDate.value = null;
                                            });
                                          },
                                    onPressed: () async {
                                      sinceDate.value = await showTimeframePicker("Since When?", context,
                                          customTimeframes: {
                                            "1 Hour": 1,
                                            "1 Day": 24,
                                            "1 Week": 168,
                                            "1 Month": 720,
                                            "6 Months": 4320,
                                            "1 Year": 8760,
                                          },
                                          selectionSuffix: "Ago",
                                          useTodayYesterday: true
                                        );
                                    },
                                  )
                                ]
                              )
                            ]
                          ),
                        ),
                      ],
                    )
                  )
                ),
          ]),
        );
      },
    );
  }
}

import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/embedded_media.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/details_menu_action.dart';
import 'package:bluebubbles/app/components/custom/custom_cupertino_alert_dialog.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/fullscreen_holder.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide BackButton;
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' hide context;
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:universal_io/io.dart';

class AttachmentPopup extends StatefulWidget {
  final Offset childPosition;
  final Size size;
  final Widget child;
  final Attachment? attachment;
  final Message message;
  final RxList<String> selected;
  final Tuple3<bool, bool, bool> serverDetails;
  final BuildContext? Function() widthContext;
  final String? url;
  final bool? returnMaterialActionWidgetsOnly;

  const AttachmentPopup({
    super.key,
    required this.childPosition,
    required this.size,
    required this.child,
    required this.message,
    required this.selected,
    this.attachment,
    required this.serverDetails,
    required this.widthContext,
    this.returnMaterialActionWidgetsOnly,
    this.url,
  });

  @override
  State<StatefulWidget> createState() => _AttachmentPopupState();
}

class _AttachmentPopupState extends OptimizedState<AttachmentPopup> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    animationBehavior: AnimationBehavior.preserve,
  );
  final double itemHeight = kIsDesktop || kIsWeb ? 56 : 48;

  late double messageOffset = Get.height - widget.childPosition.dy - widget.size.height;
  late double materialOffset = widget.childPosition.dy +
      EdgeInsets.fromViewPadding(
        View.of(context).viewInsets,
        View.of(context).devicePixelRatio,
      ).bottom;
  late int numberToShow = 3;

  MessagesService get service => ms(chat.guid);

  Chat get chat => widget.message.chat.target!;

  Attachment? get attachment => widget.attachment;
  String? get url => widget.url;

  Message get message => widget.message;

  RxList<String> get selected => widget.selected;
  

  bool get isSent => !message.guid!.startsWith('temp') && !message.guid!.startsWith('error');

  bool get showDownload =>
      (isSent && attachment != null && as.getContent(attachment!) is PlatformFile) ||
      isEmbeddedMedia;

  late bool isEmbeddedMedia = (message.balloonBundleId == "com.apple.Handwriting.HandwritingProvider" ||
          message.balloonBundleId == "com.apple.DigitalTouchBalloonProvider") &&
      File(message.interactiveMediaPath!).existsSync();

  bool get minSierra => widget.serverDetails.item1;

  bool get minBigSur => widget.serverDetails.item2;

  bool get supportsOriginalDownload => widget.serverDetails.item3;

  BuildContext get widthContext => widget.widthContext.call() ?? context;
  double get maxMenuWidth => min(max(ns.width(widthContext) * 3 / 5, 200), ns.width(widthContext) * 4 / 5);
  double get contextMenuAlignCenterSpacing => (ns.width(widthContext) - maxMenuWidth)/2;


  // Calculates whether to align the context menu to the left, center, or right of the screen
  // If the dist(top-left to left edge) - dist(top-right to right edge) < (1/4)(screen width) = center
  // Otherwise, whichever corner is closer to their respective edge wins
  String _getContextMenuAlignment() {
    double distToLeft = widget.childPosition.dx;
    double distToRight = ns.width(widthContext) - (widget.childPosition.dx + widget.size.width);
    if ((distToLeft - distToRight).abs() < (ns.width(widthContext) / 4)){ 
      return 'center';
    }
    if (distToLeft < distToRight) {
      return 'left';
    }
    return 'right';
  } 

  // Determines if the context menu is aligned to the left, center, or right
  late String contextMenuAlign;
  
  @override
  void initState() {
    super.initState();
    controller.forward();
    if (iOS) {
      contextMenuAlign = _getContextMenuAlignment();
      final remainingHeight = max(Get.height - Get.statusBarHeight - 135 - widget.size.height, itemHeight);
      numberToShow = min(remainingHeight ~/ itemHeight, 3);
    } else {
      // Potentially make this dynamic in the future
      numberToShow = (widget.returnMaterialActionWidgetsOnly == true) ? 1 : 3;
    }

    updateObx(() {
      setState(() {
        if (iOS) messageOffset = itemHeight * numberToShow + 40;
      });
    });
  }

  void popDetails({bool returnVal = true}) {
    bool dialogOpen = Get.isDialogOpen ?? false;
    if (dialogOpen) {
      if (kIsWeb) {
        Get.back();
      } else {
        Navigator.of(context).pop();
      }
    }
    Navigator.of(context).pop(returnVal);
  }

  @override
  Widget build(BuildContext context) {

    if (widget.returnMaterialActionWidgetsOnly == true) {
      return Row(
        children: [
          ...buildMaterialDetailsMenu(context),
        ]
      );
    }

    double narrowWidth = message.isFromMe! || !ss.settings.alwaysShowAvatars.value ? 330 : 360;
    bool narrowScreen = ns.width(widthContext) < narrowWidth;

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
            surface:
                ss.settings.monetTheming.value == Monet.full ? null : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
            onSurface: ss.settings.monetTheming.value == Monet.full
                ? null
                : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
          ),
        ),
        child: TitleBarWrapper(
            child: Scaffold(
                extendBodyBehindAppBar: true,
                backgroundColor: kIsDesktop && iOS && ss.settings.windowEffect.value != WindowEffect.disabled
                    ? context.theme.colorScheme.properSurface.withOpacity(0.6)
                    : Colors.transparent,
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (iOS)
                      GestureDetector(
                        onTap: popDetails,
                        child: iOS
                            ? (ss.settings.highPerfMode.value
                                ? Container(color: context.theme.colorScheme.background.withOpacity(0.8))
                                : BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: kIsDesktop && ss.settings.windowEffect.value != WindowEffect.disabled ? 10 : 30,
                                        sigmaY: kIsDesktop && ss.settings.windowEffect.value != WindowEffect.disabled ? 10 : 30),
                                    child: Container(
                                      color: context.theme.colorScheme.properSurface.withOpacity(0.3),
                                    ),
                                  ))
                            : null,
                      ),
                    if (iOS)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        left: widget.childPosition.dx,
                        bottom: messageOffset,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.8, end: 1),
                          curve: Curves.easeOutBack,
                          duration: const Duration(milliseconds: 500),
                          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: widget.size.width), child: widget.child),
                          builder: (context, size, child) {
                            return Transform.scale(
                              scale: size.clamp(1, double.infinity),
                              child: child,
                              alignment: message.isFromMe! ? Alignment.centerRight : Alignment.centerLeft,
                            );
                          },
                        ),
                      ),
                    if (iOS)
                      Positioned(
                        right: (contextMenuAlign == "right") ? 15 : (contextMenuAlign == "center") ? contextMenuAlignCenterSpacing : null,
                        left: (contextMenuAlign == "left") ? 15 : (contextMenuAlign == "center") ? contextMenuAlignCenterSpacing : null,
                        bottom: 30,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.8, end: 1),
                          curve: Curves.easeOutBack,
                          duration: const Duration(milliseconds: 400),
                          child: FadeTransition(
                            opacity: CurvedAnimation(
                              parent: controller,
                              curve: const Interval(0.0, .9, curve: Curves.ease),
                              reverseCurve: Curves.easeInCubic,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),
                                buildDetailsMenu(context),
                              ],
                            ),
                          ),
                          builder: (context, size, child) {
                            return Transform.scale(
                              scale: size,
                              child: child,
                            );
                          },
                        ),
                      ),
                  ],
                )
              )
            ),
      ),
    );
  }

  Future<void> download() async {
    try {
      dynamic content;
      if (isEmbeddedMedia) {
        content = PlatformFile(
          name: basename(message.interactiveMediaPath!),
          path: message.interactiveMediaPath,
          size: 0,
        );
      } else {
        content = as.getContent(attachment!);
      }
      if (content is PlatformFile) {
        popDetails();
        await as.saveToDisk(content, isDocument: attachment!.mimeStart != "image" && attachment!.mimeStart != "video");
      }
    } catch (ex, trace) {
      Logger.error("Error downloading attachment: ${ex.toString()}", error: ex, trace: trace);
      showSnackbar("Save Error", ex.toString());
    }
  }

  void openMedia() {
    popDetails();
    if (attachment?.mimeStart == 'image' || attachment?.mimeStart == 'video') {
      Navigator.of(Get.context!).push(
        ThemeSwitcher.buildPageRoute(
          builder: (context) => FullscreenMediaHolder(
            currentChat: cm.activeChat,
            attachment: attachment!,
            showInteractions: true,
          ),
        ),
      );
    }
  }

  void openLink() {
    mcs.invokeMethod("open-browser", {"link": url}); // TODO, part.text was also passed here... understand why.
    popDetails();
  }

  Future<void> openAttachmentWeb() async {
    await launchUrlString("${attachment!.webUrl}?guid=${ss.settings.guidAuthKey}");
    popDetails();
  }

  Future<void> downloadOriginal() async {
    final RxBool downloadingAttachments = true.obs;
    final RxnDouble progress = RxnDouble();
    final Rxn<Attachment> attachmentObs = Rxn<Attachment>();
    final toDownload = [attachment].where((element) =>
        (element!.uti?.contains("heic") ?? false) ||
        (element!.uti?.contains("heif") ?? false) ||
        (element!.uti?.contains("quicktime") ?? false) ||
        (element!.uti?.contains("coreaudio") ?? false) ||
        (element!.uti?.contains("tiff") ?? false));
    final length = toDownload.length;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.theme.colorScheme.properSurface,
        title: Text("Downloading attachment${length > 1 ? "s" : ""}...", style: context.theme.textTheme.titleLarge),
        content: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: <Widget>[
          Obx(
            () => Text(
                '${progress.value != null && attachmentObs.value != null ? (progress.value! * attachmentObs.value!.totalBytes!).getFriendlySize() : ""} / ${(attachmentObs.value!.totalBytes!.toDouble()).getFriendlySize()} (${((progress.value ?? 0) * 100).floor()}%)',
                style: context.theme.textTheme.bodyLarge),
          ),
          const SizedBox(height: 10.0),
          Obx(
            () => ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                backgroundColor: context.theme.colorScheme.outline,
                valueColor: AlwaysStoppedAnimation<Color>(Get.context!.theme.colorScheme.primary),
                value: progress.value,
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(
            height: 15.0,
          ),
          Obx(() => Text(
                progress.value == 1
                    ? "Download Complete!"
                    : "You can close this dialog. The attachment(s) will continue to download in the background.",
                maxLines: 2,
                textAlign: TextAlign.center,
                style: context.theme.textTheme.bodyLarge,
              )),
        ]),
        actions: [
          Obx(
            () => downloadingAttachments.value
                ? Container(height: 0, width: 0)
                : TextButton(
                    child: Text("Close", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                    onPressed: () async {
                      Get.closeAllSnackbars();
                      Navigator.of(context).pop();
                      popDetails();
                    },
                  ),
          ),
        ],
      ),
    );
    try {
      for (Attachment? element in toDownload) {
        attachmentObs.value = element;
        final response = await http.downloadAttachment(element!.guid!,
            original: true, onReceiveProgress: (count, total) => progress.value = kIsWeb ? (count / total) : (count / element.totalBytes!));
        final file = PlatformFile(
          name: element.transferName!,
          size: response.data.length,
          bytes: response.data,
        );

        await as.saveToDisk(file, isDocument: element.mimeStart != "image" && element.mimeStart != "video");
      }
      progress.value = 1;
      downloadingAttachments.value = false;
    } catch (ex, trace) {
      Logger.error("Failed to download original attachment!", error: ex, trace: trace);
      showSnackbar("Download Error", ex.toString());
    }
  }

  Future<void> downloadLivePhoto() async {
    final RxBool downloadingAttachments = true.obs;
    final RxnInt progress = RxnInt();
    final Rxn<Attachment> attachmentObs = Rxn<Attachment>();
    final toDownload = [attachment];
    final length = toDownload.length;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.theme.colorScheme.properSurface,
        title: Text("Downloading live photo${length > 1 ? "s" : ""}...", style: context.theme.textTheme.titleLarge),
        content: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: <Widget>[
          Obx(
            () => Text(
              progress.value?.toDouble().getFriendlySize() ?? "",
              style: context.theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 10.0),
          Obx(
            () => ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                backgroundColor: context.theme.colorScheme.outline,
                valueColor: AlwaysStoppedAnimation<Color>(Get.context!.theme.colorScheme.primary),
                value: downloadingAttachments.value ? null : 1,
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(
            height: 15.0,
          ),
          Obx(() => Text(
                !downloadingAttachments.value
                    ? "Download Complete!"
                    : "You can close this dialog. The live photo(s) will continue to download in the background.",
                maxLines: 2,
                textAlign: TextAlign.center,
                style: context.theme.textTheme.bodyLarge,
              )),
        ]),
        actions: [
          Obx(
            () => downloadingAttachments.value
                ? Container(height: 0, width: 0)
                : TextButton(
                    child: Text("Close", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                    onPressed: () async {
                      Get.closeAllSnackbars();
                      Navigator.of(context).pop();
                      popDetails();
                    },
                  ),
          ),
        ],
      ),
    );
    try {
      for (Attachment? element in toDownload) {
        attachmentObs.value = element;
        final response = await http.downloadLivePhoto(element!.guid!, onReceiveProgress: (count, total) => progress.value = count);
        final nameSplit = element.transferName!.split(".");
        final file = PlatformFile(
          name: "${nameSplit.take(nameSplit.length - 1).join(".")}.mov",
          size: response.data.length,
          bytes: response.data,
        );
        await as.saveToDisk(file, isDocument: true);
      }
      downloadingAttachments.value = false;
    } catch (ex, trace) {
      Logger.error("Failed to download live photo!", error: ex, trace: trace);
      showSnackbar("Download Error", ex.toString());
    }
  }

  void forward() async {
    popDetails();
    List<PlatformFile> attachments = [];
    final _attachments = [attachment]
        .where((e) => as.getContent(e!, autoDownload: false) is PlatformFile)
        .map((e) => as.getContent(e!, autoDownload: false) as PlatformFile);
    for (PlatformFile a in _attachments) {
      Uint8List? bytes = a.bytes;
      bytes ??= await File(a.path!).readAsBytes();
      attachments.add(PlatformFile(
        name: a.name,
        path: a.path,
        size: bytes.length,
        bytes: bytes,
      ));
    }
    if (attachments.isNotEmpty || !isNullOrEmpty(message.text)) {
      ns.pushAndRemoveUntil(
        context,
        ChatCreator(
          initialText: message.text,
          initialAttachments: attachments,
        ),
        (route) => route.isFirst,
      );
    }
  }

  void redownload() {
    if (isEmbeddedMedia) {
      popDetails();
      getActiveMwc(message.guid!)?.updateWidgets<EmbeddedMedia>(null);
    } else {
      // for (Attachment? element in part.attachments) {
      //   // We might actually need the cvController for this if we're going to manipulate imageData
      //   // widget.cvController.imageData.remove(element!.guid!);
      //   // as.redownloadAttachment(element);
      // }
      popDetails();
      getActiveMwc(message.guid!)?.updateWidgets<AttachmentHolder>(null);
    }
  }

  void share() {
    if (!message.isLegacyUrlPreview && attachment != null && !kIsWeb && !kIsDesktop) {
      Share.file(
        "${attachment!.mimeType!.split("/")[0].capitalizeFirst} shared from BlueBubbles: ${attachment!.transferName}",
        attachment!.path,
      );
    } else if (url != null) {
      Share.text(
        "Text shared from BlueBubbles",
        url!,
      );
    }
    popDetails();
  }

  void delete() {
    service.removeMessage(message);
    Message.softDelete(message.guid!);
    popDetails();
  }

  void selectMultiple() {
    if (iOS) {
      selected.add(attachment!.guid!);
    }
    popDetails(returnVal: false);
  }

  void jumpToMessage() {
    final attachmentChat = message.chat.target!;
    final service = ms(attachmentChat.guid);
    service.method = "local";
    service.struct.addMessages([message]);
    ns.pushAndRemoveUntil(
      context,
      ConversationView(
        chat: attachmentChat,
        customService: service,
      ),
      (route) => route.isFirst,
    );
  }

  get _allActions {
    return [
        if ((url != null) && !kIsWeb && !kIsDesktop && !ls.isBubble)
          DetailsMenuActionWidget(
            onTap: openLink,
            action: DetailsMenuAction.OpenInBrowser,
          ),
        if (showDownload && kIsWeb && attachment!.webUrl != null)
          DetailsMenuActionWidget(
            onTap: openAttachmentWeb,
            action: DetailsMenuAction.OpenInNewTab,
          ),
        if (attachment != null && (attachment!.mimeStart == 'image' || attachment!.mimeStart == 'video'))
          DetailsMenuActionWidget(
            onTap: selectMultiple,
            action: DetailsMenuAction.SelectMultiple,
          ),
        if (!ls.isBubble && !message.isInteractive)
          DetailsMenuActionWidget(
            onTap: forward,
            action: DetailsMenuAction.Forward,
          ),
        if (showDownload)
          DetailsMenuActionWidget(
            onTap: download,
            action: DetailsMenuAction.Save,
          ),
        
        if (showDownload &&
            supportsOriginalDownload &&
            ((attachment!.uti?.contains("heic") ?? false) ||
              (attachment!.uti?.contains("heif") ?? false) ||
              (attachment!.uti?.contains("quicktime") ?? false) ||
              (attachment!.uti?.contains("coreaudio") ?? false) ||
              (attachment!.uti?.contains("tiff") ?? false))
          )
          DetailsMenuActionWidget(
            onTap: downloadOriginal,
            action: DetailsMenuAction.SaveOriginal,
          ),
        if (showDownload && attachment!.hasLivePhoto)
          DetailsMenuActionWidget(
            onTap: downloadLivePhoto,
            action: DetailsMenuAction.SaveLivePhoto,
          ),
        if ((attachment != null && !kIsWeb && !kIsDesktop) || (!kIsWeb && !kIsDesktop && !isNullOrEmpty(url)))
          DetailsMenuActionWidget(
            onTap: share,
            action: DetailsMenuAction.Share,
          ),
        DetailsMenuActionWidget(
          onTap: jumpToMessage,
          action: DetailsMenuAction.JumpToMessage,
        ),
        if (showDownload)
          DetailsMenuActionWidget(
            onTap: redownload,
            action: DetailsMenuAction.ReDownloadFromServer,
          ),
        DetailsMenuActionWidget(
          onTap: delete,
          action: DetailsMenuAction.Delete,
        )
      ];
  }

  Widget buildDetailsMenu(BuildContext context) {
    // double maxMenuWidth = min(max(ns.width(widthContext) * 3 / 5, 200), ns.width(widthContext) * 4 / 5);

    List<DetailsMenuActionWidget> allActions = _allActions;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: context.theme.colorScheme.properSurface.withAlpha(150),
          width: maxMenuWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: allActions.cast<CustomDetailsMenuActionWidget>().sublist(0, numberToShow - 1)
              ..add(
                CustomDetailsMenuActionWidget(
                  onTap: () async {
                    Widget content = Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: allActions.sublist(numberToShow - 1),
                    );
                    Get.dialog(
                        ss.settings.skin.value == Skins.iOS
                            ? CupertinoAlertDialog(
                                backgroundColor: context.theme.colorScheme.properSurface,
                                content: content,
                              )
                            : AlertDialog(
                                backgroundColor: context.theme.colorScheme.properSurface,
                                content: content,
                              ),
                        name: 'Popup Menu');
                  },
                  title: 'More...',
                  iosIcon: cupertino.CupertinoIcons.ellipsis,
                  nonIosIcon: Icons.sms, //Icons.more_vert,
                ),
              ),
          ),
        ),
      ),
    );
  }

  List<Widget> buildMaterialDetailsMenu(BuildContext context) {
    List<DetailsMenuActionWidget> allActions = _allActions;

    return [
      ...allActions.slice(0, numberToShow - 1).map((action) {
        bool isDisabled = false;
        if (action.action == DetailsMenuAction.Edit) {
          isDisabled = !((message.dateCreated?.toUtc().isWithin(DateTime.now().toUtc(), minutes: 15) ?? false));
        }
  
        Color color = isDisabled ? context.theme.colorScheme.properOnSurface.withOpacity(0.5) : context.theme.colorScheme.properOnSurface;
        return Padding(
          padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
          child: IconButton(
            icon: Icon(action.nonIosIcon, color: color),
            onPressed: isDisabled ? null : action.onTap,
            tooltip: action.title,
          )
        );
      }),
      Padding(
        padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
        child: PopupMenuButton<int>(
          color: context.theme.colorScheme.properSurface,
          shape: ss.settings.skin.value != Skins.Material ? const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20.0)),
          ) : null,
          onSelected: (int value) {
            allActions[value + numberToShow - 1].onTap?.call();
          },
          itemBuilder: (context) {
            return allActions.slice(numberToShow - 1).mapIndexed((index, action) {
              return PopupMenuItem(
                value: index,
                child: Text(
                  action.title,
                  style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                ),
              );
            }).toList();
          }
        )
      )
    ];
  }
}

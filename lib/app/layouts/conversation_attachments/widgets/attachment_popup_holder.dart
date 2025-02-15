import 'package:bluebubbles/app/layouts/conversation_attachments/widgets/attachment_popup.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_html/html.dart' as html;

class AttachmentPopupHolder extends StatefulWidget {
  AttachmentPopupHolder({
    super.key,
    required this.child,
    required this.message,
    required this.selected,
    this.attachment,
    this.url,
    this.focusNode,
    this.setMaterialDetailsMenu,
  });

  final Widget child;
  final Message message;
  final RxList<String> selected;
  final Attachment? attachment;
  final String? url;
  final FocusNode? focusNode;
  final void Function(Widget)? setMaterialDetailsMenu;

  @override
  OptimizedState createState() => _AttachmentPopupHolderState();
}

class _AttachmentPopupHolderState extends OptimizedState<AttachmentPopupHolder> {
  final GlobalKey globalKey = GlobalKey();

  Message get message => widget.message;
  FocusNode? get focusNode => widget.focusNode;

  Attachment? get attachment => widget.attachment;

  RxList<String> get selected => widget.selected;

  get setMaterialDetailsMenu => widget.setMaterialDetailsMenu;

  bool get returnMaterialActionWidgetsOnly => (setMaterialDetailsMenu != null);
  
  void openPopup() async {
    if (focusNode != null) focusNode!.unfocus();
    HapticFeedback.lightImpact();
    final size = globalKey.currentContext?.size;
    Offset? childPos = (globalKey.currentContext?.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
    if (size == null || childPos == null) return;
    childPos = Offset(childPos.dx - MediaQueryData.fromView(View.of(context)).padding.left - (iOS ? 0 : ns.widthChatListLeft(context)), childPos.dy);
    final tuple = await ss.getServerDetails();
    final version = tuple.item4;
    final minSierra = await ss.isMinSierra;
    final minBigSur = await ss.isMinBigSur;
    if (!iOS) {
      if (attachment != null && attachment!.mimeStart == 'image' || attachment!.mimeStart == "video") {
        selected.add(attachment!.guid!);
      }
      if (returnMaterialActionWidgetsOnly) {
        widget.setMaterialDetailsMenu!(
          AttachmentPopup(
            childPosition: childPos,
            size: size,
            child: widget.child,
            message: widget.message,
            attachment: attachment,
            selected : widget.selected,
            url : widget.url,
            serverDetails: Tuple3(minSierra, minBigSur, version > 100),
            widthContext: () => mounted ? context : null,
            returnMaterialActionWidgetsOnly : true,
          )
        );
      }
      return;
    }

    if (kIsDesktop || kIsWeb) {
      // widget.cvController.showingOverlays = true;
    }
    final result = await Navigator.push(
      iOS ? Get.context! : context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Theme(
              data: ctx.theme.copyWith(
                // in case some components still use legacy theming
                primaryColor: ctx.theme.colorScheme.bubble(ctx, true),
                colorScheme: ctx.theme.colorScheme.copyWith(
                  primary: ctx.theme.colorScheme.bubble(ctx, true),
                  onPrimary: ctx.theme.colorScheme.onBubble(ctx, true),
                  surface: ss.settings.monetTheming.value == Monet.full ? null : (ctx.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
                  onSurface: ss.settings.monetTheming.value == Monet.full ? null : (ctx.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
                ),
              ),
              child: PopupScope(
                child: AttachmentPopup(
                  childPosition: childPos!,
                  size: size,
                  child: widget.child,
                  message: widget.message,
                  attachment: attachment,
                  selected : widget.selected,
                  url : widget.url,
                  serverDetails: Tuple3(minSierra, minBigSur, version > 100),
                  widthContext: () => mounted ? context : null,
                ),
              ),
            ),
          );
        },
        fullscreenDialog: true,
        opaque: false,
        barrierDismissible: true,
      ),
    );
    if (result != false) {
      // selected.clear();
    }
    if (kIsDesktop || kIsWeb) {
      // widget.cvController.showingOverlays = false;
      if (focusNode != null) focusNode!.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: globalKey,
      onDoubleTap: () => openPopup(),
      onLongPress: (){
        if (attachment != null) {
          if (selected.contains(attachment!.guid)) {
            selected.remove(attachment!.guid!);
            return;
          } else if (selected.isNotEmpty && !selected.contains(attachment!.guid)){
            selected.add(attachment!.guid!);
            return;
          }
        }
        openPopup();
      },
      onSecondaryTapUp: (details) async {
        if (!kIsWeb && !kIsDesktop) return;
        if (kIsWeb) {
          (await html.document.onContextMenu.first).preventDefault();
        }
        openPopup();
      },
      child: widget.child,
    );
  }
}

class PopupScope extends InheritedWidget {
  const PopupScope({
    super.key,
    required super.child,
  });

  static PopupScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PopupScope>();
  }

  static PopupScope of(BuildContext context) {
    final PopupScope? result = maybeOf(context);
    assert(result != null, 'No ReplyScope found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(PopupScope oldWidget) => true;
}
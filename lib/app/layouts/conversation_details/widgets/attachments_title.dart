import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/app/layouts/conversation_attachments/conversation_attachments.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';

class AttachmentsTitle extends StatelessWidget {
  final String title;
  final AttachmentTypes attachmentsType;
  final List<Attachment>? attachments;
  final List<Message>? links;
  final Chat chat;

  const AttachmentsTitle({
    super.key,
    required this.title,
    required this.attachmentsType,
    this.attachments,
    this.links,
    required this.chat,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: context.theme.textTheme.bodyMedium!.copyWith(
            color: context.theme.colorScheme.outline,
          ),
        ),
        TextButton(
          child: Text(
            "See More",
            style: context.theme.textTheme.bodyMedium!.copyWith(
              color: context.theme.colorScheme.primary,
            ),
          ),
          onPressed: () {
            // Clear the selected list or perform other actions before navigation
            Navigator.of(context).push(
              ThemeSwitcher.buildPageRoute(
                builder: (context) => ConversationAttachments(
                  chat: chat,
                  attachmentsType: attachmentsType,
                  attachments: attachments,
                  links : links,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

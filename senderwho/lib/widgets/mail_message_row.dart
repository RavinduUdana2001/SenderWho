import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../utils/mail_date.dart';
import 'mail_avatar.dart';

/// The same sender, subject and preview hierarchy in every message list.
class MailMessageRow extends StatelessWidget {
  const MailMessageRow({
    super.key,
    required this.email,
    required this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
  });

  final EmailItem email;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.softFill(context, AppColors.primary)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (selectionMode)
                SizedBox(
                  width: 42,
                  child: Checkbox(
                    value: selected,
                    onChanged: onTap == null ? null : (_) => onTap!(),
                  ),
                )
              else
                MailAvatar(
                  name: email.sender,
                  badge: email.identityStatus == 'SUSPICIOUS'
                      ? Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.error,
                        )
                      : null,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!email.isRead) ...[
                          Icon(Icons.circle, size: 6, color: AppColors.info),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            email.sender.isEmpty ? email.email : email.sender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: email.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  color: AppColors.textFor(context),
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatMailDate(email.date),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            email.subject.isEmpty
                                ? '(No subject)'
                                : email.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textFor(context)),
                          ),
                        ),
                        if (email.hasAttachments)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.attach_file_rounded, size: 15),
                          ),
                      ],
                    ),
                    if (email.snippet.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email.snippet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

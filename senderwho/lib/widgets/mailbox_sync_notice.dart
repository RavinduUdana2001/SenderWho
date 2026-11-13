import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../screens/connected_accounts_screen.dart';
import '../services/senderwho_repository.dart';
import '../utils/user_friendly_error.dart';

/// A sync interruption never replaces the mailbox's already downloaded mail.
class MailboxSyncNotice extends StatelessWidget {
  const MailboxSyncNotice({super.key, this.summary, this.account});
  final DashboardSummary? summary;
  final ConnectedEmailAccount? account;

  @override
  Widget build(BuildContext context) {
    final matches =
        account == null || summary?.connectedAccountId == account?.id;
    final status = matches
        ? summary?.syncStatus ?? account?.syncStatus
        : account?.syncStatus;
    if (status != 'FAILED' && status != 'DISCONNECTED') {
      return const SizedBox.shrink();
    }
    final error = matches
        ? summary?.syncError ?? account?.lastSyncError
        : account?.lastSyncError;
    final recovery = matches
        ? summary?.syncRecoveryAction ?? account?.recoveryAction
        : account?.recoveryAction;
    final retryAt = matches
        ? summary?.syncRetryAt ?? account?.syncRetryAt
        : account?.syncRetryAt;
    final limited = isMailboxRateLimited(error);
    final reconnect =
        !limited &&
        (status == 'DISCONNECTED' ||
            recovery == 'RECONNECT' ||
            account?.needsReconnect == true);
    final scheme = Theme.of(context).colorScheme;
    final title = reconnect ? 'Reconnect your mailbox' : 'Sync paused';
    final message = reconnect
        ? 'Sign in again to resume syncing.'
        : retryAt != null
        ? 'We’ll retry automatically. Your saved mail is available.'
        : limited
        ? 'Gmail is busy. Your saved mail is available. Check sync status to continue later.'
        : mailboxSyncError(error);
    final foreground = reconnect
        ? scheme.onErrorContainer
        : scheme.onSurfaceVariant;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('mailbox-sync-notice'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: reconnect
              ? scheme.errorContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                reconnect ? Icons.link_off_rounded : Icons.schedule_rounded,
                size: 20,
                color: foreground,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: foreground),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'View sync status',
              icon: Icon(Icons.chevron_right_rounded, color: foreground),
              onPressed: () => Navigator.pushNamed(
                context,
                ConnectedAccountsScreen.routeName,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

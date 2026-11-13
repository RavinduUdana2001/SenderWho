import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/email_details_screen.dart';
import '../screens/emails_screen.dart';
import '../services/senderwho_repository.dart';
import '../services/repository_scope.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/section_title.dart';
import '../widgets/mail_list_surface.dart';
import '../widgets/mail_message_row.dart';
import '../widgets/mail_avatar.dart';

class SenderDetailsScreen extends StatefulWidget {
  const SenderDetailsScreen({super.key, this.repository, this.senderId});

  static const routeName = '/sender-details';

  final SenderWhoRepository? repository;
  final String? senderId;

  @override
  State<SenderDetailsScreen> createState() => _SenderDetailsScreenState();
}

class _SenderDetailsScreenState extends State<SenderDetailsScreen> {
  int tab = 0;
  Future<SenderDetails>? _detailsFuture;
  String? _senderId;
  bool _mutating = false;

  SenderWhoRepository get _repository =>
      widget.repository ?? RepositoryScope.read(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_detailsFuture != null) return;
    _senderId =
        widget.senderId ??
        ModalRoute.of(context)?.settings.arguments as String?;
    if (_senderId?.isNotEmpty == true) {
      _detailsFuture = _repository.getSenderDetails(_senderId!);
    }
  }

  void _reload() {
    final senderId = _senderId;
    if (senderId == null || senderId.isEmpty) return;
    setState(() {
      _detailsFuture = _repository.getSenderDetails(senderId);
    });
  }

  Future<void> _openEmail(EmailItem email) async {
    await Navigator.pushNamed<dynamic>(
      context,
      EmailDetailsScreen.routeName,
      arguments: email,
    );
    if (mounted) _reload();
  }

  Future<void> _updateSender(
    SenderInfo sender, {
    bool? blocked,
    bool? trusted,
  }) async {
    if (_mutating) return;
    if (blocked == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Block this sender?'),
          content: const Text(
            'SenderWho will mark this sender as blocked. New messages found during inbox scans will be moved to Trash.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Block'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _mutating = true);
    final succeeded = blocked != null
        ? await _repository.setSenderBlocked(sender.id, blocked)
        : await _repository.setSenderTrusted(sender.id, trusted!);
    if (!mounted) return;
    setState(() {
      _mutating = false;
      if (succeeded) {
        _detailsFuture = _repository.getSenderDetails(sender.id);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? trusted == true
                    ? '${sender.name} is now trusted.'
                    : trusted == false
                    ? '${sender.name} is no longer trusted.'
                    : 'Sender preference updated.'
              : _repository.lastError ??
                    'Could not update this sender. Please try again.',
        ),
      ),
    );
  }

  Future<void> _unsubscribeSender(SenderInfo sender) async {
    if (_mutating) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Unsubscribe from ${sender.name}?'),
        content: Text(
          'SenderWho will ask ${sender.email} to stop future recurring email. '
          'Existing messages will stay in your mailbox.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.unsubscribe_rounded),
            label: const Text('Unsubscribe'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _mutating = true);
    final result = await _repository.createUnsubscribeJob(sender.id);
    if (!mounted) return;
    setState(() => _mutating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? _repository.lastError ?? 'Unsubscribe could not be started.'
              : 'Unsubscribe request queued. Existing messages were not deleted.',
        ),
      ),
    );
  }

  Future<void> _deleteAllFromSender(SenderInfo sender) async {
    if (_mutating || sender.totalMessages == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Move all emails from this sender to Trash?'),
        content: Text(
          'This will move up to ${sender.totalMessages} email message'
          '${sender.totalMessages == 1 ? '' : 's'} from ${sender.name} '
          '(${sender.email}) to Trash. It will not block or unsubscribe from '
          'the sender, and it is not permanent deletion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Move all to Trash'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _mutating = true);
    final result = await _repository.applyEmailActionToAllMatching(
      'trash',
      mailbox: 'ALL',
      senderId: sender.id,
    );
    if (!mounted) return;
    setState(() {
      _mutating = false;
      _detailsFuture = _repository.getSenderDetails(sender.id);
    });
    final message = result == null
        ? _repository.lastError ?? 'The emails could not be moved to Trash.'
        : result.failed == 0
        ? '${result.processed} email message${result.processed == 1 ? '' : 's'} moved to Trash.'
        : '${result.processed} moved to Trash; ${result.failed} failed. Try again for the remaining messages.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SenderDetails>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        final details = snapshot.data;
        if (details == null) {
          return AppPage(
            header: const AppHeader(title: 'Sender Details', showBack: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: context.gap(16)),
                if (_detailsFuture == null)
                  const Text('Select a sender to see email message details.')
                else if (snapshot.hasError)
                  AppCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          color: AppColors.danger,
                        ),
                        const SizedBox(height: 10),
                        const Text('Sender details could not be loaded.'),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                else
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          );
        }
        final sender = details.sender;
        final visibleMessages = switch (tab) {
          1 => details.messages.where((message) => !message.isRead).toList(),
          2 => details.messages.where((message) => message.isRead).toList(),
          _ => details.messages,
        };

        return AppPage(
          header: const AppHeader(title: 'Sender Details', showBack: true),
          plainBackground: true,
          maxContentWidth: 1100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: context.gap(16)),
              _SenderProfileCard(sender: sender),
              const SizedBox(height: 12),
              _SenderActions(
                sender: sender,
                busy: _mutating,
                onTrust: () =>
                    _updateSender(sender, trusted: !sender.isTrusted),
                onBlock: () =>
                    _updateSender(sender, blocked: !sender.isBlocked),
                onUnsubscribe: () => _unsubscribeSender(sender),
                onDeleteAll: () => _deleteAllFromSender(sender),
              ),
              if (_mutating) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ],
              const SizedBox(height: 16),
              SectionTitle(
                title: 'Messages',
                actionLabel: 'View all ${sender.totalMessages}',
                onAction: () => _viewAllMessages(context, sender),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final label in ['All Emails', 'Unread', 'Read']) ...[
                    Expanded(
                      child: MailFilterTab(
                        label: label,
                        selected:
                            tab ==
                            ['All Emails', 'Unread', 'Read'].indexOf(label),
                        onTap: () => setState(
                          () => tab = [
                            'All Emails',
                            'Unread',
                            'Read',
                          ].indexOf(label),
                        ),
                      ),
                    ),
                    if (label != 'Read') const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              MailListSurface(
                child: Column(
                  children: [
                    if (visibleMessages.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No messages in this filter.'),
                      ),
                    for (var i = 0; i < visibleMessages.length; i++) ...[
                      _EmailLine(
                        email: visibleMessages[i],
                        onTap: () => _openEmail(visibleMessages[i]),
                      ),
                      if (i != visibleMessages.length - 1)
                        const Divider(height: 1, indent: 20, endIndent: 20),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                key: const ValueKey('sender-information'),
                title: const Text('About this sender'),
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                children: [
                  _InfoLine(
                    icon: Icons.calendar_today_outlined,
                    label: 'First seen',
                    value: _formatFirstSeen(details.firstSeen),
                  ),
                  _InfoLine(
                    icon: Icons.category_outlined,
                    label: 'Type',
                    value: _displayValue(details.type),
                  ),
                  _InfoLine(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: _displayValue(details.location),
                  ),
                  _InfoLine(
                    icon: Icons.shield_outlined,
                    label: 'Sender confidence',
                    value: '${sender.score} / 100',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewAllMessages(BuildContext context, SenderInfo sender) {
    Navigator.pushNamed(
      context,
      EmailsScreen.routeName,
      arguments: EmailListArguments(
        mailbox: 'ALL',
        senderId: sender.id,
        title: sender.name,
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.softFill(context, AppColors.primary),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryFor(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailLine extends StatelessWidget {
  const _EmailLine({required this.email, required this.onTap});
  final EmailItem email;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) =>
      MailMessageRow(email: email, onTap: email.id.isEmpty ? null : onTap);
}

class _SenderProfileCard extends StatelessWidget {
  const _SenderProfileCard({required this.sender});

  final SenderInfo sender;

  @override
  Widget build(BuildContext context) {
    final suspicious = sender.identityStatus == 'SUSPICIOUS';
    final identityLabel = sender.isBlocked
        ? 'Blocked sender'
        : suspicious
        ? sender.identityRiskLevel == 'HIGH'
              ? 'High-risk sender identity'
              : 'Possible sender impersonation'
        : sender.identityStatus == 'VERIFIED'
        ? 'Sender identity confirmed'
        : 'Unable to verify sender';
    final color = sender.isBlocked || suspicious
        ? AppColors.foregroundFor(context, AppColors.danger)
        : AppColors.mutedFor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MailAvatar(name: sender.name),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                sender.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SelectableText(
          sender.email,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              suspicious ? Icons.warning_amber_rounded : Icons.shield_outlined,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                identityLabel,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SenderActions extends StatelessWidget {
  const _SenderActions({
    required this.sender,
    required this.busy,
    required this.onTrust,
    required this.onBlock,
    required this.onUnsubscribe,
    required this.onDeleteAll,
  });

  final SenderInfo sender;
  final bool busy;
  final VoidCallback onTrust;
  final VoidCallback onBlock;
  final VoidCallback onUnsubscribe;
  final VoidCallback onDeleteAll;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 0,
      children: [
        TextButton.icon(
          onPressed: busy ? null : onTrust,
          icon: Icon(
            sender.isTrusted ? Icons.verified_rounded : Icons.verified_outlined,
            size: 17,
          ),
          label: Text(sender.isTrusted ? 'Untrust' : 'Trust sender'),
        ),
        TextButton.icon(
          onPressed: busy ? null : onBlock,
          icon: Icon(
            sender.isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
            size: 17,
          ),
          label: Text(sender.isBlocked ? 'Unblock' : 'Block sender'),
        ),
        TextButton.icon(
          onPressed: busy ? null : onUnsubscribe,
          icon: const Icon(Icons.unsubscribe_outlined, size: 17),
          label: const Text('Unsubscribe'),
        ),
        TextButton.icon(
          onPressed: busy || sender.totalMessages == 0 ? null : onDeleteAll,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 17),
          label: const Text('Move all to Trash'),
        ),
      ],
    );
  }
}

String _formatFirstSeen(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return _displayValue(value);
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
}

String _displayValue(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'[_-]+'), ' ');
  if (normalized.isEmpty) return 'Not available';
  return normalized
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

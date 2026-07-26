import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/email_details_screen.dart';
import '../screens/emails_screen.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chips.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/section_title.dart';

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
      widget.repository ?? senderWhoRepository;

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
    final changed = await Navigator.pushNamed<dynamic>(
      context,
      EmailDetailsScreen.routeName,
      arguments: email.id,
    );
    if (changed == true && mounted) _reload();
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
          title: const Text('Block this sender?'),
          content: const Text(
            'SenderWho will mark this sender as blocked. New messages found during Gmail scans will be moved to Trash.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SenderDetails>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        final details = snapshot.data;
        if (details == null) {
          return AppPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppHeader(title: 'Sender Details', showBack: true),
                SizedBox(height: context.gap(25)),
                if (_detailsFuture == null)
                  const Text('Select a sender to see Gmail message details.')
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppHeader(title: 'Sender Details', showBack: true),
              SizedBox(height: context.gap(18)),
              _SenderProfileCard(sender: sender),
              const SizedBox(height: 12),
              _SenderActions(
                sender: sender,
                busy: _mutating,
                onTrust: () =>
                    _updateSender(sender, trusted: !sender.isTrusted),
                onBlock: () =>
                    _updateSender(sender, blocked: !sender.isBlocked),
              ),
              SizedBox(height: context.gap(25)),
              const SectionTitle(title: 'About this sender'),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _InfoLine(
                      icon: Icons.calendar_today_outlined,
                      label: 'First seen',
                      value: _formatFirstSeen(details.firstSeen),
                    ),
                    const Divider(height: 1),
                    _InfoLine(
                      icon: Icons.mail_outline_rounded,
                      label: 'Emails received',
                      value: '${sender.totalMessages}',
                    ),
                    const Divider(height: 1),
                    _InfoLine(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: _displayValue(details.location),
                    ),
                    const Divider(height: 1),
                    _InfoLine(
                      icon: Icons.category_outlined,
                      label: 'Type',
                      value: _displayValue(details.type),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.gap(25)),
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
                      child: SelectablePill(
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
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
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

String _trustLabel(int score) {
  if (score >= 90) return 'Very High';
  if (score >= 75) return 'High';
  if (score >= 50) return 'Medium';
  return 'Low';
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
            child: Icon(icon, size: 18, color: AppColors.primary),
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: email.id.isEmpty ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    email.sender,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(email.date, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              email.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            Text(
              email.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SenderProfileCard extends StatelessWidget {
  const _SenderProfileCard({required this.sender});

  final SenderInfo sender;

  @override
  Widget build(BuildContext context) {
    final score = sender.score.clamp(0, 100);
    final trustColor = score >= 75
        ? AppColors.primary
        : score >= 50
        ? AppColors.indigo
        : AppColors.mutedFor(context);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.brandGradient,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Text(
                  sender.initial,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sender.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sender.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusChip(
                          label: _displayValue(sender.category),
                          color: AppColors.primary,
                        ),
                        if (sender.isTrusted)
                          const StatusChip(
                            label: 'Trusted',
                            color: AppColors.primary,
                          ),
                        if (sender.isBlocked)
                          const StatusChip(
                            label: 'Blocked',
                            color: AppColors.danger,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.softFill(context, trustColor),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: trustColor.withValues(alpha: 0.16)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 20, color: trustColor),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sender confidence',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            '${_trustLabel(score)} trust',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$score / 100',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: trustColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: score / 100,
                    color: trustColor,
                    backgroundColor: AppColors.trackFor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SenderActions extends StatelessWidget {
  const _SenderActions({
    required this.sender,
    required this.busy,
    required this.onTrust,
    required this.onBlock,
  });

  final SenderInfo sender;
  final bool busy;
  final VoidCallback onTrust;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trustButton = _SenderActionButton(
          label: sender.isTrusted ? 'Untrust' : 'Trust sender',
          icon: sender.isTrusted
              ? Icons.verified_rounded
              : Icons.verified_outlined,
          color: AppColors.primary,
          onPressed: busy ? null : onTrust,
        );
        final blockButton = _SenderActionButton(
          label: sender.isBlocked ? 'Unblock' : 'Block sender',
          icon: sender.isBlocked
              ? Icons.lock_open_rounded
              : Icons.block_rounded,
          color: sender.isBlocked ? AppColors.primary : AppColors.danger,
          onPressed: busy ? null : onBlock,
        );
        if (constraints.maxWidth < 330) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: trustButton),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: blockButton),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: trustButton),
            const SizedBox(width: 10),
            Expanded(child: blockButton),
          ],
        );
      },
    );
  }
}

class _SenderActionButton extends StatelessWidget {
  const _SenderActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        backgroundColor: AppColors.softFill(context, color),
        foregroundColor: color,
        disabledBackgroundColor: AppColors.trackFor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(icon, size: 19),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
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

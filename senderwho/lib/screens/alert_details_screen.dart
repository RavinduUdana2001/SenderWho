import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/block_senders_screen.dart';
import '../screens/email_details_screen.dart';
import '../screens/emails_screen.dart';
import '../screens/sender_details_screen.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_chips.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/icon_bubble.dart';
import '../widgets/section_title.dart';

IconData _evidenceIcon(String code) {
  if (code.contains('BRAND') || code.contains('LOOKALIKE')) {
    return Icons.badge_outlined;
  }
  if (code.contains('REPLY') || code.contains('RETURN_PATH')) {
    return Icons.reply_all_rounded;
  }
  if (code.contains('SPF') ||
      code.contains('DKIM') ||
      code.contains('DMARC') ||
      code.contains('AUTH')) {
    return Icons.gpp_maybe_outlined;
  }
  return Icons.warning_amber_rounded;
}

class AlertDetailsScreen extends StatefulWidget {
  const AlertDetailsScreen({super.key, this.repository});

  static const routeName = '/alert-details';
  final SenderWhoRepository? repository;

  @override
  State<AlertDetailsScreen> createState() => _AlertDetailsScreenState();
}

class _AlertDetailsScreenState extends State<AlertDetailsScreen> {
  AlertItem? _seed;
  Future<AlertItem>? _alertFuture;
  bool _initialized = false;
  bool _busy = false;

  SenderWhoRepository get _repository =>
      widget.repository ?? senderWhoRepository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    _seed = arguments is AlertItem ? arguments : null;
    _loadDetails();
  }

  void _loadDetails() {
    final alert = _seed;
    if (alert == null || alert.id.isEmpty) return;
    _alertFuture = _repository.getSecurityAlert(alert.id);
  }

  Future<void> _setAlertStatus({required bool dismiss}) async {
    final alert = _seed;
    if (_busy || alert == null || alert.id.isEmpty) return;
    if (dismiss) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dismiss this alert?'),
          content: const Text(
            'Dismiss only if you reviewed the sender and no longer need this warning.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Dismiss alert'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _busy = true);
    final changed = dismiss
        ? await _repository.dismissSecurityAlert(alert.id)
        : await _repository.resolveSecurityAlert(alert.id);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          changed
              ? dismiss
                    ? 'Security alert dismissed.'
                    : 'Security alert marked as resolved.'
              : _repository.lastError ??
                    'Could not update this security alert.',
        ),
      ),
    );
    if (changed) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final alert = _seed;

    if (alert == null) {
      return AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppHeader(title: 'Alert Details', showBack: true),
            SizedBox(height: context.gap(25)),
            Text(
              'Select a security alert to view its real Gmail details.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return FutureBuilder<AlertItem>(
      future: _alertFuture,
      initialData: alert,
      builder: (context, snapshot) {
        final loadedAlert = snapshot.data ?? alert;
        _seed = loadedAlert;
        return AppPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeader(
                title: 'Alert Details',
                subtitle: loadedAlert.time,
                showBack: true,
              ),
              SizedBox(height: context.gap(18)),
              if (snapshot.connectionState == ConnectionState.waiting) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 12),
              ],
              if (snapshot.hasError) ...[
                AppAsyncError(
                  title: 'Could not refresh alert details',
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: () => setState(_loadDetails),
                ),
                const SizedBox(height: 12),
              ],
              AppCard(
                padding: const EdgeInsets.all(20),
                color: AppColors.softFill(context, loadedAlert.color),
                borderColor: loadedAlert.color.withValues(alpha: 0.22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBubble(
                          icon: Icons.report_gmailerrorred_outlined,
                          color: loadedAlert.color,
                        ),
                        const SizedBox(width: 14),
                        const Spacer(),
                        StatusChip(
                          label: loadedAlert.risk,
                          color: loadedAlert.color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loadedAlert.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loadedAlert.email,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      loadedAlert.reason,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              if (loadedAlert.senderId.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      SenderDetailsScreen.routeName,
                      arguments: loadedAlert.senderId,
                    ),
                    icon: const Icon(Icons.person_search_rounded),
                    label: const Text('View sender profile'),
                  ),
                ),
              ],
              SizedBox(height: context.gap(22)),
              const SectionTitle(title: 'Alert information'),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    _AlertInfoLine(
                      icon: Icons.alternate_email_rounded,
                      label: 'Sender email',
                      value: loadedAlert.email,
                    ),
                    Divider(color: AppColors.borderFor(context)),
                    _AlertInfoLine(
                      icon: Icons.schedule_rounded,
                      label: 'Detected',
                      value: loadedAlert.time,
                    ),
                    Divider(color: AppColors.borderFor(context)),
                    _AlertInfoLine(
                      icon: Icons.gpp_maybe_outlined,
                      label: 'Risk level',
                      value: loadedAlert.risk,
                      valueColor: loadedAlert.color,
                    ),
                    if (loadedAlert.claimedBrand?.isNotEmpty == true) ...[
                      Divider(color: AppColors.borderFor(context)),
                      _AlertInfoLine(
                        icon: Icons.badge_outlined,
                        label: 'Claimed identity',
                        value: loadedAlert.claimedBrand!,
                      ),
                    ],
                    if (loadedAlert.authenticatedDomain?.isNotEmpty ==
                        true) ...[
                      Divider(color: AppColors.borderFor(context)),
                      _AlertInfoLine(
                        icon: Icons.verified_user_outlined,
                        label: 'Authenticated domain',
                        value: loadedAlert.authenticatedDomain!,
                      ),
                    ],
                    if (loadedAlert.replyToEmail?.isNotEmpty == true) ...[
                      Divider(color: AppColors.borderFor(context)),
                      _AlertInfoLine(
                        icon: Icons.reply_rounded,
                        label: 'Reply-to address',
                        value: loadedAlert.replyToEmail!,
                      ),
                    ],
                    Divider(color: AppColors.borderFor(context)),
                    _AlertInfoLine(
                      icon: Icons.analytics_outlined,
                      label: 'Identity risk score',
                      value: '${loadedAlert.identityRiskScore}/100',
                      valueColor: loadedAlert.color,
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.gap(22)),
              const SectionTitle(title: 'Why this was flagged'),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                child: Column(
                  children: loadedAlert.identityEvidence.isEmpty
                      ? [
                          _ReasonLine(
                            icon: Icons.security_rounded,
                            text: loadedAlert.reason,
                          ),
                        ]
                      : [
                          for (
                            var index = 0;
                            index < loadedAlert.identityEvidence.length;
                            index++
                          ) ...[
                            _ReasonLine(
                              icon: _evidenceIcon(
                                loadedAlert.identityEvidence[index].code,
                              ),
                              text: loadedAlert.identityEvidence[index].detail,
                            ),
                            if (index !=
                                loadedAlert.identityEvidence.length - 1)
                              Divider(color: AppColors.borderFor(context)),
                          ],
                        ],
                ),
              ),
              SizedBox(height: context.gap(22)),
              const SectionTitle(title: 'Recommended action'),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Avoid links or attachments until you recognize this sender. Review related messages before blocking or resolving the alert.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _AlertActionButton(
                        icon: Icons.manage_search_rounded,
                        label: 'Review',
                        color: AppColors.primary,
                        onTap: () {
                          if (_busy ||
                              (loadedAlert.messageId.isEmpty &&
                                  loadedAlert.senderId.isEmpty)) {
                            return;
                          }
                          if (loadedAlert.messageId.isNotEmpty) {
                            Navigator.pushNamed(
                              context,
                              EmailDetailsScreen.routeName,
                              arguments: loadedAlert.messageId,
                            );
                            return;
                          }
                          Navigator.pushNamed(
                            context,
                            EmailsScreen.routeName,
                            arguments: EmailListArguments(
                              mailbox: 'ALL',
                              senderId: loadedAlert.senderId,
                              title: loadedAlert.email.isEmpty
                                  ? 'Related Emails'
                                  : loadedAlert.email,
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: _AlertActionButton(
                        icon: Icons.block_outlined,
                        label: 'Block',
                        color: AppColors.danger,
                        onTap: () {
                          if (_busy || loadedAlert.senderId.isEmpty) return;
                          Navigator.pushNamed(
                            context,
                            BlockSendersScreen.routeName,
                            arguments: {
                              'senderId': loadedAlert.senderId,
                              'email': loadedAlert.email,
                            },
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: _AlertActionButton(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Resolve',
                        color: AppColors.success,
                        onTap: _busy
                            ? () {}
                            : () => _setAlertStatus(dismiss: false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _setAlertStatus(dismiss: true),
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.notifications_off_outlined),
                  label: Text(_busy ? 'Updating alert…' : 'Dismiss alert'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AlertInfoLine extends StatelessWidget {
  const _AlertInfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mutedFor(context)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w600,
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

class _AlertActionButton extends StatelessWidget {
  const _AlertActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.softFill(context, color),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _ReasonLine extends StatelessWidget {
  const _ReasonLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

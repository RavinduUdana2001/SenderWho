import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chips.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/section_title.dart';
import 'sender_details_screen.dart';

class EmailDetailsScreen extends StatefulWidget {
  const EmailDetailsScreen({super.key, this.repository});

  static const routeName = '/email-details';

  final SenderWhoRepository? repository;

  @override
  State<EmailDetailsScreen> createState() => _EmailDetailsScreenState();
}

class _EmailDetailsScreenState extends State<EmailDetailsScreen> {
  EmailItem? _email;
  List<EmailItem> _thread = const [];
  EmailContent? _content;
  bool _contentLoading = false;
  String? _contentError;
  bool _initialized = false;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  String? _error;
  String? _id;

  SenderWhoRepository get _repository =>
      widget.repository ?? senderWhoRepository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    _id = arguments is EmailItem ? arguments.id : arguments as String?;
    if (arguments is EmailItem) _email = arguments;
    _load();
  }

  Future<void> _load() async {
    final id = _id;
    if (id == null || id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No Gmail message was selected.';
      });
      return;
    }
    setState(() => _loading = true);
    final thread = await _repository.getEmailThread(id);
    EmailItem? email;
    if (thread != null) {
      for (final item in thread.items) {
        if (item.id == id) {
          email = item;
          break;
        }
      }
      email ??= thread.items.isNotEmpty ? thread.items.last : null;
    }
    email ??= await _repository.getEmail(id);
    if (!mounted) return;
    final resolvedEmail = email ?? _email;
    setState(() {
      _loading = false;
      _email = resolvedEmail;
      _thread = thread?.items ?? (email == null ? const [] : [email]);
      _error = email == null
          ? _repository.lastError ?? 'Message details could not be loaded.'
          : null;
    });
    if (resolvedEmail != null) await _loadContent(resolvedEmail.id);
  }

  void _selectThreadMessage(EmailItem email) {
    if (_busy) return;
    setState(() {
      _email = email;
      _id = email.id;
    });
    _loadContent(email.id);
  }

  Future<void> _loadContent(String id) async {
    setState(() {
      _contentLoading = true;
      _content = null;
      _contentError = null;
    });
    final content = await _repository.getEmailContent(id);
    if (!mounted || _id != id) return;
    setState(() {
      _contentLoading = false;
      _content = content;
      _contentError = content == null
          ? _repository.lastError ??
                'The full Gmail message could not be loaded.'
          : null;
    });
  }

  Future<void> _act(String action, {bool? isRead}) async {
    final email = _email;
    if (email == null || _busy) return;
    if (action == 'trash') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Move this email to Trash?'),
          content: const Text(
            'The message will be moved to Gmail Trash and can be restored later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Move to Trash'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _busy = true);
    final result = await _repository.applyEmailAction(action, [
      email.id,
    ], isRead: isRead);
    if (!mounted) return;
    setState(() => _busy = false);
    final succeeded = result?.processed == 1;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? 'Gmail message updated.'
              : _repository.lastError ??
                    'The Gmail action failed. Please retry.',
        ),
      ),
    );
    if (succeeded) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _unsubscribe() async {
    final email = _email;
    final senderId = email?.senderId;
    if (senderId == null || senderId.isEmpty || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unsubscribe from ${email?.sender ?? 'this sender'}?'),
        content: Text(
          'SenderWho will send a verified one-click unsubscribe request for ${email?.email ?? 'this sender'}. Existing Gmail messages will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unsubscribe'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final job = await _repository.createUnsubscribeJob(senderId);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          job == null
              ? 'One-click unsubscribe could not be started.'
              : 'One-click unsubscribe started. You can monitor it from Unsubscribe.',
        ),
      ),
    );
  }

  void _leaveDetails() {
    final changed = _changed;
    if (_changed) setState(() => _changed = false);
    Navigator.pop(context, changed);
  }

  @override
  Widget build(BuildContext context) {
    final email = _email;
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leaveDetails();
      },
      child: AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppHeader(
              title: 'Message',
              subtitle: email?.date,
              showBack: true,
              onBack: _leaveDetails,
            ),
            SizedBox(height: context.gap(18)),
            if (_loading && email == null)
              const _MessageDetailsSkeleton()
            else if (email == null)
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.softFill(context, AppColors.danger),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.mail_lock_outlined,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(_error ?? 'Message not available.'),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else ...[
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusChip(
                          label: email.category,
                          color: AppColors.indigo,
                        ),
                        const Spacer(),
                        if (!email.isRead)
                          const StatusChip(
                            label: 'New message',
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      email.subject,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 18),
                    Divider(color: AppColors.borderFor(context)),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: email.senderId?.isNotEmpty == true
                          ? () => Navigator.pushNamed(
                              context,
                              SenderDetailsScreen.routeName,
                              arguments: email.senderId,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.softFill(
                                  context,
                                  AppColors.primary,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                email.sender.isEmpty
                                    ? '?'
                                    : email.sender[0].toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    email.sender,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (email.senderId?.isNotEmpty == true) ...[
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'View sender',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 3),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 19,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        StatusChip(
                          label: email.isRead ? 'Read' : 'Unread',
                          color: email.isRead
                              ? AppColors.mutedFor(context)
                              : AppColors.primary,
                        ),
                        StatusChip(
                          label: email.category,
                          color: AppColors.indigo,
                        ),
                        if (email.isArchived)
                          const StatusChip(
                            label: 'Archived',
                            color: AppColors.success,
                          ),
                        if (email.isTrashed)
                          const StatusChip(
                            label: 'Trash',
                            color: AppColors.danger,
                          ),
                        if (email.hasAttachments)
                          const StatusChip(
                            label: 'Attachment',
                            color: AppColors.warning,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Delivered to ${email.accountEmail}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.gap(22)),
              const SectionTitle(title: 'Selected message'),
              const SizedBox(height: 10),
              _SelectedMessageContent(
                email: email,
                content: _content,
                loading: _contentLoading,
                error: _contentError,
                onRetry: () => _loadContent(email.id),
              ),
              SizedBox(height: context.gap(22)),
              SectionTitle(
                title:
                    'Conversation · ${_thread.isEmpty ? 1 : _thread.length} message${(_thread.isEmpty ? 1 : _thread.length) == 1 ? '' : 's'}',
              ),
              const SizedBox(height: 10),
              for (final threadMessage
                  in (_thread.isEmpty ? <EmailItem>[email] : _thread)) ...[
                _ConversationMessageCard(
                  message: threadMessage,
                  selected: threadMessage.id == email.id,
                  onTap: () => _selectThreadMessage(threadMessage),
                ),
                const SizedBox(height: 10),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.trackFor(context),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 17,
                      color: AppColors.mutedFor(context),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'SenderWho stores Gmail metadata and a short preview—not the full message body. Actions below apply to the selected message.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.gap(22)),
              const SectionTitle(title: 'Gmail actions'),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _MessageActionButton(
                        icon: email.isRead
                            ? Icons.mark_email_unread_outlined
                            : Icons.mark_email_read_outlined,
                        label: email.isRead ? 'Unread' : 'Read',
                        onTap: _busy
                            ? null
                            : () => _act('read-state', isRead: !email.isRead),
                      ),
                    ),
                    if (!email.isTrashed) ...[
                      Container(
                        width: 1,
                        height: 38,
                        color: AppColors.borderFor(context),
                      ),
                      Expanded(
                        child: _MessageActionButton(
                          icon: email.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          label: email.isArchived ? 'Inbox' : 'Archive',
                          onTap: _busy
                              ? null
                              : () => _act(
                                  email.isArchived ? 'unarchive' : 'archive',
                                ),
                        ),
                      ),
                    ],
                    Container(
                      width: 1,
                      height: 38,
                      color: AppColors.borderFor(context),
                    ),
                    Expanded(
                      child: _MessageActionButton(
                        icon: email.isTrashed
                            ? Icons.restore_from_trash_outlined
                            : Icons.delete_outline_rounded,
                        label: email.isTrashed ? 'Restore' : 'Trash',
                        color: email.isTrashed
                            ? AppColors.primary
                            : AppColors.danger,
                        onTap: _busy
                            ? null
                            : () => _act(email.isTrashed ? 'restore' : 'trash'),
                      ),
                    ),
                  ],
                ),
              ),
              if (email.canUnsubscribe && !email.isTrashed) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _unsubscribe,
                    icon: const Icon(Icons.unsubscribe_rounded),
                    label: const Text('Unsubscribe from this sender'),
                  ),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectedMessageContent extends StatelessWidget {
  const _SelectedMessageContent({
    required this.email,
    required this.content,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final EmailItem email;
  final EmailContent? content;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = content;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading) ...[
            const LinearProgressIndicator(
              minHeight: 2,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading this message securely from Gmail…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ] else if (message == null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 20,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        error ?? 'Full message unavailable.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 9),
                      Text(
                        email.snippet.isEmpty
                            ? 'No stored preview is available.'
                            : email.snippet,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try loading again'),
            ),
          ] else ...[
            _MessageHeaderLine(label: 'From', value: message.from),
            _MessageHeaderLine(label: 'To', value: message.to),
            if (message.cc.isNotEmpty)
              _MessageHeaderLine(label: 'Cc', value: message.cc),
            if (message.date.isNotEmpty)
              _MessageHeaderLine(label: 'Date', value: message.date),
            const SizedBox(height: 12),
            Divider(color: AppColors.borderFor(context)),
            const SizedBox(height: 14),
            SelectableText(
              message.bodyText.isEmpty
                  ? 'This Gmail message does not contain a readable text body.'
                  : message.bodyText,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.55),
            ),
            if (message.truncated) ...[
              const SizedBox(height: 12),
              const StatusChip(
                label: 'Long message shortened for display',
                color: AppColors.warning,
              ),
            ],
            if (message.attachments.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Attachments',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final attachment in message.attachments)
                    Chip(
                      avatar: const Icon(Icons.attach_file_rounded, size: 16),
                      label: Text(
                        '${attachment.filename} · ${_formatAttachmentSize(attachment.sizeBytes)}',
                      ),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MessageHeaderLine extends StatelessWidget {
  const _MessageHeaderLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

String _formatAttachmentSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _ConversationMessageCard extends StatelessWidget {
  const _ConversationMessageCard({
    required this.message,
    required this.selected,
    required this.onTap,
  });

  final EmailItem message;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = message.sender.trim().isEmpty
        ? '?'
        : message.sender.trim()[0].toUpperCase();
    return AppCard(
      onTap: onTap,
      borderColor: selected ? AppColors.primary.withValues(alpha: 0.55) : null,
      color: selected ? AppColors.softFill(context, AppColors.primary) : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.softFill(context, AppColors.primary),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.date,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 5),
                  if (!message.isRead)
                    const StatusChip(label: 'Unread', color: AppColors.primary),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message.subject,
            maxLines: selected ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            message.snippet.isEmpty
                ? 'No preview was included in this Gmail message metadata.'
                : message.snippet,
            maxLines: selected ? 6 : 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (selected) ...[
            const SizedBox(height: 10),
            Text(
              'Selected · Delivered to ${message.accountEmail}',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageActionButton extends StatelessWidget {
  const _MessageActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
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
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: onTap == null ? AppColors.mutedFor(context) : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageDetailsSkeleton extends StatelessWidget {
  const _MessageDetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailSkeletonLine(width: 92),
              const SizedBox(height: 18),
              const _DetailSkeletonLine(height: 16),
              const SizedBox(height: 9),
              const _DetailSkeletonLine(width: 220, height: 16),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.trackFor(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: _DetailSkeletonLine()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppCard(
          child: Column(
            children: const [
              _DetailSkeletonLine(),
              SizedBox(height: 10),
              _DetailSkeletonLine(),
              SizedBox(height: 10),
              _DetailSkeletonLine(width: 190),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailSkeletonLine extends StatelessWidget {
  const _DetailSkeletonLine({this.width, this.height = 10});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.trackFor(context),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

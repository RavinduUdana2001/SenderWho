import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../utils/mail_date.dart';
import '../services/senderwho_repository.dart';
import '../services/repository_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chips.dart';
import '../widgets/app_header.dart';
import '../widgets/mail_avatar.dart';
import '../widgets/mail_message_row.dart';
import '../widgets/app_page.dart';
import 'sender_details_screen.dart';

class EmailDetailsScreen extends StatefulWidget {
  const EmailDetailsScreen({super.key, this.repository});

  static const routeName = '/email-details';

  final SenderWhoRepository? repository;

  @override
  State<EmailDetailsScreen> createState() => _EmailDetailsScreenState();
}

class _EmailDetailsScreenState extends State<EmailDetailsScreen>
    with WidgetsBindingObserver {
  static const _automaticReadDelay = Duration(seconds: 2);

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
  Timer? _automaticReadTimer;
  String? _automaticReadInFlightId;
  final Set<String> _automaticReadHandledIds = <String>{};

  SenderWhoRepository get _repository =>
      widget.repository ?? RepositoryScope.read(context);

  int _contentRequest = 0;
  int _detailsRequest = 0;

  bool get _interactionBusy =>
      _loading || _busy || _automaticReadInFlightId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _automaticReadTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleAutomaticRead(_email);
    } else {
      _automaticReadTimer?.cancel();
    }
  }

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
        _error = 'No email message was selected.';
      });
      return;
    }
    final request = ++_detailsRequest;
    setState(() => _loading = true);
    unawaited(_loadContent(id));
    final thread = await _repository.getEmailThread(id);
    EmailItem? email;
    if (thread != null) {
      for (final item in thread.items) {
        if (item.id == id) {
          email = item;
          break;
        }
      }
    }
    email ??= await _repository.getEmail(id);
    if (!mounted || request != _detailsRequest || _id != id) return;
    final resolvedEmail = email ?? _email;
    setState(() {
      _loading = false;
      _email = resolvedEmail;
      _thread = thread?.items ?? const [];
      if (resolvedEmail != null &&
          !_thread.any((item) => item.id == resolvedEmail.id)) {
        _thread = [..._thread, resolvedEmail];
      }
      _error = email == null
          ? _repository.lastError ?? 'Message details could not be loaded.'
          : null;
    });
    _scheduleAutomaticRead(resolvedEmail);
  }

  void _selectThreadMessage(EmailItem email) {
    if (_interactionBusy) return;
    _automaticReadTimer?.cancel();
    setState(() {
      _email = email;
      _id = email.id;
    });
    _scheduleAutomaticRead(email);
    _loadContent(email.id);
  }

  void _scheduleAutomaticRead(EmailItem? email) {
    _automaticReadTimer?.cancel();
    if (email == null ||
        email.id.isEmpty ||
        email.isRead ||
        _automaticReadHandledIds.contains(email.id)) {
      return;
    }
    final messageId = email.id;
    _automaticReadTimer = Timer(_automaticReadDelay, () {
      _automaticReadTimer = null;
      unawaited(_markReadAfterViewing(messageId));
    });
  }

  Future<void> _markReadAfterViewing(String messageId) async {
    if (!mounted || _id != messageId) return;
    final email = _email;
    if (email == null || email.isRead) return;
    if (_busy) {
      _automaticReadTimer = Timer(const Duration(milliseconds: 250), () {
        _automaticReadTimer = null;
        unawaited(_markReadAfterViewing(messageId));
      });
      return;
    }

    _automaticReadHandledIds.add(messageId);
    setState(() {
      _automaticReadInFlightId = messageId;
      _changed = true;
      _replaceReadState(messageId, true);
    });
    final result = await _repository.setEmailsRead([messageId], true);
    final succeeded =
        result != null && result.processed == 1 && result.failed == 0;
    if (!mounted) return;
    setState(() {
      _automaticReadInFlightId = null;
      if (!succeeded) _replaceReadState(messageId, false);
    });
    if (!succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not mark this message as read. Tap Read to retry.',
          ),
        ),
      );
    }
  }

  void _replaceReadState(String messageId, bool isRead) {
    if (_email?.id == messageId) {
      _email = _email!.copyWith(isRead: isRead);
    }
    _thread = _thread
        .map(
          (message) => message.id == messageId
              ? message.copyWith(isRead: isRead)
              : message,
        )
        .toList(growable: false);
  }

  Future<void> _openSenderDetails(String senderId) async {
    _automaticReadTimer?.cancel();
    await Navigator.pushNamed(
      context,
      SenderDetailsScreen.routeName,
      arguments: senderId,
    );
    if (mounted) _scheduleAutomaticRead(_email);
  }

  Future<void> _loadContent(String id) async {
    final request = ++_contentRequest;
    setState(() {
      _contentLoading = true;
      if (_content?.id != id) _content = null;
      _contentError = null;
    });
    final content = await _repository.getEmailContent(id);
    if (!mounted || _id != id || request != _contentRequest) return;
    setState(() {
      _contentLoading = false;
      if (content != null) _content = content;
      _contentError = content == null
          ? _repository.lastError ??
                'The full email message could not be loaded.'
          : null;
    });
  }

  Future<void> _act(String action, {bool? isRead}) async {
    final email = _email;
    if (email == null || _interactionBusy) return;
    if (action == 'read-state') {
      _automaticReadTimer?.cancel();
      _automaticReadHandledIds.add(email.id);
    }
    if (action == 'trash') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Move this email to Trash?'),
          content: const Text(
            'The message will be moved to Trash. You can restore it before your email provider permanently deletes it.',
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
              ? 'Email message updated.'
              : _repository.lastError ??
                    'The email action failed. Please retry.',
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
    if (senderId == null || senderId.isEmpty || _interactionBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Unsubscribe from ${email?.sender ?? 'this sender'}?'),
        content: Text(
          'SenderWho will send a verified one-click unsubscribe request for ${email?.email ?? 'this sender'}. Existing email messages will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
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

  Future<void> _blockSender() async {
    final email = _email;
    final senderId = email?.senderId;
    if (senderId == null || senderId.isEmpty || _interactionBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Block ${email?.sender ?? 'this sender'}?'),
        content: const Text(
          'Future messages found during inbox scans will be moved to Trash. '
          'Existing messages are not deleted, and you can unblock the sender later.',
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
            icon: const Icon(Icons.block_rounded),
            label: const Text('Block sender'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final succeeded = await _repository.setSenderBlocked(senderId, true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (succeeded) _changed = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? 'Sender blocked. Future messages will be moved to Trash.'
              : _repository.lastError ?? 'The sender could not be blocked.',
        ),
      ),
    );
  }

  void _leaveDetails() {
    _automaticReadTimer?.cancel();
    final changed = _changed;
    if (_changed) setState(() => _changed = false);
    Navigator.pop(context, changed);
  }

  Widget _toolbar(EmailItem email) => Row(
    children: [
      Expanded(
        child: _MessageActionButton(
          icon: email.isRead
              ? Icons.mark_email_unread_outlined
              : Icons.mark_email_read_outlined,
          label: email.isRead ? 'Unread' : 'Read',
          onTap: _interactionBusy
              ? null
              : () => _act('read-state', isRead: !email.isRead),
        ),
      ),
      if (!email.isTrashed)
        Expanded(
          child: _MessageActionButton(
            icon: email.isArchived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined,
            label: email.isArchived ? 'Inbox' : 'Archive',
            onTap: _interactionBusy
                ? null
                : () => _act(email.isArchived ? 'unarchive' : 'archive'),
          ),
        ),
      Expanded(
        child: _MessageActionButton(
          icon: email.isTrashed
              ? Icons.restore_from_trash_outlined
              : Icons.delete_outline_rounded,
          label: email.isTrashed ? 'Restore' : 'Trash',
          onTap: _interactionBusy
              ? null
              : () => _act(email.isTrashed ? 'restore' : 'trash'),
        ),
      ),
      if (email.canUnsubscribe || email.senderId?.isNotEmpty == true)
        PopupMenuButton<String>(
          tooltip: 'More message actions',
          enabled: !_interactionBusy,
          onSelected: (action) {
            if (action == 'unsubscribe') _unsubscribe();
            if (action == 'block') _blockSender();
          },
          itemBuilder: (_) => [
            if (email.canUnsubscribe && !email.isTrashed)
              const PopupMenuItem(
                value: 'unsubscribe',
                child: Text('Unsubscribe from this sender'),
              ),
            if (email.senderId?.isNotEmpty == true)
              const PopupMenuItem(
                value: 'block',
                child: Text('Block this sender'),
              ),
          ],
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final email = _email;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _automaticReadTimer?.cancel();
      },
      child: AppPage(
        maxContentWidth: 780,
        header: Column(
          children: [
            AppHeader(
              title: 'Message',
              subtitle: email == null
                  ? null
                  : formatMailDate(email.date, detailed: true),
              showBack: true,
              onBack: _leaveDetails,
            ),
            if (email != null) _toolbar(email),
            if (_loading && email != null)
              const LinearProgressIndicator(minHeight: 2),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              const SizedBox(height: 16),
              Text(
                email.subject.isEmpty ? '(No subject)' : email.subject,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  MailAvatar(name: email.sender),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email.sender,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          email.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (email.senderId?.isNotEmpty == true &&
                      MediaQuery.textScalerOf(context).scale(14) <= 18)
                    TextButton(
                      onPressed: () => _openSenderDetails(email.senderId!),
                      child: const Text('View sender'),
                    ),
                ],
              ),
              if (email.senderId?.isNotEmpty == true &&
                  MediaQuery.textScalerOf(context).scale(14) > 18)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _openSenderDetails(email.senderId!),
                    child: const Text('View sender'),
                  ),
                ),
              if (email.identityStatus == 'SUSPICIOUS') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Sender identity needs review')),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _SelectedMessageContent(
                email: email,
                content: _content,
                loading: _contentLoading,
                error: _contentError,
                onRetry: () => _loadContent(email.id),
              ),
              if (_thread.length > 1) ...[
                const SizedBox(height: 20),
                ExpansionTile(
                  title: Text('Conversation · ${_thread.length} messages'),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    for (final message in _thread)
                      _ConversationMessageCard(
                        message: message,
                        selected: message.id == email.id,
                        onTap: () => _selectThreadMessage(message),
                      ),
                  ],
                ),
              ],
              if (_interactionBusy) ...[
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
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading && message != null)
            const LinearProgressIndicator(minHeight: 2),
          if (loading && message == null) ...[
            const LinearProgressIndicator(
              minHeight: 2,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading this message securely from your inbox…',
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
                            ? 'No message preview is available.'
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
            SelectableText(
              message.bodyText.isEmpty
                  ? 'This email message does not contain a readable text body.'
                  : message.bodyText,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.55),
            ),
            const SizedBox(height: 18),
            ExpansionTile(
              title: const Text('Message details'),
              tilePadding: EdgeInsets.zero,
              children: [
                _MessageHeaderLine(label: 'From', value: message.from),
                _MessageHeaderLine(label: 'To', value: message.to),
                if (message.cc.isNotEmpty)
                  _MessageHeaderLine(label: 'Cc', value: message.cc),
                if (message.date.isNotEmpty)
                  _MessageHeaderLine(label: 'Date', value: message.date),
              ],
            ),
            const SizedBox(height: 12),
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
    return MailMessageRow(email: message, selected: selected, onTap: onTap);
  }
}

class _MessageActionButton extends StatelessWidget {
  const _MessageActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 18;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textFor(context),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        textStyle: Theme.of(context).textTheme.labelSmall,
      ),
      child: stacked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 19),
                const SizedBox(height: 4),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 19),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
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

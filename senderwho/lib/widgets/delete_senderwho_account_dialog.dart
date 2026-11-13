import 'package:flutter/material.dart';

import '../services/senderwho_repository.dart';
import '../utils/user_friendly_error.dart';

/// Deletes the SenderWho service account, never a provider mailbox.
class DeleteSenderWhoAccountDialog extends StatefulWidget {
  const DeleteSenderWhoAccountDialog({super.key, required this.repository});
  final SenderWhoRepository repository;

  @override
  State<DeleteSenderWhoAccountDialog> createState() =>
      _DeleteSenderWhoAccountDialogState();
}

class _DeleteSenderWhoAccountDialogState
    extends State<DeleteSenderWhoAccountDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    if (_deleting) return;
    final dialogRoute = ModalRoute.of(context);
    setState(() {
      _deleting = true;
      _error = null;
    });
    var deleted = false;
    try {
      deleted = await widget.repository.deleteAccount();
    } on Object {
      // Keep the confirmation available for a safe retry.
    }
    if (!mounted) return;
    if (deleted) {
      // Session invalidation may already be revealing welcome. Never pop that
      // new page while this outgoing dialog is waiting to be disposed.
      if (dialogRoute?.isCurrent == true) Navigator.pop(context);
      return;
    }
    setState(() {
      _deleting = false;
      _error = sanitizeUserMessage(
        widget.repository.lastError,
        fallback: 'Couldn’t delete your SenderWho account. Please try again.',
      );
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_deleting,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Delete SenderWho account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Permanently remove your SenderWho account and its saved data. All linked mailboxes will be disconnected.',
          ),
          const SizedBox(height: 12),
          Text(
            'Your Gmail, Outlook, Yahoo accounts and their emails will not be deleted.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            'This cannot be undone. You may be asked to sign in again to confirm.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-delete-senderwho-account'),
          onPressed: _deleting ? null : _delete,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: Text(_deleting ? 'Deleting…' : 'Delete SenderWho account'),
        ),
      ],
    ),
  );
}

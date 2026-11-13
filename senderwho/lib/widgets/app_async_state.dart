import 'package:flutter/material.dart';

import '../theme/app_semantic_colors.dart';
import '../utils/user_friendly_error.dart';
import 'app_card.dart';

class AppAsyncLoading extends StatelessWidget {
  const AppAsyncLoading({
    super.key,
    this.message = 'Loading your SenderWho data…',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppAsyncError extends StatelessWidget {
  const AppAsyncError({
    super.key,
    required this.onRetry,
    this.message = 'SenderWho could not load this information.',
    this.title = 'Something went wrong',
  });

  final VoidCallback onRetry;
  final String message;
  final String title;

  @override
  Widget build(BuildContext context) {
    final semantic = AppSemanticColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(20),
      color: semantic.warningContainer,
      borderColor: semantic.warning.withValues(alpha: 0.42),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: semantic.onWarningContainer,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: semantic.onWarningContainer,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  userFriendlyErrorMessage(message),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: semantic.onWarningContainer,
                  ),
                ),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A shared, explanatory empty state across mailbox and utility screens.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 36),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}

String appAsyncErrorMessage(Object? error) {
  return userFriendlyErrorMessage(
    error,
    fallback: 'Check your connection and try again.',
  );
}

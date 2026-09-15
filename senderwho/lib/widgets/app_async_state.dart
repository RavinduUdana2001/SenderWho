import 'package:flutter/material.dart';

import '../theme/app_semantic_colors.dart';
import '../utils/user_friendly_error.dart';
import 'app_card.dart';
import 'icon_bubble.dart';

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
      child: Column(
        children: [
          IconBubble(
            icon: Icons.cloud_off_rounded,
            color: semantic.warning,
            backgroundColor: semantic.onWarning,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: semantic.onWarningContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: semantic.onWarningContainer,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

String appAsyncErrorMessage(Object? error) {
  return userFriendlyErrorMessage(
    error,
    fallback: 'Check your connection and try again.',
  );
}

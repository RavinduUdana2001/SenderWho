import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/user_friendly_error.dart';
import 'app_card.dart';
import 'icon_bubble.dart';

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
    return AppCard(
      padding: const EdgeInsets.all(20),
      borderColor: AppColors.warning.withValues(alpha: 0.28),
      child: Column(
        children: [
          const IconBubble(
            icon: Icons.cloud_off_rounded,
            color: AppColors.warning,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
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

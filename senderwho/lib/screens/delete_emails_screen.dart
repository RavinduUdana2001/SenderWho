import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/icon_bubble.dart';
import 'bulk_clean_screen.dart';

class DeleteEmailsScreen extends StatefulWidget {
  const DeleteEmailsScreen({super.key});

  static const routeName = '/delete-emails';

  @override
  State<DeleteEmailsScreen> createState() => _DeleteEmailsScreenState();
}

class _DeleteEmailsScreenState extends State<DeleteEmailsScreen> {
  late Future<List<CleanupSuggestion>> _suggestionsFuture = senderWhoRepository
      .getCleanupSuggestions();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CleanupSuggestion>>(
      future: _suggestionsFuture,
      builder: (context, snapshot) {
        final suspicious = (snapshot.data ?? const <CleanupSuggestion>[])
            .where((item) => item.categoryKey == 'SPAM')
            .toList();
        final messageCount = suspicious.fold<int>(
          0,
          (total, item) => total + item.messageCount,
        );

        return AppPage(
          child: Column(
            children: [
              const AppHeader(
                title: 'Delete Emails',
                subtitle: 'Review suspicious-message cleanup',
                showBack: true,
              ),
              SizedBox(height: context.gap(18)),
              AppCard(
                padding: const EdgeInsets.all(24),
                color: AppColors.softFill(context, AppColors.danger),
                borderColor: AppColors.danger.withValues(alpha: 0.2),
                child: Column(
                  children: [
                    const IconBubble(
                      icon: Icons.delete_outline_rounded,
                      size: 58,
                      iconSize: 28,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Move suspicious mail to Trash?',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Trusted messages stay untouched. Gmail Trash retention rules apply.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppColors.borderFor(context)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.report_gmailerrorred_outlined,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$messageCount suspicious emails found',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.gap(18)),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(),
              if (snapshot.hasError) ...[
                const SizedBox(height: 12),
                Text(
                  'Cleanup suggestions could not be loaded.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _suggestionsFuture = senderWhoRepository
                        .getCleanupSuggestions();
                  }),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
              const SizedBox(height: 12),
              AppButton(
                label: 'Review in Bulk Clean',
                backgroundColor: AppColors.danger,
                onPressed:
                    snapshot.connectionState == ConnectionState.waiting ||
                        suspicious.isEmpty
                    ? null
                    : () => Navigator.pushReplacementNamed(
                        context,
                        BulkCleanScreen.routeName,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

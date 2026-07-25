import 'package:flutter/material.dart';

import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/icon_bubble.dart';

class BlockSendersScreen extends StatefulWidget {
  const BlockSendersScreen({super.key});

  static const routeName = '/block-senders';

  @override
  State<BlockSendersScreen> createState() => _BlockSendersScreenState();
}

class _BlockSendersScreenState extends State<BlockSendersScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final values = arguments is Map ? arguments : const {};
    final senderId = values['senderId'] as String? ?? '';
    final email = values['email'] as String? ?? '';

    return AppPage(
      child: Column(
        children: [
          const AppHeader(
            title: 'Block Sender',
            subtitle: 'Confirm this sender control',
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
                  icon: Icons.block_outlined,
                  size: 58,
                  iconSize: 28,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 16),
                Text(
                  'Block this sender?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'New messages found during Gmail scans will be moved to Trash. You can unblock the sender later.',
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
                      Icon(
                        Icons.alternate_email_rounded,
                        color: AppColors.mutedFor(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          email.isEmpty ? 'No sender selected' : email,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.gap(18)),
          if (senderId.isNotEmpty)
            AppButton(
              label: _busy ? 'Blocking sender…' : 'Block Sender',
              backgroundColor: AppColors.danger,
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final blocked = await senderWhoRepository
                          .setSenderBlocked(senderId, true);
                      if (!context.mounted) return;
                      setState(() => _busy = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            blocked
                                ? 'Sender marked as blocked in SenderWho.'
                                : 'Could not block this sender.',
                          ),
                        ),
                      );
                      if (blocked) Navigator.pop(context);
                    },
            ),
        ],
      ),
    );
  }
}

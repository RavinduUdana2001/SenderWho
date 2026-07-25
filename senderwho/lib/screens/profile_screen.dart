import 'package:flutter/material.dart';

import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/icon_bubble.dart';
import '../widgets/section_title.dart';
import 'connected_accounts_screen.dart';
import 'privacy_security_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const routeName = '/profile';

  @override
  Widget build(BuildContext context) {
    final email = senderWhoRepository.userEmail?.trim();
    final hasEmail = email?.isNotEmpty == true;
    final displayEmail = hasEmail ? email! : 'Account email unavailable';
    final initial = hasEmail ? displayEmail[0].toUpperCase() : 'S';
    final activeSession = senderWhoRepository.isAuthenticated;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppHeader(title: 'Profile'),
          SizedBox(height: context.gap(22)),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                IconBubble(
                  icon: Icons.person_rounded,
                  label: initial,
                  size: 58,
                  iconSize: 24,
                  backgroundColor: AppColors.primary,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SenderWho account',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        displayEmail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.gap(24)),
          const SectionTitle(title: 'Account details'),
          const SizedBox(height: 13),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            child: Column(
              children: [
                _ProfileDetail(
                  label: 'Email',
                  value: hasEmail ? displayEmail : 'Not available',
                ),
                const Divider(height: 1),
                _ProfileDetail(
                  label: 'Session',
                  value: activeSession ? 'Active on this device' : 'Not active',
                ),
                const Divider(height: 1),
                const _ProfileDetail(
                  label: 'Privacy',
                  value: 'Private by design',
                ),
              ],
            ),
          ),
          SizedBox(height: context.gap(24)),
          const SectionTitle(title: 'Manage account'),
          const SizedBox(height: 13),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ProfileLink(
                  icon: Icons.alternate_email_rounded,
                  title: 'Connected accounts',
                  onTap: () => Navigator.pushNamed(
                    context,
                    ConnectedAccountsScreen.routeName,
                  ),
                ),
                const Divider(height: 1, indent: 18, endIndent: 18),
                _ProfileLink(
                  icon: Icons.verified_user_outlined,
                  title: 'Privacy & security',
                  onTap: () => Navigator.pushNamed(
                    context,
                    PrivacySecurityScreen.routeName,
                  ),
                ),
                const Divider(height: 1, indent: 18, endIndent: 18),
                _ProfileLink(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () =>
                      Navigator.pushNamed(context, SettingsScreen.routeName),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      leading: IconBubble(icon: icon, size: 40, iconSize: 19),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}

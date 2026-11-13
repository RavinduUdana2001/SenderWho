import 'package:flutter/material.dart';

import '../services/senderwho_repository.dart';
import '../services/repository_scope.dart';
import '../models/app_models.dart';
import '../widgets/mail_avatar.dart';
import '../utils/responsive.dart';
import '../utils/mailbox_identity.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/icon_bubble.dart';
import '../widgets/section_title.dart';
import 'connected_accounts_screen.dart';
import 'privacy_security_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.repository});
  final SenderWhoRepository? repository;

  static const routeName = '/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = false;
  String? _error;
  SenderWhoRepository get _repository =>
      widget.repository ?? RepositoryScope.read(context);

  @override
  void initState() {
    super.initState();
    if (_repository.isAuthenticated) _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    UserProfile? profile;
    try {
      profile = await _repository.getUserProfile(refresh: true);
    } on Object {
      profile = null;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = profile == null ? 'Your profile could not be refreshed.' : null;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      _repository.userProfile,
      _repository.activeMailbox,
      _repository.connectedAccounts,
    ]),
    builder: (context, _) {
      final identity = MailboxIdentity.resolve(
        mailbox: _repository.activeMailbox.value,
        profile: _repository.userProfile.value,
        userEmail: _repository.userEmail,
      );
      final email = identity.email;
      final hasEmail = email?.isNotEmpty == true;
      final displayEmail = hasEmail ? email! : 'Account email unavailable';
      final activeSession = _repository.isAuthenticated;

      return AppPage(
        header: AppHeader(
          title: 'Profile',
          action: IconButton(
            tooltip: 'Refresh profile',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Text(_error!, style: Theme.of(context).textTheme.bodySmall),
            SizedBox(height: context.gap(22)),
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  MailAvatar(
                    key: ValueKey('profile-avatar-$email'),
                    name: identity.name,
                    label: displayEmail,
                    imageUrl: identity.avatarUrl,
                    size: 58,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          identity.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          displayEmail,
                          key: const ValueKey('profile-mailbox-email'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (_repository.activeMailbox.value != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            'Current mailbox',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
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
                    value: activeSession
                        ? 'Active on this device'
                        : 'Not active',
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
    },
  );
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: label == 'Email' || value.length > 18
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                SelectableText(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
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

import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../screens/dashboard_screen.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/icon_bubble.dart';
import '../widgets/responsive_entry_page.dart';

class ConnectEmailScreen extends StatefulWidget {
  const ConnectEmailScreen({
    super.key,
    this.startOAuth,
    this.availableProviders,
  });

  final Future<bool> Function(String provider)? startOAuth;
  final Future<Map<String, bool>> Function()? availableProviders;

  static const routeName = '/connect-email';

  @override
  State<ConnectEmailScreen> createState() => _ConnectEmailScreenState();
}

class _ConnectEmailScreenState extends State<ConnectEmailScreen> {
  String? rememberedEmail;
  Map<String, bool> providers = const {'google': true, 'yahoo': false};
  bool connecting = false;
  String? connectingProvider;
  String? failedProvider;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRememberedEmail());
    final providerRequest =
        widget.availableProviders?.call() ??
        (widget.startOAuth != null
            ? Future.value(const {'google': true, 'yahoo': true})
            : senderWhoRepository.availableAuthProviders());
    unawaited(_loadProviders(providerRequest));
  }

  Future<void> _loadRememberedEmail() async {
    final email = await senderWhoRepository.rememberedEmail();
    if (!mounted) return;
    setState(() => rememberedEmail = email);
  }

  Future<void> _loadProviders(Future<Map<String, bool>> request) async {
    try {
      final available = await request;
      if (!mounted) return;
      setState(() => providers = available);
    } on Object {
      // Keep the safe Gmail-only default if capability discovery is unavailable.
    }
  }

  Future<void> _connect(String provider, {bool chooseAccount = false}) async {
    setState(() {
      connecting = true;
      connectingProvider = provider;
      failedProvider = null;
      errorMessage = null;
    });
    final oauth =
        widget.startOAuth ??
        (chooseAccount
            ? senderWhoRepository.startOAuthWithAccountChooser
            : senderWhoRepository.startOAuth);
    final opened = await oauth(provider);
    if (!mounted) return;
    setState(() => connecting = false);

    if (!opened) {
      setState(() {
        failedProvider = provider;
        errorMessage =
            (widget.startOAuth == null
                ? senderWhoRepository.lastError
                : null) ??
            '${provider == 'yahoo' ? 'Yahoo' : 'Google'} sign-in was not completed. Please try again.';
      });
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      DashboardScreen.routeName,
      (_) => false,
    );
  }

  void _cancelConnection() {
    senderWhoRepository.cancelOAuth();
    setState(() {
      connecting = false;
      errorMessage = 'Sign-in was canceled. You can try again safely.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveEntryPage(
      leading: _BackButton(onPressed: () => Navigator.maybePop(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('connect-brand-icon'),
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/branding/senderwho_app_icon_master.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                semanticLabel: 'SenderWho',
              ),
            ),
          ),
          SizedBox(height: context.verticalGap(22)),
          Text(
            'Connect your inbox',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              providers['yahoo'] == true
                  ? 'Securely connect Gmail or Yahoo Mail to identify senders, organize messages, and power cleanup suggestions.'
                  : 'Securely connect Gmail to identify senders, organize messages, and power cleanup suggestions.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          SizedBox(height: context.verticalGap(26)),
          Builder(
            builder: (context) {
              final previousEmail = rememberedEmail?.trim();
              final hasRememberedAccount =
                  !AppConfig.uiPreviewMode &&
                  previousEmail != null &&
                  previousEmail.isNotEmpty;
              return Column(
                children: [
                  _SignInOption(
                    label: 'G',
                    color: const Color(0xFF4285F4),
                    backgroundColor: const Color(0xFFEAF1FF),
                    title: AppConfig.uiPreviewMode
                        ? 'Connect my inbox'
                        : hasRememberedAccount
                        ? 'Continue with previous account'
                        : 'Continue with Google',
                    subtitle: AppConfig.uiPreviewMode
                        ? 'Open the sample dashboard without Google sign-in'
                        : hasRememberedAccount
                        ? previousEmail
                        : 'Use your Gmail account',
                    onTap: connecting ? null : () => _connect('google'),
                  ),
                  if (hasRememberedAccount) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: connecting
                          ? null
                          : () => _connect('google', chooseAccount: true),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 19),
                      label: const Text('Use another Google account'),
                    ),
                  ],
                  if (providers['yahoo'] == true) ...[
                    const SizedBox(height: 12),
                    _SignInOption(
                      label: 'Y!',
                      color: const Color(0xFF6001D2),
                      backgroundColor: const Color(0xFFF1E7FF),
                      title: 'Continue with Yahoo',
                      subtitle: 'Sign in securely with your Yahoo account',
                      onTap: connecting ? null : () => _connect('yahoo'),
                    ),
                  ],
                ],
              );
            },
          ),
          if (connecting) ...[
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      connectingProvider == 'yahoo'
                          ? 'Complete Yahoo sign-in in your browser, then return here.'
                          : 'Complete Google sign-in in your browser, then return here.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelConnection,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            _OAuthErrorCard(
              message: errorMessage!,
              onRetry: connecting
                  ? null
                  : () => _connect(failedProvider ?? 'google'),
            ),
          ],
          SizedBox(height: context.verticalGap(18)),
          AppCard(
            padding: const EdgeInsets.all(14),
            color: AppColors.softFill(context, AppColors.primary),
            borderColor: AppColors.primary.withValues(alpha: 0.18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 19,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SenderWho stores metadata and short previews—not full email bodies. You can disconnect at any time.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OAuthErrorCard extends StatelessWidget {
  const _OAuthErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final configurationError = message.toLowerCase().contains('oauth client');
    return AppCard(
      padding: const EdgeInsets.all(14),
      color: AppColors.softFill(context, AppColors.danger),
      borderColor: AppColors.danger.withValues(alpha: 0.25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  configurationError
                      ? 'Google connection unavailable'
                      : 'Connection not completed',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: AppColors.borderFor(context)),
      ),
      child: IconButton(
        tooltip: 'Back',
        visualDensity: VisualDensity.compact,
        iconSize: 21,
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    );
  }
}

class _SignInOption extends StatelessWidget {
  const _SignInOption({
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color backgroundColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          IconBubble(
            icon: Icons.circle,
            label: label,
            size: 42,
            iconSize: 20,
            color: color,
            backgroundColor: AppColors.isDark(context)
                ? AppColors.softFill(context, color)
                : backgroundColor,
            labelColor: color,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.mutedFor(context)),
        ],
      ),
    );
  }
}

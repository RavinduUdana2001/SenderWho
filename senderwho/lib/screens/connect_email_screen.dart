import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../screens/dashboard_screen.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../utils/public_links.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/responsive_entry_page.dart';

class ConnectEmailScreen extends StatefulWidget {
  const ConnectEmailScreen({
    super.key,
    this.startOAuth,
    this.availableProviders,
    this.loadRememberedEmail,
    this.loadRememberedProvider,
  });

  final Future<bool> Function(String provider)? startOAuth;
  final Future<Map<String, bool>> Function()? availableProviders;
  final Future<String?> Function()? loadRememberedEmail;
  final Future<String?> Function()? loadRememberedProvider;

  static const routeName = '/connect-email';

  @override
  State<ConnectEmailScreen> createState() => _ConnectEmailScreenState();
}

class _ConnectEmailScreenState extends State<ConnectEmailScreen> {
  String? rememberedEmail;
  String? rememberedProvider;
  Map<String, bool> providers = const {
    'google': true,
    'microsoft': false,
    'yahoo': false,
  };
  bool connecting = false;
  String? connectingProvider;
  String? failedProvider;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRememberedAccount());
    final providerRequest =
        widget.availableProviders?.call() ??
        (widget.startOAuth != null
            ? Future.value(providers)
            : senderWhoRepository.availableAuthProviders());
    unawaited(_loadProviders(providerRequest));
  }

  Future<void> _loadRememberedAccount() async {
    final values = await Future.wait<String?>([
      widget.loadRememberedEmail?.call() ??
          senderWhoRepository.rememberedEmail(),
      widget.loadRememberedProvider?.call() ??
          senderWhoRepository.rememberedProvider(),
    ]);
    if (!mounted) return;
    setState(() {
      rememberedEmail = values[0];
      rememberedProvider = _normalizeProvider(values[1]);
    });
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
            '${_providerName(provider)} sign-in was not completed. Please try again.';
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
    final theme = Theme.of(context);

    return ResponsiveEntryPage(
      maxWidth: 440,
      leading: _BackButton(onPressed: () => Navigator.maybePop(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SecurityBadge(),
          const SizedBox(height: 18),
          const _BrandIcon(),
          SizedBox(height: context.verticalGap(24)),
          Semantics(
            header: true,
            child: Text(
              'Connect your inbox',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 370),
            child: Text(
              _connectionDescription(providers),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          SizedBox(height: context.verticalGap(26)),
          const _AccountDivider(),
          const SizedBox(height: AppSpacing.md),
          _providerOptions(),
          if (connecting) ...[
            const SizedBox(height: 14),
            _OAuthProgressCard(
              provider: connectingProvider ?? 'google',
              onCancel: _cancelConnection,
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            _OAuthErrorCard(
              provider: failedProvider ?? 'google',
              message: errorMessage!,
              onRetry: connecting
                  ? null
                  : () => _connect(failedProvider ?? 'google'),
            ),
          ],
          SizedBox(height: context.verticalGap(20)),
          _PrivacyNotice(
            onPrivacyTap: () => openSenderWhoPublicPage(
              context,
              url: AppConfig.privacyPolicyUrl,
              pageName: 'the Privacy Policy',
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () => openSenderWhoPublicPage(
                  context,
                  url: AppConfig.privacyPolicyUrl,
                  pageName: 'the Privacy Policy',
                ),
                child: const Text('Privacy Policy'),
              ),
              Text('•', style: theme.textTheme.bodySmall),
              TextButton(
                onPressed: () => openSenderWhoPublicPage(
                  context,
                  url: AppConfig.termsOfServiceUrl,
                  pageName: 'the Terms of Service',
                ),
                child: const Text('Terms of Service'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _providerOptions() {
    final previousEmail = rememberedEmail?.trim();
    final savedProvider = _normalizeProvider(rememberedProvider);
    final hasRememberedAccount =
        !AppConfig.uiPreviewMode &&
        previousEmail != null &&
        previousEmail.isNotEmpty &&
        savedProvider != null;
    // An email address alone does not reveal its OAuth provider (work domains
    // can be hosted by Google or Microsoft), so never guess for legacy data.
    final previousProvider = savedProvider ?? 'google';

    return Column(
      children: [
        _SignInOption(
          provider: previousProvider,
          eyebrow: hasRememberedAccount ? 'PREVIOUSLY CONNECTED' : null,
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
          isLoading: connecting && connectingProvider == previousProvider,
          onTap: connecting ? null : () => _connect(previousProvider),
        ),
        if (hasRememberedAccount) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: connecting
                  ? null
                  : () => _connect(previousProvider, chooseAccount: true),
              icon: const Icon(Icons.swap_horiz_rounded, size: 19),
              label: Text(
                'Use a different ${_providerAccountName(previousProvider)} account',
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surface(
                  context,
                ).withValues(alpha: AppColors.isDark(context) ? 0.72 : 0.86),
              ),
            ),
          ),
        ],
        if (hasRememberedAccount && previousProvider != 'google') ...[
          const SizedBox(height: 12),
          _SignInOption(
            provider: 'google',
            title: 'Continue with Google',
            subtitle: 'Use your Gmail account',
            isLoading: connecting && connectingProvider == 'google',
            onTap: connecting ? null : () => _connect('google'),
          ),
        ],
        if (providers['microsoft'] == true &&
            (!hasRememberedAccount || previousProvider != 'microsoft')) ...[
          const SizedBox(height: 12),
          _SignInOption(
            provider: 'microsoft',
            title: 'Continue with Microsoft',
            subtitle: 'Outlook, Hotmail or Microsoft 365',
            isLoading: connecting && connectingProvider == 'microsoft',
            onTap: connecting ? null : () => _connect('microsoft'),
          ),
        ],
        if (providers['yahoo'] == true &&
            (!hasRememberedAccount || previousProvider != 'yahoo')) ...[
          const SizedBox(height: 12),
          _SignInOption(
            provider: 'yahoo',
            title: 'Continue with Yahoo',
            subtitle: 'Use your Yahoo Mail account',
            isLoading: connecting && connectingProvider == 'yahoo',
            onTap: connecting ? null : () => _connect('yahoo'),
          ),
        ],
      ],
    );
  }
}

String _providerName(String provider) => switch (provider.toLowerCase()) {
  'microsoft' => 'Microsoft Outlook',
  'yahoo' => 'Yahoo Mail',
  _ => 'Google',
};

String _providerAccountName(String provider) =>
    switch (provider.toLowerCase()) {
      'microsoft' => 'Microsoft',
      'yahoo' => 'Yahoo',
      _ => 'Google',
    };

String? _normalizeProvider(String? provider) {
  final normalized = provider?.trim().toLowerCase();
  return switch (normalized) {
    'google' || 'microsoft' || 'yahoo' => normalized,
    _ => null,
  };
}

String _connectionDescription(Map<String, bool> providers) {
  final names = <String>['Gmail'];
  if (providers['microsoft'] == true) names.add('Microsoft Outlook');
  if (providers['yahoo'] == true) names.add('Yahoo Mail');
  final providerText = names.length == 1
      ? names.single
      : '${names.take(names.length - 1).join(', ')} or ${names.last}';
  return 'Securely connect $providerText to understand your senders and keep your inbox organized.';
}

class _SecurityBadge extends StatelessWidget {
  const _SecurityBadge();

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.successVisualFor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(
          alpha: AppColors.isDark(context) ? 0.14 : 0.08,
        ),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: accent.withValues(
            alpha: AppColors.isDark(context) ? 0.3 : 0.2,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            'PRIVATE & SECURE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.successFor(context),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.75,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandIcon extends StatelessWidget {
  const _BrandIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('connect-brand-icon'),
      width: 88,
      height: 88,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.brandSpectrum,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryFor(
              context,
            ).withValues(alpha: AppColors.isDark(context) ? 0.2 : 0.16),
            blurRadius: 28,
            offset: const Offset(0, 12),
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
    );
  }
}

class _AccountDivider extends StatelessWidget {
  const _AccountDivider();

  @override
  Widget build(BuildContext context) {
    final color = AppColors.borderFor(context).withValues(alpha: 0.7);
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'CHOOSE AN ACCOUNT',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.mutedFor(context),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice({required this.onPrivacyTap});

  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.successVisualFor(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: Color.alphaBlend(
        accent.withValues(alpha: AppColors.isDark(context) ? 0.08 : 0.035),
        AppColors.surface(context),
      ),
      borderColor: accent.withValues(
        alpha: AppColors.isDark(context) ? 0.28 : 0.18,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shield_outlined, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your inbox stays under your control',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'We store limited metadata and short previews—not full email bodies. Disconnect at any time.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 5),
                InkWell(
                  onTap: onPrivacyTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      'How we protect your data',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryFor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _OAuthProgressCard extends StatelessWidget {
  const _OAuthProgressCard({required this.provider, required this.onCancel});

  final String provider;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      color: AppColors.softFill(context, AppColors.primary),
      borderColor: AppColors.primaryFor(context).withValues(alpha: 0.2),
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
              'Finish ${_providerName(provider)} sign-in in your browser.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _OAuthErrorCard extends StatelessWidget {
  const _OAuthErrorCard({
    required this.provider,
    required this.message,
    required this.onRetry,
  });

  final String provider;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final configurationError = message.toLowerCase().contains('oauth client');
    return AppCard(
      padding: const EdgeInsets.all(14),
      color: AppColors.softFill(context, AppColors.danger),
      borderColor: AppColors.dangerFor(context).withValues(alpha: 0.25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.dangerFor(context),
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  configurationError
                      ? '${_providerName(provider)} connection unavailable'
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
      color: AppColors.surface(context).withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
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
    required this.provider,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
    this.eyebrow,
  });

  final String provider;
  final String title;
  final String subtitle;
  final String? eyebrow;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _providerColor(provider);
    final isDark = AppColors.isDark(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      elevated: true,
      color: Color.alphaBlend(
        color.withValues(alpha: isDark ? 0.055 : 0.018),
        AppColors.surface(context),
      ),
      borderColor: color.withValues(alpha: isDark ? 0.32 : 0.2),
      radius: AppRadii.lg,
      child: Row(
        children: [
          _ProviderMark(provider: provider),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.65,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isLoading
                ? SizedBox(
                    key: const ValueKey('provider-progress'),
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: color,
                    ),
                  )
                : Container(
                    key: const ValueKey('provider-arrow'),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.16 : 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: color,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

Color _providerColor(String provider) => switch (provider.toLowerCase()) {
  'microsoft' => AppColors.microsoft,
  'yahoo' => AppColors.yahoo,
  _ => AppColors.google,
};

class _ProviderMark extends StatelessWidget {
  const _ProviderMark({required this.provider});

  final String provider;

  @override
  Widget build(BuildContext context) {
    final color = _providerColor(provider);
    final dark = AppColors.isDark(context);
    return Semantics(
      label: '${_providerName(provider)} logo',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              color.withValues(alpha: dark ? 0.17 : 0.08),
              AppColors.elevatedSurface(context),
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: color.withValues(alpha: dark ? 0.28 : 0.16),
            ),
          ),
          child: switch (provider.toLowerCase()) {
            'microsoft' => const _MicrosoftMark(),
            'yahoo' => const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Y!',
                style: TextStyle(
                  color: AppColors.yahoo,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ),
            _ => const _GoogleMark(),
          },
        ),
      ),
    );
  }
}

class _MicrosoftMark extends StatelessWidget {
  const _MicrosoftMark();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: const [
        ColoredBox(color: Color(0xFFF25022)),
        ColoredBox(color: Color(0xFF7FBA00)),
        ColoredBox(color: Color(0xFF00A4EF)),
        ColoredBox(color: Color(0xFFFFB900)),
      ],
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GoogleMarkPainter());
  }
}

class _GoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.shortestSide * 0.2;
    final rect = Rect.fromCircle(
      center: center,
      radius: (size.shortestSide - stroke) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.12, 1.72, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 1.60, 1.18, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.78, 0.82, false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.60, 1.67, false, paint);
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - stroke / 2,
        size.width * 0.45,
        stroke,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

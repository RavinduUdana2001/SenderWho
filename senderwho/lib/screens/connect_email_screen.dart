import 'dart:async';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../screens/all_senders_screen.dart';
import '../services/senderwho_repository.dart';
import '../services/repository_scope.dart';
import '../theme/app_colors.dart';
import '../utils/public_links.dart';
import '../widgets/responsive_entry_page.dart';
import '../widgets/senderwho_brand.dart';

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
  late final SenderWhoRepository _repository;
  String? rememberedEmail,
      rememberedProvider,
      connectingProvider,
      failedProvider,
      errorMessage;
  Map<String, bool> providers = const {
    'google': true,
    'microsoft': false,
    'yahoo': false,
  };
  bool connecting = false;
  int _connectionRevision = 0;

  @override
  void initState() {
    super.initState();
    _repository = RepositoryScope.read(context);
    unawaited(_loadRememberedAccount());
    unawaited(_loadProviders());
  }

  Future<void> _loadRememberedAccount() async {
    try {
      final values = await Future.wait<String?>([
        widget.loadRememberedEmail?.call() ?? _repository.rememberedEmail(),
        widget.loadRememberedProvider?.call() ??
            _repository.rememberedProvider(),
      ]);
      if (!mounted) return;
      setState(() {
        rememberedEmail = values[0];
        rememberedProvider = _normalizeProvider(values[1]);
      });
    } on Object {
      // A remembered-account lookup must never prevent fresh sign-in.
    }
  }

  Future<void> _loadProviders() async {
    try {
      final available =
          await (widget.availableProviders?.call() ??
              (widget.startOAuth != null
                  ? Future.value(providers)
                  : _repository.availableAuthProviders()));
      if (mounted) setState(() => providers = available);
    } on Object {
      // Keep the safe Gmail fallback if discovery is temporarily unavailable.
    }
  }

  Future<void> _connect(String provider, {bool chooseAccount = false}) async {
    if (connecting) return;
    final revision = ++_connectionRevision;
    setState(() {
      connecting = true;
      connectingProvider = provider;
      failedProvider = null;
      errorMessage = null;
    });
    var opened = false;
    try {
      final oauth =
          widget.startOAuth ??
          (chooseAccount
              ? _repository.startOAuthWithAccountChooser
              : _repository.startOAuth);
      opened = await oauth(provider);
    } on Object {
      // Connection errors stay on this page with a retry action.
    }
    if (!mounted || revision != _connectionRevision) return;
    setState(() => connecting = false);
    if (!opened) {
      setState(() {
        failedProvider = provider;
        errorMessage =
            (widget.startOAuth == null ? _repository.lastError : null) ??
            '${_providerName(provider)} sign-in was not completed. Please try again.';
      });
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      AllSendersScreen.routeName,
      (_) => false,
    );
  }

  void _cancelConnection() {
    _connectionRevision++;
    _repository.cancelOAuth();
    setState(() {
      connecting = false;
      connectingProvider = null;
      errorMessage = null;
    });
  }

  @override
  void dispose() {
    _connectionRevision++;
    if (connecting) _repository.cancelOAuth();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ResponsiveEntryPage(
    maxWidth: 400,
    topPadding: 32,
    bottomPadding: 16,
    // The Hero's landing position must stay fixed while saved accounts and
    // providers load. The route already animates this page's entrance.
    contentAlignment: Alignment.topCenter,
    leading: IconButton(
      tooltip: 'Back',
      onPressed: () => Navigator.maybePop(context),
      icon: const Icon(Icons.arrow_back_rounded),
    ),
    pinLeading: true,
    footer: const _SignInLegalLinks(),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SenderWhoLogo(key: ValueKey('connect-brand-icon'), size: 96),
        const SizedBox(height: 18),
        const SenderWhoWordmark(size: 27),
        const SizedBox(height: 28),
        Text(
          'Connect your inbox',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in or create your account.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.borderFor(context)),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .045),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              _providerOptions(),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: AppColors.mutedFor(context),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'No new password to remember.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (connecting) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Finish sign-in in your browser.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: _cancelConnection,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
        if (errorMessage != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection not completed',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  errorMessage!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton.icon(
                  onPressed: () => _connect(failedProvider ?? 'google'),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  Widget _providerOptions() {
    final previousEmail = rememberedEmail?.trim();
    final saved = _normalizeProvider(rememberedProvider);
    final hasPrevious =
        !AppConfig.uiPreviewMode &&
        previousEmail?.isNotEmpty == true &&
        saved != null &&
        providers[saved] == true;
    final order = <String>[
      if (hasPrevious) saved,
      for (final provider in ['google', 'microsoft', 'yahoo'])
        if (providers[provider] == true && (!hasPrevious || provider != saved))
          provider,
    ];
    return Column(
      children: [
        for (final provider in order) ...[
          _SignInOption(
            provider: provider,
            highlighted: hasPrevious && provider == saved,
            title: AppConfig.uiPreviewMode && provider == 'google'
                ? 'Connect my inbox'
                : hasPrevious && provider == saved
                ? 'Continue with previous account'
                : 'Continue with ${_providerName(provider)}',
            subtitle: hasPrevious && provider == saved ? previousEmail : null,
            isLoading: connecting && connectingProvider == provider,
            onTap: connecting ? null : () => _connect(provider),
          ),
          if (hasPrevious && provider == saved)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: connecting
                    ? null
                    : () => _connect(provider, chooseAccount: true),
                child: Text(
                  'Use a different ${_providerAccountName(provider)} account',
                ),
              ),
            ),
          if (provider != order.last) const SizedBox(height: 12),
        ],
        if (order.isEmpty) ...[
          const Text(
            'Sign-in is temporarily unavailable. Please try again.',
            textAlign: TextAlign.center,
          ),
          TextButton.icon(
            onPressed: _loadProviders,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ],
    );
  }
}

String _providerName(String provider) => switch (provider) {
  'microsoft' => 'Microsoft',
  'yahoo' => 'Yahoo',
  _ => 'Google',
};
String _providerAccountName(String provider) => _providerName(provider);
String? _normalizeProvider(String? provider) =>
    switch (provider?.trim().toLowerCase()) {
      'google' => 'google',
      'microsoft' => 'microsoft',
      'yahoo' => 'yahoo',
      _ => null,
    };

class _SignInOption extends StatelessWidget {
  const _SignInOption({
    required this.provider,
    required this.title,
    this.subtitle,
    required this.isLoading,
    required this.onTap,
    this.highlighted = false,
  });
  final bool highlighted;
  final String provider, title;
  final String? subtitle;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        backgroundColor: highlighted
            ? Color.alphaBlend(
                Theme.of(context).colorScheme.primary.withValues(alpha: .055),
                Theme.of(context).colorScheme.surface,
              )
            : Theme.of(context).colorScheme.surface,
        minimumSize: const Size(48, 58),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(
          color: highlighted
              ? Theme.of(context).colorScheme.primary.withValues(alpha: .6)
              : AppColors.borderFor(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: switch (provider) {
                  'microsoft' => const _MicrosoftMark(),
                  'yahoo' => FittedBox(
                    child: Text(
                      'Y!',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 23,
                      ),
                    ),
                  ),
                  _ => const _GoogleMark(),
                },
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(title)),
              const SizedBox(width: 12),
              SizedBox.square(
                dimension: 20,
                child: isLoading
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Connecting account',
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.mutedFor(context),
                      ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    ),
  );
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

class _SignInLegalLinks extends StatelessWidget {
  const _SignInLegalLinks();
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 4,
    children: [
      TextButton(
        onPressed: () => openSenderWhoPublicPage(
          context,
          url: AppConfig.privacyPolicyUrl,
          pageName: 'the Privacy Policy',
        ),
        child: const Text('Privacy Policy'),
      ),
      TextButton(
        onPressed: () => openSenderWhoPublicPage(
          context,
          url: AppConfig.termsOfServiceUrl,
          pageName: 'the Terms of Service',
        ),
        child: const Text('Terms of Service'),
      ),
    ],
  );
}

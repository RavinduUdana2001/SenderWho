import 'dart:async';

import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'services/senderwho_repository.dart';
import 'services/repository_scope.dart';
import 'utils/app_navigation.dart';
import 'screens/activity_insights_screen.dart';
import 'screens/alert_details_screen.dart';
import 'screens/all_senders_screen.dart';
import 'screens/block_senders_screen.dart';
import 'screens/bulk_clean_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/connect_email_screen.dart';
import 'screens/connected_accounts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/delete_emails_screen.dart';
import 'screens/email_details_screen.dart';
import 'screens/emails_screen.dart';
import 'screens/inbox_health_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/privacy_security_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/review_promotions_screen.dart';
import 'screens/search_filter_screen.dart';
import 'screens/security_alerts_screen.dart';
import 'screens/sender_details_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/top_senders_screen.dart';
import 'screens/unsubscribe_screen.dart';
import 'theme/app_theme.dart';
import 'theme/app_motion.dart';
import 'theme/theme_mode_controller.dart';
import 'theme/theme_preference_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  final themePreferenceStore = SecureThemePreferenceStore();
  WidgetsBinding.instance.deferFirstFrame();
  runApp(
    SenderWhoApp(
      startOAuth: AppConfig.uiPreviewMode ? (_) async => true : null,
      themePreferenceStore: themePreferenceStore,
      startup: _prepareLaunch(themePreferenceStore),
      onSplashReady: WidgetsBinding.instance.allowFirstFrame,
      firstFrameRasterized:
          WidgetsBinding.instance.waitUntilFirstFrameRasterized,
    ),
  );
}

Future<AppLaunchState> _prepareLaunch(ThemePreferenceStore store) async {
  // Draw the splash immediately while storage and the session load together.
  final savedTheme = _readSavedTheme(store);
  var authenticated = false;
  if (!AppConfig.uiPreviewMode) {
    try {
      authenticated = await senderWhoRepository.restoreSession();
    } on Object {
      // Sign-in stays available when session restoration fails.
    }
  }
  // Remote preferences refresh after the first page is visible. They must not
  // hold the splash open for an additional network request.
  return AppLaunchState(
    authenticated: authenticated,
    themeMode: await savedTheme,
  );
}

class SenderWhoApp extends StatefulWidget {
  const SenderWhoApp({
    super.key,
    this.startOAuth,
    this.initiallyAuthenticated = false,
    this.initialThemeMode = ThemeMode.dark,
    this.themePreferenceStore,
    this.repository,
    this.startup,
    this.onSplashReady,
    this.firstFrameRasterized,
  });

  final Future<bool> Function(String provider)? startOAuth;
  final bool initiallyAuthenticated;
  final ThemeMode initialThemeMode;
  final ThemePreferenceStore? themePreferenceStore;
  final SenderWhoRepository? repository;

  /// Supplied by the real entry point; tests may also start after initialization.
  final Future<AppLaunchState>? startup;
  final VoidCallback? onSplashReady;
  final Future<void>? firstFrameRasterized;

  @override
  State<SenderWhoApp> createState() => _SenderWhoAppState();
}

class _SenderWhoAppState extends State<SenderWhoApp> {
  late ThemeMode _themeMode;
  late final ThemePreferenceStore _themePreferenceStore;
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _routeObserver = AppNavigationObserver();
  bool _booting = false;
  bool _launchRevealing = false;
  int _themeRevision = 0;
  int _contextRevision = 0;
  Future<void> _themeWrite = Future.value();
  SenderWhoRepository get _repository =>
      widget.repository ?? senderWhoRepository;

  @override
  void initState() {
    super.initState();
    _booting = widget.startup != null;
    _themeMode = widget.initialThemeMode;
    _themePreferenceStore =
        widget.themePreferenceStore ?? SecureThemePreferenceStore();
    _repository.authenticationState.addListener(_handleAuthState);
    _repository.mailboxRevision.addListener(_handleMailboxChange);
    if (!_booting && widget.initiallyAuthenticated) {
      unawaited(_loadUserContext());
    }
  }

  @override
  void dispose() {
    _repository.authenticationState.removeListener(_handleAuthState);
    _repository.mailboxRevision.removeListener(_handleMailboxChange);
    super.dispose();
  }

  void _handleAuthState() {
    if (_booting) return;
    _contextRevision++;
    if (_repository.authenticationState.value) {
      unawaited(_loadUserContext());
      // A slow startup refresh can finish after the brief splash has yielded
      // to welcome. Resume the restored session unless sign-in has been opened.
      if (_routeObserver.currentName == '/') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              !_repository.isAuthenticated ||
              _routeObserver.currentName != '/') {
            return;
          }
          _navigatorKey.currentState?.pushNamedAndRemoveUntil(
            AllSendersScreen.routeName,
            (_) => false,
          );
        });
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
    });
  }

  void _finishLaunch(AppLaunchState launch) {
    if (!mounted || !_booting) return;
    setState(() {
      _booting = false;
      _launchRevealing = true;
      _themeMode = launch.themeMode;
    });
    final navigator = _navigatorKey.currentState!;
    final reducedMotion = MediaQuery.disableAnimationsOf(navigator.context);
    final route = PageRouteBuilder<void>(
      transitionDuration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 320),
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
        child: child,
      ),
      settings: RouteSettings(
        name: launch.authenticated ? AllSendersScreen.routeName : '/',
      ),
      pageBuilder: (_, _, _) => launch.authenticated
          ? AllSendersScreen(repository: _repository)
          : const OnboardingScreen(animateEntrance: false),
    );
    navigator.pushReplacement(route);
    void revealed(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      route.animation?.removeStatusListener(revealed);
      if (!mounted) return;
      setState(() => _launchRevealing = false);
      if (launch.authenticated) unawaited(_loadUserContext());
    }

    // A route exposes an already-completed placeholder animation before the
    // Navigator installs it. Observe the real animation after its first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!route.isActive) {
        setState(() => _launchRevealing = false);
        return;
      }
      route.animation?.addStatusListener(revealed);
      if (route.animation?.status == AnimationStatus.completed) {
        revealed(AnimationStatus.completed);
      }
    });
  }

  void _setThemeMode(ThemeMode mode) {
    if (!mounted || mode == _themeMode) return;
    _themeRevision++;
    setState(() => _themeMode = mode);
    _themeWrite = _themeWrite.then(
      (_) => _saveTheme(_themePreferenceStore, mode),
    );
  }

  Future<bool> _changeThemeMode(
    ThemeMode mode,
    Future<bool> Function() save,
  ) async {
    final previous = _themeMode;
    _themeRevision++;
    _setThemeMode(mode);
    final revision = _themeRevision;
    var saved = false;
    try {
      saved = await save();
    } on Object {
      saved = false;
    }
    if (!saved && mounted && revision == _themeRevision) {
      _setThemeMode(previous);
    }
    return saved;
  }

  Future<void> _loadUserContext() async {
    if (!_repository.isAuthenticated) return;
    final contextRevision = _contextRevision;
    final themeRevision = _themeRevision;
    await Future.wait<void>([
      (() async {
        try {
          await _repository.getUserProfile(refresh: true);
        } on Object {
          /* Retry from Profile. */
        }
      })(),
      (() async {
        try {
          await _repository.getConnectedAccounts();
        } on Object {
          /* Retry from Accounts. */
        }
      })(),
      (() async {
        try {
          final settings = await _repository.getSettings();
          if (mounted &&
              _repository.isAuthenticated &&
              contextRevision == _contextRevision &&
              themeRevision == _themeRevision) {
            _setThemeMode(_themeModeFromSetting(settings.theme));
          }
        } on Object {
          /* Keep the saved device theme during an outage. */
        }
      })(),
    ]);
  }

  void _handleMailboxChange() {
    if (_booting) return;
    if (!_repository.isAuthenticated) return;
    _contextRevision++;
    final destination =
        _routeObserver.lastMailboxRoute == EmailsScreen.routeName
        ? EmailsScreen.routeName
        : AllSendersScreen.routeName;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_repository.isAuthenticated) return;
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        destination,
        (_) => false,
      );
      unawaited(_loadUserContext());
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    return RepositoryScope(
      repository: _repository,
      child: ThemeModeController(
        mode: _themeMode,
        setThemeMode: _setThemeMode,
        updateThemeMode: _changeThemeMode,
        child: MaterialApp(
          navigatorKey: _navigatorKey,
          navigatorObservers: [_routeObserver],
          title: 'SenderWho',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _themeMode,
          themeAnimationDuration: reduceMotion || _booting || _launchRevealing
              ? AppMotion.instant
              : AppMotion.standard,
          themeAnimationCurve: AppMotion.emphasized,
          home: widget.startup != null
              ? SplashScreen(
                  startup: widget.startup!,
                  onReady: _finishLaunch,
                  onLogoReady: widget.onSplashReady,
                  firstFrameRasterized: widget.firstFrameRasterized,
                )
              : widget.initiallyAuthenticated
              ? null
              : const OnboardingScreen(),
          initialRoute: widget.startup == null && widget.initiallyAuthenticated
              ? AllSendersScreen.routeName
              : null,
          onGenerateRoute: (settings) {
            final pages = <String, WidgetBuilder>{
              ConnectEmailScreen.routeName: (_) => ConnectEmailScreen(
                startOAuth:
                    widget.startOAuth ??
                    (AppConfig.uiPreviewMode ? (_) async => true : null),
              ),
              DashboardScreen.routeName: (_) => const DashboardScreen(),
              InboxHealthScreen.routeName: (_) => const InboxHealthScreen(),
              SecurityAlertsScreen.routeName: (_) =>
                  SecurityAlertsScreen(repository: _repository),
              AlertDetailsScreen.routeName: (_) =>
                  AlertDetailsScreen(repository: _repository),
              BlockSendersScreen.routeName: (_) => const BlockSendersScreen(),
              DeleteEmailsScreen.routeName: (_) => const DeleteEmailsScreen(),
              EmailsScreen.routeName: (_) =>
                  EmailsScreen(repository: _repository),
              EmailDetailsScreen.routeName: (_) =>
                  EmailDetailsScreen(repository: _repository),
              AllSendersScreen.routeName: (_) =>
                  AllSendersScreen(repository: _repository),
              SenderDetailsScreen.routeName: (_) =>
                  SenderDetailsScreen(repository: _repository),
              CategoriesScreen.routeName: (_) => const CategoriesScreen(),
              BulkCleanScreen.routeName: (_) =>
                  BulkCleanScreen(repository: _repository),
              ReviewPromotionsScreen.routeName: (_) =>
                  const ReviewPromotionsScreen(),
              UnsubscribeScreen.routeName: (_) =>
                  UnsubscribeScreen(repository: _repository),
              SearchFilterScreen.routeName: (_) =>
                  SearchFilterScreen(repository: _repository),
              TopSendersScreen.routeName: (_) => const TopSendersScreen(),
              ActivityInsightsScreen.routeName: (_) =>
                  const ActivityInsightsScreen(),
              SettingsScreen.routeName: (_) =>
                  SettingsScreen(repository: _repository),
              ConnectedAccountsScreen.routeName: (_) =>
                  ConnectedAccountsScreen(repository: _repository),
              PrivacySecurityScreen.routeName: (_) =>
                  PrivacySecurityScreen(repository: _repository),
              ProfileScreen.routeName: (_) => const ProfileScreen(),
            };
            final builder = pages[settings.name];
            if (builder == null) return null;
            return AppNavigation.route(
              settings: settings,
              builder: builder,
              disableAnimations: reduceMotion,
            );
          },
        ),
      ),
    );
  }
}

ThemeMode _themeModeFromSetting(String value) {
  return switch (value) {
    'Light' => ThemeMode.light,
    'Dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

Future<ThemeMode> _readSavedTheme(ThemePreferenceStore store) async {
  try {
    return await store.read().timeout(const Duration(seconds: 2)) ??
        ThemeMode.dark;
  } on Object {
    // Explicit saved choices win; fresh installs and storage outages use dark.
    return ThemeMode.dark;
  }
}

Future<void> _saveTheme(ThemePreferenceStore store, ThemeMode mode) async {
  try {
    await store.write(mode);
  } on Object {
    // The visible theme still updates when local persistence is unavailable.
  }
}

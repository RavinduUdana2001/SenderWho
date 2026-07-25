import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'services/senderwho_repository.dart';
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
import 'theme/theme_mode_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  final previewMode = AppConfig.uiPreviewMode;
  final authenticated = previewMode
      ? false
      : await senderWhoRepository.restoreSession();
  var initialThemeMode = ThemeMode.system;
  if (authenticated) {
    try {
      final settings = await senderWhoRepository.getSettings();
      initialThemeMode = _themeModeFromSetting(settings.theme);
    } on SenderWhoRequestException {
      // A temporary settings outage must not prevent an authenticated user
      // from opening the app. The settings screen exposes a retry action.
    }
  }
  runApp(
    SenderWhoApp(
      startOAuth: previewMode ? (_) async => true : null,
      initiallyAuthenticated: authenticated,
      initialThemeMode: initialThemeMode,
    ),
  );
}

class SenderWhoApp extends StatefulWidget {
  const SenderWhoApp({
    super.key,
    this.startOAuth,
    this.initiallyAuthenticated = false,
    this.initialThemeMode = ThemeMode.system,
  });

  final Future<bool> Function(String provider)? startOAuth;
  final bool initiallyAuthenticated;
  final ThemeMode initialThemeMode;

  @override
  State<SenderWhoApp> createState() => _SenderWhoAppState();
}

class _SenderWhoAppState extends State<SenderWhoApp> {
  late ThemeMode _themeMode;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
    senderWhoRepository.authenticationState.addListener(_handleAuthState);
  }

  @override
  void dispose() {
    senderWhoRepository.authenticationState.removeListener(_handleAuthState);
    super.dispose();
  }

  void _handleAuthState() {
    if (senderWhoRepository.authenticationState.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
    });
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return ThemeModeController(
      mode: _themeMode,
      setThemeMode: _setThemeMode,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'SenderWho',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _themeMode,
        home: widget.initiallyAuthenticated ? null : const OnboardingScreen(),
        initialRoute: widget.initiallyAuthenticated
            ? DashboardScreen.routeName
            : null,
        routes: {
          ConnectEmailScreen.routeName: (_) => ConnectEmailScreen(
            startOAuth:
                widget.startOAuth ??
                (AppConfig.uiPreviewMode ? (_) async => true : null),
          ),
          DashboardScreen.routeName: (_) => const DashboardScreen(),
          InboxHealthScreen.routeName: (_) => const InboxHealthScreen(),
          SecurityAlertsScreen.routeName: (_) => const SecurityAlertsScreen(),
          AlertDetailsScreen.routeName: (_) => const AlertDetailsScreen(),
          BlockSendersScreen.routeName: (_) => const BlockSendersScreen(),
          DeleteEmailsScreen.routeName: (_) => const DeleteEmailsScreen(),
          EmailsScreen.routeName: (_) => const EmailsScreen(),
          EmailDetailsScreen.routeName: (_) => const EmailDetailsScreen(),
          AllSendersScreen.routeName: (_) => const AllSendersScreen(),
          SenderDetailsScreen.routeName: (_) => const SenderDetailsScreen(),
          CategoriesScreen.routeName: (_) => const CategoriesScreen(),
          BulkCleanScreen.routeName: (_) => const BulkCleanScreen(),
          ReviewPromotionsScreen.routeName: (_) =>
              const ReviewPromotionsScreen(),
          UnsubscribeScreen.routeName: (_) => const UnsubscribeScreen(),
          SearchFilterScreen.routeName: (_) => const SearchFilterScreen(),
          TopSendersScreen.routeName: (_) => const TopSendersScreen(),
          ActivityInsightsScreen.routeName: (_) =>
              const ActivityInsightsScreen(),
          SettingsScreen.routeName: (_) => const SettingsScreen(),
          ConnectedAccountsScreen.routeName: (_) =>
              const ConnectedAccountsScreen(),
          PrivacySecurityScreen.routeName: (_) => const PrivacySecurityScreen(),
          ProfileScreen.routeName: (_) => const ProfileScreen(),
        },
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

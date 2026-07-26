import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/config/app_config.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/models/app_models.dart';
import 'package:sender_who/screens/activity_insights_screen.dart';
import 'package:sender_who/screens/alert_details_screen.dart';
import 'package:sender_who/screens/all_senders_screen.dart';
import 'package:sender_who/screens/block_senders_screen.dart';
import 'package:sender_who/screens/bulk_clean_screen.dart';
import 'package:sender_who/screens/categories_screen.dart';
import 'package:sender_who/screens/connect_email_screen.dart';
import 'package:sender_who/screens/connected_accounts_screen.dart';
import 'package:sender_who/screens/dashboard_screen.dart';
import 'package:sender_who/screens/delete_emails_screen.dart';
import 'package:sender_who/screens/email_details_screen.dart';
import 'package:sender_who/screens/emails_screen.dart';
import 'package:sender_who/screens/inbox_health_screen.dart';
import 'package:sender_who/screens/privacy_security_screen.dart';
import 'package:sender_who/screens/profile_screen.dart';
import 'package:sender_who/screens/review_promotions_screen.dart';
import 'package:sender_who/screens/search_filter_screen.dart';
import 'package:sender_who/screens/security_alerts_screen.dart';
import 'package:sender_who/screens/sender_details_screen.dart';
import 'package:sender_who/screens/settings_screen.dart';
import 'package:sender_who/screens/top_senders_screen.dart';
import 'package:sender_who/screens/unsubscribe_screen.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/app_colors.dart';
import 'package:sender_who/theme/app_theme.dart';
import 'package:sender_who/widgets/app_card.dart';
import 'package:sender_who/widgets/section_title.dart';

void main() {
  final providerActionLabel = AppConfig.uiPreviewMode
      ? 'Connect my inbox'
      : 'Continue with Google';
  double contrastRatio(Color first, Color second) {
    final lighter = first.computeLuminance() > second.computeLuminance()
        ? first.computeLuminance()
        : second.computeLuminance();
    final darker = first.computeLuminance() > second.computeLuminance()
        ? second.computeLuminance()
        : first.computeLuminance();
    return (lighter + 0.05) / (darker + 0.05);
  }

  test('dark palette keeps primary and secondary copy readable', () {
    expect(
      contrastRatio(AppColors.darkText, AppColors.darkCard),
      greaterThan(7),
    );
    expect(
      contrastRatio(AppColors.darkMuted, AppColors.darkCard),
      greaterThan(4.5),
    );
    expect(contrastRatio(Colors.white, AppColors.brandBlue), greaterThan(4.5));
    expect(AppColors.success, AppColors.brandBlue);
    expect(contrastRatio(Colors.white, AppColors.success), greaterThan(4.5));
    expect(
      contrastRatio(Colors.white, AppColors.brandViolet),
      greaterThan(4.5),
    );
    expect(
      contrastRatio(AppColors.brandNavy, AppColors.brandCyan),
      greaterThan(4.5),
    );
  });

  final routeSmokeCases = <({String route, String expectedText})>[
    (route: ConnectEmailScreen.routeName, expectedText: 'Connect your inbox'),
    (route: DashboardScreen.routeName, expectedText: 'Dashboard'),
    (route: InboxHealthScreen.routeName, expectedText: 'Inbox Health'),
    (route: SecurityAlertsScreen.routeName, expectedText: 'Security Alerts'),
    (route: AlertDetailsScreen.routeName, expectedText: 'Alert Details'),
    (route: BlockSendersScreen.routeName, expectedText: 'Block Sender'),
    (route: DeleteEmailsScreen.routeName, expectedText: 'Delete Emails'),
    (route: EmailsScreen.routeName, expectedText: 'Inbox'),
    (route: EmailDetailsScreen.routeName, expectedText: 'Message'),
    (route: AllSendersScreen.routeName, expectedText: 'All Senders'),
    (route: SenderDetailsScreen.routeName, expectedText: 'Sender Details'),
    (route: CategoriesScreen.routeName, expectedText: 'Categories'),
    (route: BulkCleanScreen.routeName, expectedText: 'Bulk Clean'),
    (
      route: ReviewPromotionsScreen.routeName,
      expectedText: 'Review Promotions',
    ),
    (route: UnsubscribeScreen.routeName, expectedText: 'Unsubscribe'),
    (route: SearchFilterScreen.routeName, expectedText: 'Search & Filter'),
    (route: TopSendersScreen.routeName, expectedText: 'Top Senders'),
    (route: ActivityInsightsScreen.routeName, expectedText: 'Activity'),
    (route: SettingsScreen.routeName, expectedText: 'Settings'),
    (
      route: ConnectedAccountsScreen.routeName,
      expectedText: 'Connected Accounts',
    ),
    (
      route: PrivacySecurityScreen.routeName,
      expectedText: 'Privacy & Security',
    ),
    (route: ProfileScreen.routeName, expectedText: 'Profile'),
  ];

  Future<void> setScreenSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
    });
  }

  testWidgets('SenderWho opens connect flow at the Figma mobile size', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(SenderWhoApp(startOAuth: (_) async => true));

    expect(find.byKey(const ValueKey('onboarding-brand-icon')), findsOneWidget);
    expect(find.text('Connect my inbox'), findsOneWidget);
    expect(tester.getRect(find.text('Connect my inbox')).bottom, lessThan(844));

    await tester.tap(find.text('Connect my inbox'));
    await tester.pumpAndSettle();

    expect(find.text('Connect your inbox'), findsOneWidget);
    expect(find.text(providerActionLabel), findsOneWidget);
    expect(
      tester.getRect(find.text(providerActionLabel)).bottom,
      lessThan(844),
    );

    await tester.tap(find.text(providerActionLabel));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('INBOX HEALTH'), findsOneWidget);
  });

  testWidgets('SenderWho onboarding remains usable on a compact phone', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(320, 568));
    await tester.pumpWidget(SenderWhoApp(startOAuth: (_) async => true));

    expect(find.byKey(const ValueKey('onboarding-brand-icon')), findsOneWidget);
    expect(find.text('Connect my inbox'), findsOneWidget);

    await tester.ensureVisible(find.text('Connect my inbox'));
    await tester.tap(find.text('Connect my inbox'));
    await tester.pumpAndSettle();

    expect(find.text('Connect your inbox'), findsOneWidget);
  });

  testWidgets(
    'Yahoo connection requests an app password, not a normal password',
    (tester) async {
      await setScreenSize(tester, const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const ConnectEmailScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Yahoo'));
      await tester.pumpAndSettle();

      expect(find.text('Connect Yahoo Mail'), findsOneWidget);
      expect(find.text('Yahoo email'), findsOneWidget);
      expect(find.text('Generated app password'), findsOneWidget);
      expect(
        find.textContaining('Do not enter your normal Yahoo password'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Entry screens stay centered on a tall phone', (tester) async {
    await setScreenSize(tester, const Size(430, 932));
    await tester.pumpWidget(SenderWhoApp(startOAuth: (_) async => true));

    final onboardingTop = tester
        .getRect(find.byKey(const ValueKey('onboarding-brand-icon')))
        .top;
    final onboardingBottom = tester
        .getRect(find.text('Private by design. You remain in control.'))
        .bottom;
    expect((onboardingTop + onboardingBottom) / 2, closeTo(932 / 2, 55));

    await tester.tap(find.text('Connect my inbox'));
    await tester.pumpAndSettle();

    final backTop = tester.getRect(find.byTooltip('Back')).top;
    expect(backTop, lessThan(80));

    final connectTop = tester
        .getRect(find.byKey(const ValueKey('connect-brand-icon')))
        .top;
    final connectBottom = tester
        .getRect(
          find.textContaining('SenderWho stores metadata and short previews'),
        )
        .bottom;
    expect((connectTop + connectBottom) / 2, closeTo(932 / 2, 55));

    final providerCard = tester.getRect(
      find
          .ancestor(
            of: find.text(providerActionLabel),
            matching: find.byType(AppCard),
          )
          .first,
    );
    expect(providerCard.width, lessThanOrEqualTo(420));
    expect(providerCard.center.dx, closeTo(430 / 2, 1));
  });

  testWidgets('Onboarding brand is prominent and hero copy is centered', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(430, 932));
    await tester.pumpWidget(const SenderWhoApp());

    expect(
      tester.getSize(find.byKey(const ValueKey('onboarding-brand-icon'))),
      const Size(168, 168),
    );
    final hero = tester.widget<RichText>(
      find.byKey(const ValueKey('onboarding-hero-title')),
    );
    expect(hero.textAlign, TextAlign.center);

    final subtitle = tester.widget<Text>(
      find.text(
        'Know who is emailing you, clean inbox clutter, and stay protected from risky senders.',
      ),
    );
    expect(subtitle.textAlign, TextAlign.center);
  });

  testWidgets('Google sign-in failures render an inline recovery state', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(SenderWhoApp(startOAuth: (_) async => false));

    await tester.tap(find.text('Connect my inbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(providerActionLabel));
    await tester.pumpAndSettle();

    expect(find.text('Connection not completed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Every named route renders at the Figma mobile size', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));

    for (final routeCase in routeSmokeCases) {
      await tester.pumpWidget(const SenderWhoApp());

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed(routeCase.route);
      await tester.pumpAndSettle();

      expect(
        find.text(routeCase.expectedText),
        findsWidgets,
        reason: '${routeCase.route} should render ${routeCase.expectedText}',
      );
    }
  });

  testWidgets('Every named route renders in dark mode', (tester) async {
    await setScreenSize(tester, const Size(390, 844));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    for (final routeCase in routeSmokeCases) {
      await tester.pumpWidget(const SenderWhoApp());

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed(routeCase.route);
      await tester.pumpAndSettle();

      expect(
        find.text(routeCase.expectedText),
        findsWidgets,
        reason:
            '${routeCase.route} should render ${routeCase.expectedText} in dark mode',
      );
    }
  });

  testWidgets('Every named route renders on a compact phone', (tester) async {
    await setScreenSize(tester, const Size(320, 568));

    for (final routeCase in routeSmokeCases) {
      await tester.pumpWidget(const SenderWhoApp());

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed(routeCase.route);
      await tester.pumpAndSettle();

      expect(
        find.text(routeCase.expectedText),
        findsWidgets,
        reason:
            '${routeCase.route} should render ${routeCase.expectedText} on compact phones',
      );
    }
  });

  testWidgets('Every named route renders on a large phone', (tester) async {
    await setScreenSize(tester, const Size(430, 932));

    for (final routeCase in routeSmokeCases) {
      await tester.pumpWidget(const SenderWhoApp());

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed(routeCase.route);
      await tester.pumpAndSettle();

      expect(
        find.text(routeCase.expectedText),
        findsWidgets,
        reason:
            '${routeCase.route} should render ${routeCase.expectedText} on large phones',
      );
    }
  });

  testWidgets('Every named route supports enlarged text', (tester) async {
    await setScreenSize(tester, const Size(390, 844));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final routeCase in routeSmokeCases) {
      await tester.pumpWidget(const SenderWhoApp());

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed(routeCase.route);
      await tester.pumpAndSettle();

      expect(
        find.text(routeCase.expectedText),
        findsWidgets,
        reason:
            '${routeCase.route} should render ${routeCase.expectedText} with enlarged text',
      );
    }
  });

  testWidgets('Every named route remains centered on a tablet viewport', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(768, 1024));

    for (final routeCase in routeSmokeCases) {
      await tester.pumpWidget(const SenderWhoApp());

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed(routeCase.route);
      await tester.pumpAndSettle();

      expect(
        find.text(routeCase.expectedText),
        findsWidgets,
        reason:
            '${routeCase.route} should render ${routeCase.expectedText} on tablet widths',
      );
    }
  });

  testWidgets('Every named route supports a short landscape viewport', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(844, 390));

    for (final routeCase in routeSmokeCases) {
      await tester.pumpWidget(const SenderWhoApp());

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed(routeCase.route);
      await tester.pumpAndSettle();

      expect(
        find.text(routeCase.expectedText),
        findsWidgets,
        reason:
            '${routeCase.route} should render ${routeCase.expectedText} in landscape',
      );
    }
  });

  testWidgets('Main flow renders with dark system brightness', (tester) async {
    await setScreenSize(tester, const Size(390, 844));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(SenderWhoApp(startOAuth: (_) async => true));
    await tester.ensureVisible(find.text('Connect my inbox'));
    await tester.tap(find.text('Connect my inbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(providerActionLabel));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('INBOX HEALTH'), findsOneWidget);
  });

  testWidgets('Dashboard title remains centered between its actions', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const SenderWhoApp());

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(DashboardScreen.routeName);
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.text('Dashboard').first).dx,
      closeTo(390 / 2, 1),
    );
    expect(
      find.byKey(const ValueKey('dashboard-header-title')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('app-header-subtitle')), findsNothing);
  });

  testWidgets('main destinations keep the hamburger when pushed', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const SenderWhoApp(initiallyAuthenticated: true));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open menu'), findsOneWidget);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(SettingsScreen.routeName);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open menu'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('shared section headings inherit the application typography', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SectionTitle(title: 'About this sender')),
      ),
    );

    final context = tester.element(find.text('About this sender'));
    final heading = tester.widget<Text>(find.text('About this sender'));
    final sharedStyle = Theme.of(context).textTheme.titleMedium;
    expect(heading.style?.fontSize, sharedStyle?.fontSize);
    expect(heading.style?.fontWeight, FontWeight.w800);
    expect(heading.style?.letterSpacing, 0);
  });

  testWidgets('Bulk Clean reviews selection and runs the real job lifecycle', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    var suggestionsLoads = 0;
    var cleanupStarted = false;
    var jobPolls = 0;
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/cleanup/suggestions')) {
          suggestionsLoads += 1;
          return http.Response(
            jsonEncode({
              'items': suggestionsLoads == 1
                  ? [
                      {
                        'id': 'suggestion-1',
                        'emailAccountId': 'account-1',
                        'categoryKey': 'MARKETING',
                        'category': 'Promotions',
                        'messageCount': 10,
                        'estimatedSpaceBytes': 8192,
                      },
                    ]
                  : <Object>[],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/cleanup/preview')) {
          expect(jsonDecode(request.body), {
            'emailAccountId': 'account-1',
            'categories': ['MARKETING'],
          });
          return http.Response(
            jsonEncode({
              'previewId': 'preview-1',
              'emailAccountId': 'account-1',
              'categories': ['MARKETING'],
              'totalMessages': 7,
              'estimatedSpaceBytes': 6144,
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/cleanup/jobs') &&
            request.method == 'POST') {
          expect(jsonDecode(request.body), {
            'emailAccountId': 'account-1',
            'categories': ['MARKETING'],
            'previewId': 'preview-1',
          });
          cleanupStarted = true;
          return http.Response(
            jsonEncode({
              'id': 'job-1',
              'status': 'QUEUED',
              'totalMessages': 7,
              'processedMessages': 0,
              'failedMessages': 0,
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/cleanup/jobs') &&
            request.method == 'GET') {
          return http.Response(jsonEncode({'items': <Object>[]}), 200);
        }
        if (request.url.path.endsWith('/cleanup/jobs/job-1')) {
          jobPolls += 1;
          return http.Response(
            jsonEncode({
              'id': 'job-1',
              'status': 'COMPLETED',
              'totalMessages': 7,
              'processedMessages': 7,
              'failedMessages': 0,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BulkCleanScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Promotions'), findsOneWidget);
    expect(find.textContaining('Promotional offers'), findsOneWidget);
    expect(find.text('Select at least one group'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cleanup-select-suggestion-1')));
    await tester.pump();
    await tester.ensureVisible(find.text('Review & clean 1 group'));
    await tester.tap(find.text('Review & clean 1 group'));
    await tester.pumpAndSettle();

    expect(find.text('Clean selected messages?'), findsOneWidget);
    expect(find.text('7 messages · 6.0 KB'), findsOneWidget);
    expect(find.text('Clean now'), findsOneWidget);

    await tester.tap(find.text('Clean now'));
    await tester.pumpAndSettle();

    expect(cleanupStarted, isTrue);
    expect(jobPolls, greaterThanOrEqualTo(1));
    expect(find.text('Cleanup finished'), findsOneWidget);
    expect(find.text('7 cleaned'), findsOneWidget);
  });

  testWidgets('Bulk Clean keeps partial failures in the running state', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/cleanup/suggestions')) {
          return http.Response(jsonEncode({'items': <Object>[]}), 200);
        }
        if (request.url.path.endsWith('/cleanup/jobs')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'job-active',
                  'status': 'RUNNING',
                  'totalMessages': 20,
                  'processedMessages': 8,
                  'failedMessages': 1,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/cleanup/jobs/job-active')) {
          return http.Response(
            jsonEncode({
              'id': 'job-active',
              'status': 'RUNNING',
              'totalMessages': 20,
              'processedMessages': 8,
              'failedMessages': 1,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BulkCleanScreen(repository: repository),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Cleaning messages'), findsOneWidget);
    expect(
      find.text('Cleanup continues safely in the background.'),
      findsOneWidget,
    );
    expect(find.textContaining('Refresh the suggestions'), findsNothing);
    expect(find.text('Cleanup in progress…'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Unsubscribe restores and displays each active job state', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    var candidateLoads = 0;
    var jobPolls = 0;
    final candidate = {
      'id': 'sender-1',
      'name': 'Example Newsletter',
      'email': 'news@example.test',
      'reason': 'Supports secure one-click unsubscribe',
      'colorKey': 'warning',
    };
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/unsubscribe/candidates')) {
          candidateLoads += 1;
          return http.Response(
            jsonEncode({
              'items': candidateLoads == 1 ? [candidate] : <Object>[],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/unsubscribe/jobs') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'job-restored',
                  'senderId': 'sender-1',
                  'status': 'QUEUED',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/unsubscribe/jobs/status')) {
          jobPolls += 1;
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'job-restored',
                  'senderId': 'sender-1',
                  'status': jobPolls == 1 ? 'RUNNING' : 'COMPLETED',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: UnsubscribeScreen(repository: repository),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Queued'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('Running'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Request accepted'), findsNothing);
    expect(find.text('Example Newsletter'), findsNothing);
    expect(candidateLoads, 2);
    expect(jobPolls, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Failed unsubscribe remains visible and can be retried', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    var createCalls = 0;
    var jobPolls = 0;
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/unsubscribe/candidates')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'sender-1',
                  'name': 'Example Newsletter',
                  'email': 'news@example.test',
                  'reason': 'Supports secure one-click unsubscribe',
                  'colorKey': 'warning',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/unsubscribe/jobs' &&
            request.method == 'GET') {
          return http.Response(jsonEncode({'items': <Object>[]}), 200);
        }
        if (request.url.path == '/api/v1/unsubscribe/jobs' &&
            request.method == 'POST') {
          createCalls += 1;
          expect(jsonDecode(request.body), {'senderId': 'sender-1'});
          return http.Response(
            jsonEncode({
              'id': 'job-1',
              'senderId': 'sender-1',
              'status': 'QUEUED',
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/unsubscribe/jobs/status')) {
          jobPolls += 1;
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 'job-1', 'senderId': 'sender-1', 'status': 'FAILED'},
              ],
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: UnsubscribeScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Unsubscribe'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Unsubscribe'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Queued'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(jobPolls, 1);
    expect(find.text('Failed'), findsOneWidget);
    expect(
      find.text('The provider could not complete this request. Please retry.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('unsubscribe-retry-sender-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('unsubscribe-retry-sender-1')));
    await tester.pumpAndSettle();
    expect(
      find.text('Retry unsubscribe from Example Newsletter?'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(createCalls, 2);
    expect(find.text('Queued'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'Trust removes an unsubscribe candidate and persists on refresh',
    (tester) async {
      await setScreenSize(tester, const Size(390, 844));
      var candidateLoads = 0;
      var trustCalls = 0;
      final repository = SenderWhoRepository(
        previewMode: false,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/unsubscribe/candidates')) {
            candidateLoads += 1;
            return http.Response(
              jsonEncode({
                'items': candidateLoads == 1
                    ? [
                        {
                          'id': 'sender-1',
                          'name': 'Example Newsletter',
                          'email': 'news@example.test',
                          'reason': 'Supports secure one-click unsubscribe',
                          'colorKey': 'warning',
                        },
                      ]
                    : <Object>[],
              }),
              200,
            );
          }
          if (request.method == 'GET' &&
              request.url.path == '/api/v1/unsubscribe/jobs') {
            return http.Response(jsonEncode({'items': <Object>[]}), 200);
          }
          if (request.method == 'PATCH' &&
              request.url.path == '/api/v1/senders/sender-1/trust') {
            trustCalls += 1;
            expect(jsonDecode(request.body), {'trusted': true});
            return http.Response(
              jsonEncode({
                'id': 'sender-1',
                'isTrusted': true,
                'isBlocked': false,
              }),
              200,
            );
          }
          return http.Response('Not found', 404);
        }),
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: UnsubscribeScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('trust-unsubscribe-sender-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trust Example Newsletter?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Trust sender'));
      await tester.pumpAndSettle();

      expect(trustCalls, 1);
      expect(candidateLoads, 2);
      expect(find.text('Example Newsletter'), findsNothing);
      expect(find.text('You are all caught up'), findsOneWidget);
      expect(
        find.textContaining('is now trusted and was removed'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Unsubscribe polling backs off and pauses after five failures', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    var pollCalls = 0;
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/unsubscribe/candidates')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'sender-1',
                  'name': 'Example Newsletter',
                  'email': 'news@example.test',
                  'reason': 'Supports secure one-click unsubscribe',
                  'colorKey': 'warning',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/unsubscribe/jobs') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'job-restored',
                  'senderId': 'sender-1',
                  'status': 'QUEUED',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/unsubscribe/jobs/status')) {
          pollCalls += 1;
          return http.Response(
            jsonEncode({'message': 'Progress unavailable'}),
            503,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: UnsubscribeScreen(repository: repository),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Queued'), findsOneWidget);

    for (final delay in const [
      Duration(seconds: 3),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
      Duration(seconds: 30),
    ]) {
      await tester.pump(delay);
      await tester.pump();
    }

    expect(pollCalls, 5);
    expect(
      find.textContaining('Automatic progress updates paused'),
      findsOneWidget,
    );
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(pollCalls, 5);

    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(pollCalls, 6);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Unsubscribe all uses one bounded batch request', (tester) async {
    await setScreenSize(tester, const Size(390, 844));
    var batchCalls = 0;
    var candidateLoads = 0;
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/unsubscribe/candidates')) {
          candidateLoads += 1;
          return http.Response(
            jsonEncode({
              'items': candidateLoads == 1
                  ? [
                      {
                        'id': 'sender-1',
                        'name': 'Newsletter One',
                        'email': 'one@example.test',
                        'reason': 'Supports secure one-click unsubscribe',
                      },
                      {
                        'id': 'sender-2',
                        'name': 'Newsletter Two',
                        'email': 'two@example.test',
                        'reason': 'Supports secure one-click unsubscribe',
                      },
                    ]
                  : <Object>[],
            }),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/unsubscribe/jobs') {
          return http.Response(jsonEncode({'items': <Object>[]}), 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/unsubscribe/jobs/batch') {
          batchCalls += 1;
          expect(jsonDecode(request.body), {
            'senderIds': ['sender-1', 'sender-2'],
          });
          return http.Response(
            jsonEncode({
              'requested': 2,
              'queued': 2,
              'failed': 0,
              'jobs': [
                {'id': 'job-1', 'senderId': 'sender-1', 'status': 'COMPLETED'},
                {'id': 'job-2', 'senderId': 'sender-2', 'status': 'COMPLETED'},
              ],
              'failures': <Object>[],
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: UnsubscribeScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Unsubscribe from All (2)'));
    await tester.tap(find.text('Unsubscribe from All (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Unsubscribe'));
    await tester.pumpAndSettle();

    expect(batchCalls, 1);
    expect(find.text('2 unsubscribe requests queued.'), findsOneWidget);
    expect(find.text('Request accepted'), findsNothing);
  });

  testWidgets('Email details opens the related sender profile', (tester) async {
    await setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const SenderWhoApp());

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(
      EmailDetailsScreen.routeName,
      arguments: const EmailItem(
        id: 'message-1',
        senderId: 'sender-1',
        sender: 'Example Sender',
        email: 'sender@example.com',
        subject: 'Production navigation check',
        date: 'Today',
        accountEmail: 'owner@example.com',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('View sender'), findsOneWidget);
    await tester.tap(find.text('View sender'));
    await tester.pumpAndSettle();

    expect(find.text('Sender Details'), findsOneWidget);
  });

  testWidgets('Sender Details presents a polished readable profile', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/senders/sender-1');
        return http.Response(
          jsonEncode({
            'id': 'sender-1',
            'name': 'Hasintha Nagodavithana',
            'email': 'invitations@linkedin.com',
            'category': 'SOCIAL',
            'score': 80,
            'initial': 'H',
            'colorKey': 'primary',
            'totalMessages': 143,
            'unreadMessages': 12,
            'isTrusted': false,
            'isBlocked': false,
            'firstSeenAt': '2024-11-27T17:37:12.000Z',
            'location': 'Unknown',
            'type': 'SOCIAL',
            'messages': <Object>[],
          }),
          200,
        );
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SenderDetailsScreen(repository: repository, senderId: 'sender-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hasintha Nagodavithana'), findsOneWidget);
    expect(find.text('80 / 100'), findsOneWidget);
    expect(find.text('High trust'), findsOneWidget);
    expect(find.text('Nov 27, 2024'), findsOneWidget);
    expect(find.text('Social'), findsNWidgets(2));
    expect(find.textContaining('2024-11-27T'), findsNothing);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('View all 143'), findsOneWidget);

    final senderName = tester.widget<Text>(find.text('Hasintha Nagodavithana'));
    final header = tester.widget<Text>(find.text('Sender Details'));
    expect(senderName.style?.fontFamily, header.style?.fontFamily);
  });

  testWidgets('Top sender details can persist a trusted sender', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    var detailLoads = 0;
    var trustCalls = 0;
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/senders/sender-1') {
          detailLoads += 1;
          return http.Response(
            jsonEncode({
              'id': 'sender-1',
              'name': 'Top Newsletter',
              'email': 'news@example.test',
              'category': 'NEWSLETTER',
              'score': 72,
              'initial': 'T',
              'colorKey': 'primary',
              'totalMessages': 20,
              'unreadMessages': 2,
              'isTrusted': detailLoads > 1,
              'isBlocked': false,
              'firstSeenAt': '2026-07-01T00:00:00.000Z',
              'location': 'Unknown',
              'type': 'NEWSLETTER',
              'messages': <Object>[],
            }),
            200,
          );
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/api/v1/senders/sender-1/trust') {
          trustCalls += 1;
          expect(jsonDecode(request.body), {'trusted': true});
          return http.Response(
            jsonEncode({
              'id': 'sender-1',
              'isTrusted': true,
              'isBlocked': false,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SenderDetailsScreen(repository: repository, senderId: 'sender-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trust sender'), findsOneWidget);

    await tester.tap(find.text('Trust sender'));
    await tester.pumpAndSettle();

    expect(trustCalls, 1);
    expect(detailLoads, 2);
    expect(find.text('Untrust'), findsOneWidget);
    expect(find.text('Top Newsletter is now trusted.'), findsOneWidget);
  });

  testWidgets('Tapping a real email card opens subject and Gmail body', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    final messageJson = {
      'id': 'message-1',
      'senderId': 'sender-1',
      'threadId': 'thread-1',
      'sender': 'Example Sender',
      'email': 'sender@example.test',
      'subject': 'Open this message',
      'snippet': 'A short stored preview',
      'date': '2026-07-19T09:09:00.000Z',
      'category': 'IMPORTANT',
      'isRead': true,
      'accountEmail': 'owner@example.test',
    };
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/emails/message-1/thread')) {
          return http.Response(
            jsonEncode({
              'threadId': 'thread-1',
              'total': 1,
              'items': [messageJson],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/emails/message-1/content')) {
          return http.Response(
            jsonEncode({
              'id': 'message-1',
              'from': 'Example Sender <sender@example.test>',
              'to': 'owner@example.test',
              'cc': '',
              'subject': 'Open this message',
              'date': '19 July 2026',
              'bodyText': 'This is the complete Gmail body.',
              'truncated': false,
              'attachments': <Object>[],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/emails')) {
          return http.Response(
            jsonEncode({
              'items': [messageJson],
              'total': 1,
              'page': 1,
              'limit': 25,
              'hasMore': false,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: EmailsScreen(repository: repository),
        routes: {
          EmailDetailsScreen.routeName: (_) =>
              EmailDetailsScreen(repository: repository),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open menu'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('email-row-message-1')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('Open menu'), findsNothing);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Open this message'), findsWidgets);
    expect(find.text('This is the complete Gmail body.'), findsOneWidget);
  });

  testWidgets('Archived bulk selection uses the unarchive action', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    var unarchived = false;
    Map<String, dynamic>? mutationBody;
    final archivedMessage = {
      'id': 'message-archived',
      'senderId': 'sender-1',
      'sender': 'Archived Sender',
      'email': 'archived@example.test',
      'subject': 'Archived message',
      'date': '2026-07-20T08:00:00.000Z',
      'category': 'FINANCE',
      'isRead': true,
      'isArchived': true,
      'accountEmail': 'owner@example.test',
    };
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/emails')) {
          final archivedMailbox =
              request.url.queryParameters['mailbox'] == 'ARCHIVED';
          final items = archivedMailbox && !unarchived
              ? [archivedMessage]
              : <Object>[];
          return http.Response(
            jsonEncode({
              'items': items,
              'total': items.length,
              'page': 1,
              'limit': 25,
              'hasMore': false,
            }),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/emails/actions/unarchive')) {
          mutationBody = (jsonDecode(request.body) as Map)
              .cast<String, dynamic>();
          unarchived = true;
          return http.Response(
            jsonEncode({
              'action': 'unarchive',
              'requested': 1,
              'processed': 1,
              'failed': 0,
              'processedIds': ['message-archived'],
              'failures': <Object>[],
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: EmailsScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Archived'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('email-row-message-archived')));
    await tester.pump();

    expect(find.byTooltip('Unarchive'), findsOneWidget);
    expect(find.byTooltip('Archive'), findsNothing);
    await tester.tap(find.byTooltip('Unarchive'));
    await tester.pumpAndSettle();

    expect(mutationBody, {
      'messageIds': ['message-archived'],
    });
    expect(unarchived, isTrue);
    expect(find.text('Nothing to review'), findsOneWidget);
  });

  testWidgets(
    'Email pagination failure keeps loaded rows and retries the page',
    (tester) async {
      await setScreenSize(tester, const Size(390, 844));
      var pageTwoAttempts = 0;
      Map<String, Object?> message(String id, String subject) => {
        'id': id,
        'senderId': 'sender-$id',
        'sender': 'Sender $id',
        'email': '$id@example.test',
        'subject': subject,
        'date': '2026-07-20T08:00:00.000Z',
        'category': 'FINANCE',
        'isRead': true,
        'accountEmail': 'owner@example.test',
      };
      final repository = SenderWhoRepository(
        previewMode: false,
        client: MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page'] ?? '1');
          if (page == 2) {
            pageTwoAttempts += 1;
            if (pageTwoAttempts == 1) {
              return http.Response(
                jsonEncode({
                  'message': 'The next page is temporarily unavailable.',
                }),
                503,
              );
            }
          }
          return http.Response(
            jsonEncode({
              'items': [
                page == 1
                    ? message('message-1', 'Already loaded message')
                    : message('message-2', 'Retried message'),
              ],
              'total': 2,
              'page': page,
              'limit': 1,
              'hasMore': page == 1,
            }),
            200,
          );
        }),
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: EmailsScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Load more'));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(find.text('Already loaded message'), findsOneWidget);
      expect(
        find.text(
          'SenderWho is temporarily unavailable. Please try again shortly.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(pageTwoAttempts, 2);
      expect(find.text('Already loaded message'), findsOneWidget);
      expect(find.text('Retried message'), findsOneWidget);
    },
  );

  testWidgets(
    'Sender pagination failure keeps loaded rows and retries the page',
    (tester) async {
      await setScreenSize(tester, const Size(390, 844));
      var pageTwoAttempts = 0;
      Map<String, Object?> sender(String id, String name) => {
        'id': id,
        'name': name,
        'email': '$id@example.test',
        'category': 'People',
        'score': 80,
        'initial': name.substring(0, 1),
        'totalMessages': 1,
      };
      final repository = SenderWhoRepository(
        previewMode: false,
        client: MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page'] ?? '1');
          if (page == 2) {
            pageTwoAttempts += 1;
            if (pageTwoAttempts == 1) {
              return http.Response(
                jsonEncode({'message': 'Could not load senders.'}),
                503,
              );
            }
          }
          return http.Response(
            jsonEncode({
              'items': [
                page == 1
                    ? sender('sender-1', 'First Sender')
                    : sender('sender-2', 'Second Sender'),
              ],
              'total': 2,
              'page': page,
              'limit': 1,
            }),
            200,
          );
        }),
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AllSendersScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Load more'));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(find.text('First Sender'), findsOneWidget);
      expect(find.text('Could not load senders.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(pageTwoAttempts, 2);
      expect(find.text('First Sender'), findsOneWidget);
      expect(find.text('Second Sender'), findsOneWidget);
    },
  );

  testWidgets('Promotion review uses the canonical paginated Gmail flow', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    Map<String, String>? query;
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        query = request.url.queryParameters;
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'promotion-1',
                'senderId': 'sender-1',
                'sender': 'Promotion Sender',
                'email': 'offers@example.test',
                'subject': 'Promotion to review',
                'date': '2026-07-20T08:00:00.000Z',
                'category': 'PROMOTIONS',
                'isRead': false,
              },
            ],
            'total': 1,
            'page': 1,
            'limit': 25,
            'hasMore': false,
          }),
          200,
        );
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ReviewPromotionsScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(query?['mailbox'], 'ALL');
    expect(query?['category'], 'PROMOTIONS');
    expect(find.text('Review Promotions'), findsOneWidget);
    expect(find.text('Promotion to review'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
  });

  testWidgets('Partial bulk failure keeps only failed messages selected', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    var actionCalls = 0;
    final submittedIds = <List<String>>[];
    Map<String, Object?> message(String id) => {
      'id': id,
      'senderId': 'sender-$id',
      'sender': 'Sender $id',
      'email': '$id@example.test',
      'subject': 'Subject $id',
      'date': '2026-07-20T08:00:00.000Z',
      'category': 'FINANCE',
      'isRead': true,
      'accountEmail': 'owner@example.test',
    };

    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/emails')) {
          final items = switch (actionCalls) {
            0 => [message('message-1'), message('message-2')],
            1 => [message('message-2')],
            _ => <Object>[],
          };
          return http.Response(
            jsonEncode({
              'items': items,
              'total': items.length,
              'page': 1,
              'limit': 25,
              'hasMore': false,
            }),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/emails/actions/archive')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          submittedIds.add((body['messageIds'] as List).cast<String>());
          actionCalls += 1;
          return http.Response(
            jsonEncode(
              actionCalls == 1
                  ? {
                      'action': 'archive',
                      'requested': 2,
                      'processed': 1,
                      'failed': 1,
                      'processedIds': ['message-1'],
                      'failures': [
                        {
                          'messageId': 'message-2',
                          'reason': 'Gmail rejected this message.',
                        },
                      ],
                    }
                  : {
                      'action': 'archive',
                      'requested': 1,
                      'processed': 1,
                      'failed': 0,
                      'processedIds': ['message-2'],
                      'failures': <Object>[],
                    },
            ),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: EmailsScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('email-row-message-1')));
    await tester.tap(find.byKey(const ValueKey('email-row-message-2')));
    await tester.pump();

    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.byTooltip('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byKey(const ValueKey('email-row-message-1')), findsNothing);
    expect(find.byKey(const ValueKey('email-row-message-2')), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(
      find.text(
        '1 updated, 1 failed and remain selected. Gmail rejected this message.',
      ),
      findsOneWidget,
    );
    expect(submittedIds.single, unorderedEquals(['message-1', 'message-2']));

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Archive'));
    await tester.pumpAndSettle();

    expect(submittedIds, hasLength(2));
    expect(submittedIds.last, ['message-2']);
    expect(find.text('Nothing to review'), findsOneWidget);
  });

  testWidgets('Email detail actions return a changed result when going back', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    var archived = false;
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        final message = {
          'id': 'message-1',
          'senderId': 'sender-1',
          'threadId': 'thread-1',
          'sender': 'Billing',
          'email': 'billing@example.test',
          'subject': 'Invoice',
          'date': '2026-07-20T08:00:00.000Z',
          'category': 'FINANCE',
          'isRead': true,
          'isArchived': archived,
          'accountEmail': 'owner@example.test',
        };
        if (request.url.path.endsWith('/emails/message-1/thread')) {
          return http.Response(
            jsonEncode({
              'threadId': 'thread-1',
              'total': 1,
              'items': [message],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/emails/message-1/content')) {
          return http.Response(
            jsonEncode({
              'id': 'message-1',
              'subject': 'Invoice',
              'bodyText': 'Invoice body',
              'attachments': <Object>[],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/emails/actions/archive')) {
          archived = true;
          return http.Response(
            jsonEncode({
              'action': 'archive',
              'requested': 1,
              'processed': 1,
              'failed': 0,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );
    bool? changed;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Text('Inbox host')),
        routes: {
          EmailDetailsScreen.routeName: (_) =>
              EmailDetailsScreen(repository: repository),
        },
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator
        .pushNamed<dynamic>(
          EmailDetailsScreen.routeName,
          arguments: const EmailItem(
            id: 'message-1',
            senderId: 'sender-1',
            sender: 'Billing',
            email: 'billing@example.test',
            subject: 'Invoice',
            date: 'Today',
            accountEmail: 'owner@example.test',
          ),
        )
        .then((value) => changed = value as bool?);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Archive'));
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(archived, isTrue);
    expect(changed, isTrue);
    expect(find.text('Inbox host'), findsOneWidget);
  });

  testWidgets('Alert details exposes the complete review actions', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const SenderWhoApp());

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(
      AlertDetailsScreen.routeName,
      arguments: const AlertItem(
        id: '',
        senderId: 'sender-1',
        title: 'Suspicious sender',
        email: 'alerts@example.test',
        reason: 'Sender identity changed',
        time: 'Today',
        risk: 'High Risk',
        color: AppColors.danger,
        identityRiskScore: 85,
        identityRiskLevel: 'HIGH',
        identityStatus: 'SUSPICIOUS',
        claimedBrand: 'Google',
        authenticatedDomain: 'attacker.example',
        replyToEmail: 'collect@attacker.example',
        identityEvidence: [
          IdentityEvidence(
            code: 'BRAND_DOMAIN_MISMATCH',
            detail:
                'Google is claimed, but the From domain is attacker.example.',
            weight: 35,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
    expect(find.text('Resolve'), findsOneWidget);
    expect(find.text('Dismiss alert'), findsOneWidget);
    expect(find.text('Claimed identity'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('85/100'), findsOneWidget);
    expect(
      find.text('Google is claimed, but the From domain is attacker.example.'),
      findsOneWidget,
    );
  });

  testWidgets('sender rows distinguish verified and impersonated identities', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(
            children: [
              SenderRow(
                sender: const SenderInfo(
                  name: 'Official Google',
                  email: 'no-reply@google.com',
                  category: 'Company',
                  score: 100,
                  initial: 'G',
                  color: AppColors.primary,
                  identityStatus: 'VERIFIED',
                ),
                onChanged: () {},
              ),
              SenderRow(
                sender: const SenderInfo(
                  name: 'Manually trusted sender',
                  email: 'unknown@example.test',
                  category: 'Unknown',
                  score: 70,
                  initial: 'M',
                  color: AppColors.primary,
                  isTrusted: true,
                  identityStatus: 'UNVERIFIED',
                ),
                onChanged: () {},
              ),
              SenderRow(
                sender: const SenderInfo(
                  name: 'Possible Google impostor',
                  email: 'security@goog1e.example',
                  category: 'Unknown',
                  score: 20,
                  initial: 'G',
                  color: AppColors.warning,
                  identityStatus: 'SUSPICIOUS',
                  identityRiskLevel: 'POSSIBLE_IMPERSONATION',
                  identityRiskScore: 60,
                ),
                onChanged: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.gpp_good_rounded), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byIcon(Icons.question_mark_rounded), findsOneWidget);
    expect(find.text('Trusted by you'), findsOneWidget);
    expect(find.text('Possible impersonation'), findsOneWidget);
  });

  testWidgets('Security alerts paginate without losing reviewed rows', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    final requestedPages = <int>[];
    Map<String, Object?> alert(String id, String title) => {
      'id': id,
      'senderId': 'sender-$id',
      'messageId': 'message-$id',
      'title': title,
      'email': '$id@example.test',
      'reason': 'Suspicious sender behavior',
      'time': '2026-07-20T08:00:00.000Z',
      'risk': 'High Risk',
      'colorKey': 'danger',
      'status': 'OPEN',
    };
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page'] ?? '1');
        requestedPages.add(page);
        return http.Response(
          jsonEncode({
            'items': [
              page == 1
                  ? alert('alert-1', 'First security alert')
                  : alert('alert-2', 'Second security alert'),
            ],
            'total': 2,
            'page': page,
            'limit': 1,
            'hasMore': page == 1,
          }),
          200,
        );
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SecurityAlertsScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 alerts need review'), findsOneWidget);
    await tester.ensureVisible(find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(requestedPages, [1, 2]);
    expect(find.text('First security alert'), findsOneWidget);
    expect(find.text('Second security alert'), findsOneWidget);
  });

  testWidgets('Alert review opens the exact flagged Gmail message', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/security-alerts/alert-1')) {
          return http.Response(
            jsonEncode({
              'id': 'alert-1',
              'senderId': 'sender-1',
              'messageId': 'message-1',
              'title': 'Flagged Gmail message',
              'email': 'sender@example.test',
              'reason': 'Sender identity changed',
              'time': '2026-07-20T08:00:00.000Z',
              'risk': 'High Risk',
              'colorKey': 'danger',
              'status': 'OPEN',
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/emails/message-1/thread')) {
          return http.Response(
            jsonEncode({
              'threadId': 'thread-1',
              'total': 1,
              'items': [
                {
                  'id': 'message-1',
                  'senderId': 'sender-1',
                  'sender': 'Flagged Sender',
                  'email': 'sender@example.test',
                  'subject': 'Exact flagged subject',
                  'date': '2026-07-20T08:00:00.000Z',
                  'category': 'SPAM',
                  'isRead': false,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/emails/message-1/content')) {
          return http.Response(
            jsonEncode({
              'id': 'message-1',
              'from': 'Flagged Sender <sender@example.test>',
              'to': 'owner@example.test',
              'cc': '',
              'subject': 'Exact flagged subject',
              'date': '20 July 2026',
              'bodyText': 'Exact flagged Gmail body.',
              'truncated': false,
              'attachments': <Object>[],
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SizedBox.shrink()),
        routes: {
          EmailDetailsScreen.routeName: (_) =>
              EmailDetailsScreen(repository: repository),
        },
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(
          arguments: AlertItem(
            id: 'alert-1',
            senderId: 'sender-1',
            title: 'Flagged Gmail message',
            email: 'sender@example.test',
            reason: 'Sender identity changed',
            time: 'Today',
            risk: 'High Risk',
            color: AppColors.danger,
          ),
        ),
        builder: (_) => AlertDetailsScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('Exact flagged subject'), findsWidgets);
    expect(find.text('Exact flagged Gmail body.'), findsOneWidget);
  });

  testWidgets('Settings exposes security notification controls', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/settings');
        return http.Response(
          jsonEncode({
            'account': {'connectedAccountsCount': 1},
            'preferences': {
              'notificationsEnabled': true,
              'inboxScanFrequency': 'Auto',
              'theme': 'System',
            },
            'emailManagement': {
              'archivedEmails': 2,
              'trashEmails': 1,
              'blockedSenders': 3,
            },
          }),
          200,
        );
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SettingsScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Security notifications'), findsOneWidget);
    expect(find.byType(Switch), findsWidgets);
  });

  testWidgets('Privacy export collects every section and opens file delivery', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    Map<String, dynamic>? delivered;
    final requestedSections = <String>[];
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/privacy-security')) {
          return http.Response(
            jsonEncode({
              'twoFactorEnabled': false,
              'blockedSenders': 2,
              'trustedSenders': 4,
              'dataRetention': 'Metadata only',
              'privacyMode': 'Standard',
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/auth/sessions')) {
          return http.Response(jsonEncode({'items': <Object>[]}), 200);
        }
        if (request.url.path.endsWith('/users/me/export')) {
          final section = request.url.queryParameters['section']!;
          requestedSections.add(section);
          return http.Response(
            jsonEncode({
              'section': section,
              'items': [
                {'id': '$section-1'},
              ],
              'hasMore': false,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PrivacySecurityScreen(
          repository: repository,
          exportDelivery: (export, {sharePositionOrigin}) async {
            delivered = export;
            return const ShareResult('saved', ShareResultStatus.success);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Download or share data export'));
    await tester.tap(find.text('Download or share data export'));
    await tester.pumpAndSettle();

    expect(delivered?['format'], 'senderwho-data-export');
    expect(requestedSections, [
      'profile',
      'accounts',
      'senders',
      'messages',
      'alerts',
      'audit',
    ]);
    expect(find.text('Your complete data export is ready.'), findsOneWidget);
  });

  testWidgets('Search loads later result pages without losing earlier items', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    final requestedPages = <int>[];
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/search/filters')) {
          return http.Response(
            jsonEncode({
              'categories': ['Finance'],
              'trustScores': ['All', 'High (75+)'],
              'dateRanges': ['Any time', 'Today'],
            }),
            200,
          );
        }
        if (request.method == 'POST' && request.url.path.endsWith('/search')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final page = body['page'] as int;
          requestedPages.add(page);
          return http.Response(
            jsonEncode({
              'total': 2,
              'page': page,
              'limit': 25,
              'hasMore': page == 1,
              'senders': <Object>[],
              'emails': [
                {
                  'id': 'message-$page',
                  'sender': 'Billing',
                  'email': 'billing@example.test',
                  'subject': page == 1 ? 'First invoice' : 'Second invoice',
                  'date': '2026-07-20T08:00:00.000Z',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SearchFilterScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Search Gmail metadata'));
    await tester.tap(find.text('Search Gmail metadata'));
    await tester.pumpAndSettle();
    expect(find.text('First invoice'), findsOneWidget);

    await tester.ensureVisible(find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(requestedPages, [1, 2]);
    expect(find.text('First invoice'), findsOneWidget);
    expect(find.text('Second invoice'), findsOneWidget);
  });

  testWidgets('Blocked Senders setting opens the filtered sender list', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/settings') {
          return http.Response(
            jsonEncode({
              'account': {'connectedAccountsCount': 1},
              'preferences': {
                'notificationsEnabled': true,
                'inboxScanFrequency': 'Auto',
                'theme': 'System',
              },
              'emailManagement': {
                'archivedEmails': 2,
                'trashEmails': 1,
                'blockedSenders': 1,
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/senders') {
          expect(request.url.queryParameters['control'], 'BLOCKED');
          return http.Response(
            jsonEncode({
              'items': <Object>[],
              'total': 0,
              'page': 1,
              'limit': 25,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SettingsScreen(repository: repository),
        routes: {
          AllSendersScreen.routeName: (_) =>
              AllSendersScreen(repository: repository),
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Blocked Senders'));
    await tester.tap(find.text('Blocked Senders'));
    await tester.pumpAndSettle();

    expect(find.text('Blocked Senders'), findsWidgets);
    expect(find.textContaining('senders found in Gmail'), findsOneWidget);
  });

  testWidgets('Drawer dark mode switch changes the whole app theme', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const SenderWhoApp());

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(DashboardScreen.routeName);
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.text('Dashboard').first)).brightness,
      Brightness.light,
    );

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('drawer-profile-button')), findsOneWidget);
    expect(find.byTooltip('Use dark mode'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('drawer-dark-mode-switch')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Use light mode'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('Dashboard').first)).brightness,
      Brightness.dark,
    );
  });

  testWidgets('drawer profile opens account details without showing email', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const SenderWhoApp(initiallyAuthenticated: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.byIcon(Icons.alternate_email_rounded), findsNothing);
    await tester.tap(find.byKey(const ValueKey('drawer-profile-button')));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Account details'), findsOneWidget);
    expect(find.byTooltip('Open menu'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('drawer destinations replace history and remain menu roots', (
    tester,
  ) async {
    await setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const SenderWhoApp(initiallyAuthenticated: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Senders'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Email Inbox'));
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('app-header-title'))).data,
      'Inbox',
    );
    expect(find.byTooltip('Open menu'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('Sign out explains that Gmail remains connected', (tester) async {
    await setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const SenderWhoApp(initiallyAuthenticated: true));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out of SenderWho?'), findsOneWidget);
    expect(
      find.textContaining('Your email connection stays linked'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of SenderWho?'), findsNothing);
  });
}

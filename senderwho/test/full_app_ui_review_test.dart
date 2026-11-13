import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/models/app_models.dart';
import 'package:sender_who/screens/connected_accounts_screen.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'support/ui_review_repository.dart';

const reviewRoutes = [
  '/connect-email',
  '/all-senders',
  '/emails',
  '/unsubscribe',
  '/sender-details',
  '/email-details',
  '/categories',
  '/top-senders',
  '/dashboard',
  '/inbox-health',
  '/activity',
  '/security-alerts',
  '/alert-details',
  '/bulk-clean',
  '/review-promotions',
  '/delete-emails',
  '/block-senders',
  '/search-filter',
  '/settings',
  '/connected-accounts',
  '/privacy-security',
  '/profile',
];
Object? reviewArguments(String route, UiReviewData data) => switch (route) {
  '/sender-details' => 'sender-0',
  '/email-details' => EmailItem.fromJson(data.message(0)),
  '/alert-details' => AlertItem.fromJson(data.alert(0)),
  '/block-senders' => {
    'senderId': 'sender-0',
    'email': 'updates-1@example.com',
  },
  _ => null,
};

void main() {
  for (final config in [
    (width: 390.0, height: 844.0, dark: false, textScale: 1.0),
    (width: 390.0, height: 844.0, dark: true, textScale: 1.0),
    (width: 320.0, height: 640.0, dark: false, textScale: 1.3),
    (width: 280.0, height: 568.0, dark: false, textScale: 1.0),
  ]) {
    testWidgets(
      'populated screens: $config',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(config.width, config.height);
        tester.platformDispatcher.textScaleFactorTestValue = config.textScale;
        addTearDown(() {
          tester.view.resetDevicePixelRatio();
          tester.view.resetPhysicalSize();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        for (final route in reviewRoutes) {
          final data = UiReviewData();
          await tester.pumpWidget(
            SenderWhoApp(
              key: UniqueKey(),
              repository: data.repository(),
              initiallyAuthenticated: true,
              initialThemeMode: config.dark ? ThemeMode.dark : ThemeMode.light,
              themePreferenceStore: MemoryThemePreferenceStore(),
            ),
          );
          await tester.pumpAndSettle();
          final navigator = tester.state<NavigatorState>(
            find.byType(Navigator).first,
          );
          if (route != '/all-senders') {
            navigator.pushNamed(route, arguments: reviewArguments(route, data));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull, reason: '$route at $config');
          // Render the lower parts of forms/settings as well as their first screen.
          final scrolls = find.byType(SingleChildScrollView);
          if (scrolls.evaluate().isNotEmpty) {
            await tester.drag(scrolls.first, const Offset(0, -1500));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$route after scrolling at $config',
            );
          }
          expect(data.unhandled, isEmpty, reason: 'Missing fixture for $route');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  }
  testWidgets(
    'Add another mailbox opens providers and Back returns to Senders',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });
      await tester.pumpWidget(
        SenderWhoApp(
          repository: UiReviewData().repository(),
          initiallyAuthenticated: true,
          themePreferenceStore: MemoryThemePreferenceStore(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add another mailbox'));
      await tester.tap(find.text('Add another mailbox'));
      await tester.pumpAndSettle();
      expect(find.byType(ConnectedAccountsScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('add-gmail-account')), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('All Senders'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Search starts simply and advanced filters remain available', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    await tester.pumpWidget(
      SenderWhoApp(
        repository: UiReviewData().repository(),
        initiallyAuthenticated: true,
        themePreferenceStore: MemoryThemePreferenceStore(),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed('/search-filter');
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Search')).bottom, lessThan(760));
    expect(find.text('Unread only'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('search-filter-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Unread only'), findsOneWidget);
    expect(find.text('Has attachments'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

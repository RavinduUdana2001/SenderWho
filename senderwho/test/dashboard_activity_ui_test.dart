import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'package:sender_who/theme/theme_mode_controller.dart';
import 'package:sender_who/widgets/app_header.dart';
import 'support/ui_review_repository.dart';

void main() {
  for (final dark in [false, true]) {
    for (final layout in [(390.0, 1.0), (320.0, 2.0)]) {
      testWidgets(
        'compact overview and interactive activity $layout dark=$dark',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(layout.$1, 844);
          tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final data = UiReviewData();
          final repository = SenderWhoRepository(
            previewMode: false,
            sessionStore: MemorySessionStore(),
            baseUrl: 'https://api.example.test/api/v1',
            client: MockClient((request) async {
              if (request.url.path.endsWith('/activity')) {
                return data.json({
                  'period': 'Last 7 days',
                  'stats': [
                    {
                      'key': 'emailsReceived',
                      'label': 'Emails received',
                      'value': '1,248',
                    },
                    {
                      'key': 'emailsCleaned',
                      'label': 'Emails cleaned',
                      'value': '42',
                    },
                    {
                      'key': 'spaceSaved',
                      'label': 'Cleanup volume',
                      'value': '25 MB',
                    },
                  ],
                  'weeklyActivity': [
                    for (final point in [
                      ('Mon', 1.0),
                      ('Tue', 0.0),
                      ('Wed', .4),
                      ('Thu', .8),
                      ('Fri', .2),
                      ('Sat', .6),
                      ('Sun', .5),
                    ])
                      {'day': point.$1, 'value': point.$2},
                  ],
                });
              }
              return data.handle(request);
            }),
          );
          await tester.pumpWidget(
            SenderWhoApp(
              repository: repository,
              initiallyAuthenticated: true,
              initialThemeMode: dark ? ThemeMode.dark : ThemeMode.light,
              themePreferenceStore: MemoryThemePreferenceStore(),
            ),
          );
          await tester.pumpAndSettle();
          ThemeModeController.of(
            tester.element(find.byType(AppHeader)),
          ).setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
          await tester.pumpAndSettle();
          final navigator = tester.state<NavigatorState>(
            find.byType(Navigator),
          );
          navigator.pushNamed('/dashboard');
          await tester.pumpAndSettle();
          final tile = find.byKey(const ValueKey('dashboard-metric-Senders'));
          final count = find.descendant(of: tile, matching: find.text('285'));
          expect(
            tester.getCenter(count).dx,
            closeTo(tester.getCenter(tile).dx, .5),
          );
          if (layout.$2 == 1) expect(tester.getSize(tile).height, lessThan(95));
          expect(tester.takeException(), isNull);
          navigator.pushNamed('/activity');
          await tester.pumpAndSettle();
          expect(find.text('1,248'), findsOneWidget);
          expect(find.text('25 MB'), findsOneWidget);
          final tuesday = find.byKey(const ValueKey('activity-day-1'));
          await tester.ensureVisible(tuesday);
          await tester.pumpAndSettle();
          expect(
            tester.getSize(find.byKey(const ValueKey('activity-bar-1'))).height,
            0,
          );
          await tester.tap(tuesday);
          await tester.pumpAndSettle();
          expect(find.text('Tue · No emails received'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('activity-day-0')));
          await tester.pumpAndSettle();
          expect(find.text('Mon · Busiest day'), findsOneWidget);
          expect(find.textContaining('1,248 emails on Mon'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Open menu'));
          await tester.pumpAndSettle();
          final tools = find.byKey(const ValueKey('drawer-more-tools'));
          await tester.scrollUntilVisible(
            tools,
            100,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.ensureVisible(tools);
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(of: tools, matching: find.text('More tools')),
          );
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: tools, matching: find.text('Top Senders')),
            findsNothing,
          );
          expect(
            find.descendant(of: tools, matching: find.text('Activity')),
            findsOneWidget,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

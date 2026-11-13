import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sender_who/screens/unsubscribe_screen.dart';
import 'package:sender_who/theme/app_theme.dart';
import 'package:sender_who/widgets/search_box.dart';
import 'support/ui_review_repository.dart';

Future<void> open(
  WidgetTester tester,
  UiReviewData data, {
  double width = 390,
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: UnsubscribeScreen(repository: data.repository()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [280.0, 320.0, 390.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'subscriptions fit $width in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
          await open(tester, UiReviewData(), width: width, dark: dark);
          expect(find.text('Canva'), findsOneWidget);
          expect(
            tester
                .getSize(
                  find.byKey(const ValueKey('subscription-row-sender-0')),
                )
                .height,
            lessThan(width < 340 ? 130 : 95),
          );
          expect(
            find.byKey(const ValueKey('unsubscribe-start-sender-0')),
            findsOneWidget,
          );
          expect(find.text('Trust'), findsNothing);
          if (width < 340) {
            final action = tester.getRect(
              find.byKey(const ValueKey('unsubscribe-start-sender-0')),
            );
            expect(
              action.top,
              greaterThanOrEqualTo(tester.getRect(find.text('Canva')).bottom),
            );
            expect(action.right, lessThanOrEqualTo(width));
          }
          expect(tester.takeException(), isNull);
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpAndSettle();
          await tester.longPress(find.text('Canva'));
          await tester.pumpAndSettle();
          expect(find.text('1 selected'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'search and retry filter clearly distinguish matching and empty views',
    (tester) async {
      await open(tester, UiReviewData(failedRequest: true));
      await tester.ensureVisible(find.text('Needs retry').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Needs retry').first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('subscription-row-sender-2')),
        findsOneWidget,
      );
      expect(find.text('Canva'), findsNothing);
      await tester.tap(find.byTooltip('Search subscriptions'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(SearchBox),
          matching: find.byType(TextField),
        ),
        'no-such-sender',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching subscriptions'), findsOneWidget);
      expect(find.text('No subscriptions to review'), findsNothing);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Canva'), findsOneWidget);
    },
  );
  testWidgets(
    'selection sends only the chosen subscriptions and keeps batch confirmation',
    (tester) async {
      final data = UiReviewData();
      await open(tester, data);
      await tester.longPress(find.text('Canva'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('subscription-row-sender-1')));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      await tester.tap(find.text('Unsubscribe (2)'));
      await tester.pumpAndSettle();
      expect(data.batchRequests, isEmpty);
      expect(find.text('Unsubscribe from 2 senders?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Unsubscribe'));
      await tester.pumpAndSettle();
      expect(data.batchRequests.single, ['sender-0', 'sender-1']);
      expect(find.text('Canva'), findsNothing);
      expect(find.text('LinkedIn'), findsNothing);
      expect(find.text('Weekly product and design newsletter'), findsOneWidget);
    },
  );
  testWidgets(
    'a failed refresh preserves loaded subscriptions and offers recovery',
    (tester) async {
      final data = UiReviewData();
      await open(tester, data);
      data.failRefresh = true;
      await tester.tap(find.byKey(const ValueKey('unsubscribe-page-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh subscriptions'));
      await tester.pumpAndSettle();
      expect(find.text('Could not refresh subscriptions'), findsOneWidget);
      expect(find.text('Canva'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

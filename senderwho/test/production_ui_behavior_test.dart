import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'package:sender_who/widgets/search_box.dart';
import 'package:sender_who/theme/app_theme.dart';
import 'full_app_ui_review_test.dart' show reviewRoutes, reviewArguments;
import 'support/ui_review_repository.dart';

void viewport(WidgetTester tester, Size size, double scale) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

Future<void> open(WidgetTester tester, String route, bool dark) async {
  final data = UiReviewData();
  await tester.pumpWidget(
    SenderWhoApp(
      key: UniqueKey(),
      repository: data.repository(),
      initiallyAuthenticated: true,
      initialThemeMode: dark ? ThemeMode.dark : ThemeMode.light,
      themePreferenceStore: MemoryThemePreferenceStore(),
    ),
  );
  await tester.pumpAndSettle();
  if (route != '/all-senders') {
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed(route, arguments: reviewArguments(route, data));
    await tester.pumpAndSettle();
  }
}

Finder verticalScroll() => find
    .byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.vertical,
    )
    .first;

void main() {
  for (final dark in [false, true]) {
    for (final layout in [
      (size: const Size(320, 568), scale: 2.0),
      (size: const Size(740, 360), scale: 1.3),
    ]) {
      testWidgets('all populated screens fit $layout dark=$dark', (
        tester,
      ) async {
        viewport(tester, layout.size, layout.scale);
        final layoutErrors = <String>[];
        for (final route in reviewRoutes) {
          await open(tester, route, dark);
          final initialError = tester.takeException();
          if (initialError != null) {
            layoutErrors.add('$route initial: $initialError');
          }
          if (verticalScroll().evaluate().isNotEmpty) {
            await tester.drag(verticalScroll(), const Offset(0, -1800));
            await tester.pumpAndSettle();
            final lowerError = tester.takeException();
            if (lowerError != null) {
              layoutErrors.add('$route lower: $lowerError');
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
        expect(layoutErrors, isEmpty);
      });
    }
    for (final route in [
      '/all-senders',
      '/emails',
      '/unsubscribe',
      '/search-filter',
    ]) {
      testWidgets(
        'search handles keyboard, dismissal, and large text on $route dark=$dark',
        (tester) async {
          viewport(tester, const Size(320, 568), 1.5);
          await open(tester, route, dark);
          if (route != '/search-filter') {
            await tester.tap(
              find.byTooltip(switch (route) {
                '/all-senders' => 'Search senders',
                '/emails' => 'Search messages',
                _ => 'Search subscriptions',
              }),
            );
            await tester.pumpAndSettle();
          }
          final input = find.byType(TextField).first;
          await tester.ensureVisible(input);
          await tester.pumpAndSettle();
          await tester.tap(input);
          await tester.enterText(input, 'weekly newsletter');
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$route with keyboard',
          );
          final rect = tester.getRect(input);
          expect(rect.bottom, lessThanOrEqualTo(568 - 260));
          expect(
            tester.widget<TextField>(input).keyboardAppearance,
            dark ? Brightness.dark : Brightness.light,
          );
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText).first)
                .focusNode
                .hasFocus,
            isFalse,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'unsubscribe confirmation remains reachable with large text dark=$dark',
      (tester) async {
        viewport(tester, const Size(320, 568), 2);
        await open(tester, '/unsubscribe', dark);
        final action = find.byKey(const ValueKey('unsubscribe-start-sender-0'));
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('Unsubscribe from Canva?'), findsOneWidget);
        final confirm = find.widgetWithText(FilledButton, 'Unsubscribe');
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(568));
        final scheme = Theme.of(tester.element(confirm)).colorScheme;
        final button = tester.widget<FilledButton>(confirm);
        expect(button.style!.backgroundColor!.resolve({}), scheme.error);
        expect(button.style!.foregroundColor!.resolve({}), scheme.onError);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'sender filter actions stay above the keyboard at large text dark=$dark',
      (tester) async {
        viewport(tester, const Size(320, 568), 2);
        await open(tester, '/all-senders', dark);
        await tester.tap(find.byTooltip('Filter senders'));
        await tester.pumpAndSettle();
        final input = find.byType(TextField).first;
        await tester.ensureVisible(input);
        await tester.pumpAndSettle();
        await tester.tap(input);
        await tester.pump();
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('Apply filters')).bottom,
          lessThanOrEqualTo(328),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Apply filters'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
      },
    );
    testWidgets('search controls grow with 200 percent text in dark=$dark', (
      tester,
    ) async {
      viewport(tester, const Size(320, 568), 2);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                SearchBox(controller: controller),
                const SizedBox(height: 20),
                const Text('Tap outside'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      expect(tester.getSize(field).height, greaterThan(65));
      await tester.tap(field);
      await tester.pump();
      await tester.tap(find.text('Tap outside'));
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/models/app_models.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'package:sender_who/widgets/sender_filters_sheet.dart';
import 'support/ui_review_repository.dart';

void viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class SenderFilterApi {
  final data = UiReviewData();
  final queries = <Map<String, String>>[];
  SenderWhoRepository repository() => SenderWhoRepository(
    previewMode: false,
    sessionStore: MemorySessionStore(),
    baseUrl: 'https://api.example.test/api/v1',
    client: MockClient((request) async {
      if (request.url.path.endsWith('/senders')) {
        final query = request.url.queryParameters;
        queries.add(Map.of(query));
        final finance = query['category'] == 'FINANCE';
        final page = int.parse(query['page'] ?? '1');
        return data.json({
          'items': finance
              ? [
                  for (var i = (page - 1) * 2; i < page * 2; i++)
                    {
                      ...data.sender(i),
                      'id': 'bank-$i',
                      'name': 'Bank ${i + 1}',
                      'email': 'bank$i@example.com',
                      'category': 'Finance',
                    },
                ]
              : [data.sender(0), data.sender(1)],
          'total': finance ? 4 : 2,
          'page': page,
          'limit': 2,
        });
      }
      return data.handle(request);
    }),
  );
}

Future<void> open(WidgetTester tester, SenderWhoRepository repository) async {
  await tester.pumpWidget(
    SenderWhoApp(
      repository: repository,
      initiallyAuthenticated: true,
      themePreferenceStore: MemoryThemePreferenceStore(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> chooseFinance(WidgetTester tester) async {
  final category = find.byKey(const ValueKey('sender-category-FINANCE'));
  await tester.ensureVisible(category);
  await tester.tap(category);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'category and search are requested together and retained on later pages',
    (tester) async {
      viewport(tester, const Size(390, 844));
      final api = SenderFilterApi();
      await open(tester, api.repository());
      expect(find.text('Bank 1'), findsNothing);
      await tester.tap(find.text('People'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter senders'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('sender-filter-search')),
          matching: find.byType(TextField),
        ),
        'bank',
      );
      await chooseFinance(tester);
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(api.queries.last, containsPair('category', 'FINANCE'));
      expect(api.queries.last, containsPair('query', 'bank'));
      expect(api.queries.last, containsPair('kind', 'ALL'));
      expect(api.queries.last, containsPair('page', '1'));
      expect(find.text('Bank 1'), findsOneWidget);
      expect(find.text('Canva'), findsNothing);
      expect(
        find.byKey(const ValueKey('sender-active-category')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Load more'));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(api.queries.last, containsPair('page', '2'));
      expect(api.queries.last, containsPair('category', 'FINANCE'));
      expect(api.queries.last, containsPair('query', 'bank'));
      expect(find.text('Bank 4'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Clear category filter'));
      await tester.tap(find.byTooltip('Clear category filter'));
      await tester.pumpAndSettle();
      expect(api.queries.last.containsKey('category'), isFalse);
      expect(api.queries.last['query'], 'bank');
      expect(api.queries.last['page'], '1');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing a filter draft leaves the current list and search unchanged',
    (tester) async {
      viewport(tester, const Size(390, 844));
      final api = SenderFilterApi();
      await open(tester, api.repository());
      final requests = api.queries.length;
      final titlePosition = tester.getTopLeft(
        find.byKey(const ValueKey('app-header-title')),
      );
      await tester.tap(find.byTooltip('Filter senders'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('app-header-title'))),
        titlePosition,
      );
      expect(find.byTooltip('Back'), findsNothing);
      await chooseFinance(tester);
      await tester.tap(find.byTooltip('Close sender filters'));
      await tester.pumpAndSettle();
      expect(api.queries.length, requests);
      expect(find.text('Canva'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('sender-active-category')),
        findsNothing,
      );
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1024, 900),
  ]) {
    testWidgets(
      'profile stays in the same position through navigation and scrolling at $size',
      (tester) async {
        viewport(tester, size);
        if (size.width == 320) {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        final data = UiReviewData();
        await open(tester, data.repository());
        final button = find.byKey(const ValueKey('profile-account-button'));
        final original = tester.getTopLeft(button);
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        for (final route in [
          '/sender-details',
          '/emails',
          '/email-details',
          '/settings',
          '/profile',
          '/unsubscribe',
        ]) {
          navigator.pushNamed(
            route,
            arguments: switch (route) {
              '/sender-details' => 'sender-0',
              '/email-details' => EmailItem.fromJson(data.message(0)),
              _ => null,
            },
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            tester.getTopLeft(button),
            original,
            reason: '$route during transition',
          );
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(button), original, reason: route);
          expect(
            find.byTooltip('Back'),
            ['/sender-details', '/email-details'].contains(route)
                ? findsOneWidget
                : findsNothing,
          );
          final scroll = find.byType(SingleChildScrollView);
          final vertical = scroll
              .evaluate()
              .where(
                (element) =>
                    (element.widget as SingleChildScrollView).scrollDirection ==
                    Axis.vertical,
              )
              .first;
          await tester.drag(
            find.byWidget(vertical.widget),
            const Offset(0, -550),
          );
          await tester.pumpAndSettle();
          expect(
            tester.getTopLeft(button),
            original,
            reason: '$route after scroll',
          );
          await tester.tap(find.byTooltip('Open menu'));
          await tester.pumpAndSettle();
          expect(find.text('Accounts'), findsOneWidget);
          await tester.tap(find.byTooltip('Close menu'));
          await tester.pumpAndSettle();
          if (!['/sender-details', '/email-details'].contains(route)) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.byTooltip('Back'));
          }
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(button), original);
          expect(tester.takeException(), isNull, reason: route);
        }
      },
    );
  }
  testWidgets(
    'filter sheet fits large text and keeps Apply visible above the keyboard',
    (tester) async {
      viewport(tester, const Size(320, 640));
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, SenderFilterApi().repository());
      await tester.tap(find.byTooltip('Filter senders'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Apply filters')).bottom, lessThan(400));
      await tester.ensureVisible(
        find.byKey(const ValueKey('sender-category-UNKNOWN')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SenderFiltersSheet), findsOneWidget);
    },
  );
}

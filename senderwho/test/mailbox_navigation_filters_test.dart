import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/screens/all_senders_screen.dart';
import 'package:sender_who/screens/bulk_clean_screen.dart';
import 'package:sender_who/screens/emails_screen.dart';
import 'package:sender_who/screens/unsubscribe_screen.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/app_theme.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'package:sender_who/widgets/mail_list_surface.dart';
import 'package:sender_who/widgets/app_chips.dart';
import 'package:sender_who/widgets/search_box.dart';

import 'support/ui_review_repository.dart';

void phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Finder tab(String label) => find.descendant(
  of: find.byType(NavigationDestination),
  matching: find.text(label),
);

Future<void> app(WidgetTester tester, SenderWhoRepository repository) async {
  await tester.pumpWidget(
    SenderWhoApp(
      repository: repository,
      initiallyAuthenticated: true,
      themePreferenceStore: MemoryThemePreferenceStore(),
    ),
  );
  await tester.pumpAndSettle();
}

class FilterApi {
  final data = UiReviewData();
  final emails = <Map<String, String>>[];
  final senders = <Map<String, String>>[];
  Completer<http.Response>? pending;

  SenderWhoRepository repository() => SenderWhoRepository(
    previewMode: false,
    sessionStore: MemorySessionStore(),
    baseUrl: 'https://api.example.test/api/v1',
    client: MockClient((request) async {
      final q = Map.of(request.url.queryParameters);
      if (request.url.path.endsWith('/emails')) {
        emails.add(q);
        if (pending case final wait?) return wait.future;
        return data.json({
          'items': q['category'] == 'NEWSLETTERS' ? [] : [data.message(0)],
          'total': q['category'] == 'NEWSLETTERS' ? 0 : 1,
          'page': 1,
          'limit': 25,
          'hasMore': false,
        });
      }
      if (request.url.path.endsWith('/senders')) {
        senders.add(q);
        // The quick-tab kind remains explicit alongside category. This also
        // matches older server versions that only understand sender kinds.
        return data.json({
          'items': q['kind'] == 'NEWSLETTERS' ? [] : [data.sender(0)],
          'total': q['kind'] == 'NEWSLETTERS' ? 0 : 1,
          'page': 1,
          'limit': 25,
        });
      }
      return data.handle(request);
    }),
  );
}

Future<void> inbox(WidgetTester tester, FilterApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: EmailsScreen(repository: api.repository()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String key) async {
  final category = find.byKey(ValueKey(key));
  await tester.ensureVisible(category);
  await tester.tap(category);
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'primary tabs stay stationary during push and return on $platform',
      (tester) async {
        phone(tester);
        await app(tester, UiReviewData().repository());
        final profile = find.byKey(const ValueKey('profile-account-button'));
        final profilePosition = tester.getTopLeft(profile);
        final navPosition = tester.getTopLeft(find.byType(NavigationBar));
        for (final destination in <(String, Type)>[
          ('Inbox', EmailsScreen),
          ('Unsubscribe', UnsubscribeScreen),
          ('Clean', BulkCleanScreen),
          ('Senders', AllSendersScreen),
        ]) {
          await tester.tap(tab(destination.$1));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1));
          final title = find.descendant(
            of: find.byType(destination.$2),
            matching: find.byKey(const ValueKey('app-header-title')),
          );
          final position = tester.getTopLeft(title);
          for (var frame = 0; frame < 3; frame++) {
            await tester.pump(const Duration(milliseconds: 40));
            expect(tester.getTopLeft(profile), profilePosition);
            expect(
              tester.getTopLeft(title),
              position,
              reason: '${destination.$1} must not slide',
            );
            final nav = find.descendant(
              of: find.byType(destination.$2),
              matching: find.byType(NavigationBar),
            );
            expect(tester.getTopLeft(nav), navPosition);
          }
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(title), position);
        }
        expect(find.byTooltip('Back'), findsNothing);
        // Named destinations, including drawer navigation, use the same fade.
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed('/emails');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        final inboxTitle = find.descendant(
          of: find.byType(EmailsScreen),
          matching: find.byKey(const ValueKey('app-header-title')),
        );
        final titlePosition = tester.getTopLeft(inboxTitle);
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.getTopLeft(inboxTitle), titlePosition);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Back'), findsNothing);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.getTopLeft(profile), profilePosition);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }

  testWidgets(
    'Inbox sheet applies category and search together, matching quick tabs',
    (tester) async {
      phone(tester);
      final api = FilterApi();
      await inbox(tester, api);
      await tester.tap(find.byTooltip('Filter categories'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('message-filter-search')),
          matching: find.byType(TextField),
        ),
        'design',
      );
      await choose(tester, 'message-category-NEWSLETTERS');
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(api.emails.last, containsPair('category', 'NEWSLETTERS'));
      expect(api.emails.last, containsPair('query', 'design'));
      expect(api.emails.last, containsPair('mailbox', 'INBOX'));
      expect(api.emails.last, containsPair('page', '1'));
      expect(find.text('Nothing to review'), findsOneWidget);
      expect(
        tester
            .widgetList<MailFilterTab>(find.byType(MailFilterTab))
            .singleWhere((t) => t.label == 'Newsletters')
            .selected,
        isTrue,
      );
      final sheetQuery = Map.of(api.emails.last);
      await tester.ensureVisible(find.byTooltip('Clear category filter'));
      await tester.tap(find.byTooltip('Clear category filter'));
      await tester.pumpAndSettle();
      expect(api.emails.last.containsKey('category'), isFalse);
      expect(api.emails.last['query'], 'design');
      expect(find.text('Your project update is ready'), findsOneWidget);
      await tester.ensureVisible(find.text('Newsletters'));
      await tester.tap(find.text('Newsletters'));
      await tester.pumpAndSettle();
      expect(api.emails.last, sheetQuery);
      expect(find.text('Nothing to review'), findsOneWidget);
      // Submitting a new search must retain the selected category.
      await tester.enterText(
        find.descendant(
          of: find.byType(SearchBox),
          matching: find.byType(TextField),
        ),
        'another',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(api.emails.last['query'], 'another');
      expect(api.emails.last['category'], 'NEWSLETTERS');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing Inbox filter draft keeps current results and query', (
    tester,
  ) async {
    phone(tester);
    final api = FilterApi();
    await inbox(tester, api);
    final requests = api.emails.length;
    await tester.tap(find.byTooltip('Filter categories'));
    await tester.pumpAndSettle();
    await choose(tester, 'message-category-NEWSLETTERS');
    await tester.tap(find.byTooltip('Close message filters'));
    await tester.pumpAndSettle();
    expect(api.emails.length, requests);
    expect(find.text('Your project update is ready'), findsOneWidget);
    expect(find.byTooltip('Clear category filter'), findsNothing);
  });

  testWidgets(
    'Senders sheet and quick tabs request the same newsletter scope',
    (tester) async {
      phone(tester);
      final api = FilterApi();
      await app(tester, api.repository());
      await tester.tap(find.byTooltip('Filter senders'));
      await tester.pumpAndSettle();
      await choose(tester, 'sender-category-NEWSLETTERS');
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(api.senders.last['kind'], 'NEWSLETTERS');
      expect(api.senders.last['category'], 'NEWSLETTERS');
      expect(find.text('No matching senders'), findsOneWidget);
      expect(
        tester
            .widgetList<MailFilterTab>(find.byType(MailFilterTab))
            .singleWhere((t) => t.label == 'Newsletters')
            .selected,
        isTrue,
      );
      await tester.tap(find.byTooltip('Filter senders'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelectablePill>(
              find.byKey(const ValueKey('sender-category-NEWSLETTERS')),
            )
            .selected,
        isTrue,
      );
      await tester.tap(find.byTooltip('Close sender filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear category filter'));
      await tester.pumpAndSettle();
      expect(api.senders.last['kind'], 'ALL');
      expect(api.senders.last.containsKey('category'), isFalse);
      await tester.ensureVisible(find.text('Newsletters'));
      await tester.tap(find.text('Newsletters'));
      await tester.pumpAndSettle();
      expect(api.senders.last['kind'], 'NEWSLETTERS');
      expect(find.text('No matching senders'), findsOneWidget);
      await tester.tap(find.byTooltip('Filter senders'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelectablePill>(
              find.byKey(const ValueKey('sender-category-NEWSLETTERS')),
            )
            .selected,
        isTrue,
      );
      await tester.tap(find.text('Reset'));
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(api.senders.last['kind'], 'ALL');
      expect(api.senders.last.containsKey('category'), isFalse);
      expect(find.text('Canva'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('latest Inbox filter replaces an older in-flight result', (
    tester,
  ) async {
    phone(tester);
    final api = FilterApi();
    await inbox(tester, api);
    final oldRequest = Completer<http.Response>();
    api.pending = oldRequest;
    await tester.tap(find.byTooltip('Refresh messages'));
    await tester.pump();
    await tester.tap(find.byTooltip('Filter categories'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.byKey(const ValueKey('message-category-NEWSLETTERS')),
    );
    await tester.pump(const Duration(milliseconds: 240));
    await tester.tap(find.text('Apply filters'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    api.pending = null;
    oldRequest.complete(
      api.data.json({
        'items': [api.data.message(0)],
        'total': 1,
        'page': 1,
        'limit': 25,
        'hasMore': false,
      }),
    );
    await tester.pumpAndSettle();
    expect(api.emails.last['category'], 'NEWSLETTERS');
    expect(find.text('Nothing to review'), findsOneWidget);
    expect(find.text('Your project update is ready'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

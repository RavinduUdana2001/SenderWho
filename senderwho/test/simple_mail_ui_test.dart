import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/screens/categories_screen.dart';
import 'package:sender_who/screens/emails_screen.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/app_theme.dart';
import 'package:sender_who/widgets/search_box.dart';
import 'package:sender_who/widgets/sender_drawer.dart';

void main() {
  testWidgets(
    'simple inbox keeps category, folder, and search controls working',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final queries = <Map<String, String>>[];
      final repository = SenderWhoRepository(
        previewMode: false,
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
        client: MockClient((request) async {
          queries.add(request.url.queryParameters);
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'email-1',
                  'sender': 'Canva',
                  'email': 'design@example.com',
                  'subject': 'A new design',
                  'snippet': 'Your latest updates',
                  'date': 'Today',
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
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: EmailsScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SearchBox), findsNothing);
      await tester.tap(find.text('Offers'));
      await tester.pumpAndSettle();
      expect(queries.last['category'], 'PROMOTIONS');
      await tester.tap(find.byKey(const ValueKey('app-header-title')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Archived'));
      await tester.pumpAndSettle();
      expect(queries.last['mailbox'], 'ARCHIVED');
      await tester.tap(find.byTooltip('Search messages'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'invoice');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(queries.last['query'], 'invoice');
      await tester.tap(find.byTooltip('Close message search'));
      await tester.pumpAndSettle();
      expect(queries.last.containsKey('query'), isFalse);
      expect(queries.last['category'], 'PROMOTIONS');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('short account menu keeps secondary tools behind More tools', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        routes: {
          CategoriesScreen.routeName: (_) =>
              const Scaffold(body: Text('Categories destination')),
        },
        home: Scaffold(
          drawer: const SenderDrawer(),
          appBar: AppBar(),
          body: const Text('Inbox host'),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Manage accounts'), findsOneWidget);
    expect(find.text('Categories'), findsNothing);
    expect(find.text('WORKSPACE'), findsNothing);
    await tester.ensureVisible(find.text('More tools'));
    await tester.tap(find.text('More tools'));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('Categories')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.text('Categories destination'), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}

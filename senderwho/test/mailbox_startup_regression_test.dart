import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'package:sender_who/models/app_models.dart';
import 'package:sender_who/widgets/mailbox_sync_notice.dart';
import 'package:sender_who/widgets/search_box.dart';
import 'package:sender_who/screens/all_senders_screen.dart';
import 'package:sender_who/screens/emails_screen.dart';

import 'support/ui_review_repository.dart';

class StartupMailboxApi {
  final data = UiReviewData();
  final store = MemorySessionStore()..refreshToken = 'saved';
  final requests = <http.Request>[];
  Completer<http.Response>? accountResponse;
  int accountLoads = 0;
  bool failAccounts = false;
  int total = 1;
  String mailbox = 'personal';

  http.Response accounts() => data.json({
    'items': [
      {
        'id': mailbox,
        'emailAddress': '$mailbox@example.com',
        'provider': 'GOOGLE',
        'isActive': true,
        'syncStatus': 'READY',
      },
    ],
  });

  late final repository = SenderWhoRepository(
    previewMode: false,
    baseUrl: 'https://api.example.test/api/v1',
    sessionStore: store,
    client: MockClient((request) async {
      requests.add(request);
      final path = request.url.path.split('/').last;
      if (path == 'refresh') {
        return data.json({
          'status': 'AUTHENTICATED',
          'accessToken': 'access-$mailbox',
          'refreshToken': 'refresh-$mailbox',
          'user': {'email': '$mailbox@example.com'},
        });
      }
      if (path == 'email-accounts') {
        accountLoads++;
        if (failAccounts) return data.json({'message': 'Unavailable'}, 503);
        return accountResponse?.future ?? accounts();
      }
      if (path == 'senders' || path == 'emails') {
        final q = request.url.queryParameters;
        // A legacy user has no primary mailbox until GET email-accounts repairs
        // it. A request sent before discovery would return an empty success.
        final matches =
            q['emailAccountId'] == mailbox &&
            (q['category'] == null || q['category'] == 'NEWSLETTERS');
        return data.json({
          'items': matches
              ? [
                  if (path == 'senders')
                    {...data.sender(2), 'name': '$mailbox newsletter'}
                  else
                    {...data.message(2), 'subject': '$mailbox news'},
                ]
              : [],
          'total': matches ? total : 0,
          'page': int.parse(q['page'] ?? '1'),
          'limit': 25,
          'hasMore': matches && total > 25 && q['page'] == '1',
        });
      }
      return data.handle(request);
    }),
  );

  Iterable<http.Request> get lists => requests.where(
    (r) => const ['senders', 'emails'].contains(r.url.path.split('/').last),
  );
}

void main() {
  for (final senders in [true, false]) {
    testWidgets(
      '${senders ? 'senders' : 'inbox'} restarts pagination after editing search',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = StartupMailboxApi()..total = 50;
        final repo = api.repository;
        await repo.restoreSession();
        await tester.pumpWidget(
          MaterialApp(
            home: senders
                ? AllSendersScreen(repository: repo)
                : EmailsScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byTooltip(senders ? 'Search senders' : 'Search messages'),
        );
        await tester.pumpAndSettle();
        final field = find.descendant(
          of: find.byType(SearchBox),
          matching: find.byType(TextField),
        );
        await tester.enterText(field, 'alpha');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        await tester.enterText(field, 'beta');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Load more'));
        await tester.tap(find.text('Load more'));
        await tester.pumpAndSettle();
        expect(api.lists.last.url.queryParameters['query'], 'beta');
        expect(api.lists.last.url.queryParameters['page'], '1');
        expect(
          find.text(senders ? 'personal newsletter' : 'personal news'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('first mailbox reads share discovery and preserve filters', () async {
    final api = StartupMailboxApi()..accountResponse = Completer();
    final repo = api.repository;
    expect(await repo.restoreSession(), isTrue);
    final senders = repo.getSenders(category: 'NEWSLETTERS', query: 'news');
    final emails = repo.getEmails(category: 'NEWSLETTERS', query: 'news');
    final dashboard = repo.getDashboard();
    await Future<void>.delayed(Duration.zero);
    expect(api.accountLoads, 1);
    expect(api.lists, isEmpty);
    api.accountResponse!.complete(api.accounts());
    expect((await senders)!.total, 1);
    expect((await emails)!.total, 1);
    await dashboard;
    for (final request in api.lists) {
      expect(
        request.url.queryParameters,
        containsPair('emailAccountId', 'personal'),
      );
      expect(
        request.url.queryParameters,
        containsPair('category', 'NEWSLETTERS'),
      );
      expect(request.url.queryParameters, containsPair('query', 'news'));
    }
  });

  test(
    'failed mailbox discovery is retryable and never becomes an empty success',
    () async {
      final api = StartupMailboxApi()..failAccounts = true;
      final repo = api.repository;
      await repo.restoreSession();
      expect(await repo.getSenders(), isNull);
      expect(api.lists, isEmpty);
      expect(repo.lastError, isNotNull);
      api.failAccounts = false;
      expect((await repo.getSenders())!.total, 1);
      expect(api.accountLoads, 2);
    },
  );

  test(
    'logging in again resolves the new mailbox and discards old discovery',
    () async {
      final api = StartupMailboxApi()..accountResponse = Completer();
      final repo = api.repository;
      await repo.restoreSession();
      final oldAccounts = api.accountResponse!;
      final oldRead = repo.getEmails();
      await Future<void>.delayed(Duration.zero);
      final oldResponse = api.accounts();
      await repo.logout();
      api.mailbox = 'work';
      api.accountResponse = null;
      api.store.refreshToken = 'work-session';
      expect(await repo.restoreSession(), isTrue);
      expect((await repo.getEmails())!.items.single.subject, 'work news');
      oldAccounts.complete(oldResponse);
      expect(await oldRead, isNull);
      expect(repo.activeMailbox.value!.id, 'work');
      expect(repo.connectedAccounts.value.single.id, 'work');
    },
  );

  test(
    'a repaired mailbox selection invalidates previously loaded screens',
    () async {
      final api = StartupMailboxApi();
      final repo = api.repository;
      await repo.restoreSession();
      await repo.getConnectedAccounts();
      final revision = repo.mailboxRevision.value;
      api.mailbox = 'work';
      await repo.getConnectedAccounts();
      expect(repo.mailboxRevision.value, revision + 1);
      expect((await repo.getEmails())!.items.single.subject, 'work news');
      await repo.getConnectedAccounts();
      expect(repo.mailboxRevision.value, revision + 1);
    },
  );

  testWidgets(
    'disconnected mailbox recovery remains visible when dashboard has no selected account',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MailboxSyncNotice(
              summary: DashboardSummary.fromJson({
                'sync': {'syncStatus': 'NOT_CONNECTED'},
              }),
              account: ConnectedEmailAccount.fromJson({
                'id': 'personal',
                'syncStatus': 'DISCONNECTED',
              }),
            ),
          ),
        ),
      );
      expect(find.text('Reconnect your mailbox'), findsOneWidget);
      expect(find.byTooltip('View sync status'), findsOneWidget);
    },
  );

  testWidgets(
    'filter changes during login discovery show the latest matching rows',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = StartupMailboxApi()..accountResponse = Completer();
      final repo = api.repository;
      await repo.restoreSession();
      await tester.pumpWidget(
        SenderWhoApp(
          repository: repo,
          initiallyAuthenticated: true,
          themePreferenceStore: MemoryThemePreferenceStore(),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Newsletters').first);
      await tester.tap(find.text('Newsletters').first);
      await tester.pump();
      expect(api.lists, isEmpty);
      api.accountResponse!.complete(api.accounts());
      await tester.pumpAndSettle();
      expect(find.text('personal newsletter'), findsOneWidget);
      expect(api.lists.last.url.queryParameters['category'], 'NEWSLETTERS');
      // Both the quick tab and sheet use the same category predicate.
      await tester.tap(find.byTooltip('Filter senders'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sender-category-FINANCE')));
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(find.text('personal newsletter'), findsNothing);
      expect(api.lists.last.url.queryParameters['category'], 'FINANCE');
      await tester.ensureVisible(find.text('Newsletters').first);
      await tester.tap(find.text('Newsletters').first);
      await tester.pumpAndSettle();
      expect(find.text('personal newsletter'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/screens/search_filter_screen.dart';
import 'package:sender_who/screens/unsubscribe_screen.dart';
import 'package:sender_who/services/api_transport.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/app_theme.dart';

class StalledClient extends http.BaseClient {
  bool bodyCancelled = false;
  bool abortSignalled = false;
  bool recovered = false;
  late final body = StreamController<List<int>>(
    onCancel: () {
      bodyCancelled = true;
    },
  );
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (recovered) {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode('{"items":[],"total":0,"page":1,"hasMore":false}'),
        ),
        200,
      );
    }
    if (request is http.AbortableRequest) {
      unawaited(
        request.abortTrigger!.then((_) {
          abortSignalled = true;
        }),
      );
    }
    return http.StreamedResponse(body.stream, 200);
  }
}

http.Response json(Object data) => http.Response(jsonEncode(data), 200);
SenderWhoRepository repository(
  http.Client client, {
  Duration timeout = const Duration(seconds: 15),
}) => SenderWhoRepository(
  previewMode: false,
  client: client,
  sessionStore: MemorySessionStore(),
  baseUrl: 'https://api.example.test/api/v1',
  requestTimeout: timeout,
);
void phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
}

void main() {
  testWidgets(
    'stalled response body times out and cancels the individual request',
    (tester) async {
      final client = StalledClient();
      final repo = repository(client, timeout: const Duration(seconds: 2));
      final response = repo.getEmails();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(seconds: 3));
      expect(
        client.bodyCancelled,
        isTrue,
        reason: 'deadline reached before waiting for result',
      );
      expect(await response, isNull);
      expect(client.bodyCancelled, isTrue);
      expect(client.abortSignalled, isTrue);
      expect(repo.lastError, 'The server took too long to respond.');
      client.recovered = true;
      final retry = repo.getEmails();
      await tester.pump();
      await tester.pump();
      expect((await retry)?.total, 0);
      expect(repo.lastError, isNull);
      unawaited(client.body.close());
    },
  );
  testWidgets(
    'timeout includes connection and headers as well as body transfer',
    (tester) async {
      final waiting = Completer<http.StreamedResponse>();
      final client = _HeadersClient(waiting.future);
      final result = sendApiRequest(
        client,
        http.Request('GET', Uri.parse('https://example.test')),
        timeout: const Duration(seconds: 2),
      ).then<Object?>((r) => r, onError: (Object e) => e);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(seconds: 3));
      expect(await result, isA<TimeoutException>());
      // A late response is drained/cancelled without updating a finished request.
      waiting.complete(http.StreamedResponse(const Stream.empty(), 200));
      await tester.pump();
    },
  );
  testWidgets(
    'request cancellation stops a streaming body without waiting for the deadline',
    (tester) async {
      final client = StalledClient();
      final token = RequestCancellation();
      final pending = sendApiRequest(
        client,
        http.Request('GET', Uri.parse('https://example.test')),
        timeout: const Duration(seconds: 15),
        cancellation: token,
      ).then<Object?>((value) => value, onError: (Object error) => error);
      await tester.pump();
      token.cancel();
      await tester.pump();
      expect(await pending, isA<http.RequestAbortedException>());
      expect(client.bodyCancelled, isTrue);
      expect(client.abortSignalled, isTrue);
      unawaited(client.body.close());
    },
  );
  testWidgets(
    'stalled token-refresh body is bounded and preserves saved credentials',
    (tester) async {
      final client = StalledClient();
      final store = MemorySessionStore()..refreshToken = 'saved';
      final repo = SenderWhoRepository(
        previewMode: false,
        client: client,
        sessionStore: store,
        baseUrl: 'https://api.example.test/api/v1',
        requestTimeout: const Duration(seconds: 1),
      );
      final pending = repo.restoreSession();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(seconds: 2));
      expect(await pending, isFalse);
      expect(client.bodyCancelled, isTrue);
      expect(store.refreshToken, 'saved');
      unawaited(client.body.close());
    },
  );
  testWidgets(
    'editing the query then loading more starts page one and never mixes searches',
    (tester) async {
      phone(tester);
      final requests = <Map<String, dynamic>>[];
      final repo = repository(
        MockClient((request) async {
          if (request.method == 'GET') {
            return json({
              'categories': ['Finance'],
              'trustScores': ['All'],
              'dateRanges': ['Any time'],
            });
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(body);
          final label = '${body['query']}-page-${body['page']}';
          return json({
            'senders': [],
            'emails': [
              {
                'id': label,
                'sender': 'Sender',
                'email': 'sender@example.com',
                'subject': label,
                'date': 'Today',
              },
            ],
            'total': 50,
            'returned': 1,
            'page': body['page'],
            'limit': 25,
            'hasMore': true,
          });
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: SearchFilterScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      await search(tester, 'alpha');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'beta');
      await tester.ensureVisible(find.text('Load more'));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(requests.last['query'], 'beta');
      expect(requests.last['page'], 1);
      expect(find.text('alpha-page-1'), findsNothing);
      expect(find.text('beta-page-1'), findsOneWidget);
      await tester.ensureVisible(find.text('Load more'));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(requests.last['page'], 2);
      expect(find.text('beta-page-1'), findsOneWidget);
      expect(find.text('beta-page-2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('new submitted search supersedes a slower old response', (
    tester,
  ) async {
    phone(tester);
    final old = Completer<http.Response>();
    final repo = repository(
      MockClient((request) async {
        if (request.method == 'GET') {
          return json({
            'categories': [],
            'trustScores': ['All'],
            'dateRanges': ['Any time'],
          });
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['query'] == 'old') return old.future;
        return json({
          'senders': [],
          'emails': [
            {
              'id': 'new',
              'sender': 'Sender',
              'subject': 'New result',
              'date': 'Today',
            },
          ],
          'total': 1,
          'returned': 1,
          'page': 1,
          'hasMore': false,
        });
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: SearchFilterScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    await search(tester, 'old');
    await tester.pump();
    await search(tester, 'new');
    await tester.pumpAndSettle();
    expect(find.text('New result'), findsOneWidget);
    old.complete(
      json({
        'senders': [],
        'emails': [],
        'total': 0,
        'page': 1,
        'hasMore': false,
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('New result'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'search cancellation clears busy state and ignores late results',
    (tester) async {
      phone(tester);
      final waiting = Completer<http.Response>();
      final repo = repository(
        MockClient((request) async {
          if (request.method == 'GET') {
            return json({
              'categories': [],
              'trustScores': ['All'],
              'dateRanges': ['Any time'],
            });
          }
          return waiting.future;
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: SearchFilterScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      await search(tester, 'slow');
      await tester.pump();
      await tester.ensureVisible(find.text('Cancel search'));
      await tester.tap(find.text('Cancel search'));
      await tester.pumpAndSettle();
      expect(find.text('Searching…'), findsNothing);
      waiting.complete(
        json({
          'senders': [],
          'emails': [
            {'id': 'old', 'subject': 'Cancelled result'},
          ],
          'total': 1,
          'page': 1,
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cancelled result'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'subscriptions load all pages, search beyond page one, and retain rows on a failed page',
    (tester) async {
      phone(tester);
      final queries = <Map<String, String>>[];
      var failMore = true;
      final repo = repository(
        MockClient((request) async {
          if (request.url.path.endsWith('/unsubscribe/jobs')) {
            return json({'items': []});
          }
          final q = Map.of(request.url.queryParameters);
          queries.add(q);
          final page = int.parse(q['page'] ?? '1');
          final search = q['query'] ?? '';
          if (page == 2 && failMore) {
            return http.Response('{"message":"Temporarily unavailable"}', 503);
          }
          final rows =
              [
                    for (var i = 0; i < 40; i++)
                      {
                        'id': 'sender-$i',
                        'name': 'Subscription $i',
                        'email': 'sender$i@example.com',
                        'reason': 'Supports unsubscribe',
                      },
                  ]
                  .where(
                    (s) =>
                        s['name']!.toLowerCase().contains(search.toLowerCase()),
                  )
                  .toList();
          return json({
            'items': rows.skip((page - 1) * 25).take(25).toList(),
            'total': rows.length,
            'page': page,
            'hasMore': page * 25 < rows.length,
          });
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: UnsubscribeScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('25 of 40 subscriptions'), findsOneWidget);
      await tester.ensureVisible(find.text('Load more subscriptions'));
      await tester.tap(find.text('Load more subscriptions'));
      await tester.pumpAndSettle();
      expect(find.text('Subscription 0'), findsOneWidget);
      expect(find.text('Could not load more subscriptions'), findsOneWidget);
      failMore = false;
      await tester.ensureVisible(find.text('Load more subscriptions'));
      await tester.tap(find.text('Load more subscriptions'));
      await tester.pumpAndSettle();
      expect(queries.last['page'], '2');
      expect(
        find.byKey(const ValueKey('subscription-row-sender-39')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Search subscriptions'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Subscription 39');
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
      expect(queries.last['query'], 'Subscription 39');
      expect(queries.last['page'], '1');
      expect(
        find.byKey(const ValueKey('subscription-row-sender-39')),
        findsOneWidget,
      );
      expect(find.text('Subscription 0'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'subscription actions and status checks respect the 25-item API limit',
    () async {
      final sent = <List<dynamic>>[];
      final repo = repository(
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final ids = (body['senderIds'] ?? body['jobIds']) as List;
          sent.add(ids);
          return json(
            request.url.path.endsWith('/status')
                ? {
                    'items': [
                      for (final id in ids)
                        {'id': id, 'senderId': id, 'status': 'QUEUED'},
                    ],
                  }
                : {
                    'jobs': [
                      for (final id in ids)
                        {'id': id, 'senderId': id, 'status': 'QUEUED'},
                    ],
                    'failures': [],
                  },
          );
        }),
      );
      final ids = List.generate(60, (i) => 'sender-$i');
      expect((await repo.createUnsubscribeJobs(ids))!.jobs.length, 60);
      expect((await repo.getUnsubscribeJobs(ids)).length, 60);
      expect(sent.map((s) => s.length).toList(), [25, 25, 10, 25, 25, 10]);
    },
  );
}

class _HeadersClient extends http.BaseClient {
  _HeadersClient(this.response);
  final Future<http.StreamedResponse> response;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => response;
}

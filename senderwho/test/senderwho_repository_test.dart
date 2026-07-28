import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/models/app_models.dart';
import 'package:sender_who/services/senderwho_repository.dart';

void main() {
  test('logout storage keeps only the remembered account identity', () async {
    final store = MemorySessionStore()
      ..refreshToken = 'refresh-token'
      ..rememberedEmail = 'person@example.com';

    await store.clear();

    expect(await store.readRefreshToken(), isNull);
    expect(await store.readRememberedEmail(), 'person@example.com');
  });

  test('a pending Google sign-in can be canceled safely', () async {
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/oauth/google/start')) {
          return http.Response(
            jsonEncode({
              'authorizationUrl': 'https://accounts.google.com/o/oauth2/auth',
              'loginSessionId': 'login-session',
              'loginSessionSecret': 'login-secret',
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'status': 'PENDING'}), 200);
      }),
      sessionStore: MemorySessionStore(),
      launchExternal: (_) async => true,
      baseUrl: 'https://api.example.test/api/v1',
    );

    final signIn = repository.startOAuth('google');
    repository.cancelOAuth();

    expect(await signIn, isFalse);
    expect(repository.lastError, 'Sign-in was canceled.');
  });

  test('discovers which production sign-in providers are available', () async {
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        expect(request.url.path, endsWith('/auth/providers'));
        expect(request.headers['authorization'], isNull);
        return http.Response(
          jsonEncode({
            'providers': {
              'google': {'enabled': true},
              'yahoo': {'enabled': false},
            },
          }),
          200,
        );
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    expect(await repository.availableAuthProviders(), {
      'google': true,
      'yahoo': false,
    });
    expect(repository.lastError, isNull);
  });

  test('secure storage read failures do not crash app startup', () async {
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((_) async => http.Response('Unexpected request', 500)),
      sessionStore: _FailingSessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    expect(await repository.restoreSession(), isFalse);
    expect(repository.isAuthenticated, isFalse);
    expect(repository.authenticationState.value, isFalse);
  });

  test(
    'restores and rotates a secure session before loading real data',
    () async {
      final store = MemorySessionStore()..refreshToken = 'refresh-old';
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          expect(request.headers['x-senderwho-device-id'], isNotEmpty);
          expect(request.headers['x-senderwho-device-name'], isNotEmpty);
          expect(jsonDecode(request.body), {'refreshToken': 'refresh-old'});
          return http.Response(
            jsonEncode({
              'status': 'AUTHENTICATED',
              'accessToken': 'access-new',
              'refreshToken': 'refresh-new',
              'user': {'email': 'person@example.com'},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/dashboard')) {
          expect(request.headers['authorization'], 'Bearer access-new');
          return http.Response(
            jsonEncode({
              'inboxHealth': {'score': 88, 'status': 'Good'},
              'metrics': {
                'totalMessages': 30,
                'totalSenders': 12,
                'unreadEmails': 3,
                'newsletters': 2,
                'promotions': 7,
                'spam': 1,
              },
              'opportunities': {
                'cleanupMessages': 8,
                'estimatedSpaceBytes': 2048,
                'unsubscribeSenders': 4,
              },
              'topSenders': [
                {
                  'id': 'sender-1',
                  'rank': 1,
                  'name': 'Example Sender',
                  'email': 'sender@example.com',
                  'count': 9,
                },
              ],
              'recentAlerts': <Object>[],
              'sync': {
                'id': 'gmail-1',
                'emailAddress': 'person@example.com',
                'syncStatus': 'READY',
                'recoveryAction': 'NONE',
                'lastSyncedAt': '2026-07-14T10:00:00.000Z',
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });
      final repository = SenderWhoRepository(
        previewMode: false,
        client: client,
        sessionStore: store,
        baseUrl: 'https://api.example.test/api/v1',
      );

      expect(await repository.restoreSession(), isTrue);
      expect(store.refreshToken, 'refresh-new');
      expect(repository.userEmail, 'person@example.com');

      final dashboard = await repository.getDashboard();
      expect(dashboard.inboxHealthScore, 88);
      expect(dashboard.totalSenders, 12);
      expect(dashboard.syncStatus, 'READY');
      expect(dashboard.promotions, 7);
      expect(dashboard.cleanupMessages, 8);
      expect(dashboard.unsubscribeSenders, 4);
      expect(dashboard.topSenders.single.id, 'sender-1');
      expect(dashboard.connectedAccountId, 'gmail-1');
      expect(dashboard.syncRecoveryAction, 'NONE');
    },
  );

  test(
    'loads a Gmail conversation and selected message content from real API contracts',
    () async {
      final store = MemorySessionStore()..refreshToken = 'refresh-old';
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return http.Response(
            jsonEncode({
              'status': 'AUTHENTICATED',
              'accessToken': 'access-new',
              'refreshToken': 'refresh-new',
              'user': {'email': 'person@example.com'},
            }),
            200,
          );
        }
        expect(request.headers['authorization'], 'Bearer access-new');
        if (request.url.path.endsWith('/emails/message-1/thread')) {
          return http.Response(
            jsonEncode({
              'threadId': 'thread-1',
              'total': 2,
              'items': [
                {
                  'id': 'message-1',
                  'threadId': 'thread-1',
                  'sender': 'Billing',
                  'email': 'billing@example.com',
                  'subject': 'Invoice',
                  'date': '2026-07-14T10:00:00.000Z',
                  'accountEmail': 'person@example.com',
                },
                {
                  'id': 'message-2',
                  'threadId': 'thread-1',
                  'sender': 'Person',
                  'email': 'person@example.com',
                  'subject': 'Re: Invoice',
                  'date': '2026-07-14T11:00:00.000Z',
                  'accountEmail': 'person@example.com',
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
              'from': 'Billing <billing@example.com>',
              'to': 'person@example.com',
              'cc': '',
              'subject': 'Invoice',
              'date': 'Tue, 14 Jul 2026 10:00:00 +0000',
              'bodyText': 'Your complete invoice is ready.',
              'truncated': false,
              'attachments': [
                {'filename': 'invoice.pdf', 'sizeBytes': 2048},
              ],
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });
      final repository = SenderWhoRepository(
        previewMode: false,
        client: client,
        sessionStore: store,
        baseUrl: 'https://api.example.test/api/v1',
      );

      expect(await repository.restoreSession(), isTrue);
      final thread = await repository.getEmailThread('message-1');
      final content = await repository.getEmailContent('message-1');

      expect(thread?.threadId, 'thread-1');
      expect(thread?.items.length, 2);
      expect(thread?.items.last.sender, 'Person');
      expect(content?.bodyText, 'Your complete invoice is ready.');
      expect(content?.attachments.single.filename, 'invoice.pdf');
    },
  );

  test(
    'refreshes once and retries an API request after access token expiry',
    () async {
      final store = MemorySessionStore()..refreshToken = 'refresh-0';
      var refreshCount = 0;
      var dashboardCount = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshCount += 1;
          final expected = refreshCount == 1 ? 'refresh-0' : 'refresh-1';
          expect(jsonDecode(request.body), {'refreshToken': expected});
          return http.Response(
            jsonEncode({
              'status': 'AUTHENTICATED',
              'accessToken': 'access-$refreshCount',
              'refreshToken': 'refresh-$refreshCount',
              'user': {'email': 'person@example.com'},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/dashboard')) {
          dashboardCount += 1;
          if (dashboardCount == 1) {
            expect(request.headers['authorization'], 'Bearer access-1');
            return http.Response('Unauthorized', 401);
          }
          expect(request.headers['authorization'], 'Bearer access-2');
          return http.Response(
            jsonEncode({
              'inboxHealth': {'score': 0, 'status': 'Waiting for scan'},
              'metrics': <String, int>{},
              'recentAlerts': <Object>[],
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });
      final repository = SenderWhoRepository(
        previewMode: false,
        client: client,
        sessionStore: store,
        baseUrl: 'https://api.example.test/api/v1',
      );

      expect(await repository.restoreSession(), isTrue);
      await repository.getDashboard();

      expect(refreshCount, 2);
      expect(dashboardCount, 2);
      expect(store.refreshToken, 'refresh-2');
    },
  );

  test('preserves the idempotency key when a mutation is retried', () async {
    final store = MemorySessionStore()..refreshToken = 'refresh-0';
    var refreshCount = 0;
    final idempotencyKeys = <String?>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        refreshCount += 1;
        return http.Response(
          jsonEncode({
            'status': 'AUTHENTICATED',
            'accessToken': 'access-$refreshCount',
            'refreshToken': 'refresh-$refreshCount',
            'user': {'email': 'person@example.com'},
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/emails/actions/archive')) {
        idempotencyKeys.add(request.headers['idempotency-key']);
        if (idempotencyKeys.length == 1) {
          return http.Response(jsonEncode({'message': 'Expired'}), 401);
        }
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
    });
    final repository = SenderWhoRepository(
      previewMode: false,
      client: client,
      sessionStore: store,
      baseUrl: 'https://api.example.test/api/v1',
    );

    expect(await repository.restoreSession(), isTrue);
    final result = await repository.archiveEmails(['message-1']);

    expect(result?.succeeded, isTrue);
    expect(idempotencyKeys, hasLength(2));
    expect(idempotencyKeys.first, isNotNull);
    expect(idempotencyKeys.last, idempotencyKeys.first);
  });

  test('message action results preserve processed IDs and failure details', () {
    final result = MessageActionResult.fromJson({
      'action': 'archive',
      'requested': 2,
      'processed': 1,
      'failed': 1,
      'processedIds': ['message-1'],
      'failures': [
        {'messageId': 'message-2', 'reason': 'Gmail rejected the update.'},
      ],
    });

    expect(result.processedIds, ['message-1']);
    expect(result.failures, hasLength(1));
    expect(result.failures.single.messageId, 'message-2');
    expect(result.failures.single.reason, 'Gmail rejected the update.');
    expect(result.succeeded, isFalse);
  });

  test(
    'unarchive mutation uses the API contract and parses its outcome',
    () async {
      final repository = SenderWhoRepository(
        previewMode: false,
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/emails/actions/unarchive');
          expect(jsonDecode(request.body), {
            'messageIds': ['message-archived'],
          });
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
        }),
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
      );

      final result = await repository.unarchiveEmails(['message-archived']);

      expect(result?.action, 'unarchive');
      expect(result?.processedIds, ['message-archived']);
      expect(result?.failures, isEmpty);
      expect(result?.succeeded, isTrue);
    },
  );

  test('loads alert details and preserves mutation outcome metadata', () async {
    final requestKeys = <String, String?>{};
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/security-alerts/alert-1') &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'id': 'alert-1',
              'senderId': 'sender-1',
              'messageId': 'message-1',
              'status': 'OPEN',
              'title': 'Suspicious sender',
              'email': 'alert@example.test',
              'reason': 'Domain changed',
              'time': '2026-07-19T08:00:00.000Z',
              'risk': 'High Risk',
              'colorKey': 'danger',
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/security-alerts/alert-1/dismiss')) {
          requestKeys['dismiss'] = request.headers['idempotency-key'];
          return http.Response(
            jsonEncode({'id': 'alert-1', 'status': 'DISMISSED'}),
            200,
          );
        }
        if (request.url.path.endsWith('/email-accounts/account-1')) {
          requestKeys['disconnect'] = request.headers['idempotency-key'];
          return http.Response(
            jsonEncode({
              'id': 'account-1',
              'syncStatus': 'DISCONNECTED',
              'providerRevoked': false,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    final alert = await repository.getSecurityAlert('alert-1');
    expect(alert.senderId, 'sender-1');
    expect(alert.messageId, 'message-1');
    expect(alert.status, 'OPEN');
    expect(alert.email, 'alert@example.test');
    expect(await repository.dismissSecurityAlert('alert-1'), isTrue);
    final disconnect = await repository.disconnectAccount('account-1');
    expect(disconnect?.disconnected, isTrue);
    expect(disconnect?.providerRevoked, isFalse);
    expect(requestKeys['dismiss'], isNotEmpty);
    expect(requestKeys['disconnect'], isNotEmpty);
  });

  test(
    'required collection reads report API failures instead of fake empties',
    () {
      final repository = SenderWhoRepository(
        previewMode: false,
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode({'message': 'Unavailable'}), 503),
        ),
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
      );

      expect(
        repository.getSecurityAlerts(),
        throwsA(isA<SenderWhoRequestException>()),
      );
    },
  );

  test(
    'prepares a complete paginated export across every safe section',
    () async {
      final requests = <String>[];
      final repository = SenderWhoRepository(
        previewMode: false,
        client: MockClient((request) async {
          expect(request.url.path, endsWith('/users/me/export'));
          final section = request.url.queryParameters['section']!;
          final page = int.parse(request.url.queryParameters['page']!);
          requests.add('$section:$page');
          if (section == 'messages' && page == 1) {
            return http.Response(
              jsonEncode({
                'section': section,
                'page': page,
                'items': [
                  {'id': 'message-1'},
                ],
                'hasMore': true,
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'section': section,
              'page': page,
              'items': [
                {'id': section == 'messages' ? 'message-2' : '$section-1'},
              ],
              'hasMore': false,
            }),
            200,
          );
        }),
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
      );

      final export = await repository.prepareCompleteExport();
      final sections = export['sections']! as Map<String, dynamic>;

      expect(export['format'], 'senderwho-data-export');
      expect(sections.keys, {
        'profile',
        'accounts',
        'senders',
        'messages',
        'alerts',
        'audit',
      });
      expect(sections['messages'], [
        {'id': 'message-1'},
        {'id': 'message-2'},
      ]);
      expect(requests, containsAll(['messages:1', 'messages:2', 'audit:1']));
      expect(requests, hasLength(7));
    },
  );

  test(
    'search sends bounded pagination and parses a continuation page',
    () async {
      final repository = SenderWhoRepository(
        previewMode: false,
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['page'], 3);
          expect(body['limit'], 25);
          return http.Response(
            jsonEncode({
              'total': 80,
              'page': 3,
              'limit': 25,
              'hasMore': true,
              'senders': <Object>[],
              'emails': [
                {
                  'id': 'message-51',
                  'sender': 'Billing',
                  'email': 'billing@example.test',
                  'subject': 'Invoice',
                  'date': '2026-07-20T08:00:00.000Z',
                },
              ],
            }),
            200,
          );
        }),
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
      );

      final result = await repository.search(
        query: 'invoice',
        selected: {'Finance'},
        attachments: false,
        unread: false,
        page: 3,
      );

      expect(result?.page, 3);
      expect(result?.hasMore, isTrue);
      expect(result?.emails.single.id, 'message-51');
    },
  );

  test('cleanup preview returns the exact de-duplicated impact', () async {
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/cleanup/preview');
        expect(request.headers['idempotency-key'], isNotEmpty);
        expect(jsonDecode(request.body), {
          'emailAccountId': 'account-1',
          'categories': ['MARKETING', 'NEWSLETTERS'],
        });
        return http.Response(
          jsonEncode({
            'previewId': 'preview-1',
            'emailAccountId': 'account-1',
            'categories': ['MARKETING', 'NEWSLETTERS'],
            'totalMessages': 7,
            'estimatedSpaceBytes': 4096,
          }),
          200,
        );
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    final preview = await repository.previewCleanup(
      emailAccountId: 'account-1',
      categories: ['MARKETING', 'NEWSLETTERS'],
    );

    expect(preview?.totalMessages, 7);
    expect(preview?.previewId, 'preview-1');
    expect(preview?.estimatedSpaceBytes, 4096);
    expect(preview?.categories, ['MARKETING', 'NEWSLETTERS']);
  });

  test('cleanup job is bound to the reviewed preview', () async {
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/cleanup/jobs');
        expect(jsonDecode(request.body), {
          'emailAccountId': 'account-1',
          'categories': ['MARKETING'],
          'previewId': 'preview-1',
        });
        return http.Response(
          jsonEncode({
            'id': 'job-1',
            'status': 'QUEUED',
            'totalMessages': 4,
            'processedMessages': 0,
            'failedMessages': 0,
          }),
          200,
        );
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    final job = await repository.createCleanupJob(
      emailAccountId: 'account-1',
      categories: ['MARKETING'],
      previewId: 'preview-1',
    );

    expect(job?.id, 'job-1');
  });

  test('unsubscribe job normalizes status and sanitizes its safe reason', () {
    final job = UnsubscribeJobInfo.fromJson({
      'id': 'unsubscribe-1',
      'senderId': 'sender-1',
      'status': 'failed',
      'failureReason':
          '${List.filled(20, 'Provider response\n').join()}retry later',
    });

    expect(job.status, 'FAILED');
    expect(job.isFinished, isTrue);
    expect(job.isActive, isFalse);
    expect(job.failureReason, isNot(contains('\n')));
    expect(job.failureReason.length, lessThanOrEqualTo(180));
  });

  test(
    'active unsubscribe jobs are restored with their sender state',
    () async {
      final repository = SenderWhoRepository(
        previewMode: false,
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/unsubscribe/jobs');
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'unsubscribe-active',
                  'senderId': 'sender-1',
                  'status': 'RUNNING',
                },
              ],
            }),
            200,
          );
        }),
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
      );

      final jobs = await repository.getActiveUnsubscribeJobs();

      expect(jobs.single.id, 'unsubscribe-active');
      expect(jobs.single.senderId, 'sender-1');
      expect(jobs.single.status, 'RUNNING');
      expect(jobs.single.isActive, isTrue);
    },
  );

  test('batch unsubscribe preserves jobs and per-sender failures', () async {
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/unsubscribe/jobs/batch');
        expect(jsonDecode(request.body), {
          'senderIds': ['sender-1', 'sender-2'],
        });
        expect(request.headers['idempotency-key'], isNotEmpty);
        return http.Response(
          jsonEncode({
            'requested': 2,
            'queued': 1,
            'failed': 1,
            'jobs': [
              {'id': 'job-1', 'senderId': 'sender-1', 'status': 'QUEUED'},
            ],
            'failures': [
              {
                'senderId': 'sender-2',
                'reason': 'This unsubscribe request could not be queued.',
              },
            ],
          }),
          200,
        );
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    final result = await repository.createUnsubscribeJobs([
      'sender-1',
      'sender-2',
    ]);

    expect(result?.jobs.single.senderId, 'sender-1');
    expect(result?.jobs.single.isActive, isTrue);
    expect(result?.failures.single.senderId, 'sender-2');
    expect(result?.failures.single.reason, contains('could not be queued'));
  });

  test(
    'active cleanup jobs are restored from the current user endpoint',
    () async {
      final repository = SenderWhoRepository(
        previewMode: false,
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/cleanup/jobs');
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
        }),
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
      );

      final jobs = await repository.getActiveCleanupJobs();

      expect(jobs.single.id, 'job-active');
      expect(jobs.single.processedMessages, 8);
      expect(jobs.single.isFinished, isFalse);
    },
  );

  test('canceled cleanup jobs are terminal and do not poll forever', () {
    final job = CleanupJobInfo.fromJson({
      'id': 'cleanup-canceled',
      'status': 'CANCELED',
      'totalMessages': 10,
      'processedMessages': 4,
      'failedMessages': 6,
    });

    expect(job.isFinished, isTrue);
  });
}

class _FailingSessionStore implements SessionStore {
  @override
  Future<void> clear() => throw StateError('Secure storage unavailable');

  @override
  Future<String?> readRefreshToken() =>
      throw StateError('Secure storage unavailable');

  @override
  Future<String?> readDeviceId() =>
      throw StateError('Secure storage unavailable');

  @override
  Future<String?> readRememberedEmail() =>
      throw StateError('Secure storage unavailable');

  @override
  Future<void> writeRefreshToken(String token) =>
      throw StateError('Secure storage unavailable');

  @override
  Future<void> writeDeviceId(String deviceId) =>
      throw StateError('Secure storage unavailable');

  @override
  Future<void> writeRememberedEmail(String email) =>
      throw StateError('Secure storage unavailable');
}

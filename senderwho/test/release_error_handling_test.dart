import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/models/app_models.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/utils/user_friendly_error.dart';

void main() {
  test('provider failures never expose technical details in subscriptions', () {
    for (final reason in [
      'PlatformException(keychain, failed, null, null)',
      'Bad state: response stream has already been listened to',
      '<html><body>Service failure</body></html>',
      'Request failed at https://provider.example/unsubscribe?token=secret',
      'client_secret=private-value',
      'PrismaClientKnownRequestError: P2002',
    ]) {
      final job = UnsubscribeJobInfo.fromJson({'failureReason': reason});
      final failure = UnsubscribeBatchFailure.fromJson({'reason': reason});
      expect(
        job.failureReason,
        'The unsubscribe request could not be completed. Please try again.',
      );
      expect(failure.reason, job.failureReason);
    }
    expect(
      UnsubscribeJobInfo.fromJson({
        'failureReason': 'The sender is temporarily unavailable. Try again.',
      }).failureReason,
      'The sender is temporarily unavailable. Try again.',
    );
    expect(UnsubscribeJobInfo.fromJson({}).failureReason, isEmpty);
  });

  test(
    'offline messages give recovery guidance without exposing addresses',
    () {
      expect(
        sanitizeUserMessage(
          "SocketException: Failed host lookup: 'private.example'",
        ),
        'Couldn’t connect. Check your connection and try again.',
      );
      expect(sanitizeUserMessage('Please\x00try\nagain.'), 'Please try again.');
      expect(
        friendlyHttpErrorMessage(
          401,
          serverMessage: 'Recent authentication is required for this action.',
        ),
        'Please sign in again to confirm this action.',
      );
    },
  );

  for (final openSignIn in [true, false]) {
    test(
      openSignIn
          ? 'account deletion reauthenticates and retries with the same request key'
          : 'account deletion preserves the session if fresh sign-in cannot open',
      () async {
        final store = MemorySessionStore()..refreshToken = 'saved-refresh';
        final deletes = <http.Request>[];
        var refreshes = 0;
        var reauthStarts = 0;
        var launches = 0;
        http.Response json(Map<String, dynamic> value, [int status = 200]) =>
            http.Response(jsonEncode(value), status);
        final repo = SenderWhoRepository(
          previewMode: false,
          sessionStore: store,
          baseUrl: 'https://api.example.test/api/v1',
          oauthPollInterval: Duration.zero,
          launchExternal: (uri) async {
            launches++;
            return openSignIn;
          },
          client: MockClient((request) async {
            switch (request.url.path) {
              case '/api/v1/auth/refresh':
                refreshes++;
                return json({
                  'status': 'AUTHENTICATED',
                  'accessToken': 'access',
                  'refreshToken': 'rotated-refresh',
                  'user': {'email': 'owner@example.com'},
                });
              case '/api/v1/auth/reauth/start':
                reauthStarts++;
                return json({
                  'authorizationUrl': 'https://accounts.example.test/authorize',
                  'loginSessionId': 'login',
                  'loginSessionSecret': 'login-secret',
                  'provider': 'google',
                });
              case '/api/v1/auth/oauth/session/exchange':
                return json({
                  'status': 'REAUTHENTICATED',
                  'accessToken': 'recent-access',
                });
              case '/api/v1/users/me':
                expect(request.method, 'DELETE');
                deletes.add(request);
                if (deletes.length == 1) {
                  return json({
                    'message':
                        'Recent authentication is required for this action.',
                  }, 401);
                }
                expect(
                  request.headers['Authorization'],
                  'Bearer recent-access',
                );
                return json({'success': true});
              default:
                fail(
                  'Unexpected request: ${request.method} ${request.url.path}',
                );
            }
          }),
        );
        expect(await repo.restoreSession(), isTrue);
        expect(await repo.deleteAccount(), openSignIn);
        expect(refreshes, 1);
        expect(reauthStarts, 1);
        expect(launches, 1);
        expect(deletes, hasLength(openSignIn ? 2 : 1));
        if (openSignIn) {
          expect(deletes.first.headers['Idempotency-Key'], isNotEmpty);
          expect(
            deletes.last.headers['Idempotency-Key'],
            deletes.first.headers['Idempotency-Key'],
          );
          expect(store.refreshToken, isNull);
          expect(repo.isAuthenticated, isFalse);
        } else {
          expect(store.refreshToken, 'rotated-refresh');
          expect(repo.isAuthenticated, isTrue);
          expect(repo.lastError, contains('Could not open Google sign-in'));
        }
      },
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sender_who/utils/user_friendly_error.dart';

void main() {
  group('userFriendlyErrorMessage', () {
    test(
      'long or structured errors stay short and permissions give guidance',
      () {
        for (final error in [
          List.filled(30, 'details').join(' '),
          '{"message":"provider failure","credential":"secret"}',
          'Failed eyJheader.payload.signature',
        ]) {
          final message = sanitizeUserMessage(error);
          expect(message.length, lessThanOrEqualTo(120));
          expect(message, 'Couldn’t complete that. Please try again.');
        }
        expect(
          sanitizeUserMessage(
            'Google did not grant all required SenderWho permissions.',
          ),
          'Reconnect your mailbox and allow email access.',
        );
      },
    );
    test(
      'revoked Google access asks for sign-in without claiming a known password change',
      () {
        final message = mailboxSyncError(
          'Google access expired or was revoked. Reconnect Gmail to continue scanning.',
        );
        expect(message, contains('Sign in again'));
        expect(message, isNot(contains('password')));
        expect(message, isNot(contains('invalid_grant')));
        expect(
          friendlyHttpErrorMessage(
            401,
            serverMessage: 'Google access was revoked. Reconnect the account.',
          ),
          contains('Gmail access changed'),
        );
        expect(
          friendlyHttpErrorMessage(401, serverMessage: 'Invalid app session'),
          contains('session has expired'),
        );
      },
    );
    test('removes generic exception prefixes', () {
      expect(
        userFriendlyErrorMessage(Exception('Please try again.')),
        'Please try again.',
      );
    });

    test('never exposes internal implementation details', () {
      for (final error in [
        'PrismaClientKnownRequestError: SQLSTATE 23505',
        'SocketException: Connection refused localhost:3000',
        'Null check operator used on a null value app.dart:42',
        'Internal server error',
      ]) {
        expect(userFriendlyErrorMessage(error), contains('try again'));
        expect(userFriendlyErrorMessage(error), isNot(contains(error)));
      }
    });

    test('maps HTTP failures to actionable messages', () {
      expect(friendlyHttpErrorMessage(401), contains('session has expired'));
      expect(friendlyHttpErrorMessage(403), contains('reconnect'));
      expect(friendlyHttpErrorMessage(429), contains('wait a moment'));
      expect(
        friendlyHttpErrorMessage(503),
        contains('temporarily unavailable'),
      );
    });

    test('keeps safe validation guidance but rejects unsafe server text', () {
      expect(
        friendlyHttpErrorMessage(400, serverMessage: 'Enter a valid email.'),
        'Enter a valid email.',
      );
      expect(
        friendlyHttpErrorMessage(
          400,
          serverMessage: 'Prisma failed in /src/auth.ts',
        ),
        'Please check the information you entered and try again.',
      );
    });

    test(
      'explains an outdated API without exposing query validation internals',
      () {
        final message = friendlyHttpErrorMessage(
          400,
          serverMessage: 'property emailAccountId should not exist',
        );
        expect(message, contains('service update'));
        expect(message, isNot(contains('emailAccountId')));
        expect(
          friendlyHttpErrorMessage(400, serverMessage: 'Enter a valid email.'),
          'Enter a valid email.',
        );
      },
    );
  });
}

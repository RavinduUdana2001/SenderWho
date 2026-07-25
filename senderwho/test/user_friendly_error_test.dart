import 'package:flutter_test/flutter_test.dart';
import 'package:sender_who/utils/user_friendly_error.dart';

void main() {
  group('userFriendlyErrorMessage', () {
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
      expect(friendlyHttpErrorMessage(429), contains('try again shortly'));
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
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/models/app_models.dart';
import 'package:sender_who/screens/connected_accounts_screen.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/app_theme.dart';
import 'package:sender_who/utils/user_friendly_error.dart';
import 'package:sender_who/widgets/mailbox_sync_notice.dart';
import 'package:sender_who/widgets/sender_drawer.dart';
import 'support/ui_review_repository.dart';

void main() {
  test('legacy quota errors stay concise and do not suggest reconnecting', () {
    for (final error in [
      'Gmail is temporarily limiting mailbox scans. Wait a few minutes and try Scan now.',
      'Gmail is busy. Your saved mail is still available. Sync can continue after a short pause.',
    ]) {
      final message = mailboxSyncError(error);
      expect(message.length, lessThan(110));
      expect(isMailboxRateLimited(message), isTrue);
      expect(message.toLowerCase(), isNot(contains('reconnect')));
      expect(message.toLowerCase(), isNot(contains('try again')));
    }
    expect(
      userFriendlyErrorMessage('HTTP 403 provider failure'),
      isNot(contains('403')),
    );
    expect(
      userFriendlyErrorMessage('Bearer private-token'),
      isNot(contains('private-token')),
    );
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'sync and sign-out feedback fits compact phone dark=$dark scale=$scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 640);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.resetDevicePixelRatio();
            tester.view.resetPhysicalSize();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final account = ConnectedEmailAccount.fromJson({
            'id': 'second',
            'emailAddress': 'second@example.com',
            'syncStatus': 'FAILED',
            'lastSyncError':
                'Gmail is temporarily limiting mailbox scans. Wait a few minutes and try Scan now.',
            'recoveryAction': 'RETRY',
            'syncRetryAt': '2026-11-04T20:00:00Z',
          });
          expect(account.needsReconnect, isFalse);
          expect(account.copyWith(isActive: true).hasScheduledRetry, isTrue);
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              routes: {
                ConnectedAccountsScreen.routeName: (_) =>
                    const Scaffold(body: Text('Sync details')),
              },
              home: Scaffold(
                body: SafeArea(
                  child: Column(
                    children: [MailboxSyncNotice(account: account)],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Sync paused'), findsOneWidget);
          expect(find.textContaining('retry automatically'), findsOneWidget);
          expect(find.textContaining('Try again'), findsNothing);
          if (scale == 1) {
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('mailbox-sync-notice')))
                  .height,
              lessThan(150),
            );
          }
          await tester.tap(find.byTooltip('View sync status'));
          await tester.pumpAndSettle();
          expect(find.text('Sync details'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: Scaffold(
                appBar: AppBar(),
                drawer: SenderDrawer(
                  onSignOut: () async =>
                      throw StateError('private implementation detail'),
                ),
              ),
            ),
          );
          await tester.tap(find.byTooltip('Open navigation menu'));
          await tester.pumpAndSettle();
          final signOut = find.byKey(const ValueKey('drawer-sign-out'));
          await tester.scrollUntilVisible(
            signOut,
            160,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          await tester.tap(signOut);
          await tester.pumpAndSettle();
          expect(find.text('Sign out?'), findsOneWidget);
          expect(
            find.textContaining('Your mailboxes stay connected'),
            findsOneWidget,
          );
          if (scale == 1) {
            expect(
              tester
                  .getSize(
                    find
                        .descendant(
                          of: find.byType(AlertDialog),
                          matching: find.byType(Material),
                        )
                        .first,
                  )
                  .height,
              lessThan(300),
            );
          }
          await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Sign out'),
          );
          await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
          await tester.pumpAndSettle();
          expect(
            find.text('Couldn’t sign out. Please try again.'),
            findsOneWidget,
          );
          expect(find.textContaining('private implementation'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'scheduled scan recovery has no reconnect or immediate retry action',
    (tester) async {
      final data = UiReviewData();
      final repo = SenderWhoRepository(
        previewMode: false,
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/email-accounts')) {
            return data.json({
              'items': [
                {
                  'id': 'second',
                  'provider': 'GOOGLE',
                  'emailAddress': 'second@example.com',
                  'isActive': true,
                  'syncStatus': 'FAILED',
                  'recoveryAction': 'RETRY',
                  'lastSyncError': 'Gmail is busy.',
                  'syncRetryAt': '2026-11-04T20:00:00Z',
                },
              ],
            });
          }
          return data.handle(request);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: ConnectedAccountsScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reconnect'), findsNothing);
      expect(find.text('Retry scheduled'), findsOneWidget);
      final action = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Retry scheduled'),
      );
      expect(action.onPressed, isNull);
      expect(find.text('Sync paused'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

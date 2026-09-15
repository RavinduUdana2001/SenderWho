import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/screens/connected_accounts_screen.dart';
import 'package:sender_who/screens/settings_screen.dart';
import 'package:sender_who/services/senderwho_repository.dart';

void main() {
  testWidgets('settings previews every connected mailbox', (tester) async {
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/settings')) {
          return http.Response(
            jsonEncode({
              'account': {'connectedAccountsCount': 2},
              'preferences': {
                'notificationsEnabled': true,
                'inboxScanFrequency': 'Auto',
                'theme': 'Light',
              },
              'emailManagement': {
                'archivedEmails': 0,
                'trashEmails': 0,
                'blockedSenders': 0,
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/email-accounts')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'account-1',
                  'provider': 'GOOGLE',
                  'emailAddress': 'first@gmail.com',
                  'displayName': 'Personal Gmail',
                  'syncStatus': 'READY',
                  'isActive': true,
                },
                {
                  'id': 'account-2',
                  'provider': 'YAHOO',
                  'emailAddress': 'second@yahoo.com',
                  'displayName': 'Work Yahoo',
                  'syncStatus': 'READY',
                  'isActive': false,
                },
              ],
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
    );

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-account-account-1')), findsOne);
    expect(find.byKey(const ValueKey('settings-account-account-2')), findsOne);
    expect(find.text('first@gmail.com'), findsOneWidget);
    expect(find.text('second@yahoo.com'), findsOneWidget);
    expect(find.text('Current mailbox'), findsOneWidget);
  });

  testWidgets(
    'shows every mailbox, available providers, and switches current account',
    (tester) async {
      var activeId = 'account-1';
      var activationRequests = 0;
      final repository = SenderWhoRepository(
        previewMode: false,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/providers')) {
            return http.Response(
              jsonEncode({
                'providers': {
                  'google': {'enabled': true},
                  'yahoo': {'enabled': true},
                },
              }),
              200,
            );
          }
          if (request.method == 'GET' &&
              request.url.path.endsWith('/email-accounts')) {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'account-1',
                    'provider': 'GOOGLE',
                    'emailAddress': 'first@gmail.com',
                    'displayName': 'Personal Gmail',
                    'syncStatus': 'READY',
                    'isActive': activeId == 'account-1',
                  },
                  {
                    'id': 'account-2',
                    'provider': 'YAHOO',
                    'emailAddress': 'second@yahoo.com',
                    'displayName': 'Work Yahoo',
                    'syncStatus': 'READY',
                    'isActive': activeId == 'account-2',
                  },
                ],
              }),
              200,
            );
          }
          if (request.method == 'POST' &&
              request.url.path.endsWith('/email-accounts/account-2/activate')) {
            activationRequests += 1;
            activeId = 'account-2';
            return http.Response(
              jsonEncode({'id': activeId, 'isActive': true}),
              200,
            );
          }
          return http.Response('Not found', 404);
        }),
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
      );

      await tester.pumpWidget(
        MaterialApp(home: ConnectedAccountsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('first@gmail.com'), findsOneWidget);
      expect(find.text('second@yahoo.com'), findsOneWidget);
      expect(find.byKey(const ValueKey('add-gmail-account')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('add-microsoft-account')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('add-yahoo-account')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('current-account-account-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('activate-account-account-2')),
        findsOneWidget,
      );

      final activateButton = find.byKey(
        const ValueKey('activate-account-account-2'),
      );
      await tester.ensureVisible(activateButton);
      await tester.pumpAndSettle();
      await tester.tap(activateButton);
      await tester.pumpAndSettle();

      expect(activationRequests, 1);
      expect(
        find.byKey(const ValueKey('current-account-account-2')),
        findsOneWidget,
      );
      expect(
        find.text('second@yahoo.com is now your current mailbox.'),
        findsOneWidget,
      );
    },
  );
}

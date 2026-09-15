import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/models/app_models.dart';
import 'package:sender_who/screens/email_details_screen.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'marks an unread message read after it stays open for 2 seconds',
    (tester) async {
      var actionCalls = 0;
      Map<String, dynamic>? actionBody;
      var providerIsRead = false;
      final repository = _repository(
        isRead: () => providerIsRead,
        onReadState: (body) {
          actionCalls += 1;
          actionBody = body;
          providerIsRead = body['isRead'] == true;
        },
      );

      await _openDetails(tester, repository, isRead: false);

      expect(actionCalls, 0);
      expect(find.text('New message'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(actionCalls, 0);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(actionCalls, 1);
      expect(actionBody, {
        'messageIds': ['message-1'],
        'isRead': true,
      });
      expect(find.text('New message'), findsNothing);
      expect(find.text('Read'), findsWidgets);
    },
  );

  testWidgets('does not mark the message read when the user leaves early', (
    tester,
  ) async {
    var actionCalls = 0;
    final repository = _repository(
      isRead: () => false,
      onReadState: (_) => actionCalls += 1,
    );

    await _openDetails(tester, repository, isRead: false);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(actionCalls, 0);
  });

  testWidgets('pauses the viewing timer while the app is in the background', (
    tester,
  ) async {
    var actionCalls = 0;
    final repository = _repository(
      isRead: () => false,
      onReadState: (_) => actionCalls += 1,
    );

    await _openDetails(tester, repository, isRead: false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 3));
    expect(actionCalls, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(actionCalls, 1);
  });

  testWidgets('an explicit mark unread choice is not automatically reversed', (
    tester,
  ) async {
    var actionCalls = 0;
    var providerIsRead = true;
    final repository = _repository(
      isRead: () => providerIsRead,
      onReadState: (body) {
        actionCalls += 1;
        providerIsRead = body['isRead'] == true;
      },
    );

    await _openDetails(tester, repository, isRead: true);
    await tester.ensureVisible(find.text('Unread').last);
    await tester.tap(find.text('Unread').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(actionCalls, 1);
    expect(providerIsRead, isFalse);
    expect(find.text('New message'), findsOneWidget);
  });
}

Future<void> _openDetails(
  WidgetTester tester,
  SenderWhoRepository repository, {
  required bool isRead,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        settings: RouteSettings(arguments: _message(isRead)),
        builder: (_) => EmailDetailsScreen(repository: repository),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

SenderWhoRepository _repository({
  required bool Function() isRead,
  required void Function(Map<String, dynamic> body) onReadState,
}) {
  return SenderWhoRepository(
    previewMode: false,
    client: MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path.endsWith('/emails/message-1/thread')) {
        return http.Response(
          jsonEncode({
            'threadId': 'thread-1',
            'total': 1,
            'items': [_messageJson(isRead())],
          }),
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.path.endsWith('/emails/message-1/content')) {
        return http.Response(
          jsonEncode({
            'id': 'message-1',
            'from': 'Sender <sender@example.test>',
            'to': 'owner@example.test',
            'cc': '',
            'subject': 'Read-state test',
            'date': '8 September 2026',
            'bodyText': 'Test message body.',
            'truncated': false,
            'attachments': <Object>[],
          }),
          200,
        );
      }
      if (request.method == 'POST' &&
          request.url.path.endsWith('/emails/actions/read-state')) {
        final body = (jsonDecode(request.body) as Map).cast<String, dynamic>();
        onReadState(body);
        return http.Response(
          jsonEncode({
            'action': 'read-state',
            'requested': 1,
            'processed': 1,
            'failed': 0,
            'processedIds': ['message-1'],
            'failures': <Object>[],
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    }),
    sessionStore: MemorySessionStore(),
    baseUrl: 'https://api.example.test/api/v1',
  );
}

EmailItem _message(bool isRead) => EmailItem.fromJson(_messageJson(isRead));

Map<String, dynamic> _messageJson(bool isRead) => {
  'id': 'message-1',
  'senderId': 'sender-1',
  'threadId': 'thread-1',
  'sender': 'Sender',
  'email': 'sender@example.test',
  'subject': 'Read-state test',
  'snippet': 'Test message body.',
  'date': '2026-09-08T04:00:00.000Z',
  'category': 'IMPORTANT',
  'isRead': isRead,
  'accountEmail': 'owner@example.test',
};

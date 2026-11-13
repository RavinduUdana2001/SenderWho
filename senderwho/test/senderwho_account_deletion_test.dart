import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/app_theme.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'package:sender_who/widgets/delete_senderwho_account_dialog.dart';
import 'support/ui_review_repository.dart';

class DeleteApi {
  final data = UiReviewData();
  final store = MemorySessionStore()..refreshToken = 'saved';
  final mutations = <http.Request>[];
  bool fail = false;
  bool acknowledge = true;
  Completer<http.Response>? waiting;
  late final repository = SenderWhoRepository(
    previewMode: false,
    sessionStore: store,
    baseUrl: 'https://api.example.test/api/v1',
    client: MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        return data.json({
          'status': 'AUTHENTICATED',
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'user': {'email': 'owner@example.com'},
        });
      }
      if (request.method == 'DELETE') {
        mutations.add(request);
        return waiting?.future ??
            (fail
                ? data.json({'message': 'Prisma failed /src/users.ts'}, 503)
                : data.json({'success': acknowledge}));
      }
      return data.handle(request);
    }),
  );
}

Future<void> openDelete(
  WidgetTester tester,
  DeleteApi api, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  expect(await api.repository.restoreSession(), isTrue);
  await tester.pumpWidget(
    SenderWhoApp(
      repository: api.repository,
      initiallyAuthenticated: true,
      themePreferenceStore: MemoryThemePreferenceStore(),
    ),
  );
  await tester.pumpAndSettle();
  tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/settings');
  await tester.pumpAndSettle();
  final option = find.byKey(
    const ValueKey('settings-delete-senderwho-account'),
  );
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'confirmation explains SenderWho scope and Cancel makes no mutation',
    (tester) async {
      final api = DeleteApi();
      await openDelete(tester, api, size: const Size(320, 568), scale: 2);
      expect(
        find.text(
          'Your Gmail, Outlook, Yahoo accounts and their emails will not be deleted.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('All linked mailboxes will be disconnected.'),
        findsOneWidget,
      );
      expect(api.mutations, isEmpty);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.mutations, isEmpty);
      expect(api.repository.isAuthenticated, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'confirmed deletion only calls users/me, prevents duplicates, and clears session',
    (tester) async {
      final api = DeleteApi();
      await openDelete(tester, api);
      api.waiting = Completer<http.Response>();
      final confirm = find.byKey(
        const ValueKey('confirm-delete-senderwho-account'),
      );
      await tester.tap(confirm);
      await tester.pump();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(DeleteSenderWhoAccountDialog), findsOneWidget);
      expect(api.mutations.length, 1);
      expect(api.mutations.single.url.path, '/api/v1/users/me');
      api.waiting!.complete(api.data.json({'success': true}));
      await tester.pumpAndSettle();
      expect(api.repository.isAuthenticated, isFalse);
      expect(api.repository.activeMailbox.value, isNull);
      expect(api.repository.connectedAccounts.value, isEmpty);
      expect(api.store.refreshToken, isNull);
      expect(find.text('Connect my inbox'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed deletion stays signed in and can retry without technical errors',
    (tester) async {
      final api = DeleteApi()..fail = true;
      await openDelete(tester, api);
      await tester.tap(
        find.byKey(const ValueKey('confirm-delete-senderwho-account')),
      );
      await tester.pumpAndSettle();
      expect(api.repository.isAuthenticated, isTrue);
      expect(find.textContaining('Prisma'), findsNothing);
      expect(find.textContaining('temporarily unavailable'), findsOneWidget);
      api.fail = false;
      await tester.tap(
        find.byKey(const ValueKey('confirm-delete-senderwho-account')),
      );
      await tester.pumpAndSettle();
      expect(api.mutations.length, 2);
      expect(api.repository.isAuthenticated, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'unacknowledged deletion response cannot clear the signed-in session',
    () async {
      final api = DeleteApi()..acknowledge = false;
      await api.repository.restoreSession();
      expect(await api.repository.deleteAccount(), isFalse);
      expect(api.repository.isAuthenticated, isTrue);
      expect(api.store.refreshToken, isNotNull);
    },
  );

  testWidgets(
    'explicit light preference remains available with dark as default',
    (tester) async {
      await tester.pumpWidget(
        const SenderWhoApp(initialThemeMode: ThemeMode.light),
      );
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.light,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => DeleteSenderWhoAccountDialog(
                    repository: DeleteApi().repository,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AlertDialog))).brightness,
        Brightness.dark,
      );
    },
  );
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/models/app_models.dart';
import 'package:sender_who/screens/onboarding_screen.dart';
import 'package:sender_who/screens/splash_screen.dart';
import 'package:sender_who/screens/emails_screen.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/app_theme.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'support/ui_review_repository.dart';

http.Response session(String email, String token) => http.Response(
  jsonEncode({
    'status': 'AUTHENTICATED',
    'accessToken': 'access-$token',
    'refreshToken': 'refresh-$token',
    'user': {
      'id': email,
      'email': email,
      'displayName': email.split('@').first,
    },
  }),
  200,
);

class DelayedTokenStore extends MemorySessionStore {
  final writing = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> writeRefreshToken(String token) async {
    writing.complete();
    await release.future;
    await super.writeRefreshToken(token);
  }
}

class SyncingInbox extends SenderWhoRepository {
  int loads = 0;
  @override
  bool get isAuthenticated => true;
  @override
  Future<DashboardSummary> getDashboard() async => DashboardSummary.fromJson({
    'sync': {'syncStatus': loads == 0 ? 'SYNCING' : 'READY'},
  });
  @override
  Future<EmailPage?> getEmails({
    int page = 1,
    int limit = 25,
    String mailbox = 'INBOX',
    String? query,
    String? category,
    String? cleanupCategory,
    String? senderId,
    bool? hasAttachments,
  }) async {
    final hasMessages = loads++ > 0;
    return EmailPage.fromJson({
      'items': hasMessages ? [UiReviewData().message(0)] : [],
      'total': hasMessages ? 1 : 0,
      'page': 1,
      'limit': 25,
      'hasMore': false,
    });
  }
}

void main() {
  test(
    'sign-out clears credentials after a pending secure-storage write',
    () async {
      final store = DelayedTokenStore()..refreshToken = 'saved';
      final repository = SenderWhoRepository(
        previewMode: false,
        sessionStore: store,
        baseUrl: 'https://api.example.test/api/v1',
        client: MockClient(
          (request) async => request.url.path.endsWith('/auth/refresh')
              ? session('old@example.com', 'old')
              : http.Response('{}', 200),
        ),
      );
      final restoration = repository.restoreSession();
      await store.writing.future;
      final logout = repository.logout();
      // Let the logout response invalidate identity before releasing storage.
      await Future<void>.delayed(Duration.zero);
      store.release.complete();
      await logout;
      expect(await restoration, isFalse);
      expect(store.refreshToken, isNull);
      expect(repository.isAuthenticated, isFalse);
    },
  );

  testWidgets(
    'slow restoration yields welcome within five seconds and safely resumes later',
    (tester) async {
      final data = UiReviewData();
      final waiting = Completer<http.Response>();
      final store = MemorySessionStore()..refreshToken = 'saved-refresh';
      final repository = SenderWhoRepository(
        previewMode: false,
        sessionStore: store,
        baseUrl: 'https://api.example.test/api/v1',
        client: MockClient((request) {
          if (request.url.path.endsWith('/auth/refresh')) return waiting.future;
          return data.handle(request);
        }),
      );
      final startup = repository.restoreSession().then(
        (authenticated) => AppLaunchState(
          authenticated: authenticated,
          themeMode: ThemeMode.light,
        ),
      );
      await tester.pumpWidget(
        SenderWhoApp(
          repository: repository,
          startup: startup,
          themePreferenceStore: MemoryThemePreferenceStore(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(store.refreshToken, 'saved-refresh');
      waiting.complete(session('saved@example.com', 'rotated'));
      await tester.pumpAndSettle();
      expect(store.refreshToken, 'refresh-rotated');
      expect(find.text('All Senders'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancelled old OAuth and old 401 cannot replace a newly signed-in account',
    (tester) async {
      final staleExchange = Completer<http.Response>();
      final staleData = Completer<http.Response>();
      final store = MemorySessionStore()..refreshToken = 'saved';
      var exchangeCalls = 0;
      final repository = SenderWhoRepository(
        previewMode: false,
        sessionStore: store,
        launchExternal: (_) async => true,
        oauthPollInterval: Duration.zero,
        baseUrl: 'https://api.example.test/api/v1',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            return session('old@example.com', 'old');
          }
          if (request.url.path.endsWith('/auth/oauth/google/start')) {
            return http.Response(
              jsonEncode({
                'authorizationUrl': 'https://accounts.google.com/authorize',
                'loginSessionId': 'login',
                'loginSessionSecret': 'secret',
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/auth/oauth/session/exchange')) {
            return exchangeCalls++ == 0
                ? staleExchange.future
                : session('new@example.com', 'new');
          }
          if (request.url.path.endsWith('/emails')) return staleData.future;
          return http.Response('{}', 200);
        }),
      );
      expect(await repository.restoreSession(), isTrue);
      repository.connectedAccounts.value = [
        ConnectedEmailAccount.fromJson({
          'id': 'old-mailbox',
          'emailAddress': 'old@example.com',
          'isActive': true,
          'syncStatus': 'READY',
        }),
      ];
      repository.activeMailbox.value = repository.connectedAccounts.value.first;
      final oldData = repository.getEmails();
      final oldLogin = repository.startOAuthWithAccountChooser('google');
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(exchangeCalls, 1);
      repository.cancelOAuth();
      final newLogin = repository.startOAuthWithAccountChooser('google');
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(exchangeCalls, 2);
      expect(await newLogin, isTrue);
      expect(repository.userEmail, 'new@example.com');
      expect(repository.connectedAccounts.value, isEmpty);
      expect(repository.activeMailbox.value, isNull);
      staleExchange.complete(session('stale@example.com', 'stale'));
      staleData.complete(http.Response('Unauthorized', 401));
      expect(await oldLogin, isFalse);
      expect(await oldData, isNull);
      expect(repository.userEmail, 'new@example.com');
      expect(store.refreshToken, 'refresh-new');
      expect(repository.isAuthenticated, isTrue);
    },
  );

  testWidgets('Inbox refreshes itself as a new mailbox finishes scanning', (
    tester,
  ) async {
    final repository = SyncingInbox();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: EmailsScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your inbox is syncing'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Your project update is ready'), findsOneWidget);
    expect(find.text('Your inbox is syncing'), findsNothing);
    expect(repository.loads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/models/app_models.dart';
import 'package:sender_who/screens/all_senders_screen.dart';
import 'package:sender_who/screens/email_details_screen.dart';
import 'package:sender_who/screens/settings_screen.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/app_theme.dart';
import 'package:sender_who/theme/theme_mode_controller.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'package:sender_who/widgets/mail_avatar.dart';
import 'package:sender_who/widgets/mail_list_surface.dart';

http.Response response(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Map<String, Object?> account(String id, bool active) => {
  'id': id,
  'provider': 'GOOGLE',
  'emailAddress': '$id@example.com',
  'displayName': id == 'a' ? 'Personal' : 'Work',
  'syncStatus': 'READY',
  'isActive': active,
};

class ExperienceApi {
  String active = 'a';
  bool isRead = false;
  int senderReads = 0;
  int switchCalls = 0;
  final emailQueries = <Map<String, String>>[];
  final String? photo;
  final String profileEmail;
  ExperienceApi({this.photo, this.profileEmail = 'owner@example.com'});

  Map<String, Object?> message(int index, [String? mailbox]) {
    final current = mailbox ?? active;
    return {
      'id': 'message-$current-$index',
      'senderId': 'sender-$current',
      'sender': current == 'a' ? 'Personal sender' : 'Work sender',
      'email': '$current@example.com',
      'subject': 'Message ${index + 1}',
      'snippet': 'A preview of your latest update.',
      'date': 'Today',
      'isRead': index == 0 ? isRead : true,
      'accountEmail': '$current@example.com',
    };
  }

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path.replaceFirst('/api/v1/', '');
    if (path == 'auth/refresh') {
      return response({
        'status': 'AUTHENTICATED',
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'user': {'id': 'user-1', 'email': profileEmail},
      });
    }
    if (path == 'auth/me') {
      return response({
        'id': 'user-1',
        'email': profileEmail,
        'displayName': 'Ravindu Test',
        'avatarUrl': photo,
      });
    }
    if (path == 'auth/providers') {
      return response({
        'providers': {
          'google': {'enabled': true},
        },
      });
    }
    if (path == 'email-accounts') {
      return response({
        'items': [account('a', active == 'a'), account('b', active == 'b')],
      });
    }
    if (path.endsWith('/activate')) {
      active = path.split('/')[1];
      switchCalls++;
      return response({'id': active, 'isActive': true});
    }
    if (path == 'settings') {
      return response({
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
      });
    }
    if (path == 'dashboard') {
      return response({
        'sync': {'syncStatus': 'READY'},
      });
    }
    if (path == 'senders') {
      senderReads++;
      return response({
        'items': [
          {
            'id': 'sender-$active',
            'name': active == 'a' ? 'Personal sender' : 'Work sender',
            'email': '$active@example.com',
            'category': 'People',
            'score': 90,
            'totalMessages': 3,
            'unreadMessages': 1,
          },
        ],
        'page': 1,
        'limit': 25,
        'total': 1,
      });
    }
    if (path == 'emails') {
      emailQueries.add(request.url.queryParameters);
      return response({
        'items': List.generate(3, (i) => message(i)),
        'total': 3,
        'page': 1,
        'limit': 25,
        'hasMore': false,
      });
    }
    if (path.endsWith('/thread')) {
      final parts = path.split('/')[1].split('-');
      return response({
        'threadId': 'thread-1',
        'total': 1,
        'items': [message(int.parse(parts.last), parts[1])],
      });
    }
    if (path.endsWith('/content')) {
      return response({
        'id': path.split('/')[1],
        'from': '$active@example.com',
        'to': 'owner@example.com',
        'date': 'Today',
        'attachments': [],
        'bodyText': List.filled(
          40,
          'A readable message with clear spacing and useful details.',
        ).join('\n\n'),
      });
    }
    if (path == 'emails/actions/read-state') {
      isRead = (jsonDecode(request.body) as Map)['isRead'] == true;
      return response({
        'action': 'read-state',
        'processed': 1,
        'failed': 0,
        'processedIds': ['message-a-0'],
      });
    }
    if (path == 'unsubscribe/candidates' || path == 'unsubscribe/jobs') {
      return response({'items': []});
    }
    return response({'message': 'Not found'}, 404);
  }

  Future<SenderWhoRepository> repository({bool authenticated = true}) async {
    final store = MemorySessionStore()
      ..refreshToken = authenticated ? 'refresh' : null;
    final repository = SenderWhoRepository(
      previewMode: false,
      client: MockClient(handle),
      sessionStore: store,
      baseUrl: 'https://api.example.test/api/v1',
    );
    if (authenticated) expect(await repository.restoreSession(), isTrue);
    return repository;
  }
}

Future<void> phone(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

Finder destination(String name) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(name));

void main() {
  test('profile fetch is shared, cached, and cleared on logout', () async {
    final gate = Completer<http.Response>();
    var requests = 0;
    final repository = SenderWhoRepository(
      previewMode: false,
      sessionStore: MemorySessionStore(),
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/me')) {
          requests++;
          return gate.future;
        }
        return response({'success': true});
      }),
    );
    final first = repository.getUserProfile();
    final second = repository.getUserProfile();
    gate.complete(
      response({
        'email': 'owner@example.com',
        'displayName': 'Ravindu Test',
        'avatarUrl': 'https://images.example.com/profile.png',
      }),
    );
    expect((await first)?.name, 'Ravindu Test');
    expect((await second)?.avatarUrl, 'https://images.example.com/profile.png');
    expect((await repository.getUserProfile())?.email, 'owner@example.com');
    expect(requests, 1);
    await repository.logout();
    expect(repository.userProfile.value, isNull);
  });

  test(
    'an old profile response cannot restore identity after logout',
    () async {
      final gate = Completer<http.Response>();
      final repository = SenderWhoRepository(
        previewMode: false,
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
        client: MockClient((_) => gate.future),
      );
      final pending = repository.getUserProfile();
      await repository.logout();
      gate.complete(
        response({'email': 'old@example.com', 'displayName': 'Old profile'}),
      );
      expect(await pending, isNull);
      expect(repository.userProfile.value, isNull);
    },
  );

  test(
    'mailbox switching prevents duplicates and keeps the previous mailbox on failure',
    () async {
      final gate = Completer<http.Response>();
      var switches = 0;
      final repository = SenderWhoRepository(
        previewMode: false,
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/email-accounts')) {
            return response({
              'items': [account('a', true), account('b', false)],
            });
          }
          switches++;
          if (switches == 1) return gate.future;
          return response({'message': 'Switch failed'}, 503);
        }),
      );
      await repository.getConnectedAccounts();
      final first = repository.activateEmailAccount('b');
      final duplicate = repository.activateEmailAccount('b');
      expect(await repository.activateEmailAccount('a'), isFalse);
      gate.complete(response({'id': 'b', 'isActive': true}));
      expect(await first, isTrue);
      expect(await duplicate, isTrue);
      expect(switches, 1);
      expect(repository.activeMailbox.value?.id, 'b');
      expect(repository.mailboxRevision.value, 1);
      expect(await repository.activateEmailAccount('a'), isFalse);
      expect(repository.activeMailbox.value?.id, 'b');
      expect(repository.mailboxRevision.value, 1);
      expect(repository.switchingMailbox.value, isNull);
    },
  );

  test(
    'an older account-list response cannot undo a successful mailbox switch',
    () async {
      final stale = Completer<http.Response>();
      var loads = 0;
      final repository = SenderWhoRepository(
        previewMode: false,
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/activate')) {
            return response({'id': 'b', 'isActive': true});
          }
          loads++;
          if (loads == 2) return stale.future;
          return response({
            'items': [account('a', true), account('b', false)],
          });
        }),
      );
      await repository.getConnectedAccounts();
      final pending = repository.getConnectedAccounts();
      await repository.activateEmailAccount('b');
      stale.complete(
        response({
          'items': [account('a', true), account('b', false)],
        }),
      );
      await pending;
      expect(repository.activeMailbox.value?.id, 'b');
    },
  );

  testWidgets(
    'System Back restores sender filters while main tabs have no Back icon',
    (tester) async {
      await phone(tester);
      final api = ExperienceApi();
      final repository = await api.repository();
      await tester.pumpWidget(
        SenderWhoApp(
          repository: repository,
          initiallyAuthenticated: true,
          themePreferenceStore: MemoryThemePreferenceStore(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('People'));
      await tester.pumpAndSettle();
      final loads = api.senderReads;
      await tester.tap(destination('Inbox'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back'), findsNothing);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(api.senderReads, loads);
      final people = tester
          .widgetList<MailFilterTab>(find.byType(MailFilterTab))
          .singleWhere((tab) => tab.label == 'People');
      expect(people.selected, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile photos reach the header and switching mailboxes refreshes the visible inbox',
    (tester) async {
      await phone(tester);
      final api = ExperienceApi(
        photo: 'https://images.example.com/profile.png',
        profileEmail: 'a@example.com',
      );
      final repository = await api.repository();
      await tester.pumpWidget(
        SenderWhoApp(
          repository: repository,
          initiallyAuthenticated: true,
          themePreferenceStore: MemoryThemePreferenceStore(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<MailAvatar>(find.byType(MailAvatar))
            .any((avatar) => avatar.imageUrl == api.photo),
        isTrue,
      );
      await tester.tap(destination('Inbox'));
      await tester.pumpAndSettle();
      expect(find.text('Personal sender'), findsWidgets);
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('drawer-mailbox-b')));
      await tester.pumpAndSettle();
      expect(api.switchCalls, 1);
      expect(repository.activeMailbox.value?.id, 'b');
      final activeAvatar = tester.widget<MailAvatar>(
        find.byKey(const ValueKey('header-avatar-b@example.com')),
      );
      expect(activeAvatar.name, 'Work');
      expect(activeAvatar.imageUrl, isNull);
      expect(find.text('Work sender'), findsWidgets);
      expect(find.text('Personal sender'), findsNothing);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'theme updates immediately and rolls back even after leaving the initiating page',
    (tester) async {
      await phone(tester);
      final repository = await ExperienceApi().repository();
      final store = MemoryThemePreferenceStore();
      await tester.pumpWidget(
        SenderWhoApp(
          repository: repository,
          initiallyAuthenticated: true,
          themePreferenceStore: store,
        ),
      );
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed(SettingsScreen.routeName);
      await tester.pumpAndSettle();
      final gate = Completer<bool>();
      final controller = ThemeModeController.of(
        tester.element(find.byType(SettingsScreen)),
      );
      final save = controller.changeThemeMode(
        ThemeMode.dark,
        save: () => gate.future,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      gate.complete(false);
      expect(await save, isFalse);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AllSendersScreen))).brightness,
        Brightness.light,
      );
      expect(store.mode, ThemeMode.light);
    },
  );

  testWidgets('a late failed theme save cannot replace a newer theme choice', (
    tester,
  ) async {
    await phone(tester);
    final repository = await ExperienceApi().repository();
    await tester.pumpWidget(
      SenderWhoApp(
        repository: repository,
        initiallyAuthenticated: true,
        themePreferenceStore: MemoryThemePreferenceStore(),
      ),
    );
    await tester.pumpAndSettle();
    final first = Completer<bool>();
    final initialController = ThemeModeController.of(
      tester.element(find.byType(AllSendersScreen)),
    );
    final oldSave = initialController.changeThemeMode(
      ThemeMode.dark,
      save: () => first.future,
    );
    await tester.pumpAndSettle();
    final nextController = ThemeModeController.of(
      tester.element(find.byType(AllSendersScreen)),
    );
    expect(
      await nextController.changeThemeMode(
        ThemeMode.system,
        save: () async => true,
      ),
      isTrue,
    );
    await tester.pumpAndSettle();
    first.complete(false);
    expect(await oldSave, isFalse);
    await tester.pumpAndSettle();
    expect(
      ThemeModeController.of(
        tester.element(find.byType(AllSendersScreen)),
      ).mode,
      ThemeMode.system,
    );
  });

  testWidgets(
    'opening an older mail keeps its own subject and body when it is outside the thread page',
    (tester) async {
      await phone(tester);
      final api = ExperienceApi();
      final repository = SenderWhoRepository(
        previewMode: false,
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/thread')) {
            return response({
              'items': [
                {...api.message(1), 'isRead': true},
              ],
            });
          }
          if (request.url.path.endsWith('/message-a-0')) {
            return response({
              ...api.message(0),
              'subject': 'Requested older message',
              'isRead': true,
            });
          }
          if (request.url.path.endsWith('/content')) {
            return response({
              'id': 'message-a-0',
              'bodyText': 'The requested message body',
              'attachments': [],
            });
          }
          return api.handle(request);
        }),
      );
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          theme: AppTheme.light(),
          home: const Scaffold(body: Text('Inbox host')),
          routes: {
            EmailDetailsScreen.routeName: (_) =>
                EmailDetailsScreen(repository: repository),
          },
        ),
      );
      key.currentState!.pushNamed(
        EmailDetailsScreen.routeName,
        arguments: 'message-a-0',
      );
      await tester.pumpAndSettle();
      expect(find.text('Requested older message'), findsOneWidget);
      expect(find.text('The requested message body'), findsOneWidget);
      expect(find.text('Message 2'), findsNothing);
    },
  );

  testWidgets(
    'message toolbar stays visible while reading and iOS Back works after a read update',
    (tester) async {
      await phone(tester);
      final api = ExperienceApi();
      final repository = await api.repository(authenticated: false);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          theme: AppTheme.light().copyWith(platform: TargetPlatform.iOS),
          home: const Scaffold(body: Text('Inbox host')),
          routes: {
            EmailDetailsScreen.routeName: (_) =>
                EmailDetailsScreen(repository: repository),
          },
        ),
      );
      key.currentState!.pushNamed(
        EmailDetailsScreen.routeName,
        arguments: EmailItem.fromJson(api.message(0)),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(api.isRead, isTrue);
      final before = tester.getRect(find.text('Archive'));
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Archive')).top, closeTo(before.top, 1));
      await tester.dragFrom(const Offset(1, 420), const Offset(330, 0));
      await tester.pumpAndSettle();
      expect(find.text('Inbox host'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

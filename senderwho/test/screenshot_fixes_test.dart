import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/screens/connect_email_screen.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/app_theme.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'package:sender_who/widgets/mail_list_surface.dart';
import 'package:sender_who/widgets/mail_avatar.dart';
import 'support/ui_review_repository.dart';

class MailboxApi {
  final data = UiReviewData();
  final senderRequests = <Map<String, String>>[];
  final emailRequests = <Map<String, String>>[];
  String current = 'personal';
  Map<String, Object?> account(String id, {bool failed = false}) => {
    'id': id,
    'provider': 'GOOGLE',
    'emailAddress': '$id@example.com',
    'isActive': current == id,
    'syncStatus': failed ? 'FAILED' : 'READY',
    if (failed) 'lastSyncError': 'Gmail batch item failed with status 403.',
  };
  Future<SenderWhoRepository> repository() async {
    final repo = SenderWhoRepository(
      previewMode: false,
      baseUrl: 'https://api.example.test/api/v1',
      sessionStore: MemorySessionStore()..refreshToken = 'saved',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/refresh')) {
          return data.json({
            'status': 'AUTHENTICATED',
            'accessToken': 'access',
            'refreshToken': 'refresh',
            'user': {'email': 'owner@example.com', 'displayName': 'Owner'},
          });
        }
        if (path.endsWith('/email-accounts')) {
          return data.json({
            'items': [account('personal'), account('work')],
          });
        }
        if (path.endsWith('/activate')) {
          current = path.contains('/work/') ? 'work' : 'personal';
          return data.json({'id': current, 'isActive': true});
        }
        if (path.endsWith('/senders')) {
          final q = Map.of(request.url.queryParameters);
          senderRequests.add(q);
          final selected = q['emailAccountId'] ?? current;
          const categories = ['PEOPLE', 'NEWSLETTERS', 'FINANCE'];
          final items =
              [
                for (var i = 0; i < 3; i++)
                  {
                    ...data.sender(i),
                    'id': '$selected-$i',
                    'name': '$selected ${categories[i]}',
                    'email': '$selected-$i@example.com',
                    'category': categories[i],
                  },
              ].where((s) {
                final kind = q['kind'];
                final category = s['category'];
                if (q['category'] != null && q['category'] != category) {
                  return false;
                }
                if (kind == 'PEOPLE' || kind == 'NEWSLETTERS') {
                  return category == kind;
                }
                if (kind == 'COMPANIES' && category != 'FINANCE') return false;
                final text = '${s['name']} ${s['email']}'.toLowerCase();
                return text.contains((q['query'] ?? '').toLowerCase());
              }).toList();
          return data.json({
            'items': items,
            'total': items.length,
            'page': 1,
            'limit': 25,
          });
        }
        if (path.endsWith('/emails')) {
          final q = Map.of(request.url.queryParameters);
          emailRequests.add(q);
          final selected = q['emailAccountId'] ?? current;
          return data.json({
            'items': [
              {
                ...data.message(0),
                'id': '$selected-message',
                'subject': '$selected mailbox message',
              },
            ],
            'total': 1,
            'page': 1,
            'limit': 25,
            'hasMore': false,
          });
        }
        return data.handle(request);
      }),
    );
    await repo.restoreSession();
    await repo.getConnectedAccounts();
    return repo;
  }
}

void phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> open(WidgetTester tester, SenderWhoRepository repository) async {
  await tester.pumpWidget(
    SenderWhoApp(
      repository: repository,
      initiallyAuthenticated: true,
      themePreferenceStore: MemoryThemePreferenceStore(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder nav(String label) => find.descendant(
  of: find.byType(NavigationDestination),
  matching: find.text(label),
);
Future<void> switchMailbox(WidgetTester tester, String id) async {
  await tester.tap(find.byTooltip('Open menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('drawer-mailbox-$id')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sign-in logo and copy are centered with a larger brand mark', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: ConnectEmailScreen(
          loadRememberedEmail: () async => null,
          loadRememberedProvider: () async => null,
          availableProviders: () async => {'google': true},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final logo = find.byKey(const ValueKey('connect-brand-icon'));
    expect(tester.getSize(logo), const Size(96, 96));
    expect(tester.getCenter(logo).dx, closeTo(195, .5));
    expect(
      tester.getCenter(find.text('Connect your inbox')).dx,
      closeTo(195, .5),
    );
    expect(
      tester.widget<Text>(find.text('Connect your inbox')).textAlign,
      TextAlign.center,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'primary tabs and sidebar sections hide Back and keep the profile fixed',
    (tester) async {
      phone(tester);
      await open(tester, await MailboxApi().repository());
      final profile = find.byKey(const ValueKey('profile-account-button'));
      final position = tester.getTopLeft(profile);
      for (final label in ['Inbox', 'Unsubscribe', 'Clean', 'Senders']) {
        await tester.tap(nav(label));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Back'), findsNothing);
        expect(find.byKey(const ValueKey('app-header-subtitle')), findsNothing);
        expect(tester.getTopLeft(profile), position);
      }
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Email Inbox'));
      await tester.tap(find.text('Email Inbox'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('All Senders'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'sender sheet and quick tabs use identical categories and preserve search in the selected mailbox',
    (tester) async {
      phone(tester);
      final api = MailboxApi();
      await open(tester, await api.repository());
      final newsletters = find.widgetWithText(MailFilterTab, 'Newsletters');
      await tester.ensureVisible(newsletters);
      await tester.tap(newsletters);
      await tester.pumpAndSettle();
      final tabQuery = Map.of(api.senderRequests.last);
      expect(tabQuery['category'], 'NEWSLETTERS');
      expect(find.text('personal NEWSLETTERS'), findsOneWidget);
      await tester.tap(find.byTooltip('Filter senders'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('sender-category-NEWSLETTERS')),
      );
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(api.senderRequests.last, tabQuery);
      expect(find.text('personal PEOPLE'), findsNothing);
      await tester.tap(find.widgetWithText(MailFilterTab, 'Companies'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter senders'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sender-category-PEOPLE')));
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(api.senderRequests.last['kind'], 'PEOPLE');
      expect(find.text('personal PEOPLE'), findsOneWidget);
      expect(find.text('personal FINANCE'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'switching between two mailboxes scopes Inbox and Senders and removes previous rows',
    (tester) async {
      phone(tester);
      final api = MailboxApi();
      final repository = await api.repository();
      await open(tester, repository);
      for (final id in ['work', 'personal', 'work']) {
        await switchMailbox(tester, id);
        expect(repository.activeMailbox.value?.id, id);
        final avatar = tester.widget<MailAvatar>(
          find.byKey(ValueKey('header-avatar-$id@example.com')),
        );
        expect(avatar.name, id);
        expect(avatar.imageUrl, isNull);
        await tester.tap(find.byTooltip('Open menu'));
        await tester.pumpAndSettle();
        final identity = find.byKey(const ValueKey('drawer-profile-button'));
        expect(
          find.descendant(of: identity, matching: find.text('$id@example.com')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: identity, matching: find.text(id)),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Close menu'));
        await tester.pumpAndSettle();
        expect(api.senderRequests.last['emailAccountId'], id);
        expect(find.text('$id PEOPLE'), findsOneWidget);
        final previous = id == 'work' ? 'personal' : 'work';
        expect(find.text('$previous PEOPLE'), findsNothing);
        await tester.tap(nav('Inbox'));
        await tester.pumpAndSettle();
        expect(api.emailRequests.last['emailAccountId'], id);
        expect(find.text('$id mailbox message'), findsOneWidget);
        expect(find.text('$previous mailbox message'), findsNothing);
        expect(find.byTooltip('Back'), findsNothing);
        await tester.tap(nav('Senders'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'legacy Gmail 403 offers reconnect and never displays technical batch diagnostics',
    (tester) async {
      phone(tester);
      final data = UiReviewData();
      final repository = SenderWhoRepository(
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
                  'syncStatus': 'FAILED',
                  'isActive': true,
                  'lastSyncError': 'Gmail batch item failed with status 403.',
                  'recoveryAction': 'RETRY',
                },
              ],
            });
          }
          return data.handle(request);
        }),
      );
      await open(tester, repository);
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/connected-accounts');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reconnect'));
      expect(find.text('Reconnect'), findsOneWidget);
      expect(find.textContaining('batch item failed'), findsNothing);
      expect(find.textContaining('review permissions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/models/app_models.dart';
import 'package:sender_who/screens/emails_screen.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'package:sender_who/utils/app_navigation.dart';
import 'package:sender_who/utils/mailbox_identity.dart';
import 'package:sender_who/widgets/app_header.dart';
import 'package:sender_who/widgets/mail_avatar.dart';

import 'support/ui_review_repository.dart';

class IdentityApi {
  final data = UiReviewData();
  String selected = 'owner';
  bool failActivation = false;
  Completer<http.Response>? activation;
  Completer<http.Response>? discovery;
  final queries = <Map<String, String>>[];
  Map<String, Object?> account(String id) => {
    'id': id,
    'emailAddress': '$id@example.com',
    'displayName': id == 'owner' ? 'Original Owner' : 'Work Person',
    'provider': 'GOOGLE',
    'syncStatus': 'READY',
    'isActive': id == selected,
  };
  late final repository = SenderWhoRepository(
    previewMode: false,
    baseUrl: 'https://api.example.test/api/v1',
    sessionStore: MemorySessionStore()..refreshToken = 'saved',
    client: MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/refresh')) {
        return data.json({
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'user': {
            'email': 'owner@example.com',
            'displayName': 'Original Owner',
          },
        });
      }
      if (path.endsWith('/auth/me')) {
        // This endpoint describes the SenderWho owner, not the active mailbox.
        return data.json({
          'email': 'owner@example.com',
          'displayName': 'Original Owner',
        });
      }
      if (path.endsWith('/email-accounts')) {
        return discovery?.future ??
            data.json({
              'items': [account('owner'), account('work')],
            });
      }
      if (path.endsWith('/activate')) {
        if (failActivation) {
          return data.json({
            'message': 'Prisma failure in /src/accounts.ts',
          }, 503);
        }
        selected = path.contains('/work/') ? 'work' : 'owner';
        return activation?.future ?? data.json(account(selected));
      }
      if (path.endsWith('/senders') || path.endsWith('/emails')) {
        queries.add(Map.of(request.url.queryParameters));
      }
      return data.handle(request);
    }),
  );
}

Future<void> start(WidgetTester tester, IdentityApi api) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await api.repository.restoreSession();
  await api.repository.getConnectedAccounts();
  await tester.pumpWidget(
    SenderWhoApp(
      repository: api.repository,
      initiallyAuthenticated: true,
      themePreferenceStore: MemoryThemePreferenceStore(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'selected mailbox photo survives activation copies without owner photo leakage',
    () {
      final selected = ConnectedEmailAccount.fromJson({
        'id': 'work',
        'emailAddress': 'work@example.com',
        'displayName': 'Work Person',
        'avatarUrl': 'https://example.com/work.png',
      }).copyWith(isActive: true);
      final identity = MailboxIdentity.resolve(
        mailbox: selected,
        profile: const UserProfile(
          email: 'owner@example.com',
          displayName: 'Original Owner',
          avatarUrl: 'https://example.com/owner.png',
        ),
      );
      expect(identity.name, 'Work Person');
      expect(identity.avatarUrl, 'https://example.com/work.png');
      expect(
        ConnectedEmailAccount.fromJson({
          'avatarUrl': 'http://example.com/unsafe.png',
        }).avatarUrl,
        isNull,
      );
    },
  );

  testWidgets(
    'profile and drawer follow repeated mailbox switches after owner refresh',
    (tester) async {
      final api = IdentityApi();
      await start(tester, api);
      final position = tester.getTopLeft(
        find.byKey(const ValueKey('profile-account-button')),
      );
      for (final id in ['work', 'owner', 'work']) {
        await tester.tap(find.byTooltip('Open menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('drawer-mailbox-$id')));
        await tester.pumpAndSettle();
        expect(api.repository.activeMailbox.value?.id, id);
        expect(api.queries.last['emailAccountId'], id);
        expect(find.byTooltip('Back'), findsNothing);
        final name = id == 'owner' ? 'Original Owner' : 'Work Person';
        expect(
          tester
              .widget<MailAvatar>(
                find.byKey(ValueKey('header-avatar-$id@example.com')),
              )
              .name,
          name,
        );
        expect(
          tester.getTopLeft(
            find.byKey(const ValueKey('profile-account-button')),
          ),
          position,
        );
        await tester.tap(find.byTooltip('Open menu'));
        await tester.pumpAndSettle();
        final profile = find.byKey(const ValueKey('drawer-profile-button'));
        expect(
          find.descendant(of: profile, matching: find.text('$id@example.com')),
          findsOneWidget,
        );
        await tester.tap(profile);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Refresh profile'));
        await tester.pumpAndSettle();
        expect(api.repository.userProfile.value?.email, 'owner@example.com');
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('profile-mailbox-email')))
              .data,
          '$id@example.com',
        );
        expect(
          tester
              .widget<MailAvatar>(
                find.byKey(ValueKey('profile-avatar-$id@example.com')),
              )
              .name,
          name,
        );
        expect(find.byTooltip('Back'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed switch preserves current identity with a short safe message',
    (tester) async {
      final api = IdentityApi()..failActivation = true;
      await start(tester, api);
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('drawer-mailbox-work')));
      await tester.pumpAndSettle();
      expect(api.repository.activeMailbox.value?.id, 'owner');
      final snackbar = tester.widget<SnackBar>(find.byType(SnackBar));
      final message = (snackbar.content as Text).data!;
      expect(message.length, lessThanOrEqualTo(120));
      expect(message, isNot(contains('Prisma')));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'activation retains identity if an account refresh cleared its row',
    () async {
      final api = IdentityApi();
      await api.repository.restoreSession();
      await api.repository.getConnectedAccounts();
      api.activation = Completer<http.Response>();
      final switching = api.repository.activateEmailAccount('work');
      await Future<void>.delayed(Duration.zero);
      api.repository.connectedAccounts.value = const [];
      api.activation!.complete(api.data.json({'id': 'work', 'isActive': true}));
      expect(await switching, isTrue);
      expect(
        api.repository.activeMailbox.value?.emailAddress,
        'work@example.com',
      );
      expect(api.repository.activeMailbox.value?.displayName, 'Work Person');
    },
  );

  test('late discovery cannot restore old mailbox after activation', () async {
    final api = IdentityApi();
    await api.repository.restoreSession();
    await api.repository.getConnectedAccounts();
    final oldItems = [api.account('owner'), api.account('work')];
    api.discovery = Completer<http.Response>();
    final refreshing = api.repository.getConnectedAccounts();
    expect(await api.repository.activateEmailAccount('work'), isTrue);
    api.discovery!.complete(api.data.json({'items': oldItems}));
    await refreshing;
    expect(api.repository.activeMailbox.value?.id, 'work');
  });

  test(
    'a mismatched activation response cannot change the visible identity',
    () async {
      final api = IdentityApi();
      await api.repository.restoreSession();
      await api.repository.getConnectedAccounts();
      api.activation = Completer<http.Response>();
      final switching = api.repository.activateEmailAccount('work');
      api.activation!.complete(
        api.data.json({'id': 'another-mailbox', 'isActive': true}),
      );
      expect(await switching, isFalse);
      expect(api.repository.activeMailbox.value?.id, 'owner');
      expect(api.repository.mailboxRevision.value, 0);
      expect(
        api.repository.lastError,
        'Couldn’t switch mailboxes. Refresh your accounts.',
      );
    },
  );

  testWidgets(
    'Back fades in at a fixed position and filtered lists use stationary transitions',
    (tester) async {
      final api = IdentityApi();
      await start(tester, api);
      final position = tester.getTopLeft(
        find.byKey(const ValueKey('profile-account-button')),
      );
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pushNamed('/search-filter');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final back = find.byTooltip('Back');
      final fade = tester
          .widgetList<FadeTransition>(
            find.ancestor(of: back, matching: find.byType(FadeTransition)),
          )
          .first;
      expect(fade.opacity.value, greaterThan(0));
      expect(fade.opacity.value, lessThan(1));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('profile-account-button'))),
        position,
      );
      nav.pop();
      await tester.pumpAndSettle();
      nav.pushNamed(
        '/emails',
        arguments: const EmailListArguments(
          mailbox: 'UNREAD',
          title: 'Unread Emails',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        ModalRoute.of(tester.element(find.byType(AppHeader))),
        isA<PageRouteBuilder<void>>(),
      );
      expect(find.byTooltip('Back'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('reduced motion applies to utility and native detail routes', () {
    for (final name in ['/profile', '/email-details']) {
      final route = AppNavigation.route(
        settings: RouteSettings(name: name),
        builder: (_) => const SizedBox(),
        disableAnimations: true,
      );
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
    }
  });
}

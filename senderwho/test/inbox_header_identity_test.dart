import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/models/app_models.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'package:sender_who/theme/theme_mode_controller.dart';
import 'package:sender_who/utils/mailbox_identity.dart';
import 'package:sender_who/widgets/app_header.dart';

import 'support/ui_review_repository.dart';

void main() {
  const profile = UserProfile(
    email: 'owner@example.com',
    displayName: 'Original Owner',
    avatarUrl: 'https://example.com/owner.png',
  );
  ConnectedEmailAccount mailbox(String email, String name) =>
      ConnectedEmailAccount(
        id: 'selected',
        provider: 'GOOGLE',
        emailAddress: email,
        displayName: name,
        syncStatus: 'READY',
      );

  test(
    'another mailbox uses its own identity without borrowing owner photo',
    () {
      final selected = MailboxIdentity.resolve(
        mailbox: mailbox('secondary@example.com', 'Secondary Person'),
        profile: profile,
      );
      expect(selected.name, 'Secondary Person');
      expect(selected.email, 'secondary@example.com');
      expect(selected.avatarUrl, isNull);
      final generic = MailboxIdentity.resolve(
        mailbox: mailbox('secondary@example.com', 'GOOGLE'),
        profile: profile,
      );
      expect(generic.name, 'secondary');
      final original = MailboxIdentity.resolve(
        mailbox: mailbox('OWNER@example.com', 'GOOGLE'),
        profile: profile,
      );
      expect(original.name, 'Original Owner');
      expect(original.avatarUrl, profile.avatarUrl);
    },
  );

  for (final dark in [false, true]) {
    for (final layout in [(320.0, 2.0), (390.0, 1.0), (600.0, 1.0)]) {
      testWidgets('Inbox actions share centered header $layout dark=$dark', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(layout.$1, 844);
        tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
        addTearDown(() {
          tester.view.resetDevicePixelRatio();
          tester.view.resetPhysicalSize();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await tester.pumpWidget(
          SenderWhoApp(
            repository: UiReviewData().repository(),
            initiallyAuthenticated: true,
            initialThemeMode: dark ? ThemeMode.dark : ThemeMode.light,
            themePreferenceStore: MemoryThemePreferenceStore(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationDestination),
            matching: find.text('Inbox'),
          ),
        );
        await tester.pumpAndSettle();
        final profileButton = find.byKey(
          const ValueKey('profile-account-button'),
        );
        ThemeModeController.of(
          tester.element(profileButton),
        ).setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(profileButton)).brightness,
          dark ? Brightness.dark : Brightness.light,
        );
        final search = find.byTooltip('Search messages');
        final select = find.byTooltip('Select');
        final title = find.byKey(const ValueKey('app-header-title'));
        expect(tester.getCenter(search).dy, tester.getCenter(profileButton).dy);
        expect(tester.getCenter(select).dy, tester.getCenter(profileButton).dy);
        expect(tester.getCenter(title).dx, closeTo(layout.$1 / 2, 1));
        expect(
          tester.getRect(title).right,
          lessThanOrEqualTo(tester.getRect(search).left),
        );
        expect(
          tester.getRect(profileButton).right,
          lessThanOrEqualTo(tester.getRect(title).left),
        );
        final header = tester.getSize(find.byType(AppHeader));
        expect(header.height, lessThan(80));
        await tester.tap(search);
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        await tester.tap(find.byTooltip('Close message search'));
        await tester.pumpAndSettle();
        await tester.tap(select);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Cancel selection'), findsOneWidget);
        await tester.tap(find.byTooltip('Cancel selection'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Select'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

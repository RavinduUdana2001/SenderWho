import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/screens/emails_screen.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'package:sender_who/widgets/app_header.dart';
import 'support/ui_review_repository.dart';

Finder tab(String label) => find.descendant(
  of: find.byType(NavigationDestination),
  matching: find.text(label),
);
Future<void> open(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    SenderWhoApp(
      repository: UiReviewData().repository(),
      initiallyAuthenticated: true,
      themePreferenceStore: MemoryThemePreferenceStore(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> drawer(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip('Open menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'main menus share one header; nested screens have one real Back on $platform',
      (tester) async {
        await open(tester);
        final profile = find.byKey(const ValueKey('profile-account-button'));
        final position = tester.getTopLeft(profile);
        await drawer(tester, 'Email Inbox');
        expect(find.byTooltip('Back'), findsNothing);
        expect(tester.getTopLeft(profile), position);
        await drawer(tester, 'Settings');
        expect(find.byTooltip('Back'), findsNothing);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          1,
        );
        await tester.tap(
          find.byKey(const ValueKey('settings-privacy-security')),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Back'), findsOneWidget);
        await tester.tap(find.text('Mailbox access'));
        await tester.pumpAndSettle();
        expect(find.text('Manage Accounts'), findsOneWidget);
        expect(find.byTooltip('Back'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Privacy & Security'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsOneWidget);
        await tester.tap(tab('Inbox'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Back'), findsNothing);
        expect(find.text('Settings'), findsNothing);
        expect(tester.getTopLeft(profile), position);
        await drawer(tester, 'All Senders');
        expect(find.byTooltip('Back'), findsNothing);
        expect(find.text('All Senders'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );

    testWidgets(
      'new main tab clears utility pages; filtered lists retain Back on $platform',
      (tester) async {
        await open(tester);
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        await drawer(tester, 'Settings');
        await tester.tap(
          find.byKey(const ValueKey('settings-privacy-security')),
        );
        await tester.pumpAndSettle();
        await tester.tap(tab('Inbox'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Back'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('All Senders'), findsOneWidget);
        expect(navigator.canPop(), isFalse);
        navigator.pushNamed(
          '/emails',
          arguments: const EmailListArguments(
            mailbox: 'ARCHIVED',
            title: 'Archived Emails',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Back'), findsOneWidget);
        expect(find.text('Archived Emails'), findsOneWidget);
        await tester.tap(find.byTooltip('Open menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Email Inbox'));
        await tester.pumpAndSettle();
        expect(find.text('Inbox'), findsWidgets);
        expect(find.byTooltip('Back'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('All Senders'), findsOneWidget);
        expect(navigator.canPop(), isFalse);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
  testWidgets('a standalone page never shows a Back arrow that cannot work', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppHeader(title: 'Privacy & Security', showBack: true),
        ),
      ),
    );
    expect(find.byTooltip('Back'), findsNothing);
    expect(find.text('Privacy & Security'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

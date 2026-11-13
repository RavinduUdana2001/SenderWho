import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'package:sender_who/widgets/app_header.dart';
import 'package:sender_who/theme/theme_mode_controller.dart';
import 'support/ui_review_repository.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final layout in [
      (size: const Size(280, 568), scale: 1.0),
      (size: const Size(320, 568), scale: 2.0),
      (size: const Size(740, 360), scale: 1.3),
      (size: const Size(768, 1024), scale: 2.0),
    ]) {
      for (final dark in [false, true]) {
        testWidgets(
          'menu and privacy adapt to $layout $platform dark=$dark',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = layout.size;
            tester.platformDispatcher.textScaleFactorTestValue = layout.scale;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
              tester.platformDispatcher.clearTextScaleFactorTestValue();
            });
            final data = UiReviewData();
            var revoked = false;
            final repository = SenderWhoRepository(
              previewMode: false,
              baseUrl: 'https://api.example.test/api/v1',
              sessionStore: MemorySessionStore(),
              client: MockClient((request) async {
                if (request.url.path.endsWith('/auth/sessions')) {
                  return data.json({
                    'items': revoked
                        ? []
                        : [
                            {
                              'id': 'another-device',
                              'deviceName':
                                  'A different signed-in Android or iPhone device with a long name',
                              'current': false,
                              'lastUsedAt': '2026-11-04T10:00:00Z',
                            },
                          ],
                  });
                }
                if (request.url.path.endsWith(
                      '/auth/sessions/another-device',
                    ) &&
                    request.method == 'DELETE') {
                  revoked = true;
                  return data.json({'success': true});
                }
                return data.handle(request);
              }),
            );
            await tester.pumpWidget(
              SenderWhoApp(
                repository: repository,
                initiallyAuthenticated: true,
                initialThemeMode: dark ? ThemeMode.dark : ThemeMode.light,
                themePreferenceStore: MemoryThemePreferenceStore(),
              ),
            );
            await tester.pumpAndSettle();
            ThemeModeController.of(
              tester.element(find.byType(AppHeader)),
            ).setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
            await tester.pumpAndSettle();
            final appContext = tester.element(find.byType(AppHeader));
            final navigator = Navigator.of(appContext);
            expect(
              Theme.of(appContext).brightness,
              dark ? Brightness.dark : Brightness.light,
            );
            await tester.tap(find.byTooltip('Open menu'));
            await tester.pumpAndSettle();
            final drawer = find.byType(Drawer);
            expect(tester.getSize(drawer).width, lessThanOrEqualTo(312));
            expect(
              tester.getSize(drawer).width,
              lessThanOrEqualTo(layout.size.width * .83),
            );
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('drawer-more-tools')),
              160,
              scrollable: find.byType(Scrollable).last,
            );
            await Scrollable.ensureVisible(
              tester.element(find.byKey(const ValueKey('drawer-more-tools'))),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('drawer-more-tools')));
            await tester.pumpAndSettle();
            expect(
              find.descendant(of: drawer, matching: find.text('Dashboard')),
              findsOneWidget,
            );
            expect(find.text('Search / Filter'), findsNothing);
            expect(tester.takeException(), isNull);
            await tester.tap(find.byTooltip('Close menu'));
            await tester.pumpAndSettle();
            navigator.pushNamed('/privacy-security');
            await tester.pumpAndSettle();
            expect(find.text('Changed your email password?'), findsNothing);
            expect(find.text('Delete SenderWho account'), findsNothing);
            expect(find.text('Account deletion information'), findsNothing);
            expect(find.text('Mailbox access'), findsOneWidget);
            final signOut = find.widgetWithText(TextButton, 'Sign out');
            await tester.ensureVisible(signOut);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.tap(signOut);
            await tester.pumpAndSettle();
            expect(revoked, isTrue);
            expect(find.text('No active sessions found'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          },
          variant: TargetPlatformVariant.only(platform),
        );
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/theme_mode_controller.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'package:sender_who/widgets/app_header.dart';
import 'package:sender_who/widgets/icon_bubble.dart';
import 'package:sender_who/widgets/mail_list_surface.dart';
import 'support/ui_review_repository.dart';

void main() {
  for (final dark in [false, true]) {
    for (final layout in [(390.0, 1.0), (320.0, 2.0), (768.0, 1.0)]) {
      testWidgets('security empty state centers at $layout dark=$dark', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(layout.$1, 844);
        tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final data = UiReviewData();
        final repository = SenderWhoRepository(
          previewMode: false,
          baseUrl: 'https://api.example.test/api/v1',
          sessionStore: MemorySessionStore(),
          client: MockClient((request) async {
            if (request.url.path.endsWith('/security-alerts')) {
              return data.json({
                'items': [data.alert(1)],
                'total': 1,
                'page': 1,
                'limit': 25,
              });
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
        Navigator.of(
          tester.element(find.byType(AppHeader)),
        ).pushNamed('/security-alerts');
        await tester.pumpAndSettle();
        await tester.tap(find.text('High Risk'));
        await tester.pumpAndSettle();
        for (final part in [
          find.byWidgetPredicate(
            (w) => w is IconBubble && w.icon == Icons.security_rounded,
          ),
          find.text('No alerts in this filter'),
          find.text('No security alerts match this view.'),
        ]) {
          expect(tester.getCenter(part).dx, closeTo(layout.$1 / 2, .5));
        }
        final tabs = find.byType(MailFilterTab);
        expect(tabs, findsNWidgets(3));
        expect(
          (tester.getRect(tabs.first).left + tester.getRect(tabs.last).right) /
              2,
          closeTo(layout.$1 / 2, .5),
        );
        expect(
          tester.widget<Text>(find.text('No alerts in this filter')).textAlign,
          TextAlign.center,
        );
        await tester.tap(find.text('Medium'));
        await tester.pumpAndSettle();
        expect(find.text('Unexpected sign-in message'), findsOneWidget);
        expect(find.text('No alerts in this filter'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

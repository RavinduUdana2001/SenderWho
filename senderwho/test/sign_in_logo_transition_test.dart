import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sender_who/screens/connect_email_screen.dart';
import 'package:sender_who/screens/onboarding_screen.dart';
import 'package:sender_who/theme/app_theme.dart';
import 'package:sender_who/widgets/senderwho_brand.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final dark in [false, true]) {
      testWidgets(
        'logo lands without a jump and delayed account data keeps its anchor on $platform dark=$dark',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          final email = Completer<String?>();
          final provider = Completer<String?>();
          final choices = Completer<Map<String, bool>>();
          await tester.pumpWidget(
            MaterialApp(
              theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                platform: platform,
              ),
              home: const OnboardingScreen(),
              routes: {
                ConnectEmailScreen.routeName: (_) => ConnectEmailScreen(
                  loadRememberedEmail: () => email.future,
                  loadRememberedProvider: () => provider.future,
                  availableProviders: () => choices.future,
                ),
              },
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Connect my inbox'));
          await tester.pump();
          final transition =
              ModalRoute.of(
                    tester.element(
                      find.byType(ConnectEmailScreen, skipOffstage: false),
                    ),
                  )!
                  as PageRoute<dynamic>;
          final logoImage = find.byWidgetPredicate(
            (widget) => widget is Image && widget.image == SenderWhoLogo.image,
          );
          // Sample the final frames of the flight and its handoff to the page.
          Rect? previous;
          var largestLateStep = 0.0;
          for (var frame = 0; frame < 35; frame++) {
            if (frame == 8) {
              choices.complete({
                'google': true,
                'microsoft': true,
                'yahoo': true,
              });
            }
            await tester.pump(const Duration(milliseconds: 16));
            expect(logoImage, findsOneWidget);
            final rect = tester.getRect(logoImage);
            if ((frame + 1) * 16 >=
                    transition.transitionDuration.inMilliseconds - 32 &&
                previous != null) {
              final distance = (rect.center - previous.center).distance;
              if (distance > largestLateStep) largestLateStep = distance;
            }
            previous = rect;
          }
          expect(largestLateStep, lessThan(2));
          await tester.pumpAndSettle();
          final destination = find.byKey(const ValueKey('connect-brand-icon'));
          final landed = tester.getRect(destination);
          expect(landed.center.dx, closeTo(195, .5));
          email.complete('returning@example.com');
          provider.complete('google');
          await tester.pumpAndSettle();
          expect(find.text('Continue with previous account'), findsOneWidget);
          expect(tester.getRect(destination), landed);
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          expect(find.text('Connect my inbox'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

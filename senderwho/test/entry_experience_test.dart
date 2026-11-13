import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/models/app_models.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/screens/connect_email_screen.dart';
import 'package:sender_who/screens/onboarding_screen.dart';
import 'package:sender_who/screens/splash_screen.dart';
import 'package:sender_who/theme/app_theme.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'package:sender_who/widgets/senderwho_brand.dart';
import 'support/ui_review_repository.dart';

void viewport(WidgetTester tester, [Size size = const Size(390, 844)]) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

SenderWhoApp launch(Future<AppLaunchState> startup) => SenderWhoApp(
  startup: startup,
  repository: UiReviewData().repository(),
  themePreferenceStore: MemoryThemePreferenceStore(),
);

class _LaunchContextRepository extends SenderWhoRepository {
  _LaunchContextRepository(UiReviewData data)
    : super(
        previewMode: false,
        sessionStore: MemorySessionStore(),
        client: MockClient(data.handle),
        baseUrl: 'https://api.example.test/api/v1',
      );
  int settingsLoads = 0;
  final settingsReady = Completer<void>();
  @override
  bool get isAuthenticated => true;
  @override
  Future<AppSettings> getSettings() async {
    settingsLoads++;
    await settingsReady.future;
    return super.getSettings();
  }
}

void main() {
  testWidgets(
    'splash animates once, opens welcome, and does not return on Back',
    (tester) async {
      viewport(tester);
      await tester.pumpWidget(
        launch(
          Future.value(
            const AppLaunchState(
              authenticated: false,
              themeMode: ThemeMode.light,
            ),
          ),
        ),
      );
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('SenderWho'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
      await tester.tap(find.text('Connect my inbox'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'logo is decoded before the native launch handoff and released only once',
    (tester) async {
      viewport(tester);
      var nativeHandoffs = 0;
      final startup = Completer<AppLaunchState>();
      await tester.pumpWidget(
        SenderWhoApp(
          startup: startup.future,
          onSplashReady: () => nativeHandoffs++,
          repository: UiReviewData().repository(),
          themePreferenceStore: MemoryThemePreferenceStore(),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          SenderWhoLogo.image,
          tester.element(find.byType(SplashScreen)),
        ),
      );
      await tester.pump();
      expect(nativeHandoffs, 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SplashScreen), findsOneWidget);
      startup.complete(
        const AppLaunchState(authenticated: false, themeMode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(nativeHandoffs, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'first GPU frame preparation does not consume the splash animation',
    (tester) async {
      viewport(tester);
      final rasterReady = Completer<void>();
      await tester.pumpWidget(
        SenderWhoApp(
          startup: Future.value(
            const AppLaunchState(
              authenticated: false,
              themeMode: ThemeMode.light,
            ),
          ),
          onSplashReady: () {},
          firstFrameRasterized: rasterReady.future,
          repository: UiReviewData().repository(),
          themePreferenceStore: MemoryThemePreferenceStore(),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          SenderWhoLogo.image,
          tester.element(find.byType(SplashScreen)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(SplashScreen), findsOneWidget);
      final entrance = find
          .descendant(
            of: find.byType(SplashScreen),
            matching: find.byType(ScaleTransition),
          )
          .first;
      expect(tester.widget<ScaleTransition>(entrance).scale.value, .86);
      rasterReady.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(
        tester.widget<ScaleTransition>(entrance).scale.value,
        greaterThan(.86),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'remote context loads after the first page transition rather than blocking launch',
    (tester) async {
      viewport(tester);
      final repository = _LaunchContextRepository(UiReviewData());
      await tester.pumpWidget(
        SenderWhoApp(
          startup: Future.value(
            const AppLaunchState(
              authenticated: true,
              themeMode: ThemeMode.light,
            ),
          ),
          repository: repository,
          themePreferenceStore: MemoryThemePreferenceStore(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 620));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(repository.settingsLoads, 0);
      await tester.pumpAndSettle();
      expect(find.text('All Senders'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(repository.settingsLoads, 1);
      repository.settingsReady.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'splash hides its outgoing wordmark before revealing the next page',
    (tester) async {
      viewport(tester);
      var reveals = 0;
      double? outgoingOpacity;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: SplashScreen(
            startup: Future.value(
              const AppLaunchState(
                authenticated: false,
                themeMode: ThemeMode.dark,
              ),
            ),
            onReady: (_) {
              reveals++;
              outgoingOpacity = tester
                  .widget<FadeTransition>(
                    find.byKey(const ValueKey('splash-wordmark-exit')),
                  )
                  .opacity
                  .value;
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));
      expect(reveals, 0);
      await tester.pumpAndSettle();
      expect(reveals, 1);
      expect(outgoingOpacity, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'startup waits for session restoration, then opens Senders in saved theme',
    (tester) async {
      viewport(tester);
      final startup = Completer<AppLaunchState>();
      await tester.pumpWidget(launch(startup.future));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      startup.complete(
        const AppLaunchState(authenticated: true, themeMode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();
      expect(find.text('All Senders'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(
        Theme.of(tester.element(find.text('All Senders'))).brightness,
        Brightness.dark,
      );
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed startup leaves a usable welcome screen', (tester) async {
    viewport(tester);
    final startup = Completer<AppLaunchState>();
    await tester.pumpWidget(launch(startup.future));
    startup.completeError(StateError('Storage unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Connect my inbox'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion skips the splash animation delay', (
    tester,
  ) async {
    viewport(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      launch(
        Future.value(
          const AppLaunchState(
            authenticated: false,
            themeMode: ThemeMode.light,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('canceling sign-in ignores a late successful callback', (
    tester,
  ) async {
    viewport(tester);
    final pending = Completer<bool>();
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        routes: {
          '/all-senders': (_) => const Scaffold(body: Text('Inbox opened')),
        },
        home: ConnectEmailScreen(
          loadRememberedEmail: () async => null,
          loadRememberedProvider: () async => null,
          startOAuth: (_) {
            starts++;
            return pending.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(starts, 1);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Connect your inbox'), findsOneWidget);
    expect(find.text('Inbox opened'), findsNothing);
    expect(find.text('Connection not completed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving sign-in safely disposes a pending connection', (
    tester,
  ) async {
    viewport(tester);
    final pending = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Text('Welcome host')),
        routes: {
          '/all-senders': (_) => const Scaffold(body: Text('Inbox opened')),
        },
      ),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ConnectEmailScreen(
              loadRememberedEmail: () async => null,
              loadRememberedProvider: () async => null,
              startOAuth: (_) => pending.future,
            ),
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Welcome host'), findsOneWidget);
    expect(find.text('Inbox opened'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'provider exceptions recover inline without losing sign-in choices',
    (tester) async {
      viewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: ConnectEmailScreen(
            loadRememberedEmail: () async => null,
            loadRememberedProvider: () async => null,
            startOAuth: (_) async => throw StateError('Browser unavailable'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('Connection not completed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    for (final scale in [1.5, 2.0]) {
      testWidgets('entry screens fit small phones at $scale text, dark=$dark', (
        tester,
      ) async {
        viewport(tester, const Size(320, 568));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: const OnboardingScreen(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Connect my inbox'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: ConnectEmailScreen(
              availableProviders: () async => {
                'google': true,
                'microsoft': true,
                'yahoo': true,
              },
              loadRememberedEmail: () async =>
                  'ravindu.singapura@mycompany.example',
              loadRememberedProvider: () async => 'microsoft',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Terms of Service'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}

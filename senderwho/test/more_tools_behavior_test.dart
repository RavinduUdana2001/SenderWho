import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/main.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/theme_preference_store.dart';
import 'support/ui_review_repository.dart';

class ToolsApi {
  final data = UiReviewData();
  final requests = <http.Request>[];
  String status = 'READY';
  String recovery = 'NONE';
  DateTime? retryAt;
  bool failOverview = false;
  String? failPath;
  Completer<http.Response>? pending;
  int overviewReads = 0;
  late final repository = SenderWhoRepository(
    previewMode: false,
    sessionStore: MemorySessionStore(),
    baseUrl: 'https://api.example.test/api/v1',
    client: MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path == failPath) return data.json({'message': 'Unavailable'}, 503);
      if (path.endsWith('/dashboard')) {
        overviewReads++;
        if (pending case final wait?) return wait.future;
        if (failOverview) return data.json({'message': 'Unavailable'}, 503);
        final body =
            jsonDecode((await data.handle(request)).body)
                as Map<String, dynamic>;
        body['sync'] = {
          'id': 'account-1',
          'emailAddress': 'first@example.com',
          'syncStatus': status,
          'recoveryAction': recovery,
          if (retryAt != null) 'syncRetryAt': retryAt!.toIso8601String(),
          if (status == 'FAILED') 'lastSyncError': 'Gmail is busy.',
        };
        return data.json(body);
      }
      if (path.endsWith('/sync') && request.method == 'POST') {
        return data.json({'status': 'QUEUED'});
      }
      return data.handle(request);
    }),
  );
}

Future<void> openTools(WidgetTester tester, ToolsApi api) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  await tester.pumpWidget(
    SenderWhoApp(
      repository: api.repository,
      initiallyAuthenticated: true,
      themePreferenceStore: MemoryThemePreferenceStore(),
    ),
  );
  await tester.pumpAndSettle();
  await menuTool(tester, 'Dashboard');
}

Future<void> menuTool(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip('Open menu'));
  await tester.pumpAndSettle();
  final tools = find.byKey(const ValueKey('drawer-more-tools'));
  await tester.scrollUntilVisible(
    tools,
    140,
    scrollable: find.byType(Scrollable).last,
  );
  await Scrollable.ensureVisible(tester.element(tools), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(tools);
  await tester.pumpAndSettle();
  final destination = find.descendant(of: tools, matching: find.text(name));
  await tester.ensureVisible(destination);
  await tester.pumpAndSettle();
  await tester.tap(destination);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final tool in [
    (name: 'Categories', path: '/api/v1/categories'),
    (name: 'Top Senders', path: '/api/v1/senders/top'),
    (name: 'Activity', path: '/api/v1/activity'),
  ]) {
    testWidgets('${tool.name} refresh failure has a working retry', (
      tester,
    ) async {
      final api = ToolsApi();
      await openTools(tester, api);
      if (tool.name == 'Top Senders') {
        Navigator.of(
          tester.element(find.byType(NavigationBar)),
        ).pushNamed('/top-senders');
        await tester.pumpAndSettle();
      } else {
        await menuTool(tester, tool.name);
      }
      final before = api.requests.where((r) => r.url.path == tool.path).length;
      api.failPath = tool.path;
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refresh.onRefresh();
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      api.failPath = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsNothing);
      expect(
        api.requests.where((r) => r.url.path == tool.path).length,
        before + 2,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('category browsing and ranked senders open matching records', (
    tester,
  ) async {
    final api = ToolsApi();
    await openTools(tester, api);
    await menuTool(tester, 'Categories');
    await tester.tap(find.text('Finance'));
    await tester.pumpAndSettle();
    final query = api.requests
        .lastWhere((r) => r.url.path.endsWith('/emails'))
        .url
        .queryParameters;
    expect(query['category'], 'FINANCE');
    expect(query['mailbox'], 'ALL');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byType(NavigationBar)),
    ).pushNamed('/top-senders');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Canva'));
    await tester.pumpAndSettle();
    expect(
      api.requests.any((r) => r.url.path.endsWith('/senders/sender-0')),
      isTrue,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View all senders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all senders'));
    await tester.pumpAndSettle();
    expect(find.text('All Senders'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Dashboard metrics open the correct mailbox filters and tool destinations',
    (tester) async {
      final api = ToolsApi();
      await openTools(tester, api);
      expect(find.text('5,003 messages'), findsOneWidget);
      for (final metric in [
        (label: 'Unread', mailbox: 'UNREAD', category: null),
        (label: 'Promotions', mailbox: 'ALL', category: 'PROMOTIONS'),
        (label: 'Spam', mailbox: 'ALL', category: 'SPAM'),
      ]) {
        await tapKey(tester, 'dashboard-metric-${metric.label}');
        final query = api.requests
            .lastWhere((r) => r.url.path.endsWith('/emails'))
            .url
            .queryParameters;
        expect(query['mailbox'], metric.mailbox);
        expect(query['category'], metric.category);
        expect(find.byTooltip('Back'), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }
      await tapKey(tester, 'dashboard-health');
      expect(find.text('Health breakdown'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'dashboard-sender-sender-0');
      expect(
        api.requests.any((r) => r.url.path.endsWith('/senders/sender-0')),
        isTrue,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'dashboard-alert-alert-0');
      expect(
        api.requests.any(
          (r) => r.url.path.endsWith('/security-alerts/alert-0'),
        ),
        isTrue,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search senders and messages'));
      await tester.pumpAndSettle();
      expect(find.text('Search'), findsWidgets);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'dashboard-cleanup');
      expect(find.text('Choose what to clean'), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing);
      await menuTool(tester, 'Dashboard');
      await tapKey(tester, 'dashboard-unsubscribe');
      expect(
        find.text(
          'Stop emails you no longer want. Existing messages stay in your mailbox.',
        ),
        findsOneWidget,
      );
      expect(api.requests.where((r) => !['GET'].contains(r.method)), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all More tools destinations open and primary tools never duplicate Back',
    (tester) async {
      final api = ToolsApi();
      await openTools(tester, api);
      for (final tool in [
        'Categories',
        'Activity',
        'Bulk clean',
        'Unsubscribe',
        'Dashboard',
      ]) {
        await menuTool(tester, tool);
        expect(find.byKey(const ValueKey('app-header-title')), findsOneWidget);
        expect(find.byTooltip('Back'), findsNothing);
        expect(tester.takeException(), isNull, reason: tool);
      }
      expect(api.data.unhandled, isEmpty);
    },
  );

  testWidgets(
    'Dashboard keeps cached metrics when refresh fails and disables overlapping refresh',
    (tester) async {
      final api = ToolsApi();
      await openTools(tester, api);
      final before = api.overviewReads;
      api.pending = Completer<http.Response>();
      await tester.tap(find.byTooltip('Refresh live results'));
      await tester.pump();
      expect(api.overviewReads, before + 1);
      final refresh = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Refresh live results',
        ),
      );
      expect(refresh.onPressed, isNull);
      expect(find.text('5,003 messages'), findsOneWidget);
      api.pending!.complete(api.data.json({'message': 'Unavailable'}, 503));
      api.pending = null;
      await tester.pumpAndSettle();
      expect(find.text('Showing the last update'), findsOneWidget);
      expect(find.text('5,003 messages'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh live results'));
      await tester.pumpAndSettle();
      expect(find.text('Showing the last update'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in ['SYNCING', 'PARTIAL', 'FAILED', 'DISCONNECTED']) {
    testWidgets('Dashboard uses correct sync recovery for $status', (
      tester,
    ) async {
      final api = ToolsApi()..status = status;
      if (status == 'FAILED') {
        api.retryAt = DateTime.now().add(const Duration(minutes: 2));
      }
      if (status == 'DISCONNECTED') api.recovery = 'RECONNECT';
      await openTools(tester, api);
      expect(find.text('Scan inbox'), findsNothing);
      expect(find.textContaining('short moment'), findsNothing);
      if (status == 'DISCONNECTED') {
        await tester.tap(find.byTooltip('View sync status'));
        await tester.pumpAndSettle();
        expect(find.text('Manage Accounts'), findsOneWidget);
      }
      expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Dashboard scan targets the connected account and schedules only one request',
    (tester) async {
      final api = ToolsApi();
      await openTools(tester, api);
      await tester.ensureVisible(find.text('Scan inbox'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan inbox'));
      await tester.pumpAndSettle();
      expect(
        api.requests.where((r) => r.method == 'POST').map((r) => r.url.path),
        ['/api/v1/email-accounts/account-1/sync'],
      );
      expect(find.text('Mailbox sync scheduled.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

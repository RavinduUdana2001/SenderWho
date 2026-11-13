import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sender_who/auth/session_store.dart';
import 'package:sender_who/models/app_models.dart';
import 'package:sender_who/screens/all_senders_screen.dart';
import 'package:sender_who/screens/sender_details_screen.dart';
import 'package:sender_who/services/senderwho_repository.dart';
import 'package:sender_who/theme/app_theme.dart';

Map<String, Object?> senderFixture(int index) => {
  'id': 'sender-$index',
  'name': [
    'Canva',
    'LinkedIn',
    'Amazon',
    'Figma',
    'Ravindu',
    'Weekly newsletter',
  ][index % 6],
  'email': 'updates-$index@example.com',
  'category': 'Companies',
  'score': 85,
  'totalMessages': 120 + index,
  'unreadMessages': index.isEven ? 4 : 0,
  'identityStatus': index == 2 ? 'SUSPICIOUS' : 'VERIFIED',
  'identityRiskLevel': index == 2 ? 'HIGH' : 'LOW',
};

SenderWhoRepository mailboxRepository() => SenderWhoRepository(
  previewMode: false,
  sessionStore: MemorySessionStore(),
  client: MockClient(
    (request) async => http.Response(
      jsonEncode(
        request.url.path.endsWith('/senders')
            ? {
                'items': List.generate(12, senderFixture),
                'total': 12,
                'page': 1,
                'limit': 25,
              }
            : {
                ...senderFixture(0),
                'firstSeenAt': '2024-11-27T00:00:00Z',
                'type': 'COMPANY',
                'location': 'Unknown',
                'messages': List.generate(
                  8,
                  (i) => {
                    'id': 'message-$i',
                    'sender': 'Canva',
                    'email': 'updates@example.com',
                    'subject': 'Your design is ready $i',
                    'snippet': 'Take a look at the latest updates.',
                    'date': 'Nov 3',
                    'isRead': i.isOdd,
                  },
                ),
              },
      ),
      200,
    ),
  ),
  baseUrl: 'https://api.example.test/api/v1',
);

class _ScanningRepository extends SenderWhoRepository {
  int loads = 0;

  @override
  bool get isAuthenticated => true;

  @override
  Future<DashboardSummary> getDashboard() async => DashboardSummary.fromJson({
    'sync': {'syncStatus': loads == 0 ? 'SYNCING' : 'READY'},
  });

  @override
  Future<SenderPage?> getSenders({
    int page = 1,
    int limit = 25,
    String kind = 'ALL',
    String control = 'ALL',
    String query = '',
    String? category,
  }) async {
    loads++;
    return SenderPage.fromJson({
      'items': loads == 1 ? [] : [senderFixture(0)],
      'total': loads == 1 ? 0 : 1,
      'page': 1,
      'limit': 25,
    });
  }
}

class _SlowStatisticsRepository extends SenderWhoRepository {
  final dashboard = Completer<DashboardSummary>();
  @override
  bool get isAuthenticated => true;
  @override
  Future<DashboardSummary> getDashboard() => dashboard.future;
  @override
  Future<SenderPage?> getSenders({
    int page = 1,
    int limit = 25,
    String kind = 'ALL',
    String control = 'ALL',
    String query = '',
    String? category,
  }) async => SenderPage.fromJson({
    'items': [senderFixture(0)],
    'total': 1,
    'page': 1,
    'limit': 25,
  });
}

void main() {
  testWidgets(
    'senders remain usable while inbox statistics are still loading',
    (tester) async {
      final repository = _SlowStatisticsRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AllSendersScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Canva'), findsOneWidget);
      repository.dashboard.complete(
        DashboardSummary.fromJson({
          'sync': {'syncStatus': 'READY'},
        }),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Senders refreshes during the initial scan and stops when ready',
    (tester) async {
      final repository = _ScanningRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AllSendersScreen(repository: repository),
        ),
      );
      await tester.pump();
      expect(
        find.text('Scanning your mailbox. New results appear automatically.'),
        findsOneWidget,
      );
      expect(repository.loads, 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Canva'), findsOneWidget);
      expect(find.textContaining('Syncing older mail'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(repository.loads, 2);
    },
  );

  for (final width in [320.0, 390.0, 1024.0]) {
    testWidgets(
      'compact sender rows fit a $width viewport and open the selected sender',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        addTearDown(() async {
          tester.view.resetDevicePixelRatio();
          tester.view.resetPhysicalSize();
          await tester.binding.setSurfaceSize(null);
        });
        String? openedId;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            initialRoute: AllSendersScreen.routeName,
            routes: {
              '/': (_) => const SizedBox.shrink(),
              AllSendersScreen.routeName: (_) =>
                  AllSendersScreen(repository: mailboxRepository()),
              SenderDetailsScreen.routeName: (context) {
                openedId = ModalRoute.of(context)!.settings.arguments as String;
                return const Scaffold(body: Text('Selected sender'));
              },
            },
          ),
        );
        await tester.pumpAndSettle();
        final firstRow = find.byKey(const ValueKey('sender-row-sender-0'));
        expect(tester.getSize(firstRow).height, lessThanOrEqualTo(76));
        expect(
          tester
              .getRect(find.byKey(const ValueKey('sender-row-sender-5')))
              .bottom,
          lessThan(tester.getRect(find.byType(NavigationBar)).top),
        );
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          0,
        );
        expect(find.byTooltip('High-risk sender identity'), findsOneWidget);
        await tester.tap(firstRow);
        await tester.pumpAndSettle();
        expect(openedId, 'sender-0');
        expect(find.text('Selected sender'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'sender messages are visible before expanding extra information',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: SenderDetailsScreen(
            repository: mailboxRepository(),
            senderId: 'sender-0',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Your design is ready 0')).bottom,
        lessThan(600),
      );
      expect(find.text('Nov 27, 2024'), findsNothing);
      await tester.ensureVisible(find.text('About this sender'));
      await tester.tap(find.text('About this sender'));
      await tester.pumpAndSettle();
      expect(find.text('Nov 27, 2024'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing sender filters while loading requests the latest filter',
    (tester) async {
      final firstPage = Completer<http.Response>();
      final kinds = <String?>[];
      final repository = SenderWhoRepository(
        previewMode: false,
        sessionStore: MemorySessionStore(),
        baseUrl: 'https://api.example.test/api/v1',
        client: MockClient((request) async {
          kinds.add(request.url.queryParameters['kind']);
          if (kinds.length == 1) return firstPage.future;
          return http.Response(
            jsonEncode({
              'items': [senderFixture(1)],
              'total': 1,
              'page': 1,
              'limit': 25,
            }),
            200,
          );
        }),
      );
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AllSendersScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('People'));
      await tester.pump();
      await tester.ensureVisible(find.text('Newsletters'));
      await tester.tap(find.text('Newsletters'));
      firstPage.complete(
        http.Response(
          jsonEncode({'items': [], 'total': 0, 'page': 1, 'limit': 25}),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(kinds, ['ALL', 'NEWSLETTERS']);
      expect(find.text('LinkedIn'), findsOneWidget);
    },
  );
}

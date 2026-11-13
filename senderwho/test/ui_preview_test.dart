import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sender_who/config/app_config.dart';
import 'package:sender_who/main.dart';

void main() {
  testWidgets(
    'debug UI preview opens Senders and keeps sample overview available',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      tester.view.devicePixelRatio = 1;
      addTearDown(() async {
        tester.view.resetDevicePixelRatio();
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(const SenderWhoApp());
      await tester.tap(find.text('Connect my inbox'));
      await tester.pumpAndSettle();

      expect(find.text('Connect my inbox'), findsOneWidget);
      await tester.tap(find.text('Connect my inbox'));
      await tester.pumpAndSettle();

      expect(find.text('All Senders'), findsOneWidget);
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('More tools'));
      await tester.tap(find.text('More tools'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dashboard'));
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
      expect(
        find.text('UI preview · Sample data · email actions are disabled'),
        findsOneWidget,
      );
      expect(find.textContaining('5,003'), findsOneWidget);
    },
    skip: !AppConfig.uiPreviewMode,
  );
}

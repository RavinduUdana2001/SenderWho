import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sender_who/config/app_config.dart';
import 'package:sender_who/main.dart';

void main() {
  testWidgets(
    'debug UI preview opens a populated dashboard without OAuth',
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

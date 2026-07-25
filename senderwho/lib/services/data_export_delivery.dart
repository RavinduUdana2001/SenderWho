import 'dart:convert';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

Future<ShareResult> deliverSenderWhoExport(
  Map<String, dynamic> export, {
  Rect? sharePositionOrigin,
}) {
  final timestamp = DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');
  final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(export));
  return Share.shareXFiles(
    [
      XFile.fromData(
        bytes,
        mimeType: 'application/json',
        name: 'senderwho-data-export-$timestamp.json',
      ),
    ],
    subject: 'SenderWho data export',
    text: 'Your SenderWho data export',
    sharePositionOrigin: sharePositionOrigin,
  );
}

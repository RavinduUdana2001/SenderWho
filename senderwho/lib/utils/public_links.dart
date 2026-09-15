import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openSenderWhoPublicPage(
  BuildContext context, {
  required String url,
  required String pageName,
}) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } on Object {
    opened = false;
  }
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not open $pageName. Please try again.')),
  );
}

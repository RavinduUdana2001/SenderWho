import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const productionApiBaseUrl =
      'https://lightcyan-sheep-166645.hostingersite.com/api/v1';

  static const apiBaseUrl = String.fromEnvironment(
    'SENDERWHO_API_URL',
    defaultValue: productionApiBaseUrl,
  );

  /// Local design-review mode. It is impossible to enable in profile/release
  /// builds, even if the dart-define is accidentally supplied.
  static const uiPreviewMode =
      kDebugMode &&
      bool.fromEnvironment('SENDERWHO_UI_PREVIEW', defaultValue: false);

  static void validate() {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !uri.hasAuthority) {
      throw StateError('SENDERWHO_API_URL must be an absolute URL.');
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError('SenderWho release builds require an HTTPS API URL.');
    }
  }
}

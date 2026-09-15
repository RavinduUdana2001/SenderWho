import 'package:flutter_test/flutter_test.dart';
import 'package:sender_who/config/app_config.dart';

void main() {
  test('production builds use the permanent SenderWho API domain', () {
    expect(AppConfig.productionApiBaseUrl, 'https://senderwho.com/api/v1');
    expect(AppConfig.privacyPolicyUrl, 'https://senderwho.com/privacy');
    expect(AppConfig.termsOfServiceUrl, 'https://senderwho.com/terms');
    expect(AppConfig.supportUrl, 'https://senderwho.com/support');
    expect(
      AppConfig.accountDeletionUrl,
      'https://senderwho.com/delete-account',
    );
    expect(AppConfig.supportEmail, 'senderwho.app@gmail.com');
  });
}

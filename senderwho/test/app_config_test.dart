import 'package:flutter_test/flutter_test.dart';
import 'package:sender_who/config/app_config.dart';

void main() {
  test('production builds use the permanent SenderWho API domain', () {
    expect(AppConfig.productionApiBaseUrl, 'https://senderwho.com/api/v1');
  });
}

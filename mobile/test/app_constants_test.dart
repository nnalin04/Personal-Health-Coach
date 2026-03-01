import 'package:flutter_test/flutter_test.dart';
import 'package:personal_health_coach/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    test('default API URL uses HTTPS scheme', () {
      expect(AppConstants.apiBaseUrl, startsWith('https://'));
    });

    test('default API URL ends with /api', () {
      expect(AppConstants.apiBaseUrl, endsWith('/api'));
    });

    test('default API URL is a valid URI', () {
      final uri = Uri.tryParse(AppConstants.apiBaseUrl);
      expect(uri, isNotNull);
      expect(uri!.isAbsolute, isTrue);
      expect(uri.host, isNotEmpty);
    });

    test('default API URL does not have a trailing slash after /api', () {
      expect(AppConstants.apiBaseUrl, isNot(endsWith('/api/')));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_health_coach/core/network/api_client.dart';

void main() {
  group('ApiClient', () {
    late ApiClient client;

    setUp(() {
      client = ApiClient(baseUrl: 'https://healthcoach.duckdns.org/api');
    });

    test('baseUrl returns the URL passed at construction', () {
      expect(client.baseUrl, equals('https://healthcoach.duckdns.org/api'));
    });

    test('setBaseUrl updates the baseUrl getter', () {
      client.setBaseUrl('http://localhost:8080/api');
      expect(client.baseUrl, equals('http://localhost:8080/api'));
    });

    test('setBaseUrl allows switching between environments', () {
      client.setBaseUrl('http://10.0.2.2:8080/api');
      expect(client.baseUrl, equals('http://10.0.2.2:8080/api'));

      client.setBaseUrl('https://healthcoach.duckdns.org/api');
      expect(client.baseUrl, equals('https://healthcoach.duckdns.org/api'));
    });

    test('setAuthToken with valid token does not throw', () {
      expect(() => client.setAuthToken('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'), returnsNormally);
    });

    test('setAuthToken with null clears the token without throwing', () {
      client.setAuthToken('some-token');
      expect(() => client.setAuthToken(null), returnsNormally);
    });

    test('setAuthToken with empty string clears the token without throwing', () {
      client.setAuthToken('some-token');
      expect(() => client.setAuthToken(''), returnsNormally);
    });
  });
}

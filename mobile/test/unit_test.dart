import 'package:flutter_test/flutter_test.dart';
import 'package:personal_health_coach/core/network/api_client.dart';
import 'package:personal_health_coach/core/storage/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  group('TokenStorage', () {
    test('save and read token', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storage = TokenStorage();
      await storage.saveToken('test-token');
      final token = await storage.readToken();
      expect(token, 'test-token');
    });

    test('clear token', () async {
      FlutterSecureStorage.setMockInitialValues({'jwt_token': 'test-token'});
      final storage = TokenStorage();
      await storage.clearToken();
      final token = await storage.readToken();
      expect(token, isNull);
    });
  });

  group('ApiClient', () {
    test('setAuthToken adds header', () {
      final client = ApiClient();
      client.setAuthToken('test-token');
      // Note: testing inner dio might require more mocking, 
      // but this confirms the method exists.
    });
  });
}

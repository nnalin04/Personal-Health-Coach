import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppConfigStorage {
  static const _apiBaseUrlKey = 'api_base_url';
  final FlutterSecureStorage _secureStorage;

  AppConfigStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<void> saveApiBaseUrl(String baseUrl) async {
    await _secureStorage.write(key: _apiBaseUrlKey, value: baseUrl);
  }

  Future<String?> readApiBaseUrl() async {
    return _secureStorage.read(key: _apiBaseUrlKey);
  }
}

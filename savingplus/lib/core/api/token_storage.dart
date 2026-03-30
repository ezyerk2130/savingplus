import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  final _storage = const FlutterSecureStorage();

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<bool> hasTokens() async {
    final token = await _storage.read(key: _accessKey);
    return token != null;
  }

  // Biometric login: store credentials securely after successful login
  static const _phoneKey = 'bio_phone';
  static const _passKey = 'bio_pass';

  Future<void> saveCredentials(String phone, String password) async {
    await _storage.write(key: _phoneKey, value: phone);
    await _storage.write(key: _passKey, value: password);
  }

  Future<Map<String, String>?> getSavedCredentials() async {
    final phone = await _storage.read(key: _phoneKey);
    final pass = await _storage.read(key: _passKey);
    if (phone != null && pass != null) return {'phone': phone, 'password': pass};
    return null;
  }

  Future<bool> hasSavedCredentials() async {
    final phone = await _storage.read(key: _phoneKey);
    return phone != null;
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _phoneKey);
    await _storage.delete(key: _passKey);
  }
}

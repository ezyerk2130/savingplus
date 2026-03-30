import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/token_storage.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final _api = ApiClient.instance;
  final _tokenStorage = TokenStorage();

  Future<void> init() async {
    final hasTokens = await _tokenStorage.hasTokens();
    if (hasTokens) {
      try {
        await loadProfile();
        _isAuthenticated = true;
      } catch (_) {
        await _tokenStorage.clearTokens();
        _isAuthenticated = false;
      }
      notifyListeners();
    }
  }

  Future<void> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.post('/auth/login', data: {
        'phone': phone,
        'password': password,
      });
      await _tokenStorage.saveTokens(res.data['access_token'], res.data['refresh_token']);
      await loadProfile();
      _isAuthenticated = true;
      _error = null;
    } catch (e) {
      _error = ApiClient.getErrorMessage(e, 'Login failed');
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String fullName, String phone, String password, String pin) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _api.post('/auth/register', data: {
        'full_name': fullName,
        'phone': phone,
        'password': password,
        'pin': pin,
      });
      _error = null;
    } catch (e) {
      _error = ApiClient.getErrorMessage(e, 'Registration failed');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProfile() async {
    final res = await _api.get('/profile');
    _user = User.fromJson(res.data);
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken != null) {
        await _api.post('/auth/logout', data: {'refresh_token': refreshToken});
      }
    } catch (_) {}
    await _tokenStorage.clearTokens();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}

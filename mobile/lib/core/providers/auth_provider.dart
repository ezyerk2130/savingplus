import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/token_storage.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final TokenStorage _tokenStorage = TokenStorage();

  User? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final hasTokens = await _tokenStorage.hasTokens();
    if (hasTokens) {
      try {
        await loadProfile();
      } catch (_) {
        await _tokenStorage.clearTokens();
        _isAuthenticated = false;
        _user = null;
        notifyListeners();
      }
    }
  }

  Future<void> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post('/auth/login', data: {
        'phone': phone,
        'password': password,
      });

      final data = response.data;
      await _tokenStorage.saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );

      await loadProfile();
      _isAuthenticated = true;
    } on DioException catch (e) {
      if (e.error is ApiException) {
        _error = (e.error as ApiException).message;
      } else {
        _error = 'Login failed. Please check your credentials.';
      }
      _isAuthenticated = false;
    } catch (e) {
      _error = 'An unexpected error occurred.';
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(
    String phone,
    String fullName,
    String password,
    String pin,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post('/auth/register', data: {
        'phone': phone,
        'full_name': fullName,
        'password': password,
        'pin': pin,
      });

      final data = response.data;
      await _tokenStorage.saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );

      await loadProfile();
      _isAuthenticated = true;
    } on DioException catch (e) {
      if (e.error is ApiException) {
        _error = (e.error as ApiException).message;
      } else {
        _error = 'Registration failed. Please try again.';
      }
      _isAuthenticated = false;
    } catch (e) {
      _error = 'An unexpected error occurred.';
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProfile() async {
    final response = await _api.get('/user/profile');
    _user = User.fromJson(response.data as Map<String, dynamic>);
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> refreshToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) {
      await logout();
      return;
    }

    try {
      final response = await _api.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

      final data = response.data;
      await _tokenStorage.saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );
    } catch (_) {
      await logout();
    }
  }

  Future<void> logout() async {
    // Try to invalidate refresh token on server
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken != null) {
        await _api.post('/auth/logout', data: {
          'refresh_token': refreshToken,
        });
      }
    } catch (_) {
      // Ignore errors during logout
    }

    await _tokenStorage.clearTokens();
    _user = null;
    _isAuthenticated = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

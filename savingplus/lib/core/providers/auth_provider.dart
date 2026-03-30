import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
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
  final _localAuth = LocalAuthentication();
  bool _biometricAvailable = false;
  bool _hasSavedCreds = false;

  bool get canUseBiometric => _biometricAvailable;

  Future<void> init() async {
    // Check biometric availability
    try {
      _biometricAvailable = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      _hasSavedCreds = await _tokenStorage.hasSavedCredentials();
    } catch (_) {
      _biometricAvailable = false;
    }

    final hasTokens = await _tokenStorage.hasTokens();
    if (hasTokens) {
      try {
        await loadProfile();
        _isAuthenticated = true;
      } catch (_) {
        await _tokenStorage.clearTokens();
        _isAuthenticated = false;
      }
    }
    notifyListeners();
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
      // Save credentials for biometric login next time
      await _tokenStorage.saveCredentials(phone, password);
      _hasSavedCreds = true;
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

  bool get hasSavedCredentials => _hasSavedCreds;

  /// Authenticate with fingerprint/face, then auto-login with saved credentials.
  Future<void> biometricLogin() async {
    if (!_hasSavedCreds) {
      _error = 'Please log in with your password first to enable fingerprint login.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Step 1: Biometric authentication
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint to log in to SavingPlus',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (!authenticated) {
        _error = 'Biometric authentication failed';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Step 2: Get saved credentials
      final creds = await _tokenStorage.getSavedCredentials();
      if (creds == null) {
        _error = 'No saved credentials. Please log in with your password first.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Step 3: Login with saved credentials
      final res = await _api.post('/auth/login', data: {
        'phone': creds['phone'],
        'password': creds['password'],
      });
      await _tokenStorage.saveTokens(res.data['access_token'], res.data['refresh_token']);
      await loadProfile();
      _isAuthenticated = true;
      _error = null;
    } on PlatformException catch (e) {
      _error = 'Biometric error: ${e.message}';
      _isAuthenticated = false;
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

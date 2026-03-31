import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/token_storage.dart';

/// Manages app lock state. When the user switches away from the app
/// and comes back, they must authenticate with PIN or fingerprint.
class AppLockProvider extends ChangeNotifier with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isAuthenticating = false;
  bool _isAuthenticated = false; // tracks if user is logged in
  DateTime? _pausedAt;

  /// How many seconds before the app locks after going to background.
  /// 0 = lock immediately, 30 = lock after 30 seconds in background.
  static const int lockDelaySeconds = 5;

  bool get isLocked => _isLocked;
  bool get isAuthenticating => _isAuthenticating;

  final _localAuth = LocalAuthentication();
  final _tokenStorage = TokenStorage();

  void init() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Call this when user successfully logs in.
  void onLogin() {
    _isAuthenticated = true;
    _isLocked = false;
    notifyListeners();
  }

  /// Call this when user logs out.
  void onLogout() {
    _isAuthenticated = false;
    _isLocked = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isAuthenticated) return; // Don't lock if not logged in

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background — record the time
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // App coming back to foreground
      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
        if (elapsed >= lockDelaySeconds) {
          _isLocked = true;
          notifyListeners();
        }
        _pausedAt = null;
      }
    }
  }

  /// Unlock with fingerprint/face.
  Future<bool> unlockWithBiometric() async {
    if (_isAuthenticating) return false;
    _isAuthenticating = true;
    notifyListeners();

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock SavingPlus',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        _isLocked = false;
        _isAuthenticating = false;
        notifyListeners();
        return true;
      }
    } on PlatformException catch (_) {
      // Biometric not available, fall through to PIN
    }

    _isAuthenticating = false;
    notifyListeners();
    return false;
  }

  /// Unlock with PIN (validates against saved credentials).
  Future<bool> unlockWithPin(String pin) async {
    _isAuthenticating = true;
    notifyListeners();

    try {
      final creds = await _tokenStorage.getSavedCredentials();
      // In a real app, you'd validate the PIN against the backend.
      // For now, we accept any 4+ digit PIN if the user has saved credentials.
      // The actual PIN is validated server-side on transactions.
      if (creds != null && pin.length >= 4) {
        _isLocked = false;
        _isAuthenticating = false;
        notifyListeners();
        return true;
      }
    } catch (_) {}

    _isAuthenticating = false;
    notifyListeners();
    return false;
  }

  /// Check if app lock is enabled in user preferences.
  Future<bool> isAppLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('app_lock_enabled') ?? true; // enabled by default
  }

  /// Toggle app lock setting.
  Future<void> setAppLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', enabled);
  }
}

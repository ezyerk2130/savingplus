import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/utils/theme.dart';

class PinEntryScreen extends StatefulWidget {
  final String title;
  final String description;
  final Future<void> Function(String pin) onComplete;

  const PinEntryScreen({
    super.key,
    required this.title,
    required this.description,
    required this.onComplete,
  });

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  String _pin = '';
  bool _isLoading = false;
  String? _error;
  final _localAuth = LocalAuthentication();

  void _addDigit(String digit) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 6) {
      _submit();
    }
  }

  void _removeDigit() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      await widget.onComplete(_pin);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _pin = '';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _biometricAuth() async {
    try {
      final canCheck =
          await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!canCheck) return;

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to confirm transaction',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      if (authenticated && mounted) {
        setState(() => _isLoading = true);
        try {
          await widget.onComplete('biometric');
        } catch (e) {
          setState(() => _error = e.toString());
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    } on PlatformException catch (e) {
      setState(() => _error = 'Biometric error: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onBackground.withValues(alpha: 0.7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.language), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // --- Blurred card preview area ---
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Shimmer placeholder shapes
                    Container(
                      width: 120,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 180,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 100,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Bottom sheet container ---
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('Confirm transaction',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onBackground)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      widget.description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.onSurfaceVariant),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_error != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(_error!,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.error)),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // --- PIN dots ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final filled = index < _pin.length;
                      return Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? AppColors.primary : Colors.transparent,
                          border: Border.all(
                            color: filled
                                ? AppColors.primary
                                : AppColors.surfaceContainerHigh,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),

                  if (_isLoading) ...[
                    const SizedBox(height: 16),
                    const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ],

                  const Spacer(),

                  // --- Number pad ---
                  _buildNumberPad(),

                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {},
                    child: Text.rich(
                      TextSpan(
                        text: 'Forgot PIN? ',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: AppColors.onSurfaceVariant),
                        children: [
                          TextSpan(
                            text: 'Reset',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberPad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['bio', '0', 'del'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) {
                if (key == 'bio') {
                  return _buildKeyButton(
                    child: const Icon(Icons.fingerprint,
                        color: AppColors.onBackground, size: 28),
                    onTap: _biometricAuth,
                  );
                }
                if (key == 'del') {
                  return _buildKeyButton(
                    child: const Icon(Icons.backspace_outlined,
                        color: AppColors.onBackground, size: 24),
                    onTap: _removeDigit,
                  );
                }
                return _buildKeyButton(
                  child: Text(
                    key,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onBackground),
                  ),
                  onTap: () => _addDigit(key),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKeyButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

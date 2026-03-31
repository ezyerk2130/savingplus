import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../core/utils/theme.dart';

class LockScreen extends StatefulWidget {
  final Widget child;
  const LockScreen({super.key, required this.child});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  String? _error;
  bool _attemptedBiometric = false;

  @override
  void initState() {
    super.initState();
    // Auto-attempt biometric on first show
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    if (_attemptedBiometric) return;
    _attemptedBiometric = true;
    final lock = context.read<AppLockProvider>();
    await lock.unlockWithBiometric();
  }

  void _addDigit(String digit) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  void _removeDigit() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _verifyPin() async {
    final lock = context.read<AppLockProvider>();
    final success = await lock.unlockWithPin(_pin);
    if (!success && mounted) {
      setState(() {
        _pin = '';
        _error = 'Incorrect PIN. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockProvider>();

    if (!lock.isLocked) return widget.child;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Logo
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppGradients.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.lock_outline, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome back',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your PIN to unlock',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 32),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: filled ? AppColors.primary : AppColors.surfaceContainerHigh,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13)),
            ],

            const Spacer(flex: 1),

            // Number pad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                children: [
                  for (var row in [['1','2','3'], ['4','5','6'], ['7','8','9'], ['bio','0','del']])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row.map((key) {
                          if (key == 'bio') {
                            return _KeypadButton(
                              child: Icon(Icons.fingerprint, color: AppColors.primary, size: 28),
                              onTap: () {
                                setState(() => _attemptedBiometric = false);
                                _tryBiometric();
                              },
                            );
                          }
                          if (key == 'del') {
                            return _KeypadButton(
                              child: Icon(Icons.backspace_outlined, color: AppColors.onSurfaceVariant, size: 24),
                              onTap: _removeDigit,
                            );
                          }
                          return _KeypadButton(
                            child: Text(key, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
                            onTap: () => _addDigit(key),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Forgot PIN
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Forgot PIN? ', style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant)),
                Text('Reset', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ],
            ),

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _KeypadButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 72,
          height: 56,
          child: Center(child: child),
        ),
      ),
    );
  }
}

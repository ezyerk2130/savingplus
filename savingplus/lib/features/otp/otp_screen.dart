import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/theme.dart';

class OtpScreen extends StatefulWidget {
  final String phone;

  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _error;
  int _secondsRemaining = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  bool get _isComplete => _code.length == 6;

  String get _maskedPhone {
    final p = widget.phone;
    if (p.length >= 6) {
      return '${p.substring(0, 7)}XX XXX XXX';
    }
    return p;
  }

  Future<void> _verify() async {
    if (!_isComplete) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ApiClient.instance.post('/auth/verify-otp', data: {
        'phone': widget.phone,
        'code': _code,
      });
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() => _error = ApiClient.getErrorMessage(e, 'Verification failed'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_secondsRemaining > 0) return;
    try {
      await ApiClient.instance.post('/auth/resend-otp', data: {
        'phone': widget.phone,
      });
      _startTimer();
    } catch (e) {
      if (mounted) {
        setState(() => _error = ApiClient.getErrorMessage(e, 'Failed to resend code'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'OTP Verification',
          style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text('Swahili',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify your number',
                style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.onBackground),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to $_maskedPhone. Enter it below.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 32),

              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              // OTP digit boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    width: 48,
                    height: 56,
                    margin: EdgeInsets.only(left: index == 0 ? 0 : 8),
                    child: TextFormField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.onBackground),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.ghostBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.ghostBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        setState(() {});
                      },
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // Resend timer
              _secondsRemaining > 0
                  ? Text(
                      'Resend code in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
                    )
                  : GestureDetector(
                      onTap: _resendCode,
                      child: Text(
                        'Resend code',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),

              const SizedBox(height: 32),

              GradientButton(
                onPressed: _isComplete && !_isLoading ? _verify : null,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Verify'),
              ),

              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.pop(),
                child: Text.rich(
                  TextSpan(
                    text: 'Wrong number? ',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
                    children: [
                      TextSpan(
                        text: 'Go back',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'Join 50,000+ savers securing their future across East Africa.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

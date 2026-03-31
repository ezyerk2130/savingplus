import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/theme.dart';

class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length != 6) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      await ApiClient.instance.post('/auth/2fa/verify', data: {'code': _code});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('2FA verified successfully')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() { _error = ApiClient.getErrorMessage(e); _isLoading = false; });
      for (final c in _controllers) { c.clear(); }
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        title: Text('Verification', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.ghostBorder),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Kiswahili', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Shield icon
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 32),

              Text('Two-factor\nauthentication', textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.onBackground, height: 1.2)),
              const SizedBox(height: 12),
              Text('Enter the code from your\nauthenticator app', textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurfaceVariant, height: 1.4)),
              const SizedBox(height: 36),

              // 6 digit boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final hasValue = _controllers[i].text.isNotEmpty;
                  final isFocused = _focusNodes[i].hasFocus;
                  return Container(
                    width: 48, height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: hasValue ? AppColors.surfaceContainerLow : AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: isFocused ? Border.all(color: AppColors.primary, width: 2) : null,
                    ),
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.onBackground),
                      decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        setState(() {});
                        if (v.isNotEmpty && i < 5) {
                          _focusNodes[i + 1].requestFocus();
                        }
                        if (_code.length == 6) _verify();
                      },
                    ),
                  );
                }),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13)),
              ],

              const Spacer(flex: 3),

              // Verify button
              GradientButton(
                onPressed: _isLoading || _code.length != 6 ? null : _verify,
                width: double.infinity, height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoading)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    else ...[
                      Text('Verify', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Backup codes link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.key, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text("Can't access your app? ", style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
                  Text('Use backup codes', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

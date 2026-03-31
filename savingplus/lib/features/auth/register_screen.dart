import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/utils/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // PIN controllers (4 digits each)
  final _pinControllers = List.generate(4, (_) => TextEditingController());
  final _pinFocusNodes = List.generate(4, (_) => FocusNode());
  final _confirmPinControllers =
      List.generate(4, (_) => TextEditingController());
  final _confirmPinFocusNodes = List.generate(4, (_) => FocusNode());

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _step = 1;
  String _selectedLang = 'EN';

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    for (final c in _confirmPinControllers) {
      c.dispose();
    }
    for (final f in _confirmPinFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  bool _hasSymbol() =>
      _passwordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  bool _hasNumber() =>
      _passwordController.text.contains(RegExp(r'[0-9]'));

  String get _pin => _pinControllers.map((c) => c.text).join();
  String get _confirmPin =>
      _confirmPinControllers.map((c) => c.text).join();

  void _goToStep2() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _step = 2);
  }

  Future<void> _handleRegister() async {
    final pin = _pin;
    final confirmPin = _confirmPin;

    if (pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a 4-digit PIN')),
      );
      return;
    }
    if (pin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match')),
      );
      return;
    }

    final phone = '+255${_phoneController.text.trim()}';
    final auth = context.read<AuthProvider>();
    // The API expects full_name; we derive it from email or use phone as name
    final name = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim().split('@').first
        : phone;
    await auth.register(name, phone, _passwordController.text, pin);
    if (!mounted) return;
    if (auth.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created! Please log in.')),
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // ── Header: SavingPlus + language toggle ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('SavingPlus',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: ['SW', 'EN'].map((lang) {
                          final sel = _selectedLang == lang;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedLang = lang),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.cardWhite
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(lang,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: sel
                                        ? AppColors.primary
                                        : AppColors.onSurfaceVariant,
                                  )),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Step progress bar ──
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: _step >= 2
                              ? AppColors.primary
                              : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('STEP $_step OF 2',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Title / subtitle ──
                Text(
                  _step == 1
                      ? 'Create your account'
                      : 'Set your transaction PIN',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onBackground),
                ),
                const SizedBox(height: 6),
                Text(
                  _step == 1
                      ? 'Join 100,000+ Tanzanians saving smarter with TZS & USD.'
                      : 'This PIN will be used to authorize withdrawals and transfers.',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 28),

                // ── Error message ──
                if (auth.error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(auth.error!,
                        style: GoogleFonts.inter(
                            color: AppColors.error, fontSize: 13)),
                  ),
                  const SizedBox(height: 16),
                ],

                // ═══════════════════════════════════════════════════════
                // STEP 1: Account Info
                // ═══════════════════════════════════════════════════════
                if (_step == 1) ...[
                  // Phone
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone number',
                      prefixIcon: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('+255',
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.onBackground)),
                            const SizedBox(width: 8),
                            Container(
                                width: 1,
                                height: 24,
                                color: AppColors.ghostBorder),
                          ],
                        ),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 9)
                            ? 'Enter a valid phone number'
                            : null,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon:
                          Icon(Icons.email_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon:
                          const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: AppColors.onSurfaceVariant,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Min 8 characters'
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text('Must include a symbol and a number.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: (_hasSymbol() && _hasNumber())
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      )),
                  const SizedBox(height: 16),

                  // Confirm password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon:
                          const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: AppColors.onSurfaceVariant,
                        ),
                        onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) => v != _passwordController.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                  const SizedBox(height: 32),

                  // Create account button
                  GradientButton(
                    onPressed: _goToStep2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Create account',
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward,
                            size: 18, color: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // OR divider
                  Row(
                    children: [
                      const Expanded(
                          child: Divider(color: AppColors.ghostBorder)),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.onSurfaceVariant)),
                      ),
                      const Expanded(
                          child: Divider(color: AppColors.ghostBorder)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Google button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.g_mobiledata, size: 26),
                      label: const Text('Continue with Google'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Already have account
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account? ',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.onSurfaceVariant)),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text('Log in',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Terms
                  Center(
                    child: Text(
                      'BY CONTINUING, YOU AGREE TO OUR TERMS OF SERVICE AND PRIVACY POLICY.',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                // ═══════════════════════════════════════════════════════
                // STEP 2: PIN Setup
                // ═══════════════════════════════════════════════════════
                if (_step == 2) ...[
                  // PIN entry
                  Text('Enter PIN',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onBackground)),
                  const SizedBox(height: 12),
                  _buildPinRow(_pinControllers, _pinFocusNodes),
                  const SizedBox(height: 28),

                  // Confirm PIN
                  Text('Confirm PIN',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onBackground)),
                  const SizedBox(height: 12),
                  _buildPinRow(
                      _confirmPinControllers, _confirmPinFocusNodes),
                  const SizedBox(height: 36),

                  // Complete registration button
                  GradientButton(
                    onPressed: auth.isLoading ? null : _handleRegister,
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Complete registration',
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward,
                                  size: 18, color: Colors.white),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Back to step 1
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _step = 1),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back to step 1'),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── PIN digit row (4 boxes) ──────────────────────────────────────────
  Widget _buildPinRow(
    List<TextEditingController> controllers,
    List<FocusNode> focusNodes,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        return Container(
          width: 60,
          height: 64,
          margin: EdgeInsets.only(right: i < 3 ? 16 : 0),
          child: TextField(
            controller: controllers[i],
            focusNode: focusNodes[i],
            textAlign: TextAlign.center,
            maxLength: 1,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.onBackground),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: EdgeInsets.zero,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: controllers[i].text.isNotEmpty
                      ? AppColors.primary
                      : AppColors.ghostBorder,
                  width: controllers[i].text.isNotEmpty ? 2 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 2),
              ),
            ),
            onChanged: (v) {
              setState(() {});
              if (v.isNotEmpty && i < 3) {
                focusNodes[i + 1].requestFocus();
              }
              if (v.isEmpty && i > 0) {
                focusNodes[i - 1].requestFocus();
              }
            },
          ),
        );
      }),
    );
  }
}

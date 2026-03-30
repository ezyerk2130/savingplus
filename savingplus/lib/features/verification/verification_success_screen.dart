import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/theme.dart';

class VerificationSuccessScreen extends StatefulWidget {
  const VerificationSuccessScreen({super.key});

  @override
  State<VerificationSuccessScreen> createState() => _VerificationSuccessScreenState();
}

class _VerificationSuccessScreenState extends State<VerificationSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/home'),
        ),
        title: Text('Verification Success',
            style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Animated checkmark
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: const Icon(Icons.check, size: 56, color: Colors.white),
                ),
              ),

              const SizedBox(height: 28),

              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    Text(
                      'Identity verified!',
                      style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.onBackground),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your identity has been verified successfully. You now have full access to all SavingPlus features.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant, height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Feature cards
              Row(
                children: [
                  Expanded(child: _buildFeatureCard(Icons.all_inclusive, 'Unlimited Savings', 'No caps on deposits')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildFeatureCard(Icons.bolt, 'Instant Payments', 'Send & receive instantly')),
                ],
              ),

              const Spacer(flex: 3),

              GradientButton(
                onPressed: () => context.go('/home'),
                child: const Text('Continue to dashboard'),
              ),

              const SizedBox(height: 16),

              // Secure session footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SECURE SESSION VERIFIED',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ghostBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

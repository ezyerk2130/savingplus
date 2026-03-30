import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/theme.dart';

class VerificationProgressScreen extends StatelessWidget {
  const VerificationProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        title: Text('Verification', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text('SWAHILI',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Illustration
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_late_outlined, color: AppColors.warning, size: 48),
              ),

              const SizedBox(height: 28),
              Text(
                'Verification in progress',
                style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.onBackground),
              ),
              const SizedBox(height: 8),
              Text(
                "We'll notify you within 2 hours",
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
              ),

              const SizedBox(height: 36),

              // Step indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStep('PROFILE', StepStatus.complete),
                  _buildConnector(true),
                  _buildStep('IDENTITY', StepStatus.complete),
                  _buildConnector(false),
                  _buildStep('REVIEW', StepStatus.inProgress),
                ],
              ),

              const SizedBox(height: 36),

              // Info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.ghostBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Secure Review',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                          const SizedBox(height: 4),
                          Text(
                            'Our team is reviewing your documents. Typically takes less than 2 hours.',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Contact support link
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.ghostBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.headset_mic_outlined, size: 20, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Need help? Contact support',
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.onBackground)),
                      ),
                      const Icon(Icons.chevron_right, size: 20, color: AppColors.onSurfaceVariant),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Back to dashboard
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to dashboard'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String label, StepStatus status) {
    final isComplete = status == StepStatus.complete;
    final isInProgress = status == StepStatus.inProgress;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isComplete
                ? AppColors.primary
                : isInProgress
                    ? AppColors.warning
                    : AppColors.surfaceContainerLow,
          ),
          child: isComplete
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : isInProgress
                  ? Container(
                      margin: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    )
                  : null,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isComplete ? AppColors.primary : isInProgress ? AppColors.warning : AppColors.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(bool completed) {
    return Container(
      width: 48,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
      color: completed ? AppColors.primary : AppColors.surfaceContainerHigh,
    );
  }
}

enum StepStatus { complete, inProgress, pending }

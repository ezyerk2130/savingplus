import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/theme.dart';

class DepositWaitingScreen extends StatefulWidget {
  final double amount;
  final String paymentMethod;

  const DepositWaitingScreen({
    super.key,
    required this.amount,
    required this.paymentMethod,
  });

  @override
  State<DepositWaitingScreen> createState() => _DepositWaitingScreenState();
}

class _DepositWaitingScreenState extends State<DepositWaitingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _pollTimer;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Auto-poll or auto-complete after 10 seconds for demo
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _elapsed++);
      if (_elapsed >= 10) {
        timer.cancel();
        if (mounted) {
          Navigator.of(context).pop(true); // Pop with success
        }
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Deposit',
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
            child: Text('ENG',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Animated progress indicator with phone icon
              Stack(
                alignment: Alignment.center,
                children: [
                  RotationTransition(
                    turns: _animController,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 3),
                      ),
                      child: CustomPaint(
                        painter: _ArcPainter(color: AppColors.primary),
                      ),
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                    child: const Icon(Icons.phone_android, color: AppColors.primary, size: 36),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              Text(
                'Waiting for M-Pesa...',
                style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.onBackground),
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'AMOUNT ${formatMoney(widget.amount)}',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onBackground),
                ),
              ),

              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Please check your phone for the M-Pesa push notification to authorize the deposit.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
                ),
              ),

              const SizedBox(height: 24),

              // Warning card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Do not close or refresh this screen until the transaction is confirmed.',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {},
                child: Text(
                  "Didn't receive a notification?",
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  _ArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -0.5,
      1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/theme.dart';

class SafeLockScreen extends StatefulWidget {
  const SafeLockScreen({super.key});

  @override
  State<SafeLockScreen> createState() => _SafeLockScreenState();
}

class _SafeLockScreenState extends State<SafeLockScreen> {
  final _amountController = TextEditingController(text: '500,000');
  int _durationDays = 30;
  double _sliderValue = 30;
  bool _isLoading = false;
  String? _error;
  double _availableBalance = 825000;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    try {
      final res = await ApiClient.instance.get('/wallet/balance');
      setState(() {
        _availableBalance = double.tryParse(res.data['available_balance']?.toString() ?? '0') ?? 0;
      });
    } catch (_) {}
  }

  double get _amount {
    final text = _amountController.text.replaceAll(',', '').replaceAll(' ', '');
    return double.tryParse(text) ?? 0;
  }

  double get _interestRate {
    if (_durationDays >= 90) return 0.164;
    if (_durationDays >= 30) return 0.14;
    return 0.12;
  }

  double get _earnings => _amount * _interestRate * _durationDays / 365;

  String get _interestPercent => '${(_interestRate * 100).toStringAsFixed(1)}%';

  Future<void> _lockFunds() async {
    if (_amount <= 0 || _amount > _availableBalance) {
      setState(() => _error = 'Enter a valid amount within your available balance');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ApiClient.instance.post('/savings/plan', data: {
        'name': 'SafeLock $_durationDays days',
        'type': 'locked',
        'target_amount': _amount,
        'duration_days': _durationDays,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = ApiClient.getErrorMessage(e, 'Failed to create SafeLock'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 20),
            const SizedBox(width: 8),
            Text('SafeLock Investment', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.translate), onPressed: () {})],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Info banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF1565C0), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Interest paid upfront to your Flex wallet when you lock.',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1565C0)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            Text('How much to lock?',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
            const SizedBox(height: 12),

            // Amount input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.ghostBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('TZS', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onBackground),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: _amount <= _availableBalance ? AppColors.primary : AppColors.error),
                const SizedBox(width: 6),
                Text(
                  'Available: ${formatMoney(_availableBalance)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _amount <= _availableBalance ? AppColors.primary : AppColors.error,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Lock duration
            Text('Lock duration',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
            const SizedBox(height: 12),

            // Duration chips
            Row(
              children: [10, 30, 90].map((days) {
                final selected = _durationDays == days;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: days == 90 ? 0 : 8),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _durationDays = days;
                        _sliderValue = days.toDouble();
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: selected ? AppColors.primary : AppColors.ghostBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$days days',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.surfaceContainerLow,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primary.withValues(alpha: 0.1),
                trackHeight: 4,
              ),
              child: Slider(
                value: _sliderValue,
                min: 10,
                max: 365,
                divisions: 71,
                label: '${_sliderValue.round()} days',
                onChanged: (v) => setState(() {
                  _sliderValue = v;
                  _durationDays = v.round();
                }),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('10 days', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                Text('$_durationDays days selected', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
                Text('365 days', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),

            const SizedBox(height: 24),

            // Earnings card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppGradients.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOU WILL EARN',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Text(
                    formatMoney(_earnings),
                    style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_interestPercent p.a.',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paid to your Flex wallet immediately',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Early break warning
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Text('EARLY BREAK WARNING',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error, letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your money will be locked for $_durationDays days. Breaking the lock early will incur a 5% penalty on the locked amount.',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.error),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

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

            GradientButton(
              onPressed: _isLoading ? null : _lockFunds,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Lock ${formatMoney(_amount)} now'),
            ),

            const SizedBox(height: 12),
            Center(
              child: Text(
                'You\'ll receive ${formatMoney(_earnings)} in your Flex wallet immediately',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

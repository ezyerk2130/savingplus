import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/theme.dart';

class AutoSaveSetupScreen extends StatefulWidget {
  const AutoSaveSetupScreen({super.key});

  @override
  State<AutoSaveSetupScreen> createState() => _AutoSaveSetupScreenState();
}

class _AutoSaveSetupScreenState extends State<AutoSaveSetupScreen> {
  final _amountController = TextEditingController(text: '5,000');
  String _frequency = 'daily'; // daily, weekly, monthly
  DateTime _startDate = DateTime.now();
  bool _autoDebitMpesa = true;
  bool _isLoading = false;
  String? _error;

  final String _mpesaNumber = '0744 123 456';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _amount {
    final text = _amountController.text.replaceAll(',', '').replaceAll(' ', '');
    return double.tryParse(text) ?? 0;
  }

  double get _monthlyAmount {
    switch (_frequency) {
      case 'daily':
        return _amount * 30;
      case 'weekly':
        return _amount * 4;
      default:
        return _amount;
    }
  }

  double get _projectedTotal => _monthlyAmount * 12;
  double get _projectedInterest => _projectedTotal * 0.12;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _startAutoSave() async {
    if (_amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ApiClient.instance.post('/savings/plan', data: {
        'name': '$_frequency AutoSave',
        'type': 'flexible',
        'target_amount': _monthlyAmount * 12,
        'auto_debit': _autoDebitMpesa,
        'frequency': _frequency,
        'debit_amount': _amount,
        'start_date': _startDate.toIso8601String(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = ApiClient.getErrorMessage(e, 'Failed to create AutoSave'));
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
        title: Text('AutoSave Setup', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600)),
        actions: [IconButton(icon: const Icon(Icons.language), onPressed: () {})],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Interest banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppGradients.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'You earn 12% p.a. \u2014 interest added daily',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            Text('How much do you want to save?',
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
                  Text('TZS', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
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

            const SizedBox(height: 24),

            // Frequency selector
            Row(
              children: ['daily', 'weekly', 'monthly'].map((freq) {
                final selected = _frequency == freq;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: freq == 'monthly' ? 0 : 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _frequency = freq),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: selected ? AppColors.primary : AppColors.ghostBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          freq[0].toUpperCase() + freq.substring(1),
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

            const SizedBox(height: 12),
            Text(
              'That\'s ${formatMoney(_monthlyAmount)}/month at this rate',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
            ),

            const SizedBox(height: 28),

            // Start date
            Text('When should we start?',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.ghostBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      _startDate.day == DateTime.now().day ? 'Today, ${DateFormat('dd MMM yyyy').format(_startDate)}' : DateFormat('dd MMM yyyy').format(_startDate),
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.onBackground),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // M-Pesa auto debit toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.ghostBorder),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AutoSave from my M-Pesa',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
                            const SizedBox(height: 4),
                            Text('Automatic deductions via M-Pesa',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _autoDebitMpesa,
                        onChanged: (v) => setState(() => _autoDebitMpesa = v),
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                  if (_autoDebitMpesa) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text('M', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                          const SizedBox(width: 12),
                          Text(_mpesaNumber, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (_autoDebitMpesa) ...[
              const SizedBox(height: 8),
              Text(
                'We\'ll send an M-Pesa push notification to authorise each deduction.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ],

            const SizedBox(height: 24),

            // Withdrawal windows
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.ghostBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Withdrawal Windows',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                  const SizedBox(height: 8),
                  Text('Free withdrawals on these dates:',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  ..._buildQuarterlyDates(),
                  const SizedBox(height: 8),
                  Text(
                    'Early withdrawal incurs a 2.5% fee on the withdrawn amount.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.warning),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 12-month projection
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
                  Text('12-Month Projection',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8))),
                  const SizedBox(height: 8),
                  Text(
                    formatMoney(_projectedTotal + _projectedInterest),
                    style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Principal: ${formatMoney(_projectedTotal)} + Interest: ${formatMoney(_projectedInterest)}',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
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
              onPressed: _isLoading ? null : _startAutoSave,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Start AutoSave'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildQuarterlyDates() {
    final now = DateTime.now();
    final dates = <String>[];
    for (int q = 1; q <= 4; q++) {
      final month = (((now.month - 1) ~/ 3) * 3 + q * 3) % 12 + 1;
      final year = now.year + (((now.month - 1) ~/ 3) * 3 + q * 3) ~/ 12;
      final date = DateTime(year, month, 1);
      dates.add(DateFormat('dd MMM yyyy').format(date));
    }
    return dates.map((d) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(d, style: GoogleFonts.inter(fontSize: 13, color: AppColors.onBackground)),
        ],
      ),
    )).toList();
  }
}

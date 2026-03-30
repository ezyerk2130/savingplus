import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/theme.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _api = ApiClient.instance;
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController(text: '+255 ');
  String _selectedMethod = 'mpesa';
  String _depositTarget = 'flex'; // flex or autosave
  int? _selectedQuickAmount;
  bool _isLoading = false;
  String? _error;

  final _quickAmounts = [1000, 5000, 10000, 50000];

  final _methods = [
    {'id': 'mpesa', 'label': 'M-Pesa', 'subtitle': 'Vodacom M-Pesa', 'color': Color(0xFF4CAF50), 'icon': 'M'},
    {'id': 'yaspesa', 'label': 'Yas Pesa', 'subtitle': 'Add new account', 'color': Color(0xFF2196F3), 'icon': 'Y'},
    {'id': 'airtel', 'label': 'Airtel Money', 'subtitle': 'Add new account', 'color': Color(0xFFE53935), 'icon': 'A'},
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  double get _amount {
    final text = _amountController.text.replaceAll(',', '').replaceAll(' ', '');
    return double.tryParse(text) ?? 0;
  }

  void _selectQuickAmount(int amount) {
    setState(() {
      _selectedQuickAmount = amount;
      _amountController.text = NumberFormat('#,###').format(amount);
    });
  }

  Future<void> _handleDeposit() async {
    if (_amount <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }
    if (_phoneController.text.trim().length < 10) {
      setState(() => _error = 'Please enter a valid phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _api.post('/wallet/deposit', data: {
        'amount': _amount,
        'payment_method': _selectedMethod,
        'phone_number': _phoneController.text.trim(),
        'idempotency_key': const Uuid().v4(),
      });
      if (!mounted) return;
      context.push('/deposit-waiting');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ApiClient.getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Deposit',
            style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text('SWAHILI',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // ENTER AMOUNT label
            Center(
              child: Text('ENTER AMOUNT',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 16),

            // Large amount display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.ghostBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('TZS',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: moneyStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.onBackground),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        hintText: '0',
                        hintStyle: moneyStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4)),
                      ),
                      onChanged: (_) => setState(() => _selectedQuickAmount = null),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick amount chips
            Row(
              children: _quickAmounts.map((amt) {
                final selected = _selectedQuickAmount == amt;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: amt == _quickAmounts.last ? 0 : 8),
                    child: GestureDetector(
                      onTap: () => _selectQuickAmount(amt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: selected ? AppColors.primary : AppColors.ghostBorder,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'TZS ${NumberFormat('#,###').format(amt)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Deposit target segmented tab
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                children: [
                  _buildSegment('flex', 'Deposit to Flex'),
                  _buildSegment('autosave', 'Deposit to AutoSave'),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Choose deposit method
            Text('Choose deposit method',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
            const SizedBox(height: 12),

            // Payment method cards
            ..._methods.map((m) {
              final isSelected = _selectedMethod == m['id'];
              final color = m['color'] as Color;
              return GestureDetector(
                onTap: () => setState(() => _selectedMethod = m['id'] as String),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.ghostBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(m['icon'] as String,
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['label'] as String,
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
                            Text(m['subtitle'] as String,
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 12, height: 12,
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),

            // Transaction summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TRANSACTION SUMMARY',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  _summaryRow('From', _selectedMethod == 'mpesa' ? 'M-Pesa' : _selectedMethod == 'airtel' ? 'Airtel Money' : 'Yas Pesa'),
                  const SizedBox(height: 8),
                  _summaryRow('To', _depositTarget == 'flex' ? 'Flex Wallet' : 'AutoSave'),
                  const SizedBox(height: 8),
                  _summaryRow('Amount', _amount > 0 ? formatMoney(_amount) : 'TZS 0.00'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // No fees
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('No fees. Instant settlement.',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary)),
              ],
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

            // Submit button
            GradientButton(
              onPressed: _isLoading ? null : _handleDeposit,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Send M-Pesa push'),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                      ],
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment(String value, String label) {
    final selected = _depositTarget == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _depositTarget = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.cardWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.onBackground : AppColors.onSurfaceVariant,
              )),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/theme.dart';

class FlexWalletScreen extends StatefulWidget {
  const FlexWalletScreen({super.key});

  @override
  State<FlexWalletScreen> createState() => _FlexWalletScreenState();
}

class _FlexWalletScreenState extends State<FlexWalletScreen> {
  bool _isLoading = true;
  String? _error;
  double _balance = 0;
  double _monthlyInterest = 0;
  final int _freeWithdrawalsUsed = 2;
  final int _freeWithdrawalsTotal = 4;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final balRes = await ApiClient.instance.get('/wallet/balance');
      _balance = double.tryParse(balRes.data['available_balance']?.toString() ?? '0') ?? 0;
      _monthlyInterest = _balance * 0.08 / 12;

      try {
        final txRes = await ApiClient.instance.get('/transactions');
        _transactions = txRes.data is List ? txRes.data : (txRes.data['transactions'] ?? []);
      } catch (_) {
        _transactions = [];
      }
    } catch (e) {
      _error = ApiClient.getErrorMessage(e, 'Failed to load wallet');
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
        title: Text('Flex Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text('SWAHILI',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
          ),
          IconButton(icon: const Icon(Icons.info_outline, size: 20), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: GoogleFonts.inter(color: AppColors.error)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // Balance card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: AppGradients.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Flex balance',
                                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                              const SizedBox(height: 4),
                              Text(
                                formatMoney(_balance),
                                style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Earning 8% p.a. \u2014 ${formatMoney(_monthlyInterest)} this month',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                              ),

                              const SizedBox(height: 20),

                              // Deposit + Withdraw buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 44,
                                      child: ElevatedButton(
                                        onPressed: () {},
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: AppColors.primary,
                                          shape: const StadiumBorder(),
                                          elevation: 0,
                                        ),
                                        child: Text('Deposit', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SizedBox(
                                      height: 44,
                                      child: OutlinedButton(
                                        onPressed: () {},
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                                          shape: const StadiumBorder(),
                                        ),
                                        child: Text('Withdraw', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Free withdrawals
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Free withdrawals this month',
                                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
                                  Text('$_freeWithdrawalsUsed/$_freeWithdrawalsTotal',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: List.generate(_freeWithdrawalsTotal, (i) {
                                  return Container(
                                    width: 12,
                                    height: 12,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i < _freeWithdrawalsUsed ? AppColors.primary : AppColors.surfaceContainerLow,
                                      border: Border.all(
                                        color: i < _freeWithdrawalsUsed ? AppColors.primary : AppColors.surfaceContainerHigh,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 8),
                              Text('TZS 500 fee per extra withdrawal',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // FlexDollar promo
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.attach_money, color: Color(0xFF1565C0), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Save in US Dollars',
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                                    Text('Protect against TZS devaluation',
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant, size: 20),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Transactions
                        Text('Transactions',
                            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                        const SizedBox(height: 12),

                        if (_transactions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text('No transactions yet',
                                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant)),
                            ),
                          )
                        else
                          ...(_transactions.take(10).map((tx) => _buildTransaction(tx))),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildTransaction(dynamic tx) {
    final type = (tx['type'] ?? 'transfer').toString();
    final amount = tx['amount'] ?? 0;
    final date = formatDate(tx['created_at']?.toString());
    final isCredit = type == 'deposit' || type == 'interest' || type == 'credit';

    IconData icon;
    switch (type) {
      case 'deposit':
        icon = Icons.arrow_downward;
        break;
      case 'withdrawal':
        icon = Icons.arrow_upward;
        break;
      case 'interest':
        icon = Icons.trending_up;
        break;
      default:
        icon = Icons.swap_horiz;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ghostBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isCredit ? AppColors.primary : AppColors.onSurfaceVariant).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: isCredit ? AppColors.primary : AppColors.onSurfaceVariant, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type[0].toUpperCase() + type.substring(1),
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
                Text(date, style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'} ${formatMoney(amount)}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isCredit ? AppColors.primary : AppColors.onBackground,
            ),
          ),
        ],
      ),
    );
  }
}

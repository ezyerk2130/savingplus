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
        final txRes = await ApiClient.instance.get('/transactions', queryParameters: {'page_size': 10});
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Flex Wallet',
            style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600)),
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

                        // --- Balance card ---
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: AppGradients.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Flex balance',
                                  style: GoogleFonts.inter(
                                      fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                              const SizedBox(height: 6),
                              Text(
                                formatMoney(_balance),
                                style: moneyStyle(
                                    fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Earning 8% p.a. \u2014 ${formatMoney(_monthlyInterest)} this month',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 44,
                                      child: OutlinedButton(
                                        onPressed: () {},
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(
                                              color: Colors.white.withValues(alpha: 0.6)),
                                          shape: const StadiumBorder(),
                                        ),
                                        child: Text('Deposit',
                                            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
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
                                        child: Text('Withdraw',
                                            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // --- Free withdrawals card ---
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
                                      style: GoogleFonts.inter(
                                          fontSize: 13, color: AppColors.onSurfaceVariant)),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                        '$_freeWithdrawalsUsed / $_freeWithdrawalsTotal',
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: List.generate(_freeWithdrawalsTotal, (i) {
                                  return Container(
                                    width: 14,
                                    height: 14,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i < _freeWithdrawalsUsed
                                          ? AppColors.primary
                                          : AppColors.surfaceContainerLow,
                                      border: Border.all(
                                        color: i < _freeWithdrawalsUsed
                                            ? AppColors.primary
                                            : AppColors.surfaceContainerHigh,
                                        width: 2,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                  'Enjoy up to 4 free withdrawals. TZS 500 fee per extra.',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // --- Save in US Dollars card ---
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF1565C0).withValues(alpha: 0.12)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.language,
                                        color: Color(0xFF1565C0), size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Save in US Dollars',
                                            style: GoogleFonts.plusJakartaSans(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.onBackground)),
                                        const SizedBox(height: 2),
                                        Text(
                                            'Protect your savings from TZS inflation',
                                            style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: AppColors.onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('ESTIMATED RETURNS 5-7% p.a. in USD',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurfaceVariant,
                                      letterSpacing: 0.5)),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1565C0),
                                  side: const BorderSide(color: Color(0xFF1565C0)),
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                ),
                                child: Text('Open FlexDollar account',
                                    style: GoogleFonts.inter(
                                        fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // --- Transactions heading ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Transactions',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onBackground)),
                                const SizedBox(height: 2),
                                Text('Your recent activity in Mkoba wa Uhuru',
                                    style: GoogleFonts.inter(
                                        fontSize: 12, color: AppColors.onSurfaceVariant)),
                              ],
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.filter_list,
                                  size: 20, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_transactions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text('No transactions yet',
                                  style: GoogleFonts.inter(
                                      fontSize: 14, color: AppColors.onSurfaceVariant)),
                            ),
                          )
                        else
                          ...(_transactions.take(10).map((tx) => _buildTransaction(tx))),

                        if (_transactions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: () {},
                              child: Text('View all history',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary)),
                            ),
                          ),
                        ],

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
    final dateTime = formatDateTime(tx['created_at']?.toString());
    final status = (tx['status'] ?? 'completed').toString();
    final isCredit = type == 'deposit' || type == 'interest' || type == 'credit';

    IconData icon;
    Color iconBgColor;
    Color iconColor;
    switch (type) {
      case 'deposit':
        icon = Icons.arrow_downward;
        iconBgColor = AppColors.primary.withValues(alpha: 0.1);
        iconColor = AppColors.primary;
        break;
      case 'withdrawal':
        icon = Icons.arrow_upward;
        iconBgColor = AppColors.error.withValues(alpha: 0.1);
        iconColor = AppColors.error;
        break;
      case 'interest':
        icon = Icons.trending_up;
        iconBgColor = AppColors.primary.withValues(alpha: 0.1);
        iconColor = AppColors.primary;
        break;
      case 'bank_deposit':
        icon = Icons.account_balance;
        iconBgColor = AppColors.onSurfaceVariant.withValues(alpha: 0.1);
        iconColor = AppColors.onSurfaceVariant;
        break;
      case 'fee':
        icon = Icons.receipt_long;
        iconBgColor = AppColors.warning.withValues(alpha: 0.1);
        iconColor = AppColors.warning;
        break;
      default:
        icon = Icons.swap_horiz;
        iconBgColor = AppColors.onSurfaceVariant.withValues(alpha: 0.1);
        iconColor = AppColors.onSurfaceVariant;
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type[0].toUpperCase() + type.substring(1),
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onBackground)),
                const SizedBox(height: 2),
                Text(dateTime,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'} ${formatMoney(amount)}',
                style: moneyStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isCredit ? AppColors.primary : AppColors.onBackground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                status[0].toUpperCase() + status.substring(1),
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: status == 'completed'
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

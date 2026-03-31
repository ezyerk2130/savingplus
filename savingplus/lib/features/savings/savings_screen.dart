import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/models/savings_plan.dart';
import '../../core/models/transaction.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/theme.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final _api = ApiClient.instance;
  List<SavingsPlan> _plans = [];
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  String? _error;

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
      final results = await Future.wait([
        _api.get('/savings/plans'),
        _api.get('/transactions', queryParameters: {'page_size': '5'}),
      ]);
      if (!mounted) return;
      final planData = results[0].data;
      final txData = results[1].data;
      setState(() {
        _plans = (planData is List
                ? planData
                : planData is Map
                    ? (planData['plans'] ?? [])
                    : [])
            .map<SavingsPlan>((e) => SavingsPlan.fromJson(e))
            .toList();
        _transactions = (txData is List
                ? txData
                : txData is Map
                    ? (txData['transactions'] ?? [])
                    : [])
            .map<Transaction>((e) => Transaction.fromJson(e))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = ApiClient.getErrorMessage(e);
      });
    }
  }

  Color _planBorderColor(String type) {
    switch (type) {
      case 'flexible':
        return AppColors.primary;
      case 'locked':
        return const Color(0xFF7C3AED);
      case 'target':
        return const Color(0xFFD97706);
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style:
                                GoogleFonts.inter(color: AppColors.error)),
                        const SizedBox(height: 12),
                        GradientButton(
                            onPressed: _loadData,
                            width: 140,
                            height: 40,
                            child: const Text('Retry')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        const SizedBox(height: 20),

                        // Title
                        Text('Savings',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onBackground)),
                        const SizedBox(height: 20),

                        // ── Quick Actions 2x2 Grid ──
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.check_circle_outline,
                                label: 'AutoSave',
                                bgColor: AppColors.primary
                                    .withValues(alpha: 0.08),
                                iconColor: AppColors.primary,
                                onTap: () =>
                                    context.push('/autosave/setup'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.lock_outline,
                                label: 'SafeLock',
                                bgColor: const Color(0xFF3B82F6)
                                    .withValues(alpha: 0.08),
                                iconColor: const Color(0xFF3B82F6),
                                onTap: () => context.push('/safelock'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.my_location_outlined,
                                label: 'Goals',
                                bgColor: const Color(0xFFD97706)
                                    .withValues(alpha: 0.08),
                                iconColor: const Color(0xFFD97706),
                                onTap: () =>
                                    context.push('/savings/new'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.people_outline,
                                label: 'Circles',
                                bgColor: const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.08),
                                iconColor: const Color(0xFF7C3AED),
                                onTap: () => context.go('/circles'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ── Your savings plans ──
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Your savings plans',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onBackground)),
                            TextButton(
                              onPressed: () {},
                              child: Text('See all',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_plans.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppColors.cardWhite,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.savings_outlined,
                                    size: 48,
                                    color: AppColors.onSurfaceVariant
                                        .withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                Text('No savings plans yet',
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color:
                                            AppColors.onSurfaceVariant)),
                                const SizedBox(height: 16),
                                GradientButton(
                                  onPressed: () async {
                                    await context.push('/savings/new');
                                    _loadData();
                                  },
                                  width: 180,
                                  height: 44,
                                  child: const Text('Create plan'),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._plans.map((plan) =>
                              _buildPlanCard(plan)),

                        const SizedBox(height: 28),

                        // ── Recent Transactions ──
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Recent Transactions',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onBackground)),
                            TextButton(
                              onPressed: () => context.go('/wallet'),
                              child: Text('View all',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_transactions.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.cardWhite,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('No transactions yet',
                                  style: GoogleFonts.inter(
                                      color:
                                          AppColors.onSurfaceVariant)),
                            ),
                          )
                        else
                          ..._transactions
                              .map((tx) => _buildTransactionTile(tx)),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
      ),
    );
  }

  // ─── Plan card with left colored border ───────────────────────────────
  Widget _buildPlanCard(SavingsPlan plan) {
    final borderColor = _planBorderColor(plan.type);
    final interestText = '${plan.interestRate}% p.a.';

    return GestureDetector(
      onTap: () {
        if (plan.autoDebit) {
          context.push('/autosave/detail?id=${plan.id}');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.ghostBorder),
        ),
        child: Row(
          children: [
            // Left colored border
            Container(
              width: 5,
              height: 90,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + interest pill
                    Row(
                      children: [
                        Expanded(
                          child: Text(plan.name,
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onBackground)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(interestText,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Status row
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: plan.status == 'active'
                                ? AppColors.primary
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          plan.status[0].toUpperCase() +
                              plan.status.substring(1),
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant),
                        ),
                        if (plan.autoDebit &&
                            plan.autoDebitFrequency != null) ...[
                          Text(' \u2022 ',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant)),
                          Text(
                            'Auto-debit ${plan.autoDebitFrequency}',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Balance
                    Row(
                      children: [
                        Text('BALANCE  ',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurfaceVariant,
                                letterSpacing: 0.5)),
                        Expanded(
                          child: Text(
                            formatMoney(plan.currentAmount),
                            style: moneyStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Chevron
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 22),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Transaction tile ─────────────────────────────────────────────────
  Widget _buildTransactionTile(Transaction tx) {
    IconData icon;
    Color iconColor;
    String prefix;

    switch (tx.type) {
      case 'deposit':
        icon = Icons.arrow_downward;
        iconColor = AppColors.primary;
        prefix = '+';
        break;
      case 'withdrawal':
        icon = Icons.arrow_upward;
        iconColor = AppColors.error;
        prefix = '-';
        break;
      case 'transfer':
        icon = Icons.swap_horiz;
        iconColor = AppColors.secondary;
        prefix = '';
        break;
      default:
        icon = Icons.receipt_long;
        iconColor = AppColors.onSurfaceVariant;
        prefix = '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.type.replaceFirst(
                      tx.type[0], tx.type[0].toUpperCase()),
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onBackground),
                ),
                Text(formatDate(tx.createdAt),
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$prefix ${formatMoney(tx.amount)}',
                  style: moneyStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: iconColor)),
              Text(tx.status,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Quick Action Card (2x2 grid item) ───────────────────────────────────
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 14),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onBackground)),
          ],
        ),
      ),
    );
  }
}

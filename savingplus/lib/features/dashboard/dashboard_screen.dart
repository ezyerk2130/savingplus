import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/savings_plan.dart';
import '../../core/models/transaction.dart';
import '../../core/models/wallet.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiClient.instance;
  WalletBalance? _wallet;
  List<SavingsPlan> _plans = [];
  List<Transaction> _transactions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.get('/wallet/balance'),
        _api.get('/savings/plans'),
        _api.get('/transactions', queryParameters: {'limit': '5'}),
      ]);
      if (!mounted) return;
      setState(() {
        _wallet = WalletBalance.fromJson(results[0].data);
        final planData = results[1].data;
        _plans = (planData is List ? planData : planData['plans'] ?? []).map<SavingsPlan>((j) => SavingsPlan.fromJson(j)).toList();
        final txData = results[2].data;
        _transactions = (txData is List ? txData : txData['transactions'] ?? []).map<Transaction>((j) => Transaction.fromJson(j)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = ApiClient.getErrorMessage(e); _loading = false; });
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: GoogleFonts.inter(color: AppColors.error)),
                    const SizedBox(height: 12),
                    GradientButton(onPressed: _loadData, width: 140, height: 40, child: const Text('Retry')),
                  ]),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      // Header
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(
                                    '${_greeting()}, ${user?.fullName.split(' ').first ?? 'there'}',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.onBackground),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(formatDate(DateTime.now().toIso8601String()), style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
                                ]),
                              ),
                              IconButton(
                                onPressed: () => context.push('/notifications'),
                                icon: const Icon(Icons.notifications_outlined, color: AppColors.onBackground),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => context.go('/profile'),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.primary,
                                  child: Text((user?.fullName ?? 'U').substring(0, 1).toUpperCase(), style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Balance card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(gradient: AppGradients.primaryGradient, borderRadius: BorderRadius.circular(16)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Total savings balance', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(formatMoney(_wallet?.totalBalance ?? '0'), style: moneyStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                            const SizedBox(height: 4),
                            Text('Interest earned this month: ${formatMoney('0')}', style: GoogleFonts.inter(fontSize: 12, color: Colors.white60)),
                            const SizedBox(height: 20),
                            Row(children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: OutlinedButton(
                                    onPressed: () => context.push('/deposit'),
                                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), foregroundColor: Colors.white, shape: const StadiumBorder()),
                                    child: const Text('Deposit'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: () => context.push('/withdraw'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary, shape: const StadiumBorder(), elevation: 0),
                                    child: const Text('Withdraw'),
                                  ),
                                ),
                              ),
                            ]),
                          ]),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Streak banner
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
                          ),
                          child: Row(children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.local_fire_department, color: AppColors.secondary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("You've saved for 14 days in a row!", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                                const SizedBox(height: 2),
                                Text('Keep it up.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                              ],
                            )),
                          ]),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Quick actions
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text('Quick actions', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(children: [
                          _QuickAction(icon: Icons.trending_up, label: 'Invest', color: AppColors.primary, onTap: () => context.push('/invest')),
                          const SizedBox(width: 12),
                          _QuickAction(icon: Icons.people_outline, label: 'Circles', color: AppColors.secondary, onTap: () => context.go('/circles')),
                          const SizedBox(width: 12),
                          _QuickAction(icon: Icons.shield_outlined, label: 'Insurance', color: const Color(0xFF6366F1), onTap: () => context.push('/insurance')),
                          const SizedBox(width: 12),
                          _QuickAction(icon: Icons.savings_outlined, label: 'Save', color: const Color(0xFFE8A317), onTap: () => context.go('/save')),
                        ]),
                      ),

                      const SizedBox(height: 24),

                      // Savings plans
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Your savings plans', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                          TextButton(onPressed: () => context.go('/save'), child: const Text('View all')),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      if (_plans.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(12)),
                            child: Column(children: [
                              Icon(Icons.savings_outlined, size: 40, color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
                              const SizedBox(height: 8),
                              Text('No savings plans yet', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
                              const SizedBox(height: 12),
                              GradientButton(onPressed: () => context.push('/savings/new'), width: 160, height: 40, child: const Text('Create plan')),
                            ]),
                          ),
                        )
                      else
                        ...List.generate(_plans.length.clamp(0, 3), (i) => Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: _PlanCard(plan: _plans[i]),
                        )),

                      const SizedBox(height: 16),

                      // Recent transactions
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Recent transactions', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                          TextButton(onPressed: () => context.go('/wallet'), child: const Text('View all')),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      if (_transactions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(12)),
                            child: Center(child: Text('No transactions yet', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant))),
                          ),
                        )
                      else
                        ...List.generate(_transactions.length, (i) => _TransactionTile(transaction: _transactions[i])),

                      const SizedBox(height: 24),

                      // Referral
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.card_giftcard, color: AppColors.secondary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Invite a friend', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                                const SizedBox(height: 2),
                                Text('Earn TZS 5,000 for every friend who joins', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                              ]),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
        ]),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SavingsPlan plan;
  const _PlanCard({required this.plan});

  Color _typeColor() {
    switch (plan.type) {
      case 'locked': return const Color(0xFF6366F1);
      case 'target': return AppColors.secondary;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(width: 4, height: 72, decoration: BoxDecoration(color: _typeColor(), borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(plan.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                const SizedBox(width: 8),
                Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: plan.status == 'active' ? AppColors.primary : AppColors.onSurfaceVariant)),
                const SizedBox(width: 4),
                Text(plan.status, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ]),
              const SizedBox(height: 2),
              Text('${plan.interestRate}% p.a.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Text(formatMoney(plan.currentAmount), style: moneyStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  const _TransactionTile({required this.transaction});

  IconData _icon() {
    switch (transaction.type) {
      case 'deposit': return Icons.arrow_downward;
      case 'withdrawal': return Icons.arrow_upward;
      case 'transfer': return Icons.swap_horiz;
      default: return Icons.receipt_long;
    }
  }

  Color _iconColor() {
    switch (transaction.type) {
      case 'deposit': return AppColors.primary;
      case 'withdrawal': return AppColors.error;
      default: return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefix = transaction.type == 'deposit' ? '+' : '-';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _iconColor().withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(_icon(), color: _iconColor(), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(transaction.type.replaceFirst(transaction.type[0], transaction.type[0].toUpperCase()), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
              Text(formatDate(transaction.createdAt), style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$prefix ${formatMoney(transaction.amount)}', style: moneyStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _iconColor())),
            Text(transaction.status, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
          ]),
        ]),
      ),
    );
  }
}

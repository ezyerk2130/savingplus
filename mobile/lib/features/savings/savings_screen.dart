import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/models/savings_plan.dart';
import '../../core/utils/formatters.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final ApiClient _api = ApiClient();

  List<SavingsPlan> _plans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/savings/plans');
      final list = (res.data as List<dynamic>?) ?? [];
      if (!mounted) return;
      setState(() {
        _plans = list.map((e) => SavingsPlan.fromJson(e as Map<String, dynamic>)).toList();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.error is ApiException ? e.error.toString() : 'Failed to load plans';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDepositSheet(SavingsPlan plan) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Deposit to ${plan.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: 'TZS ', labelText: 'Amount'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                try {
                  await _api.post('/savings/plans/${plan.id}/deposit', data: {
                    'amount': controller.text.trim(),
                  });
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deposit successful'), backgroundColor: Colors.green),
                  );
                  _loadPlans();
                } on DioException catch (e) {
                  final msg = e.error is ApiException ? e.error.toString() : 'Deposit failed';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              child: const Text('Deposit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawSheet(SavingsPlan plan) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Withdraw from ${plan.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Available: ${formatMoney(plan.currentAmount)}', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: 'TZS ', labelText: 'Amount'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                try {
                  await _api.post('/savings/plans/${plan.id}/withdraw', data: {
                    'amount': controller.text.trim(),
                  });
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Withdrawal successful'), backgroundColor: Colors.green),
                  );
                  _loadPlans();
                } on DioException catch (e) {
                  final msg = e.error is ApiException ? e.error.toString() : 'Withdrawal failed';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              child: const Text('Withdraw'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(SavingsPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Plan'),
        content: Text('Are you sure you want to cancel "${plan.name}"? Any locked funds will be returned.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.post('/savings/plans/${plan.id}/cancel');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Plan cancelled'), backgroundColor: Colors.green),
                );
                _loadPlans();
              } on DioException catch (e) {
                final msg = e.error is ApiException ? e.error.toString() : 'Cancel failed';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }
            },
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/savings/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPlans,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _plans.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 100),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.savings_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('No savings plans yet', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                            const SizedBox(height: 8),
                            const Text('Create one to start saving!'),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _plans.length,
                    itemBuilder: (context, i) => _planCard(_plans[i]),
                  ),
      ),
    );
  }

  Widget _planCard(SavingsPlan plan) {
    Color typeBadgeColor;
    switch (plan.type) {
      case 'locked':
        typeBadgeColor = Colors.orange;
        break;
      case 'target':
        typeBadgeColor = const Color(0xFF2563EB);
        break;
      default:
        typeBadgeColor = Colors.green;
    }

    double progress = 0;
    if (plan.targetAmount != null) {
      final target = double.tryParse(plan.targetAmount!) ?? 1;
      final current = double.tryParse(plan.currentAmount) ?? 0;
      progress = target > 0 ? (current / target).clamp(0, 1) : 0;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(plan.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeBadgeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    plan.type.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: typeBadgeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              formatMoney(plan.currentAmount),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (plan.targetAmount != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(typeBadgeColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Target: ${formatMoney(plan.targetAmount!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Rate: ${plan.interestRate}%',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                if (plan.maturityDate != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    'Matures: ${formatDate(plan.maturityDate!)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDepositSheet(plan),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Deposit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: plan.type == 'locked' ? null : () => _showWithdrawSheet(plan),
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    label: const Text('Withdraw'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: plan.status == 'active' ? () => _showCancelDialog(plan) : null,
                  icon: const Icon(Icons.cancel_outlined, size: 22),
                  color: Colors.red,
                  tooltip: 'Cancel plan',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

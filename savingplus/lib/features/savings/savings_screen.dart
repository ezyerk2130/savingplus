import 'package:flutter/material.dart';
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
  final _api = ApiClient.instance;
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
      if (!mounted) return;
      final data = res.data;
      final list = data is List ? data : (data is Map ? (data['plans'] ?? []) : []);
      setState(() {
        _plans = (list as List).map((e) => SavingsPlan.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.getErrorMessage(e))),
      );
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'flexible': return Colors.blue;
      case 'locked': return Colors.purple;
      case 'target': return Colors.teal;
      default: return Colors.grey;
    }
  }

  void _showActionSheet(SavingsPlan plan, String action) {
    final amountCtrl = TextEditingController();
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$action - ${plan.name}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (action != 'Cancel') ...[
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'TZS  ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (action == 'Cancel')
              const Text('Are you sure you want to cancel this savings plan?',
                  style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: action == 'Cancel'
                    ? FilledButton.styleFrom(backgroundColor: Colors.red)
                    : null,
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    if (action == 'Deposit') {
                      await _api.post('/savings/plans/${plan.id}/deposit', data: {
                        'amount': double.tryParse(amountCtrl.text) ?? 0,
                      });
                    } else if (action == 'Withdraw') {
                      await _api.post('/savings/plans/${plan.id}/withdraw', data: {
                        'amount': double.tryParse(amountCtrl.text) ?? 0,
                      });
                    } else if (action == 'Cancel') {
                      await _api.post('/savings/plans/${plan.id}/cancel');
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$action successful')),
                    );
                    _loadPlans();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiClient.getErrorMessage(e))),
                    );
                  }
                },
                child: Text(action == 'Cancel' ? 'Confirm Cancel' : action),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/savings/new');
          _loadPlans();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.savings_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('No savings plans yet', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () async {
                          await context.push('/savings/new');
                          _loadPlans();
                        },
                        child: const Text('Create your first plan'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPlans,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _plans.length,
                    itemBuilder: (context, index) {
                      final plan = _plans[index];
                      final typeColor = _typeColor(plan.type);
                      final current = double.tryParse(plan.currentAmount) ?? 0;
                      final target = double.tryParse(plan.targetAmount ?? '0') ?? 0;
                      final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(plan.name,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: typeColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(plan.type,
                                        style: TextStyle(color: typeColor, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(formatMoney(plan.currentAmount),
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              if (plan.type == 'target' && target > 0) ...[
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
                                          valueColor: AlwaysStoppedAnimation(typeColor),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('${(progress * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Target: ${formatMoney(plan.targetAmount)}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('Rate: ${plan.interestRate}% p.a.',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  if (plan.maturityDate != null) ...[
                                    const SizedBox(width: 16),
                                    Text('Matures: ${formatDate(plan.maturityDate)}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (plan.status == 'active')
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _showActionSheet(plan, 'Deposit'),
                                        child: const Text('Deposit'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _showActionSheet(plan, 'Withdraw'),
                                        child: const Text('Withdraw'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => _showActionSheet(plan, 'Cancel'),
                                      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                      tooltip: 'Cancel Plan',
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/models/wallet.dart';
import '../../core/utils/formatters.dart';

class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _api = ApiClient.instance;
  final _nameController = TextEditingController();
  final _initialAmountController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _autoDebitAmountController = TextEditingController();

  String _planType = 'flexible';
  int _lockDuration = 90;
  bool _autoDebit = false;
  String _autoDebitFrequency = 'daily';
  bool _isSubmitting = false;
  bool _isLoading = true;
  WalletBalance? _wallet;

  final _planTypes = [
    {'type': 'flexible', 'label': 'Flexible', 'rate': '4', 'desc': 'Withdraw anytime'},
    {'type': 'locked', 'label': 'Locked', 'rate': '8', 'desc': 'Higher returns, fixed term'},
    {'type': 'target', 'label': 'Target', 'rate': '6', 'desc': 'Save towards a goal'},
  ];

  final _lockDurations = [30, 60, 90, 180, 365];
  final _frequencies = ['daily', 'weekly', 'monthly'];

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final res = await _api.get('/wallet/balance');
      if (!mounted) return;
      setState(() {
        _wallet = WalletBalance.fromJson(res.data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _initialAmountController.dispose();
    _targetAmountController.dispose();
    _autoDebitAmountController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a plan name')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'type': _planType,
      };

      final initialAmount = double.tryParse(_initialAmountController.text.trim());
      if (initialAmount != null && initialAmount > 0) {
        data['initial_amount'] = initialAmount;
      }

      if (_planType == 'target') {
        final targetAmount = double.tryParse(_targetAmountController.text.trim());
        if (targetAmount != null && targetAmount > 0) {
          data['target_amount'] = targetAmount;
        }
      }

      if (_planType == 'locked') {
        data['lock_duration_days'] = _lockDuration;
      }

      if (_autoDebit) {
        final autoAmt = double.tryParse(_autoDebitAmountController.text.trim());
        if (autoAmt != null && autoAmt > 0) {
          data['auto_debit'] = true;
          data['auto_debit_amount'] = autoAmt;
          data['auto_debit_frequency'] = _autoDebitFrequency;
        }
      }

      await _api.post('/savings/plan', data: data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Savings plan created!')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.getErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('New Savings Plan')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_wallet != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Available: ${formatMoney(_wallet!.availableBalance)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600, color: primary),
                      ),
                    ),

                  const Text('Plan Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Emergency Fund',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text('Plan Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: _planTypes.map((pt) {
                      final isSelected = _planType == pt['type'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _planType = pt['type']!),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? primary : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                              color: isSelected ? primary.withOpacity(0.05) : null,
                            ),
                            child: Column(
                              children: [
                                Text(pt['label']!,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: isSelected ? primary : Colors.grey[700])),
                                const SizedBox(height: 4),
                                Text('${pt['rate']}% p.a.',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                const SizedBox(height: 2),
                                Text(pt['desc']!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  if (_planType == 'target') ...[
                    const Text('Target Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _targetAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        prefixText: 'TZS  ',
                        hintText: '0.00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (_planType == 'locked') ...[
                    const Text('Lock Duration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _lockDuration,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: _lockDurations
                          .map((d) => DropdownMenuItem(value: d, child: Text('$d days')))
                          .toList(),
                      onChanged: (v) => setState(() => _lockDuration = v!),
                    ),
                    const SizedBox(height: 20),
                  ],

                  const Text('Initial Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _initialAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixText: 'TZS  ',
                      hintText: '0.00 (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Auto-debit
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-debit', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Automatically save on a schedule'),
                    value: _autoDebit,
                    onChanged: (v) => setState(() => _autoDebit = v),
                  ),
                  if (_autoDebit) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _autoDebitAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Auto-debit Amount',
                        prefixText: 'TZS  ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _autoDebitFrequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                        border: OutlineInputBorder(),
                      ),
                      items: _frequencies
                          .map((f) => DropdownMenuItem(
                              value: f, child: Text(f[0].toUpperCase() + f.substring(1))))
                          .toList(),
                      onChanged: (v) => setState(() => _autoDebitFrequency = v!),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _handleCreate,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Create Plan', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

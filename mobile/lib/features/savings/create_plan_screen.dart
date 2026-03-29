import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';

class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final ApiClient _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _initialAmountController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _lockDurationController = TextEditingController();
  final _autoDebitAmountController = TextEditingController();

  String _type = 'flexible';
  bool _autoDebit = false;
  String _autoDebitFrequency = 'weekly';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _initialAmountController.dispose();
    _targetAmountController.dispose();
    _lockDurationController.dispose();
    _autoDebitAmountController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'type': _type,
        'initial_amount': _initialAmountController.text.trim(),
        'auto_debit': _autoDebit,
      };
      if (_type == 'target') {
        data['target_amount'] = _targetAmountController.text.trim();
      }
      if (_type == 'locked') {
        data['lock_duration_days'] = int.tryParse(_lockDurationController.text.trim()) ?? 30;
      }
      if (_autoDebit) {
        data['auto_debit_amount'] = _autoDebitAmountController.text.trim();
        data['auto_debit_frequency'] = _autoDebitFrequency;
      }

      await _api.post('/savings/plans', data: data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Savings plan created!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.error is ApiException ? e.error.toString() : 'Failed to create plan';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Savings Plan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Plan Name', hintText: 'e.g. Emergency Fund'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),
              const Text('Plan Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _typeSelector(),
              const SizedBox(height: 20),
              if (_type == 'target') ...[
                TextFormField(
                  controller: _targetAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(prefixText: 'TZS ', labelText: 'Target Amount'),
                  validator: (v) {
                    if (_type == 'target' && (v == null || v.trim().isEmpty)) return 'Target is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (_type == 'locked') ...[
                TextFormField(
                  controller: _lockDurationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Lock Duration (days)', hintText: 'e.g. 90'),
                  validator: (v) {
                    if (_type == 'locked' && (v == null || v.trim().isEmpty)) return 'Duration is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _initialAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(prefixText: 'TZS ', labelText: 'Initial Amount'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Initial amount is required';
                  final num = double.tryParse(v.trim());
                  if (num == null || num <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Auto-debit'),
                subtitle: const Text('Automatically save on a schedule'),
                value: _autoDebit,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _autoDebit = v),
              ),
              if (_autoDebit) ...[
                TextFormField(
                  controller: _autoDebitAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(prefixText: 'TZS ', labelText: 'Auto-debit Amount'),
                  validator: (v) {
                    if (_autoDebit && (v == null || v.trim().isEmpty)) return 'Amount required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _autoDebitFrequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (v) => setState(() => _autoDebitFrequency = v!),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreate,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeSelector() {
    final types = [
      {'value': 'flexible', 'label': 'Flexible', 'desc': 'Withdraw anytime'},
      {'value': 'locked', 'label': 'Locked', 'desc': 'Higher interest, fixed term'},
      {'value': 'target', 'label': 'Target', 'desc': 'Save towards a goal'},
    ];

    return Row(
      children: types.map((t) {
        final value = t['value'] as String;
        final isSelected = _type == value;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _type = value),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF2563EB) : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected ? const Color(0xFF2563EB).withOpacity(0.05) : null,
              ),
              child: Column(
                children: [
                  Text(
                    t['label'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF2563EB) : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t['desc'] as String,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

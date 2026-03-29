import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/models/loan.dart';
import '../../core/utils/formatters.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final ApiClient _api = ApiClient();
  final _amountController = TextEditingController();

  LoanEligibility? _eligibility;
  List<Loan> _loans = [];
  bool _isLoading = true;
  bool _isApplying = false;
  int _termDays = 30;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.get('/loans/eligibility'),
        _api.get('/loans'),
      ]);
      if (!mounted) return;
      setState(() {
        _eligibility = LoanEligibility.fromJson(results[0].data as Map<String, dynamic>);
        final list = (results[1].data as List<dynamic>?) ?? [];
        _loans = list.map((e) => Loan.fromJson(e as Map<String, dynamic>)).toList();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.error is ApiException ? e.error.toString() : 'Failed to load data';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _calculatedTotal {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final rate = double.tryParse(_eligibility?.interestRate ?? '0') ?? 0;
    return amount + (amount * rate / 100 * _termDays / 365);
  }

  Future<void> _applyLoan() async {
    if (_amountController.text.trim().isEmpty) return;

    setState(() => _isApplying = true);
    try {
      await _api.post('/loans/apply', data: {
        'amount': _amountController.text.trim(),
        'term_days': _termDays,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loan application submitted!'), backgroundColor: Colors.green),
      );
      _amountController.clear();
      _loadData();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.error is ApiException ? e.error.toString() : 'Application failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred')),
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  void _showRepaySheet(Loan loan) {
    final controller = TextEditingController();
    final remaining = (double.tryParse(loan.totalDue) ?? 0) - (double.tryParse(loan.amountPaid) ?? 0);
    controller.text = remaining.toStringAsFixed(2);

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
            const Text('Repay Loan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Loan ${loan.loanNumber}', style: TextStyle(color: Colors.grey[600])),
            Text('Remaining: ${formatMoney(remaining.toStringAsFixed(2))}',
                style: TextStyle(color: Colors.grey[600])),
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
                  await _api.post('/loans/${loan.id}/repay', data: {
                    'amount': controller.text.trim(),
                  });
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Repayment successful!'), backgroundColor: Colors.green),
                  );
                  _loadData();
                } on DioException catch (e) {
                  final msg = e.error is ApiException ? e.error.toString() : 'Repayment failed';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              child: const Text('Confirm Repayment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_eligibility != null) _buildEligibilityCard(),
                  const SizedBox(height: 20),
                  if (_eligibility != null && _eligibility!.eligible) _buildApplyForm(),
                  if (_eligibility != null && _eligibility!.eligible) const SizedBox(height: 24),
                  _buildLoansList(),
                ],
              ),
            ),
    );
  }

  Widget _buildEligibilityCard() {
    final e = _eligibility!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF102A43),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                e.eligible ? 'You are eligible for a loan' : 'Not yet eligible',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _eligibilityItem('Max Loan', formatMoney(e.maxLoanAmount)),
              _eligibilityItem('Interest', '${e.interestRate}%'),
              _eligibilityItem('Savings', formatMoney(e.savingsBalance)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eligibilityItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  Widget _buildApplyForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Apply for a Loan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: 'TZS ', labelText: 'Loan Amount'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            const Text('Term (days)', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [7, 14, 30, 60, 90].map((d) {
                final isSelected = _termDays == d;
                return ChoiceChip(
                  label: Text('$d days'),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2563EB).withOpacity(0.15),
                  onSelected: (_) => setState(() => _termDays = d),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (_amountController.text.trim().isNotEmpty)
              Text(
                'Total repayment: ${formatMoney(_calculatedTotal.toStringAsFixed(2))}',
                style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isApplying ? null : _applyLoan,
                child: _isApplying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Apply Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoansList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('My Loans', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (_loans.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text('No loans yet', style: TextStyle(color: Colors.grey[500])),
            ),
          )
        else
          ...List.generate(_loans.length, (i) => _loanCard(_loans[i])),
      ],
    );
  }

  Widget _loanCard(Loan loan) {
    Color statusColor;
    switch (loan.status) {
      case 'active':
      case 'disbursed':
        statusColor = Colors.green;
        break;
      case 'repaid':
        statusColor = const Color(0xFF2563EB);
        break;
      case 'defaulted':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    final totalDue = double.tryParse(loan.totalDue) ?? 1;
    final amountPaid = double.tryParse(loan.amountPaid) ?? 0;
    final progress = totalDue > 0 ? (amountPaid / totalDue).clamp(0.0, 1.0) : 0.0;

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
                  child: Text(loan.loanNumber, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    loan.status.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Principal: ${formatMoney(loan.principal)}', style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('Due: ${formatDate(loan.dueDate)}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
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
              '${formatMoney(loan.amountPaid)} / ${formatMoney(loan.totalDue)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            if (loan.status == 'active' || loan.status == 'disbursed') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showRepaySheet(loan),
                  child: const Text('Repay'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

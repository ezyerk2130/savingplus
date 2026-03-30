import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/models/loan.dart';
import '../../core/utils/formatters.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final _api = ApiClient.instance;
  final _amountController = TextEditingController();
  LoanEligibility? _eligibility;
  List<Loan> _loans = [];
  bool _isLoading = true;
  bool _isApplying = false;
  int _selectedTerm = 30;

  final _terms = [7, 14, 30, 60, 90];

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
      final loansData = results[1].data;
      final loansList = loansData is List ? loansData : (loansData is Map ? (loansData['loans'] ?? []) : []);
      setState(() {
        _eligibility = LoanEligibility.fromJson(results[0].data);
        _loans = (loansList as List).map((e) => Loan.fromJson(e)).toList();
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

  double _calculateTotal() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final rate = _eligibility?.interestRate ?? 0;
    final interest = amount * (rate / 100) * (_selectedTerm / 365);
    return amount + interest;
  }

  Future<void> _handleApply() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isApplying = true);
    try {
      await _api.post('/loans', data: {
        'amount': amount,
        'term_days': _selectedTerm,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loan application submitted!')),
      );
      _amountController.clear();
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.getErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  void _showRepaySheet(Loan loan) {
    final repayCtrl = TextEditingController();
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
            Text('Repay Loan #${loan.loanNumber}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Outstanding: ${formatMoney((double.tryParse(loan.totalDue) ?? 0) - (double.tryParse(loan.amountPaid) ?? 0))}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 16),
            TextField(
              controller: repayCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'TZS  ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await _api.post('/loans/${loan.id}/repay', data: {
                      'amount': double.tryParse(repayCtrl.text) ?? 0,
                    });
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Repayment successful!')),
                    );
                    _loadData();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiClient.getErrorMessage(e))),
                    );
                  }
                },
                child: const Text('Repay'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return Colors.blue;
      case 'approved': return Colors.green;
      case 'pending': return Colors.orange;
      case 'repaid': return Colors.teal;
      case 'defaulted': return Colors.red;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Eligibility card
                  if (_eligibility != null)
                    Container(
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
                              const Text('Loan Eligibility',
                                  style: TextStyle(color: Colors.white70, fontSize: 14)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (_eligibility!.eligible ? Colors.green : Colors.red).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _eligibility!.eligible ? 'Eligible' : 'Not Eligible',
                                  style: TextStyle(
                                    color: _eligibility!.eligible ? Colors.green[300] : Colors.red[300],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Max: ${formatMoney(_eligibility!.maxLoanAmount)}',
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('Rate: ${_eligibility!.interestRate}% p.a.',
                                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
                              const SizedBox(width: 20),
                              Text('Savings: ${formatMoney(_eligibility!.savingsBalance)}',
                                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Apply section
                  if (_eligibility?.eligible == true) ...[
                    const Text('Apply for Loan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Loan Amount',
                        prefixText: 'TZS  ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _selectedTerm,
                      decoration: const InputDecoration(labelText: 'Term', border: OutlineInputBorder()),
                      items: _terms.map((t) => DropdownMenuItem(value: t, child: Text('$t days'))).toList(),
                      onChanged: (v) => setState(() => _selectedTerm = v!),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Repayment', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(formatMoney(_calculateTotal()),
                              style: TextStyle(fontWeight: FontWeight.bold, color: primary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _isApplying ? null : _handleApply,
                        child: _isApplying
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Apply'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // My Loans
                  const Text('My Loans', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (_loans.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No loans yet', style: TextStyle(color: Colors.grey[500])),
                      ),
                    )
                  else
                    ...List.generate(_loans.length, (i) {
                      final loan = _loans[i];
                      final statusColor = _statusColor(loan.status);
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
                                    child: Text('Loan #${loan.loanNumber}',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(loan.status,
                                        style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Principal', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                        Text(formatMoney(loan.principal),
                                            style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Total Due', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                        Text(formatMoney(loan.totalDue),
                                            style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Paid', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                        Text(formatMoney(loan.amountPaid),
                                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Due: ${formatDate(loan.dueDate)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              if (loan.status == 'active' || loan.status == 'approved') ...[
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
                    }),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

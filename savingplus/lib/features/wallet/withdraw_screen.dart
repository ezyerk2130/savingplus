import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/api_client.dart';
import '../../core/models/wallet.dart';
import '../../core/utils/formatters.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _api = ApiClient.instance;
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String _selectedMethod = 'mpesa';
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showOtp = false;
  WalletBalance? _wallet;

  final _methods = [
    {'id': 'mpesa', 'label': 'M-Pesa', 'color': Colors.green},
    {'id': 'tigopesa', 'label': 'Tigo Pesa', 'color': Colors.blue},
    {'id': 'airtel', 'label': 'Airtel', 'color': Colors.red},
    {'id': 'halopesa', 'label': 'Halopesa', 'color': Colors.orange},
  ];

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.getErrorMessage(e))),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _pinController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleWithdraw() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }
    if (_pinController.text.trim().length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your 4-digit PIN')),
      );
      return;
    }
    if (_phoneController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final data = <String, dynamic>{
        'amount': amount,
        'pin': _pinController.text.trim(),
        'payment_method': _selectedMethod,
        'phone_number': _phoneController.text.trim(),
        'idempotency_key': const Uuid().v4(),
      };
      if (_showOtp && _otpController.text.trim().isNotEmpty) {
        data['otp'] = _otpController.text.trim();
      }
      await _api.post('/wallet/withdraw', data: data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal initiated successfully')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final msg = ApiClient.getErrorMessage(e);
      if (msg.toLowerCase().contains('otp') || msg.toLowerCase().contains('stepup')) {
        setState(() => _showOtp = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP required. Check your phone and enter the code.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Available balance
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text('Available Balance', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(formatMoney(_wallet?.availableBalance ?? '0'),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      prefixText: 'TZS  ',
                      hintText: '0.00',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text('PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      hintText: '****',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text('Payment Method', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.8,
                    children: _methods.map((m) {
                      final isSelected = _selectedMethod == m['id'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedMethod = m['id'] as String),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? primary : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            color: isSelected ? primary.withOpacity(0.05) : null,
                          ),
                          child: Center(
                            child: Text(m['label'] as String,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? primary : Colors.grey[700])),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  const Text('Phone Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+255 7XX XXX XXX',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  if (_showOtp) ...[
                    const SizedBox(height: 20),
                    const Text('OTP Code', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        hintText: '6-digit code',
                        prefixIcon: Icon(Icons.security),
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _handleWithdraw,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Withdraw', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

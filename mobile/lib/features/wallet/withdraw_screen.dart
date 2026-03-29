import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
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
  final ApiClient _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _otpController = TextEditingController();

  String _paymentMethod = 'mpesa';
  bool _isLoading = false;
  bool _showOtp = false;
  WalletBalance? _wallet;

  final _methods = [
    {'value': 'mpesa', 'label': 'M-Pesa'},
    {'value': 'tigopesa', 'label': 'Tigo Pesa'},
    {'value': 'airtel', 'label': 'Airtel Money'},
    {'value': 'halopesa', 'label': 'Halopesa'},
  ];

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final res = await _api.get('/wallet/balance');
      if (mounted) {
        setState(() {
          _wallet = WalletBalance.fromJson(res.data as Map<String, dynamic>);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleWithdraw() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final idempotencyKey = const Uuid().v4();
      final data = <String, dynamic>{
        'amount': _amountController.text.trim(),
        'payment_method': _paymentMethod,
        'phone': _phoneController.text.trim(),
        'pin': _pinController.text.trim(),
        'idempotency_key': idempotencyKey,
      };
      if (_showOtp && _otpController.text.trim().isNotEmpty) {
        data['otp'] = _otpController.text.trim();
      }

      await _api.post('/wallet/withdraw', data: data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Withdrawal initiated successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.error is ApiException ? e.error.toString() : 'Withdrawal failed';
      if (msg.contains('stepup_required') || msg.contains('OTP')) {
        setState(() => _showOtp = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent to your phone. Please enter it below.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
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
      appBar: AppBar(title: const Text('Withdraw')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_wallet != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Available Balance', style: TextStyle(color: Colors.grey)),
                      Text(
                        formatMoney(_wallet!.availableBalance),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  prefixText: 'TZS ',
                  hintText: '0.00',
                  labelText: 'Amount',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Amount is required';
                  final num = double.tryParse(v.trim());
                  if (num == null || num <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  hintText: '****',
                  prefixIcon: Icon(Icons.lock_outlined),
                  counterText: '',
                ),
                validator: (v) {
                  if (v == null || v.trim().length != 4) return 'Enter your 4-digit PIN';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Method',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _methods.map((m) {
                  final value = m['value'] as String;
                  final label = m['label'] as String;
                  final isSelected = _paymentMethod == value;
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2563EB).withOpacity(0.15),
                    onSelected: (_) => setState(() => _paymentMethod = value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+255XXXXXXXXX',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Phone number is required';
                  if (v.trim().length < 10) return 'Enter a valid phone number';
                  return null;
                },
              ),
              if (_showOtp) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'OTP Code',
                    hintText: '123456',
                    prefixIcon: Icon(Icons.security),
                    counterText: '',
                  ),
                  validator: (v) {
                    if (_showOtp && (v == null || v.trim().length != 6)) {
                      return 'Enter the 6-digit OTP';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleWithdraw,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Withdraw',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

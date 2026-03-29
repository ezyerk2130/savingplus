import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/transaction.dart';
import '../../core/models/user.dart';
import '../../core/models/wallet.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/formatters.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiClient _api = ApiClient();

  WalletBalance? _wallet;
  List<Transaction> _recentTransactions = [];
  bool _isLoading = true;
  bool _balanceVisible = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.get('/wallet/balance'),
        _api.get('/transactions', queryParameters: {'page': 1, 'page_size': 5}),
      ]);

      if (!mounted) return;
      setState(() {
        _wallet = WalletBalance.fromJson(results[0].data as Map<String, dynamic>);
        final txData = results[1].data as Map<String, dynamic>;
        _recentTransactions = (txData['transactions'] as List<dynamic>?)
                ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.error is ApiException ? e.error.toString() : 'Failed to load data';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          user != null ? 'Hi, ${user.fullName.split(' ').first}' : 'Home',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 20),
                  if (user != null && user.kycStatus != 'approved') _buildKycBanner(),
                  if (user != null && user.kycStatus != 'approved') const SizedBox(height: 20),
                  _buildQuickActions(),
                  const SizedBox(height: 20),
                  _buildServicesRow(),
                  const SizedBox(height: 24),
                  _buildRecentTransactions(),
                ],
              ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final balance = _wallet?.availableBalance ?? '0.00';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF102A43),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Balance',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _balanceVisible = !_balanceVisible),
                child: Icon(
                  _balanceVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white.withOpacity(0.7),
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _balanceVisible ? formatMoney(balance) : 'TZS ****',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (_wallet != null)
            Text(
              'Locked: ${_balanceVisible ? formatMoney(_wallet!.lockedBalance) : '****'}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKycBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Complete your KYC to unlock all features and higher limits.',
              style: TextStyle(color: Colors.orange[900], fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/kyc'),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _quickActionButton(Icons.add, 'Add Money', () => context.push('/deposit')),
        _quickActionButton(Icons.send, 'Send', () => context.push('/withdraw')),
        _quickActionButton(Icons.savings, 'Save', () => context.go('/savings')),
      ],
    );
  }

  Widget _quickActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesRow() {
    final services = [
      {'icon': Icons.trending_up, 'label': 'Invest', 'route': '/invest'},
      {'icon': Icons.group, 'label': 'Upatu', 'route': '/groups'},
      {'icon': Icons.shield, 'label': 'Insure', 'route': '/insurance'},
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final s = services[index];
          return GestureDetector(
            onTap: () {
              final route = s['route'] as String;
              if (route == '/invest') {
                context.go(route);
              } else {
                context.push(route);
              }
            },
            child: Container(
              width: 120,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(s['icon'] as IconData, color: const Color(0xFF2563EB), size: 28),
                  const SizedBox(height: 8),
                  Text(
                    s['label'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Transactions',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: () => context.go('/wallet'),
              child: const Text('See all'),
            ),
          ],
        ),
        if (_recentTransactions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No transactions yet',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          )
        else
          ...List.generate(_recentTransactions.length, (i) {
            final tx = _recentTransactions[i];
            return _transactionTile(tx);
          }),
      ],
    );
  }

  Widget _transactionTile(Transaction tx) {
    IconData icon;
    Color iconColor;
    switch (tx.type) {
      case 'deposit':
        icon = Icons.arrow_downward;
        iconColor = Colors.green;
        break;
      case 'withdrawal':
        icon = Icons.arrow_upward;
        iconColor = Colors.red;
        break;
      case 'savings_deposit':
      case 'savings_withdrawal':
        icon = Icons.savings;
        iconColor = const Color(0xFF2563EB);
        break;
      default:
        icon = Icons.swap_horiz;
        iconColor = Colors.grey;
    }

    final isCredit = tx.type == 'deposit' || tx.type == 'savings_withdrawal';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        tx.type.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        formatDate(tx.createdAt),
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
      trailing: Text(
        '${isCredit ? '+' : '-'}${formatMoney(tx.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: isCredit ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}

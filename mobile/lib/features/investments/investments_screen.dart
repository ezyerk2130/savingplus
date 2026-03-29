import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/models/investment.dart';
import '../../core/utils/formatters.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabController;

  List<InvestmentProduct> _products = [];
  List<Investment> _investments = [];
  bool _isLoadingProducts = true;
  bool _isLoadingInvestments = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProducts();
    _loadInvestments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final res = await _api.get('/investments/products');
      final list = (res.data as List<dynamic>?) ?? [];
      if (!mounted) return;
      setState(() {
        _products = list.map((e) => InvestmentProduct.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _loadInvestments() async {
    setState(() => _isLoadingInvestments = true);
    try {
      final res = await _api.get('/investments');
      final list = (res.data as List<dynamic>?) ?? [];
      if (!mounted) return;
      setState(() {
        _investments = list.map((e) => Investment.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingInvestments = false);
    }
  }

  void _showInvestSheet(InvestmentProduct product) {
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
            Text('Invest in ${product.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Min: ${formatMoney(product.minAmount)}', style: TextStyle(color: Colors.grey[600])),
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
                  await _api.post('/investments', data: {
                    'product_id': product.id,
                    'amount': controller.text.trim(),
                  });
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Investment placed!'), backgroundColor: Colors.green),
                  );
                  _loadInvestments();
                } on DioException catch (e) {
                  final msg = e.error is ApiException ? e.error.toString() : 'Investment failed';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              child: const Text('Confirm Investment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawSheet(Investment inv) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Withdraw Investment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Amount: ${formatMoney(inv.amount)}'),
            if (inv.actualReturn != null) Text('Return: ${formatMoney(inv.actualReturn!)}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _api.post('/investments/${inv.id}/withdraw');
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Withdrawal successful'), backgroundColor: Colors.green),
                  );
                  _loadInvestments();
                } on DioException catch (e) {
                  final msg = e.error is ApiException ? e.error.toString() : 'Withdrawal failed';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              child: const Text('Confirm Withdrawal'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investments'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Products'),
            Tab(text: 'My Investments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsTab(),
          _buildMyInvestmentsTab(),
        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    if (_isLoadingProducts) return const Center(child: CircularProgressIndicator());
    if (_products.isEmpty) {
      return Center(child: Text('No investment products available', style: TextStyle(color: Colors.grey[500])));
    }
    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        itemBuilder: (context, i) => _productCard(_products[i]),
      ),
    );
  }

  Widget _productCard(InvestmentProduct p) {
    Color riskColor;
    switch (p.riskLevel.toLowerCase()) {
      case 'low':
        riskColor = Colors.green;
        break;
      case 'medium':
        riskColor = Colors.orange;
        break;
      case 'high':
        riskColor = Colors.red;
        break;
      default:
        riskColor = Colors.grey;
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
                  child: Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    p.riskLevel.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: riskColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (p.description != null)
              Text(p.description!, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 12),
            Row(
              children: [
                _infoChip('Type', p.type),
                const SizedBox(width: 12),
                _infoChip('Return', '${p.expectedReturn}%'),
                const SizedBox(width: 12),
                _infoChip('Min', formatMoney(p.minAmount)),
                if (p.durationDays != null) ...[
                  const SizedBox(width: 12),
                  _infoChip('Duration', '${p.durationDays}d'),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showInvestSheet(p),
                child: const Text('Invest'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildMyInvestmentsTab() {
    if (_isLoadingInvestments) return const Center(child: CircularProgressIndicator());
    if (_investments.isEmpty) {
      return Center(child: Text('No investments yet', style: TextStyle(color: Colors.grey[500])));
    }
    return RefreshIndicator(
      onRefresh: _loadInvestments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _investments.length,
        itemBuilder: (context, i) => _investmentCard(_investments[i]),
      ),
    );
  }

  Widget _investmentCard(Investment inv) {
    Color statusColor;
    switch (inv.status) {
      case 'active':
        statusColor = Colors.green;
        break;
      case 'matured':
        statusColor = const Color(0xFF2563EB);
        break;
      case 'withdrawn':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.orange;
    }

    final canWithdraw = inv.status == 'matured' || inv.productType == 'money_market';

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
                  child: Text(inv.productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    inv.status.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invested', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    Text(formatMoney(inv.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Expected Return', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    Text('${inv.expectedReturn}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            if (inv.maturityDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Matures: ${formatDate(inv.maturityDate!)}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
            if (canWithdraw) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showWithdrawSheet(inv),
                  child: const Text('Withdraw'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

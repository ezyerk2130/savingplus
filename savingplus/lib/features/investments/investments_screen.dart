import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/models/investment.dart';
import '../../core/utils/formatters.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiClient.instance;
  late TabController _tabController;
  List<InvestmentProduct> _products = [];
  List<Investment> _myInvestments = [];
  bool _loadingProducts = true;
  bool _loadingInvestments = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _loadProducts();
    _loadInvestments();
  }

  Future<void> _loadProducts() async {
    try {
      final res = await _api.get('/investments/products');
      if (!mounted) return;
      final data = res.data;
      final list = data is List ? data : (data is Map ? (data['products'] ?? []) : []);
      setState(() {
        _products = (list as List).map((e) => InvestmentProduct.fromJson(e)).toList();
        _loadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingProducts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.getErrorMessage(e))),
      );
    }
  }

  Future<void> _loadInvestments() async {
    try {
      final res = await _api.get('/investments');
      if (!mounted) return;
      final data = res.data;
      final list = data is List ? data : (data is Map ? (data['investments'] ?? []) : []);
      setState(() {
        _myInvestments = (list as List).map((e) => Investment.fromJson(e)).toList();
        _loadingInvestments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingInvestments = false);
    }
  }

  Color _riskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'low': return Colors.green;
      case 'medium': return Colors.orange;
      case 'high': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'matured': return Colors.blue;
      case 'withdrawn': return Colors.grey;
      default: return Colors.orange;
    }
  }

  void _showInvestSheet(InvestmentProduct product) {
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
            Text('Invest in ${product.name}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Min: ${formatMoney(product.minAmount)} | Return: ${product.expectedReturn}%',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 16),
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
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await _api.post('/investments', data: {
                      'product_id': product.id,
                      'amount': double.tryParse(amountCtrl.text) ?? 0,
                    });
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Investment successful!')),
                    );
                    _loadInvestments();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiClient.getErrorMessage(e))),
                    );
                  }
                },
                child: const Text('Invest Now'),
              ),
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
          children: [
            Text('Withdraw Investment',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Amount: ${formatMoney(inv.amount)}', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await _api.post('/investments/${inv.id}/withdraw');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Withdrawal successful!')),
                    );
                    _loadInvestments();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiClient.getErrorMessage(e))),
                    );
                  }
                },
                child: const Text('Confirm Withdrawal'),
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
          // Products tab
          _loadingProducts
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty
                  ? Center(child: Text('No products available', style: TextStyle(color: Colors.grey[500])))
                  : RefreshIndicator(
                      onRefresh: _loadProducts,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final p = _products[index];
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
                                        child: Text(p.name,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(p.type,
                                            style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(p.description, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _InfoChip('Return', '${p.expectedReturn}%', Colors.green),
                                      const SizedBox(width: 8),
                                      _InfoChip('Risk', p.riskLevel, _riskColor(p.riskLevel)),
                                      const SizedBox(width: 8),
                                      _InfoChip('Min', formatMoney(p.minAmount), Colors.grey),
                                      if (p.durationDays != null) ...[
                                        const SizedBox(width: 8),
                                        _InfoChip('Days', '${p.durationDays}', Colors.grey),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: () => _showInvestSheet(p),
                                      child: const Text('Invest'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

          // My Investments tab
          _loadingInvestments
              ? const Center(child: CircularProgressIndicator())
              : _myInvestments.isEmpty
                  ? Center(child: Text('No investments yet', style: TextStyle(color: Colors.grey[500])))
                  : RefreshIndicator(
                      onRefresh: _loadInvestments,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _myInvestments.length,
                        itemBuilder: (context, index) {
                          final inv = _myInvestments[index];
                          final statusColor = _statusColor(inv.status);
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
                                        child: Text(inv.productName ?? 'Investment',
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(inv.status,
                                            style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(formatMoney(inv.amount),
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text('Return: ${inv.expectedReturn}%',
                                          style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                      if (inv.maturityDate != null) ...[
                                        const SizedBox(width: 16),
                                        Text('Matures: ${formatDate(inv.maturityDate)}',
                                            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                      ],
                                    ],
                                  ),
                                  if (inv.status == 'matured' || inv.productType == 'money_market') ...[
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
                        },
                      ),
                    ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $value',
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

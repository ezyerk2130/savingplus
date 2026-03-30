import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/models/insurance.dart';
import '../../core/utils/formatters.dart';

class InsuranceScreen extends StatefulWidget {
  const InsuranceScreen({super.key});

  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen> with SingleTickerProviderStateMixin {
  final _api = ApiClient.instance;
  late TabController _tabController;
  List<InsuranceProduct> _products = [];
  List<InsurancePolicy> _policies = [];
  bool _loadingProducts = true;
  bool _loadingPolicies = true;

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
    _loadPolicies();
  }

  Future<void> _loadProducts() async {
    try {
      final res = await _api.get('/insurance/products');
      if (!mounted) return;
      final data = res.data;
      final list = data is List ? data : (data is Map ? (data['products'] ?? []) : []);
      setState(() {
        _products = (list as List).map((e) => InsuranceProduct.fromJson(e)).toList();
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

  Future<void> _loadPolicies() async {
    try {
      final res = await _api.get('/insurance/policies');
      if (!mounted) return;
      final data = res.data;
      final list = data is List ? data : (data is Map ? (data['policies'] ?? []) : []);
      setState(() {
        _policies = (list as List).map((e) => InsurancePolicy.fromJson(e)).toList();
        _loadingPolicies = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPolicies = false);
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'health': return Colors.red;
      case 'life': return Colors.blue;
      case 'property': return Colors.green;
      case 'education': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'pending': return Colors.orange;
      case 'cancelled': return Colors.red;
      case 'expired': return Colors.grey;
      default: return Colors.grey;
    }
  }

  void _showSubscribeSheet(InsuranceProduct product) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

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
            Text('Subscribe to ${product.name}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Premium: ${formatMoney(product.premiumAmount)}/${product.premiumFrequency}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            Text('Coverage: ${formatMoney(product.coverageAmount)}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Beneficiary Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Beneficiary Phone',
                hintText: '+255 7XX XXX XXX',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill in beneficiary details')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await _api.post('/insurance/subscribe', data: {
                      'product_id': product.id,
                      'beneficiary_name': nameCtrl.text.trim(),
                      'beneficiary_phone': phoneCtrl.text.trim(),
                    });
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Subscribed successfully!')),
                    );
                    _loadPolicies();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiClient.getErrorMessage(e))),
                    );
                  }
                },
                child: const Text('Subscribe'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelPolicy(InsurancePolicy policy) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Policy'),
        content: Text('Are you sure you want to cancel policy ${policy.policyNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Policy'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.post('/insurance/policies/${policy.id}/cancel');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Policy cancelled')),
      );
      _loadPolicies();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.getErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insurance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Products'),
            Tab(text: 'My Policies'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Products
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
                          final typeColor = _typeColor(p.type);
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
                                          color: typeColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(p.type,
                                            style: TextStyle(fontSize: 11, color: typeColor, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(p.description, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Text('Provider: ${p.provider}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text('Premium: ${formatMoney(p.premiumAmount)}/${p.premiumFrequency}',
                                          style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                                    ],
                                  ),
                                  Text('Coverage: ${formatMoney(p.coverageAmount)}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: () => _showSubscribeSheet(p),
                                      child: const Text('Subscribe'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

          // My Policies
          _loadingPolicies
              ? const Center(child: CircularProgressIndicator())
              : _policies.isEmpty
                  ? Center(child: Text('No policies yet', style: TextStyle(color: Colors.grey[500])))
                  : RefreshIndicator(
                      onRefresh: _loadPolicies,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _policies.length,
                        itemBuilder: (context, index) {
                          final p = _policies[index];
                          final statusColor = _statusColor(p.status);
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
                                        child: Text(p.productName ?? 'Policy',
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(p.status,
                                            style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Policy #${p.policyNumber}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                  const SizedBox(height: 4),
                                  Text('Coverage: ${formatDate(p.coverageStart)} - ${formatDate(p.coverageEnd)}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                  if (p.status == 'active') ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                        onPressed: () => _cancelPolicy(p),
                                        child: const Text('Cancel Policy'),
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

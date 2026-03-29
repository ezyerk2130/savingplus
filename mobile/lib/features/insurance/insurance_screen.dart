import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/models/insurance.dart';
import '../../core/utils/formatters.dart';

class InsuranceScreen extends StatefulWidget {
  const InsuranceScreen({super.key});

  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen> with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabController;

  List<InsuranceProduct> _products = [];
  List<InsurancePolicy> _policies = [];
  bool _isLoadingProducts = true;
  bool _isLoadingPolicies = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProducts();
    _loadPolicies();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final res = await _api.get('/insurance/products');
      final list = (res.data as List<dynamic>?) ?? [];
      if (!mounted) return;
      setState(() {
        _products = list.map((e) => InsuranceProduct.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _loadPolicies() async {
    setState(() => _isLoadingPolicies = true);
    try {
      final res = await _api.get('/insurance/policies');
      final list = (res.data as List<dynamic>?) ?? [];
      if (!mounted) return;
      setState(() {
        _policies = list.map((e) => InsurancePolicy.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingPolicies = false);
    }
  }

  void _showSubscribeSheet(InsuranceProduct product) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Subscribe to ${product.name}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Premium: ${formatMoney(product.premiumAmount)} / ${product.premiumFrequency}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              Text(
                'Coverage: ${formatMoney(product.coverageAmount)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              const Text('Beneficiary Details',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Beneficiary Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Beneficiary Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationController,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  hintText: 'e.g. Spouse, Child, Parent',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty ||
                      phoneController.text.trim().isEmpty ||
                      relationController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill in all beneficiary fields')),
                    );
                    return;
                  }
                  try {
                    await _api.post('/insurance/subscribe', data: {
                      'product_id': product.id,
                      'beneficiary_name': nameController.text.trim(),
                      'beneficiary_phone': phoneController.text.trim(),
                      'beneficiary_relationship': relationController.text.trim(),
                    });
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Subscribed successfully!'), backgroundColor: Colors.green),
                    );
                    _loadPolicies();
                  } on DioException catch (e) {
                    final msg = e.error is ApiException ? e.error.toString() : 'Subscription failed';
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  }
                },
                child: const Text('Subscribe'),
              ),
            ],
          ),
        ),
      ),
    );
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
          _buildProductsTab(),
          _buildPoliciesTab(),
        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    if (_isLoadingProducts) return const Center(child: CircularProgressIndicator());
    if (_products.isEmpty) {
      return Center(child: Text('No insurance products available', style: TextStyle(color: Colors.grey[500])));
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

  Widget _productCard(InsuranceProduct p) {
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
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    p.type.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(p.provider, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            if (p.description != null) ...[
              const SizedBox(height: 6),
              Text(p.description!, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _infoChip('Premium', '${formatMoney(p.premiumAmount)}/${p.premiumFrequency}'),
                const SizedBox(width: 16),
                _infoChip('Coverage', formatMoney(p.coverageAmount)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showSubscribeSheet(p),
                child: const Text('Subscribe'),
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

  Widget _buildPoliciesTab() {
    if (_isLoadingPolicies) return const Center(child: CircularProgressIndicator());
    if (_policies.isEmpty) {
      return Center(child: Text('No policies yet', style: TextStyle(color: Colors.grey[500])));
    }
    return RefreshIndicator(
      onRefresh: _loadPolicies,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _policies.length,
        itemBuilder: (context, i) => _policyCard(_policies[i]),
      ),
    );
  }

  Widget _policyCard(InsurancePolicy p) {
    Color statusColor;
    switch (p.status) {
      case 'active':
        statusColor = Colors.green;
        break;
      case 'expired':
        statusColor = Colors.red;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.orange;
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
                  child: Text(p.productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    p.status.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Policy: ${p.policyNumber}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text('Type: ${p.productType}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Coverage: ${formatDate(p.coverageStart)} - ${formatDate(p.coverageEnd)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

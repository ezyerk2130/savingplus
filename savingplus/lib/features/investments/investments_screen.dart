import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/models/investment.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/theme.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  final _api = ApiClient.instance;
  List<InvestmentProduct> _products = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'All';

  final _filters = ['All', 'Low risk', 'Medium risk', 'High risk'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await _api.get('/investments/products');
      if (!mounted) return;
      final data = res.data;
      final list = data is List ? data : (data is Map ? (data['products'] ?? []) : []);
      setState(() {
        _products = (list as List).map((e) => InvestmentProduct.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = ApiClient.getErrorMessage(e); });
    }
  }

  List<InvestmentProduct> get _filteredProducts {
    if (_selectedFilter == 'All') return _products;
    final risk = _selectedFilter.replaceAll(' risk', '').toLowerCase();
    return _products.where((p) => p.riskLevel.toLowerCase() == risk).toList();
  }

  Color _riskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'low': return AppColors.primary;
      case 'medium': return const Color(0xFFFF9800);
      case 'high': return AppColors.error;
      default: return AppColors.onSurfaceVariant;
    }
  }

  String _riskLabel(String risk) {
    switch (risk.toLowerCase()) {
      case 'low': return 'LOW RISK';
      case 'medium': return 'MEDIUM RISK';
      case 'high': return 'HIGH RISK';
      default: return risk.toUpperCase();
    }
  }

  void _showInvestSheet(InvestmentProduct product) {
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invest in ${product.name}',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Min: ${formatMoney(product.minAmount)} \u2022 Return: ${product.expectedReturn}%',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 20),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount', prefixText: 'TZS  '),
            ),
            const SizedBox(height: 20),
            GradientButton(
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
                  _loadProducts();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiClient.getErrorMessage(e))));
                }
              },
              child: const Text('Invest Now'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bar_chart, color: AppColors.primary, size: 20),
          ),
        ),
        title: Text('Investify TZ',
            style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text('SWAHILI',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProducts,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 12),

                  // Warning banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFE0B2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFE65100)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Investments carry risk. Past performance is not indicative of future returns.',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFE65100))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Hero card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Grow Wealth',
                            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Secure opportunities tailored for Tanzanian investors',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Filter chips
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      itemBuilder: (ctx, i) {
                        final f = _filters[i];
                        final selected = _selectedFilter == f;
                        return Padding(
                          padding: EdgeInsets.only(right: i < _filters.length - 1 ? 8 : 0),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedFilter = f),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary : AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: selected ? AppColors.primary : AppColors.ghostBorder),
                              ),
                              child: Text(f,
                                  style: GoogleFonts.inter(
                                    fontSize: 13, fontWeight: FontWeight.w500,
                                    color: selected ? Colors.white : AppColors.onSurfaceVariant,
                                  )),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                      child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13)),
                    ),

                  if (_filteredProducts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: Text('No products available',
                          style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurfaceVariant))),
                    ),

                  // Product cards
                  ..._filteredProducts.map((p) => _buildProductCard(p)),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildProductCard(InvestmentProduct p) {
    final riskColor = _riskColor(p.riskLevel);
    final fundedPercent = 0.68; // simulated
    final fundedAmount = 340000000.0;
    final totalAmount = 500000000.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + risk badge
          Row(
            children: [
              Expanded(
                child: Text(p.name,
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_riskLabel(p.riskLevel),
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: riskColor, letterSpacing: 0.3)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Provider
          Row(
            children: [
              Icon(Icons.account_balance, size: 14, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(p.description.length > 40 ? '${p.description.substring(0, 40)}...' : p.description,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 16),

          // Return + duration
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ANNUALIZED RETURN',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text('${p.expectedReturn}%',
                        style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
              ),
              if (p.durationDays != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('DURATION',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text('${p.durationDays} days',
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Funded progress bar
          Row(
            children: [
              Text('${(fundedPercent * 100).round()}% funded',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
              const Spacer(),
              Text('${formatMoney(fundedAmount).replaceAll('.00', '')} / ${formatMoney(totalAmount).replaceAll('.00', '')}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fundedPercent,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),

          // Min investment
          Text('${formatMoney(p.minAmount)} minimum investment',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 14),

          // Invest button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => _showInvestSheet(p),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: const StadiumBorder(),
                foregroundColor: AppColors.primary,
              ),
              child: Text('Invest now', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

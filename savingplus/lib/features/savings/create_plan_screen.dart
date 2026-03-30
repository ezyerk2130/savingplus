import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/theme.dart';

class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _api = ApiClient.instance;
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  DateTime _targetDate = DateTime.now().add(const Duration(days: 270));
  bool _addCoSavers = false;
  bool _isSubmitting = false;
  String? _error;
  int _selectedCategory = 4; // Home selected by default

  final _categories = [
    {'icon': Icons.school, 'label': 'School fees', 'color': Color(0xFF2196F3)},
    {'icon': Icons.favorite, 'label': 'Medical', 'color': Color(0xFFF44336)},
    {'icon': Icons.business_center, 'label': 'Business', 'color': Color(0xFFFF9800)},
    {'icon': Icons.phone_android, 'label': 'Phone/gadget', 'color': Color(0xFF9C27B0)},
    {'icon': Icons.home, 'label': 'Home', 'color': Color(0xFF4CAF50)},
    {'icon': Icons.castle, 'label': 'Wedding', 'color': Color(0xFFE91E63)},
    {'icon': Icons.savings, 'label': 'Emergency', 'color': Color(0xFF607D8B)},
    {'icon': Icons.flight, 'label': 'Travel', 'color': Color(0xFFF44336)},
    {'icon': Icons.add, 'label': 'Custom', 'color': Color(0xFF9E9E9E)},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  double get _targetAmount {
    final text = _targetAmountController.text.replaceAll(',', '').replaceAll(' ', '');
    return double.tryParse(text) ?? 0;
  }

  int get _weeksRemaining {
    final days = _targetDate.difference(DateTime.now()).inDays;
    return (days / 7).ceil().clamp(1, 9999);
  }

  double get _weeklyAmount => _targetAmount > 0 ? _targetAmount / _weeksRemaining : 0;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now().add(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _handleCreate() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a goal name');
      return;
    }
    if (_targetAmount <= 0) {
      setState(() => _error = 'Please enter a target amount');
      return;
    }

    setState(() { _isSubmitting = true; _error = null; });
    try {
      await _api.post('/savings/plan', data: {
        'name': _nameController.text.trim(),
        'type': 'target',
        'target_amount': _targetAmount,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal created successfully!')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ApiClient.getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        title: Text('Create a goal', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            Text('What are you saving for?',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
            const SizedBox(height: 16),

            // 3x3 category grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.0,
              ),
              itemCount: _categories.length,
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final selected = _selectedCategory == i;
                final color = cat['color'] as Color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.08) : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.ghostBorder,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(cat['icon'] as IconData, color: color, size: 24),
                              ),
                              const SizedBox(height: 8),
                              Text(cat['label'] as String,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
                            ],
                          ),
                        ),
                        if (selected)
                          Positioned(
                            top: 8, right: 8,
                            child: Container(
                              width: 20, height: 20,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                              child: const Icon(Icons.check, size: 14, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Goal name
            Text('Goal name', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'e.g. Dream House'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            // Target amount
            Text('Target amount', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
            const SizedBox(height: 8),
            TextField(
              controller: _targetAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: 'TZS  ', hintText: '0'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            // Target date
            Text('Target date', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.ghostBorder),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(DateFormat('dd MMM yyyy').format(_targetDate),
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.onBackground))),
                    const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Add co-savers toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.ghostBorder),
              ),
              child: Row(
                children: [
                  Expanded(child: Text('Add co-savers',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onBackground))),
                  Switch(
                    value: _addCoSavers,
                    onChanged: (v) => setState(() => _addCoSavers = v),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Preview card
            if (_targetAmount > 0 && _nameController.text.trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('PREVIEW',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant, letterSpacing: 0.5)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text('BEST RATE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Save ${formatMoney(_weeklyAmount).replaceAll('.00', '')}/week to reach your goal by ${DateFormat('MMMM yyyy').format(_targetDate)}',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onBackground, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, size: 18, color: Color(0xFFFFB300)),
                        const SizedBox(width: 6),
                        Text('Earning 10% p.a. while you save',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13)),
              ),
              const SizedBox(height: 16),
            ],

            GradientButton(
              onPressed: _isSubmitting ? null : _handleCreate,
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Create goal'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/theme.dart';

class AutoSaveDetailScreen extends StatefulWidget {
  final String planId;

  const AutoSaveDetailScreen({super.key, required this.planId});

  @override
  State<AutoSaveDetailScreen> createState() => _AutoSaveDetailScreenState();
}

class _AutoSaveDetailScreenState extends State<AutoSaveDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _plan;
  List<dynamic> _transactions = [];
  bool _isPausing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await ApiClient.instance.get('/savings/plans/${widget.planId}');
      _plan = res.data is Map<String, dynamic> ? res.data : (res.data['plan'] ?? {});

      try {
        final txRes = await ApiClient.instance.get('/savings/plans/${widget.planId}/transactions');
        _transactions = txRes.data is List ? txRes.data : (txRes.data['transactions'] ?? []);
      } catch (_) {
        _transactions = [];
      }
    } catch (e) {
      _error = ApiClient.getErrorMessage(e, 'Failed to load plan');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePause() async {
    setState(() => _isPausing = true);
    try {
      final isActive = (_plan?['status'] ?? 'active') == 'active';
      await ApiClient.instance.post('/savings/plans/${widget.planId}/${isActive ? 'pause' : 'resume'}');
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.getErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isPausing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = (_plan?['status'] ?? 'active') == 'active';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        title: Text('Daily AutoSave', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600)),
        actions: [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {})],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: GoogleFonts.inter(color: AppColors.error)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // Green gradient balance card
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
                              // Status pill + title row
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6, height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isActive ? AppColors.primary : AppColors.warning,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(isActive ? 'ACTIVE' : 'PAUSED',
                                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                                                color: isActive ? AppColors.primary : AppColors.warning)),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text('Daily AutoSave',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.8))),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Balance
                              Text('Current Balance',
                                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                              const SizedBox(height: 4),
                              Text(
                                formatMoney(_plan?['current_amount'] ?? _plan?['balance'] ?? 0),
                                style: moneyStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              const SizedBox(height: 16),

                              // Progress section
                              Row(
                                children: [
                                  Text('PROGRESS TO 31 MAR WITHDRAWAL',
                                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(alpha: 0.7), letterSpacing: 0.5)),
                                  const Spacer(),
                                  Text('65%',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: 0.65,
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Divider
                              Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                              const SizedBox(height: 12),

                              // Next deduction
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                                  const SizedBox(width: 8),
                                  Text('Next deduction in 6 hours',
                                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Pause button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _isPausing ? null : _togglePause,
                            icon: _isPausing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(
                                    isActive ? Icons.pause : Icons.play_arrow,
                                    size: 18,
                                    color: isActive ? AppColors.error : AppColors.primary,
                                  ),
                            label: Text(isActive ? 'Pause AutoSave' : 'Resume AutoSave'),
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              side: BorderSide(color: isActive ? AppColors.error.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.3)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Change daily amount link
                        Center(
                          child: TextButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                            label: Text('Change Daily Amount',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Recent activity
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Recent Activity',
                                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                            TextButton(
                              onPressed: () {},
                              child: Text('VIEW ALL', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_transactions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('No transactions yet',
                                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant)),
                            ),
                          )
                        else
                          ...(_transactions.take(5).map((tx) => _buildTransactionItem(tx))),

                        const SizedBox(height: 24),

                        // Language toggle
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('LANGUAGE \u2022 ', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                              Text('ENG', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                              Text(' ', style: GoogleFonts.inter(fontSize: 12)),
                              Text('SWA', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildTransactionItem(dynamic tx) {
    final amount = tx['amount'] ?? 0;
    final date = formatDate(tx['created_at']?.toString());
    final status = (tx['status'] ?? 'success').toString().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ghostBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_circle_down, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deduction', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
                Text(date, style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+ ${formatMoney(amount)}',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(status,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

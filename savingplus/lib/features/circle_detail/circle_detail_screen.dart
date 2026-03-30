import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/theme.dart';

class CircleDetailScreen extends StatefulWidget {
  final String groupId;

  const CircleDetailScreen({super.key, required this.groupId});

  @override
  State<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends State<CircleDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _group;
  List<dynamic> _members = [];
  bool _isContributing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.get('/groups/${widget.groupId}');
      _group = res.data is Map<String, dynamic> ? res.data : (res.data['group'] ?? {});
      _members = _group?['members'] ?? [];
    } catch (e) {
      _error = ApiClient.getErrorMessage(e, 'Failed to load group');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _makeContribution() async {
    setState(() => _isContributing = true);
    try {
      await ApiClient.instance.post('/groups/${widget.groupId}/contribute');
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contribution successful!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.getErrorMessage(e, 'Contribution failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isContributing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _group?['name'] ?? 'Circle Group';
    final contributionAmount = _group?['contribution_amount'] ?? 5000;
    final totalPot = _group?['total_pot'] ?? 40000;
    final cycleCount = _group?['cycle_count'] ?? 8;
    final currentCycle = _group?['current_cycle'] ?? 3;
    final progress = cycleCount > 0 ? (currentCycle / cycleCount) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        title: Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text('ENG', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
          ),
          IconButton(icon: const Icon(Icons.settings_outlined, size: 20), onPressed: () {}),
        ],
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

                        // Summary card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.ghostBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cycle $currentCycle of $cycleCount',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
                              const SizedBox(height: 4),
                              Text('${formatMoney(contributionAmount)}/week contribution',
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
                              const SizedBox(height: 4),
                              Text('Total pot ${formatMoney(totalPot)}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onBackground)),
                              const SizedBox(height: 16),

                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress.toDouble(),
                                  backgroundColor: AppColors.surfaceContainerLow,
                                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('STARTED JAN 2026',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
                                  Text('${(progress * 100).round()}% COMPLETE',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Next payout
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primary,
                                child: Text('RJ', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Next payout',
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                                    Text('Rehema Juma \u2014 5 April 2026',
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Current cycle status
                        Row(
                          children: [
                            Text('Current Cycle Status',
                                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text('Week $currentCycle',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Your contribution status
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: AppGradients.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('You: PAID',
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                    const SizedBox(height: 2),
                                    Text('Confirmed on 22 Mar',
                                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                                  ],
                                ),
                              ),
                              Text(formatMoney(contributionAmount),
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Members list
                        ..._buildMemberList(),

                        const SizedBox(height: 24),

                        // Payout rotation
                        Text('Payout rotation',
                            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                        const SizedBox(height: 12),
                        _buildPayoutTimeline(),

                        const SizedBox(height: 24),

                        // Action buttons
                        GradientButton(
                          onPressed: _isContributing ? null : _makeContribution,
                          child: _isContributing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Make contribution'),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.person_add_outlined, size: 18),
                            label: const Text('Invite member'),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  List<Widget> _buildMemberList() {
    final demoMembers = _members.isNotEmpty
        ? _members
        : [
            {'name': 'Fatma Hassan', 'status': 'paid'},
            {'name': 'John Mushi', 'status': 'paid'},
            {'name': 'Grace Kimaro', 'status': 'due'},
            {'name': 'Ali Bakari', 'status': 'due'},
          ];

    return demoMembers.map<Widget>((m) {
      final name = m['name'] ?? m['full_name'] ?? 'Member';
      final status = (m['status'] ?? 'due').toString().toUpperCase();
      final isPaid = status == 'PAID';
      final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

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
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surfaceContainerLow,
              child: Text(initials, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isPaid ? AppColors.primary.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                status,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isPaid ? AppColors.primary : AppColors.warning),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildPayoutTimeline() {
    final List<Map<String, String>> rotationMembers = [
      {'name': 'You', 'position': '1', 'phone': '0744 XXX', 'status': 'RECEIVED'},
      {'name': 'Fatma Hassan', 'position': '2', 'phone': '0745 XXX', 'status': 'RECEIVED'},
      {'name': 'Rehema Juma', 'position': '3', 'phone': '0746 XXX', 'status': 'NEXT'},
      {'name': 'John Mushi', 'position': '4', 'phone': '0747 XXX', 'status': 'PENDING'},
      {'name': 'Grace Kimaro', 'position': '5', 'phone': '0748 XXX', 'status': 'PENDING'},
    ];

    return Column(
      children: rotationMembers.asMap().entries.map((entry) {
        final idx = entry.key;
        final m = entry.value;
        final isLast = idx == rotationMembers.length - 1;
        final status = m['status']!;

        Color dotColor;
        switch (status) {
          case 'RECEIVED':
            dotColor = AppColors.primary;
            break;
          case 'NEXT':
            dotColor = AppColors.warning;
            break;
          default:
            dotColor = AppColors.surfaceContainerHigh;
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                        border: Border.all(color: dotColor, width: 2),
                      ),
                      child: status == 'RECEIVED'
                          ? const Icon(Icons.check, size: 10, color: Colors.white)
                          : null,
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: AppColors.surfaceContainerHigh,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: status == 'NEXT' ? AppColors.warning.withValues(alpha: 0.06) : AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: status == 'NEXT' ? AppColors.warning.withValues(alpha: 0.2) : AppColors.ghostBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.surfaceContainerLow,
                        child: Text(
                          m['name']!.split(' ').map((w) => w[0]).take(2).join(),
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onBackground),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['name']!, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
                            Text('#${m['position']} \u2022 ${m['phone']}',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: dotColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: dotColor == AppColors.surfaceContainerHigh ? AppColors.onSurfaceVariant : dotColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

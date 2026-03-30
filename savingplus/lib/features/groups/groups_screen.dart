import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/models/group.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/theme.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _api = ApiClient.instance;
  List<SavingsGroup> _groups = [];
  bool _isLoading = true;
  String? _error;
  String _lang = 'ENG';

  final _avatarColors = [
    const Color(0xFF4CAF50), const Color(0xFF2196F3), const Color(0xFFF44336),
    const Color(0xFFFF9800), const Color(0xFF9C27B0), const Color(0xFF00BCD4),
    const Color(0xFFE91E63), const Color(0xFF607D8B),
  ];

  final _sampleInitials = ['RK', 'AM', 'SJ', 'FB', 'PL'];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await _api.get('/groups');
      if (!mounted) return;
      final data = res.data;
      final list = data is List ? data : (data is Map ? (data['groups'] ?? []) : []);
      setState(() {
        _groups = (list as List).map((e) => SavingsGroup.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = ApiClient.getErrorMessage(e); });
    }
  }

  void _showCreateSheet() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final maxMembersCtrl = TextEditingController(text: '10');
    String type = 'merry_go_round';
    String frequency = 'weekly';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create a Circle', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Circle Name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'merry_go_round', child: Text('Merry-go-round')),
                    DropdownMenuItem(value: 'fixed_pool', child: Text('Fixed Pool')),
                    DropdownMenuItem(value: 'saving_circle', child: Text('Saving Circle')),
                  ],
                  onChanged: (v) => setSheetState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextField(controller: amountCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Contribution Amount', prefixText: 'TZS  ')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (v) => setSheetState(() => frequency = v!),
                ),
                const SizedBox(height: 12),
                TextField(controller: maxMembersCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max Members')),
                const SizedBox(height: 24),
                GradientButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await _api.post('/groups', data: {
                        'name': nameCtrl.text.trim(), 'type': type,
                        'contribution_amount': double.tryParse(amountCtrl.text) ?? 0,
                        'frequency': frequency, 'max_members': int.tryParse(maxMembersCtrl.text) ?? 10,
                      });
                      if (!mounted) return;
                      _loadGroups();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiClient.getErrorMessage(e))));
                    }
                  },
                  child: const Text('Create Circle'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadGroups,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    const SizedBox(height: 20),

                    // Header row
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.people_outline, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('My Circles',
                              style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.onBackground)),
                        ),
                        GestureDetector(
                          onTap: _showCreateSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add, size: 16, color: Colors.white),
                                const SizedBox(width: 4),
                                Text('Create Circle',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Language toggle
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _lang = 'ENG'),
                          child: Text('ENG',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: _lang == 'ENG' ? FontWeight.w600 : FontWeight.w400,
                                  color: _lang == 'ENG' ? AppColors.primary : AppColors.onSurfaceVariant)),
                        ),
                        Text(' \u2022 ', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                        GestureDetector(
                          onTap: () => setState(() => _lang = 'SW'),
                          child: Text('SW',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: _lang == 'SW' ? FontWeight.w600 : FontWeight.w400,
                                  color: _lang == 'SW' ? AppColors.primary : AppColors.onSurfaceVariant)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                        child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13)),
                      ),

                    if (_groups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.group_outlined, size: 64, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text('No circles yet', style: GoogleFonts.inter(fontSize: 16, color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),

                    // Group cards
                    ..._groups.asMap().entries.map((entry) {
                      final g = entry.value;
                      final idx = entry.key;
                      return _buildGroupCard(g, idx);
                    }),

                    const SizedBox(height: 16),

                    // Score card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppGradients.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SavingPlus Score',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8))),
                                const SizedBox(height: 4),
                                Text('94/100',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text('Excellent Reliability',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9))),
                              ],
                            ),
                          ),
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.emoji_events, color: Colors.white, size: 28),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGroupCard(SavingsGroup g, int index) {
    final memberCount = g.maxMembers;
    final showPayWarning = g.status == 'active' && index % 2 == 0; // simulated
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ghostBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + TZS chip
          Row(
            children: [
              Expanded(
                child: Text(g.name,
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('TZS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Active status
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: g.status == 'active' ? AppColors.primary : AppColors.warning,
              )),
              const SizedBox(width: 6),
              Text(g.status[0].toUpperCase() + g.status.substring(1),
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),

          // Member avatars
          SizedBox(
            height: 32,
            child: Row(
              children: [
                ...List.generate(
                  _sampleInitials.length > memberCount ? memberCount : _sampleInitials.length,
                  (i) => Container(
                    margin: EdgeInsets.only(right: i == 0 ? 0 : 0),
                    transform: Matrix4.translationValues(i * -6.0, 0, 0),
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _avatarColors[i % _avatarColors.length],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(_sampleInitials[i],
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                if (memberCount > _sampleInitials.length)
                  Container(
                    transform: Matrix4.translationValues(_sampleInitials.length * -6.0, 0, 0),
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text('+${memberCount - _sampleInitials.length}',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Contribution info
          Text('${formatMoney(g.contributionAmount).replaceAll('.00', '')}/${g.frequency} \u2022 $memberCount members',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),

          // Payout info
          Row(
            children: [
              const Icon(Icons.card_giftcard, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Next payout: Rehema on 5 Apr',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
            ],
          ),

          // Pay warning banner
          if (showPayWarning) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Contribution due: 3 days',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFFE65100))),
                  ),
                  GestureDetector(
                    onTap: () async {
                      try {
                        await _api.post('/groups/${g.id}/contribute');
                        if (!mounted) return;
                        _loadGroups();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiClient.getErrorMessage(e))));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text('PAY NOW',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

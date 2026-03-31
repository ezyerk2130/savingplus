import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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

  // Mockup avatar colors: green, peach, blue, grey, light green
  static const _avatarColors = [
    Color(0xFF1DA75E),
    Color(0xFFF4A98C),
    Color(0xFF5B9BD5),
    Color(0xFF9E9E9E),
    Color(0xFF81C784),
  ];

  static const _sampleInitials = ['RK', 'AM', 'SJ', 'FB', 'PL'];
  static const _sampleNames = ['Rehema', 'Amina', 'Salim', 'Fatma', 'Peter'];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/groups');
      if (!mounted) return;
      final data = res.data;
      final list =
          data is List ? data : (data is Map ? (data['groups'] ?? []) : []);
      setState(() {
        _groups =
            (list as List).map((e) => SavingsGroup.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = ApiClient.getErrorMessage(e);
      });
    }
  }

  // ─── Create Circle Bottom Sheet ───────────────────────────────────────
  void _showCreateSheet() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final maxMembersCtrl = TextEditingController(text: '10');
    String type = 'merry_go_round';
    String frequency = 'weekly';
    bool creating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Create a Circle',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),

                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Circle Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'merry_go_round', child: Text('Upatu (Merry-go-round)')),
                    DropdownMenuItem(
                        value: 'fixed_pool', child: Text('Goal-based')),
                    DropdownMenuItem(
                        value: 'saving_circle', child: Text('Challenge')),
                  ],
                  onChanged: (v) => setSheetState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Contribution Amount',
                    prefixText: 'TZS  ',
                  ),
                ),
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
                TextField(
                  controller: maxMembersCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Max Members'),
                ),
                const SizedBox(height: 24),

                GradientButton(
                  onPressed: creating
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setSheetState(() => creating = true);
                          try {
                            await _api.post('/groups', data: {
                              'name': nameCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'type': type,
                              'contribution_amount':
                                  double.tryParse(amountCtrl.text) ?? 0,
                              'frequency': frequency,
                              'max_members':
                                  int.tryParse(maxMembersCtrl.text) ?? 10,
                            });
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            _loadGroups();
                          } catch (e) {
                            setSheetState(() => creating = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text(ApiClient.getErrorMessage(e))),
                            );
                          }
                        },
                  child: creating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Create'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Join Circle Bottom Sheet ─────────────────────────────────────────
  void _showJoinSheet() {
    final codeControllers =
        List.generate(6, (_) => TextEditingController());
    final codeFocusNodes = List.generate(6, (_) => FocusNode());
    Map<String, dynamic>? previewData;
    bool loadingPreview = false;
    bool joining = false;
    String? previewError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void lookupGroup() async {
            final code =
                codeControllers.map((c) => c.text).join();
            if (code.length != 6) return;
            setSheetState(() {
              loadingPreview = true;
              previewError = null;
            });
            try {
              final res = await _api
                  .get('/groups/lookup', queryParameters: {'code': code});
              if (!ctx.mounted) return;
              setSheetState(() {
                previewData = res.data is Map<String, dynamic>
                    ? res.data as Map<String, dynamic>
                    : null;
                loadingPreview = false;
              });
            } catch (e) {
              if (!ctx.mounted) return;
              setSheetState(() {
                loadingPreview = false;
                previewError = ApiClient.getErrorMessage(e);
                previewData = null;
              });
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Join a Circle',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Enter the 6-digit code shared by a member',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 24),

                  // 6 code boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) {
                      return SizedBox(
                        width: 48,
                        height: 56,
                        child: TextField(
                          controller: codeControllers[i],
                          focusNode: codeFocusNodes[i],
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9]')),
                            UpperCaseFormatter(),
                          ],
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onBackground),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: codeControllers[i].text.isNotEmpty
                                    ? AppColors.primary
                                    : AppColors.ghostBorder,
                                width: codeControllers[i].text.isNotEmpty
                                    ? 2
                                    : 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.primary, width: 2),
                            ),
                          ),
                          onChanged: (v) {
                            if (v.isNotEmpty && i < 5) {
                              codeFocusNodes[i + 1].requestFocus();
                            }
                            if (v.isEmpty && i > 0) {
                              codeFocusNodes[i - 1].requestFocus();
                            }
                            setSheetState(() {});
                            final full = codeControllers
                                .map((c) => c.text)
                                .join();
                            if (full.length == 6) lookupGroup();
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Loading preview
                  if (loadingPreview)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    )),

                  // Preview error
                  if (previewError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(previewError!,
                          style: GoogleFonts.inter(
                              color: AppColors.error, fontSize: 13)),
                    ),

                  // Group preview card
                  if (previewData != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.ghostBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.business,
                                    color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      previewData!['name'] ?? 'Circle',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    if (previewData!['description'] != null)
                                      Text(
                                        previewData!['description'],
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color:
                                                AppColors.onSurfaceVariant),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('CONTRIBUTION',
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                AppColors.onSurfaceVariant,
                                            letterSpacing: 0.5)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${formatMoney(previewData!['contribution_amount'] ?? '0').replaceAll('.00', '')}/${previewData!['frequency'] ?? 'mo'}',
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('MEMBERS',
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                AppColors.onSurfaceVariant,
                                            letterSpacing: 0.5)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${previewData!['max_members'] ?? 0} Members',
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.card_giftcard,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text('Next payout to Juma',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.onSurfaceVariant)),
                              const Spacer(),
                              // 3 overlapping mini avatars
                              SizedBox(
                                width: 52,
                                height: 24,
                                child: Stack(
                                  children: List.generate(3, (i) {
                                    return Positioned(
                                      left: i * 14.0,
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: _avatarColors[
                                              i % _avatarColors.length],
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white,
                                              width: 2),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          _sampleInitials[i],
                                          style: GoogleFonts.inter(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Join button
                  GradientButton(
                    onPressed: (codeControllers
                                    .map((c) => c.text)
                                    .join()
                                    .length ==
                                6 &&
                            !joining)
                        ? () async {
                            setSheetState(() => joining = true);
                            final code = codeControllers
                                .map((c) => c.text)
                                .join();
                            try {
                              await _api.post('/groups/join-by-code',
                                  data: {'invite_code': code});
                              if (!mounted) return;
                              Navigator.pop(ctx);
                              _loadGroups();
                            } catch (e) {
                              setSheetState(() => joining = false);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        ApiClient.getErrorMessage(e))),
                              );
                            }
                          }
                        : null,
                    child: joining
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Join circle'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadGroups,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    const SizedBox(height: 20),

                    // ── Header row ──
                    Row(
                      children: [
                        // Green circles icon (3 dots in triangle)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: CustomPaint(
                            size: const Size(40, 40),
                            painter: _TriangleDotsIconPainter(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'My Circles',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onBackground,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _showCreateSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add,
                                    size: 16, color: Colors.white),
                                const SizedBox(width: 4),
                                Text('Create Circle',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Language toggle (right-aligned) ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _lang = 'ENG'),
                                child: Text('ENG',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: _lang == 'ENG'
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: _lang == 'ENG'
                                          ? AppColors.primary
                                          : AppColors.onSurfaceVariant,
                                    )),
                              ),
                              Text(' \u2022 ',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.onSurfaceVariant)),
                              GestureDetector(
                                onTap: () => setState(() => _lang = 'SW'),
                                child: Text('SW',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: _lang == 'SW'
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: _lang == 'SW'
                                          ? AppColors.primary
                                          : AppColors.onSurfaceVariant,
                                    )),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // ── Join button ──
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: _showJoinSheet,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: AppColors.primary),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.group_add_outlined,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text('Join Circle',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Error ──
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error!,
                            style: GoogleFonts.inter(
                                color: AppColors.error, fontSize: 13)),
                      ),

                    // ── Empty state ──
                    if (_groups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.group_outlined,
                                  size: 64,
                                  color: AppColors.onSurfaceVariant
                                      .withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text('No circles yet',
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: AppColors.onSurfaceVariant)),
                              const SizedBox(height: 8),
                              Text(
                                  'Create or join a circle to start saving together.',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),

                    // ── Group cards ──
                    ..._groups.asMap().entries.map((entry) {
                      return _buildGroupCard(entry.value, entry.key);
                    }),

                    const SizedBox(height: 16),

                    // ── SavingPlus Score Card ──
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
                                Text('SAVINGPLUS SCORE',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white
                                          .withValues(alpha: 0.7),
                                      letterSpacing: 1.2,
                                    )),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text('94',
                                        style:
                                            GoogleFonts.plusJakartaSans(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        )),
                                    const SizedBox(width: 4),
                                    Text('/100',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                        )),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Excellent Reliability',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    )),
                                const SizedBox(height: 8),
                                Text(
                                  'Based on your on-time Upatu contributions and circle activity.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.emoji_events,
                                color: Colors.white, size: 30),
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

  // ─── Group Card ───────────────────────────────────────────────────────
  Widget _buildGroupCard(SavingsGroup g, int index) {
    final memberCount = g.maxMembers;
    final displayCount =
        _sampleInitials.length > memberCount ? memberCount : _sampleInitials.length;
    final showPayWarning = g.status == 'active' && index % 2 == 0;

    return GestureDetector(
      onTap: () => context.push('/circle/detail?id=${g.id}'),
      child: Container(
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
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onBackground)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('TZS',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Active status
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: g.status == 'active'
                        ? AppColors.primary
                        : AppColors.warning,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  g.status[0].toUpperCase() + g.status.substring(1),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: g.status == 'active'
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Member avatars (overlapping)
            SizedBox(
              height: 34,
              child: Stack(
                children: [
                  ...List.generate(displayCount, (i) {
                    return Positioned(
                      left: i * 22.0,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _avatarColors[i % _avatarColors.length],
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(_sampleInitials[i],
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    );
                  }),
                  if (memberCount > _sampleInitials.length)
                    Positioned(
                      left: displayCount * 22.0,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+${memberCount - _sampleInitials.length}',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Contribution info
            Text(
              '${formatMoney(g.contributionAmount).replaceAll('.00', '')}/${g.frequency} \u2022 $memberCount members',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onBackground),
            ),
            const SizedBox(height: 8),

            // Payout info
            Row(
              children: [
                const Icon(Icons.card_giftcard,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Next payout: ${_sampleNames[index % _sampleNames.length]} on 5 Apr',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),

            // Pay warning banner
            if (showPayWarning) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: Color(0xFFE65100)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Contribution due: 3 days',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFE65100))),
                    ),
                    GestureDetector(
                      onTap: () => _contributeToGroup(g.id),
                      child: Text('PAY NOW',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _contributeToGroup(String groupId) async {
    try {
      await _api.post('/groups/$groupId/contribute');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contribution submitted!')),
      );
      _loadGroups();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.getErrorMessage(e))),
      );
    }
  }
}

// ─── Custom painter for 3-dot triangle icon ──────────────────────────────
class _TriangleDotsIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primary;
    final cx = size.width / 2;
    final cy = size.height / 2;
    const r = 4.0;

    // Top dot
    canvas.drawCircle(Offset(cx, cy - 8), r, paint);
    // Bottom-left dot
    canvas.drawCircle(Offset(cx - 8, cy + 6), r, paint);
    // Bottom-right dot
    canvas.drawCircle(Offset(cx + 8, cy + 6), r, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Uppercase text formatter ────────────────────────────────────────────
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

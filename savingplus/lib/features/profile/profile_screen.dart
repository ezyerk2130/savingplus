import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/app_lock_provider.dart';
import '../../core/utils/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _twoFactorEnabled = false;
  bool _autoSaveReminders = true;
  bool _circleReminders = true;
  bool _interestAlerts = true;
  bool _marketing = false;

  @override
  void initState() {
    super.initState();
    _load2faStatus();
  }

  Future<void> _load2faStatus() async {
    try {
      final res = await ApiClient.instance.get('/auth/2fa/status');
      if (mounted) {
        setState(() => _twoFactorEnabled = res.data['enabled'] == true);
      }
    } catch (_) {}
  }

  Future<void> _toggle2fa(bool value) async {
    setState(() => _twoFactorEnabled = value);
    try {
      if (value) {
        await ApiClient.instance.post('/auth/2fa/enable');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _twoFactorEnabled = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.getErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final initials = user != null && user.fullName.isNotEmpty
        ? user.fullName
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Profile',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 20, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // --- Avatar + name ---
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary,
                    child: Text(initials,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  const SizedBox(height: 14),
                  Text(user.fullName,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onBackground)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(user.phone,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.onSurfaceVariant)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text('VERIFIED',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                letterSpacing: 0.3)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {},
                    child: Text('Edit profile',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),

                  const SizedBox(height: 28),

                  // --- ACCOUNT ---
                  _buildSectionHeader('ACCOUNT'),
                  _buildNavItem(
                      Icons.savings_outlined, 'My savings plans', onTap: () {}),
                  _buildNavItem(Icons.receipt_long_outlined,
                      'Transaction history',
                      onTap: () {}),
                  _buildNavItem(Icons.description_outlined,
                      'Statements & reports',
                      onTap: () {}),

                  const SizedBox(height: 20),

                  // --- SECURITY ---
                  _buildSectionHeader('SECURITY'),
                  _buildNavItem(
                      Icons.lock_outline, 'Change password', onTap: () {}),
                  _buildNavItem(Icons.pin_outlined, 'Change transaction PIN',
                      onTap: () {}),
                  _buildToggleItem(
                    Icons.security_outlined,
                    'Two-factor authentication',
                    _twoFactorEnabled,
                    _toggle2fa,
                  ),
                  _buildNavItem(
                    Icons.devices_outlined,
                    'Active sessions',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text('2',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                    onTap: () {},
                  ),

                  const SizedBox(height: 20),

                  // --- NOTIFICATIONS ---
                  _buildSectionHeader('NOTIFICATIONS'),
                  _buildToggleItem(
                    Icons.notifications_none_outlined,
                    'AutoSave reminders',
                    _autoSaveReminders,
                    (v) => setState(() => _autoSaveReminders = v),
                  ),
                  _buildToggleItem(
                    Icons.group_outlined,
                    'Circle contribution reminders',
                    _circleReminders,
                    (v) => setState(() => _circleReminders = v),
                  ),
                  _buildToggleItem(
                    Icons.trending_up_outlined,
                    'Interest earned alerts',
                    _interestAlerts,
                    (v) => setState(() => _interestAlerts = v),
                  ),
                  _buildToggleItem(
                    Icons.campaign_outlined,
                    'Marketing',
                    _marketing,
                    (v) => setState(() => _marketing = v),
                  ),

                  const SizedBox(height: 20),

                  // --- PREFERENCES ---
                  _buildSectionHeader('PREFERENCES'),
                  _buildNavItem(
                    Icons.language_outlined,
                    'Language',
                    value: 'Swahili / English',
                    onTap: () {},
                  ),
                  _buildNavItem(
                    Icons.attach_money_outlined,
                    'Currency display',
                    value: 'TZS',
                    onTap: () {},
                  ),

                  const SizedBox(height: 20),

                  // --- SUPPORT ---
                  _buildSectionHeader('SUPPORT'),
                  _buildNavItem(
                      Icons.help_outline, 'Help center', onTap: () {}),
                  _buildNavItem(Icons.headset_mic_outlined,
                      'Contact support',
                      onTap: () {}),
                  _buildNavItem(Icons.bug_report_outlined,
                      'Report a problem',
                      onTap: () {}),

                  const SizedBox(height: 28),

                  // --- Log out ---
                  GestureDetector(
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Sign Out'),
                          content: const Text(
                              'Are you sure you want to sign out?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Sign Out')),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await context.read<AuthProvider>().logout();
                        if (context.mounted) {
                          context.read<AppLockProvider>().onLogout();
                          context.go('/login');
                        }
                      }
                    },
                    child: Text('Log out',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error)),
                  ),

                  const SizedBox(height: 20),
                  Text('SavingPlus v1.0.2',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 1)),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label, {
    String? value,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.onBackground)),
            ),
            if (value != null)
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.onSurfaceVariant)),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.onBackground)),
          ),
          SizedBox(
            height: 24,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

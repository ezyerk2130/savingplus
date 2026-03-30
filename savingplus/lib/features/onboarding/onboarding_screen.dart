import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  final _pages = const [
    _OnboardingPage(
      icon: Icons.trending_up_rounded,
      iconBg: AppColors.primary,
      title: 'Your money grows\nwhile you sleep',
      subtitle: 'Automated savings that work every day — even when you don\'t.',
    ),
    _OnboardingPage(
      icon: Icons.people_rounded,
      iconBg: Color(0xFF151C27),
      title: 'Circles that keep\nyou accountable',
      subtitle: 'Join or create Upatu groups with friends and family to save together and build trust.',
    ),
    _OnboardingPage(
      icon: Icons.shield_rounded,
      iconBg: AppColors.primary,
      title: 'Earn more than\nyour bank',
      subtitle: 'Access curated investment opportunities with returns up to 25% p.a. Secure, transparent, and built for growth.',
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    context.go('/register');
  }

  void _skip() => _finish();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
                      ),
                      icon: const Icon(Icons.close, color: AppColors.primary),
                    )
                  else
                    const SizedBox(width: 48),
                  // Language toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'EN • SW',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: _skip,
                    child: Text('Skip', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const Spacer(flex: 1),
                        // Icon container
                        Container(
                          width: size.width * 0.55,
                          height: size.width * 0.55,
                          decoration: BoxDecoration(
                            color: page.iconBg.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: page.iconBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(page.icon, color: Colors.white, size: 40),
                            ),
                          ),
                        ),
                        const Spacer(flex: 1),
                        // Title
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onBackground,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Subtitle
                        Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: AppColors.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const Spacer(flex: 1),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // CTA button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GradientButton(
                onPressed: _next,
                width: double.infinity,
                height: 56,
                child: Text(
                  _currentPage == _pages.length - 1 ? 'Get started' : 'Next',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Login link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
                ),
                GestureDetector(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('onboarding_seen', true);
                    if (!mounted) return;
                    context.go('/login');
                  },
                  child: Text(
                    'Log in',
                    style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });
}

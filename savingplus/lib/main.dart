import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/providers/auth_provider.dart';
import 'core/utils/theme.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/savings/savings_screen.dart';
import 'features/savings/create_plan_screen.dart';
import 'features/investments/investments_screen.dart';
import 'features/wallet/deposit_screen.dart';
import 'features/wallet/withdraw_screen.dart';
import 'features/wallet/transactions_screen.dart';
import 'features/groups/groups_screen.dart';
import 'features/insurance/insurance_screen.dart';
import 'features/loans/loans_screen.dart';
import 'features/learn/learn_screen.dart';
import 'features/kyc/kyc_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/profile/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const SavingPlusApp(),
    ),
  );
}

class SavingPlusApp extends StatelessWidget {
  const SavingPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SavingPlus',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    // Splash → checks auth → routes to onboarding/login/home
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

    // Main app with bottom nav
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/save', builder: (_, __) => const SavingsScreen()),
        GoRoute(path: '/circles', builder: (_, __) => const GroupsScreen()),
        GoRoute(path: '/wallet', builder: (_, __) => const TransactionsScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),

    // Full-screen routes (no bottom nav)
    GoRoute(path: '/deposit', builder: (_, __) => const DepositScreen()),
    GoRoute(path: '/withdraw', builder: (_, __) => const WithdrawScreen()),
    GoRoute(path: '/savings/new', builder: (_, __) => const CreatePlanScreen()),
    GoRoute(path: '/invest', builder: (_, __) => const InvestmentsScreen()),
    GoRoute(path: '/insurance', builder: (_, __) => const InsuranceScreen()),
    GoRoute(path: '/loans', builder: (_, __) => const LoansScreen()),
    GoRoute(path: '/learn', builder: (_, __) => const LearnScreen()),
    GoRoute(path: '/kyc', builder: (_, __) => const KycScreen()),
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
  ],
);

class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          border: Border(top: BorderSide(color: AppColors.surfaceContainerLow, width: 0.5)),
        ),
        child: SafeArea(
          child: NavigationBar(
            height: 64,
            selectedIndex: _indexFor(location),
            onDestinationSelected: (i) {
              const routes = ['/home', '/save', '/circles', '/wallet', '/profile'];
              context.go(routes[i]);
            },
            backgroundColor: AppColors.cardWhite,
            indicatorColor: AppColors.primary.withValues(alpha: 0.1),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: AppColors.primary), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings, color: AppColors.primary), label: 'Save'),
              NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people, color: AppColors.primary), label: 'Circles'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet, color: AppColors.primary), label: 'Wallet'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: AppColors.primary), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  int _indexFor(String loc) {
    if (loc.startsWith('/save')) return 1;
    if (loc.startsWith('/circles')) return 2;
    if (loc.startsWith('/wallet')) return 3;
    if (loc.startsWith('/profile')) return 4;
    return 0;
  }
}

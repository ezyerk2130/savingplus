import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/providers/auth_provider.dart';
import 'core/utils/theme.dart';
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

class SavingPlusApp extends StatefulWidget {
  const SavingPlusApp({super.key});

  @override
  State<SavingPlusApp> createState() => _SavingPlusAppState();
}

class _SavingPlusAppState extends State<SavingPlusApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await context.read<AuthProvider>().init();
      if (mounted) setState(() => _initialized = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final router = GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        if (!_initialized) return null;
        final isAuth = auth.isAuthenticated;
        final loc = state.matchedLocation;
        final isAuthRoute = loc == '/login' || loc == '/register';
        final isSplash = loc == '/splash';

        if (!isAuth && !isAuthRoute && !isSplash) return '/login';
        if (isAuth && isAuthRoute) return '/home';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => _AppShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/save',
              builder: (context, state) => const SavingsScreen(),
            ),
            GoRoute(
              path: '/circles',
              builder: (context, state) => const GroupsScreen(),
            ),
            GoRoute(
              path: '/wallet',
              builder: (context, state) => const TransactionsScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/deposit',
          builder: (context, state) => const DepositScreen(),
        ),
        GoRoute(
          path: '/withdraw',
          builder: (context, state) => const WithdrawScreen(),
        ),
        GoRoute(
          path: '/savings/new',
          builder: (context, state) => const CreatePlanScreen(),
        ),
        GoRoute(
          path: '/invest',
          builder: (context, state) => const InvestmentsScreen(),
        ),
        GoRoute(
          path: '/insurance',
          builder: (context, state) => const InsuranceScreen(),
        ),
        GoRoute(
          path: '/loans',
          builder: (context, state) => const LoansScreen(),
        ),
        GoRoute(
          path: '/learn',
          builder: (context, state) => const LearnScreen(),
        ),
        GoRoute(
          path: '/kyc',
          builder: (context, state) => const KycScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'SavingPlus',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}

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
          border: Border(
            top: BorderSide(color: AppColors.surfaceContainerLow, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _calculateIndex(location),
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                context.go('/home');
              case 1:
                context.go('/save');
              case 2:
                context.go('/circles');
              case 3:
                context.go('/wallet');
              case 4:
                context.go('/profile');
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.savings_outlined),
              selectedIcon: Icon(Icons.savings),
              label: 'Save',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Circles',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Wallet',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  int _calculateIndex(String location) {
    if (location.startsWith('/save')) return 1;
    if (location.startsWith('/circles')) return 2;
    if (location.startsWith('/wallet')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }
}

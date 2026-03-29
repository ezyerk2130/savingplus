import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/providers/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/savings/savings_screen.dart';
import 'features/savings/create_plan_screen.dart';
import 'features/investments/investments_screen.dart';
import 'features/wallet/transactions_screen.dart';
import 'features/wallet/deposit_screen.dart';
import 'features/wallet/withdraw_screen.dart';
import 'features/groups/groups_screen.dart';
import 'features/insurance/insurance_screen.dart';
import 'features/loans/loans_screen.dart';
import 'features/learn/learn_screen.dart';
import 'features/kyc/kyc_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/profile/profile_screen.dart';

void main() async {
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
      theme: _buildTheme(),
      routerConfig: _buildRouter(context),
    );
  }

  ThemeData _buildTheme() {
    const primaryColor = Color(0xFF2563EB);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: const BorderSide(color: primaryColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey[500],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),
    );
  }

  GoRouter _buildRouter(BuildContext context) {
    return GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final auth = context.read<AuthProvider>();
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';

        if (!auth.isAuthenticated && !isAuthRoute) return '/login';
        if (auth.isAuthenticated && isAuthRoute) return '/home';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

        // Main app shell with bottom nav
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child, location: state.matchedLocation),
          routes: [
            GoRoute(path: '/home', builder: (_, __) => const DashboardScreen()),
            GoRoute(path: '/savings', builder: (_, __) => const SavingsScreen()),
            GoRoute(path: '/invest', builder: (_, __) => const InvestmentsScreen()),
            GoRoute(path: '/wallet', builder: (_, __) => const TransactionsScreen()),
            GoRoute(path: '/more', builder: (_, __) => const MoreScreen()),
          ],
        ),

        // Full-screen routes (no bottom nav)
        GoRoute(path: '/deposit', builder: (_, __) => const DepositScreen()),
        GoRoute(path: '/withdraw', builder: (_, __) => const WithdrawScreen()),
        GoRoute(path: '/savings/new', builder: (_, __) => const CreatePlanScreen()),
        GoRoute(path: '/groups', builder: (_, __) => const GroupsScreen()),
        GoRoute(path: '/insurance', builder: (_, __) => const InsuranceScreen()),
        GoRoute(path: '/loans', builder: (_, __) => const LoansScreen()),
        GoRoute(path: '/learn', builder: (_, __) => const LearnScreen()),
        GoRoute(path: '/kyc', builder: (_, __) => const KycScreen()),
        GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    );
  }
}

// Bottom navigation shell
class AppShell extends StatelessWidget {
  final Widget child;
  final String location;
  const AppShell({super.key, required this.child, required this.location});

  int get _currentIndex {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/savings')) return 1;
    if (location.startsWith('/invest')) return 2;
    if (location.startsWith('/wallet')) return 3;
    if (location.startsWith('/more')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          const routes = ['/home', '/savings', '/invest', '/wallet', '/more'];
          context.go(routes[i]);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.savings_outlined), activeIcon: Icon(Icons.savings), label: 'Save'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up_outlined), activeIcon: Icon(Icons.trending_up), label: 'Invest'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.menu), activeIcon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}

// "More" tab - links to all other features
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          _MoreTile(icon: Icons.groups_outlined, title: 'Upatu Groups', subtitle: 'Rotating savings', route: '/groups'),
          _MoreTile(icon: Icons.shield_outlined, title: 'Insurance', subtitle: 'Micro-insurance', route: '/insurance'),
          _MoreTile(icon: Icons.account_balance_outlined, title: 'Loans', subtitle: 'Savings-backed credit', route: '/loans'),
          _MoreTile(icon: Icons.menu_book_outlined, title: 'Learn', subtitle: 'Financial literacy', route: '/learn'),
          const Divider(height: 1),
          _MoreTile(icon: Icons.verified_user_outlined, title: 'KYC Verification', subtitle: 'Verify your identity', route: '/kyc'),
          _MoreTile(icon: Icons.notifications_outlined, title: 'Notifications', subtitle: 'Messages & alerts', route: '/notifications'),
          _MoreTile(icon: Icons.person_outline, title: 'Profile', subtitle: 'Account settings', route: '/profile'),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, route;
  const _MoreTile({required this.icon, required this.title, required this.subtitle, required this.route});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: () => context.push(route),
    );
  }
}

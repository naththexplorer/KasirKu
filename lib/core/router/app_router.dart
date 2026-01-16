import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/shop_setup_provider.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/products/presentation/screens/product_list_screen.dart';
import '../../features/products/presentation/screens/add_edit_product_screen.dart';
import '../../features/pos/presentation/screens/pos_screen.dart';
import '../../features/reports/presentation/screens/report_screen.dart';
import '../../features/stock/presentation/screens/stock_manage_screen.dart';
import '../../features/expenses/presentation/screens/expense_screen.dart';
import '../../features/customers/presentation/screens/customer_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/products/presentation/screens/barcode_scanner_screen.dart';

// Placeholder screens for testing routing
class PlaceholderScreen extends ConsumerWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () {
              ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: Center(child: Text('$title Screen')),
    );
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final shopSetupState = ref.watch(isShopSetupProvider);
  final authState = ref.watch(authControllerProvider); // Watch auth changes

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _NoTransitionPage(child: const DashboardScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _SmoothPage(child: const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _SmoothPage(child: const LoginScreen()),
      ),
      GoRoute(
        path: '/pos',
        pageBuilder: (context, state) => _SmoothPage(child: const PosScreen()),
      ),
      GoRoute(
        path: '/products',
        pageBuilder: (context, state) =>
            _SmoothPage(child: const ProductListScreen()),
        routes: [
          GoRoute(
            path: 'add',
            pageBuilder: (context, state) =>
                _SmoothPage(child: const AddEditProductScreen()),
          ),
          GoRoute(
            path: 'edit/:id',
            pageBuilder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              return _SmoothPage(child: AddEditProductScreen(productId: id));
            },
          ),
        ],
      ),
      GoRoute(
        path: '/reports',
        pageBuilder: (context, state) =>
            _SmoothPage(child: const ReportScreen()),
      ),
      GoRoute(
        path: '/stock',
        pageBuilder: (context, state) =>
            _SmoothPage(child: const StockManageScreen()),
      ),
      GoRoute(
        path: '/expenses',
        pageBuilder: (context, state) =>
            _SmoothPage(child: const ExpenseScreen()),
      ),
      GoRoute(
        path: '/customers',
        pageBuilder: (context, state) =>
            _SmoothPage(child: const CustomerScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            _SmoothPage(child: const SettingsScreen()),
      ),
      GoRoute(
        path: '/scanner',
        pageBuilder: (context, state) =>
            _SmoothPage(child: const BarcodeScannerScreen()),
      ),
    ],
    redirect: (context, state) {
      if (shopSetupState.isLoading || shopSetupState.hasError) return null;

      final isSetup = shopSetupState.valueOrNull ?? false;
      final isAuthenticated = authState != null;

      final isGoingToOnboarding = state.matchedLocation == '/onboarding';
      final isGoingToLogin = state.matchedLocation == '/login';

      // 1. Not Setup -> Force Onboarding (unless going to login)
      if (!isSetup) {
        if (isGoingToOnboarding || isGoingToLogin) return null;
        return '/onboarding';
      }

      // 2. Setup Done, Not Authenticated -> Force Login (unless going to onboarding)
      if (isSetup && !isAuthenticated) {
        if (isGoingToLogin || isGoingToOnboarding) return null;
        return '/login';
      }

      // 3. Authenticated -> Prevent Login/Onboarding access
      if (isAuthenticated && (isGoingToLogin || isGoingToOnboarding)) {
        return '/';
      }
      return null;
    },
  );
});

class _SmoothPage extends CustomTransitionPage {
  _SmoothPage({required super.child})
    : super(
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      );
}

class _NoTransitionPage extends CustomTransitionPage {
  _NoTransitionPage({required super.child})
    : super(
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            child,
        transitionDuration: Duration.zero,
      );
}

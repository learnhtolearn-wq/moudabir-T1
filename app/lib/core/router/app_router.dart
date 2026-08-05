import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/accounts_form_screen.dart';
import '../../features/accounts/providers/accounts_provider.dart';
import '../../features/auth/pin_setup_screen.dart';
import '../../features/auth/lock_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/goals/goals_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/transactions/transactions_screen.dart';
import '../security/pin_store.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/lock',
    redirect: (context, state) async {
      final goingToAuth =
          state.matchedLocation == '/lock' || state.matchedLocation == '/setup-pin';
      final hasPin = await PinStore.hasPin();

      if (!hasPin && state.matchedLocation != '/setup-pin') return '/setup-pin';
      if (hasPin && !goingToAuth && state.matchedLocation == '/setup-pin') {
        return '/lock';
      }

      if (hasPin && !goingToAuth) {
        try {
          final hasAccount = ref.read(hasAnyAccountProvider).maybeWhen(
                data: (value) => value,
                orElse: () => null,
              );
          // Still loading (first read of the session) or errored — don't
          // redirect on incomplete information; let the next navigation
          // (or the stream's next emission) resolve it.
          if (hasAccount != null) {
            final goingToSetupAccount = state.matchedLocation == '/setup-account';
            if (!hasAccount && !goingToSetupAccount) return '/setup-account';
            if (hasAccount && goingToSetupAccount) return '/dashboard';
          }
        } catch (_) {
          // A transient DB failure (e.g. mid backup-restore) must not crash
          // routing — fall through to no redirect.
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/setup-pin',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PinSetupScreen(),
      ),
      GoRoute(
        path: '/lock',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LockScreen(),
      ),
      GoRoute(
        path: '/setup-account',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => AccountsFormScreen(
          onSaved: () => GoRouter.of(context).go('/dashboard'),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard', builder: (c, s) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/transactions', builder: (c, s) => const TransactionsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/goals', builder: (c, s) => const GoalsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/reports', builder: (c, s) => const ReportsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
          ]),
        ],
      ),
    ],
  );
});

class _AppShell extends StatelessWidget {
  const _AppShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: 'nav.dashboard'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: 'nav.transactions'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.savings_outlined),
            selectedIcon: const Icon(Icons.savings),
            label: 'nav.goals'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: 'nav.reports'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: 'nav.settings'.tr(),
          ),
        ],
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/accounts_form_screen.dart';
import '../../features/accounts/providers/accounts_provider.dart';
import '../../features/auth/pin_setup_screen.dart';
import '../../features/auth/lock_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/goals/goals_screen.dart';
import '../../features/recurring/providers/recurring_provider.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/transactions/transactions_screen.dart';
import '../security/pin_store.dart';
import '../theme/app_theme.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Bottom nav tab, matching Figma's "Barre de navigation" — same 24px line
/// icon for both states, recolored gold when selected instead of swapping
/// to a filled glyph.
NavigationDestination _navDestination(String asset, String label) {
  Widget icon(Color color) => SvgPicture.asset(
        asset,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
  return NavigationDestination(
    icon: icon(AppColors.inkFaint),
    selectedIcon: icon(AppColors.or),
    label: label,
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) async {
      // Splash owns its own timed transition to /lock — skip the auth
      // redirect entirely while it's showing so it isn't preempted.
      if (state.matchedLocation == '/splash') return null;

      final goingToAuth =
          state.matchedLocation == '/lock' || state.matchedLocation == '/setup-pin';
      final hasPin = await PinStore.hasPin();

      if (!hasPin && state.matchedLocation != '/setup-pin') return '/setup-pin';
      if (hasPin && !goingToAuth && state.matchedLocation == '/setup-pin') {
        return '/lock';
      }

      if (hasPin && !goingToAuth) {
        try {
          // `.future` resolves with the stream's first emitted value (and
          // is served from cache on subsequent reads for the session, since
          // accountsProvider stays alive as long as something — this
          // redirect included — is reading it). Awaiting here matches the
          // determinism of the original inline query: the redirect blocks
          // until the real answer is known, so the very first post-unlock
          // navigation for a 0-account user is correctly caught, instead of
          // racing an AsyncLoading value.
          final accounts = await ref.read(accountsProvider.future);
          final hasAccount = accounts.isNotEmpty;
          final goingToSetupAccount = state.matchedLocation == '/setup-account';
          if (!hasAccount && !goingToSetupAccount) return '/setup-account';
          if (hasAccount && goingToSetupAccount) return '/dashboard';
        } catch (_) {
          // A transient DB failure (e.g. mid backup-restore) must not crash
          // routing — fall through to no redirect.
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),
      ),
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

class _AppShell extends ConsumerWidget {
  const _AppShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Side-effect only: fires any recurring bills/income due this month
    // that haven't already run yet. Result is intentionally unused.
    //
    // Deliberately watched here rather than in MoudabirApp.build: this
    // shell is only reached once the router's redirect logic has confirmed
    // the user has a PIN, has passed /lock (or biometric unlock), and has
    // at least one account — i.e. strictly post-authentication. Watching it
    // in MoudabirApp.build would run it on every cold start regardless of
    // lock state, silently inserting a real transaction (and potentially
    // firing an overspend notification exposing a category name) before the
    // user has unlocked.
    ref.watch(runDueRecurringTemplatesProvider);

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: [
          _navDestination('assets/icons/home.svg', 'nav.dashboard'.tr()),
          _navDestination('assets/icons/list.svg', 'nav.transactions'.tr()),
          _navDestination('assets/icons/trend.svg', 'nav.goals'.tr()),
          _navDestination('assets/icons/pie.svg', 'nav.reports'.tr()),
          _navDestination('assets/icons/user.svg', 'nav.settings'.tr()),
        ],
      ),
    );
  }
}

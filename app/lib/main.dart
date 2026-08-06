import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/notification_provider.dart';
import 'core/router/app_router.dart';
import 'core/security/pin_store.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('ar'),
        Locale('ar', 'MA'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
      startLocale: const Locale('fr'),
      child: const ProviderScope(child: MoudabirApp()),
    ),
  );
}

class MoudabirApp extends ConsumerStatefulWidget {
  const MoudabirApp({super.key});

  @override
  ConsumerState<MoudabirApp> createState() => _MoudabirAppState();
}

class _MoudabirAppState extends ConsumerState<MoudabirApp>
    with WidgetsBindingObserver {
  // Only re-lock after a real backgrounding (paused), not a brief
  // `inactive` blip from a share sheet, permission dialog, or app switcher.
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      _relockIfNeeded();
    }
  }

  Future<void> _relockIfNeeded() async {
    if (!await PinStore.hasPin()) return;
    ref.read(appRouterProvider).go('/lock');
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    // Side-effect only: reschedules reminders left enabled from a prior
    // session. Result is intentionally unused. Safe to run pre-auth: it only
    // reschedules previously-configured OS notifications (idempotent) and
    // never mutates financial records, unlike the recurring-template runner
    // below (which is deliberately NOT watched here — see _AppShell in
    // app_router.dart for why).
    ref.watch(notificationBootstrapProvider);

    return MaterialApp.router(
      // Forces the router (and every StatefulShellRoute branch it caches)
      // to fully remount on locale change — without this key, go_router's
      // per-tab page caching leaves `.tr()` strings stuck on the locale
      // that was active when each tab was first built.
      key: ValueKey(context.locale),
      title: 'app_name'.tr(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}

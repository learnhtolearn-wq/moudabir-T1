import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/notification_provider.dart';
import 'core/router/app_router.dart';
import 'core/security/pin_store.dart';

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
      child: const ProviderScope(child: MoudabbirApp()),
    ),
  );
}

class MoudabbirApp extends ConsumerStatefulWidget {
  const MoudabbirApp({super.key});

  @override
  ConsumerState<MoudabbirApp> createState() => _MoudabbirAppState();
}

class _MoudabbirAppState extends ConsumerState<MoudabbirApp>
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
    // session. Result is intentionally unused.
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
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1F6F5C),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

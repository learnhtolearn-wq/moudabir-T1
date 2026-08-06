import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// Cold-start splash, matching Figma's "0. Écran de démarrage" — dark
/// (inverted) background, badge mark, wordmark, tagline, and a 3s progress
/// bar that fills once then hands off to the router's normal auth redirect.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const duration = Duration(seconds: 3);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashScreen.duration, () {
      if (!mounted) return;
      context.go('/lock');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/branding/icon_mark_flat.png',
              width: 136,
              height: 136,
            ),
            const SizedBox(height: 16),
            Text(
              'app_name'.tr(),
              style: const TextStyle(
                fontFamily: 'Noto Sans',
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: AppColors.bg,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 35),
              child: Text(
                'splash.tagline'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Noto Sans',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.bg.withValues(alpha: 0.74),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 88,
              height: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  color: AppColors.bg.withValues(alpha: 0.22),
                  alignment: AlignmentDirectional.centerStart,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: SplashScreen.duration,
                    curve: Curves.linear,
                    builder: (context, value, _) => FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: value,
                      child: Container(height: 3, color: AppColors.or),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Design tokens pulled from Figma (p28i2vn3pA1jCSuoHygHdd, "Design System"
/// page, "Métal & Sable" palette). Source of truth for color + type — reuse
/// these instead of ad-hoc values.
class AppColors {
  const AppColors._();

  static const bg = Color(0xFFF2E9DC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFE7DAC6);
  static const ink = Color(0xFF3A2C12);
  static const inkSoft = Color(0xA83A2C12);
  static const inkFaint = Color(0x6B3A2C12);
  static const or = Color(0xFFC9A227);
  static const orStrong = Color(0xFFBF8F2E);
  static const orDeep = Color(0xFF7A5A12);
  static const orTint = Color(0x29C9A227);
  static const warning = Color(0xFFBD741D);
  static const warningTint = Color(0x29BD741D);
  static const corail = Color(0xFFE4603E);
  static const critical = Color(0xFFB23B2E);
  static const criticalTint = Color(0x24B23B2E);
  static const bronze = Color(0xFF8A5A2B);
  static const bronzeTint = Color(0x268A5A2B);
  static const silver = Color(0xFF6F6A5C);
  static const silverTint = Color(0x266F6A5C);
  static const onAccent = Color(0xFF3A2C12);
  static const onCritical = Color(0xFFFFF8F2);
  static const scrim = Color(0x80201709);

  /// "Jauge de progression" fill gradient — kept as the old green accent
  /// per Figma, which hardcodes this gradient rather than using `or`.
  static const progressStart = Color(0xFF0B4F38);
  static const progressEnd = Color(0xFF12855C);
}

class AppTextStyles {
  const AppTextStyles._();

  static const _notoSans = 'Noto Sans';
  static const _robotoMono = 'Roboto Mono';

  static const display = TextStyle(
    fontFamily: _notoSans,
    fontWeight: FontWeight.bold,
    fontSize: 24,
    color: AppColors.ink,
  );

  static const body = TextStyle(
    fontFamily: _notoSans,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: AppColors.ink,
  );

  static const bodyRegular = TextStyle(
    fontFamily: _notoSans,
    fontWeight: FontWeight.normal,
    fontSize: 15,
    color: AppColors.ink,
  );

  static const bodySmall = TextStyle(
    fontFamily: _notoSans,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    color: AppColors.inkFaint,
  );

  static const caption = TextStyle(
    fontFamily: _notoSans,
    fontWeight: FontWeight.normal,
    fontSize: 12,
    color: AppColors.inkFaint,
  );

  static const navLabel = TextStyle(
    fontFamily: _notoSans,
    fontWeight: FontWeight.normal,
    fontSize: 10,
    color: AppColors.inkFaint,
  );

  static const navLabelSelected = TextStyle(
    fontFamily: _notoSans,
    fontWeight: FontWeight.w600,
    fontSize: 10,
    color: AppColors.or,
  );

  /// Money amounts — always Roboto Mono per design system typography spec.
  static const amount = TextStyle(
    fontFamily: _robotoMono,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: AppColors.ink,
  );
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Noto Sans',
      // Noto Sans has no Arabic glyphs; fall back to Noto Sans Arabic so
      // AR/Darija text renders instead of showing tofu boxes.
      fontFamilyFallback: const ['Noto Sans Arabic'],
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.or,
        primary: AppColors.or,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.orTint,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppTextStyles.navLabelSelected
              : AppTextStyles.navLabel;
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.or,
          foregroundColor: AppColors.onAccent,
          textStyle: const TextStyle(
            fontFamily: 'Noto Sans',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.or,
          side: const BorderSide(color: AppColors.or, width: 1.5),
          textStyle: const TextStyle(
            fontFamily: 'Noto Sans',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

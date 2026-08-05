import 'package:flutter/material.dart';

/// Design tokens pulled from Figma (CfQ5K7ZLCEXglxOtqDg15L, "Design System" page).
/// Source of truth for color + type — reuse these instead of ad-hoc values.
class AppColors {
  const AppColors._();

  static const bg = Color(0xFFF6F1E4);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFEFE7D4);
  static const ink = Color(0xFF0B2A4A);
  static const inkSoft = Color(0x9E0B2A4A);
  static const inkFaint = Color(0x610B2A4A);
  static const vault = Color(0xFF12855C);
  static const vaultDeep = Color(0xFF0B4F38);
  static const vaultTint = Color(0x1F12855C);
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
    color: AppColors.vault,
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
        seedColor: AppColors.vault,
        primary: AppColors.vault,
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
        indicatorColor: AppColors.vaultTint,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppTextStyles.navLabelSelected
              : AppTextStyles.navLabel;
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.vault,
          foregroundColor: Colors.white,
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
          foregroundColor: AppColors.vault,
          side: const BorderSide(color: AppColors.vault, width: 1.5),
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

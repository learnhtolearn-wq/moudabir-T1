import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// Category icon set exported from Figma (p28i2vn3pA1jCSuoHygHdd,
/// "icon/*" components) — maps a [Categories.iconName] value to its SVG
/// asset. Falls back to [briefcase] for an unknown/missing name so a
/// category never renders with no icon at all.
const _categoryIconAssets = <String, String>{
  'basket': 'assets/icons/basket.svg',
  'car': 'assets/icons/car.svg',
  'home': 'assets/icons/home.svg',
  'shield': 'assets/icons/shield.svg',
  'sparkle': 'assets/icons/sparkle.svg',
  'briefcase': 'assets/icons/briefcase.svg',
  'laptop': 'assets/icons/laptop.svg',
  'trend': 'assets/icons/trend.svg',
};

/// Tint applied to a category's icon + circle background when it has no
/// `colorHex` of its own (e.g. user-created categories), keyed by
/// [Categories.iconName]. Falls back to the gold accent.
const _categoryIconColors = <String, Color>{
  'basket': AppColors.critical,
  'car': AppColors.warning,
  'home': AppColors.silver,
  'shield': AppColors.bronze,
  'sparkle': AppColors.corail,
  'briefcase': AppColors.or,
  'laptop': AppColors.or,
  'trend': AppColors.or,
};

String categoryIconAsset(String? iconName) =>
    _categoryIconAssets[iconName] ?? _categoryIconAssets['briefcase']!;

Color categoryIconColor(String? iconName, {String? colorHex}) {
  if (colorHex != null && colorHex.isNotEmpty) {
    final parsed = parseHexColor(colorHex);
    if (parsed != null) return parsed;
  }
  return _categoryIconColors[iconName] ?? AppColors.or;
}

/// Parses a `#RRGGBB` / `#AARRGGBB` string into a [Color]; `null` if it
/// isn't one.
Color? parseHexColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(
    cleaned.length == 6 ? 'FF$cleaned' : cleaned,
    radix: 16,
  );
  return value != null ? Color(value) : null;
}

/// Circular tinted icon marker for a category, matching Figma's "Carte
/// transaction" leading ellipse + icon overlay. Pass the category's
/// `iconName`/`colorHex` straight from the DB row.
class CategoryIconAvatar extends StatelessWidget {
  const CategoryIconAvatar({
    super.key,
    required this.iconName,
    this.colorHex,
    this.radius = 20,
  });

  final String? iconName;
  final String? colorHex;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = categoryIconColor(iconName, colorHex: colorHex);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.16),
      child: SvgPicture.asset(
        categoryIconAsset(iconName),
        width: radius,
        height: radius,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}

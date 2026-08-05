import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Screen-root header — bold title + avatar, matching Figma's
/// "En-tête d'écran" component. Used on bottom-nav tab roots only; pushed
/// sub-screens keep the native back-arrow AppBar.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.onAvatarTap});

  final String title;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.display,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: onAvatarTap,
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.vaultTint,
            child: ClipOval(
              child: Image.asset(
                'assets/branding/icon_mark.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Labeled input matching Figma's "Champ de saisie": small caption label
/// above a surface-filled, rounded-10 field. Thin wrapper over
/// [TextFormField] so it still works inside a [Form].
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.autofocus = false,
    this.validator,
    this.onChanged,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autofocus;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(label, style: AppTextStyles.caption),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autofocus: autofocus,
          validator: validator,
          onChanged: onChanged,
          readOnly: readOnly,
          onTap: onTap,
          style: AppTextStyles.bodyRegular,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTextStyles.bodyRegular.copyWith(color: AppColors.inkFaint),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

/// Labeled tap-target styled like [AppTextField] but for value pickers,
/// matching Figma's "Champ déroulant" — label, surface field, trailing
/// chevron. Opens whatever picker [onTap] wires up (bottom sheet, dialog…).
class AppSelectField extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.onTap,
    this.placeholder,
    this.errorText,
  });

  final String label;
  final String? valueLabel;
  final VoidCallback onTap;
  final String? placeholder;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasValue = valueLabel != null && valueLabel!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(label, style: AppTextStyles.caption),
        ),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasValue ? valueLabel! : (placeholder ?? ''),
                      style: AppTextStyles.bodyRegular.copyWith(
                        color: hasValue ? AppColors.ink : AppColors.inkFaint,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.inkFaint),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 6),
            child: Text(
              errorText!,
              style: AppTextStyles.caption.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

/// A single row inside an [AppSelectField]'s option sheet, matching Figma's
/// "Option de catégorie": vault border + vault text when selected, plain
/// surface + ink text otherwise (per the component's design annotation).
class AppOptionTile extends StatelessWidget {
  const AppOptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.vault : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: selected ? AppColors.vault : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a picked value so a genuine tile tap (even one picking `null`, e.g.
/// "no linked account") can be told apart from the sheet being dismissed
/// with no selection — both would otherwise surface as a bare `null`.
class _SheetPick<T> {
  const _SheetPick(this.value);
  final T value;
}

/// Opens a bottom sheet of [AppOptionTile] rows and returns the picked
/// value, for use behind an [AppSelectField.onTap]. Dismissing the sheet
/// without tapping a tile (barrier tap, drag-down) returns [selected]
/// unchanged rather than `null`, so callers can safely swap in the result
/// without a dismiss silently clearing a nullable selection.
Future<T?> showAppOptionSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  T? selected,
}) async {
  final result = await showModalBottomSheet<_SheetPick<T>>(
    context: context,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.body),
            const SizedBox(height: 12),
            ...options.map(
              (o) => AppOptionTile(
                label: labelOf(o),
                selected: o == selected,
                onTap: () => Navigator.pop(ctx, _SheetPick<T>(o)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return result == null ? selected : result.value;
}

/// Small rounded pill for a category name, matching Figma's
/// "Badge catégorie" (vault-tint background, vault text).
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.vaultTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: AppColors.vault),
      ),
    );
  }
}

/// Rounded progress track with a vault-gradient fill, matching Figma's
/// "Jauge de progression". Pass [trackColor]/[fillColors] to reuse the same
/// shape for over-budget states (e.g. orange/red) elsewhere in the app.
class ProgressGauge extends StatelessWidget {
  const ProgressGauge({
    super.key,
    required this.value,
    this.trackColor = AppColors.surfaceSunken,
    this.fillColors = const [AppColors.vaultDeep, AppColors.vault],
  });

  final double value;
  final Color trackColor;
  final List<Color> fillColors;

  @override
  Widget build(BuildContext context) {
    final ratio = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 8,
        color: trackColor,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: ratio,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: fillColors),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple row — leading icon/avatar, label, trailing widget (chevron by
/// default) — matching Figma's "Item de liste". Used for flat navigation
/// lists (Settings, Accounts, Categories, Recurring) in place of a bare
/// [ListTile] so they pick up the design system's spacing/type/ink tokens.
class AppListItem extends StatelessWidget {
  const AppListItem({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.titleColor,
  });

  final String title;
  final Widget? leading;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final chevron = Icon(
      Directionality.of(context) == TextDirection.rtl
          ? Icons.chevron_left
          : Icons.chevron_right,
      color: AppColors.inkFaint,
    );
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyRegular.copyWith(
                        color: !enabled ? AppColors.inkFaint : (titleColor ?? AppColors.ink),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
              trailing ?? (onTap != null ? chevron : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

/// 32px circular icon avatar with the app's vault-tint treatment, matching
/// the ellipse leading marker used in "Item de liste" / "Carte transaction".
class AppIconAvatar extends StatelessWidget {
  const AppIconAvatar({super.key, required this.icon, this.radius = 16});

  final IconData icon;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.vaultTint,
      child: Icon(icon, color: AppColors.vault, size: radius),
    );
  }
}

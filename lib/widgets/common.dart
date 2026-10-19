import 'package:flutter/material.dart';

import '../app/localization.dart';
import '../app/theme.dart';
import '../models/country.dart';

/// A bordered surface panel — the primary container of the whole UI.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.action,
    this.padding = WD.padCard,
    this.dense = false,
    this.accentBorder = false,
  });

  final Widget child;
  final String? title;
  final Widget? action;
  final EdgeInsets padding;
  final bool dense;
  final bool accentBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WD.surface1,
        borderRadius: BorderRadius.circular(WD.radiusMd),
        border: Border.all(color: accentBorder ? WD.accentDim : WD.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: padding.horizontal / 1,
                vertical: dense ? 7 : 9,
              ),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: WD.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: WD.textSecondary,
                      ),
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// A labelled numeric figure used across every dashboard and dossier.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.footnote,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final String? footnote;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: WD.textMuted),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                style: text.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: (compact ? text.titleSmall : text.titleMedium)?.copyWith(
            color: valueColor ?? WD.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (footnote != null) ...[
          const SizedBox(height: 1),
          Text(
            footnote!,
            style: text.labelSmall?.copyWith(fontSize: 9.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// Small uppercase section heading with an optional rule.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.color});

  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 2, height: 12, color: color ?? WD.accent),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color ?? WD.accent),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Neutral empty state — used instead of a blank area.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.compact = false,
    this.action,
  });

  final String message;
  final IconData icon;
  final bool compact;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 14 : 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 22 : 30, color: WD.textMuted),
          SizedBox(height: compact ? 6 : 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

/// A two-option or three-option segmented control with square corners.
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.expand = false,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final isSelected = value == selected;
      children.add(
        GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: WD.fast,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? WD.accentDim : Colors.transparent,
              borderRadius: BorderRadius.circular(WD.radiusSm - 2),
            ),
            child: Text(
              labels[i],
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 12,
                color: isSelected ? WD.textPrimary : WD.textMuted,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: WD.surface2,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        border: Border.all(color: WD.line),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: expand
            ? children.map((c) => Expanded(child: c)).toList(growable: false)
            : children,
      ),
    );
  }
}

/// The real national flag of a nation.
///
/// Flags are bundled as `assets/flags/<id>.png` (public-domain renderings).
/// If an image is missing the widget falls back to the authored three-stripe
/// palette so the UI never shows a broken image.
class CountryFlag extends StatelessWidget {
  const CountryFlag({
    super.key,
    required this.country,
    this.width = 30,
    this.height = 20,
    this.showIso = false,
  });

  final Country country;
  final double width;
  final double height;
  final bool showIso;

  static String assetFor(String countryId) => 'assets/flags/$countryId.png';

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(2);

    final Widget flag = Image.asset(
      assetFor(country.id),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _StripeFlag(colors: country.flagColors),
    );

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: WD.lineStrong, width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          flag,
          if (showIso)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: WD.void0.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  country.iso,
                  style: const TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fallback three-band flag drawn from the authored palette.
class _StripeFlag extends StatelessWidget {
  const _StripeFlag({required this.colors});

  final List<int> colors;

  @override
  Widget build(BuildContext context) {
    final c = colors.map(Color.new).toList(growable: false);
    if (c.length < 3) {
      return ColoredBox(color: c.isEmpty ? WD.surface3 : c.first);
    }
    return Column(
      children: [
        Expanded(child: ColoredBox(color: c[0])),
        Expanded(child: ColoredBox(color: c[1])),
        Expanded(child: ColoredBox(color: c[2])),
      ],
    );
  }
}

/// A linear meter for 0-100 values such as stability and readiness.
class Meter extends StatelessWidget {
  const Meter({
    super.key,
    required this.fraction,
    this.color = WD.accent,
    this.height = 5,
    this.background,
  });

  final double fraction;
  final Color color;
  final double height;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: [
          Container(height: height, color: background ?? WD.surface3),
          FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: Container(height: height, color: color),
          ),
        ],
      ),
    );
  }
}

/// A labelled value row: right-hand aligned, tabular figures.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.dense = false,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: dense ? 4 : 6),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: WD.textMuted),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text(
                label,
                style: style.bodySmall?.copyWith(color: WD.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: style.titleSmall?.copyWith(
                color: valueColor ?? WD.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared confirmation dialog. Returns `true` only on explicit confirmation.
Future<bool> confirmAction({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: WD.danger,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// A compact pill used for tags such as ALLY / AT WAR / doctrine names.
class Tag extends StatelessWidget {
  const Tag(
    this.label, {
    super.key,
    this.color = WD.accent,
    this.icon,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.20) : Colors.transparent,
        border: Border.all(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9.5, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Colour helper for a signed value (money, relations, stability deltas).
Color signedColor(double value) {
  if (value > 0.01) return WD.positive;
  if (value < -0.01) return WD.danger;
  return WD.textSecondary;
}

/// Convenience accessor for the localized strings and formatter.
extension BuildContextL10n on BuildContext {
  AppStrings get l10n => AppStrings.of(this);
}

/// The World Dominion brand emblem with a soft brass/teal halo.
class BrandEmblem extends StatelessWidget {
  const BrandEmblem({super.key, this.size = 120, this.glow = true});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final emblem = Image.asset(
      'assets/brand/emblem.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'World Dominion',
    );
    if (!glow) return emblem;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.9,
            height: size * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: WD.brass.withValues(alpha: 0.22),
                  blurRadius: size * 0.45,
                  spreadRadius: size * 0.02,
                ),
                BoxShadow(
                  color: WD.accent.withValues(alpha: 0.18),
                  blurRadius: size * 0.25,
                ),
              ],
            ),
          ),
          emblem,
        ],
      ),
    );
  }
}

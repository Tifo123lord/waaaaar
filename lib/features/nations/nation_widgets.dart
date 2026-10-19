import 'package:flutter/material.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/country.dart';
import '../../models/game_state.dart';
import 'nation_stats.dart';

/// Everything a dashboard tab needs, bundled once per build.
class NationContext {
  NationContext({
    required this.state,
    required this.stats,
    required this.country,
    required this.l10n,
  }) : fmt = Fmt(l10n),
       labels = NationLabels(l10n.isPersian);

  final GameState state;
  final WorldStats stats;
  final Country country;
  final AppStrings l10n;
  final Fmt fmt;
  final NationLabels labels;

  bool get fa => l10n.isPersian;
  String get id => country.id;
  bool get isPlayer => id == state.playerId;
  NationSnapshot get snap => stats.of(id);

  String nameOf(String countryId) {
    final c = state.countries[countryId];
    if (c == null) return countryId.toUpperCase();
    return fa ? c.nameFa : c.nameEn;
  }

  /// Formats a metric value for display.
  String value(NationMetric m, double v) => switch (m) {
    NationMetric.power => fmt.number(v),
    NationMetric.income => fmt.credits(v),
    NationMetric.net => fmt.creditsSigned(v),
    NationMetric.treasury => fmt.credits(v),
    NationMetric.industry => fmt.number(v, decimals: v < 100 ? 1 : 0),
    NationMetric.army => fmt.number(v),
    NationMetric.population => fmt.population(v),
    NationMetric.stability => fmt.percentLabel(v / 100),
    NationMetric.infrastructure => fmt.percentLabel(v / 100),
    NationMetric.territory => fmt.integer(v),
    NationMetric.techs => fmt.integer(v),
  };

  static IconData iconOf(NationMetric m) => switch (m) {
    NationMetric.power => Icons.bolt_outlined,
    NationMetric.income => Icons.trending_up,
    NationMetric.net => Icons.swap_vert,
    NationMetric.treasury => Icons.account_balance_wallet_outlined,
    NationMetric.industry => Icons.factory_outlined,
    NationMetric.army => Icons.shield_outlined,
    NationMetric.population => Icons.people_outline,
    NationMetric.stability => Icons.balance,
    NationMetric.infrastructure => Icons.alt_route,
    NationMetric.territory => Icons.map_outlined,
    NationMetric.techs => Icons.science_outlined,
  };
}

/// A small "#3" pill showing a world rank.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank, required this.of, this.fmt});

  final int rank;
  final int of;
  final Fmt? fmt;

  @override
  Widget build(BuildContext context) {
    final color = rank <= 3
        ? WD.brass
        : rank <= (of / 3).ceil()
        ? WD.accent
        : WD.textMuted;
    final label = fmt == null ? '#$rank' : '#${fmt!.integer(rank)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// A key figure tile with its world rank.
class RankedStatTile extends StatelessWidget {
  const RankedStatTile({
    super.key,
    required this.ctx,
    required this.metric,
    this.onTap,
  });

  final NationContext ctx;
  final NationMetric metric;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final v = ctx.snap[metric];
    final color = metric == NationMetric.net || metric == NationMetric.treasury
        ? (v < 0
              ? WD.danger
              : (metric == NationMetric.net ? WD.positive : WD.textPrimary))
        : WD.textPrimary;
    return Material(
      color: WD.surface2,
      borderRadius: BorderRadius.circular(WD.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WD.radiusSm),
            border: Border.all(color: WD.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    NationContext.iconOf(metric),
                    size: 12,
                    color: WD.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      ctx.labels.metricShort(metric),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall?.copyWith(fontSize: 10),
                    ),
                  ),
                  RankBadge(
                    rank: ctx.stats.rankOf(ctx.id, metric),
                    of: ctx.stats.count,
                    fmt: ctx.fmt,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                ctx.value(metric, v),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(
                  fontSize: 15,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact label/value pair laid out in a grid cell.
class MiniFigure extends StatelessWidget {
  const MiniFigure({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.icon,
  });

  final String label;
  final String value;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: WD.surface2,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        border: Border.all(color: WD.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 11, color: WD.textMuted),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall?.copyWith(
              color: color ?? WD.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays children out as an N-column grid that sizes to its content.
class FigureGrid extends StatelessWidget {
  const FigureGrid({
    super.key,
    required this.children,
    this.columns = 3,
    this.spacing = 8,
  });

  final List<Widget> children;
  final int columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final c in children) SizedBox(width: w, child: c)],
        );
      },
    );
  }
}

/// Opens the shared attitude label for a relation score.
String attitudeKey(double r) {
  if (r <= -45) return 'hostile';
  if (r <= -15) return 'cold';
  if (r < 20) return 'neutral';
  if (r < 55) return 'warm';
  return 'friendly';
}

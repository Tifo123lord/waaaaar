import 'package:flutter/material.dart';

import '../app/localization.dart';
import '../app/theme.dart';
import '../core/format.dart';
import '../data/country_leaders.dart';
import '../models/country.dart';
import 'common.dart';

/// Accent colour per office group.
Color leaderGroupColor(LeaderGroup g) => switch (g) {
  LeaderGroup.executive => WD.brass,
  LeaderGroup.cabinet => WD.info,
  LeaderGroup.military => WD.danger,
};

IconData leaderRoleIcon(LeaderRole r) => switch (r) {
  LeaderRole.supremeLeader => Icons.auto_awesome,
  LeaderRole.headOfState => Icons.account_balance,
  LeaderRole.deputyHeadOfState => Icons.how_to_vote_outlined,
  LeaderRole.headOfGovernment => Icons.gavel,
  LeaderRole.foreignMinister => Icons.public,
  LeaderRole.defenceMinister => Icons.shield_outlined,
  LeaderRole.chiefOfDefence => Icons.military_tech,
  LeaderRole.serviceCommander => Icons.military_tech_outlined,
};

String leaderGroupLabel(LeaderGroup g, bool fa) => switch (g) {
  LeaderGroup.executive => fa ? 'رهبری و قوه مجریه' : 'Leadership & executive',
  LeaderGroup.cabinet => fa ? 'کابینه' : 'Cabinet',
  LeaderGroup.military => fa ? 'فرماندهان نظامی' : 'Military command',
};

/// "since 20 Jan 2025 · 1 yr 9 mo" — tenure is measured to the verification
/// date so it never drifts with the device clock.
String leaderTenure(Leader l, AppStrings l10n) {
  final fa = l10n.isPersian;
  final fmt = Fmt(l10n);
  final d = l.sinceDate;
  if (d == null) return fa ? 'در منصب' : 'In office';
  final ref = DateTime.parse(CountryLeaders.verifiedOn);
  final month = l10n.months[(d.month - 1) % 12];
  final date = '${fmt.integer(d.day)} $month ${fmt.integer(d.year)}';
  var months = (ref.year - d.year) * 12 + ref.month - d.month;
  if (ref.day < d.day) months -= 1;
  if (months < 0) months = 0;
  final y = months ~/ 12, m = months % 12;
  final String span;
  if (months == 0) {
    span = fa ? 'کمتر از یک ماه' : '< 1 mo';
  } else if (fa) {
    span = [
      if (y > 0) '${fmt.integer(y)} سال',
      if (m > 0) '${fmt.integer(m)} ماه',
    ].join(' و ');
  } else {
    span = [if (y > 0) '$y yr', if (m > 0) '$m mo'].join(' ');
  }
  return fa ? 'از $date · $span' : 'Since $date · $span';
}

/// Rounded portrait with an initials fallback.
class LeaderPortrait extends StatelessWidget {
  const LeaderPortrait({
    super.key,
    required this.leader,
    this.width = 56,
    this.height = 70,
    this.radius = 6,
    this.borderColor,
  });

  final Leader leader;
  final double width, height, radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final color = borderColor ?? leaderGroupColor(leader.role.group);
    final fallback = Container(
      color: WD.surface3,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            leaderRoleIcon(leader.role),
            size: width * 0.32,
            color: color.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 2),
          Text(
            leader.initials,
            style: TextStyle(
              color: WD.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: width * 0.22,
            ),
          ),
        ],
      ),
    );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: 0.85), width: 1.3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: leader.portrait == null
            ? fallback
            : Image.asset(
                leader.portrait!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                cacheWidth: (width * 3).round(),
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

/// One row of the leadership panel.
class LeaderTile extends StatelessWidget {
  const LeaderTile({super.key, required this.leader, this.onTap});

  final Leader leader;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final fa = l10n.isPersian;
    final text = Theme.of(context).textTheme;
    final color = leaderGroupColor(leader.role.group);
    return InkWell(
      onTap: onTap ?? () => showLeaderSheet(context, leader),
      borderRadius: BorderRadius.circular(WD.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            LeaderPortrait(leader: leader, width: 48, height: 60),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(leaderRoleIcon(leader.role), size: 11, color: color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          leader.title(fa),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    leader.fullName(fa),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      color: WD.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    leader.hereditary
                        ? '${leaderTenure(leader, l10n)} · ${fa ? 'موروثی' : 'Hereditary'}'
                        : leaderTenure(leader, l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: WD.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Full leadership panel grouped by executive / cabinet / military.
class LeadershipPanel extends StatelessWidget {
  const LeadershipPanel({
    super.key,
    required this.countryId,
    this.title,
    this.compact = false,
  });

  final String countryId;
  final String? title;

  /// Compact mode shows a single horizontal strip of portraits.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fa = AppStrings.of(context).isPersian;
    final leaders = CountryLeaders.of(countryId);
    if (leaders.isEmpty) return const SizedBox.shrink();
    final heading = title ?? (fa ? 'رهبران و مقامات' : 'Leaders & officials');
    if (compact) {
      return Panel(
        title: heading,
        child: LeaderStrip(leaders: leaders),
      );
    }
    final groups = <LeaderGroup, List<Leader>>{};
    for (final l in leaders) {
      groups.putIfAbsent(l.role.group, () => []).add(l);
    }
    final text = Theme.of(context).textTheme;
    return Panel(
      title: heading,
      action: Tooltip(
        message: fa
            ? 'به‌روز شده: ${CountryLeaders.verifiedOn}'
            : 'Verified ${CountryLeaders.verifiedOn}',
        child: const Icon(Icons.verified_outlined, size: 14, color: WD.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final g in LeaderGroup.values)
            if (groups[g] != null) ...[
              if (g != LeaderGroup.executive) const SizedBox(height: 6),
              Row(
                children: [
                  Container(width: 3, height: 12, color: leaderGroupColor(g)),
                  const SizedBox(width: 6),
                  Text(
                    leaderGroupLabel(g, fa).toUpperCase(),
                    style: text.labelSmall?.copyWith(
                      color: leaderGroupColor(g),
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              for (final l in groups[g]!) LeaderTile(leader: l),
            ],
        ],
      ),
    );
  }
}

/// Horizontal strip of portrait cards.
class LeaderStrip extends StatelessWidget {
  const LeaderStrip({super.key, required this.leaders, this.height = 150});

  final List<Leader> leaders;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fa = AppStrings.of(context).isPersian;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: leaders.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final l = leaders[i];
          final color = leaderGroupColor(l.role.group);
          return InkWell(
            onTap: () => showLeaderSheet(context, l),
            borderRadius: BorderRadius.circular(WD.radiusSm),
            child: SizedBox(
              width: 76,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  LeaderPortrait(leader: l, width: 72, height: 90),
                  const SizedBox(height: 5),
                  Text(
                    l.name(fa),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: WD.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    l.title(fa),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(color: color, fontSize: 9),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compact "head of state" chip for headers.
class ParamountLeaderChip extends StatelessWidget {
  const ParamountLeaderChip({super.key, required this.countryId});

  final String countryId;

  @override
  Widget build(BuildContext context) {
    final l = CountryLeaders.paramount(countryId);
    if (l == null) return const SizedBox.shrink();
    final fa = AppStrings.of(context).isPersian;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => showLeaderSheet(context, l),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(2, 2, 10, 2),
        decoration: BoxDecoration(
          color: const Color(0xAA07090B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: WD.brass.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LeaderPortrait(
              leader: l,
              width: 22,
              height: 22,
              radius: 11,
              borderColor: WD.brass,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${l.title(fa)}: ${l.name(fa)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with a large portrait and the officeholder's details.
Future<void> showLeaderSheet(BuildContext context, Leader l) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: WD.surface1,
    builder: (context) {
      final l10n = AppStrings.of(context);
      final fa = l10n.isPersian;
      final text = Theme.of(context).textTheme;
      final color = leaderGroupColor(l.role.group);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: WD.lineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LeaderPortrait(leader: l, width: 110, height: 138, radius: 8),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tag(
                          leaderGroupLabel(l.role.group, fa).toUpperCase(),
                          color: color,
                          icon: leaderRoleIcon(l.role),
                          filled: true,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.name(fa),
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (fa) ...[
                          const SizedBox(height: 2),
                          Text(
                            l.nameEn,
                            textDirection: TextDirection.ltr,
                            style: text.labelSmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          l.title(fa),
                          style: text.bodyMedium?.copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (l.rank(fa) != null)
                KeyValueRow(label: fa ? 'درجه' : 'Rank', value: l.rank(fa)!),
              KeyValueRow(
                label: fa ? 'در منصب' : 'In office',
                value: leaderTenure(l, l10n),
              ),
              KeyValueRow(
                label: fa ? 'نوع منصب' : 'Tenure',
                value: l.hereditary
                    ? (fa ? 'موروثی (سلطنتی)' : 'Hereditary (monarch)')
                    : l.role.group == LeaderGroup.military
                    ? (fa ? 'انتصابی (نظامی)' : 'Appointed (military)')
                    : l.role == LeaderRole.supremeLeader
                    ? (fa
                          ? 'منتخب مجلس خبرگان'
                          : 'Chosen by Assembly of Experts')
                    : (fa ? 'سیاسی' : 'Political'),
              ),
              const SizedBox(height: 10),
              Text(
                fa
                    ? 'منبع: ویکی‌پدیا / ویکی‌داده · تصویر: ویکی‌مدیا کامنز · به‌روز: ${Fmt(l10n).digits(CountryLeaders.verifiedOn)}'
                    : 'Source: Wikipedia / Wikidata · Photo: Wikimedia Commons · Verified ${CountryLeaders.verifiedOn}',
                style: text.labelSmall?.copyWith(fontSize: 9.5),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Convenience for screens that have a [Country] rather than an id.
class CountryLeadershipPanel extends StatelessWidget {
  const CountryLeadershipPanel({super.key, required this.country});

  final Country country;

  @override
  Widget build(BuildContext context) => LeadershipPanel(countryId: country.id);
}

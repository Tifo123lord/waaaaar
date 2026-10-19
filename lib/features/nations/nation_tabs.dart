import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/balance.dart';
import '../../core/campaign_controller.dart';
import '../../data/tech_tree.dart';
import '../../models/diplomatic_agreement.dart';
import '../../models/history.dart';
import '../../models/military_unit.dart';
import '../../models/region.dart';
import '../../simulation/economy_engine.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/country_culture_view.dart';
import '../../widgets/leaders_view.dart';
import '../../data/country_leaders.dart';
import '../events/events_screen.dart' show EventRow;
import 'nation_stats.dart';
import 'nation_widgets.dart';

const _gap = SizedBox(height: 12);

String _noHistory(NationContext ctx) => ctx.fa
    ? 'داده کافی نیست — چند روز بازی را جلو ببرید.'
    : 'Not enough data yet — let a few days pass.';

// =============================================================== LEADERS

/// Real-world leadership: supreme leader, head of state and government,
/// foreign and defence ministers and the top military commanders.
class LeadersTab extends StatelessWidget {
  const LeadersTab({super.key, required this.ctx});

  final NationContext ctx;

  @override
  Widget build(BuildContext context) {
    final fa = ctx.fa;
    final text = Theme.of(context).textTheme;
    final c = ctx.country;
    final leaders = CountryLeaders.of(c.id);
    if (leaders.isEmpty) {
      return Center(
        child: Text(
          fa ? 'اطلاعاتی موجود نیست.' : 'No leadership data.',
          style: text.bodySmall,
        ),
      );
    }
    final paramount = CountryLeaders.paramount(c.id)!;
    final military = leaders
        .where((l) => l.role.group == LeaderGroup.military)
        .length;
    return ListView(
      padding: WD.padScreen,
      children: [
        Panel(
          accentBorder: true,
          child: InkWell(
            onTap: () => showLeaderSheet(context, paramount),
            child: Row(
              children: [
                LeaderPortrait(
                  leader: paramount,
                  width: 92,
                  height: 116,
                  radius: 8,
                  borderColor: WD.brass,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tag(
                        fa ? 'قدرت اول کشور' : 'PARAMOUNT LEADER',
                        color: WD.brass,
                        icon: Icons.star,
                        filled: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        paramount.name(fa),
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${paramount.title(fa)} · ${ctx.nameOf(c.id)}',
                        style: text.bodySmall?.copyWith(color: WD.brass),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        leaderTenure(paramount, ctx.l10n),
                        style: text.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _gap,
        FigureGrid(
          columns: 3,
          children: [
            StatTile(
              label: fa ? 'مقامات' : 'Officials',
              value: ctx.fmt.integer(leaders.length),
              icon: Icons.groups_outlined,
            ),
            StatTile(
              label: fa ? 'نظام' : 'System',
              value: _systemLabel(c.id, fa),
              icon: Icons.account_balance_outlined,
              compact: true,
            ),
            StatTile(
              label: fa ? 'فرماندهان' : 'Commanders',
              value: ctx.fmt.integer(military),
              icon: Icons.military_tech_outlined,
            ),
          ],
        ),
        _gap,
        LeadershipPanel(countryId: c.id),
        const SizedBox(height: 10),
        Text(
          fa
              ? 'نام‌ها و مناصب بر اساس منابع عمومی (ویکی‌پدیا/ویکی‌داده) تا تاریخ ${ctx.fmt.digits(CountryLeaders.verifiedOn)} به‌روز شده‌اند. تصاویر: ویکی‌مدیا کامنز.'
              : 'Names and offices verified against public sources (Wikipedia / Wikidata) as of ${CountryLeaders.verifiedOn}. Portraits: Wikimedia Commons.',
          style: text.labelSmall?.copyWith(fontSize: 9.5),
        ),
      ],
    );
  }

  static String _systemLabel(String id, bool fa) {
    const systems = <String, (String, String)>{
      'ir': ('Islamic Republic', 'جمهوری اسلامی'),
      'sa': ('Absolute monarchy', 'پادشاهی مطلقه'),
      'ae': ('Federal monarchy', 'فدراسیون امیرنشین‌ها'),
      'cn': ('One-party state', 'تک‌حزبی'),
      'vn': ('One-party state', 'تک‌حزبی'),
      'fr': ('Semi-presidential', 'نیمه‌ریاستی'),
      'ru': ('Semi-presidential', 'نیمه‌ریاستی'),
      'ua': ('Semi-presidential', 'نیمه‌ریاستی'),
      'pl': ('Parl. republic', 'جمهوری پارلمانی'),
      'kz': ('Presidential', 'ریاستی'),
      'eg': ('Presidential', 'ریاستی'),
      'kr': ('Presidential', 'ریاستی'),
    };
    const constitutional = {
      'ca',
      'uk',
      'es',
      'nl',
      'se',
      'no',
      'jp',
      'th',
      'au',
    };
    const parliamentary = {'de', 'it', 'gr', 'il', 'in', 'pk', 'et'};
    final s = systems[id];
    if (s != null) return fa ? s.$2 : s.$1;
    if (constitutional.contains(id)) {
      return fa ? 'پادشاهی مشروطه' : 'Const. monarchy';
    }
    if (parliamentary.contains(id)) {
      return fa ? 'جمهوری پارلمانی' : 'Parl. republic';
    }
    return fa ? 'ریاستی' : 'Presidential';
  }
}

// =============================================================== OVERVIEW

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, required this.ctx, required this.onOpenTab});

  final NationContext ctx;
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final fa = ctx.fa;
    final text = Theme.of(context).textTheme;
    final c = ctx.country;
    final state = ctx.state;
    final history = state.history;
    final playerId = state.playerId;

    final events = state.events.entries
        .where((e) => e.countryId == c.id || e.params.values.contains(c.nameEn))
        .toList()
        .reversed
        .take(6)
        .toList();

    final powerSeries = history.raw(c.id, HistoryMetric.power);
    final playerPower = history.raw(playerId, HistoryMetric.power);
    final avgProfile = [
      for (final m in WorldStats.radarAxes)
        ctx.stats.maxOf(m) <= 0
            ? 0.0
            : ctx.stats.averageOf(m) / ctx.stats.maxOf(m),
    ];

    return ListView(
      padding: WD.padScreen,
      children: [
        FigureGrid(
          columns: 3,
          children: [
            for (final m in const [
              NationMetric.power,
              NationMetric.income,
              NationMetric.net,
              NationMetric.treasury,
              NationMetric.industry,
              NationMetric.army,
              NationMetric.population,
              NationMetric.stability,
              NationMetric.territory,
            ])
              RankedStatTile(
                ctx: ctx,
                metric: m,
                onTap: () => onOpenTab(switch (m) {
                  NationMetric.income ||
                  NationMetric.net ||
                  NationMetric.treasury ||
                  NationMetric.industry => 2,
                  NationMetric.army => 3,
                  NationMetric.territory => 5,
                  _ => 6,
                }),
              ),
          ],
        ),
        if (CountryLeaders.has(c.id)) ...[
          _gap,
          Panel(
            title: fa ? 'رهبران و مقامات' : 'Leaders & officials',
            action: InkWell(
              onTap: () => onOpenTab(1),
              child: Text(
                fa ? 'همه ›' : 'All ›',
                style: text.labelSmall?.copyWith(color: WD.accent),
              ),
            ),
            child: LeaderStrip(leaders: CountryLeaders.of(c.id)),
          ),
        ],
        _gap,
        Panel(
          title: fa ? 'روند قدرت ملی' : 'National power trend',
          child: TrendChart(
            height: 120,
            emptyLabel: _noHistory(ctx),
            formatValue: (v) => ctx.fmt.number(v),
            series: [
              ChartSeries(
                values: powerSeries,
                color: WD.brass,
                label: ctx.nameOf(c.id),
              ),
              if (!ctx.isPlayer)
                ChartSeries(
                  values: playerPower,
                  color: WD.info,
                  label: ctx.nameOf(playerId),
                  fill: false,
                  dashed: true,
                ),
            ],
          ),
        ),
        _gap,
        Panel(
          title: ctx.isPlayer
              ? (fa
                    ? 'نیم‌رخ راهبردی در برابر میانگین جهان'
                    : 'Strategic profile vs world average')
              : (fa
                    ? 'مقایسه با ${ctx.nameOf(playerId)}'
                    : 'Compared with ${ctx.nameOf(playerId)}'),
          child: Column(
            children: [
              RadarChart(
                axes: [
                  for (final m in WorldStats.radarAxes)
                    ctx.labels.metricShort(m),
                ],
                primary: ctx.stats.radarProfile(c.id),
                secondary: ctx.isPlayer
                    ? avgProfile
                    : ctx.stats.radarProfile(playerId),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 14,
                children: [
                  _LegendDot(color: WD.brass, label: ctx.nameOf(c.id)),
                  _LegendDot(
                    color: WD.info,
                    label: ctx.isPlayer
                        ? (fa ? 'میانگین جهان' : 'World average')
                        : ctx.nameOf(playerId),
                  ),
                ],
              ),
            ],
          ),
        ),
        _gap,
        Panel(
          title: fa ? 'وضعیت داخلی' : 'Domestic condition',
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  RingGauge(
                    fraction: c.stability / 100,
                    label: ctx.labels.metricShort(NationMetric.stability),
                    value: ctx.fmt.percentLabel(c.stability / 100),
                    color: c.stability < 35
                        ? WD.danger
                        : c.stability < 55
                        ? WD.warning
                        : WD.positive,
                  ),
                  RingGauge(
                    fraction: c.infrastructure / 100,
                    label: ctx.labels.metricShort(NationMetric.infrastructure),
                    value: ctx.fmt.percentLabel(c.infrastructure / 100),
                    color: WD.info,
                  ),
                  RingGauge(
                    fraction: c.armyReadiness / 100,
                    label: fa ? 'آمادگی' : 'Readiness',
                    value: ctx.fmt.percentLabel(c.armyReadiness / 100),
                    color: WD.accent,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              KeyValueRow(
                dense: true,
                icon: Icons.gavel_outlined,
                label: fa ? 'دکترین' : 'Doctrine',
                value: ctx.l10n.t('ai.${c.personality.name}'),
              ),
              KeyValueRow(
                dense: true,
                icon: Icons.local_fire_department_outlined,
                label: fa ? 'جنگ‌های فعال' : 'Active wars',
                value: ctx.fmt.integer(
                  state.wars.where((w) => w.involves(c.id)).length,
                ),
                valueColor: state.wars.any((w) => w.involves(c.id))
                    ? WD.danger
                    : WD.positive,
              ),
              KeyValueRow(
                dense: true,
                icon: Icons.handshake_outlined,
                label: fa ? 'متحدان' : 'Allies',
                value: ctx.fmt.integer(state.alliesOf(c.id).length),
              ),
              KeyValueRow(
                dense: true,
                icon: Icons.block,
                label: fa ? 'فشار تحریم' : 'Sanction pressure',
                value: ctx.fmt.percentLabel(state.sanctionPressureOn(c.id)),
                valueColor: state.sanctionPressureOn(c.id) > 0
                    ? WD.warning
                    : WD.textPrimary,
              ),
              KeyValueRow(
                dense: true,
                icon: Icons.public,
                label: fa ? 'سهم از اقتصاد جهان' : 'Share of world economy',
                value: ctx.fmt.percentLabel(
                  ctx.stats.shareOf(c.id, NationMetric.income),
                  decimals: 1,
                ),
              ),
            ],
          ),
        ),
        _gap,
        Panel(
          title: fa ? 'ارزیابی' : 'Assessment',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bullet(
                icon: Icons.add_circle_outline,
                color: WD.positive,
                title: ctx.l10n.t('select.strengths'),
                body: fa ? c.strengthsFa : c.strengthsEn,
              ),
              const SizedBox(height: 10),
              _Bullet(
                icon: Icons.remove_circle_outline,
                color: WD.danger,
                title: ctx.l10n.t('select.weaknesses'),
                body: fa ? c.weaknessesFa : c.weaknessesEn,
              ),
            ],
          ),
        ),
        _gap,
        Panel(
          title: fa ? 'رویدادهای مرتبط' : 'Related events',
          child: events.isEmpty
              ? EmptyState(
                  message: ctx.l10n.t('evt.empty'),
                  icon: Icons.receipt_long_outlined,
                  compact: true,
                )
              : Column(
                  children: [
                    for (final e in events) EventRow(event: e, state: state),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Text(
          fa
              ? 'همه ارقام، مقادیر نمایشی و خیالی بازی هستند.'
              : 'All figures are fictionalised gameplay values.',
          textAlign: TextAlign.center,
          style: text.labelSmall?.copyWith(fontSize: 9.5),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text.titleSmall?.copyWith(color: color, fontSize: 12.5),
              ),
              const SizedBox(height: 2),
              Text(body, style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================================ ECONOMY

class EconomyTab extends StatelessWidget {
  const EconomyTab({super.key, required this.ctx});

  final NationContext ctx;

  @override
  Widget build(BuildContext context) {
    final fa = ctx.fa;
    final c = ctx.country;
    final state = ctx.state;
    final budget = ctx.stats.budgetOf(c.id);
    final history = state.history;
    final l10n = ctx.l10n;
    final maxLine = [
      ...budget.income.map((b) => b.amount),
      ...budget.expenses.map((b) => b.amount),
    ].fold<double>(1, (a, b) => b > a ? b : a);
    final construction = state.constructionOf(c.id);
    final production = state.productionOf(c.id);
    final partners = state.tradePartnersOf(c.id);
    final sanctionsOn = state.politics.sanctionsOn(c.id);
    final sanctionsBy = state.politics.sanctionsBy(c.id);

    return ListView(
      padding: WD.padScreen,
      children: [
        FigureGrid(
          columns: 3,
          children: [
            RankedStatTile(ctx: ctx, metric: NationMetric.income),
            RankedStatTile(ctx: ctx, metric: NationMetric.net),
            RankedStatTile(ctx: ctx, metric: NationMetric.treasury),
          ],
        ),
        _gap,
        Panel(
          title: fa ? 'بودجه ماهانه' : 'Monthly budget',
          child: Column(
            children: [
              for (final line in budget.income)
                BarRow(
                  label: l10n.t(line.labelKey),
                  value: '+${ctx.fmt.credits(line.amount)}',
                  fraction: line.amount / maxLine,
                  color: WD.positive,
                ),
              const Divider(height: 14),
              for (final line in budget.expenses)
                BarRow(
                  label: l10n.t(line.labelKey),
                  value: '-${ctx.fmt.credits(line.amount)}',
                  fraction: line.amount / maxLine,
                  color: WD.danger,
                ),
              const Divider(height: 14),
              KeyValueRow(
                label: l10n.t('res.income'),
                value: ctx.fmt.money(budget.totalIncome),
                valueColor: WD.positive,
              ),
              KeyValueRow(
                label: l10n.t('res.expenses'),
                value: ctx.fmt.money(budget.totalExpenses),
                valueColor: WD.danger,
              ),
              KeyValueRow(
                label: l10n.t('res.net'),
                value: ctx.fmt.moneySigned(budget.net),
                valueColor: signedColor(budget.net),
              ),
              KeyValueRow(
                label: fa ? 'خالص روزانه' : 'Daily net',
                value: ctx.fmt.creditsSigned(budget.dailyNet),
                valueColor: signedColor(budget.dailyNet),
                dense: true,
              ),
            ],
          ),
        ),
        _gap,
        Panel(
          title: fa ? 'روند درآمد ماهانه' : 'Monthly income trend',
          child: TrendChart(
            emptyLabel: _noHistory(ctx),
            formatValue: (v) => ctx.fmt.credits(v),
            series: [
              ChartSeries(
                values: history.raw(c.id, HistoryMetric.economy),
                color: WD.positive,
              ),
            ],
          ),
        ),
        _gap,
        Panel(
          title: fa ? 'روند خزانه' : 'Treasury trend',
          child: TrendChart(
            emptyLabel: _noHistory(ctx),
            formatValue: (v) => ctx.fmt.credits(v),
            series: [
              ChartSeries(
                values: history.raw(c.id, HistoryMetric.treasury),
                color: WD.brass,
              ),
            ],
          ),
        ),
        _gap,
        Panel(
          title: fa ? 'صنعت' : 'Industry',
          child: Column(
            children: [
              FigureGrid(
                columns: 3,
                children: [
                  MiniFigure(
                    icon: Icons.factory_outlined,
                    label: fa ? 'کارخانه غیرنظامی' : 'Civilian factories',
                    value: ctx.fmt.integer(c.civilianFactories),
                  ),
                  MiniFigure(
                    icon: Icons.precision_manufacturing_outlined,
                    label: fa ? 'کارخانه نظامی' : 'Military factories',
                    value: ctx.fmt.integer(c.militaryFactories),
                  ),
                  MiniFigure(
                    icon: Icons.speed,
                    label: fa ? 'ضریب تولید' : 'Output multiplier',
                    value:
                        '×${ctx.fmt.number(c.techFactoryMultiplier, decimals: 2)}',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final type in BuildingType.values)
                KeyValueRow(
                  dense: true,
                  label: l10n.t('eco.${type.name}.name'),
                  value: ctx.fmt.integer(c.buildingCount(type)),
                ),
              KeyValueRow(
                dense: true,
                label: fa ? 'بازده هر واحد صنعتی' : 'Income per industry point',
                value: ctx.fmt.credits(
                  c.industrial <= 0
                      ? 0
                      : budget.industrialOutput / c.industrial,
                ),
              ),
            ],
          ),
        ),
        _gap,
        Panel(
          title: fa
              ? 'منابع راهبردی (تولید روزانه)'
              : 'Strategic resources (daily output)',
          child: _Resources(ctx: ctx),
        ),
        _gap,
        Panel(
          title: l10n.t('dash.construction'),
          child: construction.isEmpty && production.isEmpty
              ? EmptyState(
                  message: l10n.t('dash.idle'),
                  icon: Icons.construction,
                  compact: true,
                )
              : Column(
                  children: [
                    for (final o in construction) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.construction,
                            size: 13,
                            color: WD.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.t('eco.${o.type.name}.name'),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            l10n.t('eco.readyIn', {
                              'n': ctx.fmt.integer(o.daysRemaining),
                            }),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Meter(fraction: o.fraction),
                      const SizedBox(height: 10),
                    ],
                    for (final o in production) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 13,
                            color: WD.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${ctx.labels.equipment(o.type)} ×${ctx.fmt.integer(o.quantity)}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            l10n.t('eco.readyIn', {
                              'n': ctx.fmt.integer(o.daysRemaining),
                            }),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Meter(fraction: o.fraction, color: WD.info),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
        _gap,
        Panel(
          title: fa ? 'تجارت و تحریم‌ها' : 'Trade & sanctions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SubHeader(fa ? 'شرکای تجاری' : 'Trade partners'),
              partners.isEmpty
                  ? _Muted(
                      fa
                          ? 'قرارداد تجاری فعالی ندارد'
                          : 'No active trade deals',
                    )
                  : _FlagWrap(ctx: ctx, ids: partners),
              const SizedBox(height: 10),
              _SubHeader(
                fa
                    ? 'تحریم‌های اعمال‌شده بر این کشور'
                    : 'Sanctions on this nation',
              ),
              if (sanctionsOn.isEmpty)
                _Muted(fa ? 'تحریمی وجود ندارد' : 'None')
              else
                for (final s in sanctionsOn)
                  KeyValueRow(
                    dense: true,
                    label: ctx.nameOf(s.imposerId),
                    value: ctx.labels.sanctionTier(s.tier),
                    valueColor: WD.danger,
                    icon: Icons.block,
                  ),
              const SizedBox(height: 10),
              _SubHeader(
                fa ? 'تحریم‌های اعمال‌شده توسط این کشور' : 'Sanctions imposed',
              ),
              if (sanctionsBy.isEmpty)
                _Muted(fa ? 'تحریمی وجود ندارد' : 'None')
              else
                for (final s in sanctionsBy)
                  KeyValueRow(
                    dense: true,
                    label: ctx.nameOf(s.targetId),
                    value: ctx.labels.sanctionTier(s.tier),
                    valueColor: WD.warning,
                    icon: Icons.outbond_outlined,
                  ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _Resources extends StatelessWidget {
  const _Resources({required this.ctx});
  final NationContext ctx;

  static const _aliases = {'aluminium': 'alu'};

  double _production(String key) =>
      ctx.country.resourceProduction[key] ??
      ctx.country.resourceProduction[_aliases[key]] ??
      0;

  @override
  Widget build(BuildContext context) {
    final values = {
      for (final r in ResourceType.values) r: _production(r.name),
    };
    final max = values.values.fold<double>(1, (a, b) => b > a ? b : a);
    if (values.values.every((v) => v <= 0)) {
      return _Muted(ctx.fa ? 'داده‌ای ثبت نشده' : 'No data recorded');
    }
    return Column(
      children: [
        for (final r in ResourceType.values)
          BarRow(
            leading: Icon(_icon(r), size: 13, color: WD.textMuted),
            label: ctx.labels.resource(r),
            value:
                ctx.fmt.number(values[r]!, decimals: 0) +
                (ctx.country.resources.isEmpty
                    ? ''
                    : ' · ${ctx.fa ? 'ذخیره' : 'stock'} ${ctx.fmt.number(ctx.country.resourceStock(r))}'),
            fraction: values[r]! / max,
            color: WD.accent,
          ),
      ],
    );
  }

  static IconData _icon(ResourceType r) => switch (r) {
    ResourceType.oil => Icons.oil_barrel_outlined,
    ResourceType.steel => Icons.hardware_outlined,
    ResourceType.aluminium => Icons.layers_outlined,
    ResourceType.rubber => Icons.circle_outlined,
    ResourceType.food => Icons.grass_outlined,
    ResourceType.energy => Icons.bolt_outlined,
  };
}

// =============================================================== MILITARY

class MilitaryTab extends ConsumerWidget {
  const MilitaryTab({super.key, required this.ctx});

  final NationContext ctx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fa = ctx.fa;
    final l10n = ctx.l10n;
    final text = Theme.of(context).textTheme;
    final c = ctx.country;
    final state = ctx.state;
    final army = state.armyOf(c.id);
    const economy = EconomyEngine();
    final capacity = economy.manpowerCapacityOf(c);
    final units = state.unitsOf(c.id).toList()
      ..sort((a, b) => b.power.compareTo(a.power));
    final wars = state.wars.where((w) => w.involves(c.id)).toList();
    final battles = state.battles.where((b) => b.involves(c.id)).toList();
    final fronts = state.regions.values
        .where(
          (r) =>
              r.frontProgress > 0.5 &&
              (r.ownerId == c.id || r.controllerId == c.id),
        )
        .toList();
    final totalUnits = army.infantryUnits + army.armorUnits;

    final estimate = (!ctx.isPlayer && totalUnits >= 0)
        ? ref.read(campaignProvider.notifier).estimateBattle(c.id)
        : null;

    return ListView(
      padding: WD.padScreen,
      children: [
        FigureGrid(
          columns: 3,
          children: [
            RankedStatTile(ctx: ctx, metric: NationMetric.army),
            MiniFigure(
              icon: Icons.north_east,
              label: fa ? 'حمله' : 'Attack',
              value: ctx.fmt.number(army.totalAttack),
            ),
            MiniFigure(
              icon: Icons.shield_moon_outlined,
              label: fa ? 'دفاع' : 'Defence',
              value: ctx.fmt.number(army.totalDefense),
            ),
            MiniFigure(
              icon: Icons.speed_outlined,
              label: l10n.t('mil.readiness'),
              value: ctx.fmt.percentLabel(army.readiness / 100),
            ),
            MiniFigure(
              icon: Icons.local_shipping_outlined,
              label: fa ? 'تدارکات' : 'Supply',
              value: ctx.fmt.percentLabel(army.supply / 100),
            ),
            MiniFigure(
              icon: Icons.payments_outlined,
              label: l10n.t('mil.maintenance'),
              value: ctx.fmt.credits(army.monthlyMaintenance),
            ),
          ],
        ),
        _gap,
        Panel(
          title: fa ? 'ترکیب نیروها' : 'Force composition',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: l10n.t('mil.infantry'),
                      value: ctx.fmt.integer(army.infantryUnits),
                      icon: Icons.groups_2_outlined,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: l10n.t('mil.armor'),
                      value: ctx.fmt.integer(army.armorUnits),
                      icon: Icons.directions_car_filled_outlined,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: fa ? 'کل لشکرها' : 'Divisions',
                      value: ctx.fmt.integer(totalUnits),
                      icon: Icons.flag_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (totalUnits > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Row(
                    children: [
                      Expanded(
                        flex: army.infantryUnits.clamp(0, 1 << 20),
                        child: Container(height: 8, color: WD.accent),
                      ),
                      Expanded(
                        flex: army.armorUnits.clamp(0, 1 << 20),
                        child: Container(height: 8, color: WD.brass),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(l10n.t('mil.manpowerUse'), style: text.labelSmall),
              ),
              const SizedBox(height: 5),
              Meter(
                fraction: capacity <= 0 ? 0 : army.manpower / capacity,
                color: capacity > 0 && army.manpower / capacity > 0.9
                    ? WD.warning
                    : WD.accent,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${ctx.fmt.number(army.manpower, decimals: 2)} ${l10n.t('res.million')}',
                    style: text.labelSmall,
                  ),
                  Text(
                    '${ctx.fmt.number(capacity, decimals: 2)} ${l10n.t('res.million')}',
                    style: text.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        _gap,
        Panel(
          title: fa ? 'روند توان ارتش' : 'Army strength trend',
          child: TrendChart(
            emptyLabel: _noHistory(ctx),
            formatValue: (v) => ctx.fmt.number(v),
            series: [
              ChartSeries(
                values: state.history.raw(c.id, HistoryMetric.army),
                color: WD.danger,
                label: ctx.nameOf(c.id),
              ),
              if (!ctx.isPlayer)
                ChartSeries(
                  values: state.history.raw(state.playerId, HistoryMetric.army),
                  color: WD.info,
                  label: ctx.nameOf(state.playerId),
                  fill: false,
                  dashed: true,
                ),
            ],
          ),
        ),
        _gap,
        Panel(
          title: fa ? 'انبار تجهیزات' : 'Equipment stockpile',
          child: FigureGrid(
            columns: 2,
            children: [
              for (final e in EquipmentType.values)
                MiniFigure(
                  label: ctx.labels.equipment(e),
                  value: ctx.fmt.integer(c.equipmentCount(e)),
                ),
            ],
          ),
        ),
        if (estimate != null) ...[
          _gap,
          Panel(
            accentBorder: true,
            title: fa
                ? 'برآورد نبرد: ارتش شما در برابر این کشور'
                : 'War estimate: your army vs this nation',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: fa ? 'توان شما' : 'Your power',
                        value: ctx.fmt.number(estimate.attackerPower),
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: fa ? 'توان آن‌ها' : 'Their power',
                        value: ctx.fmt.number(estimate.defenderPower),
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: fa ? 'شانس پیروزی' : 'Win chance',
                        value: ctx.fmt.percentLabel(estimate.winChance),
                        valueColor: estimate.winChance >= 0.55
                            ? WD.positive
                            : estimate.winChance >= 0.4
                            ? WD.warning
                            : WD.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Meter(
                  fraction: estimate.winChance,
                  color: estimate.winChance >= 0.5 ? WD.positive : WD.danger,
                ),
              ],
            ),
          ),
        ],
        _gap,
        Panel(
          title: fa ? 'جنگ‌ها و جبهه‌ها' : 'Wars & fronts',
          child: wars.isEmpty
              ? EmptyState(
                  message: l10n.t('dash.noWars'),
                  icon: Icons.verified_user_outlined,
                  compact: true,
                )
              : Column(
                  children: [
                    for (final w in wars)
                      KeyValueRow(
                        icon: Icons.gps_fixed,
                        label:
                            '${fa ? 'در برابر' : 'vs'} ${ctx.nameOf(w.opponentOf(c.id))}',
                        value: w.aggressor == c.id
                            ? (fa ? 'مهاجم' : 'Aggressor')
                            : (fa ? 'مدافع' : 'Defender'),
                        valueColor: WD.danger,
                      ),
                    if (battles.isNotEmpty) ...[
                      const Divider(height: 14),
                      for (final b in battles)
                        KeyValueRow(
                          dense: true,
                          icon: Icons.whatshot_outlined,
                          label: fa
                              ? 'نبرد فعال با ${ctx.nameOf(b.opponentOf(c.id))}'
                              : 'Active battle with ${ctx.nameOf(b.opponentOf(c.id))}',
                          value: ctx.fmt.percentLabel(
                            (b.attackerId == c.id
                                    ? b.attackerMorale
                                    : b.defenderMorale) /
                                100,
                          ),
                        ),
                    ],
                    for (final r in fronts) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${ctx.nameOf(r.ownerId)} · ${ctx.labels.sector(WorldRegions.byId(r.id)?.sector ?? '')}',
                              style: text.labelSmall,
                            ),
                          ),
                          Text(
                            ctx.fmt.percentLabel(r.frontProgress / 100),
                            style: text.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Meter(
                        fraction: r.frontProgress / 100,
                        color: WD.danger,
                        height: 4,
                      ),
                    ],
                  ],
                ),
        ),
        _gap,
        Panel(
          title: '${l10n.t('mil.roster')} (${ctx.fmt.integer(units.length)})',
          child: units.isEmpty
              ? EmptyState(
                  message: fa ? 'یگانی ندارد' : 'No formations',
                  icon: Icons.shield_outlined,
                  compact: true,
                )
              : Column(
                  children: [
                    for (final u in units.take(14)) _UnitRow(ctx: ctx, unit: u),
                    if (units.length > 14)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _Muted(
                          fa
                              ? '+ ${ctx.fmt.integer(units.length - 14)} یگان دیگر'
                              : '+ ${units.length - 14} more formations',
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({required this.ctx, required this.unit});
  final NationContext ctx;
  final MilitaryUnit unit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final f = unit.power / unit.maxPower;
    final region = WorldRegions.byId(unit.homeRegion);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            unit.type == UnitType.infantry
                ? Icons.groups_2_outlined
                : Icons.directions_car_filled_outlined,
            size: 15,
            color: unit.type == UnitType.infantry ? WD.accent : WD.brass,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.fa
                      ? '${ctx.l10n.t(unit.type == UnitType.infantry ? 'mil.infantry' : 'mil.armor')} ${ctx.fmt.integer(unit.ordinal)}'
                      : unit.designation(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(fontSize: 12),
                ),
                Text(
                  region == null
                      ? ctx.nameOf(unit.homeRegion)
                      : '${ctx.nameOf(region.countryId)} · ${ctx.labels.sector(region.sector)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(fontSize: 9.5),
                ),
                const SizedBox(height: 3),
                Meter(
                  fraction: f,
                  height: 3,
                  color: f < 0.4
                      ? WD.danger
                      : f < 0.7
                      ? WD.warning
                      : WD.positive,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ctx.fmt.percentLabel(f),
                style: text.titleSmall?.copyWith(fontSize: 11.5),
              ),
              Text(
                '${ctx.fa ? 'تجربه' : 'XP'} ${ctx.fmt.number(unit.experience)}',
                style: text.labelSmall?.copyWith(fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================== DIPLOMACY

class DiplomacyTab extends ConsumerWidget {
  const DiplomacyTab({
    super.key,
    required this.ctx,
    required this.onOpenNation,
  });

  final NationContext ctx;
  final ValueChanged<String> onOpenNation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fa = ctx.fa;
    final l10n = ctx.l10n;
    final text = Theme.of(context).textTheme;
    final c = ctx.country;
    final state = ctx.state;
    final playerId = state.playerId;
    final bloc = state.politics.blocOf(c.id);
    final mind = state.politics.mindOf(c.id);
    final agreements = state.agreements.where((a) => a.involves(c.id)).toList();
    final relations =
        c.relations.entries
            .where((e) => state.countries.containsKey(e.key) && e.key != c.id)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final friends = relations.take(5).toList();
    final rivals = relations.reversed.take(5).toList();

    final controller = ref.read(campaignProvider.notifier);
    final reachable = controller.simulation.diplomacy
        .reachablePartners(state, playerId)
        .contains(c.id);
    final relToPlayer = state.player.relations[c.id] ?? 0;
    final theirRel = c.relations[playerId] ?? 0;
    final atWar = state.atWarWith(playerId, c.id);
    final hasPact = state.hasAgreement(
      playerId,
      c.id,
      AgreementType.nonAggression,
    );
    final hasAlly = state.hasAgreement(playerId, c.id, AgreementType.alliance);

    void feedback() {
      final msg = controller.consumeMessage();
      if (!context.mounted || msg == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t(msg.messageKey, msg.params)),
          backgroundColor: msg.success ? WD.surface3 : WD.dangerDim,
        ),
      );
    }

    String typeLabel(AgreementType t) => switch (t) {
      AgreementType.nonAggression => fa ? 'عدم تجاوز' : 'Non-aggression',
      AgreementType.defencePact => fa ? 'پیمان دفاعی' : 'Defence pact',
      AgreementType.alliance => fa ? 'اتحاد' : 'Alliance',
      AgreementType.trade => fa ? 'تجارت' : 'Trade',
      AgreementType.sanction => fa ? 'تحریم' : 'Sanction',
    };

    return ListView(
      padding: WD.padScreen,
      children: [
        if (!ctx.isPlayer) ...[
          Panel(
            accentBorder: true,
            title: fa
                ? 'رابطه با ${ctx.nameOf(playerId)}'
                : 'Relations with ${ctx.nameOf(playerId)}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: fa ? 'نگاه شما' : 'Your view',
                        value: ctx.fmt.number(relToPlayer),
                        valueColor: signedColor(relToPlayer),
                        footnote: l10n.t(
                          'dip.attitude.${attitudeKey(relToPlayer)}',
                        ),
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: fa ? 'نگاه آن‌ها' : 'Their view',
                        value: ctx.fmt.number(theirRel),
                        valueColor: signedColor(theirRel),
                        footnote: l10n.t(
                          'dip.attitude.${attitudeKey(theirRel)}',
                        ),
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: fa ? 'وضعیت' : 'Status',
                        value: atWar
                            ? (fa ? 'جنگ' : 'War')
                            : hasAlly
                            ? (fa ? 'متحد' : 'Allied')
                            : hasPact
                            ? (fa ? 'پیمان' : 'Pact')
                            : (fa ? 'صلح' : 'Peace'),
                        valueColor: atWar
                            ? WD.danger
                            : hasAlly
                            ? WD.ally
                            : WD.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SignedBar(value: relToPlayer),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ctx.fmt.integer(-100),
                      style: text.labelSmall?.copyWith(fontSize: 9),
                    ),
                    Text(
                      ctx.fmt.integer(0),
                      style: text.labelSmall?.copyWith(fontSize: 9),
                    ),
                    Text(
                      ctx.fmt.integer(100),
                      style: text.labelSmall?.copyWith(fontSize: 9),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (atWar)
                  Text(
                    l10n.t('dip.atWarNoDiplomacy', {'name': ctx.nameOf(c.id)}),
                    style: text.labelSmall?.copyWith(color: WD.danger),
                  )
                else if (!reachable)
                  Text(
                    fa
                        ? 'این کشور خارج از حوزه دسترسی دیپلماتیک شماست.'
                        : 'This nation is outside your diplomatic reach.',
                    style: text.labelSmall,
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              state.player.treasury >=
                                  Balance.costImproveRelations
                              ? () {
                                  controller.improveRelations(c.id);
                                  feedback();
                                }
                              : null,
                          child: Text(
                            l10n.t('dip.improve'),
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              (!hasPact &&
                                  state.player.treasury >=
                                      Balance.costNonAggression)
                              ? () {
                                  controller.proposeAgreement(
                                    c.id,
                                    AgreementType.nonAggression,
                                  );
                                  feedback();
                                }
                              : null,
                          child: Text(
                            hasPact
                                ? l10n.t('common.active')
                                : l10n.t('dip.pact'),
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              (!hasAlly &&
                                  state.player.treasury >= Balance.costAlliance)
                              ? () {
                                  controller.proposeAgreement(
                                    c.id,
                                    AgreementType.alliance,
                                  );
                                  feedback();
                                }
                              : null,
                          child: Text(
                            hasAlly
                                ? l10n.t('common.active')
                                : l10n.t('dip.alliance'),
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          _gap,
        ],
        Panel(
          title: fa ? 'بلوک و سیاست خارجی' : 'Bloc & foreign policy',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (bloc == null)
                KeyValueRow(
                  dense: true,
                  icon: Icons.hub_outlined,
                  label: fa ? 'بلوک' : 'Bloc',
                  value: fa ? 'غیرمتعهد' : 'Non-aligned',
                )
              else ...[
                KeyValueRow(
                  dense: true,
                  icon: Icons.hub_outlined,
                  label: fa ? 'بلوک' : 'Bloc',
                  value: fa ? bloc.nameFa : bloc.nameEn,
                  valueColor: Color(bloc.colorArgb),
                ),
                KeyValueRow(
                  dense: true,
                  label: fa ? 'منشور' : 'Charter',
                  value: ctx.labels.charter(bloc.charter),
                ),
                KeyValueRow(
                  dense: true,
                  label: fa ? 'رهبر' : 'Leader',
                  value: ctx.nameOf(bloc.leaderId),
                ),
                const SizedBox(height: 6),
                _FlagWrap(ctx: ctx, ids: bloc.members, onTap: onOpenNation),
              ],
              if (mind != null && !ctx.isPlayer) ...[
                const Divider(height: 18),
                KeyValueRow(
                  dense: true,
                  icon: Icons.psychology_outlined,
                  label: fa ? 'دستور کار' : 'Agenda',
                  value: ctx.labels.agenda(mind.agenda),
                  valueColor: WD.brass,
                ),
                if (mind.rivalId != null)
                  KeyValueRow(
                    dense: true,
                    label: fa ? 'رقیب اصلی' : 'Main rival',
                    value: ctx.nameOf(mind.rivalId!),
                    valueColor: WD.danger,
                  ),
                if (mind.patronId != null)
                  KeyValueRow(
                    dense: true,
                    label: fa ? 'حامی' : 'Patron',
                    value: ctx.nameOf(mind.patronId!),
                    valueColor: WD.ally,
                  ),
                const SizedBox(height: 4),
                Text(
                  fa ? 'خستگی از جنگ' : 'War weariness',
                  style: text.labelSmall,
                ),
                const SizedBox(height: 4),
                Meter(fraction: mind.warWeariness / 100, color: WD.warning),
              ],
            ],
          ),
        ),
        _gap,
        Panel(
          title:
              '${l10n.t('dip.agreements')} (${ctx.fmt.integer(agreements.length)})',
          child: agreements.isEmpty
              ? EmptyState(
                  message: l10n.t('dip.noAgreements'),
                  icon: Icons.description_outlined,
                  compact: true,
                )
              : Column(
                  children: [
                    for (final a in agreements)
                      KeyValueRow(
                        dense: true,
                        icon: a.type == AgreementType.alliance
                            ? Icons.handshake
                            : Icons.description_outlined,
                        label: ctx.nameOf(a.other(c.id)),
                        value: typeLabel(a.type),
                        valueColor: a.type == AgreementType.alliance
                            ? WD.ally
                            : WD.accent,
                        onTap: () => onOpenNation(a.other(c.id)),
                      ),
                  ],
                ),
        ),
        _gap,
        Panel(
          title: fa ? 'نزدیک‌ترین دوستان' : 'Closest friends',
          child: Column(
            children: [
              for (final e in friends)
                _RelationRow(
                  ctx: ctx,
                  id: e.key,
                  value: e.value,
                  onTap: () => onOpenNation(e.key),
                ),
            ],
          ),
        ),
        _gap,
        Panel(
          title: fa ? 'سرسخت‌ترین رقبا' : 'Fiercest rivals',
          child: Column(
            children: [
              for (final e in rivals)
                _RelationRow(
                  ctx: ctx,
                  id: e.key,
                  value: e.value,
                  onTap: () => onOpenNation(e.key),
                ),
            ],
          ),
        ),
        _gap,
        Panel(
          title: fa ? 'همه روابط' : 'All relations',
          child: Column(
            children: [
              for (final e in relations)
                _RelationRow(
                  ctx: ctx,
                  id: e.key,
                  value: e.value,
                  compact: true,
                  onTap: () => onOpenNation(e.key),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _RelationRow extends StatelessWidget {
  const _RelationRow({
    required this.ctx,
    required this.id,
    required this.value,
    this.compact = false,
    this.onTap,
  });
  final NationContext ctx;
  final String id;
  final double value;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = ctx.state.countries[id]!;
    final atWar = ctx.state.atWarWith(ctx.id, id);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6),
        child: Row(
          children: [
            CountryFlag(
              country: c,
              width: compact ? 20 : 26,
              height: compact ? 13 : 17,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 104,
              child: Text(
                ctx.nameOf(id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(
                  color: id == ctx.state.playerId ? WD.brass : WD.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: SignedBar(value: value, height: compact ? 4 : 6),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 34,
              child: Text(
                ctx.fmt.number(value),
                textAlign: TextAlign.end,
                style: text.titleSmall?.copyWith(
                  fontSize: 11.5,
                  color: signedColor(value),
                ),
              ),
            ),
            if (atWar) ...[
              const SizedBox(width: 4),
              const Icon(Icons.gps_fixed, size: 12, color: WD.danger),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================ DEVELOPMENT

class DevelopmentTab extends StatelessWidget {
  const DevelopmentTab({super.key, required this.ctx});

  final NationContext ctx;

  @override
  Widget build(BuildContext context) {
    final fa = ctx.fa;
    final text = Theme.of(context).textTheme;
    final c = ctx.country;
    final state = ctx.state;
    final owned = state.ownedRegionsOf(c.id);
    final lost = owned.where((r) => r.controllerId != c.id).toList();
    final occupied = state.occupiedBy(c.id);
    final held = owned.length - lost.length;
    final research = c.researchId == null ? null : TechTree.byId(c.researchId!);
    final researchSpeed = c.techResearchMultiplier;

    return ListView(
      padding: WD.padScreen,
      children: [
        Panel(
          title: fa ? 'قلمرو' : 'Territory',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FigureGrid(
                columns: 3,
                children: [
                  MiniFigure(
                    icon: Icons.home_work_outlined,
                    label: fa ? 'مناطق ملی' : 'Home regions',
                    value: ctx.fmt.integer(owned.length),
                  ),
                  MiniFigure(
                    icon: Icons.check_circle_outline,
                    label: fa ? 'تحت کنترل' : 'Held',
                    value: ctx.fmt.integer(held),
                    color: lost.isEmpty ? WD.positive : WD.warning,
                  ),
                  MiniFigure(
                    icon: Icons.flag_circle_outlined,
                    label: fa ? 'اشغال‌شده' : 'Occupied',
                    value: ctx.fmt.integer(occupied.length),
                    color: occupied.isEmpty ? null : WD.brass,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Meter(
                fraction: owned.isEmpty ? 0 : held / owned.length,
                color: lost.isEmpty ? WD.positive : WD.warning,
              ),
              const SizedBox(height: 10),
              for (final r in owned) _RegionRow(ctx: ctx, region: r),
              if (occupied.isNotEmpty) ...[
                const Divider(height: 18),
                _SubHeader(
                  fa
                      ? 'مناطق اشغالی خارجی'
                      : 'Foreign regions under occupation',
                ),
                for (final r in occupied) _RegionRow(ctx: ctx, region: r),
              ],
            ],
          ),
        ),
        _gap,
        Panel(
          title: fa ? 'پژوهش و فناوری' : 'Research & technology',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: fa ? 'فناوری‌های کسب‌شده' : 'Researched',
                      value:
                          '${ctx.fmt.integer(c.techs.length)} / ${ctx.fmt.integer(TechTree.all.length)}',
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: fa ? 'سرعت پژوهش' : 'Research speed',
                      value: '×${ctx.fmt.number(researchSpeed, decimals: 2)}',
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: fa ? 'رتبه فناوری' : 'Tech rank',
                      value:
                          '#${ctx.fmt.integer(ctx.stats.rankOf(c.id, NationMetric.techs))}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (research != null) ...[
                Text(
                  '${fa ? 'در حال پژوهش' : 'Researching'}: ${ctx.labels.tech(research.id)}',
                  style: text.titleSmall?.copyWith(color: WD.accent),
                ),
                const SizedBox(height: 4),
                Meter(
                  fraction: research.days <= 0
                      ? 1
                      : c.researchProgress / research.days,
                  color: WD.accent,
                ),
                const SizedBox(height: 10),
              ],
              for (final branch in TechBranch.values) ...[
                _SubHeader(ctx.labels.branch(branch)),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in TechTree.ofBranch(branch))
                      _TechChip(
                        label: ctx.labels.tech(t.id),
                        tier: t.tier,
                        done: c.hasTech(t.id),
                        active: c.researchId == t.id,
                        fmt: ctx.fmt,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              const Divider(height: 10),
              KeyValueRow(
                dense: true,
                label: fa ? 'ضریب درآمد فناوری' : 'Tech income bonus',
                value: '+${ctx.fmt.percentLabel(c.techIncomeMultiplier - 1)}',
              ),
              KeyValueRow(
                dense: true,
                label: fa ? 'ضریب حمله' : 'Attack bonus',
                value: '+${ctx.fmt.percentLabel(c.techAttackMultiplier - 1)}',
              ),
              KeyValueRow(
                dense: true,
                label: fa ? 'ضریب دفاع' : 'Defence bonus',
                value: '+${ctx.fmt.percentLabel(c.techDefenseMultiplier - 1)}',
              ),
            ],
          ),
        ),
        _gap,
        Panel(
          title: fa ? 'روند صنعت و ثبات' : 'Industry & stability trend',
          child: TrendChart(
            emptyLabel: _noHistory(ctx),
            formatValue: (v) => ctx.fmt.number(v),
            series: [
              ChartSeries(
                values: state.history.raw(c.id, HistoryMetric.industry),
                color: WD.accent,
                label: ctx.labels.metricShort(NationMetric.industry),
              ),
              ChartSeries(
                values: state.history.raw(c.id, HistoryMetric.stability),
                color: WD.info,
                label: ctx.labels.metricShort(NationMetric.stability),
                fill: false,
              ),
            ],
          ),
        ),
        _gap,
        Panel(
          title: fa ? 'اطلاعات ملی' : 'National facts',
          child: CountryFactsGrid(country: c),
        ),
        _gap,
        Panel(
          title: fa ? 'جاذبه‌های دیدنی' : 'Landmarks',
          child: LandmarkGallery(countryId: c.id, height: 120),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _RegionRow extends StatelessWidget {
  const _RegionRow({required this.ctx, required this.region});
  final NationContext ctx;
  final RegionState region;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final geo = WorldRegions.byId(region.id);
    final lost = region.controllerId != region.ownerId;
    final name =
        '${ctx.nameOf(region.ownerId)} · ${ctx.labels.sector(geo?.sector ?? '')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            geo?.capital == true ? Icons.star : Icons.place_outlined,
            size: 13,
            color: geo?.capital == true ? WD.brass : WD.textMuted,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
          ),
          if (region.supplyHub) ...[
            const Icon(Icons.local_shipping_outlined, size: 12, color: WD.info),
            const SizedBox(width: 6),
          ],
          if (region.frontProgress > 0.5) ...[
            Text(
              ctx.fmt.percentLabel(region.frontProgress / 100),
              style: text.labelSmall?.copyWith(color: WD.danger, fontSize: 9.5),
            ),
            const SizedBox(width: 6),
          ],
          Tag(
            lost
                ? (ctx.fa
                      ? 'اشغال: ${ctx.nameOf(region.controllerId)}'
                      : 'Held by ${ctx.nameOf(region.controllerId)}')
                : (ctx.fa ? 'کنترل' : 'Held'),
            color: lost ? WD.danger : WD.positive,
          ),
        ],
      ),
    );
  }
}

class _TechChip extends StatelessWidget {
  const _TechChip({
    required this.label,
    required this.tier,
    required this.done,
    required this.active,
    required this.fmt,
  });
  final String label;
  final int tier;
  final bool done;
  final bool active;
  final dynamic fmt;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? WD.positive
        : active
        ? WD.accent
        : WD.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: done ? WD.positive.withValues(alpha: 0.12) : WD.surface2,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: done || active ? 0.7 : 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done
                ? Icons.check_circle
                : active
                ? Icons.hourglass_top
                : Icons.lock_outline,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: done ? WD.textPrimary : WD.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'T${fmt.integer(tier)}',
            style: TextStyle(
              fontSize: 8.5,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================== INTEL

class IntelTab extends StatelessWidget {
  const IntelTab({super.key, required this.ctx, required this.onOpenNation});

  final NationContext ctx;
  final ValueChanged<String> onOpenNation;

  @override
  Widget build(BuildContext context) {
    final fa = ctx.fa;
    final text = Theme.of(context).textTheme;
    final c = ctx.country;
    final state = ctx.state;
    final stats = ctx.stats;
    final playerId = state.playerId;
    final player = stats.of(playerId);
    final order = stats.ordered(NationMetric.power);
    final myIndex = order.indexOf(c.id);
    final window = <String>{
      ...order.take(5),
      for (
        var i = (myIndex - 2).clamp(0, order.length);
        i <= (myIndex + 2).clamp(0, order.length - 1);
        i++
      )
        order[i],
    }.toList()..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    final maxPower = stats.maxOf(NationMetric.power);
    final metrics = NationMetric.values;

    return ListView(
      padding: WD.padScreen,
      children: [
        Panel(
          title: fa ? 'جایگاه جهانی' : 'World standing',
          child: Column(
            children: [
              for (final m in metrics)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(
                        NationContext.iconOf(m),
                        size: 13,
                        color: WD.textMuted,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        flex: 5,
                        child: Text(
                          ctx.labels.metric(m),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: WD.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          ctx.value(m, ctx.snap[m]),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          style: text.titleSmall?.copyWith(
                            fontSize: 12,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 52,
                        child: _VsAverage(
                          value: ctx.snap[m],
                          average: stats.averageOf(m),
                          fmt: ctx,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 34,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: RankBadge(
                            rank: stats.rankOf(c.id, m),
                            of: stats.count,
                            fmt: ctx.fmt,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                fa
                    ? 'ستون میانی: اختلاف با میانگین جهان'
                    : 'Middle column: difference from the world average',
                style: text.labelSmall?.copyWith(fontSize: 9.5),
              ),
            ],
          ),
        ),
        _gap,
        Panel(
          title: fa ? 'جدول قدرت جهانی' : 'Power league',
          child: Column(
            children: [
              for (final id in window)
                BarRow(
                  leading: SizedBox(
                    width: 54,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text(
                            ctx.fmt.integer(order.indexOf(id) + 1),
                            style: text.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        CountryFlag(
                          country: state.countries[id]!,
                          width: 26,
                          height: 17,
                        ),
                      ],
                    ),
                  ),
                  label: ctx.nameOf(id),
                  value: ctx.fmt.number(stats.of(id)[NationMetric.power]),
                  fraction: maxPower <= 0
                      ? 0
                      : stats.of(id)[NationMetric.power] / maxPower,
                  color: id == c.id
                      ? WD.brass
                      : id == playerId
                      ? WD.info
                      : WD.accentDim,
                  highlight: id == c.id,
                  onTap: () => onOpenNation(id),
                ),
            ],
          ),
        ),
        if (!ctx.isPlayer) ...[
          _gap,
          Panel(
            title: fa
                ? 'رو در رو با ${ctx.nameOf(playerId)}'
                : 'Head to head with ${ctx.nameOf(playerId)}',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CountryFlag(country: c, width: 24, height: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              ctx.nameOf(c.id),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelMedium?.copyWith(
                                color: WD.brass,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              ctx.nameOf(playerId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelMedium?.copyWith(color: WD.info),
                            ),
                          ),
                          const SizedBox(width: 6),
                          CountryFlag(
                            country: state.player,
                            width: 24,
                            height: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final m in metrics)
                  _HeadToHead(
                    label: ctx.labels.metricShort(m),
                    left: ctx.snap[m],
                    right: player[m],
                    leftText: ctx.value(m, ctx.snap[m]),
                    rightText: ctx.value(m, player[m]),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

class _VsAverage extends StatelessWidget {
  const _VsAverage({
    required this.value,
    required this.average,
    required this.fmt,
  });
  final double value;
  final double average;
  final NationContext fmt;

  @override
  Widget build(BuildContext context) {
    if (average.abs() < 1e-9) return const SizedBox.shrink();
    final pct = (value - average) / average.abs();
    final s = '${pct >= 0 ? '+' : ''}${fmt.fmt.percentLabel(pct)}';
    return Text(
      s,
      textAlign: TextAlign.end,
      maxLines: 1,
      style: TextStyle(
        fontSize: 10,
        color: signedColor(pct),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _HeadToHead extends StatelessWidget {
  const _HeadToHead({
    required this.label,
    required this.left,
    required this.right,
    required this.leftText,
    required this.rightText,
  });

  final String label;
  final double left;
  final double right;
  final String leftText;
  final String rightText;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = left.clamp(0, double.infinity).toDouble();
    final r = right.clamp(0, double.infinity).toDouble();
    final total = l + r;
    final lf = total <= 0 ? 0.5 : l / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  leftText,
                  style: text.titleSmall?.copyWith(
                    fontSize: 11.5,
                    color: left >= right ? WD.textPrimary : WD.textSecondary,
                  ),
                ),
              ),
              Text(label, style: text.labelSmall?.copyWith(fontSize: 10)),
              Expanded(
                child: Text(
                  rightText,
                  textAlign: TextAlign.end,
                  style: text.titleSmall?.copyWith(
                    fontSize: 11.5,
                    color: right >= left ? WD.textPrimary : WD.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Row(
              children: [
                Expanded(
                  flex: (lf * 1000).round().clamp(1, 999),
                  child: Container(height: 5, color: WD.brass),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: ((1 - lf) * 1000).round().clamp(1, 999),
                  child: Container(height: 5, color: WD.info),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================ HELPERS

class _SubHeader extends StatelessWidget {
  const _SubHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: WD.accent, fontSize: 10),
    ),
  );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: WD.textMuted),
  );
}

class _FlagWrap extends StatelessWidget {
  const _FlagWrap({required this.ctx, required this.ids, this.onTap});
  final NationContext ctx;
  final List<String> ids;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final id in ids)
          if (ctx.state.countries[id] != null)
            InkWell(
              onTap: onTap == null ? null : () => onTap!(id),
              borderRadius: BorderRadius.circular(WD.radiusSm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: WD.surface2,
                  borderRadius: BorderRadius.circular(WD.radiusSm),
                  border: Border.all(color: WD.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CountryFlag(
                      country: ctx.state.countries[id]!,
                      width: 20,
                      height: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      ctx.nameOf(id),
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: WD.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../core/balance.dart';
import '../../core/campaign_controller.dart';
import '../../core/format.dart';
import '../../data/tech_tree.dart';
import '../../models/country.dart';
import '../../models/game_state.dart';
import '../../simulation/industry_engine.dart';
import '../../widgets/common.dart';
import '../nations/nation_stats.dart';

/// Industry & research: strategic resources, factories, equipment production
/// lines and the technology tree. Every number comes from [IndustryEngine],
/// the same code the daily tick runs.
class IndustryScreen extends ConsumerStatefulWidget {
  const IndustryScreen({super.key});

  @override
  ConsumerState<IndustryScreen> createState() => _IndustryScreenState();
}

class _IndustryScreenState extends ConsumerState<IndustryScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final state = ref.watch(campaignProvider);
    if (state == null) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SegmentedToggle<int>(
            expand: true,
            values: const [0, 1],
            labels: [l10n.t('ind.tabIndustry'), l10n.t('ind.tabResearch')],
            selected: _tab,
            onChanged: (v) => setState(() => _tab = v),
          ),
        ),
        Expanded(
          child: _tab == 0
              ? _IndustryTab(state: state)
              : _ResearchTab(state: state),
        ),
      ],
    );
  }
}

void _feedback(BuildContext context, WidgetRef ref) {
  final l10n = AppStrings.of(context);
  final msg = ref.read(campaignProvider.notifier).consumeMessage();
  if (!context.mounted || msg == null) return;
  final params = <String, String>{
    for (final e in msg.params.entries)
      e.key:
          (e.value.startsWith('tech.') ||
              e.value.startsWith('equip.') ||
              e.value.startsWith('dip.'))
          ? l10n.t(e.value)
          : e.value,
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.t(msg.messageKey, params)),
      backgroundColor: msg.success ? WD.surface3 : WD.dangerDim,
    ),
  );
}

// ---------------------------------------------------------------------------
// Industry tab
// ---------------------------------------------------------------------------

class _IndustryTab extends ConsumerWidget {
  const _IndustryTab({required this.state});

  final GameState state;

  static const _engine = IndustryEngine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppStrings.of(context);
    final fmt = Fmt(l10n);
    final labels = NationLabels(l10n.isPersian);
    final c = state.player;
    final controller = ref.read(campaignProvider.notifier);
    final prod = _engine.dailyProduction(state, c);
    final demand = _engine.dailyDemand(state, c);
    final trade = _engine.tradeFlows(state, c.id);
    final penalty = _engine.shortagePenalty(state, c);
    final points = _engine.militaryPoints(state, c);
    final orders = state.productionOf(state.playerId);
    final occupation = _engine.occupationOf(state, c.id);

    return ListView(
      padding: WD.padScreen,
      children: [
        Panel(
          title: l10n.t('ind.factories'),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: l10n.t('ind.civilian'),
                      value: fmt.integer(c.civilianFactories),
                      icon: Icons.factory_outlined,
                      footnote:
                          '${fmt.credits(_engine.civilianOutput(state, c))}${l10n.t('common.perMonth')}',
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: l10n.t('ind.military'),
                      value: fmt.integer(c.militaryFactories),
                      icon: Icons.precision_manufacturing_outlined,
                      footnote:
                          '${fmt.number(points, decimals: 1)} ${l10n.t('ind.points')}',
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: l10n.t('ind.readiness'),
                      value: fmt.percentLabel(c.armyReadiness / 100),
                      icon: Icons.verified_outlined,
                      valueColor: c.armyReadiness >= 75
                          ? WD.positive
                          : c.armyReadiness >= 50
                          ? WD.warning
                          : WD.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.t('ind.factoryHint'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (penalty > 0) ...[
                const SizedBox(height: 8),
                _Warning(
                  l10n.t('ind.shortage', {'n': fmt.percentLabel(penalty)}),
                ),
              ],
              if (occupation.homeLoss > 0) ...[
                const SizedBox(height: 8),
                _Warning(
                  l10n.t('ind.occupied', {
                    'n': fmt.percentLabel(occupation.homeLoss),
                  }),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: l10n.t('ind.resources'),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      l10n.t('ind.resource'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  for (final h in ['ind.prod', 'ind.need', 'ind.stock'])
                    Expanded(
                      flex: 2,
                      child: Text(
                        l10n.t(h),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
              const Divider(height: 12),
              for (final r in ResourceType.values)
                _ResourceRow(
                  label: labels.resource(r),
                  production: prod[r]!,
                  demand: demand[r]!,
                  stock: c.resourceStock(r),
                  cap: _engine.stockCap(demand[r]!),
                  shortage: _engine.shortageOf(state, c, r),
                  fmt: fmt,
                ),
              const Divider(height: 16),
              KeyValueRow(
                label: l10n.t('eco.exports'),
                value: fmt.moneySigned(trade.exports),
                valueColor: WD.positive,
                dense: true,
              ),
              KeyValueRow(
                label: l10n.t('eco.imports'),
                value: fmt.moneySigned(-trade.imports),
                valueColor: trade.imports > 0 ? WD.danger : null,
                dense: true,
              ),
              KeyValueRow(
                label: l10n.t('eco.tradeDeals'),
                value: fmt.moneySigned(trade.tradeDeals),
                valueColor: WD.positive,
                dense: true,
              ),
              if (!_engine.canImport(state, c)) ...[
                const SizedBox(height: 6),
                _Warning(l10n.t('ind.noImports')),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: l10n.t('ind.stockpile'),
          child: Column(
            children: [
              for (final e in EquipmentType.values)
                _EquipmentRow(
                  type: e,
                  label: labels.equipment(e),
                  have: c.equipmentCount(e),
                  need: e == EquipmentType.aircraft
                      ? state.unitsOf(c.id).length * 1.5
                      : _engine.equipmentNeed(state, c.id)[e]!,
                  fmt: fmt,
                  onOrder: (qty) {
                    controller.queueProduction(e, qty);
                    _feedback(context, ref);
                  },
                  costOf: (qty) => _engine.productionCost(e, qty),
                  treasury: c.treasury,
                  enabled:
                      c.militaryFactories > 0 &&
                      orders.length < Balance.maxProductionLines,
                ),
              const SizedBox(height: 4),
              Text(
                l10n.t('ind.equipHint'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          title:
              '${l10n.t('ind.lines')} (${fmt.integer(orders.length)}/${fmt.integer(Balance.maxProductionLines)})',
          child: orders.isEmpty
              ? EmptyState(
                  message: l10n.t('ind.noLines'),
                  icon: Icons.precision_manufacturing_outlined,
                  compact: true,
                )
              : Column(
                  children: [
                    for (var i = 0; i < orders.length; i++) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${labels.equipment(orders[i].type)} × ${fmt.integer(orders[i].quantity)}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleSmall,
                                ),
                                Text(
                                  l10n.t('ind.delivered', {
                                    'a': fmt.integer(orders[i].completed),
                                    'b': fmt.integer(orders[i].quantity),
                                  }),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            fmt.percentLabel(orders[i].fraction),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          IconButton(
                            tooltip: l10n.t('common.cancel'),
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () async {
                              final ok = await confirmAction(
                                context: context,
                                title: l10n.t('ind.cancelLine'),
                                message: l10n.t('ind.cancelLineBody'),
                                confirmLabel: l10n.t('common.confirm'),
                                cancelLabel: l10n.t('common.cancel'),
                                destructive: true,
                              );
                              if (!ok) return;
                              controller.cancelProduction(i);
                              if (context.mounted) _feedback(context, ref);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Meter(fraction: orders[i].fraction),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.warning_amber_rounded, size: 15, color: WD.warning),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: WD.warning),
        ),
      ),
    ],
  );
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.label,
    required this.production,
    required this.demand,
    required this.stock,
    required this.cap,
    required this.shortage,
    required this.fmt,
  });

  final String label;
  final double production;
  final double demand;
  final double stock;
  final double cap;
  final double shortage;
  final Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final surplus = production >= demand;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Icon(
                      shortage > 0
                          ? Icons.error_outline
                          : surplus
                          ? Icons.trending_up
                          : Icons.trending_down,
                      size: 13,
                      color: shortage > 0
                          ? WD.danger
                          : surplus
                          ? WD.positive
                          : WD.warning,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  fmt.number(production, decimals: 1),
                  textAlign: TextAlign.end,
                  style: style,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  fmt.number(demand, decimals: 1),
                  textAlign: TextAlign.end,
                  style: style,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  fmt.number(stock),
                  textAlign: TextAlign.end,
                  style: style,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Meter(
            fraction: cap <= 0 ? 0 : (stock / cap).clamp(0.0, 1.0),
            height: 3,
            color: shortage > 0
                ? WD.danger
                : surplus
                ? WD.accent
                : WD.warning,
          ),
        ],
      ),
    );
  }
}

class _EquipmentRow extends StatelessWidget {
  const _EquipmentRow({
    required this.type,
    required this.label,
    required this.have,
    required this.need,
    required this.fmt,
    required this.onOrder,
    required this.costOf,
    required this.treasury,
    required this.enabled,
  });

  final EquipmentType type;
  final String label;
  final double have;
  final double need;
  final Fmt fmt;
  final ValueChanged<int> onOrder;
  final double Function(int) costOf;
  final double treasury;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final coverage = need <= 0 ? 1.0 : (have / need).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${fmt.integer(have)} / ${fmt.integer(need.ceil())}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: coverage >= 1 ? WD.positive : WD.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Meter(
            fraction: coverage,
            height: 3,
            color: coverage >= 1 ? WD.positive : WD.warning,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final qty in Balance.productionBatches) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: enabled && treasury >= costOf(qty)
                        ? () => onOrder(qty)
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 34),
                    ),
                    child: Text(
                      '+${fmt.integer(qty)} · ${fmt.credits(costOf(qty))}',
                      style: const TextStyle(fontSize: 10.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (qty != Balance.productionBatches.last)
                  const SizedBox(width: 6),
              ],
            ],
          ),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.t('ind.linesFullHint'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Research tab
// ---------------------------------------------------------------------------

class _ResearchTab extends ConsumerWidget {
  const _ResearchTab({required this.state});

  final GameState state;

  static const _engine = IndustryEngine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppStrings.of(context);
    final fmt = Fmt(l10n);
    final labels = NationLabels(l10n.isPersian);
    final c = state.player;
    final controller = ref.read(campaignProvider.notifier);
    final active = c.researchId == null ? null : TechTree.byId(c.researchId!);
    final rate = _engine.researchRate(c);

    return ListView(
      padding: WD.padScreen,
      children: [
        Panel(
          title: l10n.t('res.current'),
          accentBorder: active != null,
          child: active == null
              ? EmptyState(
                  message: l10n.t('res.idle'),
                  icon: Icons.science_outlined,
                  compact: true,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            labels.tech(active.id),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Tag(labels.branch(active.branch), color: WD.accent),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Meter(
                      fraction: (c.researchProgress / active.days).clamp(
                        0.0,
                        1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.t('res.eta', {
                        'n': fmt.integer(
                          ((active.days - c.researchProgress) / rate)
                              .ceil()
                              .clamp(0, 99999),
                        ),
                      }),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () async {
                          final ok = await confirmAction(
                            context: context,
                            title: l10n.t('res.cancel'),
                            message: l10n.t('res.cancelBody'),
                            confirmLabel: l10n.t('common.confirm'),
                            cancelLabel: l10n.t('common.cancel'),
                            destructive: true,
                          );
                          if (!ok) return;
                          controller.cancelResearch();
                          if (context.mounted) _feedback(context, ref);
                        },
                        child: Text(l10n.t('res.cancel')),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Row(
            children: [
              Expanded(
                child: StatTile(
                  label: l10n.t('res.speed'),
                  value: '${fmt.number(rate, decimals: 2)}/${l10n.t('common.day')}',
                  icon: Icons.speed,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: l10n.t('res.known'),
                  value:
                      '${fmt.integer(c.techs.length)}/${fmt.integer(TechTree.all.length)}',
                  icon: Icons.school_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final branch in TechBranch.values) ...[
          Panel(
            title: labels.branch(branch),
            child: Column(
              children: [
                for (final t in TechTree.ofBranch(branch)) ...[
                  _TechCard(
                    spec: t,
                    country: c,
                    label: labels.tech(t.id),
                    effects: _effects(t, l10n, fmt),
                    days: (t.days / rate).ceil(),
                    unlocked: _engine.prerequisitesMet(c, t),
                    fmt: fmt,
                    onStart: () {
                      controller.startResearch(t.id);
                      _feedback(context, ref);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  static String _effects(TechSpec t, AppStrings l10n, Fmt fmt) {
    final parts = <String>[];
    if (t.industrial > 0) {
      parts.add('${l10n.t('res.fx.industry')} +${fmt.number(t.industrial)}');
    }
    if (t.infrastructure > 0) {
      parts.add('${l10n.t('res.fx.infra')} +${fmt.number(t.infrastructure)}');
    }
    void pct(double v, String key) {
      if (v > 0) parts.add('${l10n.t(key)} +${fmt.percentLabel(v)}');
    }

    pct(t.incomePct, 'res.fx.income');
    pct(t.attackPct, 'res.fx.attack');
    pct(t.defensePct, 'res.fx.defense');
    pct(t.factoryOutputPct, 'res.fx.factory');
    pct(t.researchPct, 'res.fx.research');
    pct(t.supplyBonus, 'res.fx.supply');
    return parts.join(' · ');
  }
}

class _TechCard extends StatelessWidget {
  const _TechCard({
    required this.spec,
    required this.country,
    required this.label,
    required this.effects,
    required this.days,
    required this.unlocked,
    required this.fmt,
    required this.onStart,
  });

  final TechSpec spec;
  final Country country;
  final String label;
  final String effects;
  final int days;
  final bool unlocked;
  final Fmt fmt;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final done = country.hasTech(spec.id);
    final active = country.researchId == spec.id;
    final busy = country.researchId != null;
    final affordable = country.treasury >= spec.cost;
    final border = done
        ? WD.positive.withValues(alpha: 0.5)
        : active
        ? WD.brass
        : WD.line;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: done ? WD.surface3 : WD.surface2,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Tag(
                '${l10n.t('res.tier')} ${fmt.integer(spec.tier)}',
                color: WD.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontSize: 13.5),
                ),
              ),
              if (done)
                const Icon(Icons.check_circle, size: 18, color: WD.positive)
              else if (!unlocked)
                const Icon(Icons.lock_outline, size: 16, color: WD.textMuted),
            ],
          ),
          const SizedBox(height: 6),
          Text(effects, style: Theme.of(context).textTheme.bodySmall),
          if (!done) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${fmt.credits(spec.cost)} ${l10n.t('common.cost')} · ~${fmt.integer(days)} ${l10n.t('common.day')}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                FilledButton(
                  onPressed: (unlocked && !busy && affordable)
                      ? onStart
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(84, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text(
                    active
                        ? l10n.t('res.inProgress')
                        : !unlocked
                        ? l10n.t('common.locked')
                        : l10n.t('res.start'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

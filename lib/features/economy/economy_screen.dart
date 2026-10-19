import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../core/balance.dart';
import '../../core/campaign_controller.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';

class EconomyScreen extends ConsumerWidget {
  const EconomyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppStrings.of(context);
    final fmt = Fmt(l10n);
    final state = ref.watch(campaignProvider);
    if (state == null) return const Center(child: CircularProgressIndicator());

    final controller = ref.read(campaignProvider.notifier);
    final budget = controller.simulation.economy.breakdown(
      state,
      state.playerId,
    );
    final player = state.player;
    final queue = state.constructionOf(state.playerId);
    final budgetMultiplier = state.budgetOf(state.playerId);

    return ListView(
      padding: WD.padScreen,
      children: [
        Panel(
          title: l10n.t('eco.incomeBreakdown'),
          child: Column(
            children: [
              for (final line in budget.income)
                KeyValueRow(
                  label: l10n.t(line.labelKey),
                  value: fmt.money(line.amount),
                  valueColor: WD.positive,
                ),
              const Divider(height: 14),
              KeyValueRow(
                label: l10n.t('common.total'),
                value: fmt.money(budget.totalIncome),
                valueColor: WD.positive,
              ),
              KeyValueRow(
                label: l10n.t('common.perDay'),
                value: fmt.money(budget.dailyIncome),
                dense: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: l10n.t('eco.expenseBreakdown'),
          child: Column(
            children: [
              for (final line in budget.expenses)
                KeyValueRow(
                  label: l10n.t(line.labelKey),
                  value: fmt.money(line.amount),
                  valueColor: WD.danger,
                ),
              const Divider(height: 14),
              KeyValueRow(
                label: l10n.t('common.total'),
                value: fmt.money(budget.totalExpenses),
                valueColor: WD.danger,
              ),
              KeyValueRow(
                label: l10n.t('common.perDay'),
                value: fmt.money(budget.dailyExpenses),
                dense: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: KeyValueRow(
            label: l10n.t('res.net'),
            value: fmt.moneySigned(budget.net),
            valueColor: signedColor(budget.net),
            icon: Icons.swap_vert,
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: l10n.t('eco.budgetTitle'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.t('eco.budgetHint'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: budgetMultiplier,
                      min: 0.6,
                      max: 1.5,
                      divisions: 9,
                      label: fmt.number(budgetMultiplier, decimals: 2),
                      onChanged: (v) => controller.setMilitaryBudget(v),
                    ),
                  ),
                  SizedBox(
                    width: 58,
                    child: Text(
                      '${fmt.number(budgetMultiplier, decimals: 2)}×',
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.t('eco.budgetLow'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l10n.t('eco.budgetNormal'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l10n.t('eco.budgetTotal'),
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: l10n.t('mil.maintenance'),
                      value: fmt.credits(budget.militaryUpkeep),
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: l10n.t('res.army'),
                      value: fmt.number(
                        state.armyOf(state.playerId).combatScore,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (queue.isNotEmpty) ...[
          Panel(
            title: l10n.t('eco.building'),
            child: Column(
              children: [
                for (final o in queue) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.t('eco.${o.type.name}.name'),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              l10n.t('eco.daysLeft', {
                                'n': fmt.integer(o.daysRemaining),
                              }),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        fmt.percentLabel(o.fraction),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Meter(fraction: o.fraction),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Panel(
          title: l10n.t('eco.projects'),
          child: Column(
            children: [
              for (final type in BuildingType.values) ...[
                _BuildingCard(
                  type: type,
                  owned: player.buildingCount(type).toInt(),
                  queued: queue.any((o) => o.type == type),
                  affordable: player.treasury >= Balance.buildings[type]!.cost,
                  fmt: fmt,
                  onBuild: () async {
                    final ok = controller.startConstruction(type);
                    final msg = controller.consumeMessage();
                    if (!context.mounted || msg == null) return;
                    final params = Map<String, String>.from(msg.params);
                    if (params['name'] != null &&
                        params['name']!.startsWith('eco.')) {
                      params['name'] = l10n.t(params['name']!);
                    }
                    if (params['need'] == null && type == type) {
                      params['need'] = fmt.money(Balance.buildings[type]!.cost);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.t(msg.messageKey, params)),
                        backgroundColor: ok ? WD.surface3 : WD.dangerDim,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _BuildingCard extends StatelessWidget {
  const _BuildingCard({
    required this.type,
    required this.owned,
    required this.queued,
    required this.affordable,
    required this.fmt,
    required this.onBuild,
  });

  final BuildingType type;
  final int owned;
  final bool queued;
  final bool affordable;
  final Fmt fmt;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final spec = Balance.buildings[type]!;
    final description = l10n.t('eco.${type.name}.desc', {
      'a': fmt.number(spec.industrialDelta + spec.infrastructureDelta),
      'b': fmt.number(spec.industrialDelta),
    });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WD.surface2,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        border: Border.all(color: queued ? WD.accentDim : WD.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.t('eco.${type.name}.name'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontSize: 14),
                ),
              ),
              if (owned > 0)
                Tag(
                  '${l10n.t('eco.built')} ${fmt.integer(owned)}',
                  color: WD.textMuted,
                ),
              if (queued) ...[
                const SizedBox(width: 5),
                Tag(l10n.t('eco.building').toUpperCase(), color: WD.accent),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  compact: true,
                  label: l10n.t('common.cost'),
                  value: fmt.credits(spec.cost),
                ),
              ),
              Expanded(
                child: StatTile(
                  compact: true,
                  label: l10n.t('eco.readyIn', {'n': ''}).trim(),
                  value: '${fmt.integer(spec.days)} ${l10n.t('common.day')}',
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: (!affordable || queued) ? null : onBuild,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(78, 40),
                  padding: EdgeInsets.zero,
                ),
                child: Text(l10n.t('eco.build')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

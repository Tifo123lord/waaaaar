import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../core/balance.dart';
import '../../core/campaign_controller.dart';
import '../../core/format.dart';
import '../../models/military_unit.dart';
import '../../widgets/common.dart';

class MilitaryScreen extends ConsumerWidget {
  const MilitaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppStrings.of(context);
    final fmt = Fmt(l10n);
    final state = ref.watch(campaignProvider);
    if (state == null) return const Center(child: CircularProgressIndicator());

    final controller = ref.read(campaignProvider.notifier);
    final player = state.player;
    final army = state.armyOf(state.playerId);
    final capacity = controller.simulation.economy.manpowerCapacityOf(player);
    final units = state.unitsOf(state.playerId).toList()
      ..sort((a, b) => a.ordinal.compareTo(b.ordinal));

    void feedback(bool ok) {
      final msg = controller.consumeMessage();
      if (!context.mounted || msg == null) return;
      final params = Map<String, String>.from(msg.params);
      for (final k in params.keys.toList()) {
        if (params[k]!.startsWith('mil.')) params[k] = l10n.t(params[k]!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t(msg.messageKey, params)),
          backgroundColor: ok ? WD.surface3 : WD.dangerDim,
        ),
      );
    }

    return ListView(
      padding: WD.padScreen,
      children: [
        Panel(
          title: l10n.t('mil.title'),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: l10n.t('mil.totalStrength'),
                      value: fmt.number(army.combatScore),
                      icon: Icons.shield_outlined,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: l10n.t('mil.readiness'),
                      value: fmt.percentLabel(army.readiness / 100),
                      icon: Icons.speed_outlined,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: l10n.t('mil.maintenance'),
                      value: fmt.credits(army.monthlyMaintenance),
                      icon: Icons.payments_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.t('mil.manpowerUse'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: 5),
              Meter(
                fraction: capacity <= 0 ? 0 : army.manpower / capacity,
                color: army.manpower / (capacity <= 0 ? 1 : capacity) > 0.9
                    ? WD.warning
                    : WD.accent,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${fmt.number(army.manpower, decimals: 2)} ${l10n.t('res.million')}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    '${fmt.number(capacity, decimals: 2)} ${l10n.t('res.million')}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: l10n.t('mil.recruit'),
          child: Column(
            children: [
              if (player.recruitmentDiscount > 0.001)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.factory_outlined, size: 13, color: WD.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.t('mil.discount', {
                            'n': fmt.number(player.recruitmentDiscount * 100),
                          }),
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: WD.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  for (final type in UnitType.values) ...[
                    Expanded(
                      child: _RecruitCard(
                        type: type,
                        discount: player.recruitmentDiscount,
                        treasury: player.treasury,
                        fmt: fmt,
                        onRecruit: () => feedback(controller.recruit(type)),
                      ),
                    ),
                    if (type != UnitType.values.last) const SizedBox(width: 9),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.t('mil.deployHint'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: l10n.t('mil.roster'),
          child: units.isEmpty
              ? EmptyState(
                  message: l10n.t('mil.empty'),
                  icon: Icons.groups_outlined,
                )
              : Column(
                  children: [
                    for (final u in units) ...[
                      _UnitRow(
                        unit: u,
                        fmt: fmt,
                        region: l10n.isPersian
                            ? state.countries[u.homeRegion]?.nameFa ??
                                  u.homeRegion
                            : state.countries[u.homeRegion]?.nameEn ??
                                  u.homeRegion,
                        onDisband: () async {
                          final ok = await confirmAction(
                            context: context,
                            title: l10n.t('mil.disband'),
                            message: l10n.t('mil.disbandConfirm', {
                              'name': u.designation(),
                            }),
                            confirmLabel: l10n.t('mil.disband'),
                            cancelLabel: l10n.t('common.cancel'),
                            destructive: true,
                          );
                          if (ok) controller.disband(u.id);
                        },
                      ),
                      const Divider(height: 1),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('mil.attritionNote'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _RecruitCard extends StatelessWidget {
  const _RecruitCard({
    required this.type,
    required this.discount,
    required this.treasury,
    required this.fmt,
    required this.onRecruit,
  });

  final UnitType type;
  final double discount;
  final double treasury;
  final Fmt fmt;
  final VoidCallback onRecruit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final spec = Balance.units[type]!;
    final cost = spec.cost * (1 - discount);
    final affordable = treasury >= cost;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: WD.surface2,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        border: Border.all(color: WD.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                type == UnitType.infantry
                    ? Icons.groups_2_outlined
                    : Icons.directions_car_filled_outlined,
                size: 15,
                color: WD.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.t('mil.${type.name}'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            l10n.t('mil.${type.name}.desc'),
            style: Theme.of(context).textTheme.labelSmall,
            maxLines: 3,
          ),
          const SizedBox(height: 9),
          KeyValueRow(
            label: l10n.t('common.cost'),
            value: fmt.credits(cost),
            dense: true,
            valueColor: affordable ? WD.textPrimary : WD.danger,
          ),
          KeyValueRow(
            label: l10n.t('mil.maintenance'),
            value: fmt.credits(spec.maintenance),
            dense: true,
          ),
          KeyValueRow(
            label: l10n.t('mil.power'),
            value: fmt.number(spec.attack + spec.defense),
            dense: true,
          ),
          const SizedBox(height: 7),
          FilledButton(
            onPressed: affordable ? onRecruit : null,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
            child: Text(
              l10n.t('mil.recruitBtn'),
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({
    required this.unit,
    required this.fmt,
    required this.region,
    required this.onDisband,
  });

  final MilitaryUnit unit;
  final Fmt fmt;
  final String region;
  final VoidCallback onDisband;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final intact = unit.power / unit.maxPower;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                unit.type == UnitType.infantry
                    ? Icons.groups_2_outlined
                    : Icons.directions_car_filled_outlined,
                size: 14,
                color: intact > 0.6 ? WD.accent : WD.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.designation(),
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${l10n.t('mil.homeRegion')}: $region · ${l10n.t('mil.experience')}: ${fmt.number(unit.experience)}',
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                '${fmt.number(unit.power)}/${fmt.number(unit.maxPower)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              IconButton(
                onPressed: onDisband,
                icon: const Icon(Icons.delete_outline, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: l10n.t('mil.disband'),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Meter(fraction: intact, color: intact > 0.6 ? WD.accent : WD.warning),
        ],
      ),
    );
  }
}

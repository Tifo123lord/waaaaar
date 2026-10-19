import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../core/campaign_controller.dart';
import '../../core/format.dart';
import '../../models/battle.dart';
import '../../models/game_state.dart';
import '../../widgets/common.dart';

class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key});

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> {
  String? _target;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final fmt = Fmt(l10n);
    final state = ref.watch(campaignProvider);
    if (state == null) return const Center(child: CircularProgressIndicator());

    final controller = ref.read(campaignProvider.notifier);
    final active = state.playerBattle;
    final targets = controller.simulation.battle.availableTargets(
      state,
      state.playerId,
    );

    return ListView(
      padding: WD.padScreen,
      children: [
        if (active != null) ...[
          _ActiveBattleCard(state: state, battle: active, fmt: fmt),
          const SizedBox(height: 12),
        ],
        if (state.playerWars.isNotEmpty) ...[
          Panel(
            title: l10n.t('dash.activeWars'),
            child: Column(
              children: [
                for (final w in state.playerWars)
                  _WarRow(
                    state: state,
                    opponentId: w.opponentOf(state.playerId),
                    fmt: fmt,
                    onPeace: () async {
                      final ok = await confirmAction(
                        context: context,
                        title: l10n.t('bt.sueForPeace'),
                        message: l10n.t('bt.sueForPeace'),
                        confirmLabel: l10n.t('common.confirm'),
                        cancelLabel: l10n.t('common.cancel'),
                      );
                      if (!ok) return;
                      final made = controller.sueForPeace(
                        w.opponentOf(state.playerId),
                      );
                      final msg = controller.consumeMessage();
                      if (!context.mounted || msg == null) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.t(msg.messageKey, msg.params)),
                          backgroundColor: made ? WD.surface3 : WD.dangerDim,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Panel(
          title: l10n.t('bt.selectTarget'),
          child: targets.isEmpty
              ? EmptyState(message: l10n.t('bt.noTargets'), icon: Icons.gps_off)
              : Column(
                  children: [
                    for (final id in targets) ...[
                      _TargetRow(
                        state: state,
                        id: id,
                        selected: _target == id,
                        fmt: fmt,
                        onTap: () => setState(() => _target = id),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
        if (_target != null) ...[
          const SizedBox(height: 12),
          _Assessment(
            estimates: controller.estimateBattle(_target!),
            state: state,
            targetId: _target!,
            fmt: fmt,
            onLaunch: () async {
              final t = state.countries[_target!]!;
              final ok = await confirmAction(
                context: context,
                title: l10n.t('bt.declare'),
                message: l10n.t('bt.warDeclared', {
                  'name': l10n.isPersian ? t.nameFa : t.nameEn,
                }),
                confirmLabel: l10n.t('bt.declare'),
                cancelLabel: l10n.t('common.cancel'),
                destructive: true,
              );
              if (!ok) return;
              final err = controller.declareWar(_target!);
              final msg = controller.consumeMessage();
              if (!context.mounted || msg == null) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.t(msg.messageKey, msg.params)),
                  backgroundColor: err == null ? WD.surface3 : WD.dangerDim,
                ),
              );
              if (err == null) setState(() => _target = null);
            },
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.state,
    required this.id,
    required this.selected,
    required this.fmt,
    required this.onTap,
  });

  final GameState state;
  final String id;
  final bool selected;
  final Fmt fmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final c = state.countries[id]!;
    final army = state.armyOf(id);
    final relation = state.player.relations[id] ?? 0;
    final ratio =
        state.armyOf(state.playerId).combatScore /
        (army.combatScore <= 0 ? 1 : army.combatScore);

    return Material(
      color: selected ? WD.surface3 : WD.surface2,
      borderRadius: BorderRadius.circular(WD.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WD.radiusSm),
            border: Border.all(
              color: selected ? WD.danger : WD.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CountryFlag(country: c, width: 26, height: 17),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      l10n.isPersian ? c.nameFa : c.nameEn,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Tag(
                    l10n.t('dip.attitude.${_attitude(relation)}'),
                    color: signedColor(relation),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      compact: true,
                      label: l10n.t('bt.theirStrength'),
                      value: fmt.number(army.combatScore),
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      compact: true,
                      label: l10n.t('map.relations'),
                      value: fmt.number(relation),
                      valueColor: signedColor(relation),
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      compact: true,
                      label: l10n.t('res.industrial'),
                      value: fmt.number(c.industrial),
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      compact: true,
                      label: l10n.t('bt.estimatedChance'),
                      value: fmt.percentLabel(
                        (ratio / (1 + ratio)).clamp(0.05, 0.95),
                      ),
                      valueColor: ratio > 1.4
                          ? WD.positive
                          : ratio < 0.8
                          ? WD.danger
                          : WD.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _attitude(double r) {
    if (r <= -45) return 'hostile';
    if (r <= -15) return 'cold';
    if (r < 20) return 'neutral';
    if (r < 55) return 'warm';
    return 'friendly';
  }
}

class _Assessment extends StatelessWidget {
  const _Assessment({
    required this.estimates,
    required this.state,
    required this.targetId,
    required this.fmt,
    required this.onLaunch,
  });

  final CombatEstimates estimates;
  final GameState state;
  final String targetId;
  final Fmt fmt;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final supplyLabel = estimates.supplyPenalty < 0.08
        ? 'bt.supplyGood'
        : estimates.supplyPenalty < 0.18
        ? 'bt.supplyStrained'
        : 'bt.supplyCritical';
    final supplyColor = estimates.supplyPenalty < 0.08
        ? WD.positive
        : estimates.supplyPenalty < 0.18
        ? WD.warning
        : WD.danger;

    return Panel(
      accentBorder: true,
      title: l10n.t('bt.assessment'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: l10n.t('bt.ourStrength'),
                  value: fmt.number(estimates.attackerPower),
                  valueColor: WD.positive,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: l10n.t('bt.theirStrength'),
                  value: fmt.number(estimates.defenderPower),
                  valueColor: WD.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.t('bt.estimatedChance'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Meter(
                  fraction: estimates.winChance,
                  height: 9,
                  color: estimates.winChance > 0.55
                      ? WD.positive
                      : estimates.winChance > 0.35
                      ? WD.warning
                      : WD.danger,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                fmt.percentLabel(estimates.winChance),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  compact: true,
                  label: l10n.t('bt.expectedLosses'),
                  value: fmt.number(estimates.expectedAttackerLosses),
                  valueColor: WD.danger,
                ),
              ),
              Expanded(
                child: StatTile(
                  compact: true,
                  label: l10n.t('bt.supply'),
                  value: l10n.t(supplyLabel),
                  valueColor: supplyColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onLaunch,
            style: FilledButton.styleFrom(
              backgroundColor: WD.danger,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.gps_fixed, size: 16),
            label: Text(l10n.t('bt.declare')),
          ),
        ],
      ),
    );
  }
}

class _ActiveBattleCard extends StatelessWidget {
  const _ActiveBattleCard({
    required this.state,
    required this.battle,
    required this.fmt,
  });

  final GameState state;
  final ActiveBattle battle;
  final Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final opponentId = battle.opponentOf(state.playerId);
    final opponent = state.countries[opponentId]!;
    final playerIsAttacker = battle.attackerId == state.playerId;
    final ourMorale = playerIsAttacker
        ? battle.attackerMorale
        : battle.defenderMorale;
    final theirMorale = playerIsAttacker
        ? battle.defenderMorale
        : battle.attackerMorale;

    return Panel(
      accentBorder: true,
      title: l10n.t('bt.inProgress', {
        'region': l10n.isPersian ? opponent.capitalFa : opponent.capitalEn,
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CountryFlag(country: opponent, width: 30, height: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.isPersian ? opponent.nameFa : opponent.nameEn,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Tag(l10n.t('map.atWarTag'), color: WD.danger, filled: true),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('common.you'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Meter(fraction: ourMorale / 100, color: WD.accent),
                    const SizedBox(height: 3),
                    Text(
                      fmt.percentLabel(ourMorale / 100),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.isPersian ? opponent.shortFa : opponent.shortEn,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Meter(fraction: theirMorale / 100, color: WD.danger),
                    const SizedBox(height: 3),
                    Text(
                      fmt.percentLabel(theirMorale / 100),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.t('bt.roundLog').toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: WD.accent),
          ),
          const SizedBox(height: 6),
          if (battle.log.isEmpty)
            Text(
              l10n.t('bt.awaiting'),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ...battle.log.reversed.take(5).map((entry) {
              final parts = entry.split('|');
              final key = parts.isNotEmpty ? parts[0] : entry;
              final round = parts.length > 1 ? parts[1] : '1';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: WD.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.t(key, {'n': round}),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _WarRow extends StatelessWidget {
  const _WarRow({
    required this.state,
    required this.opponentId,
    required this.fmt,
    required this.onPeace,
  });

  final GameState state;
  final String opponentId;
  final Fmt fmt;
  final VoidCallback onPeace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final c = state.countries[opponentId]!;
    final ours = state.armyOf(state.playerId).combatScore;
    final theirs = state.armyOf(opponentId).combatScore;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CountryFlag(country: c, width: 26, height: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.isPersian ? c.nameFa : c.nameEn,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontSize: 12.5),
                ),
                Text(
                  '${l10n.t('res.army')}: ${fmt.number(ours)} vs ${fmt.number(theirs)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onPeace,
            child: Text(
              l10n.t('bt.sueForPeace'),
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

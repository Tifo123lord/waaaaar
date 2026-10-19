import 'package:flutter/material.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../core/game_clock.dart';
import '../../core/format.dart';
import '../../models/battle.dart';
import '../../models/game_state.dart';
import '../../widgets/common.dart';

/// Full-screen result dialog for a concluded battle. Every figure shown here
/// comes from the [BattleResult] the engine produced.
Future<void> showBattleReport(
  BuildContext context,
  BattleResult result,
  GameState state,
) {
  final l10n = AppStrings.of(context);
  final fmt = Fmt(l10n);
  final attacker = state.countries[result.attackerId]!;
  final defender = state.countries[result.defenderId]!;
  final playerIsAttacker = result.attackerId == state.playerId;
  final playerWon = result.attackerWon == playerIsAttacker;
  final accent = playerWon ? WD.positive : WD.danger;

  final region = state
      .countries[result.territoryTransferred
          ? result.defenderId
          : result.defenderId]!
      .capitalEn;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                border: Border(
                  bottom: BorderSide(color: accent.withValues(alpha: 0.5)),
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(WD.radiusLg),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    playerWon
                        ? Icons.verified_outlined
                        : Icons.dangerous_outlined,
                    color: accent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('bt.report').toUpperCase(),
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: accent),
                        ),
                        Text(
                          l10n.t(
                            playerWon ? 'bt.outcome.win' : 'bt.outcome.loss',
                          ),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: accent, letterSpacing: 1.6),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    fmt.date(GameDate(result.day)),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.t(
                        result.attackerWon
                            ? 'bt.narrative.win'
                            : 'bt.narrative.loss',
                        {
                          'attacker': l10n.isPersian
                              ? attacker.nameFa
                              : attacker.nameEn,
                          'defender': l10n.isPersian
                              ? defender.nameFa
                              : defender.nameEn,
                          'region': region,
                        },
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    _SideRow(
                      title: l10n.t('bt.attacker'),
                      name: l10n.isPersian ? attacker.nameFa : attacker.nameEn,
                      before: result.attackerPowerBefore,
                      after: result.attackerPowerAfter,
                      lossRatio: result.attackerLossRatio,
                      isPlayer: playerIsAttacker,
                      fmt: fmt,
                      win: result.attackerWon,
                    ),
                    const SizedBox(height: 10),
                    _SideRow(
                      title: l10n.t('bt.defender'),
                      name: l10n.isPersian ? defender.nameFa : defender.nameEn,
                      before: result.defenderPowerBefore,
                      after: result.defenderPowerAfter,
                      lossRatio: result.defenderLossRatio,
                      isPlayer: !playerIsAttacker,
                      fmt: fmt,
                      win: !result.attackerWon,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: WD.surface2,
                        borderRadius: BorderRadius.circular(WD.radiusSm),
                        border: Border.all(color: WD.line),
                      ),
                      child: Column(
                        children: [
                          KeyValueRow(
                            label: l10n.t('bt.lossesUs'),
                            value: fmt.number(
                              playerIsAttacker
                                  ? result.attackerLosses
                                  : result.defenderLosses,
                            ),
                            valueColor: WD.danger,
                          ),
                          KeyValueRow(
                            label: l10n.t('bt.lossesThem'),
                            value: fmt.number(
                              playerIsAttacker
                                  ? result.defenderLosses
                                  : result.attackerLosses,
                            ),
                            valueColor: WD.positive,
                          ),
                          if (result.attackerTreasuryGain > 0)
                            KeyValueRow(
                              label: l10n.t('bt.loot'),
                              value: fmt.money(result.attackerTreasuryGain),
                              valueColor: WD.brass,
                            ),
                          const Divider(height: 14),
                          KeyValueRow(
                            label: l10n.t(
                              result.territoryTransferred
                                  ? 'bt.territoryGained'
                                  : 'bt.territoryHeld',
                              {'region': region},
                            ),
                            value: result.territoryTransferred
                                ? (l10n.isPersian
                                      ? attacker.nameFa
                                      : attacker.nameEn)
                                : '—',
                            valueColor: result.territoryTransferred
                                ? WD.brass
                                : WD.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.t('bt.acknowledge')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SideRow extends StatelessWidget {
  const _SideRow({
    required this.title,
    required this.name,
    required this.before,
    required this.after,
    required this.lossRatio,
    required this.isPlayer,
    required this.fmt,
    required this.win,
  });

  final String title;
  final String name;
  final double before;
  final double after;
  final double lossRatio;
  final bool isPlayer;
  final Fmt fmt;
  final bool win;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: WD.surface2,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        border: Border.all(color: isPlayer ? WD.brassDim : WD.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tag(title, color: win ? WD.positive : WD.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isPlayer)
                Tag(AppStrings.of(context).t('common.you'), color: WD.brass),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  compact: true,
                  label: AppStrings.of(context).t('res.army'),
                  value: fmt.number(before),
                  footnote: '→ ${fmt.number(after)}',
                ),
              ),
              Expanded(
                child: StatTile(
                  compact: true,
                  label: AppStrings.of(context).t('bt.expectedLosses'),
                  value: fmt.percentLabel(lossRatio),
                  valueColor: WD.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:math';

import '../core/balance.dart';
import '../models/battle.dart';
import '../models/diplomatic_agreement.dart';
import '../models/game_state.dart';
import '../models/military_unit.dart';
import 'industry_engine.dart';

/// Turn-based, simulation-tick driven combat.
///
/// The design goal is a battle that is *internally consistent and legible*: the
/// same numbers the player sees in the preview are the ones that decide the
/// fight, and initiating an attack never guarantees victory.
class BattleEngine {
  BattleEngine({Random? random}) : _rng = random ?? Random();

  final Random _rng;

  static const IndustryEngine _air = IndustryEngine();

  static double _readinessFactor(double readiness) =>
      0.6 + 0.4 * (readiness / 100).clamp(0.0, 1.0);

  /// Fraction of the attacker's combat power actually committed to a battle.
  /// Reserves are always held back, so a nation is never left defenceless.
  static const double _commitment = 0.72;

  // ------------------------------------------------------------------ odds

  /// Computes the odds the UI shows *before* the player commits.
  CombatEstimates estimate(
    GameState state,
    String attackerId,
    String defenderId,
  ) {
    final attackerArmy = state.armyOf(attackerId);
    final defenderArmy = state.armyOf(defenderId);

    final attacker = state.countries[attackerId]!;
    final defender = state.countries[defenderId]!;
    // Equipment-driven readiness and air cover scale the committed force.
    final attackerCommit =
        attackerArmy.combatScore *
        _commitment *
        _readinessFactor(attacker.armyReadiness) *
        (1 + _air.airBonus(state, attacker));

    // Entrenchment: the defender fights on its own ground.
    final terrain = 1.12;
    final fortifications = 1 + defender.fortificationBonus;
    // Allies and defence-pact partners send expeditionary support.
    var support = 0.0;
    for (final ally in state.defendersOf(defenderId)) {
      if (ally == attackerId || !state.countries.containsKey(ally)) continue;
      support += state.armyOf(ally).combatScore * Balance.allySupportShare;
    }
    final defenderCommit =
        (defenderArmy.combatScore + support) *
        terrain *
        fortifications *
        _readinessFactor(defender.armyReadiness) *
        (1 + _air.airBonus(state, defender));

    final supply = supplyPenalty(state, attackerId);
    final supplyFactor = 1 - supply;

    final effectiveAttack = attackerCommit * supplyFactor;
    final ratio = effectiveAttack <= 0
        ? 0.0
        : effectiveAttack / (effectiveAttack + defenderCommit);

    // Logistic curve keeps the result readable rather than knife-edge.
    final winChance = (1 / (1 + exp(-(ratio - 0.5) * 6.2))).clamp(0.03, 0.97);

    final lossScale = ratio < 0.5 ? 1.0 : 0.72;

    return CombatEstimates(
      attackerPower: effectiveAttack,
      defenderPower: defenderCommit,
      winChance: winChance,
      expectedAttackerLosses:
          attackerCommit * (0.34 * lossScale) * supplyFactor,
      expectedDefenderLosses:
          defenderCommit *
          (0.42 * (1 - ratio) + 0.16) *
          (0.75 + winChance * 0.3),
      supplyPenalty: supply,
    );
  }

  /// How badly distance and ongoing commitments strain the attacker.
  double supplyPenalty(GameState state, String attackerId) {
    final attacker = state.countries[attackerId]!;
    final concurrentWars = state.wars
        .where((w) => w.involves(attackerId))
        .length;
    var penalty = concurrentWars * 0.06;
    if (attacker.treasury < 0) penalty += 0.10;
    if (attacker.stability < 40) penalty += 0.06;
    penalty += (1 - attacker.infrastructure / 110).clamp(0.0, 0.16);
    // Logistics research and an oil shortage push in opposite directions.
    penalty -= attacker.techSupplyBonus * 0.5;
    penalty += _air.shortageOf(state, attacker, ResourceType.oil) * 0.12;
    return penalty.clamp(0.0, Balance.battleSupplyWeight + 0.12);
  }

  // --------------------------------------------------------------- lifecycle

  /// Whether an attack is legal under the demo's rules. Returns a
  /// localization key describing the problem, or `null` when allowed.
  String? validateAttack(
    GameState state,
    String attackerId,
    String defenderId,
  ) {
    if (attackerId == defenderId) return 'bt.cannotBorder';
    if (state.hasAgreement(attackerId, defenderId, AgreementType.alliance)) {
      return 'bt.cannotAlly';
    }
    if (state.hasAgreement(
          attackerId,
          defenderId,
          AgreementType.nonAggression,
        ) ||
        state.hasAgreement(attackerId, defenderId, AgreementType.defencePact)) {
      return 'bt.cannotPact';
    }
    final attacker = state.countries[attackerId]!;
    if (!attacker.theatres.contains(defenderId)) return 'bt.cannotBorder';
    if (state.armyOf(attackerId).combatScore <= 0) return 'bt.noArmy';
    if (state.battles.any((b) => b.involves(attackerId))) {
      return 'bt.warOngoing';
    }
    return null;
  }

  /// Countries the player could legitimately attack right now.
  List<String> availableTargets(GameState state, String attackerId) {
    final attacker = state.countries[attackerId]!;
    return attacker.theatres
        .where((id) => state.countries.containsKey(id))
        .where((id) => validateAttack(state, attackerId, id) == null)
        .toList(growable: false);
  }

  /// Opens a new war and schedules the first engagement.
  ActiveBattle beginBattle(
    GameState state,
    String attackerId,
    String defenderId, {
    required String warId,
    required int battleIndex,
  }) {
    return ActiveBattle(
      id: 'b${state.day}_$battleIndex',
      attackerId: attackerId,
      defenderId: defenderId,
      warId: warId,
      day: state.day,
      attackerMorale: 100,
      defenderMorale: 100,
      attackerPowerBefore: state.armyOf(attackerId).combatScore,
      defenderPowerBefore: state.armyOf(defenderId).combatScore,
      log: const [],
    );
  }

  /// Advances one round. Returns the battle plus, when it concludes, the
  /// result — combat power is *not* mutated here, the simulation applies it.
  BattleRoundStep step(GameState state, ActiveBattle battle) {
    final estimates = estimate(state, battle.attackerId, battle.defenderId);
    final swing = (_rng.nextDouble() * 2 - 1) * Balance.battleRandomness;
    final attackerEdge = estimates.winChance + swing;

    final attackerGain = attackerEdge > 0.5;
    var attackerMorale = battle.attackerMorale;
    var defenderMorale = battle.defenderMorale;

    final intensity = 6.5 + _rng.nextDouble() * 4.0;

    String logKey;
    if (attackerGain) {
      defenderMorale -= intensity * (0.8 + estimates.winChance);
      attackerMorale -= intensity * 0.35;
      logKey = 'bt.log.attackerGaining';
    } else if (attackerEdge < 0.42) {
      attackerMorale -= intensity * 0.9;
      defenderMorale -= intensity * 0.3;
      logKey = 'bt.log.defenderGaining';
    } else {
      attackerMorale -= intensity * 0.55;
      defenderMorale -= intensity * 0.55;
      logKey = 'bt.log.steady';
    }

    attackerMorale = attackerMorale.clamp(0, 100);
    defenderMorale = defenderMorale.clamp(0, 100);

    final round = battle.log.length + 1;
    final updated = battle.copyWith(
      day: state.day,
      attackerMorale: attackerMorale,
      defenderMorale: defenderMorale,
      log: [...battle.log, '$logKey|$round'],
    );

    final decided =
        attackerMorale <= 18 ||
        defenderMorale <= 18 ||
        battle.log.length >= 11 ||
        // A decisive first round is possible when one side is crushed.
        (battle.log.isEmpty &&
            (estimates.winChance > 0.9 || estimates.winChance < 0.1));

    if (!decided) {
      return BattleRoundStep(battle: updated, result: null, roundKey: logKey);
    }

    final attackerWon =
        attackerMorale > defenderMorale + 4 ||
        (attackerMorale > defenderMorale && estimates.winChance >= 0.5);

    return BattleRoundStep(
      battle: updated,
      result: resolve(
        state,
        updated,
        attackerWon: attackerWon,
        estimates: estimates,
      ),
      roundKey: logKey,
    );
  }

  /// Produces the authoritative outcome of a concluded battle.
  BattleResult resolve(
    GameState state,
    ActiveBattle battle, {
    required bool attackerWon,
    CombatEstimates? estimates,
  }) {
    final est =
        estimates ?? estimate(state, battle.attackerId, battle.defenderId);

    final attackerPowerBefore = state.armyOf(battle.attackerId).combatScore;
    final defenderPowerBefore = state.armyOf(battle.defenderId).combatScore;

    final rounds = max(1, battle.log.length);
    final intensity = (rounds / 6).clamp(0.6, 1.8);

    // Loss ratios stay bounded: a victor can still be badly bloodied.
    var attackerLossRatio = attackerWon
        ? (0.16 + est.supplyPenalty * 0.5) * intensity
        : (0.34 + est.supplyPenalty * 0.6) * intensity;
    var defenderLossRatio = attackerWon
        ? (0.36 + (1 - est.winChance) * 0.2) * intensity
        : (0.22 + est.winChance * 0.25) * intensity;

    attackerLossRatio = attackerLossRatio.clamp(0.04, 0.72);
    defenderLossRatio = defenderLossRatio.clamp(0.05, 0.80);

    final attackerPowerAfter = max(
      0.0,
      attackerPowerBefore * (1 - attackerLossRatio),
    );
    final defenderPowerAfter = max(
      0.0,
      defenderPowerBefore * (1 - defenderLossRatio),
    );

    final transferred = attackerWon && defenderLossRatio > 0.42;

    final loot = attackerWon
        ? defenderPowerBefore *
              Balance.battleLooterShare *
              140 *
              (0.5 + (1 - attackerLossRatio))
        : 0.0;

    return BattleResult(
      attackerId: battle.attackerId,
      defenderId: battle.defenderId,
      attackerWon: attackerWon,
      attackerPowerBefore: attackerPowerBefore,
      attackerPowerAfter: attackerPowerAfter,
      defenderPowerBefore: defenderPowerBefore,
      defenderPowerAfter: defenderPowerAfter,
      attackerLossRatio: attackerLossRatio,
      defenderLossRatio: defenderLossRatio,
      attackerTreasuryGain: loot,
      stabilityDeltaAttacker: attackerWon
          ? Balance.battleWinStability
          : -Balance.battleLossStability,
      stabilityDeltaDefender: attackerWon
          ? -Balance.battleLossStability
          : Balance.battleWinStability,
      territoryTransferred: transferred,
      day: state.day,
    );
  }

  double _clamp01(double v) => v.clamp(0.0, 1.0);

  /// Applies the outcome of a battle to a fresh mutable unit list.
  ///
  /// Returns the new unit list; destroyed formations are dropped.
  List<MilitaryUnit> applyLosses(
    List<MilitaryUnit> units,
    String countryId,
    double lossRatio,
  ) {
    final out = <MilitaryUnit>[];
    for (final unit in units) {
      if (unit.ownerId != countryId) {
        out.add(unit);
        continue;
      }
      final loss = _clamp01(lossRatio) * (0.85 + _rng.nextDouble() * 0.3);
      final newPower = unit.power * (1 - loss.clamp(0.0, 0.95));
      if (newPower <= 0.6) continue; // formation destroyed
      out.add(
        unit.copyWith(
          power: newPower,
          experience: (unit.experience + 3.5).clamp(0.0, 100.0),
        ),
      );
    }
    return out;
  }
}

/// Result of one simulation tick applied to an ongoing battle.
class BattleRoundStep {
  const BattleRoundStep({
    required this.battle,
    required this.result,
    required this.roundKey,
  });

  final ActiveBattle battle;

  /// Non-null when the battle concluded on this tick.
  final BattleResult? result;

  final String roundKey;

  bool get concluded => result != null;
}

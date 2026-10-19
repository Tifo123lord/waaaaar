import 'dart:math';

import '../core/balance.dart';
import '../core/constants.dart';
import '../models/country.dart';
import '../models/diplomatic_agreement.dart';
import '../models/game_state.dart';

/// Why a diplomatic action was refused.
enum DiploRejection {
  atWar,
  alreadyExists,
  relationsTooLow,
  insufficientFunds,
  noEligiblePartner,
}

class DiploOutcome {
  const DiploOutcome.accepted(this.message) : accepted = true, rejection = null;

  const DiploOutcome.rejected(this.rejection)
    : accepted = false,
      message = null;

  final bool accepted;
  final String? message;
  final DiploRejection? rejection;
}

/// Rule-based diplomacy. Every decision reads the real relation score, power
/// balance and war status, so proposals genuinely change later gameplay.
class DiplomacyEngine {
  DiplomacyEngine({Random? random}) : _rng = random ?? Random();

  final Random _rng;

  /// A nation's attitude band, used for colour coding and AI logic.
  static String attitudeKey(double relations) {
    if (relations <= -45) return 'dip.attitude.hostile';
    if (relations <= -15) return 'dip.attitude.cold';
    if (relations < 20) return 'dip.attitude.neutral';
    if (relations < 55) return 'dip.attitude.warm';
    return 'dip.attitude.friendly';
  }

  double relationsOf(GameState state, String a, String b) =>
      state.countries[a]?.relations[b] ?? 0;

  /// Whether the AI would accept a proposal, using only observable state.
  bool wouldAccept(
    GameState state, {
    required String proposer,
    required String target,
    required AgreementType type,
  }) {
    final targetCountry = state.countries[target]!;
    final proposerCountry = state.countries[proposer]!;

    if (state.atWarWith(proposer, target)) return false;

    final relations = relationsOf(state, target, proposer);
    final powerRatio = _powerRatio(state, proposer, target);

    // A stronger, more stable partner is more attractive; an aggressive one is
    // less so.
    final powerBonus = (powerRatio - 1) * 22;
    final stabilityBonus = (proposerCountry.stability - 55) * 0.22;
    final doctrineBonus = switch (targetCountry.personality) {
      AiPersonality.defensive => 8.0,
      AiPersonality.industrialist => 4.0,
      AiPersonality.opportunist => -2.0,
      AiPersonality.expansionist => -6.0,
    };

    final sharedAllies = state
        .alliesOf(proposer)
        .where((a) => state.alliesOf(target).contains(a))
        .length;

    final score =
        relations +
        powerBonus +
        stabilityBonus +
        doctrineBonus +
        sharedAllies * 6 +
        (_rng.nextDouble() * 6 - 3);

    final required = switch (type) {
      AgreementType.nonAggression => Balance.pactMinRelations * 0.55,
      AgreementType.defencePact =>
        (Balance.pactMinRelations * 0.55 +
                Balance.allianceMinRelations * 0.85) /
            2,
      AgreementType.alliance => Balance.allianceMinRelations * 0.85,
      AgreementType.trade => Balance.tradeDealMinRelations.toDouble(),
      AgreementType.sanction => 1000.0,
    };
    return score >= required;
  }

  double _powerRatio(GameState state, String a, String b) {
    final pa = state.countries[a]!;
    final pb = state.countries[b]!;
    final scaleA = pa.industrial * 1.4 + state.armyOf(a).combatScore * 0.9;
    final scaleB = pb.industrial * 1.4 + state.armyOf(b).combatScore * 0.9;
    if (scaleB <= 0.1) return 3;
    return (scaleA / scaleB).clamp(0.2, 3.0);
  }

  /// Nations adjacent to (i.e. diplomatically reachable from) the player.
  List<String> reachablePartners(GameState state, String playerId) {
    final player = state.countries[playerId]!;
    return player.theatres
        .where(state.countries.containsKey)
        .where((id) => !state.atWarWith(playerId, id))
        .toList(growable: false);
  }

  bool hasAgreement(GameState state, String a, String b, AgreementType type) =>
      state.hasAgreement(a, b, type);

  /// Validates an "improve relations" action.
  String? validateImprove(GameState state, String a, String b) {
    if (!state.countries.containsKey(b)) return 'bt.cannotBorder';
    if (state.atWarWith(a, b)) return 'dip.atWarNoDiplomacy';
    if (state.countries[a]!.treasury < Balance.costImproveRelations) {
      return 'eco.insufficient';
    }
    return null;
  }

  String? validateProposal(
    GameState state,
    String a,
    String b,
    AgreementType type,
  ) {
    if (!state.countries.containsKey(b)) return 'bt.cannotBorder';
    if (state.atWarWith(a, b)) return 'dip.atWarNoDiplomacy';
    if (state.hasAgreement(a, b, type)) return 'dip.alreadyExists';
    if (type == AgreementType.sanction) return 'dip.alreadyExists';
    if (type == AgreementType.trade &&
        (state.politics.sanctionBetween(a, b) != null ||
            state.politics.sanctionBetween(b, a) != null)) {
      return 'dip.tradeSanctioned';
    }
    if (state.countries[a]!.treasury < proposalCost(type)) {
      return 'eco.insufficient';
    }
    return null;
  }

  double proposalCost(AgreementType type) => switch (type) {
    AgreementType.alliance => Balance.costAlliance,
    AgreementType.defencePact => Balance.costDefencePact,
    AgreementType.trade => Balance.costTradeDeal,
    _ => Balance.costNonAggression,
  };

  /// Whether a pact still holds between two nations at war.
  bool pactBlocksAttack(GameState state, String a, String b) =>
      state.hasAgreement(a, b, AgreementType.nonAggression) ||
      state.hasAgreement(a, b, AgreementType.defencePact);

  /// Drifts relations slowly toward zero each day, and toward hostility while
  /// the two nations are fighting.
  Country driftRelations(GameState state, String countryId) {
    final c = state.countries[countryId]!;
    final relations = Map<String, double>.from(c.relations);
    var changed = false;

    for (final other in relations.keys.toList()) {
      if (!state.countries.containsKey(other)) continue;
      final atWar = state.atWarWith(countryId, other);
      final ally = state.alliesOf(countryId).contains(other);
      final pact =
          state.hasAgreement(countryId, other, AgreementType.nonAggression) ||
          state.hasAgreement(countryId, other, AgreementType.defencePact) ||
          state.hasAgreement(countryId, other, AgreementType.trade);
      final sanctioned = state.politics.sanctionBetween(other, countryId) != null;

      var value = relations[other]!;
      if (atWar) {
        value -= 0.22;
      } else if (sanctioned) {
        value -= 0.06;
      } else if (ally) {
        value += 0.05;
      } else if (pact) {
        value += 0.02;
      } else {
        value += value > 0 ? -Balance.relationsDrift : Balance.relationsDrift;
      }
      value = value.clamp(
        GameConstants.minRelations,
        GameConstants.maxRelations,
      );
      if ((value - relations[other]!).abs() > 0.001) changed = true;
      relations[other] = value;
    }

    if (!changed) return c;
    return c.copyWith(relations: relations);
  }
}

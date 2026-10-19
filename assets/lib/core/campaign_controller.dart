import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/balance.dart';
import '../core/constants.dart';
import '../data/save_repository.dart';
import '../models/battle.dart';
import '../models/diplomatic_agreement.dart';
import '../models/game_state.dart';
import '../simulation/game_simulation.dart';

/// The campaign controller.
///
/// Owns the running [GameState] and the simulation clock. The clock is a
/// real-time timer that requests one *in-game day* per fire — the world never
/// advances because of frame rendering, so speed is identical on every device
/// and the UI stays responsive while paused.
class CampaignController extends StateNotifier<GameState?> {
  CampaignController({GameSimulation? simulation, SaveRepository? saves})
    : simulation = simulation ?? GameSimulation(),
      saves = saves ?? SaveRepository(),
      super(null);

  final GameSimulation simulation;
  final SaveRepository saves;

  Timer? _timer;
  bool _ticking = false;

  /// Set when a battle the player is involved in concludes, so the UI can open
  /// the report exactly once.
  BattleResult? pendingReport;

  /// Last user-facing feedback message (localization key + params), consumed by
  /// the shell which displays it as a snack bar or dialog.
  ActionResult? lastMessage;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- lifecycle

  void startNewCampaign(String countryId) {
    state = simulation.newCampaign(countryId);
    pendingReport = null;
    _applySpeed(GameSpeed.normal);
  }

  void loadState(GameState next, {bool paused = true}) {
    state = next;
    pendingReport = null;
    _applySpeed(paused ? GameSpeed.paused : next.speed);
  }

  void endCampaign() {
    _timer?.cancel();
    _timer = null;
    state = null;
    pendingReport = null;
    lastMessage = null;
  }

  // -------------------------------------------------------------------- clock

  void setSpeed(GameSpeed speed) {
    final current = state;
    if (current == null) return;
    state = simulation.setSpeed(current, speed);
    _applySpeed(speed);
  }

  void togglePause() {
    final current = state;
    if (current == null) return;
    final next = current.speed == GameSpeed.paused
        ? GameSpeed.normal
        : GameSpeed.paused;
    setSpeed(next);
  }

  void _applySpeed(GameSpeed speed) {
    _timer?.cancel();
    _timer = null;
    if (speed == GameSpeed.paused) return;
    final interval = speed == GameSpeed.fast
        ? GameConstants.tickMsFast
        : GameConstants.tickMsNormal;
    _timer = Timer.periodic(
      Duration(milliseconds: interval),
      (_) => advanceOneDay(),
    );
  }

  /// Advances exactly one in-game day. Public so the UI can offer a
  /// "step one day" control and so tests can drive the clock deterministically.
  void advanceOneDay() {
    final current = state;
    if (current == null || _ticking) return;
    _ticking = true;
    try {
      final next = simulation.tick(current, current.speed);
      if (next.lastBattleReport != current.lastBattleReport &&
          next.lastBattleReport != null) {
        pendingReport = next.lastBattleReport;
      }
      state = next;
      _maybeAutosave(next);
    } finally {
      _ticking = false;
    }
  }

  // ------------------------------------------------------------ player actions

  /// Queues and pays for a building project.
  bool startConstruction(BuildingType type) {
    final current = state;
    if (current == null) return false;
    final validation = simulation.startConstruction(current, type);
    if (!validation.success) {
      lastMessage = validation;
      return false;
    }
    state = simulation.commitConstruction(current, type);
    final spec = Balance.buildings[type]!;
    lastMessage = ActionResult.ok(
      'eco.queued',
      params: {'name': 'eco.${type.name}.name', 'n': spec.days.toString()},
    );
    return true;
  }

  bool recruit(UnitType type) {
    final current = state;
    if (current == null) return false;
    final validation = simulation.recruit(current, type);
    if (!validation.success) {
      lastMessage = validation;
      return false;
    }
    state = simulation.commitRecruit(current, type);
    lastMessage = validation;
    return true;
  }

  bool disband(String unitId) {
    final current = state;
    if (current == null) return false;
    state = simulation.disband(current, unitId);
    lastMessage = const ActionResult.ok('mil.disband');
    return true;
  }

  void setMilitaryBudget(double multiplier) {
    final current = state;
    if (current == null) return;
    state = simulation.setMilitaryBudget(current, multiplier);
  }

  // ---------------------------------------------------------------- diplomacy

  bool improveRelations(String otherId) {
    final current = state;
    if (current == null) return false;
    final validation = simulation.improveRelations(current, otherId);
    if (!validation.success) {
      lastMessage = validation;
      return false;
    }
    state = simulation.commitImproveRelations(current, otherId);
    final value = state!.player.relations[otherId]?.toStringAsFixed(0) ?? '0';
    lastMessage = ActionResult.ok(
      'dip.improved',
      params: {'name': state!.countries[otherId]!.nameEn, 'value': value},
    );
    return true;
  }

  bool proposeAgreement(String otherId, AgreementType type) {
    final current = state;
    if (current == null) return false;
    final outcome = simulation.proposeAgreement(current, otherId, type);
    state = simulation.commitAgreement(
      current,
      otherId,
      type,
      accepted: outcome.success,
    );
    lastMessage = outcome.success
        ? ActionResult.ok(
            'dip.accepted',
            params: {'name': state!.countries[otherId]!.nameEn},
          )
        : ActionResult.failed(
            'dip.rejected',
            params: {'name': state!.countries[otherId]!.nameEn},
          );
    return outcome.success;
  }

  bool renounceAgreement(String agreementId) {
    final current = state;
    if (current == null) return false;
    state = simulation.renounceAgreement(current, agreementId);
    lastMessage = const ActionResult.ok('dip.renounced');
    return true;
  }

  // -------------------------------------------------------------------- battle

  /// Declares war and starts the battle. Returns the validation failure key.
  String? declareWar(String defenderId) {
    final current = state;
    if (current == null) return 'bt.noTargets';
    final validation = simulation.declareWar(current, defenderId);
    if (!validation.success) {
      lastMessage = validation;
      return validation.messageKey;
    }
    state = simulation.commitDeclareWar(current, defenderId);
    lastMessage = ActionResult.ok(
      'bt.battleJoined',
      params: {'region': state!.countries[defenderId]!.capitalEn},
    );
    return null;
  }

  bool sueForPeace(String opponentId) {
    final current = state;
    if (current == null) return false;
    final accepted = simulation.wouldAcceptPeace(current, opponentId);
    if (!accepted) {
      lastMessage = ActionResult.failed(
        'bt.peaceRejected',
        params: {'name': current.countries[opponentId]!.nameEn},
      );
      return false;
    }
    state = simulation.makePeace(current, opponentId);
    lastMessage = ActionResult.ok(
      'bt.peaceMade',
      params: {'name': current.countries[opponentId]!.nameEn},
    );
    return true;
  }

  // --------------------------------------------------------- research/industry

  bool startResearch(String techId) {
    final current = state;
    if (current == null) return false;
    final validation = simulation.startResearch(current, techId);
    lastMessage = validation;
    if (!validation.success) return false;
    state = simulation.commitResearch(current, techId);
    return true;
  }

  void cancelResearch() {
    final current = state;
    if (current == null) return;
    state = simulation.cancelResearch(current);
    lastMessage = const ActionResult.ok('res.cancelled');
  }

  bool queueProduction(EquipmentType type, int quantity) {
    final current = state;
    if (current == null) return false;
    final validation = simulation.queueProduction(current, type, quantity);
    lastMessage = validation;
    if (!validation.success) return false;
    state = simulation.commitProduction(current, type, quantity);
    return true;
  }

  void cancelProduction(int index) {
    final current = state;
    if (current == null) return;
    state = simulation.cancelProduction(current, index);
    lastMessage = const ActionResult.ok('prod.cancelled');
  }

  // --------------------------------------------------------------- sanctions

  bool imposeSanction(String targetId) {
    final current = state;
    if (current == null) return false;
    final validation = simulation.imposeSanction(current, targetId);
    lastMessage = validation;
    if (!validation.success) return false;
    state = simulation.commitSanction(current, targetId);
    return true;
  }

  void liftSanction(String targetId) {
    final current = state;
    if (current == null) return;
    state = simulation.liftSanction(current, targetId);
    lastMessage = ActionResult.ok(
      'dip.sanctionLifted',
      params: {'name': current.countries[targetId]?.nameEn ?? targetId},
    );
  }

  // ---------------------------------------------------------------- autosave

  /// Saves silently every 30 in-game days while a campaign is running.
  void _maybeAutosave(GameState next) {
    if (!autosaveEnabled) return;
    if (next.day > 0 && next.day % 30 == 0) {
      saves.save(next);
    }
  }

  /// Toggled from settings; on by default.
  bool autosaveEnabled = true;

  BattleResult? consumeReport() {
    final report = pendingReport;
    pendingReport = null;
    return report;
  }

  ActionResult? consumeMessage() {
    final message = lastMessage;
    lastMessage = null;
    return message;
  }

  // -------------------------------------------------------------------- saving

  Future<bool> saveCampaign() =>
      state == null ? Future.value(false) : saves.save(state!);

  SaveRepository get repository => saves;

  /// Read-only helper used by screens that need the estimate panel.
  CombatEstimates estimateBattle(String defenderId) {
    final current = state;
    if (current == null) {
      return const CombatEstimates(
        attackerPower: 0,
        defenderPower: 0,
        winChance: 0.5,
        expectedAttackerLosses: 0,
        expectedDefenderLosses: 0,
        supplyPenalty: 0,
      );
    }
    return simulation.battle.estimate(current, current.playerId, defenderId);
  }
}

final campaignProvider = StateNotifierProvider<CampaignController, GameState?>((
  ref,
) {
  return CampaignController();
});

/// Whether a valid save exists on disk (drives the Continue button).
final saveSummaryProvider = FutureProvider<SaveSummary?>((ref) async {
  return SaveRepository().readSummary();
});

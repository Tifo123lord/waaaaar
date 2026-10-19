import 'dart:math';

import '../core/balance.dart';
import '../core/constants.dart';
import '../core/game_clock.dart';
import '../data/country_data.dart';
import '../data/tech_tree.dart';
import '../models/battle.dart';
import '../models/country.dart';
import '../models/diplomatic_agreement.dart';
import '../models/game_event.dart';
import '../models/game_state.dart';
import '../models/history.dart';
import '../models/military_unit.dart';
import '../models/production.dart';
import '../models/region.dart';
import '../models/world_politics.dart';
import 'ai_engine.dart';
import 'battle_engine.dart';
import 'diplomacy_engine.dart';
import 'economy_engine.dart';
import 'industry_engine.dart';
import 'workspace.dart';

/// The one place where gameplay actions are executed.
///
/// UI code never mutates state directly: it calls a command here, which
/// produces a new immutable [GameState] plus the immediate feedback (a
/// localization key and severity) the caller should surface.
class ActionResult {
  const ActionResult.ok(
    this.messageKey, {
    this.params = const {},
    this.severity = 1,
  }) : success = true;

  const ActionResult.failed(
    this.messageKey, {
    this.params = const {},
    this.severity = -1,
  }) : success = false;

  final bool success;
  final String messageKey;
  final Map<String, String> params;
  final int severity;
}

class GameSimulation {
  GameSimulation({Random? random})
    : _rng = random ?? Random(),
      economy = const EconomyEngine() {
    battle = BattleEngine(random: _rng);
    diplomacy = DiplomacyEngine(random: _rng);
    ai = AiEngine(battle: battle, diplomacy: diplomacy, random: _rng);
  }

  final Random _rng;
  final EconomyEngine economy;
  IndustryEngine get industry => EconomyEngine.industry;
  late final BattleEngine battle;
  late final DiplomacyEngine diplomacy;
  late final AiEngine ai;

  // ------------------------------------------------------------ new campaign

  /// Creates a fresh campaign for [playerId] at the campaign start date.
  GameState newCampaign(String playerId) {
    final countries = {for (final c in CountryData.build()) c.id: c};
    final events = EventLog([]);
    final units = <MilitaryUnit>[];
    for (final entry in CountryData.startingArmy.entries) {
      final id = entry.key;
      if (!countries.containsKey(id)) continue;
      final infantry = entry.value[0];
      final armor = entry.value[1];
      var ordinal = 1;
      for (var i = 0; i < infantry; i++) {
        units.add(_startingUnit(id, UnitType.infantry, ordinal++));
      }
      for (var i = 0; i < armor; i++) {
        units.add(_startingUnit(id, UnitType.armor, ordinal++));
      }
    }

    // Every playable nation controls its own home region.
    final control = <String, String>{for (final id in countries.keys) id: id};

    final state = GameState(
      countries: countries,
      playerId: playerId,
      day: 0,
      units: units,
      agreements: const [],
      wars: const [],
      battles: const [],
      construction: {
        for (final id in countries.keys) id: <ConstructionOrder>[],
      },
      events: events,
      control: control,
      speed: GameSpeed.normal,
    );

    // Seed equipment and resource stockpiles so every army starts equipped.
    for (final id in countries.keys.toList()) {
      countries[id] = industry.seed(state, countries[id]!);
    }

    events.add(
      kind: GameEventKind.game,
      day: 0,
      titleKey: 'evt.game.title',
      bodyKey: 'evt.game.body',
      params: {'country': countries[playerId]!.nameEn},
      countryId: playerId,
      severity: 1,
    );
    recordHistory(state, state.history);
    return state;
  }

  MilitaryUnit _startingUnit(String owner, UnitType type, int ordinal) =>
      MilitaryUnit(
        id: '${owner}_start_$ordinal',
        type: type,
        ownerId: owner,
        homeRegion: owner,
        power: 100,
        maxPower: 100,
        // Standing armies begin with a little institutional experience.
        experience: 12,
        formedDay: 0,
        ordinal: ordinal,
      );

  // ------------------------------------------------------------------- clock

  GameState setSpeed(GameState state, GameSpeed speed) =>
      state.copyWithSpeed(speed);

  /// Advances the campaign by exactly one in-game day.
  ///
  /// This is the only path by which the world changes during play.
  GameState tick(GameState state, GameSpeed speed) {
    final ws = SimulationWorkspace(source: state);
    ws.day = state.day + 1;

    // 1. Economy, stability and industrial drift for every nation.
    for (final id in ws.countries.keys.toList()) {
      final before = ws.country(id)!;
      final after = economy.applyDay(ws.state, id);
      ws.putCountry(after);
      _maybeEconomicEvent(ws, before, after);
    }

    // 1b. Resources, research and readiness.
    for (final id in ws.countries.keys.toList()) {
      final (updated, tech) = industry.applyDay(ws.state, id);
      ws.putCountry(updated);
      if (tech != null) _techEvent(ws, updated, tech);
    }

    // 2. Construction and equipment production progress one day.
    _progressConstruction(ws);
    _progressProduction(ws);

    // 3. Peace-time attrition recovery for every formation.
    _recoverFormations(ws);

    // 4. Ongoing battles advance one round.
    BattleResult? report = _advanceBattles(ws);

    // 5. AI decision pulse.
    if (ws.day % GameConstants.aiPulseDays == 0) {
      ai.pulse(ws, addUnit: ws.addUnit);
    } else {
      for (final id in ws.foreignIds) {
        final c = ws.country(id);
        if (c == null) continue;
        ws.putCountry(diplomacy.driftRelations(ws.state, id));
      }
      final player = ws.country(ws.playerId);
      if (player != null) {
        ws.putCountry(diplomacy.driftRelations(ws.state, ws.playerId));
      }
    }

    // 6. Chart history sample.
    if (ws.day % Balance.historySampleDays == 0 &&
        ws.history.lastDay != ws.day) {
      recordHistory(ws.state, ws.history);
    }

    return ws.publish(speed: speed, report: report);
  }

  /// Records one chart sample for every nation into [history].
  void recordHistory(GameState state, HistorySeries history) {
    history.markDay(state.day);
    for (final id in state.countries.keys) {
      final c = state.countries[id]!;
      final budget = economy.breakdown(state, id);
      history.record(
        id,
        economy: budget.totalIncome,
        power: economy.powerScore(state, id),
        industry: c.industrial,
        treasury: c.treasury,
        stability: c.stability,
        army: state.armyOf(id).combatScore,
      );
    }
  }

  void _maybeEconomicEvent(
    SimulationWorkspace ws,
    Country before,
    Country after,
  ) {
    // Only surface meaningful growth, and only occasionally, so the feed stays
    // readable instead of scrolling continuously.
    final growth = after.industrial - before.industrial;
    if (growth > 0.05 && _rng.nextDouble() < 0.12) {
      ws.events.add(
        kind: GameEventKind.economy,
        day: ws.day,
        titleKey: 'evt.econ.title',
        bodyKey: 'evt.econ.body',
        params: {
          'country': after.nameEn,
          'treasury': after.treasury.toStringAsFixed(0),
        },
        countryId: after.id,
        amount: after.treasury - before.treasury,
        severity: 1,
      );
    }
  }

  void _progressConstruction(SimulationWorkspace ws) {
    for (final countryId in ws.countries.keys.toList()) {
      final orders = ws.construction[countryId];
      if (orders == null || orders.isEmpty) continue;

      final remaining = <ConstructionOrder>[];
      final completed = <ConstructionOrder>[];

      for (final order in orders) {
        final next = order.advance(1);
        if (next.progressDays >= next.durationDays) {
          completed.add(next);
        } else {
          remaining.add(next);
        }
      }

      if (completed.isEmpty && remaining.isEmpty) continue;

      var country = ws.country(countryId)!;
      final buildings = Map<String, int>.from(country.buildings);
      var industrial = country.industrial;
      var infrastructure = country.infrastructure;
      var civilian = country.civilianFactories;
      var military = country.militaryFactories;

      for (final order in completed) {
        final spec = Balance.buildings[order.type]!;
        buildings[order.type.name] = (buildings[order.type.name] ?? 0) + 1;
        industrial += spec.industrialDelta;
        infrastructure += spec.infrastructureDelta;
        civilian += spec.civilianFactories;
        military += spec.militaryFactories;
        ws.events.add(
          kind: GameEventKind.construction,
          day: ws.day,
          titleKey: 'evt.build.title',
          bodyKey: 'evt.build.body',
          params: {
            'building': 'eco.${order.type.name}.name',
            'country': country.nameEn,
            'amount': spec.industrialDelta.toStringAsFixed(0),
          },
          countryId: countryId,
          severity: 1,
        );
      }

      country = country.copyWith(
        buildings: buildings,
        industrial: industrial.clamp(
          GameConstants.minIndustrial,
          GameConstants.maxIndustrial,
        ),
        infrastructure: infrastructure.clamp(0, 120),
        civilianFactories: civilian,
        militaryFactories: military,
      );
      ws.putCountry(country);
      ws.putConstruction(countryId, remaining);
    }
  }

  void _techEvent(SimulationWorkspace ws, Country c, String techId) {
    // Only the player's breakthroughs and major powers' are worth a headline.
    if (c.id != ws.playerId && c.industrial < 60) return;
    ws.events.add(
      kind: GameEventKind.economy,
      day: ws.day,
      titleKey: 'evt.tech.title',
      bodyKey: 'evt.tech.body',
      params: {'country': c.nameEn, 'tech': 'tech.$techId'},
      countryId: c.id,
      severity: c.id == ws.playerId ? 1 : 0,
    );
  }

  void _progressProduction(SimulationWorkspace ws) {
    for (final countryId in ws.production.keys.toList()) {
      final orders = ws.production[countryId]!;
      if (orders.isEmpty) continue;
      final country = ws.country(countryId);
      if (country == null) continue;
      final (remaining, updated, done) = industry.advanceProduction(
        ws.state,
        country,
        orders,
      );
      ws.putCountry(updated);
      ws.putProduction(countryId, remaining);
      if (countryId != ws.playerId) continue;
      for (final o in done) {
        ws.events.add(
          kind: GameEventKind.construction,
          day: ws.day,
          titleKey: 'evt.prod.title',
          bodyKey: 'evt.prod.body',
          params: {
            'country': updated.nameEn,
            'equipment': 'equip.${o.type.name}',
            'count': o.quantity.toString(),
          },
          countryId: countryId,
          severity: 1,
        );
      }
    }
  }

  void _recoverFormations(SimulationWorkspace ws) {
    final next = <MilitaryUnit>[];
    var changed = false;
    for (final unit in ws.units) {
      final ownerAtWar = ws.state.wars.any((w) => w.involves(unit.ownerId));
      if (unit.power >= unit.maxPower || ownerAtWar) {
        next.add(unit);
        continue;
      }
      final healed = min(unit.maxPower, unit.power + unit.maxPower * 0.01);
      next.add(unit.copyWith(power: healed));
      changed = true;
    }
    if (changed) ws.setUnits(next);
  }

  BattleResult? _advanceBattles(SimulationWorkspace ws) {
    if (ws.battles.isEmpty) return null;
    BattleResult? report;

    for (var i = ws.battles.length - 1; i >= 0; i--) {
      final current = ws.battles[i];
      final step = battle.step(ws.state, current);

      if (!step.concluded) {
        ws.replaceBattle(i, step.battle);
        // Each round costs both sides a little materiel.
        _applyBattleAttrition(ws, current.attackerId, 0.035);
        _applyBattleAttrition(ws, current.defenderId, 0.035);
        continue;
      }

      final result = step.result!;
      _applyBattleResult(ws, result);
      ws.removeWar(current.warId);
      ws.removeBattleAt(i);
      if (result.attackerId == ws.playerId ||
          result.defenderId == ws.playerId) {
        report = result;
      }
    }
    return report;
  }

  void _applyBattleAttrition(
    SimulationWorkspace ws,
    String countryId,
    double perRound,
  ) {
    ws.setUnits(battle.applyLosses(ws.units, countryId, perRound));
  }

  void _applyBattleResult(SimulationWorkspace ws, BattleResult result) {
    final attacker = ws.country(result.attackerId);
    final defender = ws.country(result.defenderId);
    if (attacker == null || defender == null) return;

    // Apply formation losses using the ratio the engine decided on.
    var units = battle.applyLosses(
      ws.units,
      result.attackerId,
      result.attackerLossRatio,
    );
    units = battle.applyLosses(
      units,
      result.defenderId,
      result.defenderLossRatio,
    );
    ws.setUnits(units);

    final attackerTreasury = _clampTreasury(
      attacker.treasury + result.attackerTreasuryGain,
    );
    final defenderLoss = result.attackerWon ? defender.treasury * 0.06 : 0.0;

    ws.putCountry(
      industry
          .applyEquipmentLosses(attacker, result.attackerLossRatio)
          .copyWith(
        treasury: attackerTreasury,
        stability: (attacker.stability + result.stabilityDeltaAttacker).clamp(
          GameConstants.minStability,
          GameConstants.maxStability,
        ),
      ),
    );
    ws.putCountry(
      industry
          .applyEquipmentLosses(defender, result.defenderLossRatio)
          .copyWith(
        treasury: _clampTreasury(defender.treasury - defenderLoss),
        stability: (defender.stability + result.stabilityDeltaDefender).clamp(
          GameConstants.minStability,
          GameConstants.maxStability,
        ),
      ),
    );

    String? capturedRegion;
    if (result.territoryTransferred) {
      capturedRegion = _captureRegion(ws, result.attackerId, result.defenderId);
    } else if (!result.attackerWon) {
      // A failed offensive lets the defender liberate one of its regions.
      _liberateRegion(ws, result.defenderId, result.attackerId);
    }

    // Relations collapse between the belligerents.
    _shiftRelations(ws, result.attackerId, result.defenderId, -18);
    ws.events.add(
      kind: GameEventKind.battle,
      day: result.day,
      titleKey: 'evt.battle.title',
      bodyKey: 'evt.battle.body',
      params: {
        'region': capturedRegion == null
            ? ws.country(result.defenderId)!.capitalEn
            : regionLabel(capturedRegion),
        'winner': (result.attackerWon ? attacker : defender).nameEn,
        'loser': (result.attackerWon ? defender : attacker).nameEn,
        'losses': (result.attackerLosses + result.defenderLosses)
            .toStringAsFixed(0),
      },
      countryId: result.attackerWon ? result.attackerId : result.defenderId,
      severity: result.attackerWon ? 1 : -1,
    );
  }

  /// Human-readable region label, e.g. "Iran (north)".
  static String regionLabel(String regionId) {
    final region = WorldRegions.byId(regionId);
    if (region == null) return regionId;
    final owner = CountryData.build().firstWhere(
      (c) => c.id == region.countryId,
      orElse: () => CountryData.build().first,
    );
    return region.capital
        ? owner.capitalEn
        : '${owner.nameEn} (${region.sector.toUpperCase()})';
  }

  /// Moves one region of [loserId] (non-capital first) to [winnerId].
  /// Returns the captured region id, or null when nothing was left to take.
  String? _captureRegion(
    SimulationWorkspace ws,
    String winnerId,
    String loserId,
  ) {
    final held = ws.regions.values
        .where((r) => r.controllerId == loserId)
        .toList();
    if (held.isEmpty) return null;
    // Occupied foreign land falls first, then provinces, the capital last.
    held.sort((a, b) {
      int rank(RegionState r) {
        if (r.ownerId == winnerId) return -1; // winner's own land first
        if (r.ownerId != loserId) return 0; // then other occupied land
        return WorldRegions.byId(r.id)?.capital == true ? 2 : 1;
      }

      return rank(a).compareTo(rank(b));
    });
    final target = held.first;
    ws.setControl(target.id, winnerId);
    // Garrisons in a lost region fall back to the capital.
    final capital = WorldRegions.capitalOf(loserId) ?? loserId;
    ws.setUnits([
      for (final u in ws.units)
        u.ownerId == loserId && u.homeRegion == target.id
            ? u.copyWith(homeRegion: capital)
            : u,
    ]);
    return target.id;
  }

  void _liberateRegion(
    SimulationWorkspace ws,
    String ownerId,
    String occupierId,
  ) {
    for (final r in ws.regions.values) {
      if (r.ownerId == ownerId && r.controllerId == occupierId) {
        ws.setControl(r.id, ownerId);
        return;
      }
    }
  }

  void _shiftRelations(
    SimulationWorkspace ws,
    String a,
    String b,
    double delta,
  ) {
    for (final (self, other) in [(a, b), (b, a)]) {
      final c = ws.country(self);
      if (c == null) continue;
      final rel = Map<String, double>.from(c.relations);
      rel[other] = ((rel[other] ?? 0) + delta).clamp(
        GameConstants.minRelations,
        GameConstants.maxRelations,
      );
      ws.putCountry(c.copyWith(relations: rel));
    }
  }

  double _clampTreasury(double v) =>
      v.clamp(GameConstants.minTreasury, GameConstants.maxTreasury);

  // ------------------------------------------------------------- player acts

  /// Queues a building project for the player's nation.
  ActionResult startConstruction(GameState state, BuildingType type) {
    final country = state.player;
    final spec = Balance.buildings[type]!;
    final existing = state.constructionOf(state.playerId);

    if (existing.any((o) => o.type == type)) {
      return const ActionResult.failed('eco.alreadyBuilding');
    }
    if (country.treasury < spec.cost) {
      return ActionResult.failed(
        'eco.insufficient',
        params: {
          'need': '${spec.cost.toStringAsFixed(0)} ${GameConstants.currency}',
        },
      );
    }
    return const ActionResult.ok('eco.queued');
  }

  /// Applies a construction order (called only after [startConstruction] OK).
  GameState commitConstruction(GameState state, BuildingType type) {
    final spec = Balance.buildings[type]!;
    final ws = SimulationWorkspace(source: state);
    final country = ws.country(state.playerId)!;
    ws.putCountry(
      country.copyWith(treasury: _clampTreasury(country.treasury - spec.cost)),
    );
    final orders = [
      ...ws.construction[state.playerId] ?? <ConstructionOrder>[],
    ];
    orders.add(
      ConstructionOrder(
        type: type,
        startedDay: ws.day,
        durationDays: spec.days,
        invested: spec.cost,
        progressDays: 0,
      ),
    );
    ws.putConstruction(state.playerId, orders);
    ws.events.add(
      kind: GameEventKind.construction,
      day: ws.day,
      titleKey: 'evt.build.title',
      params: {
        'building': 'eco.${type.name}.name',
        'country': country.nameEn,
        'amount': '0',
      },
      countryId: state.playerId,
      severity: 0,
    );
    return ws.publish();
  }

  /// Recruits one formation. Returns a result describing success/failure.
  ActionResult recruit(GameState state, UnitType type) {
    final country = state.player;
    final spec = Balance.units[type]!;
    final army = state.armyOf(state.playerId);
    final cost = spec.cost * (1 - country.recruitmentDiscount);

    final capacity = economy.manpowerCapacityOf(country);
    if (army.manpower + spec.manpower > capacity) {
      return const ActionResult.failed('mil.capacityFull');
    }
    if (country.treasury < cost) {
      return ActionResult.failed(
        'mil.insufficient',
        params: {
          'need': '${cost.toStringAsFixed(0)} ${GameConstants.currency}',
        },
      );
    }
    return ActionResult.ok(
      'mil.recruited',
      params: {
        'name': type == UnitType.infantry ? 'mil.infantry' : 'mil.armor',
        'region': country.nameEn,
      },
    );
  }

  /// Applies recruitment (called only after [recruit] returns OK).
  GameState commitRecruit(GameState state, UnitType type) {
    final ws = SimulationWorkspace(source: state);
    final country = ws.country(state.playerId)!;
    final spec = Balance.units[type]!;
    final cost = spec.cost * (1 - country.recruitmentDiscount);
    final ordinal = state.unitsOf(state.playerId).length + 1;
    // Equipment shortages raise the formation at reduced strength.
    final (equipped, fraction) = industry.consumeForRecruit(
      country,
      spec.equipmentCost,
    );

    ws.addUnit(
      MilitaryUnit(
        id: '${state.playerId}_rec${ws.day}_$ordinal',
        type: type,
        ownerId: state.playerId,
        homeRegion: state.playerId,
        power: 55 + 45 * fraction,
        maxPower: 100,
        experience: 0,
        formedDay: ws.day,
        ordinal: ordinal,
      ),
    );
    ws.putCountry(
      equipped.copyWith(treasury: _clampTreasury(country.treasury - cost)),
    );
    ws.events.add(
      kind: GameEventKind.recruitment,
      day: ws.day,
      titleKey: 'evt.recruit.title',
      bodyKey: 'evt.recruit.body',
      params: {'country': country.nameEn, 'count': '1'},
      countryId: state.playerId,
      severity: 1,
    );
    return ws.publish();
  }

  bool canDisband(GameState state, MilitaryUnit unit) =>
      state.wars.any((w) => w.involves(state.playerId)) == false;

  GameState disband(GameState state, String unitId) {
    final ws = SimulationWorkspace(source: state);
    ws.setUnits(ws.units.where((u) => u.id != unitId).toList());
    return ws.publish();
  }

  /// Sets the player's military funding multiplier.
  GameState setMilitaryBudget(GameState state, double multiplier) {
    final clamped = multiplier.clamp(0.6, 1.5);
    final country = state.player;
    final ws = SimulationWorkspace(source: state);
    ws.putCountry(country.copyWith(militaryBudget: clamped));
    return ws.publish().copyWithBudgetOverride(clamped);
  }

  // --------------------------------------------------------------- diplomacy

  ActionResult improveRelations(GameState state, String otherId) {
    final problem = diplomacy.validateImprove(state, state.playerId, otherId);
    if (problem != null) {
      return ActionResult.failed(
        problem,
        params: {'name': state.countries[otherId]?.nameEn ?? otherId},
      );
    }
    return ActionResult.ok('dip.improved');
  }

  GameState commitImproveRelations(GameState state, String otherId) {
    final ws = SimulationWorkspace(source: state);
    final player = ws.country(state.playerId)!;
    ws.putCountry(
      player.copyWith(
        treasury: _clampTreasury(
          player.treasury - Balance.costImproveRelations,
        ),
      ),
    );
    _shiftRelations(ws, state.playerId, otherId, Balance.relationsGainImprove);
    final value = ws.country(state.playerId)!.relations[otherId] ?? 0;
    ws.events.add(
      kind: GameEventKind.diplomacy,
      day: ws.day,
      titleKey: 'evt.dip.title',
      bodyKey: 'evt.dip.body',
      params: {
        'type': 'dip.improve',
        'a': player.nameEn,
        'b': ws.country(otherId)!.nameEn,
        'value': value.toStringAsFixed(0),
      },
      countryId: state.playerId,
      severity: 1,
    );
    return ws.publish();
  }

  /// Proposes a treaty; the AI decides immediately and the treaty is stored.
  ActionResult proposeAgreement(
    GameState state,
    String otherId,
    AgreementType type,
  ) {
    final problem = diplomacy.validateProposal(
      state,
      state.playerId,
      otherId,
      type,
    );
    if (problem != null) {
      return ActionResult.failed(
        problem,
        params: {
          'name': state.countries[otherId]?.nameEn ?? otherId,
          'n': Balance.pactMinRelations.toStringAsFixed(0),
        },
      );
    }
    final accepted = diplomacy.wouldAccept(
      state,
      proposer: state.playerId,
      target: otherId,
      type: type,
    );
    return accepted
        ? const ActionResult.ok('dip.accepted')
        : const ActionResult.failed('dip.rejected');
  }

  GameState commitAgreement(
    GameState state,
    String otherId,
    AgreementType type, {
    required bool accepted,
  }) {
    final ws = SimulationWorkspace(source: state);
    final cost = diplomacy.proposalCost(type);
    final player = ws.country(state.playerId)!;
    // The lobbying cost is spent whether or not the offer is accepted.
    ws.putCountry(
      player.copyWith(treasury: _clampTreasury(player.treasury - cost)),
    );

    if (accepted) {
      ws.addAgreement(
        DiplomaticAgreement(
          id: 'ag_${ws.day}_${state.playerId}_$otherId',
          type: type,
          a: state.playerId,
          b: otherId,
          signedDay: ws.day,
        ),
      );
      _shiftRelations(ws, state.playerId, otherId, 6);
      ws.events.add(
        kind: GameEventKind.diplomacy,
        day: ws.day,
        titleKey: 'evt.dip.title',
        bodyKey: 'evt.dip.body',
        params: {
          'type': type == AgreementType.alliance
              ? 'dip.allianceLabel'
              : 'dip.pactLabel',
          'a': player.nameEn,
          'b': ws.country(otherId)!.nameEn,
          'value': (ws.country(state.playerId)!.relations[otherId] ?? 0)
              .toStringAsFixed(0),
        },
        countryId: state.playerId,
        severity: 1,
      );
    } else {
      _shiftRelations(ws, state.playerId, otherId, -2);
    }
    return ws.publish();
  }

  /// Renounces one treaty; relations take a hit.
  GameState renounceAgreement(GameState state, String agreementId) {
    final ws = SimulationWorkspace(source: state);
    final agreement = ws.agreements.firstWhere(
      (a) => a.id == agreementId,
      orElse: () => DiplomaticAgreement(
        id: agreementId,
        type: AgreementType.nonAggression,
        a: state.playerId,
        b: state.playerId,
        signedDay: ws.day,
      ),
    );
    if (agreement.id != agreementId) return state;
    final other = agreement.other(state.playerId);
    ws.removeAgreement(agreementId);
    _shiftRelations(ws, state.playerId, other, -12);
    return ws.publish();
  }

  // ------------------------------------------------------------------ battle

  ActionResult declareWar(GameState state, String defenderId) {
    final problem = battle.validateAttack(state, state.playerId, defenderId);
    if (problem != null) {
      return ActionResult.failed(
        problem,
        params: {'name': state.countries[defenderId]?.nameEn ?? defenderId},
      );
    }
    return ActionResult.ok(
      'bt.warDeclared',
      params: {'name': state.countries[defenderId]!.nameEn},
    );
  }

  GameState commitDeclareWar(GameState state, String defenderId) {
    final ws = SimulationWorkspace(source: state);
    final warId = 'war_${ws.day}_${state.playerId}_$defenderId';
    ws.addWar(
      War(
        id: warId,
        aggressor: state.playerId,
        defender: defenderId,
        startedDay: ws.day,
        frontRegion: defenderId,
      ),
    );
    ws.addBattle(
      battle.beginBattle(
        state,
        state.playerId,
        defenderId,
        warId: warId,
        battleIndex: ws.battles.length,
      ),
    );
    _shiftRelations(ws, state.playerId, defenderId, -28);
    // Treaty partners of the victim condemn the aggression.
    for (final ally in state.defendersOf(defenderId)) {
      if (ally == state.playerId) continue;
      _shiftRelations(ws, state.playerId, ally, -14);
    }
    ws.updatePolitics(
      (p) => p.copyWith(tension: (p.tension + 6).clamp(0.0, 100.0)),
    );
    ws.events.add(
      kind: GameEventKind.battle,
      day: ws.day,
      titleKey: 'evt.war.title',
      bodyKey: 'evt.war.body',
      params: {
        'a': state.player.nameEn,
        'b': state.countries[defenderId]!.nameEn,
        'region': state.countries[defenderId]!.capitalEn,
      },
      countryId: state.playerId,
      severity: -1,
    );
    return ws.publish();
  }

  /// Offers peace to the opponent of an ongoing war.
  bool wouldAcceptPeace(GameState state, String opponentId) {
    final war = state.warBetween(state.playerId, opponentId);
    if (war == null) return true;
    final ours = state.armyOf(state.playerId).combatScore;
    final theirs = state.armyOf(opponentId).combatScore;
    final opponent = state.countries[opponentId]!;
    // A nation only accepts peace when it is not clearly winning.
    final winning =
        theirs > ours * 1.3 &&
        opponent.stability > 35 &&
        opponent.treasury > -20000;
    if (winning) return false;
    return _rng.nextDouble() < 0.72;
  }

  GameState makePeace(GameState state, String opponentId) {
    final war = state.warBetween(state.playerId, opponentId);
    if (war == null) return state;
    final ws = SimulationWorkspace(source: state);
    ws.removeWar(war.id);
    ws.battles.removeWhere((b) => b.warId == war.id);
    ws.dirty();
    _shiftRelations(ws, state.playerId, opponentId, 8);
    ws.events.add(
      kind: GameEventKind.battle,
      day: ws.day,
      titleKey: 'evt.peace.title',
      bodyKey: 'evt.peace.body',
      params: {
        'a': state.player.nameEn,
        'b': state.countries[opponentId]!.nameEn,
        'region': state.countries[opponentId]!.capitalEn,
      },
      countryId: state.playerId,
      severity: 1,
    );
    return ws.publish();
  }


  // ---------------------------------------------------------------- research

  /// Validates starting [techId] for the player.
  ActionResult startResearch(GameState state, String techId) {
    final c = state.player;
    final spec = TechTree.byId(techId);
    if (spec == null) return const ActionResult.failed('res.unknown');
    if (c.hasTech(techId)) return const ActionResult.failed('res.known');
    if (c.researchId != null) return const ActionResult.failed('res.busy');
    if (!industry.prerequisitesMet(c, spec)) {
      return const ActionResult.failed('res.locked');
    }
    if (c.treasury < spec.cost) {
      return ActionResult.failed(
        'eco.insufficient',
        params: {
          'need': '${spec.cost.toStringAsFixed(0)} ${GameConstants.currency}',
        },
      );
    }
    return ActionResult.ok('res.started', params: {'tech': 'tech.$techId'});
  }

  GameState commitResearch(GameState state, String techId) =>
      _beginResearch(state, state.playerId, techId);

  GameState _beginResearch(GameState state, String countryId, String techId) {
    final spec = TechTree.byId(techId)!;
    final ws = SimulationWorkspace(source: state);
    final c = ws.country(countryId)!;
    ws.putCountry(
      c.copyWith(
        treasury: _clampTreasury(c.treasury - spec.cost),
        researchId: techId,
        researchProgress: 0,
      ),
    );
    return ws.publish();
  }

  /// Abandons the current programme; half of its cost is refunded.
  GameState cancelResearch(GameState state) {
    final c = state.player;
    final spec = c.researchId == null ? null : TechTree.byId(c.researchId!);
    if (spec == null) return state;
    final ws = SimulationWorkspace(source: state);
    ws.putCountry(
      c.copyWith(
        treasury: _clampTreasury(c.treasury + spec.cost * 0.5),
        clearResearch: true,
      ),
    );
    return ws.publish();
  }

  // -------------------------------------------------------------- production

  ActionResult queueProduction(
    GameState state,
    EquipmentType type,
    int quantity,
  ) {
    final c = state.player;
    if (c.militaryFactories <= 0) {
      return const ActionResult.failed('prod.noFactories');
    }
    if (state.productionOf(state.playerId).length >=
        Balance.maxProductionLines) {
      return const ActionResult.failed('prod.linesFull');
    }
    final cost = industry.productionCost(type, quantity);
    if (c.treasury < cost) {
      return ActionResult.failed(
        'eco.insufficient',
        params: {'need': '${cost.toStringAsFixed(0)} ${GameConstants.currency}'},
      );
    }
    return ActionResult.ok(
      'prod.queued',
      params: {'equipment': 'equip.${type.name}', 'n': quantity.toString()},
    );
  }

  GameState commitProduction(
    GameState state,
    EquipmentType type,
    int quantity,
  ) => _placeProduction(state, state.playerId, type, quantity);

  GameState _placeProduction(
    GameState state,
    String countryId,
    EquipmentType type,
    int quantity,
  ) {
    final ws = SimulationWorkspace(source: state);
    final c = ws.country(countryId)!;
    final cost = industry.productionCost(type, quantity);
    ws.putCountry(c.copyWith(treasury: _clampTreasury(c.treasury - cost)));
    ws.putProduction(countryId, [
      ...ws.production[countryId] ?? const <ProductionOrder>[],
      ProductionOrder.queue(type, quantity: quantity, day: ws.day),
    ]);
    return ws.publish();
  }

  /// Cancels a production line; undelivered units are refunded at 50%.
  GameState cancelProduction(GameState state, int index) {
    final orders = state.productionOf(state.playerId);
    if (index < 0 || index >= orders.length) return state;
    final o = orders[index];
    final ws = SimulationWorkspace(source: state);
    final c = ws.country(state.playerId)!;
    final refund = industry.productionCost(o.type, o.unitsRemaining) * 0.5;
    ws.putCountry(c.copyWith(treasury: _clampTreasury(c.treasury + refund)));
    ws.putProduction(state.playerId, [...orders]..removeAt(index));
    return ws.publish();
  }

  // ------------------------------------------------------ trade & sanctions

  /// Imposes (or escalates) a sanction from the player on [targetId].
  ActionResult imposeSanction(GameState state, String targetId) {
    if (!state.countries.containsKey(targetId) || targetId == state.playerId) {
      return const ActionResult.failed('bt.cannotBorder');
    }
    final existing = state.politics.sanctionBetween(state.playerId, targetId);
    if (existing?.tier == SanctionTier.embargo) {
      return const ActionResult.failed('dip.sanctionMax');
    }
    if (state.alliesOf(state.playerId).contains(targetId)) {
      return const ActionResult.failed('dip.sanctionAlly');
    }
    return ActionResult.ok(
      'dip.sanctioned',
      params: {'name': state.countries[targetId]!.nameEn},
    );
  }

  GameState commitSanction(GameState state, String targetId) =>
      _applySanction(state, state.playerId, targetId);

  GameState _applySanction(GameState state, String imposer, String target) {
    final ws = SimulationWorkspace(source: state);
    final existing = ws.politics.sanctionBetween(imposer, target);
    final tier = existing == null
        ? SanctionTier.targeted
        : SanctionTier.values[(existing.tier.index + 1).clamp(
            0,
            SanctionTier.values.length - 1,
          )];
    final rest = ws.politics.sanctions
        .where((x) => !(x.imposerId == imposer && x.targetId == target))
        .toList();
    rest.add(
      Sanction(
        id: 'sn_${ws.day}_${imposer}_$target',
        imposerId: imposer,
        targetId: target,
        tier: tier,
        imposedDay: ws.day,
        reasonKey: 'dip.sanctionReason',
      ),
    );
    ws.updatePolitics(
      (p) => p.copyWith(
        sanctions: rest,
        tension: (p.tension + 2.5).clamp(0.0, 100.0),
      ),
    );
    // Sanctions end any trade deal and sour relations.
    ws.agreements.removeWhere(
      (a) =>
          a.type == AgreementType.trade && a.involves(imposer) && a.involves(target),
    );
    ws.dirty();
    _shiftRelations(ws, imposer, target, -Balance.sanctionRelationsCost / 2);
    ws.events.add(
      kind: GameEventKind.diplomacy,
      day: ws.day,
      titleKey: 'evt.sanction.title',
      bodyKey: 'evt.sanction.body',
      params: {
        'a': ws.country(imposer)!.nameEn,
        'b': ws.country(target)!.nameEn,
        'tier': 'dip.tier.${tier.name}',
      },
      countryId: imposer,
      severity: -1,
    );
    return ws.publish();
  }

  /// Lifts the player's sanction on [targetId]; relations recover a little.
  GameState liftSanction(GameState state, String targetId) {
    final s = state.politics.sanctionBetween(state.playerId, targetId);
    if (s == null) return state;
    final ws = SimulationWorkspace(source: state);
    ws.updatePolitics(
      (p) => p.copyWith(
        sanctions: p.sanctions.where((x) => x.id != s.id).toList(),
        tension: (p.tension - 1.5).clamp(0.0, 100.0),
      ),
    );
    _shiftRelations(ws, state.playerId, targetId, 5);
    return ws.publish();
  }

  // ------------------------------------------------------------------ map/HUD

  /// Regions grouped by current controller, for the military map mode.
  Map<String, String> controlMap(GameState state) => state.control;

  Set<String> warRegions(GameState state) => {
    for (final w in state.wars)
      if (w.aggressor == state.playerId || w.defender == state.playerId) ...{
        w.aggressor,
        w.defender,
      },
  };

  bool isAlly(GameState state, String countryId) =>
      state.alliesOf(state.playerId).contains(countryId);

  bool isAtWar(GameState state, String countryId) =>
      state.atWarWith(state.playerId, countryId);
}

import 'dart:math';

import '../core/balance.dart';
import '../models/battle.dart';
import '../models/country.dart';
import '../models/diplomatic_agreement.dart';
import '../models/game_event.dart';
import '../models/military_unit.dart';
import '../models/production.dart';
import '../models/world_politics.dart';
import 'battle_engine.dart';
import 'workspace.dart';
import 'diplomacy_engine.dart';
import 'industry_engine.dart';

/// Predictable, testable decision rules for every non-player nation.
///
/// The AI runs on a fixed pulse (every [GameConstants.aiPulseDays] days) rather
/// than every frame, and every action is bounded so it can never create money,
/// units or treaties out of nothing.
class AiEngine {
  AiEngine({required this.battle, required this.diplomacy, Random? random})
    : _rng = random ?? Random();

  final BattleEngine battle;
  final DiplomacyEngine diplomacy;
  final Random _rng;

  static const IndustryEngine _industry = IndustryEngine();

  /// Runs one AI pulse for every non-player nation.
  void pulse(
    SimulationWorkspace ws, {
    required void Function(MilitaryUnit) addUnit,
  }) {
    final state = ws.state;
    final ids = ws.foreignIds.toList(growable: false);

    for (final id in ids) {
      final country = ws.country(id);
      if (country == null) continue;
      _act(ws, id, country, addUnit);
      _develop(ws, id);
    }

    // AI nations occasionally open a limited demo war against a weak,
    // unfriendly neighbour.
    _considerWar(ws);

    // Relations continue to evolve between pulses.
    for (final id in ids) {
      final c = ws.country(id);
      if (c == null) continue;
      final drifted = diplomacy.driftRelations(state, id);
      ws.putCountry(drifted);
    }
  }

  void _act(
    SimulationWorkspace ws,
    String id,
    Country country,
    void Function(MilitaryUnit) addUnit,
  ) {
    final state = ws.state;
    final army = state.armyOf(id);
    final atWar = state.wars.any((w) => w.involves(id));

    // --- 1. Construction: industrialists build, others build when rich. -----
    final projects = state.constructionOf(id);
    if (projects.length < 2) {
      final buildChance = switch (country.personality) {
        AiPersonality.industrialist => 0.65,
        AiPersonality.defensive => 0.30,
        AiPersonality.opportunist => 0.35,
        AiPersonality.expansionist => 0.55,
      };
      final type = _pickBuilding(country, atWar);
      final spec = Balance.buildings[type]!;
      final affordable = country.treasury > spec.cost * 1.35;
      if (affordable && _rng.nextDouble() < buildChance) {
        final orders = [...projects];
        orders.add(
          ConstructionOrder(
            type: type,
            startedDay: ws.day,
            durationDays: spec.days,
            invested: spec.cost,
            progressDays: 0,
          ),
        );
        ws.putCountry(country.copyWith(treasury: country.treasury - spec.cost));
        ws.putConstruction(id, orders);
        ws.events.add(
          kind: GameEventKind.construction,
          day: ws.day,
          titleKey: 'evt.build.title',
          params: {
            'building': 'eco.${type.name}.name',
            'country': country.nameEn,
            'amount': spec.industrialDelta.toStringAsFixed(0),
          },
          countryId: id,
          severity: 1,
        );
      }
    }

    // --- 2. Recruitment: keep an army proportionate to ambition. ------------
    final manpowerCap =
        state.countries[id]!.population *
        0.012 *
        (0.7 + country.stability / 250);
    final usedManpower = army.manpower;
    final wantInfantry = switch (country.personality) {
      AiPersonality.expansionist => 0.85,
      AiPersonality.defensive => 0.70,
      AiPersonality.opportunist => 0.55,
      AiPersonality.industrialist => 0.40,
    };
    final wantArmor = switch (country.personality) {
      AiPersonality.expansionist => 0.45,
      AiPersonality.industrialist => 0.30,
      AiPersonality.defensive => 0.25,
      AiPersonality.opportunist => 0.35,
    };

    if (army.totalUnits < 40 && usedManpower < manpowerCap) {
      // Pick the doctrine's preferred arm, falling back to infantry when the
      // armoured share is already at its target.
      final armoredShare = army.totalUnits == 0
          ? 1.0
          : army.armorUnits / army.totalUnits;
      var type = UnitType.infantry;
      if (armoredShare < wantArmor && army.infantryUnits > 0) {
        type = UnitType.armor;
      } else if (wantInfantry > 0 && _rng.nextDouble() < 0.25) {
        type = UnitType.armor;
      }

      final spec = Balance.units[type]!;
      final cost = spec.cost * (1 - country.recruitmentDiscount);
      // At war the AI commits hard; in peacetime it keeps a healthy reserve.
      final reserveFactor = atWar ? 0.55 : 1.5;
      final chance = atWar ? 0.85 : 0.40;

      final current = ws.country(id)!;
      if (current.treasury > cost * reserveFactor &&
          _rng.nextDouble() < chance) {
        final ordinal = state.unitsOf(id).length + 1;
        final (equipped, fraction) = _industry.consumeForRecruit(
          current,
          spec.equipmentCost,
        );
        addUnit(
          MilitaryUnit(
            id: '${id}_u${ws.day}_$ordinal',
            type: type,
            ownerId: id,
            homeRegion: id,
            power: 55 + 45 * fraction,
            maxPower: 100,
            experience: 0,
            formedDay: ws.day,
            ordinal: ordinal,
          ),
        );
        ws.putCountry(equipped.copyWith(treasury: current.treasury - cost));
        ws.events.add(
          kind: GameEventKind.recruitment,
          day: ws.day,
          titleKey: 'evt.ai.title',
          bodyKey: 'evt.ai.body',
          params: {'country': country.nameEn},
          countryId: id,
          severity: 0,
        );
      }
    }

    // --- 3. Diplomacy: reach out to nations it already likes. --------------
    if (!atWar && _rng.nextDouble() < 0.28) {
      final partners = state.countries.keys
          .where(
            (other) =>
                other != id &&
                other != state.playerId &&
                !state.atWarWith(id, other) &&
                state.countries[id]!.theatres.contains(other),
          )
          .toList();
      if (partners.isNotEmpty) {
        partners.shuffle(_rng);
        final target = partners.first;
        final relations = diplomacy.relationsOf(state, id, target);
        if (relations >= Balance.allianceMinRelations &&
            !state.hasAgreement(id, target, AgreementType.alliance)) {
          ws.addAgreement(
            DiplomaticAgreement(
              id: 'ag_${ws.day}_${id}_$target',
              type: AgreementType.alliance,
              a: id,
              b: target,
              signedDay: ws.day,
            ),
          );
          ws.events.add(
            kind: GameEventKind.diplomacy,
            day: ws.day,
            titleKey: 'evt.dip.title',
            bodyKey: 'evt.dip.body',
            params: {
              'type': 'dip.allianceLabel',
              'a': state.countries[id]!.nameEn,
              'b': state.countries[target]!.nameEn,
              'value': relations.toStringAsFixed(0),
            },
            countryId: id,
            severity: 1,
          );
        } else if (relations < -35 && _rng.nextDouble() < 0.4) {
          // Rivals drift further apart — surfaced as a tension event.
          final c = ws.country(id)!;
          final rel = Map<String, double>.from(c.relations);
          rel[target] = (relations - 4).clamp(-100.0, 100.0);
          ws.putCountry(c.copyWith(relations: rel));
          ws.events.add(
            kind: GameEventKind.intelligence,
            day: ws.day,
            titleKey: 'evt.tension.title',
            bodyKey: 'evt.tension.body',
            params: {
              'a': c.nameEn,
              'b': state.countries[target]!.nameEn,
              'value': rel[target]!.toStringAsFixed(0),
            },
            countryId: id,
            severity: -1,
          );
        }
      }
    }
  }

  /// Research, equipment production, trade and sanctions.
  void _develop(SimulationWorkspace ws, String id) {
    final state = ws.state;
    var c = ws.country(id)!;
    final atWar = state.wars.any((w) => w.involves(id));

    // --- research: always keep a programme running when affordable.
    if (c.researchId == null) {
      final options = _industry.availableTechs(c)
        ..sort((a, b) => _techWeight(c, b).compareTo(_techWeight(c, a)));
      if (options.isNotEmpty) {
        final pick = options.first;
        if (c.treasury > pick.cost * 1.6) {
          c = c.copyWith(
            treasury: c.treasury - pick.cost,
            researchId: pick.id,
            researchProgress: 0,
          );
          ws.putCountry(c);
        }
      }
    }

    // --- equipment: top up whatever the army is short of.
    final orders = ws.production[id] ?? const <ProductionOrder>[];
    if (c.militaryFactories > 0 && orders.length < 2) {
      final need = _industry.equipmentNeed(state, id);
      EquipmentType? worst;
      var worstRatio = atWar ? 1.4 : 1.1;
      for (final e in EquipmentType.values) {
        final required = e == EquipmentType.aircraft
            ? state.unitsOf(id).length * 1.0
            : need[e]!;
        if (required <= 0) continue;
        final ratio = c.equipmentCount(e) / required;
        if (ratio < worstRatio) {
          worstRatio = ratio;
          worst = e;
        }
      }
      if (worst != null && !orders.any((o) => o.type == worst)) {
        final qty = atWar ? 25 : 10;
        final cost = _industry.productionCost(worst, qty);
        if (c.treasury > cost * 2) {
          c = c.copyWith(treasury: c.treasury - cost);
          ws.putCountry(c);
          ws.putProduction(id, [
            ...orders,
            ProductionOrder.queue(worst, quantity: qty, day: ws.day),
          ]);
        }
      }
    }

    if (atWar || _rng.nextDouble() > 0.35) return;

    // --- trade & sanctions with neighbours.
    final neighbours = c.theatres
        .where((o) => o != id && state.countries.containsKey(o))
        .toList()
      ..shuffle(_rng);
    for (final other in neighbours.take(2)) {
      final rel = c.relations[other] ?? 0;
      final sanctioned =
          state.politics.sanctionBetween(id, other) != null ||
          state.politics.sanctionBetween(other, id) != null;
      final isPlayer = other == state.playerId;

      if (rel >= Balance.tradeDealMinRelations + 8 &&
          !sanctioned &&
          !isPlayer &&
          !state.hasAgreement(id, other, AgreementType.trade) &&
          state.tradePartnersOf(id).length < 4) {
        ws.addAgreement(
          DiplomaticAgreement(
            id: 'tr_${ws.day}_${id}_$other',
            type: AgreementType.trade,
            a: id,
            b: other,
            signedDay: ws.day,
          ),
        );
        return;
      }

      if (rel >= Balance.allianceMinRelations * 0.8 &&
          !isPlayer &&
          !state.hasAgreement(id, other, AgreementType.defencePact) &&
          !state.hasAgreement(id, other, AgreementType.alliance) &&
          c.personality == AiPersonality.defensive) {
        ws.addAgreement(
          DiplomaticAgreement(
            id: 'dp_${ws.day}_${id}_$other',
            type: AgreementType.defencePact,
            a: id,
            b: other,
            signedDay: ws.day,
          ),
        );
        return;
      }

      final existing = state.politics.sanctionBetween(id, other);
      if (rel <= -45 &&
          c.industrial > 40 &&
          (existing == null || existing.tier != SanctionTier.embargo) &&
          !state.alliesOf(id).contains(other) &&
          _rng.nextDouble() < 0.5) {
        final tier = existing == null
            ? SanctionTier.targeted
            : SanctionTier.values[existing.tier.index + 1];
        ws.updatePolitics(
          (p) => p.copyWith(
            sanctions: [
              ...p.sanctions.where((x) => x != existing),
              Sanction(
                id: 'sn_${ws.day}_${id}_$other',
                imposerId: id,
                targetId: other,
                tier: tier,
                imposedDay: ws.day,
                reasonKey: 'dip.sanctionReason',
              ),
            ],
            tension: (p.tension + 2).clamp(0.0, 100.0),
          ),
        );
        // Trade with a sanctioned nation collapses.
        ws.agreements.removeWhere(
          (a) =>
              a.type == AgreementType.trade &&
              a.involves(id) &&
              a.involves(other),
        );
        ws.dirty();
        ws.events.add(
          kind: GameEventKind.diplomacy,
          day: ws.day,
          titleKey: 'evt.sanction.title',
          bodyKey: 'evt.sanction.body',
          params: {
            'a': c.nameEn,
            'b': state.countries[other]!.nameEn,
            'tier': 'dip.tier.${tier.name}',
          },
          countryId: id,
          severity: other == state.playerId ? -1 : 0,
        );
        return;
      }

      // Long-standing sanctions are lifted once relations recover.
      if (existing != null && rel > -10) {
        ws.updatePolitics(
          (p) => p.copyWith(
            sanctions: p.sanctions.where((x) => x != existing).toList(),
          ),
        );
        return;
      }
    }
  }

  double _techWeight(Country c, TechSpec t) {
    final base = 10.0 - t.tier * 2;
    final doctrine = switch ((c.personality, t.branch)) {
      (AiPersonality.industrialist, TechBranch.industry) => 6.0,
      (AiPersonality.industrialist, TechBranch.economy) => 5.0,
      (AiPersonality.expansionist, TechBranch.military) => 6.0,
      (AiPersonality.expansionist, TechBranch.logistics) => 4.0,
      (AiPersonality.defensive, TechBranch.military) => 4.0,
      (AiPersonality.defensive, TechBranch.science) => 3.0,
      (AiPersonality.opportunist, TechBranch.economy) => 5.0,
      _ => 1.0,
    };
    return base + doctrine + _rng.nextDouble() * 3;
  }

  BuildingType _pickBuilding(Country country, bool atWar) {
    if (atWar && _rng.nextDouble() < 0.45) {
      return _rng.nextBool()
          ? BuildingType.fortification
          : BuildingType.militaryFactory;
    }
    return switch (country.personality) {
      AiPersonality.industrialist =>
        _rng.nextBool() ? BuildingType.factory : BuildingType.infrastructure,
      AiPersonality.defensive =>
        _rng.nextBool()
            ? BuildingType.fortification
            : BuildingType.militaryFactory,
      AiPersonality.expansionist =>
        _rng.nextBool() ? BuildingType.militaryFactory : BuildingType.factory,
      AiPersonality.opportunist =>
        _rng.nextBool() ? BuildingType.infrastructure : BuildingType.factory,
    };
  }

  /// Limits AI aggression: at most one AI-initiated war at a time, only against
  /// a clearly weaker and unfriendly nation, and never in the first 45 days.
  void _considerWar(SimulationWorkspace ws) {
    if (ws.day < 45) return;
    // Never let an AI nation open more than one war at a time, and never while
    // another AI war is already running — keeps the demo readable.
    final aiWars = ws.wars
        .where((w) => w.aggressor != ws.playerId && w.defender != ws.playerId)
        .length;
    if (aiWars >= 1) return;
    if (_rng.nextDouble() > 0.10) return;

    final candidates = <(String, String, double)>[];
    for (final aggressor in ws.foreignIds) {
      final a = ws.country(aggressor);
      if (a == null) continue;
      if (a.personality == AiPersonality.defensive) continue;
      if (ws.state.wars.any((w) => w.involves(aggressor))) continue;
      final aArmy = ws.state.armyOf(aggressor);
      if (aArmy.combatScore < 40) continue;

      for (final target in a.theatres) {
        final b = ws.country(target);
        if (b == null || target == aggressor) continue;
        if (ws.state.atWarWith(aggressor, target)) continue;
        if (ws.state.hasAgreement(aggressor, target, AgreementType.alliance)) {
          continue;
        }
        if (ws.state.nonAggressionBetween(aggressor, target)) continue;
        final relations = a.relations[target] ?? 0;
        if (relations > -30) continue;
        final bArmy = ws.state.armyOf(target);
        if (aArmy.combatScore < bArmy.combatScore * 1.45) continue;
        candidates.add((aggressor, target, relations));
      }
    }

    if (candidates.isEmpty) return;
    candidates.sort((x, y) => x.$3.compareTo(y.$3));
    final pick = candidates.first;
    ws.addWar(
      War(
        id: 'war_${ws.day}_${pick.$1}_${pick.$2}',
        aggressor: pick.$1,
        defender: pick.$2,
        startedDay: ws.day,
        frontRegion: pick.$2,
      ),
    );
    ws.events.add(
      kind: GameEventKind.battle,
      day: ws.day,
      titleKey: 'evt.war.title',
      bodyKey: 'evt.war.body',
      params: {
        'a': ws.country(pick.$1)!.nameEn,
        'b': ws.country(pick.$2)!.nameEn,
        'region': ws.country(pick.$2)!.capitalEn,
      },
      countryId: pick.$1,
      severity: -1,
    );

    // The war opens with an immediate engagement.
    final warId = 'war_${ws.day}_${pick.$1}_${pick.$2}';
    ws.addBattle(
      battle.beginBattle(
        ws.state,
        pick.$1,
        pick.$2,
        warId: warId,
        battleIndex: ws.battles.length,
      ),
    );
  }
}

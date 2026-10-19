import 'dart:math';

import '../core/balance.dart';
import '../data/tech_tree.dart';
import '../models/country.dart';
import '../models/game_state.dart';
import '../models/production.dart';
import '../models/region.dart';

/// Monthly resource trade of one nation on the world market.
class TradeFlows {
  const TradeFlows({
    required this.exports,
    required this.imports,
    required this.tradeDeals,
  });

  /// Credits earned by selling surplus resources.
  final double exports;

  /// Credits spent buying resources the nation does not produce enough of.
  final double imports;

  /// Bonus income from bilateral trade agreements.
  final double tradeDeals;
}

/// Occupation economics of one nation (monthly).
class OccupationFlows {
  const OccupationFlows({
    required this.income,
    required this.cost,
    required this.homeLoss,
  });

  /// Income extracted from foreign regions this nation holds.
  final double income;

  /// Garrison cost of holding those regions.
  final double cost;

  /// Fraction (0..1) of its own homeland currently held by an enemy.
  final double homeLoss;
}

/// Resources, factories, research, equipment production and army readiness.
///
/// Everything here is a pure function of [GameState] (or returns an updated
/// copy), so the economy screen, the industry screen and the daily tick all
/// read identical numbers.
class IndustryEngine {
  const IndustryEngine();

  // ---------------------------------------------------------------- resources

  /// Daily production of every resource. Occupied homeland produces nothing.
  Map<ResourceType, double> dailyProduction(GameState s, Country c) {
    final loss = occupationOf(s, c.id).homeLoss;
    return {
      for (final r in ResourceType.values)
        r: _rawProduction(c, r) * Balance.resourceDailyScale * (1 - loss),
    };
  }

  static double _rawProduction(Country c, ResourceType r) =>
      c.resourceProduction[r.name] ??
      (r == ResourceType.aluminium ? c.resourceProduction['alu'] : null) ??
      0;

  /// Daily demand of every resource from industry, population and the army.
  Map<ResourceType, double> dailyDemand(GameState s, Country c) {
    final divisions = s.units.where((u) => u.ownerId == c.id).length;
    final out = <ResourceType, double>{};
    for (final r in ResourceType.values) {
      out[r] =
          c.industrial * (Balance.industryDemand[r] ?? 0) +
          c.population / 10 * (Balance.civilianDemand[r] ?? 0) +
          divisions * (Balance.armyDemand[r] ?? 0);
    }
    return out;
  }

  /// Stock ceiling for one resource: two months of demand.
  double stockCap(double dailyDemand) => max(20.0, dailyDemand * 60);

  /// Whether the nation can still buy on the world market.
  bool canImport(GameState s, Country c) =>
      c.treasury > 0 && s.sanctionPressureOn(c.id) < 0.40;

  /// Fraction (0..1) of a resource's demand that is currently unmet.
  double shortageOf(GameState s, Country c, ResourceType r) {
    final prod = dailyProduction(s, c)[r]!;
    final demand = dailyDemand(s, c)[r]!;
    if (demand <= 0 || prod >= demand) return 0;
    if (canImport(s, c)) return 0;
    if (c.resourceStock(r) > 0.01) return 0;
    return ((demand - prod) / demand).clamp(0.0, 1.0);
  }

  /// Output penalty (0..max) caused by industrial resource shortages.
  double shortagePenalty(GameState s, Country c) {
    var weighted = 0.0;
    var weights = 0.0;
    for (final r in Balance.industryDemand.keys) {
      final w = Balance.resources[r]!.weight;
      weighted += shortageOf(s, c, r) * w;
      weights += w;
    }
    if (weights <= 0) return 0;
    final avg = weighted / weights;
    if (avg < Balance.shortageThreshold) return 0;
    return avg * Balance.shortageMaxPenalty;
  }

  /// Monthly world-market trade flows.
  TradeFlows tradeFlows(GameState s, String id) {
    final c = s.countries[id]!;
    final prod = dailyProduction(s, c);
    final demand = dailyDemand(s, c);
    final pressure = s.sanctionPressureOn(id);
    final partners = s.tradePartnersOf(id);
    final importing = canImport(s, c);

    // Trade partners shave the import markup; sanctions add to it.
    final markup =
        (Balance.importMarkup -
                partners.length * (1 - Balance.tradePriceMargin) * 0.5)
            .clamp(1.0, 2.0) +
        pressure;

    var exports = 0.0;
    var imports = 0.0;
    for (final r in ResourceType.values) {
      final price = Balance.resources[r]!.price * Balance.marketPriceScale;
      final balance = prod[r]! - demand[r]!;
      if (balance > 0) {
        exports += balance * price * Balance.exportShare;
      } else if (balance < 0 && importing) {
        imports += -balance * price * markup;
      }
    }
    exports *= 30 * (1 - pressure);
    imports *= 30;

    var deals = 0.0;
    for (final p in partners) {
      final other = s.countries[p];
      if (other == null) continue;
      deals += min(other.industrial, c.industrial) * Balance.tradeDealIncome;
    }
    // Economic communities grant every member a small market bonus.
    final bloc = s.politics.blocOf(id);
    if (bloc != null && bloc.isEconomic) {
      deals += c.resourceIncome * 0.06;
    }
    return TradeFlows(
      exports: exports,
      imports: imports,
      tradeDeals: deals * (1 - pressure),
    );
  }

  // ---------------------------------------------------------------- territory

  /// Occupation income/cost and homeland loss for one nation.
  OccupationFlows occupationOf(GameState s, String id) {
    var held = 0.0;
    var cost = 0.0;
    var homeTotal = 0;
    var homeLost = 0;
    for (final r in s.regions.values) {
      if (r.ownerId == id) {
        homeTotal++;
        if (r.controllerId != id) homeLost++;
      } else if (r.controllerId == id) {
        final owner = s.countries[r.ownerId];
        if (owner == null) continue;
        final count = max(1, WorldRegions.of(r.ownerId).length);
        final value =
            owner.industrial * Balance.incomePerIndustrial / count * 0.35;
        held += value;
        cost += value * Balance.occupationCostFactor * 6;
      }
    }
    return OccupationFlows(
      income: held,
      cost: cost,
      homeLoss: homeTotal == 0 ? 0 : homeLost / homeTotal,
    );
  }

  // ---------------------------------------------------------------- factories

  /// Monthly credits produced by civilian factories.
  double civilianOutput(GameState s, Country c) =>
      c.civilianFactories *
      Balance.civilianFactoryOutput *
      c.techFactoryMultiplier *
      (1 - shortagePenalty(s, c));

  /// Daily military production points.
  double militaryPoints(GameState s, Country c) =>
      c.militaryFactories *
      Balance.militaryFactoryOutput *
      c.techFactoryMultiplier *
      (1 - shortagePenalty(s, c));

  /// Credits to order [quantity] units of [type].
  double productionCost(EquipmentType type, int quantity) =>
      Balance.equipment[type]!.productionCost *
      quantity *
      Balance.equipmentCreditCost;

  // ----------------------------------------------------------------- research

  /// Research progress (in research-days) gained per in-game day.
  double researchRate(Country c) =>
      (Balance.baseResearchPerDay * 0.6 +
          c.industrial * Balance.researchPerIndustrial * 0.7) *
      c.techResearchMultiplier;

  /// Whether every prerequisite of [spec] has been researched.
  bool prerequisitesMet(Country c, TechSpec spec) {
    if (spec.requires.isNotEmpty) return spec.requires.every(c.hasTech);
    if (spec.tier <= 1) return true;
    return TechTree.ofBranch(
      spec.branch,
    ).any((t) => t.tier == spec.tier - 1 && c.hasTech(t.id));
  }

  /// Techs that could be started right now (ignoring money).
  List<TechSpec> availableTechs(Country c) => TechTree.all
      .where((t) => !c.hasTech(t.id) && prerequisitesMet(c, t))
      .toList(growable: false);

  // ---------------------------------------------------------------- equipment

  /// One full set of equipment for the nation's current army.
  Map<EquipmentType, double> equipmentNeed(GameState s, String id) {
    final need = {for (final e in EquipmentType.values) e: 0.0};
    for (final u in s.units) {
      if (u.ownerId != id) continue;
      for (final entry in u.spec.equipmentCost.entries) {
        final type = EquipmentType.values.firstWhere(
          (e) => e.name == entry.key,
          orElse: () => EquipmentType.smallArms,
        );
        need[type] = need[type]! + entry.value;
      }
    }
    return need;
  }

  /// Fraction (0..1) of the army's equipment requirement in stock.
  double equipmentCoverage(GameState s, Country c) {
    final need = equipmentNeed(s, c.id);
    var total = 0.0;
    var n = 0;
    for (final e in need.entries) {
      if (e.value <= 0) continue;
      total += (c.equipmentCount(e.key) / e.value).clamp(0.0, 1.0);
      n++;
    }
    return n == 0 ? 1.0 : total / n;
  }

  /// The readiness the army is drifting toward (0..100).
  double targetReadiness(GameState s, Country c) {
    final coverage = equipmentCoverage(s, c);
    final oil = shortageOf(s, c, ResourceType.oil);
    final value = (45 + 55 * coverage) * (1 - oil * 0.4);
    return value.clamp(10.0, 100.0);
  }

  /// Air-power attack bonus (0..0.08).
  double airBonus(GameState s, Country c) {
    final divisions = s.units.where((u) => u.ownerId == c.id).length;
    if (divisions == 0) return 0;
    final ratio = c.equipmentCount(EquipmentType.aircraft) / (divisions * 1.5);
    return ratio.clamp(0.0, 1.0) * 0.08;
  }

  /// Consumes the equipment a new formation needs.
  ///
  /// Returns the updated country and the fraction (0..1) of the requirement
  /// that was actually available — shortages raise weaker formations.
  (Country, double) consumeForRecruit(Country c, Map<String, int> cost) {
    final stock = Map<String, int>.from(c.equipment);
    var needed = 0;
    var got = 0;
    for (final e in cost.entries) {
      final have = stock[e.key] ?? 0;
      final take = min(have, e.value);
      stock[e.key] = have - take;
      needed += e.value;
      got += take;
    }
    final fraction = needed == 0 ? 1.0 : got / needed;
    return (c.copyWith(equipment: stock), fraction);
  }

  /// Destroys a share of the stockpile after a battle.
  Country applyEquipmentLosses(Country c, double lossRatio) {
    final factor = (1 - lossRatio * 0.5).clamp(0.3, 1.0);
    return c.copyWith(
      equipment: {
        for (final e in c.equipment.entries)
          e.key: (e.value * factor).floor(),
      },
    );
  }

  // ------------------------------------------------------------- daily update

  /// Applies one day of resource flow, research and readiness drift.
  ///
  /// Returns the updated country plus the id of a technology completed today.
  (Country, String?) applyDay(GameState s, String id) {
    var c = s.countries[id]!;
    final prod = dailyProduction(s, c);
    final demand = dailyDemand(s, c);
    final importing = canImport(s, c);

    // --- resource stockpiles.
    final stock = <String, double>{};
    for (final r in ResourceType.values) {
      final cap = stockCap(demand[r]!);
      var value = c.resourceStock(r);
      final net = prod[r]! - demand[r]!;
      if (net >= 0) {
        value = min(cap, value + net);
      } else if (importing) {
        // Imports cover the deficit and slowly rebuild the reserve.
        value = min(cap, value + demand[r]! * 0.05);
      } else {
        value = max(0.0, value + net);
      }
      stock[r.name] = value;
    }
    c = c.copyWith(resources: stock);

    // --- research.
    String? completed;
    final researching = c.researchId;
    if (researching != null) {
      final spec = TechTree.byId(researching);
      if (spec == null) {
        c = c.copyWith(clearResearch: true);
      } else {
        final progress = c.researchProgress + researchRate(c);
        if (progress >= spec.days) {
          completed = spec.id;
          c = c.copyWith(
            techs: [...c.techs, spec.id],
            industrial: c.industrial + spec.industrial,
            infrastructure: min(120.0, c.infrastructure + spec.infrastructure),
            clearResearch: true,
          );
        } else {
          c = c.copyWith(researchProgress: progress);
        }
      }
    }

    // --- readiness drifts toward what the stockpile can sustain.
    final target = targetReadiness(s, c);
    final readiness = c.armyReadiness + (target - c.armyReadiness) * 0.08;

    final occupied = s.occupiedBy(id).length;
    c = c.copyWith(
      armyReadiness: readiness.clamp(0.0, 100.0),
      occupiedRegions: occupied,
    );
    return (c, completed);
  }

  /// Advances every production order of one nation by one day.
  ///
  /// Returns the remaining orders, the updated country (with delivered
  /// equipment) and the orders finished today.
  (List<ProductionOrder>, Country, List<ProductionOrder>) advanceProduction(
    GameState s,
    Country c,
    List<ProductionOrder> orders,
  ) {
    if (orders.isEmpty) return (orders, c, const []);
    final points = militaryPoints(s, c);
    final share = points / orders.length / Balance.referenceMilitaryPoints;
    final stock = Map<String, int>.from(c.equipment);
    final remaining = <ProductionOrder>[];
    final done = <ProductionOrder>[];
    for (final o in orders) {
      var next = o.advance(share);
      final target = (next.fraction * next.quantity).floor();
      final delta = target - next.completed;
      if (delta > 0) {
        next = next.deliver(delta);
        stock[o.type.name] = (stock[o.type.name] ?? 0) + delta;
      }
      if (next.isDone) {
        final rest = next.unitsRemaining;
        if (rest > 0) {
          stock[o.type.name] = (stock[o.type.name] ?? 0) + rest;
          next = next.deliver(rest);
        }
        done.add(next);
      } else {
        remaining.add(next);
      }
    }
    return (remaining, c.copyWith(equipment: stock), done);
  }

  // ------------------------------------------------------------------ seeding

  /// Starting stockpiles so every army begins fully equipped and every
  /// economy begins with a month of reserves.
  Country seed(GameState s, Country c) {
    final need = equipmentNeed(s, c.id);
    final equipment = <String, int>{
      for (final e in EquipmentType.values)
        e.name: (need[e]! * 1.1).ceil() + c.militaryFactories * 2,
    };
    equipment[EquipmentType.aircraft.name] =
        (equipment[EquipmentType.aircraft.name] ?? 0) +
        c.militaryFactories * 4;
    final demand = dailyDemand(s, c);
    final resources = <String, double>{
      for (final r in ResourceType.values) r.name: demand[r]! * 30,
    };
    return c.copyWith(
      equipment: equipment,
      resources: resources,
      armyReadiness: 100,
    );
  }
}

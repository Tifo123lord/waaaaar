/// Balance tables: unit types, building types, resources, industry, equipment,
/// technology and economy tuning.
library;

enum UnitType { infantry, armor }

/// Construction projects the player can queue.
///
/// `factory` and `militaryFactory` raise the civilian / military factory counts
/// directly, which is what drives the whole production and resource economy.
enum BuildingType { factory, infrastructure, militaryFactory, fortification }

enum AiPersonality { expansionist, industrialist, defensive, opportunist }

/// Strategic resources. Every nation produces some and needs all of them.
enum ResourceType { oil, steel, aluminium, rubber, food, energy }

/// Equipment categories produced by the military industry.
enum EquipmentType { smallArms, artillery, armor, aircraft }

/// Research branches — each unlocks a column of the technology tree.
enum TechBranch { industry, military, logistics, economy, science }

class UnitSpec {
  const UnitSpec({
    required this.type,
    required this.cost,
    required this.maintenance,
    required this.attack,
    required this.defense,
    required this.manpower,
    required this.equipmentCost,
  });

  final UnitType type;
  final double cost;
  final double maintenance; // per month
  final double attack;
  final double defense;
  final double manpower; // millions

  /// Equipment consumed when the formation is raised, keyed by
  /// [EquipmentType.name]. A shortage means the division is raised at reduced
  /// readiness instead of blocking the order outright.
  final Map<String, int> equipmentCost;

  String get id => type.name;
}

class BuildingSpec {
  const BuildingSpec({
    required this.type,
    required this.cost,
    required this.days,
    required this.industrialDelta,
    required this.infrastructureDelta,
    required this.recruitDiscount,
    required this.defenseBonus,
    this.civilianFactories = 0,
    this.militaryFactories = 0,
  });

  final BuildingType type;
  final double cost;
  final int days;
  final double industrialDelta;
  final double infrastructureDelta;

  /// Fractional reduction applied to future recruitment cost (0.0 - 0.6).
  final double recruitDiscount;

  /// Fractional defensive bonus granted in battle (0.0 - 0.5).
  final double defenseBonus;

  /// Factories added on completion.
  final int civilianFactories;
  final int militaryFactories;

  String get id => type.name;
}

class ResourceSpec {
  const ResourceSpec({
    required this.type,
    required this.price,
    this.weight = 1.0,
  });

  final ResourceType type;

  /// Credits per unit when traded on the world market.
  final double price;

  /// How much one unit of the resource matters to industry / the army.
  final double weight;

  String get id => type.name;
}

class EquipmentSpec {
  const EquipmentSpec({
    required this.type,
    required this.productionCost,
    required this.days,
    required this.attackBonus,
    required this.defenseBonus,
    required this.readinessBonus,
  });

  final EquipmentType type;

  /// Military production points consumed per unit.
  final double productionCost;

  /// Days per unit at full factory output.
  final int days;

  /// Contribution to national army attack / defence / readiness.
  final double attackBonus;
  final double defenseBonus;
  final double readinessBonus;

  String get id => type.name;
}

class TechSpec {
  const TechSpec({
    required this.id,
    required this.branch,
    required this.tier,
    required this.days,
    required this.cost,
    required this.requires,
    this.industrial = 0,
    this.infrastructure = 0,
    this.incomePct = 0,
    this.attackPct = 0,
    this.defensePct = 0,
    this.factoryOutputPct = 0,
    this.researchPct = 0,
    this.supplyBonus = 0,
  });

  final String id;
  final TechBranch branch;

  /// 1..3 — the tier gate. A tier-N tech needs at least one tier-(N-1) tech of
  /// the same branch researched first.
  final int tier;

  /// Research days at the nation's research speed.
  final int days;

  /// One-off credit cost to begin the programme.
  final double cost;

  final List<String> requires;

  final double industrial;
  final double infrastructure;
  final double incomePct;
  final double attackPct;
  final double defensePct;
  final double factoryOutputPct;
  final double researchPct;
  final double supplyBonus;
}

class Balance {
  Balance._();

  // ------------------------------------------------------------------- units
  static const Map<UnitType, UnitSpec> units = {
    UnitType.infantry: UnitSpec(
      type: UnitType.infantry,
      cost: 1200,
      maintenance: 46,
      attack: 10,
      defense: 12,
      manpower: 0.020,
      equipmentCost: {'smallArms': 3, 'artillery': 1},
    ),
    UnitType.armor: UnitSpec(
      type: UnitType.armor,
      cost: 4800,
      maintenance: 165,
      attack: 34,
      defense: 26,
      manpower: 0.010,
      equipmentCost: {'armor': 3, 'artillery': 1, 'smallArms': 1},
    ),
  };

  // --------------------------------------------------------------- buildings
  static const Map<BuildingType, BuildingSpec> buildings = {
    BuildingType.factory: BuildingSpec(
      type: BuildingType.factory,
      cost: 24000,
      days: 28,
      industrialDelta: 7,
      infrastructureDelta: 0,
      recruitDiscount: 0,
      defenseBonus: 0,
      civilianFactories: 1,
    ),
    BuildingType.infrastructure: BuildingSpec(
      type: BuildingType.infrastructure,
      cost: 18000,
      days: 24,
      industrialDelta: 2,
      infrastructureDelta: 6,
      recruitDiscount: 0,
      defenseBonus: 0,
    ),
    BuildingType.militaryFactory: BuildingSpec(
      type: BuildingType.militaryFactory,
      cost: 32000,
      days: 36,
      industrialDelta: 4,
      infrastructureDelta: 0,
      recruitDiscount: 0.12,
      defenseBonus: 0.02,
      militaryFactories: 1,
    ),
    BuildingType.fortification: BuildingSpec(
      type: BuildingType.fortification,
      cost: 21000,
      days: 30,
      industrialDelta: 0,
      infrastructureDelta: 0,
      recruitDiscount: 0,
      defenseBonus: 0.10,
    ),
  };

  // --------------------------------------------------------------- resources
  static const Map<ResourceType, ResourceSpec> resources = {
    ResourceType.oil: ResourceSpec(
      type: ResourceType.oil,
      price: 3.1,
      weight: 1.25,
    ),
    ResourceType.steel: ResourceSpec(
      type: ResourceType.steel,
      price: 2.4,
      weight: 1.2,
    ),
    ResourceType.aluminium: ResourceSpec(
      type: ResourceType.aluminium,
      price: 2.0,
      weight: 0.9,
    ),
    ResourceType.rubber: ResourceSpec(
      type: ResourceType.rubber,
      price: 1.6,
      weight: 0.7,
    ),
    ResourceType.food: ResourceSpec(
      type: ResourceType.food,
      price: 1.1,
      weight: 1.0,
    ),
    ResourceType.energy: ResourceSpec(
      type: ResourceType.energy,
      price: 1.8,
      weight: 1.15,
    ),
  };

  /// Industry consumes this many units of each resource per point of industrial
  /// capacity per day.
  static const Map<ResourceType, double> industryDemand = {
    ResourceType.oil: 0.014,
    ResourceType.steel: 0.020,
    ResourceType.aluminium: 0.010,
    ResourceType.energy: 0.018,
  };

  /// Population demand, per million citizens per day.
  static const Map<ResourceType, double> civilianDemand = {
    ResourceType.food: 0.020,
    ResourceType.energy: 0.008,
  };

  /// Army demand, per division per day.
  static const Map<ResourceType, double> armyDemand = {
    ResourceType.oil: 0.045,
    ResourceType.rubber: 0.012,
  };

  /// A shortage of this severity (fraction of demand unmet) starts to bite.
  static const double shortageThreshold = 0.05;

  /// Worst-case output penalty from a total resource shortage.
  static const double shortageMaxPenalty = 0.34;

  /// Converts the authored `resourceProduction` figures into units per day.
  static const double resourceDailyScale = 0.08;

  /// Credits per resource unit on the world market = price × this scale.
  static const double marketPriceScale = 10;

  /// Share of a surplus that actually finds a buyer each day.
  static const double exportShare = 0.6;

  /// Imports cost this multiple of the market price before sanctions.
  static const double importMarkup = 1.15;

  /// Monthly credits per point of the smaller partner's industry, per deal.
  static const double tradeDealIncome = 32;

  // --------------------------------------------------------------- industry
  /// Credits produced per month by one civilian factory, before modifiers.
  static const double civilianFactoryOutput = 640;

  /// Military production points per military factory per day.
  static const double militaryFactoryOutput = 6.0;

  /// Consumer-goods fraction of civilian output that never reaches the budget
  /// at low stability (a rising share is diverted to keep the population calm).
  static const double consumerGoodsBase = 0.16;

  // -------------------------------------------------------------- equipment
  static const Map<EquipmentType, EquipmentSpec> equipment = {
    EquipmentType.smallArms: EquipmentSpec(
      type: EquipmentType.smallArms,
      productionCost: 1.0,
      days: 2,
      attackBonus: 0.6,
      defenseBonus: 0.9,
      readinessBonus: 0.9,
    ),
    EquipmentType.artillery: EquipmentSpec(
      type: EquipmentType.artillery,
      productionCost: 2.6,
      days: 4,
      attackBonus: 1.5,
      defenseBonus: 0.6,
      readinessBonus: 0.4,
    ),
    EquipmentType.armor: EquipmentSpec(
      type: EquipmentType.armor,
      productionCost: 5.5,
      days: 7,
      attackBonus: 2.4,
      defenseBonus: 1.4,
      readinessBonus: 0.5,
    ),
    EquipmentType.aircraft: EquipmentSpec(
      type: EquipmentType.aircraft,
      productionCost: 7.0,
      days: 9,
      attackBonus: 2.9,
      defenseBonus: 1.1,
      readinessBonus: 0.7,
    ),
  };

  /// Credits charged per military production point when an order is placed.
  static const double equipmentCreditCost = 120;

  /// Military production points that advance an order at its nominal pace.
  static const double referenceMilitaryPoints = 12;

  /// Batch sizes offered by the production screen.
  static const List<int> productionBatches = [5, 10, 25];

  /// Maximum simultaneous production lines per nation.
  static const int maxProductionLines = 4;

  /// Equipment stock above this contributes nothing further to readiness.
  static const double equipmentSurplusCap = 400;

  // --------------------------------------------------------------- research
  /// Research points produced per day by the base research establishment.
  static const double baseResearchPerDay = 1.0;

  /// Research points per point of industrial capacity per day.
  static const double researchPerIndustrial = 0.010;

  // -------------------------------------------------------------- logistics
  /// A formation fully supplied inside a connected, friendly region.
  static const double supplyRange = 3.0;

  /// Supply fall-off per region of distance from the nearest supply hub.
  static const double supplyFalloffPerStep = 0.16;

  /// Minimum supply a formation can be reduced to.
  static const double minSupply = 0.35;

  /// Combat penalty applied at zero supply.
  static const double supplyCombatPenalty = 0.45;

  /// Monthly upkeep of an occupied region, as a fraction of its value.
  static const double occupationCostFactor = 0.05;

  // ------------------------------------------------------------------ fronts
  /// Front progress gained per battle round, scaled by the power ratio.
  static const double frontAdvancePerRound = 14.0;

  /// How much of the attacker's power edge converts into front momentum.
  static const double frontMomentumWeight = 0.5;

  /// A formation below this readiness falls back instead of holding.
  static const double retreatReadiness = 26.0;

  /// Days a formation spends moving between adjacent regions.
  static const int moveDaysPerRegion = 6;

  // ------------------------------------------------------------------ economy
  /// Base monthly income per point of industrial capacity.
  static const double incomePerIndustrial = 132;

  /// Infrastructure multiplier on income: 1 + infra/100 * 1.35
  static const double infrastructureIncomeWeight = 1.35;

  /// Stability multiplier: 0.55 + stability/100 * 0.6
  static const double stabilityFloor = 0.55;
  static const double stabilityWeight = 0.60;

  /// Base monthly civilian upkeep per million citizens.
  static const double upkeepPerMillion = 3.6;

  /// Stability drifts toward the equilibrium each day.
  static const double stabilityEquilibrium = 62;
  static const double stabilityDrift = 0.020;
  static const double wartimeStabilityDrain = 0.060;

  /// Relations drift toward neutral each day.
  static const double relationsDrift = 0.035;

  /// Battle tuning.
  static const double battleRandomness = 0.18;
  static const double battleSupplyWeight = 0.22;
  static const double battleLooterShare = 0.05;
  static const double battleLossStability = 4.5;
  static const double battleWinStability = 2.4;

  /// Share of an ally's combat score sent to help a defender it is bound to.
  static const double allySupportShare = 0.18;

  /// Diplomacy action costs.
  static const double costImproveRelations = 6000;
  static const double relationsGainImprove = 9;
  static const double costNonAggression = 4000;
  static const double costAlliance = 12000;
  static const double costDefencePact = 8000;
  static const double costTradeDeal = 3000;

  static const double allianceMinRelations = 55;
  static const double pactMinRelations = 15;

  /// Trade & sanctions.
  static const double sanctionRelationsCost = 26;
  static const double sanctionIncomePenalty = 0.14;
  static const double tradeDealMinRelations = 10;
  static const double tradePriceMargin = 0.9;

  // ------------------------------------------------------------------- history
  /// How many samples the economy/power charts keep.
  static const int historyLength = 120;

  /// One history sample every N in-game days.
  static const int historySampleDays = 5;
}

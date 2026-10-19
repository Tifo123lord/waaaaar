import '../core/balance.dart';

/// A player- or AI-controlled nation.
///
/// All economic and military figures are **fictionalized demo values** authored
/// for gameplay balance — they are not presented as real national statistics.
class Country {
  const Country({
    required this.id,
    required this.nameEn,
    required this.nameFa,
    required this.shortEn,
    required this.shortFa,
    required this.capitalEn,
    required this.capitalFa,
    required this.iso,
    required this.flagColors,
    required this.population,
    required this.industrial,
    required this.infrastructure,
    required this.stability,
    required this.treasury,
    required this.resourceIncome,
    required this.militaryBudget,
    required this.personality,
    required this.theatres,
    required this.strengthsEn,
    required this.strengthsFa,
    required this.weaknessesEn,
    required this.weaknessesFa,
    required this.relations,
    required this.buildings,
    this.civilianFactories = 0,
    this.militaryFactories = 0,
    this.resourceProduction = const {},
    this.resources = const {},
    this.equipment = const {},
    this.techs = const [],
    this.researchId,
    this.researchProgress = 0,
    this.armyReadiness = 100,
    this.occupiedRegions = 0,
  });

  final String id;
  final String nameEn;
  final String nameFa;
  final String shortEn;
  final String shortFa;
  final String capitalEn;
  final String capitalFa;
  final String iso;

  /// Three ARGB colours used to render a stylized national flag.
  final List<int> flagColors;

  /// Millions of citizens.
  final double population;

  /// Industrial capacity points.
  final double industrial;

  /// Infrastructure points (0-100).
  final double infrastructure;

  /// Political stability (0-100).
  final double stability;

  /// Treasury in credits.
  final double treasury;

  /// Monthly income from natural resources / trade (fictional).
  final double resourceIncome;

  /// Military funding multiplier (0.6 - 1.5).
  final double militaryBudget;

  final AiPersonality personality;

  /// Country ids in the same reachable theatre.
  final List<String> theatres;

  final String strengthsEn;
  final String strengthsFa;
  final String weaknessesEn;
  final String weaknessesFa;

  /// Diplomatic relation score toward other country ids (-100 .. 100).
  final Map<String, double> relations;

  /// Completed building counts keyed by [BuildingType.name].
  final Map<String, int> buildings;

  // ------------------------------------------------------------- industry

  /// Civilian factories: convert resources into credits and consumer goods.
  final int civilianFactories;

  /// Military factories: convert resources into equipment.
  final int militaryFactories;

  /// Daily resource output per [ResourceType.name] (base, before occupation
  /// penalties).
  final Map<String, double> resourceProduction;

  /// Current strategic stockpile per [ResourceType.name].
  final Map<String, double> resources;

  /// Current equipment stock per [EquipmentType.name].
  final Map<String, int> equipment;

  // -------------------------------------------------------------- research

  /// Researched technology ids.
  final List<String> techs;

  /// Technology currently being researched, or null.
  final String? researchId;

  /// Days of progress toward [researchId].
  final double researchProgress;

  /// Aggregate army readiness (0-100) derived from equipment and supply.
  final double armyReadiness;

  /// Regions this nation holds that belong to someone else.
  final int occupiedRegions;

  double buildingCount(BuildingType type) =>
      (buildings[type.name] ?? 0).toDouble();

  /// Total defensive bonus from fortifications.
  double get fortificationBonus =>
      buildingCount(BuildingType.fortification) *
      Balance.buildings[BuildingType.fortification]!.defenseBonus;

  /// Total recruitment discount from military factories (capped).
  double get recruitmentDiscount {
    final raw =
        buildingCount(BuildingType.militaryFactory) *
        Balance.buildings[BuildingType.militaryFactory]!.recruitDiscount;
    return raw > 0.45 ? 0.45 : raw;
  }

  bool hasTech(String id) => techs.contains(id);

  double equipmentCount(EquipmentType type) =>
      (equipment[type.name] ?? 0).toDouble();

  double resourceStock(ResourceType type) => resources[type.name] ?? 0;

  /// Aggregate combat bonus from every researched technology.
  double get techAttackMultiplier => 1 + _techSum((t) => t.attackPct);
  double get techDefenseMultiplier => 1 + _techSum((t) => t.defensePct);
  double get techIncomeMultiplier => 1 + _techSum((t) => t.incomePct);
  double get techFactoryMultiplier => 1 + _techSum((t) => t.factoryOutputPct);
  double get techResearchMultiplier => 1 + _techSum((t) => t.researchPct);
  double get techSupplyBonus => _techSum((t) => t.supplyBonus);

  double _techSum(double Function(TechSpec) f) {
    var total = 0.0;
    for (final id in techs) {
      final spec = _techById(id);
      if (spec != null) total += f(spec);
    }
    return total;
  }

  static TechSpec? _techById(String id) => kTechIndex[id];

  Country copyWith({
    double? population,
    double? industrial,
    double? infrastructure,
    double? stability,
    double? treasury,
    double? resourceIncome,
    double? militaryBudget,
    List<String>? theatres,
    Map<String, double>? relations,
    Map<String, int>? buildings,
    int? civilianFactories,
    int? militaryFactories,
    Map<String, double>? resourceProduction,
    Map<String, double>? resources,
    Map<String, int>? equipment,
    List<String>? techs,
    String? researchId,
    bool clearResearch = false,
    double? researchProgress,
    double? armyReadiness,
    int? occupiedRegions,
  }) {
    return Country(
      id: id,
      nameEn: nameEn,
      nameFa: nameFa,
      shortEn: shortEn,
      shortFa: shortFa,
      capitalEn: capitalEn,
      capitalFa: capitalFa,
      iso: iso,
      flagColors: flagColors,
      population: population ?? this.population,
      industrial: industrial ?? this.industrial,
      infrastructure: infrastructure ?? this.infrastructure,
      stability: stability ?? this.stability,
      treasury: treasury ?? this.treasury,
      resourceIncome: resourceIncome ?? this.resourceIncome,
      militaryBudget: militaryBudget ?? this.militaryBudget,
      personality: personality,
      theatres: theatres ?? this.theatres,
      strengthsEn: strengthsEn,
      strengthsFa: strengthsFa,
      weaknessesEn: weaknessesEn,
      weaknessesFa: weaknessesFa,
      relations: relations ?? this.relations,
      buildings: buildings ?? this.buildings,
      civilianFactories: civilianFactories ?? this.civilianFactories,
      militaryFactories: militaryFactories ?? this.militaryFactories,
      resourceProduction: resourceProduction ?? this.resourceProduction,
      resources: resources ?? this.resources,
      equipment: equipment ?? this.equipment,
      techs: techs ?? this.techs,
      researchId: clearResearch ? null : (researchId ?? this.researchId),
      researchProgress: clearResearch
          ? 0
          : (researchProgress ?? this.researchProgress),
      armyReadiness: armyReadiness ?? this.armyReadiness,
      occupiedRegions: occupiedRegions ?? this.occupiedRegions,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'population': population,
    'industrial': industrial,
    'infrastructure': infrastructure,
    'stability': stability,
    'treasury': treasury,
    'resourceIncome': resourceIncome,
    'militaryBudget': militaryBudget,
    'relations': relations,
    'buildings': buildings,
    'civilianFactories': civilianFactories,
    'militaryFactories': militaryFactories,
    'resources': resources,
    'equipment': equipment,
    'techs': techs,
    'researchId': researchId,
    'researchProgress': researchProgress,
    'armyReadiness': armyReadiness,
    'occupiedRegions': occupiedRegions,
  };

  /// Builds a mutable snapshot from persisted values, keeping static
  /// metadata (names, geometry, flag) from the authored dataset.
  static Country fromJson(Map<String, dynamic> json, Country template) {
    return template.copyWith(
      population: _d(json['population'], template.population),
      industrial: _d(json['industrial'], template.industrial),
      infrastructure: _d(json['infrastructure'], template.infrastructure),
      stability: _d(json['stability'], template.stability),
      treasury: _d(json['treasury'], template.treasury),
      resourceIncome: _d(json['resourceIncome'], template.resourceIncome),
      militaryBudget: _d(json['militaryBudget'], template.militaryBudget),
      civilianFactories: _i(
        json['civilianFactories'],
        template.civilianFactories,
      ),
      militaryFactories: _i(
        json['militaryFactories'],
        template.militaryFactories,
      ),
      armyReadiness: _d(json['armyReadiness'], template.armyReadiness),
      occupiedRegions: _i(json['occupiedRegions'], template.occupiedRegions),
      researchProgress: _d(json['researchProgress'], 0),
      researchId: json['researchId']?.toString(),
      relations: json['relations'] == null
          ? template.relations
          : Map<String, double>.from(
              (json['relations'] as Map).map(
                (k, v) => MapEntry(k as String, _d(v, 0)),
              ),
            ),
      buildings: json['buildings'] == null
          ? template.buildings
          : Map<String, int>.from(
              (json['buildings'] as Map).map(
                (k, v) => MapEntry(k as String, (v as num).toInt()),
              ),
            ),
      resources: json['resources'] == null
          ? template.resources
          : Map<String, double>.from(
              (json['resources'] as Map).map(
                (k, v) => MapEntry(k as String, _d(v, 0)),
              ),
            ),
      equipment: json['equipment'] == null
          ? template.equipment
          : Map<String, int>.from(
              (json['equipment'] as Map).map(
                (k, v) => MapEntry(k as String, (v as num).toInt()),
              ),
            ),
      techs: json['techs'] == null
          ? template.techs
          : (json['techs'] as List).map((e) => e.toString()).toList(),
    );
  }

  static double _d(Object? v, double fallback) =>
      v is num ? v.toDouble() : fallback;

  static int _i(Object? v, int fallback) => v is num ? v.toInt() : fallback;
}

/// Flat technology index, populated once so [Country] can resolve specs
/// without importing the tree (which would create a cycle).
final Map<String, TechSpec> kTechIndex = {};

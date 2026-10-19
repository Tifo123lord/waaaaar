import '../core/balance.dart';
import '../core/constants.dart';
import '../core/game_clock.dart';
import '../data/world_geometry.dart';
import 'battle.dart';
import 'country.dart';
import 'diplomatic_agreement.dart';
import 'history.dart';
import 'military_unit.dart';
import 'production.dart';
import 'region.dart';
import 'world_politics.dart';

enum GameSpeed { paused, normal, fast }

/// The single source of truth for a campaign.
///
/// Every screen reads from this object — no screen keeps private copies of
/// gameplay numbers.
class GameState {
  GameState({
    required this.countries,
    required this.playerId,
    required this.day,
    required this.units,
    required this.agreements,
    required this.wars,
    required this.battles,
    required this.construction,
    required this.events,
    Map<String, RegionState>? regions,
    Map<String, String>? control,
    this.production = const {},
    HistorySeries? history,
    this.politics = const WorldPolitics(),
    this.speed = GameSpeed.normal,
    this.revision = 0,
    this.lastBattleReport,
    double? playerBudgetOverride,
  }) : _playerBudgetOverride = playerBudgetOverride,
       regions = regions ?? _seedRegions(control),
       history = history ?? HistorySeries();

  /// Builds the initial region table from a legacy `regionId -> controllerId`
  /// map (or from the authored world when none is supplied).
  static Map<String, RegionState> _seedRegions(Map<String, String>? control) {
    final out = <String, RegionState>{};
    for (final r in kWorldRegions) {
      out[r.id] = RegionState(
        id: r.id,
        ownerId: r.countryId,
        controllerId: control?[r.id] ?? r.countryId,
      );
    }
    return out;
  }

  /// Country snapshots, keyed by country id for fast lookup.
  final Map<String, Country> countries;

  final String playerId;
  final int day;

  /// Only **living** formations are kept here; destroyed ones are removed.
  final List<MilitaryUnit> units;

  final List<DiplomaticAgreement> agreements;
  final List<War> wars;
  final List<ActiveBattle> battles;

  /// countryId -> in-progress construction orders.
  final Map<String, List<ConstructionOrder>> construction;

  /// countryId -> in-progress equipment production orders.
  final Map<String, List<ProductionOrder>> production;

  final EventLog events;

  /// Every capturable region in the world, keyed by region id.
  final Map<String, RegionState> regions;

  /// Rolling economy / power samples for the charts.
  final HistorySeries history;

  /// Blocs, sanctions, peace talks, AI agendas and global tension.
  final WorldPolitics politics;

  final GameSpeed speed;

  /// Bumped on every mutation so Riverpod consumers rebuild reliably.
  final int revision;

  final BattleResult? lastBattleReport;

  /// Player-only budget override; `null` means "use the doctrine default".
  final double? _playerBudgetOverride;

  double? get playerBudgetOverride => _playerBudgetOverride;

  // ---------------------------------------------------------------- derived

  Country get player => countries[playerId]!;

  GameDate get date => GameDate(day);

  bool get isAtWar => wars.any((w) => w.involves(playerId));

  List<War> get playerWars =>
      wars.where((w) => w.involves(playerId)).toList(growable: false);

  ActiveBattle? get playerBattle {
    for (final b in battles) {
      if (b.involves(playerId)) return b;
    }
    return null;
  }

  /// Compatibility view over [regions]: regionId -> controller country id.
  Map<String, String> get control => {
    for (final e in regions.entries) e.key: e.value.controllerId,
  };

  RegionState? region(String id) => regions[id];

  List<RegionState> regionsOf(String countryId) => regions.values
      .where((r) => r.controllerId == countryId)
      .toList(growable: false);

  /// Regions a nation legally owns.
  List<RegionState> ownedRegionsOf(String countryId) => regions.values
      .where((r) => r.ownerId == countryId)
      .toList(growable: false);

  /// Regions a nation holds that belong to someone else.
  List<RegionState> occupiedBy(String countryId) => regions.values
      .where((r) => r.controllerId == countryId && r.ownerId != countryId)
      .toList(growable: false);

  /// The capital region of a nation, if it still exists.
  String? capitalRegionOf(String countryId) =>
      WorldRegions.capitalOf(countryId);

  List<MilitaryUnit> unitsOf(String countryId) =>
      units.where((u) => u.ownerId == countryId).toList(growable: false);

  List<MilitaryUnit> unitsIn(String regionId) =>
      units.where((u) => u.homeRegion == regionId).toList(growable: false);

  List<ProductionOrder> productionOf(String countryId) =>
      production[countryId] ?? const [];

  ArmySummary armyOf(String countryId) {
    var infantry = 0;
    var armor = 0;
    var attack = 0.0;
    var defense = 0.0;
    var power = 0.0;
    var maxPower = 0.0;
    var manpower = 0.0;
    var maintenance = 0.0;
    var readiness = 0.0;
    final country = countries[countryId];
    if (country == null) {
      return const ArmySummary(
        infantryUnits: 0,
        armorUnits: 0,
        totalAttack: 0,
        totalDefense: 0,
        totalPower: 0,
        maxPower: 0,
        manpower: 0,
        monthlyMaintenance: 0,
        readiness: 0,
        supply: 0,
      );
    }
    final budget = budgetOf(countryId);
    final techAtk = country.techAttackMultiplier;
    final techDef = country.techDefenseMultiplier;
    for (final u in units) {
      if (u.ownerId != countryId) continue;
      if (u.type == UnitType.infantry) {
        infantry++;
      } else {
        armor++;
      }
      final condition = u.power / u.maxPower;
      attack += u.spec.attack * condition * techAtk;
      defense += u.spec.defense * condition * techDef;
      power += u.power;
      maxPower += u.maxPower;
      manpower += u.spec.manpower;
      maintenance += u.maintenanceAt(budget);
      readiness += u.supply;
    }
    final supply = units.isEmpty
        ? 1.0
        : readiness / units.where((u) => u.ownerId == countryId).length;
    return ArmySummary(
      infantryUnits: infantry,
      armorUnits: armor,
      totalAttack: attack,
      totalDefense: defense,
      totalPower: power,
      maxPower: maxPower,
      manpower: manpower,
      monthlyMaintenance: maintenance,
      readiness: country.armyReadiness,
      supply: supply * 100,
    );
  }

  List<DiplomaticAgreement> agreementsOf(
    String countryId,
    AgreementType type,
  ) => agreements
      .where((a) => a.type == type && a.involves(countryId))
      .toList(growable: false);

  bool hasAgreement(String a, String b, AgreementType type) => agreements.any(
    (ag) => ag.type == type && ag.involves(a) && ag.involves(b),
  );

  bool atWarWith(String a, String b) =>
      wars.any((w) => w.involves(a) && w.involves(b));

  War? warBetween(String a, String b) {
    for (final w in wars) {
      if (w.involves(a) && w.involves(b)) return w;
    }
    return null;
  }

  /// Bilateral allies plus every fellow member of the nation's bloc.
  List<String> alliesOf(String countryId) {
    final out = <String>{};
    for (final a in agreements) {
      if (a.type == AgreementType.alliance && a.involves(countryId)) {
        out.add(a.other(countryId));
      }
    }
    final bloc = politics.blocOf(countryId);
    if (bloc != null) {
      for (final m in bloc.members) {
        if (m != countryId) out.add(m);
      }
    }
    return out.toList(growable: false);
  }

  /// Nations bound to defend [countryId] if it is attacked: bilateral
  /// alliances, defence pacts and defensive-bloc partners.
  List<String> defendersOf(String countryId) {
    final out = <String>{...alliesOf(countryId)};
    for (final a in agreements) {
      if (a.type == AgreementType.defencePact && a.involves(countryId)) {
        out.add(a.other(countryId));
      }
    }
    final bloc = politics.blocOf(countryId);
    if (bloc != null && !bloc.isDefensive) {
      // Economic communities and spheres do not carry a defence obligation.
      for (final m in bloc.members) {
        if (m != countryId &&
            !hasAgreement(countryId, m, AgreementType.alliance) &&
            !hasAgreement(countryId, m, AgreementType.defencePact)) {
          out.remove(m);
        }
      }
    }
    return out.toList(growable: false);
  }

  /// Whether two nations are bound not to fight each other.
  bool nonAggressionBetween(String a, String b) =>
      hasAgreement(a, b, AgreementType.nonAggression) ||
      hasAgreement(a, b, AgreementType.defencePact) ||
      hasAgreement(a, b, AgreementType.alliance) ||
      politics.sameBloc(a, b);

  /// Combined severity of every sanction currently applied to [countryId],
  /// weighted by the imposer's industrial size relative to the target.
  double sanctionPressureOn(String countryId) {
    final target = countries[countryId];
    if (target == null) return 0;
    var total = 0.0;
    for (final s in politics.sanctionsOn(countryId)) {
      final imposer = countries[s.imposerId];
      if (imposer == null) continue;
      final weight = (imposer.industrial / (target.industrial + 1)).clamp(
        0.25,
        2.5,
      );
      total += s.severity * weight;
    }
    return total.clamp(0.0, 0.45);
  }

  /// Country ids this nation has a trade deal with.
  List<String> tradePartnersOf(String countryId) => agreements
      .where((a) => a.type == AgreementType.trade && a.involves(countryId))
      .map((a) => a.other(countryId))
      .toList(growable: false);

  /// Country ids under this nation's sanctions.
  List<String> sanctionedBy(String countryId) => agreements
      .where((a) => a.type == AgreementType.sanction && a.involves(countryId))
      .map((a) => a.other(countryId))
      .toList(growable: false);

  /// Region ids currently held by [countryId] (home region plus conquests).
  int territoryCountOf(String countryId) =>
      regions.values.where((r) => r.controllerId == countryId).length;

  List<ConstructionOrder> constructionOf(String countryId) =>
      construction[countryId] ?? const [];

  /// Military funding multiplier for a nation.
  ///
  /// The player sets this explicitly; every other nation derives it from its
  /// authored doctrine, so no duplicate copy of the value is ever stored.
  double budgetOf(String countryId) => countryId == playerId
      ? _playerBudgetOverride ?? countries[countryId]!.militaryBudget
      : countries[countryId]!.militaryBudget;

  /// Creates a new state object sharing the same underlying data with a new
  /// revision number — cheap and reliable for Riverpod change detection.
  GameState touch([BattleResult? report]) => rebuilt(lastBattleReport: report);

  GameState copyWithSpeed(GameSpeed newSpeed) => rebuilt(speed: newSpeed);

  GameState copyWithBudgetOverride(double? override) => GameState(
    countries: countries,
    playerId: playerId,
    day: day,
    units: units,
    agreements: agreements,
    wars: wars,
    battles: battles,
    construction: construction,
    production: production,
    events: events,
    regions: regions,
    history: history,
    politics: politics,
    speed: speed,
    revision: revision + 1,
    lastBattleReport: lastBattleReport,
    playerBudgetOverride: override,
  );

  /// A state rebuilt from freshly mutated collections (used by the workspace
  /// and by load). Keeps the revision chain monotonic.
  GameState rebuilt({
    Map<String, Country>? countries,
    int? day,
    List<MilitaryUnit>? units,
    List<DiplomaticAgreement>? agreements,
    List<War>? wars,
    List<ActiveBattle>? battles,
    Map<String, List<ConstructionOrder>>? construction,
    Map<String, List<ProductionOrder>>? production,
    EventLog? events,
    Map<String, RegionState>? regions,
    HistorySeries? history,
    WorldPolitics? politics,
    GameSpeed? speed,
    BattleResult? lastBattleReport,
    double? playerBudgetOverride,
    bool clearBattleReport = false,
  }) => GameState(
    countries: countries ?? this.countries,
    playerId: playerId,
    day: day ?? this.day,
    units: units ?? this.units,
    agreements: agreements ?? this.agreements,
    wars: wars ?? this.wars,
    battles: battles ?? this.battles,
    construction: construction ?? this.construction,
    production: production ?? this.production,
    events: events ?? this.events,
    regions: regions ?? this.regions,
    history: history ?? this.history,
    politics: politics ?? this.politics,
    speed: speed ?? this.speed,
    revision: revision + 1,
    lastBattleReport: clearBattleReport
        ? null
        : (lastBattleReport ?? this.lastBattleReport),
    playerBudgetOverride: playerBudgetOverride ?? _playerBudgetOverride,
  );

  // ------------------------------------------------------------- persistence

  Map<String, dynamic> toJson() => {
    'version': GameConstants.saveFormatVersion,
    'playerId': playerId,
    'day': day,
    'speed': speed.name,
    'playerBudgetOverride': _playerBudgetOverride,
    'countries': countries.values.map((c) => c.toJson()).toList(),
    'units': units.map((u) => u.toJson()).toList(),
    'agreements': agreements.map((a) => a.toJson()).toList(),
    'wars': wars.map((w) => w.toJson()).toList(),
    'battles': battles.map((b) => b.toJson()).toList(),
    'construction': construction.map(
      (k, v) => MapEntry(k, v.map((o) => o.toJson()).toList()),
    ),
    'production': production.map(
      (k, v) => MapEntry(k, v.map((o) => o.toJson()).toList()),
    ),
    'events': events.toJson(),
    'regions': regions.map((k, v) => MapEntry(k, v.toJson())),
    'history': history.toJson(),
    'politics': politics.toJson(),
  };
}

import '../core/game_clock.dart';
import '../models/battle.dart';
import '../models/country.dart';
import '../models/diplomatic_agreement.dart';
import '../models/game_state.dart';
import '../models/history.dart';
import '../models/military_unit.dart';
import '../models/production.dart';
import '../models/region.dart';
import '../models/world_politics.dart';

/// A mutable working set used while a simulation tick is being computed.
///
/// The engines themselves are pure functions over [GameState]; this class only
/// holds the intermediate collections so a tick can be applied in a single pass
/// and then republished as one immutable snapshot (a single state revision, one
/// rebuild for the whole app).
class SimulationWorkspace {
  SimulationWorkspace({required GameState source})
    : _source = source,
      day = source.day,
      countries = Map<String, Country>.from(source.countries),
      units = List<MilitaryUnit>.from(source.units),
      construction = {
        for (final e in source.construction.entries)
          e.key: List<ConstructionOrder>.from(e.value),
      },
      agreements = List<DiplomaticAgreement>.from(source.agreements),
      wars = List<War>.from(source.wars),
      battles = List<ActiveBattle>.from(source.battles),
      regions = Map<String, RegionState>.from(source.regions),
      production = {
        for (final e in source.production.entries)
          e.key: List<ProductionOrder>.from(e.value),
      },
      politics = source.politics,
      history = source.history,
      events = source.events;

  final GameState _source;

  int day;
  final Map<String, Country> countries;
  List<MilitaryUnit> units;
  final Map<String, List<ConstructionOrder>> construction;
  final List<DiplomaticAgreement> agreements;
  final List<War> wars;
  final List<ActiveBattle> battles;
  final Map<String, RegionState> regions;
  final Map<String, List<ProductionOrder>> production;
  final EventLog events;

  /// Compatibility view: regionId -> controller.
  Map<String, String> get control => {
    for (final e in regions.entries) e.key: e.value.controllerId,
  };

  /// Rolling chart samples. Shared (mutable) series carried across ticks.
  final HistorySeries history;

  /// Living-world politics. Immutable value; replace via [setPolitics].
  WorldPolitics politics;

  String get playerId => _source.playerId;

  /// A read-only [GameState] view of the current working set.
  ///
  /// Rebuilt lazily and invalidated whenever a collection changes, so engines
  /// can freely query the partially-updated tick.
  GameState get state {
    final cached = _cache;
    if (cached != null && cached.day == day && identical(cached.units, units)) {
      return cached;
    }
    final snapshot = GameState(
      countries: countries,
      playerId: _source.playerId,
      day: day,
      units: units,
      agreements: agreements,
      wars: wars,
      battles: battles,
      construction: construction,
      events: events,
      regions: regions,
      politics: politics,
      history: history,
      production: production,
      speed: _source.speed,
      revision: _source.revision,
      lastBattleReport: _source.lastBattleReport,
      playerBudgetOverride: _source.playerBudgetOverride,
    );
    _cache = snapshot;
    return snapshot;
  }

  GameState? _cache;

  void dirty() => _cache = null;

  Country? country(String id) => countries[id];

  void putCountry(Country c) {
    countries[c.id] = c;
    dirty();
  }

  void addUnit(MilitaryUnit u) {
    units = [...units, u];
    dirty();
  }

  void setUnits(List<MilitaryUnit> next) {
    units = next;
    dirty();
  }

  void putConstruction(String countryId, List<ConstructionOrder> orders) {
    construction[countryId] = orders;
    dirty();
  }

  void addAgreement(DiplomaticAgreement a) {
    agreements.add(a);
    dirty();
  }

  void removeAgreement(String id) {
    agreements.removeWhere((a) => a.id == id);
    dirty();
  }

  void addWar(War w) {
    wars.add(w);
    dirty();
  }

  void removeWar(String id) {
    wars.removeWhere((w) => w.id == id);
    dirty();
  }

  void addBattle(ActiveBattle b) {
    battles.add(b);
    dirty();
  }

  void replaceBattle(int index, ActiveBattle b) {
    battles[index] = b;
    dirty();
  }

  void removeBattleAt(int index) {
    battles.removeAt(index);
    dirty();
  }

  /// Hands control of one region to [controllerId].
  void setControl(String regionId, String controllerId) {
    final r = regions[regionId];
    if (r == null) return;
    regions[regionId] = r.copyWith(controllerId: controllerId, frontProgress: 0);
    dirty();
  }

  void putRegion(RegionState r) {
    regions[r.id] = r;
    dirty();
  }

  void putProduction(String countryId, List<ProductionOrder> orders) {
    production[countryId] = orders;
    dirty();
  }

  void setPolitics(WorldPolitics next) {
    politics = next;
    dirty();
  }

  /// Convenience: apply a transform to the politics value.
  void updatePolitics(WorldPolitics Function(WorldPolitics) f) =>
      setPolitics(f(politics));

  /// Number of non-player nations that own at least one formation.
  Iterable<String> get foreignIds =>
      countries.keys.where((id) => id != playerId);

  /// Builds the final immutable state after a tick.
  GameState publish({GameSpeed? speed, BattleResult? report}) {
    return GameState(
      countries: countries,
      playerId: _source.playerId,
      day: day,
      units: units,
      agreements: agreements,
      wars: wars,
      battles: battles,
      construction: construction,
      events: events,
      regions: regions,
      politics: politics,
      history: history,
      production: production,
      speed: speed ?? _source.speed,
      revision: _source.revision + 1,
      lastBattleReport: report ?? _source.lastBattleReport,
      playerBudgetOverride: _source.playerBudgetOverride,
    );
  }
}

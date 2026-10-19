import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../data/country_data.dart';
import '../data/world_geometry.dart';
import '../core/game_clock.dart';
import '../models/battle.dart';
import '../models/country.dart';
import '../models/diplomatic_agreement.dart';
import '../models/game_event.dart';
import '../models/game_state.dart';
import '../models/military_unit.dart';
import '../models/history.dart';
import '../models/world_politics.dart';
import '../models/production.dart';
import '../models/region.dart';

/// Metadata shown on the main menu without loading the whole save.
class SaveSummary {
  const SaveSummary({
    required this.playerId,
    required this.playerName,
    required this.day,
    required this.treasury,
    required this.armyPower,
    required this.units,
    required this.savedAtIso,
    required this.gameVersion,
  });

  final String playerId;
  final String playerName;
  final int day;
  final double treasury;
  final double armyPower;
  final int units;
  final String savedAtIso;
  final String gameVersion;

  GameDate get date => GameDate(day);

  DateTime? get savedAt => DateTime.tryParse(savedAtIso);
}

/// Why a load attempt failed.
enum LoadFailure { none, missing, malformed, unsupportedVersion, invalidData }

class LoadResult {
  const LoadResult.loaded(this.state)
    : failure = LoadFailure.none,
      summary = null;

  const LoadResult.error(this.failure) : state = null, summary = null;

  const LoadResult.summaryOnly(this.summary)
    : failure = LoadFailure.none,
      state = null;

  final LoadFailure failure;
  final GameState? state;
  final SaveSummary? summary;

  bool get ok => failure == LoadFailure.none && state != null;
}

/// Versioned local persistence.
///
/// The payload is a single JSON document stored in `SharedPreferences`:
///   { "format": 1, "savedAt": "...", "summary": {...}, "state": {...} }
///
/// Every field is validated on read and unknown/missing values fall back to the
/// authored dataset, so a partially corrupted save can never crash the app.
class SaveRepository {
  SaveRepository({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ------------------------------------------------------------------ summary

  /// Reads only the header of the save (cheap; used by the main menu).
  Future<SaveSummary?> readSummary() async {
    final prefs = await _store;
    final raw = prefs.getString(GameConstants.saveSlotKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final summary = decoded['summary'];
      if (summary is Map) {
        return SaveSummary(
          playerId: summary['playerId']?.toString() ?? 'us',
          playerName: summary['playerName']?.toString() ?? '—',
          day: (summary['day'] as num?)?.toInt() ?? 0,
          treasury: (summary['treasury'] as num?)?.toDouble() ?? 0,
          armyPower: (summary['armyPower'] as num?)?.toDouble() ?? 0,
          units: (summary['units'] as num?)?.toInt() ?? 0,
          savedAtIso: decoded['savedAt']?.toString() ?? '',
          gameVersion: decoded['gameVersion']?.toString() ?? '—',
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasSave() async => (await readSummary()) != null;

  // --------------------------------------------------------------------- save

  Future<bool> save(GameState state) async {
    try {
      final prefs = await _store;
      final army = state.armyOf(state.playerId);
      final payload = {
        'format': GameConstants.saveFormatVersion,
        'gameVersion': GameConstants.version,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'summary': {
          'playerId': state.playerId,
          'playerName': state.player.nameEn,
          'day': state.day,
          'treasury': state.player.treasury,
          'armyPower': army.totalPower,
          'units': army.totalUnits.toInt(),
        },
        'state': state.toJson(),
      };
      return await prefs.setString(
        GameConstants.saveSlotKey,
        jsonEncode(payload),
      );
    } catch (_) {
      return false;
    }
  }

  // --------------------------------------------------------------------- load

  /// Loads the campaign, validating every value.
  Future<LoadResult> load() async {
    final prefs = await _store;
    final raw = prefs.getString(GameConstants.saveSlotKey);
    if (raw == null || raw.isEmpty) {
      return const LoadResult.error(LoadFailure.missing);
    }

    final Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const LoadResult.error(LoadFailure.malformed);
      }
      payload = decoded;
    } catch (_) {
      return const LoadResult.error(LoadFailure.malformed);
    }

    final format = (payload['format'] as num?)?.toInt();
    if (format == null || format > GameConstants.saveFormatVersion) {
      return const LoadResult.error(LoadFailure.unsupportedVersion);
    }

    final rawState = payload['state'];
    if (rawState is! Map<String, dynamic>) {
      return const LoadResult.error(LoadFailure.malformed);
    }

    try {
      final state = _decodeState(rawState);
      if (state == null) {
        return const LoadResult.error(LoadFailure.invalidData);
      }
      return LoadResult.loaded(state);
    } catch (_) {
      return const LoadResult.error(LoadFailure.invalidData);
    }
  }

  GameState? _decodeState(Map<String, dynamic> json) {
    final templates = {for (final c in CountryData.build()) c.id: c};

    final playerId = json['playerId']?.toString();
    if (playerId == null || !templates.containsKey(playerId)) return null;

    final day = (json['day'] as num?)?.toInt();
    if (day == null || day < 0 || day > 2000000) return null;

    // --- countries --------------------------------------------------------
    final rawCountries = json['countries'];
    if (rawCountries is! List) return null;
    final countries = <String, Country>{};
    for (final entry in rawCountries) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final id = map['id']?.toString();
      final template = id == null ? null : templates[id];
      if (template == null) continue;
      final restored = Country.fromJson(map, template);
      // Sanity rails: a malformed save must not produce nonsensical numbers.
      if (restored.population <= 0 ||
          restored.population > 5000 ||
          restored.industrial <= 0 ||
          restored.treasury.isNaN) {
        return null;
      }
      countries[id!] = restored;
    }
    if (!countries.containsKey(playerId) || countries.length < 2) {
      return null;
    }
    // Fill in any nation that is missing from the save with its template.
    for (final t in templates.values) {
      countries.putIfAbsent(t.id, () => t);
    }

    // --- events -----------------------------------------------------------
    final eventLog = EventLog([]);
    final rawEvents = json['events'];
    if (rawEvents is List) {
      for (final e in rawEvents) {
        if (e is! Map) continue;
        try {
          final event = GameEvent.fromJson(Map<String, dynamic>.from(e));
          eventLog.add(
            kind: event.kind,
            day: event.day,
            titleKey: event.titleKey,
            bodyKey: event.bodyKey,
            params: event.params,
            countryId: event.countryId,
            amount: event.amount,
            severity: event.severity,
          );
        } catch (_) {
          // Skip an unreadable entry rather than failing the whole load.
        }
      }
    }

    // --- units ------------------------------------------------------------
    final units = <MilitaryUnit>[];
    final rawUnits = json['units'];
    if (rawUnits is List) {
      for (final u in rawUnits) {
        if (u is! Map) continue;
        try {
          final unit = MilitaryUnit.fromJson(Map<String, dynamic>.from(u));
          if (!countries.containsKey(unit.ownerId)) continue;
          if (unit.power <= 0 || unit.maxPower <= 0) continue;
          units.add(unit);
        } catch (_) {
          // Skip damaged entries.
        }
      }
    }

    // --- agreements -------------------------------------------------------
    final agreements = <DiplomaticAgreement>[];
    final rawAgreements = json['agreements'];
    if (rawAgreements is List) {
      for (final a in rawAgreements) {
        if (a is! Map) continue;
        try {
          final agreement = DiplomaticAgreement.fromJson(
            Map<String, dynamic>.from(a),
          );
          if (!countries.containsKey(agreement.a) ||
              !countries.containsKey(agreement.b)) {
            continue;
          }
          agreements.add(agreement);
        } catch (_) {
          // Skip damaged entries.
        }
      }
    }

    // --- wars & battles ---------------------------------------------------
    final wars = <War>[];
    final rawWars = json['wars'];
    if (rawWars is List) {
      for (final w in rawWars) {
        if (w is! Map) continue;
        try {
          final war = War.fromJson(Map<String, dynamic>.from(w));
          if (!countries.containsKey(war.aggressor) ||
              !countries.containsKey(war.defender)) {
            continue;
          }
          wars.add(war);
        } catch (_) {
          // Skip damaged entries.
        }
      }
    }

    final battles = <ActiveBattle>[];
    final rawBattles = json['battles'];
    if (rawBattles is List) {
      for (final b in rawBattles) {
        if (b is! Map) continue;
        try {
          final battle = ActiveBattle.fromJson(Map<String, dynamic>.from(b));
          if (!countries.containsKey(battle.attackerId) ||
              !countries.containsKey(battle.defenderId)) {
            continue;
          }
          battles.add(battle);
        } catch (_) {
          // Skip damaged entries.
        }
      }
    }

    // --- construction -----------------------------------------------------
    final construction = <String, List<ConstructionOrder>>{
      for (final id in countries.keys) id: <ConstructionOrder>[],
    };
    final rawConstruction = json['construction'];
    if (rawConstruction is Map) {
      rawConstruction.forEach((key, value) {
        final id = key.toString();
        if (!countries.containsKey(id) || value is! List) return;
        final orders = <ConstructionOrder>[];
        for (final o in value) {
          if (o is! Map) continue;
          try {
            orders.add(
              ConstructionOrder.fromJson(Map<String, dynamic>.from(o)),
            );
          } catch (_) {
            // Skip damaged entries.
          }
        }
        construction[id] = orders;
      });
    }

    // --- regions ----------------------------------------------------------
    // Current format: full region table. Legacy saves only carried a
    // `control` map keyed by country id, which is migrated onto capitals.
    final regions = <String, RegionState>{
      for (final r in kWorldRegions)
        r.id: RegionState(
          id: r.id,
          ownerId: r.countryId,
          controllerId: r.countryId,
        ),
    };
    final rawRegions = json['regions'];
    if (rawRegions is Map) {
      rawRegions.forEach((key, value) {
        final id = key.toString();
        final base = regions[id];
        if (base == null || value is! Map) return;
        try {
          final r = RegionState.fromJson(
            id,
            Map<String, dynamic>.from(value),
            base.ownerId,
          );
          if (!countries.containsKey(r.controllerId)) return;
          // The legal owner is static map data; never trust the save for it.
          regions[id] = r.copyWith(ownerId: base.ownerId);
        } catch (_) {
          // Skip damaged entries.
        }
      });
    } else {
      final rawControl = json['control'];
      if (rawControl is Map) {
        rawControl.forEach((key, value) {
          final owner = value.toString();
          if (!countries.containsKey(owner)) return;
          final region = key.toString();
          final target = regions.containsKey(region)
              ? region
              : WorldRegions.capitalOf(region);
          if (target != null && regions.containsKey(target)) {
            regions[target] = regions[target]!.copyWith(controllerId: owner);
          }
        });
      }
    }

    // --- production -------------------------------------------------------
    final production = <String, List<ProductionOrder>>{};
    final rawProduction = json['production'];
    if (rawProduction is Map) {
      rawProduction.forEach((key, value) {
        final id = key.toString();
        if (!countries.containsKey(id) || value is! List) return;
        final orders = <ProductionOrder>[];
        for (final o in value) {
          if (o is! Map) continue;
          try {
            final order = ProductionOrder.fromJson(
              Map<String, dynamic>.from(o),
            );
            if (order.quantity > 0 && order.daysTotal > 0) orders.add(order);
          } catch (_) {
            // Skip damaged entries.
          }
        }
        if (orders.isNotEmpty) production[id] = orders;
      });
    }

    final speedName = json['speed']?.toString();
    final speed = GameSpeed.values.firstWhere(
      (s) => s.name == speedName,
      orElse: () => GameSpeed.paused,
    );

    final budgetOverride = (json['playerBudgetOverride'] as num?)?.toDouble();

    // --- living-world politics ------------------------------------------
    final rawPolitics = json['politics'];
    final politics = WorldPolitics.fromJson(
      rawPolitics is Map ? Map<String, dynamic>.from(rawPolitics) : null,
      knownCountry: countries.containsKey,
    );

    // --- chart history -----------------------------------------------------
    final rawHistory = json['history'];
    HistorySeries? history;
    if (rawHistory is Map) {
      try {
        history = HistorySeries.fromJson(Map<String, dynamic>.from(rawHistory));
      } catch (_) {
        history = null;
      }
    }

    return GameState(
      countries: countries,
      playerId: playerId,
      day: day,
      units: units,
      agreements: agreements,
      wars: wars,
      battles: battles,
      construction: construction,
      events: eventLog,
      regions: regions,
      production: production,
      politics: politics,
      history: history,
      speed: speed,
      revision: 1,
      playerBudgetOverride: budgetOverride?.clamp(0.6, 1.5).toDouble(),
    );
  }

  // ------------------------------------------------------------------- delete

  Future<bool> delete() async {
    final prefs = await _store;
    return prefs.remove(GameConstants.saveSlotKey);
  }
}

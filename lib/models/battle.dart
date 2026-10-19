import '../core/balance.dart';

/// A single in-progress construction order.
class ConstructionOrder {
  const ConstructionOrder({
    required this.type,
    required this.startedDay,
    required this.durationDays,
    required this.invested,
    required this.progressDays,
  });

  final BuildingType type;
  final int startedDay;
  final int durationDays;
  final double invested;
  final double progressDays;

  double get fraction =>
      durationDays <= 0 ? 1 : (progressDays / durationDays).clamp(0.0, 1.0);

  int get daysRemaining =>
      (durationDays - progressDays).ceil().clamp(0, durationDays);

  ConstructionOrder advance(double days) => ConstructionOrder(
    type: type,
    startedDay: startedDay,
    durationDays: durationDays,
    invested: invested,
    progressDays: progressDays + days,
  );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'startedDay': startedDay,
    'durationDays': durationDays,
    'invested': invested,
    'progressDays': progressDays,
  };

  static ConstructionOrder fromJson(Map<String, dynamic> json) {
    final type = BuildingType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => BuildingType.factory,
    );
    return ConstructionOrder(
      type: type,
      startedDay: (json['startedDay'] as num).toInt(),
      durationDays: (json['durationDays'] as num).toInt(),
      invested: (json['invested'] as num?)?.toDouble() ?? 0,
      progressDays: (json['progressDays'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Result of a resolved, turn-based battle.
class BattleResult {
  const BattleResult({
    required this.attackerId,
    required this.defenderId,
    required this.attackerWon,
    required this.attackerPowerBefore,
    required this.attackerPowerAfter,
    required this.defenderPowerBefore,
    required this.defenderPowerAfter,
    required this.attackerLossRatio,
    required this.defenderLossRatio,
    required this.attackerTreasuryGain,
    required this.stabilityDeltaAttacker,
    required this.stabilityDeltaDefender,
    required this.territoryTransferred,
    required this.day,
  });

  final String attackerId;
  final String defenderId;
  final bool attackerWon;
  final double attackerPowerBefore;
  final double attackerPowerAfter;
  final double defenderPowerBefore;
  final double defenderPowerAfter;
  final double attackerLossRatio;
  final double defenderLossRatio;
  final double attackerTreasuryGain;
  final double stabilityDeltaAttacker;
  final double stabilityDeltaDefender;
  final bool territoryTransferred;
  final int day;

  double get attackerLosses => attackerPowerBefore - attackerPowerAfter;
  double get defenderLosses => defenderPowerBefore - defenderPowerAfter;
}

/// An ongoing war between two or more countries.
class War {
  const War({
    required this.id,
    required this.aggressor,
    required this.defender,
    required this.startedDay,
    required this.frontRegion,
  });

  final String id;
  final String aggressor;
  final String defender;
  final int startedDay;

  /// Country id whose territory the fighting is happening on.
  final String frontRegion;

  bool involves(String countryId) =>
      aggressor == countryId || defender == countryId;

  String opponentOf(String countryId) =>
      aggressor == countryId ? defender : aggressor;

  Map<String, dynamic> toJson() => {
    'id': id,
    'aggressor': aggressor,
    'defender': defender,
    'startedDay': startedDay,
    'frontRegion': frontRegion,
  };

  static War fromJson(Map<String, dynamic> json) => War(
    id: json['id'] as String,
    aggressor: json['aggressor'] as String,
    defender: json['defender'] as String,
    startedDay: (json['startedDay'] as num).toInt(),
    frontRegion: json['frontRegion'] as String? ?? json['defender'] as String,
  );
}

/// A live, tick-driven battle the player can watch resolve.
class ActiveBattle {
  const ActiveBattle({
    required this.id,
    required this.attackerId,
    required this.defenderId,
    required this.warId,
    required this.day,
    required this.attackerMorale,
    required this.defenderMorale,
    required this.attackerPowerBefore,
    required this.defenderPowerBefore,
    required this.log,
  });

  final String id;
  final String attackerId;
  final String defenderId;
  final String warId;
  final int day;
  final double attackerMorale;
  final double defenderMorale;
  final double attackerPowerBefore;
  final double defenderPowerBefore;
  final List<String> log;

  bool involves(String countryId) =>
      attackerId == countryId || defenderId == countryId;

  String opponentOf(String countryId) =>
      attackerId == countryId ? defenderId : attackerId;

  ActiveBattle copyWith({
    int? day,
    double? attackerMorale,
    double? defenderMorale,
    List<String>? log,
  }) {
    return ActiveBattle(
      id: id,
      attackerId: attackerId,
      defenderId: defenderId,
      warId: warId,
      day: day ?? this.day,
      attackerMorale: attackerMorale ?? this.attackerMorale,
      defenderMorale: defenderMorale ?? this.defenderMorale,
      attackerPowerBefore: attackerPowerBefore,
      defenderPowerBefore: defenderPowerBefore,
      log: log ?? this.log,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'attackerId': attackerId,
    'defenderId': defenderId,
    'warId': warId,
    'day': day,
    'attackerMorale': attackerMorale,
    'defenderMorale': defenderMorale,
    'attackerPowerBefore': attackerPowerBefore,
    'defenderPowerBefore': defenderPowerBefore,
    'log': log,
  };

  static ActiveBattle fromJson(Map<String, dynamic> json) => ActiveBattle(
    id: json['id'] as String,
    attackerId: json['attackerId'] as String,
    defenderId: json['defenderId'] as String,
    warId: json['warId'] as String? ?? 'war',
    day: (json['day'] as num).toInt(),
    attackerMorale: (json['attackerMorale'] as num).toDouble(),
    defenderMorale: (json['defenderMorale'] as num).toDouble(),
    attackerPowerBefore: (json['attackerPowerBefore'] as num).toDouble(),
    defenderPowerBefore: (json['defenderPowerBefore'] as num).toDouble(),
    log: (json['log'] as List?)?.map((e) => e.toString()).toList() ?? [],
  );
}

/// Combat summary used by the battle engine to decide the odds preview.
class CombatEstimates {
  const CombatEstimates({
    required this.attackerPower,
    required this.defenderPower,
    required this.winChance,
    required this.expectedAttackerLosses,
    required this.expectedDefenderLosses,
    required this.supplyPenalty,
  });

  final double attackerPower;
  final double defenderPower;

  /// 0..1 estimated probability the attacker prevails.
  final double winChance;
  final double expectedAttackerLosses;
  final double expectedDefenderLosses;
  final double supplyPenalty;

  double get powerRatio =>
      defenderPower <= 0 ? 99 : attackerPower / defenderPower;
}

/// Read-only snapshot of how one side performed, derived from the unit list.
class ArmySummary {
  const ArmySummary({
    required this.infantryUnits,
    required this.armorUnits,
    required this.totalAttack,
    required this.totalDefense,
    required this.totalPower,
    required this.maxPower,
    required this.manpower,
    required this.monthlyMaintenance,
    this.readiness = 100,
    this.supply = 100,
  });

  final int infantryUnits;
  final int armorUnits;
  final double totalAttack;
  final double totalDefense;
  final double totalPower;
  final double maxPower;
  final double manpower;
  final double monthlyMaintenance;

  /// Aggregate national army readiness (0-100), driven by equipment stock.
  final double readiness;

  /// Average formation supply (0-100), driven by the logistics network.
  final double supply;

  double get totalUnits => (infantryUnits + armorUnits).toDouble();

  /// Composite score used by the battle engine.
  double get combatScore {
    final base = (totalAttack + totalDefense) * 0.5;
    final readinessFactor =
        0.45 + 0.55 * (maxPower <= 0 ? 0 : totalPower / maxPower);
    return base * readinessFactor +
        Balance.units[UnitType.infantry]!.attack * 0;
  }
}

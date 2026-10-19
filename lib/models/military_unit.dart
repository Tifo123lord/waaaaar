import '../core/balance.dart';

/// A named military formation (e.g. "3rd Infantry Division").
///
/// The demo models army strength at division granularity so that every unit can
/// carry a unique id, a cost, combat power and a home region.
class MilitaryUnit {
  const MilitaryUnit({
    required this.id,
    required this.type,
    required this.ownerId,
    required this.homeRegion,
    required this.power,
    required this.maxPower,
    required this.experience,
    required this.formedDay,
    required this.ordinal,
    this.supply = 1.0,
    this.moveDays = 0,
  });

  final String id;
  final UnitType type;
  final String ownerId;

  /// Country id where the formation is stationed.
  final String homeRegion;

  /// Current combat power (attrition reduces this).
  final double power;
  final double maxPower;

  /// 0..100, improves with combat.
  final double experience;

  /// Absolute simulation day when the formation was raised.
  final int formedDay;

  /// Sequence number used for the display designation.
  final int ordinal;

  /// Logistics supply level, 0..1, from the supply network.
  final double supply;

  /// Days of a move still to complete (0 = stationary).
  final int moveDays;

  UnitSpec get spec => Balance.units[type]!;

  bool get isDestroyed => power <= 0.5;

  /// Monthly upkeep scaled by the formation's condition.
  double maintenanceAt(double budgetMultiplier) =>
      spec.maintenance * (0.35 + 0.65 * (power / maxPower)) * budgetMultiplier;

  String designation() {
    final suffix = ordinal % 100;
    final mod100 = ordinal % 100;
    final ending = (mod100 >= 11 && mod100 <= 13)
        ? 'th'
        : switch (suffix % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    final branch = type == UnitType.infantry ? 'Infantry' : 'Armoured';
    return '$ordinal$ending $branch Division';
  }

  MilitaryUnit copyWith({
    String? homeRegion,
    double? power,
    double? experience,
    double? supply,
    int? moveDays,
  }) {
    return MilitaryUnit(
      id: id,
      type: type,
      ownerId: ownerId,
      homeRegion: homeRegion ?? this.homeRegion,
      power: power ?? this.power,
      maxPower: maxPower,
      experience: experience ?? this.experience,
      formedDay: formedDay,
      ordinal: ordinal,
      supply: supply ?? this.supply,
      moveDays: moveDays ?? this.moveDays,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'ownerId': ownerId,
    'homeRegion': homeRegion,
    'power': power,
    'maxPower': maxPower,
    'experience': experience,
    'formedDay': formedDay,
    'ordinal': ordinal,
    'supply': supply,
    'moveDays': moveDays,
  };

  static MilitaryUnit fromJson(Map<String, dynamic> json) {
    final type = UnitType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => UnitType.infantry,
    );
    return MilitaryUnit(
      id: json['id'] as String,
      type: type,
      ownerId: json['ownerId'] as String,
      homeRegion: json['homeRegion'] as String? ?? json['ownerId'] as String,
      power: (json['power'] as num).toDouble(),
      maxPower: (json['maxPower'] as num).toDouble(),
      experience: (json['experience'] as num?)?.toDouble() ?? 0,
      formedDay: (json['formedDay'] as num?)?.toInt() ?? 0,
      ordinal: (json['ordinal'] as num?)?.toInt() ?? 1,
      supply: (json['supply'] as num?)?.toDouble() ?? 1.0,
      moveDays: (json['moveDays'] as num?)?.toInt() ?? 0,
    );
  }
}

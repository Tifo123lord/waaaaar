import '../data/world_geometry.dart';

/// Mutable, save-able state for one capturable region.
///
/// The static geometry (outline, anchor, sector) lives in [MapRegion] in the
/// generated `world_geometry.dart`; this class only carries the parts that
/// change during a campaign, so a save file stores deltas rather than a copy of
/// the whole map.
class RegionState {
  const RegionState({
    required this.id,
    required this.ownerId,
    required this.controllerId,
    this.supplyHub = false,
    this.frontProgress = 0,
  });

  final String id;

  /// The nation that legally owns the region (its homeland).
  final String ownerId;

  /// The nation whose troops currently hold the region.
  final String controllerId;

  /// A supply hub projects logistics to nearby friendly regions.
  final bool supplyHub;

  /// Attacker momentum on this region's front, 0..100. Reaching 100 flips
  /// control; at 0 the line is stable or the defender has pushed back.
  final double frontProgress;

  bool get isOccupied => controllerId != ownerId;

  RegionState copyWith({
    String? ownerId,
    String? controllerId,
    bool? supplyHub,
    double? frontProgress,
  }) => RegionState(
    id: id,
    ownerId: ownerId ?? this.ownerId,
    controllerId: controllerId ?? this.controllerId,
    supplyHub: supplyHub ?? this.supplyHub,
    frontProgress: frontProgress ?? this.frontProgress,
  );

  Map<String, dynamic> toJson() => {
    'ownerId': ownerId,
    'controllerId': controllerId,
    if (supplyHub) 'supplyHub': true,
    if (frontProgress > 0.001) 'frontProgress': frontProgress,
  };

  static RegionState fromJson(
    String id,
    Map<String, dynamic> json,
    String fallbackOwner,
  ) {
    final owner = json['ownerId']?.toString() ?? fallbackOwner;
    return RegionState(
      id: id,
      ownerId: owner,
      controllerId: json['controllerId']?.toString() ?? owner,
      supplyHub: json['supplyHub'] == true,
      frontProgress: (json['frontProgress'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Static lookup helpers over the generated world data.
class WorldRegions {
  WorldRegions._();

  static final Map<String, MapRegion> _byId = {
    for (final r in kWorldRegions) r.id: r,
  };

  static final Map<String, List<MapRegion>> _byCountry = () {
    final map = <String, List<MapRegion>>{};
    for (final r in kWorldRegions) {
      map.putIfAbsent(r.countryId, () => []).add(r);
    }
    return map;
  }();

  static MapRegion? byId(String id) => _byId[id];

  static List<MapRegion> of(String countryId) =>
      _byCountry[countryId] ?? const [];

  /// The home (capital) region of a nation.
  static String? capitalOf(String countryId) {
    for (final r in of(countryId)) {
      if (r.capital) return r.id;
    }
    final list = of(countryId);
    return list.isEmpty ? null : list.first.id;
  }

  static String? ownerOfRegion(String regionId) => _byId[regionId]?.countryId;

  /// Every region a nation started with.
  static List<String> homeRegionsOf(String countryId) =>
      of(countryId).map((r) => r.id).toList(growable: false);

  /// All regions of all nations, in stable order.
  static List<String> get allIds =>
      kWorldRegions.map((r) => r.id).toList(growable: false);
}

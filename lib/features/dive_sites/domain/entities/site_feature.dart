/// The fixed feature vocabulary for slice 2. Stored as the enum NAME;
/// user-extensible types are out of scope.
enum SiteFeatureType {
  wreck,
  mooring,
  entry,
  exit,
  swimThrough,
  hazard,
  current,
}

/// A diver-placed annotation on a dive site: a point with an optional
/// bearing and optional depth. [typeName] keeps the raw stored string so
/// a type from a newer app version round-trips unchanged; [type] is null
/// for unknown names and the UI renders a generic marker.
class SiteFeature {
  final String id;
  final String siteId;
  final String typeName;
  final String name;
  final double latitude;
  final double longitude;

  /// 0-359 compass degrees; current direction or wreck orientation.
  final double? bearingDeg;

  /// Meters. Stored metric, displayed in the diver's unit.
  final double? depthMeters;
  final String notes;

  const SiteFeature({
    required this.id,
    required this.siteId,
    required this.typeName,
    this.name = '',
    required this.latitude,
    required this.longitude,
    this.bearingDeg,
    this.depthMeters,
    this.notes = '',
  });

  SiteFeatureType? get type => SiteFeatureType.values.asNameMap()[typeName];

  SiteFeature copyWith({
    String? id,
    String? siteId,
    String? typeName,
    String? name,
    double? latitude,
    double? longitude,
    double? bearingDeg,
    bool clearBearing = false,
    double? depthMeters,
    bool clearDepth = false,
    String? notes,
  }) {
    return SiteFeature(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      typeName: typeName ?? this.typeName,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      bearingDeg: clearBearing ? null : (bearingDeg ?? this.bearingDeg),
      depthMeters: clearDepth ? null : (depthMeters ?? this.depthMeters),
      notes: notes ?? this.notes,
    );
  }
}

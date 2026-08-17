/// What kind of craft the wreck was.
enum WreckVesselType { ship, aircraft, other }

/// Why it ended up on the bottom.
enum WreckCause {
  foundered,
  collision,
  grounding,
  scuttled,
  war,
  fire,
  unknown,
}

/// How much of it is still recognisable.
enum WreckCondition { intact, broken, debris }

/// Legal protection, which decides whether a diver may touch or enter.
enum WreckProtection { none, permitRequired, protected, warGrave }

/// A wreck in the diver's catalogue: a top-level record like a dive site,
/// carrying its own position and outliving any one site.
///
/// Enum-valued fields keep the RAW stored string alongside a nullable
/// typed getter, so a value written by a newer build (or by a future
/// external source) round-trips through sync unchanged instead of being
/// dropped. The typed getter is null for names this build does not know.
class Wreck {
  final String id;
  final String? diverId;

  /// The site this wreck is dived from, when the diver logged one.
  final String? siteId;
  final String name;
  final double? latitude;
  final double? longitude;
  final String? vesselTypeName;
  final String? causeName;
  final String? conditionName;
  final String? protectionName;

  /// Meters. Stored metric, displayed in the diver's unit.
  final double? depthToDeckMeters;
  final double? depthToSeabedMeters;
  final double? lengthMeters;
  final int? yearBuilt;
  final int? yearSunk;

  /// Null means unknown, which is not the same as no.
  final bool? penetrationPossible;
  final String notes;
  final bool isShared;

  const Wreck({
    required this.id,
    required this.name,
    this.diverId,
    this.siteId,
    this.latitude,
    this.longitude,
    this.vesselTypeName,
    this.causeName,
    this.conditionName,
    this.protectionName,
    this.depthToDeckMeters,
    this.depthToSeabedMeters,
    this.lengthMeters,
    this.yearBuilt,
    this.yearSunk,
    this.penetrationPossible,
    this.notes = '',
    this.isShared = false,
  });

  WreckVesselType? get vesselType =>
      WreckVesselType.values.asNameMap()[vesselTypeName];

  WreckCause? get cause => WreckCause.values.asNameMap()[causeName];

  WreckCondition? get condition =>
      WreckCondition.values.asNameMap()[conditionName];

  WreckProtection? get protection =>
      WreckProtection.values.asNameMap()[protectionName];

  bool get hasCoordinates => latitude != null && longitude != null;

  Wreck copyWith({
    String? id,
    String? diverId,
    String? siteId,

    /// Unlinks the wreck from its site.
    bool clearSite = false,
    String? name,
    double? latitude,
    double? longitude,

    /// Clears BOTH halves of the position: half a position is not one.
    bool clearCoordinates = false,
    String? vesselTypeName,
    String? causeName,
    String? conditionName,
    String? protectionName,
    double? depthToDeckMeters,
    double? depthToSeabedMeters,

    /// Clears both depth fields. Length is not a depth and is untouched.
    bool clearDepths = false,
    double? lengthMeters,
    int? yearBuilt,
    int? yearSunk,
    bool? penetrationPossible,
    String? notes,
    bool? isShared,
  }) {
    return Wreck(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      siteId: clearSite ? null : (siteId ?? this.siteId),
      name: name ?? this.name,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      vesselTypeName: vesselTypeName ?? this.vesselTypeName,
      causeName: causeName ?? this.causeName,
      conditionName: conditionName ?? this.conditionName,
      protectionName: protectionName ?? this.protectionName,
      depthToDeckMeters: clearDepths
          ? null
          : (depthToDeckMeters ?? this.depthToDeckMeters),
      depthToSeabedMeters: clearDepths
          ? null
          : (depthToSeabedMeters ?? this.depthToSeabedMeters),
      lengthMeters: lengthMeters ?? this.lengthMeters,
      yearBuilt: yearBuilt ?? this.yearBuilt,
      yearSunk: yearSunk ?? this.yearSunk,
      penetrationPossible: penetrationPossible ?? this.penetrationPossible,
      notes: notes ?? this.notes,
      isShared: isShared ?? this.isShared,
    );
  }
}

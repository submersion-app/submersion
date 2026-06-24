import 'package:equatable/equatable.dart';

/// Site difficulty levels
enum SiteDifficulty {
  beginner,
  intermediate,
  advanced,
  technical;

  String get displayName {
    switch (this) {
      case SiteDifficulty.beginner:
        return 'Beginner';
      case SiteDifficulty.intermediate:
        return 'Intermediate';
      case SiteDifficulty.advanced:
        return 'Advanced';
      case SiteDifficulty.technical:
        return 'Technical';
    }
  }

  static SiteDifficulty? fromString(String? value) {
    if (value == null) return null;
    return SiteDifficulty.values.cast<SiteDifficulty?>().firstWhere(
      (e) => e?.name == value.toLowerCase(),
      orElse: () => null,
    );
  }
}

/// Dive site/location entity
class DiveSite extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final String description;
  final GeoPoint? location;
  final double? minDepth; // meters - shallowest point of the site
  final double? maxDepth; // meters - deepest point of the site
  final SiteDifficulty? difficulty; // Site difficulty level
  final String? country;
  final String? region;
  final String? city;
  final String? island;
  final String? bodyOfWater;
  final List<String> photoIds;
  final double? rating; // 1-5 stars
  final String notes;
  final String? hazards; // Currents, boats, marine life warnings, etc.
  final String? accessNotes; // How to access the site, entry/exit points
  final String? mooringNumber; // Mooring buoy number for boat dives
  final String? parkingInfo; // Parking availability and tips
  final double?
  altitude; // Altitude above sea level in meters (for altitude diving)
  final SiteConditions? conditions;
  final bool isShared;

  const DiveSite({
    required this.id,
    this.diverId,
    required this.name,
    this.description = '',
    this.location,
    this.minDepth,
    this.maxDepth,
    this.difficulty,
    this.country,
    this.region,
    this.city,
    this.island,
    this.bodyOfWater,
    this.photoIds = const [],
    this.rating,
    this.notes = '',
    this.hazards,
    this.accessNotes,
    this.mooringNumber,
    this.parkingInfo,
    this.altitude,
    this.conditions,
    this.isShared = false,
  });

  /// Compact one-line location formatted as `locality · region, country`.
  /// Locality prefers [city], falling back to [island]. [bodyOfWater] is
  /// intentionally excluded to keep list tiles and map popups tight.
  String get locationString {
    // Trim before testing meaningfulness and before rendering so whitespace-
    // only values (e.g. from imported/synced data) are ignored and the output
    // is normalized — consistent with the save/merge paths' trim().isNotEmpty.
    final regionTrimmed = region?.trim() ?? '';
    final countryTrimmed = country?.trim() ?? '';
    final base = <String>[];
    if (regionTrimmed.isNotEmpty) base.add(regionTrimmed);
    if (countryTrimmed.isNotEmpty) base.add(countryTrimmed);
    final baseStr = base.join(', ');

    final cityTrimmed = city?.trim() ?? '';
    final islandTrimmed = island?.trim() ?? '';
    final locality = cityTrimmed.isNotEmpty ? cityTrimmed : islandTrimmed;

    if (locality.isNotEmpty && baseStr.isNotEmpty) {
      return '$locality · $baseStr';
    }
    if (locality.isNotEmpty) return locality;
    return baseStr;
  }

  bool get hasCoordinates => location != null;

  /// Depth range string (min - max)
  String? get depthRange {
    if (minDepth == null && maxDepth == null) return null;
    if (minDepth != null && maxDepth != null) {
      return '${minDepth!.toStringAsFixed(0)}-${maxDepth!.toStringAsFixed(0)}m';
    }
    if (minDepth != null) return '${minDepth!.toStringAsFixed(0)}m+';
    return 'up to ${maxDepth!.toStringAsFixed(0)}m';
  }

  DiveSite copyWith({
    String? id,
    String? diverId,
    String? name,
    String? description,
    GeoPoint? location,
    double? minDepth,
    double? maxDepth,
    SiteDifficulty? difficulty,
    String? country,
    String? region,
    String? city,
    String? island,
    String? bodyOfWater,
    List<String>? photoIds,
    double? rating,
    String? notes,
    String? hazards,
    String? accessNotes,
    String? mooringNumber,
    String? parkingInfo,
    double? altitude,
    SiteConditions? conditions,
    bool? isShared,
  }) {
    return DiveSite(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      minDepth: minDepth ?? this.minDepth,
      maxDepth: maxDepth ?? this.maxDepth,
      difficulty: difficulty ?? this.difficulty,
      country: country ?? this.country,
      region: region ?? this.region,
      city: city ?? this.city,
      island: island ?? this.island,
      bodyOfWater: bodyOfWater ?? this.bodyOfWater,
      photoIds: photoIds ?? this.photoIds,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      hazards: hazards ?? this.hazards,
      accessNotes: accessNotes ?? this.accessNotes,
      mooringNumber: mooringNumber ?? this.mooringNumber,
      parkingInfo: parkingInfo ?? this.parkingInfo,
      altitude: altitude ?? this.altitude,
      conditions: conditions ?? this.conditions,
      isShared: isShared ?? this.isShared,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    description,
    location,
    minDepth,
    maxDepth,
    difficulty,
    country,
    region,
    city,
    island,
    bodyOfWater,
    photoIds,
    rating,
    notes,
    hazards,
    accessNotes,
    mooringNumber,
    parkingInfo,
    altitude,
    conditions,
    isShared,
  ];
}

/// Geographic coordinates
class GeoPoint extends Equatable {
  final double latitude;
  final double longitude;

  const GeoPoint(this.latitude, this.longitude);

  @override
  List<Object?> get props => [latitude, longitude];

  @override
  String toString() =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

/// Typical conditions at a dive site
class SiteConditions extends Equatable {
  final String? waterType; // salt, fresh, brackish
  final String? typicalVisibility;
  final String? typicalCurrent;
  final String? bestSeason;
  final double? minTemp; // celsius
  final double? maxTemp; // celsius
  final String? entryType; // shore, boat

  const SiteConditions({
    this.waterType,
    this.typicalVisibility,
    this.typicalCurrent,
    this.bestSeason,
    this.minTemp,
    this.maxTemp,
    this.entryType,
  });

  @override
  List<Object?> get props => [
    waterType,
    typicalVisibility,
    typicalCurrent,
    bestSeason,
    minTemp,
    maxTemp,
    entryType,
  ];
}

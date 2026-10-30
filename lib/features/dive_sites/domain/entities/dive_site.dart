import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

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
  final WaterType? waterType; // Salt / fresh / brackish
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
  /// The ways into the water at this site (issues #1104, #2054), in enum
  /// order. Snapped onto a dive when the site is assigned only while there is
  /// exactly one ([soleEntryMethod]); the diver can always override it.
  final List<EntryMethod> entryMethods;

  /// The ways out of the water at this site. Empty means "same as entry".
  final List<EntryMethod> exitMethods;
  final bool isShared;

  /// The shared site library this site belongs to (issue #2567); null for a
  /// personal site.
  final String? sharedLibraryId;

  const DiveSite({
    required this.id,
    this.diverId,
    required this.name,
    this.description = '',
    this.location,
    this.minDepth,
    this.maxDepth,
    this.difficulty,
    this.waterType,
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
    this.entryMethods = const [],
    this.exitMethods = const [],
    this.isShared = false,
    this.sharedLibraryId,
  });

  /// Whether this site belongs to a shared site library (issue #2567).
  bool get isLibrarySite => sharedLibraryId != null;

  /// The site's entry method when it lists exactly one, else null: with
  /// several there is no telling which one a given dive used.
  EntryMethod? get soleEntryMethod =>
      entryMethods.length == 1 ? entryMethods.single : null;

  /// The site's exit method when it lists exactly one, else null.
  EntryMethod? get soleExitMethod =>
      exitMethods.length == 1 ? exitMethods.single : null;

  /// The town a site belongs to: its [city], falling back to its [island],
  /// trimmed; empty when neither is set.
  String get locality {
    final cityTrimmed = city?.trim() ?? '';
    return cityTrimmed.isNotEmpty ? cityTrimmed : (island?.trim() ?? '');
  }

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
    WaterType? waterType,
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
    List<EntryMethod>? entryMethods,
    List<EntryMethod>? exitMethods,
    bool? isShared,
    String? sharedLibraryId,
    bool clearSharedLibraryId = false,
    bool clearRating = false,
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
      waterType: waterType ?? this.waterType,
      country: country ?? this.country,
      region: region ?? this.region,
      city: city ?? this.city,
      island: island ?? this.island,
      bodyOfWater: bodyOfWater ?? this.bodyOfWater,
      photoIds: photoIds ?? this.photoIds,
      rating: clearRating ? null : rating ?? this.rating,
      notes: notes ?? this.notes,
      hazards: hazards ?? this.hazards,
      accessNotes: accessNotes ?? this.accessNotes,
      mooringNumber: mooringNumber ?? this.mooringNumber,
      parkingInfo: parkingInfo ?? this.parkingInfo,
      altitude: altitude ?? this.altitude,
      entryMethods: entryMethods ?? this.entryMethods,
      exitMethods: exitMethods ?? this.exitMethods,
      isShared: isShared ?? this.isShared,
      sharedLibraryId: clearSharedLibraryId
          ? null
          : (sharedLibraryId ?? this.sharedLibraryId),
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
    waterType,
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
    entryMethods,
    exitMethods,
    isShared,
    sharedLibraryId,
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

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
  final List<String> photoIds;
  final double? rating; // 1-5 stars
  final String notes;
  final String? hazards; // Currents, boats, marine life warnings, etc.
  final String? accessNotes; // How to access the site, entry/exit points
  final String? mooringNumber; // Mooring buoy number for boat dives
  final String? parkingInfo; // Parking availability and tips
  final SiteConditions? conditions;

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
    this.photoIds = const [],
    this.rating,
    this.notes = '',
    this.hazards,
    this.accessNotes,
    this.mooringNumber,
    this.parkingInfo,
    this.conditions,
  });

  /// Full location string (region, country)
  String get locationString {
    final parts = <String>[];
    if (region != null && region!.isNotEmpty) parts.add(region!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.join(', ');
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
    List<String>? photoIds,
    double? rating,
    String? notes,
    String? hazards,
    String? accessNotes,
    String? mooringNumber,
    String? parkingInfo,
    SiteConditions? conditions,
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
      photoIds: photoIds ?? this.photoIds,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      hazards: hazards ?? this.hazards,
      accessNotes: accessNotes ?? this.accessNotes,
      mooringNumber: mooringNumber ?? this.mooringNumber,
      parkingInfo: parkingInfo ?? this.parkingInfo,
      conditions: conditions ?? this.conditions,
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
        photoIds,
        rating,
        notes,
        hazards,
        accessNotes,
        mooringNumber,
        parkingInfo,
        conditions,
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
  String toString() => '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
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

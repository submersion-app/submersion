import 'package:equatable/equatable.dart';

/// A diver-emergency hotline region (DAN/DES).
class EmergencyRegion extends Equatable {
  final String id;
  final String name;
  final String phone;

  /// ISO 3166-1 alpha-2 codes served by this hotline. Empty = worldwide
  /// fallback.
  final List<String> countries;

  const EmergencyRegion({
    required this.id,
    required this.name,
    required this.phone,
    required this.countries,
  });

  factory EmergencyRegion.fromJson(Map<String, dynamic> json) {
    return EmergencyRegion(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      countries: (json['countries'] as List? ?? const []).cast<String>(),
    );
  }

  @override
  List<Object?> get props => [id, name, phone, countries];
}

/// A hyperbaric chamber entry: bundled (dated, read-only) or user-added.
class EmergencyChamber extends Equatable {
  final String id;
  final String name;
  final String country;
  final String? city;
  final String phone;
  final double? latitude;
  final double? longitude;
  final String? notes;

  /// Verification date for bundled entries; null for user entries.
  final DateTime? lastVerified;

  final bool isBuiltIn;

  const EmergencyChamber({
    required this.id,
    required this.name,
    required this.country,
    this.city,
    required this.phone,
    this.latitude,
    this.longitude,
    this.notes,
    this.lastVerified,
    required this.isBuiltIn,
  });

  factory EmergencyChamber.fromBundledJson(Map<String, dynamic> json) {
    return EmergencyChamber(
      id: json['id'] as String,
      name: json['name'] as String,
      country: json['country'] as String,
      city: json['city'] as String?,
      phone: json['phone'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      lastVerified: json['lastVerified'] != null
          ? DateTime.tryParse(json['lastVerified'] as String)
          : null,
      isBuiltIn: true,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    country,
    city,
    phone,
    latitude,
    longitude,
    notes,
    lastVerified,
    isBuiltIn,
  ];
}

/// The bundled hotline + EMS dataset.
class EmergencyNumbers {
  final List<EmergencyRegion> regions;
  final String defaultEms;
  final Map<String, String> emsByCountry;

  const EmergencyNumbers({
    required this.regions,
    required this.defaultEms,
    required this.emsByCountry,
  });

  /// Hotline for an ISO country code: the region listing the country, else
  /// the worldwide fallback (empty country list), else the first region.
  EmergencyRegion hotlineFor(String? countryCode) {
    if (countryCode != null) {
      for (final region in regions) {
        if (region.countries.contains(countryCode.toUpperCase())) {
          return region;
        }
      }
    }
    return regions.firstWhere(
      (r) => r.countries.isEmpty,
      orElse: () => regions.first,
    );
  }

  String emsFor(String? countryCode) {
    if (countryCode == null) return defaultEms;
    return emsByCountry[countryCode.toUpperCase()] ?? defaultEms;
  }
}

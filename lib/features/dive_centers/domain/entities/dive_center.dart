import 'package:equatable/equatable.dart';

/// Represents a dive center/operator
class DiveCenter extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final String? street; // Street address
  final String? city;
  final String? stateProvince; // State, province, or region
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? country;
  final String? phone;
  final String? email;
  final String? website;
  final List<String> affiliations; // PADI, SSI, etc.
  final double? rating;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DiveCenter({
    required this.id,
    this.diverId,
    required this.name,
    this.street,
    this.city,
    this.stateProvince,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.country,
    this.phone,
    this.email,
    this.website,
    this.affiliations = const [],
    this.rating,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if dive center has location coordinates
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Check if dive center has a street address
  bool get hasStreetAddress =>
      street != null ||
      city != null ||
      stateProvince != null ||
      postalCode != null;

  /// Get display location (city or country)
  String? get displayLocation => city ?? country;

  /// Get formatted street address (multi-line)
  String? get formattedAddress {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);

    // Build city/state/postal line
    final cityLine = <String>[];
    if (city != null && city!.isNotEmpty) cityLine.add(city!);
    if (stateProvince != null && stateProvince!.isNotEmpty) {
      cityLine.add(stateProvince!);
    }
    if (postalCode != null && postalCode!.isNotEmpty) {
      cityLine.add(postalCode!);
    }
    if (cityLine.isNotEmpty) parts.add(cityLine.join(', '));

    if (country != null && country!.isNotEmpty) parts.add(country!);

    return parts.isEmpty ? null : parts.join('\n');
  }

  /// Get single-line address summary
  String? get addressSummary {
    final parts = <String>[];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (stateProvince != null && stateProvince!.isNotEmpty) {
      parts.add(stateProvince!);
    }
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Get full location string (city, country)
  String? get fullLocationString {
    final parts = <String>[];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Get affiliations as display string
  String get affiliationsDisplay =>
      affiliations.isEmpty ? '' : affiliations.join(', ');

  /// Create a copy with updated fields
  DiveCenter copyWith({
    String? id,
    String? diverId,
    String? name,
    String? street,
    String? city,
    String? stateProvince,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? country,
    String? phone,
    String? email,
    String? website,
    List<String>? affiliations,
    double? rating,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiveCenter(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      street: street ?? this.street,
      city: city ?? this.city,
      stateProvince: stateProvince ?? this.stateProvince,
      postalCode: postalCode ?? this.postalCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      affiliations: affiliations ?? this.affiliations,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create a new empty dive center
  factory DiveCenter.empty() {
    final now = DateTime.now();
    return DiveCenter(id: '', name: '', createdAt: now, updatedAt: now);
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    street,
    city,
    stateProvince,
    postalCode,
    latitude,
    longitude,
    country,
    phone,
    email,
    website,
    affiliations,
    rating,
    notes,
    createdAt,
    updatedAt,
  ];
}

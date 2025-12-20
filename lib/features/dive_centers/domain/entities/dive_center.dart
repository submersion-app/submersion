import 'package:equatable/equatable.dart';

/// Represents a dive center/operator
class DiveCenter extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final String? location;
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
    this.location,
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

  /// Get display location (location or country)
  String? get displayLocation => location ?? country;

  /// Get affiliations as display string
  String get affiliationsDisplay =>
      affiliations.isEmpty ? '' : affiliations.join(', ');

  /// Create a copy with updated fields
  DiveCenter copyWith({
    String? id,
    String? diverId,
    String? name,
    String? location,
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
      location: location ?? this.location,
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
    return DiveCenter(
      id: '',
      name: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  List<Object?> get props => [
        id,
        diverId,
        name,
        location,
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

import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// A circular geofence attached to an equipment set. Matches a dive when its
/// [center] is within [radiusMeters] of one of the dive's known points.
class EquipmentSetGeofence extends Equatable {
  final String id;
  final String setId;
  final String? label;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EquipmentSetGeofence({
    required this.id,
    required this.setId,
    this.label,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.createdAt,
    required this.updatedAt,
  });

  GeoPoint get center => GeoPoint(latitude, longitude);

  EquipmentSetGeofence copyWith({
    String? id,
    String? setId,
    String? label,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EquipmentSetGeofence(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    setId,
    label,
    latitude,
    longitude,
    radiusMeters,
    createdAt,
    updatedAt,
  ];
}

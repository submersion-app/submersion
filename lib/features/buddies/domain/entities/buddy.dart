import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// Dive buddy entity
class Buddy extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final String? email;
  final String? phone;
  final CertificationLevel? certificationLevel;
  final CertificationAgency? certificationAgency;
  final String? photoPath;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Buddy({
    required this.id,
    this.diverId,
    required this.name,
    this.email,
    this.phone,
    this.certificationLevel,
    this.certificationAgency,
    this.photoPath,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Display name with certification info
  String get displayName {
    if (certificationLevel != null) {
      return '$name (${certificationLevel!.displayName})';
    }
    return name;
  }

  /// Get initials for avatar
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Check if buddy has contact info
  bool get hasContactInfo => email != null || phone != null;

  /// Check if buddy has certification info
  bool get hasCertificationInfo =>
      certificationLevel != null || certificationAgency != null;

  Buddy copyWith({
    String? id,
    String? diverId,
    String? name,
    String? email,
    String? phone,
    CertificationLevel? certificationLevel,
    CertificationAgency? certificationAgency,
    String? photoPath,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Buddy(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      certificationLevel: certificationLevel ?? this.certificationLevel,
      certificationAgency: certificationAgency ?? this.certificationAgency,
      photoPath: photoPath ?? this.photoPath,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        diverId,
        name,
        email,
        phone,
        certificationLevel,
        certificationAgency,
        photoPath,
        notes,
        createdAt,
        updatedAt,
      ];
}

/// Buddy with role for a specific dive
class BuddyWithRole extends Equatable {
  final Buddy buddy;
  final BuddyRole role;

  const BuddyWithRole({
    required this.buddy,
    required this.role,
  });

  @override
  List<Object?> get props => [buddy, role];
}

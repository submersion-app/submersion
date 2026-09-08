import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// Dive buddy entity
class Buddy extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final String? email;
  final String? phone;
  final CertificationLevel? certificationLevel;
  final CertificationAgency? certificationAgency;

  /// The primary certification's on-screen title -- its "Name on the card"
  /// when that says more than the agency/level pair, otherwise the derived
  /// title. Derived at hydration alongside [certificationLevel] (issue #1303);
  /// null on the raw row and whenever the buddy has no certification.
  final String? certificationTitle;
  final String? photoPath;

  /// Profile photo: a 512x512 square JPEG. Supersedes [photoPath].
  final Uint8List? photo;
  final String notes;
  final bool isFavorite;
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
    this.certificationTitle,
    this.photoPath,
    this.photo,
    this.notes = '',
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Display name with certification info
  String get displayName {
    final cert = certificationTitle ?? certificationLevel?.displayName;
    return cert == null ? name : '$name ($cert)';
  }

  /// The certification line for list tiles: the title, followed by the agency
  /// unless the agency is [CertificationAgency.other] (whose "Other" says
  /// nothing) or already part of the title. Null when the buddy has no
  /// certification. Issue #1303.
  String? get certificationLine {
    final title = certificationTitle ?? certificationLevel?.displayName;
    final agency = certificationAgency;
    if (title == null) {
      return agency == null || agency == CertificationAgency.other
          ? null
          : agency.displayName;
    }
    if (agency == null || agency == CertificationAgency.other) {
      return title;
    }
    // A stored "Name on the card" often already spells out the agency in its
    // own casing/spacing ("Padi Rescue Diver", "PADI - Rescue Diver"), so
    // compare loosely to avoid appending the agency a second time.
    String loose(String s) =>
        s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    if (loose(title).contains(loose(agency.displayName))) {
      return title;
    }
    return '$title · ${agency.displayName}';
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
    String? certificationTitle,
    String? photoPath,
    Uint8List? photo,
    String? notes,
    bool? isFavorite,
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
      certificationTitle: certificationTitle ?? this.certificationTitle,
      photoPath: photoPath ?? this.photoPath,
      photo: photo ?? this.photo,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create a copy with the profile photo explicitly removed.
  ///
  /// [copyWith] uses the plain `??` idiom, so `copyWith(photo: null)` keeps
  /// the current value rather than clearing it. This mirrors
  /// `Certification.clearPhotos`, which solves the same problem for the
  /// certification card blobs.
  Buddy clearPhoto() {
    return Buddy(
      id: id,
      diverId: diverId,
      name: name,
      email: email,
      phone: phone,
      certificationLevel: certificationLevel,
      certificationAgency: certificationAgency,
      certificationTitle: certificationTitle,
      photoPath: photoPath,
      photo: null,
      notes: notes,
      isFavorite: isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt,
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
    certificationTitle,
    photoPath,
    photo,
    notes,
    isFavorite,
    createdAt,
    updatedAt,
  ];
}

/// Buddy with role for a specific dive. The role is resolved from the
/// dive_roles table (synthetic for unknown slugs); persistence always uses
/// [DiveRole.id], never the display name.
class BuddyWithRole extends Equatable {
  final Buddy buddy;
  final DiveRole role;

  const BuddyWithRole({required this.buddy, required this.role});

  @override
  List<Object?> get props => [buddy, role];
}

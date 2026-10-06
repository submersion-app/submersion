import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// Dive buddy entity
class Buddy extends Equatable {
  final String id;
  final String? diverId;

  /// The local diver profile this buddy is (issue #2002). Null for a buddy
  /// with no profile on this library. Not the owner: that is [diverId].
  final String? linkedDiverId;
  final String name;
  final String? email;
  final String? phone;

  /// The primary certification's level and agency ids (built-in enum names
  /// or custom ids, issue #690).
  final String? certificationLevel;
  final String? certificationAgency;

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
    this.linkedDiverId,
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

  /// The primary level's English name, from the built-in catalog. A custom
  /// level is named through certificationTitle, which hydration derives.
  String? get _levelName {
    final level = certificationLevel;
    if (level == null) return null;
    return CertificationCatalog.builtInOnly.level(level).interchangeName;
  }

  /// Display name with certification info
  String get displayName {
    final cert = certificationTitle ?? _levelName;
    return cert == null ? name : '$name ($cert)';
  }

  /// The certification line for list tiles: the title, followed by the agency
  /// unless the agency is [CertificationAgency.other] (whose "Other" says
  /// nothing) or already part of the title. Null when the buddy has no
  /// certification. Issue #1303.
  String? get certificationLine {
    final title = certificationTitle ?? _levelName;
    final agency = certificationAgency;
    final agencyName = agency == null
        ? null
        : CertificationCatalog.builtInOnly.agency(agency).interchangeName;
    if (title == null) {
      return agency == null || agency == CertificationAgency.other.name
          ? null
          : agencyName;
    }
    if (agency == null || agency == CertificationAgency.other.name) {
      return title;
    }
    // A stored "Name on the card" often already spells out the agency in its
    // own casing/spacing ("Padi Rescue Diver", "PADI - Rescue Diver"), so
    // compare loosely to avoid appending the agency a second time.
    String loose(String s) =>
        s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    if (loose(title).contains(loose(agencyName!))) {
      return title;
    }
    return '$title · $agencyName';
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
    String? linkedDiverId,
    String? name,
    String? email,
    String? phone,
    String? certificationLevel,
    String? certificationAgency,
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
      linkedDiverId: linkedDiverId ?? this.linkedDiverId,
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
      linkedDiverId: linkedDiverId,
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

  /// Create a copy with the profile link removed. [copyWith] keeps the
  /// current value on a null argument, so clearing needs its own method,
  /// as [clearPhoto] does for the photo.
  Buddy clearLinkedDiver() {
    return Buddy(
      id: id,
      diverId: diverId,
      linkedDiverId: null,
      name: name,
      email: email,
      phone: phone,
      certificationLevel: certificationLevel,
      certificationAgency: certificationAgency,
      certificationTitle: certificationTitle,
      photoPath: photoPath,
      photo: photo,
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
    linkedDiverId,
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

  /// Every role this person holds on the dive, in DiveRoleSet order; never
  /// empty (issue #1221). The first is the primary role `dive_buddies.role`
  /// holds for older app versions.
  final List<DiveRole> roles;

  BuddyWithRole({required this.buddy, required this.roles})
    : assert(roles.isNotEmpty, 'a buddy link always carries a role');

  DiveRole get primaryRole => roles.first;

  List<String> get roleIds => [for (final r in roles) r.id];

  @override
  List<Object?> get props => [buddy, roles];
}

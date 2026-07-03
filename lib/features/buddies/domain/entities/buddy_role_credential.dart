import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// Roles that represent professional credentials a buddy can hold.
const kProfessionalBuddyRoles = [
  BuddyRole.instructor,
  BuddyRole.diveMaster,
  BuddyRole.diveGuide,
];

/// A professional credential held by a buddy (issue #395).
class BuddyRoleCredential extends Equatable {
  final String id;
  final String buddyId;
  final BuddyRole role;
  final String? credentialNumber;
  final CertificationAgency? agency;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BuddyRoleCredential({
    required this.id,
    required this.buddyId,
    required this.role,
    this.credentialNumber,
    this.agency,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Display string like "Instructor - PADI #12345".
  String get displayLabel {
    final parts = <String>[
      if (agency != null) agency!.displayName,
      if (credentialNumber != null && credentialNumber!.isNotEmpty)
        '#$credentialNumber',
    ];
    if (parts.isEmpty) return role.displayName;
    return '${role.displayName} - ${parts.join(' ')}';
  }

  /// Copy with overrides. The nullable [credentialNumber] and [agency] use a
  /// sentinel default so passing `null` explicitly CLEARS the field, while
  /// omitting the argument keeps the current value (a plain `?? this.field`
  /// cannot express "clear").
  BuddyRoleCredential copyWith({
    String? id,
    String? buddyId,
    BuddyRole? role,
    Object? credentialNumber = _unset,
    Object? agency = _unset,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BuddyRoleCredential(
      id: id ?? this.id,
      buddyId: buddyId ?? this.buddyId,
      role: role ?? this.role,
      credentialNumber: identical(credentialNumber, _unset)
          ? this.credentialNumber
          : credentialNumber as String?,
      agency: identical(agency, _unset)
          ? this.agency
          : agency as CertificationAgency?,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Sentinel marking a copyWith argument as "not provided" so an explicit
  /// `null` can be distinguished from omission.
  static const Object _unset = Object();

  @override
  List<Object?> get props => [
    id,
    buddyId,
    role,
    credentialNumber,
    agency,
    notes,
    createdAt,
    updatedAt,
  ];
}

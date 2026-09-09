import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// One (agency, level) recognition on a certification card. A card can grant
/// several at once -- e.g. an FFESSM Niveau 1 that is also a CMAS 1-star --
/// with no primary among them.
class CertificationCredential extends Equatable {
  final CertificationAgency agency;
  final CertificationLevel? level;

  const CertificationCredential({required this.agency, this.level});

  Map<String, dynamic> toJson() => {
    'agency': agency.name,
    if (level != null) 'level': level!.name,
  };

  factory CertificationCredential.fromJson(Map<String, dynamic> json) =>
      CertificationCredential(
        agency: CertificationAgency.values.firstWhere(
          (a) => a.name == json['agency'],
          orElse: () => CertificationAgency.other,
        ),
        level: json['level'] == null
            ? null
            : CertificationLevel.values.firstWhere(
                (l) => l.name == json['level'],
                orElse: () => CertificationLevel.other,
              ),
      );

  @override
  List<Object?> get props => [agency, level];
}

/// Represents a diver certification
class Certification extends Equatable {
  final String id;
  final String? diverId;

  /// Owner when this certification belongs to a buddy instead of the diver
  /// (issue #553). At most one of {diverId, buddyId} is set -- ownerless rows
  /// are allowed (legacy rows and the no-validated-diver fallback).
  final String? buddyId;
  final String name;
  final CertificationAgency agency;
  final CertificationLevel? level;

  /// Extra recognitions the same card grants beyond [agency]/[level] (e.g. a
  /// CMAS 1-star equivalence on an FFESSM N1). Empty for a single-agency card.
  /// None of them outranks [agency]/[level]; the card simply is all of them.
  /// [credentials] is the full list, in the stable display order the UI uses.
  final List<CertificationCredential> additionalCredentials;

  final String? cardNumber;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String? instructorName;
  final String? instructorNumber;
  final String? instructorId;
  final Uint8List? photoFront;
  final Uint8List? photoBack;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Certification({
    required this.id,
    this.diverId,
    this.buddyId,
    required this.name,
    required this.agency,
    this.level,
    this.additionalCredentials = const [],
    this.cardNumber,
    this.issueDate,
    this.expiryDate,
    this.instructorName,
    this.instructorNumber,
    this.instructorId,
    this.photoFront,
    this.photoBack,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Every (agency, level) this card grants. No entry is the primary one --
  /// they are equal recognitions -- but the list order is stable and is what
  /// the list tile, detail page and wallet card render: the row's own
  /// [agency]/[level] first, then [additionalCredentials] in stored order.
  /// Always at least one entry.
  List<CertificationCredential> get credentials => [
    CertificationCredential(agency: agency, level: level),
    ...additionalCredentials,
  ];

  /// Whether the card grants more than one agency's credential.
  bool get hasMultipleCredentials => additionalCredentials.isNotEmpty;

  /// Check if certification has any photos
  bool get hasPhotos => photoFront != null || photoBack != null;

  /// Check if certification is expired
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  /// Check if certification expires within the given number of days
  bool expiresWithin(int days) {
    if (expiryDate == null) return false;
    final threshold = DateTime.now().add(Duration(days: days));
    return expiryDate!.isBefore(threshold) && !isExpired;
  }

  /// Days until expiry (null if no expiry date or already expired)
  int? get daysUntilExpiry {
    if (expiryDate == null || isExpired) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  /// Human-readable expiry status
  String get expiryStatus {
    if (expiryDate == null) return 'No expiry';
    if (isExpired) return 'Expired';
    final days = daysUntilExpiry;
    if (days == null) return 'Unknown';
    if (days <= 30) return 'Expires in $days days';
    if (days <= 90) return 'Expires in ${(days / 30).round()} months';
    return 'Valid';
  }

  /// Create a copy with updated fields
  Certification copyWith({
    String? id,
    String? diverId,
    String? buddyId,
    String? name,
    CertificationAgency? agency,
    CertificationLevel? level,
    List<CertificationCredential>? additionalCredentials,
    String? cardNumber,
    DateTime? issueDate,
    DateTime? expiryDate,
    String? instructorName,
    String? instructorNumber,
    String? instructorId,
    Uint8List? photoFront,
    Uint8List? photoBack,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Certification(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      buddyId: buddyId ?? this.buddyId,
      name: name ?? this.name,
      agency: agency ?? this.agency,
      level: level ?? this.level,
      additionalCredentials:
          additionalCredentials ?? this.additionalCredentials,
      cardNumber: cardNumber ?? this.cardNumber,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      instructorName: instructorName ?? this.instructorName,
      instructorNumber: instructorNumber ?? this.instructorNumber,
      instructorId: instructorId ?? this.instructorId,
      photoFront: photoFront ?? this.photoFront,
      photoBack: photoBack ?? this.photoBack,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create a copy with photos explicitly cleared
  Certification clearPhotos({bool clearFront = false, bool clearBack = false}) {
    return Certification(
      id: id,
      diverId: diverId,
      buddyId: buddyId,
      name: name,
      agency: agency,
      level: level,
      additionalCredentials: additionalCredentials,
      cardNumber: cardNumber,
      issueDate: issueDate,
      expiryDate: expiryDate,
      instructorName: instructorName,
      instructorNumber: instructorNumber,
      instructorId: instructorId,
      photoFront: clearFront ? null : photoFront,
      photoBack: clearBack ? null : photoBack,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create a new certification with default values
  factory Certification.empty() {
    final now = DateTime.now();
    return Certification(
      id: '',
      name: '',
      agency: CertificationAgency.padi,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    buddyId,
    name,
    agency,
    level,
    additionalCredentials,
    cardNumber,
    issueDate,
    expiryDate,
    instructorName,
    instructorNumber,
    instructorId,
    photoFront,
    photoBack,
    notes,
    createdAt,
    updatedAt,
  ];
}

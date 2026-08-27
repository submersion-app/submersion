import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

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

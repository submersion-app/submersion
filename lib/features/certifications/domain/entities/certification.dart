import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// Represents a diver certification
class Certification extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final CertificationAgency agency;
  final CertificationLevel? level;
  final String? cardNumber;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String? instructorName;
  final String? instructorNumber;
  final String? photoFrontPath;
  final String? photoBackPath;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Certification({
    required this.id,
    this.diverId,
    required this.name,
    required this.agency,
    this.level,
    this.cardNumber,
    this.issueDate,
    this.expiryDate,
    this.instructorName,
    this.instructorNumber,
    this.photoFrontPath,
    this.photoBackPath,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

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
    String? name,
    CertificationAgency? agency,
    CertificationLevel? level,
    String? cardNumber,
    DateTime? issueDate,
    DateTime? expiryDate,
    String? instructorName,
    String? instructorNumber,
    String? photoFrontPath,
    String? photoBackPath,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Certification(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      agency: agency ?? this.agency,
      level: level ?? this.level,
      cardNumber: cardNumber ?? this.cardNumber,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      instructorName: instructorName ?? this.instructorName,
      instructorNumber: instructorNumber ?? this.instructorNumber,
      photoFrontPath: photoFrontPath ?? this.photoFrontPath,
      photoBackPath: photoBackPath ?? this.photoBackPath,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    name,
    agency,
    level,
    cardNumber,
    issueDate,
    expiryDate,
    instructorName,
    instructorNumber,
    photoFrontPath,
    photoBackPath,
    notes,
    createdAt,
    updatedAt,
  ];
}

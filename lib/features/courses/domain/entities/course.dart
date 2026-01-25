import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// Represents a training course (e.g., "Advanced Open Water", "Rescue Diver")
class Course extends Equatable {
  final String id;
  final String diverId;
  final String name;
  final CertificationAgency agency;
  final DateTime startDate;
  final DateTime? completionDate;
  final String? instructorId; // FK to buddy
  final String? instructorName; // Text fallback
  final String? instructorNumber; // Instructor cert number
  final String? certificationId; // FK to earned certification
  final String? location; // Dive center/shop
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Course({
    required this.id,
    required this.diverId,
    required this.name,
    required this.agency,
    required this.startDate,
    this.completionDate,
    this.instructorId,
    this.instructorName,
    this.instructorNumber,
    this.certificationId,
    this.location,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether the course is completed
  bool get isCompleted => completionDate != null;

  /// Whether the course is still in progress
  bool get isInProgress => completionDate == null;

  /// Display name for the instructor
  String get instructorDisplay => instructorName ?? 'Unknown Instructor';

  /// Duration of the course in days (null if in progress)
  int? get durationDays {
    if (completionDate == null) return null;
    return completionDate!.difference(startDate).inDays;
  }

  /// Days since course started
  int get daysSinceStart => DateTime.now().difference(startDate).inDays;

  /// Create a copy with updated fields
  Course copyWith({
    String? id,
    String? diverId,
    String? name,
    CertificationAgency? agency,
    DateTime? startDate,
    DateTime? completionDate,
    String? instructorId,
    String? instructorName,
    String? instructorNumber,
    String? certificationId,
    String? location,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      agency: agency ?? this.agency,
      startDate: startDate ?? this.startDate,
      completionDate: completionDate ?? this.completionDate,
      instructorId: instructorId ?? this.instructorId,
      instructorName: instructorName ?? this.instructorName,
      instructorNumber: instructorNumber ?? this.instructorNumber,
      certificationId: certificationId ?? this.certificationId,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create a copy with completionDate explicitly cleared
  Course clearCompletionDate({
    String? id,
    String? diverId,
    String? name,
    CertificationAgency? agency,
    DateTime? startDate,
    String? instructorId,
    String? instructorName,
    String? instructorNumber,
    String? certificationId,
    String? location,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      agency: agency ?? this.agency,
      startDate: startDate ?? this.startDate,
      completionDate: null,
      instructorId: instructorId ?? this.instructorId,
      instructorName: instructorName ?? this.instructorName,
      instructorNumber: instructorNumber ?? this.instructorNumber,
      certificationId: certificationId ?? this.certificationId,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create a new course with default values
  factory Course.empty(String diverId) {
    final now = DateTime.now();
    return Course(
      id: '',
      diverId: diverId,
      name: '',
      agency: CertificationAgency.padi,
      startDate: now,
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
    startDate,
    completionDate,
    instructorId,
    instructorName,
    instructorNumber,
    certificationId,
    location,
    notes,
    createdAt,
    updatedAt,
  ];
}

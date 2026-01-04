import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// Represents an equipment service record
class ServiceRecord extends Equatable {
  final String id;
  final String equipmentId;
  final ServiceType serviceType;
  final DateTime serviceDate;
  final String? provider;
  final double? cost;
  final String currency;
  final DateTime? nextServiceDue;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceRecord({
    required this.id,
    required this.equipmentId,
    required this.serviceType,
    required this.serviceDate,
    this.provider,
    this.cost,
    this.currency = 'USD',
    this.nextServiceDue,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if service is overdue
  bool get isOverdue {
    if (nextServiceDue == null) return false;
    return DateTime.now().isAfter(nextServiceDue!);
  }

  /// Check if service is due within the given number of days
  bool dueWithin(int days) {
    if (nextServiceDue == null) return false;
    final threshold = DateTime.now().add(Duration(days: days));
    return nextServiceDue!.isBefore(threshold) && !isOverdue;
  }

  /// Days until next service due (null if no date set or already overdue)
  int? get daysUntilDue {
    if (nextServiceDue == null || isOverdue) return null;
    return nextServiceDue!.difference(DateTime.now()).inDays;
  }

  /// Create a copy with updated fields
  ServiceRecord copyWith({
    String? id,
    String? equipmentId,
    ServiceType? serviceType,
    DateTime? serviceDate,
    String? provider,
    double? cost,
    String? currency,
    DateTime? nextServiceDue,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceRecord(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      serviceType: serviceType ?? this.serviceType,
      serviceDate: serviceDate ?? this.serviceDate,
      provider: provider ?? this.provider,
      cost: cost ?? this.cost,
      currency: currency ?? this.currency,
      nextServiceDue: nextServiceDue ?? this.nextServiceDue,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create a new service record with default values
  factory ServiceRecord.empty(String equipmentId) {
    final now = DateTime.now();
    return ServiceRecord(
      id: '',
      equipmentId: equipmentId,
      serviceType: ServiceType.annual,
      serviceDate: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  List<Object?> get props => [
    id,
    equipmentId,
    serviceType,
    serviceDate,
    provider,
    cost,
    currency,
    nextServiceDue,
    notes,
    createdAt,
    updatedAt,
  ];
}

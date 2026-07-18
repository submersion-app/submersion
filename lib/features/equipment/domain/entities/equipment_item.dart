import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// Diving equipment entity
class EquipmentItem extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final EquipmentType type;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final String? size; // S, M, L, XL, or specific size
  final String? thickness; // 2,3,4,5,6 or 6mm
  final EquipmentStatus status;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String purchaseCurrency;
  final DateTime? lastServiceDate;
  final int? serviceIntervalDays;
  final String notes;
  final bool isActive;

  // Buoyancy metadata (v104): net in-water buoyancy in kg (positive floats,
  // negative sinks) and dry weight in kg. Both optional; the weight
  // prediction engine falls back to type-based defaults when absent.
  final double? buoyancyKg;
  final double? weightKg;

  // Notification overrides
  final bool? customReminderEnabled; // NULL = use global
  final List<int>? customReminderDays; // Override reminder days

  /// Row creation time (null for entities built before persistence); used as
  /// the last anchor fallback for service clocks.
  final DateTime? createdAt;

  const EquipmentItem({
    required this.id,
    this.diverId,
    required this.name,
    required this.type,
    this.brand,
    this.model,
    this.serialNumber,
    this.size,
    this.thickness,
    this.status = EquipmentStatus.active,
    this.purchaseDate,
    this.purchasePrice,
    this.purchaseCurrency = 'USD',
    this.lastServiceDate,
    this.serviceIntervalDays,
    this.notes = '',
    this.isActive = true,
    this.buoyancyKg,
    this.weightKg,
    this.customReminderEnabled,
    this.customReminderDays,
    this.createdAt,
  });

  /// Full name including brand and model
  String get fullName {
    final parts = <String>[];
    if (brand != null && brand!.isNotEmpty) parts.add(brand!);
    if (model != null && model!.isNotEmpty) parts.add(model!);
    return parts.isEmpty ? name : parts.join(' ');
  }

  /// Next service due date
  DateTime? get nextServiceDue {
    if (lastServiceDate == null || serviceIntervalDays == null) return null;
    return lastServiceDate!.add(Duration(days: serviceIntervalDays!));
  }

  /// Whether service is currently due or overdue
  bool get isServiceDue {
    final dueDate = nextServiceDue;
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate);
  }

  /// Days until next service (negative if overdue)
  int? get daysUntilService {
    final dueDate = nextServiceDue;
    if (dueDate == null) return null;
    return dueDate.difference(DateTime.now()).inDays;
  }

  /// Ownership duration
  Duration? get ownershipDuration {
    if (purchaseDate == null) return null;
    return DateTime.now().difference(purchaseDate!);
  }

  EquipmentItem copyWith({
    String? id,
    String? diverId,
    String? name,
    EquipmentType? type,
    String? brand,
    String? model,
    String? serialNumber,
    String? size,
    String? thickness,
    EquipmentStatus? status,
    DateTime? purchaseDate,
    double? purchasePrice,
    String? purchaseCurrency,
    DateTime? lastServiceDate,
    int? serviceIntervalDays,
    String? notes,
    bool? isActive,
    double? buoyancyKg,
    double? weightKg,
    bool? customReminderEnabled,
    List<int>? customReminderDays,
    DateTime? createdAt,
  }) {
    return EquipmentItem(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      size: size ?? this.size,
      thickness: thickness ?? this.thickness,
      status: status ?? this.status,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchaseCurrency: purchaseCurrency ?? this.purchaseCurrency,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      serviceIntervalDays: serviceIntervalDays ?? this.serviceIntervalDays,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      buoyancyKg: buoyancyKg ?? this.buoyancyKg,
      weightKg: weightKg ?? this.weightKg,
      customReminderEnabled:
          customReminderEnabled ?? this.customReminderEnabled,
      customReminderDays: customReminderDays ?? this.customReminderDays,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    type,
    brand,
    model,
    serialNumber,
    size,
    thickness,
    status,
    purchaseDate,
    purchasePrice,
    purchaseCurrency,
    lastServiceDate,
    serviceIntervalDays,
    notes,
    isActive,
    buoyancyKg,
    weightKg,
    customReminderEnabled,
    customReminderDays,
    createdAt,
  ];
}

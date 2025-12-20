import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

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
  final EquipmentStatus status;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String purchaseCurrency;
  final DateTime? lastServiceDate;
  final int? serviceIntervalDays;
  final String notes;
  final bool isActive;

  const EquipmentItem({
    required this.id,
    this.diverId,
    required this.name,
    required this.type,
    this.brand,
    this.model,
    this.serialNumber,
    this.size,
    this.status = EquipmentStatus.active,
    this.purchaseDate,
    this.purchasePrice,
    this.purchaseCurrency = 'USD',
    this.lastServiceDate,
    this.serviceIntervalDays,
    this.notes = '',
    this.isActive = true,
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
    EquipmentStatus? status,
    DateTime? purchaseDate,
    double? purchasePrice,
    String? purchaseCurrency,
    DateTime? lastServiceDate,
    int? serviceIntervalDays,
    String? notes,
    bool? isActive,
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
      status: status ?? this.status,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchaseCurrency: purchaseCurrency ?? this.purchaseCurrency,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      serviceIntervalDays: serviceIntervalDays ?? this.serviceIntervalDays,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
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
        status,
        purchaseDate,
        purchasePrice,
        purchaseCurrency,
        lastServiceDate,
        serviceIntervalDays,
        notes,
        isActive,
      ];
}

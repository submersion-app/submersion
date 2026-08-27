import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

/// Diving equipment entity
class EquipmentItem extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final EquipmentType type;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final EquipmentStatus status;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String purchaseCurrency;
  final DateTime? lastServiceDate;
  final int? serviceIntervalDays;
  final String notes;
  final bool isActive;

  /// Type-specific and user-defined attributes (equipment_attributes rows).
  /// Hydrated by detail/edit/list reads; empty on partially loaded items.
  final List<EquipmentAttribute> attributes;

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
    this.status = EquipmentStatus.active,
    this.purchaseDate,
    this.purchasePrice,
    this.purchaseCurrency = 'USD',
    this.lastServiceDate,
    this.serviceIntervalDays,
    this.notes = '',
    this.isActive = true,
    this.attributes = const [],
    this.customReminderEnabled,
    this.customReminderDays,
    this.createdAt,
  });

  /// Curated attribute lookup helpers. Legacy field names are preserved as
  /// getters so existing consumers (weight planner, CSV export, detail page)
  /// read from the attribute store transparently.
  String? attrText(String key) {
    for (final a in attributes) {
      if (!a.isCustom && a.key == key) return a.valueText;
    }
    return null;
  }

  double? attrNum(String key) {
    for (final a in attributes) {
      if (!a.isCustom && a.key == key) return a.valueNum;
    }
    return null;
  }

  String? get size => attrText(EquipmentAttrKeys.size);
  String? get thickness => attrText(EquipmentAttrKeys.thicknessMm);
  double? get buoyancyKg => attrNum(EquipmentAttrKeys.buoyancyKg);
  double? get weightKg => attrNum(EquipmentAttrKeys.dryWeightKg);

  /// Wing/BCD rated lift capacity in kg (curated attribute; see the BCD entry
  /// in [EquipmentAttributeCatalog]). Feeds the buoyancy twin's peak-lift
  /// demand comparison; null when unspecified.
  double? get liftCapacityKg => attrNum(EquipmentAttrKeys.liftCapacityKg);

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
    EquipmentStatus? status,
    DateTime? purchaseDate,
    double? purchasePrice,
    String? purchaseCurrency,
    DateTime? lastServiceDate,
    int? serviceIntervalDays,
    String? notes,
    bool? isActive,
    List<EquipmentAttribute>? attributes,
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
      status: status ?? this.status,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchaseCurrency: purchaseCurrency ?? this.purchaseCurrency,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      serviceIntervalDays: serviceIntervalDays ?? this.serviceIntervalDays,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      attributes: attributes ?? this.attributes,
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
    status,
    purchaseDate,
    purchasePrice,
    purchaseCurrency,
    lastServiceDate,
    serviceIntervalDays,
    notes,
    isActive,
    attributes,
    customReminderEnabled,
    customReminderDays,
    createdAt,
  ];
}

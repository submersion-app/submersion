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

  /// The item this one is installed in (v202). Null for a standalone item.
  final String? parentEquipmentId;

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
    this.parentEquipmentId,
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

  /// When a child item was installed in its parent; the parent's dives on or
  /// after this date count for the child.
  DateTime? get installedDate {
    final ms = attrNum(EquipmentAttrKeys.installedDate);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms.round());
  }

  /// From when a child inherits its parent's dives: its install date, or
  /// its creation when none is set (the design's attribute catalog). Every
  /// exposure read for a child goes through this, so the clocks, the
  /// condition engine and the charts all count the same dives.
  ///
  /// In the dive-time frame, because the exposure SQL compares it with
  /// `dive_date_time`, which holds wall-clock time as UTC. The install date
  /// is a local calendar day (the date picker stores local midnight;
  /// replacing a child stores the local moment), so it becomes that day's
  /// midnight in UTC; the creation time is a local instant, so it becomes
  /// its wall clock in UTC. Comparing the raw instants shifted the boundary
  /// by the device's UTC offset, counting dives from the evening before east
  /// of UTC and dropping the install day's early dives west of it.
  DateTime? get parentDivesFrom {
    final installed = installedDate;
    if (installed != null) {
      return DateTime.utc(installed.year, installed.month, installed.day);
    }
    final created = createdAt;
    if (created == null || created.isUtc) return created;
    return DateTime.utc(
      created.year,
      created.month,
      created.day,
      created.hour,
      created.minute,
      created.second,
      created.millisecond,
      created.microsecond,
    );
  }

  /// Still in service: active, and not carrying a terminal status. Older
  /// rows can be retired or sold with isActive left true, and the
  /// repository's own active-gear queries treat both statuses as gone.
  bool get isFitted =>
      isActive &&
      status != EquipmentStatus.retired &&
      status != EquipmentStatus.sold;

  /// Wing/BCD rated lift capacity in kg (curated attribute; see the BCD entry
  /// in [EquipmentAttributeCatalog]). Feeds the buoyancy twin's peak-lift
  /// demand comparison; null when unspecified.
  double? get liftCapacityKg => attrNum(EquipmentAttrKeys.liftCapacityKg);

  /// Cylinder specs (curated tank attributes). Null when unspecified.
  double? get volumeL => attrNum(EquipmentAttrKeys.volumeL);
  double? get workingPressureBar =>
      attrNum(EquipmentAttrKeys.workingPressureBar);

  /// The catalog stores the choice key ('aluminum', 'steel',
  /// 'carbon_composite'); the enum name for the last one differs.
  TankMaterial? get tankMaterial =>
      switch (attrText(EquipmentAttrKeys.tankMaterial)) {
        'aluminum' => TankMaterial.aluminum,
        'steel' => TankMaterial.steel,
        'carbon_composite' => TankMaterial.carbonFiber,
        _ => null,
      };

  /// Purchase record (issue #1517): the manufacturer or retailer SKU, who it
  /// was bought from, and the product/receipt listing. Null when unrecorded.
  String? get sku => attrText(EquipmentAttrKeys.sku);
  String? get retailer => attrText(EquipmentAttrKeys.retailer);
  String? get productUrl => attrText(EquipmentAttrKeys.productUrl);

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
    String? parentEquipmentId,
    bool clearParentEquipmentId = false,
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
      parentEquipmentId: clearParentEquipmentId
          ? null
          : (parentEquipmentId ?? this.parentEquipmentId),
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
    parentEquipmentId,
    createdAt,
  ];
}

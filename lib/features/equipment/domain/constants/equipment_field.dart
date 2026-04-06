import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// Enumeration of every field from the [EquipmentItem] entity that can appear
/// in table or card views.
///
/// Note: the item name field is called [itemName] (not `name`) to avoid
/// conflicting with Dart's built-in [Enum.name] property, which already
/// satisfies [EntityField.name].
enum EquipmentField implements EntityField {
  // Core
  itemName,
  fullName,
  type,
  brand,
  model,

  // Details
  serialNumber,
  size,
  status,
  isActive,

  // Purchase
  purchaseDate,
  purchasePrice,

  // Service
  lastServiceDate,
  nextServiceDue,
  daysUntilService,
  serviceIntervalDays,

  // Other
  notes;

  @override
  String get name => toString().split('.').last;

  @override
  String get displayName => switch (this) {
    EquipmentField.itemName => 'Name',
    EquipmentField.fullName => 'Full Name',
    EquipmentField.type => 'Type',
    EquipmentField.brand => 'Brand',
    EquipmentField.model => 'Model',
    EquipmentField.serialNumber => 'Serial Number',
    EquipmentField.size => 'Size',
    EquipmentField.status => 'Status',
    EquipmentField.isActive => 'Active',
    EquipmentField.purchaseDate => 'Purchase Date',
    EquipmentField.purchasePrice => 'Purchase Price',
    EquipmentField.lastServiceDate => 'Last Service',
    EquipmentField.nextServiceDue => 'Next Service Due',
    EquipmentField.daysUntilService => 'Days Until Service',
    EquipmentField.serviceIntervalDays => 'Service Interval',
    EquipmentField.notes => 'Notes',
  };

  @override
  String get shortLabel => switch (this) {
    EquipmentField.itemName => 'Name',
    EquipmentField.fullName => 'Full Name',
    EquipmentField.type => 'Type',
    EquipmentField.brand => 'Brand',
    EquipmentField.model => 'Model',
    EquipmentField.serialNumber => 'Serial #',
    EquipmentField.size => 'Size',
    EquipmentField.status => 'Status',
    EquipmentField.isActive => 'Active',
    EquipmentField.purchaseDate => 'Purchased',
    EquipmentField.purchasePrice => 'Price',
    EquipmentField.lastServiceDate => 'Serviced',
    EquipmentField.nextServiceDue => 'Next Svc',
    EquipmentField.daysUntilService => 'Days Left',
    EquipmentField.serviceIntervalDays => 'Interval',
    EquipmentField.notes => 'Notes',
  };

  @override
  IconData? get icon => switch (this) {
    EquipmentField.itemName => Icons.label,
    EquipmentField.fullName => Icons.badge,
    EquipmentField.type => Icons.category,
    EquipmentField.brand => Icons.business,
    EquipmentField.model => Icons.info_outline,
    EquipmentField.serialNumber => Icons.pin,
    EquipmentField.size => Icons.straighten,
    EquipmentField.status => Icons.circle,
    EquipmentField.isActive => Icons.check_circle_outline,
    EquipmentField.purchaseDate => Icons.calendar_today,
    EquipmentField.purchasePrice => Icons.attach_money,
    EquipmentField.lastServiceDate => Icons.build,
    EquipmentField.nextServiceDue => Icons.event,
    EquipmentField.daysUntilService => Icons.timelapse,
    EquipmentField.serviceIntervalDays => Icons.repeat,
    EquipmentField.notes => Icons.notes,
  };

  @override
  double get defaultWidth => switch (this) {
    EquipmentField.itemName => 150,
    EquipmentField.fullName => 180,
    EquipmentField.type => 100,
    EquipmentField.brand => 100,
    EquipmentField.model => 100,
    EquipmentField.serialNumber => 110,
    EquipmentField.size => 70,
    EquipmentField.status => 90,
    EquipmentField.isActive => 70,
    EquipmentField.purchaseDate => 100,
    EquipmentField.purchasePrice => 90,
    EquipmentField.lastServiceDate => 100,
    EquipmentField.nextServiceDue => 100,
    EquipmentField.daysUntilService => 80,
    EquipmentField.serviceIntervalDays => 80,
    EquipmentField.notes => 150,
  };

  @override
  double get minWidth => switch (this) {
    EquipmentField.itemName => 80,
    EquipmentField.fullName => 100,
    EquipmentField.type => 60,
    EquipmentField.brand => 60,
    EquipmentField.model => 60,
    EquipmentField.serialNumber => 70,
    EquipmentField.size => 50,
    EquipmentField.status => 60,
    EquipmentField.isActive => 50,
    EquipmentField.purchaseDate => 70,
    EquipmentField.purchasePrice => 60,
    EquipmentField.lastServiceDate => 70,
    EquipmentField.nextServiceDue => 70,
    EquipmentField.daysUntilService => 60,
    EquipmentField.serviceIntervalDays => 60,
    EquipmentField.notes => 80,
  };

  @override
  bool get sortable => switch (this) {
    EquipmentField.itemName => true,
    EquipmentField.fullName => true,
    EquipmentField.type => true,
    EquipmentField.brand => true,
    EquipmentField.model => true,
    EquipmentField.serialNumber => true,
    EquipmentField.size => true,
    EquipmentField.status => true,
    EquipmentField.isActive => true,
    EquipmentField.purchaseDate => true,
    EquipmentField.purchasePrice => true,
    EquipmentField.lastServiceDate => true,
    EquipmentField.nextServiceDue => true,
    EquipmentField.daysUntilService => true,
    EquipmentField.serviceIntervalDays => true,
    EquipmentField.notes => false,
  };

  @override
  String get categoryName => switch (this) {
    EquipmentField.itemName => 'core',
    EquipmentField.fullName => 'core',
    EquipmentField.type => 'core',
    EquipmentField.brand => 'core',
    EquipmentField.model => 'core',
    EquipmentField.serialNumber => 'details',
    EquipmentField.size => 'details',
    EquipmentField.status => 'details',
    EquipmentField.isActive => 'details',
    EquipmentField.purchaseDate => 'purchase',
    EquipmentField.purchasePrice => 'purchase',
    EquipmentField.lastServiceDate => 'service',
    EquipmentField.nextServiceDue => 'service',
    EquipmentField.daysUntilService => 'service',
    EquipmentField.serviceIntervalDays => 'service',
    EquipmentField.notes => 'other',
  };

  @override
  bool get isRightAligned => switch (this) {
    EquipmentField.purchasePrice => true,
    EquipmentField.daysUntilService => true,
    _ => false,
  };
}

/// Adapter bridging [EquipmentItem] entities with [EquipmentField] for the
/// generic table infrastructure.
class EquipmentFieldAdapter
    extends EntityFieldAdapter<EquipmentItem, EquipmentField> {
  static final instance = EquipmentFieldAdapter._();
  EquipmentFieldAdapter._();

  static const List<EquipmentField> _allFields = EquipmentField.values;

  static final Map<String, List<EquipmentField>> _fieldsByCategory = () {
    final map = <String, List<EquipmentField>>{};
    for (final f in _allFields) {
      map.putIfAbsent(f.categoryName, () => []).add(f);
    }
    return map;
  }();

  @override
  List<EquipmentField> get allFields => _allFields;

  @override
  Map<String, List<EquipmentField>> get fieldsByCategory => _fieldsByCategory;

  @override
  dynamic extractValue(EquipmentField field, EquipmentItem entity) {
    return switch (field) {
      EquipmentField.itemName => entity.name,
      EquipmentField.fullName => entity.fullName,
      EquipmentField.type => entity.type,
      EquipmentField.brand => entity.brand,
      EquipmentField.model => entity.model,
      EquipmentField.serialNumber => entity.serialNumber,
      EquipmentField.size => entity.size,
      EquipmentField.status => entity.status,
      EquipmentField.isActive => entity.isActive,
      EquipmentField.purchaseDate => entity.purchaseDate,
      EquipmentField.purchasePrice => entity.purchasePrice,
      EquipmentField.lastServiceDate => entity.lastServiceDate,
      EquipmentField.nextServiceDue => entity.nextServiceDue,
      EquipmentField.daysUntilService => entity.daysUntilService,
      EquipmentField.serviceIntervalDays => entity.serviceIntervalDays,
      EquipmentField.notes => entity.notes,
    };
  }

  @override
  String formatValue(EquipmentField field, dynamic value, UnitFormatter units) {
    if (value == null) return '--';
    return switch (field) {
      EquipmentField.itemName => value as String,
      EquipmentField.fullName => value as String,
      EquipmentField.type => (value as EquipmentType).displayName,
      EquipmentField.brand => value as String,
      EquipmentField.model => value as String,
      EquipmentField.serialNumber => value as String,
      EquipmentField.size => value as String,
      EquipmentField.status => (value as EquipmentStatus).displayName,
      EquipmentField.isActive => (value as bool) ? 'Yes' : 'No',
      EquipmentField.purchaseDate => units.formatDate(value as DateTime),
      EquipmentField.purchasePrice => _formatPrice(value as double),
      EquipmentField.lastServiceDate => units.formatDate(value as DateTime),
      EquipmentField.nextServiceDue => units.formatDate(value as DateTime),
      EquipmentField.daysUntilService => _formatDaysUntilService(value as int),
      EquipmentField.serviceIntervalDays => '${value as int} days',
      EquipmentField.notes => value as String,
    };
  }

  String _formatPrice(double price) {
    return NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(price);
  }

  String _formatDaysUntilService(int days) {
    if (days < 0) return 'Overdue';
    return '$days days';
  }

  @override
  EquipmentField fieldFromName(String name) {
    return EquipmentField.values.firstWhere((e) => e.name == name);
  }
}

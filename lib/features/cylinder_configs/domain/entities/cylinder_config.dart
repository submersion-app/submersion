import 'package:equatable/equatable.dart';

import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';

/// A named, reusable set of cylinders.
///
/// When [equipmentId] is set the config reads as "a configuration for this
/// rebreather"; when null it is a generic gas plan any dive can use. The
/// distinction is presentation only -- the two share one shape, which is why
/// a technical open-circuit diver entering doubles plus two deco stages gets
/// the same relief from re-entry tedium as a CCR diver.
///
/// Deleting the owning unit sets equipment_id null rather than cascading,
/// demoting the config instead of destroying a painstakingly entered bailout
/// plan.
class CylinderConfig extends Equatable {
  final String id;
  final String? diverId;
  final String? equipmentId;
  final String name;
  final String description;
  final int sortOrder;
  final List<CylinderConfigItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CylinderConfig({
    required this.id,
    this.diverId,
    this.equipmentId,
    required this.name,
    this.description = '',
    this.sortOrder = 0,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOwnedByUnit => equipmentId != null;

  int get cylinderCount => items.length;

  CylinderConfig copyWith({
    String? id,
    String? diverId,
    bool clearDiverId = false,
    String? equipmentId,
    bool clearEquipmentId = false,
    String? name,
    String? description,
    int? sortOrder,
    List<CylinderConfigItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CylinderConfig(
    id: id ?? this.id,
    diverId: clearDiverId ? null : (diverId ?? this.diverId),
    equipmentId: clearEquipmentId ? null : (equipmentId ?? this.equipmentId),
    name: name ?? this.name,
    description: description ?? this.description,
    sortOrder: sortOrder ?? this.sortOrder,
    items: items ?? this.items,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Timestamps are excluded: they churn on every write and would defeat
  /// Riverpod's equality-based rebuild suppression. Mirrors EquipmentSet.
  @override
  List<Object?> get props => [
    id,
    diverId,
    equipmentId,
    name,
    description,
    sortOrder,
    items,
  ];
}

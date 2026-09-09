import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// One part of an assembly: the row that says [componentEquipmentId] is a
/// component of [parentEquipmentId], in what [role] and at what position.
///
/// An assembly is any equipment item with at least one of these rows; there
/// is no assembly type. A part may sit in several assemblies' templates (the
/// same second stage under a DIN reg and a yoke reg): the template says what
/// can be assembled, and the dive snapshot records what was.
class EquipmentComponent extends Equatable {
  final String id;
  final String parentEquipmentId;
  final String componentEquipmentId;

  /// Free text such as "Primary second stage"; empty when unset.
  final String role;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The part itself, hydrated by reads that join it; null on bare rows.
  final EquipmentItem? component;

  const EquipmentComponent({
    required this.id,
    required this.parentEquipmentId,
    required this.componentEquipmentId,
    this.role = '',
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.component,
  });

  EquipmentComponent copyWith({
    String? id,
    String? parentEquipmentId,
    String? componentEquipmentId,
    String? role,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    EquipmentItem? component,
  }) => EquipmentComponent(
    id: id ?? this.id,
    parentEquipmentId: parentEquipmentId ?? this.parentEquipmentId,
    componentEquipmentId: componentEquipmentId ?? this.componentEquipmentId,
    role: role ?? this.role,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    component: component ?? this.component,
  );

  @override
  List<Object?> get props => [
    id,
    parentEquipmentId,
    componentEquipmentId,
    role,
    sortOrder,
    createdAt,
    updatedAt,
    component,
  ];
}

import 'package:equatable/equatable.dart';

import 'equipment_item.dart';

/// A named collection of equipment items
class EquipmentSet extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final String description;
  final List<String> equipmentIds;
  final List<EquipmentItem>? items; // Populated when fetched with items
  final DateTime createdAt;
  final DateTime updatedAt;

  const EquipmentSet({
    required this.id,
    this.diverId,
    required this.name,
    this.description = '',
    this.equipmentIds = const [],
    this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Number of items in this set
  int get itemCount => equipmentIds.length;

  /// Check if set contains a specific equipment item
  bool containsEquipment(String equipmentId) {
    return equipmentIds.contains(equipmentId);
  }

  EquipmentSet copyWith({
    String? id,
    String? diverId,
    String? name,
    String? description,
    List<String>? equipmentIds,
    List<EquipmentItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EquipmentSet(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      description: description ?? this.description,
      equipmentIds: equipmentIds ?? this.equipmentIds,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, diverId, name, description, equipmentIds, createdAt, updatedAt];
}

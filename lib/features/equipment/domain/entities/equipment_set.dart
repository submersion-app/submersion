import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

/// A named collection of equipment items
class EquipmentSet extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final String description;
  final List<String> equipmentIds;
  final List<EquipmentItem>? items; // Populated when fetched with items
  final bool isDefault;
  final List<EquipmentSetGeofence> geofences; // Populated when fetched
  final DateTime createdAt;
  final DateTime updatedAt;

  const EquipmentSet({
    required this.id,
    this.diverId,
    required this.name,
    this.description = '',
    this.equipmentIds = const [],
    this.items,
    this.isDefault = false,
    this.geofences = const [],
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
    bool? isDefault,
    List<EquipmentSetGeofence>? geofences,
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
      isDefault: isDefault ?? this.isDefault,
      geofences: geofences ?? this.geofences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    description,
    equipmentIds,
    isDefault,
    geofences,
    createdAt,
    updatedAt,
  ];
}

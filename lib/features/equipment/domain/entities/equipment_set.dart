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

  /// Populated when fetched with items: the set's EFFECTIVE gear, its own
  /// plus that of the sets it includes. [equipmentIds] stays the set's own.
  final List<EquipmentItem>? items;

  /// Other sets this set includes, in order (issue #4525). One level: a
  /// set that includes sets is never itself included.
  final List<String> includedSetIds;

  /// Weight presets applied with the set's gear, in order.
  final List<String> weightPresetIds;

  /// Cylinder configurations applied with the set's gear, in order.
  final List<String> cylinderConfigIds;
  final bool isDefault;

  /// Whether this set is auto-applied to a dive whose computer is a member
  /// of it (issue #1020). Opt-in, off by default.
  final bool autoApplyOnComputerImport;

  /// Whether the set page draws this set's gear on the diver figure
  /// (issue #2326). On by default (issue #3889); a diver can hide it.
  final bool showFigure;
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
    this.includedSetIds = const [],
    this.weightPresetIds = const [],
    this.cylinderConfigIds = const [],
    this.isDefault = false,
    this.autoApplyOnComputerImport = false,
    this.showFigure = true,
    this.geofences = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether the set applies anything besides its own gear: other sets,
  /// weights or tanks (issue #4525).
  bool get carriesBeyondGear =>
      includedSetIds.isNotEmpty ||
      weightPresetIds.isNotEmpty ||
      cylinderConfigIds.isNotEmpty;

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
    List<String>? includedSetIds,
    List<String>? weightPresetIds,
    List<String>? cylinderConfigIds,
    bool? isDefault,
    bool? autoApplyOnComputerImport,
    bool? showFigure,
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
      includedSetIds: includedSetIds ?? this.includedSetIds,
      weightPresetIds: weightPresetIds ?? this.weightPresetIds,
      cylinderConfigIds: cylinderConfigIds ?? this.cylinderConfigIds,
      isDefault: isDefault ?? this.isDefault,
      autoApplyOnComputerImport:
          autoApplyOnComputerImport ?? this.autoApplyOnComputerImport,
      showFigure: showFigure ?? this.showFigure,
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
    includedSetIds,
    weightPresetIds,
    cylinderConfigIds,
    isDefault,
    autoApplyOnComputerImport,
    showFigure,
    geofences,
    createdAt,
    updatedAt,
  ];
}

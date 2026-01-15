import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/constants/tank_presets.dart';

/// Domain entity for tank presets (both built-in and custom)
class TankPresetEntity extends Equatable {
  final String id;
  final String? diverId; // null for built-in presets
  final String name; // Internal name/identifier
  final String displayName; // User-friendly display name
  final double volumeLiters; // Water volume in liters
  final int workingPressureBar; // Rated working pressure in bar
  final TankMaterial material;
  final String description;
  final int sortOrder;
  final bool isBuiltIn; // true for system presets
  final DateTime createdAt;
  final DateTime updatedAt;

  const TankPresetEntity({
    required this.id,
    this.diverId,
    required this.name,
    required this.displayName,
    required this.volumeLiters,
    required this.workingPressureBar,
    required this.material,
    this.description = '',
    this.sortOrder = 0,
    this.isBuiltIn = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Calculate gas capacity in cubic feet (imperial tank size rating)
  /// Formula: (water_volume_liters * working_pressure_bar) / 28.3168
  double get volumeCuft => (volumeLiters * workingPressureBar) / 28.3168;

  /// Create from a built-in TankPreset constant
  factory TankPresetEntity.fromBuiltIn(TankPreset preset) {
    final fixedDate = DateTime(2024, 1, 1);
    return TankPresetEntity(
      id: preset.name,
      name: preset.name,
      displayName: preset.displayName,
      volumeLiters: preset.volumeLiters,
      workingPressureBar: preset.workingPressureBar,
      material: preset.material,
      description: preset.description ?? '',
      isBuiltIn: true,
      createdAt: fixedDate,
      updatedAt: fixedDate,
    );
  }

  /// Create a new custom tank preset
  factory TankPresetEntity.create({
    required String id,
    required String name,
    required String displayName,
    required double volumeLiters,
    required int workingPressureBar,
    required TankMaterial material,
    String? diverId,
    String description = '',
    int sortOrder = 0,
  }) {
    final now = DateTime.now();
    return TankPresetEntity(
      id: id,
      diverId: diverId,
      name: name,
      displayName: displayName,
      volumeLiters: volumeLiters,
      workingPressureBar: workingPressureBar,
      material: material,
      description: description,
      sortOrder: sortOrder,
      isBuiltIn: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Generate a slug from a display name
  static String generateSlug(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  TankPresetEntity copyWith({
    String? id,
    String? diverId,
    String? name,
    String? displayName,
    double? volumeLiters,
    int? workingPressureBar,
    TankMaterial? material,
    String? description,
    int? sortOrder,
    bool? isBuiltIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TankPresetEntity(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      volumeLiters: volumeLiters ?? this.volumeLiters,
      workingPressureBar: workingPressureBar ?? this.workingPressureBar,
      material: material ?? this.material,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    displayName,
    volumeLiters,
    workingPressureBar,
    material,
    description,
    sortOrder,
    isBuiltIn,
    createdAt,
    updatedAt,
  ];
}

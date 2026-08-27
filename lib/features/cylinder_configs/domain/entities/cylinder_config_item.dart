import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// One cylinder in a reusable configuration.
///
/// The cylinder spec is a SNAPSHOT, not a reference. A tank preset may
/// populate volume/pressure/material at edit time, but the config then owns
/// those values and there is deliberately no foreign key back to
/// tank_presets. A configuration records what the diver actually dives, so a
/// later edit to a preset must not rewrite the meaning of a saved config.
class CylinderConfigItem extends Equatable {
  final String id;
  final String configId;
  final int sortOrder;

  /// Free-text label such as "Bailout 1" or "AL80 EAN50". Maps to
  /// dive_tanks.tank_name when the configuration is applied.
  final String? label;

  final TankRole tankRole;
  final double? volumeL;
  final double? workingPressureBar;
  final TankMaterial? tankMaterial;

  /// Gas fractions are never null: a cylinder always holds something, and
  /// air is the sensible floor. This mirrors dive_tanks, where o2_percent
  /// and he_percent carry non-null defaults.
  final double o2Percent;
  final double hePercent;

  final double? defaultStartPressureBar;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CylinderConfigItem({
    required this.id,
    required this.configId,
    this.sortOrder = 0,
    this.label,
    required this.tankRole,
    this.volumeL,
    this.workingPressureBar,
    this.tankMaterial,
    this.o2Percent = 21,
    this.hePercent = 0,
    this.defaultStartPressureBar,
    required this.createdAt,
    required this.updatedAt,
  });

  CylinderConfigItem copyWith({
    String? id,
    String? configId,
    int? sortOrder,
    String? label,
    bool clearLabel = false,
    TankRole? tankRole,
    double? volumeL,
    bool clearVolumeL = false,
    double? workingPressureBar,
    bool clearWorkingPressureBar = false,
    TankMaterial? tankMaterial,
    bool clearTankMaterial = false,
    double? o2Percent,
    double? hePercent,
    double? defaultStartPressureBar,
    bool clearDefaultStartPressureBar = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CylinderConfigItem(
    id: id ?? this.id,
    configId: configId ?? this.configId,
    sortOrder: sortOrder ?? this.sortOrder,
    label: clearLabel ? null : (label ?? this.label),
    tankRole: tankRole ?? this.tankRole,
    volumeL: clearVolumeL ? null : (volumeL ?? this.volumeL),
    workingPressureBar: clearWorkingPressureBar
        ? null
        : (workingPressureBar ?? this.workingPressureBar),
    tankMaterial: clearTankMaterial
        ? null
        : (tankMaterial ?? this.tankMaterial),
    o2Percent: o2Percent ?? this.o2Percent,
    hePercent: hePercent ?? this.hePercent,
    defaultStartPressureBar: clearDefaultStartPressureBar
        ? null
        : (defaultStartPressureBar ?? this.defaultStartPressureBar),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Timestamps are excluded: they churn on every write and would defeat
  /// Riverpod's equality-based rebuild suppression. Mirrors EquipmentSet.
  @override
  List<Object?> get props => [
    id,
    configId,
    sortOrder,
    label,
    tankRole,
    volumeL,
    workingPressureBar,
    tankMaterial,
    o2Percent,
    hePercent,
    defaultStartPressureBar,
  ];
}

import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// One registered air-integration transmitter and the cylinder it feeds.
///
/// Identity is the transmitter serial the dive computer reports, or, for
/// parsers that report none, the (dive computer, channel index) pair. The
/// spec fields are a snapshot copied from a preset or a gear cylinder at edit
/// time; a later preset edit never rewrites an entry.
class Transmitter extends Equatable {
  final String id;
  final String? diverId;
  final String? transmitterSerial;
  final String? diveComputerId;
  final int? channelIndex;
  final String label;
  final TankRole role;
  final double? volumeL;
  final double? workingPressureBar;
  final TankMaterial? material;
  final String? presetName;
  final String? equipmentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transmitter({
    required this.id,
    this.diverId,
    this.transmitterSerial,
    this.diveComputerId,
    this.channelIndex,
    required this.label,
    this.role = TankRole.backGas,
    this.volumeL,
    this.workingPressureBar,
    this.material,
    this.presetName,
    this.equipmentId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasSerial =>
      transmitterSerial != null && transmitterSerial!.isNotEmpty;

  bool get hasChannel => diveComputerId != null && channelIndex != null;

  Transmitter copyWith({
    String? id,
    String? diverId,
    bool clearDiverId = false,
    String? transmitterSerial,
    bool clearTransmitterSerial = false,
    String? diveComputerId,
    bool clearDiveComputerId = false,
    int? channelIndex,
    bool clearChannelIndex = false,
    String? label,
    TankRole? role,
    double? volumeL,
    bool clearVolumeL = false,
    double? workingPressureBar,
    bool clearWorkingPressureBar = false,
    TankMaterial? material,
    bool clearMaterial = false,
    String? presetName,
    bool clearPresetName = false,
    String? equipmentId,
    bool clearEquipmentId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Transmitter(
    id: id ?? this.id,
    diverId: clearDiverId ? null : (diverId ?? this.diverId),
    transmitterSerial: clearTransmitterSerial
        ? null
        : (transmitterSerial ?? this.transmitterSerial),
    diveComputerId: clearDiveComputerId
        ? null
        : (diveComputerId ?? this.diveComputerId),
    channelIndex: clearChannelIndex
        ? null
        : (channelIndex ?? this.channelIndex),
    label: label ?? this.label,
    role: role ?? this.role,
    volumeL: clearVolumeL ? null : (volumeL ?? this.volumeL),
    workingPressureBar: clearWorkingPressureBar
        ? null
        : (workingPressureBar ?? this.workingPressureBar),
    material: clearMaterial ? null : (material ?? this.material),
    presetName: clearPresetName ? null : (presetName ?? this.presetName),
    equipmentId: clearEquipmentId ? null : (equipmentId ?? this.equipmentId),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Timestamps are excluded: they churn on every write and would defeat
  /// Riverpod's equality-based rebuild suppression. Mirrors CylinderConfig.
  @override
  List<Object?> get props => [
    id,
    diverId,
    transmitterSerial,
    diveComputerId,
    channelIndex,
    label,
    role,
    volumeL,
    workingPressureBar,
    material,
    presetName,
    equipmentId,
  ];
}

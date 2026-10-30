import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

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

  /// The transmitter gear item this entry is, beside [equipmentId], the
  /// cylinder it feeds (condition phase 3b). The dropout rules read an
  /// item's serials through it.
  final String? transmitterEquipmentId;

  /// False for an entry the app created from a download and the diver has
  /// not saved yet (issue #3676).
  final bool isConfigured;
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
    this.transmitterEquipmentId,
    this.isConfigured = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether the entry carries a usable serial in the canonical sense: a
  /// whitespace-only or all-zero value counts as none, matching how the
  /// matcher and the repository treat it.
  bool get hasSerial => normalizeTransmitterSerial(transmitterSerial) != null;

  bool get hasChannel => diveComputerId != null && channelIndex != null;

  /// Whether the diver set this transmitter up (issue #3676): saved it, and
  /// named the cylinder it feeds by a gear link or a size. A transmitter that
  /// is not set up is what the unknown-transmitter nudge asks about.
  bool get isSetUp =>
      isConfigured && (equipmentId != null || (volumeL ?? 0) > 0);

  /// The canonical serials of [entries], for membership checks against tank
  /// serials that are normalized the same way. Rows can arrive raw through a
  /// sync payload, so the repository's write-time normalization is not
  /// enough on its own; blank and all-zero values are dropped here too.
  static Set<String> knownSerials(Iterable<Transmitter> entries) => {
    for (final t in entries) ?normalizeTransmitterSerial(t.transmitterSerial),
  };

  /// The canonical serials of the entries in [entries] that are set up.
  static Set<String> setUpSerials(Iterable<Transmitter> entries) => {
    for (final t in entries)
      if (t.isSetUp) ?normalizeTransmitterSerial(t.transmitterSerial),
  };

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
    String? transmitterEquipmentId,
    bool clearTransmitterEquipmentId = false,
    bool? isConfigured,
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
    transmitterEquipmentId: clearTransmitterEquipmentId
        ? null
        : (transmitterEquipmentId ?? this.transmitterEquipmentId),
    isConfigured: isConfigured ?? this.isConfigured,
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
    transmitterEquipmentId,
    isConfigured,
  ];
}

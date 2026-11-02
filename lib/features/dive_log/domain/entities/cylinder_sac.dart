import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// SAC calculation result for a single cylinder/tank.
///
/// This entity holds the Surface Air Consumption (SAC) rate calculated
/// for a specific tank during a dive. It supports both basic calculations
/// (from start/end pressures) and enhanced calculations (from time-series
/// pressure data when available from AI transmitters).
class CylinderSac extends Equatable {
  /// Tank ID from the dive_tanks table
  final String tankId;

  /// User-friendly tank name (e.g., "AL80", "Stage EAN50")
  final String? tankName;

  /// Gas mix used in this tank
  final GasMix gasMix;

  /// Role of this tank (back gas, stage, deco, etc.)
  final TankRole role;

  /// Tank volume in liters (required for the per-cylinder RMV, [rmv])
  final double? tankVolume;

  /// SAC rate in bar/min at surface
  final double? sacRate;

  /// RMV for this cylinder in L/min at surface (computed if tankVolume
  /// available).
  ///
  /// [sacRate] is bar/min against a 1 bar reference, so scaling it by the
  /// cylinder's size is the whole conversion. Dividing by the standard
  /// atmosphere as well shaved 1.3% off this readout while the dive's
  /// headline value used a different reference (issue #828).
  double? get rmv =>
      sacRate != null && tankVolume != null ? sacRate! * tankVolume! : null;

  /// Surface liters per minute of loop time on a CCR dive, with no depth
  /// correction: O2 and diluent use do not scale with ambient pressure the way
  /// open-circuit breathing does (issue #4082). Null off the loop.
  final double? loopRate;

  /// Start pressure in bar
  final double? startPressure;

  /// End pressure in bar
  final double? endPressure;

  /// Equation of state behind [gasUsedLiters], the one the rates here used.
  final GasModel gasModel;

  /// Total gas used in liters (if tankVolume known), under [gasModel], so it
  /// agrees with [loopRate] and [rmv] (issue #828).
  double? get gasUsedLiters {
    final start = startPressure;
    final end = endPressure;
    final volume = tankVolume;
    if (start == null || end == null || volume == null) return null;
    return gasVolumeBetween(
      tankSizeLiters: volume,
      startBar: start,
      endBar: end,
      o2Percent: gasMix.o2,
      hePercent: gasMix.he,
      model: gasModel,
    );
  }

  /// Duration this tank was actively used
  final Duration? usageDuration;

  /// Average depth while this tank was in use (meters)
  final double? avgDepthDuringUse;

  /// Whether this calculation used time-series pressure data (more accurate)
  final bool hasTimeSeriesData;

  /// Order of this tank in the dive (for display)
  final int order;

  const CylinderSac({
    required this.tankId,
    this.tankName,
    required this.gasMix,
    required this.role,
    this.tankVolume,
    this.sacRate,
    this.loopRate,
    this.startPressure,
    this.endPressure,
    this.gasModel = GasModel.ideal,
    this.usageDuration,
    this.avgDepthDuringUse,
    this.hasTimeSeriesData = false,
    this.order = 0,
  });

  /// Whether we have enough data to calculate SAC
  bool get hasValidSac => sacRate != null && sacRate! > 0;

  /// Formatted duration string (MM:SS)
  String get durationFormatted {
    if (usageDuration == null) return '--:--';
    final minutes = usageDuration!.inMinutes;
    final seconds = usageDuration!.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Display label combining tank name and gas mix
  String get displayLabel {
    if (tankName != null && tankName!.isNotEmpty) {
      return tankName!;
    }
    return '${role.displayName} (${gasMix.name})';
  }

  CylinderSac copyWith({
    String? tankId,
    String? tankName,
    GasMix? gasMix,
    TankRole? role,
    double? tankVolume,
    double? sacRate,
    double? loopRate,
    double? startPressure,
    double? endPressure,
    GasModel? gasModel,
    Duration? usageDuration,
    double? avgDepthDuringUse,
    bool? hasTimeSeriesData,
    int? order,
  }) {
    return CylinderSac(
      tankId: tankId ?? this.tankId,
      tankName: tankName ?? this.tankName,
      gasMix: gasMix ?? this.gasMix,
      role: role ?? this.role,
      tankVolume: tankVolume ?? this.tankVolume,
      sacRate: sacRate ?? this.sacRate,
      loopRate: loopRate ?? this.loopRate,
      startPressure: startPressure ?? this.startPressure,
      endPressure: endPressure ?? this.endPressure,
      gasModel: gasModel ?? this.gasModel,
      usageDuration: usageDuration ?? this.usageDuration,
      avgDepthDuringUse: avgDepthDuringUse ?? this.avgDepthDuringUse,
      hasTimeSeriesData: hasTimeSeriesData ?? this.hasTimeSeriesData,
      order: order ?? this.order,
    );
  }

  @override
  List<Object?> get props => [
    tankId,
    tankName,
    gasMix,
    role,
    tankVolume,
    sacRate,
    loopRate,
    startPressure,
    endPressure,
    gasModel,
    usageDuration,
    avgDepthDuringUse,
    hasTimeSeriesData,
    order,
  ];
}

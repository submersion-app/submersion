import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import 'dive.dart';

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

  /// Tank volume in liters (required for L/min SAC conversion)
  final double? tankVolume;

  /// SAC rate in bar/min at surface
  final double? sacRate;

  /// SAC rate in L/min at surface (computed if tankVolume available)
  double? get sacVolume =>
      sacRate != null && tankVolume != null ? sacRate! * tankVolume! : null;

  /// Start pressure in bar
  final int? startPressure;

  /// End pressure in bar
  final int? endPressure;

  /// Total gas used in bar
  int? get gasUsedBar => startPressure != null && endPressure != null
      ? startPressure! - endPressure!
      : null;

  /// Total gas used in liters (if tankVolume known)
  double? get gasUsedLiters => gasUsedBar != null && tankVolume != null
      ? gasUsedBar! * tankVolume!
      : null;

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
    this.startPressure,
    this.endPressure,
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
    int? startPressure,
    int? endPressure,
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
      startPressure: startPressure ?? this.startPressure,
      endPressure: endPressure ?? this.endPressure,
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
    startPressure,
    endPressure,
    usageDuration,
    avgDepthDuringUse,
    hasTimeSeriesData,
    order,
  ];
}

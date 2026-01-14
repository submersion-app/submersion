import 'package:equatable/equatable.dart';

import '../../../dive_log/domain/entities/dive.dart';

/// Types of segments in a dive plan.
///
/// Each segment represents a distinct phase of the planned dive:
/// - `descent`: Moving from surface to a deeper depth
/// - `bottom`: Time spent at a constant depth (the "working" phase)
/// - `ascent`: Moving from deeper to shallower depth
/// - `decoStop`: Mandatory decompression stop at a specific depth
/// - `gasSwitch`: Switching to a different gas mix (typically for deco)
/// - `safetyStop`: Optional safety stop (typically 3-5m for 3min)
enum SegmentType { descent, bottom, ascent, decoStop, gasSwitch, safetyStop }

/// A single segment in a dive plan.
///
/// Dive plans are composed of sequential segments that define the dive profile.
/// Each segment has a start depth, end depth, duration, and associated gas mix.
///
/// Example dive plan segments:
/// 1. Descent: 0m → 30m, 3 min, Air
/// 2. Bottom: 30m → 30m, 20 min, Air
/// 3. Ascent: 30m → 6m, 2.5 min, Air
/// 4. Gas Switch: 6m, Air → EAN50
/// 5. Deco Stop: 6m, 3 min, EAN50
/// 6. Ascent: 6m → 3m, 0.3 min, EAN50
/// 7. Safety/Deco Stop: 3m, 5 min, EAN50
/// 8. Ascent: 3m → 0m, 0.3 min, EAN50
class PlanSegment extends Equatable {
  /// Unique identifier for this segment.
  final String id;

  /// The type of segment (descent, bottom, ascent, etc.).
  final SegmentType type;

  /// Starting depth in meters.
  final double startDepth;

  /// Ending depth in meters.
  final double endDepth;

  /// Duration of this segment in seconds.
  final int durationSeconds;

  /// Reference to the tank being used for this segment.
  final String tankId;

  /// The gas mix being breathed during this segment.
  /// Stored directly for convenience, should match the referenced tank.
  final GasMix gasMix;

  /// Descent or ascent rate in meters per minute.
  /// Positive values indicate descent, negative indicate ascent.
  /// Only meaningful for descent/ascent segments.
  final double? rate;

  /// For gas switch segments, the new tank to switch to.
  final String? switchToTankId;

  /// Order of this segment in the plan (0-indexed).
  final int order;

  const PlanSegment({
    required this.id,
    required this.type,
    required this.startDepth,
    required this.endDepth,
    required this.durationSeconds,
    required this.tankId,
    required this.gasMix,
    this.rate,
    this.switchToTankId,
    this.order = 0,
  });

  /// Calculate the average depth of this segment.
  double get avgDepth => (startDepth + endDepth) / 2;

  /// Whether this segment involves a depth change.
  bool get isDepthChange => startDepth != endDepth;

  /// Calculate descent/ascent rate in m/min from segment parameters.
  /// Returns null if duration is zero.
  double? get calculatedRate {
    if (durationSeconds == 0) return null;
    final depthChange = endDepth - startDepth;
    return depthChange / (durationSeconds / 60);
  }

  /// Duration formatted as MM:SS.
  String get durationFormatted {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Human-readable description of this segment.
  String get description {
    switch (type) {
      case SegmentType.descent:
        return 'Descent ${startDepth.toStringAsFixed(0)}m → ${endDepth.toStringAsFixed(0)}m';
      case SegmentType.bottom:
        return 'Bottom ${startDepth.toStringAsFixed(0)}m for ${durationSeconds ~/ 60} min';
      case SegmentType.ascent:
        return 'Ascent ${startDepth.toStringAsFixed(0)}m → ${endDepth.toStringAsFixed(0)}m';
      case SegmentType.decoStop:
        return 'Deco ${startDepth.toStringAsFixed(0)}m for ${durationSeconds ~/ 60} min';
      case SegmentType.gasSwitch:
        return 'Gas switch to ${gasMix.name}';
      case SegmentType.safetyStop:
        return 'Safety stop ${startDepth.toStringAsFixed(0)}m for ${durationSeconds ~/ 60} min';
    }
  }

  /// Short label for display in lists.
  String get shortLabel {
    switch (type) {
      case SegmentType.descent:
        return '↓ ${endDepth.toStringAsFixed(0)}m';
      case SegmentType.bottom:
        return '● ${startDepth.toStringAsFixed(0)}m';
      case SegmentType.ascent:
        return '↑ ${endDepth.toStringAsFixed(0)}m';
      case SegmentType.decoStop:
        return '◆ ${startDepth.toStringAsFixed(0)}m';
      case SegmentType.gasSwitch:
        return '⇄ ${gasMix.name}';
      case SegmentType.safetyStop:
        return '○ ${startDepth.toStringAsFixed(0)}m';
    }
  }

  /// Create a copy with updated fields.
  PlanSegment copyWith({
    String? id,
    SegmentType? type,
    double? startDepth,
    double? endDepth,
    int? durationSeconds,
    String? tankId,
    GasMix? gasMix,
    double? rate,
    String? switchToTankId,
    int? order,
    bool clearSwitchToTankId = false,
  }) {
    return PlanSegment(
      id: id ?? this.id,
      type: type ?? this.type,
      startDepth: startDepth ?? this.startDepth,
      endDepth: endDepth ?? this.endDepth,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      tankId: tankId ?? this.tankId,
      gasMix: gasMix ?? this.gasMix,
      rate: rate ?? this.rate,
      switchToTankId: clearSwitchToTankId
          ? null
          : (switchToTankId ?? this.switchToTankId),
      order: order ?? this.order,
    );
  }

  /// Create a default descent segment.
  factory PlanSegment.descent({
    required String id,
    required double targetDepth,
    required String tankId,
    required GasMix gasMix,
    double rate = 18.0, // 18 m/min default descent rate
    int order = 0,
  }) {
    final durationSeconds = ((targetDepth / rate) * 60).round();
    return PlanSegment(
      id: id,
      type: SegmentType.descent,
      startDepth: 0,
      endDepth: targetDepth,
      durationSeconds: durationSeconds,
      tankId: tankId,
      gasMix: gasMix,
      rate: rate,
      order: order,
    );
  }

  /// Create a default bottom segment.
  factory PlanSegment.bottom({
    required String id,
    required double depth,
    required int durationMinutes,
    required String tankId,
    required GasMix gasMix,
    int order = 0,
  }) {
    return PlanSegment(
      id: id,
      type: SegmentType.bottom,
      startDepth: depth,
      endDepth: depth,
      durationSeconds: durationMinutes * 60,
      tankId: tankId,
      gasMix: gasMix,
      order: order,
    );
  }

  /// Create a default ascent segment.
  factory PlanSegment.ascent({
    required String id,
    required double fromDepth,
    required double toDepth,
    required String tankId,
    required GasMix gasMix,
    double rate = 9.0, // 9 m/min default ascent rate
    int order = 0,
  }) {
    final depthChange = fromDepth - toDepth;
    final durationSeconds = ((depthChange / rate) * 60).round();
    return PlanSegment(
      id: id,
      type: SegmentType.ascent,
      startDepth: fromDepth,
      endDepth: toDepth,
      durationSeconds: durationSeconds,
      tankId: tankId,
      gasMix: gasMix,
      rate: -rate, // Negative rate for ascent
      order: order,
    );
  }

  /// Create a deco stop segment.
  factory PlanSegment.decoStop({
    required String id,
    required double depth,
    required int durationMinutes,
    required String tankId,
    required GasMix gasMix,
    int order = 0,
  }) {
    return PlanSegment(
      id: id,
      type: SegmentType.decoStop,
      startDepth: depth,
      endDepth: depth,
      durationSeconds: durationMinutes * 60,
      tankId: tankId,
      gasMix: gasMix,
      order: order,
    );
  }

  /// Create a gas switch segment (typically instantaneous).
  factory PlanSegment.gasSwitch({
    required String id,
    required double depth,
    required String fromTankId,
    required String toTankId,
    required GasMix newGasMix,
    int order = 0,
  }) {
    return PlanSegment(
      id: id,
      type: SegmentType.gasSwitch,
      startDepth: depth,
      endDepth: depth,
      durationSeconds: 60, // 1 minute for gas switch
      tankId: toTankId,
      gasMix: newGasMix,
      switchToTankId: toTankId,
      order: order,
    );
  }

  /// Create a safety stop segment.
  factory PlanSegment.safetyStop({
    required String id,
    required String tankId,
    required GasMix gasMix,
    double depth = 5.0, // Default 5m
    int durationMinutes = 3, // Default 3 minutes
    int order = 0,
  }) {
    return PlanSegment(
      id: id,
      type: SegmentType.safetyStop,
      startDepth: depth,
      endDepth: depth,
      durationSeconds: durationMinutes * 60,
      tankId: tankId,
      gasMix: gasMix,
      order: order,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    startDepth,
    endDepth,
    durationSeconds,
    tankId,
    gasMix,
    rate,
    switchToTankId,
    order,
  ];
}

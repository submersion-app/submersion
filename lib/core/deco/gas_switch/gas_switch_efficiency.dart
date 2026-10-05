import 'package:equatable/equatable.dart';

/// How a deco gas switch fell short of the ideal ascent (issue #2939).
enum GasSwitchWindowKind {
  /// The diver switched, but past the depth or time tolerance.
  late,

  /// The diver never breathed the gas from the window's start onward.
  missed,
}

/// One flagged stretch where a richer eligible gas was carried but not
/// breathed. Timestamps are seconds from dive start; depths are metres.
class GasSwitchWindow extends Equatable {
  const GasSwitchWindow({
    required this.kind,
    required this.fO2,
    required this.fHe,
    required this.idealTimestamp,
    required this.idealDepth,
    this.switchTimestamp,
    this.switchDepth,
    required this.endTimestamp,
    required this.delaySeconds,
    this.depthDelayMeters,
    required this.extraDecoSeconds,
  });

  final GasSwitchWindowKind kind;

  /// Mix that should have been breathed.
  final double fO2;
  final double fHe;

  /// Where the ideal ascent would have switched.
  final int idealTimestamp;
  final double idealDepth;

  /// Where the diver did switch; null when missed.
  final int? switchTimestamp;
  final double? switchDepth;

  /// Last instant of the shaded window.
  final int endTimestamp;

  final int delaySeconds;

  /// How much shallower than ideal the switch happened; null when missed.
  final double? depthDelayMeters;

  /// Largest TTS gap the late switch caused (tissue replay).
  final int extraDecoSeconds;

  bool get isMissed => kind == GasSwitchWindowKind.missed;

  bool contains(int timestamp) =>
      timestamp >= idealTimestamp && timestamp <= endTimestamp;

  GasSwitchWindow copyWith({
    GasSwitchWindowKind? kind,
    double? fO2,
    double? fHe,
    int? idealTimestamp,
    double? idealDepth,
    int? switchTimestamp,
    double? switchDepth,
    int? endTimestamp,
    int? delaySeconds,
    double? depthDelayMeters,
    int? extraDecoSeconds,
  }) {
    return GasSwitchWindow(
      kind: kind ?? this.kind,
      fO2: fO2 ?? this.fO2,
      fHe: fHe ?? this.fHe,
      idealTimestamp: idealTimestamp ?? this.idealTimestamp,
      idealDepth: idealDepth ?? this.idealDepth,
      switchTimestamp: switchTimestamp ?? this.switchTimestamp,
      switchDepth: switchDepth ?? this.switchDepth,
      endTimestamp: endTimestamp ?? this.endTimestamp,
      delaySeconds: delaySeconds ?? this.delaySeconds,
      depthDelayMeters: depthDelayMeters ?? this.depthDelayMeters,
      extraDecoSeconds: extraDecoSeconds ?? this.extraDecoSeconds,
    );
  }

  @override
  List<Object?> get props => [
    kind,
    fO2,
    fHe,
    idealTimestamp,
    idealDepth,
    switchTimestamp,
    switchDepth,
    endTimestamp,
    delaySeconds,
    depthDelayMeters,
    extraDecoSeconds,
  ];
}

/// Gas-switch efficiency of one open-circuit dive: a read-only comparison of
/// the gases breathed against the ideal ascent TTS already assumes.
class GasSwitchEfficiency extends Equatable {
  const GasSwitchEfficiency({
    required this.evaluated,
    this.windows = const [],
    this.totalExtraDecoSeconds = 0,
  });

  /// Nothing to judge: no deco obligation, or no gas to assess.
  static const notEvaluated = GasSwitchEfficiency(evaluated: false);

  /// False when there was nothing to judge, so the UI can tell "all switches
  /// on time" apart from "not applicable".
  final bool evaluated;

  /// Flagged windows only, time-ordered.
  final List<GasSwitchWindow> windows;

  /// Extra deco with every flagged window fixed at once (not a sum).
  final int totalExtraDecoSeconds;

  /// The window under [timestamp]. Where one window ends on the sample the
  /// next starts on, the starting one is current: windows are time-ordered,
  /// so the last match wins.
  GasSwitchWindow? windowAt(int timestamp) {
    for (final window in windows.reversed) {
      if (window.contains(timestamp)) return window;
    }
    return null;
  }

  GasSwitchEfficiency copyWith({
    bool? evaluated,
    List<GasSwitchWindow>? windows,
    int? totalExtraDecoSeconds,
  }) {
    return GasSwitchEfficiency(
      evaluated: evaluated ?? this.evaluated,
      windows: windows ?? this.windows,
      totalExtraDecoSeconds:
          totalExtraDecoSeconds ?? this.totalExtraDecoSeconds,
    );
  }

  @override
  List<Object?> get props => [evaluated, windows, totalExtraDecoSeconds];
}

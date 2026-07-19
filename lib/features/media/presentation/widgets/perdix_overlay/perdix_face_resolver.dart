import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';
import 'package:submersion/features/dive_log/presentation/widgets/instrument_tiles.dart';

/// Snapshot of dive computer readings at one moment of the dive, shaped for
/// the Perdix-style media overlay. Values are metric; formatting happens in
/// the widget layer.
class PerdixFaceData {
  final int diveTimeSeconds;
  final double? depthMeters;
  final double? runningMaxDepthMeters;
  final int? ndlSeconds;
  final double? ceilingMeters;
  final int? ttsSeconds;
  final double? temperatureCelsius;
  final String? gasLabel;
  final double? tankPressureBar;
  final double? cnsPercent;
  final double? ppO2Bar;
  final bool inDeco;

  const PerdixFaceData({
    required this.diveTimeSeconds,
    this.depthMeters,
    this.runningMaxDepthMeters,
    this.ndlSeconds,
    this.ceilingMeters,
    this.ttsSeconds,
    this.temperatureCelsius,
    this.gasLabel,
    this.tankPressureBar,
    this.cnsPercent,
    this.ppO2Bar,
    this.inDeco = false,
  });
}

/// Resolves [PerdixFaceData] for arbitrary dive-time seconds. Construct once
/// per dive data load (prefix-max depths and gas segments are precomputed);
/// [resolve] is cheap enough to call per video frame.
class PerdixFaceResolver {
  PerdixFaceResolver({
    required List<DiveProfilePoint> profile,
    ProfileAnalysis? analysis,
    List<DiveTank> tanks = const [],
    List<GasSwitchWithTank> gasSwitches = const [],
    Map<String, List<TankPressurePoint>>? tankPressures,
  }) : _profile = profile,
       _analysis = analysis,
       _tankPressures = tankPressures,
       _prefixMaxDepths = _computePrefixMax(profile),
       _gasSegments = profile.isEmpty
           ? const []
           : buildGasUsageSegments(
               tanks: tanks,
               gasSwitches: gasSwitches,
               diveDurationSeconds: profile.last.timestamp,
             ),
       _activeTankIntervals = profile.isEmpty
           ? const {}
           : buildActiveTankIntervals(
               tanks: tanks,
               gasSwitches: gasSwitches,
               diveDurationSeconds: profile.last.timestamp,
             );

  final List<DiveProfilePoint> _profile;
  final ProfileAnalysis? _analysis;
  final Map<String, List<TankPressurePoint>>? _tankPressures;
  final List<double> _prefixMaxDepths;
  final List<GasUsageSegment> _gasSegments;
  final Map<String, List<({int start, int end})>> _activeTankIntervals;

  bool get isAvailable => _profile.isNotEmpty;

  static List<double> _computePrefixMax(List<DiveProfilePoint> profile) {
    final result = List<double>.filled(profile.length, 0.0);
    var running = 0.0;
    for (var i = 0; i < profile.length; i++) {
      if (profile[i].depth > running) running = profile[i].depth;
      result[i] = running;
    }
    return result;
  }

  PerdixFaceData resolve(int diveTimeSeconds) {
    if (_profile.isEmpty) {
      return PerdixFaceData(diveTimeSeconds: diveTimeSeconds);
    }
    final clamped = diveTimeSeconds.clamp(
      _profile.first.timestamp,
      _profile.last.timestamp,
    );
    final sample = resolveSample(
      profile: _profile,
      analysis: _analysis,
      tankPressures: _tankPressures,
      timestamp: clamped,
    );
    final index = indexForTimestamp(_profile, clamped)!;
    final ceiling = sample.ceilingMeters;
    return PerdixFaceData(
      diveTimeSeconds: clamped,
      depthMeters: sample.depthMeters,
      runningMaxDepthMeters: _prefixMaxDepths[index],
      ndlSeconds: sample.ndlSeconds,
      ceilingMeters: ceiling,
      ttsSeconds: sample.ttsSeconds,
      temperatureCelsius: sample.temperatureCelsius,
      gasLabel: _gasLabelAt(clamped),
      tankPressureBar: _tankPressureAt(clamped, sample.tankPressuresBar),
      cnsPercent: sample.cnsPercent,
      ppO2Bar: sample.ppO2Bar,
      inDeco: sample.inDeco || ((ceiling ?? 0) > 0),
    );
  }

  String? _gasLabelAt(int t) {
    if (_gasSegments.isEmpty) return null;
    for (final segment in _gasSegments) {
      if (t >= segment.startSeconds && t < segment.endSeconds) {
        return segment.label;
      }
    }
    // endSeconds is exclusive; the final second of the dive belongs to the
    // last segment.
    return t >= _gasSegments.last.endSeconds ? _gasSegments.last.label : null;
  }

  double? _tankPressureAt(int t, Map<String, double> pressures) {
    if (pressures.isEmpty) return null;
    final activeTankId = _activeTankIdAt(t);
    if (activeTankId != null) {
      final active = pressures[activeTankId];
      if (active != null) return active;
    }
    return pressures.values.first;
  }

  String? _activeTankIdAt(int t) {
    String? lastTank;
    var lastEnd = -1;
    for (final entry in _activeTankIntervals.entries) {
      for (final window in entry.value) {
        if (t >= window.start && t < window.end) return entry.key;
        if (window.end > lastEnd) {
          lastEnd = window.end;
          lastTank = entry.key;
        }
      }
    }
    // Interval ends are exclusive; the final second of the dive belongs to
    // the last window.
    return (lastEnd >= 0 && t >= lastEnd) ? lastTank : null;
  }
}

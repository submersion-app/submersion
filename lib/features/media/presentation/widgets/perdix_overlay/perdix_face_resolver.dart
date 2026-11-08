import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/instrument_sample.dart';

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

  /// True when the dive has pressure readings at this moment but none to show
  /// for the cylinder in use, as opposed to a dive with no pressure data. The
  /// face then holds the TANK cell open with no value, which keeps the cells
  /// beside it from moving at a gas switch.
  final bool tankPressureMissing;
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
    this.tankPressureMissing = false,
    this.cnsPercent,
    this.ppO2Bar,
    this.inDeco = false,
  });
}

/// Resolves [PerdixFaceData] for arbitrary dive-time seconds. Construct once
/// per dive data load (prefix-max depths and gas segments are precomputed);
/// [resolve] is cheap enough to call per video frame.
class PerdixFaceResolver {
  /// A face whose gas and active cylinder come from every cylinder in [tanks]
  /// and every switch in [gasSwitches], as one series breathed from the start.
  /// The media viewer builds its face with [PerdixFaceResolver.forSource],
  /// which scopes those to one computer the way the profile chart does.
  PerdixFaceResolver({
    required List<DiveProfilePoint> profile,
    ProfileAnalysis? analysis,
    List<DiveTank> tanks = const [],
    List<GasSwitchWithTank> gasSwitches = const [],
    Map<String, List<TankPressurePoint>>? tankPressures,
  }) : this._(
         profile: profile,
         analysis: analysis,
         tankPressures: tankPressures,
         gasSegments: profile.isEmpty
             ? const []
             : buildGasUsageSegments(
                 tanks: tanks,
                 gasSwitches: gasSwitches,
                 diveDurationSeconds: profile.last.timestamp,
                 firstSampleSeconds: profile.first.timestamp,
               ),
         activeTankIntervals: profile.isEmpty
             ? const {}
             : buildActiveTankIntervals(
                 tanks: tanks,
                 gasSwitches: gasSwitches,
                 diveDurationSeconds: profile.last.timestamp,
                 firstSampleSeconds: profile.first.timestamp,
               ),
       );

  /// The face of [computerId]'s series of [dive], [profile] being the points
  /// drawn for it. Its gas reads the profile chart's own gas strip
  /// ([activeGasUsageSegments]), and its active cylinder the same cylinders
  /// and switches ([computerGasInputs]), so the GAS and TANK cells always
  /// agree with the chart and with the source's own ppO2 beside them. Another
  /// computer's record of a switch never moves this one's gas (#4300).
  ///
  /// Null [computerId] is every source drawn as one series (a single-source
  /// dive, or the consecutive halves of a Combine), so every switch counts.
  factory PerdixFaceResolver.forSource(
    Dive dive, {
    required List<DiveProfilePoint> profile,
    ProfileAnalysis? analysis,
    List<GasSwitchWithTank> gasSwitches = const [],
    Map<String, List<TankPressurePoint>>? tankPressures,
    String? computerId,
  }) {
    if (profile.isEmpty) {
      return PerdixFaceResolver._(
        profile: profile,
        analysis: analysis,
        tankPressures: tankPressures,
        gasSegments: const [],
        activeTankIntervals: const {},
      );
    }
    final inputs = computerGasInputs(
      dive,
      gasSwitches: gasSwitches,
      computerId: computerId,
    );
    return PerdixFaceResolver._(
      profile: profile,
      analysis: analysis,
      tankPressures: tankPressures,
      gasSegments: activeGasUsageSegments(
        dive,
        gasSwitches: gasSwitches,
        profile: profile,
        computerId: computerId,
      ),
      activeTankIntervals: buildActiveTankIntervals(
        tanks: inputs.tanks,
        gasSwitches: inputs.gasSwitches,
        diveDurationSeconds: profile.last.timestamp,
        firstSampleSeconds: profile.first.timestamp,
        onLoop: dive.isRebreather,
      ),
    );
  }

  PerdixFaceResolver._({
    required List<DiveProfilePoint> profile,
    required ProfileAnalysis? analysis,
    required Map<String, List<TankPressurePoint>>? tankPressures,
    required List<GasUsageSegment> gasSegments,
    required Map<String, List<({int start, int end})>> activeTankIntervals,
  }) : _profile = profile,
       _analysis = analysis,
       _tankPressures = tankPressures,
       _prefixMaxDepths = _computePrefixMax(profile),
       _gasSegments = gasSegments,
       _activeTankIntervals = activeTankIntervals;

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
    final tankPressure = _tankPressureAt(clamped, sample.tankPressuresBar);
    return PerdixFaceData(
      diveTimeSeconds: clamped,
      depthMeters: sample.depthMeters,
      runningMaxDepthMeters: _prefixMaxDepths[index],
      ndlSeconds: sample.ndlSeconds,
      ceilingMeters: ceiling,
      ttsSeconds: sample.ttsSeconds,
      temperatureCelsius: sample.temperatureCelsius,
      gasLabel: _gasLabelAt(clamped),
      tankPressureBar: tankPressure,
      tankPressureMissing:
          tankPressure == null && sample.tankPressuresBar.isNotEmpty,
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

  /// The active cylinder's reading, or null when it has none. The face shows
  /// this beside the active gas, so another cylinder's pressure would read as
  /// a measurement of that gas (#4006). With no cylinder known to be active,
  /// a lone reading is all there is to show, and no gas label goes with it;
  /// among several, picking one would be a guess.
  double? _tankPressureAt(int t, Map<String, double> pressures) {
    final activeTankId = _activeTankIdAt(t);
    if (activeTankId != null) return pressures[activeTankId];
    return pressures.length == 1 ? pressures.values.single : null;
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

import 'package:uuid/uuid.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/deco/ascent_rate_calculator.dart';
import '../../../../core/deco/buhlmann_algorithm.dart';
import '../../../../core/deco/constants/buhlmann_coefficients.dart';
import '../../../../core/deco/entities/deco_status.dart';
import '../../../../core/deco/entities/o2_exposure.dart';
import '../../../../core/deco/o2_toxicity_calculator.dart';
import '../../domain/entities/profile_event.dart';

/// Complete analysis results for a dive profile.
class ProfileAnalysis {
  /// Ascent rate at each profile point
  final List<AscentRatePoint> ascentRates;

  /// Ascent rate statistics
  final AscentRateStats ascentRateStats;

  /// Ascent rate violations
  final List<AscentRateViolation> ascentRateViolations;

  /// Auto-detected and imported events
  final List<ProfileEvent> events;

  /// Decompression ceiling at each profile point (meters)
  final List<double> ceilingCurve;

  /// NDL at each profile point (seconds, -1 if in deco)
  final List<int> ndlCurve;

  /// Decompression status at each point
  final List<DecoStatus> decoStatuses;

  /// Oxygen toxicity exposure
  final O2Exposure o2Exposure;

  /// ppO2 at each profile point (bar)
  final List<double> ppO2Curve;

  /// SAC rate at each point (L/min at surface) - null if no pressure data
  final List<double>? sacCurve;

  /// Maximum depth reached (meters)
  final double maxDepth;

  /// Average depth (meters)
  final double averageDepth;

  /// Timestamp of max depth
  final int maxDepthTimestamp;

  /// Dive duration in seconds
  final int durationSeconds;

  const ProfileAnalysis({
    required this.ascentRates,
    required this.ascentRateStats,
    required this.ascentRateViolations,
    required this.events,
    required this.ceilingCurve,
    required this.ndlCurve,
    required this.decoStatuses,
    required this.o2Exposure,
    required this.ppO2Curve,
    this.sacCurve,
    required this.maxDepth,
    required this.averageDepth,
    required this.maxDepthTimestamp,
    required this.durationSeconds,
  });

  /// Whether diver went into decompression obligation
  bool get hadDecoObligation => ndlCurve.any((ndl) => ndl < 0);

  /// Whether any ascent rate violations occurred
  bool get hadAscentViolations => ascentRateViolations.isNotEmpty;

  /// Whether any critical ascent violations occurred
  bool get hadCriticalAscentViolations =>
      ascentRateViolations.any((v) => v.isCritical);

  /// Whether ppO2 exceeded warning threshold
  bool get hadPpO2Warning => o2Exposure.ppO2Warning;

  /// Whether ppO2 exceeded critical threshold
  bool get hadPpO2Critical => o2Exposure.ppO2Critical;

  /// Get all warning events
  List<ProfileEvent> get warningEvents =>
      events.where((e) => e.severity == EventSeverity.warning).toList();

  /// Get all alert events
  List<ProfileEvent> get alertEvents =>
      events.where((e) => e.severity == EventSeverity.alert).toList();

  /// Create an empty analysis
  factory ProfileAnalysis.empty() {
    return const ProfileAnalysis(
      ascentRates: [],
      ascentRateStats: AscentRateStats(
        maxAscentRate: 0,
        maxDescentRate: 0,
        averageAscentRate: 0,
        averageDescentRate: 0,
        violationCount: 0,
        criticalViolationCount: 0,
        timeInViolation: 0,
      ),
      ascentRateViolations: [],
      events: [],
      ceilingCurve: [],
      ndlCurve: [],
      decoStatuses: [],
      o2Exposure: O2Exposure(),
      ppO2Curve: [],
      maxDepth: 0,
      averageDepth: 0,
      maxDepthTimestamp: 0,
      durationSeconds: 0,
    );
  }
}

/// Service for analyzing dive profiles.
class ProfileAnalysisService {
  final AscentRateCalculator _ascentRateCalculator;
  final O2ToxicityCalculator _o2ToxicityCalculator;
  final BuhlmannAlgorithm _buhlmannAlgorithm;
  final Uuid _uuid;

  ProfileAnalysisService({
    double ascentRateWarning = 9.0,
    double ascentRateCritical = 12.0,
    double ppO2WarningThreshold = 1.4,
    double ppO2CriticalThreshold = 1.6,
    int cnsWarningThreshold = 80,
    double gfLow = 0.30,
    double gfHigh = 0.70,
    double lastStopDepth = 3.0,
    double decoStopIncrement = 3.0,
  })  : _ascentRateCalculator = AscentRateCalculator(
          warningThreshold: ascentRateWarning,
          criticalThreshold: ascentRateCritical,
        ),
        _o2ToxicityCalculator = O2ToxicityCalculator(
          ppO2WarningThreshold: ppO2WarningThreshold,
          ppO2CriticalThreshold: ppO2CriticalThreshold,
          cnsWarningThreshold: cnsWarningThreshold,
        ),
        _buhlmannAlgorithm = BuhlmannAlgorithm(
          gfLow: gfLow,
          gfHigh: gfHigh,
          lastStopDepth: lastStopDepth,
          stopIncrement: decoStopIncrement,
        ),
        _uuid = const Uuid();

  /// Analyze a complete dive profile.
  ///
  /// [diveId] is the dive's unique identifier.
  /// [depths] is a list of depths in meters.
  /// [timestamps] is a list of timestamps in seconds from dive start.
  /// [o2Fraction] is the oxygen fraction (0.0-1.0), default air.
  /// [heFraction] is the helium fraction (0.0-1.0), default 0.
  /// [startCns] is starting CNS% from previous dives.
  /// [pressures] is optional tank pressure data for SAC calculation.
  ProfileAnalysis analyze({
    required String diveId,
    required List<double> depths,
    required List<int> timestamps,
    double o2Fraction = airO2Fraction,
    double heFraction = 0.0,
    double startCns = 0.0,
    List<double>? pressures,
  }) {
    if (depths.isEmpty || depths.length != timestamps.length) {
      return ProfileAnalysis.empty();
    }

    final n2Fraction = 1.0 - o2Fraction - heFraction;

    // Calculate ascent rates
    final ascentRates = _ascentRateCalculator.calculateProfileRates(
      depths,
      timestamps,
    );
    final ascentRateStats = _ascentRateCalculator.getStats(ascentRates);
    final ascentRateViolations =
        _ascentRateCalculator.findViolations(ascentRates);

    // Calculate decompression data
    _buhlmannAlgorithm.reset();
    final decoStatuses = _buhlmannAlgorithm.processProfile(
      depths: depths,
      timestamps: timestamps,
      fN2: n2Fraction,
      fHe: heFraction,
    );
    final ceilingCurve = decoStatuses.map((s) => s.ceilingMeters).toList();
    final ndlCurve = decoStatuses.map((s) => s.ndlSeconds).toList();

    // Calculate O2 exposure
    final o2Exposure = _o2ToxicityCalculator.calculateDiveExposure(
      depths: depths,
      timestamps: timestamps,
      o2Fraction: o2Fraction,
      startCns: startCns,
    );

    // Calculate ppO2 curve
    final ppO2Curve =
        _o2ToxicityCalculator.calculatePpO2Curve(depths, o2Fraction);

    // Calculate basic stats
    double maxDepth = 0;
    int maxDepthTimestamp = 0;
    double depthSum = 0;

    for (int i = 0; i < depths.length; i++) {
      if (depths[i] > maxDepth) {
        maxDepth = depths[i];
        maxDepthTimestamp = timestamps[i];
      }
      depthSum += depths[i];
    }

    final averageDepth = depthSum / depths.length;
    final durationSeconds =
        timestamps.isNotEmpty ? timestamps.last - timestamps.first : 0;

    // Auto-detect events
    final events = _detectEvents(
      diveId: diveId,
      depths: depths,
      timestamps: timestamps,
      ascentRates: ascentRates,
      ascentRateViolations: ascentRateViolations,
      ndlCurve: ndlCurve,
      ppO2Curve: ppO2Curve,
      maxDepth: maxDepth,
      maxDepthTimestamp: maxDepthTimestamp,
    );

    // Calculate SAC if pressure data available
    List<double>? sacCurve;
    if (pressures != null && pressures.length == depths.length) {
      sacCurve = _calculateSacCurve(depths, timestamps, pressures);
    }

    return ProfileAnalysis(
      ascentRates: ascentRates,
      ascentRateStats: ascentRateStats,
      ascentRateViolations: ascentRateViolations,
      events: events,
      ceilingCurve: ceilingCurve,
      ndlCurve: ndlCurve,
      decoStatuses: decoStatuses,
      o2Exposure: o2Exposure,
      ppO2Curve: ppO2Curve,
      sacCurve: sacCurve,
      maxDepth: maxDepth,
      averageDepth: averageDepth,
      maxDepthTimestamp: maxDepthTimestamp,
      durationSeconds: durationSeconds,
    );
  }

  /// Detect significant events in the profile.
  List<ProfileEvent> _detectEvents({
    required String diveId,
    required List<double> depths,
    required List<int> timestamps,
    required List<AscentRatePoint> ascentRates,
    required List<AscentRateViolation> ascentRateViolations,
    required List<int> ndlCurve,
    required List<double> ppO2Curve,
    required double maxDepth,
    required int maxDepthTimestamp,
  }) {
    final events = <ProfileEvent>[];
    final now = DateTime.now();

    // Find descent start (first significant depth increase)
    int? descentStartIndex;
    for (int i = 1; i < depths.length; i++) {
      if (depths[i] > 1.0 && depths[i] > depths[i - 1]) {
        descentStartIndex = i;
        events.add(ProfileEvent.descentStart(
          id: _uuid.v4(),
          diveId: diveId,
          timestamp: timestamps[i],
          depth: depths[i],
          createdAt: now,
        ));
        break;
      }
    }

    // Find descent end (first point where descent stops)
    if (descentStartIndex != null) {
      for (int i = descentStartIndex + 1; i < depths.length; i++) {
        if (depths[i] <= depths[i - 1]) {
          events.add(ProfileEvent(
            id: _uuid.v4(),
            diveId: diveId,
            timestamp: timestamps[i],
            eventType: ProfileEventType.descentEnd,
            depth: depths[i],
            createdAt: now,
          ));
          break;
        }
      }
    }

    // Find max depth
    events.add(ProfileEvent.maxDepth(
      id: _uuid.v4(),
      diveId: diveId,
      timestamp: maxDepthTimestamp,
      depth: maxDepth,
      createdAt: now,
    ));

    // Find ascent start (last significant depth decrease starting)
    for (int i = depths.length - 1; i > 0; i--) {
      if (depths[i - 1] > depths[i] + 1.0) {
        // Find where this ascent started
        int ascentStart = i;
        for (int j = i - 1; j >= 0; j--) {
          if (depths[j] <= depths[j + 1]) {
            ascentStart = j + 1;
            break;
          }
        }
        events.add(ProfileEvent.ascentStart(
          id: _uuid.v4(),
          diveId: diveId,
          timestamp: timestamps[ascentStart],
          depth: depths[ascentStart],
          createdAt: now,
        ));
        break;
      }
    }

    // Detect safety stops (3-6m depth for 2+ minutes)
    _detectSafetyStops(diveId, depths, timestamps, events, now);

    // Add ascent rate violation events
    for (final violation in ascentRateViolations) {
      events.add(ProfileEvent.ascentRateWarning(
        id: _uuid.v4(),
        diveId: diveId,
        timestamp: violation.startTimestamp,
        depth: violation.depthAtMaxRate,
        rate: violation.maxRate,
        createdAt: now,
        isCritical: violation.isCritical,
      ));
    }

    // Detect ppO2 warnings
    for (int i = 0; i < ppO2Curve.length; i++) {
      if (ppO2Curve[i] > 1.6) {
        events.add(ProfileEvent(
          id: _uuid.v4(),
          diveId: diveId,
          timestamp: timestamps[i],
          eventType: ProfileEventType.ppO2High,
          severity: EventSeverity.alert,
          depth: depths[i],
          value: ppO2Curve[i],
          createdAt: now,
        ));
        // Skip ahead to avoid duplicate events
        while (i < ppO2Curve.length - 1 && ppO2Curve[i + 1] > 1.6) {
          i++;
        }
      } else if (ppO2Curve[i] > 1.4) {
        events.add(ProfileEvent(
          id: _uuid.v4(),
          diveId: diveId,
          timestamp: timestamps[i],
          eventType: ProfileEventType.ppO2High,
          severity: EventSeverity.warning,
          depth: depths[i],
          value: ppO2Curve[i],
          createdAt: now,
        ));
        while (i < ppO2Curve.length - 1 && ppO2Curve[i + 1] > 1.4) {
          i++;
        }
      }
    }

    // Sort events by timestamp
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return events;
  }

  /// Detect safety stops in the profile.
  void _detectSafetyStops(
    String diveId,
    List<double> depths,
    List<int> timestamps,
    List<ProfileEvent> events,
    DateTime now,
  ) {
    const minStopDepth = 3.0;
    const maxStopDepth = 6.0;
    const minStopDuration = 120; // 2 minutes

    int? stopStartIndex;
    int? stopStartTimestamp;

    for (int i = 0; i < depths.length; i++) {
      final depth = depths[i];
      final timestamp = timestamps[i];

      if (depth >= minStopDepth && depth <= maxStopDepth) {
        if (stopStartIndex == null) {
          stopStartIndex = i;
          stopStartTimestamp = timestamp;
        }
      } else {
        if (stopStartIndex != null && stopStartTimestamp != null) {
          final duration = timestamps[i - 1] - stopStartTimestamp;
          if (duration >= minStopDuration) {
            // This was a safety stop
            events.add(ProfileEvent.safetyStop(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: stopStartTimestamp,
              depth: depths[stopStartIndex],
              createdAt: now,
              isStart: true,
            ));
            events.add(ProfileEvent.safetyStop(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: timestamps[i - 1],
              depth: depths[i - 1],
              createdAt: now,
              isStart: false,
            ));
          }
          stopStartIndex = null;
          stopStartTimestamp = null;
        }
      }
    }
  }

  /// Calculate SAC curve from pressure data.
  List<double>? _calculateSacCurve(
    List<double> depths,
    List<int> timestamps,
    List<double> pressures,
  ) {
    if (pressures.length < 2) return null;

    final sacCurve = <double>[0.0]; // First point has no SAC

    for (int i = 1; i < depths.length; i++) {
      final duration = timestamps[i] - timestamps[i - 1];
      if (duration <= 0) {
        sacCurve.add(0.0);
        continue;
      }

      final pressureDrop = pressures[i - 1] - pressures[i];
      if (pressureDrop <= 0) {
        sacCurve.add(0.0);
        continue;
      }

      // Average depth for segment
      final avgDepth = (depths[i - 1] + depths[i]) / 2.0;
      final ambientPressure = 1.0 + (avgDepth / 10.0);

      // Gas consumed in bar/min
      final consumptionRate = pressureDrop / (duration / 60.0);

      // Surface consumption rate (SAC)
      final sac = consumptionRate / ambientPressure;

      sacCurve.add(sac);
    }

    return sacCurve;
  }

  /// Get analysis at a specific timestamp.
  ///
  /// Returns null if timestamp not found in profile.
  ({
    AscentRatePoint? ascentRate,
    double? ceiling,
    int? ndl,
    double? ppO2,
    DecoStatus? decoStatus,
  })? getAnalysisAt(ProfileAnalysis analysis, int timestamp) {
    // Find index of timestamp
    int? index;
    for (int i = 0; i < analysis.ascentRates.length; i++) {
      if (analysis.ascentRates[i].timestamp == timestamp) {
        index = i;
        break;
      }
    }

    if (index == null) return null;

    return (
      ascentRate: analysis.ascentRates[index],
      ceiling: analysis.ceilingCurve[index],
      ndl: analysis.ndlCurve[index],
      ppO2: analysis.ppO2Curve[index],
      decoStatus:
          index < analysis.decoStatuses.length
              ? analysis.decoStatuses[index]
              : null,
    );
  }
}

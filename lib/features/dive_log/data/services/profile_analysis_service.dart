import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/core/deco/scr_calculator.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

/// Represents SAC calculated over a segment of the dive.
class SacSegment extends Equatable {
  /// Start timestamp of this segment (seconds from dive start)
  final int startTimestamp;

  /// End timestamp of this segment (seconds from dive start)
  final int endTimestamp;

  /// Average depth during this segment (meters)
  final double avgDepth;

  /// Minimum depth during this segment (meters)
  final double minDepth;

  /// Maximum depth during this segment (meters)
  final double maxDepth;

  /// SAC rate for this segment (bar/min at surface)
  final double sacRate;

  /// Gas consumed during this segment (bar)
  final double gasConsumed;

  /// Tank ID for gas-switch segmentation (optional)
  final String? tankId;

  /// Tank display name (optional)
  final String? tankName;

  /// Gas mix used in this segment (optional)
  final GasMix? gasMix;

  /// Dive phase for depth-phase segmentation (optional)
  final DivePhase? phase;

  /// Segmentation type that produced this segment
  final SacSegmentationType? segmentationType;

  const SacSegment({
    required this.startTimestamp,
    required this.endTimestamp,
    required this.avgDepth,
    required this.minDepth,
    required this.maxDepth,
    required this.sacRate,
    required this.gasConsumed,
    this.tankId,
    this.tankName,
    this.gasMix,
    this.phase,
    this.segmentationType,
  });

  /// Duration of this segment in seconds
  int get durationSeconds => endTimestamp - startTimestamp;

  /// Duration of this segment in minutes
  double get durationMinutes => durationSeconds / 60.0;

  /// Get the midpoint timestamp (useful for charting)
  int get midTimestamp => (startTimestamp + endTimestamp) ~/ 2;

  /// Display label for this segment based on its type
  String get displayLabel {
    if (phase != null) {
      return phase!.displayName;
    }
    if (tankName != null) {
      return tankName!;
    }
    if (gasMix != null) {
      return gasMix!.name;
    }
    // Default: time range
    final startMin = startTimestamp ~/ 60;
    final endMin = endTimestamp ~/ 60;
    return '$startMin-${endMin}min';
  }

  @override
  List<Object?> get props => [
    startTimestamp,
    endTimestamp,
    avgDepth,
    minDepth,
    maxDepth,
    sacRate,
    gasConsumed,
    tankId,
    tankName,
    gasMix,
    phase,
    segmentationType,
  ];
}

/// Type of segmentation for SAC calculation.
enum SacSegmentationType {
  /// Fixed time intervals (e.g., every 5 minutes)
  timeInterval,

  /// Segments based on depth zones
  depthBased,

  /// Segments divided by gas/tank switches
  gasSwitch,

  /// Segments based on dive phases (descent, bottom, ascent, etc.)
  depthPhase;

  /// Display name for UI
  String get displayName {
    return switch (this) {
      SacSegmentationType.timeInterval => 'Time',
      SacSegmentationType.depthBased => 'Depth',
      SacSegmentationType.gasSwitch => 'Gas',
      SacSegmentationType.depthPhase => 'Phase',
    };
  }

  /// Icon name for UI
  String get iconName {
    return switch (this) {
      SacSegmentationType.timeInterval => 'timer',
      SacSegmentationType.depthBased => 'layers',
      SacSegmentationType.gasSwitch => 'swap_horiz',
      SacSegmentationType.depthPhase => 'trending_down',
    };
  }
}

/// Represents a phase of the dive for depth-phase segmentation.
enum DivePhase {
  /// Descending to depth
  descent,

  /// At bottom depth (within 15% of max depth)
  bottom,

  /// Ascending to surface
  ascent,

  /// Safety stop (3-6m for 3+ minutes)
  safetyStop,

  /// Decompression stop
  deco;

  /// Display name for UI
  String get displayName {
    return switch (this) {
      DivePhase.descent => 'Descent',
      DivePhase.bottom => 'Bottom',
      DivePhase.ascent => 'Ascent',
      DivePhase.safetyStop => 'Safety Stop',
      DivePhase.deco => 'Deco',
    };
  }

  /// Short label for compact display
  String get shortLabel {
    return switch (this) {
      DivePhase.descent => '↓',
      DivePhase.bottom => '—',
      DivePhase.ascent => '↑',
      DivePhase.safetyStop => '⏸',
      DivePhase.deco => '⚠',
    };
  }
}

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

  /// SAC rate at each point (bar/min at surface) - null if no pressure data
  final List<double>? sacCurve;

  /// Smoothed SAC curve (rolling average, bar/min at surface) - better for visualization
  final List<double>? smoothedSacCurve;

  /// SAC calculated over time-based segments (e.g., 5-minute intervals)
  final List<SacSegment>? sacSegments;

  /// ppN2 (partial pressure of nitrogen) at each profile point (bar)
  final List<double>? ppN2Curve;

  /// ppHe (partial pressure of helium) at each profile point (bar)
  final List<double>? ppHeCurve;

  /// Maximum Operating Depth for current gas at each point (meters)
  final List<double>? modCurve;

  /// Gas density at each profile point (g/L)
  final List<double>? densityCurve;

  /// Gradient Factor % at each profile point (0-100+, percent of M-value used)
  final List<double>? gfCurve;

  /// Surface GF% (what GF would be if surfaced now) at each point (0-100+)
  final List<double>? surfaceGfCurve;

  /// Mean depth from start to each profile point (meters)
  final List<double>? meanDepthCurve;

  /// Time To Surface at each profile point (seconds)
  final List<int>? ttsCurve;

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
    this.smoothedSacCurve,
    this.sacSegments,
    this.ppN2Curve,
    this.ppHeCurve,
    this.modCurve,
    this.densityCurve,
    this.gfCurve,
    this.surfaceGfCurve,
    this.meanDepthCurve,
    this.ttsCurve,
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

  /// Whether ppN2 curve data is available
  bool get hasPpN2Data => ppN2Curve != null && ppN2Curve!.isNotEmpty;

  /// Whether ppHe curve data is available (trimix dive)
  bool get hasPpHeData =>
      ppHeCurve != null && ppHeCurve!.any((he) => he > 0.001);

  /// Whether MOD curve data is available
  bool get hasModData => modCurve != null && modCurve!.isNotEmpty;

  /// Whether density curve data is available
  bool get hasDensityData => densityCurve != null && densityCurve!.isNotEmpty;

  /// Whether GF curve data is available
  bool get hasGfData => gfCurve != null && gfCurve!.isNotEmpty;

  /// Whether surface GF curve data is available
  bool get hasSurfaceGfData =>
      surfaceGfCurve != null && surfaceGfCurve!.isNotEmpty;

  /// Whether mean depth curve data is available
  bool get hasMeanDepthData =>
      meanDepthCurve != null && meanDepthCurve!.isNotEmpty;

  /// Whether TTS curve data is available
  bool get hasTtsData => ttsCurve != null && ttsCurve!.isNotEmpty;

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
  }) : _ascentRateCalculator = AscentRateCalculator(
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
  /// [diveMode] is the dive mode (OC, CCR, SCR), default OC.
  /// [setpointHigh] is the CCR high setpoint (bar), used for bottom phase.
  /// [setpointLow] is the optional CCR low setpoint (bar), for descent/ascent.
  /// [lowSetpointMaxDepth] is the depth (m) to switch from low to high setpoint.
  /// [scrInjectionRate] is the SCR injection rate (L/min at surface).
  /// [scrSupplyO2Percent] is the SCR supply gas O2 percentage.
  /// [scrVo2] is the assumed metabolic O2 consumption (L/min) for SCR.
  ProfileAnalysis analyze({
    required String diveId,
    required List<double> depths,
    required List<int> timestamps,
    double o2Fraction = airO2Fraction,
    double heFraction = 0.0,
    double startCns = 0.0,
    List<double>? pressures,
    DiveMode diveMode = DiveMode.oc,
    double? setpointHigh,
    double? setpointLow,
    double lowSetpointMaxDepth = 6.0,
    double? scrInjectionRate,
    double? scrSupplyO2Percent,
    double scrVo2 = ScrCalculator.defaultVo2,
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
    final ascentRateViolations = _ascentRateCalculator.findViolations(
      ascentRates,
    );

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

    // Calculate ppO2 curve based on dive mode
    final List<double> ppO2Curve;
    switch (diveMode) {
      case DiveMode.ccr:
        // CCR: ppO2 equals the setpoint (constant or variable by depth phase)
        if (setpointHigh != null) {
          ppO2Curve = _o2ToxicityCalculator.calculatePpO2CurveCCR(
            depths,
            setpointHigh: setpointHigh,
            setpointLow: setpointLow,
            lowSetpointMaxDepth: lowSetpointMaxDepth,
          );
        } else {
          // Fallback to OC calculation if no setpoint provided
          ppO2Curve = _o2ToxicityCalculator.calculatePpO2Curve(
            depths,
            o2Fraction,
          );
        }
      case DiveMode.scr:
        // SCR: ppO2 varies with depth based on steady-state loop FO2
        if (scrInjectionRate != null && scrSupplyO2Percent != null) {
          ppO2Curve = _o2ToxicityCalculator.calculatePpO2CurveSCR(
            depths,
            injectionRateLpm: scrInjectionRate,
            supplyO2Percent: scrSupplyO2Percent,
            vo2: scrVo2,
          );
        } else {
          // Fallback to OC calculation if SCR params not provided
          ppO2Curve = _o2ToxicityCalculator.calculatePpO2Curve(
            depths,
            o2Fraction,
          );
        }
      case DiveMode.oc:
        // OC: ppO2 = ambient pressure × FO2
        ppO2Curve = _o2ToxicityCalculator.calculatePpO2Curve(
          depths,
          o2Fraction,
        );
    }

    // Calculate O2 exposure using the ppO2 curve
    // For CCR/SCR, we need to calculate based on actual ppO2 values
    final O2Exposure o2Exposure;
    if (diveMode == DiveMode.oc) {
      o2Exposure = _o2ToxicityCalculator.calculateDiveExposure(
        depths: depths,
        timestamps: timestamps,
        o2Fraction: o2Fraction,
        startCns: startCns,
      );
    } else {
      // For CCR/SCR, calculate O2 exposure from ppO2 curve
      o2Exposure = _calculateO2ExposureFromPpO2Curve(
        ppO2Curve: ppO2Curve,
        timestamps: timestamps,
        depths: depths,
        startCns: startCns,
      );
    }

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
    final durationSeconds = timestamps.isNotEmpty
        ? timestamps.last - timestamps.first
        : 0;

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
    List<double>? smoothedSacCurve;
    List<SacSegment>? sacSegments;

    if (pressures != null && pressures.length == depths.length) {
      sacCurve = _calculateSacCurve(depths, timestamps, pressures);

      if (sacCurve != null) {
        // Calculate 5-minute segment SAC values first (needed for fallback)
        sacSegments = _calculateSacSegments(
          depths: depths,
          timestamps: timestamps,
          pressures: pressures,
          intervalSeconds: 300, // 5 minutes
        );

        // Calculate smoothed SAC curve using rolling window on raw pressure data
        // This is more accurate than smoothing the noisy point-by-point SAC values
        // Use 60-second window for better accuracy with sparse pressure data
        smoothedSacCurve = _calculateRollingWindowSac(
          depths: depths,
          timestamps: timestamps,
          pressures: pressures,
          windowSeconds: 60, // 60-second rolling window
        );

        // Check if rolling window produced mostly zeros (sparse/noisy data)
        // If so, fall back to interpolating from segment data
        final nonZeroCount = smoothedSacCurve.where((s) => s > 0).length;
        final totalCount = smoothedSacCurve.length;
        if (totalCount > 0 &&
            nonZeroCount < totalCount * 0.3 &&
            sacSegments.isNotEmpty) {
          // Less than 30% valid data - interpolate from segments instead
          smoothedSacCurve = _interpolateSacFromSegments(
            timestamps: timestamps,
            segments: sacSegments,
          );
        }
      }
    }

    // Calculate additional gas/deco curves
    final ppN2Curve = _calculatePpN2Curve(depths, n2Fraction);
    final ppHeCurve = heFraction > 0
        ? _calculatePpHeCurve(depths, heFraction)
        : null;
    final modCurve = _calculateModCurve(depths, o2Fraction);
    final densityCurve = _calculateDensityCurve(
      depths,
      o2Fraction,
      n2Fraction,
      heFraction,
    );
    final gfCurve = _calculateGfCurve(decoStatuses);
    final surfaceGfCurve = _calculateSurfaceGfCurve(decoStatuses);
    final meanDepthCurve = _calculateMeanDepthCurve(depths);
    final ttsCurve = decoStatuses.map((s) => s.ttsSeconds).toList();

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
      smoothedSacCurve: smoothedSacCurve,
      sacSegments: sacSegments,
      ppN2Curve: ppN2Curve,
      ppHeCurve: ppHeCurve,
      modCurve: modCurve,
      densityCurve: densityCurve,
      gfCurve: gfCurve,
      surfaceGfCurve: surfaceGfCurve,
      meanDepthCurve: meanDepthCurve,
      ttsCurve: ttsCurve,
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
        events.add(
          ProfileEvent.descentStart(
            id: _uuid.v4(),
            diveId: diveId,
            timestamp: timestamps[i],
            depth: depths[i],
            createdAt: now,
          ),
        );
        break;
      }
    }

    // Find descent end (first point where descent stops)
    if (descentStartIndex != null) {
      for (int i = descentStartIndex + 1; i < depths.length; i++) {
        if (depths[i] <= depths[i - 1]) {
          events.add(
            ProfileEvent(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: timestamps[i],
              eventType: ProfileEventType.descentEnd,
              depth: depths[i],
              createdAt: now,
            ),
          );
          break;
        }
      }
    }

    // Find max depth
    events.add(
      ProfileEvent.maxDepth(
        id: _uuid.v4(),
        diveId: diveId,
        timestamp: maxDepthTimestamp,
        depth: maxDepth,
        createdAt: now,
      ),
    );

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
        events.add(
          ProfileEvent.ascentStart(
            id: _uuid.v4(),
            diveId: diveId,
            timestamp: timestamps[ascentStart],
            depth: depths[ascentStart],
            createdAt: now,
          ),
        );
        break;
      }
    }

    // Detect safety stops (3-6m depth for 2+ minutes)
    _detectSafetyStops(diveId, depths, timestamps, events, now);

    // Add ascent rate violation events
    for (final violation in ascentRateViolations) {
      events.add(
        ProfileEvent.ascentRateWarning(
          id: _uuid.v4(),
          diveId: diveId,
          timestamp: violation.startTimestamp,
          depth: violation.depthAtMaxRate,
          rate: violation.maxRate,
          createdAt: now,
          isCritical: violation.isCritical,
        ),
      );
    }

    // Detect ppO2 warnings
    for (int i = 0; i < ppO2Curve.length; i++) {
      if (ppO2Curve[i] > 1.6) {
        events.add(
          ProfileEvent(
            id: _uuid.v4(),
            diveId: diveId,
            timestamp: timestamps[i],
            eventType: ProfileEventType.ppO2High,
            severity: EventSeverity.alert,
            depth: depths[i],
            value: ppO2Curve[i],
            createdAt: now,
          ),
        );
        // Skip ahead to avoid duplicate events
        while (i < ppO2Curve.length - 1 && ppO2Curve[i + 1] > 1.6) {
          i++;
        }
      } else if (ppO2Curve[i] > 1.4) {
        events.add(
          ProfileEvent(
            id: _uuid.v4(),
            diveId: diveId,
            timestamp: timestamps[i],
            eventType: ProfileEventType.ppO2High,
            severity: EventSeverity.warning,
            depth: depths[i],
            value: ppO2Curve[i],
            createdAt: now,
          ),
        );
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
            events.add(
              ProfileEvent.safetyStop(
                id: _uuid.v4(),
                diveId: diveId,
                timestamp: stopStartTimestamp,
                depth: depths[stopStartIndex],
                createdAt: now,
                isStart: true,
              ),
            );
            events.add(
              ProfileEvent.safetyStop(
                id: _uuid.v4(),
                diveId: diveId,
                timestamp: timestamps[i - 1],
                depth: depths[i - 1],
                createdAt: now,
                isStart: false,
              ),
            );
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

  /// Calculate SAC using a rolling window on raw pressure data.
  ///
  /// This calculates SAC for each point by looking at the total pressure drop
  /// over a time window centered on that point. This is more accurate than
  /// smoothing noisy point-by-point SAC values because it uses the actual
  /// pressure delta over a meaningful time period (like segments do).
  ///
  /// [windowSeconds] is the time window in seconds (default 60).
  /// The function handles sparse data by expanding the window if needed to
  /// ensure we have at least 2 data points with meaningful time span.
  List<double> _calculateRollingWindowSac({
    required List<double> depths,
    required List<int> timestamps,
    required List<double> pressures,
    int windowSeconds = 60,
  }) {
    if (timestamps.isEmpty || pressures.length != depths.length) {
      return [];
    }

    // Need at least 2 points to calculate any SAC
    if (timestamps.length < 2) {
      return [];
    }

    final result = <double>[];
    final halfWindow = windowSeconds ~/ 2;

    // Minimum time span required for valid SAC calculation (5 seconds)
    // Lower threshold helps with sparse data
    const minDuration = 5;

    for (int i = 0; i < timestamps.length; i++) {
      final centerTime = timestamps[i];

      // Find window bounds by time (not index)
      final windowStart = centerTime - halfWindow;
      final windowEnd = centerTime + halfWindow;

      // Find indices that fall within the time window
      var startIdx = i;
      var endIdx = i;

      // Expand backwards to find window start
      while (startIdx > 0 && timestamps[startIdx - 1] >= windowStart) {
        startIdx--;
      }

      // Expand forwards to find window end
      while (endIdx < timestamps.length - 1 &&
          timestamps[endIdx + 1] <= windowEnd) {
        endIdx++;
      }

      // If window is too small, expand it to get more data points
      // This helps with sparse pressure data (e.g., recordings every 30 sec)
      int duration = timestamps[endIdx] - timestamps[startIdx];
      while (duration < minDuration &&
          (startIdx > 0 || endIdx < timestamps.length - 1)) {
        // Expand in the direction that adds more time
        if (startIdx > 0 &&
            (endIdx >= timestamps.length - 1 ||
                (timestamps[startIdx] - timestamps[startIdx - 1]) <=
                    (timestamps[endIdx + 1] - timestamps[endIdx]))) {
          startIdx--;
        } else if (endIdx < timestamps.length - 1) {
          endIdx++;
        } else {
          break;
        }
        duration = timestamps[endIdx] - timestamps[startIdx];
      }

      // Calculate SAC for this window
      final pressureDrop = pressures[startIdx] - pressures[endIdx];

      if (duration >= minDuration && pressureDrop > 0) {
        // Calculate average depth over the window
        double depthSum = 0;
        int depthCount = 0;
        for (int j = startIdx; j <= endIdx; j++) {
          depthSum += depths[j];
          depthCount++;
        }
        final avgDepth = depthCount > 0 ? depthSum / depthCount : depths[i];

        // Calculate SAC
        final ambientPressure = 1.0 + (avgDepth / 10.0);
        final consumptionRate = pressureDrop / (duration / 60.0);
        final sac = consumptionRate / ambientPressure;

        result.add(sac);
      } else {
        // No valid consumption in this window
        result.add(0.0);
      }
    }

    return result;
  }

  /// Interpolate SAC values from segment data.
  ///
  /// This creates a smooth SAC curve by interpolating between segment midpoints.
  /// Used as a fallback when rolling window calculation produces sparse data.
  List<double> _interpolateSacFromSegments({
    required List<int> timestamps,
    required List<SacSegment> segments,
  }) {
    if (timestamps.isEmpty || segments.isEmpty) {
      return [];
    }

    final result = <double>[];

    // Create a list of (timestamp, sac) pairs from segment midpoints
    final sacPoints = segments
        .map((s) => (timestamp: s.midTimestamp, sac: s.sacRate))
        .toList();

    for (final timestamp in timestamps) {
      // Find the two segments this timestamp falls between
      int beforeIdx = -1;
      int afterIdx = -1;

      for (int i = 0; i < sacPoints.length; i++) {
        if (sacPoints[i].timestamp <= timestamp) {
          beforeIdx = i;
        }
        if (sacPoints[i].timestamp >= timestamp && afterIdx == -1) {
          afterIdx = i;
        }
      }

      double sac;
      if (beforeIdx == -1 && afterIdx == -1) {
        // No segment data - use 0
        sac = 0.0;
      } else if (beforeIdx == -1) {
        // Before first segment - use first segment's value
        sac = sacPoints[afterIdx].sac;
      } else if (afterIdx == -1 || beforeIdx == afterIdx) {
        // After last segment or exactly on a segment - use that segment's value
        sac = sacPoints[beforeIdx].sac;
      } else {
        // Interpolate between two segments
        final t1 = sacPoints[beforeIdx].timestamp;
        final t2 = sacPoints[afterIdx].timestamp;
        final s1 = sacPoints[beforeIdx].sac;
        final s2 = sacPoints[afterIdx].sac;

        if (t2 == t1) {
          sac = s1;
        } else {
          final ratio = (timestamp - t1) / (t2 - t1);
          sac = s1 + (s2 - s1) * ratio;
        }
      }

      result.add(sac);
    }

    return result;
  }

  /// Calculate SAC over fixed time intervals.
  ///
  /// [intervalSeconds] is the segment duration (default 300 = 5 minutes).
  List<SacSegment> _calculateSacSegments({
    required List<double> depths,
    required List<int> timestamps,
    required List<double> pressures,
    int intervalSeconds = 300,
  }) {
    if (timestamps.isEmpty || pressures.length != depths.length) {
      return [];
    }

    final segments = <SacSegment>[];
    final startTime = timestamps.first;
    final endTime = timestamps.last;

    int segmentStart = startTime;

    while (segmentStart < endTime) {
      final segmentEnd = math.min(segmentStart + intervalSeconds, endTime);

      // Find indices within this segment
      final startIdx = timestamps.indexWhere((t) => t >= segmentStart);
      final endIdx = timestamps.lastIndexWhere((t) => t <= segmentEnd);

      if (startIdx < 0 || endIdx < 0 || endIdx <= startIdx) {
        segmentStart = segmentEnd;
        continue;
      }

      // Calculate segment metrics
      double depthSum = 0;
      double minDepth = double.infinity;
      double maxDepth = 0;
      int count = 0;

      for (int i = startIdx; i <= endIdx; i++) {
        final depth = depths[i];
        depthSum += depth;
        minDepth = math.min(minDepth, depth);
        maxDepth = math.max(maxDepth, depth);
        count++;
      }

      if (count == 0) {
        segmentStart = segmentEnd;
        continue;
      }

      final avgDepth = depthSum / count;
      final pressureStart = pressures[startIdx];
      final pressureEnd = pressures[endIdx];
      final pressureDrop = pressureStart - pressureEnd;
      final segmentDuration = timestamps[endIdx] - timestamps[startIdx];

      // Calculate SAC for segment
      double sacRate = 0;
      if (pressureDrop > 0 && segmentDuration > 0) {
        final ambientPressure = 1.0 + (avgDepth / 10.0);
        final consumptionRate = pressureDrop / (segmentDuration / 60.0);
        sacRate = consumptionRate / ambientPressure;
      }

      // Only add segment if we have valid data
      if (segmentDuration > 30) {
        // At least 30 seconds
        segments.add(
          SacSegment(
            startTimestamp: timestamps[startIdx],
            endTimestamp: timestamps[endIdx],
            avgDepth: avgDepth,
            minDepth: minDepth == double.infinity ? 0 : minDepth,
            maxDepth: maxDepth,
            sacRate: sacRate,
            gasConsumed: pressureDrop > 0 ? pressureDrop : 0,
          ),
        );
      }

      segmentStart = segmentEnd;
    }

    return segments;
  }

  /// Calculate SAC segments based on depth zones.
  ///
  /// Groups the dive into segments based on depth ranges (0-10m, 10-20m, etc.)
  List<SacSegment> calculateDepthBasedSegments({
    required List<double> depths,
    required List<int> timestamps,
    required List<double> pressures,
    double depthInterval = 10.0,
  }) {
    if (timestamps.isEmpty || pressures.length != depths.length) {
      return [];
    }

    // Group points by depth zone
    final zoneData = <int, List<int>>{}; // zone -> list of indices

    for (int i = 0; i < depths.length; i++) {
      final zone = (depths[i] / depthInterval).floor();
      zoneData.putIfAbsent(zone, () => []).add(i);
    }

    final segments = <SacSegment>[];

    for (final entry in zoneData.entries) {
      final indices = entry.value;
      if (indices.length < 2) continue;

      // Sort indices by timestamp
      indices.sort((a, b) => timestamps[a].compareTo(timestamps[b]));

      final startIdx = indices.first;
      final endIdx = indices.last;

      // Calculate metrics
      double depthSum = 0;
      double minDepth = double.infinity;
      double maxDepth = 0;

      for (final i in indices) {
        depthSum += depths[i];
        minDepth = math.min(minDepth, depths[i]);
        maxDepth = math.max(maxDepth, depths[i]);
      }

      final avgDepth = depthSum / indices.length;
      final pressureStart = pressures[startIdx];
      final pressureEnd = pressures[endIdx];
      final pressureDrop = pressureStart - pressureEnd;
      final segmentDuration = timestamps[endIdx] - timestamps[startIdx];

      double sacRate = 0;
      if (pressureDrop > 0 && segmentDuration > 0) {
        final ambientPressure = 1.0 + (avgDepth / 10.0);
        final consumptionRate = pressureDrop / (segmentDuration / 60.0);
        sacRate = consumptionRate / ambientPressure;
      }

      if (segmentDuration > 30) {
        segments.add(
          SacSegment(
            startTimestamp: timestamps[startIdx],
            endTimestamp: timestamps[endIdx],
            avgDepth: avgDepth,
            minDepth: minDepth == double.infinity ? 0 : minDepth,
            maxDepth: maxDepth,
            sacRate: sacRate,
            gasConsumed: pressureDrop > 0 ? pressureDrop : 0,
          ),
        );
      }
    }

    // Sort by start timestamp
    segments.sort((a, b) => a.startTimestamp.compareTo(b.startTimestamp));

    return segments;
  }

  /// Calculate O2 exposure (CNS and OTU) from a pre-calculated ppO2 curve.
  ///
  /// Used for CCR/SCR dives where ppO2 is known directly rather than
  /// calculated from gas fraction and depth.
  O2Exposure _calculateO2ExposureFromPpO2Curve({
    required List<double> ppO2Curve,
    required List<int> timestamps,
    required List<double> depths,
    required double startCns,
  }) {
    if (ppO2Curve.isEmpty || ppO2Curve.length != timestamps.length) {
      return O2Exposure(cnsStart: startCns, cnsEnd: startCns);
    }

    double totalCns = 0.0;
    double totalOtu = 0.0;
    double maxPpO2 = 0.0;
    double depthAtMaxPpO2 = 0.0;
    int timeAboveWarning = 0;
    int timeAboveCritical = 0;

    for (int i = 1; i < ppO2Curve.length; i++) {
      final duration = timestamps[i] - timestamps[i - 1];
      if (duration <= 0) continue;

      // Use average ppO2 for segment
      final avgPpO2 = (ppO2Curve[i - 1] + ppO2Curve[i]) / 2.0;
      final avgDepth = (depths[i - 1] + depths[i]) / 2.0;

      // Track max ppO2
      if (avgPpO2 > maxPpO2) {
        maxPpO2 = avgPpO2;
        depthAtMaxPpO2 = avgDepth;
      }

      // Calculate CNS for this segment
      totalCns += _o2ToxicityCalculator.calculateCnsForSegment(
        avgPpO2,
        duration,
      );

      // Calculate OTU for this segment
      totalOtu += _o2ToxicityCalculator.calculateOtuForSegment(
        avgPpO2,
        duration,
      );

      // Track time above thresholds
      if (avgPpO2 > _o2ToxicityCalculator.ppO2CriticalThreshold) {
        timeAboveCritical += duration;
        timeAboveWarning += duration;
      } else if (avgPpO2 > _o2ToxicityCalculator.ppO2WarningThreshold) {
        timeAboveWarning += duration;
      }
    }

    return O2Exposure(
      cnsStart: startCns,
      cnsEnd: startCns + totalCns,
      otu: totalOtu,
      maxPpO2: maxPpO2,
      maxPpO2Depth: depthAtMaxPpO2,
      timeAboveWarning: timeAboveWarning,
      timeAboveCritical: timeAboveCritical,
    );
  }

  /// Calculate ppN2 (partial pressure of nitrogen) curve.
  ///
  /// ppN2 = ambient_pressure × N2_fraction
  List<double> _calculatePpN2Curve(List<double> depths, double n2Fraction) {
    return depths.map((depth) {
      final ambientPressure = 1.0 + (depth / 10.0);
      return ambientPressure * n2Fraction;
    }).toList();
  }

  /// Calculate ppHe (partial pressure of helium) curve.
  ///
  /// ppHe = ambient_pressure × He_fraction
  List<double> _calculatePpHeCurve(List<double> depths, double heFraction) {
    return depths.map((depth) {
      final ambientPressure = 1.0 + (depth / 10.0);
      return ambientPressure * heFraction;
    }).toList();
  }

  /// Calculate MOD (Maximum Operating Depth) curve.
  ///
  /// MOD = ((maxPpO2 / O2_fraction) - 1) × 10
  /// Using 1.4 bar as the standard recreational MOD limit.
  List<double> _calculateModCurve(List<double> depths, double o2Fraction) {
    // MOD is constant for a given gas, but we return it per point for consistency
    final mod = O2ToxicityCalculator.calculateMod(o2Fraction, maxPpO2: 1.4);
    return List.filled(depths.length, mod);
  }

  /// Calculate gas density curve (g/L).
  ///
  /// Density at depth is critical for work of breathing.
  /// High density (>5.7 g/L) increases CO2 retention risk.
  /// Formula: density = ambient_pressure × sum(fraction × molecular_weight) / 24.04
  ///
  /// Molecular weights (g/mol): O2=32, N2=28, He=4
  /// At STP, 1 mole of gas = 24.04 L
  List<double> _calculateDensityCurve(
    List<double> depths,
    double o2Fraction,
    double n2Fraction,
    double heFraction,
  ) {
    // Average molecular weight of gas mix
    const o2MolWeight = 32.0;
    const n2MolWeight = 28.0;
    const heMolWeight = 4.0;
    const molarVolume = 24.04; // L/mol at STP

    final avgMolWeight =
        (o2Fraction * o2MolWeight) +
        (n2Fraction * n2MolWeight) +
        (heFraction * heMolWeight);

    // Density at surface (1 bar)
    final surfaceDensity = avgMolWeight / molarVolume;

    return depths.map((depth) {
      final ambientPressure = 1.0 + (depth / 10.0);
      return surfaceDensity * ambientPressure;
    }).toList();
  }

  /// Calculate Gradient Factor % curve at current depth.
  ///
  /// GF% = (current_tissue_tension - ambient_pressure) / (M_value - ambient_pressure) × 100
  /// This shows how close the leading compartment is to the M-value limit at current depth.
  List<double> _calculateGfCurve(List<DecoStatus> decoStatuses) {
    return decoStatuses.map((status) {
      final leading = status.leadingCompartment;
      final pTissue = leading.totalInertGas;
      final pAmbient = status.ambientPressureBar;
      final mValue = leading.blendedA + (pAmbient / leading.blendedB);

      // GF% = how far toward M-value we are
      if (mValue <= pAmbient) return 0.0;
      final gfPercent = ((pTissue - pAmbient) / (mValue - pAmbient)) * 100.0;
      return gfPercent.clamp(0.0, 200.0); // Clamp for safety
    }).toList();
  }

  /// Calculate Surface GF% curve (what GF would be if surfaced now).
  ///
  /// This shows the theoretical GF% if the diver ascended directly to surface.
  /// Values >100% indicate deco obligation.
  List<double> _calculateSurfaceGfCurve(List<DecoStatus> decoStatuses) {
    return decoStatuses.map((status) {
      final leading = status.leadingCompartment;
      final pTissue = leading.totalInertGas;
      const pSurface = 1.0; // Surface pressure in bar
      final mValueSurface = leading.blendedA + (pSurface / leading.blendedB);

      // Surface GF% = tissue loading relative to surface M-value
      if (mValueSurface <= pSurface) return 0.0;
      final surfaceGf =
          ((pTissue - pSurface) / (mValueSurface - pSurface)) * 100.0;
      return surfaceGf.clamp(0.0, 200.0);
    }).toList();
  }

  /// Calculate mean depth curve (running average from start).
  ///
  /// Shows the average depth from dive start to each point.
  /// Useful for gas consumption calculations.
  List<double> _calculateMeanDepthCurve(List<double> depths) {
    if (depths.isEmpty) return [];

    final meanDepths = <double>[];
    double depthSum = 0;

    for (int i = 0; i < depths.length; i++) {
      depthSum += depths[i];
      meanDepths.add(depthSum / (i + 1));
    }

    return meanDepths;
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
  })?
  getAnalysisAt(ProfileAnalysis analysis, int timestamp) {
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
      decoStatus: index < analysis.decoStatuses.length
          ? analysis.decoStatuses[index]
          : null,
    );
  }
}

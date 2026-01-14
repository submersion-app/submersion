import 'package:uuid/uuid.dart';

import '../../../../core/deco/buhlmann_algorithm.dart';
import '../../../../core/deco/constants/buhlmann_coefficients.dart';
import '../../../../core/deco/entities/tissue_compartment.dart';
import '../../../../core/deco/o2_toxicity_calculator.dart';
import '../../../dive_log/domain/entities/dive.dart';
import '../../domain/entities/plan_result.dart';
import '../../domain/entities/plan_segment.dart';

/// Service for calculating dive plan results.
///
/// This service processes dive plan segments through the Bühlmann ZH-L16C
/// decompression algorithm and calculates:
/// - Tissue loading and decompression status
/// - Gas consumption projections per tank
/// - CNS% and OTU accumulation
/// - Safety warnings for ppO2, CNS, gas reserves, etc.
class PlanCalculatorService {
  /// Gradient Factor Low (0-100).
  final int gfLow;

  /// Gradient Factor High (0-100).
  final int gfHigh;

  /// ppO2 warning threshold (typically 1.4 bar).
  final double ppO2Warning;

  /// ppO2 critical threshold (typically 1.6 bar).
  final double ppO2Critical;

  /// CNS warning threshold percentage (typically 80).
  final int cnsWarningThreshold;

  /// Default ascent rate in m/min.
  final double defaultAscentRate;

  /// Default descent rate in m/min.
  final double defaultDescentRate;

  final _uuid = const Uuid();

  PlanCalculatorService({
    this.gfLow = 30,
    this.gfHigh = 70,
    this.ppO2Warning = 1.4,
    this.ppO2Critical = 1.6,
    this.cnsWarningThreshold = 80,
    this.defaultAscentRate = 9.0,
    this.defaultDescentRate = 18.0,
  });

  /// Calculate complete plan results from segments.
  ///
  /// [segments] - The dive plan segments in order.
  /// [tanks] - Available tanks with starting pressures and volumes.
  /// [sacRate] - Surface Air Consumption in L/min.
  /// [initialTissueState] - Tissue state from previous dive (for repetitive).
  PlanResult calculatePlan({
    required List<PlanSegment> segments,
    required List<DiveTank> tanks,
    required double sacRate,
    List<TissueCompartment>? initialTissueState,
  }) {
    if (segments.isEmpty) {
      return PlanResult.empty();
    }

    // Initialize the Bühlmann algorithm
    final algorithm = BuhlmannAlgorithm(
      gfLow: gfLow / 100.0,
      gfHigh: gfHigh / 100.0,
      ascentRate: defaultAscentRate,
    );

    // Load tissue state for repetitive dives
    if (initialTissueState != null &&
        initialTissueState.length == zhl16CompartmentCount) {
      algorithm.setCompartments(initialTissueState);
    }

    // Initialize O2 toxicity calculator
    final o2Calc = O2ToxicityCalculator(
      ppO2WarningThreshold: ppO2Warning,
      ppO2CriticalThreshold: ppO2Critical,
      cnsWarningThreshold: cnsWarningThreshold,
    );

    // Track results
    final segmentResults = <String, SegmentResult>{};
    final warnings = <PlanWarning>[];
    final gasUsageByTank = <String, _GasUsageTracker>{};

    // Initialize gas trackers for each tank
    for (final tank in tanks) {
      gasUsageByTank[tank.id] = _GasUsageTracker(
        startPressure: tank.startPressure,
        volume: tank.volume ?? 11.0, // Default AL80 if not specified
      );
    }

    int runtime = 0;
    double maxDepth = 0;
    double totalDepthTime = 0; // For average depth calculation
    int totalTime = 0;
    double maxPpO2 = 0;
    double cnsTotal = 0;
    double otuTotal = 0;
    int? ndlAtBottom;
    int? ttsAtBottom;
    double? maxCeilingDuringDive;

    // Process each segment
    for (final segment in segments) {
      final startRuntime = runtime;

      // Calculate average depth for this segment
      final avgDepth = segment.avgDepth;
      if (segment.endDepth > maxDepth) maxDepth = segment.endDepth;
      if (segment.startDepth > maxDepth) maxDepth = segment.startDepth;

      // Get gas fractions
      final o2Frac = segment.gasMix.o2 / 100.0;
      final heFrac = segment.gasMix.he / 100.0;
      final n2Frac = 1.0 - o2Frac - heFrac;

      // Calculate ppO2 for this segment
      final segmentMaxPpO2 = O2ToxicityCalculator.calculatePpO2(
        segment.startDepth > segment.endDepth
            ? segment.startDepth
            : segment.endDepth,
        o2Frac,
      );
      if (segmentMaxPpO2 > maxPpO2) maxPpO2 = segmentMaxPpO2;

      // Check ppO2 limits
      if (segmentMaxPpO2 > ppO2Critical) {
        warnings.add(
          PlanWarning(
            type: PlanWarningType.ppO2Critical,
            severity: PlanWarningSeverity.critical,
            message:
                'ppO₂ of ${segmentMaxPpO2.toStringAsFixed(2)} bar exceeds critical limit',
            atRuntime: runtime,
            atDepth: maxDepth,
            segmentId: segment.id,
            value: segmentMaxPpO2,
            threshold: ppO2Critical,
          ),
        );
      } else if (segmentMaxPpO2 > ppO2Warning) {
        warnings.add(
          PlanWarning(
            type: PlanWarningType.ppO2High,
            severity: PlanWarningSeverity.warning,
            message:
                'ppO₂ of ${segmentMaxPpO2.toStringAsFixed(2)} bar exceeds working limit',
            atRuntime: runtime,
            atDepth: maxDepth,
            segmentId: segment.id,
            value: segmentMaxPpO2,
            threshold: ppO2Warning,
          ),
        );
      }

      // Process segment through Bühlmann algorithm
      algorithm.calculateSegment(
        depthMeters: avgDepth,
        durationSeconds: segment.durationSeconds,
        fN2: n2Frac,
        fHe: heFrac,
      );

      // Get deco status after segment
      final decoStatus = algorithm.getDecoStatus(
        currentDepth: segment.endDepth,
        fN2: n2Frac,
        fHe: heFrac,
      );

      // Track NDL/TTS at maximum depth point
      if (segment.type == SegmentType.bottom ||
          (segment.endDepth >= maxDepth - 0.1)) {
        ndlAtBottom = decoStatus.ndlSeconds;
        ttsAtBottom = decoStatus.ttsSeconds;
      }

      // Track max ceiling
      if (decoStatus.ceilingMeters > (maxCeilingDuringDive ?? 0)) {
        maxCeilingDuringDive = decoStatus.ceilingMeters;
      }

      // Check for deco obligation
      if (decoStatus.ndlSeconds < 0 && segment.type == SegmentType.bottom) {
        warnings.add(
          PlanWarning(
            type: PlanWarningType.ndlExceeded,
            severity: PlanWarningSeverity.alert,
            message: 'Dive enters decompression obligation',
            atRuntime: runtime + segment.durationSeconds,
            atDepth: segment.endDepth,
            segmentId: segment.id,
          ),
        );
      }

      // Calculate CNS and OTU for segment
      final avgPpO2 = O2ToxicityCalculator.calculatePpO2(avgDepth, o2Frac);
      final segmentCns = o2Calc.calculateCnsForSegment(
        avgPpO2,
        segment.durationSeconds,
      );
      final segmentOtu = o2Calc.calculateOtuForSegment(
        avgPpO2,
        segment.durationSeconds,
      );
      cnsTotal += segmentCns;
      otuTotal += segmentOtu;

      // Check CNS
      if (cnsTotal >= 100) {
        warnings.add(
          PlanWarning(
            type: PlanWarningType.cnsCritical,
            severity: PlanWarningSeverity.critical,
            message: 'CNS% exceeds 100%',
            atRuntime: runtime + segment.durationSeconds,
            segmentId: segment.id,
            value: cnsTotal,
            threshold: 100,
          ),
        );
      } else if (cnsTotal >= cnsWarningThreshold) {
        warnings.add(
          PlanWarning(
            type: PlanWarningType.cnsWarning,
            severity: PlanWarningSeverity.warning,
            message: 'CNS% exceeds $cnsWarningThreshold%',
            atRuntime: runtime + segment.durationSeconds,
            segmentId: segment.id,
            value: cnsTotal,
            threshold: cnsWarningThreshold.toDouble(),
          ),
        );
      }

      // Calculate gas consumption for this segment
      final gasUsedLiters = _calculateGasConsumption(
        sacRate: sacRate,
        avgDepth: avgDepth,
        durationSeconds: segment.durationSeconds,
      );

      // Update tank usage
      final tracker = gasUsageByTank[segment.tankId];
      if (tracker != null) {
        tracker.addGasUsed(gasUsedLiters);
      }

      // Update runtime and depth-time totals
      runtime += segment.durationSeconds;
      totalDepthTime += avgDepth * segment.durationSeconds;
      totalTime += segment.durationSeconds;

      // Store segment results
      segmentResults[segment.id] = SegmentResult(
        segmentId: segment.id,
        startRuntime: startRuntime,
        endRuntime: runtime,
        ndlAtEnd: decoStatus.ndlSeconds,
        ceilingAtEnd: decoStatus.ceilingMeters,
        ttsAtEnd: decoStatus.ttsSeconds,
        cnsAtEnd: cnsTotal,
        otuAccumulated: segmentOtu,
        gasConsumedLiters: gasUsedLiters,
        maxPpO2: segmentMaxPpO2,
        avgDepth: avgDepth,
      );
    }

    // Calculate average depth
    final avgDepth = totalTime > 0 ? totalDepthTime / totalTime : 0.0;

    // Build gas consumption results
    final gasConsumptions = <GasConsumption>[];
    for (final tank in tanks) {
      final tracker = gasUsageByTank[tank.id];
      if (tracker != null) {
        final gasUsedBar = tracker.gasUsedBar;
        final remainingPressure = tracker.remainingPressure;
        final percentUsed = tracker.percentUsed;

        // Check for gas warnings
        if (remainingPressure != null && remainingPressure <= 0) {
          warnings.add(
            PlanWarning(
              type: PlanWarningType.gasOut,
              severity: PlanWarningSeverity.critical,
              message: 'Tank ${tank.name ?? tank.gasMix.name} will be empty',
              value: remainingPressure.toDouble(),
            ),
          );
        } else if (remainingPressure != null && remainingPressure < 50) {
          warnings.add(
            PlanWarning(
              type: PlanWarningType.gasLow,
              severity: PlanWarningSeverity.alert,
              message:
                  'Tank ${tank.name ?? tank.gasMix.name} below 50 bar reserve',
              value: remainingPressure.toDouble(),
              threshold: 50,
            ),
          );
        }

        gasConsumptions.add(
          GasConsumption(
            tankId: tank.id,
            tankName: tank.name,
            gasMix: tank.gasMix,
            gasUsedLiters: tracker.gasUsedLiters,
            gasUsedBar: gasUsedBar,
            startPressure: tank.startPressure,
            remainingPressure: remainingPressure,
            percentUsed: percentUsed,
            reserveViolation:
                remainingPressure != null && remainingPressure < 50,
          ),
        );
      }
    }

    // Get deco schedule for final state
    final decoSchedule = _buildDecoSchedule(
      algorithm: algorithm,
      segments: segments,
      runtime: runtime,
    );

    // Determine if dive has deco obligation
    final hasDecoObligation = ndlAtBottom != null && ndlAtBottom < 0;

    return PlanResult(
      totalRuntime: runtime,
      ttsAtBottom: ttsAtBottom ?? 0,
      ndlAtBottom: ndlAtBottom ?? 0,
      maxDepth: maxDepth,
      maxCeiling: maxCeilingDuringDive ?? 0,
      avgDepth: avgDepth,
      decoSchedule: decoSchedule,
      gasConsumptions: gasConsumptions,
      warnings: warnings,
      endTissueState: algorithm.compartments,
      segmentResults: segmentResults,
      cnsEnd: cnsTotal,
      otuTotal: otuTotal,
      maxPpO2: maxPpO2,
      hasDecoObligation: hasDecoObligation,
    );
  }

  /// Calculate gas consumption for a segment.
  ///
  /// Formula: gas = SAC × time_min × (avgDepth/10 + 1)
  double _calculateGasConsumption({
    required double sacRate,
    required double avgDepth,
    required int durationSeconds,
  }) {
    final pressureAtm = (avgDepth / 10.0) + 1.0;
    final timeMinutes = durationSeconds / 60.0;
    return sacRate * timeMinutes * pressureAtm;
  }

  /// Build deco schedule from current algorithm state.
  List<DecoStop> _buildDecoSchedule({
    required BuhlmannAlgorithm algorithm,
    required List<PlanSegment> segments,
    required int runtime,
  }) {
    if (segments.isEmpty) return [];

    // Find the last non-surface depth
    final lastSegment = segments.last;
    final currentDepth = lastSegment.endDepth;

    if (currentDepth <= 0) return [];

    // Get deco schedule from algorithm
    final algoStops = algorithm.calculateDecoSchedule(
      currentDepth: currentDepth,
    );

    // Convert to our DecoStop type
    int arrivalRuntime = runtime;
    return algoStops.map((stop) {
      final decoStop = DecoStop(
        depth: stop.depthMeters,
        durationSeconds: stop.durationSeconds,
        gasMix: const GasMix(), // Default to air, can be optimized
        arrivalRuntime: arrivalRuntime,
      );
      arrivalRuntime += stop.durationSeconds;
      return decoStop;
    }).toList();
  }

  /// Apply surface interval off-gassing to tissue state.
  ///
  /// [startState] - Tissue state at end of previous dive.
  /// [interval] - Surface interval duration.
  /// Returns new tissue state after off-gassing.
  List<TissueCompartment> calculateSurfaceInterval({
    required List<TissueCompartment> startState,
    required Duration interval,
  }) {
    final algorithm = BuhlmannAlgorithm(
      gfLow: gfLow / 100.0,
      gfHigh: gfHigh / 100.0,
    );

    algorithm.setCompartments(startState);

    // Simulate breathing air at surface
    algorithm.calculateSegment(
      depthMeters: 0,
      durationSeconds: interval.inSeconds,
      fN2: airN2Fraction,
      fHe: 0.0,
    );

    return algorithm.compartments;
  }

  /// Generate profile points from segments for charting.
  ///
  /// Returns a list of profile points suitable for visualization.
  List<DiveProfilePoint> generateProfilePoints(List<PlanSegment> segments) {
    final points = <DiveProfilePoint>[];
    int timestamp = 0;

    for (final segment in segments) {
      // Add start point
      points.add(
        DiveProfilePoint(timestamp: timestamp, depth: segment.startDepth),
      );

      // Add intermediate points for depth changes
      if (segment.isDepthChange) {
        // Add points at regular intervals for smooth visualization
        const intervalSeconds = 10;
        final numIntervals = segment.durationSeconds ~/ intervalSeconds;

        for (int i = 1; i < numIntervals; i++) {
          final progress = i / numIntervals;
          final depth =
              segment.startDepth +
              (segment.endDepth - segment.startDepth) * progress;
          points.add(
            DiveProfilePoint(
              timestamp: timestamp + (intervalSeconds * i),
              depth: depth,
            ),
          );
        }
      }

      timestamp += segment.durationSeconds;

      // Add end point
      points.add(
        DiveProfilePoint(timestamp: timestamp, depth: segment.endDepth),
      );
    }

    return points;
  }

  /// Create a simple rectangular dive plan.
  ///
  /// [maxDepth] - Target depth in meters.
  /// [bottomTime] - Bottom time in minutes.
  /// [tank] - Tank to use for the dive.
  /// Returns list of segments for descent, bottom, and ascent.
  List<PlanSegment> createSimplePlan({
    required double maxDepth,
    required int bottomTimeMinutes,
    required DiveTank tank,
  }) {
    final segments = <PlanSegment>[];

    // Descent segment
    segments.add(
      PlanSegment.descent(
        id: _uuid.v4(),
        targetDepth: maxDepth,
        tankId: tank.id,
        gasMix: tank.gasMix,
        rate: defaultDescentRate,
        order: 0,
      ),
    );

    // Bottom segment
    segments.add(
      PlanSegment.bottom(
        id: _uuid.v4(),
        depth: maxDepth,
        durationMinutes: bottomTimeMinutes,
        tankId: tank.id,
        gasMix: tank.gasMix,
        order: 1,
      ),
    );

    // Safety stop (if needed)
    if (maxDepth > 10) {
      segments.add(
        PlanSegment.ascent(
          id: _uuid.v4(),
          fromDepth: maxDepth,
          toDepth: 5.0,
          tankId: tank.id,
          gasMix: tank.gasMix,
          rate: defaultAscentRate,
          order: 2,
        ),
      );

      segments.add(
        PlanSegment.safetyStop(
          id: _uuid.v4(),
          tankId: tank.id,
          gasMix: tank.gasMix,
          order: 3,
        ),
      );

      segments.add(
        PlanSegment.ascent(
          id: _uuid.v4(),
          fromDepth: 5.0,
          toDepth: 0.0,
          tankId: tank.id,
          gasMix: tank.gasMix,
          rate: defaultAscentRate,
          order: 4,
        ),
      );
    } else {
      // Direct ascent for shallow dives
      segments.add(
        PlanSegment.ascent(
          id: _uuid.v4(),
          fromDepth: maxDepth,
          toDepth: 0.0,
          tankId: tank.id,
          gasMix: tank.gasMix,
          rate: defaultAscentRate,
          order: 2,
        ),
      );
    }

    return segments;
  }
}

/// Internal tracker for gas usage per tank.
class _GasUsageTracker {
  final int? startPressure;
  final double volume;
  double gasUsedLiters = 0;

  _GasUsageTracker({this.startPressure, required this.volume});

  void addGasUsed(double liters) {
    gasUsedLiters += liters;
  }

  /// Convert liters used to bar used.
  double get gasUsedBar => volume > 0 ? gasUsedLiters / volume : 0;

  /// Calculate remaining pressure.
  int? get remainingPressure {
    if (startPressure == null) return null;
    return (startPressure! - gasUsedBar).round();
  }

  /// Calculate percentage of tank used.
  double get percentUsed {
    if (startPressure == null || startPressure == 0) return 0;
    return (gasUsedBar / startPressure!) * 100;
  }
}

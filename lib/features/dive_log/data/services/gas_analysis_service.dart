import 'dart:math' as math;

import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_lookup.dart';
import 'package:submersion/features/dive_log/domain/services/tank_usage_range.dart';

/// Service for calculating SAC (Surface Air Consumption) metrics
/// per segment and per cylinder.
///
/// This service provides multiple segmentation methods:
/// - **Time-based**: Fixed intervals (e.g., every 5 minutes)
/// - **Gas-switch**: Segments divided by tank changes
/// - **Depth-phase**: Segments based on dive phases (descent, bottom, ascent)
class GasAnalysisService {
  /// Equation of state used to convert cylinder pressure to gas volume.
  ///
  /// Injected from `gasModelProvider` so a change to the preference rebuilds
  /// this service and invalidates every SAC readout that depends on it.
  final GasModel gasModel;

  const GasAnalysisService({this.gasModel = GasModel.real});

  /// Minimum segment duration in seconds to be considered valid
  static const int minSegmentDuration = 30;

  /// Depth threshold for safety stop detection (meters)
  static const double safetyStopMinDepth = 3.0;
  static const double safetyStopMaxDepth = 6.0;

  /// Minimum duration for safety stop in seconds
  static const int safetyStopMinDuration = 120;

  /// Calculate SAC segments using gas-switch segmentation.
  ///
  /// Segments are divided at each gas/tank switch event.
  /// Returns null if no gas switches recorded.
  List<SacSegment>? calculateGasSwitchSegments({
    required List<DiveProfilePoint> profile,
    required List<DiveTank> tanks,
    required List<GasSwitchWithTank> gasSwitches,
    Map<String, List<TankPressurePoint>>? tankPressures,
  }) {
    if (profile.isEmpty || gasSwitches.isEmpty) return null;

    final resolvedPressures = resolveTankPressureSeries(tanks, tankPressures);
    final segments = <SacSegment>[];
    final diveEndTimestamp = profile.last.timestamp;

    // Sort gas switches by timestamp
    final sortedSwitches = List<GasSwitchWithTank>.from(gasSwitches)
      ..sort((a, b) => a.gasSwitch.timestamp.compareTo(b.gasSwitch.timestamp));

    // Create segments from gas switch boundaries
    for (int i = 0; i < sortedSwitches.length; i++) {
      final currentSwitch = sortedSwitches[i];
      final startTime = currentSwitch.gasSwitch.timestamp;
      final endTime = i + 1 < sortedSwitches.length
          ? sortedSwitches[i + 1].gasSwitch.timestamp
          : diveEndTimestamp;

      if (endTime - startTime < minSegmentDuration) continue;

      // Find the tank for this segment
      final tank = tanks.firstWhere(
        (t) => t.id == currentSwitch.gasSwitch.tankId,
        orElse: () => tanks.first,
      );

      // Get profile points for this segment
      final segmentProfile = profile
          .where((p) => p.timestamp >= startTime && p.timestamp < endTime)
          .toList();

      if (segmentProfile.isEmpty) continue;

      // Calculate depth statistics
      final depths = segmentProfile.map((p) => p.depth).toList();
      final avgDepth = depths.reduce((a, b) => a + b) / depths.length;
      final minDepth = depths.reduce(math.min);
      final maxDepth = depths.reduce(math.max);

      // Calculate SAC for this segment
      final sacRate = _calculateSegmentSac(
        profile: segmentProfile,
        tank: tank,
        tankVolume: consumptionVolume(tank, tanks),
        tankPressures: resolvedPressures[tank.id],
        startTime: startTime,
        endTime: endTime,
        prorationWindows: _prorationWindows(
          tank: tank,
          tanks: tanks,
          profile: profile,
          gasSwitches: sortedSwitches,
        ),
      );

      if (sacRate == null) continue;

      // Calculate gas consumed
      final durationMin = (endTime - startTime) / 60.0;
      final ambientPressureBar = (avgDepth / 10.0) + 1.0;
      final gasConsumed = sacRate * durationMin * ambientPressureBar;

      segments.add(
        SacSegment(
          startTimestamp: startTime,
          endTimestamp: endTime,
          avgDepth: avgDepth,
          minDepth: minDepth,
          maxDepth: maxDepth,
          sacRate: sacRate,
          gasConsumed: gasConsumed,
          tankId: tank.id,
          tankName: currentSwitch.tankName,
          gasMix: GasMix(
            o2: currentSwitch.o2Fraction * 100,
            he: currentSwitch.heFraction * 100,
          ),
          segmentationType: SacSegmentationType.gasSwitch,
        ),
      );
    }

    return segments.isEmpty ? null : segments;
  }

  /// Calculate SAC segments using depth-phase segmentation.
  ///
  /// Automatically detects dive phases: descent, bottom, ascent, safety stop.
  List<SacSegment>? calculatePhaseSegments({
    required List<DiveProfilePoint> profile,
    required List<DiveTank> tanks,
    Map<String, List<TankPressurePoint>>? tankPressures,
    List<GasSwitchWithTank>? gasSwitches,
  }) {
    if (profile.length < 10) return null;

    final resolvedPressures = resolveTankPressureSeries(tanks, tankPressures);

    // Find max depth
    final maxDepth = profile.map((p) => p.depth).reduce(math.max);
    if (maxDepth < 3.0) return null; // Too shallow

    // Classify each profile point by phase
    final phasePoints = <({int timestamp, DivePhase phase})>[];
    for (int i = 0; i < profile.length; i++) {
      final phase = _classifyPhase(profile, i, maxDepth);
      phasePoints.add((timestamp: profile[i].timestamp, phase: phase));
    }

    // Group consecutive points by phase
    final rawSegments = <({int start, int end, DivePhase phase})>[];
    DivePhase? currentPhase;
    int segmentStart = profile.first.timestamp;

    for (int i = 0; i < phasePoints.length; i++) {
      final point = phasePoints[i];
      if (currentPhase == null) {
        currentPhase = point.phase;
        segmentStart = point.timestamp;
      } else if (point.phase != currentPhase) {
        rawSegments.add((
          start: segmentStart,
          end: point.timestamp,
          phase: currentPhase,
        ));
        currentPhase = point.phase;
        segmentStart = point.timestamp;
      }
    }

    // Add final segment
    if (currentPhase != null) {
      rawSegments.add((
        start: segmentStart,
        end: profile.last.timestamp,
        phase: currentPhase,
      ));
    }

    // Merge small segments (< minSegmentDuration) into adjacent ones
    final mergedSegments = _mergeSmallSegments(rawSegments);

    // Calculate SAC for each phase segment
    final segments = <SacSegment>[];
    for (final seg in mergedSegments) {
      final segmentProfile = profile
          .where((p) => p.timestamp >= seg.start && p.timestamp < seg.end)
          .toList();

      if (segmentProfile.isEmpty) continue;

      // Find active tank for this segment
      final tank = activeTankAt(
        tanks: tanks,
        gasSwitches: gasSwitches,
        timestamp: seg.start,
        diveStart: profile.first.timestamp,
      );
      if (tank == null) continue;

      // Calculate depth statistics
      final depths = segmentProfile.map((p) => p.depth).toList();
      final avgDepth = depths.reduce((a, b) => a + b) / depths.length;
      final minD = depths.reduce(math.min);
      final maxD = depths.reduce(math.max);

      // Calculate SAC
      final usageWindows = _prorationWindows(
        tank: tank,
        tanks: tanks,
        profile: profile,
        gasSwitches: gasSwitches,
      );
      // A phase can outlast its cylinder's breathing time; only what was
      // breathed of it drew on this tank, at the depths it was breathed.
      final breathedProfile = segmentProfile
          .where((p) => usageWindows.covers(p.timestamp))
          .toList();
      final sacProfile = breathedProfile.isEmpty
          ? segmentProfile
          : breathedProfile;

      final sacRate = _calculateSegmentSac(
        profile: sacProfile,
        tank: tank,
        tankVolume: consumptionVolume(tank, tanks),
        tankPressures: resolvedPressures[tank.id],
        startTime: seg.start,
        endTime: seg.end,
        prorationWindows: usageWindows,
      );

      if (sacRate == null) continue;

      final durationMin =
          usageWindows.breathedBetween(seg.start, seg.end) / 60.0;
      final breathedDepth =
          sacProfile.map((p) => p.depth).reduce((a, b) => a + b) /
          sacProfile.length;
      final ambientPressureBar = (breathedDepth / 10.0) + 1.0;
      final gasConsumed = sacRate * durationMin * ambientPressureBar;

      segments.add(
        SacSegment(
          startTimestamp: seg.start,
          endTimestamp: seg.end,
          avgDepth: avgDepth,
          minDepth: minD,
          maxDepth: maxD,
          sacRate: sacRate,
          gasConsumed: gasConsumed,
          tankId: tank.id,
          tankName: tank.name,
          gasMix: tank.gasMix,
          phase: seg.phase,
          segmentationType: SacSegmentationType.depthPhase,
        ),
      );
    }

    return segments.isEmpty ? null : segments;
  }

  /// Calculate SAC for each cylinder independently.
  ///
  /// Works with basic tank data (start/end pressures) and provides
  /// enhanced accuracy when time-series pressure data is available.
  List<CylinderSac> calculateCylinderSac({
    required Dive dive,
    required List<DiveProfilePoint> profile,
    List<GasSwitchWithTank>? gasSwitches,
    Map<String, List<TankPressurePoint>>? tankPressures,
  }) {
    final results = <CylinderSac>[];

    // Resolve each tank's time-series pressure, tolerating series that were
    // re-keyed under a stale tank id (see [resolveTankPressureSeries]).
    final resolvedPressures = resolveTankPressureSeries(
      dive.tanks,
      tankPressures,
    );

    final diveEnd =
        dive.effectiveRuntime?.inSeconds ?? profile.lastOrNull?.timestamp ?? 0;
    // Only a switch that says when a cylinder was breathed overrides a
    // recorded duration: not a stale id (#110), nor one after the dive.
    final hasGasSwitches = knownGasSwitches(
      dive.tanks,
      gasSwitches,
      before: diveEnd,
    ).isNotEmpty;

    for (final tank in dive.tanks) {
      // Its own size, else its matched partner's (issue #3109).
      final volume = consumptionVolume(tank, dive.tanks);
      // How long the source log says this tank was breathed (issue #1496).
      // Gas switches say when, which is more, so they win; without them
      // this is the only thing that tells two same-role tanks apart.
      final recordedSeconds = hasGasSwitches
          ? null
          : tank.usageDuration?.inSeconds;
      final hasRecordedUsage = recordedSeconds != null && recordedSeconds > 0;

      // Determine when this tank was in use. A recorded duration says how
      // long but not when, so its depth window is the whole dive.
      final usageWindows = hasRecordedUsage
          ? [(start: 0, end: diveEnd > 0 ? diveEnd : recordedSeconds)]
          : tankUsageWindows(
              tank: tank,
              gasSwitches: gasSwitches,
              diveStart: 0,
              diveEnd: diveEnd,
              tanks: dive.tanks,
            );

      if (usageWindows.isEmpty) continue;
      final usageSeconds = hasRecordedUsage
          ? recordedSeconds
          : usageWindows.breathedSeconds;

      // Get profile points during tank usage
      final usageProfile = profile
          .where((p) => usageWindows.covers(p.timestamp))
          .toList();

      // Calculate average depth during usage
      double? avgDepthDuringUse;
      if (usageProfile.isNotEmpty) {
        avgDepthDuringUse =
            usageProfile.map((p) => p.depth).reduce((a, b) => a + b) /
            usageProfile.length;
      }

      // Check if we have time-series pressure data for this tank (matched by
      // id, or adopted from a re-keyed/orphaned series).
      final tsPressures = resolvedPressures[tank.id];
      final hasTsData = tsPressures != null;

      // Calculate SAC rate
      double? sacRate;

      if (tsPressures != null && tsPressures.length >= 2) {
        // Enhanced calculation using time-series data
        sacRate = _calculateSacFromTimeSeries(
          pressurePoints: tsPressures,
          // A cylinder holds its pressure between breathing periods, so the
          // drop from the first to the last is the gas breathed in them all.
          startTime: usageWindows.first.start,
          endTime: usageWindows.last.end,
          avgDepth: avgDepthDuringUse ?? dive.avgDepth ?? 10.0,
          tankVolume: volume,
          gasMix: tank.gasMix,
          breathingSeconds: usageSeconds,
        );
      }
      // A series that shows no drop over the window (a flat or lost
      // transmitter) falls back to the logged pressures (issue #3373).
      if (sacRate == null &&
          tank.startPressure != null &&
          tank.endPressure != null &&
          (avgDepthDuringUse ?? dive.avgDepth) != null) {
        // Basic calculation from start/end pressures with Z-factor correction.
        //
        // Fall back to the dive's average depth when there are no profile
        // samples in the usage window (older or manually-logged dives store a
        // summary avgDepth but no depth profile). Without this the ambient
        // pressure correction below could not run and SAC by cylinder would be
        // blank for every profileless dive (issue #510).
        final effectiveAvgDepth = avgDepthDuringUse ?? dive.avgDepth!;
        final pressureUsed = tank.startPressure! - tank.endPressure!;
        if (pressureUsed > 0) {
          final durationMin = usageSeconds / 60.0;
          if (durationMin > 0) {
            final ambientPressureBar = (effectiveAvgDepth / 10.0) + 1.0;
            if (volume != null) {
              sacRate = _zCorrectedSacRate(
                tankVolume: volume,
                startPressureBar: tank.startPressure!,
                endPressureBar: tank.endPressure!,
                o2Percent: tank.gasMix.o2,
                hePercent: tank.gasMix.he,
                durationMin: durationMin,
                ambientPressureBar: ambientPressureBar,
                model: gasModel,
              );
            } else {
              // Fallback: pressure-based SAC (bar/min) when no tank volume
              sacRate = pressureUsed / durationMin / ambientPressureBar;
            }
          }
        }
      }

      results.add(
        CylinderSac(
          tankId: tank.id,
          tankName: tank.name,
          gasMix: tank.gasMix,
          role: tank.role,
          tankVolume: volume,
          sacRate: sacRate,
          startPressure: tank.startPressure,
          endPressure: tank.endPressure,
          usageDuration: Duration(seconds: usageSeconds),
          avgDepthDuringUse: avgDepthDuringUse,
          hasTimeSeriesData: hasTsData,
          order: tank.order,
        ),
      );
    }

    // Sort by tank order
    results.sort((a, b) => a.order.compareTo(b.order));
    return results;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private Helper Methods
  // ─────────────────────────────────────────────────────────────────────────

  /// When [tank]'s logged pressure drop happened, to share it among segments:
  /// its usage windows when the gas switches identify any, else the whole
  /// dive. A tank only breathed for part of the dive must not have its drop
  /// spread across all of it. Empty when the switches name other cylinders
  /// and never this one: a stale switch that fell back to it says nothing.
  static List<TankUsageWindow> _prorationWindows({
    required DiveTank tank,
    required List<DiveTank> tanks,
    required List<DiveProfilePoint> profile,
    required List<GasSwitchWithTank>? gasSwitches,
  }) {
    final diveStart = profile.first.timestamp;
    final diveEnd = profile.last.timestamp;
    final windows = tankUsageWindows(
      tank: tank,
      gasSwitches: gasSwitches,
      diveStart: diveStart,
      diveEnd: diveEnd,
      tanks: tanks,
    );
    if (windows.isNotEmpty) return windows;
    return knownGasSwitches(tanks, gasSwitches, before: diveEnd).isEmpty
        ? [(start: diveStart, end: diveEnd)]
        : const [];
  }

  /// Compute SAC rate under [model], using its gas volumes.
  ///
  /// Returns the SAC rate in bar/min at surface, or null if gas used ≤ 0.
  /// gasVolume() returns liters at 1 bar, so dividing by tankVolume yields
  /// bar directly and [ambientPressureBar] is in the same reference.
  static double? _zCorrectedSacRate({
    required double tankVolume,
    required double startPressureBar,
    required double endPressureBar,
    required double o2Percent,
    required double hePercent,
    required double durationMin,
    required double ambientPressureBar,
    required GasModel model,
  }) {
    if (tankVolume <= 0 || durationMin <= 0 || ambientPressureBar <= 0) {
      return null;
    }
    final startVol = gasVolume(
      tankSizeLiters: tankVolume,
      pressureBar: startPressureBar,
      o2Percent: o2Percent,
      hePercent: hePercent,
      model: model,
    );
    final endVol = gasVolume(
      tankSizeLiters: tankVolume,
      pressureBar: endPressureBar,
      o2Percent: o2Percent,
      hePercent: hePercent,
      model: model,
    );
    final gasUsedLiters = startVol - endVol;
    if (gasUsedLiters <= 0) return null;
    return gasUsedLiters / tankVolume / durationMin / ambientPressureBar;
  }

  /// Classify a profile point into a dive phase
  DivePhase _classifyPhase(
    List<DiveProfilePoint> profile,
    int index,
    double maxDepth,
  ) {
    final point = profile[index];
    final depth = point.depth;

    // Safety stop detection: 3-6m depth
    if (depth >= safetyStopMinDepth && depth <= safetyStopMaxDepth) {
      // Check if we're stable at this depth (could be safety stop)
      // Look at surrounding points
      int stableCount = 0;
      for (
        int i = math.max(0, index - 10);
        i < math.min(profile.length, index + 10);
        i++
      ) {
        if (profile[i].depth >= safetyStopMinDepth &&
            profile[i].depth <= safetyStopMaxDepth) {
          stableCount++;
        }
      }
      // If we have many points in safety stop range, it's likely a safety stop
      if (stableCount > 15) {
        return DivePhase.safetyStop;
      }
    }

    // Bottom: within 15% of max depth
    final bottomThreshold = maxDepth * 0.85;
    if (depth >= bottomThreshold) {
      return DivePhase.bottom;
    }

    // Calculate rate of depth change
    double depthRate = 0;
    if (index > 0) {
      final prevPoint = profile[index - 1];
      final timeDiff = point.timestamp - prevPoint.timestamp;
      if (timeDiff > 0) {
        depthRate = (depth - prevPoint.depth) / (timeDiff / 60.0); // m/min
      }
    }

    // Descent: significant depth increase
    if (depthRate > 3.0) {
      return DivePhase.descent;
    }

    // Ascent: significant depth decrease
    if (depthRate < -1.0) {
      return DivePhase.ascent;
    }

    // Default based on position in dive
    // If before max depth, likely descent/bottom; after, likely ascent
    final maxDepthIndex = profile.indexWhere((p) => p.depth == maxDepth);
    if (index <= maxDepthIndex) {
      return depth < bottomThreshold ? DivePhase.descent : DivePhase.bottom;
    } else {
      return DivePhase.ascent;
    }
  }

  /// Merge small segments into adjacent ones
  List<({int start, int end, DivePhase phase})> _mergeSmallSegments(
    List<({int start, int end, DivePhase phase})> segments,
  ) {
    if (segments.length <= 1) return segments;

    final merged = <({int start, int end, DivePhase phase})>[];
    var current = segments.first;

    for (int i = 1; i < segments.length; i++) {
      final next = segments[i];
      final currentDuration = current.end - current.start;

      if (currentDuration < minSegmentDuration) {
        // Merge into next segment
        current = (start: current.start, end: next.end, phase: next.phase);
      } else {
        merged.add(current);
        current = next;
      }
    }

    // Add the last segment
    merged.add(current);

    return merged;
  }

  /// Calculate SAC for a segment from profile data
  double? _calculateSegmentSac({
    required List<DiveProfilePoint> profile,
    required DiveTank tank,
    // The tank's own size, else its matched partner's (issue #3109).
    required double? tankVolume,
    List<TankPressurePoint>? tankPressures,
    required int startTime,
    required int endTime,
    required List<TankUsageWindow> prorationWindows,
  }) {
    if (profile.isEmpty) return null;

    final durationSec = endTime - startTime;
    if (durationSec < minSegmentDuration) return null;

    // Calculate average depth
    final depths = profile.map((p) => p.depth).toList();
    final avgDepth = depths.reduce((a, b) => a + b) / depths.length;
    if (avgDepth <= 0) return null;

    double? pressureUsed;
    double? startPressure;
    double? endPressure;
    // A phase can outlast the tank's breathing time, which is what its drop
    // happened over. None at all is a segment a stale switch handed to it,
    // where only a transmitter can say the tank was on the regulator.
    final breathedInSegment = prorationWindows.breathedBetween(
      startTime,
      endTime,
    );

    // Try time-series pressure data first
    if (tankPressures != null && tankPressures.length >= 2) {
      startPressure = pressureAtTime(tankPressures, startTime);
      endPressure = pressureAtTime(tankPressures, endTime);
      if (startPressure != null && endPressure != null) {
        pressureUsed = startPressure - endPressure;
      }
    }

    // Fallback: estimate from tank start/end (less accurate for segments)
    if (pressureUsed == null || pressureUsed <= 0) {
      if (tank.startPressure != null && tank.endPressure != null) {
        // Prorate across the window the tank was actually breathed, NOT the
        // segment's own span: the profile passed in is the segment slice, so
        // dividing by it made proportion ~1.0 and charged every segment the
        // entire cylinder (#110). The window is the tank's usage range when
        // gas switches identify it -- spreading a stage/deco tank's drop over
        // the whole dive would understate its SAC by the ratio of its stint
        // to the dive, and calculateCylinderSac already prorates this way.
        // Time counts only inside the window, which a tank the diver came
        // back to leaves and re-enters and a phase can outlast (#3900).
        final totalDuration = prorationWindows.breathedSeconds;
        if (totalDuration > 0) {
          final tankPressureUsed = tank.startPressure! - tank.endPressure!;
          final breathedBefore = prorationWindows.breathedBefore(startTime);
          pressureUsed = tankPressureUsed * breathedInSegment / totalDuration;
          // Estimate absolute pressures for this segment
          startPressure =
              tank.startPressure! -
              (tankPressureUsed * breathedBefore / totalDuration);
          endPressure = startPressure - pressureUsed;
        }
      }
    }

    if (pressureUsed == null || pressureUsed <= 0) return null;

    // Calculate SAC under the configured gas model
    final durationMin =
        (breathedInSegment > 0 ? breathedInSegment : durationSec) / 60.0;
    final ambientPressureBar = (avgDepth / 10.0) + 1.0;

    // Use volume-corrected SAC when tank data available
    if (tankVolume != null && startPressure != null && endPressure != null) {
      final result = _zCorrectedSacRate(
        tankVolume: tankVolume,
        startPressureBar: startPressure,
        endPressureBar: endPressure,
        o2Percent: tank.gasMix.o2,
        hePercent: tank.gasMix.he,
        durationMin: durationMin,
        ambientPressureBar: ambientPressureBar,
        model: gasModel,
      );
      if (result != null) return result;
    }

    return pressureUsed / durationMin / ambientPressureBar;
  }

  /// Calculate SAC from time-series pressure data
  double? _calculateSacFromTimeSeries({
    required List<TankPressurePoint> pressurePoints,
    required int startTime,
    required int endTime,
    required double avgDepth,
    double? tankVolume,
    GasMix gasMix = const GasMix(),
    // The breathing time when it is not the window's length: a recorded
    // usage duration (issue #1496) measured over a whole-dive window, or the
    // periods of a cylinder the diver came back to (issue #3900).
    int? breathingSeconds,
  }) {
    if (pressurePoints.length < 2) return null;

    final startPressure = pressureAtTime(pressurePoints, startTime);
    final endPressure = pressureAtTime(pressurePoints, endTime);

    if (startPressure == null || endPressure == null) return null;

    final pressureUsed = startPressure - endPressure;
    if (pressureUsed <= 0) return null;

    final durationMin = (breathingSeconds ?? endTime - startTime) / 60.0;
    if (durationMin <= 0) return null;

    final ambientPressureBar = (avgDepth / 10.0) + 1.0;

    // Use volume-corrected SAC if tank size is known
    if (tankVolume != null && tankVolume > 0) {
      final result = _zCorrectedSacRate(
        tankVolume: tankVolume,
        startPressureBar: startPressure,
        endPressureBar: endPressure,
        o2Percent: gasMix.o2,
        hePercent: gasMix.he,
        durationMin: durationMin,
        ambientPressureBar: ambientPressureBar,
        model: gasModel,
      );
      if (result != null) return result;
    }

    // Fallback: simple pressure-based (no volume correction possible)
    return pressureUsed / durationMin / ambientPressureBar;
  }
}

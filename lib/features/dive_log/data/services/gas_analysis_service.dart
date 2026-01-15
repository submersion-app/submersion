import 'dart:math' as math;

import '../../../../core/constants/enums.dart';
import '../../domain/entities/cylinder_sac.dart';
import '../../domain/entities/dive.dart';
import '../../domain/entities/gas_switch.dart';
import 'profile_analysis_service.dart';

/// Service for calculating SAC (Surface Air Consumption) metrics
/// per segment and per cylinder.
///
/// This service provides multiple segmentation methods:
/// - **Time-based**: Fixed intervals (e.g., every 5 minutes)
/// - **Gas-switch**: Segments divided by tank changes
/// - **Depth-phase**: Segments based on dive phases (descent, bottom, ascent)
class GasAnalysisService {
  /// Standard surface pressure in bar
  static const double surfacePressureBar = 1.013;

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
        tankPressures: tankPressures?[tank.id],
        startTime: startTime,
        endTime: endTime,
      );

      if (sacRate == null) continue;

      // Calculate gas consumed
      final durationMin = (endTime - startTime) / 60.0;
      final ambientPressure = surfacePressureBar + (avgDepth / 10.0);
      final gasConsumed = sacRate * durationMin * ambientPressure;

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
      final tank = _getActiveTankAtTimestamp(tanks, gasSwitches, seg.start);
      if (tank == null) continue;

      // Calculate depth statistics
      final depths = segmentProfile.map((p) => p.depth).toList();
      final avgDepth = depths.reduce((a, b) => a + b) / depths.length;
      final minD = depths.reduce(math.min);
      final maxD = depths.reduce(math.max);

      // Calculate SAC
      final sacRate = _calculateSegmentSac(
        profile: segmentProfile,
        tank: tank,
        tankPressures: tankPressures?[tank.id],
        startTime: seg.start,
        endTime: seg.end,
      );

      if (sacRate == null) continue;

      final durationMin = (seg.end - seg.start) / 60.0;
      final ambientPressure = surfacePressureBar + (avgDepth / 10.0);
      final gasConsumed = sacRate * durationMin * ambientPressure;

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

    for (final tank in dive.tanks) {
      // Determine when this tank was in use
      final usageRange = _getTankUsageRange(
        tank: tank,
        gasSwitches: gasSwitches,
        diveStart: 0,
        diveEnd: dive.duration?.inSeconds ?? profile.lastOrNull?.timestamp ?? 0,
        tanks: dive.tanks,
      );

      if (usageRange == null) continue;

      // Get profile points during tank usage
      final usageProfile = profile
          .where(
            (p) =>
                p.timestamp >= usageRange.start &&
                p.timestamp <= usageRange.end,
          )
          .toList();

      // Calculate average depth during usage
      double? avgDepthDuringUse;
      if (usageProfile.isNotEmpty) {
        avgDepthDuringUse =
            usageProfile.map((p) => p.depth).reduce((a, b) => a + b) /
            usageProfile.length;
      }

      // Check if we have time-series pressure data for this tank
      final hasTsData = tankPressures?.containsKey(tank.id) ?? false;
      final tsPressures = tankPressures?[tank.id];

      // Calculate SAC rate
      double? sacRate;

      if (hasTsData && tsPressures != null && tsPressures.length >= 2) {
        // Enhanced calculation using time-series data
        sacRate = _calculateSacFromTimeSeries(
          pressurePoints: tsPressures,
          startTime: usageRange.start,
          endTime: usageRange.end,
          avgDepth: avgDepthDuringUse ?? dive.avgDepth ?? 10.0,
        );
      } else if (tank.startPressure != null &&
          tank.endPressure != null &&
          avgDepthDuringUse != null) {
        // Basic calculation from start/end pressures
        final pressureUsed = tank.startPressure! - tank.endPressure!;
        if (pressureUsed > 0) {
          final durationMin = (usageRange.end - usageRange.start) / 60.0;
          if (durationMin > 0) {
            final ambientPressure =
                surfacePressureBar + (avgDepthDuringUse / 10.0);
            sacRate = pressureUsed / durationMin / ambientPressure;
          }
        }
      }

      results.add(
        CylinderSac(
          tankId: tank.id,
          tankName: tank.name,
          gasMix: tank.gasMix,
          role: tank.role,
          tankVolume: tank.volume,
          sacRate: sacRate,
          startPressure: tank.startPressure,
          endPressure: tank.endPressure,
          usageDuration: Duration(seconds: usageRange.end - usageRange.start),
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

  /// Get the active tank at a given timestamp
  DiveTank? _getActiveTankAtTimestamp(
    List<DiveTank> tanks,
    List<GasSwitchWithTank>? gasSwitches,
    int timestamp,
  ) {
    if (tanks.isEmpty) return null;

    if (gasSwitches == null || gasSwitches.isEmpty) {
      // No gas switches - use first tank (or back gas)
      return tanks.firstWhere(
        (t) => t.role == TankRole.backGas,
        orElse: () => tanks.first,
      );
    }

    // Find the last switch before this timestamp
    final sortedSwitches = List<GasSwitchWithTank>.from(gasSwitches)
      ..sort((a, b) => a.gasSwitch.timestamp.compareTo(b.gasSwitch.timestamp));

    GasSwitchWithTank? activeSwitch;
    for (final sw in sortedSwitches) {
      if (sw.gasSwitch.timestamp <= timestamp) {
        activeSwitch = sw;
      } else {
        break;
      }
    }

    if (activeSwitch == null) {
      // Before first switch - use first tank
      return tanks.firstWhere(
        (t) => t.role == TankRole.backGas,
        orElse: () => tanks.first,
      );
    }

    return tanks.firstWhere(
      (t) => t.id == activeSwitch!.gasSwitch.tankId,
      orElse: () => tanks.first,
    );
  }

  /// Get the time range when a tank was in use
  ({int start, int end})? _getTankUsageRange({
    required DiveTank tank,
    required List<GasSwitchWithTank>? gasSwitches,
    required int diveStart,
    required int diveEnd,
    required List<DiveTank> tanks,
  }) {
    if (diveEnd <= diveStart) return null;

    if (gasSwitches == null || gasSwitches.isEmpty) {
      // No gas switches - assume single tank used entire dive
      // For multi-tank without switches, use the back gas
      if (tanks.length > 1 && tank.role != TankRole.backGas) {
        return null; // Can't determine usage without gas switches
      }
      return (start: diveStart, end: diveEnd);
    }

    final sortedSwitches = List<GasSwitchWithTank>.from(gasSwitches)
      ..sort((a, b) => a.gasSwitch.timestamp.compareTo(b.gasSwitch.timestamp));

    // Find all time ranges where this tank was active
    int? rangeStart;
    int totalEnd = diveEnd;

    // Check if this tank is the initial tank (before first switch)
    final firstSwitch = sortedSwitches.first;
    if (firstSwitch.gasSwitch.tankId == tank.id) {
      rangeStart = diveStart;
    }

    // Find switches to and from this tank
    for (int i = 0; i < sortedSwitches.length; i++) {
      final sw = sortedSwitches[i];
      if (sw.gasSwitch.tankId == tank.id) {
        // Switched TO this tank
        rangeStart ??= sw.gasSwitch.timestamp;
      } else if (rangeStart != null) {
        // Switched AWAY from this tank
        totalEnd = sw.gasSwitch.timestamp;
        break;
      }
    }

    // If we found a start but no end, tank was used until dive end
    if (rangeStart != null) {
      return (start: rangeStart, end: totalEnd);
    }

    return null;
  }

  /// Calculate SAC for a segment from profile data
  double? _calculateSegmentSac({
    required List<DiveProfilePoint> profile,
    required DiveTank tank,
    List<TankPressurePoint>? tankPressures,
    required int startTime,
    required int endTime,
  }) {
    if (profile.isEmpty) return null;

    final durationSec = endTime - startTime;
    if (durationSec < minSegmentDuration) return null;

    // Calculate average depth
    final depths = profile.map((p) => p.depth).toList();
    final avgDepth = depths.reduce((a, b) => a + b) / depths.length;
    if (avgDepth <= 0) return null;

    double? pressureUsed;

    // Try time-series pressure data first
    if (tankPressures != null && tankPressures.length >= 2) {
      final startPressure = _interpolatePressureAtTime(
        tankPressures,
        startTime,
      );
      final endPressure = _interpolatePressureAtTime(tankPressures, endTime);
      if (startPressure != null && endPressure != null) {
        pressureUsed = startPressure - endPressure;
      }
    }

    // Fallback to profile pressure data
    if (pressureUsed == null) {
      final pressurePoints = profile.where((p) => p.pressure != null).toList();
      if (pressurePoints.length >= 2) {
        final startPressure = pressurePoints.first.pressure!;
        final endPressure = pressurePoints.last.pressure!;
        pressureUsed = startPressure - endPressure;
      }
    }

    // Last fallback: estimate from tank start/end (less accurate for segments)
    if (pressureUsed == null || pressureUsed <= 0) {
      if (tank.startPressure != null && tank.endPressure != null) {
        // Estimate proportionally based on segment duration
        final totalDuration = profile.last.timestamp - profile.first.timestamp;
        if (totalDuration > 0) {
          final tankPressureUsed = tank.startPressure! - tank.endPressure!;
          final proportion = durationSec / totalDuration;
          pressureUsed = tankPressureUsed * proportion;
        }
      }
    }

    if (pressureUsed == null || pressureUsed <= 0) return null;

    // Calculate SAC
    final durationMin = durationSec / 60.0;
    final ambientPressure = surfacePressureBar + (avgDepth / 10.0);

    return pressureUsed / durationMin / ambientPressure;
  }

  /// Calculate SAC from time-series pressure data
  double? _calculateSacFromTimeSeries({
    required List<TankPressurePoint> pressurePoints,
    required int startTime,
    required int endTime,
    required double avgDepth,
  }) {
    if (pressurePoints.length < 2) return null;

    final startPressure = _interpolatePressureAtTime(pressurePoints, startTime);
    final endPressure = _interpolatePressureAtTime(pressurePoints, endTime);

    if (startPressure == null || endPressure == null) return null;

    final pressureUsed = startPressure - endPressure;
    if (pressureUsed <= 0) return null;

    final durationMin = (endTime - startTime) / 60.0;
    if (durationMin <= 0) return null;

    final ambientPressure = surfacePressureBar + (avgDepth / 10.0);

    return pressureUsed / durationMin / ambientPressure;
  }

  /// Interpolate pressure at a specific timestamp from time-series data
  double? _interpolatePressureAtTime(
    List<TankPressurePoint> pressurePoints,
    int timestamp,
  ) {
    if (pressurePoints.isEmpty) return null;

    // Sort by timestamp
    final sorted = List<TankPressurePoint>.from(pressurePoints)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Exact match
    final exact = sorted.where((p) => p.timestamp == timestamp).firstOrNull;
    if (exact != null) return exact.pressure;

    // Find surrounding points
    TankPressurePoint? before;
    TankPressurePoint? after;

    for (final point in sorted) {
      if (point.timestamp <= timestamp) {
        before = point;
      } else {
        after = point;
        break;
      }
    }

    // Edge cases
    if (before == null && after != null) return after.pressure;
    if (before != null && after == null) return before.pressure;
    if (before == null) return null;

    // Linear interpolation
    final timeDiff = after!.timestamp - before.timestamp;
    if (timeDiff == 0) return before.pressure;

    final ratio = (timestamp - before.timestamp) / timeDiff;
    return before.pressure + (after.pressure - before.pressure) * ratio;
  }
}

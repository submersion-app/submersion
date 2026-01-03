import 'package:flutter/material.dart';

import '../../domain/entities/dive.dart';

/// Types of markers that can be displayed on the dive profile
enum ProfileMarkerType {
  maxDepth,
  pressureTwoThirds,
  pressureHalf,
  pressureOneThird,
}

/// Represents a marker point on the dive profile chart
class ProfileMarker {
  final int timestamp; // seconds from dive start
  final double depth; // meters
  final ProfileMarkerType type;
  final String? tankId; // for pressure markers
  final String? tankName; // display name
  final int tankIndex; // for color coding (0-based)
  final double? value; // threshold value or depth value

  const ProfileMarker({
    required this.timestamp,
    required this.depth,
    required this.type,
    this.tankId,
    this.tankName,
    this.tankIndex = 0,
    this.value,
  });

  /// Get a display label for this marker
  String get label {
    switch (type) {
      case ProfileMarkerType.maxDepth:
        return 'Max';
      case ProfileMarkerType.pressureTwoThirds:
        return '⅔';
      case ProfileMarkerType.pressureHalf:
        return '½';
      case ProfileMarkerType.pressureOneThird:
        return '⅓';
    }
  }

  /// Get the color for this marker based on type and tank index
  Color getColor({List<Color>? tankColors}) {
    if (type == ProfileMarkerType.maxDepth) {
      return Colors.red;
    }

    // Default tank colors
    final colors = tankColors ??
        [
          Colors.orange,
          Colors.amber,
          Colors.green,
          Colors.cyan,
          Colors.purple,
          Colors.pink,
        ];

    return colors[tankIndex % colors.length];
  }

  /// Get the marker size based on threshold type
  double get markerSize {
    switch (type) {
      case ProfileMarkerType.maxDepth:
        return 7.0;
      case ProfileMarkerType.pressureTwoThirds:
        return 5.0;
      case ProfileMarkerType.pressureHalf:
        return 6.0;
      case ProfileMarkerType.pressureOneThird:
        return 7.0;
    }
  }
}

/// Service for calculating profile markers
class ProfileMarkersService {
  const ProfileMarkersService._();

  /// Calculate the max depth marker
  ///
  /// Returns a marker at the point of maximum depth, or null if the profile is empty.
  static ProfileMarker? getMaxDepthMarker({
    required List<DiveProfilePoint> profile,
    required int maxDepthTimestamp,
    required double maxDepth,
  }) {
    if (profile.isEmpty) return null;

    // Find the profile point at or nearest to the max depth timestamp
    DiveProfilePoint? maxPoint;
    for (final point in profile) {
      if (point.timestamp == maxDepthTimestamp) {
        maxPoint = point;
        break;
      }
    }

    // If exact match not found, find the deepest point
    maxPoint ??= profile.reduce(
      (a, b) => a.depth > b.depth ? a : b,
    );

    return ProfileMarker(
      timestamp: maxPoint.timestamp,
      depth: maxPoint.depth,
      type: ProfileMarkerType.maxDepth,
      value: maxPoint.depth,
    );
  }

  /// Calculate pressure threshold markers for all tanks
  ///
  /// Scans the profile pressure data to find when pressure crosses
  /// 2/3, 1/2, and 1/3 of the starting pressure for each tank.
  ///
  /// If [tankPressures] is provided, uses per-tank time-series data for
  /// accurate threshold detection. Otherwise falls back to legacy single
  /// pressure field or linear estimation.
  static List<ProfileMarker> getPressureThresholdMarkers({
    required List<DiveProfilePoint> profile,
    required List<DiveTank> tanks,
    Map<String, List<TankPressurePoint>>? tankPressures,
  }) {
    final markers = <ProfileMarker>[];

    // Filter to tanks that have start pressure
    final tanksWithPressure = tanks
        .where((t) => t.startPressure != null && t.startPressure! > 0)
        .toList();

    if (tanksWithPressure.isEmpty || profile.isEmpty) {
      return markers;
    }

    // Check if we have per-tank pressure data
    final hasMultiTankData = tankPressures != null && tankPressures.isNotEmpty;

    // Check if we have legacy pressure data in the profile
    final hasProfilePressure = profile.any((p) => p.pressure != null);

    if (!hasMultiTankData && !hasProfilePressure) {
      // No time-series pressure data - estimate based on linear consumption
      return _estimatePressureMarkersLinear(profile, tanksWithPressure);
    }

    for (var tankIndex = 0; tankIndex < tanksWithPressure.length; tankIndex++) {
      final tank = tanksWithPressure[tankIndex];
      final startPressure = tank.startPressure!.toDouble();

      // Calculate threshold values
      final thresholds = {
        ProfileMarkerType.pressureTwoThirds: startPressure * (2 / 3),
        ProfileMarkerType.pressureHalf: startPressure * 0.5,
        ProfileMarkerType.pressureOneThird: startPressure * (1 / 3),
      };

      // Try to use per-tank pressure data first
      if (hasMultiTankData && tankPressures.containsKey(tank.id)) {
        final tankPressurePoints = tankPressures[tank.id]!;
        markers.addAll(
          _findPressureCrossingsFromTankData(
            profile: profile,
            tankPressurePoints: tankPressurePoints,
            thresholds: thresholds,
            tank: tank,
            tankIndex: tankIndex,
          ),
        );
      } else if (tankIndex == 0 && hasProfilePressure) {
        // Fall back to legacy profile pressure for primary tank
        markers.addAll(
          _findPressureCrossingsFromProfile(
            profile: profile,
            thresholds: thresholds,
            tank: tank,
            tankIndex: tankIndex,
          ),
        );
      } else {
        // Estimate for other tanks (or if no profile data)
        markers.addAll(
          _estimatePressureCrossings(
            profile: profile,
            tank: tank,
            tankIndex: tankIndex,
            thresholds: thresholds,
          ),
        );
      }
    }

    return markers;
  }

  /// Find exact timestamps when pressure crosses thresholds using per-tank data
  static List<ProfileMarker> _findPressureCrossingsFromTankData({
    required List<DiveProfilePoint> profile,
    required List<TankPressurePoint> tankPressurePoints,
    required Map<ProfileMarkerType, double> thresholds,
    required DiveTank tank,
    required int tankIndex,
  }) {
    final markers = <ProfileMarker>[];
    final foundThresholds = <ProfileMarkerType>{};

    if (tankPressurePoints.isEmpty) return markers;

    // Sort by timestamp to ensure chronological order
    final sortedPoints = List<TankPressurePoint>.from(tankPressurePoints)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Scan chronologically to find first crossing of each threshold
    for (final point in sortedPoints) {
      for (final entry in thresholds.entries) {
        if (foundThresholds.contains(entry.key)) continue;

        // Check if pressure has dropped below threshold
        if (point.pressure <= entry.value) {
          // Find the corresponding depth from the dive profile
          final depth = _findDepthAtTimestamp(profile, point.timestamp);

          markers.add(
            ProfileMarker(
              timestamp: point.timestamp,
              depth: depth,
              type: entry.key,
              tankId: tank.id,
              tankName: tank.name ?? 'Tank ${tankIndex + 1}',
              tankIndex: tankIndex,
              value: entry.value,
            ),
          );
          foundThresholds.add(entry.key);
        }
      }

      // If all thresholds found, stop scanning
      if (foundThresholds.length == thresholds.length) break;
    }

    return markers;
  }

  /// Find depth at a given timestamp from the profile
  static double _findDepthAtTimestamp(
    List<DiveProfilePoint> profile,
    int timestamp,
  ) {
    // Find the closest profile point
    DiveProfilePoint? closest;
    int minDiff = 999999;

    for (final point in profile) {
      final diff = (point.timestamp - timestamp).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = point;
      }
      // Early exit if we've passed the target
      if (point.timestamp > timestamp && diff > minDiff) break;
    }

    return closest?.depth ?? 0.0;
  }

  /// Find exact timestamps when pressure crosses thresholds using profile data
  static List<ProfileMarker> _findPressureCrossingsFromProfile({
    required List<DiveProfilePoint> profile,
    required Map<ProfileMarkerType, double> thresholds,
    required DiveTank tank,
    required int tankIndex,
  }) {
    final markers = <ProfileMarker>[];
    final foundThresholds = <ProfileMarkerType>{};

    // Scan chronologically to find first crossing of each threshold
    for (final point in profile) {
      if (point.pressure == null) continue;

      for (final entry in thresholds.entries) {
        if (foundThresholds.contains(entry.key)) continue;

        // Check if pressure has dropped below threshold
        if (point.pressure! <= entry.value) {
          markers.add(
            ProfileMarker(
              timestamp: point.timestamp,
              depth: point.depth,
              type: entry.key,
              tankId: tank.id,
              tankName: tank.name ?? 'Tank ${tankIndex + 1}',
              tankIndex: tankIndex,
              value: entry.value,
            ),
          );
          foundThresholds.add(entry.key);
        }
      }

      // If all thresholds found, stop scanning
      if (foundThresholds.length == thresholds.length) break;
    }

    return markers;
  }

  /// Estimate pressure crossings based on linear consumption
  static List<ProfileMarker> _estimatePressureCrossings({
    required List<DiveProfilePoint> profile,
    required DiveTank tank,
    required int tankIndex,
    required Map<ProfileMarkerType, double> thresholds,
  }) {
    final markers = <ProfileMarker>[];

    final startPressure = tank.startPressure?.toDouble();
    final endPressure = tank.endPressure?.toDouble();

    if (startPressure == null || endPressure == null || profile.isEmpty) {
      return markers;
    }

    final totalDuration = profile.last.timestamp;
    if (totalDuration <= 0) return markers;

    final pressureUsed = startPressure - endPressure;
    if (pressureUsed <= 0) return markers;

    // Calculate consumption rate (bar per second)
    final consumptionRate = pressureUsed / totalDuration;

    for (final entry in thresholds.entries) {
      final thresholdPressure = entry.value;

      // Calculate when this threshold would be crossed
      final pressureToDrop = startPressure - thresholdPressure;
      if (pressureToDrop <= 0) continue; // Already below threshold at start

      final timeToThreshold = (pressureToDrop / consumptionRate).round();

      if (timeToThreshold > 0 && timeToThreshold < totalDuration) {
        // Find the profile point nearest to this timestamp
        final nearestPoint = _findNearestPoint(profile, timeToThreshold);

        markers.add(
          ProfileMarker(
            timestamp: nearestPoint.timestamp,
            depth: nearestPoint.depth,
            type: entry.key,
            tankId: tank.id,
            tankName: tank.name ?? 'Tank ${tankIndex + 1}',
            tankIndex: tankIndex,
            value: thresholdPressure,
          ),
        );
      }
    }

    return markers;
  }

  /// Estimate markers using linear consumption when no profile pressure data
  static List<ProfileMarker> _estimatePressureMarkersLinear(
    List<DiveProfilePoint> profile,
    List<DiveTank> tanks,
  ) {
    final markers = <ProfileMarker>[];

    for (var tankIndex = 0; tankIndex < tanks.length; tankIndex++) {
      final tank = tanks[tankIndex];
      final startPressure = tank.startPressure?.toDouble();

      if (startPressure == null) continue;

      final thresholds = {
        ProfileMarkerType.pressureTwoThirds: startPressure * (2 / 3),
        ProfileMarkerType.pressureHalf: startPressure * 0.5,
        ProfileMarkerType.pressureOneThird: startPressure * (1 / 3),
      };

      markers.addAll(
        _estimatePressureCrossings(
          profile: profile,
          tank: tank,
          tankIndex: tankIndex,
          thresholds: thresholds,
        ),
      );
    }

    return markers;
  }

  /// Find the profile point nearest to a given timestamp
  static DiveProfilePoint _findNearestPoint(
    List<DiveProfilePoint> profile,
    int targetTimestamp,
  ) {
    DiveProfilePoint? nearest;
    int minDiff = 999999;

    for (final point in profile) {
      final diff = (point.timestamp - targetTimestamp).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = point;
      }
      // Early exit if we've passed the target and diff is increasing
      if (point.timestamp > targetTimestamp && diff > minDiff) break;
    }

    return nearest ?? profile.first;
  }
}

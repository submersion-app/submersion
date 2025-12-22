import '../../../../features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import '../../domain/services/download_manager.dart';
export '../../../../features/dive_log/data/repositories/dive_computer_repository_impl.dart' show TankData;

/// Service for parsing downloaded dive data into app entities.
///
/// Converts the raw data from dive computers into the format used
/// by the app's database and UI.
class DiveParser {
  const DiveParser();

  /// Convert a downloaded dive's profile samples to ProfilePointData.
  ///
  /// This is the format used by the dive_computer_repository for import.
  /// Note: timestamps are stored as seconds from dive start, not absolute time.
  List<ProfilePointData> parseProfile(DownloadedDive dive) {
    final points = <ProfilePointData>[];

    for (final sample in dive.profile) {
      points.add(
        ProfilePointData(
          // Use relative time in seconds from dive start
          // (the chart and profile analysis expect this format)
          timestamp: sample.timeSeconds,
          depth: sample.depth,
          pressure: sample.pressure,
          temperature: sample.temperature,
          heartRate: sample.heartRate,
        ),
      );
    }

    return points;
  }

  /// Convert a downloaded dive's tank data to TankData.
  ///
  /// This extracts tank information including gas mix and pressures.
  List<TankData> parseTanks(DownloadedDive dive) {
    final tanks = <TankData>[];

    for (final tank in dive.tanks) {
      tanks.add(
        TankData(
          index: tank.index,
          o2Percent: tank.o2Percent,
          hePercent: tank.hePercent,
          startPressure: tank.startPressure,
          endPressure: tank.endPressure,
          volumeLiters: tank.volumeLiters,
        ),
      );
    }

    return tanks;
  }

  /// Extract the maximum depth from a dive's profile.
  double calculateMaxDepth(List<ProfileSample> profile) {
    if (profile.isEmpty) return 0.0;
    return profile.map((s) => s.depth).reduce((a, b) => a > b ? a : b);
  }

  /// Calculate the average depth from a dive's profile.
  double calculateAvgDepth(List<ProfileSample> profile) {
    if (profile.isEmpty) return 0.0;

    // Weight by time interval
    double totalDepthTime = 0.0;
    int totalTime = 0;

    for (int i = 0; i < profile.length; i++) {
      final current = profile[i];
      final next = i + 1 < profile.length ? profile[i + 1] : null;

      // Calculate time interval
      final interval = next != null
          ? next.timeSeconds - current.timeSeconds
          : 1; // Assume 1 second for last sample

      totalDepthTime += current.depth * interval;
      totalTime += interval;
    }

    return totalTime > 0 ? totalDepthTime / totalTime : 0.0;
  }

  /// Extract temperature range from a dive's profile.
  ({double? min, double? max}) extractTemperatureRange(
    List<ProfileSample> profile,
  ) {
    final temps =
        profile.map((s) => s.temperature).whereType<double>().toList();

    if (temps.isEmpty) {
      return (min: null, max: null);
    }

    return (
      min: temps.reduce((a, b) => a < b ? a : b),
      max: temps.reduce((a, b) => a > b ? a : b),
    );
  }

  /// Detect safety stop from profile data.
  ///
  /// A safety stop is typically 3-5 minutes at 5m depth.
  SafetyStopInfo? detectSafetyStop(List<ProfileSample> profile) {
    const minDepth = 4.0; // meters
    const maxDepth = 6.0; // meters
    const minDuration = 120; // 2 minutes minimum

    int? startIndex;

    for (int i = 0; i < profile.length; i++) {
      final sample = profile[i];

      if (sample.depth >= minDepth && sample.depth <= maxDepth) {
        startIndex ??= i;

        // Calculate duration
        final startTime = profile[startIndex].timeSeconds;
        final duration = sample.timeSeconds - startTime;

        if (duration >= minDuration && i > 0) {
          // Check if this is near the end (ascending after this)
          final remainingSamples = profile.skip(i + 1);
          final ascending = remainingSamples.every((s) => s.depth < minDepth);

          if (ascending) {
            return SafetyStopInfo(
              startTime: startTime,
              duration: duration,
              depth: (minDepth + maxDepth) / 2,
            );
          }
        }
      } else {
        startIndex = null;
      }
    }

    return null;
  }

  /// Calculate ascent rates between profile samples.
  List<AscentRateInfo> calculateAscentRates(List<ProfileSample> profile) {
    final rates = <AscentRateInfo>[];

    for (int i = 1; i < profile.length; i++) {
      final prev = profile[i - 1];
      final curr = profile[i];

      final depthChange = prev.depth - curr.depth; // Positive = ascending
      final timeChange = curr.timeSeconds - prev.timeSeconds;

      if (timeChange > 0 && depthChange > 0) {
        // Only for ascending
        final ratePerMin = (depthChange / timeChange) * 60; // m/min

        rates.add(
          AscentRateInfo(
            timeSeconds: curr.timeSeconds,
            depth: curr.depth,
            rateMetersPerMin: ratePerMin,
            severity: _getAscentRateSeverity(ratePerMin),
          ),
        );
      }
    }

    return rates;
  }

  AscentRateSeverity _getAscentRateSeverity(double ratePerMin) {
    if (ratePerMin <= 9.0) return AscentRateSeverity.safe;
    if (ratePerMin <= 12.0) return AscentRateSeverity.warning;
    return AscentRateSeverity.critical;
  }

  /// Extract dive phases (descent, bottom, ascent).
  DivePhases analyzeDivePhases(List<ProfileSample> profile) {
    if (profile.isEmpty) {
      return const DivePhases(
        descentEnd: 0,
        ascentStart: 0,
        bottomTime: 0,
      );
    }

    // Find max depth point
    int maxDepthIndex = 0;
    double maxDepth = 0.0;
    for (int i = 0; i < profile.length; i++) {
      if (profile[i].depth > maxDepth) {
        maxDepth = profile[i].depth;
        maxDepthIndex = i;
      }
    }

    // Find descent end (first point within 10% of max depth)
    int descentEnd = 0;
    final threshold = maxDepth * 0.9;
    for (int i = 0; i < maxDepthIndex; i++) {
      if (profile[i].depth >= threshold) {
        descentEnd = profile[i].timeSeconds;
        break;
      }
    }

    // Find ascent start (last point within 10% of max depth)
    int ascentStart = profile[maxDepthIndex].timeSeconds;
    for (int i = profile.length - 1; i > maxDepthIndex; i--) {
      if (profile[i].depth >= threshold) {
        ascentStart = profile[i].timeSeconds;
        break;
      }
    }

    return DivePhases(
      descentEnd: descentEnd,
      ascentStart: ascentStart,
      bottomTime: ascentStart - descentEnd,
    );
  }
}

/// Information about a detected safety stop.
class SafetyStopInfo {
  final int startTime; // seconds from dive start
  final int duration; // seconds
  final double depth; // meters

  const SafetyStopInfo({
    required this.startTime,
    required this.duration,
    required this.depth,
  });
}

/// Information about ascent rate at a point.
class AscentRateInfo {
  final int timeSeconds;
  final double depth;
  final double rateMetersPerMin;
  final AscentRateSeverity severity;

  const AscentRateInfo({
    required this.timeSeconds,
    required this.depth,
    required this.rateMetersPerMin,
    required this.severity,
  });
}

/// Severity levels for ascent rate.
enum AscentRateSeverity {
  safe, // < 9 m/min
  warning, // 9-12 m/min
  critical, // > 12 m/min
}

/// Information about dive phases.
class DivePhases {
  final int descentEnd; // seconds
  final int ascentStart; // seconds
  final int bottomTime; // seconds

  const DivePhases({
    required this.descentEnd,
    required this.ascentStart,
    required this.bottomTime,
  });
}

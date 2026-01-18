import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute;

import 'package:submersion/core/tide/astronomical_arguments.dart';
import 'package:submersion/core/tide/constants/harmonic_constituents.dart';
import 'package:submersion/core/tide/entities/tide_constituent.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/tide/entities/tide_prediction.dart';

/// Pure Dart implementation of harmonic tidal prediction.
///
/// Uses the standard harmonic prediction formula adopted by NOAA and IHO:
///
/// ```
/// h(t) = Z₀ + Σ fₙ × Hₙ × cos(ωₙ×t + V₀ₙ + uₙ - gₙ)
/// ```
///
/// Where:
/// - `Z₀` = mean sea level datum offset
/// - `fₙ` = nodal factor (amplitude modulation from 18.6-year lunar cycle)
/// - `Hₙ` = constituent amplitude (from FES/local data)
/// - `ωₙ` = constituent angular speed (degrees/hour)
/// - `t` = time from reference epoch (hours)
/// - `V₀ₙ` = equilibrium argument (astronomical phase)
/// - `uₙ` = nodal angle (phase modulation)
/// - `gₙ` = Greenwich phase lag (from FES/local data)
///
/// This class follows the same pure Dart pattern as [BuhlmannAlgorithm],
/// enabling fully offline tide calculations once constituent data is loaded.
class TideCalculator {
  /// Location-specific harmonic constituents (amplitude and phase).
  ///
  /// Keys are constituent names (e.g., 'M2', 'S2', 'K1').
  /// Values contain the amplitude (meters) and phase (degrees) for this location.
  final Map<String, TideConstituent> constituents;

  /// Mean sea level offset in meters.
  ///
  /// This is added to the harmonic sum to give absolute height.
  /// Typically 0.0 when using MSL as datum, or a local offset for chart datum.
  final double z0;

  /// Create a tide calculator with the given constituents.
  ///
  /// [constituents] - Map of constituent name to amplitude/phase data.
  ///   Should be extracted from FES model or NOAA harmonic constants.
  /// [z0] - Mean sea level offset (default 0.0)
  TideCalculator({required this.constituents, this.z0 = 0.0});

  /// Calculate tide height at a specific time.
  ///
  /// Returns height in meters relative to datum (MSL by default).
  /// Positive values are above datum, negative below.
  ///
  /// ```dart
  /// final calculator = TideCalculator(constituents: siteConstituents);
  /// final height = calculator.calculateHeight(DateTime.now());
  /// print('Current tide: ${height.toStringAsFixed(2)}m');
  /// ```
  double calculateHeight(DateTime time) {
    final astro = AstronomicalArguments.forDateTime(time);
    final hoursFromEpoch = AstronomicalArguments.hoursFromReferenceEpoch(time);

    double height = z0;

    for (final entry in constituents.entries) {
      final name = entry.key;
      final constituent = entry.value;

      // Get angular speed for this constituent
      final speed = constituentSpeeds[name];
      if (speed == null) continue;

      // Nodal modulation (amplitude and phase corrections)
      final f = astro.nodalFactor(name);
      final equilibriumPhase = astro.equilibriumPhase(name);

      // Total phase angle in degrees:
      // ω×t + V₀ + u - g
      // where V₀ + u is the equilibrium phase, and g is the local phase lag
      final phase =
          speed * hoursFromEpoch + equilibriumPhase - constituent.phase;

      // Convert to radians and compute contribution
      final phaseRad = degreesToRadians(phase);
      height += f * constituent.amplitude * math.cos(phaseRad);
    }

    return height;
  }

  /// Generate tide predictions over a time range.
  ///
  /// Returns a list of [TidePrediction] objects at regular intervals.
  ///
  /// [start] - Start time of prediction range
  /// [end] - End time of prediction range
  /// [interval] - Time between predictions (default 10 minutes)
  ///
  /// ```dart
  /// final predictions = calculator.predict(
  ///   start: DateTime.now(),
  ///   end: DateTime.now().add(Duration(hours: 24)),
  ///   interval: Duration(minutes: 15),
  /// );
  /// ```
  List<TidePrediction> predict({
    required DateTime start,
    required DateTime end,
    Duration interval = const Duration(minutes: 10),
  }) {
    final predictions = <TidePrediction>[];
    var current = start;

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      final height = calculateHeight(current);
      predictions.add(TidePrediction(time: current, heightMeters: height));
      current = current.add(interval);
    }

    return predictions;
  }

  /// Find high and low tides within a time range.
  ///
  /// Uses derivative analysis to locate extremes, then refines
  /// with parabolic interpolation for sub-minute accuracy.
  ///
  /// Returns a list of [TideExtreme] sorted by time.
  ///
  /// ```dart
  /// final extremes = calculator.findExtremes(
  ///   start: DateTime.now(),
  ///   end: DateTime.now().add(Duration(hours: 24)),
  /// );
  /// for (final extreme in extremes) {
  ///   print('${extreme.type.displayName} at ${extreme.time}: '
  ///       '${extreme.heightMeters.toStringAsFixed(2)}m');
  /// }
  /// ```
  List<TideExtreme> findExtremes({
    required DateTime start,
    required DateTime end,
  }) {
    final extremes = <TideExtreme>[];

    // Generate predictions for analysis (5-minute resolution for performance)
    // Tidal extremes change slowly enough that 5-minute resolution is sufficient
    // and provides parabolic interpolation refinement for sub-minute accuracy
    final predictions = predict(
      start: start,
      end: end,
      interval: const Duration(minutes: 5),
    );

    if (predictions.length < 3) return extremes;

    for (int i = 1; i < predictions.length - 1; i++) {
      final prev = predictions[i - 1];
      final curr = predictions[i];
      final next = predictions[i + 1];

      // Local maximum (high tide)
      if (curr.heightMeters > prev.heightMeters &&
          curr.heightMeters > next.heightMeters) {
        final refined = _refineExtreme(prev, curr, next);
        extremes.add(
          TideExtreme(
            type: TideExtremeType.high,
            time: refined.time,
            heightMeters: refined.height,
          ),
        );
      }

      // Local minimum (low tide)
      if (curr.heightMeters < prev.heightMeters &&
          curr.heightMeters < next.heightMeters) {
        final refined = _refineExtreme(prev, curr, next);
        extremes.add(
          TideExtreme(
            type: TideExtremeType.low,
            time: refined.time,
            heightMeters: refined.height,
          ),
        );
      }
    }

    return extremes;
  }

  /// Get the current tide state (rising, falling, or slack).
  ///
  /// Determines direction by comparing heights at nearby times.
  /// Slack is detected when the rate of change is very small.
  ///
  /// ```dart
  /// final state = calculator.getCurrentState(DateTime.now());
  /// print('Tide is ${state.displayName}');
  /// ```
  TideState getCurrentState(DateTime time) {
    final current = calculateHeight(time);
    final before = calculateHeight(time.subtract(const Duration(minutes: 15)));
    final after = calculateHeight(time.add(const Duration(minutes: 15)));

    // Rate of change in meters per hour
    final derivative = (after - before) / 0.5;

    // Check if near slack (less than 5cm/hour change)
    if (derivative.abs() < 0.05) {
      // Determine if high or low slack by checking trend over longer period
      final hourBefore = calculateHeight(
        time.subtract(const Duration(hours: 1)),
      );
      if (current > hourBefore) {
        return TideState.slackHigh;
      } else {
        return TideState.slackLow;
      }
    }

    return derivative > 0 ? TideState.rising : TideState.falling;
  }

  /// Get comprehensive tide status including current state and nearby extremes.
  ///
  /// Returns a [TideStatus] with current height, state, and surrounding
  /// high/low tide information useful for dive planning.
  TideStatus getStatus(DateTime time) {
    final currentHeight = calculateHeight(time);
    final state = getCurrentState(time);

    // Find extremes in a 12-hour window around current time
    final extremes = findExtremes(
      start: time.subtract(const Duration(hours: 6)),
      end: time.add(const Duration(hours: 6)),
    );

    // Find previous and next extremes relative to current time
    TideExtreme? previousExtreme;
    TideExtreme? nextExtreme;

    for (final extreme in extremes) {
      if (extreme.time.isBefore(time)) {
        previousExtreme = extreme;
      } else if (nextExtreme == null && extreme.time.isAfter(time)) {
        nextExtreme = extreme;
      }
    }

    // Calculate rate of change
    final before = calculateHeight(time.subtract(const Duration(minutes: 30)));
    final after = calculateHeight(time.add(const Duration(minutes: 30)));
    final rateOfChange = (after - before); // meters per hour

    return TideStatus(
      state: state,
      currentHeight: currentHeight,
      previousExtreme: previousExtreme,
      nextExtreme: nextExtreme,
      rateOfChange: rateOfChange,
    );
  }

  /// Calculate tide height at a specific time for a dive.
  ///
  /// Convenience method that returns both the height and state
  /// for recording with a dive log entry.
  ({double height, TideState state}) getTideAtTime(DateTime time) {
    return (height: calculateHeight(time), state: getCurrentState(time));
  }

  /// Refine extreme point using parabolic interpolation.
  ///
  /// Given three consecutive predictions where the middle is an extreme,
  /// this fits a parabola and finds its vertex for more accurate
  /// extreme time and height.
  ({DateTime time, double height}) _refineExtreme(
    TidePrediction p1,
    TidePrediction p2,
    TidePrediction p3,
  ) {
    final y1 = p1.heightMeters;
    final y2 = p2.heightMeters;
    final y3 = p3.heightMeters;

    // Parabolic interpolation: find vertex offset from center point
    // Using the formula for a parabola through 3 equally-spaced points
    final denominator = y1 - 2 * y2 + y3;

    // Avoid division by zero (flat region)
    if (denominator.abs() < 1e-10) {
      return (time: p2.time, height: y2);
    }

    // Offset from center point (-1 to 1 in interval units)
    final offset = (y1 - y3) / (2 * denominator);

    // Interpolated time
    final dt = p2.time.difference(p1.time);
    final refinedTime = p2.time.add(
      Duration(milliseconds: (offset * dt.inMilliseconds).round()),
    );

    // Interpolated height at vertex
    final refinedHeight = y2 - (y1 - y3) * offset / 4;

    return (time: refinedTime, height: refinedHeight);
  }

  /// Create a calculator with only the major 8 constituents.
  ///
  /// Useful for quick approximations or when only major constituents
  /// are available. Provides ~90% accuracy for most locations.
  factory TideCalculator.majorConstituentsOnly({
    required Map<String, TideConstituent> allConstituents,
    double z0 = 0.0,
  }) {
    final major = <String, TideConstituent>{};
    for (final name in majorConstituents) {
      if (allConstituents.containsKey(name)) {
        major[name] = allConstituents[name]!;
      }
    }
    return TideCalculator(constituents: major, z0: z0);
  }

  /// Check if the calculator has enough constituents for reliable predictions.
  ///
  /// Returns true if at least the 4 major constituents (M2, S2, K1, O1) are present.
  bool get hasMinimumConstituents {
    const required = ['M2', 'S2', 'K1', 'O1'];
    return required.every((name) => constituents.containsKey(name));
  }

  /// Get the dominant constituent (typically M2 for most locations).
  TideConstituent? get dominantConstituent {
    if (constituents.isEmpty) return null;

    TideConstituent? dominant;
    for (final constituent in constituents.values) {
      if (dominant == null || constituent.amplitude > dominant.amplitude) {
        dominant = constituent;
      }
    }
    return dominant;
  }

  /// Estimate tidal range based on constituent amplitudes.
  ///
  /// Returns approximate spring tide range (when all constituents align).
  double get estimatedTidalRange {
    double sum = 0.0;
    for (final constituent in constituents.values) {
      sum += constituent.amplitude;
    }
    // Double for full range (low to high)
    return sum * 2;
  }

  @override
  String toString() {
    return 'TideCalculator(${constituents.length} constituents, '
        'z0=${z0.toStringAsFixed(2)}m, '
        'range≈${estimatedTidalRange.toStringAsFixed(1)}m)';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Async methods for background isolate computation
  // ─────────────────────────────────────────────────────────────────────────

  /// Async version of [findExtremes] that runs on a background isolate.
  ///
  /// Use this for UI-facing code to avoid blocking the main thread.
  Future<List<TideExtreme>> findExtremesAsync({
    required DateTime start,
    required DateTime end,
  }) {
    return compute(
      _findExtremesIsolate,
      _TideComputeParams(
        constituents: constituents,
        z0: z0,
        start: start,
        end: end,
      ),
    );
  }

  /// Async version of [getStatus] that runs on a background isolate.
  ///
  /// Use this for UI-facing code to avoid blocking the main thread.
  Future<TideStatus> getStatusAsync(DateTime time) {
    return compute(
      _getStatusIsolate,
      _TideComputeParams(constituents: constituents, z0: z0, time: time),
    );
  }

  /// Async version of [predict] that runs on a background isolate.
  ///
  /// Use this for large prediction ranges to avoid blocking the main thread.
  Future<List<TidePrediction>> predictAsync({
    required DateTime start,
    required DateTime end,
    Duration interval = const Duration(minutes: 10),
  }) {
    return compute(
      _predictIsolate,
      _TideComputeParams(
        constituents: constituents,
        z0: z0,
        start: start,
        end: end,
        interval: interval,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Isolate helper classes and functions
// ─────────────────────────────────────────────────────────────────────────────

/// Parameters for tide computation on a background isolate.
///
/// All fields must be serializable for isolate message passing.
class _TideComputeParams {
  final Map<String, TideConstituent> constituents;
  final double z0;
  final DateTime? start;
  final DateTime? end;
  final DateTime? time;
  final Duration? interval;

  _TideComputeParams({
    required this.constituents,
    required this.z0,
    this.start,
    this.end,
    this.time,
    this.interval,
  });
}

/// Top-level function for findExtremes computation on isolate.
List<TideExtreme> _findExtremesIsolate(_TideComputeParams params) {
  final calculator = TideCalculator(
    constituents: params.constituents,
    z0: params.z0,
  );
  return calculator.findExtremes(start: params.start!, end: params.end!);
}

/// Top-level function for getStatus computation on isolate.
TideStatus _getStatusIsolate(_TideComputeParams params) {
  final calculator = TideCalculator(
    constituents: params.constituents,
    z0: params.z0,
  );
  return calculator.getStatus(params.time!);
}

/// Top-level function for predict computation on isolate.
List<TidePrediction> _predictIsolate(_TideComputeParams params) {
  final calculator = TideCalculator(
    constituents: params.constituents,
    z0: params.z0,
  );
  return calculator.predict(
    start: params.start!,
    end: params.end!,
    interval: params.interval ?? const Duration(minutes: 10),
  );
}

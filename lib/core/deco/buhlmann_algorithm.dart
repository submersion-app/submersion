import 'dart:math' as math;

import 'constants/buhlmann_coefficients.dart';
import 'entities/deco_status.dart';
import 'entities/tissue_compartment.dart';

/// Bühlmann ZH-L16C decompression algorithm implementation.
///
/// This class implements the Bühlmann ZH-L16C decompression model with
/// gradient factors for added conservatism. It calculates:
/// - Tissue loading for all 16 compartments
/// - No-Decompression Limit (NDL)
/// - Decompression ceiling
/// - Time To Surface (TTS)
/// - Decompression stop schedule
class BuhlmannAlgorithm {
  /// Gradient Factor Low (0.0-1.0)
  final double gfLow;

  /// Gradient Factor High (0.0-1.0)
  final double gfHigh;

  /// Last stop depth in meters (typically 3 or 6)
  final double lastStopDepth;

  /// Deco stop depth increment in meters (typically 3)
  final double stopIncrement;

  /// Ascent rate in meters per minute
  final double ascentRate;

  /// Current tissue compartments state
  List<TissueCompartment> _compartments;

  BuhlmannAlgorithm({
    this.gfLow = 0.30,
    this.gfHigh = 0.70,
    this.lastStopDepth = 3.0,
    this.stopIncrement = 3.0,
    this.ascentRate = 9.0,
  }) : _compartments = _createSurfaceSaturatedCompartments();

  /// Get current compartments state (read-only copy).
  List<TissueCompartment> get compartments => List.unmodifiable(_compartments);

  /// Create compartments saturated at surface.
  static List<TissueCompartment> _createSurfaceSaturatedCompartments() {
    final compartments = <TissueCompartment>[];

    // Surface N2 tension = inspired N2 at surface
    final surfaceN2 = calculateInspiredN2(surfacePressureBar, airN2Fraction);

    for (int i = 0; i < zhl16CompartmentCount; i++) {
      compartments.add(
        TissueCompartment(
          compartmentNumber: i + 1,
          halfTimeN2: zhl16cN2HalfTimes[i],
          halfTimeHe: zhl16cHeHalfTimes[i],
          mValueAN2: zhl16cN2A[i],
          mValueBN2: zhl16cN2B[i],
          mValueAHe: zhl16cHeA[i],
          mValueBHe: zhl16cHeB[i],
          currentPN2: surfaceN2,
          currentPHe: 0.0,
        ),
      );
    }

    return compartments;
  }

  /// Reset compartments to surface-saturated state.
  void reset() {
    _compartments = _createSurfaceSaturatedCompartments();
  }

  /// Set compartments to a specific state (for loading from saved data).
  void setCompartments(List<TissueCompartment> compartments) {
    if (compartments.length == zhl16CompartmentCount) {
      _compartments = List.from(compartments);
    }
  }

  /// Calculate tissue loading for a time segment at constant depth.
  ///
  /// Uses the Schreiner equation for exponential gas loading/unloading.
  /// [depthMeters] is the depth in meters.
  /// [durationSeconds] is time at depth in seconds.
  /// [fN2] is nitrogen fraction (0.0-1.0).
  /// [fHe] is helium fraction (0.0-1.0).
  void calculateSegment({
    required double depthMeters,
    required int durationSeconds,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
  }) {
    final ambientPressure = calculateAmbientPressure(depthMeters);
    final inspiredN2 = calculateInspiredN2(ambientPressure, fN2);
    final inspiredHe = calculateInspiredHe(ambientPressure, fHe);
    final durationMinutes = durationSeconds / 60.0;

    final newCompartments = <TissueCompartment>[];

    for (final comp in _compartments) {
      // Calculate new N2 tension using Schreiner equation
      final newN2 = _schreinerEquation(
        comp.currentPN2,
        inspiredN2,
        durationMinutes,
        comp.halfTimeN2,
      );

      // Calculate new He tension
      final newHe = _schreinerEquation(
        comp.currentPHe,
        inspiredHe,
        durationMinutes,
        comp.halfTimeHe,
      );

      newCompartments.add(comp.copyWith(currentPN2: newN2, currentPHe: newHe));
    }

    _compartments = newCompartments;
  }

  /// Schreiner equation for gas loading/unloading.
  ///
  /// P(t) = P_inspired + (P_initial - P_inspired) * e^(-k*t)
  /// where k = ln(2) / half_time
  double _schreinerEquation(
    double initialPressure,
    double inspiredPressure,
    double timeMinutes,
    double halfTimeMinutes,
  ) {
    final k = math.log(2) / halfTimeMinutes;
    return inspiredPressure +
        (initialPressure - inspiredPressure) * math.exp(-k * timeMinutes);
  }

  /// Calculate the current decompression ceiling (minimum safe depth).
  ///
  /// Uses gradient factors to add conservatism.
  /// [currentDepth] is used to interpolate the gradient factor.
  /// Returns ceiling depth in meters.
  double calculateCeiling({double currentDepth = 0}) {
    double maxCeiling = 0;

    // Calculate GF at current depth (linear interpolation between GF Low and GF High)
    final gf = _interpolateGf(currentDepth);

    for (final comp in _compartments) {
      final ceiling = comp.ceiling(gf: gf);
      if (ceiling > maxCeiling) {
        maxCeiling = ceiling;
      }
    }

    return maxCeiling;
  }

  /// Interpolate gradient factor based on depth.
  ///
  /// GF starts at gfLow at the first stop depth and increases
  /// linearly to gfHigh at the surface.
  double _interpolateGf(double currentDepth) {
    if (currentDepth <= 0) return gfHigh;

    final firstStopDepth = _findFirstStopDepth();
    if (firstStopDepth <= 0) return gfHigh;

    if (currentDepth >= firstStopDepth) return gfLow;

    // Linear interpolation
    final ratio = currentDepth / firstStopDepth;
    return gfHigh - (gfHigh - gfLow) * ratio;
  }

  /// Find the depth of the first required stop.
  double _findFirstStopDepth() {
    double maxCeiling = 0;

    for (final comp in _compartments) {
      final ceiling = comp.ceiling(gf: gfLow);
      if (ceiling > maxCeiling) {
        maxCeiling = ceiling;
      }
    }

    // Round up to next stop depth
    if (maxCeiling <= 0) return 0;
    return (maxCeiling / stopIncrement).ceil() * stopIncrement;
  }

  /// Calculate No-Decompression Limit (NDL) at current depth.
  ///
  /// [depthMeters] is the depth to calculate NDL for.
  /// [fN2] is nitrogen fraction (default air).
  /// [fHe] is helium fraction (default 0).
  /// [maxNdl] is maximum NDL to return in seconds (default 999 minutes).
  /// Returns NDL in seconds, or -1 if already in deco obligation.
  int calculateNdl({
    required double depthMeters,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
    int maxNdl = 999 * 60,
  }) {
    // Check if already in deco
    if (calculateCeiling(currentDepth: depthMeters) > 0) {
      return -1;
    }

    // Binary search for NDL
    int low = 0;
    int high = maxNdl;

    // Create a copy of current compartments for simulation
    final savedCompartments = List<TissueCompartment>.from(_compartments);

    while (high - low > 1) {
      final mid = (low + high) ~/ 2;

      // Reset to saved state
      _compartments = List<TissueCompartment>.from(savedCompartments);

      // Simulate staying at depth for 'mid' seconds
      calculateSegment(
        depthMeters: depthMeters,
        durationSeconds: mid,
        fN2: fN2,
        fHe: fHe,
      );

      // Check if this creates a deco obligation
      if (calculateCeiling(currentDepth: depthMeters) > 0) {
        high = mid;
      } else {
        low = mid;
      }
    }

    // Restore original compartments
    _compartments = savedCompartments;

    return low;
  }

  /// Calculate complete decompression schedule.
  ///
  /// [currentDepth] is starting depth in meters.
  /// [fN2] is nitrogen fraction for ascent gas.
  /// [fHe] is helium fraction for ascent gas.
  /// Returns list of [DecoStop] required.
  List<DecoStop> calculateDecoSchedule({
    required double currentDepth,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
  }) {
    final stops = <DecoStop>[];

    // Create working copy of compartments
    final savedCompartments = List<TissueCompartment>.from(_compartments);

    // Find first stop depth
    final double ceiling = calculateCeiling(currentDepth: currentDepth);
    if (ceiling <= 0) {
      _compartments = savedCompartments;
      return stops; // No deco required
    }

    double currentStopDepth = (ceiling / stopIncrement).ceil() * stopIncrement;

    // Simulate ascent to first stop
    _simulateAscent(currentDepth, currentStopDepth, fN2, fHe);

    // Calculate stops
    while (currentStopDepth >= lastStopDepth) {
      final int stopTime = _calculateStopTime(currentStopDepth, fN2, fHe);

      if (stopTime > 0) {
        stops.add(
          DecoStop(
            depthMeters: currentStopDepth,
            durationSeconds: stopTime,
            isDeepStop: currentStopDepth > 9,
          ),
        );

        // Apply stop time
        calculateSegment(
          depthMeters: currentStopDepth,
          durationSeconds: stopTime,
          fN2: fN2,
          fHe: fHe,
        );
      }

      // Move to next shallower stop
      final nextStop = currentStopDepth - stopIncrement;
      if (nextStop >= lastStopDepth) {
        _simulateAscent(currentStopDepth, nextStop, fN2, fHe);
      }
      currentStopDepth = nextStop;
    }

    // Restore original compartments
    _compartments = savedCompartments;

    return stops;
  }

  /// Calculate time required at a stop depth.
  int _calculateStopTime(double stopDepth, double fN2, double fHe) {
    final nextStopDepth = stopDepth <= lastStopDepth
        ? 0.0
        : stopDepth - stopIncrement;
    int stopTime = 0;
    const maxStopTime = 120 * 60; // 2 hours max per stop

    // Find minimum time to clear to next stop
    while (stopTime < maxStopTime) {
      // Calculate ceiling after 1 minute at stop
      final testCompartments = List<TissueCompartment>.from(_compartments);

      calculateSegment(
        depthMeters: stopDepth,
        durationSeconds: 60,
        fN2: fN2,
        fHe: fHe,
      );

      final ceiling = calculateCeiling(currentDepth: stopDepth);

      // Restore for next iteration
      _compartments = testCompartments;

      if (ceiling <= nextStopDepth) {
        break;
      }

      // Add one minute to stop
      calculateSegment(
        depthMeters: stopDepth,
        durationSeconds: 60,
        fN2: fN2,
        fHe: fHe,
      );
      stopTime += 60;
    }

    // Round up to whole minutes
    return ((stopTime + 59) ~/ 60) * 60;
  }

  /// Simulate ascent between depths.
  void _simulateAscent(
    double fromDepth,
    double toDepth,
    double fN2,
    double fHe,
  ) {
    if (fromDepth <= toDepth) return;

    final depthChange = fromDepth - toDepth;
    final ascentTimeMinutes = depthChange / ascentRate;
    final ascentTimeSeconds = (ascentTimeMinutes * 60).round();

    // Use average depth for ascent segment
    final avgDepth = (fromDepth + toDepth) / 2.0;

    calculateSegment(
      depthMeters: avgDepth,
      durationSeconds: ascentTimeSeconds,
      fN2: fN2,
      fHe: fHe,
    );
  }

  /// Calculate Time To Surface (TTS) including all deco stops.
  ///
  /// [currentDepth] is starting depth in meters.
  /// Returns TTS in seconds.
  int calculateTts({required double currentDepth}) {
    final stops = calculateDecoSchedule(currentDepth: currentDepth);

    int tts = 0;

    // Add deco stop times
    for (final stop in stops) {
      tts += stop.durationSeconds;
    }

    // Add ascent times between stops
    double depth = currentDepth;
    for (final stop in stops) {
      final ascentTime = ((depth - stop.depthMeters) / ascentRate * 60).round();
      tts += ascentTime;
      depth = stop.depthMeters;
    }

    // Add final ascent to surface
    if (depth > 0) {
      tts += (depth / ascentRate * 60).round();
    }

    return tts;
  }

  /// Get current decompression status.
  ///
  /// [currentDepth] is current depth in meters.
  /// [fN2] is nitrogen fraction of current gas.
  /// [fHe] is helium fraction of current gas.
  DecoStatus getDecoStatus({
    required double currentDepth,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
  }) {
    final ceiling = calculateCeiling(currentDepth: currentDepth);
    final ndl = calculateNdl(depthMeters: currentDepth, fN2: fN2, fHe: fHe);
    final stops = ndl < 0
        ? calculateDecoSchedule(currentDepth: currentDepth, fN2: fN2, fHe: fHe)
        : <DecoStop>[];
    final tts = ndl < 0 ? calculateTts(currentDepth: currentDepth) : 0;

    return DecoStatus(
      compartments: List.unmodifiable(_compartments),
      ndlSeconds: ndl,
      ceilingMeters: ceiling,
      ttsSeconds: tts,
      gfLow: gfLow,
      gfHigh: gfHigh,
      decoStops: stops,
      currentDepthMeters: currentDepth,
      ambientPressureBar: calculateAmbientPressure(currentDepth),
    );
  }

  /// Process a dive profile and return deco status at each point.
  ///
  /// [depths] list of depths in meters.
  /// [timestamps] list of timestamps in seconds.
  /// [fN2] nitrogen fraction of gas.
  /// [fHe] helium fraction of gas.
  /// Returns list of [DecoStatus] for each point.
  List<DecoStatus> processProfile({
    required List<double> depths,
    required List<int> timestamps,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
  }) {
    if (depths.length != timestamps.length || depths.isEmpty) {
      return [];
    }

    reset();
    final results = <DecoStatus>[];

    for (int i = 0; i < depths.length; i++) {
      if (i > 0) {
        final duration = timestamps[i] - timestamps[i - 1];
        final avgDepth = (depths[i - 1] + depths[i]) / 2.0;

        calculateSegment(
          depthMeters: avgDepth,
          durationSeconds: duration,
          fN2: fN2,
          fHe: fHe,
        );
      }

      results.add(getDecoStatus(currentDepth: depths[i], fN2: fN2, fHe: fHe));
    }

    return results;
  }

  /// Get ceiling curve for a dive profile.
  ///
  /// Returns list of ceiling depths corresponding to each profile point.
  List<double> getCeilingCurve({
    required List<double> depths,
    required List<int> timestamps,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
  }) {
    final statuses = processProfile(
      depths: depths,
      timestamps: timestamps,
      fN2: fN2,
      fHe: fHe,
    );

    return statuses.map((s) => s.ceilingMeters).toList();
  }

  /// Get NDL curve for a dive profile.
  ///
  /// Returns list of NDL values in seconds for each profile point.
  /// Values of -1 indicate deco obligation.
  List<int> getNdlCurve({
    required List<double> depths,
    required List<int> timestamps,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
  }) {
    final statuses = processProfile(
      depths: depths,
      timestamps: timestamps,
      fN2: fN2,
      fHe: fHe,
    );

    return statuses.map((s) => s.ndlSeconds).toList();
  }
}

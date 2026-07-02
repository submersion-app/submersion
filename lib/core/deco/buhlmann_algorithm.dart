import 'dart:math' as math;

import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';

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

  /// Deepest GF-low ceiling (metres) reached so far this dive -- the fixed
  /// anchor for gradient-factor interpolation, mirroring Subsurface's
  /// `gf_low_pressure_this_dive`. It is a running maximum, never re-derived from
  /// the current (off-gassing) tissue state, so shallow stops interpolate toward
  /// GF-high instead of collapsing to GF-low.
  double _gfLowCeilingAnchor = 0.0;

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
    _gfLowCeilingAnchor = 0.0;
  }

  /// Set compartments to a specific state (for loading from saved data).
  void setCompartments(List<TissueCompartment> compartments) {
    if (compartments.length == zhl16CompartmentCount) {
      _compartments = List.from(compartments);
      _gfLowCeilingAnchor = 0.0;
      _updateGfAnchor();
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
    _updateGfAnchor();
  }

  /// Grow the GF-low anchor to the current deepest GF-low ceiling. Runs after
  /// every loading step so it records the dive's deepest stop; it only ever
  /// increases. Simulated look-ahead (NDL, deco schedule) saves/restores it so
  /// their transient loading cannot pollute it.
  void _updateGfAnchor() {
    double ceiling = 0;
    for (final comp in _compartments) {
      final c = comp.ceiling(gf: gfLow);
      if (c > ceiling) ceiling = c;
    }
    if (ceiling > _gfLowCeilingAnchor) _gfLowCeilingAnchor = ceiling;
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

    // Anchor GF-low at the dive's deepest ceiling, fixed for the whole ascent
    // (Subsurface's gf_low_pressure_this_dive), not the current stop.
    final anchorDepth = _gfLowCeilingAnchor;
    if (anchorDepth <= 0) return gfHigh;

    if (currentDepth >= anchorDepth) return gfLow;

    // Linear interpolation from GF-low at the anchor to GF-high at the surface.
    final ratio = currentDepth / anchorDepth;
    return gfHigh - (gfHigh - gfLow) * ratio;
  }

  /// Calculate ceiling using GF High only (for NDL/deco obligation checks).
  ///
  /// This method determines if the diver can ascend directly to the surface.
  /// GF High represents the surface target, which is the correct GF to use
  /// when checking whether decompression stops are required.
  ///
  /// Note: GF Low and GF interpolation are used for calculating deep stop
  /// depths during actual decompression ascent, not for determining if
  /// deco is required in the first place.
  double _calculateSurfaceTargetCeiling() {
    double maxCeiling = 0;
    for (final comp in _compartments) {
      final ceiling = comp.ceiling(gf: gfHigh);
      if (ceiling > maxCeiling) {
        maxCeiling = ceiling;
      }
    }
    return maxCeiling;
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
    // Check if already in deco using GF High (surface target).
    // NDL is about whether we can ascend directly to the surface.
    if (_calculateSurfaceTargetCeiling() > 0) {
      return -1;
    }

    // Binary search for NDL
    int low = 0;
    int high = maxNdl;

    // Create a copy of current compartments for simulation
    final savedCompartments = List<TissueCompartment>.from(_compartments);
    final savedAnchor = _gfLowCeilingAnchor;

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

      // Check if this creates a deco obligation using GF High
      if (_calculateSurfaceTargetCeiling() > 0) {
        high = mid;
      } else {
        low = mid;
      }
    }

    // Restore original compartments and anchor.
    _compartments = savedCompartments;
    _gfLowCeilingAnchor = savedAnchor;

    return low;
  }

  /// Calculate complete decompression schedule.
  ///
  /// [currentDepth] is starting depth in meters.
  /// [fN2] is nitrogen fraction for ascent gas.
  /// [fHe] is helium fraction for ascent gas.
  /// [ascentGas] optional multi-gas plan; omit for single-gas behavior.
  /// Returns list of [DecoStop] required.
  List<DecoStop> calculateDecoSchedule({
    required double currentDepth,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
    AscentGasPlan? ascentGas,
  }) {
    final plan = ascentGas ?? FixedAscentGas(fN2: fN2, fHe: fHe);
    final stops = <DecoStop>[];

    final savedCompartments = List<TissueCompartment>.from(_compartments);
    final savedAnchor = _gfLowCeilingAnchor;

    final double ceiling = calculateCeiling(currentDepth: currentDepth);
    if (ceiling <= 0) {
      _compartments = savedCompartments;
      _gfLowCeilingAnchor = savedAnchor;
      return stops; // No deco required
    }

    double currentStopDepth = (ceiling / stopIncrement).ceil() * stopIncrement;

    // Travel to first stop may cross a gas MOD: _simulateAscent splits it.
    _simulateAscent(currentDepth, currentStopDepth, plan);

    while (currentStopDepth >= lastStopDepth) {
      final int stopTime = _calculateStopTime(currentStopDepth, plan);

      if (stopTime > 0) {
        stops.add(
          DecoStop(
            depthMeters: currentStopDepth,
            durationSeconds: stopTime,
            isDeepStop: currentStopDepth > 9,
          ),
        );

        final stopGas = plan.gasForDepth(currentStopDepth);
        calculateSegment(
          depthMeters: currentStopDepth,
          durationSeconds: stopTime,
          fN2: stopGas.fN2,
          fHe: stopGas.fHe,
        );
      }

      final nextStop = currentStopDepth - stopIncrement;
      if (nextStop >= lastStopDepth) {
        _simulateAscent(currentStopDepth, nextStop, plan);
      }
      currentStopDepth = nextStop;
    }

    // Restore original compartments and anchor.
    _compartments = savedCompartments;
    _gfLowCeilingAnchor = savedAnchor;

    return stops;
  }

  /// Calculate time required at a stop depth, breathing the plan's gas there.
  int _calculateStopTime(double stopDepth, AscentGasPlan ascentGas) {
    final gas = ascentGas.gasForDepth(stopDepth);
    final nextStopDepth = stopDepth <= lastStopDepth
        ? 0.0
        : stopDepth - stopIncrement;
    int stopTime = 0;
    const maxStopTime = 120 * 60;

    // This method only COMPUTES the stop time; the loop loads minutes onto the
    // tissues to search for the clearance time, but the caller
    // (calculateDecoSchedule) applies the stop's loading once via
    // calculateSegment(stopTime). Snapshot the entry state and restore it before
    // returning so those search minutes do not persist and get double-counted.
    final entryCompartments = List<TissueCompartment>.from(_compartments);
    final entryAnchor = _gfLowCeilingAnchor;

    while (stopTime < maxStopTime) {
      final testCompartments = List<TissueCompartment>.from(_compartments);
      final testAnchor = _gfLowCeilingAnchor;

      calculateSegment(
        depthMeters: stopDepth,
        durationSeconds: 60,
        fN2: gas.fN2,
        fHe: gas.fHe,
      );

      // Leave the stop once the diver may ascend to the NEXT (shallower) stop:
      // evaluate the ceiling at the gradient factor for that shallower depth,
      // matching Subsurface's trial_ascent (tissue tolerance at the target
      // stoplevel), with GF-low anchored at the dive's deepest ceiling. At the
      // last stop the next level is the surface, where the GF is GF-high -- the
      // same criterion the deco-cleared check uses -- so TTS counts down to
      // surfacing instead of collapsing in one sample.
      final ceiling = calculateCeiling(currentDepth: nextStopDepth);

      // Restore for next iteration. The trial minute must not leak into
      // persistent state: restore the anchor too, otherwise a trial minute that
      // is never taken (the break below) could permanently grow the anchor.
      _compartments = testCompartments;
      _gfLowCeilingAnchor = testAnchor;

      if (ceiling <= nextStopDepth) {
        break;
      }

      calculateSegment(
        depthMeters: stopDepth,
        durationSeconds: 60,
        fN2: gas.fN2,
        fHe: gas.fHe,
      );
      stopTime += 60;
    }

    // Undo the search loading; the caller applies the stop's loading once.
    _compartments = entryCompartments;
    _gfLowCeilingAnchor = entryAnchor;

    return ((stopTime + 59) ~/ 60) * 60;
  }

  /// Simulate ascent between depths, splitting the leg at every gas-switch
  /// (MOD) depth it crosses so each sub-leg breathes the gas eligible at that
  /// sub-leg's deeper end. For [FixedAscentGas] there are no switch depths, so
  /// this collapses to a single average-depth segment (legacy behavior).
  void _simulateAscent(
    double fromDepth,
    double toDepth,
    AscentGasPlan ascentGas,
  ) {
    if (fromDepth <= toDepth) return;

    final switches = ascentGas.switchDepthsBetween(fromDepth, toDepth);
    double segTop = fromDepth;
    for (final switchDepth in switches) {
      // switches is descending; each is strictly between toDepth and fromDepth.
      _ascendLeg(segTop, switchDepth, ascentGas);
      segTop = switchDepth;
    }
    _ascendLeg(segTop, toDepth, ascentGas);
  }

  /// Load one un-split ascent sub-leg on the gas eligible at its deeper end.
  void _ascendLeg(double fromDepth, double toDepth, AscentGasPlan ascentGas) {
    if (fromDepth <= toDepth) return;
    final gas = ascentGas.gasForDepth(fromDepth);
    final depthChange = fromDepth - toDepth;
    final ascentTimeSeconds = (depthChange / ascentRate * 60).round();
    final avgDepth = (fromDepth + toDepth) / 2.0;

    calculateSegment(
      depthMeters: avgDepth,
      durationSeconds: ascentTimeSeconds,
      fN2: gas.fN2,
      fHe: gas.fHe,
    );
  }

  /// Calculate Time To Surface (TTS) including all deco stops.
  ///
  /// [currentDepth] is starting depth in meters.
  /// [fN2] is nitrogen fraction for ascent gas.
  /// [fHe] is helium fraction for ascent gas.
  /// [ascentGas] optional multi-gas plan; omit for single-gas behavior.
  /// Returns TTS in seconds.
  int calculateTts({
    required double currentDepth,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
    AscentGasPlan? ascentGas,
  }) {
    final plan = ascentGas ?? FixedAscentGas(fN2: fN2, fHe: fHe);
    final stops = calculateDecoSchedule(
      currentDepth: currentDepth,
      ascentGas: plan,
    );

    int tts = 0;
    for (final stop in stops) {
      tts += stop.durationSeconds;
    }

    double depth = currentDepth;
    for (final stop in stops) {
      final ascentTime = ((depth - stop.depthMeters) / ascentRate * 60).round();
      tts += ascentTime;
      depth = stop.depthMeters;
    }

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
  /// [safetyStopTimeAccumulated] is seconds already spent in safety stop zone.
  DecoStatus getDecoStatus({
    required double currentDepth,
    double fN2 = airN2Fraction,
    double fHe = 0.0,
    int safetyStopTimeAccumulated = 0,
    AscentGasPlan? ascentGas,
  }) {
    final plan = ascentGas ?? FixedAscentGas(fN2: fN2, fHe: fHe);
    final ndl = calculateNdl(depthMeters: currentDepth, fN2: fN2, fHe: fHe);

    // Only calculate ceiling/stops when actually in deco (NDL < 0).
    // The GF-interpolated ceiling is for ascent planning during deco,
    // not for display when the diver can still ascend directly to surface.
    final ceiling = ndl < 0
        ? calculateCeiling(currentDepth: currentDepth)
        : 0.0;
    final stops = ndl < 0
        ? calculateDecoSchedule(currentDepth: currentDepth, ascentGas: plan)
        : <DecoStop>[];

    // TTS is the MANDATORY time to surface only: the ascent plus any required
    // decompression stops. The recommended safety stop is NOT folded in here --
    // it is reported separately in safetyStopSeconds. Baking the safety stop
    // into TTS made TTS drop when a dive entered deco (the safety stop vanished
    // as deco stops appeared), which reads backwards on the profile. Keeping TTS
    // mandatory-only means it can only ever rise as an obligation grows.
    final int tts;
    final int safetyStop;
    if (ndl < 0) {
      // In deco: full obligation (ascent + deco stops). The mandatory deco
      // stops supersede any recommended safety stop, so it is not reported.
      tts = calculateTts(currentDepth: currentDepth, ascentGas: plan);
      safetyStop = 0;
    } else {
      // No deco obligation: TTS is just the direct ascent to the surface.
      tts = (currentDepth / ascentRate * 60).round();

      // Report the recommended safety stop separately: a 3-minute stop, minus
      // time already accumulated in the 3-6 m safety-stop zone during the ascent
      // (see processProfileWithGasSegments; can't go negative).
      const safetyStopDuration = 180; // 3 minutes in seconds
      safetyStop = (safetyStopDuration - safetyStopTimeAccumulated).clamp(
        0,
        safetyStopDuration,
      );
    }

    return DecoStatus(
      compartments: List.unmodifiable(_compartments),
      ndlSeconds: ndl,
      ceilingMeters: ceiling,
      ttsSeconds: tts,
      safetyStopSeconds: safetyStop,
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
    return processProfileWithGasSegments(
      depths: depths,
      timestamps: timestamps,
      gasSegments: [ProfileGasSegment(startTimestamp: 0, fN2: fN2, fHe: fHe)],
    );
  }

  /// Process a dive profile with explicit gas changes over time.
  ///
  /// [gasSegments] must be non-empty and sorted by [startTimestamp].
  /// Each segment becomes active from its start timestamp onward until
  /// superseded by the next segment.
  /// [ascentGasPlan] optionally overrides the ascent gas selection for TTS
  /// and deco-schedule calculations; null reproduces the legacy per-sample
  /// single-gas behavior.
  List<DecoStatus> processProfileWithGasSegments({
    required List<double> depths,
    required List<int> timestamps,
    required List<ProfileGasSegment> gasSegments,
    AscentGasPlan? ascentGasPlan,
  }) {
    if (depths.length != timestamps.length || depths.isEmpty) {
      return [];
    }
    if (gasSegments.isEmpty) {
      throw ArgumentError('gasSegments must not be empty');
    }
    if (gasSegments.first.startTimestamp > timestamps.first) {
      throw ArgumentError(
        'gasSegments.first.startTimestamp must be less than or equal to '
        'the first profile timestamp',
      );
    }
    for (int i = 1; i < gasSegments.length; i++) {
      if (gasSegments[i].startTimestamp < gasSegments[i - 1].startTimestamp) {
        throw ArgumentError('gasSegments must be sorted by startTimestamp');
      }
    }

    final results = <DecoStatus>[];

    // Track time spent in the safety-stop zone (3-6m / 10-20ft) so the
    // recommended safety stop reported on DecoStatus counts down as the diver
    // completes it. Only count time during the ascent phase -- after the dive's
    // deepest sample -- so descent through the zone and mid-dive shallow
    // excursions don't pre-drain the recommendation. This mirrors
    // profile_analysis_service's safety-stop detection (which anchors on the
    // last occurrence of max depth).
    const safetyStopZoneMin = 3.0; // meters
    const safetyStopZoneMax = 6.0; // meters
    final maxDepth = depths.reduce(math.max);
    final maxDepthIndex = depths.lastIndexOf(maxDepth);
    int safetyStopTimeAccumulated = 0;

    for (int i = 0; i < depths.length; i++) {
      if (i > 0) {
        final intervalStart = timestamps[i - 1];
        final intervalEnd = timestamps[i];
        final intervalBoundaries = <int>[
          intervalStart,
          ...gasSegments
              .where(
                (segment) =>
                    segment.startTimestamp > intervalStart &&
                    segment.startTimestamp < intervalEnd,
              )
              .map((segment) => segment.startTimestamp),
          intervalEnd,
        ];

        for (
          int boundaryIndex = 1;
          boundaryIndex < intervalBoundaries.length;
          boundaryIndex++
        ) {
          final subIntervalStart = intervalBoundaries[boundaryIndex - 1];
          final subIntervalEnd = intervalBoundaries[boundaryIndex];
          final duration = subIntervalEnd - subIntervalStart;
          final startDepth = _interpolateDepth(
            startTimestamp: intervalStart,
            endTimestamp: intervalEnd,
            startDepth: depths[i - 1],
            endDepth: depths[i],
            targetTimestamp: subIntervalStart,
          );
          final endDepth = _interpolateDepth(
            startTimestamp: intervalStart,
            endTimestamp: intervalEnd,
            startDepth: depths[i - 1],
            endDepth: depths[i],
            targetTimestamp: subIntervalEnd,
          );
          final avgDepth = (startDepth + endDepth) / 2.0;
          final gas = _activeGasAtTimestamp(subIntervalStart, gasSegments);

          calculateSegment(
            depthMeters: avgDepth,
            durationSeconds: duration,
            fN2: gas.fN2,
            fHe: gas.fHe,
          );

          // Accumulate time if average depth was in the safety-stop zone,
          // but only on the ascent (after the deepest sample) so descent and
          // mid-dive shallow excursions don't count.
          if (i > maxDepthIndex &&
              avgDepth >= safetyStopZoneMin &&
              avgDepth <= safetyStopZoneMax) {
            safetyStopTimeAccumulated += duration;
          }
        }
      }

      results.add(
        getDecoStatus(
          currentDepth: depths[i],
          fN2: _activeGasAtTimestamp(timestamps[i], gasSegments).fN2,
          fHe: _activeGasAtTimestamp(timestamps[i], gasSegments).fHe,
          safetyStopTimeAccumulated: safetyStopTimeAccumulated,
          ascentGas: ascentGasPlan,
        ),
      );
    }

    return results;
  }

  double _interpolateDepth({
    required int startTimestamp,
    required int endTimestamp,
    required double startDepth,
    required double endDepth,
    required int targetTimestamp,
  }) {
    if (endTimestamp == startTimestamp) {
      return endDepth;
    }

    final progress =
        (targetTimestamp - startTimestamp) / (endTimestamp - startTimestamp);
    return startDepth + ((endDepth - startDepth) * progress);
  }

  ProfileGasSegment _activeGasAtTimestamp(
    int timestamp,
    List<ProfileGasSegment> gasSegments,
  ) {
    var active = gasSegments.first;
    for (final segment in gasSegments) {
      if (segment.startTimestamp <= timestamp) {
        active = segment;
      } else {
        break;
      }
    }
    return active;
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
    reset();
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
    reset();
    final statuses = processProfile(
      depths: depths,
      timestamps: timestamps,
      fN2: fN2,
      fHe: fHe,
    );

    return statuses.map((s) => s.ndlSeconds).toList();
  }
}

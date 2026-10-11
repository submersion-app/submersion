import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';

/// Projects the diver's tissue state at the end of their last dive forward
/// to the current moment.
///
/// Unlike [CnsOtuLiveService] there is no closed-form decay: tissue loading
/// is a full Bühlmann off-gassing segment at the surface (breathing air),
/// using the same [BuhlmannAlgorithm] the dive log and planner already run.
/// Mirrors `tissue_seed.dart`, which off-gasses a dive's end-of-dive
/// compartments for a fixed surface interval to seed a plan that follows it;
/// this projects to "now" instead of to a fixed interval, and re-evaluates
/// on each UI tick (see `CnsOtuPage`'s minute timer) rather than caching a
/// stale result from the moment the data was fetched.
class TissueLiveService {
  const TissueLiveService._();

  /// Tissue state at [now], off-gassed from [endOfDiveCompartments] over the
  /// time elapsed since [lastDiveEnd].
  ///
  /// [gfLow]/[gfHigh] are the diver's CURRENT decompression settings, not
  /// whatever the dive itself was analyzed with: the live readout reflects
  /// what the diver's present conservatism means for their residual loading
  /// right now, not a historical setting.
  ///
  /// A [now] at or before [lastDiveEnd] (clock skew, or evaluating right at
  /// the dive's end) applies no off-gassing, the same guard
  /// [CnsOtuLiveService.currentCns] uses for its elapsed time.
  static DecoStatus currentStatus({
    required List<TissueCompartment> endOfDiveCompartments,
    required DateTime lastDiveEnd,
    required DateTime now,
    required double gfLow,
    required double gfHigh,
  }) {
    final algorithm = _loadedAlgorithm(
      endOfDiveCompartments: endOfDiveCompartments,
      gfLow: gfLow,
      gfHigh: gfHigh,
    );

    final elapsed = now.difference(lastDiveEnd);
    if (elapsed > Duration.zero) {
      algorithm.calculateSegment(
        depthMeters: 0,
        durationSeconds: elapsed.inSeconds,
        fN2: airN2Fraction,
        fHe: 0.0,
      );
    }

    return algorithm.getDecoStatus(
      currentDepth: 0,
      fN2: airN2Fraction,
      fHe: 0.0,
    );
  }

  /// Number of samples [surfaceIntervalTimeline] divides the surface
  /// interval into, independent of how long it actually is. The off-gassing
  /// math is cheap regardless of step size, so a fixed count keeps the
  /// resulting heat map a similar width whether the interval is 20 minutes
  /// or 2 days, rather than growing without bound for a long one.
  static const int timelineSampleCount = 60;

  /// A sampled timeline of tissue state across the surface interval since
  /// [lastDiveEnd], for a heat map / area chart of off-gassing -- the same
  /// way `CompactTissueLoadingCard` already draws one across a dive, just
  /// across the surface interval that follows it instead. The last entry is
  /// the same [DecoStatus] [currentStatus] would return for the same inputs.
  ///
  /// A single-entry list (just the end-of-dive state, not off-gassed) when
  /// [now] is at or before [lastDiveEnd]: nothing has elapsed to sample.
  static List<DecoStatus> surfaceIntervalTimeline({
    required List<TissueCompartment> endOfDiveCompartments,
    required DateTime lastDiveEnd,
    required DateTime now,
    required double gfLow,
    required double gfHigh,
  }) {
    final algorithm = _loadedAlgorithm(
      endOfDiveCompartments: endOfDiveCompartments,
      gfLow: gfLow,
      gfHigh: gfHigh,
    );
    DecoStatus snapshot() =>
        algorithm.getDecoStatus(currentDepth: 0, fN2: airN2Fraction, fHe: 0.0);

    final totalSeconds = now.difference(lastDiveEnd).inSeconds;
    if (totalSeconds <= 0) return [snapshot()];

    final stepSeconds = (totalSeconds / timelineSampleCount).ceil();
    final timeline = <DecoStatus>[snapshot()];
    var remaining = totalSeconds;
    while (remaining > 0) {
      final step = remaining < stepSeconds ? remaining : stepSeconds;
      algorithm.calculateSegment(
        depthMeters: 0,
        durationSeconds: step,
        fN2: airN2Fraction,
        fHe: 0.0,
      );
      timeline.add(snapshot());
      remaining -= step;
    }
    return timeline;
  }

  /// An algorithm loaded with [endOfDiveCompartments], ready to off-gas at
  /// the surface. restoreState, not setCompartments, to load the raw
  /// end-of-dive tensions without side effects, then
  /// deriveGfAnchorFromLoading explicitly -- same two-step sequence as
  /// tissue_seed.dart's seededTissueState, and for the same reason: a diver
  /// who still owes a real ceiling at the moment they surface (skipped or
  /// shortened a stop) must get that ceiling re-derived from the loaded
  /// compartments, not an anchor stuck at 0 (which
  /// getDecoStatus/calculateCeiling would otherwise read as "no ceiling
  /// ever owed" and under-report).
  static BuhlmannAlgorithm _loadedAlgorithm({
    required List<TissueCompartment> endOfDiveCompartments,
    required double gfLow,
    required double gfHigh,
  }) {
    final algorithm = BuhlmannAlgorithm(gfLow: gfLow, gfHigh: gfHigh);
    algorithm.restoreState(endOfDiveCompartments);
    algorithm.deriveGfAnchorFromLoading();
    return algorithm;
  }

  /// Nitrogen+helium tension above surface equilibrium, in bar, below which
  /// a compartment's residual loading is treated as noise rather than a
  /// real reading worth showing. Small enough that a trivial, shallow dive
  /// does not linger as "still loaded" for days; large enough to survive
  /// floating-point noise as a compartment's tension asymptotically
  /// approaches the surface value without ever exactly reaching it.
  static const double _residualLoadEpsilonBar = 0.01;

  /// Whether [status] (as returned by [currentStatus]) still carries
  /// residual tissue loading worth showing, i.e. at least one compartment's
  /// inert-gas tension is meaningfully above surface equilibrium. Serves the
  /// same purpose for tissue loading as the CNS%/OTU epsilon in
  /// `CnsOtuStatusCard` serves for those readouts: a projection that is
  /// technically non-zero but has decayed into irrelevance should not keep a
  /// safety readout in its "active" state.
  static bool hasResidualLoad(DecoStatus status) {
    final surfaceTension = calculateInspiredN2(1.0, airN2Fraction);
    return status.compartments.any(
      (comp) => comp.totalInertGas - surfaceTension > _residualLoadEpsilonBar,
    );
  }
}

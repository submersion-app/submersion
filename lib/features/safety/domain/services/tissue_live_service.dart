import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
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
  /// [environment] is the last dive's site conditions (see
  /// `CnsOtuSnapshot.surfaceEnvironment`): the surface the tissues off-gas
  /// toward, which at altitude sits well below the sea-level equilibrium.
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
    DiveEnvironment environment = DiveEnvironment.standard,
  }) {
    final algorithm = _loadedAlgorithm(
      endOfDiveCompartments: endOfDiveCompartments,
      gfLow: gfLow,
      gfHigh: gfHigh,
      environment: environment,
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
    // Derived from THIS loading, after off-gassing, not the end-of-dive
    // loading _loadedAlgorithm handed back -- see its doc for why a stale
    // anchor under-reports.
    algorithm.deriveGfAnchorFromLoading();

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
    DiveEnvironment environment = DiveEnvironment.standard,
  }) {
    final algorithm = _loadedAlgorithm(
      endOfDiveCompartments: endOfDiveCompartments,
      gfLow: gfLow,
      gfHigh: gfHigh,
      environment: environment,
    );
    // Re-derived before every snapshot, not just the first: each sampled
    // state's ceiling must reflect what THAT state currently owes, not a
    // ceiling anchored once at the end-of-dive loading and frozen through
    // the rest of the off-gassing. See _loadedAlgorithm's doc.
    DecoStatus snapshot() {
      algorithm.deriveGfAnchorFromLoading();
      return algorithm.getDecoStatus(
        currentDepth: 0,
        fN2: airN2Fraction,
        fHe: 0.0,
      );
    }

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

  /// An algorithm loaded with [endOfDiveCompartments]'s raw tensions, ready
  /// to off-gas at the surface.
  ///
  /// restoreState, not setCompartments, so loading them has no side effect
  /// on the GF-low ceiling anchor here: unlike tissue_seed.dart's
  /// seededTissueState (which off-gasses a FIXED interval once and derives
  /// the anchor once, after that single step), both callers here derive the
  /// anchor themselves, fresh, right before every snapshot they take --
  /// `currentStatus` after its one off-gassing step, `surfaceIntervalTimeline`
  /// after each of its many. A diver who still owes a real ceiling at the
  /// moment they surface (skipped or shortened a stop) must get that
  /// ceiling re-derived from whatever the compartments currently hold, not
  /// anchored once to the end-of-dive loading and then frozen while they
  /// off-gas: `calculateSegment` only ever grows the anchor, never shrinks
  /// it, so a stale anchor keeps reporting the dive's original, deeper
  /// ceiling long after the tissues no longer owe it.
  static BuhlmannAlgorithm _loadedAlgorithm({
    required List<TissueCompartment> endOfDiveCompartments,
    required double gfLow,
    required double gfHigh,
    required DiveEnvironment environment,
  }) {
    final algorithm = BuhlmannAlgorithm(
      gfLow: gfLow,
      gfHigh: gfHigh,
      environment: environment,
    );
    algorithm.restoreState(endOfDiveCompartments);
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
  /// inert-gas tension is meaningfully above surface equilibrium.
  ///
  /// The equilibrium is [status]'s own inspired N2 at its ambient pressure,
  /// so it follows the environment the status was projected in rather than
  /// assuming a 1.0 bar sea-level surface. Serves the
  /// same purpose for tissue loading as the CNS%/OTU epsilon in
  /// `CnsOtuStatusCard` serves for those readouts: a projection that is
  /// technically non-zero but has decayed into irrelevance should not keep a
  /// safety readout in its "active" state.
  static bool hasResidualLoad(DecoStatus status) {
    final surfaceTension =
        status.inspiredN2Bar ??
        calculateInspiredN2(status.ambientPressureBar, airN2Fraction);
    return status.compartments.any(
      (comp) => comp.totalInertGas - surfaceTension > _residualLoadEpsilonBar,
    );
  }
}

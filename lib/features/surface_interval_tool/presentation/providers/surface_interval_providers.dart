import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

// =============================================================================
// Input State Providers
// =============================================================================

/// First dive depth in meters (stored in metric, converted for display).
final siFirstDiveDepthProvider = StateProvider<double>((ref) => 18.0);

/// First dive time in minutes.
final siFirstDiveTimeProvider = StateProvider<int>((ref) => 45);

/// First dive O2 percentage (21 = air, 32 = EAN32, etc.).
final siFirstDiveO2Provider = StateProvider<double>((ref) => 21.0);

/// First dive Helium percentage (0 for recreational, >0 for trimix).
final siFirstDiveHeProvider = StateProvider<double>((ref) => 0.0);

/// Second dive depth in meters.
final siSecondDiveDepthProvider = StateProvider<double>((ref) => 18.0);

/// Second dive time in minutes.
final siSecondDiveTimeProvider = StateProvider<int>((ref) => 45);

/// Second dive O2 percentage (21 = air, 32 = EAN32, etc.).
final siSecondDiveO2Provider = StateProvider<double>((ref) => 21.0);

/// Second dive Helium percentage (0 for recreational, >0 for trimix).
final siSecondDiveHeProvider = StateProvider<double>((ref) => 0.0);

/// Current surface interval for chart visualization (minutes).
final siSurfaceIntervalProvider = StateProvider<int>((ref) => 60);

// =============================================================================
// Computed Providers
// =============================================================================

/// Nitrogen fraction for first dive gas.
final siFirstDiveFN2Provider = Provider<double>((ref) {
  final o2 = ref.watch(siFirstDiveO2Provider);
  final he = ref.watch(siFirstDiveHeProvider);
  return (100 - o2 - he) / 100.0;
});

/// Helium fraction for first dive gas.
final siFirstDiveFHeProvider = Provider<double>((ref) {
  return ref.watch(siFirstDiveHeProvider) / 100.0;
});

/// Nitrogen fraction for second dive gas.
final siSecondDiveFN2Provider = Provider<double>((ref) {
  final o2 = ref.watch(siSecondDiveO2Provider);
  final he = ref.watch(siSecondDiveHeProvider);
  return (100 - o2 - he) / 100.0;
});

/// Helium fraction for second dive gas.
final siSecondDiveFHeProvider = Provider<double>((ref) {
  return ref.watch(siSecondDiveHeProvider) / 100.0;
});

// =============================================================================
// Oxygen Exposure (ppO2 / MOD)
// =============================================================================

/// Oxygen exposure for one dive's gas at that dive's planned depth.
@immutable
class SiGasSafety {
  /// The planned depth this exposure was evaluated at, in meters.
  final double depthMeters;

  /// Partial pressure of oxygen at [depthMeters], in bar.
  final double ppO2;

  /// Maximum operating depth for this mix at [limit], in meters.
  final double modMeters;

  /// The diver's configured working ppO2 ceiling, in bar.
  final double limit;

  const SiGasSafety({
    required this.depthMeters,
    required this.ppO2,
    required this.modMeters,
    required this.limit,
  });

  /// Whether the planned depth puts the diver past their ppO2 ceiling.
  ///
  /// The ceiling itself is allowed; only exposure above it is a violation. The
  /// tolerance keeps a mix that lands exactly on the limit from tripping the
  /// warning through floating point noise.
  bool get exceedsMod => ppO2 > limit + 1e-9;
}

SiGasSafety _gasSafetyAt({
  required double depthMeters,
  required double o2Percent,
  required double limit,
}) {
  final o2Fraction = o2Percent / 100.0;
  return SiGasSafety(
    depthMeters: depthMeters,
    ppO2: O2ToxicityCalculator.calculatePpO2(depthMeters, o2Fraction),
    modMeters: O2ToxicityCalculator.calculateMod(o2Fraction, maxPpO2: limit),
    limit: limit,
  );
}

/// Oxygen exposure for the first dive's gas at the first dive's depth.
final siFirstDiveGasSafetyProvider = Provider<SiGasSafety>((ref) {
  return _gasSafetyAt(
    depthMeters: ref.watch(siFirstDiveDepthProvider),
    o2Percent: ref.watch(siFirstDiveO2Provider),
    limit: ref.watch(ppO2MaxWorkingProvider),
  );
});

/// Oxygen exposure for the second dive's gas at the second dive's depth.
final siSecondDiveGasSafetyProvider = Provider<SiGasSafety>((ref) {
  return _gasSafetyAt(
    depthMeters: ref.watch(siSecondDiveDepthProvider),
    o2Percent: ref.watch(siSecondDiveO2Provider),
    limit: ref.watch(ppO2MaxWorkingProvider),
  );
});

/// Whether both planned dives stay within the diver's working ppO2 ceiling.
///
/// Kept separate from [siSecondDiveIsSafeProvider] so the no-deco verdict and
/// the oxygen verdict stay independently testable and independently explainable
/// to the diver.
final siGasMixesAreSafeProvider = Provider<bool>((ref) {
  return !ref.watch(siFirstDiveGasSafetyProvider).exceedsMod &&
      !ref.watch(siSecondDiveGasSafetyProvider).exceedsMod;
});

/// Tissue compartments state after first dive completes.
final siPostDiveCompartmentsProvider = Provider<List<TissueCompartment>>((ref) {
  final depth = ref.watch(siFirstDiveDepthProvider);
  final time = ref.watch(siFirstDiveTimeProvider);
  final fN2 = ref.watch(siFirstDiveFN2Provider);
  final fHe = ref.watch(siFirstDiveFHeProvider);
  final settings = ref.watch(settingsProvider);

  final algorithm = BuhlmannAlgorithm(
    gfLow: settings.gfLowDecimal,
    gfHigh: settings.gfHighDecimal,
  );

  // Simulate first dive at constant depth
  algorithm.calculateSegment(
    depthMeters: depth,
    durationSeconds: time * 60,
    fN2: fN2,
    fHe: fHe,
  );

  return algorithm.compartments;
});

/// Tissue compartments after the selected surface interval.
final siRecoveredCompartmentsProvider = Provider<List<TissueCompartment>>((
  ref,
) {
  final postDiveCompartments = ref.watch(siPostDiveCompartmentsProvider);
  final surfaceInterval = ref.watch(siSurfaceIntervalProvider);

  return _calculateRecoveredCompartments(postDiveCompartments, surfaceInterval);
});

/// NDL available for the second dive given the current surface interval.
/// Returns -1 if still in deco obligation, otherwise NDL in seconds.
final siSecondDiveNdlProvider = Provider<int>((ref) {
  final recoveredCompartments = ref.watch(siRecoveredCompartmentsProvider);
  final secondDiveDepth = ref.watch(siSecondDiveDepthProvider);
  final fN2 = ref.watch(siSecondDiveFN2Provider);
  final fHe = ref.watch(siSecondDiveFHeProvider);
  final settings = ref.watch(settingsProvider);

  final algorithm = BuhlmannAlgorithm(
    gfLow: settings.gfLowDecimal,
    gfHigh: settings.gfHighDecimal,
  );
  algorithm.setCompartments(recoveredCompartments);

  return algorithm.calculateNdl(
    depthMeters: secondDiveDepth,
    fN2: fN2,
    fHe: fHe,
  );
});

/// Whether the second dive can be completed within NDL given current interval.
final siSecondDiveIsSafeProvider = Provider<bool>((ref) {
  final ndl = ref.watch(siSecondDiveNdlProvider);
  final secondDiveTime = ref.watch(siSecondDiveTimeProvider);

  // NDL must be positive and at least as long as planned dive
  return ndl > 0 && ndl >= secondDiveTime * 60;
});

/// Longest surface interval the planner searches, in minutes.
///
/// This is a reporting horizon, not a physical limit. Compartment 16 has a 635
/// minute nitrogen half-time, so a heavily loaded diver is still off-gassing
/// well past six hours; a plan that does not fit inside the horizon may still
/// fit after a longer wait. Only the clean-tissue no-stop limit settles whether
/// a dive is possible at all.
const int siMaxSearchIntervalMinutes = 360;

/// Why the planner did or did not produce a surface interval.
enum SiIntervalOutcome {
  /// A wait inside [siMaxSearchIntervalMinutes] makes the second dive no-stop.
  withinHorizon,

  /// Off-gassing gets there eventually, but not inside the planner's horizon.
  /// The remedy is a longer wait, not a different dive.
  beyondHorizon,

  /// The second dive busts its no-stop limit even on completely clean tissues,
  /// so no surface interval of any length is enough. The remedy is a shorter or
  /// shallower dive.
  impossible,
}

/// How long a diver must wait on the surface before the planned second dive.
@immutable
class SiMinimumInterval {
  /// Which of the three answers the planner arrived at.
  final SiIntervalOutcome outcome;

  /// Shortest surface interval, in minutes, after which the second dive fits
  /// inside its no-decompression limit.
  ///
  /// Set only for [SiIntervalOutcome.withinHorizon]; null otherwise, because
  /// the planner has no honest number to offer in those states.
  final int? minutes;

  /// No-stop limit at the second dive's depth and mix on clean tissues, in
  /// seconds.
  ///
  /// Surface time works toward this ceiling and can never beat it, which is
  /// what separates "wait longer" from "change the dive". It depends only on
  /// the second dive's depth and mix, not on how loaded the first dive left the
  /// diver.
  final int cleanTissueNoStopSeconds;

  const SiMinimumInterval({
    required this.outcome,
    required this.minutes,
    required this.cleanTissueNoStopSeconds,
  });

  /// Whether the planner produced a concrete interval to wait.
  bool get hasInterval => minutes != null;
}

/// Minimum surface interval needed before the planned second dive.
///
/// Binary searches for the shortest wait whose NDL covers the planned dive, but
/// only after settling two questions the search itself cannot answer. The
/// search returns its own bounds when it finds nothing, so on its own it cannot
/// tell "no wait is long enough" from "the answer is exactly the bound" -- that
/// is what reported an impossible plan as a plausible six hour wait.
final siMinimumIntervalProvider = Provider<SiMinimumInterval>((ref) {
  final postDiveCompartments = ref.watch(siPostDiveCompartmentsProvider);
  final secondDiveDepth = ref.watch(siSecondDiveDepthProvider);
  final secondDiveTime = ref.watch(siSecondDiveTimeProvider);
  final fN2 = ref.watch(siSecondDiveFN2Provider);
  final fHe = ref.watch(siSecondDiveFHeProvider);
  final settings = ref.watch(settingsProvider);

  final requiredNdlSeconds = secondDiveTime * 60;

  /// NDL for the second dive after [surfaceIntervalMinutes] of off-gassing.
  int ndlAfter(int surfaceIntervalMinutes) {
    final algorithm = BuhlmannAlgorithm(
      gfLow: settings.gfLowDecimal,
      gfHigh: settings.gfHighDecimal,
    );
    algorithm.setCompartments(
      _calculateRecoveredCompartments(
        postDiveCompartments,
        surfaceIntervalMinutes,
      ),
    );
    return algorithm.calculateNdl(
      depthMeters: secondDiveDepth,
      fN2: fN2,
      fHe: fHe,
    );
  }

  // Surface off-gassing drives every compartment toward equilibrium with
  // surface air, so the second dive's NDL rises toward -- and never past -- the
  // no-stop time a diver with clean tissues would get here. That makes the
  // clean-tissue NDL an exact test for "no surface interval can ever be
  // enough", and unlike a fixed horizon it does not depend on how far the slow
  // compartments still have to unload. calculateNdl signals a standing deco
  // obligation with -1, which is not a duration, so floor it at zero.
  final cleanTissue = BuhlmannAlgorithm(
    gfLow: settings.gfLowDecimal,
    gfHigh: settings.gfHighDecimal,
  );
  final cleanTissueNoStopSeconds = math.max(
    0,
    cleanTissue.calculateNdl(depthMeters: secondDiveDepth, fN2: fN2, fHe: fHe),
  );

  SiMinimumInterval result(SiIntervalOutcome outcome, int? minutes) {
    return SiMinimumInterval(
      outcome: outcome,
      minutes: minutes,
      cleanTissueNoStopSeconds: cleanTissueNoStopSeconds,
    );
  }

  if (requiredNdlSeconds > cleanTissueNoStopSeconds) {
    return result(SiIntervalOutcome.impossible, null);
  }

  // The dive does fit on clean tissues, so waiting is the right remedy -- but
  // the diver may still need longer than the planner looks ahead.
  if (ndlAfter(siMaxSearchIntervalMinutes) < requiredNdlSeconds) {
    return result(SiIntervalOutcome.beyondHorizon, null);
  }

  // A diver who can roll straight into the next dive should not be handed a
  // one minute wait, which is what the bare search converges to.
  if (ndlAfter(0) >= requiredNdlSeconds) {
    return result(SiIntervalOutcome.withinHorizon, 0);
  }

  // Invariant: low is known to be too short, high is known to be sufficient.
  int low = 0;
  int high = siMaxSearchIntervalMinutes;

  while (high - low > 1) {
    final mid = (low + high) ~/ 2;

    if (ndlAfter(mid) >= requiredNdlSeconds) {
      high = mid;
    } else {
      low = mid;
    }
  }

  return result(SiIntervalOutcome.withinHorizon, high);
});

/// Data class for a single point on the tissue recovery chart.
class TissueRecoveryPoint {
  final int minutes;
  final double loadingPercent;

  const TissueRecoveryPoint({
    required this.minutes,
    required this.loadingPercent,
  });
}

/// Recovery curve data for all 16 compartments over 4 hours.
/// Returns a list of 16 lists, each containing loading % at 5-minute intervals.
final siRecoveryCurveProvider = Provider<List<List<TissueRecoveryPoint>>>((
  ref,
) {
  final postDiveCompartments = ref.watch(siPostDiveCompartmentsProvider);

  final curves = <List<TissueRecoveryPoint>>[];

  for (int compartmentIdx = 0; compartmentIdx < 16; compartmentIdx++) {
    final curve = <TissueRecoveryPoint>[];
    final comp = postDiveCompartments[compartmentIdx];

    // Generate points from 0 to 240 minutes at 5-minute intervals
    for (int minutes = 0; minutes <= 240; minutes += 5) {
      final loading = _calculateCompartmentLoadingAtSurface(comp, minutes);
      curve.add(TissueRecoveryPoint(minutes: minutes, loadingPercent: loading));
    }
    curves.add(curve);
  }

  return curves;
});

/// Leading (most saturated) compartment index after first dive.
final siLeadingCompartmentProvider = Provider<int>((ref) {
  final compartments = ref.watch(siPostDiveCompartmentsProvider);

  int leadingIdx = 0;
  double maxLoading = 0;

  for (int i = 0; i < compartments.length; i++) {
    if (compartments[i].percentLoading > maxLoading) {
      maxLoading = compartments[i].percentLoading;
      leadingIdx = i;
    }
  }

  return leadingIdx;
});

// =============================================================================
// Helper Functions
// =============================================================================

/// Calculate recovered tissue state after surface interval.
List<TissueCompartment> _calculateRecoveredCompartments(
  List<TissueCompartment> postDiveCompartments,
  int surfaceIntervalMinutes,
) {
  final surfaceN2 = calculateInspiredN2(surfacePressureBar, airN2Fraction);

  final recovered = <TissueCompartment>[];

  for (final comp in postDiveCompartments) {
    // Use Schreiner equation for off-gassing at surface
    final newN2 = _schreinerEquation(
      comp.currentPN2,
      surfaceN2,
      surfaceIntervalMinutes.toDouble(),
      comp.halfTimeN2,
    );

    // Helium also off-gasses
    final newHe = _schreinerEquation(
      comp.currentPHe,
      0.0, // No inspired helium at surface
      surfaceIntervalMinutes.toDouble(),
      comp.halfTimeHe,
    );

    recovered.add(comp.copyWith(currentPN2: newN2, currentPHe: newHe));
  }

  return recovered;
}

/// Calculate loading percentage for a single compartment after surface interval.
double _calculateCompartmentLoadingAtSurface(
  TissueCompartment comp,
  int surfaceIntervalMinutes,
) {
  final surfaceN2 = calculateInspiredN2(surfacePressureBar, airN2Fraction);

  // Calculate tissue tensions after surface interval
  final newN2 = _schreinerEquation(
    comp.currentPN2,
    surfaceN2,
    surfaceIntervalMinutes.toDouble(),
    comp.halfTimeN2,
  );

  final newHe = _schreinerEquation(
    comp.currentPHe,
    0.0,
    surfaceIntervalMinutes.toDouble(),
    comp.halfTimeHe,
  );

  // Create temporary compartment to calculate loading
  final tempComp = comp.copyWith(currentPN2: newN2, currentPHe: newHe);
  return tempComp.percentLoading;
}

/// Schreiner equation for gas loading/unloading.
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

/// Reset all surface interval inputs to defaults.
void resetSurfaceIntervalInputs(WidgetRef ref) {
  ref.read(siFirstDiveDepthProvider.notifier).state = 18.0;
  ref.read(siFirstDiveTimeProvider.notifier).state = 45;
  ref.read(siFirstDiveO2Provider.notifier).state = 21.0;
  ref.read(siFirstDiveHeProvider.notifier).state = 0.0;
  ref.read(siSecondDiveDepthProvider.notifier).state = 18.0;
  ref.read(siSecondDiveTimeProvider.notifier).state = 45;
  ref.read(siSecondDiveO2Provider.notifier).state = 21.0;
  ref.read(siSecondDiveHeProvider.notifier).state = 0.0;
  ref.read(siSurfaceIntervalProvider.notifier).state = 60;
}

/// Color palette for 16 tissue compartments.
/// Fast compartments (1-5) are blue, medium (6-10) are green,
/// slow (11-16) are warm colors (orange/red).
const List<int> compartmentColorValues = [
  0xFF00B4D8, 0xFF0096C7, 0xFF0077B6, 0xFF023E8A, 0xFF03045E, // Fast - blues
  0xFF2D6A4F, 0xFF40916C, 0xFF52B788, 0xFF74C69D, 0xFFA7C957, // Medium - greens
  0xFFF4A261, 0xFFE9C46A, 0xFFE76F51, 0xFFD62828, 0xFFB5179E,
  0xFF7209B7, // Slow - warm
];

/// Get compartment speed category name.
String getCompartmentCategory(int index) {
  if (index < 5) return 'Fast';
  if (index < 10) return 'Medium';
  return 'Slow';
}

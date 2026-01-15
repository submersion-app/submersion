import 'dart:math' as math;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
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
  final settings = ref.watch(settingsProvider);

  final algorithm = BuhlmannAlgorithm(
    gfLow: settings.gfLowDecimal,
    gfHigh: settings.gfHighDecimal,
  );
  algorithm.setCompartments(recoveredCompartments);

  return algorithm.calculateNdl(
    depthMeters: secondDiveDepth,
    fN2: airN2Fraction,
    fHe: 0.0,
  );
});

/// Whether the second dive can be completed within NDL given current interval.
final siSecondDiveIsSafeProvider = Provider<bool>((ref) {
  final ndl = ref.watch(siSecondDiveNdlProvider);
  final secondDiveTime = ref.watch(siSecondDiveTimeProvider);

  // NDL must be positive and at least as long as planned dive
  return ndl > 0 && ndl >= secondDiveTime * 60;
});

/// Minimum surface interval in minutes to achieve safe second dive.
/// Uses binary search to find the shortest interval where NDL >= dive time.
final siMinimumIntervalProvider = Provider<int>((ref) {
  final postDiveCompartments = ref.watch(siPostDiveCompartmentsProvider);
  final secondDiveDepth = ref.watch(siSecondDiveDepthProvider);
  final secondDiveTime = ref.watch(siSecondDiveTimeProvider);
  final settings = ref.watch(settingsProvider);

  final requiredNdlSeconds = secondDiveTime * 60;

  // Binary search for minimum surface interval (0 to 360 minutes / 6 hours)
  int low = 0;
  int high = 360;

  while (high - low > 1) {
    final mid = (low + high) ~/ 2;

    // Simulate recovery at surface for 'mid' minutes
    final recoveredCompartments = _calculateRecoveredCompartments(
      postDiveCompartments,
      mid,
    );

    // Check NDL for second dive
    final algorithm = BuhlmannAlgorithm(
      gfLow: settings.gfLowDecimal,
      gfHigh: settings.gfHighDecimal,
    );
    algorithm.setCompartments(recoveredCompartments);

    final ndl = algorithm.calculateNdl(
      depthMeters: secondDiveDepth,
      fN2: airN2Fraction,
      fHe: 0.0,
    );

    if (ndl >= requiredNdlSeconds) {
      high = mid;
    } else {
      low = mid;
    }
  }

  // Return the higher value to ensure safety
  return high;
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

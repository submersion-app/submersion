import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix.dart';
import 'package:submersion/features/gas_calculators/domain/gas_consumption.dart';
import 'package:submersion/features/gas_calculators/domain/rock_bottom.dart';
import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/mnd_calculator_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MOD Calculator State
// ═══════════════════════════════════════════════════════════════════════════
/// Oxygen percentage for MOD calculation (21-100%)
final modO2Provider = StateProvider<double>((ref) => 32.0);

/// Maximum ppO2 limit (typically 1.2, 1.4, or 1.6 bar)
final modPpO2Provider = StateProvider<double>((ref) => 1.4);

/// Computed Maximum Operating Depth in meters
final modResultProvider = Provider<double>((ref) {
  final o2 = ref.watch(modO2Provider);
  final ppO2 = ref.watch(modPpO2Provider);
  // MOD formula: ((ppO2 / fO2) - 1) × 10
  return ((ppO2 / (o2 / 100)) - 1) * 10;
});

// ═══════════════════════════════════════════════════════════════════════════
// Best Mix Calculator State
// ═══════════════════════════════════════════════════════════════════════════
/// Target depth for best mix calculation (meters)
final bestMixDepthProvider = StateProvider<double>((ref) => 30.0);

/// Maximum ppO2 limit for best mix
final bestMixPpO2Provider = StateProvider<double>((ref) => 1.4);

/// END limit for best mix (meters), initialized from settings.
///
/// Uses ref.read (not ref.watch) so user overrides are not lost when
/// unrelated settings change. Reset via ref.invalidate re-reads settings,
/// mirroring the MND calculator.
final bestMixEndLimitProvider = StateProvider<double>((ref) {
  return ref.read(settingsProvider).endLimit;
});

/// Whether O2 counts as narcotic, initialized from settings.
final bestMixO2NarcoticProvider = StateProvider<bool>((ref) {
  return ref.read(settingsProvider).o2Narcotic;
});

/// Best mix for the target depth, rounded toward safety.
final bestMixResultProvider = Provider<BestMixResult>((ref) {
  return computeBestMix(
    BestMixInputs(
      depthMeters: ref.watch(bestMixDepthProvider),
      ppO2Limit: ref.watch(bestMixPpO2Provider),
      endLimitMeters: ref.watch(bestMixEndLimitProvider),
      o2Narcotic: ref.watch(bestMixO2NarcoticProvider),
    ),
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// Gas Consumption Calculator State
// ═══════════════════════════════════════════════════════════════════════════
/// Average depth for consumption calculation (meters)
final consumptionDepthProvider = StateProvider<double>((ref) => 20.0);

/// Dive duration (minutes)
final consumptionTimeProvider = StateProvider<int>((ref) => 45);

/// Surface Air Consumption rate (L/min at surface)
final consumptionSacProvider = StateProvider<double>((ref) => 15.0);

/// Selected cylinder for consumption planning.
final consumptionTankProvider = StateProvider<TankSpec>(
  (ref) => defaultTankSpec(),
);

/// Gas used over the planned dive, plus what is left in the cylinder.
final consumptionResultProvider = Provider<ConsumptionResult>((ref) {
  return computeConsumption(
    ConsumptionInputs(
      avgDepthMeters: ref.watch(consumptionDepthProvider),
      minutes: ref.watch(consumptionTimeProvider),
      sacLitersPerMin: ref.watch(consumptionSacProvider),
      tank: ref.watch(consumptionTankProvider),
    ),
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// Rock Bottom Calculator State
// ═══════════════════════════════════════════════════════════════════════════
/// Maximum depth for rock bottom calculation (meters)
final rockBottomDepthProvider = StateProvider<double>((ref) => 30.0);

/// Ascent rate (m/min) - typically 9 m/min
final rockBottomAscentRateProvider = StateProvider<double>((ref) => 9.0);

/// Your stressed SAC rate (L/min at surface) - higher than normal due to stress
final rockBottomSacProvider = StateProvider<double>((ref) => 20.0);

/// Buddy's stressed SAC rate (L/min at surface)
final rockBottomBuddySacProvider = StateProvider<double>((ref) => 25.0);

/// Time spent at depth solving the problem before ascending (minutes).
final rockBottomSolveMinutesProvider = StateProvider<double>((ref) => 1.0);

/// Selected cylinder.
///
/// Water capacity and working pressure travel together so reserve pressure
/// cannot be computed against a free-gas figure.
final rockBottomTankProvider = StateProvider<TankSpec>(
  (ref) => defaultTankSpec(),
);

/// Whether to include 3-minute safety stop at 5m
final rockBottomSafetyStopProvider = StateProvider<bool>((ref) => true);

/// Rock bottom result with per-phase breakdown.
final rockBottomResultProvider = Provider<RockBottomResult>((ref) {
  return computeRockBottom(
    RockBottomInputs(
      depthMeters: ref.watch(rockBottomDepthProvider),
      ascentRateMetersPerMin: ref.watch(rockBottomAscentRateProvider),
      diverSacLitersPerMin: ref.watch(rockBottomSacProvider),
      buddySacLitersPerMin: ref.watch(rockBottomBuddySacProvider),
      solveMinutes: ref.watch(rockBottomSolveMinutesProvider),
      includeSafetyStop: ref.watch(rockBottomSafetyStopProvider),
      tank: ref.watch(rockBottomTankProvider),
    ),
  );
});

/// Reset all gas calculator providers to defaults
void resetGasCalculators(WidgetRef ref) {
  // MOD
  ref.read(modO2Provider.notifier).state = 32.0;
  ref.read(modPpO2Provider.notifier).state = 1.4;
  // Best Mix
  ref.read(bestMixDepthProvider.notifier).state = 30.0;
  ref.read(bestMixPpO2Provider.notifier).state = 1.4;
  ref.invalidate(bestMixEndLimitProvider);
  ref.invalidate(bestMixO2NarcoticProvider);
  // Consumption
  ref.read(consumptionDepthProvider.notifier).state = 20.0;
  ref.read(consumptionTimeProvider.notifier).state = 45;
  ref.read(consumptionSacProvider.notifier).state = 15.0;
  ref.read(consumptionTankProvider.notifier).state = defaultTankSpec();
  // Rock Bottom
  ref.read(rockBottomDepthProvider.notifier).state = 30.0;
  ref.read(rockBottomAscentRateProvider.notifier).state = 9.0;
  ref.read(rockBottomSacProvider.notifier).state = 20.0;
  ref.read(rockBottomBuddySacProvider.notifier).state = 25.0;
  ref.read(rockBottomSolveMinutesProvider.notifier).state = 1.0;
  ref.read(rockBottomTankProvider.notifier).state = defaultTankSpec();
  ref.read(rockBottomSafetyStopProvider.notifier).state = true;
  // MND/END
  resetMndCalculator(ref);
}

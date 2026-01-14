import 'package:submersion/core/providers/provider.dart';

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

/// Computed ideal oxygen percentage
final bestMixResultProvider = Provider<double>((ref) {
  final depth = ref.watch(bestMixDepthProvider);
  final ppO2 = ref.watch(bestMixPpO2Provider);
  // Best mix formula: O2% = (ppO2 / ambientPressure) × 100
  final ambientPressure = (depth / 10) + 1;
  return (ppO2 / ambientPressure) * 100;
});

/// Suggested common gas mix based on best mix result
final bestMixSuggestionProvider = Provider<String>((ref) {
  final idealO2 = ref.watch(bestMixResultProvider);
  if (idealO2 >= 99) return 'Oxygen (100%)';
  if (idealO2 >= 48 && idealO2 <= 52) return 'EAN50';
  if (idealO2 >= 38 && idealO2 <= 42) return 'EAN40';
  if (idealO2 >= 34 && idealO2 <= 38) return 'EAN36';
  if (idealO2 >= 30 && idealO2 <= 34) return 'EAN32';
  if (idealO2 >= 19 && idealO2 <= 23) return 'Air';
  return 'Custom mix';
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

/// Tank water capacity (liters)
final consumptionTankSizeProvider = StateProvider<double>((ref) => 12.0);

/// Result record with liters consumed and bar pressure
final consumptionResultProvider =
    Provider<({double liters, double bar, bool exceedsTank})>((ref) {
      final depth = ref.watch(consumptionDepthProvider);
      final time = ref.watch(consumptionTimeProvider);
      final sac = ref.watch(consumptionSacProvider);
      final tankSize = ref.watch(consumptionTankSizeProvider);

      // Gas consumption at depth = SAC × ambient pressure × time
      final avgPressure = (depth / 10) + 1;
      final litersConsumed = sac * avgPressure * time;

      // Convert to bar based on tank size
      // Assuming tank is filled to 200 bar standard
      final barConsumed = litersConsumed / tankSize;

      return (
        liters: litersConsumed,
        bar: barConsumed,
        exceedsTank: barConsumed > 200,
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

/// Tank water capacity (liters)
final rockBottomTankSizeProvider = StateProvider<double>((ref) => 12.0);

/// Whether to include 3-minute safety stop at 5m
final rockBottomSafetyStopProvider = StateProvider<bool>((ref) => true);

/// Rock bottom result with breakdown
final rockBottomResultProvider =
    Provider<
      ({
        double totalLiters,
        double totalBar,
        double ascentTime,
        double ascentGas,
        double safetyStopGas,
      })
    >((ref) {
      final depth = ref.watch(rockBottomDepthProvider);
      final ascentRate = ref.watch(rockBottomAscentRateProvider);
      final sac = ref.watch(rockBottomSacProvider);
      final buddySac = ref.watch(rockBottomBuddySacProvider);
      final tankSize = ref.watch(rockBottomTankSizeProvider);
      final includeSafetyStop = ref.watch(rockBottomSafetyStopProvider);

      // Combined SAC for buddy breathing (both divers on one tank)
      final combinedSac = sac + buddySac;

      // Phase 1: Ascent from depth to 5m (or surface if no safety stop)
      final ascentEndDepth = includeSafetyStop ? 5.0 : 0.0;
      final ascentDistance = depth - ascentEndDepth;
      final ascentTime = ascentDistance / ascentRate;
      final avgAscentDepth = (depth + ascentEndDepth) / 2;
      final avgAscentPressure = (avgAscentDepth / 10) + 1;
      final ascentGas = combinedSac * avgAscentPressure * ascentTime;

      // Phase 2: Safety stop (3 min at 5m) if enabled
      double safetyStopGas = 0;
      if (includeSafetyStop) {
        const safetyStopPressure = 1.5; // ATM at 5m
        const safetyStopTime = 3.0; // minutes
        safetyStopGas = combinedSac * safetyStopPressure * safetyStopTime;
      }

      // Phase 3: Final ascent from 5m to surface (if safety stop was included)
      double finalAscentGas = 0;
      if (includeSafetyStop) {
        const finalAscentTime = 5.0 / 9.0; // 5m at 9m/min ≈ 0.56 min
        const avgFinalPressure = 1.25; // avg between 5m and surface
        finalAscentGas = combinedSac * avgFinalPressure * finalAscentTime;
      }

      final totalLiters = ascentGas + safetyStopGas + finalAscentGas;
      final totalBar = totalLiters / tankSize;

      return (
        totalLiters: totalLiters,
        totalBar: totalBar,
        ascentTime: ascentTime + (includeSafetyStop ? 3.56 : 0),
        ascentGas: ascentGas + finalAscentGas,
        safetyStopGas: safetyStopGas,
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
  // Consumption
  ref.read(consumptionDepthProvider.notifier).state = 20.0;
  ref.read(consumptionTimeProvider.notifier).state = 45;
  ref.read(consumptionSacProvider.notifier).state = 15.0;
  ref.read(consumptionTankSizeProvider.notifier).state = 12.0;
  // Rock Bottom
  ref.read(rockBottomDepthProvider.notifier).state = 30.0;
  ref.read(rockBottomAscentRateProvider.notifier).state = 9.0;
  ref.read(rockBottomSacProvider.notifier).state = 20.0;
  ref.read(rockBottomBuddySacProvider.notifier).state = 25.0;
  ref.read(rockBottomTankSizeProvider.notifier).state = 12.0;
  ref.read(rockBottomSafetyStopProvider.notifier).state = true;
}

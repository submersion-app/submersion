import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Input state: depth in meters
final calcDepthProvider = StateProvider<double>((ref) => 18.0);

/// Input state: bottom time in minutes
final calcTimeProvider = StateProvider<int>((ref) => 30);

/// Input state: O2 percentage (21-100)
final calcO2Provider = StateProvider<double>((ref) => 21.0);

/// Input state: Helium percentage (0-65)
final calcHeProvider = StateProvider<double>((ref) => 0.0);

/// Computed gas mix from current O2/He inputs
final calcGasMixProvider = Provider<GasMix>((ref) {
  final o2 = ref.watch(calcO2Provider);
  final he = ref.watch(calcHeProvider);
  return GasMix(o2: o2, he: he);
});

/// Computed N2 fraction for algorithm (0.0 - 1.0)
final calcN2FractionProvider = Provider<double>((ref) {
  final o2 = ref.watch(calcO2Provider);
  final he = ref.watch(calcHeProvider);
  return (100 - o2 - he) / 100.0;
});

/// Computed He fraction for algorithm (0.0 - 1.0)
final calcHeFractionProvider = Provider<double>((ref) {
  return ref.watch(calcHeProvider) / 100.0;
});

/// ppO2 at current depth
final calcPpO2Provider = Provider<double>((ref) {
  final depth = ref.watch(calcDepthProvider);
  final o2 = ref.watch(calcO2Provider);
  final ambientPressure = (depth / 10) + 1; // bar absolute
  return ambientPressure * (o2 / 100);
});

/// Maximum Operating Depth for current gas at ppO2 1.4
final calcMODProvider = Provider<double>((ref) {
  final gasMix = ref.watch(calcGasMixProvider);
  return gasMix.mod(ppO2: 1.4);
});

/// Equivalent Narcotic Depth at current depth
final calcENDProvider = Provider<double>((ref) {
  final depth = ref.watch(calcDepthProvider);
  final gasMix = ref.watch(calcGasMixProvider);
  return gasMix.end(depth);
});

/// Computed decompression status based on current inputs.
///
/// This creates a fresh BuhlmannAlgorithm instance, simulates the dive
/// segment at the configured depth/time/gas, and returns the resulting
/// deco status with NDL, ceiling, TTS, and tissue loading.
final calcDecoStatusProvider = Provider<DecoStatus>((ref) {
  final depth = ref.watch(calcDepthProvider);
  final timeMinutes = ref.watch(calcTimeProvider);
  final fN2 = ref.watch(calcN2FractionProvider);
  final fHe = ref.watch(calcHeFractionProvider);
  final settings = ref.watch(settingsProvider);

  // Create algorithm with user's GF settings
  final algorithm = BuhlmannAlgorithm(
    gfLow: settings.gfLowDecimal,
    gfHigh: settings.gfHighDecimal,
  );

  // Simulate the dive segment at depth for the given time
  algorithm.calculateSegment(
    depthMeters: depth,
    durationSeconds: timeMinutes * 60,
    fN2: fN2,
    fHe: fHe,
  );

  // Return the deco status after the segment
  return algorithm.getDecoStatus(currentDepth: depth, fN2: fN2, fHe: fHe);
});

/// Gas preset options for quick selection
enum GasPreset {
  air('Air', 21.0, 0.0),
  ean32('EAN32', 32.0, 0.0),
  ean36('EAN36', 36.0, 0.0),
  ean50('EAN50', 50.0, 0.0),
  oxygen('O2', 100.0, 0.0),
  tmx2135('Tx 21/35', 21.0, 35.0),
  tmx1845('Tx 18/45', 18.0, 45.0);

  const GasPreset(this.label, this.o2, this.he);

  final String label;
  final double o2;
  final double he;
}

/// Current gas preset (null if custom values)
final calcGasPresetProvider = Provider<GasPreset?>((ref) {
  final o2 = ref.watch(calcO2Provider);
  final he = ref.watch(calcHeProvider);

  for (final preset in GasPreset.values) {
    if ((o2 - preset.o2).abs() < 0.5 && (he - preset.he).abs() < 0.5) {
      return preset;
    }
  }
  return null; // Custom mix
});

/// Reset calculator to defaults
void resetCalculator(WidgetRef ref) {
  ref.read(calcDepthProvider.notifier).state = 18.0;
  ref.read(calcTimeProvider.notifier).state = 30;
  ref.read(calcO2Provider.notifier).state = 21.0;
  ref.read(calcHeProvider.notifier).state = 0.0;
}

/// Apply a gas preset
void applyGasPreset(WidgetRef ref, GasPreset preset) {
  ref.read(calcO2Provider.notifier).state = preset.o2;
  ref.read(calcHeProvider.notifier).state = preset.he;
}

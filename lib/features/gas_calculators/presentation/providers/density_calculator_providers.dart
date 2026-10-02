import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Gas Density Calculator State
// ═══════════════════════════════════════════════════════════════════════════

const double _defaultO2 = 21.0;
const double _defaultHe = 35.0;
const double _defaultDepth = 50.0;

/// O2% of the breathing gas (OC) or diluent (CCR).
final densityO2Provider = StateProvider<double>((ref) => _defaultO2);

/// He% of the breathing gas or diluent (clamped to 100 - O2% by the domain).
final densityHeProvider = StateProvider<double>((ref) => _defaultHe);

/// Target depth in meters.
final densityDepthProvider = StateProvider<double>((ref) => _defaultDepth);

/// Whether the gas is breathed on a CCR loop rather than open circuit.
final densityCcrProvider = StateProvider<bool>((ref) => false);

/// CCR setpoint in bar. Kept while OC is selected so switching back to CCR
/// restores it. Seeded from the diver's own CCR setpoint high, not a fixed
/// literal, since that is the setpoint actually used for the working/bottom
/// phase this calculator defaults to. Watched rather than read, so the seed
/// follows settings hydration, a diver switch, or a Settings edit instead of
/// latching whatever was loaded the first time the calculator opened.
final densitySetpointProvider = StateProvider<double>(
  (ref) => ref.watch(ccrSetpointHighProvider),
);

/// Gas temperature. Defaults to the colder, conservative option.
final densityTemperatureProvider = StateProvider<GasDensityTemperature>(
  (ref) => GasDensityTemperature.zeroC,
);

/// Water type for the depth-to-pressure conversion: salt or fresh.
final densityWaterTypeProvider = StateProvider<WaterType>(
  (ref) => WaterType.salt,
);

/// Computed density result.
final densityResultProvider = Provider<GasDensityResult>((ref) {
  final isCcr = ref.watch(densityCcrProvider);
  return computeGasDensity(
    GasDensityInputs(
      o2Percent: ref.watch(densityO2Provider),
      hePercent: ref.watch(densityHeProvider),
      depthMeters: ref.watch(densityDepthProvider),
      setpointBar: isCcr ? ref.watch(densitySetpointProvider) : null,
      temperature: ref.watch(densityTemperatureProvider),
      waterType: ref.watch(densityWaterTypeProvider),
    ),
  );
});

/// Reset the gas density calculator to its defaults.
void resetDensityCalculator(WidgetRef ref) {
  ref.read(densityO2Provider.notifier).state = _defaultO2;
  ref.read(densityHeProvider.notifier).state = _defaultHe;
  ref.read(densityDepthProvider.notifier).state = _defaultDepth;
  ref.read(densityCcrProvider.notifier).state = false;
  ref.read(densitySetpointProvider.notifier).state = ref.read(
    ccrSetpointHighProvider,
  );
  ref.read(densityTemperatureProvider.notifier).state =
      GasDensityTemperature.zeroC;
  ref.read(densityWaterTypeProvider.notifier).state = WaterType.salt;
}

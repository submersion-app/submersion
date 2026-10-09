import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/icd_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ICD Calculator State (issue #3121)
// ═══════════════════════════════════════════════════════════════════════════

/// O2% of Gas A, the gas breathed before the switch.
final icdO2AProvider = StateProvider<double>((ref) => 18.0);

/// He% of Gas A.
final icdHeAProvider = StateProvider<double>((ref) => 45.0);

/// O2% of Gas B, the gas switched to.
final icdO2BProvider = StateProvider<double>((ref) => 32.0);

/// He% of Gas B.
final icdHeBProvider = StateProvider<double>((ref) => 0.0);

/// Whether the assessment is shown at all, initialized from settings.
/// Uses ref.read (not ref.watch) so a user override is not lost when
/// unrelated settings change. Reset via ref.invalidate re-reads settings.
final icdWarningsEnabledProvider = StateProvider<bool>((ref) {
  final settings = ref.read(settingsProvider);
  return settings.icdWarningsEnabled;
});

/// Computed gas inputs from the O2/He fields, each He clamped against its
/// own O2 so the pair can never claim more than 100%.
final icdInputsProvider = Provider<IcdInputs>((ref) {
  final o2A = ref.watch(icdO2AProvider);
  final heA = ref.watch(icdHeAProvider);
  final o2B = ref.watch(icdO2BProvider);
  final heB = ref.watch(icdHeBProvider);
  return IcdInputs(
    gasA: IcdGasInputs(
      o2Percent: o2A,
      hePercent: heA.clamp(0, 100 - o2A).toDouble(),
    ),
    gasB: IcdGasInputs(
      o2Percent: o2B,
      hePercent: heB.clamp(0, 100 - o2B).toDouble(),
    ),
  );
});

/// Computed ICD assessment for the current Gas A / Gas B pair.
final icdResultProvider = Provider<IcdResult>((ref) {
  return computeIcd(ref.watch(icdInputsProvider));
});

/// Suggested He% fixes, one per gas kept unchanged. Shown beside the
/// assessment whenever it is not [IcdSeverity.ok].
final icdFixSuggestionsProvider = Provider<IcdFixSuggestions>((ref) {
  return computeIcdFixSuggestions(ref.watch(icdInputsProvider));
});

/// Reset the ICD calculator providers to defaults.
void resetIcdCalculator(WidgetRef ref) {
  ref.read(icdO2AProvider.notifier).state = 18.0;
  ref.read(icdHeAProvider.notifier).state = 45.0;
  ref.read(icdO2BProvider.notifier).state = 32.0;
  ref.read(icdHeBProvider.notifier).state = 0.0;
  // icdWarningsEnabled resets to the settings value automatically.
  ref.invalidate(icdWarningsEnabledProvider);
}

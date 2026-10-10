import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
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

/// Whether the assessment is shown at all. The calculator has no control of
/// its own for this; it only ever reflects the Settings > Decompression
/// toggle, so it is a plain derived provider rather than a `StateProvider`.
/// It always follows the persisted setting, including a later change to it
/// or the async settings load finishing after this provider was created.
final icdWarningsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.icdWarningsEnabled));
});

/// Computed gas inputs from the O2/He fields, each He clamped against its
/// own O2 so the pair can never claim more than 100%.
final icdInputsProvider = Provider<IcdInputs>((ref) {
  final o2A = ref.watch(icdO2AProvider);
  final heA = ref.watch(icdHeAProvider);
  final o2B = ref.watch(icdO2BProvider);
  final heB = ref.watch(icdHeBProvider);
  return IcdInputs(
    gasA: GasMix(o2: o2A, he: heA.clamp(0, 100 - o2A).toDouble()),
    gasB: GasMix(o2: o2B, he: heB.clamp(0, 100 - o2B).toDouble()),
  );
});

/// Computed ICD assessment for the current Gas A / Gas B pair.
final icdResultProvider = Provider<IcdResult>((ref) {
  return computeIcd(ref.watch(icdInputsProvider));
});

/// Suggested He% fixes, one per gas kept unchanged. Shown beside the
/// assessment only for an [IcdSeverity.violation]: a caution already
/// complies with the rule of fifths.
final icdFixSuggestionsProvider = Provider<IcdFixSuggestions>((ref) {
  return computeIcdFixSuggestions(ref.watch(icdInputsProvider));
});

/// Reset the ICD calculator providers to defaults. Invalidating rebuilds each
/// from its own initial value, so the defaults live in one place.
void resetIcdCalculator(WidgetRef ref) {
  ref.invalidate(icdO2AProvider);
  ref.invalidate(icdHeAProvider);
  ref.invalidate(icdO2BProvider);
  ref.invalidate(icdHeBProvider);
  // icdWarningsEnabled always reflects the settings value; nothing to reset.
}

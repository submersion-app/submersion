import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MND/END Calculator State
// ═══════════════════════════════════════════════════════════════════════════

/// O2% for MND calculation (21-100%)
final mndO2Provider = StateProvider<double>((ref) => 21.0);

/// He% for MND calculation (0 to 100 - O2%, clamped in mndGasMixProvider)
final mndHeProvider = StateProvider<double>((ref) => 35.0);

/// END limit for MND calculation (meters), initialized from settings.
/// Uses ref.read (not ref.watch) so user overrides are not lost when
/// unrelated settings change. Reset via ref.invalidate re-reads settings.
final mndEndLimitProvider = StateProvider<double>((ref) {
  final settings = ref.read(settingsProvider);
  return settings.endLimit;
});

/// Whether O2 is narcotic, initialized from settings.
/// Uses ref.read (not ref.watch) so user overrides are not lost when
/// unrelated settings change. Reset via ref.invalidate re-reads settings.
final mndO2NarcoticProvider = StateProvider<bool>((ref) {
  final settings = ref.read(settingsProvider);
  return settings.o2Narcotic;
});

/// Computed gas mix from O2/He inputs
final mndGasMixProvider = Provider<GasMix>((ref) {
  final o2 = ref.watch(mndO2Provider);
  final he = ref.watch(mndHeProvider);
  return GasMix(o2: o2, he: he.clamp(0, 100 - o2));
});

/// Computed MND result in meters
final mndResultProvider = Provider<double>((ref) {
  final gasMix = ref.watch(mndGasMixProvider);
  final endLimit = ref.watch(mndEndLimitProvider);
  final o2Narcotic = ref.watch(mndO2NarcoticProvider);
  return gasMix.mnd(endLimit: endLimit, o2Narcotic: o2Narcotic);
});

/// Depth input for END-at-depth calculation (meters)
final mndDepthProvider = StateProvider<double>((ref) => 40.0);

/// Computed END at the given depth
final mndEndAtDepthProvider = Provider<double>((ref) {
  final gasMix = ref.watch(mndGasMixProvider);
  final depth = ref.watch(mndDepthProvider);
  final o2Narcotic = ref.watch(mndO2NarcoticProvider);
  return gasMix.end(depth, o2Narcotic: o2Narcotic);
});

/// Reset MND calculator providers to defaults
void resetMndCalculator(WidgetRef ref) {
  ref.read(mndO2Provider.notifier).state = 21.0;
  ref.read(mndHeProvider.notifier).state = 35.0;
  ref.read(mndDepthProvider.notifier).state = 40.0;
  // endLimit and o2Narcotic reset to settings values automatically
  ref.invalidate(mndEndLimitProvider);
  ref.invalidate(mndO2NarcoticProvider);
}

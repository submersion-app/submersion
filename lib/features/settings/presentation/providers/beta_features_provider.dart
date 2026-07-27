import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _kBetaFeaturesKey = 'beta_features_enabled';

/// Notifier for the "Enable beta features" toggle.
///
/// Device-local by design: persisted to SharedPreferences so the choice
/// survives restarts but never syncs to other devices. Beta gating hides
/// UI surfaces only (see lib/core/constants/feature_flags.dart for the
/// policy); services, providers, and schema stay intact.
class BetaFeaturesNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;

  BetaFeaturesNotifier(this._prefs)
    : super(_prefs.getBool(_kBetaFeaturesKey) ?? false);

  Future<void> setEnabled(bool value) async {
    state = value;
    await _prefs.setBool(_kBetaFeaturesKey, value);
  }
}

/// Whether beta features are enabled on this device.
final betaFeaturesEnabledProvider =
    StateNotifierProvider<BetaFeaturesNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BetaFeaturesNotifier(prefs);
    });

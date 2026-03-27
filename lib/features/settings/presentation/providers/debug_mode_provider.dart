import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _kDebugModeKey = 'debug_mode_enabled';

/// Notifier that manages the debug mode toggle state.
/// Persists to SharedPreferences so debug mode survives app restarts.
class DebugModeNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;

  DebugModeNotifier(this._prefs)
    : super(_prefs.getBool(_kDebugModeKey) ?? false);

  Future<void> enable() async {
    state = true;
    await _prefs.setBool(_kDebugModeKey, true);
  }

  Future<void> disable() async {
    state = false;
    await _prefs.setBool(_kDebugModeKey, false);
  }
}

/// Provider for the debug mode state.
final debugModeProvider = StateNotifierProvider<DebugModeNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DebugModeNotifier(prefs);
});

import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _kVisibilityInputModeKey = 'dive_edit_visibility_input_mode';

/// The visibility input a new dive's form opens with: the mode of the last
/// save that carried a new visibility value (issue #3226). A per-device
/// convenience, not diver data, so it lives in SharedPreferences and does
/// not sync. Starts at Precise, the form's behaviour before ranges existed.
class VisibilityInputModeNotifier extends StateNotifier<VisibilityInputMode> {
  VisibilityInputModeNotifier(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static VisibilityInputMode _read(SharedPreferences prefs) =>
      VisibilityInputMode.values.asNameMap()[prefs.getString(
        _kVisibilityInputModeKey,
      )] ??
      VisibilityInputMode.precise;

  Future<void> remember(VisibilityInputMode mode) async {
    state = mode;
    await _prefs.setString(_kVisibilityInputModeKey, mode.name);
  }
}

final visibilityInputModeProvider =
    StateNotifierProvider<VisibilityInputModeNotifier, VisibilityInputMode>(
      (ref) =>
          VisibilityInputModeNotifier(ref.watch(sharedPreferencesProvider)),
    );

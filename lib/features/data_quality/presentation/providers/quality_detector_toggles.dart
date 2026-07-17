import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/data_quality/domain/detectors/quality_detector_toggles.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

export 'package:submersion/features/data_quality/domain/detectors/quality_detector_toggles.dart';

class QualityDetectorTogglesNotifier extends StateNotifier<Set<String>> {
  QualityDetectorTogglesNotifier(this._prefs)
    : super(_prefs.getStringList(_key)?.toSet() ?? <String>{}) {
    QualityDetectorToggles.disabled = state;
  }

  final SharedPreferences _prefs;
  static const _key = 'quality_disabled_detectors';

  Future<void> setEnabled(String detectorId, bool enabled) async {
    final next = Set<String>.of(state);
    if (enabled) {
      next.remove(detectorId);
    } else {
      next.add(detectorId);
    }
    state = next;
    QualityDetectorToggles.disabled = next;
    await _prefs.setStringList(_key, next.toList());
  }
}

final qualityDetectorTogglesProvider =
    StateNotifierProvider<QualityDetectorTogglesNotifier, Set<String>>(
      (ref) =>
          QualityDetectorTogglesNotifier(ref.watch(sharedPreferencesProvider)),
    );

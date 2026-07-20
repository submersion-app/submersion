import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/data_quality/presentation/providers/quality_detector_toggles.dart';

void main() {
  tearDown(() => QualityDetectorToggles.disabled = <String>{});

  test('disabling persists and mirrors to the static set', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = QualityDetectorTogglesNotifier(prefs);
    await notifier.setEnabled('impossible_rate', false);
    expect(notifier.state, contains('impossible_rate'));
    expect(QualityDetectorToggles.disabled, contains('impossible_rate'));
    expect(
      prefs.getStringList('quality_disabled_detectors'),
      contains('impossible_rate'),
    );
    await notifier.setEnabled('impossible_rate', true);
    expect(QualityDetectorToggles.disabled, isNot(contains('impossible_rate')));
  });

  test('hydrateFromPrefs loads persisted toggles without building the '
      'provider (so scans honor them before settings is opened)', () async {
    SharedPreferences.setMockInitialValues({
      'quality_disabled_detectors': ['gas_mod', 'temp_anomaly'],
    });
    final prefs = await SharedPreferences.getInstance();

    // No notifier/provider constructed -- mirrors a fresh launch where the
    // settings page hasn't been opened yet.
    QualityDetectorTogglesNotifier.hydrateFromPrefs(prefs);

    expect(QualityDetectorToggles.disabled, {'gas_mod', 'temp_anomaly'});
  });

  test('hydrateFromPrefs with no saved toggles yields an empty set', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    QualityDetectorToggles.disabled = {'stale'};
    QualityDetectorTogglesNotifier.hydrateFromPrefs(prefs);
    expect(QualityDetectorToggles.disabled, isEmpty);
  });
}

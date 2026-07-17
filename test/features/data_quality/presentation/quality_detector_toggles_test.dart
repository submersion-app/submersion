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
}

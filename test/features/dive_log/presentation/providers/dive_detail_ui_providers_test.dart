import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';

void main() {
  test('CollapsibleSectionState defaults surfaceGps to expanded', () {
    const s = CollapsibleSectionState();
    expect(s.surfaceGpsExpanded, true);
  });

  test('copyWith updates surfaceGpsExpanded', () {
    const s = CollapsibleSectionState();
    expect(s.copyWith(surfaceGpsExpanded: false).surfaceGpsExpanded, false);
  });

  test('copyWith without surfaceGpsExpanded preserves current value', () {
    const s = CollapsibleSectionState(surfaceGpsExpanded: false);
    // Omitting surfaceGpsExpanded falls through to this.surfaceGpsExpanded.
    expect(s.copyWith(decoExpanded: true).surfaceGpsExpanded, false);
  });

  test('setSurfaceGpsExpanded updates state and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = CollapsibleSectionNotifier(prefs);
    expect(notifier.state.surfaceGpsExpanded, true);

    await notifier.setSurfaceGpsExpanded(false);

    expect(notifier.state.surfaceGpsExpanded, false);
    expect(prefs.getBool(DiveDetailUiKeys.surfaceGpsSectionExpanded), false);
  });

  test('CollapsibleSectionNotifier hydrates surfaceGps from prefs', () async {
    SharedPreferences.setMockInitialValues({
      DiveDetailUiKeys.surfaceGpsSectionExpanded: false,
    });
    final prefs = await SharedPreferences.getInstance();
    final notifier = CollapsibleSectionNotifier(prefs);

    expect(notifier.state.surfaceGpsExpanded, false);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';

void main() {
  test('CollapsibleSectionState defaults surfaceGps to collapsed', () {
    const s = CollapsibleSectionState();
    expect(s.surfaceGpsExpanded, false);
  });

  test('copyWith updates surfaceGpsExpanded', () {
    const s = CollapsibleSectionState();
    expect(s.copyWith(surfaceGpsExpanded: true).surfaceGpsExpanded, true);
  });

  test('copyWith without surfaceGpsExpanded preserves current value', () {
    const s = CollapsibleSectionState(surfaceGpsExpanded: true);
    // Omitting surfaceGpsExpanded falls through to this.surfaceGpsExpanded.
    expect(s.copyWith(decoExpanded: true).surfaceGpsExpanded, true);
  });

  test('setSurfaceGpsExpanded updates state and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = CollapsibleSectionNotifier(prefs);
    expect(notifier.state.surfaceGpsExpanded, false);

    await notifier.setSurfaceGpsExpanded(true);

    expect(notifier.state.surfaceGpsExpanded, true);
    expect(prefs.getBool(DiveDetailUiKeys.surfaceGpsSectionExpanded), true);
  });

  test('CollapsibleSectionNotifier hydrates surfaceGps from prefs', () async {
    SharedPreferences.setMockInitialValues({
      DiveDetailUiKeys.surfaceGpsSectionExpanded: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final notifier = CollapsibleSectionNotifier(prefs);

    expect(notifier.state.surfaceGpsExpanded, true);
  });
}

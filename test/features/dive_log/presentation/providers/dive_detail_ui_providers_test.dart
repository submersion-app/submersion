import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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

  group('sacSegmentsLaneProvider', () {
    ProviderContainer containerFor(GasConsumptionDisplay display) {
      final container = ProviderContainer(
        overrides: [gasConsumptionDisplayProvider.overrideWithValue(display)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('follows the preference when there is no override', () {
      expect(
        containerFor(GasConsumptionDisplay.rmv).read(sacSegmentsLaneProvider),
        GasConsumptionLane.rmv,
      );
      expect(
        containerFor(GasConsumptionDisplay.both).read(sacSegmentsLaneProvider),
        GasConsumptionLane.sac,
      );
    });

    test('honors an override the preference allows', () {
      final container = containerFor(GasConsumptionDisplay.both);
      container.read(sacSegmentsLaneOverrideProvider.notifier).state =
          GasConsumptionLane.rmv;
      expect(container.read(sacSegmentsLaneProvider), GasConsumptionLane.rmv);
    });

    test('ignores an override the preference forbids', () {
      // SAC-only mode has no chip; a stale override from an earlier session
      // state must not resurrect the other lane.
      final container = containerFor(GasConsumptionDisplay.sac);
      container.read(sacSegmentsLaneOverrideProvider.notifier).state =
          GasConsumptionLane.rmv;
      expect(container.read(sacSegmentsLaneProvider), GasConsumptionLane.sac);
    });
  });
}

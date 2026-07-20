import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _gas = GasMix(o2: 21);

PlanSegment _bottom(String id, int order) => PlanSegment(
  id: id,
  type: SegmentType.bottom,
  startDepth: 20,
  endDepth: 20,
  durationSeconds: 600,
  tankId: 't1',
  gasMix: _gas,
  order: order,
);

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> makeContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
    );
  }

  test(
    'replaceSegment swaps one segment for many and renumbers orders',
    () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(divePlanNotifierProvider.notifier);
      notifier.addSegment(_bottom('a', 0));
      notifier.addSegment(_bottom('b', 1));
      notifier.addSegment(_bottom('c', 2));
      notifier.markSaved();

      notifier.replaceSegment('b', [_bottom('b1', 0), _bottom('b2', 0)]);

      final segments = container.read(divePlanNotifierProvider).segments;
      expect(segments.map((s) => s.id), ['a', 'b1', 'b2', 'c']);
      expect(segments.map((s) => s.order), [0, 1, 2, 3]);
      expect(container.read(divePlanNotifierProvider).isDirty, isTrue);
    },
  );

  test('replaceSegment with unknown id is a no-op', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addSegment(_bottom('a', 0));

    notifier.replaceSegment('missing', [_bottom('x', 0)]);

    expect(container.read(divePlanNotifierProvider).segments.map((s) => s.id), [
      'a',
    ]);
  });
}

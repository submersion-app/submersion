import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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

  final nine = DateTime.utc(2026, 10, 27, 9);

  Future<ProviderContainer> makeContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 25);
    return container;
  }

  DivePlanState editor(ProviderContainer c) => c.read(divePlanNotifierProvider);
  PlanSeriesNotifier series(ProviderContainer c) =>
      c.read(planSeriesNotifierProvider.notifier);

  /// When Dive A ends, as clock digits.
  DateTime firstEnd(ProviderContainer c) {
    final a = c.read(planSeriesResultsProvider).first;
    return asWallClockUtc(
      fromWallClockUtc(
        a.state.startDateTime!,
      ).add(Duration(seconds: a.outcome.runtimeSeconds)),
    );
  }

  test('a start on Dive A gives the next dive its start', () async {
    final c = await makeContainer();
    series(c).setSelectedStart(nine);
    expect(editor(c).startDateTime, nine);

    series(c).addDive();

    expect(editor(c).startDateTime, firstEnd(c).add(const Duration(hours: 1)));
  });

  test('a start on a later dive sets its interval', () async {
    final c = await makeContainer();
    series(c).setSelectedStart(nine);
    series(c).addDive();
    final start = firstEnd(c).add(const Duration(hours: 2));

    series(c).setSelectedStart(start);

    expect(editor(c).startDateTime, start);
    expect(editor(c).surfaceInterval, const Duration(hours: 2));
    expect(c.read(planSeriesNotifierProvider).selected.fixedStart, isTrue);
  });

  test('typing an interval after a start lets the interval lead', () async {
    final c = await makeContainer();
    series(c).setSelectedStart(nine);
    series(c).addDive();
    series(c).setSelectedStart(firstEnd(c).add(const Duration(hours: 2)));

    c
        .read(divePlanNotifierProvider.notifier)
        .setSurfaceInterval(const Duration(minutes: 45));

    expect(c.read(planSeriesNotifierProvider).selected.fixedStart, isFalse);
    expect(
      editor(c).startDateTime,
      firstEnd(c).add(const Duration(minutes: 45)),
    );
  });

  test('a fixed start survives moving away and back', () async {
    final c = await makeContainer();
    series(c).setSelectedStart(nine);
    series(c).addDive();
    final start = firstEnd(c).add(const Duration(hours: 3));
    series(c).setSelectedStart(start);

    series(c).select(0);
    series(c).select(1);

    expect(editor(c).startDateTime, start);
    expect(editor(c).surfaceInterval, const Duration(hours: 3));
  });

  test('clearing a later dive\'s start lets its interval lead', () async {
    final c = await makeContainer();
    series(c).setSelectedStart(nine);
    series(c).addDive();
    series(c).setSelectedStart(firstEnd(c).add(const Duration(hours: 3)));

    series(c).setSelectedStart(null);

    expect(c.read(planSeriesNotifierProvider).selected.fixedStart, isFalse);
    // Measured from Dive A again, after the interval it was left with.
    expect(editor(c).startDateTime, firstEnd(c).add(const Duration(hours: 3)));
  });
}

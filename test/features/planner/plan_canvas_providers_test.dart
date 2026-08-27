import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  // Null means "leave at the AppSettings default", so these fixtures cannot
  // drift away from the real defaults.
  _TestSettingsNotifier({int? gfLow, int? gfHigh})
    : super(const AppSettings().copyWith(gfLow: gfLow, gfHigh: gfHigh));

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container({int? gfLow, int? gfHigh}) {
  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith(
        (ref) => _TestSettingsNotifier(gfLow: gfLow, gfHigh: gfHigh),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

int _totalStopSeconds(ProviderContainer container) => container
    .read(planOutcomeProvider)
    .stops
    .fold(0, (sum, stop) => sum + stop.durationSeconds);

void main() {
  test('scrub provider defaults to null', () {
    final container = _container();
    expect(container.read(scrubTimeProvider), isNull);
  });

  test('simple plan produces a surface-to-surface profile', () {
    final container = _container();
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30.0, bottomTimeMinutes: 10);
    final series = container.read(planCanvasSeriesProvider);

    expect(series.isEmpty, isFalse);
    expect(series.profile.first.timeSeconds, 0);
    expect(series.profile.first.depth, 0);
    expect(series.profile.last.depth, 0);
    // Time is monotonically non-decreasing.
    for (var i = 1; i < series.profile.length; i++) {
      expect(
        series.profile[i].timeSeconds,
        greaterThanOrEqualTo(series.profile[i - 1].timeSeconds),
      );
    }
    expect(series.maxDepth, 30.0);
    expect(series.depthAt(0), 0);
  });

  test('new plan adopts the diver gradient factor settings', () {
    final container = _container(gfLow: 35, gfHigh: 75);
    final state = container.read(divePlanNotifierProvider);

    expect(state.gfLow, 35);
    expect(state.gfHigh, 75);
  });

  test('conservative gradient factors lengthen the computed deco', () {
    final conservative = _container(gfLow: 20, gfHigh: 55);
    conservative
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 45.0, bottomTimeMinutes: 25);

    final liberal = _container(gfLow: 90, gfHigh: 95);
    liberal
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 45.0, bottomTimeMinutes: 25);

    expect(
      _totalStopSeconds(conservative),
      greaterThan(_totalStopSeconds(liberal)),
    );
  });

  test('deco plan appends stop flats and stop markers', () {
    final container = _container();
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addSimplePlan(maxDepth: 45.0, bottomTimeMinutes: 25);
    final outcome = container.read(planOutcomeProvider);
    final series = container.read(planCanvasSeriesProvider);

    expect(outcome.stops, isNotEmpty);
    expect(series.stopLabels, hasLength(outcome.stops.length));
    // Each stop contributes a flat: two consecutive points at equal depth.
    for (final stop in outcome.stops) {
      final flat = series.profile.where(
        (p) =>
            p.depth == stop.depthMeters &&
            p.timeSeconds >= stop.arrivalRuntimeSeconds,
      );
      expect(
        flat.length,
        greaterThanOrEqualTo(2),
        reason: 'stop ${stop.depthMeters}',
      );
    }
    expect(series.ceiling, isNotEmpty);
  });

  test('multi-gas plan yields gas-switch markers at deco depths', () {
    final container = _container();
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addSimplePlan(maxDepth: 45.0, bottomTimeMinutes: 25);
    notifier.addTank(
      const DiveTank(
        id: 'ean50',
        name: 'EAN50',
        volume: 11.1,
        startPressure: 207,
        gasMix: GasMix(o2: 50),
        role: TankRole.deco,
      ),
    );
    final series = container.read(planCanvasSeriesProvider);

    expect(series.gasSwitches, isNotEmpty);
    for (final marker in series.gasSwitches) {
      expect(marker.depth, lessThanOrEqualTo(22.0));
      expect(marker.label, isNotEmpty);
    }
  });

  test('planEngineConfig reflects settings defaults', () {
    final container = _container();
    final config = container.read(planEngineConfigProvider);
    expect(config.ppO2Working, 1.4);
    expect(config.ppO2Deco, 1.6);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier({PressureUnit pressureUnit = PressureUnit.bar})
    : super(AppSettings(pressureUnit: pressureUnit));

  void updatePressureUnitForTest(PressureUnit unit) {
    state = AppSettings(pressureUnit: unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('divePlanNotifierProvider', () {
    test('uses ~34 bar reserve when pressure unit is psi', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(pressureUnit: PressureUnit.psi),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(divePlanNotifierProvider);
      // 500 psi ≈ 34.47 bar
      expect(state.reservePressure, closeTo(34.47, 0.5));
    });

    test('uses 50 bar reserve when pressure unit is bar', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(divePlanNotifierProvider);
      expect(state.reservePressure, DivePlanState.kDefaultReservePressureBar);
    });

    test('toDive sets runtime from segment durations', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(divePlanNotifierProvider.notifier);

      // Load a plan with a segment so totalTime > 0
      final defaultState = container.read(divePlanNotifierProvider);
      final tank = defaultState.tanks.first;
      notifier.loadPlan(
        defaultState.copyWith(
          segments: [
            PlanSegment(
              id: 'seg-1',
              type: SegmentType.bottom,
              startDepth: 20,
              endDepth: 20,
              durationSeconds: 30 * 60,
              tankId: tank.id,
              gasMix: tank.gasMix,
              order: 0,
            ),
          ],
        ),
      );

      final dive = notifier.toDive();

      expect(dive.runtime, isNotNull);
      expect(dive.runtime!.inSeconds, 30 * 60);
      expect(dive.isPlanned, isTrue);
    });

    test(
      'newPlan resets reserve to 500 psi (~34 bar) when pressure unit is psi',
      () {
        final settingsNotifier = _TestSettingsNotifier();
        final container = ProviderContainer(
          overrides: [settingsProvider.overrideWith((ref) => settingsNotifier)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(divePlanNotifierProvider.notifier);
        expect(
          container.read(divePlanNotifierProvider).reservePressure,
          DivePlanState.kDefaultReservePressureBar,
        );

        settingsNotifier.updatePressureUnitForTest(PressureUnit.psi);
        notifier.newPlan();

        final state = container.read(divePlanNotifierProvider);
        expect(state.reservePressure, closeTo(34.47, 0.5));
      },
    );

    test('newPlan uses reservePressure fallback when no callback provided', () {
      final notifier = DivePlanNotifier(
        PlanCalculatorService(),
        reservePressure: 40,
      );
      addTearDown(notifier.dispose);

      notifier.newPlan();
      expect(notifier.state.reservePressure, 40);
    });
  });
}

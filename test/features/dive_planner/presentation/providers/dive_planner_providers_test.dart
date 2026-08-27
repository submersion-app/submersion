import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  // Null means "leave at the AppSettings default", so these fixtures cannot
  // drift away from the real defaults.
  _TestSettingsNotifier({PressureUnit? pressureUnit, int? gfLow, int? gfHigh})
    : super(
        const AppSettings().copyWith(
          pressureUnit: pressureUnit,
          gfLow: gfLow,
          gfHigh: gfHigh,
        ),
      );

  void updatePressureUnitForTest(PressureUnit unit) {
    state = state.copyWith(pressureUnit: unit);
  }

  void updateGradientFactorsForTest(int low, int high) {
    state = state.copyWith(gfLow: low, gfHigh: high);
  }

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

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

    test(
      'initial plan seeds gradient factors from the diver deco settings',
      () {
        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => _TestSettingsNotifier(gfLow: 35, gfHigh: 75),
            ),
          ],
        );
        addTearDown(container.dispose);

        final state = container.read(divePlanNotifierProvider);
        expect(state.gfLow, 35);
        expect(state.gfHigh, 75);
      },
    );

    test('newPlan re-reads gradient factors from the diver deco settings', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(gfLow: 35, gfHigh: 75),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(divePlanNotifierProvider.notifier);
      notifier.updateGradientFactors(10, 20);
      expect(container.read(divePlanNotifierProvider).gfLow, 10);

      notifier.newPlan();

      final state = container.read(divePlanNotifierProvider);
      expect(state.gfLow, 35);
      expect(state.gfHigh, 75);
    });

    test('changing deco settings does not discard the in-progress plan', () {
      final settingsNotifier = _TestSettingsNotifier(gfLow: 50, gfHigh: 85);
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith((ref) => settingsNotifier)],
      );
      addTearDown(container.dispose);

      container
          .read(divePlanNotifierProvider.notifier)
          .addSimplePlan(maxDepth: 30.0, bottomTimeMinutes: 20);
      final planned = container.read(divePlanNotifierProvider);
      expect(planned.segments, isNotEmpty);

      settingsNotifier.updateGradientFactorsForTest(20, 60);

      final state = container.read(divePlanNotifierProvider);
      expect(state.id, planned.id);
      expect(state.segments, planned.segments);
      // The plan keeps the gradient factors it was built with; settings seed
      // new plans, they do not retroactively rewrite an open one.
      expect(state.gfLow, 50);
      expect(state.gfHigh, 85);
    });

    test('an untouched plan follows later gradient factor settings', () {
      final settingsNotifier = _TestSettingsNotifier(gfLow: 50, gfHigh: 85);
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith((ref) => settingsNotifier)],
      );
      addTearDown(container.dispose);

      expect(container.read(divePlanNotifierProvider).gfLow, 50);

      // Settings hydrate from the database after this provider is first read.
      settingsNotifier.updateGradientFactorsForTest(20, 60);

      final state = container.read(divePlanNotifierProvider);
      expect(state.gfLow, 20);
      expect(state.gfHigh, 60);
      // Adopting a setting is not a diver edit, so it must not arm Save.
      expect(state.isDirty, isFalse);
    });

    test('a hand-tuned plan ignores later gradient factor settings', () {
      final settingsNotifier = _TestSettingsNotifier(gfLow: 50, gfHigh: 85);
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith((ref) => settingsNotifier)],
      );
      addTearDown(container.dispose);

      container
          .read(divePlanNotifierProvider.notifier)
          .updateGradientFactors(10, 20);

      settingsNotifier.updateGradientFactorsForTest(20, 60);

      final state = container.read(divePlanNotifierProvider);
      expect(state.gfLow, 10);
      expect(state.gfHigh, 20);
    });

    test('plan results follow the plan gradient factors, not the settings', () {
      // Settings stay liberal throughout; only the plan's own factors move.
      int ttsForPlanFactors(int low, int high) {
        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => _TestSettingsNotifier(gfLow: 90, gfHigh: 95),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(divePlanNotifierProvider.notifier);
        notifier.addSimplePlan(maxDepth: 45.0, bottomTimeMinutes: 25);
        notifier.updateGradientFactors(low, high);
        return container.read(planResultsProvider).ttsAtBottom;
      }

      // planIsValidProvider gates convert-to-dive off these results, so they
      // have to describe the plan the diver is actually looking at.
      expect(ttsForPlanFactors(20, 55), greaterThan(ttsForPlanFactors(90, 95)));
    });

    test('newPlan uses gradient factor fallback when no callback provided', () {
      final notifier = DivePlanNotifier(PlanCalculatorService());
      addTearDown(notifier.dispose);

      notifier.newPlan();

      expect(notifier.state.gfLow, 30);
      expect(notifier.state.gfHigh, 70);
    });

    test('newPlan uses reservePressure fallback when no callback provided', () {
      final notifier = DivePlanNotifier(
        PlanCalculatorService(),
        reservePressure: 40,
      );
      addTearDown(notifier.dispose);

      notifier.newPlan();
      expect(notifier.state.reservePressure, 40);
    });

    test('setFollowedDive seeds context and clearFollowedDive drops it', () {
      final notifier = DivePlanNotifier(PlanCalculatorService());
      addTearDown(notifier.dispose);

      final compartments = [
        const TissueCompartment(
          compartmentNumber: 1,
          halfTimeN2: 5.0,
          halfTimeHe: 1.88,
          mValueAN2: 1.1696,
          mValueBN2: 0.5578,
          mValueAHe: 1.6189,
          mValueBHe: 0.4770,
          currentPN2: 1.2,
        ),
      ];
      notifier.setFollowedDive(
        diveId: 'dive-9',
        compartments: compartments,
        surfaceInterval: const Duration(hours: 2),
      );

      var state = notifier.state;
      expect(state.sourceDiveId, 'dive-9');
      expect(state.initialTissueState, compartments);
      expect(state.surfaceInterval, const Duration(hours: 2));
      expect(state.isDirty, isTrue);

      notifier.clearFollowedDive();
      state = notifier.state;
      expect(state.sourceDiveId, isNull);
      expect(state.initialTissueState, isNull);
      expect(state.surfaceInterval, isNull);
    });

    test('setLinkedDive records and clears the converted dive', () {
      final notifier = DivePlanNotifier(PlanCalculatorService());
      addTearDown(notifier.dispose);

      notifier.setLinkedDive('dive-12');
      expect(notifier.state.linkedDiveId, 'dive-12');

      notifier.setLinkedDive(null);
      expect(notifier.state.linkedDiveId, isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  // Null means "leave at the AppSettings default", so these fixtures cannot
  // drift away from the real defaults.
  _TestSettingsNotifier({
    PressureUnit? pressureUnit,
    int? gfLow,
    int? gfHigh,
    PlannerWaterType? plannerWater,
    double? ccrSetpointLow,
    double? ccrSetpointHigh,
  }) : super(
         const AppSettings().copyWith(
           pressureUnit: pressureUnit,
           gfLow: gfLow,
           gfHigh: gfHigh,
           defaultPlannerWaterType: plannerWater,
           ccrSetpointLow: ccrSetpointLow,
           ccrSetpointHigh: ccrSetpointHigh,
         ),
       );

  void updatePressureUnitForTest(PressureUnit unit) {
    state = state.copyWith(pressureUnit: unit);
  }

  void updateGradientFactorsForTest(int low, int high) {
    state = state.copyWith(gfLow: low, gfHigh: high);
  }

  void updatePlannerWaterForTest(PlannerWaterType type) {
    state = state.copyWith(defaultPlannerWaterType: type);
  }

  void updateCcrSetpointsForTest(double low, double high) {
    state = state.copyWith(ccrSetpointLow: low, ccrSetpointHigh: high);
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

    test('a new plan starts on salt water', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(divePlanNotifierProvider).waterType,
        WaterType.salt,
      );
    });

    test('a new plan starts on the diver default water type', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) =>
                _TestSettingsNotifier(plannerWater: PlannerWaterType.fresh),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(divePlanNotifierProvider).waterType,
        WaterType.fresh,
      );
    });

    test('a new plan starts on custom salinity when that is the default', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) =>
                _TestSettingsNotifier(plannerWater: PlannerWaterType.custom),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(divePlanNotifierProvider);
      expect(state.waterType, isNull);
      expect(state.salinityPpt, DiveEnvironment.typicalSeaSalinityPpt);
    });

    test('an untouched plan follows later planner water settings', () {
      final settingsNotifier = _TestSettingsNotifier();
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith((ref) => settingsNotifier)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(divePlanNotifierProvider).waterType,
        WaterType.salt,
      );

      settingsNotifier.updatePlannerWaterForTest(PlannerWaterType.fresh);

      final state = container.read(divePlanNotifierProvider);
      expect(state.waterType, WaterType.fresh);
      expect(state.salinityPpt, isNull);
      expect(state.isDirty, isFalse);
    });

    test('an untouched plan adopts a later custom water default', () {
      final settingsNotifier = _TestSettingsNotifier();
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith((ref) => settingsNotifier)],
      );
      addTearDown(container.dispose);

      container.read(divePlanNotifierProvider);
      settingsNotifier.updatePlannerWaterForTest(PlannerWaterType.custom);

      final state = container.read(divePlanNotifierProvider);
      expect(state.waterType, isNull);
      expect(state.salinityPpt, DiveEnvironment.typicalSeaSalinityPpt);
      expect(state.isDirty, isFalse);
    });

    test('adopting the current water type is a no-op', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(divePlanNotifierProvider.notifier);
      final before = container.read(divePlanNotifierProvider);
      notifier.adoptPlannerWaterIfPristine(PlannerWaterType.salt);
      expect(container.read(divePlanNotifierProvider).id, before.id);
      expect(container.read(divePlanNotifierProvider).isDirty, isFalse);
    });

    test('a hand-tuned plan ignores later planner water settings', () {
      final settingsNotifier = _TestSettingsNotifier();
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith((ref) => settingsNotifier)],
      );
      addTearDown(container.dispose);

      container
          .read(divePlanNotifierProvider.notifier)
          .updateWaterType(WaterType.fresh);

      settingsNotifier.updatePlannerWaterForTest(PlannerWaterType.custom);

      final state = container.read(divePlanNotifierProvider);
      expect(state.waterType, WaterType.fresh);
      expect(state.salinityPpt, isNull);
    });

    test('a plan with segments ignores later planner water settings', () {
      final settingsNotifier = _TestSettingsNotifier();
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith((ref) => settingsNotifier)],
      );
      addTearDown(container.dispose);

      container
          .read(divePlanNotifierProvider.notifier)
          .addSimplePlan(maxDepth: 30.0, bottomTimeMinutes: 20);
      // addSimplePlan is a structural edit; keep water salt, then prove
      // settings cannot rewrite it.
      expect(
        container.read(divePlanNotifierProvider).waterType,
        WaterType.salt,
      );

      settingsNotifier.updatePlannerWaterForTest(PlannerWaterType.fresh);

      expect(
        container.read(divePlanNotifierProvider).waterType,
        WaterType.salt,
      );
    });

    test('switching to CCR seeds the diver own CCR setpoints', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(
              ccrSetpointLow: 0.6,
              ccrSetpointHigh: 1.2,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(divePlanNotifierProvider.notifier)
          .updateMode(domain.PlanMode.ccr);

      final state = container.read(divePlanNotifierProvider);
      expect(state.setpointLow, 0.6);
      expect(state.setpointHigh, 1.2);
    });

    group('CCR loop slots (#3220)', () {
      ProviderContainer ccrContainer() {
        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
        );
        addTearDown(container.dispose);
        container
            .read(divePlanNotifierProvider.notifier)
            .updateMode(domain.PlanMode.ccr);
        return container;
      }

      DiveTank bailout(String id, {double o2 = 50}) => DiveTank(
        id: id,
        volume: 11.1,
        startPressure: 200,
        gasMix: GasMix(o2: o2),
        role: TankRole.backGas,
      );

      PlanSegment hold(String tankId, GasMix mix) => PlanSegment.hold(
        id: 'seg-$tankId',
        depth: 30,
        durationMinutes: 20,
        tankId: tankId,
        gasMix: mix,
        order: 0,
      );

      test('entering CCR makes the plan\'s cylinder the diluent and adds an '
          'oxygen placeholder', () {
        final state = ccrContainer().read(divePlanNotifierProvider);
        expect(state.tanks, hasLength(2));
        expect(state.tanks.first.role, TankRole.diluent);
        final o2 = state.tanks.last;
        expect(o2.role, TankRole.oxygenSupply);
        expect(o2.gasMix.o2, 100);
        expect(o2.volume, 3.0);
        expect(o2.startPressure, 200);
      });

      test('a further pure-O2 cylinder stays bailout; the slot is not '
          'duplicated', () {
        final container = ccrContainer();
        final notifier = container.read(divePlanNotifierProvider.notifier);
        notifier.addTank(bailout('bo-o2', o2: 100));
        notifier.updateMode(domain.PlanMode.scr);
        notifier.updateMode(domain.PlanMode.ccr);
        final state = container.read(divePlanNotifierProvider);
        expect(
          state.tanks.where((t) => t.role == TankRole.oxygenSupply),
          hasLength(1),
        );
        expect(
          state.tanks.firstWhere((t) => t.id == 'bo-o2').role,
          TankRole.backGas,
        );
      });

      test('the oxygen slot and the last diluent cannot be removed', () {
        final container = ccrContainer();
        final notifier = container.read(divePlanNotifierProvider.notifier);
        notifier.addTank(bailout('bo'));
        final before = container.read(divePlanNotifierProvider).tanks;
        final o2 = before.firstWhere((t) => t.role == TankRole.oxygenSupply);
        final dil = before.firstWhere((t) => t.role == TankRole.diluent);

        notifier.removeTank(o2.id);
        notifier.removeTank(dil.id);
        expect(container.read(divePlanNotifierProvider).tanks, before);

        // A bailout cylinder still goes.
        notifier.removeTank('bo');
        expect(container.read(divePlanNotifierProvider).tanks, hasLength(2));
      });

      test('a second diluent can be removed; its segments move to the '
          'remaining one', () {
        final container = ccrContainer();
        final notifier = container.read(divePlanNotifierProvider.notifier);
        const deep = GasMix(o2: 10, he: 70);
        notifier.addTank(
          const DiveTank(
            id: 'deep',
            volume: 11.1,
            startPressure: 200,
            gasMix: deep,
            role: TankRole.diluent,
          ),
        );
        notifier.addSegment(hold('deep', deep));
        notifier.removeTank('deep');
        final state = container.read(divePlanNotifierProvider);
        final remaining = state.tanks.firstWhere(
          (t) => t.role == TankRole.diluent,
        );
        expect(state.segments.single.tankId, remaining.id);
        expect(state.segments.single.gasMix, remaining.gasMix);
      });

      test('the oxygen slot keeps its role and 100 % through an edit; the '
          'only diluent keeps its role', () {
        final container = ccrContainer();
        final notifier = container.read(divePlanNotifierProvider.notifier);
        final tanks = container.read(divePlanNotifierProvider).tanks;
        final o2 = tanks.firstWhere((t) => t.role == TankRole.oxygenSupply);
        final dil = tanks.firstWhere((t) => t.role == TankRole.diluent);

        notifier.updateTank(
          o2.id,
          o2.copyWith(role: TankRole.backGas, gasMix: const GasMix(o2: 50)),
        );
        notifier.updateTank(dil.id, dil.copyWith(role: TankRole.backGas));

        final after = container.read(divePlanNotifierProvider).tanks;
        final o2After = after.firstWhere((t) => t.id == o2.id);
        expect(o2After.role, TankRole.oxygenSupply);
        expect(o2After.gasMix.o2, 100);
        expect(after.firstWhere((t) => t.id == dil.id).role, TankRole.diluent);
      });

      test('a segment on a CCR plan always breathes a diluent', () {
        final container = ccrContainer();
        final notifier = container.read(divePlanNotifierProvider.notifier);
        notifier.addTank(bailout('bo'));
        notifier.addSegment(hold('bo', const GasMix(o2: 50)));
        final state = container.read(divePlanNotifierProvider);
        final dil = state.tanks.firstWhere((t) => t.role == TankRole.diluent);
        expect(state.segments.single.tankId, dil.id);
        expect(state.segments.single.gasMix, dil.gasMix);
      });

      test('entering CCR on a plan whose only pure-O2 cylinder is already '
          'breathed by a segment (an ordinary OC/SCR O2 deco bottle) '
          'remaps that segment onto the diluent instead of leaving it on '
          'the cylinder CcrLoopSlots just claimed for oxygen', () {
        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(divePlanNotifierProvider.notifier);
        final primary = container.read(divePlanNotifierProvider).tanks.first;
        const o2 = DiveTank(
          id: 'o2-deco',
          volume: 11.1,
          startPressure: 207,
          gasMix: GasMix(o2: 100),
          role: TankRole.deco,
        );
        notifier.addTank(o2);
        notifier.addSegment(hold(primary.id, primary.gasMix));
        notifier.addSegment(hold('o2-deco', const GasMix(o2: 100)));

        notifier.updateMode(domain.PlanMode.ccr);

        final state = container.read(divePlanNotifierProvider);
        final slot = state.tanks.firstWhere((t) => t.id == 'o2-deco');
        expect(slot.role, TankRole.oxygenSupply);
        final dil = state.tanks.firstWhere((t) => t.role == TankRole.diluent);
        // Neither segment may still reference the oxygen slot.
        for (final segment in state.segments) {
          expect(segment.tankId, isNot('o2-deco'));
          expect(segment.tankId, dil.id);
          expect(segment.gasMix, dil.gasMix);
        }
      });

      test('loading a CCR plan with a segment stuck on the oxygen slot '
          '(saved before this remap existed) is repaired on load', () {
        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(divePlanNotifierProvider.notifier);
        final saved = container
            .read(divePlanNotifierProvider)
            .copyWith(
              mode: domain.PlanMode.ccr,
              tanks: const [
                DiveTank(
                  id: 'dil',
                  volume: 3,
                  startPressure: 200,
                  gasMix: GasMix(o2: 18, he: 45),
                  role: TankRole.diluent,
                ),
                DiveTank(
                  id: 'o2',
                  volume: 3,
                  startPressure: 200,
                  gasMix: GasMix(o2: 100),
                  role: TankRole.oxygenSupply,
                ),
              ],
              segments: [hold('o2', const GasMix(o2: 100))],
              isDirty: false,
            );
        notifier.loadPlan(saved);
        final state = container.read(divePlanNotifierProvider);
        expect(state.segments.single.tankId, 'dil');
        expect(state.segments.single.gasMix, const GasMix(o2: 18, he: 45));
      });

      test('a quick plan on a CCR plan starts on the diluent, not the first '
          'cylinder', () {
        final container = ccrContainer();
        final notifier = container.read(divePlanNotifierProvider.notifier);
        // Reorder so a bailout sits first: the quick plan must still pick
        // the diluent.
        final dil = container
            .read(divePlanNotifierProvider)
            .tanks
            .firstWhere((t) => t.role == TankRole.diluent);
        notifier.removeTank(dil.id); // refused: last diluent
        notifier.addTank(bailout('bo'));
        notifier.addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
        final state = container.read(divePlanNotifierProvider);
        for (final segment in state.segments) {
          expect(segment.tankId, dil.id);
        }
      });

      test('loading a CCR plan saved without an oxygen slot fills it '
          'without marking the plan dirty', () {
        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(divePlanNotifierProvider.notifier);
        final saved = container
            .read(divePlanNotifierProvider)
            .copyWith(
              mode: domain.PlanMode.ccr,
              tanks: [
                const DiveTank(
                  id: 'dil',
                  volume: 3,
                  startPressure: 200,
                  gasMix: GasMix(o2: 18, he: 45),
                  role: TankRole.diluent,
                ),
              ],
              isDirty: false,
            );
        notifier.loadPlan(saved);
        final state = container.read(divePlanNotifierProvider);
        expect(state.isDirty, isFalse);
        expect(state.tanks.map((t) => t.role), [
          TankRole.diluent,
          TankRole.oxygenSupply,
        ]);
      });
    });

    test('switching to CCR keeps setpoints the diver already set', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(
              ccrSetpointLow: 0.6,
              ccrSetpointHigh: 1.2,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(divePlanNotifierProvider.notifier);
      notifier.updateMode(domain.PlanMode.ccr);
      notifier.updateSetpoints(low: 0.8, high: 1.4);
      // Switching mode again (e.g. OC -> CCR -> SCR -> CCR while cycling)
      // must not clobber a setpoint the diver already dialed in.
      notifier.updateMode(domain.PlanMode.scr);
      notifier.updateMode(domain.PlanMode.ccr);

      final state = container.read(divePlanNotifierProvider);
      expect(state.setpointLow, 0.8);
      expect(state.setpointHigh, 1.4);
    });

    test('switching to CCR seeds only the half the diver never set', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(
              ccrSetpointLow: 0.6,
              ccrSetpointHigh: 1.2,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(divePlanNotifierProvider.notifier);
      // Only the low setpoint was ever hand-set (e.g. editing just that
      // field); the high half must still pick up the diver's Settings
      // instead of staying null forever.
      notifier.updateSetpoints(low: 0.9);
      notifier.updateMode(domain.PlanMode.ccr);

      final state = container.read(divePlanNotifierProvider);
      expect(state.setpointLow, 0.9);
      expect(state.setpointHigh, 1.2);
    });

    test('a CCR plan ignores later CCR setpoint settings; switching mode '
        'already dirtied it, so unlike GF/water there is nothing pristine '
        'left to adopt into', () {
      final settingsNotifier = _TestSettingsNotifier(
        ccrSetpointLow: 0.6,
        ccrSetpointHigh: 1.2,
      );
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith((ref) => settingsNotifier)],
      );
      addTearDown(container.dispose);

      container
          .read(divePlanNotifierProvider.notifier)
          .updateMode(domain.PlanMode.ccr);
      expect(container.read(divePlanNotifierProvider).isDirty, isTrue);

      settingsNotifier.updateCcrSetpointsForTest(0.9, 1.5);

      final state = container.read(divePlanNotifierProvider);
      expect(state.setpointLow, 0.6);
      expect(state.setpointHigh, 1.2);
    });

    test('an OC plan ignores CCR setpoint settings', () {
      final settingsNotifier = _TestSettingsNotifier();
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith((ref) => settingsNotifier)],
      );
      addTearDown(container.dispose);

      container.read(divePlanNotifierProvider);
      settingsNotifier.updateCcrSetpointsForTest(0.6, 1.2);

      final state = container.read(divePlanNotifierProvider);
      expect(state.setpointLow, isNull);
      expect(state.setpointHigh, isNull);
    });

    test('newPlan re-reads planner water from the diver settings', () {
      final settingsNotifier = _TestSettingsNotifier();
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith((ref) => settingsNotifier)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(divePlanNotifierProvider.notifier);
      notifier.updateWaterType(WaterType.fresh);
      settingsNotifier.updatePlannerWaterForTest(PlannerWaterType.custom);
      notifier.newPlan();

      final state = container.read(divePlanNotifierProvider);
      expect(state.waterType, isNull);
      expect(state.salinityPpt, DiveEnvironment.typicalSeaSalinityPpt);
    });

    test('selectCustomSalinity seeds EN13319 when water type is unset', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(divePlanNotifierProvider.notifier);
      notifier.updateWaterType(null);
      notifier.selectCustomSalinity();
      expect(container.read(divePlanNotifierProvider).waterType, isNull);
      expect(
        container.read(divePlanNotifierProvider).salinityPpt,
        DiveEnvironment.typicalSeaSalinityPpt,
      );
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
              targetDepth: 20,
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

    test('toDive dates the dive at the plan start time', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(divePlanNotifierProvider.notifier);
      final start = DateTime(2026, 10, 3, 9, 30);
      notifier.loadPlan(
        container.read(divePlanNotifierProvider).copyWith(startDateTime: start),
      );

      expect(notifier.toDive().dateTime, start);
    });

    test(
      'updateWaterType stores water type, marks dirty, and toDive copies it',
      () {
        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(divePlanNotifierProvider.notifier);
        expect(
          container.read(divePlanNotifierProvider).waterType,
          WaterType.salt,
        );

        notifier.updateWaterType(WaterType.fresh);
        expect(
          container.read(divePlanNotifierProvider).waterType,
          WaterType.fresh,
        );
        expect(container.read(divePlanNotifierProvider).isDirty, isTrue);
        expect(notifier.toDive().waterType, WaterType.fresh);

        notifier.updateWaterType(null);
        expect(container.read(divePlanNotifierProvider).waterType, isNull);
      },
    );

    test('selectCustomSalinity seeds from the current type and clears it', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(divePlanNotifierProvider.notifier);
      notifier.updateWaterType(WaterType.fresh);
      notifier.selectCustomSalinity();
      expect(container.read(divePlanNotifierProvider).waterType, isNull);
      expect(container.read(divePlanNotifierProvider).salinityPpt, 0.0);

      notifier.updateSalinityPpt(20);
      expect(container.read(divePlanNotifierProvider).salinityPpt, 20);
      notifier.updateWaterType(WaterType.salt);
      expect(container.read(divePlanNotifierProvider).salinityPpt, isNull);
    });

    test('plan results follow custom salinity', () {
      int ttsForSalinity(double ppt) {
        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(divePlanNotifierProvider.notifier);
        notifier.addSimplePlan(maxDepth: 45.0, bottomTimeMinutes: 25);
        notifier.updateSalinityPpt(ppt);
        return container.read(planResultsProvider).ttsAtBottom;
      }

      expect(ttsForSalinity(40), greaterThan(ttsForSalinity(0)));
    });

    test('plan results follow the plan water type', () {
      int ttsForWaterType(WaterType waterType) {
        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(divePlanNotifierProvider.notifier);
        notifier.addSimplePlan(maxDepth: 45.0, bottomTimeMinutes: 25);
        notifier.updateWaterType(waterType);
        return container.read(planResultsProvider).ttsAtBottom;
      }

      expect(
        ttsForWaterType(WaterType.salt),
        greaterThan(ttsForWaterType(WaterType.fresh)),
      );
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

      // These results have to describe the plan the diver is actually
      // looking at.
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

    test('setEquipmentIds keeps provenance in step with the ids (#1487)', () {
      final notifier = DivePlanNotifier(PlanCalculatorService());
      addTearDown(notifier.dispose);

      notifier.setGear(
        const ['reg', 'hose'],
        const [
          GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
          GearProvenance(
            equipmentId: 'hose',
            viaEquipmentId: 'reg',
            viaSetId: 'winter',
          ),
        ],
      );
      // The id-only setter: a surviving id keeps its row, a new id starts
      // loose, a dropped id takes its row with it.
      notifier.setEquipmentIds(const ['reg', 'mask']);

      final rows = notifier.state.gearProvenance;
      expect(rows.map((p) => p.equipmentId), ['reg', 'mask']);
      expect(rows[0].viaSetId, 'winter');
      expect(rows[1].isTopLevel, isTrue);
      expect(rows[1].viaSetId, isNull);
    });

    test('fullGearProvenance gives every id a row so an assembly whose own '
        'row is missing still rolls up (#1487)', () {
      final notifier = DivePlanNotifier(PlanCalculatorService());
      addTearDown(notifier.dispose);

      // A sparse list: the wing's row names the bcd as parent, but the bcd
      // has no row of its own. Read raw, the wing is an orphan and nothing
      // rolls up, so buoyancy would count the bcd and the wing.
      final state = notifier.state.copyWith(
        equipmentIds: const ['bcd', 'wing'],
        gearProvenance: const [
          GearProvenance(equipmentId: 'wing', viaEquipmentId: 'bcd'),
        ],
      );

      final full = state.fullGearProvenance;
      expect(full.map((p) => p.equipmentId), ['bcd', 'wing']);
      expect(full[0].isTopLevel, isTrue);
      expect(full[1].viaEquipmentId, 'bcd');
      expect(GearTree.rolledUpIds(full), {'bcd'});
    });
  });
}

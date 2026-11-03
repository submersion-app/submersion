import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show TurnPressureRule;
import 'package:submersion/features/planner/domain/services/plan_setting_groups.dart';

import 'series_fixtures.dart';

void main() {
  final base = seriesDiveState();

  test('a group changed between two states is the one reported', () {
    final edited = base.copyWith(gfLow: 30, gfHigh: 70);
    expect(changedGroups(base, edited), {PlanSettingGroup.deco});
  });

  test('changes outside every group report none', () {
    final edited = base.copyWith(name: 'Other', notes: 'n');
    expect(changedGroups(base, edited), isEmpty);
  });

  test('each group is told apart', () {
    expect(changedGroups(base, base.copyWith(ascentRate: 6)), {
      PlanSettingGroup.rates,
    });
    expect(changedGroups(base, base.copyWith(sacRate: 14)), {
      PlanSettingGroup.gas,
    });
    expect(changedGroups(base, base.copyWith(altitude: 800)), {
      PlanSettingGroup.environment,
    });
    expect(changedGroups(base, base.copyWith(deviationTimeMinutes: 5)), {
      PlanSettingGroup.contingencies,
    });
  });

  group('applyGroup', () {
    test('copies the group and nothing else', () {
      final from = base.copyWith(
        gfLow: 30,
        gfHigh: 70,
        ascentRate: 6,
        name: 'Source',
      );
      final to = base.copyWith(id: 'other', name: 'Target');

      final applied = applyGroup(PlanSettingGroup.deco, from: from, to: to);

      expect(applied.gfLow, 30);
      expect(applied.gfHigh, 70);
      expect(applied.ascentRate, to.ascentRate);
      expect(applied.name, 'Target');
      expect(applied.id, 'other');
      expect(
        changedGroups(from, applied),
        isNot(contains(PlanSettingGroup.deco)),
      );
    });

    test('a source on the diver\'s default clears the target\'s value', () {
      final to = base.copyWith(sacRate: 20, reservePressure: 60);
      final from = base.copyWith(
        clearSacRate: true,
        clearReservePressure: true,
      );

      final applied = applyGroup(PlanSettingGroup.gas, from: from, to: to);

      expect(applied.sacRate, isNull);
      expect(applied.reservePressure, isNull);
    });

    test('an explicit off is copied as off', () {
      final from = base.copyWith(airBreaksExplicitlyOff: true);
      final applied = applyGroup(PlanSettingGroup.deco, from: from, to: base);
      expect(applied.airBreaksExplicitlyOff, isTrue);
    });

    test('environment carries water, salinity and altitude', () {
      final from = base.copyWith(
        waterType: WaterType.fresh,
        altitude: 1200,
        salinityPpt: 2,
      );
      final applied = applyGroup(
        PlanSettingGroup.environment,
        from: from,
        to: base,
      );
      expect(applied.waterType, WaterType.fresh);
      expect(applied.altitude, 1200);
      expect(applied.salinityPpt, 2);
    });

    test(
      'a turn rule on the default clears the target\'s rule and fraction',
      () {
        final to = base.copyWith(
          turnPressureRule: TurnPressureRule.thirds,
          turnPressureFraction: 0.4,
        );
        final applied = applyGroup(
          PlanSettingGroup.contingencies,
          from: base,
          to: to,
        );
        expect(applied.turnPressureRule, isNull);
        expect(applied.turnPressureFraction, isNull);
      },
    );

    test('applying a group leaves the target marked as changed', () {
      final from = base.copyWith(gfLow: 30);
      final applied = applyGroup(
        PlanSettingGroup.deco,
        from: from,
        to: base.copyWith(isDirty: false),
      );
      expect(applied.isDirty, isTrue);
    });
  });

  test('a group the target already matches is left as it was', () {
    final applied = applyGroup(PlanSettingGroup.deco, from: base, to: base);
    expect(identical(applied, base), isTrue);
  });
}

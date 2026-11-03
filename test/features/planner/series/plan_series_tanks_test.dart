import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart';
import 'package:submersion/features/planner/domain/services/plan_series_edits.dart';
import 'package:submersion/features/planner/domain/services/plan_series_settings.dart';
import 'package:submersion/features/planner/domain/services/plan_setting_groups.dart';

import 'series_fixtures.dart';

const _air = GasMix(o2: 21);

void main() {
  late String Function() ids;

  setUp(() => ids = idSequence('new'));

  /// Dives A, B and C, all on A's two tanks.
  PlanSeries threeDives() {
    final next = idSequence();
    var series = PlanSeries.single(seriesDiveState());
    series = appendDive(series, newId: next);
    return appendDive(series, newId: next);
  }

  /// The series after the tanks of the dive at [index] become [tanks].
  PlanSeries editTanks(
    PlanSeries series,
    int index,
    List<DiveTank> Function(List<DiveTank>) tanks,
  ) {
    final before = series.dives[index].state;
    final edited = updateDiveState(
      series,
      index,
      before.copyWith(tanks: tanks(before.tanks)),
      pinTypedPressures: false,
    );
    return shareSettingEdits(edited, index, before: before, newId: ids);
  }

  List<GasMix> gases(PlanSeries series, int index) => [
    for (final tank in series.dives[index].state.tanks) tank.gasMix,
  ];

  test('a new gas on the first dive reaches the later dives', () {
    final series = editTanks(threeDives(), 0, (tanks) {
      return [tanks[0].copyWith(gasMix: _air), tanks[1]];
    });

    expect(gases(series, 1), [_air, ean50]);
    expect(gases(series, 2), [_air, ean50]);
  });

  test('the gas reaches the later dives\' profiles too', () {
    final series = editTanks(threeDives(), 0, (tanks) {
      return [tanks[0].copyWith(gasMix: _air), tanks[1]];
    });

    expect(series.dives[1].state.segments.first.gasMix, _air);
  });

  test('a tank added to the first dive joins the later dives, linked', () {
    final series = editTanks(threeDives(), 0, (tanks) {
      return [...tanks, const DiveTank(id: 'added', volume: 7, gasMix: _air)];
    });

    expect(series.dives[1].state.tanks, hasLength(3));
    expect(series.dives[2].state.tanks, hasLength(3));
    final inB = series.dives[1].state.tanks.last;
    final inC = series.dives[2].state.tanks.last;
    expect(inB.id, isNot('added'));
    expect(series.dives[1].sourceTankIds[inB.id], 'added');
    expect(series.dives[2].sourceTankIds[inC.id], inB.id);
  });

  test('a tank removed from the first dive leaves the later dives', () {
    final start = threeDives();
    final stageInB = start.dives[1].state.tanks[1].id;
    final b = start.dives[1];
    // Dive B's profile uses the stage, which is about to go.
    final onStage = updateDiveState(
      start,
      1,
      b.state.copyWith(
        segments: [
          for (final s in b.state.segments)
            s.copyWith(tankId: stageInB, gasMix: ean50),
        ],
      ),
      pinTypedPressures: false,
    );

    final series = editTanks(onStage, 0, (tanks) => [tanks[0]]);

    final after = series.dives[1].state;
    expect(after.tanks, hasLength(1));
    expect(after.segments.first.tankId, after.tanks.first.id);
    expect(after.segments.first.gasMix, after.tanks.first.gasMix);
  });

  test('each dive keeps its own tank ids and start pressures', () {
    final start = threeDives();
    final b = start.dives[1].state.tanks[0];
    final filled = updateDiveState(
      start,
      1,
      start.dives[1].state.copyWith(
        tanks: [b.copyWith(startPressure: 150), start.dives[1].state.tanks[1]],
      ),
    );

    final series = editTanks(filled, 0, (tanks) {
      return [tanks[0].copyWith(gasMix: _air), tanks[1]];
    });

    final after = series.dives[1].state.tanks[0];
    expect(after.id, b.id);
    expect(after.startPressure, 150);
    expect(series.dives[1].pinnedTankIds, {b.id});
  });

  test('a start pressure alone does not make the tanks a dive\'s own', () {
    final series = editTanks(threeDives(), 1, (tanks) {
      return [tanks[0].copyWith(startPressure: 150), tanks[1]];
    });

    expect(
      series.dives[1].settingOverrides,
      isNot(contains(PlanSettingGroup.tanks)),
    );
  });

  test('changing a later dive\'s tanks makes them its own', () {
    var series = editTanks(threeDives(), 1, (tanks) {
      return [tanks[0].copyWith(gasMix: _air), tanks[1]];
    });
    expect(series.dives[1].settingOverrides, {PlanSettingGroup.tanks});
    expect(gases(series, 0), [ean32, ean50]);
    expect(gases(series, 2), [ean32, ean50]);

    series = editTanks(series, 0, (tanks) {
      return [tanks[0].copyWith(volume: 15), tanks[1]];
    });
    expect(series.dives[1].state.tanks[0].volume, 12);
    expect(series.dives[2].state.tanks[0].volume, 15);
  });

  test('Reset to series takes the first dive\'s tanks back', () {
    var series = editTanks(threeDives(), 1, (tanks) {
      return [tanks[0].copyWith(gasMix: _air), tanks[1]];
    });
    series = resetGroupToSeries(series, 1, PlanSettingGroup.tanks, newId: ids);

    expect(gases(series, 1), [ean32, ean50]);
    expect(series.dives[1].settingOverrides, isEmpty);
  });

  test('Apply to all dives makes a dive\'s tanks the series\'', () {
    var series = editTanks(threeDives(), 1, (tanks) {
      return [
        tanks[0].copyWith(gasMix: _air),
        tanks[1],
        const DiveTank(
          id: 'bailout',
          volume: 5,
          gasMix: ean32,
          role: TankRole.deco,
        ),
      ];
    });
    series = applyGroupToAll(series, 1, PlanSettingGroup.tanks, newId: ids);

    for (var i = 0; i < 3; i++) {
      expect(gases(series, i), [_air, ean50, ean32]);
    }
    expect(series.dives[1].settingOverrides, isEmpty);
  });

  group('start pressures', () {
    const config = PlanEngineConfig();

    test('the same tanks carry what the dive before left', () {
      final series = threeDives();
      final results = computeSeries(series.dives, config: config);

      expect(
        results[1].state.tanks[0].startPressure,
        results[0].outcome.tankUsages.first.remainingPressure,
      );
    });

    test('a tank changed to another gas starts full', () {
      final series = editTanks(threeDives(), 1, (tanks) {
        return [
          tanks[0].copyWith(gasMix: _air, workingPressure: 232),
          tanks[1],
        ];
      });
      final results = computeSeries(series.dives, config: config);

      expect(results[1].state.tanks[0].startPressure, 232);
    });

    test('a tank of another size starts full', () {
      final series = editTanks(threeDives(), 1, (tanks) {
        return [tanks[0].copyWith(volume: 15, workingPressure: 300), tanks[1]];
      });
      final results = computeSeries(series.dives, config: config);

      expect(results[1].state.tanks[0].startPressure, 300);
    });

    test('a pinned tank keeps its pressure even when it changed', () {
      final start = threeDives();
      final id = start.dives[1].state.tanks[0].id;
      final pinned = start.copyWith(
        dives: [
          start.dives[0],
          start.dives[1].copyWith(pinnedTankIds: {id}),
          start.dives[2],
        ],
      );
      final series = editTanks(pinned, 1, (tanks) {
        return [tanks[0].copyWith(gasMix: _air, startPressure: 90), tanks[1]];
      });
      final results = computeSeries(series.dives, config: config);

      expect(results[1].state.tanks[0].startPressure, 90);
    });

    test('a tank added to a later dive keeps the pressure it was given', () {
      final series = editTanks(threeDives(), 1, (tanks) {
        return [
          ...tanks,
          const DiveTank(
            id: 'extra',
            volume: 7,
            startPressure: 180,
            gasMix: _air,
          ),
        ];
      });
      final results = computeSeries(series.dives, config: config);

      expect(results[1].state.tanks[2].startPressure, 180);
    });

    test('after a dive with its own tanks, the next one starts full', () {
      final series = editTanks(threeDives(), 1, (tanks) => [tanks[0]]);
      final results = computeSeries(series.dives, config: config);

      // Dive C still has the stage, which Dive B did not carry.
      expect(results[2].state.tanks[1].startPressure, 200);
    });
  });

  test('a dive on another circuit keeps its own tanks', () {
    final start = threeDives();
    final other = updateDiveState(
      start,
      1,
      start.dives[1].state.copyWith(mode: PlanMode.ccr),
      pinTypedPressures: false,
    );
    final series = editTanks(other, 0, (tanks) {
      return [tanks[0].copyWith(gasMix: _air), tanks[1]];
    });

    expect(gases(series, 1), [ean32, ean50]);
  });
}

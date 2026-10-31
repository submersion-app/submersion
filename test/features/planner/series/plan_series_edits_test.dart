import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/services/plan_series_edits.dart';

import 'series_fixtures.dart';

void main() {
  group('series dive letters', () {
    test('run A to Z, then AA, AB', () {
      expect(seriesDiveLetter(0), 'A');
      expect(seriesDiveLetter(1), 'B');
      expect(seriesDiveLetter(25), 'Z');
      expect(seriesDiveLetter(26), 'AA');
      expect(seriesDiveLetter(27), 'AB');
    });
  });

  group('a new series', () {
    test('holds one dive, selected, and is not yet a series', () {
      final series = PlanSeries.single(seriesDiveState());
      expect(series.dives, hasLength(1));
      expect(series.selectedIndex, 0);
      expect(series.selected.state.id, 'dive-a');
      expect(series.isSeries, isFalse);
    });
  });

  group('appendDive', () {
    final ids = idSequence();
    final series = appendDive(
      PlanSeries.single(seriesDiveState()),
      newId: ids,
      now: DateTime(2026, 10, 28),
    );
    final added = series.dives.last;

    test('adds a dive after the last one and selects it', () {
      expect(series.dives, hasLength(2));
      expect(series.selectedIndex, 1);
      expect(series.isSeries, isTrue);
      expect(added.state.id, isNot('dive-a'));
    });

    test('gives the new dive a 1:00 surface interval', () {
      expect(added.state.surfaceInterval, const Duration(hours: 1));
      expect(defaultSeriesSurfaceInterval, const Duration(hours: 1));
    });

    test('copies tanks and gases under fresh ids, mapped to their source', () {
      final source = series.dives.first.state.tanks;
      expect(added.state.tanks, hasLength(source.length));
      for (var i = 0; i < source.length; i++) {
        final tank = added.state.tanks[i];
        expect(tank.id, isNot(source[i].id));
        expect(tank.gasMix, source[i].gasMix);
        expect(tank.volume, source[i].volume);
        expect(added.sourceTankIds[tank.id], source[i].id);
      }
      expect(added.pinnedTankIds, isEmpty);
    });

    test('copies the profile, pointing its segments at the new tanks', () {
      final tankIds = added.state.tanks.map((t) => t.id).toSet();
      final sourceIds = series.dives.first.state.segments.map((s) => s.id);
      expect(added.state.segments, hasLength(2));
      for (final segment in added.state.segments) {
        expect(sourceIds, isNot(contains(segment.id)));
        expect(tankIds, contains(segment.tankId));
      }
    });

    test('copies the settings and drops the previous dive\'s links', () {
      final first = PlanSeries.single(
        seriesDiveState().copyWith(
          sourceDiveId: 'logged-1',
          linkedDiveId: 'logged-2',
          initialTissueState: BuhlmannAlgorithm().compartments,
          initialCns: 12,
        ),
      );
      final next = appendDive(first, newId: idSequence()).dives.last.state;
      expect(next.gfLow, 40);
      expect(next.gfHigh, 80);
      expect(next.sourceDiveId, isNull);
      expect(next.linkedDiveId, isNull);
      expect(next.initialTissueState, isNull);
      expect(next.initialCns, isNull);
      expect(next.isDirty, isFalse);
    });

    test('is not offered for a DPV mission plan', () {
      final mission = PlanSeries.single(
        seriesDiveState().copyWith(mission: const DpvMission()),
      );
      expect(canAppendDive(mission), isFalse);
      expect(canAppendDive(PlanSeries.single(seriesDiveState())), isTrue);
      expect(appendDive(mission, newId: idSequence()), same(mission));
    });

    test('is not offered with a DPV mission on any dive', () {
      final series = appendDive(
        PlanSeries.single(seriesDiveState()),
        newId: idSequence(),
      );
      final missionFirst = PlanSeries(
        dives: [
          series.dives[0].copyWith(
            state: series.dives[0].state.copyWith(mission: const DpvMission()),
          ),
          series.dives[1],
        ],
      );
      expect(canAppendDive(missionFirst), isFalse);
    });
  });

  group('canPlanMission', () {
    test('allows a DPV mission on a single dive', () {
      expect(canPlanMission(PlanSeries.single(seriesDiveState())), isTrue);
    });

    test('holds a DPV mission back once the plan is a series', () {
      final series = appendDive(
        PlanSeries.single(seriesDiveState()),
        newId: idSequence(),
      );
      expect(canPlanMission(series), isFalse);
      expect(canPlanMission(series.copyWith(selectedIndex: 0)), isFalse);
    });
  });

  group('removeDive', () {
    PlanSeries threeDives() {
      final ids = idSequence();
      var series = PlanSeries.single(seriesDiveState());
      series = appendDive(series, newId: ids);
      return appendDive(series, newId: ids);
    }

    test('keeps the last remaining dive', () {
      final single = PlanSeries.single(seriesDiveState());
      expect(removeDive(single, 0), same(single));
    });

    test(
      're-links the next dive\'s tanks to the dive before the removed one',
      () {
        final series = threeDives();
        final first = series.dives[0];
        final last = series.dives[2];
        final removed = removeDive(series, 1);

        expect(removed.dives, hasLength(2));
        final relinked = removed.dives[1];
        expect(relinked.state.id, last.state.id);
        for (var i = 0; i < relinked.state.tanks.length; i++) {
          expect(
            relinked.sourceTankIds[relinked.state.tanks[i].id],
            first.state.tanks[i].id,
          );
        }
      },
    );

    test('removing the first dive makes the next one a fresh first dive', () {
      final series = threeDives();
      final removed = removeDive(series, 0);
      final first = removed.dives.first;

      expect(first.state.id, series.dives[1].state.id);
      expect(first.state.surfaceInterval, isNull);
      expect(first.state.initialTissueState, isNull);
      expect(first.state.initialCns, isNull);
      expect(first.state.initialOtu, isNull);
      expect(first.sourceTankIds, isEmpty);
    });

    test('keeps the same dive selected, or the one before a removed one', () {
      final series = threeDives(); // C selected
      expect(removeDive(series, 0).selected.state.id, series.dives[2].state.id);
      expect(removeDive(series, 2).selectedIndex, 1);
      final onB = selectDive(series, 1);
      expect(removeDive(onB, 1).selectedIndex, 0);
    });
  });

  group('selectDive', () {
    test('clamps to the dives in the series', () {
      final series = appendDive(
        PlanSeries.single(seriesDiveState()),
        newId: idSequence(),
      );
      expect(selectDive(series, 0).selectedIndex, 0);
      expect(selectDive(series, 9).selectedIndex, 1);
      expect(selectDive(series, -1).selectedIndex, 0);
    });
  });

  group('tank start pressures', () {
    final series = appendDive(
      PlanSeries.single(seriesDiveState(backPressure: 220)),
      newId: idSequence(),
    );
    final dive = series.dives[1];
    final back = dive.state.tanks[0];
    final stage = dive.state.tanks[1];

    test('a typed start pressure pins that tank', () {
      final typed = dive.state.copyWith(
        tanks: [back.copyWith(startPressure: 150), stage],
      );
      final updated = updateDiveState(series, 1, typed).dives[1];
      expect(updated.pinnedTankIds, {back.id});
      expect(updated.state.tanks[0].startPressure, 150);
    });

    test('other edits pin nothing', () {
      final renamed = dive.state.copyWith(gfLow: 30);
      final updated = updateDiveState(series, 1, renamed).dives[1];
      expect(updated.pinnedTankIds, isEmpty);
      expect(updated.state.gfLow, 30);
    });

    test('Fill fills one tank to its fill in the first dive', () {
      final filled = fillTank(series, 1, back.id).dives[1];
      expect(filled.state.tanks[0].startPressure, 220);
      expect(filled.pinnedTankIds, {back.id});
    });

    test('Fill all tanks fills and pins every tank', () {
      final filled = fillAllTanks(series, 1).dives[1];
      expect(filled.state.tanks.map((t) => t.startPressure), [220, 200]);
      expect(filled.pinnedTankIds, {back.id, stage.id});
    });

    test('a tank new to this dive fills to its own pressure', () {
      expect(fullPressureFor(series, 0, 'dive-a-back'), 220);
      expect(fullPressureFor(series, 1, 'unknown'), isNull);
    });
  });

  group('renameDive', () {
    PlanSeries twoDives() =>
        appendDive(PlanSeries.single(seriesDiveState()), newId: idSequence());

    test('names the dive, trimmed, and only that dive', () {
      final named = renameDive(twoDives(), 0, '  Wreck  ');
      expect(named.dives[0].name, 'Wreck');
      expect(named.dives[1].name, isNull);
    });

    test('a blank name clears it', () {
      final named = renameDive(twoDives(), 1, 'Reef');
      expect(renameDive(named, 1, '   ').dives[1].name, isNull);
    });

    test('a new dive starts unnamed', () {
      final named = renameDive(
        PlanSeries.single(seriesDiveState()),
        0,
        'Wreck',
      );
      final added = appendDive(named, newId: idSequence());
      expect(added.dives[0].name, 'Wreck');
      expect(added.dives[1].name, isNull);
    });

    test('names stay with their dives when one is removed', () {
      var series = appendDive(twoDives(), newId: idSequence('more'));
      series = renameDive(series, 0, 'Wreck');
      series = renameDive(series, 2, 'Reef');
      final removed = removeDive(series, 1);
      expect(removed.dives.map((d) => d.name), ['Wreck', 'Reef']);
    });
  });

  group('removing the first dive', () {
    test('leaves a plan that can be saved', () {
      final two = appendDive(
        PlanSeries.single(seriesDiveState()),
        newId: idSequence(),
      );
      expect(two.dives[1].state.isDirty, isFalse);
      expect(removeDive(two, 0).selected.state.isDirty, isTrue);
    });
  });

  group('setPlanName', () {
    test('names the plan on every dive', () {
      final two = appendDive(
        PlanSeries.single(seriesDiveState()),
        newId: idSequence(),
      );
      final named = setPlanName(two, 'Wreck week');
      expect(named.dives.map((d) => d.state.name), [
        'Wreck week',
        'Wreck week',
      ]);
      expect(named.selectedIndex, two.selectedIndex);
    });
  });
}

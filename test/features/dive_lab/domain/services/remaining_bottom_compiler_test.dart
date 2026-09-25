import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_lab/domain/services/remaining_bottom_compiler.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

import '../support/synthetic_dives.dart';

ProfileAnalysis _analyze(SyntheticDive d) =>
    ProfileAnalysisService(gfLow: 0.30, gfHigh: 0.70).analyze(
      diveId: 'd',
      depths: d.depths,
      timestamps: d.timestamps,
      gasSegments: TankSchedule.fromDive(
        tanks: d.tanks,
        switches: d.switches,
      ).toGasSegments(),
    );

void main() {
  group('finalAscentStartIndex', () {
    test('square dive: the last bottom sample', () {
      final d = squareDive();
      final a = _analyze(d);
      expect(
        finalAscentStartIndex(
          depths: d.depths,
          timestamps: d.timestamps,
          ndlCurve: a.ndlCurve,
          decoStopCurve: a.decoStopCurve,
        ),
        d.bottomEndIndex,
      );
    });

    test('multi-level dive: the end of the shallow level', () {
      final d = multiLevelDive();
      final a = _analyze(d);
      expect(
        finalAscentStartIndex(
          depths: d.depths,
          timestamps: d.timestamps,
          ndlCurve: a.ndlCurve,
          decoStopCurve: a.decoStopCurve,
        ),
        d.bottomEndIndex,
      );
    });

    test('deco dive: stops are not mistaken for a bottom level', () {
      // 45 m for 30 min goes into deco at GF 30/70; the 5 m hold is inside
      // the safety band and any deeper stop sits on the ceiling.
      final d = squareDive(depth: 45, bottomMinutes: 30, withDeco50: false);
      final a = _analyze(d);
      expect(a.hadDecoObligation, isTrue);
      expect(
        finalAscentStartIndex(
          depths: d.depths,
          timestamps: d.timestamps,
          ndlCurve: a.ndlCurve,
          decoStopCurve: a.decoStopCurve,
        ),
        d.bottomEndIndex,
      );
    });

    test('no sample deeper than the safety band yields null', () {
      expect(
        finalAscentStartIndex(
          depths: [0, 3, 5, 5, 5, 2, 0],
          timestamps: [0, 10, 20, 30, 40, 50, 60],
        ),
        isNull,
      );
    });
  });

  group('compileRemainingBottom', () {
    test('branch mid-bottom yields one bottom segment to the ascent start', () {
      final d = squareDive();
      final schedule = TankSchedule.fromDive(
        tanks: d.tanks,
        switches: d.switches,
      );
      final branch = d.indexAt(900);
      final segs = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: branch,
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
      );
      expect(segs, hasLength(1));
      expect(segs.single.type, SegmentType.bottom);
      expect(segs.single.startDepth, closeTo(40, 1e-9));
      expect(segs.single.durationSeconds, d.timestamps[d.bottomEndIndex] - 900);
      expect(segs.single.tankId, 'back');
      expect(segs.single.gasMix.o2, 21);
      expect(segs.single.order, 0);
    });

    test('multi-level branch yields level, transition, level', () {
      final d = multiLevelDive();
      final schedule = TankSchedule.fromDive(
        tanks: d.tanks,
        switches: d.switches,
      );
      final branch = d.indexAt(600);
      final segs = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: branch,
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
      );
      expect(segs.map((s) => s.type), [
        SegmentType.bottom,
        SegmentType.ascent,
        SegmentType.bottom,
      ]);
      expect(segs[0].startDepth, closeTo(40, 1e-9));
      expect(segs[1].startDepth, closeTo(40, 0.5));
      expect(segs[1].endDepth, closeTo(20, 0.5));
      expect(segs[2].startDepth, closeTo(20, 1e-9));
      final total = segs.fold(0, (s, x) => s + x.durationSeconds);
      expect(total, d.timestamps[d.bottomEndIndex] - 600);
      expect(segs.map((s) => s.order), [0, 1, 2]);
    });

    test('forcedTankId overrides the tank on every segment', () {
      final d = squareDive();
      final schedule = TankSchedule.fromDive(
        tanks: d.tanks,
        switches: d.switches,
      );
      final segs = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: d.indexAt(900),
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
        forcedTankId: 'deco50',
      );
      expect(segs.single.tankId, 'deco50');
      expect(segs.single.gasMix.o2, 50);
    });

    test('negative shift trims the last bottom; positive extends it', () {
      final d = squareDive();
      final schedule = TankSchedule.fromDive(
        tanks: d.tanks,
        switches: d.switches,
      );
      final base = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: d.indexAt(900),
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
      ).single.durationSeconds;
      final earlier = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: d.indexAt(900),
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
        shiftSeconds: -300,
      );
      expect(earlier.single.durationSeconds, base - 300);
      final later = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: d.indexAt(900),
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
        shiftSeconds: 300,
      );
      expect(later.single.durationSeconds, base + 300);
    });

    test('a shift larger than the remainder collapses to ascend-now', () {
      final d = squareDive();
      final schedule = TankSchedule.fromDive(
        tanks: d.tanks,
        switches: d.switches,
      );
      final segs = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: d.indexAt(900),
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
        shiftSeconds: -99999,
      );
      expect(segs, hasLength(1));
      expect(segs.single.durationSeconds, 0);
      expect(segs.single.startDepth, 40);
    });

    test('ascendNow and branch-after-bottom yield a zero-duration hold', () {
      final d = squareDive();
      final schedule = TankSchedule.fromDive(
        tanks: d.tanks,
        switches: d.switches,
      );
      final now = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: d.indexAt(900),
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
        ascendNow: true,
      );
      expect(now.single.durationSeconds, 0);
      expect(now.single.startDepth, 40);
      final late = compileRemainingBottom(
        depths: d.depths,
        timestamps: d.timestamps,
        branchIndex: d.bottomEndIndex + 30,
        bottomEndIndex: d.bottomEndIndex,
        schedule: schedule,
      );
      expect(late.single.durationSeconds, 0);
      expect(late.single.startDepth, d.depths[d.bottomEndIndex + 30]);
    });
  });
}

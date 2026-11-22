import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/range_table_service.dart';

const _air = GasMix(o2: 21);
const _airTank = DiveTank(
  id: 'tank-1',
  volume: 11.1,
  startPressure: 207.0,
  gasMix: _air,
);

domain.DivePlan _plan({double depth = 40.0, int minutes = 20}) {
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Range test',
    gfLow: 40,
    gfHigh: 80,
    segments: [
      PlanSegment.travel(
        id: 'seg-1',
        fromDepth: 0,
        targetDepth: depth,
        tankId: 'tank-1',
        gasMix: _air,
        order: 0,
        ratePerMinute: 18.0,
      ),
      PlanSegment.hold(
        id: 'seg-2',
        depth: depth,
        durationMinutes: minutes,
        tankId: 'tank-1',
        gasMix: _air,
        order: 1,
      ),
    ],
    tanks: const [_airTank],
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

void main() {
  group('RangeTableService', () {
    test('base cell matches the plan computed directly', () {
      const service = RangeTableService();
      final table = service.compute(_plan());
      final base = table.baseCell;
      expect(base, isNotNull);

      final direct = const PlanEngine().compute(_plan());
      expect(base!.outcome.ttsAtBottom, direct.ttsAtBottom);
      expect(base.outcome.runtimeSeconds, direct.runtimeSeconds);
    });

    test('deeper and longer variants carry at least the base TTS', () {
      const service = RangeTableService();
      final table = service.compute(_plan());
      final base = table.baseCell!;

      for (final row in table.cells) {
        for (final cell in row) {
          if (cell == null) continue;
          if (cell.depthDelta >= 0 && cell.timeDelta >= 0 && !cell.isBase) {
            expect(
              cell.outcome.ttsAtBottom,
              greaterThanOrEqualTo(base.outcome.ttsAtBottom),
              reason: '+${cell.depthDelta} m / +${cell.timeDelta} min',
            );
          }
        }
      }
    });

    test('variants that would zero out the bottom are skipped', () {
      const service = RangeTableService();
      // 8-minute bottom: the -10 min column must be null, -5 min computes.
      final table = service.compute(_plan(minutes: 8));
      final minusTenIndex = table.timeDeltas.indexOf(-10);
      final minusFiveIndex = table.timeDeltas.indexOf(-5);
      for (final row in table.cells) {
        expect(row[minusTenIndex], isNull);
      }
      final baseRow = table.cells[table.depthDeltas.indexOf(0.0)];
      expect(baseRow[minusFiveIndex], isNotNull);
    });

    // Issue #4849: the time columns must vary a plan whose bottom is the
    // hold half of a single descent split at the configured rate.
    test('time columns vary a single rate-split descent plan', () {
      const service = RangeTableService();
      final plan = _plan().copyWith(
        segments: [
          const PlanSegment(
            id: 'seg-1',
            targetDepth: 40.0,
            durationSeconds: 25 * 60,
            tankId: 'tank-1',
            gasMix: _air,
            splitAtConfiguredRate: true,
          ),
        ],
      );
      final table = service.compute(plan);
      final baseRow = table.cells[table.depthDeltas.indexOf(0.0)];
      final base = table.baseCell!;
      final plusFive = baseRow[table.timeDeltas.indexOf(5)]!;
      final minusFive = baseRow[table.timeDeltas.indexOf(-5)]!;

      expect(
        plusFive.outcome.runtimeSeconds,
        greaterThan(base.outcome.runtimeSeconds),
      );
      expect(
        minusFive.outcome.runtimeSeconds,
        lessThan(base.outcome.runtimeSeconds),
      );
    });

    test(
      'a rate-split descent can shrink only by its hold, not its travel',
      () {
        // 40 m at 18 m/min is 2:13 of travel, so a 10:00 descent holds 7:47:
        // -5 min still leaves a bottom, -10 min would eat into the travel.
        const service = RangeTableService();
        final plan = _plan().copyWith(
          segments: [
            const PlanSegment(
              id: 'seg-1',
              targetDepth: 40.0,
              durationSeconds: 10 * 60,
              tankId: 'tank-1',
              gasMix: _air,
              splitAtConfiguredRate: true,
            ),
          ],
        );
        final table = service.compute(plan);
        final baseRow = table.cells[table.depthDeltas.indexOf(0.0)];

        expect(baseRow[table.timeDeltas.indexOf(-10)], isNull);
        expect(baseRow[table.timeDeltas.indexOf(-5)], isNotNull);
      },
    );

    test('a deeper row measures the hold left after its longer travel', () {
      // At 3 m/min, 40 m is 13:20 of travel and 46 m is 15:20. A 24:20
      // descent holds 11:00 at 40 m but only 9:00 at 46 m, so -10 min still
      // leaves a bottom in the base row and none in the +6 m row.
      const service = RangeTableService(
        config: PlanEngineConfig(descentRate: 3.0),
      );
      final plan = _plan().copyWith(
        segments: [
          const PlanSegment(
            id: 'seg-1',
            targetDepth: 40.0,
            durationSeconds: 1460,
            tankId: 'tank-1',
            gasMix: _air,
            splitAtConfiguredRate: true,
          ),
        ],
      );
      final table = service.compute(plan);
      final minusTen = table.timeDeltas.indexOf(-10);

      expect(table.cells[table.depthDeltas.indexOf(0.0)][minusTen], isNotNull);
      expect(table.cells[table.depthDeltas.indexOf(6.0)][minusTen], isNull);
    });

    test('time columns are blank when the plan has no bottom to vary', () {
      // A linear descent never holds at depth, so a time delta has nothing
      // to lengthen; those cells must not repeat the base value.
      const service = RangeTableService();
      final plan = _plan().copyWith(
        segments: [
          const PlanSegment(
            id: 'seg-1',
            targetDepth: 40.0,
            durationSeconds: 25 * 60,
            tankId: 'tank-1',
            gasMix: _air,
          ),
        ],
      );
      final table = service.compute(plan);

      for (var r = 0; r < table.depthDeltas.length; r++) {
        for (var c = 0; c < table.timeDeltas.length; c++) {
          final cell = table.cells[r][c];
          if (table.timeDeltas[c] == 0) {
            expect(cell, isNotNull, reason: 'row ${table.depthDeltas[r]}');
          } else {
            expect(cell, isNull, reason: '${table.timeDeltas[c]} min');
          }
        }
      }
    });

    test('empty plan yields an empty table', () {
      const service = RangeTableService();
      final table = service.compute(
        domain.DivePlan(
          id: 'p',
          name: 'empty',
          gfLow: 40,
          gfHigh: 80,
          createdAt: DateTime(2026, 7, 5),
          updatedAt: DateTime(2026, 7, 5),
        ),
      );
      expect(table.isEmpty, isTrue);
    });
  });
}

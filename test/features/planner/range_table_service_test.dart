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
      PlanSegment.descent(
        id: 'seg-1',
        targetDepth: depth,
        tankId: 'tank-1',
        gasMix: _air,
        order: 0,
      ),
      PlanSegment.bottom(
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

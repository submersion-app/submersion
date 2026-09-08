import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/schedule_lines.dart';

/// A slate prints whole minutes, but travel legs end at odd seconds. The
/// printed durations are differences of the printed runtimes, so the column
/// always adds up to the runtime beside it - the check a diver makes.
PlanScheduleRow _row(
  PlanScheduleRowKind kind,
  double depth,
  int end,
  int dur,
) => PlanScheduleRow(
  kind: kind,
  depthMeters: depth,
  durationSeconds: dur,
  runtimeSeconds: end,
  gasFO2: 0.21,
  gasFHe: 0,
);

void main() {
  test('durations are differences of the rounded runtimes', () {
    // Bottom ends at 35:00; 3:13 to 21 m; 47 s stop snapped to 39:00;
    // 30 s to 18 m; stop to 42:00.
    final lines = scheduleLines([
      _row(PlanScheduleRowKind.descent, 50, 5 * 60, 5 * 60),
      _row(PlanScheduleRowKind.level, 50, 35 * 60, 30 * 60),
      _row(PlanScheduleRowKind.ascent, 21, 35 * 60 + 193, 193),
      _row(PlanScheduleRowKind.stop, 21, 39 * 60, 47),
      _row(PlanScheduleRowKind.ascent, 18, 39 * 60 + 30, 30),
      _row(PlanScheduleRowKind.stop, 18, 42 * 60, 150),
    ]);

    // 39:30 rounds up to 40, so the leg prints 1 min and the 2:30 stop
    // prints 2.
    expect(lines.map((l) => l.runtimeMinutes), [5, 35, 38, 39, 40, 42]);
    expect(lines.map((l) => l.durationMinutes), [5, 30, 3, 1, 1, 2]);
    // The column sums to the last runtime, whatever the seconds did.
    expect(
      lines.fold<int>(0, (sum, l) => sum + l.durationMinutes),
      lines.last.runtimeMinutes,
    );
  });

  test('a leg too short to round to a minute still prints one, and the stop '
      'after it gives the minute back', () {
    // Leave 21 m at 39:00, 20 s to 18 m, hold 1:40 to 41:00. A slate has one
    // unit: the leg prints 1 min (arrive by 40), the stop prints 1 (leave at
    // 41), and the column still sums to 41.
    final lines = scheduleLines([
      _row(PlanScheduleRowKind.stop, 21, 39 * 60, 60),
      _row(PlanScheduleRowKind.ascent, 18, 39 * 60 + 20, 20),
      _row(PlanScheduleRowKind.stop, 18, 41 * 60, 100),
    ]);
    expect(lines.map((l) => l.runtimeMinutes), [39, 40, 41]);
    expect(lines.map((l) => l.durationMinutes), [39, 1, 1]);
  });

  test('a line with no duration does not invent a minute', () {
    final lines = scheduleLines([
      _row(PlanScheduleRowKind.level, 50, 35 * 60, 30 * 60),
      _row(PlanScheduleRowKind.ascent, 50, 35 * 60, 0),
    ]);
    expect(lines[1].runtimeMinutes, 35);
    expect(lines[1].durationMinutes, 0);
  });

  test('half a minute rounds up', () {
    expect(ScheduleLine.minutesOf(30), 1);
    expect(ScheduleLine.minutesOf(29), 0);
    expect(ScheduleLine.minutesOf(39 * 60 + 30), 40);
  });

  test('every row kind has a distinct glyph', () {
    final glyphs = PlanScheduleRowKind.values.map(scheduleRowGlyph).toSet();
    expect(glyphs.length, PlanScheduleRowKind.values.length);
  });
}

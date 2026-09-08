import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

/// A [PlanScheduleRow] with the whole-minute numbers a table prints.
///
/// A slate shows minutes, but travel legs end at odd seconds (3 m at
/// 6 m/min is thirty seconds) while stops end on whole minutes. Printing each
/// line's own duration rounded would make the column stop adding up to the
/// runtime beside it. So the runtime is rounded to the nearest minute and
/// each duration is the difference between consecutive printed runtimes:
/// whatever a travel leg's minute overstates, the stop after it gives back.
/// The column always sums to the runtime, which is what a diver checks it
/// against. This is how Subsurface's plan table reads too.
class ScheduleLine {
  const ScheduleLine({
    required this.row,
    required this.runtimeMinutes,
    required this.durationMinutes,
  });

  final PlanScheduleRow row;

  /// The row's end time to the nearest whole minute.
  final int runtimeMinutes;

  /// The printed duration: this line's [runtimeMinutes] less the previous
  /// line's. At least one minute for any line that takes time at all.
  final int durationMinutes;

  /// Half-up rounding of a runtime in seconds to whole minutes.
  static int minutesOf(int seconds) => (seconds + 30) ~/ 60;
}

/// The printable lines for [rows], in order.
///
/// A line that takes any time prints at least one minute and advances the
/// runtime by at least one, even when its end rounds back onto the previous
/// line's minute. A thirty-second leg between stops therefore prints as
/// "1 min" and the stop after it gives that minute back, exactly as
/// Subsurface prints a twenty-second leg. Printing the odd seconds instead
/// was tried and read as minutes at a glance; a slate has one unit.
List<ScheduleLine> scheduleLines(List<PlanScheduleRow> rows) {
  final lines = <ScheduleLine>[];
  var previousMinutes = 0;
  for (final row in rows) {
    var minutes = ScheduleLine.minutesOf(row.runtimeSeconds);
    if (row.durationSeconds > 0 && minutes <= previousMinutes) {
      minutes = previousMinutes + 1;
    }
    lines.add(
      ScheduleLine(
        row: row,
        runtimeMinutes: minutes,
        durationMinutes: minutes - previousMinutes,
      ),
    );
    previousMinutes = minutes;
  }
  return lines;
}

/// The direction glyph a slate prints in front of a line: descending,
/// level, ascending, or holding a stop.
String scheduleRowGlyph(PlanScheduleRowKind kind) => switch (kind) {
  PlanScheduleRowKind.descent => '↘',
  PlanScheduleRowKind.level => '→',
  PlanScheduleRowKind.ascent => '↗',
  PlanScheduleRowKind.stop => '−',
};

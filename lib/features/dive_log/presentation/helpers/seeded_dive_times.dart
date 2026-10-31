import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The edit form's time inputs. They hold whole minutes: the entry and exit
/// pickers have no seconds and the duration fields take integers.
class DiveTimeInputs {
  /// Wall clock stamped UTC, as every dive time is.
  final DateTime entry;
  final DateTime? exit;
  final int? bottomTimeMinutes;
  final int? runtimeMinutes;

  const DiveTimeInputs({
    required this.entry,
    this.exit,
    this.bottomTimeMinutes,
    this.runtimeMinutes,
  });
}

/// A dive's times at full precision.
class ExactDiveTimes {
  final DateTime entry;
  final DateTime? exit;
  final Duration? bottomTime;
  final Duration? runtime;

  const ExactDiveTimes({
    required this.entry,
    this.exit,
    this.bottomTime,
    this.runtime,
  });
}

/// What the form's time inputs were filled with, next to the exact values
/// they round.
class SeededDiveTimes {
  /// The inputs as filled, which is how an untouched form reads back.
  final DiveTimeInputs shown;

  /// What an input saves while it still reads as [shown].
  final ExactDiveTimes exact;

  const SeededDiveTimes({required this.shown, required this.exact});

  factory SeededDiveTimes.of(Dive dive) {
    final entry = dive.effectiveEntryTime;
    final bottomTime = dive.bottomTime ?? _bottomTimeFromProfile(dive);
    final timedRuntime = dive.entryTime != null && dive.exitTime != null
        ? dive.exitTime!.difference(dive.entryTime!)
        : null;
    final runtime = dive.runtime ?? timedRuntime;
    // A dive with no exit shows one estimated from its bottom time. The
    // estimate stays on the form: saved, it would stand in for a recorded
    // exit and set the runtime from a bottom time.
    final shownExit =
        dive.exitTime ??
        (dive.bottomTime == null ? null : entry.add(dive.bottomTime!));
    return SeededDiveTimes(
      shown: DiveTimeInputs(
        entry: _wholeMinute(entry),
        exit: shownExit == null ? null : _wholeMinute(shownExit),
        bottomTimeMinutes: bottomTime?.inMinutes,
        runtimeMinutes: runtime?.inMinutes,
      ),
      exact: ExactDiveTimes(
        entry: entry,
        exit: dive.exitTime,
        bottomTime: bottomTime,
        runtime: runtime == null || runtime.isNegative ? null : runtime,
      ),
    );
  }

  static Duration? _bottomTimeFromProfile(Dive dive) =>
      dive.profile.isEmpty ? null : dive.calculateBottomTimeFromProfile();

  static DateTime _wholeMinute(DateTime time) =>
      DateTime.utc(time.year, time.month, time.day, time.hour, time.minute);

  /// The instant [input] stands for, the stored one until the diver moves it.
  DateTime entryFor(DateTime input) =>
      input == shown.entry ? exact.entry : input;

  /// As [entryFor]; null for a dive with no stored exit left as it was shown.
  DateTime? exitFor(DateTime? input) =>
      input == shown.exit ? exact.exit : input;

  /// These times once the diver confirms an exit in its picker. An estimate
  /// they confirm is an exit they recorded, even at the minute shown; a
  /// stored exit keeps its seconds, as any input left alone does.
  SeededDiveTimes withExitPicked() => exact.exit != null
      ? this
      : SeededDiveTimes(
          shown: DiveTimeInputs(
            entry: shown.entry,
            bottomTimeMinutes: shown.bottomTimeMinutes,
            runtimeMinutes: shown.runtimeMinutes,
          ),
          exact: exact,
        );
}

/// What a save writes for the form's time inputs.
///
/// An input the diver left alone saves the exact value it was filled from, so
/// re-saving to fix the notes cannot round a time (issue #3901). Reading the
/// same minutes counts as left alone, so reopening a picker changes nothing.
/// [seeded] is null for a new dive, which has only what the form holds.
ExactDiveTimes resolveDiveTimes(
  DiveTimeInputs form, {
  SeededDiveTimes? seeded,
}) {
  final shown = seeded?.shown;
  final exact = seeded?.exact;
  final entry = seeded?.entryFor(form.entry) ?? form.entry;
  final exit = seeded == null ? form.exit : seeded.exitFor(form.exit);
  final timesKept =
      shown != null && form.entry == shown.entry && form.exit == shown.exit;
  final runtimeKept =
      shown != null && form.runtimeMinutes == shown.runtimeMinutes;
  final bottomTimeKept =
      shown != null && form.bottomTimeMinutes == shown.bottomTimeMinutes;

  var runtime = runtimeKept ? exact?.runtime : _minutes(form.runtimeMinutes);
  if (exit != null && !(timesKept && runtimeKept)) {
    // Total dive time follows the timestamps; a dive with an exit saves no
    // runtime typed against them.
    final timed = exit.difference(entry);
    runtime = timed.isNegative ? null : timed;
  }

  return ExactDiveTimes(
    entry: entry,
    exit: exit,
    bottomTime: bottomTimeKept
        ? exact?.bottomTime
        : _minutes(form.bottomTimeMinutes),
    runtime: runtime,
  );
}

Duration? _minutes(int? minutes) =>
    minutes == null ? null : Duration(minutes: minutes);

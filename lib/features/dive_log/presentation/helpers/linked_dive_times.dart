import 'package:submersion/features/dive_log/presentation/helpers/seeded_dive_times.dart';

// Entry, exit and runtime kept in step on the edit form (issue #241).
//
// Each edit returns the form's times re-seeded: what the time inputs now show,
// next to what a save writes for them. A save reads the result as a form left
// alone, so it writes exactly what it would have written before the edit,
// moved: a recorded exit keeps its seconds, a stored runtime is kept, and an
// estimated exit stays an estimate that is never saved.

/// The times once the diver moves the entry from [form]'s to [entry]: the
/// exit moves by the same amount, so the dive keeps its length. [seeded] is
/// null for a new dive, which has only what the form holds.
SeededDiveTimes moveDiveEntry(
  DiveTimeInputs form,
  DateTime entry, {
  SeededDiveTimes? seeded,
}) {
  // The shift the diver sees, in whole minutes, carries the stored seconds
  // along unchanged.
  final shift = entry.difference(form.entry);
  final times = resolveDiveTimes(form, seeded: seeded);
  return SeededDiveTimes(
    shown: DiveTimeInputs(
      entry: entry,
      exit: form.exit?.add(shift),
      bottomTimeMinutes: form.bottomTimeMinutes,
      runtimeMinutes: form.runtimeMinutes,
    ),
    exact: ExactDiveTimes(
      entry: times.entry.add(shift),
      exit: times.exit?.add(shift),
      bottomTime: times.bottomTime,
      runtime: times.runtime,
    ),
  );
}

/// The times once the diver sets the runtime to [minutes]: the exit becomes
/// entry plus the runtime. An exit that would not be saved (an estimate, or
/// none) is shown as an estimate and still not saved.
SeededDiveTimes setDiveRuntime(
  DiveTimeInputs form,
  int minutes, {
  SeededDiveTimes? seeded,
}) {
  final times = resolveDiveTimes(form, seeded: seeded);
  final runtime = Duration(minutes: minutes);
  final end = times.entry.add(runtime);
  return SeededDiveTimes(
    shown: DiveTimeInputs(
      entry: form.entry,
      exit: wholeMinute(end),
      bottomTimeMinutes: form.bottomTimeMinutes,
      runtimeMinutes: minutes,
    ),
    exact: ExactDiveTimes(
      entry: times.entry,
      exit: times.exit == null ? null : end,
      bottomTime: times.bottomTime,
      runtime: runtime,
    ),
  );
}

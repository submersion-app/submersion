import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

// The rules a dive's number, times and visibility follow when an agent
// writes them, as the dive editor applies them (issue #4294). Each takes a
// change's parsed fields as `values` and the dive as stored as `document`,
// null for a create. Times are wall clocks stamped UTC.

/// The keys of a measured visibility: one distance, or a range of two ends.
const measuredVisibilityKeys = [
  'visibility_m',
  'visibility_min_m',
  'visibility_max_m',
];

const _rangeKeys = ['visibility_min_m', 'visibility_max_m'];

/// The longest a dive may last from entry to exit.
const maxDiveSpan = Duration(hours: 24);

/// A planned dive never holds a number, as the editor saves one.
PlanBlock? diveNumberProblem(
  Map<String, Object?> values,
  Map<String, Object?>? document,
) {
  if (values['dive_number'] == null || document?['is_planned'] != true) {
    return null;
  }
  return const PlanBlock(
    BlockReason.notPermitted,
    'dive_number: a planned dive holds no number. It takes one when it is '
    'logged as a dive.',
  );
}

/// The entry and exit a change leaves, once a moved date_time has shifted
/// the stored exit with it and a named exit has replaced it.
({DateTime entry, DateTime? exit}) diveTimesAfter(
  Map<String, Object?> values,
  Map<String, Object?>? document,
) {
  if (document == null) {
    return (
      entry: values['date_time']! as DateTime,
      exit: values['exit_time'] as DateTime?,
    );
  }
  final stored = DateTime.parse(
    (document['entry_time'] ?? document['date_time'])! as String,
  );
  final offset = switch (values['date_time']) {
    final DateTime moved => moved.difference(
      DateTime.parse(document['date_time']! as String),
    ),
    _ => Duration.zero,
  };
  final exit = values.containsKey('exit_time')
      ? values['exit_time'] as DateTime?
      : switch (document['exit_time']) {
          final String clock => DateTime.parse(clock).add(offset),
          _ => null,
        };
  return (entry: stored.add(offset), exit: exit);
}

/// The runtime, in seconds, that an exit at [exit] gives a dive entered at
/// [entry].
int runtimeBetween(DateTime entry, DateTime exit) =>
    exit.difference(entry).inSeconds;

/// The runtime a named exit sets, when the change does not name one itself:
/// total dive time follows the timestamps, as the editor saves it.
int? runtimeFromExit(
  Map<String, Object?> values,
  Map<String, Object?>? document,
) {
  if (values['exit_time'] == null || values.containsKey('runtime_s')) {
    return null;
  }
  final times = diveTimesAfter(values, document);
  return runtimeBetween(times.entry, times.exit!);
}

/// A named exit must follow the entry within a day, and a dive with an exit
/// holds the runtime its timestamps give, so a runtime that disagrees is
/// refused rather than dropped as the editor drops it.
PlanBlock? diveTimesProblem(
  Map<String, Object?> values,
  Map<String, Object?>? document,
) {
  final times = diveTimesAfter(values, document);
  final exit = times.exit;
  if (values['exit_time'] != null && exit != null) {
    final span = exit.difference(times.entry);
    if (span <= Duration.zero) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'exit_time must be after the entry.',
      );
    }
    if (span > maxDiveSpan) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'exit_time is more than 24 hours after the entry.',
      );
    }
  }
  if (!values.containsKey('runtime_s') || exit == null) return null;
  final runtime = runtimeBetween(times.entry, exit);
  if (values['runtime_s'] == runtime) return null;
  return PlanBlock(
    BlockReason.invalidValue,
    'runtime_s follows the exit: with this exit_time the runtime is '
    '$runtime s. Change exit_time, or clear it, in the same change instead.',
  );
}

/// The visibility shapes [values] name with a value.
List<String> _shapesNamed(Map<String, Object?> values) => [
  if (values['visibility'] != null) 'visibility',
  if (values['visibility_m'] != null) 'visibility_m',
  if (_rangeKeys.any((key) => values[key] != null)) 'range',
];

/// The visibility fields a change clears so the dive keeps one shape: a
/// band, a measurement or a range each clears the others.
Set<String> visibilityCleared(Map<String, Object?> values) =>
    switch (_shapesNamed(values)) {
      ['visibility'] => {...measuredVisibilityKeys},
      ['visibility_m'] => {'visibility', ..._rangeKeys},
      ['range'] => {'visibility', 'visibility_m'},
      _ => const {},
    };

/// A dive holds one visibility shape, and a range end joins the other end as
/// stored, so the two must still make a range.
PlanBlock? visibilityProblem(
  Map<String, Object?> values,
  Map<String, Object?>? document,
) {
  if (_shapesNamed(values).length > 1) {
    return const PlanBlock(
      BlockReason.invalidValue,
      'A dive holds one visibility: a band (visibility), a measurement '
      '(visibility_m) or a range (visibility_min_m, visibility_max_m). '
      'Send one of them.',
    );
  }
  if (!_rangeKeys.any(values.containsKey)) return null;
  double? end(String key) =>
      (values.containsKey(key) ? values[key] : document?[key]) as double?;
  final min = end('visibility_min_m');
  final max = end('visibility_max_m');
  if (min == null && max == null) return null;
  if (VisibilityRange.tryParse(min, max) != null) return null;
  return PlanBlock(
    BlockReason.invalidValue,
    'This change leaves visibility_min_m at $min and visibility_max_m at '
    '$max, and the low end must be below the high end. Set or clear the '
    'other end in the same change.',
  );
}

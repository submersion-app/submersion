import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/services/shared_gear_overlap_rules.dart';
import 'package:submersion/features/equipment/data/repositories/dive_gear_usage_sql.dart';

/// Another profile's dive an item is also on, for the note under a gear row
/// while editing a dive (issue #2853). [entry] is a UTC wall-clock instant.
typedef SharedGearNote = ({String diverName, DateTime entry});

/// The gear on other profiles' dives that overlap [entry]..[exit] by more
/// than the tolerance, keyed by equipment id; the earliest such dive wins.
/// Uses the dive editor's unsaved times, so it works before the dive exists
/// ([diveId] null) and follows time edits. Dives of [diverId] and dives
/// without a profile are never compared, and [diveId] never matches itself.
Future<Map<String, SharedGearNote>> sharedGearNotesFor(
  AppDatabase db, {
  required String? diveId,
  required String diverId,
  required DateTime entry,
  required DateTime exit,
}) async {
  final windowMs = QualityThresholds.neighborWindow.inMilliseconds;
  final rows = await db
      .customSelect(
        'SELECT d.id, d.entry_time, d.dive_date_time, d.exit_time, '
        'd.runtime, d.bottom_time, v.name AS diver_name FROM dives d '
        'JOIN divers v ON v.id = d.diver_id '
        'WHERE d.id IS NOT ?1 AND d.diver_id != ?2 '
        'AND COALESCE(d.entry_time, d.dive_date_time) BETWEEN ?3 AND ?4',
        variables: [
          Variable(diveId),
          Variable.withString(diverId),
          Variable.withInt(entry.millisecondsSinceEpoch - windowMs),
          Variable.withInt(exit.millisecondsSinceEpoch + windowMs),
        ],
      )
      .get();
  final overlapping = <String, SharedGearNote>{};
  for (final r in rows) {
    final entryMs = r.read<int?>('entry_time') ?? r.read<int>('dive_date_time');
    final seconds = r.read<int?>('runtime') ?? r.read<int?>('bottom_time');
    final exitMs =
        r.read<int?>('exit_time') ??
        (seconds != null ? entryMs + seconds * 1000 : null);
    if (exitMs == null) continue;
    final otherEntry = DateTime.fromMillisecondsSinceEpoch(
      entryMs,
      isUtc: true,
    );
    if (!gearUseOverlaps(
      aStart: entry,
      aEnd: exit,
      bStart: otherEntry,
      bEnd: DateTime.fromMillisecondsSinceEpoch(exitMs, isUtc: true),
    )) {
      continue;
    }
    overlapping[r.read<String>('id')] = (
      diverName: r.read<String>('diver_name'),
      entry: otherEntry,
    );
  }
  if (overlapping.isEmpty) return const {};
  final notes = <String, SharedGearNote>{};
  for (final g in await gearUsageForDives(db, overlapping.keys)) {
    final note = overlapping[g.diveId]!;
    final current = notes[g.equipmentId];
    if (current == null || note.entry.isBefore(current.entry)) {
      notes[g.equipmentId] = note;
    }
  }
  return notes;
}

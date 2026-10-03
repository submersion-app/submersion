import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

/// Every way an item is on a dive (issue #2853), as rows of `dive_id`,
/// `equipment_id` and `link_kind`: `gearList` (dive_equipment),
/// `tankCylinder` and `tankRegulator` (dive_tanks), and `transmitter` (a
/// tank serial the dive's diver's registry assigns to a transmitter item,
/// the rule `getExposureSamplesForEquipment` uses: a blank or all-zero
/// serial names no transmitter).
///
/// [diveIdPredicate] is SQL that follows a dive id column in every branch
/// (`IN (?, ?)`, `= da.id`), so each branch filters through its `dive_id`
/// index instead of reading the whole library first. Null reads every dive.
String diveGearUsageSql({String? diveIdPredicate}) {
  String where(String column) =>
      diveIdPredicate == null ? '' : ' AND $column $diveIdPredicate';
  return '''
SELECT dive_id, equipment_id, 'gearList' AS link_kind FROM dive_equipment
  WHERE 1 = 1${where('dive_id')}
UNION ALL
SELECT dive_id, equipment_id, 'tankCylinder' FROM dive_tanks
  WHERE equipment_id IS NOT NULL${where('dive_id')}
UNION ALL
SELECT dive_id, regulator_equipment_id, 'tankRegulator' FROM dive_tanks
  WHERE regulator_equipment_id IS NOT NULL${where('dive_id')}
UNION ALL
SELECT t.dive_id, r.transmitter_equipment_id, 'transmitter'
  FROM dive_tanks t
  JOIN transmitters r
    ON TRIM(t.transmitter_serial) = TRIM(r.transmitter_serial)
  JOIN dives rd ON rd.id = t.dive_id
  WHERE r.transmitter_equipment_id IS NOT NULL
    AND LTRIM(TRIM(r.transmitter_serial), '0') <> ''
    AND (r.diver_id IS NULL OR rd.diver_id IS NULL
      OR rd.diver_id = r.diver_id)${where('t.dive_id')}
''';
}

/// The rows of [diveGearUsageSql] for [diveIds].
Future<List<({String diveId, String equipmentId, String linkKind})>>
gearUsageForDives(AppDatabase db, Iterable<String> diveIds) async {
  final ids = diveIds.toSet().toList()..sort();
  final out = <({String diveId, String equipmentId, String linkKind})>[];
  // The ids repeat once per branch: 240 x 4 stays under SQLite's oldest
  // variable limit (999).
  for (final chunk in seriesIdChunks(ids, size: 240)) {
    final marks = List.filled(chunk.length, '?').join(', ');
    final vars = [for (final id in chunk) Variable.withString(id)];
    final rows = await db
        .customSelect(
          diveGearUsageSql(diveIdPredicate: 'IN ($marks)'),
          // One set of variables per branch.
          variables: [...vars, ...vars, ...vars, ...vars],
        )
        .get();
    for (final r in rows) {
      out.add((
        diveId: r.read<String>('dive_id'),
        equipmentId: r.read<String>('equipment_id'),
        linkKind: r.read<String>('link_kind'),
      ));
    }
  }
  return out;
}

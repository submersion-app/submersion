import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/database/computer_serial_identity.dart';
import 'package:submersion/core/database/imported_computer_identity.dart';
import 'package:submersion/core/database/table_columns.dart';

/// Gives a downloaded `dive_data_sources` row back the computer link it lost
/// while that computer still exists (issue #4368), and returns how many rows
/// it relinked.
///
/// A sync apply that ends with a source pointing at a computer row this
/// database does not hold has its foreign-key repair set the link to NULL,
/// and nothing restored it once the computer arrived. Such a source cannot
/// say which computer it came from, so it is relinked only on its own dive's
/// word: the dive is attributed to an existing computer, the source's model
/// snapshot names that computer's model, its serial snapshot is empty or the
/// same serial, the dive has no source already linked to that computer, and
/// no other unlinked downloaded source on the dive fits as well. Its profile
/// and tank pressure series, cleared by the same repair, follow it. A dive with
/// no computer of its own is never guessed at, so the sources of a computer
/// the diver deleted stay detached.
///
/// Local-only and idempotent: no HLC bump, no pending mark. Every device on
/// this version derives the same link from rows it already shares, and it
/// runs again after an inbound sync apply, where the link is lost.
Future<int> relinkDiveAttributedSources(DatabaseConnectionUser db) async {
  final computerCols = await tableColumnNames(db, 'dive_computers');
  final sourceCols = await tableColumnNames(db, 'dive_data_sources');
  final diveCols = await tableColumnNames(db, 'dives');
  if (!computerCols.containsAll(const {
        'id',
        'manufacturer',
        'model',
        'serial_number',
      }) ||
      !sourceCols.containsAll(const {
        'id',
        'dive_id',
        'computer_id',
        'computer_model',
        'computer_serial',
        'source_format',
      }) ||
      !diveCols.containsAll(const {'id', 'computer_id'})) {
    return 0;
  }

  final rows = await db.customSelect('''
    SELECT s.id, s.dive_id, s.computer_model, s.computer_serial,
      c.id AS computer_id, c.manufacturer, c.model, c.serial_number
    FROM dive_data_sources s
    JOIN dives d ON d.id = s.dive_id
    JOIN dive_computers c ON c.id = d.computer_id
    WHERE s.computer_id IS NULL
      AND s.source_format = 'dive_computer'
      AND NOT EXISTS (SELECT 1 FROM dive_data_sources o
        WHERE o.dive_id = s.dive_id AND o.computer_id = c.id)
  ''').get();

  // Candidates per dive: more than one fitting source means the dive cannot
  // say which is its computer's.
  final fitting = groupBy(
    rows.where(_fits),
    (QueryRow row) => row.read<String>('dive_id'),
  );
  final hasSeries = await _seriesTablesWithSource(db);

  var relinked = 0;
  for (final candidates in fitting.values) {
    if (candidates.length != 1) continue;
    final row = candidates.single;
    final computerId = row.read<String>('computer_id');
    final sourceId = row.read<String>('id');
    // An empty serial copy takes the computer's at once: a source relinked
    // while a conflict is resolved sees no serial heal until the next open.
    await db.customStatement(
      'UPDATE dive_data_sources SET computer_id = ?, computer_serial = '
      "COALESCE(NULLIF(TRIM(computer_serial), ''), ?, computer_serial) "
      'WHERE id = ?',
      [computerId, row.readNullable<String>('serial_number'), sourceId],
    );
    // The same repair cleared the link on the source's recorded series,
    // which say whose they are only through it.
    for (final table in hasSeries) {
      await db.customStatement(
        'UPDATE $table SET computer_id = ? '
        'WHERE source_id = ? AND computer_id IS NULL',
        [computerId, sourceId],
      );
    }
    relinked++;
  }
  return relinked;
}

/// The series tables that carry both a `computer_id` and a `source_id`.
Future<List<String>> _seriesTablesWithSource(DatabaseConnectionUser db) async {
  const tables = ['dive_profile_series', 'tank_pressure_series'];
  return [
    for (final table in tables)
      if ((await tableColumnNames(
        db,
        table,
      )).containsAll(const {'computer_id', 'source_id'}))
        table,
  ];
}

/// Whether the source's snapshots describe the dive's computer.
bool _fits(QueryRow row) {
  final manufacturer = row.readNullable<String>('manufacturer');
  final model = row.readNullable<String>('model');
  final snapshot = normalizeComputerIdentityPart(
    row.readNullable<String>('computer_model'),
  );
  final modelKey = normalizeComputerIdentityPart(model);
  if (snapshot.isEmpty || modelKey.isEmpty) return false;
  final fullKey = normalizeComputerIdentityPart(
    manufacturer == null ? model : '$manufacturer $model',
  );
  if (snapshot != modelKey && snapshot != fullKey) return false;

  final serial = row.readNullable<String>('computer_serial')?.trim() ?? '';
  if (serial.isEmpty) return true;
  return computerSerialsMatch(
    serial,
    row.readNullable<String>('serial_number'),
    shearwater: isShearwaterFamily(manufacturer: manufacturer, model: model),
  );
}

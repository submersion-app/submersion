import 'package:drift/drift.dart';

import 'package:submersion/core/database/imported_computer_identity.dart';

/// Register the dive computers that file-imported dives name, and attribute
/// those dives to them (issue #1288).
///
/// A file import writes only the `dive_computer_model`/`_serial` display
/// snapshots; before #1288 it created no `dive_computers` row and never
/// stamped `computer_id`. The filter, the statistics SQL, and "View dives
/// from this computer" all read the registry, so a logbook built from files
/// named a computer on every dive and still reported "No dive computers
/// registered".
///
/// The #1064 self-heal cannot reach these dives: it adopts `computer_id` from
/// `dive_data_sources`, which a file import also left null. Hence a second
/// pass keyed on the snapshots instead.
///
/// Local-only and idempotent: no HLC bump, nothing marked pending. New rows
/// land on a deterministic id ([importedDiveComputerId]), so every device in a
/// synced fleet derives the same primary key independently and converges
/// without any of them pushing duplicates. An existing row for the same
/// hardware is adopted rather than shadowed, using the same rule the import
/// path applies ([matchImportedComputer]).
///
/// Must run after the #1064 heal, so a dive that can be attributed from its
/// data source (the stronger, download-derived signal) is already resolved
/// and skipped here.
///
/// Only `dives.computer_id` is stamped, not `dive_data_sources.computer_id`:
/// a dive can carry several sources, and no snapshot on the source row is
/// reliable enough to say which of them this device produced.
Future<void> backfillImportedDiveComputers(DatabaseConnectionUser db) async {
  // PRAGMA-guarded like every other self-heal helper: beforeOpen runs for
  // every open, including minimal old-schema fixtures and databases caught
  // mid-upgrade. PRAGMA table_info returns empty for a missing table, so
  // probing the columns covers both cases.
  Future<Set<String>> columnsOf(String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return rows.map((c) => c.read<String>('name')).toSet();
  }

  final diveCols = await columnsOf('dives');
  if (!diveCols.containsAll({
    'computer_id',
    'dive_computer_model',
    'dive_computer_serial',
    'diver_id',
  })) {
    return;
  }
  final computerCols = await columnsOf('dive_computers');
  if (!computerCols.containsAll({
    'id',
    'diver_id',
    'name',
    'manufacturer',
    'model',
    'serial_number',
    'dive_count',
    'is_favorite',
    'notes',
    'created_at',
    'updated_at',
  })) {
    return;
  }
  final sourceCols = await columnsOf('dive_data_sources');
  if (!sourceCols.containsAll({'dive_id', 'source_format'})) return;

  // Downloaded dives carry the same model/serial snapshots, written by
  // importProfile. Excluding them is what stops a deleted device from coming
  // back as a phantom: deleteComputer nulls dives.computer_id but leaves the
  // snapshots, and its _backfillProvenanceSnapshots pass guarantees every
  // orphaned dive keeps a `dive_computer` source row to recognize it by.
  const notADownload =
      "NOT EXISTS (SELECT 1 FROM dive_data_sources s "
      "WHERE s.dive_id = dives.id AND s.source_format = 'dive_computer')";

  final identities = await db.customSelect('''
    SELECT DISTINCT diver_id, dive_computer_model, dive_computer_serial
    FROM dives
    WHERE computer_id IS NULL
      AND TRIM(COALESCE(dive_computer_model, '')) <> ''
      AND $notADownload
  ''').get();
  if (identities.isEmpty) return;

  // A file-imported computer the user deleted keeps its snapshots too, and
  // its row was registered at the deterministic id, so re-minting would
  // resurrect a tombstoned primary key: the peer that applied the delete
  // would delete it again on the next sync, forever.
  final tombstoned = await _tombstonedComputerIds(db);

  // The registry is small (a handful of devices per library), so it is read
  // once into memory: the model comparison collapses internal whitespace,
  // which SQLite cannot express.
  var candidates = await _candidates(db);

  for (final identity in identities) {
    final model = identity.read<String>('dive_computer_model');
    final serial = identity.read<String?>('dive_computer_serial');
    final diverId = identity.read<String?>('diver_id');

    var computerId = matchImportedComputer(
      model: model,
      serialNumber: serial,
      diverId: diverId,
      candidates: candidates,
    )?.id;

    if (computerId == null) {
      final derivedId = importedDiveComputerId(
        model: model,
        serialNumber: serial,
        diverId: diverId,
      );
      if (tombstoned.contains(derivedId)) continue;

      computerId = derivedId;
      final trimmedModel = model.trim();
      final trimmedSerial = serial?.trim();
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.customStatement(
        'INSERT OR IGNORE INTO dive_computers '
        '(id, diver_id, name, model, serial_number, dive_count, '
        'is_favorite, notes, created_at, updated_at) '
        "VALUES (?, ?, ?, ?, ?, 0, 0, '', ?, ?)",
        [
          computerId,
          diverId,
          trimmedModel,
          trimmedModel,
          (trimmedSerial?.isEmpty ?? true) ? null : trimmedSerial,
          now,
          now,
        ],
      );
      // Re-read so a later identity that normalizes onto this same device
      // adopts it instead of racing to insert it again.
      candidates = await _candidates(db);
    }

    // `IS` rather than `=` so the NULL diver/serial groups match too. The
    // download exclusion is repeated here: without it this would claim the
    // downloaded dives that share the identity but were filtered out above.
    await db.customStatement(
      'UPDATE dives SET computer_id = ? '
      'WHERE computer_id IS NULL AND diver_id IS ? '
      'AND dive_computer_model IS ? AND dive_computer_serial IS ? '
      'AND $notADownload',
      [computerId, diverId, model, serial],
    );
  }
}

/// Ids of dive computers this library has deleted.
///
/// Empty when the schema predates the deletion log, which also predates any
/// delete it could have recorded.
Future<Set<String>> _tombstonedComputerIds(DatabaseConnectionUser db) async {
  final cols = await db.customSelect("PRAGMA table_info('deletion_log')").get();
  final names = cols.map((c) => c.read<String>('name')).toSet();
  if (!names.containsAll({'entity_type', 'record_id'})) return const {};

  final rows = await db
      .customSelect(
        "SELECT record_id FROM deletion_log WHERE entity_type = 'diveComputers'",
      )
      .get();
  return rows.map((r) => r.read<String>('record_id')).toSet();
}

Future<List<ImportedComputerCandidate>> _candidates(
  DatabaseConnectionUser db,
) async {
  final rows = await db
      .customSelect(
        'SELECT id, diver_id, manufacturer, model, serial_number '
        'FROM dive_computers ORDER BY updated_at DESC, id',
      )
      .get();
  return rows
      .map(
        (row) => ImportedComputerCandidate(
          id: row.read<String>('id'),
          diverId: row.read<String?>('diver_id'),
          manufacturer: row.read<String?>('manufacturer'),
          model: row.read<String?>('model'),
          serialNumber: row.read<String?>('serial_number'),
        ),
      )
      .toList();
}

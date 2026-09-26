import 'package:drift/drift.dart';

/// The (equipment_id, diver_id) unique index on `equipment_shares` (v228,
/// issue #2046). With the index in place an unguarded duplicate insert
/// throws, so every writer uses `DoNothing`.
const String kEquipmentSharesUniqueIndexName =
    'idx_equipment_shares_equipment_diver_unique';

const String kCreateEquipmentSharesUniqueIndexSql =
    'CREATE UNIQUE INDEX IF NOT EXISTS $kEquipmentSharesUniqueIndexName '
    'ON equipment_shares(equipment_id, diver_id)';

/// Keeps the oldest row of each (item, diver) pair, `id` breaking ties, so
/// every device lands on the same survivor.
const String _collapseDuplicateSharePairsSql = '''
  DELETE FROM equipment_shares WHERE rowid IN (
    SELECT rowid FROM (
      SELECT rowid, ROW_NUMBER() OVER (
        PARTITION BY equipment_id, diver_id ORDER BY created_at ASC, id ASC
      ) AS rn FROM equipment_shares
    ) WHERE rn > 1
  )
''';

Future<bool> _exists(
  DatabaseConnectionUser db,
  String type,
  String name,
) async =>
    (await db
            .customSelect(
              'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ?',
              variables: [Variable<String>(type), Variable<String>(name)],
            )
            .get())
        .isNotEmpty;

/// Creates the share pair index when missing, collapsing any duplicate pairs
/// first so the create cannot fail. A no-op before the table exists.
Future<void> assertEquipmentShareUniqueness(DatabaseConnectionUser db) async {
  if (!await _exists(db, 'table', 'equipment_shares')) return;
  if (await _exists(db, 'index', kEquipmentSharesUniqueIndexName)) return;
  await db.customStatement(_collapseDuplicateSharePairsSql);
  await db.customStatement(kCreateEquipmentSharesUniqueIndexSql);
}

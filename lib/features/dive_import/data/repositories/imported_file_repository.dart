import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/utils/stream_debounce.dart';

/// The `imported_files` rows that hold the original logbook file a dive was
/// imported from, so a later parser fix can be replayed onto it (issue #478).
///
/// Content-addressed: the row id is the sha256 of the bytes, so one import run
/// stores one row however many dives came out of the file, and re-importing
/// the same file reuses the row it already has.
class ImportedFileRepository {
  ImportedFileRepository({AppDatabase Function()? database})
    : _database = database ?? _defaultDatabase;

  final AppDatabase Function() _database;

  /// Bound to the same database the rows are written to: a repository handed an
  /// injected database must not file its pending marks in the global one, where
  /// nothing would ever publish the row they describe.
  SyncRepository get _sync => SyncRepository(database: _database());

  static AppDatabase _defaultDatabase() => DatabaseService.instance.database;

  /// The sync entity type of an `imported_files` row.
  static const entityType = 'importedFiles';

  /// Trailing-debounce window for [watchImportedFilesChanges], the same one the
  /// dive-log ticks use. Duplicated rather than imported so this repository
  /// stays clear of the dive-log layer.
  static const _changeTickDebounce = Duration(milliseconds: 300);

  /// Change-tick for the stored files.
  ///
  /// A row arrives on its own clock, independently of the `dive_data_sources`
  /// row that names it, so a consumer that asks "is the file here" goes stale
  /// the moment sync applies the reference first -- nothing writes the source
  /// row again when the bytes land. Debounced because one import run stores a
  /// row per file in a single batch.
  Stream<void> watchImportedFilesChanges() {
    final db = _database();
    return db
        .tableUpdates(TableUpdateQuery.onTable(db.importedFiles))
        .debounce(_changeTickDebounce);
  }

  /// Stores [bytes] and returns the row id to record in
  /// `dive_data_sources.imported_file_id`.
  ///
  /// A second store of identical bytes is a no-op that returns the same id:
  /// the id is the content, so there is nothing a re-store could change. That
  /// is what keeps the refcount honest -- a row is created once and reclaimed
  /// once.
  Future<String> store({
    required Uint8List bytes,
    String? fileName,
    DateTime? now,
  }) async {
    final db = _database();
    final id = sha256.convert(bytes).toString();
    if (await exists(id)) return id;

    final stamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    await db
        .into(db.importedFiles)
        .insert(
          ImportedFilesCompanion.insert(
            id: id,
            bytes: bytes,
            fileName: Value(fileName),
            byteCount: bytes.length,
            createdAt: stamp,
            updatedAt: stamp,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await _sync.markRecordPending(
      entityType: entityType,
      recordId: id,
      localUpdatedAt: stamp,
    );
    SyncEventBus.notifyLocalChange();
    return id;
  }

  /// The stored file's original bytes, or null when this device does not hold
  /// the row. The blob column's converter inflates it.
  Future<Uint8List?> read(String id) async {
    final db = _database();
    final row = await (db.select(
      db.importedFiles,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.bytes;
  }

  /// Whether this device holds the row [id] names, without loading the blob.
  ///
  /// The reference syncs ahead of nothing in particular, and a peer below the
  /// schema floor never sends the file at all, so a source row can legitimately
  /// name a row that is not here.
  Future<bool> exists(String id) async {
    final db = _database();
    final row =
        await (db.selectOnly(db.importedFiles)
              ..addColumns([db.importedFiles.id])
              ..where(db.importedFiles.id.equals(id))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Bytes the stored files occupy at rest, compressed as they are stored, for
  /// the Storage Usage page.
  Future<int> storedBytes() async {
    final db = _database();
    final row = await db
        .customSelect(
          'SELECT COALESCE(SUM(LENGTH(bytes)), 0) AS total FROM imported_files',
          readsFrom: {db.importedFiles},
        )
        .getSingle();
    return row.read<int>('total');
  }
}

import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';

import '../../../helpers/test_database.dart';

/// A dives tombstone from a peer deletes the local row, and the FK cascade
/// takes its `dive_data_sources` rows with it. Those rows are the only
/// references to the stored import file, so the refcounted sweep has to run
/// here the way it does on a local delete (issue #478).
///
/// The other direction matters just as much: an `importedFiles` tombstone from
/// a peer must not take bytes a dive still living here needs.
void main() {
  late AppDatabase db;
  late ImportedFileRepository importedFiles;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    importedFiles = ImportedFileRepository();
    serializer = SyncDataSerializer();
  });

  tearDown(tearDownTestDatabase);

  Future<void> insertDive(String id) async {
    const epoch = 1700000000000;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: epoch,
            createdAt: epoch,
            updatedAt: epoch,
          ),
        );
  }

  Future<void> insertSource({
    required String id,
    required String diveId,
    required String importedFileId,
  }) async {
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: id,
            diveId: diveId,
            isPrimary: const Value(true),
            importedAt: DateTime(2026, 1, 1),
            createdAt: DateTime(2026, 1, 1),
            sourceFileFormat: const Value('uddf'),
            importedFileId: Value(importedFileId),
          ),
        );
  }

  Future<String> storeFile({List<int> bytes = const [1, 2, 3]}) => importedFiles
      .store(bytes: Uint8List.fromList(bytes), fileName: 'logbook.uddf');

  test('takes the stored file whose last reference it removes', () async {
    await insertDive('dive-1');
    final id = await storeFile();
    await insertSource(id: 'src-1', diveId: 'dive-1', importedFileId: id);

    await serializer.deleteRecord('dives', 'dive-1');

    expect(await db.select(db.dives).get(), isEmpty);
    expect(await importedFiles.exists(id), isFalse);
  });

  test('keeps a stored file another dive still references', () async {
    await insertDive('dive-1');
    await insertDive('dive-2');
    final id = await storeFile();
    await insertSource(id: 'src-1', diveId: 'dive-1', importedFileId: id);
    await insertSource(id: 'src-2', diveId: 'dive-2', importedFileId: id);

    await serializer.deleteRecord('dives', 'dive-1');

    expect(await importedFiles.exists(id), isTrue);

    await serializer.deleteRecord('dives', 'dive-2');

    expect(await importedFiles.exists(id), isFalse);
  });

  test('a tombstone for a dive with no stored file is unaffected', () async {
    await insertDive('dive-1');

    await serializer.deleteRecord('dives', 'dive-1');

    expect(await db.select(db.dives).get(), isEmpty);
  });

  test('a source-row tombstone takes the file it last referenced', () async {
    // A peer can delete a single data source without deleting its dive (a
    // replaceSource re-download on that device), and that row may be the only
    // one naming the stored file, so this path has to sweep like every other
    // deletion path.
    await insertDive('dive-1');
    final id = await storeFile();
    await insertSource(id: 'src-1', diveId: 'dive-1', importedFileId: id);

    await serializer.deleteRecord('diveDataSources', 'src-1');

    expect(await db.select(db.diveDataSources).get(), isEmpty);
    expect(await importedFiles.exists(id), isFalse);
  });

  test('a source-row tombstone keeps a file another row still '
      'names', () async {
    await insertDive('dive-1');
    await insertDive('dive-2');
    final id = await storeFile();
    await insertSource(id: 'src-1', diveId: 'dive-1', importedFileId: id);
    await insertSource(id: 'src-2', diveId: 'dive-2', importedFileId: id);

    await serializer.deleteRecord('diveDataSources', 'src-1');

    expect(await importedFiles.exists(id), isTrue);
  });

  test('an importedFiles tombstone reclaims an unreferenced row', () async {
    final id = await storeFile();

    await serializer.deleteRecord('importedFiles', id);

    expect(await importedFiles.exists(id), isFalse);
  });

  test('an importedFiles tombstone spares a row a local dive needs', () async {
    // The peer reclaimed the row because its own copy of the dive was gone; it
    // has no way to know this device still holds one, so its tombstone must
    // not be applied blindly.
    await insertDive('dive-1');
    final id = await storeFile();
    await insertSource(id: 'src-1', diveId: 'dive-1', importedFileId: id);

    await serializer.deleteRecord('importedFiles', id);

    expect(await importedFiles.exists(id), isTrue);
  });
}

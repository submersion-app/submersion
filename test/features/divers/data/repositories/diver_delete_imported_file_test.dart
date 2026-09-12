import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';

import '../../../../helpers/test_database.dart';

/// Deleting a diver runs `DELETE FROM dives WHERE diver_id = ?` as raw SQL,
/// so the FK cascade takes every `dive_data_sources` row those dives owned.
/// Each of those rows can be the last reference to a stored import file, so
/// the refcounted sweep has to run here the way it does on a dive deletion
/// (issue #478).
void main() {
  late AppDatabase db;
  late ImportedFileRepository importedFiles;
  late DiverRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    importedFiles = ImportedFileRepository();
    repository = DiverRepository();
  });

  tearDown(tearDownTestDatabase);

  Future<void> insertDiver(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value(id),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDive(String id, String diverId) async {
    const epoch = 1700000000000;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: Value(diverId),
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

  test('takes every stored file the diver was the last to reference', () async {
    await insertDiver('diver-1');
    await insertDive('dive-1', 'diver-1');
    await insertDive('dive-2', 'diver-1');
    final first = await storeFile();
    final second = await storeFile(bytes: const [9, 9, 9]);
    await insertSource(id: 'src-1', diveId: 'dive-1', importedFileId: first);
    await insertSource(id: 'src-2', diveId: 'dive-2', importedFileId: second);

    await repository.deleteDiverWithReassignment('diver-1');

    expect(await db.select(db.dives).get(), isEmpty);
    expect(await importedFiles.exists(first), isFalse);
    expect(await importedFiles.exists(second), isFalse);
  });

  test('keeps a file a surviving diver still references', () async {
    await insertDiver('diver-1');
    await insertDiver('diver-2');
    await insertDive('dive-1', 'diver-1');
    await insertDive('dive-2', 'diver-2');
    final id = await storeFile();
    await insertSource(id: 'src-1', diveId: 'dive-1', importedFileId: id);
    await insertSource(id: 'src-2', diveId: 'dive-2', importedFileId: id);

    await repository.deleteDiverWithReassignment('diver-1');

    expect(await importedFiles.exists(id), isTrue);

    await repository.deleteDiverWithReassignment('diver-2');

    expect(await importedFiles.exists(id), isFalse);
  });

  test('the source rows go before the stored file', () async {
    await insertDiver('diver-1');
    await insertDive('dive-1', 'diver-1');
    final id = await storeFile();
    await insertSource(id: 'src-1', diveId: 'dive-1', importedFileId: id);

    await repository.deleteDiverWithReassignment('diver-1');

    expect(await db.select(db.diveDataSources).get(), isEmpty);
    expect(await importedFiles.exists(id), isFalse);
  });
}

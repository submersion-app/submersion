import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// The replaceSource path deletes the `dive_data_sources` row for a
/// dive+computer pair. When that row is the last one referencing a stored
/// import file (issue #478), the row holding the bytes has to go with it --
/// and when it is not, it has to stay.
void main() {
  late AppDatabase db;
  late ImportedFileRepository importedFiles;
  late DiveComputerRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    importedFiles = ImportedFileRepository();
    repo = DiveComputerRepository();
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

  Future<String> storeFile({List<int> bytes = const [1, 2, 3]}) => importedFiles
      .store(bytes: Uint8List.fromList(bytes), fileName: 'logbook.uddf');

  Future<void> insertSource({
    required String id,
    required String diveId,
    required String computerId,
    String? importedFileId,
  }) async {
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: id,
            diveId: diveId,
            computerId: Value(computerId),
            isPrimary: const Value(true),
            importedAt: DateTime(2026, 1, 1),
            createdAt: DateTime(2026, 1, 1),
            sourceFileFormat: const Value('uddf'),
            importedFileId: Value(importedFileId),
          ),
        );
  }

  test('reclaims the stored file whose last reference it removes', () async {
    await insertDive('dive-1');
    final id = await storeFile();
    await insertSource(
      id: 'src-1',
      diveId: 'dive-1',
      computerId: 'comp-1',
      importedFileId: id,
    );

    await repo.clearSourceAndProfiles(diveId: 'dive-1', computerId: 'comp-1');

    expect(await importedFiles.exists(id), isFalse);
  });

  test('keeps a stored file another dive still references', () async {
    await insertDive('dive-1');
    await insertDive('dive-2');
    final id = await storeFile();
    await insertSource(
      id: 'src-1',
      diveId: 'dive-1',
      computerId: 'comp-1',
      importedFileId: id,
    );
    await insertSource(
      id: 'src-2',
      diveId: 'dive-2',
      computerId: 'comp-1',
      importedFileId: id,
    );

    await repo.clearSourceAndProfiles(diveId: 'dive-1', computerId: 'comp-1');

    expect(await importedFiles.exists(id), isTrue);
  });

  test('keeps a stored file a surviving source of the same dive '
      'references', () async {
    await insertDive('dive-1');
    final id = await storeFile();
    await insertSource(
      id: 'src-1',
      diveId: 'dive-1',
      computerId: 'comp-1',
      importedFileId: id,
    );
    await insertSource(
      id: 'src-2',
      diveId: 'dive-1',
      computerId: 'comp-2',
      importedFileId: id,
    );

    await repo.clearSourceAndProfiles(diveId: 'dive-1', computerId: 'comp-1');

    expect(await importedFiles.exists(id), isTrue);
  });

  test('the source row goes before the stored file', () async {
    await insertDive('dive-1');
    final id = await storeFile();
    await insertSource(
      id: 'src-1',
      diveId: 'dive-1',
      computerId: 'comp-1',
      importedFileId: id,
    );

    await repo.clearSourceAndProfiles(diveId: 'dive-1', computerId: 'comp-1');

    expect(await db.select(db.diveDataSources).get(), isEmpty);
    expect(await importedFiles.exists(id), isFalse);
  });
}

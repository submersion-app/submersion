import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_resync_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  setUp(setUpTestDatabase);

  tearDown(tearDownTestDatabase);

  Future<void> seedDiveWithSource(String? importedFileId) async {
    final database = DatabaseService.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await database
        .into(database.divers)
        .insert(
          db.DiversCompanion(
            id: const Value('x'),
            name: const Value('Test Diver'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    await database
        .into(database.dives)
        .insert(
          db.DivesCompanion(
            id: const Value('d1'),
            diverId: const Value('x'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await database
        .into(database.diveDataSources)
        .insert(
          db.DiveDataSourcesCompanion(
            id: const Value('s1'),
            diveId: const Value('d1'),
            isPrimary: const Value(true),
            importedAt: Value(DateTime.now()),
            createdAt: Value(DateTime.now()),
            importedFileId: Value(importedFileId),
          ),
        );
  }

  test('diveHasImportedFileProvider is true for a file held here', () async {
    final stored = await ImportedFileRepository().store(
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'logbook.uddf',
    );
    await seedDiveWithSource(stored);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      await container.read(diveHasImportedFileProvider('d1').future),
      isTrue,
    );
    expect(
      await container.read(diveHasImportedFileProvider('nope').future),
      isFalse,
    );
  });

  test('a dive with no stored file at all is false', () async {
    await seedDiveWithSource(null);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      await container.read(diveHasImportedFileProvider('d1').future),
      isFalse,
    );
  });

  test('turns true when the stored file arrives after the '
      'reference', () async {
    // `imported_file_id` and the row it names travel as separate entities, so
    // sync routinely applies the reference first. Nothing writes
    // `dive_data_sources` again when the blob row lands, so without the
    // imported_files tick the action never appears on the page.
    final bytes = Uint8List.fromList([1, 2, 3]);
    final fileId = sha256.convert(bytes).toString();
    await seedDiveWithSource(fileId);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(diveHasImportedFileProvider('d1'), (_, _) {});

    expect(
      await container.read(diveHasImportedFileProvider('d1').future),
      isFalse,
    );

    await ImportedFileRepository().store(bytes: bytes, fileName: 'late.uddf');
    await Future<void>.delayed(const Duration(milliseconds: 600));

    expect(
      await container.read(diveHasImportedFileProvider('d1').future),
      isTrue,
    );
  });

  test('a reference whose row this device does not hold is false', () async {
    // `imported_file_id` travels with its dive, while the row it names is a
    // top-level entity with its own clock, so a device can hold the reference
    // before (or without ever) holding the bytes. Offering resync there only
    // ever fails.
    await seedDiveWithSource('a-file-this-device-never-received');

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      await container.read(diveHasImportedFileProvider('d1').future),
      isFalse,
    );
  });
}

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';
import 'package:submersion/features/dive_import/data/services/imported_file_reclaimer.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(tearDownTestDatabase);

  Uint8List bytesOf(String text) => Uint8List.fromList(utf8.encode(text));

  test('tombstones what it reclaims in the database it was given', () async {
    // The reclaimer takes an injected database, so its deletion log has to
    // land there: a SyncRepository bound to the global instance tombstones the
    // row in a database that never held it, and the peers are never told about
    // the one that did.
    final injected = createTestDatabase();
    addTearDown(injected.close);
    final files = ImportedFileRepository(database: () => injected);
    final id = await files.store(
      bytes: bytesOf('<uddf>orphan</uddf>'),
      fileName: 'orphan.uddf',
    );

    await ImportedFileReclaimer(database: () => injected).reclaimOrphans();

    expect(await files.exists(id), isFalse);
    final tombstones = await (injected.select(
      injected.deletionLog,
    )..where((t) => t.entityType.equals('importedFiles'))).get();
    expect(tombstones.map((r) => r.recordId), contains(id));
    final global = await (db.select(
      db.deletionLog,
    )..where((t) => t.entityType.equals('importedFiles'))).get();
    expect(global, isEmpty);
  });
}

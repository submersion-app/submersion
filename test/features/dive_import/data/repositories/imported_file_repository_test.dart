import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/raw_dive_data_codec.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ImportedFileRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = ImportedFileRepository(database: () => db);
  });

  tearDown(tearDownTestDatabase);

  Uint8List bytesOf(String text) => Uint8List.fromList(utf8.encode(text));

  test('names the row after the sha256 of the bytes', () async {
    final bytes = bytesOf('<uddf>one</uddf>');

    final id = await repository.store(bytes: bytes, fileName: 'one.uddf');

    expect(id, sha256.convert(bytes).toString());
  });

  test('reads the original bytes back unchanged', () async {
    // Long and repetitive so the at-rest form is genuinely compressed, which
    // is the case a verbatim round trip would not exercise.
    final bytes = bytesOf('<dive>${'0123456789' * 400}</dive>');

    final id = await repository.store(bytes: bytes, fileName: 'big.uddf');

    expect(await repository.read(id), bytes);
  });

  test('compresses at rest behind the shared raw-data header', () async {
    final bytes = bytesOf('<dive>${'0123456789' * 400}</dive>');

    final id = await repository.store(bytes: bytes, fileName: 'big.uddf');

    final stored = await db
        .customSelect(
          'SELECT bytes FROM imported_files WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    final atRest = stored.read<Uint8List>('bytes');
    expect(isCompressedRawDiveData(atRest), isTrue);
    expect(atRest.length, lessThan(bytes.length));
  });

  test('stores one row however many times the same file is imported', () async {
    final bytes = bytesOf('<uddf>same</uddf>');

    final first = await repository.store(bytes: bytes, fileName: 'a.uddf');
    final second = await repository.store(bytes: bytes, fileName: 'b.uddf');

    expect(second, first);
    final rows = await db.select(db.importedFiles).get();
    expect(rows, hasLength(1));
    expect(rows.single.fileName, 'a.uddf', reason: 'the first name stands');
  });

  test('different content lands on different rows', () async {
    final one = await repository.store(
      bytes: bytesOf('<uddf>one</uddf>'),
      fileName: 'dive.uddf',
    );
    final two = await repository.store(
      bytes: bytesOf('<uddf>two</uddf>'),
      fileName: 'dive.uddf',
    );

    expect(two, isNot(one));
    expect(await db.select(db.importedFiles).get(), hasLength(2));
  });

  test('records the original length and the import timestamps', () async {
    final bytes = bytesOf('<uddf>one</uddf>');
    final now = DateTime(2026, 9, 10, 12);

    final id = await repository.store(
      bytes: bytes,
      fileName: 'one.uddf',
      now: now,
    );

    final row = await (db.select(
      db.importedFiles,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.byteCount, bytes.length);
    expect(row.createdAt, now.millisecondsSinceEpoch);
    expect(row.updatedAt, now.millisecondsSinceEpoch);
  });

  test('stamps an hlc so the row reaches a changeset', () async {
    final id = await repository.store(
      bytes: bytesOf('<uddf>one</uddf>'),
      fileName: 'one.uddf',
    );

    final row = await (db.select(
      db.importedFiles,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.hlc, isNotNull);
  });

  test('marks the row pending so sync picks it up', () async {
    final id = await repository.store(
      bytes: bytesOf('<uddf>one</uddf>'),
      fileName: 'one.uddf',
    );

    final pending = await (db.select(
      db.syncRecords,
    )..where((t) => t.entityType.equals('importedFiles'))).get();
    expect(pending.map((r) => r.recordId), contains(id));
  });

  test('keeps its sync bookkeeping in the database it was given', () async {
    // The repository takes an injected database, so everything it writes has
    // to land there -- a SyncRepository bound to the global instance files the
    // pending mark in a different database from the row it describes, and the
    // row then never reaches a changeset.
    final injected = createTestDatabase();
    addTearDown(injected.close);
    final isolated = ImportedFileRepository(database: () => injected);

    final id = await isolated.store(
      bytes: bytesOf('<uddf>injected</uddf>'),
      fileName: 'injected.uddf',
    );

    final pending = await (injected.select(
      injected.syncRecords,
    )..where((t) => t.entityType.equals('importedFiles'))).get();
    expect(pending.map((r) => r.recordId), contains(id));
    final global = await (db.select(
      db.syncRecords,
    )..where((t) => t.entityType.equals('importedFiles'))).get();
    expect(global, isEmpty);
  });

  test('reports a row this device does not hold as absent', () async {
    expect(await repository.exists('not-a-stored-file'), isFalse);
    expect(await repository.read('not-a-stored-file'), isNull);
  });

  test('measures what the stored rows occupy at rest', () async {
    expect(await repository.storedBytes(), 0);

    await repository.store(
      bytes: bytesOf('<uddf>one</uddf>'),
      fileName: 'one.uddf',
    );
    await repository.store(
      bytes: bytesOf('<uddf>two</uddf>'),
      fileName: 'two.uddf',
    );

    final stored = await db
        .customSelect('SELECT bytes FROM imported_files')
        .get();
    final expected = stored.fold<int>(
      0,
      (sum, row) => sum + row.read<Uint8List>('bytes').length,
    );
    expect(await repository.storedBytes(), expected);
  });
}

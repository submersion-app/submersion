import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/raw_dive_data_codec.dart';

/// The column stores compressed bytes and hands back the original ones. What
/// is asserted here is the seam itself: what SQLite holds, read with raw SQL
/// that bypasses the converter, versus what the row class returns.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Uint8List teric() => Uint8List.fromList(
    File(
      'packages/libdivecomputer_plugin/android/src/androidTest/assets/'
      'shearwater_teric_dive.bin',
    ).readAsBytesSync(),
  );

  // Through the companion, not raw SQL: `dives` has required columns this
  // test has no business hard-coding, and a missing one is then a compile
  // error naming the field rather than a runtime NOT NULL failure. The
  // parent row is not optional; `beforeOpen` turns foreign keys on, so a
  // dive_data_sources insert without it will not even prepare.
  Future<void> seedDive(String diveId) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diveDateTime: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  }

  test('a written blob lands compressed and reads back identical', () async {
    final raw = teric();
    await seedDive('d1');
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 's1',
            diveId: 'd1',
            importedAt: DateTime.fromMillisecondsSinceEpoch(0),
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            rawData: Value(raw),
          ),
        );

    final onDisk = await db
        .customSelect(
          'SELECT raw_data FROM dive_data_sources WHERE id = ?',
          variables: [Variable('s1')],
        )
        .getSingle();
    final storedBytes = onDisk.read<Uint8List>('raw_data');

    expect(isCompressedRawDiveData(storedBytes), isTrue);
    expect(storedBytes.length, lessThan(raw.length));

    final row = await (db.select(
      db.diveDataSources,
    )..where((t) => t.id.equals('s1'))).getSingle();
    expect(row.rawData, equals(raw));
  });

  test('a legacy uncompressed row still reads back correctly', () async {
    // The state every existing database is in before the v188 rung, and the
    // state a row inbound from a peer that has not updated arrives in.
    final raw = teric();
    await seedDive('d2');
    await db.customStatement(
      'INSERT INTO dive_data_sources '
      '(id, dive_id, is_primary, imported_at, created_at, raw_data) '
      'VALUES (?, ?, 0, 0, 0, ?)',
      ['s2', 'd2', raw],
    );

    final row = await (db.select(
      db.diveDataSources,
    )..where((t) => t.id.equals('s2'))).getSingle();

    expect(row.rawData, equals(raw));
  });

  test('a null blob stays null in both directions', () async {
    await seedDive('d3');
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 's3',
            diveId: 'd3',
            importedAt: DateTime.fromMillisecondsSinceEpoch(0),
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );

    final row = await (db.select(
      db.diveDataSources,
    )..where((t) => t.id.equals('s3'))).getSingle();

    expect(row.rawData, isNull);
  });
}

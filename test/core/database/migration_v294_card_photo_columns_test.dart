import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/documents/domain/document_ids.dart';

/// v294 (issue #3502): the v277 copy left every certification card photo in
/// the database twice, once in certifications.photo_front / photo_back and
/// once in document_pages. The rung clears the old columns wherever the
/// copy is known to have run.
void main() {
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 293');
      rawDb.execute(
        'CREATE TABLE certifications (id TEXT PRIMARY KEY, '
        'photo_front BLOB, photo_back BLOB, '
        'updated_at INTEGER NOT NULL DEFAULT 0, hlc TEXT)',
      );
      rawDb.execute(
        'CREATE TABLE documents (id TEXT PRIMARY KEY, '
        'certification_id TEXT, type TEXT)',
      );
      rawDb.execute(
        'CREATE TABLE deletion_log (id TEXT PRIMARY KEY, '
        'entity_type TEXT NOT NULL, record_id TEXT NOT NULL, '
        'deleted_at INTEGER NOT NULL)',
      );
      // k1: copied into a card document that still exists.
      rawDb.execute(
        'INSERT INTO certifications (id, photo_front, photo_back, '
        "updated_at, hlc) VALUES ('k1', X'0102', X'0304', 50, 'h1')",
      );
      rawDb.execute(
        'INSERT INTO documents VALUES '
        "('${documentCertificationCardId('k1')}', 'k1', "
        "'certificationCard')",
      );
      // k2: copied, then the diver deleted the card.
      rawDb.execute(
        "INSERT INTO certifications (id, photo_front) VALUES ('k2', X'05')",
      );
      rawDb.execute(
        "INSERT INTO deletion_log VALUES ('t1', 'documents', "
        "'${documentCertificationCardId('k2')}', 1)",
      );
      // k3: never copied (v277 found no diver), so the old columns hold the
      // only copy.
      rawDb.execute(
        "INSERT INTO certifications (id, photo_back) VALUES ('k3', X'06')",
      );
      // k4: a deleted card PAGE is not a deleted card.
      rawDb.execute(
        "INSERT INTO certifications (id, photo_front) VALUES ('k4', X'07')",
      );
      rawDb.execute(
        "INSERT INTO deletion_log VALUES ('t2', 'documentPages', "
        "'${documentCertificationCardId('k4')}', 1)",
      );
    },
  );

  Future<Map<String, Map<String, Object?>>> certs(AppDatabase db) async => {
    for (final r
        in await db
            .customSelect(
              'SELECT id, photo_front, photo_back, updated_at, hlc '
              'FROM certifications',
            )
            .get())
      r.read<String>('id'): r.data,
  };

  test('v294 is in the ladder and leaves the sync floor alone', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(294));
    expect(AppDatabase.migrationVersions, contains(294));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(294));
  });

  test('clears the old photos of a card the documents store holds', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final k1 = (await certs(db))['k1']!;
    expect(k1['photo_front'], isNull);
    expect(k1['photo_back'], isNull);
  });

  test('clears the old photos of a card the diver deleted', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect((await certs(db))['k2']!['photo_front'], isNull);
  });

  test('keeps photos that were never copied, the only copy left', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final all = await certs(db);
    expect(all['k3']!['photo_back'], Uint8List.fromList([6]));
    expect(all['k4']!['photo_front'], Uint8List.fromList([7]));
  });

  test('stamps no sync change: the columns no longer sync', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final k1 = (await certs(db))['k1']!;
    expect(k1['updated_at'], 50);
    expect(k1['hlc'], 'h1');
  });

  test('without a documents table the rung changes nothing', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 293');
          rawDb.execute(
            'CREATE TABLE certifications (id TEXT PRIMARY KEY, '
            'photo_front BLOB, photo_back BLOB)',
          );
          rawDb.execute(
            "INSERT INTO certifications VALUES ('k1', X'01', NULL)",
          );
        },
      ),
    );
    addTearDown(db.close);
    final row = await db
        .customSelect("SELECT photo_front FROM certifications WHERE id = 'k1'")
        .getSingle();
    expect(row.data['photo_front'], Uint8List.fromList([1]));
  });
}

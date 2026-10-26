import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/documents/domain/document_ids.dart';
import 'package:submersion/core/services/sync/changeset_log/rebase_request.dart';

/// v277 (issue #2613): the documents tables, and the copy of insurance,
/// medical clearance and certification card photos into them.
const _parents = [
  'CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, '
      'is_default INTEGER NOT NULL DEFAULT 0, '
      'medical_clearance_expiry_date INTEGER, insurance_provider TEXT, '
      'insurance_policy_number TEXT, insurance_expiry_date INTEGER, '
      'insurance_emergency_phone TEXT, insurance_phone TEXT, '
      'created_at INTEGER NOT NULL DEFAULT 0, '
      'updated_at INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE buddies (id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, '
      "name TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL DEFAULT 0, "
      'updated_at INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE certifications (id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, '
      "buddy_id TEXT, name TEXT NOT NULL DEFAULT '', "
      "agency TEXT NOT NULL DEFAULT '', photo_front BLOB, photo_back BLOB, "
      'created_at INTEGER NOT NULL DEFAULT 0, '
      'updated_at INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)',
  'CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY)',
  'CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY)',
  'CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)',
  'CREATE TABLE courses (id TEXT NOT NULL PRIMARY KEY)',
  'CREATE TABLE dive_centers (id TEXT NOT NULL PRIMARY KEY)',
  'CREATE TABLE local_publish_states (provider TEXT NOT NULL PRIMARY KEY, '
      'base_seq INTEGER, base_part_count INTEGER, base_bytes INTEGER, '
      'head_seq INTEGER NOT NULL DEFAULT 0, published_hlc_high TEXT, '
      'changeset_bytes_since_base INTEGER NOT NULL DEFAULT 0, '
      'updated_at INTEGER NOT NULL DEFAULT 0)',
];

void _seed(sqlite.Database raw) {
  raw.execute('PRAGMA user_version = 276');
  for (final sql in _parents) {
    raw.execute(sql);
  }
  raw.execute(
    "INSERT INTO local_publish_states (provider, base_seq, base_bytes, "
    "changeset_bytes_since_base) VALUES ('icloud', 3, 1000, 12)",
  );
  raw.execute(
    'INSERT INTO divers (id, name, is_default, insurance_provider, '
    'insurance_policy_number, insurance_expiry_date, '
    'insurance_emergency_phone, insurance_phone, '
    'medical_clearance_expiry_date, created_at) VALUES '
    "('d1', 'Ana', 1, 'DAN Europe', 'P-1', 1800000000000, '+1 911', "
    "'+1 555', 1790000000000, 1)",
  );
  raw.execute(
    "UPDATE divers SET created_at = 1600000000000, updated_at = 1650000000000 "
    "WHERE id = 'd1'",
  );
  raw.execute(
    "INSERT INTO divers (id, name, insurance_provider, created_at) "
    "VALUES ('d2', 'Ben', '   ', 2)",
  );
  raw.execute("INSERT INTO buddies (id, diver_id) VALUES ('b1', 'd2')");
  raw.execute(
    'INSERT INTO certifications (id, diver_id, photo_front, photo_back, '
    "created_at, updated_at) VALUES ('c1', 'd1', X'0102', X'0304', "
    '1610000000000, 1660000000000)',
  );
  raw.execute(
    'INSERT INTO certifications (id, buddy_id, photo_front) '
    "VALUES ('c2', 'b1', X'0506')",
  );
  raw.execute(
    "INSERT INTO certifications (id, photo_back) VALUES ('c3', X'0708')",
  );
  raw.execute("INSERT INTO certifications (id, diver_id) VALUES ('c4', 'd1')");
}

NativeDatabase seeded() => NativeDatabase.memory(setup: _seed);

Future<List<Map<String, Object?>>> rows(AppDatabase db, String sql) async => [
  for (final r in await db.customSelect(sql).get()) r.data,
];

void main() {
  test('v277 is in the ladder and did not move the sync floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(277));
    expect(AppDatabase.migrationVersions, contains(277));
    expect(
      AppDatabase.migrationStepCount(276),
      AppDatabase.migrationStepCount(277) + 1,
    );
    // v277 is additive; v278 (#2361) later raised the floor for an
    // unrelated reason, so assert only that 277 itself was never the floor.
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(277));
  });

  test('insurance becomes a primary insurance document', () async {
    final db = AppDatabase(seeded());
    addTearDown(db.close);
    final r = await rows(
      db,
      "SELECT * FROM documents WHERE type = 'insurance'",
    );
    expect(r, hasLength(1));
    expect(r.single['id'], documentInsuranceId('d1'));
    expect(r.single['diver_id'], 'd1');
    expect(r.single['issuer'], 'DAN Europe');
    expect(r.single['reference_number'], 'P-1');
    expect(r.single['expiry_date'], 1800000000000);
    expect(r.single['emergency_phone'], '+1 911');
    expect(r.single['phone'], '+1 555');
    expect(r.single['is_primary'], 1);
    expect(r.single['hlc'], isNull);
  });

  test('clearance becomes a medical clearance document', () async {
    final db = AppDatabase(seeded());
    addTearDown(db.close);
    final r = await rows(
      db,
      "SELECT * FROM documents WHERE type = 'medicalClearance'",
    );
    expect(r.single['id'], documentMedicalClearanceId('d1'));
    expect(r.single['expiry_date'], 1790000000000);
  });

  test('a diver with only blank insurance gets no document', () async {
    final db = AppDatabase(seeded());
    addTearDown(db.close);
    final r = await rows(
      db,
      "SELECT * FROM documents WHERE diver_id = 'd2' "
      "AND type != 'certificationCard'",
    );
    expect(r, isEmpty);
  });

  test('cert photos become card documents with front and back pages', () async {
    final db = AppDatabase(seeded());
    addTearDown(db.close);
    final docs = await rows(
      db,
      'SELECT id, diver_id, certification_id FROM documents '
      "WHERE type = 'certificationCard' ORDER BY certification_id",
    );
    expect([for (final d in docs) d['certification_id']], ['c1', 'c2', 'c3']);
    // c2 is a buddy's cert: filed under the diver who owns that buddy.
    expect(docs[1]['diver_id'], 'd2');
    // c3 is ownerless: filed under the default diver.
    expect(docs[2]['diver_id'], 'd1');
    final pages = await rows(
      db,
      'SELECT side, bytes, mime_type, page_index FROM document_pages '
      "WHERE document_id = '${documentCertificationCardId('c1')}' "
      'ORDER BY page_index',
    );
    expect([for (final p in pages) p['side']], ['front', 'back']);
    expect([for (final p in pages) p['page_index']], [0, 1]);
    expect(pages[0]['bytes'], Uint8List.fromList([1, 2]));
    expect(pages[0]['mime_type'], 'image/jpeg');
  });

  test(
    'migrated rows carry their source row timestamps, the same on every '
    'device, so a peer edit made after the upgrade is not a conflict',
    () async {
      final db = AppDatabase(seeded());
      addTearDown(db.close);
      final docs = await rows(
        db,
        'SELECT type, created_at, updated_at FROM documents '
        "WHERE diver_id = 'd1' AND (type != 'certificationCard' "
        "OR certification_id = 'c1') ORDER BY type",
      );
      for (final d in docs) {
        if (d['type'] == 'certificationCard') {
          expect(d['created_at'], 1610000000000);
          expect(d['updated_at'], 1660000000000);
        } else {
          expect(d['created_at'], 1600000000000, reason: '${d['type']}');
          expect(d['updated_at'], 1650000000000, reason: '${d['type']}');
        }
      }
      final pages = await rows(
        db,
        'SELECT updated_at FROM document_pages '
        "WHERE document_id = '${documentCertificationCardId('c1')}'",
      );
      expect(pages.map((p) => p['updated_at']), everyElement(1660000000000));
    },
  );

  test('the rung asks for a fresh base so a device joining later gets the '
      'migrated documents', () async {
    final db = AppDatabase(seeded());
    addTearDown(db.close);
    final r = await rows(
      db,
      'SELECT changeset_bytes_since_base AS b FROM local_publish_states',
    );
    expect(isRebaseRequested(r.single['b'] as int), isTrue);
  });

  test(
    'with nothing to migrate the rung leaves the publish state alone',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('PRAGMA user_version = 276');
            for (final sql in _parents) {
              raw.execute(sql);
            }
            raw.execute(
              "INSERT INTO local_publish_states (provider, "
              "changeset_bytes_since_base) VALUES ('icloud', 12)",
            );
            raw.execute("INSERT INTO divers (id, name) VALUES ('d1', 'Ana')");
          },
        ),
      );
      addTearDown(db.close);
      final r = await rows(
        db,
        'SELECT changeset_bytes_since_base AS b FROM local_publish_states',
      );
      expect(r.single['b'], 12);
    },
  );

  test('a cert with no photos gets no card document', () async {
    final db = AppDatabase(seeded());
    addTearDown(db.close);
    final r = await rows(
      db,
      "SELECT id FROM documents WHERE certification_id = 'c4'",
    );
    expect(r, isEmpty);
  });

  test('old diver columns are left untouched', () async {
    final db = AppDatabase(seeded());
    addTearDown(db.close);
    final d = await rows(
      db,
      "SELECT insurance_provider FROM divers WHERE id = 'd1'",
    );
    expect(d.single['insurance_provider'], 'DAN Europe');
  });

  test('the copied card photos leave the old columns by v294', () async {
    final db = AppDatabase(seeded());
    addTearDown(db.close);
    final c = await rows(
      db,
      'SELECT photo_front, photo_back FROM certifications '
      "WHERE id IN ('c1', 'c2', 'c3')",
    );
    expect(c, hasLength(3));
    for (final row in c) {
      expect(row['photo_front'], isNull);
      expect(row['photo_back'], isNull);
    }
  });

  test('two independent upgrades produce identical ids', () async {
    final a = AppDatabase(seeded());
    final b = AppDatabase(seeded());
    addTearDown(a.close);
    addTearDown(b.close);
    const sql =
        'SELECT id FROM documents UNION ALL '
        'SELECT id FROM document_pages ORDER BY 1';
    final fromA = await rows(a, sql);
    // Documents: insurance, clearance, three cards. Pages: 2 + 1 + 1.
    expect(fromA, hasLength(5 + 4));
    expect(fromA, await rows(b, sql));
  });

  test('reopening never re-creates a deleted migrated document', () async {
    final dir = Directory.systemTemp.createTempSync('v277_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'v277.db'));
    final first = AppDatabase(NativeDatabase(file, setup: _seedOnce()));
    await first.customStatement(
      "DELETE FROM documents WHERE id = '${documentInsuranceId('d1')}'",
    );
    await first.close();

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    final r = await rows(
      reopened,
      "SELECT id FROM documents WHERE type = 'insurance'",
    );
    expect(r, isEmpty);
  });
}

/// Seeds [file] only on its first open, so the reopen sees the migrated
/// database as it was left.
void Function(sqlite.Database) _seedOnce() {
  var seeded = false;
  return (raw) {
    if (seeded) return;
    seeded = true;
    _seed(raw);
  };
}

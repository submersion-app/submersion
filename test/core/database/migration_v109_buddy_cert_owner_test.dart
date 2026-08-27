import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v109 buddies + certifications shape (buddies still carry the
/// inline cert columns; certifications has no buddy_id).
NativeDatabase _dbAt106({
  required String buddyId,
  String? level,
  String? agency,
  String? preseedCertId,
}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 106');
      rawDb.execute('''
        CREATE TABLE buddies (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT,
          name TEXT NOT NULL,
          email TEXT,
          phone TEXT,
          certification_level TEXT,
          certification_agency TEXT,
          photo_path TEXT,
          notes TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          hlc TEXT
        )
      ''');
      rawDb.execute('''
        CREATE TABLE certifications (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT,
          name TEXT NOT NULL,
          agency TEXT NOT NULL,
          level TEXT,
          card_number TEXT,
          issue_date INTEGER,
          expiry_date INTEGER,
          instructor_name TEXT,
          instructor_number TEXT,
          instructor_id TEXT,
          photo_front_path TEXT,
          photo_back_path TEXT,
          photo_front BLOB,
          photo_back BLOB,
          course_id TEXT,
          notes TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          hlc TEXT
        )
      ''');
      rawDb.execute(
        "INSERT INTO buddies (id, name, certification_level, "
        "certification_agency, created_at, updated_at) "
        "VALUES ('$buddyId', 'Sarah', "
        "${level == null ? 'NULL' : "'$level'"}, "
        "${agency == null ? 'NULL' : "'$agency'"}, 0, 0)",
      );
      if (preseedCertId != null) {
        // Models a row that already arrived via sync from an upgraded peer
        // (the pre-v109 certifications table has no buddy_id column yet).
        rawDb.execute(
          "INSERT INTO certifications (id, name, agency, created_at, "
          "updated_at) VALUES ('$preseedCertId', 'stale', 'padi', 0, 0)",
        );
      }
    },
  );
}

void main() {
  test('v109 adds buddy_id and copies a buddy inline cert into a '
      'deterministic-id certifications row', () async {
    final db = AppDatabase(
      _dbAt106(buddyId: 'b1', level: 'cmas2StarDiver', agency: 'cmas'),
    );
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('certifications')")
        .get();
    expect(cols.map((c) => c.read<String>('name')), contains('buddy_id'));

    final certs = await db.customSelect('SELECT * FROM certifications').get();
    expect(certs, hasLength(1));
    expect(certs.first.data['id'], 'buddycert-b1');
    expect(certs.first.data['buddy_id'], 'b1');
    expect(certs.first.data['diver_id'], isNull);
    expect(certs.first.data['level'], 'cmas2StarDiver');
    expect(certs.first.data['agency'], 'cmas');
  });

  test('v109 defaults agency to "other" when the buddy had a level but no '
      'agency', () async {
    final db = AppDatabase(_dbAt106(buddyId: 'b2', level: 'openWater'));
    addTearDown(() => db.close());
    final cert = await db
        .customSelect("SELECT * FROM certifications WHERE buddy_id = 'b2'")
        .getSingle();
    expect(cert.data['agency'], 'other');
  });

  test('v109 data copy upserts onto the deterministic id (no duplicate) when '
      'that row already exists — models cross-device convergence', () async {
    final db = AppDatabase(
      _dbAt106(
        buddyId: 'b1',
        level: 'openWater',
        agency: 'padi',
        preseedCertId: 'buddycert-b1',
      ),
    );
    addTearDown(() => db.close());
    final certs = await db
        .customSelect("SELECT * FROM certifications WHERE id = 'buddycert-b1'")
        .get();
    expect(certs, hasLength(1));
    // ON CONFLICT set buddy_id on the pre-existing row.
    expect(certs.first.data['buddy_id'], 'b1');
  });

  test('version ladder includes 109', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(109));
    expect(AppDatabase.migrationVersions, contains(109));
  });
}

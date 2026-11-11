import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v360: dive_sites.country_code, a site's ISO 3166-1 alpha-2 code
/// (issue #4426). Nullable; the rung backfills it from the country text the
/// site already holds wherever that text names one country, with no network.
void main() {
  NativeDatabase dbAt(int version, List<(String, String?, String?)> sites) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          final hasCode = sites.any((s) => s.$3 != null);
          rawDb.execute(
            'CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY, '
            'name TEXT NOT NULL, country TEXT'
            "${hasCode ? ', country_code TEXT' : ''})",
          );
          for (final (id, country, code) in sites) {
            rawDb.execute(
              hasCode
                  ? 'INSERT INTO dive_sites (id, name, country, country_code) '
                        'VALUES (?, ?, ?, ?)'
                  : 'INSERT INTO dive_sites (id, name, country) '
                        'VALUES (?, ?, ?)',
              [id, id, country, if (hasCode) code],
            );
          }
        },
      );

  Future<Map<String, String?>> codes(AppDatabase db) async => {
    for (final row
        in await db
            .customSelect('SELECT id, country_code FROM dive_sites')
            .get())
      row.read<String>('id'): row.read<String?>('country_code'),
  };

  test('v360 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(360));
    expect(AppDatabase.migrationVersions, contains(360));
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(360));
  });

  test('upgrading backfills recognised countries only', () async {
    final db = AppDatabase(
      dbAt(359, [
        ('mx', 'Mexico', null),
        ('do', 'República Dominicana', null),
        ('eg', 'مصر', null),
        ('reef', 'Atlantis', null),
        ('blank', null, null),
      ]),
    );
    addTearDown(db.close);

    expect(await codes(db), {
      'mx': 'MX',
      'do': 'DO',
      'eg': 'EG',
      'reef': null,
      'blank': null,
    });
  });

  test('a code already stored is kept', () async {
    final db = AppDatabase(
      dbAt(359, [('geocoded', 'Korea', 'KR'), ('mx', 'Mexico', null)]),
    );
    addTearDown(db.close);

    expect(await codes(db), {'geocoded': 'KR', 'mx': 'MX'});
  });

  test('a database without dive_sites upgrades without failing', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) => rawDb.execute('PRAGMA user_version = 359'),
      ),
    );
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get(); // opens and migrates
  });
}

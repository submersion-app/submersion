import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v137 shape: a dives table with a surface_pressure column,
/// stamped at v136 so only the 136->137 repair block runs.
NativeDatabase _dbAt136({required List<String> inserts}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 136');
      rawDb.execute('''
        CREATE TABLE dives (
          id TEXT NOT NULL PRIMARY KEY,
          surface_pressure REAL
        )
      ''');
      for (final sql in inserts) {
        rawDb.execute(sql);
      }
    },
  );
}

void main() {
  test('v137 repairs surface_pressure stored in the wrong unit', () async {
    final db = AppDatabase(
      _dbAt136(
        inserts: [
          // millibar written into the bar column -> convert to bar.
          "INSERT INTO dives (id, surface_pressure) VALUES ('mbar', 1013)",
          // implausible even as mbar (1.264 bar) -> null out.
          "INSERT INTO dives (id, surface_pressure) VALUES ('garbage', 1264)",
          // already a valid bar value -> untouched.
          "INSERT INTO dives (id, surface_pressure) VALUES ('ok', 1.02)",
          // no data -> stays null.
          "INSERT INTO dives (id, surface_pressure) VALUES ('none', NULL)",
        ],
      ),
    );
    addTearDown(db.close);

    Future<double?> sp(String id) async {
      final row = await db
          .customSelect(
            "SELECT surface_pressure AS sp FROM dives WHERE id = '$id'",
          )
          .getSingle();
      return row.data['sp'] as double?;
    }

    expect(await sp('mbar'), closeTo(1.013, 1e-9));
    expect(await sp('garbage'), isNull);
    expect(await sp('ok'), closeTo(1.02, 1e-9));
    expect(await sp('none'), isNull);
  });

  test('v137 is the current schema version (exact-latest tripwire)', () {
    // The newest migration owns the tripwire; the next schema bump must move
    // it forward and relax this file's assertion to greaterThanOrEqualTo.
    expect(AppDatabase.currentSchemaVersion, 137);
    expect(AppDatabase.migrationVersions, contains(137));
  });
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tank_shared_computer_backfill.dart';

void main() {
  test('v260 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 260);
    expect(AppDatabase.migrationVersions, contains(260));
    expect(AppDatabase.migrationStepCount(259), 1);
  });

  test('the column is additive, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  group('inferSharedComputers', () {
    BackfillTank tank(
      String id,
      String? computer,
      double o2, {
      String role = 'backGas',
    }) => (
      id: id,
      computerId: computer,
      o2: o2,
      he: 0,
      role: role,
      sharedComputerIds: null,
    );

    // The shape a Suunto (21%, 50%) plus Garmin (21%, 50%, O2) fold left:
    // the Garmin's 21% and 50% merged into the Suunto's rows.
    final folded = [
      tank('air', 'suunto', 21),
      tank('ean50', 'suunto', 50, role: 'deco'),
      tank('o2', 'garmin', 100, role: 'deco'),
    ];

    test('a secondary shares the primary cylinders it has no gas of its '
        'own for', () {
      expect(
        inferSharedComputers(
          primaryComputerId: 'suunto',
          secondaryComputerIds: {'garmin'},
          tanks: folded,
        ),
        {
          'air': ['garmin'],
          'ean50': ['garmin'],
        },
      );
    });

    test('the primary never takes a secondary-only cylinder', () {
      final shared = inferSharedComputers(
        primaryComputerId: 'suunto',
        secondaryComputerIds: {'garmin'},
        tanks: folded,
      );
      expect(shared.containsKey('o2'), isFalse);
    });

    test('a secondary that kept a tank on that gas does not share it', () {
      expect(
        inferSharedComputers(
          primaryComputerId: 'suunto',
          secondaryComputerIds: {'garmin'},
          tanks: [tank('air', 'suunto', 21), tank('g-air', 'garmin', 21)],
        ),
        isEmpty,
      );
    });

    test('a tank that already records its sharers is left alone', () {
      expect(
        inferSharedComputers(
          primaryComputerId: 'suunto',
          secondaryComputerIds: {'garmin'},
          tanks: [
            (
              id: 'air',
              computerId: 'suunto',
              o2: 21,
              he: 0,
              role: 'backGas',
              sharedComputerIds: '["other"]',
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('a backup left on another bottom gas keeps its own: nothing merged, '
        'so sharing the primary\'s would change the gas it starts on', () {
      // The primary was set to 32%, the backup left on 21%: the gases differ,
      // so the fold merged nothing and the backup kept its own cylinder.
      expect(
        inferSharedComputers(
          primaryComputerId: 'perdix',
          secondaryComputerIds: {'backup'},
          tanks: [tank('ean32', 'perdix', 32), tank('b-air', 'backup', 21)],
        ),
        isEmpty,
      );
    });

    test('a sidemount backup left on another bottom gas keeps its own', () {
      expect(
        inferSharedComputers(
          primaryComputerId: 'perdix',
          secondaryComputerIds: {'backup'},
          tanks: [
            tank('left', 'perdix', 32, role: 'sidemountLeft'),
            tank('right', 'perdix', 32, role: 'sidemountRight'),
            tank('b-left', 'backup', 21, role: 'sidemountLeft'),
          ],
        ),
        isEmpty,
      );
    });

    test('a cylinder labelled back gas but rich in O2 is not the secondary\'s '
        'bottom gas', () {
      // An import without roles labels every cylinder back gas.
      expect(
        inferSharedComputers(
          primaryComputerId: 'suunto',
          secondaryComputerIds: {'garmin'},
          tanks: [tank('air', 'suunto', 21), tank('o2', 'garmin', 100)],
        ),
        {
          'air': ['garmin'],
        },
      );
    });

    test('a secondary\'s pressure series on a cylinder proves it logged it, '
        'whatever the gas rule says', () {
      // The backup kept a 21% of its own (a second cylinder), yet the fold
      // moved its transmitter's series onto the primary's 21%.
      expect(
        inferSharedComputers(
          primaryComputerId: 'perdix',
          secondaryComputerIds: {'backup'},
          tanks: [tank('air', 'perdix', 21), tank('b-air', 'backup', 21)],
          loggedOn: {(tankId: 'air', computerId: 'backup')},
        ),
        {
          'air': ['backup'],
        },
      );
    });
  });

  /// Dive d: a Suunto (primary) and Garmin fold that recorded nothing.
  /// Dive b: a backup left on 21% while the Perdix ran 32%, the backup's
  /// transmitter series sitting on the Perdix's 32% through its source row
  /// only. Dive solo: one computer. At [version] 260 the column already
  /// exists; [recorded] is what is already stored on a tank, by id.
  /// [badAirO2] stores dive d's 21% as text, a row the inference cannot
  /// read.
  NativeDatabase consolidatedFixture({
    int version = 259,
    Map<String, String> recorded = const {},
    bool badAirO2 = false,
  }) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute('''
        CREATE TABLE dive_tanks (
          id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          computer_id TEXT,
          o2_percent REAL NOT NULL DEFAULT 21,
          he_percent REAL NOT NULL DEFAULT 0,
          tank_order INTEGER NOT NULL DEFAULT 0,
          tank_role TEXT NOT NULL DEFAULT 'backGas'
          ${version >= 260 ? ', shared_computer_ids TEXT' : ''}
        )
      ''');
      rawDb.execute('''
        CREATE TABLE tank_pressure_series (
          id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          tank_id TEXT NOT NULL,
          computer_id TEXT,
          source_id TEXT
        )
      ''');
      rawDb.execute('''
        CREATE TABLE dive_data_sources (
          id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          computer_id TEXT,
          is_primary INTEGER NOT NULL DEFAULT 0
        )
      ''');
      rawDb.execute(
        "INSERT INTO dive_data_sources VALUES "
        "('s1', 'd', 'suunto', 1), ('s2', 'd', 'garmin', 0), "
        "('s3', 'solo', 'suunto', 1), "
        "('s4', 'b', 'perdix', 1), ('s5', 'b', 'backup', 0)",
      );
      rawDb.execute(
        "INSERT INTO dive_tanks "
        "(id, dive_id, computer_id, o2_percent, he_percent, tank_order, "
        "tank_role) VALUES "
        "('air', 'd', 'suunto', 21, 0, 0, 'backGas'), "
        "('ean50', 'd', 'suunto', 50, 0, 1, 'deco'), "
        "('o2', 'd', 'garmin', 100, 0, 2, 'deco'), "
        "('solo-air', 'solo', 'suunto', 21, 0, 0, 'backGas'), "
        "('b-ean32', 'b', 'perdix', 32, 0, 0, 'backGas'), "
        "('b-ean50', 'b', 'perdix', 50, 0, 1, 'deco'), "
        "('b-air', 'b', 'backup', 21, 0, 2, 'backGas')",
      );
      for (final entry in recorded.entries) {
        rawDb.execute(
          "UPDATE dive_tanks SET shared_computer_ids = '${entry.value}' "
          "WHERE id = '${entry.key}'",
        );
      }
      if (badAirO2) {
        rawDb.execute(
          "UPDATE dive_tanks SET o2_percent = 'twenty-one' WHERE id = 'air'",
        );
      }
      rawDb.execute(
        "INSERT INTO tank_pressure_series VALUES "
        "('p1', 'b', 'b-ean32', NULL, 's5')",
      );
    },
  );

  Future<Map<String, String?>> sharedById(AppDatabase db) async => {
    for (final r
        in await db
            .customSelect(
              'SELECT id, shared_computer_ids FROM dive_tanks ORDER BY id',
            )
            .get())
      r.read<String>('id'): r.read<String?>('shared_computer_ids'),
  };

  // What inference leaves: the sharers, and the recorded-nobody marker on
  // every other cylinder of an inferred dive, so it is never guessed again.
  const inferred = {
    'air': '["garmin"]',
    'ean50': '["garmin"]',
    'o2': '[]',
    'solo-air': null,
    'b-ean32': '["backup"]',
    'b-ean50': '["backup"]',
    'b-air': '[]',
  };

  test('a v259 database gains the column and its consolidated dives are '
      'inferred', () async {
    final db = AppDatabase(consolidatedFixture());
    addTearDown(db.close);
    expect(await sharedById(db), inferred);
  });

  test('a consolidated dive that reaches a v260 database unrecorded (folded '
      'on an older peer, or synced into a fresh install) is inferred on '
      'open', () async {
    final db = AppDatabase(consolidatedFixture(version: 260));
    addTearDown(db.close);
    expect(await sharedById(db), inferred);
  });

  test('a dive a fold recorded is never guessed again', () async {
    // The fold found nobody to share dive d's cylinders, which inference
    // would have shared with the Garmin.
    final db = AppDatabase(
      consolidatedFixture(
        version: 260,
        recorded: const {'air': '[]', 'ean50': '[]', 'o2': '[]'},
      ),
    );
    addTearDown(db.close);
    expect(await sharedById(db), {
      ...inferred,
      'air': '[]',
      'ean50': '[]',
      'o2': '[]',
    });
  });

  test('a dive with only some cylinders recorded still has its unrecorded '
      'primary cylinders inferred', () async {
    // A peer's edit carried the Garmin's O2 row with a recorded value; the
    // merged 21% and 50% arrived from an older peer unrecorded.
    final db = AppDatabase(
      consolidatedFixture(version: 260, recorded: const {'o2': '[]'}),
    );
    addTearDown(db.close);
    expect(await sharedById(db), inferred);
  });

  test('a row the inference cannot read does not stop the database '
      'opening', () async {
    final db = AppDatabase(consolidatedFixture(version: 260, badAirO2: true));
    addTearDown(db.close);
    final shared = await sharedById(db);
    expect(shared, contains('air'));
    expect(shared['solo-air'], isNull);
  });
}

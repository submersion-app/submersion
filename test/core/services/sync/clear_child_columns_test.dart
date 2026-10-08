import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/bound_variables.dart';
import '../../../helpers/test_database.dart';

/// The write half of #2644: a peer's deliberate clears land as NULL on the
/// named nullable columns, and nothing else is touched.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    // Placeholder parents; this exercises the column write, not FKs.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
      "INSERT INTO dive_tanks (id, dive_id, volume, working_pressure, "
      "transmitter_serial, hlc) "
      "VALUES ('t1', 'd1', 11.1, 232.0, 'SER-1', '1000:0:a')",
    );
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Map<String, dynamic>> tank() async =>
      (await serializer.fetchRecord('diveTanks', 't1'))!;

  test('nulls the named nullable columns and leaves the rest', () async {
    await serializer.clearChildColumns('diveTanks', {
      't1': {'transmitterSerial', 'volume'},
    });
    final row = await tank();
    expect(row['transmitterSerial'], isNull);
    expect(row['volume'], isNull);
    expect(row['workingPressure'], 232.0);
    expect(row['hlc'], '1000:0:a');
  });

  test('ignores NOT NULL, key, clock and unknown keys', () async {
    await serializer.clearChildColumns('diveTanks', {
      't1': {'o2Percent', 'id', 'diveId', 'hlc', 'noSuchColumn'},
    });
    final row = await tank();
    expect(row['id'], 't1');
    expect(row['diveId'], 'd1');
    expect(row['hlc'], '1000:0:a');
    expect(row['transmitterSerial'], 'SER-1');
  });

  test('a composite-key child is matched on both key columns', () async {
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id, via_set_id) "
      "VALUES ('d1', 'e1', 's1'), ('d1', 'e2', 's1')",
    );
    await serializer.clearChildColumns('diveEquipment', {
      'd1|e1': {'viaSetId'},
    });
    final rows = await db
        .customSelect(
          'SELECT equipment_id, via_set_id FROM dive_equipment '
          'ORDER BY equipment_id',
        )
        .get();
    expect(rows.map((r) => r.read<String?>('via_set_id')), [null, 's1']);
  });

  test('an entity outside the parent-gated set is a no-op', () async {
    await serializer.clearChildColumns('dives', {
      't1': {'transmitterSerial'},
    });
    expect((await tank())['transmitterSerial'], 'SER-1');
  });

  test(
    'rows clearing the same columns share one statement per chunk',
    () async {
      // An adopt replays every tank row, and each carries explicit nulls; a
      // statement per row made a large adopt crawl.
      await tearDownTestDatabase();
      db = setUpLoggingTestDatabase();
      serializer = SyncDataSerializer();
      final ids = [for (var i = 0; i < 2000; i++) 'bt$i'];
      await quietly(() async {
        await db.customStatement('PRAGMA foreign_keys = OFF');
        await db.batch(
          (b) => b.insertAll(db.diveTanks, [
            for (final id in ids)
              DiveTanksCompanion.insert(
                id: id,
                diveId: 'd1',
                transmitterSerial: const Value('SER'),
              ),
          ]),
        );
      });

      var updates = 0;
      final most = await maxBoundVariables(
        () => runZoned(
          () => serializer.clearChildColumns('diveTanks', {
            for (final id in ids) id: {'transmitterSerial'},
          }),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) {
              if (line.startsWith('Drift: Sent UPDATE')) updates += 1;
              parent.print(zone, line);
            },
          ),
        ),
      );

      expect(updates, 3, reason: '2000 ids at 900 per statement');
      expect(most, lessThanOrEqualTo(sqliteVariableLimit));
      final left = await quietly(
        () => db
            .customSelect(
              'SELECT COUNT(*) AS n FROM dive_tanks '
              'WHERE transmitter_serial IS NOT NULL',
            )
            .getSingle(),
      );
      expect(left.read<int>('n'), 0);
    },
  );

  test(
    'clearableChildKeys names what a clear may touch, empty when nothing',
    () {
      expect(
        serializer.clearableChildKeys('diveTanks'),
        containsAll(<String>['transmitterSerial', 'computerId']),
      );
      expect(
        serializer.clearableChildKeys('diveTanks'),
        isNot(contains('hlc')),
      );
      // A junction with no nullable user column, and a type outside the set.
      expect(serializer.clearableChildKeys('diveDiveTypes'), isEmpty);
      expect(serializer.clearableChildKeys('dives'), isEmpty);
    },
  );

  test(
    'a composite-key clear binds two variables a row, within the limit',
    () async {
      await tearDownTestDatabase();
      db = setUpLoggingTestDatabase();
      serializer = SyncDataSerializer();
      final gear = [for (var i = 0; i < 1000; i++) 'ge$i'];
      await quietly(() async {
        await db.customStatement('PRAGMA foreign_keys = OFF');
        await db.batch(
          (b) => b.insertAll(db.diveEquipment, [
            for (final e in gear)
              DiveEquipmentCompanion.insert(
                diveId: 'd1',
                equipmentId: e,
                viaSetId: const Value('s1'),
              ),
          ]),
        );
      });

      var updates = 0;
      final most = await maxBoundVariables(
        () => runZoned(
          () => serializer.clearChildColumns('diveEquipment', {
            for (final e in gear) 'd1|$e': {'viaSetId'},
          }),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) {
              if (line.startsWith('Drift: Sent UPDATE')) updates += 1;
              parent.print(zone, line);
            },
          ),
        ),
      );

      expect(updates, 3, reason: '1000 pairs at 450 per statement');
      expect(most, lessThanOrEqualTo(sqliteVariableLimit));
      final left = await quietly(
        () => db
            .customSelect(
              'SELECT COUNT(*) AS n FROM dive_equipment '
              'WHERE via_set_id IS NOT NULL',
            )
            .getSingle(),
      );
      expect(left.read<int>('n'), 0);
    },
  );
}

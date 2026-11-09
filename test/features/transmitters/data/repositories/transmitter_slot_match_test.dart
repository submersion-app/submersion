import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show DiveTanksCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

import '../../../../helpers/test_database.dart';

/// Issue #4347: file-imported tanks with no serial match a registry entry by
/// computer, slot and date.
void main() {
  late TransmitterRepository repo;

  Transmitter entry({String serial = '180777'}) => Transmitter(
    id: 'tx',
    diverId: 'diver-1',
    transmitterSerial: serial,
    label: 'Left sidemount',
    role: TankRole.sidemountLeft,
    volumeL: 11.1,
    createdAt: DateTime.utc(2026, 9, 8),
    updatedAt: DateTime.utc(2026, 9, 8),
  );

  Future<void> computer(String id) =>
      DatabaseService.instance.database.customStatement(
        'INSERT OR IGNORE INTO dive_computers (id, name, connection_type, '
        "created_at, updated_at) VALUES ('$id', 'Perdix $id', 'ble', 1, 1)",
      );

  /// A dive on [computerId] at [date] with one tank: [serial] and [slot] as
  /// given, and a pressure series unless [series] is false.
  Future<void> dive(
    String id,
    DateTime date, {
    String computerId = 'perdix',
    String? serial,
    int? slot,
    bool series = true,
    String diverId = 'diver-1',
  }) async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'INSERT OR IGNORE INTO divers (id, name, created_at, updated_at) '
      "VALUES ('$diverId', 'A', 1, 1)",
    );
    await computer(computerId);
    await DiveRepository().createDive(
      domain.Dive(
        id: id,
        dateTime: date,
        diverId: diverId,
        computerId: computerId,
      ),
    );
    await db.customStatement(
      "UPDATE dives SET computer_id = '$computerId' WHERE id = '$id'",
    );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value('$id-t'),
            diveId: Value(id),
            transmitterSerial: Value(serial),
            transmitterSlot: Value(slot),
            tankOrder: const Value(0),
            tankRole: const Value('backGas'),
            o2Percent: const Value(21),
            hePercent: const Value(0),
          ),
        );
    if (series) {
      await TankPressureRepository().insertTankPressures(id, {
        '$id-t': [(timestamp: 0, pressure: 200.0)],
      });
    }
  }

  final mar = DateTime.utc(2026, 3, 12, 9);
  final jun = DateTime.utc(2026, 6, 1, 9);

  setUp(() async {
    await setUpTestDatabase();
    repo = TransmitterRepository();
  });
  tearDown(tearDownTestDatabase);

  test('a slot tank after a download that showed the serial is a candidate, '
      'one without a pressure series is not', () async {
    await dive('bt', mar, serial: '180777', slot: 1);
    await dive('cloud', DateTime.utc(2026, 4, 1), slot: 1);
    await dive('plain', DateTime.utc(2026, 4, 2), slot: 1, series: false);

    final preview = await repo.previewSlotMatches(entry());
    expect(preview.tankIds(includeOlder: true), {'cloud-t'});
    expect(preview.candidates.single.olderThanFirstDownload, isFalse);
  });

  test('a dive older than every download is flagged with its date', () async {
    await dive('bt', mar, serial: '180777', slot: 1);
    await dive('old', DateTime.utc(2025, 11, 1), slot: 1);

    final preview = await repo.previewSlotMatches(entry());
    final c = preview.candidates.single;
    expect(c.olderThanFirstDownload, isTrue);
    expect(c.firstDownload, mar);
    expect(preview.tankIds(includeOlder: true), {'old-t'});
    expect(preview.tankIds(includeOlder: false), isEmpty);
    expect(preview.diveIds(includeOlder: false), isEmpty);
  });

  test('a slot that changed hands around the dive is skipped', () async {
    await dive('bt1', mar, serial: '180777', slot: 1);
    await dive('bt2', jun, serial: '999999', slot: 1);
    await dive('mid', DateTime.utc(2026, 5, 1), slot: 1);

    final preview = await repo.previewSlotMatches(entry());
    expect(preview.candidates, isEmpty);
    expect(preview.changedHandsDiveIds, {'mid'});
  });

  test('a slot that changed hands between two other transmitters is not '
      'counted against this one', () async {
    await dive('bt', mar, serial: '180777', slot: 1);
    await dive('s2-a', mar, serial: '222222', slot: 2);
    await dive('s2-b', jun, serial: '333333', slot: 2);
    await dive('mid', DateTime.utc(2026, 5, 1), slot: 2);

    final preview = await repo.previewSlotMatches(entry());
    expect(preview.candidates, isEmpty);
    expect(preview.changedHandsDiveIds, isEmpty);
  });

  test('another diver with the same serial stays out of the preview', () async {
    await dive('bt', mar, serial: '180777', slot: 1);
    await dive('cloud', jun, slot: 1);
    await dive('bt-2', mar, serial: '180777', slot: 1, diverId: 'diver-2');
    await dive('cloud-2', jun, slot: 1, diverId: 'diver-2');

    final preview = await repo.previewSlotMatches(entry());
    expect(preview.tankIds(includeOlder: true), {'cloud-t'});
    expect(await repo.computersForSerial('180777', diverId: 'diver-2'), {
      'perdix',
    });
  });

  test(
    'apply writes no other diver\'s tank even when its id is given',
    () async {
      await dive('bt', mar, serial: '180777', slot: 1);
      await dive('cloud-2', jun, slot: 1, diverId: 'diver-2');

      await repo.applyToExistingDives(entry(), slotTankIds: {'cloud-2-t'});
      final db = DatabaseService.instance.database;
      final row = await (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals('cloud-2-t'))).getSingle();
      expect(row.volume, isNull);
      expect(row.tankName, isNull);
    },
  );

  test('two computers sharing the transmitter keep their own slots', () async {
    await dive('bt-a', mar, serial: '180777', slot: 1);
    await dive('bt-b', mar, computerId: 'petrel', serial: '180777', slot: 2);
    await dive('cloud-a', jun, slot: 1);
    await dive('cloud-b', jun, computerId: 'petrel', slot: 1);

    final preview = await repo.previewSlotMatches(entry());
    expect(preview.tankIds(includeOlder: true), {'cloud-a-t'});
  });

  test('given computer ids scope the preview without a second scan', () async {
    await dive('bt-a', mar, serial: '180777', slot: 1);
    await dive('bt-b', mar, computerId: 'petrel', serial: '180777', slot: 1);
    await dive('cloud-a', jun, slot: 1);
    await dive('cloud-b', jun, computerId: 'petrel', slot: 1);

    final preview = await repo.previewSlotMatches(
      entry(),
      computerIds: {'petrel'},
    );
    expect(preview.tankIds(includeOlder: true), {'cloud-b-t'});
  });

  test(
    'a slot tank on a computer no download observed is no candidate',
    () async {
      await dive('bt', mar, serial: '180777', slot: 1);
      await dive('other', jun, computerId: 'teric', slot: 1);

      final preview = await repo.previewSlotMatches(entry());
      expect(preview.candidates, isEmpty);
    },
  );

  test(
    'a tank with neither serial nor slot counts as no slot information',
    () async {
      await dive('bt', mar, serial: '180777', slot: 1);
      await dive('legacy', jun);

      final preview = await repo.previewSlotMatches(entry());
      expect(preview.noSlotDiveIds, {'legacy'});
    },
  );

  test('an entry with no serial previews nothing', () async {
    await dive('bt', mar, serial: '180777', slot: 1);
    await dive('cloud', jun, slot: 1);
    final preview = await repo.previewSlotMatches(
      entry().copyWith(clearTransmitterSerial: true),
    );
    expect(preview.candidates, isEmpty);
  });

  test('apply fills the given slot tanks and never writes a serial', () async {
    await dive('bt', mar, serial: '180777', slot: 1);
    await dive('cloud', jun, slot: 1);
    await dive('other', jun, serial: '555', slot: 1);

    final result = await repo.applyToExistingDives(
      entry(),
      slotTankIds: {'cloud-t', 'other-t'},
    );

    final db = DatabaseService.instance.database;
    final rows = {for (final r in await db.select(db.diveTanks).get()) r.id: r};
    expect(rows['cloud-t']!.volume, 11.1);
    expect(rows['cloud-t']!.tankRole, 'sidemountLeft');
    expect(rows['cloud-t']!.transmitterSerial, isNull);
    // A tank that carries another serial is never touched.
    expect(rows['other-t']!.volume, isNull);
    expect(result.divesUpdated, 2);
  });

  test('apply without slot ids matches by serial only, as before', () async {
    await dive('bt', mar, serial: '180777', slot: 1);
    await dive('cloud', jun, slot: 1);

    final result = await repo.applyToExistingDives(entry());
    expect(result.divesUpdated, 1);
    final db = DatabaseService.instance.database;
    final cloud = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('cloud-t'))).getSingle();
    expect(cloud.volume, isNull);
  });
}

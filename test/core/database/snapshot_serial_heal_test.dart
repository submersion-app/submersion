import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/snapshot_serial_heal.dart';

import '../../helpers/test_database.dart';

/// Issue #4368: the serial a download copies onto its source row and dive
/// was empty on a computer's first download (the serial arrives only when
/// the download completes) and stayed decimal after #3106 rewrote only the
/// computer record, so one Shearwater showed three serials in the "Data
/// sources" table.
void main() {
  late AppDatabase db;

  const nowMs = 1750000000000;
  final now = DateTime.fromMillisecondsSinceEpoch(nowMs);

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertComputer(
    String id, {
    String? manufacturer = 'Shearwater',
    String? model = 'Teric',
    String? serial,
  }) async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value('Computer $id'),
            manufacturer: Value(manufacturer),
            model: Value(model),
            serialNumber: Value(serial),
            createdAt: const Value(nowMs),
            updatedAt: const Value(nowMs),
          ),
        );
  }

  Future<void> insertDive(
    String id, {
    String? computerId,
    String? serial,
    String? model,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: const Value(nowMs),
            computerId: Value(computerId),
            diveComputerSerial: Value(serial),
            diveComputerModel: Value(model),
            hlc: const Value('dive-hlc'),
            createdAt: const Value(nowMs),
            updatedAt: const Value(5),
          ),
        );
  }

  Future<void> insertSource(
    String id, {
    required String diveId,
    String? computerId,
    String? serial,
    String? model = 'Shearwater Teric',
    String? descriptorVendor,
    String sourceFormat = 'dive_computer',
  }) async {
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: id,
            diveId: diveId,
            computerId: Value(computerId),
            computerModel: Value(model),
            computerSerial: Value(serial),
            sourceFormat: Value(sourceFormat),
            descriptorVendor: Value(descriptorVendor),
            hlc: const Value('source-hlc'),
            importedAt: now,
            createdAt: now,
          ),
        );
  }

  Future<DiveDataSourcesData> source(String id) => (db.select(
    db.diveDataSources,
  )..where((t) => t.id.equals(id))).getSingle();

  Future<Dive> dive(String id) =>
      (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

  group('sources linked to a computer', () {
    test('an empty serial takes the computer\'s, for any brand, with no '
        'sync stamp', () async {
      await insertComputer('sw', serial: '8629AC48');
      await insertComputer(
        'ratio',
        manufacturer: 'Ratio',
        model: 'iX3M 2',
        serial: '74691',
      );
      await insertDive('d1');
      await insertSource('s1', diveId: 'd1', computerId: 'sw');
      await insertSource('s2', diveId: 'd1', computerId: 'ratio', serial: '');

      expect(await healDownloadedSnapshotSerials(db), 2);

      final s1 = await source('s1');
      expect(s1.computerSerial, '8629AC48');
      expect(s1.hlc, 'source-hlc');
      expect((await source('s2')).computerSerial, '74691');
    });

    test('a decimal Shearwater serial takes the computer\'s hex', () async {
      // 0x8629AC48 == 2250878024
      await insertComputer('sw', serial: '8629AC48');
      await insertDive('d1');
      await insertSource(
        's1',
        diveId: 'd1',
        computerId: 'sw',
        serial: '2250878024',
      );

      expect(await healDownloadedSnapshotSerials(db), 1);
      expect((await source('s1')).computerSerial, '8629AC48');
    });

    test('an 8-digit decimal is settled by the computer\'s spelling, and a '
        'second run does nothing', () async {
      // 0x00BC614E == 12345678; 0x12345678 == 305419896.
      await insertComputer('a', serial: '00BC614E');
      await insertComputer('b', serial: '12345678');
      await insertDive('d1');
      await insertSource(
        's1',
        diveId: 'd1',
        computerId: 'a',
        serial: '12345678',
      );
      await insertSource(
        's2',
        diveId: 'd1',
        computerId: 'b',
        serial: '305419896',
      );
      await insertSource(
        's3',
        diveId: 'd1',
        computerId: 'b',
        serial: '12345678',
      );

      expect(await healDownloadedSnapshotSerials(db), 2);
      expect(await healDownloadedSnapshotSerials(db), 0);
      expect((await source('s1')).computerSerial, '00BC614E');
      expect((await source('s2')).computerSerial, '12345678');
      expect((await source('s3')).computerSerial, '12345678');
    });

    test('a serial naming another unit is kept', () async {
      await insertComputer('sw', serial: '8629AC48');
      await insertDive('d1');
      await insertSource(
        's1',
        diveId: 'd1',
        computerId: 'sw',
        serial: '8C4FE663',
      );

      expect(await healDownloadedSnapshotSerials(db), 0);
      expect((await source('s1')).computerSerial, '8C4FE663');
    });

    test('another unit\'s serial still in decimal is kept, in hex', () async {
      // 0x8C4FE663 == 2354046563: not the linked computer, but a Shearwater
      // download, so only its spelling changes.
      await insertComputer('sw', serial: '8629AC48');
      await insertDive('d1');
      await insertSource(
        's1',
        diveId: 'd1',
        computerId: 'sw',
        serial: '2354046563',
      );

      expect(await healDownloadedSnapshotSerials(db), 1);
      expect(await healDownloadedSnapshotSerials(db), 0);
      expect((await source('s1')).computerSerial, '8C4FE663');
    });

    test('a file import\'s source is not a download\'s copy and is left '
        'alone', () async {
      await insertComputer('sw', serial: '8629AC48');
      await insertDive('d1');
      await insertSource(
        's1',
        diveId: 'd1',
        computerId: 'sw',
        sourceFormat: 'shearwater_cloud',
      );

      expect(await healDownloadedSnapshotSerials(db), 0);
      expect((await source('s1')).computerSerial, isNull);
    });

    test('scoped to one computer, another computer\'s rows wait', () async {
      await insertComputer('a', serial: '8629AC48');
      await insertComputer('b', serial: '8C4FE663');
      await insertDive('d1');
      await insertSource('s1', diveId: 'd1', computerId: 'a');
      await insertSource('s2', diveId: 'd1', computerId: 'b');

      expect(await healDownloadedSnapshotSerials(db, computerId: 'a'), 1);
      expect((await source('s1')).computerSerial, '8629AC48');
      expect((await source('s2')).computerSerial, isNull);
    });
  });

  group('sources with no computer to compare against', () {
    test('a downloaded Shearwater decimal becomes hex; 8 digits and other '
        'brands stay', () async {
      await insertDive('d1');
      await insertSource(
        's1',
        diveId: 'd1',
        serial: '2250878024',
        descriptorVendor: 'Shearwater',
      );
      await insertSource('s2', diveId: 'd1', serial: '12345678');
      await insertSource(
        's3',
        diveId: 'd1',
        serial: '2250878024',
        model: 'Ratio iX3M 2',
        descriptorVendor: 'Ratio',
      );

      expect(await healDownloadedSnapshotSerials(db), 1);
      expect(await healDownloadedSnapshotSerials(db), 0);
      expect((await source('s1')).computerSerial, '8629AC48');
      expect((await source('s2')).computerSerial, '12345678');
      expect((await source('s3')).computerSerial, '2250878024');
    });
  });

  group('dives', () {
    test('a downloaded dive takes its computer\'s serial, without a sync '
        'stamp', () async {
      await insertComputer('sw', serial: '8629AC48');
      await insertDive('empty', computerId: 'sw');
      await insertSource('s1', diveId: 'empty', computerId: 'sw');
      await insertDive('decimal', computerId: 'sw', serial: '2250878024');
      await insertSource('s2', diveId: 'decimal', computerId: 'sw');

      await healDownloadedSnapshotSerials(db);

      final empty = await dive('empty');
      expect(empty.diveComputerSerial, '8629AC48');
      expect(empty.hlc, 'dive-hlc');
      expect(empty.updatedAt, 5);
      expect((await dive('decimal')).diveComputerSerial, '8629AC48');
    });

    test('a dive with no download from that computer is left alone', () async {
      await insertComputer('sw', serial: '8629AC48');
      await insertDive('d1', computerId: 'sw');
      await insertSource(
        's1',
        diveId: 'd1',
        computerId: 'sw',
        sourceFormat: 'uddf',
      );

      await healDownloadedSnapshotSerials(db);
      expect((await dive('d1')).diveComputerSerial, isNull);
    });

    test('a downloaded Shearwater dive with no computer serial converts its '
        'decimal', () async {
      await insertDive('d1', serial: '2250878024', model: 'Teric');
      await insertSource('s1', diveId: 'd1');
      await insertDive('d2', serial: '12345678', model: 'Teric');
      await insertSource('s2', diveId: 'd2');

      await healDownloadedSnapshotSerials(db);
      expect((await dive('d1')).diveComputerSerial, '8629AC48');
      expect((await dive('d2')).diveComputerSerial, '12345678');
    });
  });
}

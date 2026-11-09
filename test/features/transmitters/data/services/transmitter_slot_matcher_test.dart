import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_tank_ref_router.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';
import 'package:submersion/features/dive_import/data/services/stored_source_dive_finder.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_slot_matcher.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

import '../../../../helpers/test_database.dart';

/// Answers [findMany] from a fixed map, standing in for the stored files.
class _FakeFinder extends StoredSourceDiveFinder {
  _FakeFinder(this.parsed) : super(db: DatabaseService.instance.database);

  final Map<String, Map<String, dynamic>> parsed;

  @override
  Future<Map<String, Map<String, dynamic>>> findMany(
    Iterable<String> diveIds,
  ) async => {for (final id in diveIds) id: ?parsed[id]};
}

Transmitter _entry({String? serial = '180777', String diverId = 'diver-1'}) =>
    Transmitter(
      id: 't1',
      diverId: diverId,
      transmitterSerial: serial,
      diveComputerId: serial == null ? 'c1' : null,
      channelIndex: serial == null ? 0 : null,
      label: 'Sidemount left',
      role: TankRole.sidemountLeft,
      volumeL: 10,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

/// The two Cloud cylinders of dive u1 as the stored file parses them.
Map<String, dynamic> _parsedU1() => {
  'tanks': [
    {'startPressure': 200.5, 'endPressure': 128.8, kUddfSourceSlotKey: 2},
    {'startPressure': 219.5, 'endPressure': 142.4, kUddfSourceSlotKey: 3},
  ],
};

/// Matching serial-less cylinders by computer slot (issue #4347).
void main() {
  AppDatabase db() => DatabaseService.instance.database;

  setUp(() async {
    await setUpTestDatabase();
    await db().customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) VALUES "
      "('diver-1', 'A', 1, 1), ('diver-2', 'B', 1, 1)",
    );
    await db().customStatement(
      "INSERT INTO dive_computers (id, name, connection_type, created_at, "
      "updated_at) VALUES ('c1', 'Perdix', 'ble', 1, 1), "
      "('c2', 'Teric', 'ble', 1, 1)",
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> seedDive(
    String id, {
    String computer = 'c1',
    String diverId = 'diver-1',
    String? importedFileId = 'f1',
    DateTime? at,
    double maxDepth = 18,
    int runtime = 2400,
  }) async {
    final when = at ?? DateTime.utc(2026, 9, 1, 10);
    await db()
        .into(db().dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: Value(diverId),
            computerId: Value(computer),
            diveDateTime: when.millisecondsSinceEpoch,
            maxDepth: Value(maxDepth),
            runtime: Value(runtime),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    if (importedFileId == null) return;
    await db()
        .into(db().diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-$id',
            diveId: id,
            isPrimary: const Value(true),
            importedAt: when,
            createdAt: when,
            sourceFileFormat: const Value('uddf'),
            importedFileId: Value(importedFileId),
          ),
        );
  }

  Future<void> seedTank(
    String id,
    String diveId, {
    String? serial,
    String? computer,
    double? start,
    double? end,
    double? volume,
    String role = 'backGas',
    String? name,
  }) => db()
      .into(db().diveTanks)
      .insert(
        DiveTanksCompanion.insert(
          id: id,
          diveId: diveId,
          transmitterSerial: Value(serial),
          computerId: Value(computer),
          startPressure: Value(start),
          endPressure: Value(end),
          volume: Value(volume),
          tankRole: Value(role),
          tankName: Value(name),
        ),
      );

  /// A Bluetooth download on c1 that showed the serial, and the Cloud dive
  /// u1 with its two serial-less cylinders.
  Future<void> seedPerdixHistory() async {
    await seedDive('dl', importedFileId: null);
    await seedTank('dl-t', 'dl', serial: '180777', computer: 'c1');
    await seedDive('u1');
    await seedTank('a', 'u1', start: 200.5, end: 128.8);
    await seedTank('b', 'u1', start: 219.5, end: 142.4);
  }

  TransmitterSlotMatcher matcher([Map<String, Map<String, dynamic>>? files]) =>
      TransmitterSlotMatcher(finder: _FakeFinder(files ?? {'u1': _parsedU1()}));

  test('offers nothing for an entry without a serial', () async {
    await seedPerdixHistory();

    final computers = await matcher().computersWithCandidates(
      _entry(serial: null),
    );

    expect(computers, isEmpty);
  });

  test('finds the computers the serial was downloaded on', () async {
    await seedPerdixHistory();

    final computers = await matcher().computersWithCandidates(_entry());

    expect(computers.map((c) => (c.computerId, c.computerName)), [
      ('c1', 'Perdix'),
    ]);
  });

  test('skips a dive that already carries the serial', () async {
    await seedPerdixHistory();
    await seedTank('c', 'u1', serial: '180777');

    expect(await matcher().computersWithCandidates(_entry()), isEmpty);
  });

  test('skips a dive on another computer', () async {
    await seedDive('dl', importedFileId: null);
    await seedTank('dl-t', 'dl', serial: '180777', computer: 'c1');
    await seedDive('u1', computer: 'c2');
    await seedTank('a', 'u1', start: 200.5, end: 128.8);

    expect(await matcher().computersWithCandidates(_entry()), isEmpty);
  });

  test('skips a dive without a stored file', () async {
    await seedDive('dl', importedFileId: null);
    await seedTank('dl-t', 'dl', serial: '180777', computer: 'c1');
    await seedDive('u1', importedFileId: null);
    await seedTank('a', 'u1', start: 200.5, end: 128.8);

    expect(await matcher().computersWithCandidates(_entry()), isEmpty);
  });

  test("skips another diver's dive", () async {
    await seedDive('dl', importedFileId: null);
    await seedTank('dl-t', 'dl', serial: '180777', computer: 'c1');
    await seedDive('u1', diverId: 'diver-2');
    await seedTank('a', 'u1', start: 200.5, end: 128.8);

    expect(await matcher().computersWithCandidates(_entry()), isEmpty);
  });

  test('pairs parsed and stored cylinders by pressures and gas', () async {
    await seedPerdixHistory();

    final resolved = await matcher().resolve(_entry());

    expect(resolved, hasLength(1));
    expect(resolved.single.computer.computerId, 'c1');
    expect(resolved.single.tankIdsBySlot, {
      2: ['a'],
      3: ['b'],
    });
    expect(resolved.single.divesFor(2), 1);
    expect(resolved.single.divesFor(1), 0);
  });

  test('skips a cylinder whose pressures were edited after import', () async {
    await seedDive('dl', importedFileId: null);
    await seedTank('dl-t', 'dl', serial: '180777', computer: 'c1');
    await seedDive('u1');
    await seedTank('a', 'u1', start: 190, end: 128.8);
    await seedTank('b', 'u1', start: 219.5, end: 142.4);

    final resolved = await matcher().resolve(_entry());

    expect(resolved.single.tankIdsBySlot, {
      3: ['b'],
    });
  });

  test('skips a cylinder that pairs with two stored cylinders', () async {
    await seedPerdixHistory();
    await seedTank('a2', 'u1', start: 200.5, end: 128.8);

    final resolved = await matcher().resolve(_entry());

    expect(resolved.single.tankIdsBySlot.containsKey(2), isFalse);
    expect(resolved.single.tankIdsBySlot[3], ['b']);
  });

  test('skips cylinders the fill would not change', () async {
    await seedDive('dl', importedFileId: null);
    await seedTank('dl-t', 'dl', serial: '180777', computer: 'c1');
    await seedDive('u1');
    await seedTank(
      'a',
      'u1',
      start: 200.5,
      end: 128.8,
      volume: 10,
      role: 'sidemountLeft',
      name: 'Sidemount left',
    );
    await seedTank('b', 'u1', start: 219.5, end: 142.4);

    final resolved = await matcher().resolve(_entry());

    expect(resolved.single.tankIdsBySlot, {
      3: ['b'],
    });
  });

  test('reads the slots from a real stored Shearwater Cloud file', () async {
    const uddf = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2025-09-01T14:18:24Z</datetime>
        </informationbeforedive>
        <tankdata>
          <tankpressurebegin>0</tankpressurebegin>
          <tankpressureend>0</tankpressureend>
        </tankdata>
        <tankdata>
          <tankpressurebegin>20049962</tankpressurebegin>
          <tankpressureend>12879411</tankpressureend>
        </tankdata>
        <tankdata>
          <tankpressurebegin>21952916</tankpressurebegin>
          <tankpressureend>14244574</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <depth>1</depth>
            <divetime>0</divetime>
            <tankpressure ref="T3">21952916</tankpressure>
          </waypoint>
          <waypoint>
            <depth>18</depth>
            <divetime>2400</divetime>
            <tankpressure ref="T2">20049962</tankpressure>
            <tankpressure ref="T3">21939126</tankpressure>
          </waypoint>
        </samples>
        <informationafterdive>
          <greatestdepth>18</greatestdepth>
          <diveduration>2400</diveduration>
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';
    final fileId = await ImportedFileRepository().store(
      bytes: Uint8List.fromList(utf8.encode(uddf)),
      fileName: 'cloud.uddf',
    );
    await seedDive('dl', importedFileId: null);
    await seedTank('dl-t', 'dl', serial: '180777', computer: 'c1');
    await seedDive(
      'u1',
      importedFileId: fileId,
      at: DateTime.utc(2025, 9, 1, 14, 18, 24),
    );
    await seedTank('t2', 'u1', start: 200.49962, end: 128.79411);
    await seedTank('t3', 'u1', start: 219.52916, end: 142.44574);

    final resolved = await TransmitterSlotMatcher().resolve(_entry());

    expect(resolved.single.tankIdsBySlot, {
      2: ['t2'],
      3: ['t3'],
    });
  });
}

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_computer/data/repositories/dive_computer_connection_repository.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3106: a file import records the format it came from as one of the
/// computer's connections, on the same record a download registered.
void main() {
  late AppDatabase db;
  late UddfEntityImporter importer;
  late ImportRepositories repos;
  const diverId = 'diver-1';

  setUp(() async {
    db = await setUpTestDatabase();
    importer = UddfEntityImporter();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: const Value(diverId),
            name: const Value('Test Diver'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    repos = ImportRepositories(
      tripRepository: TripRepository(),
      equipmentRepository: EquipmentRepository(),
      equipmentSetRepository: EquipmentSetRepository(),
      buddyRepository: BuddyRepository(),
      diveCenterRepository: DiveCenterRepository(),
      certificationRepository: CertificationRepository(),
      tagRepository: TagRepository(),
      diveTypeRepository: DiveTypeRepository(),
      siteRepository: SiteRepository(),
      diveRepository: DiveRepository(),
      tankPressureRepository: TankPressureRepository(),
      courseRepository: CourseRepository(),
      diveComputerRepository: DiveComputerRepository(),
      diveComputerConnectionRepository: DiveComputerConnectionRepository(),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Map<String, dynamic> diveEntry({
    required int day,
    String? model,
    String? serial,
    String? firmware,
    String? manufacturer,
  }) => {
    'dateTime': DateTime(2024, 3, day, 10),
    'maxDepth': 30.0,
    'diveComputerModel': model,
    'diveComputerSerial': serial,
    'diveComputerFirmware': firmware,
    'diveComputerManufacturer': manufacturer,
  };

  Future<UddfEntityImportResult> runImport(
    List<Map<String, dynamic>> dives, {
    ImportFormat? format,
  }) => importer.import(
    data: UddfImportResult(dives: dives),
    selections: UddfImportSelections(
      dives: {for (var i = 0; i < dives.length; i++) i},
    ),
    repositories: repos,
    diverId: diverId,
    sourceFormat: format,
  );

  test('a FIT file records one fit connection on its computer', () async {
    await runImport([
      diveEntry(day: 1, model: 'Descent Mk3', serial: '3412345678'),
      diveEntry(day: 2, model: 'Descent Mk3', serial: '3412345678'),
      diveEntry(day: 3, model: 'Descent Mk3', serial: '3412345678'),
    ], format: ImportFormat.fit);

    final computer = (await db.select(db.diveComputers).get()).single;
    final connections = await db.select(db.diveComputerConnections).get();
    expect(connections, hasLength(1));
    expect(connections.single.computerId, computer.id);
    expect(connections.single.kind, 'file');
    expect(connections.single.detail, 'fit');
  });

  test('a Shearwater export lands on the computer a BLE download '
      'registered, which then has both connections', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: const Value('ble'),
            diverId: const Value(diverId),
            name: const Value('Shearwater Perdix 2'),
            manufacturer: const Value('Shearwater'),
            model: const Value('Perdix 2'),
            serialNumber: const Value('2712847316'),
            connectionType: const Value('bluetooth'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await DiveComputerConnectionRepository().recordConnection(
      computerId: 'ble',
      kind: DiveComputerConnectionKind.ble,
      address: 'AA:BB',
    );

    await runImport([
      diveEntry(
        day: 1,
        model: 'Perdix 2',
        serial: 'A1B2C3D4',
        manufacturer: 'Shearwater',
      ),
    ], format: ImportFormat.shearwaterDb);

    final computers = await db.select(db.diveComputers).get();
    expect(computers.map((c) => c.id), ['ble']);
    final connections = await db.select(db.diveComputerConnections).get();
    expect(
      connections.map((c) => (c.kind, c.detail)),
      unorderedEquals([('ble', null), ('file', 'shearwaterDb')]),
    );
  });

  test('every computer a multi-computer dive was worn with records the '
      'file format', () async {
    await runImport([
      {
        ...diveEntry(day: 1, model: 'Perdix', serial: 'SN-A'),
        'additionalComputers': [
          {
            'diveComputerModel': 'Teric',
            'diveComputerSerial': 'SN-B',
            'maxDepth': 29.5,
          },
        ],
      },
    ], format: ImportFormat.subsurfaceXml);

    final computers = await db.select(db.diveComputers).get();
    expect(computers, hasLength(2));
    final connections = await db.select(db.diveComputerConnections).get();
    expect(
      connections.map((c) => (c.computerId, c.kind, c.detail)),
      unorderedEquals([
        for (final c in computers) (c.id, 'file', 'subsurfaceXml'),
      ]),
    );
  });

  test('dives without a registered computer record no connection', () async {
    await runImport([diveEntry(day: 1)], format: ImportFormat.fit);
    expect(await db.select(db.diveComputerConnections).get(), isEmpty);
  });
}

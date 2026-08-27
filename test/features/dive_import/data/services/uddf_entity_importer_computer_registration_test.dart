import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/imported_computer_identity.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart'
    as domain;
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1288: a logbook built from a file import named a dive computer on
/// every dive's Details card, yet Dives > Filter still read "No dive
/// computers registered" and offered nothing to filter by. The importer wrote
/// only the `dive_computer_model`/`_serial` display snapshots and never
/// registered a `dive_computers` row, which is what the filter reads.
///
/// These run against a real in-memory database rather than mocks: the bug was
/// the absence of a write, so only the persisted rows prove the fix.
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

  Future<UddfEntityImportResult> runImport(List<Map<String, dynamic>> dives) =>
      importer.import(
        data: UddfImportResult(dives: dives),
        selections: UddfImportSelections(
          dives: {for (var i = 0; i < dives.length; i++) i},
        ),
        repositories: repos,
        diverId: diverId,
      );

  test('registers one computer for dives naming the same device', () async {
    final result = await runImport([
      diveEntry(day: 1, model: 'Perdix 2', serial: 'SN-1'),
      diveEntry(day: 2, model: 'Perdix 2', serial: 'SN-1'),
    ]);

    expect(result.dives, 2);

    final computers = await db.select(db.diveComputers).get();
    expect(computers, hasLength(1));
    expect(computers.single.model, 'Perdix 2');
    expect(computers.single.serialNumber, 'SN-1');
    expect(computers.single.diverId, diverId);
  });

  test('stamps computer_id on every imported dive', () async {
    await runImport([
      diveEntry(day: 1, model: 'Perdix 2', serial: 'SN-1'),
      diveEntry(day: 2, model: 'Perdix 2', serial: 'SN-1'),
    ]);

    final computer = (await db.select(db.diveComputers).get()).single;
    final dives = await db.select(db.dives).get();
    expect(dives, hasLength(2));
    expect(dives.every((d) => d.computerId == computer.id), isTrue);
    // The display snapshots stay: they are what the Details card renders
    // when no computer is registered, and what exports carry.
    expect(dives.every((d) => d.diveComputerModel == 'Perdix 2'), isTrue);
  });

  test('stamps computer_id on the provenance row', () async {
    await runImport([diveEntry(day: 1, model: 'Perdix 2', serial: 'SN-1')]);

    final computer = (await db.select(db.diveComputers).get()).single;
    final source = (await db.select(db.diveDataSources).get()).single;
    expect(source.computerId, computer.id);
  });

  test('registers a computer per distinct device in one file', () async {
    await runImport([
      diveEntry(day: 1, model: 'Perdix 2', serial: 'SN-1'),
      diveEntry(day: 2, model: 'Teric', serial: 'SN-2'),
    ]);

    final computers = await db.select(db.diveComputers).get();
    expect(computers, hasLength(2));
    expect(computers.map((c) => c.model).toSet(), {'Perdix 2', 'Teric'});
  });

  test(
    'registers a computer when the file gives a model but no serial',
    () async {
      await runImport([diveEntry(day: 1, model: 'Suunto D5')]);

      final computer = (await db.select(db.diveComputers).get()).single;
      expect(computer.serialNumber, isNull);
      expect(computer.model, 'Suunto D5');
      expect((await db.select(db.dives).get()).single.computerId, computer.id);
    },
  );

  test('records the manufacturer when the file supplies one', () async {
    await runImport([
      diveEntry(day: 1, model: 'Perdix 2', manufacturer: 'Shearwater'),
    ]);

    final computer = (await db.select(db.diveComputers).get()).single;
    expect(computer.manufacturer, 'Shearwater');
    expect(computer.name, 'Shearwater Perdix 2');
  });

  test('records the firmware the file reports', () async {
    await runImport([
      diveEntry(day: 1, model: 'Perdix 2', serial: 'SN-1', firmware: '92'),
    ]);

    expect(
      (await db.select(db.diveComputers).get()).single.firmwareVersion,
      '92',
    );
  });

  test('leaves dives unattributed when the file names no computer', () async {
    await runImport([diveEntry(day: 1)]);

    expect(await db.select(db.diveComputers).get(), isEmpty);
    expect((await db.select(db.dives).get()).single.computerId, isNull);
  });

  test(
    'reuses an already registered computer instead of duplicating it',
    () async {
      await runImport([diveEntry(day: 1, model: 'Perdix 2', serial: 'SN-1')]);
      await runImport([diveEntry(day: 5, model: 'Perdix 2', serial: 'SN-1')]);

      final computers = await db.select(db.diveComputers).get();
      expect(computers, hasLength(1));
      final dives = await db.select(db.dives).get();
      expect(dives, hasLength(2));
      expect(dives.every((d) => d.computerId == computers.single.id), isTrue);
    },
  );

  test(
    'registers at the deterministic id so a synced fleet converges',
    () async {
      await runImport([diveEntry(day: 1, model: 'Perdix 2', serial: 'SN-1')]);

      expect(
        (await db.select(db.diveComputers).get()).single.id,
        importedDiveComputerId(
          diverId: diverId,
          model: 'Perdix 2',
          serialNumber: 'SN-1',
        ),
      );
    },
  );

  test(
    'the query behind the filter dropdown finds the imported computer',
    () async {
      await runImport([diveEntry(day: 1, model: 'Perdix 2', serial: 'SN-1')]);

      // allDiveComputersProvider, which the Dives > Filter dropdown builds its
      // list from, is exactly this call. Coming back empty is what rendered
      // "No dive computers registered" while every dive showed a computer.
      final computers = await DiveComputerRepository().getAllComputers(
        diverId: diverId,
      );

      expect(computers, hasLength(1));
      expect(computers.single.model, 'Perdix 2');
    },
  );

  test('a registration failure does not abort the import', () async {
    // Attribution is cosmetic next to the dives themselves: a registry
    // problem must degrade to "unattributed", never cost the user the
    // logbook they were importing.
    final result = await importer.import(
      data: UddfImportResult(
        dives: [diveEntry(day: 1, model: 'Perdix 2', serial: 'SN-1')],
      ),
      selections: const UddfImportSelections(dives: {0}),
      repositories: ImportRepositories(
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
        diveComputerRepository: _FailingComputerRepository(),
      ),
      diverId: diverId,
    );

    expect(result.dives, 1);
    final dives = await db.select(db.dives).get();
    expect(dives, hasLength(1));
    expect(dives.single.computerId, isNull);
    // The display snapshot still lands, so the Details card is unaffected.
    expect(dives.single.diveComputerModel, 'Perdix 2');
  });

  test(
    'a failed attribution leaves the provenance link for the self-heal',
    () async {
      // Deliberately NOT symmetric: when the dive-level write fails, the
      // dive_data_sources.computer_id stamp is kept on purpose. The #1064
      // beforeOpen heal adopts dives.computer_id from exactly that column, so
      // the breadcrumb is what recovers the attribution on the next open.
      // Clearing it for tidiness would throw the recovery away.
      final result = await importer.import(
        data: UddfImportResult(
          dives: [diveEntry(day: 1, model: 'Perdix 2', serial: 'SN-1')],
        ),
        selections: const UddfImportSelections(dives: {0}),
        repositories: ImportRepositories(
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
          diveComputerRepository: _AttributionFailingComputerRepository(),
        ),
        diverId: diverId,
      );

      expect(result.dives, 1);
      final computer = (await db.select(db.diveComputers).get()).single;
      expect((await db.select(db.dives).get()).single.computerId, isNull);
      expect(
        (await db.select(db.diveDataSources).get()).single.computerId,
        computer.id,
      );

      // The next app open recovers it.
      await db.backfillDiveComputerIdsForTest();

      expect((await db.select(db.dives).get()).single.computerId, computer.id);
    },
  );

  test('adopts a computer already registered by a download', () async {
    // The download path stores vendor and product separately; the file
    // carries them as one string. The dive must join the existing device,
    // not fork a second record for it.
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: const Value('downloaded'),
            diverId: const Value(diverId),
            name: const Value('Shearwater Perdix 2'),
            manufacturer: const Value('Shearwater'),
            model: const Value('Perdix 2'),
            serialNumber: const Value('SN-1'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    await runImport([
      diveEntry(day: 1, model: 'Shearwater Perdix 2', serial: 'SN-1'),
    ]);

    expect(await db.select(db.diveComputers).get(), hasLength(1));
    expect((await db.select(db.dives).get()).single.computerId, 'downloaded');
  });
}

/// Stands in for a registry that cannot be written, to pin that the importer
/// treats attribution as best-effort.
class _FailingComputerRepository extends DiveComputerRepository {
  @override
  Future<domain.DiveComputer?> findOrRegisterImportedComputer({
    required String model,
    String? manufacturer,
    String? serialNumber,
    String? firmwareVersion,
    String? diverId,
  }) async => throw StateError('registry unavailable');
}

/// Registers normally but cannot write the dive-level attribution, to pin
/// that the provenance link survives for the #1064 self-heal.
class _AttributionFailingComputerRepository extends DiveComputerRepository {
  @override
  Future<void> attributeDiveToComputer({
    required String diveId,
    required String computerId,
  }) async => throw StateError('dives table unavailable');
}

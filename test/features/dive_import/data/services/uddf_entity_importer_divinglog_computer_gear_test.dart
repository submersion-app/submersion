import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_equipment_mapper.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

import '../../../../helpers/test_database.dart';

/// Issue #2299: a DiveLogDT import listed the diver's Shearwater Teric twice,
/// on every dive and in Equipment.
///
/// The dive's `Computer` column registers a dive computer, and registration
/// mints that computer's gear twin unless active `computer` gear with the same
/// identity already exists. The Equipment table's row for the same device
/// arrived first, but typed as a knife ("shear" inside "Shearwater") with no
/// model, so the twin never found it and a second item was minted and linked.
///
/// Runs against a real in-memory database: the bug was an extra persisted
/// row, so only the persisted rows prove the fix.
void main() {
  late AppDatabase db;
  late ImportRepositories repos;
  const diverId = 'diver-1';

  setUp(() async {
    db = await setUpTestDatabase();
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

  /// Imports [book] the way the wizard hands a Diving Log payload to the
  /// importer: gear from the equipment mapper, and each dive carrying its
  /// `Computer` value and its gear refs.
  Future<void> importLogbook(DivingLogLogbook book) async {
    final equipment = DivingLogEquipmentMapper.entities(book).values.toList();
    final dives = [
      for (final (i, raw) in book.dives.indexed)
        <String, dynamic>{
          'dateTime': DateTime(2024, 3, i + 1, 10),
          'maxDepth': 30.0,
          'diveComputerModel': ?raw.computer,
          'equipmentRefs': DivingLogEquipmentMapper.refsFor(book, raw),
        },
    ];
    await UddfEntityImporter().import(
      data: UddfImportResult(equipment: equipment, dives: dives),
      selections: UddfImportSelections(
        equipment: {for (var i = 0; i < equipment.length; i++) i},
        dives: {for (var i = 0; i < dives.length; i++) i},
      ),
      repositories: repos,
      diverId: diverId,
    );
  }

  DivingLogLogbook logbook({
    required String equipmentName,
    required String computer,
  }) => DivingLogLogbook(
    capabilities: const DivingLogCapabilities(tables: {}, columns: {}),
    equipmentById: {
      1: DivingLogRawEquipment(
        id: 1,
        object: equipmentName,
        manufacturer: 'Shearwater',
        serial: 'T-0042',
      ),
      2: const DivingLogRawEquipment(id: 2, object: 'Go Sport Fins'),
    },
    dives: [
      DivingLogRawDive(id: 1, computer: computer, equipmentIds: const [1, 2]),
      DivingLogRawDive(id: 2, computer: computer, equipmentIds: const [1, 2]),
    ],
  );

  for (final (equipmentName, computer) in const [
    ('Shearwater Teric', 'Shearwater Teric'),
    ('Teric', 'Shearwater Teric'),
    ('Teric', 'Teric'),
  ]) {
    test(
      'gear "$equipmentName" and Computer "$computer" import as one item',
      () async {
        await importLogbook(
          logbook(equipmentName: equipmentName, computer: computer),
        );

        final gear = await db.select(db.equipment).get();
        final computers = gear
            .where((g) => g.type == EquipmentType.computer.name)
            .toList();
        expect(computers, hasLength(1), reason: 'one Teric, not two');
        expect(gear, hasLength(2), reason: 'the Teric and the fins');

        final teric = computers.single;
        expect(teric.name, equipmentName);
        expect(teric.serialNumber, 'T-0042');

        // The registered computer adopted the imported row as its twin.
        final registered = (await db.select(db.diveComputers).get()).single;
        expect(registered.equipmentId, teric.id);

        // Each dive lists the Teric once, beside the fins.
        final links = await db.select(db.diveEquipment).get();
        final diveIds = links.map((l) => l.diveId).toSet();
        expect(diveIds, hasLength(2));
        for (final diveId in diveIds) {
          final onDive = links
              .where((l) => l.diveId == diveId)
              .map((l) => l.equipmentId)
              .toList();
          expect(onDive, hasLength(2));
          expect(onDive.where((id) => id == teric.id), hasLength(1));
        }
      },
    );
  }
}

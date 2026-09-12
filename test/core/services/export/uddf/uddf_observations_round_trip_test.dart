import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain_dive;
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:xml/xml.dart';

import '../../../../helpers/test_database.dart';

/// Phase 3a: the parent link and the check-ins ride inside each
/// `<applicationdata><submersion><equipment><item>` and come back through
/// the full importer with their references resolved.
ImportRepositories buildRepositories() => ImportRepositories(
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
  equipmentObservationRepository: EquipmentObservationRepository(),
);

Future<String> createTestDiver() async {
  final now = DateTime.now();
  const diverId = 'diver-obs-rt';
  await DiverRepository().createDiver(
    domain.Diver(
      id: diverId,
      name: 'Test Diver',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
  return diverId;
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  final parent = EquipmentItem(
    id: 'p',
    name: 'JJ-CCR',
    type: EquipmentType.rebreather,
    createdAt: DateTime.utc(2026),
  );
  final child = EquipmentItem(
    id: 'c',
    name: 'Cell 1',
    type: EquipmentType.o2Cell,
    parentEquipmentId: 'p',
    createdAt: DateTime.utc(2026),
  );
  final dive = domain_dive.Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 6, 2, 10),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 30.0,
    tanks: const [],
    profile: const [],
    gear: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );
  final onDive = EquipmentObservation(
    id: 'o1',
    equipmentId: 'c',
    diveId: 'dive-1',
    observedAt: DateTime.utc(2026, 6, 2, 11),
    status: ObservationStatus.issue,
    issueTags: const [ObservationTag.erratic, ObservationTag.other],
    note: 'Jumped around at 1.3',
    createdAt: DateTime.utc(2026, 6, 2, 12),
    updatedAt: DateTime.utc(2026, 6, 2, 12),
  );
  final bench = EquipmentObservation(
    id: 'o2',
    equipmentId: 'c',
    observedAt: DateTime.utc(2026, 6, 3, 9),
    status: ObservationStatus.ok,
    createdAt: DateTime.utc(2026, 6, 3, 9),
    updatedAt: DateTime.utc(2026, 6, 3, 9),
  );

  test('the export writes parentref and observations under the item', () async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      equipment: [parent, child],
      observations: [onDive, bench],
    );
    final doc = XmlDocument.parse(xml);
    final items = {
      for (final e in doc.findAllElements('item')) e.getAttribute('id'): e,
    };
    final childItem = items['equip_c']!;
    expect(childItem.findElements('parentref').single.innerText, 'equip_p');
    expect(items['equip_p']!.findElements('parentref'), isEmpty);

    final observations = childItem
        .findElements('observations')
        .single
        .findElements('observation')
        .toList();
    expect(observations, hasLength(2));
    final first = observations.first;
    expect(first.getAttribute('id'), 'obs_o1');
    expect(first.findElements('diveref').single.innerText, 'dive_dive-1');
    expect(first.findElements('status').single.innerText, 'issue');
    expect(
      first
          .findElements('tags')
          .single
          .findElements('tag')
          .map((t) => t.innerText),
      ['erratic', 'other'],
    );
    expect(first.findElements('note').single.innerText, 'Jumped around at 1.3');
    final second = observations.last;
    expect(second.findElements('diveref'), isEmpty);
    expect(second.findElements('status').single.innerText, 'ok');
    expect(second.findElements('tags'), isEmpty);
  });

  test('the import resolves the parent and the dive references', () async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      equipment: [parent, child],
      observations: [onDive, bench],
    );

    await tearDownTestDatabase();
    db = await setUpTestDatabase();
    final diverId = await createTestDiver();

    final parsed = await ExportService().importAllDataFromUddf(xml);
    await UddfEntityImporter().import(
      data: parsed,
      selections: const UddfImportSelections(equipment: {0, 1}, dives: {0}),
      repositories: buildRepositories(),
      diverId: diverId,
    );

    final rows = await db.select(db.equipment).get();
    final byName = {for (final r in rows) r.name: r};
    expect(byName.keys, containsAll(['JJ-CCR', 'Cell 1']));
    expect(byName['Cell 1']!.parentEquipmentId, byName['JJ-CCR']!.id);
    expect(byName['JJ-CCR']!.parentEquipmentId, isNull);

    final importedDive = (await db.select(db.dives).get()).single;
    final observations = await (db.select(
      db.equipmentObservations,
    )..orderBy([(t) => OrderingTerm.asc(t.observedAt)])).get();
    expect(observations, hasLength(2));
    expect(
      observations.every((o) => o.equipmentId == byName['Cell 1']!.id),
      isTrue,
    );
    expect(observations.first.diveId, importedDive.id);
    expect(observations.first.status, 'issue');
    expect(observations.first.issueTags, '["erratic","other"]');
    expect(observations.first.note, 'Jumped around at 1.3');
    expect(
      observations.first.observedAt,
      onDive.observedAt.millisecondsSinceEpoch,
    );
    expect(observations.last.diveId, isNull);
    expect(observations.last.status, 'ok');
    expect(observations.last.issueTags, '[]');
  });

  test('a newer peer\'s tags survive the export and the import', () async {
    // This build cannot name them, but the entity carries them so an edit
    // or a backup never deletes them for the build that can.
    final mixed = onDive.copyWith(
      issueTags: const [ObservationTag.erratic],
      unrecognizedTags: const ['futureTag'],
    );
    final unknownOnly = bench.copyWith(
      status: ObservationStatus.issue,
      unrecognizedTags: const ['otherFutureTag'],
    );
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      equipment: [parent, child],
      observations: [mixed, unknownOnly],
    );
    final tags = [
      for (final o in XmlDocument.parse(xml).findAllElements('observation'))
        [for (final t in o.findAllElements('tag')) t.innerText],
    ];
    expect(tags, [
      ['erratic', 'futureTag'],
      ['otherFutureTag'],
    ]);

    await tearDownTestDatabase();
    db = await setUpTestDatabase();
    final diverId = await createTestDiver();
    final parsed = await ExportService().importAllDataFromUddf(xml);
    await UddfEntityImporter().import(
      data: parsed,
      selections: const UddfImportSelections(equipment: {0, 1}, dives: {0}),
      repositories: buildRepositories(),
      diverId: diverId,
    );
    final stored = await (db.select(
      db.equipmentObservations,
    )..orderBy([(t) => OrderingTerm.asc(t.observedAt)])).get();
    expect(stored.map((o) => o.issueTags), [
      '["erratic","futureTag"]',
      '["otherFutureTag"]',
    ]);
  });
}

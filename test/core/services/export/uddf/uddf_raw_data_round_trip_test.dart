// The end-to-end proof for issue #228: a two-source dive survives a real
// export and a real import unchanged, bytes included, and the restored row is
// something ReparseService can actually consume.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
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
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/test_database.dart';

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
);

Future<String> createTestDiver() async {
  final now = DateTime.now();
  const diverId = 'diver-round-trip';
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

  final fixture = Uint8List.fromList(
    File(
      'packages/libdivecomputer_plugin/android/src/androidTest/assets/'
      'shearwater_teric_dive.bin',
    ).readAsBytesSync(),
  );

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  test('a two source dive survives export and import unchanged', () async {
    const diveId = 'dive-rt-1';
    final stamp = DateTime(2019, 6, 2, 18, 41, 7);
    final epoch = DateTime(2019, 6, 2, 10).millisecondsSinceEpoch;
    // A diver has to exist before the export side seeds anything.
    await createTestDiver();

    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value(diveId),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
    // Primary: carries the raw bytes and a full descriptor triple.
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-a'),
            diveId: const Value(diveId),
            isPrimary: const Value(true),
            rawData: Value(fixture),
            computerModel: const Value('Perdix AI'),
            computerSerial: const Value('SN-A'),
            descriptorVendor: const Value('Shearwater'),
            descriptorProduct: const Value('Perdix'),
            descriptorModel: const Value(5),
            mergeSourceSlot: const Value(0),
            maxDepth: const Value(31.5),
            cns: const Value(12.5),
            decoAlgorithm: const Value('ZHL16C'),
            importedAt: Value(stamp),
            createdAt: Value(stamp),
          ),
        );
    // Secondary: a second computer, no bytes, its own metrics.
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-b'),
            diveId: const Value(diveId),
            isPrimary: const Value(false),
            computerModel: const Value('Teric'),
            computerSerial: const Value('SN-B'),
            mergeSourceSlot: const Value(1),
            maxDepth: const Value(30.9),
            importedAt: Value(stamp),
            createdAt: Value(stamp.add(const Duration(seconds: 1))),
          ),
        );

    final sources = await DiveRepository().getSourcesForExport([diveId]);
    expect(sources, hasLength(2));

    final dive = domain_dive.Dive(
      id: diveId,
      diveNumber: 1,
      dateTime: DateTime(2019, 6, 2, 10),
      bottomTime: const Duration(minutes: 40),
      maxDepth: 31.5,
      tanks: const [],
      profile: const [],
      equipment: const [],
      notes: '',
      photoIds: const [],
      sightings: const [],
      weights: const [],
      tags: const [],
    );

    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      dataSources: sources,
    );

    // A clean database, as a restore onto a new device would be.
    await tearDownTestDatabase();
    db = await setUpTestDatabase();
    final restoredDiverId = await createTestDiver();

    final parsed = await ExportService().importAllDataFromUddf(xml);
    expect(parsed.unpairedDumps, 0);

    await UddfEntityImporter().import(
      data: parsed,
      selections: const UddfImportSelections(dives: {0}),
      repositories: buildRepositories(),
      diverId: restoredDiverId,
    );

    final restored = await (db.select(
      db.diveDataSources,
    )..orderBy([(t) => OrderingTerm.desc(t.isPrimary)])).get();

    expect(restored, hasLength(2), reason: 'both sources must come back');
    expect(restored[0].rawData, equals(fixture));
    expect(restored[1].rawData, isNull);
    expect(restored[0].maxDepth, 31.5);
    expect(restored[1].maxDepth, 30.9);
    expect(restored[0].cns, 12.5);
    expect(restored[0].decoAlgorithm, 'ZHL16C');
    expect(restored[0].mergeSourceSlot, 0);
    expect(restored[1].mergeSourceSlot, 1);
    expect(restored[0].computerModel, 'Perdix AI');
    expect(restored[1].computerModel, 'Teric');
    expect(
      restored[0].importedAt,
      stamp,
      reason: 'the restore must not relabel a 2019 dive with today',
    );

    // Re-parse counts a source as failed unless the descriptor triple is
    // present, so this is what makes the restored bytes actually useful.
    final reparseable = await ReparseService(
      db: db,
    ).getSourcesForDiveReparse(restored[0].diveId);
    expect(reparseable, hasLength(1));
    expect(reparseable.single.descriptorVendor, 'Shearwater');
    expect(reparseable.single.descriptorProduct, 'Perdix');
    expect(reparseable.single.descriptorModel, 5);
    expect(reparseable.single.rawData, equals(fixture));

    // The dump's own datetime must not have become the dive's.
    final restoredDive = await (db.select(db.dives)..limit(1)).getSingle();
    expect(
      DateTime.fromMillisecondsSinceEpoch(restoredDive.diveDateTime).toUtc(),
      DateTime.utc(2019, 6, 2, 10),
    );
  });
}

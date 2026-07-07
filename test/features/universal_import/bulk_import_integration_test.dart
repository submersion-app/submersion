// End-to-end bulk import batch test: parse -> merge -> intra-batch dedup ->
// import into an in-memory AppDatabase -> FK integrity check.
//
// Batch composition:
// - file A (hand-built payload): one dive linked to site "Blue Hole"
// - file B (REAL parse through BatchParseService): minimal UDDF bytes
// - file C (hand-built payload): a fuzzy duplicate of file A's dive plus a
//   differently-cased "BLUE HOLE " site that must fold into A's site

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/data/services/batch_parse_service.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';
import 'package:submersion/features/universal_import/data/services/payload_merger.dart';

import '../../helpers/test_database.dart';

const _minimalUddf = '''<uddf version="3.2.1">
  <profiledata>
    <repetitiongroup id="repgrp1">
      <dive id="DIVE-B-1">
        <informationbeforedive>
          <datetime>2024-02-20T14:00:00</datetime>
          <divenumber>2</divenumber>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>22.0</greatestdepth>
          <diveduration>1800.0</diveduration>
        </informationafterdive>
        <samples>
          <waypoint>
            <divetime>0.0</divetime>
            <depth>0.0</depth>
          </waypoint>
          <waypoint>
            <divetime>60.0</divetime>
            <depth>10.0</depth>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

final _diveTimeA = DateTime(2024, 1, 15, 10);

ImportPayload _payloadA() {
  return ImportPayload(
    entities: {
      ImportEntityType.sites: [
        {'uddfId': 'sA', 'name': 'Blue Hole'},
      ],
      ImportEntityType.dives: [
        {
          'dateTime': _diveTimeA,
          'maxDepth': 30.0,
          'duration': const Duration(minutes: 40),
          'sourceUuid': 'uuid-A',
          'site': {'uddfId': 'sA', 'name': 'Blue Hole'},
        },
      ],
    },
  );
}

ImportPayload _payloadC() {
  return ImportPayload(
    entities: {
      ImportEntityType.sites: [
        {'uddfId': 'sC', 'name': 'BLUE HOLE ', 'latitude': 12.2},
      ],
      ImportEntityType.dives: [
        // Fuzzy duplicate of file A's dive: one minute later, near-equal
        // depth and duration.
        {
          'dateTime': _diveTimeA.add(const Duration(minutes: 1)),
          'maxDepth': 30.2,
          'duration': const Duration(minutes: 39),
          'site': {'uddfId': 'sC', 'name': 'BLUE HOLE '},
        },
      ],
    },
  );
}

ImportRepositories _buildRepositories() {
  return ImportRepositories(
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
  );
}

Future<String> _createTestDiver() async {
  final now = DateTime.now();
  const diverId = 'diver-bulk-import-test';
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

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('3-file batch: parse, merge, dedup, import, FK-clean', () async {
    final diverId = await _createTestDiver();

    // File B goes through the REAL batch parse path.
    final parseResult = await const BatchParseService().parseAll([
      PickedImportFile(
        name: 'b.uddf',
        bytes: Uint8List.fromList(utf8.encode(_minimalUddf)),
        detection: const DetectionResult(
          format: ImportFormat.uddf,
          confidence: 1,
        ),
        status: ImportFileStatus.pending,
      ),
    ]);
    expect(parseResult.parsed, hasLength(1));

    final merged = const PayloadMerger().merge([
      FilePayload(fileId: 'f0', fileName: 'a.fit', payload: _payloadA()),
      FilePayload(
        fileId: 'f1',
        fileName: 'b.uddf',
        payload: parseResult.parsed.single.payload,
      ),
      FilePayload(fileId: 'f2', fileName: 'c.uddf', payload: _payloadC()),
    ]);

    // Merge assertions.
    expect(merged.metadata['batchFileCount'], 3);
    final mergedSites = merged.entitiesOf(ImportEntityType.sites);
    expect(
      mergedSites,
      hasLength(1),
      reason: 'BLUE HOLE variants must fold into one site',
    );
    expect(mergedSites.single['uddfId'], 'f0:sA');
    expect(
      mergedSites.single['latitude'],
      12.2,
      reason: 'survivor is enriched with the later file\'s coordinates',
    );
    final mergedDives = merged.entitiesOf(ImportEntityType.dives);
    expect(mergedDives, hasLength(3));
    expect(
      mergedDives.every(
        (d) => (d['_sourceFile'] as String?)?.isNotEmpty ?? false,
      ),
      isTrue,
      reason: 'every dive carries source-file attribution',
    );

    // Intra-batch duplicate detection against an empty database.
    final dupResult = const ImportDuplicateChecker().check(
      payload: merged,
      existingDives: const [],
      existingSites: const [],
      existingTrips: const [],
      existingEquipment: const [],
      existingBuddies: const [],
      existingDiveCenters: const [],
      existingCertifications: const [],
      existingTags: const [],
      existingDiveTypes: const [],
      checkIntraBatch: true,
    );

    // Exactly the file-C dive is an in-batch duplicate of file A's dive.
    final aIndex = mergedDives.indexWhere((d) => d['_sourceFile'] == 'a.fit');
    final cIndex = mergedDives.indexWhere((d) => d['_sourceFile'] == 'c.uddf');
    expect(dupResult.diveMatches.keys, [cIndex]);
    expect(dupResult.diveMatches[cIndex]!.inBatchIndex, aIndex);
    expect(dupResult.diveMatches[cIndex]!.diveId, '');

    // Import everything except the in-batch duplicate.
    final selectedDives = {
      for (var i = 0; i < mergedDives.length; i++)
        if (!dupResult.diveMatches.containsKey(i)) i,
    };
    final data = UddfImportResult(dives: mergedDives, sites: mergedSites);
    final importResult = await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections(dives: selectedDives, sites: const {0}),
      repositories: _buildRepositories(),
      diverId: diverId,
    );

    expect(importResult.dives, 2);
    expect(importResult.sites, 1);

    // Database-level assertions.
    final diveRows = await db.select(db.dives).get();
    expect(diveRows, hasLength(2));
    final siteRows = await db.select(db.diveSites).get();
    expect(siteRows, hasLength(1));
    expect(siteRows.single.name, 'Blue Hole');

    // File A's dive must be linked to the folded site.
    final linkedDives = diveRows.where((d) => d.siteId != null).toList();
    expect(
      linkedDives,
      hasLength(1),
      reason: 'the dive from file A references the folded Blue Hole site',
    );
    expect(linkedDives.single.siteId, siteRows.single.id);

    // FK integrity: dive_log tests run with FKs off, so check explicitly.
    final violations = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(
      violations,
      isEmpty,
      reason: 'bulk import must not create orphaned child rows',
    );
  });
}

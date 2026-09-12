// End-to-end regression test for issue #478: a dive imported before a parser
// fix shipped must be able to pick up the fix (missed tank/gas-switch data)
// without losing anything the diver typed in afterwards, and without the
// #276 cascade wiping tank-scoped child data.
//
// Flow: real UddfEntityImporter import (one tank, no gas switches) into a
// real in-memory AppDatabase -> diver edits notes/buddy/rating/site/tags and
// records a tank-pressure point by hand -> DiveResyncOrchestrator replays a
// stubbed "fixed" parser output (second tank + a gas switch, no profile, plus
// conflicting stale notes/buddy/rating/site/tag values) through the real
// DiveReimportService -> assert the fix landed and every diver edit survived.

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_import/data/services/dive_resync_orchestrator.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as dive_domain;
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as site_domain;
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart'
    as tag_domain;
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';

import '../../../helpers/test_database.dart';

final _diveTime = DateTime(2024, 3, 10, 9, 0);
const _diveDepth = 18.0;
const _fixedDepth = 19.5;
const _diveDuration = Duration(minutes: 35);

/// Original parser output: one tank, no gas switches -- the pre-fix state
/// issue #478 describes.
UddfImportResult _originalParse() {
  return UddfImportResult(
    dives: [
      {
        'dateTime': _diveTime,
        'maxDepth': _diveDepth,
        'duration': _diveDuration,
        'tanks': <Map<String, dynamic>>[
          {
            'order': 0,
            'startPressure': 200.0,
            'endPressure': 90.0,
            'gasMix': const dive_domain.GasMix(o2: 21),
          },
        ],
        'profile': <Map<String, dynamic>>[
          {'timestamp': 0, 'depth': 0.0},
          {'timestamp': 120, 'depth': 17.0},
          {'timestamp': 900, 'depth': 17.5},
          {'timestamp': 1500, 'depth': 3.0},
        ],
      },
    ],
  );
}

/// Stands in for a fixed parser: same dive (dateTime/depth/duration match
/// exactly, so [DiveMatcher] scores it 1.0), but now reports the second tank
/// and gas switch the original parse missed. It also echoes stale
/// `notes`/`buddy`/`rating`/`siteId`/`tagRefs` values -- fields a real
/// re-parse of the same file could plausibly carry -- so that if
/// [DiveReimportService]'s allowlist is ever widened to include one of them,
/// this test actually overwrites something and fails, instead of passing by
/// coincidence because the stale value happens to equal the diver's edit.
ImportPayload _fixedPayload() {
  return ImportPayload(
    entities: {
      ImportEntityType.dives: [
        {
          'dateTime': _diveTime,
          'maxDepth': _diveDepth,
          'duration': _diveDuration,
          'notes': 'stale parser notes',
          'buddy': 'stale parser buddy',
          'rating': 2,
          'siteId': 'stale-parser-site-id',
          'tagRefs': <String>['stale-parser-tag-ref'],
          'tanks': <Map<String, dynamic>>[
            {
              'order': 0,
              'startPressure': 200.0,
              'endPressure': 90.0,
              'gasMix': const dive_domain.GasMix(o2: 21),
            },
            {
              'order': 1,
              'startPressure': 200.0,
              'endPressure': 150.0,
              'gasMix': const dive_domain.GasMix(o2: 50),
            },
          ],
          'gasSwitches': <Map<String, dynamic>>[
            {'timestamp': 900, 'tankIndex': 1, 'depth': 6.0},
          ],
        },
      ],
    },
  );
}

/// The realistic parser-fix shape: the fix also corrects the SAMPLES, so the
/// destructive `_replaceProfile`/`_replaceTankPressures` path actually runs.
/// The summary still matches the stored dive closely enough for
/// [DiveMatcher] to recognise it.
ImportPayload _fixedPayloadWithProfile() {
  return ImportPayload(
    entities: {
      ImportEntityType.dives: [
        {
          'dateTime': _diveTime,
          'maxDepth': _fixedDepth,
          'duration': _diveDuration,
          'notes': 'stale parser notes',
          'buddy': 'stale parser buddy',
          'rating': 2,
          'siteId': 'stale-parser-site-id',
          'tagRefs': <String>['stale-parser-tag-ref'],
          'tanks': <Map<String, dynamic>>[
            {
              'order': 0,
              'startPressure': 200.0,
              'endPressure': 70.0,
              'gasMix': const dive_domain.GasMix(o2: 21),
            },
          ],
          'profile': _fixedProfile,
        },
      ],
    },
  );
}

const _fixedProfile = <Map<String, dynamic>>[
  {
    'timestamp': 0,
    'depth': 0.0,
    'allTankPressures': [
      {'tankIndex': 0, 'pressure': 200.0},
    ],
  },
  {
    'timestamp': 120,
    'depth': 19.0,
    'allTankPressures': [
      {'tankIndex': 0, 'pressure': 170.0},
    ],
  },
  {
    'timestamp': 1200,
    'depth': 19.5,
    'allTankPressures': [
      {'tankIndex': 0, 'pressure': 90.0},
    ],
  },
  {'timestamp': 1800, 'depth': 3.0},
];

class _StubFixedParser implements ImportParser {
  final ImportPayload payload;
  int parseCallCount = 0;

  _StubFixedParser(this.payload);

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    parseCallCount++;
    return payload;
  }

  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.uddf];
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
  const diverId = 'diver-resync-test';
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
  late ImportedFileRepository importedFiles;

  setUp(() async {
    db = await setUpTestDatabase();
    importedFiles = ImportedFileRepository();
  });

  tearDown(tearDownTestDatabase);

  test('resync applies a parser fix (missed tank/gas switch) while leaving '
      'diver edits and tank-scoped child data untouched', () async {
    final diverId = await _createTestDiver();

    // 1. Real import through UddfEntityImporter, storing the source file
    // in the real imported_files table.
    final originalBytes = Uint8List.fromList(
      utf8.encode('<uddf version="3.2.1"></uddf>'),
    );
    final importer = UddfEntityImporter(importedFiles: importedFiles);
    final importResult = await importer.import(
      data: _originalParse(),
      selections: const UddfImportSelections(dives: {0}),
      repositories: _buildRepositories(),
      diverId: diverId,
      sourceFormat: ImportFormat.uddf,
      sourceFileBytes: originalBytes,
      sourceFileName: 'dive.uddf',
    );
    expect(importResult.dives, 1);

    final diveId = (await db.select(db.dives).get()).single.id;

    final tanksBefore = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals(diveId))).get();
    expect(tanksBefore, hasLength(1));
    final originalTankId = tanksBefore.single.id;

    // 2. Diver edits notes/buddy/rating/site/tags after the import (the
    // user-authored fields the writer must never touch).
    final editedSite = await SiteRepository().createSite(
      const site_domain.DiveSite(id: '', name: 'Local Quarry'),
    );
    final editedTag = await TagRepository().createTag(
      tag_domain.Tag.create(id: '', name: 'Night Dive'),
    );

    final diveRepository = DiveRepository();
    final importedDive = await diveRepository.getDiveById(diveId);
    await diveRepository.updateDive(
      importedDive!.copyWith(
        notes: 'Great wreck dive, saw a moray eel',
        buddy: 'Alex',
        rating: 5,
        site: editedSite,
        tags: [editedTag],
      ),
    );

    // 3. Diver's dive computer already reported tank pressure for the one
    // tank the original parse knew about; this must survive the #276
    // cascade path untouched.
    final tankPressureRepository = TankPressureRepository();
    await tankPressureRepository.insertTankPressures(diveId, {
      originalTankId: [(timestamp: 600, pressure: 120.0)],
    });

    // 4. Resync against a stubbed "fixed" parser that now reports the
    // second tank and gas switch the original parse missed.
    final stubParser = _StubFixedParser(_fixedPayload());
    final orchestrator = DiveResyncOrchestrator(
      db: db,
      importedFiles: importedFiles,
      parserFor: (_) => stubParser,
    );

    // 5/6. Resync and assert.
    final outcome = await orchestrator.resync(diveId);

    expect(outcome.succeeded, isTrue, reason: outcome.failureReason?.name);
    expect(stubParser.parseCallCount, 1);

    final diveAfter = await diveRepository.getDiveById(diveId);
    expect(
      diveAfter!.notes,
      'Great wreck dive, saw a moray eel',
      reason: 'diver-authored notes must survive the resync untouched',
    );
    expect(
      diveAfter.buddy,
      'Alex',
      reason: 'diver-authored buddy must survive the resync untouched',
    );
    expect(
      diveAfter.rating,
      5,
      reason: 'diver-authored rating must survive the resync untouched',
    );
    expect(
      diveAfter.site?.id,
      editedSite.id,
      reason: 'diver-authored site must survive the resync untouched',
    );
    expect(diveAfter.tags.map((t) => t.id), [
      editedTag.id,
    ], reason: 'diver-authored tags must survive the resync untouched');

    final tanksAfter =
        await (db.select(db.diveTanks)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
            .get();
    expect(
      tanksAfter,
      hasLength(2),
      reason: 'the parser fix must add the second tank it now reports',
    );
    expect(
      tanksAfter.first.id,
      originalTankId,
      reason: 'the original tank id must be preserved by tankOrder (#276)',
    );
    final newTankId = tanksAfter.last.id;

    final pressuresAfter = await tankPressureRepository.getPressuresForTank(
      diveId,
      originalTankId,
    );
    expect(
      pressuresAfter,
      hasLength(1),
      reason:
          'the pre-existing tank-pressure point must not be wiped by the '
          'resync (#276 cascade)',
    );
    expect(pressuresAfter.single.timestamp, 600);
    expect(pressuresAfter.single.pressure, 120.0);

    final switchesAfter = await diveRepository.getGasSwitchesForDive(diveId);
    expect(
      switchesAfter,
      hasLength(1),
      reason: 'the parser fix must add the gas switch it now reports',
    );
    expect(switchesAfter.single.gasSwitch.tankId, newTankId);
  });

  test('a parser fix that also corrects the profile rewrites computer data '
      'and still leaves diver edits standing', () async {
    final diverId = await _createTestDiver();

    final importer = UddfEntityImporter(importedFiles: importedFiles);
    await importer.import(
      data: _originalParse(),
      selections: const UddfImportSelections(dives: {0}),
      repositories: _buildRepositories(),
      diverId: diverId,
      sourceFormat: ImportFormat.uddf,
      sourceFileBytes: Uint8List.fromList(
        utf8.encode('<uddf version="3.2.1"></uddf>'),
      ),
      sourceFileName: 'dive.uddf',
    );

    final diveId = (await db.select(db.dives).get()).single.id;
    final diveRepository = DiveRepository();

    // Diver edits: notes, and a stage cylinder the file never mentioned.
    final importedDive = await diveRepository.getDiveById(diveId);
    await diveRepository.updateDive(
      importedDive!.copyWith(notes: 'Great wreck dive, saw a moray eel'),
    );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'diver-stage-tank',
            diveId: diveId,
            tankOrder: const Value(1),
            startPressure: const Value(207.0),
          ),
        );
    final tankPressureRepository = TankPressureRepository();
    await tankPressureRepository.insertTankPressures(diveId, {
      'diver-stage-tank': [(timestamp: 900, pressure: 180.0)],
    });

    final orchestrator = DiveResyncOrchestrator(
      db: db,
      importedFiles: importedFiles,
      parserFor: (_) => _StubFixedParser(_fixedPayloadWithProfile()),
    );

    final outcome = await orchestrator.resync(diveId);
    expect(outcome.succeeded, isTrue, reason: outcome.failureReason?.name);

    // The fixed samples landed, attributed to the source they came from.
    final series = await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.diveId.equals(diveId))).get();
    expect(series, hasLength(1));
    expect(series.single.sampleCount, _fixedProfile.length);
    expect(series.single.maxDepth, closeTo(_fixedDepth, 0.001));
    final source = await (db.select(
      db.diveDataSources,
    )..where((t) => t.diveId.equals(diveId))).getSingle();
    expect(series.single.sourceId, source.id);

    // Summary and profile agree afterwards.
    final diveAfter = await (db.select(
      db.dives,
    )..where((t) => t.id.equals(diveId))).getSingle();
    expect(diveAfter.maxDepth, _fixedDepth);
    expect(diveAfter.bottomTime, 1200);

    // Diver edits survive the destructive path.
    expect(diveAfter.notes, 'Great wreck dive, saw a moray eel');
    final tanks = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals(diveId))).get();
    expect(
      tanks.map((t) => t.id),
      contains('diver-stage-tank'),
      reason:
          'a cylinder the diver added by hand is not the parser\'s to delete',
    );
    final stagePressures = await tankPressureRepository.getPressuresForTank(
      diveId,
      'diver-stage-tank',
    );
    expect(
      stagePressures.map((p) => p.timestamp),
      [900],
      reason:
          'keeping the tank row is worth nothing if its pressure series is '
          'deleted with the rest of the dive',
    );
    expect(stagePressures.single.pressure, 180.0);
  });

  test('a dive consolidated with a dive-computer download keeps both '
      'strands when resynced', () async {
    final diverId = await _createTestDiver();

    final importer = UddfEntityImporter(importedFiles: importedFiles);
    await importer.import(
      data: _originalParse(),
      selections: const UddfImportSelections(dives: {0}),
      repositories: _buildRepositories(),
      diverId: diverId,
      sourceFormat: ImportFormat.uddf,
      sourceFileBytes: Uint8List.fromList(
        utf8.encode('<uddf version="3.2.1"></uddf>'),
      ),
      sourceFileName: 'dive.uddf',
    );

    final diveId = (await db.select(db.dives).get()).single.id;

    // A Perdix download folded in afterwards: consolidation demotes only the
    // secondary, so the file-import row stays primary and resync is still on
    // offer.
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'computer-perdix',
            name: 'Perdix',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-perdix',
            diveId: diveId,
            isPrimary: const Value(false),
            computerId: const Value('computer-perdix'),
            rawData: Value(Uint8List.fromList([1, 2, 3])),
            importedAt: DateTime(2026, 1, 1),
            createdAt: DateTime(2026, 1, 1),
          ),
        );
    await ProfileSeriesRepository(database: db).insertSeries(
      diveId: diveId,
      computerId: 'computer-perdix',
      sourceId: 'src-perdix',
      samples: const [
        ProfileSample(timestamp: 0, depth: 0.0),
        ProfileSample(timestamp: 300, depth: 25.0),
      ],
    );

    final seriesBefore = await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.diveId.equals(diveId))).get();

    final orchestrator = DiveResyncOrchestrator(
      db: db,
      importedFiles: importedFiles,
      parserFor: (_) => _StubFixedParser(_fixedPayloadWithProfile()),
    );

    final outcome = await orchestrator.resync(diveId);
    expect(outcome.succeeded, isTrue, reason: outcome.failureReason?.name);

    final seriesAfter = await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.diveId.equals(diveId))).get();
    expect(
      seriesAfter.map((r) => r.id).toSet(),
      seriesBefore.map((r) => r.id).toSet(),
      reason:
          'a multi-source dive has no per-source scoping for these tables, so '
          'resync must leave every strand alone',
    );

    // The summary is still the primary source's to refresh.
    final diveAfter = await (db.select(
      db.dives,
    )..where((t) => t.id.equals(diveId))).getSingle();
    expect(diveAfter.maxDepth, _fixedDepth);
  });
}

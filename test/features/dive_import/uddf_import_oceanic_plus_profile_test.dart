// Regression test for issue #279: dives exported directly from the Oceanic+
// app (Apple Watch Ultra) imported with no dive profile, while the same dives
// routed through MacDive first imported fine.
//
// This exercises the full path the app uses for a UDDF file: parse with
// ExportService, then persist with UddfEntityImporter against an in-memory
// AppDatabase, then read the dive back through DiveRepository. The fixture is
// the export attached to the issue with site coordinates rounded to one
// decimal place and dive dates shifted back by eight years; sample data,
// element structure and number formatting are untouched.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/export_service.dart';
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

import '../../helpers/test_database.dart';

const _fixturePath = 'test/dives/issue_279_oceanic_plus_export.uddf';

/// The fixture holds nine dives.
const _expectedDiveCount = 9;

/// Oceanic+ records one sample every 15 seconds.
const _sampleCadenceSeconds = 15;

/// Sample count of the shortest dive in the fixture. A profile shorter than
/// this had samples dropped, not merely reordered.
const _minSamplesPerDive = 99;

/// Fixed clock for rows the test creates itself.
final _fixedNow = DateTime.utc(2024, 1, 15, 12);

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
  const diverId = 'diver-issue-279';
  await DiverRepository().createDiver(
    domain.Diver(
      id: diverId,
      name: 'Test Diver',
      isDefault: true,
      createdAt: _fixedNow,
      updatedAt: _fixedNow,
    ),
  );
  return diverId;
}

/// Asserts every sample sits on the Oceanic+ cadence: sample i is at
/// i * 15 s. This is the exact shape that collapsed to all zeros before the
/// lenient integer parser landed.
void _expectFullCadence(List<int> timestamps, {required String reason}) {
  expect(
    timestamps.length,
    greaterThanOrEqualTo(_minSamplesPerDive),
    reason: reason,
  );
  expect(
    timestamps,
    List<int>.generate(timestamps.length, (i) => i * _sampleCadenceSeconds),
    reason: reason,
  );
}

void main() {
  late AppDatabase db;
  final importer = UddfEntityImporter();
  final exportService = ExportService();
  late String content;

  setUpAll(() {
    content = File(_fixturePath).readAsStringSync();
  });

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('Oceanic+ direct export (issue #279)', () {
    test('parser yields a full-cadence profile for every dive', () async {
      final parsed = await exportService.importAllDataFromUddf(content);

      expect(parsed.dives, hasLength(_expectedDiveCount));
      for (final dive in parsed.dives) {
        final profile = dive['profile'] as List<Map<String, dynamic>>?;
        expect(profile, isNotNull);
        _expectFullCadence(
          profile!.map((p) => p['timestamp'] as int).toList(),
          reason: 'parsed dive at ${dive['dateTime']}',
        );
      }
    });

    test('persisted dives read back with their full profile', () async {
      final diverId = await _createTestDiver();
      final parsed = await exportService.importAllDataFromUddf(content);
      final parsedSampleCounts =
          parsed.dives.map((d) => (d['profile'] as List).length).toList()
            ..sort();

      await importer.import(
        data: parsed,
        selections: UddfImportSelections.selectAll(parsed),
        repositories: _buildRepositories(),
        diverId: diverId,
      );

      final diveRepo = DiveRepository();
      final dives = await diveRepo.getAllDives();
      expect(dives, hasLength(_expectedDiveCount));

      // One packed series row per dive, and its sample count must match what
      // the parser produced for that dive, so nothing was dropped between
      // parse and persistence.
      final seriesRows = await db.select(db.diveProfileSeries).get();
      expect(seriesRows, hasLength(_expectedDiveCount));
      expect(
        seriesRows.map((r) => r.diveId).toSet(),
        dives.map((d) => d.id).toSet(),
      );
      final persistedSampleCounts =
          seriesRows.map((r) => r.sampleCount).toList()..sort();
      expect(persistedSampleCounts, parsedSampleCounts);

      final seriesByDive = {for (final r in seriesRows) r.diveId: r};
      for (final summary in dives) {
        final dive = await diveRepo.getDiveById(summary.id);
        expect(dive, isNotNull);
        _expectFullCadence(
          dive!.profile.map((p) => p.timestamp).toList(),
          reason: 'dive ${dive.id} lost its profile on import',
        );
        expect(dive.profile.length, seriesByDive[dive.id]!.sampleCount);
        expect(dive.maxDepth, greaterThan(5));
        expect(dive.runtime, isNotNull);
        expect(dive.runtime!.inSeconds, greaterThan(1000));
      }
      // Imports nine real dives of 99-250 samples each through the entity
      // importer and a database round trip, then reads every one back. That
      // costs ~18s on an idle machine, which leaves almost no headroom under
      // the 30s default and times out on a loaded CI shard (seen on PR #1530,
      // shard 3, where the file passes on its own).
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_computer/data/repositories/dive_computer_connection_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';

import '../../../../fixtures/macdive_sqlite/build_synthetic_db.dart';
import '../../../../helpers/test_database.dart';

/// Issue #3871: the summary's buddy count is what the import added to the
/// logbook. Nothing a dive merely links, by reference or by name, counts again.
void main() {
  late AppDatabase db;
  late UddfEntityImporter importer;
  late ImportRepositories repos;
  late Uint8List macDiveBytes;
  const diverId = 'diver-1';

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('buddy_count_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = buildSyntheticMacDiveDb(p.join(dir.path, 'count.sqlite'));
    macDiveBytes = Uint8List.fromList(await file.readAsBytes());
  });

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

  Future<List<String>> buddyNames() async {
    final rows = await db.select(db.buddies).get();
    return rows.map((b) => b.name).toList()..sort();
  }

  Future<void> seedBuddy(String name) async {
    final now = DateTime.now();
    await repos.buddyRepository.createBuddy(
      domain.Buddy(
        id: '',
        diverId: diverId,
        name: name,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Map<String, dynamic> dive(int day, Map<String, dynamic> people) => {
    'dateTime': DateTime(2024, 3, day, 10),
    'maxDepth': 20.0,
    ...people,
  };

  Future<UddfImportResult> macDiveData() async {
    final payload = await const MacDiveSqliteParser().parse(macDiveBytes);
    return UniversalAdapter.payloadToUddfResult(payload);
  }

  UddfImportSelections allDivesOf(UddfImportResult data) =>
      UddfImportSelections(
        dives: {for (var i = 0; i < data.dives.length; i++) i},
      );

  group('a MacDive logbook', () {
    test('counts each buddy once, as the logbook ends up holding', () async {
      final data = await macDiveData();

      final result = await importer.import(
        data: data,
        selections: UddfImportSelections(
          dives: allDivesOf(data).dives,
          buddies: {for (var i = 0; i < data.buddies.length; i++) i},
        ),
        repositories: repos,
        diverId: diverId,
      );

      expect(await buddyNames(), ['Alice', 'Bob']);
      expect(result.buddies, 2);
      expect(await db.select(db.diveBuddies).get(), hasLength(3));
    });

    test('leaves out a buddy the diver deselected', () async {
      final data = await macDiveData();
      final bob = data.buddies.indexWhere((b) => b['name'] == 'Bob');

      final result = await importer.import(
        data: data,
        selections: UddfImportSelections(
          dives: allDivesOf(data).dives,
          buddies: {bob},
        ),
        repositories: repos,
        diverId: diverId,
      );

      expect(await buddyNames(), ['Bob']);
      expect(result.buddies, 1);
    });

    test('links a buddy the diver chose to skip as a duplicate', () async {
      await seedBuddy('Alice');
      final existing = (await db.select(db.buddies).get()).single;
      final data = await macDiveData();
      final bob = data.buddies.indexWhere((b) => b['name'] == 'Bob');

      final result = await importer.import(
        data: data,
        selections: UddfImportSelections(
          dives: allDivesOf(data).dives,
          buddies: {bob},
        ),
        repositories: repos,
        diverId: diverId,
        preResolvedBuddyIds: {'Alice': existing.id},
      );

      expect(await buddyNames(), ['Alice', 'Bob']);
      expect(result.buddies, 1);
      final links = await db.select(db.diveBuddies).get();
      expect(links.where((l) => l.buddyId == existing.id), hasLength(1));
    });
  });

  group('people named inline on a dive', () {
    test('a dive guide who is also a listed buddy counts once', () async {
      final data = UddfImportResult(
        buddies: const [
          {'name': 'Sam', 'uddfId': 'sam'},
        ],
        dives: [
          dive(1, {
            'unmatchedDiveGuideNames': ['Sam'],
          }),
        ],
      );

      final result = await importer.import(
        data: data,
        selections: UddfImportSelections.selectAll(data),
        repositories: repos,
        diverId: diverId,
      );

      expect(await buddyNames(), ['Sam']);
      expect(result.buddies, 1);
    });

    test('a name matching someone already logged counts nothing', () async {
      await seedBuddy('Sam');
      final data = UddfImportResult(
        dives: [
          dive(1, {
            'unmatchedBuddyNames': ['Sam'],
            'unmatchedDiveGuideNames': ['sam'],
          }),
        ],
      );

      final result = await importer.import(
        data: data,
        selections: allDivesOf(data),
        repositories: repos,
        diverId: diverId,
      );

      expect(await buddyNames(), ['Sam']);
      expect(result.buddies, 0);
    });

    test('a new name counts once across all its dives', () async {
      final data = UddfImportResult(
        dives: [
          dive(1, {
            'unmatchedBuddyNames': ['Walk In'],
          }),
          dive(2, {
            'unmatchedBuddyNames': ['Walk In'],
          }),
          dive(3, {
            'unmatchedDiveGuideNames': ['Walk In'],
          }),
        ],
      );

      final result = await importer.import(
        data: data,
        selections: allDivesOf(data),
        repositories: repos,
        diverId: diverId,
      );

      expect(await buddyNames(), ['Walk In']);
      expect(result.buddies, 1);
    });
  });
}

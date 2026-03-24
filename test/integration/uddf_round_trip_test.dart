// UDDF Import/Export Round-Trip Integration Test
//
// Tests that data can be:
// 1. Generated via Python script
// 2. Imported into the app database
// 3. Exported back to UDDF
// 4. Re-parsed with semantic equivalence to original
//
// This validates the integrity of the UDDF import/export pipeline.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as dive_entity;
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart'
    as tag_entity;
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../helpers/python_script_runner.dart';
import '../helpers/uddf_comparison_helper.dart';
import 'uddf_test_importer.dart';

void main() {
  late AppDatabase testDb;
  late ExportService exportService;
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Create temp directory for test files
    tempDir = await Directory.systemTemp.createTemp('uddf_round_trip_test_');

    // Mock path_provider for ExportService file operations
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return tempDir.path;
            }
            return null;
          },
        );

    // Mock share_plus (required by ExportService but not used in tests)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (MethodCall methodCall) async => null,
        );
  });

  setUp(() async {
    // Create fresh in-memory database for each test
    testDb = AppDatabase(NativeDatabase.memory());
    DatabaseService.instance.setTestDatabase(testDb);
    exportService = ExportService();
  });

  tearDown(() async {
    await testDb.close();
    DatabaseService.instance.resetForTesting();
  });

  tearDownAll(() async {
    // Clean up temp directory
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Creates a [UddfTestImporter] with all repositories initialized.
  UddfTestImporter createImporter() {
    return UddfTestImporter(
      diverRepository: DiverRepository(),
      diveRepository: DiveRepository(),
      siteRepository: SiteRepository(),
      buddyRepository: BuddyRepository(),
      equipmentRepository: EquipmentRepository(),
      equipmentSetRepository: EquipmentSetRepository(),
      tripRepository: TripRepository(),
      diveCenterRepository: DiveCenterRepository(),
      certificationRepository: CertificationRepository(),
      tagRepository: TagRepository(),
      diveTypeRepository: DiveTypeRepository(),
      tankPressureRepository: TankPressureRepository(),
    );
  }

  group('UDDF Round-Trip', () {
    test('import -> export preserves semantic data integrity', () async {
      // STEP 1: Generate test UDDF file using Python script
      final originalUddfPath = await PythonScriptRunner.generateUddfTestData(
        quick: true,
        outputPath: '${tempDir.path}/original.uddf',
      );

      final originalContent = await File(originalUddfPath).readAsString();

      // STEP 2: Parse original UDDF to get baseline data
      final originalResult = await exportService.importAllDataFromUddf(
        originalContent,
      );
      final normalizedOriginal = UddfComparisonHelper.normalizeImportResult(
        originalResult,
      );

      // Verify original has expected data
      expect(
        originalResult.dives.length,
        greaterThan(0),
        reason: 'Original UDDF should contain dives',
      );
      expect(
        originalResult.sites.length,
        greaterThan(0),
        reason: 'Original UDDF should contain sites',
      );

      // Print summary for debugging
      // ignore: avoid_print
      print(
        'Original data:\n${UddfComparisonHelper.summarize(normalizedOriginal)}',
      );

      // STEP 3: Import into database
      final importer = createImporter();
      await importer.importFromContent(originalContent);

      // STEP 4: Fetch all data from database and export back to UDDF
      final diveRepository = DiveRepository();
      final siteRepository = SiteRepository();
      final buddyRepository = BuddyRepository();
      final equipmentRepository = EquipmentRepository();
      final tripRepository = TripRepository();
      final tagRepository = TagRepository();
      final certificationRepository = CertificationRepository();
      final diveCenterRepository = DiveCenterRepository();
      final equipmentSetRepository = EquipmentSetRepository();
      final diveTypeRepository = DiveTypeRepository();
      final diverRepository = DiverRepository();

      // Get all dives, then load full data including profiles for each
      final divesWithoutProfiles = await diveRepository.getAllDives();
      final dives = <dive_entity.Dive>[];
      for (final dive in divesWithoutProfiles) {
        // Load profile data for each dive (getAllDives doesn't include profiles)
        final profile = await diveRepository.getDiveProfile(dive.id);
        dives.add(dive.copyWith(profile: profile));
      }
      final sites = await siteRepository.getAllSites();
      final buddies = await buddyRepository.getAllBuddies();
      final equipment = await equipmentRepository.getAllEquipment();
      final trips = await tripRepository.getAllTrips();
      final tags = await tagRepository.getAllTags();
      final certifications = await certificationRepository
          .getAllCertifications();
      final diveCenters = await diveCenterRepository.getAllDiveCenters();
      final equipmentSets = await equipmentSetRepository.getAllSets();
      final diveTypes = await diveTypeRepository.getAllDiveTypes();
      final diver = await diverRepository.getDefaultDiver();

      // Get buddy and tag associations per dive
      final diveBuddies = <String, List<BuddyWithRole>>{};
      final diveTags = <String, List<tag_entity.Tag>>{};
      for (final dive in dives) {
        diveBuddies[dive.id] = await buddyRepository.getBuddiesForDive(dive.id);
        diveTags[dive.id] = await tagRepository.getTagsForDive(dive.id);
      }

      final exportedUddfPath = await exportService.exportAllDataToUddf(
        dives: dives,
        sites: sites,
        buddies: buddies,
        equipment: equipment,
        trips: trips,
        tags: tags,
        certifications: certifications,
        diveCenters: diveCenters,
        equipmentSets: equipmentSets,
        customDiveTypes: diveTypes.where((t) => !t.isBuiltIn).toList(),
        owner: diver,
        diveBuddies: diveBuddies,
        diveTags: diveTags,
      );

      // STEP 5: Parse exported UDDF
      final exportedContent = await File(exportedUddfPath).readAsString();
      final exportedResult = await exportService.importAllDataFromUddf(
        exportedContent,
      );
      final normalizedExported = UddfComparisonHelper.normalizeImportResult(
        exportedResult,
      );

      // Print summary for debugging
      // ignore: avoid_print
      print(
        'Exported data:\n${UddfComparisonHelper.summarize(normalizedExported)}',
      );

      // STEP 6: Compare semantic content
      final differences = UddfComparisonHelper.compareResults(
        normalizedOriginal,
        normalizedExported,
      );

      // Assert no significant differences
      if (differences.isNotEmpty) {
        // ignore: avoid_print
        print('Differences found:\n${differences.take(20).join('\n')}');
        if (differences.length > 20) {
          // ignore: avoid_print
          print('... and ${differences.length - 20} more differences');
        }
      }

      expect(
        differences,
        isEmpty,
        reason:
            'Round-trip should preserve data. '
            'Found ${differences.length} differences.',
      );

      // Additional specific checks
      expect(
        normalizedExported['diveCount'],
        equals(normalizedOriginal['diveCount']),
        reason: 'Dive count should match',
      );
      expect(
        normalizedExported['siteCount'],
        equals(normalizedOriginal['siteCount']),
        reason: 'Site count should match',
      );
      expect(
        normalizedExported['buddyCount'],
        equals(normalizedOriginal['buddyCount']),
        reason: 'Buddy count should match',
      );
      expect(
        normalizedExported['tripCount'],
        equals(normalizedOriginal['tripCount']),
        reason: 'Trip count should match',
      );
    });

    test('preserves dive profile data through round-trip', () async {
      // Generate and import
      final originalUddfPath = await PythonScriptRunner.generateUddfTestData(
        quick: true,
        outputPath: '${tempDir.path}/profile_test.uddf',
      );

      final content = await File(originalUddfPath).readAsString();
      final originalResult = await exportService.importAllDataFromUddf(content);

      // Count dives with profile data in original
      var originalDivesWithProfiles = 0;
      var originalTotalPoints = 0;
      for (final dive in originalResult.dives) {
        final profile = dive['profile'] as List?;
        if (profile != null && profile.isNotEmpty) {
          originalDivesWithProfiles++;
          originalTotalPoints += profile.length;
        }
      }

      expect(
        originalDivesWithProfiles,
        greaterThan(0),
        reason: 'Original should have dives with profile data',
      );

      // Import, export, re-parse
      final importer = createImporter();
      await importer.importFromContent(content);

      final diveRepository = DiveRepository();
      final divesWithoutProfiles = await diveRepository.getAllDives();

      // Load profile data for each dive (getAllDives doesn't include profiles)
      final dives = <dive_entity.Dive>[];
      for (final dive in divesWithoutProfiles) {
        final profile = await diveRepository.getDiveProfile(dive.id);
        dives.add(dive.copyWith(profile: profile));
      }

      final exportedPath = await exportService.exportAllDataToUddf(
        dives: dives,
      );
      final exportedContent = await File(exportedPath).readAsString();
      final exportedResult = await exportService.importAllDataFromUddf(
        exportedContent,
      );

      // Verify profile data survives round-trip
      var exportedDivesWithProfiles = 0;
      var exportedTotalPoints = 0;
      for (final dive in exportedResult.dives) {
        final profile = dive['profile'] as List?;
        if (profile != null && profile.isNotEmpty) {
          exportedDivesWithProfiles++;
          exportedTotalPoints += profile.length;
        }
      }

      // All dives that had profiles should still have profiles
      expect(
        exportedDivesWithProfiles,
        equals(originalDivesWithProfiles),
        reason: 'Same number of dives should have profile data',
      );

      // Profile data should be fully preserved (100% retention)
      // Export may add 1 extra waypoint per dive for tank switch at t=0
      expect(
        exportedTotalPoints,
        greaterThanOrEqualTo(originalTotalPoints),
        reason:
            '100% of profile points should survive round-trip '
            '(original: $originalTotalPoints, exported: $exportedTotalPoints)',
      );
    });

    test('preserves tank data through round-trip', () async {
      // Generate and import
      final originalUddfPath = await PythonScriptRunner.generateUddfTestData(
        quick: true,
        outputPath: '${tempDir.path}/tank_test.uddf',
      );

      final content = await File(originalUddfPath).readAsString();
      final originalResult = await exportService.importAllDataFromUddf(content);

      // Count dives with tank data in original
      var originalTankCount = 0;
      for (final dive in originalResult.dives) {
        final tanks = dive['tanks'] as List?;
        if (tanks != null) {
          originalTankCount += tanks.length;
        }
      }

      // Import, export, re-parse
      final importer = createImporter();
      await importer.importFromContent(content);

      final diveRepository = DiveRepository();
      final divesWithoutProfiles = await diveRepository.getAllDives();

      // Load profile data for each dive (needed for complete export)
      final dives = <dive_entity.Dive>[];
      for (final dive in divesWithoutProfiles) {
        final profile = await diveRepository.getDiveProfile(dive.id);
        dives.add(dive.copyWith(profile: profile));
      }

      final exportedPath = await exportService.exportAllDataToUddf(
        dives: dives,
      );
      final exportedContent = await File(exportedPath).readAsString();
      final exportedResult = await exportService.importAllDataFromUddf(
        exportedContent,
      );

      // Count tanks in exported
      var exportedTankCount = 0;
      for (final dive in exportedResult.dives) {
        final tanks = dive['tanks'] as List?;
        if (tanks != null) {
          exportedTankCount += tanks.length;
        }
      }

      expect(
        exportedTankCount,
        equals(originalTankCount),
        reason: 'Total tank count should match through round-trip',
      );
    });

    test('imports multi-tank dive and stores separate pressure data', () async {
      // 1. Manually create a UDDF string for a two-tank dive
      const uddfContent = '''
<uddf version="3.2.0">
  <profiledata>
    <repetitiongroup>
      <dive id="dive_1">
        <informationbeforedive>
          <datetime>2024-01-01T12:00:00</datetime>
          <divenumber>1</divenumber>
        </informationbeforedive>
        <tankdata id="T1">
          <tankvolume>12.0</tankvolume>
        </tankdata>
        <tankdata id="T2">
          <tankvolume>11.0</tankvolume>
        </tankdata>
        <samples>
          <waypoint>
            <divetime>10</divetime>
            <depth>10.0</depth>
            <tankpressure ref="T1">20000000</tankpressure>
            <tankpressure ref="T2">19000000</tankpressure>
          </waypoint>
          <waypoint>
            <divetime>20</divetime>
            <depth>20.0</depth>
            <tankpressure ref="T1">18000000</tankpressure>
            <tankpressure ref="T2">17000000</tankpressure>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

      // 2. Import the data into the database
      final importer = createImporter();
      await importer.importFromContent(uddfContent);

      // 3. Verify the dive was created
      final diveRepository = DiveRepository();
      final dives = await diveRepository.getAllDives();
      expect(dives, hasLength(1));
      final diveId = dives.first.id;

      // 4. Query the tank pressure data from the repository
      final tankPressureRepository = TankPressureRepository();
      final pressuresByTank = await tankPressureRepository
          .getTankPressuresForDive(diveId);

      // 5. Assert that pressure data for two separate tanks was stored
      expect(
        pressuresByTank.keys,
        hasLength(2),
        reason: 'Should have pressure data for two tanks.',
      );

      final tankIds = pressuresByTank.keys.toList();
      final pressures1 = pressuresByTank[tankIds[0]]!;
      final pressures2 = pressuresByTank[tankIds[1]]!;

      expect(pressures1, hasLength(2));
      expect(pressures2, hasLength(2));
      expect(pressures1.first.pressure, closeTo(200.0, 0.1));
      expect(pressures2.first.pressure, closeTo(190.0, 0.1));
    });

    test(
      'imports multi-tank dive without tank IDs and stores separate pressure data',
      () async {
        // Test case for UDDF files where tankdata elements don't have id attributes
        // but waypoints reference tanks as "T1", "T2", etc. (like Perdix AI exports)
        const uddfContent = '''
<uddf version="3.2.3" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.streit.cc/uddf/3.2/">
  <profiledata>
    <repetitiongroup>
      <dive id="1190044691756736304">
        <informationbeforedive>
          <divenumber>235</divenumber>
          <datetime>2025-09-01T14:18:24Z</datetime>
        </informationbeforedive>
        <tankdata>
          <tankpressurebegin>20049962</tankpressurebegin>
          <tankpressureend>12879411</tankpressureend>
        </tankdata>
        <tankdata>
          <tankpressurebegin>21952916</tankpressurebegin>
          <tankpressureend>14244574</tankpressureend>
        </tankdata>
        <tankdata>
          <tankpressurebegin>0</tankpressurebegin>
          <tankpressureend>0</tankpressureend>
        </tankdata>
        <tankdata>
          <tankpressurebegin>0</tankpressurebegin>
          <tankpressureend>0</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <depth>1</depth>
            <divetime>0</divetime>
            <tankpressure ref="T1">20049962</tankpressure>
            <tankpressure ref="T2">21952916</tankpressure>
          </waypoint>
          <waypoint>
            <depth>3</depth>
            <divetime>10</divetime>
            <tankpressure ref="T1">19939646</tankpressure>
            <tankpressure ref="T2">21939126</tankpressure>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

        // 2. Import the data into the database
        final importer = createImporter();
        await importer.importFromContent(uddfContent);

        // 3. Verify the dive was created
        final diveRepository = DiveRepository();
        final dives = await diveRepository.getAllDives();
        expect(dives, hasLength(1));
        final diveId = dives.first.id;

        // 4. Query the tank pressure data from the repository
        final tankPressureRepository = TankPressureRepository();
        final pressuresByTank = await tankPressureRepository
            .getTankPressuresForDive(diveId);

        // 5. Assert that pressure data for two separate tanks was stored
        // (tanks 3-4 have zero pressures and should be filtered out)
        expect(
          pressuresByTank.keys,
          hasLength(2),
          reason:
              'Should have pressure data for two tanks with non-zero pressures.',
        );

        final tankIds = pressuresByTank.keys.toList();
        final pressures1 = pressuresByTank[tankIds[0]]!;
        final pressures2 = pressuresByTank[tankIds[1]]!;

        expect(pressures1, hasLength(2));
        expect(pressures2, hasLength(2));
        // First waypoint pressures
        expect(pressures1.first.pressure, closeTo(200.5, 0.1));
        expect(pressures2.first.pressure, closeTo(219.5, 0.1));
        // Second waypoint pressures
        expect(pressures1.last.pressure, closeTo(199.4, 0.1));
        expect(pressures2.last.pressure, closeTo(219.4, 0.1));
      },
    );
  });
}

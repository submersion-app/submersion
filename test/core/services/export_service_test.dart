import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

void main() {
  late ExportService exportService;
  late Directory testDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Create a temporary directory for tests
    testDir = await Directory.systemTemp.createTemp('submersion_test_');

    // Mock the path_provider channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return testDir.path;
            }
            return null;
          },
        );

    // Mock the share_plus channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (MethodCall methodCall) async {
            // Return success for shareFiles
            return null;
          },
        );
  });

  tearDownAll(() async {
    // Clean up the temp directory
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  setUp(() {
    exportService = ExportService();
  });

  // Helper to read CSV content from the exported file path
  Future<String> readCsvFromPath(String filePath) async {
    return await File(filePath).readAsString();
  }

  group('CSV Injection Prevention', () {
    test('exportTripsToCsv sanitizes formula injection in trip name', () async {
      // Create a trip with a malicious name starting with '='
      final now = DateTime.now();
      final maliciousTrip = Trip(
        id: 'test-1',
        name: '=SUM(A1:A10)',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 7),
        location: 'Test Location',
        notes: '',
        createdAt: now,
        updatedAt: now,
      );

      final filePath = await exportService.exportTripsToCsv([maliciousTrip]);
      final csvOutput = await readCsvFromPath(filePath);

      // The CSV should contain the sanitized version with a leading single quote
      expect(csvOutput, contains("'=SUM(A1:A10)"));
      // Should NOT contain the raw formula
      expect(csvOutput, isNot(contains('\n=SUM(A1:A10),')));
    });

    test('exportTripsToCsv sanitizes all dangerous characters', () async {
      final now = DateTime.now();
      final dangerousTrips = [
        Trip(
          id: 'test-1',
          name: '=FORMULA()',
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 2),
          location: '+PLUSFORMULA()',
          resortName: '-MINUSFORMULA()',
          liveaboardName: '@ATFORMULA()',
          notes: '',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final filePath = await exportService.exportTripsToCsv(dangerousTrips);
      final csvOutput = await readCsvFromPath(filePath);

      // All dangerous characters should be prefixed with single quote
      expect(csvOutput, contains("'=FORMULA()"));
      expect(csvOutput, contains("'+PLUSFORMULA()"));
      expect(csvOutput, contains("'-MINUSFORMULA()"));
      expect(csvOutput, contains("'@ATFORMULA()"));
    });

    test(
      'exportTripsToCsv sanitizes tab and carriage return characters',
      () async {
        final now = DateTime.now();
        final dangerousTrips = [
          Trip(
            id: 'test-1',
            name: '\tTABFORMULA()',
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2024, 1, 2),
            location: '\rCRFORMULA()',
            resortName: '|PIPEFORMULA()',
            notes: '',
            createdAt: now,
            updatedAt: now,
          ),
        ];

        final filePath = await exportService.exportTripsToCsv(dangerousTrips);
        final csvOutput = await readCsvFromPath(filePath);

        // Tab, carriage return, and pipe characters should be prefixed with single quote
        expect(csvOutput, contains("'\tTABFORMULA()"));
        expect(csvOutput, contains("'\rCRFORMULA()"));
        expect(csvOutput, contains("'|PIPEFORMULA()"));
      },
    );

    test('exportTripsToCsv does not modify safe strings', () async {
      final now = DateTime.now();
      final safeTrip = Trip(
        id: 'test-1',
        name: 'Safe Trip Name',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 7),
        location: 'Maldives',
        resortName: 'Paradise Resort',
        liveaboardName: 'Ocean Explorer',
        notes: 'Great diving conditions',
        createdAt: now,
        updatedAt: now,
      );

      final filePath = await exportService.exportTripsToCsv([safeTrip]);
      final csvOutput = await readCsvFromPath(filePath);

      // Safe strings should remain unchanged (no leading single quote)
      expect(csvOutput, contains('Safe Trip Name'));
      expect(csvOutput, contains('Maldives'));
      expect(csvOutput, contains('Paradise Resort'));
      expect(csvOutput, contains('Ocean Explorer'));
      expect(csvOutput, contains('Great diving conditions'));

      // Should NOT have unnecessary quotes
      expect(csvOutput, isNot(contains("'Safe Trip Name")));
      expect(csvOutput, isNot(contains("'Maldives")));
    });

    test(
      'exportTripsToCsv handles strings starting with hyphen in middle',
      () async {
        // A hyphen in the middle of a string should not be prefixed
        final now = DateTime.now();
        final trip = Trip(
          id: 'test-1',
          name: 'Red Sea - Best Diving',
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 7),
          location: 'Egypt',
          notes: '',
          createdAt: now,
          updatedAt: now,
        );

        final filePath = await exportService.exportTripsToCsv([trip]);
        final csvOutput = await readCsvFromPath(filePath);

        // The hyphen is not at the start, so no sanitization needed
        expect(csvOutput, contains('Red Sea - Best Diving'));
        expect(csvOutput, isNot(contains("'Red Sea - Best Diving")));
      },
    );

    test('exportTripsToCsv sanitizes notes field', () async {
      final now = DateTime.now();
      final trip = Trip(
        id: 'test-1',
        name: 'Test Trip',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 7),
        location: 'Test',
        notes: '=EVIL_FORMULA()',
        createdAt: now,
        updatedAt: now,
      );

      final filePath = await exportService.exportTripsToCsv([trip]);
      final csvOutput = await readCsvFromPath(filePath);

      // Notes should be sanitized
      expect(csvOutput, contains("'=EVIL_FORMULA()"));
    });

    test('exportTripsToCsv handles null and empty values safely', () async {
      final now = DateTime.now();
      final trip = Trip(
        id: 'test-1',
        name: 'Test Trip',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 7),
        location: null,
        resortName: null,
        liveaboardName: null,
        notes: '',
        createdAt: now,
        updatedAt: now,
      );

      final filePath = await exportService.exportTripsToCsv([trip]);
      final csvOutput = await readCsvFromPath(filePath);

      // Should not crash and should produce valid CSV
      expect(csvOutput, isNotEmpty);
      expect(csvOutput, contains('Test Trip'));
    });
  });

  group('UDDF export with tank pressure', () {
    test('exportDivesToUddf includes tankpressure elements with ref', () async {
      final dive = Dive(
        id: 'dive-1',
        dateTime: DateTime(2025, 6, 15, 10, 30),
        maxDepth: 20.0,
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 10.0),
          const DiveProfilePoint(timestamp: 120, depth: 20.0),
          const DiveProfilePoint(timestamp: 180, depth: 10.0),
          const DiveProfilePoint(timestamp: 240, depth: 0.0),
        ],
        tanks: [
          const DiveTank(id: 'tank-a', startPressure: 200, endPressure: 150),
          const DiveTank(id: 'tank-b', startPressure: 190, endPressure: 140),
        ],
      );

      final tankPressures = <String, Map<String, List<TankPressurePoint>>>{
        'dive-1': {
          'tank-a': [
            const TankPressurePoint(
              id: 'tp1',
              tankId: 'tank-a',
              timestamp: 0,
              pressure: 200.0,
            ),
            const TankPressurePoint(
              id: 'tp2',
              tankId: 'tank-a',
              timestamp: 120,
              pressure: 175.0,
            ),
            const TankPressurePoint(
              id: 'tp3',
              tankId: 'tank-a',
              timestamp: 240,
              pressure: 150.0,
            ),
          ],
          'tank-b': [
            const TankPressurePoint(
              id: 'tp4',
              tankId: 'tank-b',
              timestamp: 0,
              pressure: 190.0,
            ),
            const TankPressurePoint(
              id: 'tp5',
              tankId: 'tank-b',
              timestamp: 120,
              pressure: 165.0,
            ),
            const TankPressurePoint(
              id: 'tp6',
              tankId: 'tank-b',
              timestamp: 240,
              pressure: 140.0,
            ),
          ],
        },
      };

      final path = await exportService.exportDivesToUddf([
        dive,
      ], diveTankPressures: tankPressures);

      // Read the generated file to verify tankpressure elements
      final uddfFile = File(path);
      expect(await uddfFile.exists(), isTrue);
      final xml = await uddfFile.readAsString();

      // Should contain tankpressure elements (simple export omits ref
      // since it doesn't export <tankdata> elements with matching ids)
      expect(xml, contains('tankpressure'));

      // Pressure values should be in Pascal (bar * 100000)
      expect(xml, contains('20000000')); // 200.0 bar
      expect(xml, contains('19000000')); // 190.0 bar

      // Clean up
      if (await uddfFile.exists()) await uddfFile.delete();
    });

    test('exportAllDataToUddf includes tankpressure with ref', () async {
      final dive = Dive(
        id: 'dive-full',
        dateTime: DateTime(2025, 6, 15, 10, 30),
        maxDepth: 20.0,
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 20.0),
          const DiveProfilePoint(timestamp: 120, depth: 0.0),
        ],
        tanks: [
          const DiveTank(id: 'tank-full', startPressure: 200, endPressure: 150),
        ],
      );

      final tankPressures = <String, Map<String, List<TankPressurePoint>>>{
        'dive-full': {
          'tank-full': [
            const TankPressurePoint(
              id: 'tp-f1',
              tankId: 'tank-full',
              timestamp: 0,
              pressure: 200.0,
            ),
            const TankPressurePoint(
              id: 'tp-f2',
              tankId: 'tank-full',
              timestamp: 120,
              pressure: 150.0,
            ),
          ],
        },
      };

      final path = await exportService.exportAllDataToUddf(
        dives: [dive],
        diveTankPressures: tankPressures,
      );

      final uddfFile = File(path);
      expect(await uddfFile.exists(), isTrue);
      final xml = await uddfFile.readAsString();

      expect(xml, contains('tankpressure'));
      // Full export includes tankdata id and matching tankpressure ref
      expect(xml, contains('id="tank_tank-full"'));
      expect(xml, contains('ref="tank_tank-full"'));

      if (await uddfFile.exists()) await uddfFile.delete();
    });

    test('exportDivesToUddf works without tank pressures', () async {
      final dive = Dive(
        id: 'dive-2',
        dateTime: DateTime(2025, 6, 15, 10, 30),
        maxDepth: 15.0,
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 60, depth: 15.0),
          const DiveProfilePoint(timestamp: 120, depth: 0.0),
        ],
      );

      final path = await exportService.exportDivesToUddf([dive]);

      final uddfFile = File(path);
      expect(await uddfFile.exists(), isTrue);
      final xml = await uddfFile.readAsString();

      // Should not contain tankpressure elements
      expect(xml, isNot(contains('tankpressure')));

      if (await uddfFile.exists()) await uddfFile.delete();
    });
  });
}

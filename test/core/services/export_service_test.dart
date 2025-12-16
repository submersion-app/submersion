import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export_service.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

void main() {
  late ExportService exportService;

  setUp(() {
    exportService = ExportService();
  });

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

      final csvOutput = await exportService.exportTripsToCsv([maliciousTrip]);

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

      final csvOutput = await exportService.exportTripsToCsv(dangerousTrips);

      // All dangerous characters should be prefixed with single quote
      expect(csvOutput, contains("'=FORMULA()"));
      expect(csvOutput, contains("'+PLUSFORMULA()"));
      expect(csvOutput, contains("'-MINUSFORMULA()"));
      expect(csvOutput, contains("'@ATFORMULA()"));
    });

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

      final csvOutput = await exportService.exportTripsToCsv([safeTrip]);

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

    test('exportTripsToCsv handles strings starting with hyphen in middle', () async {
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

      final csvOutput = await exportService.exportTripsToCsv([trip]);

      // The hyphen is not at the start, so no sanitization needed
      expect(csvOutput, contains('Red Sea - Best Diving'));
      expect(csvOutput, isNot(contains("'Red Sea - Best Diving")));
    });

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

      final csvOutput = await exportService.exportTripsToCsv([trip]);

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

      final csvOutput = await exportService.exportTripsToCsv([trip]);

      // Should not crash and should produce valid CSV
      expect(csvOutput, isNotEmpty);
      expect(csvOutput, contains('Test Trip'));
    });
  });
}

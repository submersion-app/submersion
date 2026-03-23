import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';

void main() {
  group('UnifiedImportResult', () {
    test('creates with all fields', () {
      const result = UnifiedImportResult(
        importedCounts: {ImportEntityType.dives: 5, ImportEntityType.sites: 2},
        consolidatedCount: 3,
        skippedCount: 1,
        errorMessage: null,
      );

      expect(result.importedCounts[ImportEntityType.dives], 5);
      expect(result.importedCounts[ImportEntityType.sites], 2);
      expect(result.consolidatedCount, 3);
      expect(result.skippedCount, 1);
      expect(result.errorMessage, isNull);
    });

    test('creates with errorMessage', () {
      const result = UnifiedImportResult(
        importedCounts: {},
        consolidatedCount: 0,
        skippedCount: 0,
        errorMessage: 'File could not be parsed.',
      );

      expect(result.errorMessage, 'File could not be parsed.');
    });

    test('importedCounts can be empty map', () {
      const result = UnifiedImportResult(
        importedCounts: {},
        consolidatedCount: 0,
        skippedCount: 0,
      );

      expect(result.importedCounts, isEmpty);
    });

    test('importedCounts returns zero for absent entity type', () {
      const result = UnifiedImportResult(
        importedCounts: {ImportEntityType.dives: 4},
        consolidatedCount: 0,
        skippedCount: 0,
      );

      expect(result.importedCounts[ImportEntityType.sites], isNull);
    });

    test('consolidatedCount is accessible', () {
      const result = UnifiedImportResult(
        importedCounts: {},
        consolidatedCount: 7,
        skippedCount: 2,
      );

      expect(result.consolidatedCount, 7);
      expect(result.skippedCount, 2);
    });

    test('supports zero values for all counts', () {
      const result = UnifiedImportResult(
        importedCounts: {},
        consolidatedCount: 0,
        skippedCount: 0,
      );

      expect(result.consolidatedCount, 0);
      expect(result.skippedCount, 0);
    });

    test('multiple entity types tracked independently', () {
      const result = UnifiedImportResult(
        importedCounts: {
          ImportEntityType.dives: 10,
          ImportEntityType.sites: 3,
          ImportEntityType.equipment: 1,
          ImportEntityType.buddies: 0,
        },
        consolidatedCount: 2,
        skippedCount: 5,
      );

      expect(result.importedCounts[ImportEntityType.dives], 10);
      expect(result.importedCounts[ImportEntityType.sites], 3);
      expect(result.importedCounts[ImportEntityType.equipment], 1);
      expect(result.importedCounts[ImportEntityType.buddies], 0);
    });
  });
}

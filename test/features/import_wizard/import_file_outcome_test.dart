import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/import_file_outcome.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';

void main() {
  test('ImportFileOutcome defaults', () {
    const outcome = ImportFileOutcome(
      fileName: 'a.fit',
      formatName: 'Garmin FIT',
      status: ImportFileOutcomeStatus.imported,
    );
    expect(outcome.importedDives, 0);
    expect(outcome.error, isNull);
  });

  test('UnifiedImportResult carries fileOutcomes, empty by default', () {
    const result = UnifiedImportResult(
      importedCounts: {},
      consolidatedCount: 0,
      skippedCount: 0,
    );
    expect(result.fileOutcomes, isEmpty);

    const withOutcomes = UnifiedImportResult(
      importedCounts: {},
      consolidatedCount: 0,
      skippedCount: 0,
      fileOutcomes: [
        ImportFileOutcome(
          fileName: 'b.uddf',
          formatName: 'UDDF',
          status: ImportFileOutcomeStatus.parseFailed,
          error: 'bad xml',
        ),
      ],
    );
    expect(withOutcomes.fileOutcomes.single.error, 'bad xml');
  });
}

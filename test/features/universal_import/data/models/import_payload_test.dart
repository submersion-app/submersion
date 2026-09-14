import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

ImportPayload _withWarnings(List<ImportWarning> warnings) =>
    ImportPayload(entities: const {}, warnings: warnings);

void main() {
  // When a file imports nothing, this is the reason shown for it. Parsers can
  // record diagnostics before the error that actually sank the file, and a
  // diagnostic is never meant to be shown.
  group('failureReason', () {
    test('is the first error, even behind earlier warnings', () {
      final payload = _withWarnings(const [
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          code: ImportWarningCode.diagnostic,
          message: 'ZDT segment without a preceding ZDH; ignored',
        ),
        ImportWarning(
          severity: ImportWarningSeverity.error,
          message: 'No dives found in DL7 file',
        ),
      ]);

      expect(payload.failureReason, 'No dives found in DL7 file');
    });

    test('falls back to the first warning that is not a diagnostic', () {
      final payload = _withWarnings(const [
        ImportWarning(
          severity: ImportWarningSeverity.info,
          code: ImportWarningCode.diagnostic,
          message: 'internal note',
        ),
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          code: ImportWarningCode.divesSkipped,
          message: 'Skipped dive 1: no readable start time',
        ),
      ]);

      expect(payload.failureReason, 'Skipped dive 1: no readable start time');
    });

    test('is null when only diagnostics were recorded', () {
      final payload = _withWarnings(const [
        ImportWarning(
          severity: ImportWarningSeverity.info,
          code: ImportWarningCode.diagnostic,
          message: 'internal note',
        ),
      ]);

      expect(payload.failureReason, isNull);
    });

    test('is null when nothing was recorded', () {
      expect(_withWarnings(const []).failureReason, isNull);
    });
  });
}

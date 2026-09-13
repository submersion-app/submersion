// The text the import wizard shows when a file produced nothing to import.
//
// For a CSV whose every row was skipped this used to be the first raw
// transformer warning, in English, whatever the language setting: "Row 2:
// could not resolve dateTime, skipping", or "Row 2: failed to apply ..." when
// a value transform happened to fail first.

import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/presentation/providers/empty_payload_message.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

ImportWarning _unreadable(int? row) => ImportWarning(
  severity: ImportWarningSeverity.warning,
  code: ImportWarningCode.unreadableDate,
  message: 'Row $row: could not resolve dateTime, skipping',
  sourceRow: row,
);

ImportWarning _transformFailed(int row) => ImportWarning(
  severity: ImportWarningSeverity.info,
  message: 'Row $row: failed to apply parseDepth to "x" for field maxDepth',
  sourceRow: row,
);

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));

  group('rows skipped for an unreadable date', () {
    test('says how many, lists the rows, and points at the mapping', () {
      final message = emptyPayloadMessage(en, [
        _unreadable(2),
        _unreadable(3),
        _unreadable(4),
      ]);

      expect(
        message,
        'Nothing was imported: the dates in 3 rows could not be read.\n'
        'Rows 2, 3, 4\n'
        'Check that the date and time columns are mapped on this step, '
        'and that they hold dates.',
      );
    });

    test('uses the singular for one row', () {
      final message = emptyPayloadMessage(en, [_unreadable(2)]);

      expect(message.split('\n').take(2), [
        'Nothing was imported: the date in 1 row could not be read.',
        'Row 2',
      ]);
    });

    test('lists the first five rows and counts the rest', () {
      final message = emptyPayloadMessage(en, [
        for (var row = 2; row <= 13; row++) _unreadable(row),
      ]);

      expect(message.split('\n')[1], 'Rows 2, 3, 4, 5, 6 and 7 more');
    });

    test('lists rows in spreadsheet order, once each', () {
      final message = emptyPayloadMessage(en, [
        _unreadable(9),
        _unreadable(4),
        _unreadable(9),
        _unreadable(2),
      ]);

      expect(message.split('\n')[1], 'Rows 2, 4, 9');
    });

    test('leaves out the row line when no row is known', () {
      final message = emptyPayloadMessage(en, [
        _unreadable(null),
        _unreadable(null),
      ]);

      expect(message.split('\n'), [
        'Nothing was imported: the dates in 2 rows could not be read.',
        en.universalImport_error_unreadableDatesHint,
      ]);
    });

    test('is not displaced by a transform warning that came first', () {
      final message = emptyPayloadMessage(en, [
        _transformFailed(2),
        _unreadable(2),
        _unreadable(3),
      ]);

      expect(message, isNot(contains('failed to apply')));
      expect(
        message.split('\n').first,
        'Nothing was imported: the dates in 2 rows could not be read.',
      );
    });

    test('is written in the language it is given', () {
      final message = emptyPayloadMessage(de, [_unreadable(2), _unreadable(3)]);

      expect(message.split('\n'), [
        de.universalImport_error_unreadableDatesHeadline(2),
        de.universalImport_summary_unreadableDatesRows(2, '2, 3'),
        de.universalImport_error_unreadableDatesHint,
      ]);
      expect(message, isNot(contains('Nothing was imported')));
    });
  });

  group('any other empty payload', () {
    test('leads with a localized sentence and keeps the parser detail', () {
      final message = emptyPayloadMessage(de, const [
        ImportWarning(
          severity: ImportWarningSeverity.error,
          message: 'Failed to parse XML: Expected a single root element',
        ),
      ]);

      expect(
        message,
        de.universalImport_error_noDataInFileWithDetails(
          'Failed to parse XML: Expected a single root element',
        ),
      );
    });

    test('prefers an error over an earlier informational note', () {
      final message = emptyPayloadMessage(en, [
        _transformFailed(2),
        const ImportWarning(
          severity: ImportWarningSeverity.error,
          message: 'Failed to parse XML: Expected a single root element',
        ),
      ]);

      expect(
        message,
        'No importable data was found in this file: '
        'Failed to parse XML: Expected a single root element',
      );
    });

    test('falls back to the first warning when none is an error', () {
      final message = emptyPayloadMessage(en, const [
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          message: 'No field mapping found for file role "dives"',
        ),
      ]);

      expect(
        message,
        'No importable data was found in this file: '
        'No field mapping found for file role "dives"',
      );
    });

    test('is just the sentence when there is no warning at all', () {
      expect(
        emptyPayloadMessage(en, const []),
        'No importable data was found in this file.',
      );
    });
  });
}

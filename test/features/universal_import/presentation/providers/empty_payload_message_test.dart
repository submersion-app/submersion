// The text the import wizard shows when a file produced nothing to import.
//
// For a CSV whose every row was skipped this used to be the first raw
// transformer warning, in English, whatever the language setting: "Row 2:
// could not resolve dateTime, skipping", or "Row 2: failed to apply ..." when
// a value transform happened to fail first.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser.dart';
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
  code: ImportWarningCode.valuesNotConverted,
  message: 'Row $row: failed to apply parseDepth to "x" for field maxDepth',
  sourceRow: row,
);

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));

  test(
    'a Submersion CSV with an unreadable date column is summarized',
    () async {
      // The whole file was reported by its first row alone, which named a row
      // the diver had not touched (#2152).
      const csv =
          'Dive Number,Date (MMM D, YYYY),Time (24-hour)\r\n'
          '1,not a date,09:05\r\n'
          '2,nor this,10:05\r\n';
      final payload = await const SubmersionDivesCsvParser().parse(
        Uint8List.fromList(utf8.encode(csv)),
      );

      expect(
        emptyPayloadMessage(
          en,
          payload.warnings,
          mapsColumns: false,
        ).split('\n'),
        [
          'Nothing was imported: the dates in 2 rows could not be read.',
          'Rows 2, 3',
          // This path has no Map Fields step to send the diver back to, so
          // the hint names the file's own header instead.
          'Check that the date column holds dates written the way its header '
              'names.',
        ],
      );
    },
  );

  group('rows skipped for an unreadable date', () {
    test('says how many, lists the rows, and points at the mapping', () {
      final message = emptyPayloadMessage(en, [
        _unreadable(2),
        _unreadable(3),
        _unreadable(4),
      ], mapsColumns: true);

      expect(
        message,
        'Nothing was imported: the dates in 3 rows could not be read.\n'
        'Rows 2, 3, 4\n'
        'Check that the date and time columns are mapped on this step, '
        'and that they hold dates.',
      );
    });

    test('uses the singular for one row', () {
      final message = emptyPayloadMessage(en, [
        _unreadable(2),
      ], mapsColumns: true);

      expect(message.split('\n').take(2), [
        'Nothing was imported: the date in 1 row could not be read.',
        'Row 2',
      ]);
    });

    test('lists the first five rows and counts the rest', () {
      final message = emptyPayloadMessage(en, [
        for (var row = 2; row <= 13; row++) _unreadable(row),
      ], mapsColumns: true);

      expect(message.split('\n')[1], 'Rows 2, 3, 4, 5, 6 and 7 more');
    });

    test('lists rows in spreadsheet order, once each', () {
      final message = emptyPayloadMessage(en, [
        _unreadable(9),
        _unreadable(4),
        _unreadable(9),
        _unreadable(2),
      ], mapsColumns: true);

      expect(message.split('\n')[1], 'Rows 2, 4, 9');
    });

    test('leaves out the row line when no row is known', () {
      final message = emptyPayloadMessage(en, [
        _unreadable(null),
        _unreadable(null),
      ], mapsColumns: true);

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
      ], mapsColumns: true);

      expect(message, isNot(contains('failed to apply')));
      expect(
        message.split('\n').first,
        'Nothing was imported: the dates in 2 rows could not be read.',
      );
    });

    test('gives way to an error, which is what sank the file', () {
      final message = emptyPayloadMessage(en, [
        _unreadable(2),
        const ImportWarning(
          severity: ImportWarningSeverity.error,
          message: 'Failed to read the file',
        ),
      ], mapsColumns: true);

      expect(
        message,
        'No importable data was found in this file: Failed to read the file',
      );
    });

    test('a self-describing format is not sent to the mapping step', () {
      final warnings = [_unreadable(2), _unreadable(3)];

      expect(
        emptyPayloadMessage(en, warnings, mapsColumns: false).split('\n').last,
        en.universalImport_error_unreadableDatesHintNoMapping,
      );
      expect(
        emptyPayloadMessage(en, warnings, mapsColumns: true).split('\n').last,
        en.universalImport_error_unreadableDatesHint,
      );
      expect(
        en.universalImport_error_unreadableDatesHintNoMapping,
        isNot(en.universalImport_error_unreadableDatesHint),
      );
    });

    test('is written in the language it is given', () {
      final message = emptyPayloadMessage(de, [
        _unreadable(2),
        _unreadable(3),
      ], mapsColumns: true);

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
      ], mapsColumns: true);

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
      ], mapsColumns: true);

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
          code: ImportWarningCode.divesSkipped,
          message: 'No field mapping found for file role "dives"',
        ),
      ], mapsColumns: true);

      expect(
        message,
        'No importable data was found in this file: '
        'No field mapping found for file role "dives"',
      );
    });

    test('never shows a diagnostic as the detail', () {
      // A parser may record a diagnostic ahead of anything worth showing.
      final message = emptyPayloadMessage(en, const [
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          code: ImportWarningCode.diagnostic,
          message: 'ZDT segment without a preceding ZDH; ignored',
        ),
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          code: ImportWarningCode.divesSkipped,
          message: 'Skipped dive 1: no readable start time',
        ),
      ], mapsColumns: true);

      expect(
        message,
        'No importable data was found in this file: '
        'Skipped dive 1: no readable start time',
      );
    });

    test('is just the sentence when only diagnostics were recorded', () {
      final message = emptyPayloadMessage(en, const [
        ImportWarning(
          severity: ImportWarningSeverity.info,
          code: ImportWarningCode.diagnostic,
          message: 'internal note',
        ),
      ], mapsColumns: true);

      expect(message, 'No importable data was found in this file.');
    });

    test('is just the sentence when there is no warning at all', () {
      expect(
        emptyPayloadMessage(en, const [], mapsColumns: true),
        'No importable data was found in this file.',
      );
    });
  });
}

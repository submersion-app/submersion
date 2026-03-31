import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/models/parsed_csv.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_transformer.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

void main() {
  late CsvTransformer transformer;

  setUp(() {
    transformer = CsvTransformer();
  });

  group('CsvTransformer', () {
    test('maps columns to target fields', () {
      // Without date/time, rows should be skipped (no dateTime).
      // Add date column to make rows valid.
      const csvWithDate = ParsedCsv(
        headers: ['Dive No', 'Max Depth', 'Site Name', 'Notes', 'Date'],
        rows: [
          ['1', '25.5', 'Blue Hole', 'Great dive', '2024-06-15'],
          ['2', '30.0', 'Reef Wall', 'Saw a turtle', '2024-06-16'],
        ],
      );

      const configWithDate = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Dive No', targetField: 'diveNumber'),
              ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
              ColumnMapping(sourceColumn: 'Site Name', targetField: 'siteName'),
              ColumnMapping(sourceColumn: 'Notes', targetField: 'notes'),
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
            ],
          ),
        },
      );

      final result = transformer.transform(csvWithDate, configWithDate);

      expect(result.rows, hasLength(2));
      expect(result.rows[0]['diveNumber'], 1);
      expect(result.rows[0]['maxDepth'], 25.5);
      expect(result.rows[0]['siteName'], 'Blue Hole');
      expect(result.rows[0]['notes'], 'Great dive');
      expect(result.rows[1]['diveNumber'], 2);
      expect(result.rows[1]['maxDepth'], 30.0);
      expect(result.rows[1]['siteName'], 'Reef Wall');
    });

    test('combines date and time into UTC dateTime', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Time', 'Max Depth'],
        rows: [
          ['2024-06-15', '14:30', '25.5'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(sourceColumn: 'Time', targetField: 'time'),
              ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      final dateTime = result.rows[0]['dateTime'] as DateTime;
      expect(dateTime.isUtc, isTrue);
      expect(dateTime.year, 2024);
      expect(dateTime.month, 6);
      expect(dateTime.day, 15);
      expect(dateTime.hour, 14);
      expect(dateTime.minute, 30);
    });

    test('applies hmsToSeconds transform for duration', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Duration'],
        rows: [
          ['2024-06-15', '1:05:30'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(
                sourceColumn: 'Duration',
                targetField: 'duration',
                transform: ValueTransform.hmsToSeconds,
              ),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      final duration = result.rows[0]['duration'] as Duration;
      // 1 hour + 5 minutes + 30 seconds = 3930 seconds
      expect(duration.inSeconds, 3930);
    });

    test('applies minutesToSeconds transform for duration', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Duration'],
        rows: [
          ['2024-06-15', '45'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(
                sourceColumn: 'Duration',
                targetField: 'duration',
                transform: ValueTransform.minutesToSeconds,
              ),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      final duration = result.rows[0]['duration'] as Duration;
      expect(duration.inSeconds, 2700);
    });

    test('skips rows with no valid dateTime and warns', () {
      const csv = ParsedCsv(
        headers: ['Max Depth', 'Notes'],
        rows: [
          ['25.5', 'No date here'],
          ['30.0', 'Also no date'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
              ColumnMapping(sourceColumn: 'Notes', targetField: 'notes'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, isEmpty);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any(
          (w) =>
              w.severity == ImportWarningSeverity.warning &&
              w.message.contains('dateTime'),
        ),
        isTrue,
      );
    });

    test('resolves informal times (am -> 9:00, pm -> 14:00)', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Time', 'Max Depth'],
        rows: [
          ['2024-06-15', 'am', '25.5'],
          ['2024-06-15', 'pm', '30.0'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(sourceColumn: 'Time', targetField: 'time'),
              ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(2));

      final dt1 = result.rows[0]['dateTime'] as DateTime;
      expect(dt1.hour, 9); // 'am' defaults to 9:00

      final dt2 = result.rows[1]['dateTime'] as DateTime;
      expect(dt2.hour, 14); // 'pm' defaults to 14:00
    });

    test('applies feetToMeters transform', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Max Depth'],
        rows: [
          ['2024-06-15', '100'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(
                sourceColumn: 'Max Depth',
                targetField: 'maxDepth',
                transform: ValueTransform.feetToMeters,
              ),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      // 100 feet = 30.5 meters (rounded to 1 decimal)
      expect(result.rows[0]['maxDepth'], closeTo(30.5, 0.1));
    });

    test('uses defaultValue when source column is empty', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Max Depth', 'Dive Type'],
        rows: [
          ['2024-06-15', '25.5', ''],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
              ColumnMapping(
                sourceColumn: 'Dive Type',
                targetField: 'diveType',
                transform: ValueTransform.diveTypeMap,
                defaultValue: 'recreational',
              ),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      expect(result.rows[0]['diveType'], 'recreational');
    });

    test('handles combined dateTime column', () {
      const csv = ParsedCsv(
        headers: ['Date/Time', 'Max Depth'],
        rows: [
          ['2024-06-15 14:30:00', '25.5'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date/Time', targetField: 'dateTime'),
              ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      final dateTime = result.rows[0]['dateTime'] as DateTime;
      expect(dateTime.year, 2024);
      expect(dateTime.month, 6);
      expect(dateTime.day, 15);
      expect(dateTime.hour, 14);
      expect(dateTime.minute, 30);
    });

    test('sets importVersion to 2 on each row', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Max Depth'],
        rows: [
          ['2024-06-15', '25.5'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      expect(result.rows[0]['importVersion'], 2);
    });

    test('sets fileRole on result', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Max Depth'],
        rows: [
          ['2024-06-15', '25.5'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'dive_profile': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
            ],
          ),
        },
      );

      final result = transformer.transform(
        csv,
        config,
        fileRole: 'dive_profile',
      );

      expect(result.fileRole, 'dive_profile');
    });

    test('handles case-insensitive column matching', () {
      const csv = ParsedCsv(
        headers: ['DATE', 'max depth'],
        rows: [
          ['2024-06-15', '25.5'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'date', targetField: 'date'),
              ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      expect(result.rows[0]['maxDepth'], 25.5);
    });

    test('applies visibilityScale transform', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Visibility'],
        rows: [
          ['2024-06-15', 'excellent'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(
                sourceColumn: 'Visibility',
                targetField: 'visibility',
                transform: ValueTransform.visibilityScale,
              ),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      expect(result.rows[0]['visibility'], 'excellent');
    });

    test('applies ratingScale transform', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Rating'],
        rows: [
          ['2024-06-15', '8'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(
                sourceColumn: 'Rating',
                targetField: 'rating',
                transform: ValueTransform.ratingScale,
              ),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      // 8 on a 1-10 scale => 8/2 = 4
      expect(result.rows[0]['rating'], 4);
    });

    test('returns empty TransformedRows for missing fileRole mapping', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Max Depth'],
        rows: [
          ['2024-06-15', '25.5'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [ColumnMapping(sourceColumn: 'Date', targetField: 'date')],
          ),
        },
      );

      final result = transformer.transform(
        csv,
        config,
        fileRole: 'nonexistent',
      );

      expect(result.rows, isEmpty);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first.message, contains('No field mapping'));
    });

    test(
      'strips number suffix for double field recognition (startPressure_1)',
      () {
        const csv = ParsedCsv(
          headers: ['Date', 'Start Pressure 1'],
          rows: [
            ['2024-06-15', '200'],
          ],
        );

        const config = ImportConfiguration(
          mappings: {
            'primary': FieldMapping(
              name: 'Test',
              columns: [
                ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
                ColumnMapping(
                  sourceColumn: 'Start Pressure 1',
                  targetField: 'startPressure_1',
                ),
              ],
            ),
          },
        );

        final result = transformer.transform(csv, config);

        expect(result.rows, hasLength(1));
        // startPressure_1 should be recognized as a double field after stripping
        // the _1 suffix, and parsed as a double.
        expect(result.rows[0]['startPressure_1'], isA<double>());
        expect(result.rows[0]['startPressure_1'], 200.0);
      },
    );

    test('infers rating field via _inferType', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Rating'],
        rows: [
          ['2024-06-15', '7'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(sourceColumn: 'Rating', targetField: 'rating'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      // 7 on a 1-10 scale -> 7/2 = 3.5 -> 4
      expect(result.rows[0]['rating'], isA<int>());
      expect(result.rows[0]['rating'], 4);
    });

    test('infers visibility field via _inferType', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Visibility'],
        rows: [
          ['2024-06-15', 'murky'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(
                sourceColumn: 'Visibility',
                targetField: 'visibility',
              ),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      expect(result.rows[0]['visibility'], 'poor');
    });

    test('infers diveType field via _inferType', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Dive Type'],
        rows: [
          ['2024-06-15', 'wreck'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(sourceColumn: 'Dive Type', targetField: 'diveType'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      expect(result.rows[0]['diveType'], 'wreck');
    });

    test('emits warning when explicit transform fails on malformed value', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Duration'],
        rows: [
          ['2024-06-15', 'not-a-duration'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(
                sourceColumn: 'Duration',
                targetField: 'duration',
                transform: ValueTransform.hmsToSeconds,
              ),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      // The transform failed, so 'duration' should not be in the row.
      expect(result.rows[0].containsKey('duration'), isFalse);
      // A warning should have been emitted about the failed transform.
      expect(
        result.warnings.any(
          (w) =>
              w.severity == ImportWarningSeverity.info &&
              w.message.contains('hmsToSeconds') &&
              w.message.contains('not-a-duration'),
        ),
        isTrue,
      );
    });

    test('infers duration as minutes when value has no colons', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Duration'],
        rows: [
          ['2024-06-15', '45'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(sourceColumn: 'Duration', targetField: 'duration'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      final duration = result.rows[0]['duration'] as Duration;
      // 45 minutes = 2700 seconds
      expect(duration.inSeconds, 2700);
    });

    test('_coerceDefault applies transform to default value', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Depth'],
        rows: [
          ['2024-06-15', ''],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(
                sourceColumn: 'Depth',
                targetField: 'maxDepth',
                transform: ValueTransform.feetToMeters,
                defaultValue: '100',
              ),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      // 100 ft -> ~30.5 m via feetToMeters transform on the default value.
      expect(result.rows[0]['maxDepth'], closeTo(30.5, 0.1));
    });

    test('_coerceDefault infers double for double target field', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Max Depth'],
        rows: [
          ['2024-06-15', ''],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(
                sourceColumn: 'Max Depth',
                targetField: 'maxDepth',
                defaultValue: '25.5',
              ),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      expect(result.rows[0]['maxDepth'], isA<double>());
      expect(result.rows[0]['maxDepth'], 25.5);
    });

    test('_coerceDefault infers integer for diveNumber field', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Dive No'],
        rows: [
          ['2024-06-15', ''],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(
                sourceColumn: 'Dive No',
                targetField: 'diveNumber',
                defaultValue: '99',
              ),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      expect(result.rows[0]['diveNumber'], isA<int>());
      expect(result.rows[0]['diveNumber'], 99);
    });

    test('_coerceDefault infers rating for rating field', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Rating'],
        rows: [
          ['2024-06-15', ''],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(
                sourceColumn: 'Rating',
                targetField: 'rating',
                defaultValue: '3',
              ),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      expect(result.rows[0]['rating'], isA<int>());
      expect(result.rows[0]['rating'], 3);
    });

    test('_coerceDefault returns string for unrecognized field', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Notes'],
        rows: [
          ['2024-06-15', ''],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(
                sourceColumn: 'Notes',
                targetField: 'notes',
                defaultValue: 'No notes',
              ),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      expect(result.rows[0]['notes'], 'No notes');
    });

    test('skips column when source column index exceeds row length', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Depth', 'Extra'],
        rows: [
          ['2024-06-15', '25.5'], // row shorter than headers
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth'),
              ColumnMapping(sourceColumn: 'Extra', targetField: 'notes'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      expect(result.rows[0]['maxDepth'], 25.5);
      expect(result.rows[0].containsKey('notes'), isFalse);
    });

    test('infers duration as hms when value contains colons', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Duration'],
        rows: [
          ['2024-06-15', '1:05:30'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(sourceColumn: 'Duration', targetField: 'duration'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      final duration = result.rows[0]['duration'] as Duration;
      // 1 hour + 5 minutes + 30 seconds = 3930 seconds
      expect(duration.inSeconds, 3930);
    });

    test('recognizes diveNum as integer field via _inferType', () {
      const csv = ParsedCsv(
        headers: ['Date', 'Dive Num'],
        rows: [
          ['2024-06-15', '42'],
        ],
      );

      const config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(sourceColumn: 'Dive Num', targetField: 'diveNum'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);

      expect(result.rows, hasLength(1));
      expect(result.rows[0]['diveNum'], isA<int>());
      expect(result.rows[0]['diveNum'], 42);
    });
  });
}

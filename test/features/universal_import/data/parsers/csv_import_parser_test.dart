import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/csv_import_parser.dart';

void main() {
  const parser = CsvImportParser();

  Uint8List csvBytes(String csv) => Uint8List.fromList(utf8.encode(csv));

  group('supportedFormats', () {
    test('supports CSV', () {
      expect(parser.supportedFormats, [ImportFormat.csv]);
    });
  });

  group('parse - basic CSV', () {
    test('parses valid MacDive-style CSV', () async {
      const csv =
          'Date,Time,Max. Depth,Bottom Time,Location\n'
          '2024-01-15,10:00,25.5,45,Blue Hole\n'
          '2024-01-16,14:30,18.0,30,Shark Reef\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.macdive,
          format: ImportFormat.csv,
        ),
      );

      expect(result.entities, isNotEmpty);
      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.length, 2);
    });

    test('extracts unique site names', () async {
      const csv =
          'Date,Time,Location\n'
          '2024-01-15,10:00,Blue Hole\n'
          '2024-01-16,14:30,Shark Reef\n'
          '2024-01-17,09:00,Blue Hole\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.csv,
        ),
      );

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites.length, 2); // Blue Hole, Shark Reef (deduplicated)
    });

    test('returns error for empty file', () async {
      final result = await parser.parse(csvBytes(''));
      expect(
        result.warnings.any((w) => w.severity == ImportWarningSeverity.error),
        isTrue,
      );
    });

    test('returns error for headers-only CSV', () async {
      final result = await parser.parse(csvBytes('Date,Depth,Duration\n'));
      expect(
        result.warnings.any((w) => w.message.contains('no data rows')),
        isTrue,
      );
    });

    test('skips rows without valid dateTime', () async {
      const csv =
          'Date,Max. Depth\n'
          ',25.5\n' // missing date
          '2024-01-15,18.0\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.csv,
        ),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.length, 1);
    });

    test('skips empty rows', () async {
      const csv =
          'Date,Max. Depth\n'
          ',\n'
          '2024-01-15,25.5\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.csv,
        ),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.length, 1);
    });
  });

  group('parse - custom mapping', () {
    test('uses custom mapping when provided', () async {
      const csv =
          'my_date,my_depth,my_dur\n'
          '2024-01-15,25.5,45\n';

      const customMapping = FieldMapping(
        name: 'Custom',
        sourceApp: SourceApp.generic,
        columns: [
          ColumnMapping(sourceColumn: 'my_date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'my_depth', targetField: 'maxDepth'),
          ColumnMapping(sourceColumn: 'my_dur', targetField: 'duration'),
        ],
      );

      const customParser = CsvImportParser(customMapping: customMapping);
      final result = await customParser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.length, 1);
      expect(dives.first['maxDepth'], 25.5);
    });
  });

  group('parse - metadata', () {
    test('includes parsing metadata', () async {
      const csv =
          'Date,Max. Depth\n'
          '2024-01-15,25.5\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.csv,
        ),
      );

      expect(result.metadata, isNotEmpty);
      expect(result.metadata['totalRows'], 1);
      expect(result.metadata['parsedDives'], 1);
    });
  });

  group('parse - type inference', () {
    test('infers numeric depth', () async {
      const csv =
          'Date,Max Depth\n'
          '2024-01-15,25.5\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.csv,
        ),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['maxDepth'], isA<double>());
    });

    test('infers dive number as int', () async {
      const csv =
          'Date,Dive Number\n'
          '2024-01-15,42\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.csv,
        ),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['diveNumber'], isA<int>());
      expect(dives.first['diveNumber'], 42);
    });
  });

  group('parse - date/time combining', () {
    test('combines separate date and time columns', () async {
      const csv =
          'Date,Time,Max Depth\n'
          '2024-01-15,14:30,25.5\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.csv,
        ),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(dateTime.year, 2024);
      expect(dateTime.month, 1);
      expect(dateTime.day, 15);
      expect(dateTime.hour, 14);
      expect(dateTime.minute, 30);
    });

    test('produces UTC DateTimes (utc-as-wall-time convention)', () async {
      const csv =
          'Date,Time,Max Depth\n'
          '2024-01-15,14:30,25.5\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.csv,
        ),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(
        dateTime.isUtc,
        isTrue,
        reason: 'CSV import must produce UTC DateTimes for wall-time storage',
      );
      expect(dateTime, DateTime.utc(2024, 1, 15, 14, 30));
    });

    test('date-only CSV produces UTC DateTime at midnight', () async {
      const csv =
          'Date,Max Depth\n'
          '2024-01-15,25.5\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.csv,
        ),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(dateTime.isUtc, isTrue);
      expect(dateTime, DateTime.utc(2024, 1, 15));
    });

    test('times are not shifted by local UTC offset (issue #60)', () async {
      // This is the exact scenario from issue #60: a user at UTC+4 imports
      // a CSV with time "11:22" and it should remain 11:22, not become 15:22.
      const csv =
          'Dive,Date,Time,Depth,Duration,,,Notes\n'
          '3,1998-08-05,11:22,15,45,,,\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.csv,
        ),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(dateTime.isUtc, isTrue);
      expect(
        dateTime.hour,
        11,
        reason: 'Time must not be shifted by UTC offset',
      );
      expect(dateTime.minute, 22);
    });

    test('all dives in multi-row CSV produce UTC DateTimes', () async {
      const csv =
          'Date,Time,Max Depth\n'
          '2024-01-15,08:00,20\n'
          '2024-01-15,14:30,25\n'
          '2024-01-16,09:45,18\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.csv,
        ),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(3));
      for (final dive in dives) {
        final dt = dive['dateTime'] as DateTime;
        expect(dt.isUtc, isTrue, reason: 'Every dive must have UTC dateTime');
      }
      expect((dives[0]['dateTime'] as DateTime).hour, 8);
      expect((dives[1]['dateTime'] as DateTime).hour, 14);
      expect((dives[2]['dateTime'] as DateTime).hour, 9);
    });

    test('custom mapping with date field produces UTC', () async {
      const csv =
          'dive_date,dive_time,depth\n'
          '2024-06-20,16:45,30\n';

      const customMapping = FieldMapping(
        name: 'Custom UTC',
        sourceApp: SourceApp.generic,
        columns: [
          ColumnMapping(sourceColumn: 'dive_date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'dive_time', targetField: 'time'),
          ColumnMapping(sourceColumn: 'depth', targetField: 'maxDepth'),
        ],
      );

      const customParser = CsvImportParser(customMapping: customMapping);
      final result = await customParser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(dateTime.isUtc, isTrue);
      expect(dateTime, DateTime.utc(2024, 6, 20, 16, 45));
    });

    test('time with seconds produces UTC', () async {
      const csv =
          'Date,Time,Max Depth\n'
          '2024-01-15,14:30:45,25.5\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.csv,
        ),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(dateTime.isUtc, isTrue);
      expect(dateTime.hour, 14);
      expect(dateTime.minute, 30);
    });
  });
}

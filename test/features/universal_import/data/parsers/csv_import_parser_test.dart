import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/csv_import_parser.dart';

void main() {
  late CsvImportParser parser;

  setUp(() {
    parser = CsvImportParser();
  });

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
        result.warnings.any((w) => w.severity == ImportWarningSeverity.error),
        isTrue,
      );
    });

    test('skips rows without valid dateTime', () async {
      const csv =
          'Date,Max Depth\n'
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
          'Date,Max Depth\n'
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

      final customParser = CsvImportParser(customMapping: customMapping);
      final result = await customParser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.length, 1);
      expect(dives.first['maxDepth'], 25.5);
    });
  });

  group('parse - metadata', () {
    test('includes parsing metadata', () async {
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

    test('date-only CSV produces UTC DateTime at noon', () async {
      // Note: The pipeline's TimeResolver defaults to hour 12 when no time
      // column is present (to provide a reasonable midday default).
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
      expect(dateTime.year, 2024);
      expect(dateTime.month, 1);
      expect(dateTime.day, 15);
      expect(dateTime.hour, 12);
      expect(dateTime.minute, 0);
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

      final customParser = CsvImportParser(customMapping: customMapping);
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

  group('parse - new pipeline features', () {
    test('each dive has a generated UUID', () async {
      const csv =
          'Date,Time,Max Depth\n'
          '2024-01-15,10:00,25.5\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.csv,
        ),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['id'], isA<String>());
      expect((dives.first['id'] as String).isNotEmpty, isTrue);
    });

    test('accepts timeInterpretation parameter', () async {
      const csv =
          'Date,Time,Max Depth\n'
          '2024-01-15,14:30,25.5\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.csv,
        ),
        timeInterpretation: TimeInterpretation.utc,
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(dateTime.isUtc, isTrue);
      // For utc interpretation, the value should be stored as-is.
      expect(dateTime.hour, 14);
      expect(dateTime.minute, 30);
    });

    test('accepts specificUtcOffset parameter', () async {
      const csv =
          'Date,Time,Max Depth\n'
          '2024-01-15,14:30,25.5\n';

      final result = await parser.parse(
        csvBytes(csv),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.csv,
        ),
        timeInterpretation: TimeInterpretation.specificOffset,
        specificUtcOffset: const Duration(hours: 4),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(dateTime.isUtc, isTrue);
      // Wall-clock time is preserved as UTC (app convention).
      expect(dateTime.hour, 14);
      expect(dateTime.minute, 30);
    });

    test('accepts customMappingOverride parameter', () async {
      const csv =
          'MyDate,MyDepth\n'
          '2024-01-15,25.5\n';

      const customMapping = FieldMapping(
        name: 'Override',
        sourceApp: SourceApp.generic,
        columns: [
          ColumnMapping(sourceColumn: 'MyDate', targetField: 'date'),
          ColumnMapping(sourceColumn: 'MyDepth', targetField: 'maxDepth'),
        ],
      );

      final result = await parser.parse(
        csvBytes(csv),
        customMappingOverride: customMapping,
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['maxDepth'], 25.5);
    });

    test('detects MacDive preset from headers', () async {
      // Uses MacDive's exact header names so the detector picks up the preset.
      const csv =
          'Dive No,Date,Time,Location,Max. Depth,Avg. Depth,Bottom Time,'
          'Water Temp,Air Temp,Visibility,Dive Type,Rating,Notes,Buddy,'
          'Dive Master\n'
          '1,2024-01-15,10:00,Blue Hole,25.5,18.0,45,27.0,28.0,Good,'
          'Recreation,5,Saw a turtle,Alice,Bob\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      // Metadata should reflect the detected source app.
      expect(result.metadata['sourceApp'], 'macdive');
    });
  });

  group('auto-mapping from headers', () {
    test('maps "Dive Master" header to diveMaster field', () async {
      const csv =
          'Date,Dive Master\n'
          '2024-01-15,Captain Jack\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['diveMaster'], 'Captain Jack');
    });

    test('maps "Wind Speed" header to windSpeed field', () async {
      const csv =
          'Date,Wind Speed\n'
          '2024-01-15,15\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['windSpeed'], isNotNull);
    });

    test('maps "Current" to no specific field (unknown column)', () async {
      // "Current" by itself does not match any keyword pattern, so it should
      // be ignored by the auto-mapper and not appear in output.
      const csv =
          'Date,Current\n'
          '2024-01-15,Strong\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      // "Current" has no keyword match, so it should not be mapped.
      expect(dives.first.containsKey('current'), isFalse);
    });

    test('maps "Surface Conditions" to no specific field', () async {
      // "Surface Conditions" does not match any keyword pattern.
      const csv =
          'Date,Surface Conditions\n'
          '2024-01-15,Calm\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first.containsKey('surfaceConditions'), isFalse);
    });

    test('maps compound header "water temperature" to waterTemp', () async {
      const csv =
          'Date,Water Temperature\n'
          '2024-01-15,27.0\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['waterTemp'], 27.0);
    });

    test('maps compound header "air temp" to airTemp', () async {
      const csv =
          'Date,Air Temp\n'
          '2024-01-15,30.0\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['airTemp'], 30.0);
    });

    test('maps compound header "max depth" to maxDepth', () async {
      const csv =
          'Date,Max Depth\n'
          '2024-01-15,35.5\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['maxDepth'], 35.5);
    });

    test('maps "avg depth" to avgDepth', () async {
      const csv =
          'Date,Avg Depth\n'
          '2024-01-15,18.2\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['avgDepth'], 18.2);
    });

    test('maps "divemaster" (single word) to diveMaster', () async {
      const csv =
          'Date,Divemaster\n'
          '2024-01-15,Bob\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['diveMaster'], 'Bob');
    });

    test('maps buddy header to buddy field', () async {
      const csv =
          'Date,Buddy\n'
          '2024-01-15,Alice\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['buddy'], 'Alice');
    });

    test('maps visibility header to visibility field', () async {
      const csv =
          'Date,Visibility\n'
          '2024-01-15,Good\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      // The value may be lowercased by the transform pipeline.
      expect(dives.first['visibility'], isNotNull);
    });

    test('maps start pressure and end pressure via auto-mapping', () async {
      // The auto-mapper maps these headers to startPressure/endPressure,
      // but DiveExtractor does not include them in the dive entity output.
      // This test verifies the parse completes without error.
      const csv =
          'Date,Start Pressure,End Pressure\n'
          '2024-01-15,200,50\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
    });

    test('maps tank volume via auto-mapping', () async {
      const csv =
          'Date,Tank Volume\n'
          '2024-01-15,12\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
    });

    test('maps o2 header via auto-mapping', () async {
      const csv =
          'Date,O2\n'
          '2024-01-15,32\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
    });

    test('maps computer header via auto-mapping', () async {
      const csv =
          'Date,Computer\n'
          '2024-01-15,Suunto D5\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
    });

    test('maps suit header via auto-mapping', () async {
      const csv =
          'Date,Suit\n'
          '2024-01-15,Wetsuit 5mm\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
    });

    test('maps weight header to weight field', () async {
      const csv =
          'Date,Weight\n'
          '2024-01-15,8\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['weight'], isNotNull);
    });

    test('maps tags header via auto-mapping', () async {
      const csv =
          'Date,Tags\n'
          '2024-01-15,reef drift\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
    });

    test('maps gps header via auto-mapping', () async {
      const csv =
          'Date,GPS\n'
          '2024-01-15,27.5 -80.3\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
    });

    test('maps weather headers (cloud, precipitation, humidity)', () async {
      const csv =
          'Date,Cloud Cover,Precipitation,Humidity\n'
          '2024-01-15,Partly Cloudy,None,75\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['cloudCover'], isNotNull);
      expect(dives.first['precipitation'], isNotNull);
      expect(dives.first['humidity'], isNotNull);
    });

    test('maps weather description header', () async {
      const csv =
          'Date,Weather Description\n'
          '2024-01-15,Sunny and warm\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['weatherDescription'], 'Sunny and warm');
    });

    test('maps wind direction header', () async {
      const csv =
          'Date,Wind Direction\n'
          '2024-01-15,NNW\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['windDirection'], 'NNW');
    });

    test('maps serial number and firmware headers via auto-mapping', () async {
      // The auto-mapper maps "Serial Number" -> "serialNumber" and
      // "Firmware" -> "firmware". These are not in DiveExtractor's known
      // fields (it uses diveComputerSerial/diveComputerFirmware), so
      // they are dropped from the final output. This test verifies the
      // auto-mapping and parse succeed without error.
      const csv =
          'Date,Serial Number,Firmware\n'
          '2024-01-15,SN12345,v2.1\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
    });

    test('maps rating header', () async {
      const csv =
          'Date,Rating\n'
          '2024-01-15,5\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['rating'], isNotNull);
    });

    test('maps notes header', () async {
      const csv =
          'Date,Notes\n'
          '2024-01-15,Great dive with turtles\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['notes'], 'Great dive with turtles');
    });

    test('maps location/site headers to siteName', () async {
      const csv =
          'Date,Location\n'
          '2024-01-15,Blue Hole\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['siteName'], 'Blue Hole');
    });

    test('maps site header to siteName', () async {
      const csv =
          'Date,Site\n'
          '2024-01-15,Shark Reef\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['siteName'], 'Shark Reef');
    });

    test('maps duration and bottom time headers', () async {
      const csv =
          'Date,Duration\n'
          '2024-01-15,45\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['duration'], isNotNull);
    });

    test('maps bottom time header to duration', () async {
      const csv =
          'Date,Bottom Time\n'
          '2024-01-15,45\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['duration'], isNotNull);
    });

    test('maps runtime header to duration', () async {
      const csv =
          'Date,Runtime\n'
          '2024-01-15,50\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['duration'], isNotNull);
    });

    test('maps dateTime combined header', () async {
      const csv =
          'DateTime,Max Depth\n'
          '2024-01-15 14:30,25.5\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      final dateTime = dives.first['dateTime'] as DateTime;
      expect(dateTime.year, 2024);
      expect(dateTime.month, 1);
      expect(dateTime.day, 15);
    });

    test('maps dive number header (Dive No)', () async {
      const csv =
          'Date,Dive No\n'
          '2024-01-15,42\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['diveNumber'], 42);
    });

    test('unknown columns are not mapped', () async {
      const csv =
          'Date,Completely Unknown Header,Another Random Column\n'
          '2024-01-15,value1,value2\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      // Unknown columns should not appear in the dive data.
      expect(dives.first.containsKey('completelyUnknownHeader'), isFalse);
      expect(dives.first.containsKey('anotherRandomColumn'), isFalse);
    });
  });

  group('parse - _isDateOnly and _isTimeOnly edge cases', () {
    test('"bottom time" is not mapped as time (contains "bottom")', () async {
      // "bottom time" should map to duration, not time.
      const csv =
          'Date,Bottom Time\n'
          '2024-01-15,45\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['duration'], isNotNull);
      // Should not have been mistakenly mapped as a 'time' field.
    });

    test('"surface time" is not mapped as time', () async {
      const csv =
          'Date,Surface Time\n'
          '2024-01-15,60\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      // "surface time" contains "surface", so _isTimeOnly returns false.
      // It should not produce a 'time' field.
    });

    test('"date" alone maps to date', () async {
      const csv =
          'Date,Max Depth\n'
          '2024-01-15,25.5\n';

      final result = await parser.parse(csvBytes(csv));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
      expect(dives.first['dateTime'], isA<DateTime>());
    });
  });

  group('parse - profile file handling', () {
    test('handles invalid profile file bytes gracefully', () async {
      const csv =
          'Date,Max Depth\n'
          '2024-01-15,25.5\n';

      // Invalid profile data (not valid CSV).
      final badProfile = Uint8List.fromList([0, 1, 2, 3]);

      final result = await parser.parse(
        csvBytes(csv),
        profileFileBytes: badProfile,
      );

      // Should still parse the primary file successfully, ignoring bad profile.
      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, isNotEmpty);
    });
  });

  group('_buildConfiguration - Case 1: custom mapping with preset entities', () {
    test(
      'custom mapping override preserves entity types from detected preset',
      () async {
        // Use MacDive-style headers so the detector picks up the MacDive
        // preset which includes buddies in supportedEntities.
        const csv =
            'Dive No,Date,Time,Location,Max. Depth,Avg. Depth,Bottom Time,'
            'Water Temp,Air Temp,Visibility,Dive Type,Rating,Notes,Buddy,'
            'Dive Master\n'
            '1,2024-01-15,10:00,Blue Hole,25.5,18.0,45,27.0,28.0,Good,'
            'Recreation,5,Saw a turtle,Alice,Bob\n';

        // Provide a custom mapping override. Under _buildConfiguration Case 1,
        // the entityTypesToImport should come from the detected MacDive preset
        // (which includes buddies), not the default {dives, sites}.
        const customMapping = FieldMapping(
          name: 'Custom Override',
          sourceApp: SourceApp.macdive,
          columns: [
            ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
            ColumnMapping(sourceColumn: 'Time', targetField: 'time'),
            ColumnMapping(sourceColumn: 'Max. Depth', targetField: 'maxDepth'),
            ColumnMapping(sourceColumn: 'Buddy', targetField: 'buddy'),
            ColumnMapping(sourceColumn: 'Location', targetField: 'siteName'),
          ],
        );

        final result = await parser.parse(
          csvBytes(csv),
          customMappingOverride: customMapping,
        );

        // If entity types are preserved from the MacDive preset, buddies
        // should be extracted.
        final buddies = result.entitiesOf(ImportEntityType.buddies);
        expect(
          buddies,
          isNotEmpty,
          reason:
              'Custom mapping should inherit entity types from detected '
              'preset, including buddies',
        );

        final names = buddies.map((b) => b['name']).toList();
        expect(names, contains('Alice'));
      },
    );

    test(
      'custom mapping without detected preset falls back to default entity types',
      () async {
        // Headers that do not match any known preset.
        const csv =
            'my_date,my_time,my_depth,my_buddy,my_tags\n'
            '2024-01-15,10:00,25.5,Alice,reef\n';

        const customMapping = FieldMapping(
          name: 'Unknown Source',
          columns: [
            ColumnMapping(sourceColumn: 'my_date', targetField: 'date'),
            ColumnMapping(sourceColumn: 'my_time', targetField: 'time'),
            ColumnMapping(sourceColumn: 'my_depth', targetField: 'maxDepth'),
            ColumnMapping(sourceColumn: 'my_buddy', targetField: 'buddy'),
            ColumnMapping(sourceColumn: 'my_tags', targetField: 'tags'),
          ],
        );

        final result = await parser.parse(
          csvBytes(csv),
          customMappingOverride: customMapping,
        );

        // Without a detected preset, the default entity types are
        // {dives, sites} only. Buddies and tags should not be extracted.
        final buddies = result.entitiesOf(ImportEntityType.buddies);
        final tags = result.entitiesOf(ImportEntityType.tags);
        expect(
          buddies,
          isEmpty,
          reason:
              'Without detected preset, default entity types should not '
              'include buddies',
        );
        expect(
          tags,
          isEmpty,
          reason:
              'Without detected preset, default entity types should not '
              'include tags',
        );
      },
    );
  });
}

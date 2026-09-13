import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/core/services/export/csv/dive_csv_columns.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';

import '../../../../helpers/mock_file_picker_platform.dart';

void main() {
  late CsvExportService service;

  setUp(() {
    service = CsvExportService();
  });

  group('Custom Fields column (#1814)', () {
    test('holds the dive\'s fields as JSON in their own order', () {
      final dive = Dive(
        id: 'dive-1',
        dateTime: DateTime(2026, 3, 28, 10, 0),
        customFields: const [
          DiveCustomField(id: 'b', key: 'flag', sortOrder: 1),
          DiveCustomField(id: 'a', key: 'zulu', value: 'x', sortOrder: 0),
        ],
      );

      final rows = const CsvToListConverter().convert(
        service.generateDivesCsvContent([dive]),
      );
      final cell = rows[1][rows.first.indexOf(DiveCsvColumns.customFields)];

      expect(jsonDecode(cell as String), [
        {'key': 'zulu', 'value': 'x'},
        {'key': 'flag', 'value': ''},
      ]);
    });
  });

  group('sanitizeCsvField', () {
    test('quotes a value that starts with a formula character', () {
      expect(service.sanitizeCsvField('=1+1'), "'=1+1");
      expect(service.sanitizeCsvField('-5'), "'-5");
    });

    test('quotes a value that already starts with a quote, so the import '
        'can tell the guard from the text (#1814)', () {
      expect(service.sanitizeCsvField("'=1+1"), "''=1+1");
      expect(service.sanitizeCsvField("'hello"), "''hello");
    });

    test('leaves plain text and empty values alone', () {
      expect(service.sanitizeCsvField('GoPro'), 'GoPro');
      expect(service.sanitizeCsvField(''), '');
      expect(service.sanitizeCsvField(null), '');
    });
  });

  group('generateDivesCsvContent', () {
    test('includes bottomTime in CSV output', () {
      final dives = [
        Dive(
          id: 'dive-1',
          diveNumber: 1,
          dateTime: DateTime(2026, 3, 28, 10, 0),
          bottomTime: const Duration(minutes: 45),
          runtime: const Duration(minutes: 50),
          maxDepth: 25.0,
          tanks: const [],
          profile: const [],
          gear: looseGear(const []),
          notes: '',
          photoIds: const [],
          sightings: const [],
          weights: const [],
          tags: const [],
        ),
      ];

      final csv = service.generateDivesCsvContent(dives);

      expect(csv, contains('45'));
      expect(csv, contains('50'));
    });

    test('exports tank pressure values with 1 decimal precision', () {
      final dives = [
        Dive(
          id: 'dive-1',
          diveNumber: 1,
          dateTime: DateTime(2026, 3, 28, 10, 0),
          bottomTime: const Duration(minutes: 45),
          maxDepth: 25.0,
          tanks: const [
            DiveTank(
              id: 't1',
              startPressure: 206.843,
              endPressure: 50.5,
              volume: 11.1,
            ),
          ],
          profile: const [],
          gear: looseGear(const []),
          notes: '',
          photoIds: const [],
          sightings: const [],
          weights: const [],
          tags: const [],
        ),
      ];

      final csv = service.generateDivesCsvContent(dives);

      // Pressures exported with 1 decimal for round-trip fidelity
      expect(csv, contains('206.8'));
      expect(csv, contains('50.5'));
    });

    test('writes the shared column constants, then the site place columns '
        '(#1814)', () {
      final dive = Dive(
        id: 'dive-1',
        dateTime: DateTime(2026, 3, 28, 10, 0),
        site: const DiveSite(
          id: 'site-1',
          name: 'Blue Hole',
          city: 'Victoria',
          region: 'Gozo',
          country: 'Malta',
        ),
      );

      final rows = const CsvToListConverter().convert(
        service.generateDivesCsvContent([dive]),
      );

      expect(rows.first, DiveCsvColumns.fixed);
      // The place columns come after every pre-#1814 column, so a sheet that
      // addresses the export by position keeps its offsets.
      expect(
        rows.first.indexOf(DiveCsvColumns.siteCity),
        rows.first.indexOf(DiveCsvColumns.weatherDescription) + 1,
      );
      final row = rows[1];
      expect(row[rows.first.indexOf(DiveCsvColumns.customFields)], '');
      expect(row[rows.first.indexOf(DiveCsvColumns.siteCity)], 'Victoria');
      expect(row[rows.first.indexOf(DiveCsvColumns.siteRegion)], 'Gozo');
      expect(row[rows.first.indexOf(DiveCsvColumns.siteCountry)], 'Malta');
    });
  });

  group('save to file', () {
    late MockFilePickerPlatform mockPicker;
    late FilePickerPlatform originalPicker;

    setUp(() {
      originalPicker = FilePickerPlatform.instance;
      mockPicker = MockFilePickerPlatform();
      FilePickerPlatform.instance = mockPicker;
    });

    tearDown(() {
      FilePickerPlatform.instance = originalPicker;
    });

    test('saveDivesCsvToFile returns null when user cancels', () async {
      mockPicker.saveFileResult = null;
      final result = await service.saveDivesCsvToFile([], dialogTitle: 'Save');
      expect(result, isNull);
    });

    test('saveSitesCsvToFile returns null when user cancels', () async {
      mockPicker.saveFileResult = null;
      final result = await service.saveSitesCsvToFile(
        <DiveSite>[],
        dialogTitle: 'Save',
      );
      expect(result, isNull);
    });

    test('saveEquipmentCsvToFile returns null when user cancels', () async {
      mockPicker.saveFileResult = null;
      final result = await service.saveEquipmentCsvToFile(
        <EquipmentItem>[],
        dialogTitle: 'Save',
      );
      expect(result, isNull);
    });
  });

  group('generateObservationsCsvContent (condition phase 3a)', () {
    test('writes the header and quotes a note with a comma', () {
      final csv = service.generateObservationsCsvContent([
        (
          equipmentName: 'Apeks XTX',
          equipmentType: 'Regulator',
          diveNumber: 42,
          observation: EquipmentObservation(
            id: 'o1',
            equipmentId: 'reg',
            diveId: 'd1',
            observedAt: DateTime.utc(2026, 3, 14, 11),
            status: ObservationStatus.issue,
            issueTags: const [ObservationTag.freeFlow, ObservationTag.leak],
            note: 'Cold, 4 C',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ),
        (
          equipmentName: 'Apeks XTX',
          equipmentType: 'Regulator',
          diveNumber: null,
          observation: EquipmentObservation(
            id: 'o2',
            equipmentId: 'reg',
            observedAt: DateTime.utc(2026, 3, 15, 9),
            status: ObservationStatus.ok,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ),
      ]);
      final lines = csv.trim().split(RegExp(r'\r?\n'));
      expect(
        lines.first,
        'Equipment,Equipment Type,Date,Dive Number,Status,Tags,Note',
      );
      expect(lines, hasLength(3));
      expect(lines[1], contains('Apeks XTX,Regulator,2026-03-14,42,issue,'));
      expect(lines[1], contains('freeFlow; leak'));
      expect(lines[1], contains('"Cold, 4 C"'));
      expect(lines[2], contains(',,ok,,'));
    });

    test('a newer peer\'s tags are exported with the known ones', () {
      // The entity keeps names this build cannot read; dropping them here
      // would lose part of the record. They come from another device, so
      // the cell is still neutralised.
      final csv = service.generateObservationsCsvContent([
        (
          equipmentName: 'Reg',
          equipmentType: 'Regulator',
          diveNumber: null,
          observation: EquipmentObservation(
            id: 'o1',
            equipmentId: 'reg',
            observedAt: DateTime.utc(2026, 3, 14),
            status: ObservationStatus.issue,
            issueTags: const [ObservationTag.leak],
            unrecognizedTags: const ['futureTag'],
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ),
        (
          equipmentName: 'Reg',
          equipmentType: 'Regulator',
          diveNumber: null,
          observation: EquipmentObservation(
            id: 'o2',
            equipmentId: 'reg',
            observedAt: DateTime.utc(2026, 3, 15),
            status: ObservationStatus.issue,
            unrecognizedTags: const ['=cmd'],
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ),
      ]);
      final lines = csv.trim().split(RegExp(r'\r?\n'));
      expect(lines[1], contains(',leak; futureTag,'));
      expect(lines[2], contains(",'=cmd,"));
    });

    test(
      'a formula-looking note or name is neutralised and kept on one row',
      () {
        final csv = service.generateObservationsCsvContent([
          (
            equipmentName: '=HYPERLINK("x")',
            equipmentType: 'Regulator',
            diveNumber: null,
            observation: EquipmentObservation(
              id: 'o1',
              equipmentId: 'reg',
              observedAt: DateTime.utc(2026, 3, 14),
              status: ObservationStatus.ok,
              note: '=1+1\nsecond line',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ),
        ]);
        final lines = csv.trim().split(RegExp(r'\r?\n'));
        // One header and one data row: the note's line break is flattened,
        // as the trips export does.
        expect(lines, hasLength(2));
        // A leading quote makes a spreadsheet read the cell as text.
        expect(lines[1], startsWith('"\'=HYPERLINK(""x"")"'));
        expect(lines[1], endsWith("'=1+1 second line"));
      },
    );
  });
}

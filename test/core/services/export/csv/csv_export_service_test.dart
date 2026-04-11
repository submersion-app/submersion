import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/mock_file_picker_platform.dart';

void main() {
  late CsvExportService service;

  setUp(() {
    service = CsvExportService();
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
          equipment: const [],
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
          equipment: const [],
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
      final result = await service.saveDivesCsvToFile([]);
      expect(result, isNull);
    });

    test('saveSitesCsvToFile returns null when user cancels', () async {
      mockPicker.saveFileResult = null;
      final result = await service.saveSitesCsvToFile(<DiveSite>[]);
      expect(result, isNull);
    });

    test('saveEquipmentCsvToFile returns null when user cancels', () async {
      mockPicker.saveFileResult = null;
      final result = await service.saveEquipmentCsvToFile(<EquipmentItem>[]);
      expect(result, isNull);
    });
  });
}

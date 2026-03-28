import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/excel_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  late ExcelExportService service;

  setUp(() {
    service = ExcelExportService();
  });

  Dive makeDive({
    String id = 'dive-1',
    int? diveNumber,
    DateTime? dateTime,
    Duration? bottomTime,
    Duration? runtime,
    double? maxDepth,
    double? avgDepth,
    double? waterTemp,
  }) {
    return Dive(
      id: id,
      diveNumber: diveNumber,
      dateTime: dateTime ?? DateTime(2026, 3, 28, 10, 0),
      bottomTime: bottomTime,
      runtime: runtime,
      maxDepth: maxDepth,
      avgDepth: avgDepth,
      waterTemp: waterTemp,
      tanks: const [],
      profile: const [],
      equipment: const [],
      notes: '',
      photoIds: const [],
      sightings: const [],
      weights: const [],
      tags: const [],
    );
  }

  group('generateExcelBytes', () {
    test('generates valid Excel bytes with bottomTime data', () async {
      final dives = [
        makeDive(
          id: 'd1',
          diveNumber: 1,
          bottomTime: const Duration(minutes: 45),
          runtime: const Duration(minutes: 50),
          maxDepth: 25.0,
          waterTemp: 22.0,
        ),
        makeDive(
          id: 'd2',
          diveNumber: 2,
          bottomTime: const Duration(minutes: 30),
          runtime: const Duration(minutes: 35),
          maxDepth: 18.0,
          waterTemp: 24.0,
        ),
      ];

      final bytes = await service.generateExcelBytes(
        dives: dives,
        sites: const [],
        equipment: const [],
        depthUnit: DepthUnit.meters,
        temperatureUnit: TemperatureUnit.celsius,
        pressureUnit: PressureUnit.bar,
        volumeUnit: VolumeUnit.liters,
        dateFormat: DateFormatPreference.yyyymmdd,
      );

      // Should produce valid XLSX bytes
      expect(bytes, isNotEmpty);
      // XLSX files start with PK zip header
      expect(bytes[0], 0x50); // 'P'
      expect(bytes[1], 0x4B); // 'K'
    });

    test('generates Excel with null bottomTime', () async {
      final dives = [makeDive(id: 'd1', diveNumber: 1, maxDepth: 20.0)];

      final bytes = await service.generateExcelBytes(
        dives: dives,
        sites: const [],
        equipment: const [],
        depthUnit: DepthUnit.meters,
        temperatureUnit: TemperatureUnit.celsius,
        pressureUnit: PressureUnit.bar,
        volumeUnit: VolumeUnit.liters,
        dateFormat: DateFormatPreference.yyyymmdd,
      );

      expect(bytes, isNotEmpty);
    });

    test('statistics sheet includes bottomTime calculations', () async {
      // Multiple dives to trigger summary statistics (longest dive, total time)
      final dives = [
        makeDive(
          id: 'd1',
          diveNumber: 1,
          bottomTime: const Duration(minutes: 45),
          maxDepth: 25.0,
          waterTemp: 22.0,
        ),
        makeDive(
          id: 'd2',
          diveNumber: 2,
          bottomTime: const Duration(minutes: 60),
          maxDepth: 30.0,
          waterTemp: 20.0,
          dateTime: DateTime(2026, 3, 29, 10, 0),
        ),
        makeDive(
          id: 'd3',
          diveNumber: 3,
          bottomTime: const Duration(minutes: 30),
          maxDepth: 15.0,
          waterTemp: 24.0,
          dateTime: DateTime(2025, 6, 15, 10, 0), // Different year
        ),
      ];

      final bytes = await service.generateExcelBytes(
        dives: dives,
        sites: const [],
        equipment: const [],
        depthUnit: DepthUnit.meters,
        temperatureUnit: TemperatureUnit.celsius,
        pressureUnit: PressureUnit.bar,
        volumeUnit: VolumeUnit.liters,
        dateFormat: DateFormatPreference.yyyymmdd,
      );

      // Excel was generated without errors
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });
  });
}

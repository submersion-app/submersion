import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/core/services/export/excel/excel_export_service.dart';
import 'package:submersion/core/services/export/kml/kml_export_service.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/core/constants/units.dart';

import '../../../helpers/mock_file_picker_platform.dart';

/// Tests that all export service save-to-file methods correctly delegate to
/// [FilePicker.saveFile] and return null when the user cancels.
///
/// These tests cover the FilePicker.platform -> FilePicker static API migration
/// from file_picker 10.x to 11.x.
void main() {
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

  group('CsvExportService save to file', () {
    late CsvExportService service;
    setUp(() => service = CsvExportService());

    test('saveDivesCsvToFile returns null when cancelled', () async {
      mockPicker.saveFileResult = null;
      expect(await service.saveDivesCsvToFile([]), isNull);
    });

    test('saveSitesCsvToFile returns null when cancelled', () async {
      mockPicker.saveFileResult = null;
      expect(await service.saveSitesCsvToFile(<DiveSite>[]), isNull);
    });

    test('saveEquipmentCsvToFile returns null when cancelled', () async {
      mockPicker.saveFileResult = null;
      expect(await service.saveEquipmentCsvToFile(<EquipmentItem>[]), isNull);
    });
  });

  group('ExcelExportService save to file', () {
    late ExcelExportService service;
    setUp(() => service = ExcelExportService());

    test('saveExcelToFile returns null when cancelled', () async {
      mockPicker.saveFileResult = null;
      expect(
        await service.saveExcelToFile(
          dives: <Dive>[],
          sites: <DiveSite>[],
          equipment: <EquipmentItem>[],
          depthUnit: DepthUnit.meters,
          temperatureUnit: TemperatureUnit.celsius,
          pressureUnit: PressureUnit.bar,
          volumeUnit: VolumeUnit.liters,
          dateFormat: DateFormatPreference.yyyymmdd,
        ),
        isNull,
      );
    });
  });

  group('KmlExportService save to file', () {
    late KmlExportService service;
    setUp(() => service = KmlExportService());

    test('saveKmlToFile returns null when cancelled', () async {
      mockPicker.saveFileResult = null;
      const site = DiveSite(
        id: 's1',
        name: 'Test Site',
        location: GeoPoint(28.5, -80.6),
      );
      final (path, _) = await service.saveKmlToFile(
        sites: [site],
        dives: <Dive>[],
        depthUnit: DepthUnit.meters,
        dateFormat: DateFormatPreference.yyyymmdd,
      );
      expect(path, isNull);
    });
  });

  group('file_export_utils', () {
    test('saveImageToFile returns null when cancelled', () async {
      mockPicker.saveFileResult = null;
      expect(await saveImageToFile([1, 2, 3], 'test.png'), isNull);
    });

    test('savePdfToFile returns null when cancelled', () async {
      mockPicker.saveFileResult = null;
      expect(await savePdfToFile([1, 2, 3], 'test.pdf'), isNull);
    });
  });
}

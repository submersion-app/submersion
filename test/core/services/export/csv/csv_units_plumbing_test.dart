import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/export_service.dart';

import '../../../../helpers/mock_file_picker_platform.dart';
import 'csv_dives_writer_test.dart' show imperial;
import 'csv_test_fixtures.dart';

/// The `units` choice reaches every CSV entry point on the ExportService
/// facade, including the save-to-file paths (#1813).
void main() {
  late MockFilePickerPlatform mockPicker;
  late FilePickerPlatform originalPicker;

  setUp(() {
    originalPicker = FilePickerPlatform.instance;
    mockPicker = MockFilePickerPlatform()
      ..saveFileResult = Uri.file('/tmp/export.csv');
    FilePickerPlatform.instance = mockPicker;
  });

  tearDown(() => FilePickerPlatform.instance = originalPicker);

  final units = CsvExportUnits.fromSettings(imperial);
  final service = ExportService();

  String header(String csv) => csv.split('\r\n').first;
  String saved() => utf8.decode(mockPicker.lastSavedBytes!);

  test('generating content honours the units', () {
    expect(
      header(service.generateDivesCsvContent(goldenDives(), units: units)),
      contains('Max Depth (ft)'),
    );
    expect(
      header(service.generateSitesCsvContent(goldenSites(), units: units)),
      contains('Max Depth (ft)'),
    );
    expect(
      header(
        service.generateEquipmentCsvContent(goldenEquipment(), units: units),
      ),
      contains('Buoyancy (lbs)'),
    );
  });

  test('saving dives writes the chosen units', () async {
    await service.saveDivesCsvToFile(
      goldenDives(),
      dialogTitle: 'Save',
      units: units,
    );
    expect(header(saved()), contains('Water Temp (°F)'));
  });

  test('saving sites writes the chosen units', () async {
    await service.saveSitesCsvToFile(
      goldenSites(),
      dialogTitle: 'Save',
      units: units,
    );
    expect(header(saved()), contains('Max Depth (ft)'));
  });

  test('saving equipment writes the chosen units and parts', () async {
    await service.saveEquipmentCsvToFile(
      goldenEquipment(),
      componentNames: goldenComponentNames(),
      dialogTitle: 'Save',
      units: units,
    );
    expect(header(saved()), contains('Dry Weight (lbs)'));
    expect(saved(), contains('Mk25; Long hose'));
  });

  test('the default is still the historical metric file', () async {
    await service.saveDivesCsvToFile(goldenDives(), dialogTitle: 'Save');
    expect(header(saved()), contains('Max Depth (m)'));
  });
}

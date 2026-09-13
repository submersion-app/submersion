import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';

import '../../../helpers/mock_file_picker_platform.dart';

/// Every dives CSV entry point hands the diver's dive types through, so each
/// type is written under the name the diver gave it (#1834).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory workDir;
  late MockFilePickerPlatform picker;
  late FilePickerPlatform originalPicker;

  setUpAll(() async {
    workDir = await Directory.systemTemp.createTemp('export_dive_types_');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? workDir.path
          : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async => null,
    );
  });

  tearDownAll(() async {
    if (await workDir.exists()) await workDir.delete(recursive: true);
  });

  setUp(() {
    originalPicker = FilePickerPlatform.instance;
    picker = MockFilePickerPlatform();
    FilePickerPlatform.instance = picker;
  });

  tearDown(() => FilePickerPlatform.instance = originalPicker);

  final custom = DiveTypeEntity(
    id: 'search_recovery_1a2b3c4d',
    name: 'Search & Recovery',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final dives = [
    Dive(id: 'd1', dateTime: DateTime(2026, 1, 1), diveTypeIds: [custom.id]),
  ];
  final diveTypesById = {custom.id: custom};

  test('generateDivesCsvContent passes the dive types on', () {
    final csv = ExportService().generateDivesCsvContent(
      dives,
      diveTypesById: diveTypesById,
    );

    expect(csv, contains('Search & Recovery'));
  });

  test('exportDivesToCsv passes the dive types on', () async {
    final path = await ExportService().exportDivesToCsv(
      dives,
      diveTypesById: diveTypesById,
    );

    expect(await File(path).readAsString(), contains('Search & Recovery'));
  });

  test('CsvExportService.exportDivesToCsv passes the dive types on', () async {
    final path = await CsvExportService().exportDivesToCsv(
      dives,
      diveTypesById: diveTypesById,
    );

    expect(await File(path).readAsString(), contains('Search & Recovery'));
  });

  test('saveDivesCsvToFile passes the dive types on', () async {
    picker.saveFileResult = Uri.file('${workDir.path}/saved.csv');

    await ExportService().saveDivesCsvToFile(
      dives,
      dialogTitle: 'Save Dives CSV',
      diveTypesById: diveTypesById,
    );

    expect(utf8.decode(picker.lastSavedBytes!), contains('Search & Recovery'));
  });
}

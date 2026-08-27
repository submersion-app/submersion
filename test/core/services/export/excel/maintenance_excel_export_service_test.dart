import 'dart:io';

import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/maintenance_excel_export_service.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

import '../../../../helpers/mock_file_picker_platform.dart';

void main() {
  late MaintenanceExcelExportService service;

  setUp(() => service = MaintenanceExcelExportService());

  final date = DateTime(2026, 3, 14);

  MaintenanceLogRow row({
    String task = 'Scrubber repack',
    double? cost = 45,
    String notes = 'Packed 2.4kg',
    DateTime? nextDue,
  }) => (
    equipmentName: 'JJ-CCR',
    equipmentType: 'Rebreather',
    serviceTypeName: task,
    serviceCategory: ServiceCategory.cleaning,
    record: ServiceRecord(
      id: 'r1',
      equipmentId: 'e1',
      serviceCategory: ServiceCategory.cleaning,
      serviceKindId: 'scrubber-repack',
      serviceDate: date,
      provider: 'DiveShop Bonn',
      cost: cost,
      currency: 'EUR',
      nextServiceDue: nextDue ?? DateTime(2026, 6, 14),
      notes: notes,
      createdAt: date,
      updatedAt: date,
    ),
  );

  String? cellText(xl.Sheet sheet, int rowIndex, int col) {
    final value = sheet.rows[rowIndex][col]?.value;
    return value is xl.TextCellValue ? value.value.toString() : null;
  }

  test('writes the header row', () {
    final excel = xl.Excel.createExcel();
    service.buildSheet(
      excel,
      rows: [row()],
      dateFormat: DateFormatPreference.yyyymmdd,
    );

    final sheet = excel[MaintenanceExcelExportService.maintenanceSheet];
    final headers = [
      for (var col = 0; col < 10; col++) cellText(sheet, 0, col),
    ];

    expect(headers, [
      'Equipment',
      'Equipment Type',
      'Service Type',
      'Category',
      'Date',
      'Provider',
      'Cost',
      'Currency',
      'Next Due',
      'Notes',
    ]);
  });

  test('maps a record onto one row', () {
    final excel = xl.Excel.createExcel();
    service.buildSheet(
      excel,
      rows: [row()],
      dateFormat: DateFormatPreference.yyyymmdd,
    );

    final sheet = excel[MaintenanceExcelExportService.maintenanceSheet];
    expect(cellText(sheet, 1, 0), 'JJ-CCR');
    expect(cellText(sheet, 1, 1), 'Rebreather');
    expect(cellText(sheet, 1, 2), 'Scrubber repack');
    // The workbook is an analysis target, so the category stays English
    // rather than following the diver's locale.
    expect(cellText(sheet, 1, 3), 'Cleaning');
    expect(cellText(sheet, 1, 5), 'DiveShop Bonn');
    expect((sheet.rows[1][6]?.value as xl.DoubleCellValue).value, 45.0);
    expect(cellText(sheet, 1, 7), 'EUR');
    expect(cellText(sheet, 1, 9), 'Packed 2.4kg');
  });

  test('an untagged record leaves the task column blank', () {
    final excel = xl.Excel.createExcel();
    service.buildSheet(
      excel,
      rows: [row(task: '')],
      dateFormat: DateFormatPreference.yyyymmdd,
    );

    final sheet = excel[MaintenanceExcelExportService.maintenanceSheet];
    expect(cellText(sheet, 1, 2), isEmpty);
  });

  test('newlines in notes are flattened so the row stays one line', () {
    final excel = xl.Excel.createExcel();
    service.buildSheet(
      excel,
      rows: [row(notes: 'first\nsecond')],
      dateFormat: DateFormatPreference.yyyymmdd,
    );

    final sheet = excel[MaintenanceExcelExportService.maintenanceSheet];
    expect(cellText(sheet, 1, 9), 'first second');
  });

  test('generateBytes produces a decodable workbook without Sheet1', () {
    final bytes = service.generateBytes(
      rows: [row()],
      dateFormat: DateFormatPreference.yyyymmdd,
    );

    expect(bytes, isNotEmpty);
    final decoded = xl.Excel.decodeBytes(bytes);
    expect(
      decoded.tables.keys,
      contains(MaintenanceExcelExportService.maintenanceSheet),
    );
    expect(decoded.tables.keys, isNot(contains('Sheet1')));
  });

  group('delivery paths', () {
    late MockFilePickerPlatform picker;
    late Directory tmp;

    setUp(() {
      picker = MockFilePickerPlatform();
      FilePickerPlatform.instance = picker;
      tmp = Directory.systemTemp.createTempSync('maintenance_export');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test(
      'saveToFile writes a dated workbook and returns its location',
      () async {
        final target = File('${tmp.path}/log.xlsx');
        picker.saveFileResult = Uri.file(target.path);

        final path = await service.saveToFile(
          rows: [row()],
          dateFormat: DateFormatPreference.yyyymmdd,
        );

        expect(path, isNotNull);
        expect(target.existsSync(), isTrue);
        expect(picker.lastSavedFileName, startsWith('submersion_maintenance_'));
        expect(picker.lastSavedFileName, endsWith('.xlsx'));
        // The bytes the picker was handed are the workbook, not an empty stub.
        final decoded = xl.Excel.decodeBytes(picker.lastSavedBytes!);
        expect(
          decoded.tables.keys,
          contains(MaintenanceExcelExportService.maintenanceSheet),
        );
      },
    );

    test('saveToFile returns null when the diver cancels', () async {
      // The real plugin returns null on dismiss; callers must treat that as a
      // no-op rather than as a successful export.
      picker.saveFileResult = null;

      final path = await service.saveToFile(
        rows: [row()],
        dateFormat: DateFormatPreference.yyyymmdd,
      );

      expect(path, isNull);
    });
  });
}

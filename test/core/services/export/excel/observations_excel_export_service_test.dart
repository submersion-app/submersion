import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/observations_excel_export_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

void main() {
  final rows = <ObservationExportRow>[
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
  ];

  String cell(xl.Sheet sheet, int col, int row) =>
      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
          .value
          ?.toString() ??
      '';

  test('writes a header and one row per observation', () {
    final excel = xl.Excel.createExcel();
    ObservationsExcelExportService().buildSheet(
      excel,
      rows: rows,
      dateFormat: DateFormatPreference.mmmDYYYY,
    );
    final sheet = excel[ObservationsExcelExportService.observationsSheet];
    expect(sheet.maxRows, 3);
    expect(cell(sheet, 0, 0), 'Equipment');
    expect(cell(sheet, 1, 0), 'Equipment Type');
    expect(cell(sheet, 2, 0), 'Date');
    expect(cell(sheet, 3, 0), 'Dive Number');
    expect(cell(sheet, 4, 0), 'Status');
    expect(cell(sheet, 5, 0), 'Tags');
    expect(cell(sheet, 6, 0), 'Note');

    expect(cell(sheet, 0, 1), 'Apeks XTX');
    expect(cell(sheet, 1, 1), 'Regulator');
    expect(cell(sheet, 2, 1), contains('2026'));
    expect(cell(sheet, 3, 1), '42');
    expect(cell(sheet, 4, 1), 'issue');
    expect(cell(sheet, 5, 1), 'freeFlow; leak');
    expect(cell(sheet, 6, 1), 'Cold, 4 C');

    expect(cell(sheet, 3, 2), '');
    expect(cell(sheet, 4, 2), 'ok');
    expect(cell(sheet, 5, 2), '');
  });

  test('a newer peer\'s tags are exported with the known ones', () {
    final excel = xl.Excel.createExcel();
    ObservationsExcelExportService().buildSheet(
      excel,
      rows: [
        (
          equipmentName: 'Reg',
          equipmentType: 'Regulator',
          diveNumber: null,
          observation: rows.first.observation.copyWith(
            unrecognizedTags: const ['futureTag'],
          ),
        ),
      ],
      dateFormat: DateFormatPreference.mmmDYYYY,
    );
    final sheet = excel[ObservationsExcelExportService.observationsSheet];
    expect(cell(sheet, 5, 1), 'freeFlow; leak; futureTag');
  });
}

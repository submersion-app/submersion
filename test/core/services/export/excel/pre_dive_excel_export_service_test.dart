import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/pre_dive_excel_export_service.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';

void main() {
  late PreDiveExcelExportService service;

  setUp(() => service = PreDiveExcelExportService());

  final started = DateTime(2026, 3, 15, 8, 30);
  final completed = DateTime(2026, 3, 15, 8, 52);

  PreDiveSession session({
    String id = 's1',
    String name = 'CCR Build',
    PreDiveSessionStatus status = PreDiveSessionStatus.completed,
    String? diveId,
    String? equipmentSetName,
    String notes = '',
  }) => PreDiveSession(
    id: id,
    templateName: name,
    status: status,
    diveId: diveId,
    equipmentSetName: equipmentSetName,
    notes: notes,
    startedAt: started,
    completedAt: status == PreDiveSessionStatus.inProgress ? null : completed,
    createdAt: started,
    updatedAt: completed,
  );

  PreDiveSessionItem item({
    String id = 'i1',
    String sessionId = 's1',
    String title = 'Check cells',
    String? section,
    PreDiveItemState state = PreDiveItemState.done,
    PreDiveItemType type = PreDiveItemType.check,
    double? valueNumber,
    String? valueUnit,
    String note = '',
    bool required = false,
    DateTime? completedAt,
  }) => PreDiveSessionItem(
    id: id,
    sessionId: sessionId,
    title: title,
    section: section,
    state: state,
    itemType: type,
    valueNumber: valueNumber,
    valueUnit: valueUnit,
    note: note,
    isRequired: required,
    completedAt: completedAt,
    sortOrder: 0,
    createdAt: started,
    updatedAt: started,
  );

  /// Reads a decoded sheet back as rows of plain strings so assertions can
  /// talk about content rather than about cell objects.
  List<List<String>> rowsOf(xl.Excel excel, String sheetName) {
    final sheet = excel.tables[sheetName]!;
    return [
      for (final row in sheet.rows)
        [for (final cell in row) cell?.value?.toString() ?? ''],
    ];
  }

  xl.Excel decode(List<int> bytes) => xl.Excel.decodeBytes(bytes);

  test('produces a runs sheet and an items sheet', () {
    final bytes = service.generateBytes(
      sessions: [session()],
      itemsBySession: {
        's1': [item()],
      },
      dateFormat: DateFormatPreference.yyyymmdd,
    );

    final excel = decode(bytes);

    expect(excel.tables.keys, contains(PreDiveExcelExportService.runsSheet));
    expect(excel.tables.keys, contains(PreDiveExcelExportService.itemsSheet));
    // The default sheet the excel package creates must not survive.
    expect(excel.tables.keys, isNot(contains('Sheet1')));
  });

  test('runs sheet carries one row per session under a header row', () {
    final bytes = service.generateBytes(
      sessions: [
        session(id: 's1', name: 'CCR Build'),
        session(id: 's2', name: 'BWRAF', status: PreDiveSessionStatus.aborted),
      ],
      itemsBySession: const {},
      dateFormat: DateFormatPreference.yyyymmdd,
    );

    final rows = rowsOf(decode(bytes), PreDiveExcelExportService.runsSheet);

    expect(rows.first.first, 'Checklist');
    expect(rows, hasLength(3));
    expect(rows[1].first, 'CCR Build');
    expect(rows[2].first, 'BWRAF');
  });

  test('runs sheet reports tallies, status and linkage', () {
    final bytes = service.generateBytes(
      sessions: [session(diveId: 'dive-42', equipmentSetName: 'CCR set')],
      itemsBySession: {
        's1': [
          item(id: 'i1', state: PreDiveItemState.done),
          item(id: 'i2', state: PreDiveItemState.flagged),
          item(id: 'i3', state: PreDiveItemState.pending),
        ],
      },
      dateFormat: DateFormatPreference.yyyymmdd,
    );

    final rows = rowsOf(decode(bytes), PreDiveExcelExportService.runsSheet);
    final header = rows.first;
    final run = rows[1];
    String cell(String column) => run[header.indexOf(column)];

    expect(cell('Status'), 'Completed');
    expect(cell('Items'), '3');
    expect(cell('Resolved'), '2');
    expect(cell('Flagged'), '1');
    expect(cell('Linked Dive'), 'dive-42');
    expect(cell('Equipment Set'), 'CCR set');
    expect(cell('Started'), contains('2026-03-15'));
  });

  test('items sheet carries one row per item, keyed back to its run', () {
    final bytes = service.generateBytes(
      sessions: [session(id: 's1', name: 'CCR Build')],
      itemsBySession: {
        's1': [
          item(id: 'i1', title: 'Check cells', section: 'Electronics'),
          item(id: 'i2', title: 'Check scrubber', section: 'Scrubber'),
        ],
      },
      dateFormat: DateFormatPreference.yyyymmdd,
    );

    final rows = rowsOf(decode(bytes), PreDiveExcelExportService.itemsSheet);
    final header = rows.first;

    expect(rows, hasLength(3));
    expect(rows[1][header.indexOf('Checklist')], 'CCR Build');
    expect(rows[1][header.indexOf('Section')], 'Electronics');
    expect(rows[1][header.indexOf('Item')], 'Check cells');
    expect(rows[2][header.indexOf('Item')], 'Check scrubber');
  });

  test('items sheet records the flag note, state and measured value', () {
    final bytes = service.generateBytes(
      sessions: [session()],
      itemsBySession: {
        's1': [
          item(
            id: 'i1',
            title: 'Cell 1 mV',
            type: PreDiveItemType.value,
            state: PreDiveItemState.flagged,
            valueNumber: 8.2,
            valueUnit: 'mV',
            note: 'Reading low, replaced cell',
            required: true,
            completedAt: completed,
          ),
        ],
      },
      dateFormat: DateFormatPreference.yyyymmdd,
    );

    final rows = rowsOf(decode(bytes), PreDiveExcelExportService.itemsSheet);
    final header = rows.first;
    String cell(String column) => rows[1][header.indexOf(column)];

    // The note and flag are the audit evidence a checklist export exists for.
    expect(cell('State'), 'Flagged');
    expect(cell('Note'), 'Reading low, replaced cell');
    expect(cell('Value'), '8.2');
    expect(cell('Unit'), 'mV');
    expect(cell('Required'), 'Yes');
    expect(cell('Completed At'), isNotEmpty);
  });

  test('a session with no items still appears on the runs sheet', () {
    final bytes = service.generateBytes(
      sessions: [session()],
      itemsBySession: const {},
      dateFormat: DateFormatPreference.yyyymmdd,
    );

    final excel = decode(bytes);
    final runs = rowsOf(excel, PreDiveExcelExportService.runsSheet);
    final items = rowsOf(excel, PreDiveExcelExportService.itemsSheet);

    expect(runs, hasLength(2));
    expect(runs[1][runs.first.indexOf('Items')], '0');
    // Header only: no orphan item rows invented for it.
    expect(items, hasLength(1));
  });

  test('an in-progress run leaves the completed column empty', () {
    final bytes = service.generateBytes(
      sessions: [session(status: PreDiveSessionStatus.inProgress)],
      itemsBySession: const {},
      dateFormat: DateFormatPreference.yyyymmdd,
    );

    final rows = rowsOf(decode(bytes), PreDiveExcelExportService.runsSheet);

    expect(rows[1][rows.first.indexOf('Completed')], isEmpty);
    expect(rows[1][rows.first.indexOf('Status')], 'In progress');
  });

  test('generates a valid xlsx container for an empty export', () {
    final bytes = service.generateBytes(
      sessions: const [],
      itemsBySession: const {},
      dateFormat: DateFormatPreference.yyyymmdd,
    );

    expect(bytes, isNotEmpty);
    // xlsx is a zip: "PK" magic number.
    expect(bytes[0], 0x50);
    expect(bytes[1], 0x4B);
    expect(
      rowsOf(decode(bytes), PreDiveExcelExportService.runsSheet),
      hasLength(1),
    );
  });
}

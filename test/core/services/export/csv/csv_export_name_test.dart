import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  test('dive CSV export includes a Name column with the raw name', () {
    final dives = [
      Dive(
        id: 'd1',
        diveNumber: 60,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        name: 'Wreck penetration dive',
      ),
      Dive(id: 'd2', diveNumber: 61, dateTime: DateTime(2026, 3, 29, 10, 0)),
    ];

    final csv = CsvExportService().generateDivesCsvContent(dives);
    final lines = csv.trim().split('\n');

    final headers = lines.first.split(',');
    final nameIdx = headers.indexOf('Name');
    expect(nameIdx, 1, reason: 'Name column sits right after Dive Number');

    expect(lines[1], contains('Wreck penetration dive'));
    // Unnamed dive exports an empty cell, never a site fallback.
    expect(lines[2].split(',')[nameIdx], isEmpty);
  });

  test('name newlines are normalized and whitespace-only exports empty', () {
    final dives = [
      Dive(
        id: 'd1',
        diveNumber: 60,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        name: 'Wreck\npenetration',
      ),
      Dive(
        id: 'd2',
        diveNumber: 61,
        dateTime: DateTime(2026, 3, 29, 10, 0),
        name: '   ',
      ),
    ];

    final csv = CsvExportService().generateDivesCsvContent(dives);
    final lines = csv.trim().split('\n');

    final headers = lines.first.split(',');
    final nameIdx = headers.indexOf('Name');

    // Embedded newlines are replaced so each record stays on one line,
    // matching how notes are exported.
    expect(lines[1].split(',')[nameIdx], 'Wreck penetration');
    // Whitespace-only names behave as unset.
    expect(lines[2].split(',')[nameIdx], isEmpty);
  });
}

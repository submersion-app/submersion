import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/core/services/export/csv/dive_csv_columns.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';

void main() {
  DiveTypeEntity type(String id, String name) => DiveTypeEntity(
    id: id,
    name: name,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Dive dive(List<String> ids) =>
      Dive(id: 'd', dateTime: DateTime(2026, 1, 1), diveTypeIds: ids);

  /// The single dive row of [csv], keyed by header.
  Map<String, String> rowOf(String csv) {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(csv);
    final headers = rows.first.map((h) => h.toString()).toList();
    return {
      for (var i = 0; i < headers.length; i++) headers[i]: '${rows[1][i]}',
    };
  }

  test('CSV joins multiple dive types in the Dive Type column', () {
    final service = CsvExportService();
    final csv = service.generateDivesCsvContent([
      dive(const ['shore', 'wreck']),
    ]);
    expect(csv, contains('Shore; Wreck'));
  });

  group('custom dive types (#1834)', () {
    final typesById = {
      'search_recovery': type('search_recovery', 'Search & Recovery'),
      'search_recovery_1a2b3c4d': type(
        'search_recovery_1a2b3c4d',
        'Search Recovery',
      ),
      'night': type('night', 'Night'),
    };

    test('writes the name the diver gave each type', () {
      final csv = CsvExportService().generateDivesCsvContent([
        dive(const ['search_recovery', 'search_recovery_1a2b3c4d', 'night']),
      ], diveTypesById: typesById);

      expect(
        rowOf(csv)[DiveCsvColumns.diveType],
        'Search & Recovery; Search Recovery; Night',
      );
    });

    test('writes each type id, in the same order, in Dive Type IDs', () {
      final csv = CsvExportService().generateDivesCsvContent([
        dive(const ['search_recovery', 'search_recovery_1a2b3c4d', 'night']),
      ], diveTypesById: typesById);

      expect(
        rowOf(csv)[DiveCsvColumns.diveTypeIds],
        'search_recovery; search_recovery_1a2b3c4d; night',
      );
    });

    test('guards a type name against CSV injection', () {
      final csv = CsvExportService().generateDivesCsvContent(
        [
          dive(const ['sum']),
        ],
        diveTypesById: {'sum': type('sum', '=SUM(A1)')},
      );

      expect(rowOf(csv)[DiveCsvColumns.diveType], "'=SUM(A1)");
    });

    test('appends Dive Type IDs after the pre-#1834 columns', () {
      // Spreadsheets that address the export by position keep their offsets.
      expect(DiveCsvColumns.fixed.last, DiveCsvColumns.diveTypeIds);
    });
  });
}

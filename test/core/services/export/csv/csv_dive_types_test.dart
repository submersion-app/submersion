import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  test('CSV joins multiple dive types in the Dive Type column', () {
    final service = CsvExportService();
    final dive = Dive(
      id: 'd',
      dateTime: DateTime(2026, 1, 1),
      diveTypeIds: const ['shore', 'wreck'],
    );
    final csv = service.generateDivesCsvContent([dive]);
    expect(csv, contains('Shore; Wreck'));
  });
}

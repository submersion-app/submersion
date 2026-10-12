import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../csv/csv_test_fixtures.dart';

/// Fills ride the full backup and come back from its parser (#2651).
void main() {
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 6, 2, 10),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 18.0,
    tanks: const [],
    profile: const [],
    gear: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  test(
    'the full export writes the fills and the full parser reads them',
    () async {
      final xml = await UddfFullExportService().generateAllDataXmlForTest(
        dives: [dive],
        fills: goldenFills(),
      );
      expect(xml, contains('<cylinderfills>'));
      final result = await UddfFullImportService().importAllDataFromUddf(xml);
      expect(result.fills.map((f) => f['id']), [
        for (final f in goldenFills()) f.id,
      ]);
      expect(result.fills.first['pressureBar'], 206.843);
    },
  );

  test('a backup with no fills writes no section', () async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
    );
    expect(xml, isNot(contains('cylinderfills')));
  });
}

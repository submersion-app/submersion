import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/submersion_csv_signatures.dart';
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
import 'package:submersion/core/services/export/csv/csv_equipment_writer.dart';
import 'package:submersion/core/services/export/csv/csv_sites_writer.dart';

import '../csv_dives_writer_test.dart' show imperial;
import '../csv_test_fixtures.dart';

/// Header row of a writer's output. Safe to split on ',' because the
/// imperial fixture's date format (MM/DD/YYYY) has no comma in it.
List<String> _headers(String csv) => csv.split('\r\n').first.split(',');

void main() {
  for (final units in [
    CsvExportUnits.metric,
    CsvExportUnits.fromSettings(imperial),
  ]) {
    final label = units.isMetric ? 'metric' : 'my units';

    test('dives export matches in $label mode', () {
      final csv = CsvDivesWriter(units).write(goldenDives());
      expect(
        SubmersionCsvSignatures.match(_headers(csv)),
        SubmersionCsvKind.dives,
      );
    });

    test('sites export matches in $label mode', () {
      final csv = CsvSitesWriter(units).write(goldenSites());
      expect(
        SubmersionCsvSignatures.match(_headers(csv)),
        SubmersionCsvKind.sites,
      );
    });

    test('equipment export matches in $label mode', () {
      final csv = CsvEquipmentWriter(units).write(goldenEquipment());
      expect(
        SubmersionCsvSignatures.match(_headers(csv)),
        SubmersionCsvKind.equipment,
      );
    });
  }

  test("other apps' CSVs do not match", () {
    expect(
      SubmersionCsvSignatures.match([
        'Dive Number',
        'Date',
        'Time',
        'Site',
        'Max Depth',
        'Bottom Time',
        'Water Temp',
        'Start Pressure',
      ]),
      isNull,
    );
    expect(SubmersionCsvSignatures.match(['Date', 'Time', 'Depth']), isNull);
  });
}

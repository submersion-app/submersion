import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/submersion_csv_signatures.dart';
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
import 'package:submersion/core/services/export/csv/csv_equipment_writer.dart';
import 'package:submersion/core/services/export/csv/csv_fills_writer.dart';
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

    test('fills export matches in $label mode', () {
      final csv = CsvFillsWriter(units).write(goldenFills());
      expect(
        SubmersionCsvSignatures.match(_headers(csv)),
        SubmersionCsvKind.fills,
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

  test('a fills export is never read as a dives export, or the reverse', () {
    // The two sheets share Date, Time, O2 %, Serial Number and Notes.
    final fills = _headers(
      CsvFillsWriter(CsvExportUnits.metric).write(goldenFills()),
    );
    expect(fills, isNot(contains('Dive Number')));
    expect(SubmersionCsvSignatures.match(fills), SubmersionCsvKind.fills);
    final dives = _headers(
      CsvDivesWriter(CsvExportUnits.metric).write(goldenDives()),
    );
    expect(dives, isNot(contains('Fill ID')));
    expect(SubmersionCsvSignatures.match(dives), SubmersionCsvKind.dives);
  });

  test('an equipment export from before the Tags column still matches', () {
    // Detection uses containsAll over a fixed signature, so the new column
    // is optional (issue #1942).
    final headers = _headers(
      CsvEquipmentWriter(CsvExportUnits.metric).write(goldenEquipment()),
    )..remove('Tags');
    expect(SubmersionCsvSignatures.match(headers), SubmersionCsvKind.equipment);
  });
}

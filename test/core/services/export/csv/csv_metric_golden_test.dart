import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/core/services/export/csv/csv_fills_writer.dart';

import 'csv_test_fixtures.dart';

/// Metric mode must stay byte-for-byte identical to the pre-#1813 export.
/// The goldens were written by the unchanged exporter; regenerate ONLY with
/// `flutter test <this file> --dart-define=WRITE_CSV_GOLDENS=true`, and only
/// when a deliberate format change has been agreed.
///
/// The sites golden moved once since, for issue #2201: the export used to
/// drop twelve of a site's fields, so a CSV round trip was lossy. The
/// restored columns are APPENDED after the historical twelve, which keep
/// their order and position, so a consumer reading this file by column
/// offset or by header name is unaffected.
///
/// The equipment golden moved once, for equipment locations (v268): a
/// Location column is APPENDED after Notes, for the same reason.
///
/// The fills golden (cylinder passports phase 5) was written by the new
/// writer on 2026-09-29; it exists so a later change to the sheet is a
/// deliberate one.
const _write = bool.fromEnvironment('WRITE_CSV_GOLDENS');
const _dir = 'test/core/services/export/csv/goldens';

void _check(String name, String actual) {
  final file = File('$_dir/$name');
  if (_write) {
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(actual);
    return;
  }
  expect(actual, file.readAsStringSync());
}

void main() {
  final service = CsvExportService();

  test('dives metric export matches the golden', () {
    _check('dives_metric.csv', service.generateDivesCsvContent(goldenDives()));
  });

  test('sites metric export matches the golden', () {
    _check('sites_metric.csv', service.generateSitesCsvContent(goldenSites()));
  });

  test('equipment metric export matches the golden', () {
    _check(
      'equipment_metric.csv',
      service.generateEquipmentCsvContent(
        goldenEquipment(),
        componentNames: goldenComponentNames(),
      ),
    );
  });

  test('fills metric export matches the golden', () {
    _check(
      'fills_metric.csv',
      CsvFillsWriter(
        CsvExportUnits.metric,
      ).write(goldenFills(), equipmentById: goldenFillEquipment()),
    );
  });
}

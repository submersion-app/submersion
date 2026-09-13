import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
import 'package:submersion/core/services/export/csv/csv_equipment_writer.dart';
import 'package:submersion/core/services/export/csv/csv_sites_writer.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/services/format_detector.dart';

import '../../../../core/services/export/csv/csv_dives_writer_test.dart'
    show imperial;
import '../../../../core/services/export/csv/csv_test_fixtures.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

/// Issue #1813: Submersion's own CSV exports route to their parsers.
void main() {
  const detector = FormatDetector();

  for (final units in [
    CsvExportUnits.metric,
    CsvExportUnits.fromSettings(imperial),
  ]) {
    test('each export is detected as its own format '
        '(${units.isMetric ? 'metric' : 'my units'})', () {
      final dives = detector.detect(
        _bytes(CsvDivesWriter(units).write(goldenDives())),
      );
      expect(dives.format, ImportFormat.submersionDivesCsv);
      expect(dives.sourceApp, SourceApp.submersion);
      expect(dives.isFormatSupported, isTrue);
      expect(
        detector
            .detect(_bytes(CsvSitesWriter(units).write(goldenSites())))
            .format,
        ImportFormat.submersionSitesCsv,
      );
      expect(
        detector
            .detect(_bytes(CsvEquipmentWriter(units).write(goldenEquipment())))
            .format,
        ImportFormat.submersionEquipmentCsv,
      );
    });
  }

  test(
    'a Submersion-like CSV without the full signature stays generic CSV',
    () {
      final result = detector.detect(
        _bytes(
          'Dive Number,Date,Time,Site,Max Depth,Bottom Time,Water Temp,'
          'Start Pressure\n1,2024-01-01,09:00,Reef,20,40,24,200\n',
        ),
      );
      expect(result.format, ImportFormat.csv);
    },
  );
}

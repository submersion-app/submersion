import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:xml/xml.dart';

/// A band-picked visibility range has no standard UDDF element, so both
/// writers carry it in the private `visibilityranges` block inside
/// Submersion's application data, and the reader puts it back on the dive,
/// while the standard `<visibility>` stays empty rather than holding an
/// invented number (issue #3226).
void main() {
  Dive dive({double? min, double? max}) => Dive(
    id: 'dive-a',
    diveNumber: 1,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 25.0,
    tanks: const [DiveTank(id: 'tank-a', gasMix: GasMix(o2: 21))],
    visibilityMinMeters: min,
    visibilityMaxMeters: max,
  );

  final writers = <String, Future<String> Function(List<Dive>)>{
    'full backup': (dives) =>
        UddfFullExportService().generateAllDataXmlForTest(dives: dives),
    'dives-only export': (dives) =>
        UddfExportService().generateDivesUddfContent(dives),
  };

  Future<List<Map<String, dynamic>>> restore(String xml) async =>
      (await UddfFullImportService().importAllDataFromUddf(xml)).dives;

  for (final MapEntry(key: name, value: write) in writers.entries) {
    group(name, () {
      test('restores a closed range', () async {
        final xml = await write([dive(min: 6, max: 12)]);

        final restored = (await restore(xml)).single;
        expect(restored['visibilityMinMeters'], 6.0);
        expect(restored['visibilityMaxMeters'], 12.0);
        expect(restored['visibilityMeters'], isNull);
      });

      test('restores an open range', () async {
        final restored = (await restore(await write([dive(min: 12)]))).single;
        expect(restored['visibilityMinMeters'], 12.0);
        expect(restored['visibilityMaxMeters'], isNull);
      });

      test('writes no standard visibility for a range dive', () async {
        final xml = await write([dive(min: 6, max: 12)]);
        expect(XmlDocument.parse(xml).findAllElements('visibility'), isEmpty);
      });
    });
  }
}

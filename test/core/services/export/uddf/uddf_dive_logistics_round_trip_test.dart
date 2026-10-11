import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Issue #3229: the operator, boat, captain and surface conditions survive a
/// UDDF export and re-import from both writers, in the MacDive element names
/// the reader already understands.
void main() {
  Dive dive({
    String? diveOperator,
    String? boatName,
    String? boatCaptain,
    String? surfaceConditions,
  }) => Dive(
    id: 'dive-a',
    diveNumber: 1,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 25.0,
    tanks: const [DiveTank(id: 'tank-a', gasMix: GasMix(o2: 32))],
    diveOperator: diveOperator,
    boatName: boatName,
    boatCaptain: boatCaptain,
    surfaceConditions: surfaceConditions,
  );

  final writers = <String, Future<String> Function(List<Dive>)>{
    'full backup': (dives) =>
        UddfFullExportService().generateAllDataXmlForTest(dives: dives),
    'dives-only export': (dives) =>
        UddfExportService().generateDivesUddfContent(dives),
  };

  Future<Map<String, dynamic>> restore(String xml) async =>
      (await UddfFullImportService().importAllDataFromUddf(xml)).dives.single;

  for (final MapEntry(key: name, value: write) in writers.entries) {
    group(name, () {
      test('restores all four, XML special characters included', () async {
        final restored = await restore(
          await write([
            dive(
              diveOperator: 'Buddy Dive',
              boatName: 'Mike & Sons <II>',
              boatCaptain: 'Rik',
              surfaceConditions: 'Choppy',
            ),
          ]),
        );

        expect(restored['diveOperator'], 'Buddy Dive');
        expect(restored['boatName'], 'Mike & Sons <II>');
        expect(restored['boatCaptain'], 'Rik');
        expect(restored['surfaceConditions'], 'Choppy');
      });

      test('writes nothing for empty or blank values', () async {
        final xml = await write([dive(boatName: '   ')]);

        expect(xml, isNot(contains('<boatname')));
        expect(xml, isNot(contains('<boatcaptain')));
        expect(xml, isNot(contains('<diveoperator')));
        expect(xml, isNot(contains('<surfaceconditions')));
      });
    });
  }
}

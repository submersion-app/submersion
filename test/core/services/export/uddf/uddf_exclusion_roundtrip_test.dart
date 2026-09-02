import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:xml/xml.dart';

/// UDDF is hand-plumbed (unlike sync, which rides Drift's generated
/// serializer), so the statistics-exclusion flags need an explicit test.
///
/// Each flag is exercised alone as well as together, so a bug that writes one
/// flag into the other's element cannot pass by symmetry.
void main() {
  Dive makeDive({
    bool excludedFromStats = false,
    bool excludedFromGasStats = false,
  }) => Dive(
    id: 'dive-exclusion',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 25.0,
    excludedFromStats: excludedFromStats,
    excludedFromGasStats: excludedFromGasStats,
  );

  String exportOne(Dive dive) {
    final builder = XmlBuilder();
    builder.element(
      'root',
      nest: () {
        UddfExportBuilders.buildDiveElement(
          builder,
          dive,
          null,
          const [],
          const [],
          const [],
          const [],
          null,
          const [],
        );
      },
    );
    return builder.buildDocument().toXmlString();
  }

  bool? readFlag(String xml, String tag) {
    final el = XmlDocument.parse(xml).findAllElements(tag).firstOrNull;
    return el == null ? null : el.innerText.toLowerCase() == 'true';
  }

  test('an included dive writes neither exclusion element', () {
    final xml = exportOne(makeDive());
    expect(readFlag(xml, 'excludedfromstats'), isNull);
    expect(readFlag(xml, 'excludedfromgasstats'), isNull);
  });

  test('the master flag alone writes only its own element', () {
    final xml = exportOne(makeDive(excludedFromStats: true));
    expect(readFlag(xml, 'excludedfromstats'), isTrue);
    expect(
      readFlag(xml, 'excludedfromgasstats'),
      isNull,
      reason:
          'the master-implies-gas rule lives in SQL. Materialising it here '
          'would lose the diver\'s own gas-only choice on re-import, so that '
          'unticking the master flag would not restore it.',
    );
  });

  test('the gas flag alone writes only its own element', () {
    final xml = exportOne(makeDive(excludedFromGasStats: true));
    expect(readFlag(xml, 'excludedfromstats'), isNull);
    expect(readFlag(xml, 'excludedfromgasstats'), isTrue);
  });

  test('both flags write both elements', () {
    final xml = exportOne(
      makeDive(excludedFromStats: true, excludedFromGasStats: true),
    );
    expect(readFlag(xml, 'excludedfromstats'), isTrue);
    expect(readFlag(xml, 'excludedfromgasstats'), isTrue);
  });
}

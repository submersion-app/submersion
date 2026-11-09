import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:xml/xml.dart';

/// UDDF is hand-plumbed, so the draft flag (issue #637) needs its own
/// round trip: a backup that lost it would restore a draft as an ordinary
/// dive, counted in the totals with no readings.
void main() {
  Dive makeDive({bool isDraft = false, bool isPlanned = false}) => Dive(
    id: 'dive-draft',
    dateTime: DateTime(2026, 7, 17, 10, 0),
    entryTime: DateTime(2026, 7, 17, 10, 0),
    exitTime: DateTime(2026, 7, 17, 10, 52),
    isDraft: isDraft,
    isPlanned: isPlanned,
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

  test('a logged dive writes no isdraft element', () {
    expect(readFlag(exportOne(makeDive()), 'isdraft'), isNull);
  });

  test('a draft writes isdraft and not isplanned', () {
    final xml = exportOne(makeDive(isDraft: true));
    expect(readFlag(xml, 'isdraft'), isTrue);
    expect(readFlag(xml, 'isplanned'), isNull);
  });

  test('a backup carrying isdraft reads it back', () async {
    const backup = '''
<uddf version="3.2.0">
  <generator><name>Submersion</name></generator>
  <profiledata><repetitiongroup><dive id="d1">
    <informationbeforedive>
      <datetime>2026-07-17T10:00:00</datetime>
      <isdraft>true</isdraft>
    </informationbeforedive>
  </dive></repetitiongroup></profiledata>
</uddf>''';

    final result = await UddfFullImportService().importAllDataFromUddf(backup);

    expect(result.dives.single['isDraft'], isTrue);
    expect(result.dives.single['isPlanned'], isNull);
  });

  test('a backup without isdraft reads an ordinary dive', () async {
    const backup = '''
<uddf version="3.2.0">
  <generator><name>Submersion</name></generator>
  <profiledata><repetitiongroup><dive id="d1">
    <informationbeforedive>
      <datetime>2026-07-17T10:00:00</datetime>
    </informationbeforedive>
  </dive></repetitiongroup></profiledata>
</uddf>''';

    final result = await UddfFullImportService().importAllDataFromUddf(backup);

    expect(result.dives.single['isDraft'], isNull);
  });
}

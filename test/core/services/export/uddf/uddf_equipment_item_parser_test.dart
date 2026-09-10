import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:xml/xml.dart';

void main() {
  XmlElement itemWithObservationDate(String date) => XmlDocument.parse('''
<item id="equip_reg">
  <name>Reg</name>
  <observations>
    <observation id="obs_1">
      <date>$date</date>
      <status>ok</status>
    </observation>
  </observations>
</item>
''').rootElement;

  List<Map<String, dynamic>> observationsOf(XmlElement item) =>
      (UddfImportParsers.parseEquipmentItem(item)['observations'] as List)
          .cast<Map<String, dynamic>>();

  group('parseEquipmentItem check-in dates', () {
    test('a date with no zone keeps its wall clock, as dive dates do', () {
      // Read as local time, a zoneless date would shift by the importing
      // device's offset when it is stored.
      final observed = observationsOf(
        itemWithObservationDate('2026-03-14T11:00:00'),
      ).single['observedAt'];
      expect(observed, DateTime.utc(2026, 3, 14, 11));
    });

    test('our own UTC export reads back unchanged', () {
      final observed = observationsOf(
        itemWithObservationDate('2026-03-14T11:00:00.000Z'),
      ).single['observedAt'];
      expect(observed, DateTime.utc(2026, 3, 14, 11));
    });
  });
}

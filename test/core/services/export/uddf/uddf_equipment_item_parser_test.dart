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

  group('parseEquipmentItem tags (#1942)', () {
    test("an item's own tag refs are read, never a check-in's tags", () {
      final item = UddfImportParsers.parseEquipmentItem(
        XmlDocument.parse('''
<item id="equip_reg">
  <name>Reg</name>
  <observations>
    <observation id="obs_1">
      <date>2026-03-14T11:00:00Z</date>
      <status>issue</status>
      <tags><tag>freeFlow</tag></tags>
    </observation>
  </observations>
  <tags><tagref>tag_t1</tagref><tagref> </tagref></tags>
</item>
''').rootElement,
      );
      expect(item['tagRefs'], ['tag_t1']);
      expect((item['observations'] as List).single['tags'], ['freeFlow']);
    });

    test('an untagged item carries no refs', () {
      final item = UddfImportParsers.parseEquipmentItem(
        XmlDocument.parse(
          '<item id="equip_fins"><name>Fins</name></item>',
        ).rootElement,
      );
      expect(item.containsKey('tagRefs'), isFalse);
    });
  });

  test('a tag definition reads its equipment flag, null when absent', () {
    Map<String, dynamic> parse(String body) => UddfImportParsers.parseTag(
      XmlDocument.parse(
        '<tag id="tag_t1"><name>Rental</name>$body</tag>',
      ).rootElement,
    );
    expect(
      parse(
        '<appliestoequipment>true</appliestoequipment>',
      )['appliesToEquipment'],
      isTrue,
    );
    expect(parse('')['appliesToEquipment'], isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/uddf_sighting_time.dart';

/// When in the dive a sighting was seen, across a UDDF `<sighting>`
/// (issue #5092).
void main() {
  XmlElement sighting(String attributes) =>
      XmlDocument.parse('<sighting speciesref="s" $attributes/>').rootElement;

  test('a time writes seenat in seconds; no time writes nothing', () {
    expect(UddfSightingTime.attributes(750), {'seenat': '750'});
    expect(UddfSightingTime.attributes(null), isEmpty);
  });

  test('a written time reads back', () {
    final parsed = UddfSightingTime.parse(sighting('seenat="750"'));
    expect(UddfSightingTime.of(parsed), 750);
  });

  test('no attribute, junk, a negative or more than a day reads as none', () {
    for (final attr in ['', 'seenat="soon"', 'seenat="-5"', 'seenat="90000"']) {
      expect(
        UddfSightingTime.of(UddfSightingTime.parse(sighting(attr))),
        isNull,
        reason: attr,
      );
    }
  });
}

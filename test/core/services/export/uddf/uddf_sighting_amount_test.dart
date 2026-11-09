import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/uddf_sighting_amount.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';

/// Issue #4337: how a sighting's abundance crosses a UDDF file.
void main() {
  XmlElement sighting(String attributes) =>
      XmlDocument.parse('<sighting speciesref="sp" $attributes/>').rootElement;

  group('attributes', () {
    test('an exact count writes count only', () {
      expect(
        UddfSightingAmount.attributes((
          abundance: SightingAbundance.exact,
          count: 3,
        )),
        {'count': '3'},
      );
    });

    test('Seen and the groups write abundance and no count', () {
      expect(
        UddfSightingAmount.attributes((
          abundance: SightingAbundance.few,
          count: 1,
        )),
        {'abundance': 'few'},
      );
      expect(
        UddfSightingAmount.attributes((
          abundance: SightingAbundance.seen,
          count: 1,
        )),
        {'abundance': 'seen'},
      );
    });
  });

  group('parse', () {
    test('a known abundance wins', () {
      expect(UddfSightingAmount.parse(sighting('abundance="many"')), {
        'abundance': 'many',
      });
    });

    test('a count with no abundance is exact, one included', () {
      expect(UddfSightingAmount.parse(sighting('count="1"')), {'count': 1});
      expect(UddfSightingAmount.parse(sighting('count="12"')), {'count': 12});
    });

    test('no count and no abundance gives nothing, which imports as Seen', () {
      expect(UddfSightingAmount.parse(sighting('')), isEmpty);
    });

    test('an unknown abundance falls back to the count', () {
      expect(UddfSightingAmount.parse(sighting('abundance="lots" count="4"')), {
        'count': 4,
      });
    });
  });

  group('amountOf', () {
    test('reads the importer map', () {
      expect(UddfSightingAmount.amountOf({'abundance': 'abundant'}), (
        abundance: SightingAbundance.abundant,
        count: 1,
      ));
      expect(UddfSightingAmount.amountOf({'count': 5}), (
        abundance: SightingAbundance.exact,
        count: 5,
      ));
      expect(UddfSightingAmount.amountOf(const {}), (
        abundance: SightingAbundance.seen,
        count: 1,
      ));
    });
  });
}

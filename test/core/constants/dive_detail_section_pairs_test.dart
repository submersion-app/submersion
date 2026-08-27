import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_section_pairs.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';

void main() {
  group('DiveDetailSectionPair', () {
    test('partnerOf resolves either half and rejects outsiders', () {
      const pair = DiveDetailSectionPair(
        DiveDetailSectionId.tanks,
        DiveDetailSectionId.weights,
      );

      expect(pair.partnerOf(DiveDetailSectionId.tanks), pair.right);
      expect(pair.partnerOf(DiveDetailSectionId.weights), pair.left);
      expect(pair.partnerOf(DiveDetailSectionId.notes), isNull);
    });
  });

  group('kDiveDetailSectionPairs', () {
    test('pairs the four card pairs, left half first', () {
      expect(kDiveDetailSectionPairs.map((p) => (p.left, p.right)), [
        (DiveDetailSectionId.details, DiveDetailSectionId.environment),
        (DiveDetailSectionId.surfaceGps, DiveDetailSectionId.tide),
        (DiveDetailSectionId.tanks, DiveDetailSectionId.weights),
        (DiveDetailSectionId.buddies, DiveDetailSectionId.signatures),
      ]);
    });

    // diveDetailSectionPairFor returns the first match, so a section in two
    // pairs would silently lose one of them.
    test('no section appears in more than one pair', () {
      final seen = <DiveDetailSectionId>{};
      for (final pair in kDiveDetailSectionPairs) {
        expect(seen.add(pair.left), isTrue, reason: '${pair.left} repeats');
        expect(seen.add(pair.right), isTrue, reason: '${pair.right} repeats');
      }
    });

    // Pairing looks ahead, so a gap would still pair -- but the settings list
    // reads as the page renders only while the halves sit together.
    test('default order lists each pair adjacently, left half first', () {
      final order = DiveDetailSectionConfig.defaultSections
          .map((s) => s.id)
          .toList();

      for (final pair in kDiveDetailSectionPairs) {
        expect(
          order.indexOf(pair.right),
          order.indexOf(pair.left) + 1,
          reason: '${pair.left} should be followed by ${pair.right}',
        );
      }
    });

    test('the declaration order matches the default section order', () {
      expect(
        DiveDetailSectionConfig.defaultSections.map((s) => s.id),
        DiveDetailSectionId.values,
      );
    });
  });

  group('diveDetailSectionPairFor', () {
    test('finds the pair from either half', () {
      expect(
        diveDetailSectionPairFor(DiveDetailSectionId.tide)?.left,
        DiveDetailSectionId.surfaceGps,
      );
      expect(
        diveDetailSectionPairFor(DiveDetailSectionId.surfaceGps)?.right,
        DiveDetailSectionId.tide,
      );
    });

    test('returns null for a section that never pairs', () {
      expect(diveDetailSectionPairFor(DiveDetailSectionId.buoyancy), isNull);
      expect(diveDetailSectionPairFor(DiveDetailSectionId.reefHealth), isNull);
    });
  });
}

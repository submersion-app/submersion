import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';

SightingAmount exact(int n) => (abundance: SightingAbundance.exact, count: n);

const SightingAmount seen = (abundance: SightingAbundance.seen, count: 1);
const SightingAmount single = (abundance: SightingAbundance.single, count: 1);
const SightingAmount few = (abundance: SightingAbundance.few, count: 1);
const SightingAmount many = (abundance: SightingAbundance.many, count: 1);
const SightingAmount abundant = (
  abundance: SightingAbundance.abundant,
  count: 1,
);

SightingAmount combine(SightingAmount a, SightingAmount b) =>
    SightingAbundance.combine(a, b);

void main() {
  group('storage', () {
    test('every value round trips', () {
      for (final a in SightingAbundance.values) {
        expect(SightingAbundance.fromStorage(a.storageValue), a);
      }
    });

    test('exact is stored as null', () {
      expect(SightingAbundance.exact.storageValue, isNull);
      expect(SightingAbundance.few.storageValue, 'few');
    });

    test('null and unknown text read as exact', () {
      expect(SightingAbundance.fromStorage(null), SightingAbundance.exact);
      expect(SightingAbundance.fromStorage('lots'), SightingAbundance.exact);
    });
  });

  test('isGroup is true for the four REEF groups only', () {
    expect(SightingAbundance.values.where((a) => a.isGroup), [
      SightingAbundance.single,
      SightingAbundance.few,
      SightingAbundance.many,
      SightingAbundance.abundant,
    ]);
  });

  test('groupForCount follows the REEF ranges', () {
    expect(SightingAbundance.groupForCount(0), SightingAbundance.single);
    expect(SightingAbundance.groupForCount(1), SightingAbundance.single);
    expect(SightingAbundance.groupForCount(2), SightingAbundance.few);
    expect(SightingAbundance.groupForCount(10), SightingAbundance.few);
    expect(SightingAbundance.groupForCount(11), SightingAbundance.many);
    expect(SightingAbundance.groupForCount(100), SightingAbundance.many);
    expect(SightingAbundance.groupForCount(101), SightingAbundance.abundant);
  });

  group('combine', () {
    test('two exact counts add up', () {
      expect(combine(exact(3), exact(4)), exact(7));
    });

    test('seen is neutral', () {
      expect(combine(seen, exact(3)), exact(3));
      expect(combine(few, seen), few);
      expect(combine(seen, seen), seen);
    });

    test('otherwise the larger group wins, exact placed in its group', () {
      expect(combine(exact(3), few), few);
      expect(combine(exact(50), few), many);
      expect(combine(few, exact(50)), many);
      expect(combine(single, abundant), abundant);
      expect(combine(many, single), many);
    });
  });
}

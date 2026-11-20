import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/reef/domain/entities/nearby_species.dart';

void main() {
  group('NearbySpecies.speciesKeys', () {
    test('species keys survive a JSON round trip', () {
      const nearby = NearbySpecies(speciesKeys: {2335, 5208});
      expect(NearbySpecies.fromJson(nearby.toJson()).speciesKeys, {2335, 5208});
    });

    test('a list saved without keys reads back with none', () {
      expect(
        NearbySpecies.fromJson({
          'matched': <Object>[],
          'unmatchedNames': <Object>[],
        }).speciesKeys,
        isEmpty,
      );
    });

    test('keys alone do not make a list non-empty', () {
      // What the site page shows is unchanged: keys are for matching only.
      expect(const NearbySpecies(speciesKeys: {2335}).isEmpty, isTrue);
    });

    test('copies with each field', () {
      const nearby = NearbySpecies(
        matched: [MatchedNearbySpecies(speciesId: 'a', occurrenceCount: 1)],
        unmatchedNames: ['B c'],
        speciesKeys: {1},
      );
      expect(nearby.copyWith(speciesKeys: {2}).speciesKeys, {2});
      expect(nearby.copyWith(matched: const []).matched, isEmpty);
      expect(nearby.copyWith(unmatchedNames: const []).unmatchedNames, isEmpty);
      expect(nearby.copyWith(namesIncomplete: true).namesIncomplete, isTrue);
      expect(nearby.copyWith(), nearby);
    });

    test('two lists differing only in keys are not equal', () {
      expect(
        const NearbySpecies(speciesKeys: {1}),
        isNot(const NearbySpecies(speciesKeys: {2})),
      );
    });
  });
}

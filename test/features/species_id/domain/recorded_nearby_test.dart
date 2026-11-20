import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/species_id/domain/services/recorded_nearby.dart';

/// Where a "Recorded nearby" list is read, and what counts as on it.
void main() {
  group('nearbyListLocation', () {
    const site = GeoPoint(12.1, -68.2);
    const photo = GeoPoint(12.2, -68.3);
    const entry = GeoPoint(12.3, -68.4);

    test('the dive site comes before the photo position', () {
      expect(nearbyListLocation(site: site, photo: photo, entry: entry), site);
    });

    test('without a site, the photo position, then the entry', () {
      expect(nearbyListLocation(photo: photo, entry: entry), photo);
      expect(nearbyListLocation(entry: entry), entry);
    });

    test('no place at all is null', () {
      expect(nearbyListLocation(), isNull);
    });
  });

  group('isRecordedNearby', () {
    const nearby = NearbySpecies(
      matched: [
        MatchedNearbySpecies(speciesId: 'queen-parrotfish', occurrenceCount: 9),
      ],
      speciesKeys: {2335},
    );

    test('a listed GBIF key is recorded nearby', () {
      expect(isRecordedNearby(nearby, gbifKeys: {2335}), isTrue);
    });

    test('one listed key among several is enough', () {
      expect(isRecordedNearby(nearby, gbifKeys: {1, 2335}), isTrue);
    });

    test('a listed catalogue species is, whatever its key', () {
      // A pack candidate may carry a synonym's key; its catalogue id still
      // ties it to the species the list matched.
      expect(
        isRecordedNearby(nearby, gbifKeys: {1}, catalogId: 'queen-parrotfish'),
        isTrue,
      );
    });

    test('anything else is not', () {
      expect(
        isRecordedNearby(nearby, gbifKeys: {1, 2}, catalogId: 'other'),
        isFalse,
      );
      expect(isRecordedNearby(nearby), isFalse);
    });
  });
}

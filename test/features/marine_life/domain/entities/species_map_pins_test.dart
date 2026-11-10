import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';

void main() {
  group('SiteSpeciesPin.copyWith', () {
    const pin = SiteSpeciesPin(
      siteId: 's1',
      siteName: 'Blue Corner',
      latitude: 7.1,
      longitude: 134.2,
      speciesCount: 3,
      sightingCount: 20,
    );

    test('with no arguments is an equal copy', () {
      expect(pin.copyWith(), pin);
    });

    test('replaces only the fields given', () {
      final moved = pin.copyWith(
        siteName: 'Blue Holes',
        latitude: 7.2,
        speciesCount: 4,
      );

      expect(moved.siteId, 's1');
      expect(moved.siteName, 'Blue Holes');
      expect(moved.latitude, 7.2);
      expect(moved.longitude, 134.2);
      expect(moved.speciesCount, 4);
      expect(moved.sightingCount, 20);
      expect(
        pin.copyWith(siteId: 's2', longitude: 1, sightingCount: 1),
        const SiteSpeciesPin(
          siteId: 's2',
          siteName: 'Blue Corner',
          latitude: 7.1,
          longitude: 1,
          speciesCount: 3,
          sightingCount: 1,
        ),
      );
    });
  });

  group('SpeciesSitePin.copyWith', () {
    const pin = SpeciesSitePin(
      siteId: 's3',
      siteName: 'Crystal Bay',
      latitude: -8.7,
      longitude: 115.4,
      kind: SpeciesPinKind.expected,
      sightingCount: 0,
    );

    test('with no arguments is an equal copy', () {
      expect(pin.copyWith(), pin);
    });

    test('replaces only the fields given', () {
      expect(
        pin.copyWith(kind: SpeciesPinKind.logged, sightingCount: 2),
        const SpeciesSitePin(
          siteId: 's3',
          siteName: 'Crystal Bay',
          latitude: -8.7,
          longitude: 115.4,
          kind: SpeciesPinKind.logged,
          sightingCount: 2,
        ),
      );
      expect(
        pin.copyWith(
          siteId: 's4',
          siteName: 'Manta Point',
          latitude: -8.8,
          longitude: 115.5,
        ),
        const SpeciesSitePin(
          siteId: 's4',
          siteName: 'Manta Point',
          latitude: -8.8,
          longitude: 115.5,
          kind: SpeciesPinKind.expected,
          sightingCount: 0,
        ),
      );
    });
  });

  group('LoggedSpeciesAtSite.copyWith', () {
    const logged = LoggedSpeciesAtSite(speciesId: 'manta', sightingCount: 6);

    test('with no arguments is an equal copy', () {
      expect(logged.copyWith(), logged);
    });

    test('replaces only the fields given', () {
      expect(
        logged.copyWith(sightingCount: 7),
        const LoggedSpeciesAtSite(speciesId: 'manta', sightingCount: 7),
      );
      expect(
        logged.copyWith(speciesId: 'mola'),
        const LoggedSpeciesAtSite(speciesId: 'mola', sightingCount: 6),
      );
    });
  });
}

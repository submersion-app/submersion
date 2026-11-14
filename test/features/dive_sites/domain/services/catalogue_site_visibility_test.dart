import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_visibility.dart';

/// About 111 m per 0.001 degree of latitude.
const _east = CatalogueSite(
  id: 'east',
  name: 'Barracuda East',
  location: GeoPoint(12.0000, -68.0000),
  source: 'osm',
);
const _west = CatalogueSite(
  id: 'west',
  name: 'Barracuda West',
  // About 100 m north of _east.
  location: GeoPoint(12.0009, -68.0000),
  source: 'osm',
);
const _unlocated = CatalogueSite(id: 'nowhere', name: 'Nowhere', source: 'osm');

List<String> _ids(List<CatalogueSite> sites) => [for (final s in sites) s.id];

void main() {
  group('offerableCatalogueSites', () {
    test('a linked site hides its own record', () {
      const adopted = DiveSite(
        id: 's1',
        name: 'Barracuda East',
        location: GeoPoint(12.0000, -68.0000),
        catalogueId: 'east',
      );

      final offered = offerableCatalogueSites(
        const [_east],
        const [adopted],
        byPosition: true,
      );

      expect(offered, isEmpty);
    });

    test('a linked site does not hide a neighbour 100 m away', () {
      const adopted = DiveSite(
        id: 's1',
        name: 'Barracuda East',
        location: GeoPoint(12.0000, -68.0000),
        catalogueId: 'east',
      );

      final offered = offerableCatalogueSites(
        const [_east, _west],
        const [adopted],
        byPosition: true,
      );

      expect(_ids(offered), ['west']);
    });

    test('an unlinked site within 150 m hides the record', () {
      // About 144 m north of _east.
      const mine = DiveSite(
        id: 's1',
        name: 'My Barracuda',
        location: GeoPoint(12.0013, -68.0000),
      );

      final offered = offerableCatalogueSites(
        const [_east],
        const [mine],
        byPosition: true,
      );

      expect(offered, isEmpty);
    });

    test('an unlinked site just past 150 m does not', () {
      // About 156 m north of _east.
      const mine = DiveSite(
        id: 's1',
        name: 'My Barracuda',
        location: GeoPoint(12.0014, -68.0000),
      );

      final offered = offerableCatalogueSites(
        const [_east],
        const [mine],
        byPosition: true,
      );

      expect(_ids(offered), ['east']);
    });

    test('byPosition false hides by link only', () {
      const mine = DiveSite(
        id: 's1',
        name: 'My Barracuda',
        location: GeoPoint(12.0000, -68.0000),
      );
      const adopted = DiveSite(id: 's2', name: 'West', catalogueId: 'west');

      final offered = offerableCatalogueSites(
        const [_east, _west],
        const [mine, adopted],
        byPosition: false,
      );

      expect(_ids(offered), ['east']);
    });

    test('a record without coordinates is hidden only by link', () {
      const mine = DiveSite(
        id: 's1',
        name: 'Anything',
        location: GeoPoint(0, 0),
      );

      expect(
        _ids(
          offerableCatalogueSites(
            const [_unlocated],
            const [mine],
            byPosition: true,
          ),
        ),
        ['nowhere'],
      );
      expect(
        offerableCatalogueSites(
          const [_unlocated],
          const [DiveSite(id: 's2', name: 'N', catalogueId: 'nowhere')],
          byPosition: true,
        ),
        isEmpty,
      );
    });

    test('a diver site without coordinates hides nothing by position', () {
      const mine = DiveSite(id: 's1', name: 'Barracuda East');

      final offered = offerableCatalogueSites(
        const [_east],
        const [mine],
        byPosition: true,
      );

      expect(_ids(offered), ['east']);
    });

    test('the order of the catalogue sites is kept', () {
      final offered = offerableCatalogueSites(
        const [_west, _unlocated, _east],
        const [],
        byPosition: true,
      );

      expect(_ids(offered), ['west', 'nowhere', 'east']);
    });

    test('a site near the antimeridian is hidden from across it', () {
      const across = CatalogueSite(
        id: 'fiji',
        name: 'Rainbow Reef',
        location: GeoPoint(-16.8, -179.9999),
        source: 'osm',
      );
      // About 21 m west of it, on the other side of the line.
      const mine = DiveSite(
        id: 's1',
        name: 'My Rainbow',
        location: GeoPoint(-16.8, 179.9999),
      );

      final offered = offerableCatalogueSites(
        const [across],
        const [mine],
        byPosition: true,
      );

      expect(offered, isEmpty);
    });
  });

  test('linkedCatalogueIds collects the non-null links', () {
    expect(
      linkedCatalogueIds(const [
        DiveSite(id: 's1', name: 'A', catalogueId: 'east'),
        DiveSite(id: 's2', name: 'B'),
        DiveSite(id: 's3', name: 'C', catalogueId: 'west'),
      ]),
      {'east', 'west'},
    );
  });
}

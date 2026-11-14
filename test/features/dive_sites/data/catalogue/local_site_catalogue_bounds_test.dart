import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/dive_sites/data/catalogue/local_site_catalogue.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_importer.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_bounds.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';

class _Bundle extends AssetBundle {
  _Bundle(this.catalogue);

  final String catalogue;

  @override
  Future<ByteData> load(String key) async {
    final text = key == kSiteCatalogueAsset ? catalogue : 'fixture';
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

/// What the map overlay reads: the catalogue's records in a view.
void main() {
  List<String> idsOf(List<CatalogueSite> sites) =>
      sites.map((s) => s.id).toList();

  /// A catalogue of just [sites].
  Future<LocalSiteCatalogue> catalogueOf(List<Object?> sites) async {
    final db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    await SiteCatalogueImporter(
      database: db,
      bundle: _Bundle(
        jsonEncode({
          'metadata': {'format': 2, 'sources': <String, Object?>{}},
          'sites': sites,
        }),
      ),
    ).importIfChanged();
    return LocalSiteCatalogue(database: db);
  }

  group('inBounds', () {
    const box = CatalogueBounds(south: 58, west: -4, north: 60, east: -2);
    Map<String, Object?> at(
      String id,
      double lat,
      double lon, {
      bool register = false,
    }) => {
      'id': id,
      'name': id,
      'lat': lat,
      'lon': lon,
      if (register) 'kind': 'register',
      'source': 'osm',
      'trust': 'verified',
    };

    test('returns the sites in the box and no others', () async {
      final catalogue = await catalogueOf([
        at('inside', 59, -3),
        at('wreck_inside', 59.5, -2.5, register: true),
        at('north', 61, -3),
        at('west', 59, -5),
        {'id': 'nowhere', 'name': 'x', 'source': 'osm', 'trust': 'verified'},
      ]);

      final result = await catalogue.inBounds(box);

      expect(idsOf(result.sites).toSet(), {'inside', 'wreck_inside'});
      expect(result.truncated, isFalse);
    });

    test('over the limit, dive sites come first, then the register '
        'records nearest the centre', () async {
      final catalogue = await catalogueOf([
        at('wreck_edge', 59.9, -2.1, register: true),
        at('wreck_centre', 59.01, -3.01, register: true),
        at('site_a', 58.2, -3.8),
        at('site_b', 59.8, -2.2),
        at('wreck_mid', 59.4, -3.4, register: true),
      ]);

      final result = await catalogue.inBounds(box, limit: 3);

      expect(idsOf(result.sites).toSet(), {'site_a', 'site_b', 'wreck_centre'});
      expect(result.truncated, isTrue);

      final all = await catalogue.inBounds(box, limit: 5);
      expect(all.sites, hasLength(5));
      expect(all.truncated, isFalse);
    });

    test('more dive sites than the limit is cut short too', () async {
      final catalogue = await catalogueOf([
        at('site_a', 58.2, -3.8),
        at('site_b', 59.8, -2.2),
        at('site_c', 59, -3),
      ]);

      final result = await catalogue.inBounds(box, limit: 2);

      expect(result.sites, hasLength(2));
      expect(result.truncated, isTrue);
    });

    test('more dive sites than the limit keeps the ones nearest the '
        'centre', () async {
      // Without an order the database answers in index order, south
      // first: a view of Europe marked nothing north of the Alps, and a
      // view of the world nothing north of 17 degrees.
      final catalogue = await catalogueOf([
        at('site_south_edge', 58.05, -3),
        at('site_centre', 59, -3),
        at('site_near', 59.2, -3),
        at('site_north_edge', 59.95, -3),
      ]);

      final result = await catalogue.inBounds(box, limit: 2);

      expect(idsOf(result.sites), ['site_centre', 'site_near']);
      expect(result.truncated, isTrue);
    });

    test('a box across the antimeridian holds both sides', () async {
      const seam = CatalogueBounds(
        south: -18,
        west: 179,
        north: -16,
        east: -179,
      );
      final catalogue = await catalogueOf([
        at('fiji_west', -16.8, 179.95),
        at('fiji_east', -16.8, -179.95),
        at('fiji_far', -16.8, 178.0),
        at('wreck_east', -17, -179.5, register: true),
      ]);

      final result = await catalogue.inBounds(seam);

      expect(idsOf(result.sites).toSet(), {
        'fiji_west',
        'fiji_east',
        'wreck_east',
      });
      expect(seam.center.longitude.abs(), closeTo(180, 0.001));
    });

    test('the whole world is one box', () async {
      const world = CatalogueBounds(
        south: -90,
        west: -180,
        north: 90,
        east: 180,
      );

      final catalogue = await catalogueOf([
        at('north', 78, 15),
        at('south', -54, -68),
        at('east', 20, 179.5),
        at('west', 20, -179.5, register: true),
        {'id': 'nowhere', 'name': 'x', 'source': 'osm', 'trust': 'verified'},
      ]);

      final result = await catalogue.inBounds(world, limit: 1000);

      expect(idsOf(result.sites).toSet(), {'north', 'south', 'east', 'west'});
    });
  });
}

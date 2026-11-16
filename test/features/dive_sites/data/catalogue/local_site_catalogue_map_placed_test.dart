import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/dive_sites/data/catalogue/local_site_catalogue.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_importer.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Matching reads map-placed records out to 2 km on their own, so the
/// records nearer the dive cannot fill the read's limit first (wider
/// sources design, section 5).

class _Bundle extends AssetBundle {
  _Bundle(this.catalogue);

  final String catalogue;

  @override
  Future<ByteData> load(String key) async {
    final text = key == kSiteCatalogueAsset ? catalogue : 'fixture';
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

const _point = GeoPoint(-8.27, 115.59);

/// A record [northMeters] north of [_point].
Map<String, Object?> _at(
  String id,
  double northMeters, {
  String trust = 'verified',
  String? positionFrom,
}) => {
  'id': id,
  'name': id,
  'lat': -8.27 + northMeters / 111194.93,
  'lon': 115.59,
  'source': 'osm',
  'trust': trust,
  'position_from': ?positionFrom,
};

void main() {
  late LocalCacheDatabase db;
  late LocalSiteCatalogue catalogue;

  setUp(() async {
    db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    await SiteCatalogueImporter(
      database: db,
      bundle: _Bundle(
        jsonEncode({
          'metadata': {'format': 2, 'sources': <String, Object?>{}},
          'sites': [
            _at('verified', 100),
            _at('stated', 200, trust: 'researched'),
            _at('garden', 1900, trust: 'researched', positionFrom: 'map'),
            _at('far_garden', 3000, trust: 'researched', positionFrom: 'map'),
          ],
        }),
      ),
    ).importIfChanged();
    catalogue = LocalSiteCatalogue(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('near with mapPlacedOnly reads only map-placed records, '
      'inside the radius', () async {
    final sites = await catalogue.near(
      _point,
      radiusMeters: 2000,
      mapPlacedOnly: true,
    );

    expect(sites.map((s) => s.id), ['garden']);
    expect(sites.single.positionFromMap, isTrue);
  });

  test('the limit counts map-placed records alone', () async {
    // Two nearer records would fill a limit of one if they were counted.
    final sites = await catalogue.near(
      _point,
      radiusMeters: 2000,
      limit: 1,
      mapPlacedOnly: true,
    );

    expect(sites.map((s) => s.id), ['garden']);
  });

  test('near without it reads every record in the radius', () async {
    final sites = await catalogue.near(_point, radiusMeters: 2000);

    expect(sites.map((s) => s.id), ['verified', 'stated', 'garden']);
  });
}

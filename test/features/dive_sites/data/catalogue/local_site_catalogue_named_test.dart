import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/dive_sites/data/catalogue/local_site_catalogue.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_importer.dart';
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

Map<String, Object?> _site(
  String id,
  String name, {
  double? lat = 1,
  double? lon = 1,
  String? countryCode,
}) => {
  'id': id,
  'name': name,
  'lat': ?lat,
  'lon': ?lon,
  'country_code': ?countryCode,
  'source': 'osm',
  'trust': 'verified',
};

final _fixture = jsonEncode({
  'metadata': {
    'format': 2,
    'sources': {
      'osm': {
        'name': 'OpenStreetMap',
        'licence': 'ODbL-1.0',
        'licence_url': 'https://www.openstreetmap.org/copyright',
        'credit': 'OpenStreetMap contributors',
      },
    },
  },
  'sites': [
    _site('bh_eg', 'Blue Hole', lat: 28.57, lon: 34.53, countryCode: 'EG'),
    _site('bh_bz', 'Blue Hole', lat: 17.31, lon: -87.53, countryCode: 'BZ'),
    _site('bh_north', 'Blue Hole North', lat: 28.58, lon: 34.53),
    _site('bh_lost', 'Blue Hole', lat: null, lon: null, countryCode: 'MT'),
    _site('pier', 'Salt-Pier', countryCode: 'BQ'),
    _site('cancun', 'Cancún Reef', countryCode: 'MX'),
    _site('wall', 'Wall', countryCode: 'KY'),
    // More records holding the word than a search returns.
    for (var i = 0; i < 60; i++) _site('wall_$i', 'North Wall $i'),
    _site('percent', '100% Reef'),
    _site('other', '100 Reef'),
  ],
});

void main() {
  late LocalCacheDatabase db;
  late LocalSiteCatalogue catalogue;

  setUp(() async {
    db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    await SiteCatalogueImporter(
      database: db,
      bundle: _Bundle(_fixture),
    ).importIfChanged();
    catalogue = LocalSiteCatalogue(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  Set<String> idsOf(List<CatalogueSite> sites) => {for (final s in sites) s.id};

  test('finds every located record of exactly that name', () async {
    expect(idsOf(await catalogue.named('Blue Hole')), {'bh_eg', 'bh_bz'});
  });

  test('a longer name that holds the words is not the same name', () async {
    expect(idsOf(await catalogue.named('Blue Hole North')), {'bh_north'});
    expect(await catalogue.named('Hole'), isEmpty);
  });

  test('case, accents and punctuation do not matter', () async {
    expect(idsOf(await catalogue.named('blue-hole')), {'bh_eg', 'bh_bz'});
    expect(idsOf(await catalogue.named('salt pier')), {'pier'});
    expect(idsOf(await catalogue.named('CANCUN REEF')), {'cancun'});
  });

  test('a country narrows the answer', () async {
    expect(idsOf(await catalogue.named('Blue Hole', countryCode: 'EG')), {
      'bh_eg',
    });
    expect(await catalogue.named('Blue Hole', countryCode: 'FR'), isEmpty);
  });

  test('a record without a position is never returned', () async {
    expect(await catalogue.named('Blue Hole', countryCode: 'MT'), isEmpty);
  });

  test('a blank name, or one of punctuation only, finds nothing', () async {
    expect(await catalogue.named(''), isEmpty);
    expect(await catalogue.named('   '), isEmpty);
    expect(await catalogue.named('?!'), isEmpty);
  });

  test('the exact name is found among many that hold the word', () async {
    expect(idsOf(await catalogue.named('Wall')), {'wall'});
  });

  test('a wildcard character in the name is read as itself', () async {
    expect(idsOf(await catalogue.named('100% Reef')), {'percent', 'other'});
    expect(await catalogue.named('1_0 Reef'), isEmpty);
  });

  test('a catalogue that cannot be read answers as an empty one', () async {
    await db.close();

    expect(await catalogue.named('Blue Hole'), isEmpty);

    // The tearDown closes it again; give it something to close.
    db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
  });
}

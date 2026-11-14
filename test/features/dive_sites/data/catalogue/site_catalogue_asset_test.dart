import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/database/site_type_seed.dart';
import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/core/geography/country_names.generated.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/dive_sites/data/catalogue/local_site_catalogue.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_importer.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_parser.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_bounds.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The shipped catalogue file itself: what the scripts wrote is what the
/// app can read, credit and place.
/// Serves the catalogue assets straight from the repository's files.
class _FileBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(p.joinAll(key.split('/'))).readAsBytesSync());
}

/// The sources that ship on their own terms, outside the ODbL database.
const _ownTermsSources = {'njdep', 'hi_dar', 'tpwd', 'nc_dmf'};

void main() {
  final catalogueFile = File(p.join('assets', 'data', 'site_catalogue.json'));
  final versionFile = File(p.join('assets', 'data', 'site_catalogue.version'));

  late Map<String, dynamic> doc;
  late List<Map<String, dynamic>> sites;

  setUpAll(() {
    doc = jsonDecode(catalogueFile.readAsStringSync()) as Map<String, dynamic>;
    sites = (doc['sites'] as List).cast<Map<String, dynamic>>();
  });

  test('the metadata names the format, the notice and the sources', () {
    final metadata = doc['metadata'] as Map<String, dynamic>;

    expect(metadata['format'], 2);
    expect(metadata['notice'], contains('Open Database License'));
    expect(
      metadata['notice'],
      contains('https://www.openstreetmap.org/copyright'),
    );
    expect(metadata['total_count'], sites.length);
    final sources = metadata['sources'] as Map<String, dynamic>;
    expect(sources.keys.toSet(), {
      'osm',
      'curated',
      'ukho',
      'awois',
      'fwc',
      'noaa_reefs',
      'fknms',
      'nms_ie',
      'wikidata',
      ..._ownTermsSources,
    });
    for (final source in sources.values.cast<Map<String, dynamic>>()) {
      expect(source['name'], isNotEmpty);
      expect(source['licence'], isNotEmpty);
      expect(source['credit'], isNotEmpty);
    }
  });

  test('the sources outside the ODbL database say so, and only they', () {
    final sources =
        (doc['metadata'] as Map<String, dynamic>)['sources']
            as Map<String, dynamic>;

    for (final MapEntry(:key, :value) in sources.entries) {
      expect(
        (value as Map<String, dynamic>)['own_terms'],
        _ownTermsSources.contains(key) ? isNotEmpty : isNull,
        reason: key,
      );
    }
    // Every one of them has records in the file: a source declared with
    // nothing shipped would be a credit for nothing.
    for (final key in sources.keys) {
      expect(sites.where((s) => s['source'] == key), isNotEmpty, reason: key);
    }
  });

  test("New Jersey's metadata ships beside its records", () {
    // NJDEP's agreement: its data is not redistributed without it.
    expect(sites.where((s) => s['source'] == 'njdep'), isNotEmpty);
    final metadata = File(
      p.join('assets', 'data', 'site_catalogue_njdep_metadata.xml'),
    );
    expect(metadata.existsSync(), isTrue);
    expect(metadata.readAsStringSync(), contains('<metadata'));
  });

  test('every record is complete, unique and from a declared source', () {
    final sources = (doc['metadata'] as Map<String, dynamic>)['sources'] as Map;
    final ids = <String>{};

    expect(sites, hasLength(20932));
    for (final site in sites) {
      final id = site['id'] as String;
      expect(ids.add(id), isTrue, reason: 'duplicate id $id');
      expect(site['name'], isNotEmpty, reason: id);
      expect(sources.containsKey(site['source']), isTrue, reason: id);
      expect(site['trust'], 'verified', reason: id);
      expect(site.containsKey('lat'), site.containsKey('lon'), reason: id);
      // Empty values are left out, never written as null.
      expect(site.values, everyElement(isNotNull), reason: id);
    }
  });

  test('every country is one the app knows by that code', () {
    for (final site in sites) {
      final id = site['id'] as String;
      final code = site['country_code'] as String?;
      final country = site['country'] as String?;
      expect(code == null, country == null, reason: id);
      if (code == null) continue;
      expect(assignedAlpha2Codes, contains(code), reason: id);
      // The name must read back as the same country, or the site's flag
      // and its country text would disagree once it is adopted.
      expect(countryCodeFor(country), code, reason: '$id: $country');
    }
  });

  test('every record is a dive site or a register record with a '
      'position', () {
    for (final site in sites) {
      final id = site['id'] as String;
      expect(site['kind'], anyOf(isNull, 'register'), reason: id);
      if (site['kind'] == 'register') {
        expect(site['lat'], isNotNull, reason: id);
        expect(site['lon'], isNotNull, reason: id);
      }
    }
    final registers = sites.where((s) => s['kind'] == 'register').length;
    expect(registers, 17001);
    expect(sites.length - registers, 3931);
  });

  test('no dive site a diver may hold was lost to a register', () {
    // Every curated site ships, and none of them as a register record.
    final curated = sites.where((s) => s['source'] == 'curated').toList();
    expect(curated, hasLength(55));
    expect(curated.map((s) => s['kind']), everyElement(isNull));
    // One wreck, three sources: it ships once, as the dive site.
    final thistlegorm = sites
        .where((s) => (s['name'] as String) == 'SS Thistlegorm')
        .toList();
    expect(thistlegorm.single['id'], 'osm_node_255316037');
    expect(thistlegorm.single['kind'], isNull);
  });

  test('the dive businesses the last catalogue listed as sites are gone', () {
    // Dive centres, shops and a dive hotel that OpenStreetMap tags with the
    // sport, which the last catalogue shipped as places to dive.
    const businesses = {
      'osm_node_2678338322', // Blue Coral Diving, a travel agency
      'osm_node_4694084262', // Bali Dive Trek, a sports centre
      'osm_node_12374075315', // Twin Island Dive, a shop
      'osm_node_4432316400', // Murex Dive, a hotel
      'osm_node_3842620651', // Centre de Plongée Souterraine
    };

    expect(sites.map((s) => s['id']).toSet().intersection(businesses), isEmpty);
  });

  test('nothing ships at 0, 0 or off the globe', () {
    for (final site in sites) {
      final lat = site['lat'] as num?;
      final lon = site['lon'] as num?;
      if (lat == null || lon == null) continue;
      final id = site['id'] as String;
      expect(lat, inInclusiveRange(-90, 90), reason: id);
      expect(lon, inInclusiveRange(-180, 180), reason: id);
      expect(lat == 0 && lon == 0, isFalse, reason: id);
    }
  });

  test('wrecks on dry land are not offered as dives', () {
    // OpenStreetMap's and Wikidata's wrecks include aircraft on mountains
    // and hulls in museums: each of these shipped before the land gate.
    const onLand = {
      'Fairchild C-82', // inland Alaska
      'SS Sultana', // under an Arkansas field
      'Haithabu 1', // a museum ship
      'liberator B-24', // the Julian Alps
    };

    expect(sites.map((s) => s['name']).toSet().intersection(onLand), isEmpty);
  });

  test('register depths are ones a diver can reach', () {
    for (final site in sites.where((s) => s['kind'] == 'register')) {
      final id = site['id'] as String;
      final depth = site['max_depth_m'] as num?;
      if (depth != null) expect(depth, lessThanOrEqualTo(60), reason: id);
      if (site['source'] == 'ukho') {
        expect(depth, inInclusiveRange(2, 60), reason: id);
      }
    }
  });

  test('no reef comes from a state whose terms keep it out of the '
      'federal file', () {
    // Florida, New Jersey and North Carolina come from their own files;
    // New York's terms forbid distribution.
    expect(
      sites.map((s) => s['id'] as String),
      everyElement(isNot(matches(RegExp(r'^usreef_(fl|nj|nc|ny)_')))),
    );
  });

  test('a territory is its own country, and regions read in English', () {
    final tahiti = sites.singleWhere((s) => s['id'] == 'osm_node_663869230');
    expect(tahiti['country_code'], 'PF');
    expect(tahiti['country'], 'French Polynesia');
    expect(tahiti['region'], 'Windward Islands');
    // Latin letters and their accents only: no region in Thai, Arabic or
    // Dhivehi script, as the last catalogue had.
    final latin = RegExp(r"^[\u0020-\u024F\u1E00-\u1EFF\u2013\u2018\u2019]+$");
    for (final site in sites) {
      final region = site['region'] as String?;
      if (region == null) continue;
      expect(region, matches(latin), reason: site['id'] as String);
    }
  });

  test('the file is one record to a line', () {
    // A refresh then shows in a diff as the records that changed.
    // Line endings folded, so a checkout that rewrites them still agrees.
    final lines = catalogueFile
        .readAsStringSync()
        .replaceAll('\r\n', '\n')
        .split('\n');

    expect(lines.first, startsWith('{"metadata":'));
    expect(lines.first, endsWith('"sites":['));
    expect(lines.sublist(lines.length - 2), [']}', '']);
    expect(lines, hasLength(sites.length + 3));
  });

  test('a Bonaire site is in the Caribbean Netherlands, not the '
      'Netherlands', () {
    final saltPier = sites.singleWhere((s) => s['id'] == 'osm_node_663869401');

    expect(saltPier['name'], 'Salt Pier');
    expect(saltPier['country_code'], 'BQ');
    expect(saltPier['country'], 'Caribbean Netherlands');
  });

  test('depths are a maximum, or a range that reads the right way', () {
    for (final site in sites) {
      final min = site['min_depth_m'] as num?;
      final max = site['max_depth_m'] as num?;
      if (min == null) continue;
      expect(max, isNotNull, reason: '${site['id']}: a lone depth is a max');
      expect(min, lessThan(max!), reason: site['id'] as String);
    }
  });

  test('every type and entry is a name the app has', () {
    final entryNames = EntryMethod.values.map((m) => m.name).toSet();
    for (final site in sites) {
      for (final type in (site['types'] as List?) ?? const []) {
        expect(kBuiltInSiteTypeIds, contains(type), reason: site['id']);
      }
      for (final entry in (site['entry'] as List?) ?? const []) {
        expect(entryNames, contains(entry), reason: site['id']);
      }
    }
  });

  test('every OpenStreetMap record points at its object', () {
    for (final site in sites.where((s) => s['source'] == 'osm')) {
      expect(
        site['source_ref'],
        startsWith('https://www.openstreetmap.org/'),
        reason: site['id'] as String,
      );
    }
  });

  test('the app reads every record of the file', () {
    final parsed = parseSiteCatalogue(catalogueFile.readAsStringSync());

    expect(parsed.format, 2);
    expect(parsed.sites, hasLength(sites.length));
    expect(parsed.sources.map((s) => s.key), containsAll(['osm', 'curated']));
    expect(
      parsed.sites.where((s) => s.kind == CatalogueKind.register),
      hasLength(sites.where((s) => s['kind'] == 'register').length),
    );
  });

  test('the version sidecar is the hash of the file', () {
    final hash = sha256.convert(catalogueFile.readAsBytesSync()).toString();

    expect(versionFile.readAsStringSync(), hash);
  });

  test('the shipped file imports whole and answers a real query', () async {
    final db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);

    final outcome = await SiteCatalogueImporter(
      database: db,
      bundle: _FileBundle(),
    ).importIfChanged();

    expect(outcome, SiteCatalogueImportOutcome.imported);
    final catalogue = LocalSiteCatalogue(database: db);
    final located = await catalogue.inBounds(
      const CatalogueBounds(south: -90, west: -180, north: 90, east: 180),
      limit: 1000000,
    );
    expect(located.sites, hasLength(20932));
    expect(located.truncated, isFalse);
    // Salt Pier, by name and by place.
    final found = await catalogue.search('salt pier');
    expect(found.map((s) => s.id), contains('osm_node_663869401'));
    final nearSaltPier = await catalogue.near(
      const GeoPoint(12.0836, -68.2820),
      radiusMeters: 50000,
    );
    expect(nearSaltPier.first.id, 'osm_node_663869401');
    expect(nearSaltPier.length, greaterThan(20));
    expect(
      (await catalogue.source('osm'))!.credit,
      'OpenStreetMap contributors',
    );
  });

  test('a changed sea table comes with a new import revision', () {
    // The rows an import writes depend on the sea table as well as on the
    // catalogue file: it names each site's sea. Only the catalogue file's
    // hash is in the version an install stores, so a sea table that changes
    // on its own would never reach an app that has already imported. The
    // import revision is what forces that import, and this pins the two
    // together.
    //
    // If this fails because sea_areas.json changed: raise
    // kSiteCatalogueImportRevision, then put the new revision and hash here.
    const pinned = (
      revision: 3,
      seaTable:
          '184175e914bbc5cdde973767181c50a75af59b49b1f5def95ff845eb89e659a6',
    );

    final seaTable = File(p.join('assets', 'data', 'sea_areas.json'));
    // Line endings folded, so a checkout that rewrites them still agrees.
    final hash = sha256
        .convert(
          utf8.encode(seaTable.readAsStringSync().replaceAll('\r\n', '\n')),
        )
        .toString();

    expect((revision: kSiteCatalogueImportRevision, seaTable: hash), pinned);
  });

  /// The shipped file, imported as the app imports it.
  Future<LocalSiteCatalogue> shippedCatalogue() async {
    final db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    await SiteCatalogueImporter(
      database: db,
      bundle: _FileBundle(),
    ).importIfChanged();
    return LocalSiteCatalogue(database: db);
  }

  test('the shipped catalogue is found by island and by sea', () async {
    // What a diver types, and what the import page's Red Sea and Caribbean
    // chips search for. Before the island and the sea names these found
    // 0, 1 and 64 sites (the 64 only because Bonaire's country reads
    // "Caribbean Netherlands").
    final catalogue = await shippedCatalogue();

    final bonaire = await catalogue.search('bonaire', limit: 1000);
    expect(bonaire.where((s) => s.island == 'Bonaire').length, greaterThan(50));
    // Anything else is in the island's country, whose full name carries
    // the word (two sites on Saba), or is named with it (a Florida wreck,
    // the Esso Bonaire).
    expect(
      bonaire
          .where((s) => s.island != 'Bonaire' && s.countryCode != 'BQ')
          .map((s) => normalize(s.name)),
      everyElement(contains('bonaire')),
    );
    expect(
      (await catalogue.search('red sea', limit: 1000)).length,
      greaterThan(150),
    );
    expect(
      (await catalogue.search('caribbean', limit: 1000)).length,
      greaterThan(150),
    );
    // "sea" is in the name of most seas, so it matches over a thousand
    // sites by place. The sites named with it still lead the list.
    final sea = await catalogue.search('sea');
    expect(sea, hasLength(50));
    expect(
      sea.take(20).map((s) => normalize(s.name)),
      everyElement(contains('sea')),
    );
    // A cenote a few hundred metres from the Caribbean is still not in it.
    final cenotes = await catalogue.search('cenote', limit: 1000);
    expect(
      cenotes
          .where((s) => s.typeIds.contains('cenote'))
          .map((s) => s.bodyOfWater),
      everyElement(isNull),
    );
  });

  group('the shipped catalogue is found by a country named in another '
      'language', () {
    // Issue #4520's countries, each as a diver who does not write English
    // types it. The catalogue holds the English name only.
    for (final (query, code) in [
      ('Thaïlande', 'TH'),
      ('Ägypten', 'EG'),
      ('Allemagne', 'DE'),
      ('Suiza', 'CH'),
      ('Maldivas', 'MV'),
      ('Grecia', 'GR'),
      ('Espagne', 'ES'),
      ('Italien', 'IT'),
    ]) {
      test('"$query" lists that country\'s sites', () async {
        final catalogue = await shippedCatalogue();

        final found = await catalogue.search(query, limit: 5000);

        final inCountry = sites.where((s) => s['country_code'] == code).length;
        expect(inCountry, greaterThan(0));
        expect(found.where((s) => s.countryCode == code), hasLength(inCountry));
        // Anything else is a site named with the word itself.
        expect(
          found
              .where((s) => s.countryCode != code)
              .map((s) => normalize(s.name)),
          everyElement(contains(normalize(query))),
        );
      });
    }
  });
}

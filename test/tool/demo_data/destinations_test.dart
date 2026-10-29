import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/demo_data/src/story/catalog.dart';
import '../../../tool/demo_data/src/story/destination_life.dart';
import '../../../tool/demo_data/src/story/destinations.dart';
import '../../../tool/demo_data/src/story/name_regions.dart';
import '../../../tool/demo_data/src/story/story_plan.dart';

void main() {
  late Catalog catalog;
  final all = [homeDestination, ...tripDestinations];

  setUpAll(() => catalog = Catalog.load('assets/data'));

  test('at least 25 trip destinations with unique keys', () {
    expect(tripDestinations.length, greaterThanOrEqualTo(25));
    expect({for (final d in all) d.key}.length, all.length);
  });

  test('every destination has at least 6 catalogue sites in its area', () {
    for (final d in all) {
      expect(
        catalogSitesFor(d, catalog).length,
        greaterThanOrEqualTo(6),
        reason: d.key,
      );
    }
  });

  test('shops and tour operators are never picked as dive sites', () {
    final centreNames = {for (final c in catalog.centers) c.name};
    for (final d in all) {
      for (final s in catalogSitesFor(d, catalog)) {
        expect(centreNames, isNot(contains(s.name)), reason: s.name);
        expect(
          s.name.toLowerCase(),
          isNot(matches(RegExp(r'\b(shop|tours?|shuttle|scuba|diving)\b'))),
          reason: s.name,
        );
      }
    }
  });

  test('every destination has a catalogue dive centre in its country', () {
    for (final d in all) {
      expect(
        catalog.centers.where((c) => c.country == d.country),
        isNotEmpty,
        reason: d.key,
      );
    }
  });

  test('destinations span the world', () {
    expect({for (final d in all) d.country}.length, greaterThanOrEqualTo(15));
    final points = [
      for (final d in all)
        for (final s in catalogSitesFor(d, catalog).take(1))
          (s.latitude, s.longitude),
    ];
    expect(points.where((p) => p.$2 < -30), isNotEmpty);
    expect(points.where((p) => p.$2 >= -30 && p.$2 <= 60), isNotEmpty);
    expect(points.where((p) => p.$2 > 60), isNotEmpty);
    expect(points.where((p) => p.$1 < 0).length, greaterThanOrEqualTo(3));
  });

  test('freshwater beyond home, and no scooter where it would be a cave', () {
    final fresh = all.where((d) => d.freshwater).map((d) => d.key).toList();
    expect(fresh, containsAll(['florida-springs', 'st-lawrence']));
    final springs = all.where((d) => d.key == 'florida-springs').single;
    expect(springs.scooterOk, isFalse);
  });

  test('home is the New Jersey coast, dived at its curated sites', () {
    expect(homeDestination.country, 'United States');
    expect(homeDestination.region, 'New Jersey');
    expect(homeDestination.freshwater, isFalse);
    // A summer thermocline over cold bottom water, like a lake.
    expect(homeDestination.stratifies, isTrue);
    expect(homeDestination.utcOffsetMinutes, -300);
    expect(homeDestination.daylightSaving, DaylightSaving.north);
    final sites = catalogSitesFor(homeDestination, catalog);
    expect(sites.length, greaterThanOrEqualTo(12));
    for (final s in sites) {
      expect(s.id, startsWith('curated_nj_'), reason: s.name);
    }
  });

  test('the home site table matches the curated sites', () {
    final curated =
        (jsonDecode(File('scripts/dive_sites_curated.json').readAsStringSync())
                as List)
            .cast<Map<String, Object?>>()
            .where((s) => (s['id']! as String).startsWith('curated_nj_'));
    expect(homeSiteDepthM, {
      for (final s in curated) s['id']: (s['depthM']! as num).toDouble(),
    });
    expect(homeShoreSites, {
      for (final s in curated)
        if (s['kind'] == 'shore') s['id'],
    });
  });

  test('the near-home weekends are northeastern, not European', () {
    final near = [
      for (final d in tripDestinations)
        if (d.nearHome) d.key,
    ];
    expect(near, ['st-lawrence']);
    expect(
      tripDestinations.map((d) => d.key),
      isNot(anyOf(contains('austria-lakes'), contains('swiss-lakes'))),
    );
  });

  test('seven Caribbean destinations, each a trip destination', () {
    expect(caribbeanDestinations, {
      'bonaire',
      'curacao',
      'cozumel',
      'dominican',
      'guadeloupe',
      'san-andres',
      'santa-marta',
    });
    final keys = {for (final d in tripDestinations) d.key};
    expect(keys, containsAll(caribbeanDestinations));
  });

  test('every destination names known species and built-in site types', () {
    final species = {
      for (final s
          in (jsonDecode(File('assets/data/species.json').readAsStringSync())
                  as Map<String, Object?>)['species']!
              as List)
        (s as Map)['commonName'] as String,
    };
    final seed = File(
      'lib/core/database/site_type_seed.dart',
    ).readAsStringSync();
    for (final d in all) {
      final names = destinationSpecies[d.key];
      expect(names, isNotNull, reason: d.key);
      expect(names!.length, greaterThanOrEqualTo(3), reason: d.key);
      for (final n in names) {
        expect(species, contains(n), reason: '${d.key}: $n');
      }
      final types = destinationSiteTypes[d.key];
      expect(types, isNotEmpty, reason: d.key);
      for (final t in types!) {
        expect(seed, contains("'$t'"), reason: '${d.key}: $t');
      }
    }
  });

  test('every destination names a known region for its people', () {
    for (final d in all) {
      expect(nameRegions, contains(d.nameRegion), reason: d.key);
    }
  });
}

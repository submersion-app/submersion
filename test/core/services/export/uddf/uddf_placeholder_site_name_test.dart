import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/universal_import/data/services/import_site_location.dart';

/// Oceanic+ writes every site's own id as its `<name>` (#2938):
///
///     <site id="site_67967df50a920e3cfb15217b">
///         <name>site_67967df50a920e3cfb15217b</name>
///
/// and mints a fresh site for every dive, even at the same reef. Read
/// verbatim, the log filled with sites called `site_6a78edb8033b...`, one
/// per dive.
void main() {
  Future<UddfImportResult> parse(String sites, String dives) =>
      UddfFullImportService().importAllDataFromUddf('''
<?xml version="1.0" encoding="UTF-8" ?>
<uddf version="3.2.1" xmlns="http://www.streit.cc/uddf/3.2/">
  <divesite>$sites</divesite>
  <profiledata>
    <repetitiongroup id="rg_1">$dives</repetitiongroup>
  </profiledata>
</uddf>''');

  String site(String id, {String? name, double? lat, double? lon}) =>
      '''
<site id="$id">
  ${name == null ? '' : '<name>$name</name>'}
  ${lat == null ? '' : '''
  <geography>
    <location>$id</location>
    <latitude>$lat</latitude>
    <longitude>$lon</longitude>
  </geography>'''}
</site>''';

  String dive(String id, String siteRef, String datetime) =>
      '''
<dive id="$id">
  <informationbeforedive>
    <link ref="$siteRef"/>
    <datetime>$datetime</datetime>
  </informationbeforedive>
  <informationafterdive>
    <greatestdepth>18.0</greatestdepth>
    <diveduration>2400</diveduration>
  </informationafterdive>
</dive>''';

  group('a site whose name is its own id', () {
    test('is named from its coordinates instead', () async {
      final result = await parse(
        site('site_aaa1', name: 'site_aaa1', lat: 19.5, lon: -155.9),
        dive('dive_1', 'site_aaa1', '2025-12-26T07:48:00'),
      );

      expect(result.sites, hasLength(1));
      expect(
        result.sites.single['name'],
        ImportSiteLocation.nameFromCoordinates(19.5, -155.9),
      );
      expect(result.dives.single['site'], same(result.sites.single));
    });

    test('is matched ignoring surrounding whitespace', () async {
      final result = await parse(
        site('site_aaa1', name: '  site_aaa1  ', lat: 19.5, lon: -155.9),
        dive('dive_1', 'site_aaa1', '2025-12-26T07:48:00'),
      );

      expect(
        result.sites.single['name'],
        ImportSiteLocation.nameFromCoordinates(19.5, -155.9),
      );
    });

    test(
      'with no coordinates either is dropped, like any empty site',
      () async {
        final result = await parse(
          site('site_aaa1', name: 'site_aaa1'),
          dive('dive_1', 'site_aaa1', '2025-12-26T07:48:00'),
        );

        expect(result.sites, isEmpty);
        expect(result.dives.single['site'], isNull);
      },
    );
  });

  group('placeholder sites at one spot', () {
    test('fold into one site that every dive links to', () async {
      final result = await parse(
        [
          site('site_a', name: 'site_a', lat: 19.5, lon: -155.9),
          site('site_b', name: 'site_b', lat: 19.5, lon: -155.9),
          site('site_c', name: 'site_c', lat: 19.50001, lon: -155.90001),
        ].join(),
        [
          dive('dive_1', 'site_a', '2025-12-26T07:48:00'),
          dive('dive_2', 'site_b', '2025-12-26T09:54:00'),
          dive('dive_3', 'site_c', '2025-12-27T18:34:00'),
        ].join(),
      );

      expect(result.sites, hasLength(1));
      final survivor = result.sites.single;
      expect(survivor['uddfId'], 'site_a');
      for (final d in result.dives) {
        expect(d['site'], same(survivor));
      }
    });

    test('stay apart when they are far from each other', () async {
      final result = await parse(
        [
          site('site_a', name: 'site_a', lat: 19.5, lon: -155.9),
          site('site_b', name: 'site_b', lat: 20.5, lon: -156.9),
        ].join(),
        [
          dive('dive_1', 'site_a', '2025-12-26T07:48:00'),
          dive('dive_2', 'site_b', '2025-12-26T09:54:00'),
        ].join(),
      );

      expect(result.sites, hasLength(2));
      expect(result.dives[0]['site'], same(result.sites[0]));
      expect(result.dives[1]['site'], same(result.sites[1]));
    });

    test('fold into a named site sitting on top of them', () async {
      final result = await parse(
        [
          site('site_a', name: 'site_a', lat: 19.5, lon: -155.9),
          site('s_named', name: 'Kealakekua Bay', lat: 19.5, lon: -155.9),
        ].join(),
        dive('dive_1', 'site_a', '2025-12-26T07:48:00'),
      );

      expect(result.sites, hasLength(1));
      expect(result.sites.single['name'], 'Kealakekua Bay');
      expect(result.dives.single['site'], same(result.sites.single));
    });
  });

  test(
    'a dive keeps its site when that site folds into one with no id',
    () async {
      // UDDF keeps a <site> without an id. When a placeholder site folds into
      // it, the survivor has to take the placeholder's id, or the dive's
      // <link ref> no longer resolves.
      final result = await parse(
        [
          '<site><name>Kealakekua Bay</name><geography>'
              '<latitude>19.5</latitude><longitude>-155.9</longitude>'
              '</geography></site>',
          site('site_a', name: 'site_a', lat: 19.5, lon: -155.9),
        ].join(),
        dive('dive_1', 'site_a', '2025-12-26T07:48:00'),
      );

      expect(result.sites, hasLength(1));
      expect(result.sites.single['name'], 'Kealakekua Bay');
      expect(result.sites.single['uddfId'], 'site_a');
      expect(result.dives.single['site'], same(result.sites.single));
      expect(result.divesMissingSite, 0);
    },
  );

  test('two named sites sharing a name and a spot are kept apart', () async {
    // Submersion's own export can hold two sites with one name, and a round
    // trip has to bring both back.
    final result = await parse(
      [
        site('s1', name: 'House Reef', lat: 19.5, lon: -155.9),
        site('s2', name: 'House Reef', lat: 19.5, lon: -155.9),
      ].join(),
      [
        dive('dive_1', 's1', '2025-12-26T07:48:00'),
        dive('dive_2', 's2', '2025-12-26T09:54:00'),
      ].join(),
    );

    expect(result.sites, hasLength(2));
    expect(result.dives[0]['site'], same(result.sites[0]));
    expect(result.dives[1]['site'], same(result.sites[1]));
  });

  test('a real Oceanic+ export imports one named site per place', () async {
    final content = await File(
      p.join('test', 'dives', 'issue_279_oceanic_plus_export.uddf'),
    ).readAsString();

    final result = await UddfFullImportService().importAllDataFromUddf(content);

    // Nine dives, nine <site> elements, three distinct positions.
    expect(result.dives, hasLength(9));
    expect(result.sites, hasLength(3));
    for (final s in result.sites) {
      expect(s['name'], isNot(startsWith('site_')));
    }
    for (final d in result.dives) {
      expect(result.sites, contains(same(d['site'])));
    }
    expect(result.divesMissingSite, 0);
  });
}

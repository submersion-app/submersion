import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';

/// Subsurface only gained the top-level `<divesites>` block in 4.5. Every file
/// written before that carries each dive's site inline, as a `<location>`
/// child of `<dive>`, so a logbook that predates the migration has no
/// `divesiteid` anywhere and its sites have no uuids to link by.
void main() {
  final parser = SubsurfaceXmlParser();
  const legacyFixturePath =
      'test/features/universal_import/data/parsers/fixtures/'
      'legacy-inline-sites.ssrf';

  Uint8List xmlBytes(String xml) => Uint8List.fromList(utf8.encode(xml));

  String? siteRefOf(Map<String, dynamic> dive) =>
      (dive['site'] as Map<String, dynamic>?)?['uddfId'] as String?;

  Map<String, dynamic> siteNamed(
    List<Map<String, dynamic>> sites,
    String name,
  ) => sites.firstWhere(
    (site) => site['name'] == name,
    orElse: () =>
        fail('no site named "$name" in ${sites.map((s) => s['name'])}'),
  );

  /// A pre-4.5 file: no `<divesites>` block, sites inline on each dive.
  String legacyDivelog(String dives) =>
      '''
<divelog program='subsurface' version='2'>
<dives>
$dives
</dives>
</divelog>
''';

  String legacyDive(
    String locationXml, {
    int number = 1,
    String date = '2011-06-18',
  }) =>
      '''
<dive number='$number' date='$date' time='0$number:11:00' duration='47:30 min'>
  $locationXml
  <divecomputer model='Suunto Vyper'>
  <depth max='28.3 m' mean='16.7 m' />
  </divecomputer>
</dive>
''';

  group('a site Subsurface wrote inline, before 4.5', () {
    test('comes from <location> and its gps attribute', () async {
      final result = await parser.parse(
        xmlBytes(
          legacyDivelog(
            legacyDive(
              "<location gps='12.216667 -68.283333'>Karpata</location>",
            ),
          ),
        ),
      );

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites.length, 1);
      expect(sites[0]['name'], 'Karpata');
      expect(sites[0]['latitude'], closeTo(12.216667, 0.00001));
      expect(sites[0]['longitude'], closeTo(-68.283333, 0.00001));

      final dive = result.entitiesOf(ImportEntityType.dives).single;
      expect(siteRefOf(dive), sites[0]['uddfId']);
    });

    test('comes from a <gps> child when <location> carries none', () async {
      // Subsurface's own save path never wrote this shape, but its parser
      // matches a bare `gps` entry anywhere under a dive, so files other
      // tools produced for it put the coordinates here.
      final result = await parser.parse(
        xmlBytes(
          legacyDivelog(
            legacyDive(
              '<location>1000 Steps</location>\n'
              '  <gps>12.207500 -68.287500</gps>',
            ),
          ),
        ),
      );

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites.single['name'], '1000 Steps');
      expect(sites.single['latitude'], closeTo(12.2075, 0.00001));
      expect(sites.single['longitude'], closeTo(-68.2875, 0.00001));
    });

    test('survives with a name alone when the dive has no gps', () async {
      final result = await parser.parse(
        xmlBytes(legacyDivelog(legacyDive('<location>Salt Pier</location>'))),
      );

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites.single['name'], 'Salt Pier');
      expect(sites.single.containsKey('latitude'), isFalse);
      expect(
        siteRefOf(result.entitiesOf(ImportEntityType.dives).single),
        sites.single['uddfId'],
      );
    });

    test('survives with coordinates alone when the dive has no name', () async {
      // `show_location()` wrote a self-closing <location> when the dive had
      // coordinates but no name. The fold names it from its coordinates
      // rather than discarding a place the diver actually dived.
      final result = await parser.parse(
        xmlBytes(legacyDivelog(legacyDive("<location gps='12.19 -68.30'/>"))),
      );

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites.single['latitude'], closeTo(12.19, 0.00001));
      expect(sites.single['name'], isNotEmpty);
      expect(
        siteRefOf(result.entitiesOf(ImportEntityType.dives).single),
        sites.single['uddfId'],
      );
    });

    test('is left alone when the dive names no place at all', () async {
      final result = await parser.parse(
        xmlBytes(legacyDivelog(legacyDive(''))),
      );

      expect(result.entitiesOf(ImportEntityType.sites), isEmpty);
      expect(
        siteRefOf(result.entitiesOf(ImportEntityType.dives).single),
        isNull,
      );
      expect(result.warnings, isEmpty);
    });
  });

  group('inline sites fold like declared ones', () {
    test('one reef logged on many dives becomes one site', () async {
      // Subsurface split a site whenever the dive's GPS drifted more than
      // 20 m, so the same reef reaches us under slightly different fixes.
      final result = await parser.parse(
        xmlBytes(
          legacyDivelog(
            legacyDive(
                  "<location gps='12.216667 -68.283333'>Karpata</location>",
                ) +
                legacyDive(
                  "<location gps='12.216700 -68.283300'>Karpata</location>",
                  number: 2,
                ) +
                legacyDive('<location>Karpata</location>', number: 3),
          ),
        ),
      );

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites.length, 1);
      expect(sites.single['name'], 'Karpata');

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.map(siteRefOf).toSet(), {sites.single['uddfId']});
    });

    test('two places that share a name stay apart', () async {
      final result = await parser.parse(
        xmlBytes(
          legacyDivelog(
            legacyDive(
                  "<location gps='12.216667 -68.283333'>Blue Hole</location>",
                ) +
                legacyDive(
                  "<location gps='17.315000 -87.535000'>Blue Hole</location>",
                  number: 2,
                ),
          ),
        ),
      );

      expect(result.entitiesOf(ImportEntityType.sites).length, 2);
      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(siteRefOf(dives[0]), isNot(siteRefOf(dives[1])));
    });
  });

  group('a file that mixes both layouts', () {
    test('keeps the declared site and adds the inline one', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<divesites>
<site uuid='abc123' name='Blue Hole' gps='18.465562 -66.084902'/>
</divesites>
<dives>
<dive number='1' divesiteid='abc123' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'><depth max='20.0 m' mean='15.0 m' /></divecomputer>
</dive>
${legacyDive("<location gps='12.216667 -68.283333'>Karpata</location>", number: 2)}
</dives>
</divelog>
'''),
      );

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites.map((s) => s['name']), ['Blue Hole', 'Karpata']);

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(siteRefOf(dives[0]), 'abc123');
      expect(siteRefOf(dives[1]), siteNamed(sites, 'Karpata')['uddfId']);
      expect(result.warnings, isEmpty);
    });

    test(
      'folds an inline site into the declared site of the same name',
      () async {
        final result = await parser.parse(
          xmlBytes('''
<divelog program='subsurface' version='3'>
<divesites>
<site uuid='abc123' name='Karpata' gps='12.216667 -68.283333'/>
</divesites>
<dives>
<dive number='1' divesiteid='abc123' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'><depth max='20.0 m' mean='15.0 m' /></divecomputer>
</dive>
${legacyDive("<location gps='12.216700 -68.283300'>Karpata</location>", number: 2)}
</dives>
</divelog>
'''),
        );

        final sites = result.entitiesOf(ImportEntityType.sites);
        expect(sites.length, 1);
        expect(sites.single['uddfId'], 'abc123');
        expect(result.entitiesOf(ImportEntityType.dives).map(siteRefOf), [
          'abc123',
          'abc123',
        ]);
      },
    );

    test('prefers the declared site when a dive carries both', () async {
      // A modern file that still writes a legacy <location> describes the
      // same place twice; the declared site is the richer record.
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<divesites>
<site uuid='abc123' name='Blue Hole' gps='18.465562 -66.084902'>
  <geo cat='2' origin='2' value='Puerto Rico'/>
</site>
</divesites>
<dives>
<dive number='1' divesiteid='abc123' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <location gps='12.216667 -68.283333'>Karpata</location>
  <divecomputer model='Test'><depth max='20.0 m' mean='15.0 m' /></divecomputer>
</dive>
</dives>
</divelog>
'''),
      );

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites.single['name'], 'Blue Hole');
      expect(sites.single['country'], 'Puerto Rico');
      expect(
        siteRefOf(result.entitiesOf(ImportEntityType.dives).single),
        'abc123',
      );
    });
  });

  group('a dive whose site the file never describes', () {
    String danglingDivelog(int dives) =>
        '''
<divelog program='subsurface' version='3'>
<divesites>
<site uuid='abc123' name='Blue Hole' gps='18.465562 -66.084902'/>
</divesites>
<dives>
${[for (var n = 1; n <= dives; n++) "<dive number='$n' divesiteid='gone$n' date='2025-01-1$n' "
              "time='10:00:00' duration='30:00 min'>"
              "<divecomputer model='Test'>"
              "<depth max='20.0 m' mean='15.0 m' /></divecomputer></dive>"].join('\n')}
</dives>
</divelog>
''';

    test('imports with no site rather than a reference to nothing', () async {
      final result = await parser.parse(xmlBytes(danglingDivelog(1)));

      expect(
        result.entitiesOf(ImportEntityType.sites).single['uddfId'],
        'abc123',
      );
      expect(
        siteRefOf(result.entitiesOf(ImportEntityType.dives).single),
        isNull,
      );
    });

    test('is reported rather than lost in silence', () async {
      final result = await parser.parse(xmlBytes(danglingDivelog(1)));

      final warning = result.warnings.single;
      expect(warning.code, ImportWarningCode.sitesUnresolved);
      expect(warning.severity, ImportWarningSeverity.warning);
      expect(warning.entityType, ImportEntityType.dives);
      expect(warning.count, 1);
    });

    test('is counted once for the whole file, not once per dive', () async {
      final result = await parser.parse(xmlBytes(danglingDivelog(3)));

      expect(result.warnings.single.count, 3);
    });

    test('is rescued by its inline site, with no warning', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<divesites>
<site uuid='abc123' name='Blue Hole' gps='18.465562 -66.084902'/>
</divesites>
<dives>
<dive number='1' divesiteid='gone' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <location gps='12.216667 -68.283333'>Karpata</location>
  <divecomputer model='Test'><depth max='20.0 m' mean='15.0 m' /></divecomputer>
</dive>
</dives>
</divelog>
'''),
      );

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(
        siteRefOf(result.entitiesOf(ImportEntityType.dives).single),
        siteNamed(sites, 'Karpata')['uddfId'],
      );
      expect(result.warnings, isEmpty);
    });
  });

  group('a declared site whose uuid looks like a minted one', () {
    test('keeps its own id, and the inline site gets another', () async {
      // Nothing stops a Subsurface uuid from reading 'inline-site-1'. If the
      // minted id collided with it, the inline site would fold into a place
      // it has nothing to do with and both dives would land on one site.
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<divesites>
<site uuid='inline-site-1' name='Blue Hole' gps='18.465562 -66.084902'/>
</divesites>
<dives>
<dive number='1' divesiteid='inline-site-1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'><depth max='20.0 m' mean='15.0 m' /></divecomputer>
</dive>
${legacyDive("<location gps='12.216667 -68.283333'>Karpata</location>", number: 2)}
</dives>
</divelog>
'''),
      );

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites.length, 2);
      expect(siteNamed(sites, 'Blue Hole')['uddfId'], 'inline-site-1');
      expect(siteNamed(sites, 'Karpata')['uddfId'], isNot('inline-site-1'));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(siteRefOf(dives[0]), 'inline-site-1');
      expect(siteRefOf(dives[1]), siteNamed(sites, 'Karpata')['uddfId']);
      expect(result.warnings, isEmpty);
    });
  });

  group('a tag that names a kind of place', () {
    test('suggests a site type for an inline site too (#2205)', () async {
      // The tag-derived suggestion is keyed on the dive's resolved site id,
      // so it has to reach a site synthesised from a legacy <location> the
      // same way it reaches one declared in <divesites>.
      final result = await parser.parse(
        xmlBytes(
          legacyDivelog('''
<dive number='1' date='2011-06-18' time='09:11:00' duration='47:30 min' tags='cave, deep'>
  <location gps='30.101000 -85.201000'>Vortex Spring</location>
  <divecomputer model='Suunto Vyper'>
  <depth max='28.3 m' mean='16.7 m' />
  </divecomputer>
</dive>
'''),
        ),
      );

      final site = result.entitiesOf(ImportEntityType.sites).single;
      expect(site['name'], 'Vortex Spring');
      expect(site['suggestedSiteTypeRefs'], ['cave']);
    });
  });

  group('a real pre-4.5 Subsurface export', () {
    test('brings across every site the file carries', () async {
      final bytes = await File(legacyFixturePath).readAsBytes();
      final result = await parser.parse(bytes);

      final sites = result.entitiesOf(ImportEntityType.sites);
      // Karpata twice over, 1000 Steps, Salt Pier, and the unnamed fix.
      expect(sites.length, 4);
      expect(
        sites.map((s) => s['name']),
        containsAll(<String>['Karpata', '1000 Steps', 'Salt Pier']),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.length, 6);
      final karpata = siteNamed(sites, 'Karpata')['uddfId'];
      expect(siteRefOf(dives[0]), karpata);
      expect(siteRefOf(dives[1]), karpata);
      expect(siteRefOf(dives[2]), siteNamed(sites, '1000 Steps')['uddfId']);
      expect(siteRefOf(dives[3]), siteNamed(sites, 'Salt Pier')['uddfId']);
      expect(siteRefOf(dives[4]), isNotNull);
      // The last dive names no place, so it has no site and nothing is lost.
      expect(siteRefOf(dives[5]), isNull);
      expect(result.warnings, isEmpty);
    });

    test('keeps the trip location off the site list', () async {
      // `<trip location='Bonaire'>` names a region, not a dive site.
      final bytes = await File(legacyFixturePath).readAsBytes();
      final result = await parser.parse(bytes);

      expect(
        result.entitiesOf(ImportEntityType.sites).map((s) => s['name']),
        isNot(contains('Bonaire')),
      );
    });
  });
}

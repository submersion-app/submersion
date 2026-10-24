import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface/subsurface_declared_site.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';
import 'package:xml/xml.dart';

/// A `<site>` in a `<divesites>` block (#3110).
///
/// Subsurface writes a site's fields as attributes, but its reader takes a
/// child element of the same name just as well, and DiveMate's "Subsurface
/// XML" export writes them that way. Read as attributes only, every DiveMate
/// site came in unnamed and without a country, and the fold then dropped all
/// of them that had no coordinates: 102 of 105 in a donated logbook.
void main() {
  XmlElement site(String xml) => XmlDocument.parse(xml).rootElement;

  group('parseDeclaredSubsurfaceSite', () {
    test('reads the attributes Subsurface writes', () {
      final parsed = parseDeclaredSubsurfaceSite(
        site(
          "<site uuid=' 3029fde' name='Xwejni Bay' "
          "gps='36.078791 14.247781' description='Salt pans'>"
          "<geo cat='2' origin='2' value='Malta'/>"
          "<geo cat='3' origin='2' value='Gozo'/>"
          '<notes>Shore entry</notes>'
          '</site>',
        ),
      );

      expect(parsed, {
        'name': 'Xwejni Bay',
        'uddfId': '3029fde',
        'latitude': 36.078791,
        'longitude': 14.247781,
        'description': 'Salt pans',
        'country': 'Malta',
        'region': 'Gozo',
        'notes': 'Shore entry',
      });
    });

    test('reads the same fields written as child elements', () {
      final parsed = parseDeclaredSubsurfaceSite(
        site(
          "<site uuid=' 7b0e53b'>"
          '<name><![CDATA[Sorpetalsperre Wintertauchplatz]]></name>'
          '<gps>51.2516 7.9530</gps>'
          '<description><![CDATA[Winter entry]]></description>'
          "<geo cat='2' origin='2'><value><![CDATA[Deutschland]]></value></geo>"
          "<geo cat='3' origin='2'><value>Nordrhein-Westfalen</value></geo>"
          '</site>',
        ),
      );

      expect(parsed, {
        'name': 'Sorpetalsperre Wintertauchplatz',
        'uddfId': '7b0e53b',
        'latitude': 51.2516,
        'longitude': 7.953,
        'description': 'Winter entry',
        'country': 'Deutschland',
        'region': 'Nordrhein-Westfalen',
      });
    });

    test('an attribute wins over a child element of the same name', () {
      final parsed = parseDeclaredSubsurfaceSite(
        site(
          "<site uuid='a1' name='Attribute name'>"
          '<name>Child name</name>'
          "<geo cat='2' value='Austria'><value>Italy</value></geo>"
          '</site>',
        ),
      );

      expect(parsed['name'], 'Attribute name');
      expect(parsed['country'], 'Austria');
    });

    test('leaves out blank values', () {
      final parsed = parseDeclaredSubsurfaceSite(
        site(
          "<site uuid='a1' name=' '>"
          '<name><![CDATA[  ]]></name>'
          "<geo cat='2'><value><![CDATA[]]></value></geo>"
          '<notes> </notes>'
          '</site>',
        ),
      );

      expect(parsed, {'uddfId': 'a1'});
    });

    test('ignores geo categories other than country and region', () {
      // DiveMate writes the kind of water ("See", "Bad") as category 1,
      // Subsurface's ocean slot; it names no country or region.
      final parsed = parseDeclaredSubsurfaceSite(
        site(
          "<site uuid='a1' name='Pappelsee'>"
          "<geo cat='1' origin='2'><value>See</value></geo>"
          '</site>',
        ),
      );

      expect(parsed.containsKey('country'), isFalse);
      expect(parsed.containsKey('region'), isFalse);
    });
  });

  group('SubsurfaceXmlParser with DiveMate child-element sites', () {
    // Trimmed from a DiveMate "Subsurface XML" export: sites carry no name
    // attribute and no coordinates, only child elements.
    const diveMateXml = '''
<divelog program='subsurface' version='3'>
<settings>
</settings>
<divesites>
<site uuid='7dd52921'>
  <name><![CDATA[Panoramabad Pappelsee]]></name>
  <geo cat='2' origin='2'>
    <value><![CDATA[Deutschland]]></value>
  </geo>
  <geo cat='1' origin='2'>
    <value><![CDATA[Bad]]></value>
  </geo>
</site>
<site uuid=' 7b0e53b'>
  <name><![CDATA[Attersee]]></name>
  <geo cat='2' origin='2'>
    <value><![CDATA[Österreich]]></value>
  </geo>
</site>
</divesites>
<dives>
<dive number='2' rating='4' divesiteid=' 7b0e53b' date='2026-02-28' time='11:19:00' duration='41:00 min'>
  <depth max='18.000 m' mean='9.000 m' />
</dive>
<dive number='1' rating='3' divesiteid='7dd52921' date='2026-02-21' time='10:00:00' duration='35:00 min'>
  <depth max='6.000 m' mean='4.000 m' />
</dive>
</dives>
</divelog>
''';

    test('keeps every site, named and in its own country', () async {
      final payload = await SubsurfaceXmlParser().parse(
        Uint8List.fromList(utf8.encode(diveMateXml)),
      );

      final sites = payload.entities[ImportEntityType.sites]!;
      expect(
        {for (final s in sites) s['name']: s['country']},
        {'Panoramabad Pappelsee': 'Deutschland', 'Attersee': 'Österreich'},
      );
    });

    test('links each dive to its site with no missing-site warning', () async {
      final payload = await SubsurfaceXmlParser().parse(
        Uint8List.fromList(utf8.encode(diveMateXml)),
      );

      final sites = payload.entities[ImportEntityType.sites]!;
      final nameById = {for (final s in sites) s['uddfId']: s['name']};
      final dives = payload.entities[ImportEntityType.dives]!;
      expect(
        {
          for (final d in dives)
            d['diveNumber']: nameById[(d['site'] as Map?)?['uddfId']],
        },
        {1: 'Panoramabad Pappelsee', 2: 'Attersee'},
      );
      expect(payload.warnings, isEmpty);
    });
  });
}

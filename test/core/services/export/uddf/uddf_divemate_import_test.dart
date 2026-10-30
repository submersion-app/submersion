import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/dialects/divemate_dialect.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_normalizer.dart';
import 'package:xml/xml.dart';

// Trimmed from a donated DiveMate 5 UDDF export (#3110): no namespace, the
// literal text "null" for every empty field, and the site country nested at
// geography/address/country.
const _diveMateUddf = '''<?xml version="1.0" encoding="UTF-8"?>
<uddf version="3.2.0">
<generator>
  <name>DiveMate</name>
  <type>Android smartphone and tablet app</type>
</generator>
<diver>
  <owner>
    <personal>
      <firstname>Test</firstname>
      <lastname>Diver</lastname>
    </personal>
    <equipment>
      <tank id="29">
        <name>12er Faber</name>
        <serialnumber>null</serialnumber>
      </tank>
    </equipment>
  </owner>
  <buddy>
    <personal>
      <firstname>Christof</firstname>
      <lastname>Bednarski</lastname>
    </personal>
    <contact>
      <phone>null</phone>
      <email>null</email>
    </contact>
  </buddy>
</diver>
<divesite>
  <site id="site_4">
    <name>Panoramabad Pappelsee</name>
    <geography>
      <address>
        <country>Deutschland</country>
      </address>
      <location>Panoramabad Pappelsee</location>
    </geography>
  </site>
</divesite>
<gasdefinitions>
  <mix id="air">
    <name>Air</name>
    <o2>0.21</o2>
    <n2>0.79</n2>
    <he>0.0</he>
  </mix>
</gasdefinitions>
<profiledata>
  <repetitiongroup id="1">
    <dive id="dive_862">
      <informationbeforedive>
        <link ref="site_4"/>
        <divenumber>541</divenumber>
        <datetime>2025-03-17T10:05</datetime>
      </informationbeforedive>
      <informationafterdive>
        <greatestdepth>23.00</greatestdepth>
        <diveduration>3730</diveduration>
        <notes>
          <para>null</para>
        </notes>
      </informationafterdive>
      <tankdata id="1">
        <link ref="air"/>
      </tankdata>
      <samples>
      </samples>
    </dive>
    <dive id="dive_863">
      <informationbeforedive>
        <link ref="site_4"/>
        <divenumber>542</divenumber>
        <datetime>2025-03-18T10:05</datetime>
      </informationbeforedive>
      <informationafterdive>
        <greatestdepth>12.00</greatestdepth>
        <diveduration>2400</diveduration>
        <notes>
          <para>Null zone at the drop-off</para>
        </notes>
      </informationafterdive>
      <samples>
      </samples>
    </dive>
  </repetitiongroup>
</profiledata>
</uddf>
''';

void main() {
  final dialect = DiveMateDialect();

  group('DiveMateDialect.isMatch', () {
    test('matches a file whose generator is DiveMate', () {
      expect(dialect.isMatch(XmlDocument.parse(_diveMateUddf)), isTrue);
    });

    test('does not match another generator', () {
      final other = _diveMateUddf.replaceFirst(
        '<name>DiveMate</name>',
        '<name>Subsurface</name>',
      );
      expect(dialect.isMatch(XmlDocument.parse(other)), isFalse);
    });

    test('does not match a file with no generator', () {
      const bare = '<uddf version="3.2.0"><profiledata/></uddf>';
      expect(dialect.isMatch(XmlDocument.parse(bare)), isFalse);
    });
  });

  group('DiveMateDialect.normalizeXml', () {
    late XmlDocument normalized;
    setUp(() {
      normalized = XmlDocument.parse(dialect.normalizeXml(_diveMateUddf));
    });

    test('removes every element whose whole text is "null"', () {
      for (final tag in ['serialnumber', 'phone', 'email']) {
        expect(normalized.findAllElements(tag), isEmpty, reason: tag);
      }
      // The dive without notes keeps its empty <notes>, minus the <para>.
      expect(normalized.findAllElements('notes'), hasLength(2));
      expect(normalized.findAllElements('para'), hasLength(1));
    });

    test('keeps the elements around a removed value', () {
      expect(
        normalized.findAllElements('tank').single.innerText,
        contains('12er Faber'),
      );
      expect(normalized.findAllElements('contact'), hasLength(1));
    });

    test('matches a versioned generator name', () {
      final versioned = _diveMateUddf.replaceFirst(
        '<name>DiveMate</name>',
        '<name>DiveMate 5.1</name>',
      );
      expect(dialect.isMatch(XmlDocument.parse(versioned)), isTrue);
    });

    test('keeps text that only contains the word', () {
      expect(normalized.findAllElements('para').map((e) => e.innerText), [
        'Null zone at the drop-off',
      ]);
    });

    test('copies the nested site country onto the site', () {
      final site = normalized.findAllElements('site').single;
      final direct = site.childElements.where((e) => e.localName == 'country');
      expect(direct.map((e) => e.innerText), ['Deutschland']);
    });
  });

  group('UddfNormalizer', () {
    test('applies the DiveMate dialect', () {
      expect(UddfNormalizer.normalize(_diveMateUddf), isNot(_diveMateUddf));
    });
  });

  group('UddfFullImportService, DiveMate export', () {
    test('a dive DiveMate left without notes imports without notes', () async {
      final result = await UddfFullImportService().importAllDataFromUddf(
        _diveMateUddf,
      );

      final notesByNumber = {
        for (final d in result.dives) d['diveNumber']: d['notes'],
      };
      expect(notesByNumber, {541: null, 542: 'Null zone at the drop-off'});
    });

    test('a site keeps the country DiveMate nested under geography', () async {
      final result = await UddfFullImportService().importAllDataFromUddf(
        _diveMateUddf,
      );

      expect(result.sites.single['country'], 'Deutschland');
    });

    test('no imported value is the text "null"', () async {
      final result = await UddfFullImportService().importAllDataFromUddf(
        _diveMateUddf,
      );

      final found = <String>[];
      void walk(String path, Object? value) {
        if (value is Map) {
          value.forEach((k, v) => walk('$path.$k', v));
        } else if (value is List) {
          for (final v in value) {
            walk('$path[]', v);
          }
        } else if (value is String && value.trim() == 'null') {
          found.add(path);
        }
      }

      walk('dives', result.dives);
      walk('sites', result.sites);
      walk('equipment', result.equipment);
      walk('buddies', result.buddies);
      walk('owner', result.owner);
      expect(found, isEmpty);
    });
  });
}

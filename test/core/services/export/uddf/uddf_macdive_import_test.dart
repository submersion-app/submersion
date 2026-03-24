import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/dialects/macdive_dialect.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_normalizer.dart';
import 'package:xml/xml.dart';

// Minimal but complete MacDive-style UDDF with:
//   - default xmlns namespace on root element
//   - site country nested inside geography/address/country
//   - equipmentused inside informationafterdive
//   - dive profile waypoints in samples
const _macDiveUddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <diver>
    <owner id="owner-1">
      <personal>
        <firstname>Test</firstname>
        <lastname>Diver</lastname>
      </personal>
      <equipment>
        <divecomputer id="dc-1">
          <name>Shearwater Perdix</name>
          <model>Perdix</model>
          <serialnumber>2013766D</serialnumber>
        </divecomputer>
      </equipment>
    </owner>
    <buddy id="buddy-1">
      <personal>
        <firstname>Henrik</firstname>
        <lastname>Penrik</lastname>
      </personal>
    </buddy>
  </diver>
  <divesite>
    <site id="site-1">
      <name>Engnesbukta</name>
      <geography>
        <address>
          <country>Norway</country>
        </address>
        <location>Oslofjord</location>
        <latitude>59.69991</latitude>
        <longitude>10.53924</longitude>
      </geography>
    </site>
  </divesite>
  <gasdefinitions>
    <mix id="mix-1">
      <name>EAN30</name>
      <o2>0.30</o2>
      <n2>0.70</n2>
      <he>0.00</he>
    </mix>
  </gasdefinitions>
  <profiledata>
    <repetitiongroup id="repgrp-1">
      <dive id="dive-1">
        <informationbeforedive>
          <link ref="site-1" />
          <link ref="buddy-1" />
          <datetime>2024-03-10T11:22:37</datetime>
          <divenumber>102</divenumber>
          <surfaceintervalbeforedive>
            <passedtime>3600.00</passedtime>
          </surfaceintervalbeforedive>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>22.50</greatestdepth>
          <diveduration>3494.00</diveduration>
          <lowesttemperature>275.15</lowesttemperature>
          <notes>
            <para><![CDATA[Test dive notes for MacDive]]></para>
          </notes>
          <equipmentused>
            <leadquantity>3.0</leadquantity>
          </equipmentused>
        </informationafterdive>
        <tankdata>
          <link ref="mix-1" />
          <tankvolume>0.012</tankvolume>
          <tankpressurebegin>20000000</tankpressurebegin>
          <tankpressureend>5000000</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <divetime>0.00</divetime>
            <depth>0.0</depth>
            <temperature>276.15</temperature>
          </waypoint>
          <waypoint>
            <divetime>60.00</divetime>
            <depth>5.2</depth>
            <temperature>275.65</temperature>
          </waypoint>
          <waypoint>
            <divetime>120.00</divetime>
            <depth>10.8</depth>
          </waypoint>
          <waypoint>
            <divetime>180.00</divetime>
            <depth>22.50</depth>
          </waypoint>
          <waypoint>
            <divetime>3494.00</divetime>
            <depth>0.0</depth>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

// Same structure without the namespace declaration.
const _standardUddf = '''<uddf version="3.2.1">
  <profiledata>
    <repetitiongroup id="rg-1">
      <dive id="d-1">
        <informationbeforedive>
          <datetime>2024-01-01T10:00:00</datetime>
          <divenumber>1</divenumber>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>30.0</greatestdepth>
          <diveduration>1800</diveduration>
        </informationafterdive>
        <samples>
          <waypoint>
            <divetime>0</divetime>
            <depth>0.0</depth>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

// Submersion-style export: same UDDF 3.2 namespace but with a Submersion
// generator tag and standard element structure (no MacDive quirks).
const _submersionUddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.0">
  <generator><name>Submersion</name><version>1.0.0</version></generator>
  <diver>
    <owner id="owner-1">
      <personal><firstname>Test</firstname><lastname>User</lastname></personal>
    </owner>
  </diver>
  <divesite>
    <site id="s1">
      <name>Test Site</name>
      <country>US</country>
    </site>
  </divesite>
  <profiledata>
    <repetitiongroup id="rg-1">
      <dive id="d-1">
        <informationbeforedive>
          <link ref="s1" />
          <datetime>2024-06-01T09:00:00</datetime>
          <equipmentused><leadquantity>2.0</leadquantity></equipmentused>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>18.0</greatestdepth>
          <diveduration>2400</diveduration>
        </informationafterdive>
        <samples>
          <waypoint><divetime>0</divetime><depth>0.0</depth></waypoint>
          <waypoint><divetime>60</divetime><depth>10.0</depth></waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

// MacDive-style UDDF without <informationbeforedive>, where equipmentused
// is only in <informationafterdive>.
const _macDiveNoBeforeInfo = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <diver>
    <owner id="owner-1">
      <personal><firstname>Test</firstname></personal>
    </owner>
  </diver>
  <profiledata>
    <repetitiongroup id="rg-1">
      <dive id="d-1">
        <informationafterdive>
          <greatestdepth>15.0</greatestdepth>
          <diveduration>1800.00</diveduration>
          <equipmentused><leadquantity>4.0</leadquantity></equipmentused>
        </informationafterdive>
        <samples>
          <waypoint><divetime>0.00</divetime><depth>0.0</depth></waypoint>
          <waypoint><divetime>60.00</divetime><depth>10.0</depth></waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

void main() {
  group('MacDiveDialect', () {
    group('isMatch', () {
      test('returns true for UDDF with MacDive structural quirks', () {
        final doc = XmlDocument.parse(_macDiveUddf);
        expect(MacDiveDialect().isMatch(doc), isTrue);
      });

      test('returns true when generator tag says MacDive', () {
        const uddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <generator><name>MacDive</name><version>2.8.1</version></generator>
  <profiledata>
    <repetitiongroup id="rg-1">
      <dive id="d-1">
        <informationbeforedive><datetime>2024-01-01T10:00:00</datetime></informationbeforedive>
        <informationafterdive><greatestdepth>20.0</greatestdepth></informationafterdive>
        <samples><waypoint><divetime>0</divetime><depth>0.0</depth></waypoint></samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';
        final doc = XmlDocument.parse(uddf);
        expect(MacDiveDialect().isMatch(doc), isTrue);
      });

      test('returns false for UDDF without namespace', () {
        final doc = XmlDocument.parse(_standardUddf);
        expect(MacDiveDialect().isMatch(doc), isFalse);
      });

      test('returns false for Submersion export with same namespace', () {
        final doc = XmlDocument.parse(_submersionUddf);
        expect(MacDiveDialect().isMatch(doc), isFalse);
      });

      test('returns false for other app with same namespace and generator', () {
        const uddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.0">
  <generator><name>Subsurface Divelog</name><version>3</version></generator>
  <profiledata>
    <repetitiongroup id="rg-1">
      <dive id="d-1">
        <informationbeforedive><datetime>2024-01-01T10:00:00</datetime></informationbeforedive>
        <informationafterdive><greatestdepth>20.0</greatestdepth></informationafterdive>
        <samples><waypoint><divetime>0</divetime><depth>0.0</depth></waypoint></samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';
        final doc = XmlDocument.parse(uddf);
        expect(MacDiveDialect().isMatch(doc), isFalse);
      });
    });

    group('normalizeXml - encoding', () {
      test(
        'removes default namespace so elements are in the empty namespace',
        () {
          final result = MacDiveDialect().normalizeXml(_macDiveUddf);
          final normalized = XmlDocument.parse(result);
          // After stripping, all findElements() calls must work without namespace
          expect(
            normalized.rootElement.findElements('divesite').firstOrNull,
            isNotNull,
          );
          expect(
            normalized.rootElement.findElements('profiledata').firstOrNull,
            isNotNull,
          );
        },
      );

      test('root element local name remains uddf', () {
        final result = MacDiveDialect().normalizeXml(_macDiveUddf);
        final normalized = XmlDocument.parse(result);
        expect(normalized.rootElement.name.local, 'uddf');
      });

      test('normalises float-encoded integer fields to plain integers', () {
        final result = MacDiveDialect().normalizeXml(_macDiveUddf);
        expect(result, contains('<divetime>0</divetime>'));
        expect(result, contains('<divetime>60</divetime>'));
        expect(result, contains('<diveduration>3494</diveduration>'));
        expect(result, contains('<passedtime>3600</passedtime>'));
      });
    });

    group('normalizeXml - country fix', () {
      test('adds country as direct child of site element', () {
        final result = MacDiveDialect().normalizeXml(_macDiveUddf);
        final normalized = XmlDocument.parse(result);

        final site = normalized.findAllElements('site').firstOrNull;
        expect(site, isNotNull);
        // Direct <country> child under <site>
        final country = site!.findElements('country').firstOrNull;
        expect(country, isNotNull);
        expect(country!.innerText, 'Norway');
      });

      test('does not duplicate country when already a direct child', () {
        final result = MacDiveDialect().normalizeXml(_macDiveUddf);
        // Normalize a second time to verify idempotency.
        final secondPass = MacDiveDialect().normalizeXml(result);
        final normalized = XmlDocument.parse(secondPass);

        final site = normalized.findAllElements('site').firstOrNull;
        expect(site, isNotNull);
        final directCountries = site!.children
            .whereType<XmlElement>()
            .where((child) => child.name.local == 'country')
            .length;
        expect(directCountries, 1, reason: 'normalization must be idempotent');
      });

      test('preserves original geography/address/country structure', () {
        final result = MacDiveDialect().normalizeXml(_macDiveUddf);
        final normalized = XmlDocument.parse(result);

        final geo = normalized.findAllElements('geography').firstOrNull;
        expect(geo, isNotNull);
        final address = geo!.findElements('address').firstOrNull;
        expect(address, isNotNull);
        expect(
          address!.findElements('country').firstOrNull?.innerText,
          'Norway',
        );
      });
    });

    group('normalizeXml - equipmentused move', () {
      test(
        'copies equipmentused from informationafterdive to informationbeforedive',
        () {
          final result = MacDiveDialect().normalizeXml(_macDiveUddf);
          final normalized = XmlDocument.parse(result);

          final dive = normalized.findAllElements('dive').firstOrNull;
          expect(dive, isNotNull);

          final before = dive!
              .findElements('informationbeforedive')
              .firstOrNull;
          expect(
            before?.findElements('equipmentused').firstOrNull,
            isNotNull,
            reason: 'equipmentused must be present in informationbeforedive',
          );
        },
      );

      test('equipmentused content is preserved after move', () {
        final result = MacDiveDialect().normalizeXml(_macDiveUddf);
        final normalized = XmlDocument.parse(result);

        final dive = normalized.findAllElements('dive').firstOrNull;
        final before = dive!.findElements('informationbeforedive').firstOrNull;
        final equip = before!.findElements('equipmentused').firstOrNull;
        expect(
          equip?.findElements('leadquantity').firstOrNull?.innerText,
          '3.0',
        );
      });

      test('creates informationbeforedive when absent', () {
        final result = MacDiveDialect().normalizeXml(_macDiveNoBeforeInfo);
        final normalized = XmlDocument.parse(result);

        final dive = normalized.findAllElements('dive').firstOrNull;
        expect(dive, isNotNull);
        final before = dive!.findElements('informationbeforedive').firstOrNull;
        expect(
          before,
          isNotNull,
          reason: 'informationbeforedive should be created when absent',
        );
        final equip = before!.findElements('equipmentused').firstOrNull;
        expect(equip, isNotNull);
        expect(
          equip!.findElements('leadquantity').firstOrNull?.innerText,
          '4.0',
        );
      });

      test('does not duplicate equipmentused when already present', () {
        final result = MacDiveDialect().normalizeXml(_macDiveUddf);
        // Normalize a second time to verify idempotency.
        final secondPass = MacDiveDialect().normalizeXml(result);
        final normalized = XmlDocument.parse(secondPass);

        final dive = normalized.findAllElements('dive').firstOrNull;
        final before = dive!.findElements('informationbeforedive').firstOrNull;
        final equipCount = before!.findElements('equipmentused').length;
        expect(equipCount, 1, reason: 'normalization must be idempotent');
      });
    });
  });

  group('UddfDialect', () {
    test('default normalizeXml passes through content unchanged', () {
      // UddfNormalizer falls back unchanged when no dialect matches
      final result = UddfNormalizer.normalize(_standardUddf);
      expect(result, equals(_standardUddf));
    });

    test('non-MacDive content is not processed by MacDiveDialect', () {
      final doc = XmlDocument.parse(_standardUddf);
      expect(MacDiveDialect().isMatch(doc), isFalse);
    });
  });

  group('UddfNormalizer', () {
    test('normalizes MacDive content (returns different string)', () {
      final normalized = UddfNormalizer.normalize(_macDiveUddf);
      expect(normalized, isNot(equals(_macDiveUddf)));
    });

    test('passes through non-MacDive content unchanged', () {
      final result = UddfNormalizer.normalize(_standardUddf);
      expect(result, equals(_standardUddf));
    });

    test('passes through Submersion export unchanged', () {
      final result = UddfNormalizer.normalize(_submersionUddf);
      expect(result, equals(_submersionUddf));
    });
  });

  group('UddfFullImportService - MacDive import', () {
    late UddfFullImportService service;

    setUp(() {
      service = UddfFullImportService();
    });

    test('parses one dive from MacDive UDDF', () async {
      final result = await service.importAllDataFromUddf(_macDiveUddf);
      expect(result.dives, hasLength(1));
    });

    test('parses max depth', () async {
      final result = await service.importAllDataFromUddf(_macDiveUddf);
      final dive = result.dives.first;
      expect(dive['maxDepth'], closeTo(22.5, 0.01));
    });

    test('parses duration as runtime Duration', () async {
      final result = await service.importAllDataFromUddf(_macDiveUddf);
      final dive = result.dives.first;
      expect(dive['runtime'], equals(const Duration(seconds: 3494)));
    });

    test('parses water temperature from lowesttemperature in Kelvin', () async {
      // 275.15 K - 273.15 = 2.0 °C
      final result = await service.importAllDataFromUddf(_macDiveUddf);
      final dive = result.dives.first;
      expect(dive['waterTemp'], closeTo(2.0, 0.01));
    });

    test('parses notes from informationafterdive', () async {
      final result = await service.importAllDataFromUddf(_macDiveUddf);
      final dive = result.dives.first;
      expect(dive['notes'], 'Test dive notes for MacDive');
    });

    test('parses dive number', () async {
      final result = await service.importAllDataFromUddf(_macDiveUddf);
      final dive = result.dives.first;
      expect(dive['diveNumber'], 102);
    });

    test('parses dive date and time', () async {
      final result = await service.importAllDataFromUddf(_macDiveUddf);
      final dive = result.dives.first;
      expect(dive['dateTime'], DateTime.utc(2024, 3, 10, 11, 22, 37));
    });

    test('parses dive site name', () async {
      final result = await service.importAllDataFromUddf(_macDiveUddf);
      final dive = result.dives.first;
      final site = dive['site'] as Map<String, dynamic>?;
      expect(site, isNotNull);
      expect(site!['name'], 'Engnesbukta');
    });

    test(
      'parses dive site country via geography/address/country fix',
      () async {
        final result = await service.importAllDataFromUddf(_macDiveUddf);
        expect(result.sites, isNotEmpty);
        final site = result.sites.first;
        expect(site['country'], 'Norway');
      },
    );

    test('parses dive site coordinates', () async {
      final result = await service.importAllDataFromUddf(_macDiveUddf);
      final site = result.sites.first;
      expect(site['latitude'], closeTo(59.69991, 0.00001));
      expect(site['longitude'], closeTo(10.53924, 0.00001));
    });

    test('parses profile waypoints', () async {
      final result = await service.importAllDataFromUddf(_macDiveUddf);
      final dive = result.dives.first;
      final profile = dive['profile'] as List<Map<String, dynamic>>?;
      expect(profile, isNotNull);
      expect(profile!.length, greaterThanOrEqualTo(3));
    });

    test('profile points have timestamp and depth', () async {
      final result = await service.importAllDataFromUddf(_macDiveUddf);
      final dive = result.dives.first;
      final profile = dive['profile'] as List<Map<String, dynamic>>?;
      expect(profile, isNotNull);
      for (final point in profile!) {
        expect(point['timestamp'], isNotNull);
        expect(point['depth'], isNotNull);
      }
    });

    test('profile points include temperature where available', () async {
      final result = await service.importAllDataFromUddf(_macDiveUddf);
      final dive = result.dives.first;
      final profile = dive['profile'] as List<Map<String, dynamic>>?;
      expect(profile, isNotNull);
      // First waypoint has temperature 276.15 K = 3.0 °C
      final firstPoint = profile!.first;
      expect(firstPoint['temperature'], closeTo(3.0, 0.01));
    });

    test('parses surface interval from float-encoded passedtime', () async {
      final result = await service.importAllDataFromUddf(_macDiveUddf);
      final dive = result.dives.first;
      expect(dive['surfaceInterval'], equals(const Duration(hours: 1)));
    });

    test(
      'parses weight from equipmentused moved from informationafterdive',
      () async {
        final result = await service.importAllDataFromUddf(_macDiveUddf);
        final dive = result.dives.first;
        expect(dive['weightUsed'], closeTo(3.0, 0.01));
      },
    );

    test('parses gas mix from gasdefinitions', () async {
      final result = await service.importAllDataFromUddf(_macDiveUddf);
      final dive = result.dives.first;
      final tanks = dive['tanks'] as List<Map<String, dynamic>>?;
      // Either tanks list or loose gasMix field must have 30% O2
      if (tanks != null && tanks.isNotEmpty) {
        final gasMix = tanks.first['gasMix'];
        expect(gasMix, isNotNull);
      } else {
        // Gas mix comes from samples section when separate tanks absent
        final gasMix = dive['gasMix'];
        expect(gasMix, isNotNull);
      }
    });
  });
}

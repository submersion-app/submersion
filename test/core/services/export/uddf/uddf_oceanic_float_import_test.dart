import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/dialects/macdive_dialect.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:xml/xml.dart';

// Synthetic UDDF reproducing the serialization shape of Oceanic Plus
// (Oceanic's iPhone app, paired with an Apple Watch Ultra). Structure,
// element ordering and number formatting mirror a real export; site ids
// and coordinates are invented.
//
// The traits that matter:
//   - default xmlns namespace on the root element
//   - <generator> WITHOUT a <name> child, so no vendor fingerprint exists
//   - integer-semantics fields written as floats (<divetime>15.0</divetime>,
//     <diveduration>3492.0</diveduration>)
//   - <equipmentused> in <informationafterdive>, not <informationbeforedive>
//   - exponent-notation pressures (2.2E7)
const _oceanicUddf = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<uddf version="3.2.1" xmlns="http://www.streit.cc/uddf/3.2/">
    <generator>
        <manufacturer>
            <contact>
                <homepage>https://www.oceanicworldwide.com/it/oceanic-plus/</homepage>
            </contact>
        </manufacturer>
        <version>0.0.1</version>
        <datetime>2026-08-13T13:36:16.619Z</datetime>
    </generator>
    <divesite>
        <site id="site_aaa1">
            <name>site_aaa1</name>
            <geography>
                <location>site_aaa1</location>
                <latitude>12.345678</latitude>
                <longitude>-65.43210</longitude>
                <altitude>4.87455</altitude>
            </geography>
        </site>
    </divesite>
    <gasdefinitions>
        <mix id="air">
            <name>air</name>
            <o2>0.21</o2>
            <n2>0.79</n2>
            <he>0.0</he>
        </mix>
    </gasdefinitions>
    <profiledata>
        <repetitiongroup id="rg_1">
            <dive id="dive_aaa1">
                <informationbeforedive>
                    <link ref="site_aaa1"/>
                    <datetime>2026-08-10T20:10:29.000-00:05</datetime>
                    <altitude>4.87455</altitude>
                </informationbeforedive>
                <samples>
                    <waypoint>
                        <depth>0.0</depth>
                        <divetime>0.0</divetime>
                        <switchmix ref="air"/>
                        <divemode type="opencircuit"/>
                    </waypoint>
                    <waypoint>
                        <depth>0.1</depth>
                        <divetime>15.0</divetime>
                        <temperature>303.04</temperature>
                    </waypoint>
                    <waypoint>
                        <depth>5.7</depth>
                        <divetime>30.0</divetime>
                        <temperature>302.99</temperature>
                    </waypoint>
                    <waypoint>
                        <depth>12.3</depth>
                        <divetime>45.0</divetime>
                    </waypoint>
                    <waypoint>
                        <depth>0.0</depth>
                        <divetime>3492.0</divetime>
                    </waypoint>
                </samples>
                <tankdata id="tank_aaa1">
                    <link ref="air"/>
                    <tankpressurebegin>2.2E7</tankpressurebegin>
                    <tankpressureend>6500000.0</tankpressureend>
                </tankdata>
                <informationafterdive>
                    <lowesttemperature>302.94</lowesttemperature>
                    <greatestdepth>18.335197</greatestdepth>
                    <notes>
                        <para>Night shore dive</para>
                    </notes>
                    <diveduration>3492.0</diveduration>
                    <equipmentused>
                        <leadquantity>12.0</leadquantity>
                        <link ref="tank_aaa1"/>
                    </equipmentused>
                </informationafterdive>
            </dive>
        </repetitiongroup>
    </profiledata>
</uddf>''';

// Same file with <equipmentused> in BOTH halves of the dive, to pin down
// which one wins.
const _weightInBothHalves =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<uddf version="3.2.1" xmlns="http://www.streit.cc/uddf/3.2/">
    <profiledata>
        <repetitiongroup id="rg_1">
            <dive id="dive_bbb1">
                <informationbeforedive>
                    <datetime>2026-08-10T20:10:29</datetime>
                    <equipmentused>
                        <leadquantity>6.0</leadquantity>
                    </equipmentused>
                </informationbeforedive>
                <samples>
                    <waypoint><depth>0.0</depth><divetime>0.0</divetime></waypoint>
                </samples>
                <informationafterdive>
                    <diveduration>1200.0</diveduration>
                    <equipmentused>
                        <leadquantity>12.0</leadquantity>
                    </equipmentused>
                </informationafterdive>
            </dive>
        </repetitiongroup>
    </profiledata>
</uddf>''';

void main() {
  final service = UddfFullImportService();

  group('Oceanic Plus float-formatted UDDF', () {
    test('waypoint timestamps advance instead of collapsing to zero', () async {
      // The reported symptom: int.tryParse("15.0") returns null, so every
      // waypoint fell through to the `?? 0` default and the depth/time
      // graph drew all samples stacked at t=0.
      final result = await service.importAllDataFromUddf(_oceanicUddf);
      final dive = result.dives.single;
      final profile = dive['profile'] as List<Map<String, dynamic>>?;

      expect(profile, isNotNull);
      expect(profile!.length, 5);
      expect(profile.map((p) => p['timestamp']).toList(), [
        0,
        15,
        30,
        45,
        3492,
      ]);
    });

    test('waypoint depths still parse alongside the timestamps', () async {
      final result = await service.importAllDataFromUddf(_oceanicUddf);
      final profile =
          result.dives.single['profile'] as List<Map<String, dynamic>>;

      expect(profile[1]['depth'], closeTo(0.1, 0.001));
      expect(profile[3]['depth'], closeTo(12.3, 0.001));
    });

    test('float diveduration is parsed as runtime', () async {
      // Second data loss in the same file: diveduration has no `?? 0`
      // fallback, so a float value dropped runtime entirely.
      final result = await service.importAllDataFromUddf(_oceanicUddf);

      expect(
        result.dives.single['runtime'],
        equals(const Duration(seconds: 3492)),
      );
    });

    test('lead weight is read from informationafterdive', () async {
      // Third loss: leadquantity was only ever read from
      // informationbeforedive, where Oceanic does not put it.
      final result = await service.importAllDataFromUddf(_oceanicUddf);

      expect(result.dives.single['weightUsed'], closeTo(12.0, 0.001));
    });

    test(
      'informationbeforedive weight wins when both halves supply it',
      () async {
        final result = await service.importAllDataFromUddf(_weightInBothHalves);

        expect(result.dives.single['weightUsed'], closeTo(6.0, 0.001));
      },
    );

    test('greatestdepth and temperature are unaffected', () async {
      final result = await service.importAllDataFromUddf(_oceanicUddf);
      final dive = result.dives.single;

      expect(dive['maxDepth'], closeTo(18.335197, 0.0001));
      expect(dive['waterTemp'], closeTo(302.94 - 273.15, 0.01));
    });

    test('the site is imported with its coordinates', () async {
      final result = await service.importAllDataFromUddf(_oceanicUddf);

      expect(result.sites, hasLength(1));
      expect(result.sites.single['latitude'], closeTo(12.345678, 0.000001));
      expect(result.sites.single['longitude'], closeTo(-65.43210, 0.000001));
    });

    test('MacDiveDialect does not claim Oceanic exports', () async {
      // Oceanic shares the UDDF 3.2 namespace with MacDive AND nests
      // equipmentused in informationafterdive, which is one of the two
      // structural quirks MacDiveDialect fingerprints on. Only the presence
      // of a <generator> element keeps detection from misfiring, so this
      // guards a genuinely narrow margin.
      final doc = XmlDocument.parse(_oceanicUddf);

      expect(MacDiveDialect().isMatch(doc), isFalse);
    });
  });
}

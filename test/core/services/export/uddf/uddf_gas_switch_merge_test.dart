// Regression test: a UDDF file can mark gas switches both as waypoint-level
// <switchmix> elements and in a top-level <gasswitches> block (Submersion's
// own exports write both). The two sources must merge — the top-level block
// must not overwrite waypoint-derived switches it does not contain.
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';

const _uddf = '''
<?xml version="1.0" encoding="UTF-8"?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.0">
  <gasdefinitions>
    <mix id="mix1"><name>Air</name><o2>0.21</o2><he>0.0</he></mix>
    <mix id="mix2"><name>EAN50</name><o2>0.50</o2><he>0.0</he></mix>
  </gasdefinitions>
  <profiledata>
    <repetitiongroup>
      <dive id="dive1">
        <informationbeforedive>
          <datetime>2026-01-01T10:00:00</datetime>
        </informationbeforedive>
        <tankdata id="T1">
          <link ref="mix1" />
          <tankvolume>12</tankvolume>
        </tankdata>
        <tankdata id="T2">
          <link ref="mix2" />
          <tankvolume>7</tankvolume>
        </tankdata>
        <samples>
          <waypoint><depth>0.0</depth><divetime>0</divetime><switchmix ref="mix1" /></waypoint>
          <waypoint><depth>20.0</depth><divetime>600</divetime></waypoint>
          <waypoint><depth>15.0</depth><divetime>1200</divetime><switchmix ref="mix2" /></waypoint>
          <waypoint><depth>0.0</depth><divetime>1800</divetime></waypoint>
        </samples>
        <informationafterdive>
          <greatestdepth>20.0</greatestdepth>
          <diveduration>1800</diveduration>
          <gasswitches>
            <gasswitch><time>1200</time><depth>15.0</depth><tankref>T2</tankref></gasswitch>
          </gasswitches>
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

void main() {
  group('UDDF gas switch source merging', () {
    late Map<String, dynamic> dive;

    setUpAll(() async {
      final result = await UddfFullImportService().importAllDataFromUddf(_uddf);
      expect(result.dives, hasLength(1));
      dive = result.dives.first;
    });

    test('keeps waypoint switchmix entries missing from <gasswitches>', () {
      final switches = dive['gasSwitches'] as List<Map<String, dynamic>>;
      expect(
        switches.map((gs) => gs['timestamp']).toSet(),
        {0, 1200},
        reason:
            'the t=0 initial-mix switchmix only exists as a waypoint '
            'marker and must survive the top-level <gasswitches> parse',
      );
    });

    test('prefers the richer top-level entry for a shared timestamp', () {
      final switches = dive['gasSwitches'] as List<Map<String, dynamic>>;
      final at1200 = switches.where((gs) => gs['timestamp'] == 1200).toList();
      expect(at1200, hasLength(1), reason: 'no duplicate rows per timestamp');
      expect(at1200.single['tankRef'], 'T2');
    });
  });
}

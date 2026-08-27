// Edge cases for materializing waypoint <switchmix> mixes as tanks when
// <tankdata> carries no gas links: claiming existing mix-less tanks before
// appending, and skipping refs that resolve to no known mix.
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

const _uddf = '''
<?xml version="1.0" encoding="UTF-8"?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.0">
  <gasdefinitions>
    <mix id="mix1"><name>Tx18/45</name><o2>0.18</o2><he>0.45</he></mix>
    <mix id="mix2"><name>EAN50</name><o2>0.50</o2><he>0.0</he></mix>
  </gasdefinitions>
  <profiledata>
    <repetitiongroup>
      <dive id="dive1">
        <informationbeforedive>
          <datetime>2026-01-01T10:00:00</datetime>
        </informationbeforedive>
        <tankdata id="T1"><tankvolume>12</tankvolume></tankdata>
        <tankdata id="T2"><tankvolume>7</tankvolume></tankdata>
        <samples>
          <waypoint><depth>0.0</depth><divetime>0</divetime><switchmix ref="mix1" /></waypoint>
          <waypoint><depth>40.0</depth><divetime>600</divetime></waypoint>
          <waypoint><depth>21.0</depth><divetime>1200</divetime><switchmix ref="mix2" /></waypoint>
          <waypoint><depth>10.0</depth><divetime>1500</divetime><switchmix ref="ghost-mix" /></waypoint>
          <waypoint><depth>0.0</depth><divetime>1800</divetime></waypoint>
        </samples>
        <informationafterdive>
          <greatestdepth>40.0</greatestdepth>
          <diveduration>1800</diveduration>
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

void main() {
  group('switchmix tank materialization with linkless tankdata', () {
    late Map<String, dynamic> dive;

    setUpAll(() async {
      final result = await UddfFullImportService().importAllDataFromUddf(_uddf);
      expect(result.dives, hasLength(1));
      dive = result.dives.first;
    });

    test('claims existing mix-less tanks in switch order', () {
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(tanks, hasLength(2), reason: 'no extra tank may be appended');
      expect(tanks[0]['uddfTankId'], 'T1');
      expect(tanks[0]['gasMix'], const GasMix(o2: 18, he: 45));
      expect(tanks[0]['uddfGasMixRef'], 'mix1');
      expect(tanks[1]['uddfTankId'], 'T2');
      expect(tanks[1]['gasMix'], const GasMix(o2: 50, he: 0));
      expect(tanks[1]['uddfGasMixRef'], 'mix2');
    });

    test('a switchmix ref without a gas definition adds no tank', () {
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(
        tanks.map((t) => t['uddfGasMixRef']),
        isNot(contains('ghost-mix')),
      );
    });

    test('still emits all switchmix waypoints as gas switches', () {
      final switches = dive['gasSwitches'] as List<Map<String, dynamic>>;
      expect(switches.map((gs) => gs['timestamp']).toList(), [0, 1200, 1500]);
    });
  });
}

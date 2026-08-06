import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

const _uddfEan29 = '''<uddf version="3.2.1">
  <gasdefinitions>
    <mix id="mix(29/0)">
      <name>EANx 29</name>
      <o2>0.29</o2>
      <he>0.00</he>
    </mix>
  </gasdefinitions>
  <profiledata>
    <repetitiongroup id="id4">
      <dive id="id4">
        <informationbeforedive>
          <divenumber>107</divenumber>
          <datetime>2025-03-19T08:19:54</datetime>
          <equipmentused>
            <leadquantity>5</leadquantity>
          </equipmentused>
        </informationbeforedive>
        <tankdata>
          <link ref="mix(29/0)"/>
          <tankvolume>24.0</tankvolume>
          <tankpressurebegin>20500000</tankpressurebegin>
          <tankpressureend>11000000</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <depth>1.7</depth>
            <divetime>2</divetime>
            <switchmix ref="mix(29/0)"/>
            <temperature>290.15</temperature>
          </waypoint>
          <waypoint>
            <depth>2</depth>
            <divetime>4</divetime>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

void main() {
  group('UddfFullImportService', () {
    late UddfFullImportService service;

    setUp(() {
      service = UddfFullImportService();
    });

    test('keeps a 0.29 UDDF mix labeled as EAN29', () async {
      final result = await service.importAllDataFromUddf(_uddfEan29);
      final dive = result.dives.first;
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      final gasMix = tanks.first['gasMix'] as dynamic;

      expect(gasMix, isNotNull);
      expect(gasMix.o2, closeTo(29.0, 0.000001));
      expect(gasMix.name, 'EAN29');
    });

    test(
      'maps tankpressure refs by tank order when tankdata entries omit ids',
      () async {
        const uddfContent = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2025-09-01T14:18:24Z</datetime>
          <divenumber>235</divenumber>
        </informationbeforedive>
        <tankdata>
          <tankpressurebegin>20049962</tankpressurebegin>
          <tankpressureend>12879411</tankpressureend>
        </tankdata>
        <tankdata>
          <tankpressurebegin>21952916</tankpressurebegin>
          <tankpressureend>14244574</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <depth>1</depth>
            <divetime>0</divetime>
            <tankpressure ref="o2">20049962</tankpressure>
            <tankpressure ref="he">21952916</tankpressure>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

        final result = await service.importAllDataFromUddf(uddfContent);
        expect(result.dives, hasLength(1));

        final dive = result.dives.first;
        final tanks = dive['tanks'] as List<Map<String, dynamic>>;
        final profile = dive['profile'] as List<Map<String, dynamic>>;
        final firstPointPressures =
            profile.first['allTankPressures'] as List<Map<String, dynamic>>;

        expect(tanks, hasLength(2));
        expect(tanks[0]['uddfTankId'], isNull);
        expect(tanks[1]['uddfTankId'], isNull);

        expect(firstPointPressures, hasLength(2));
        expect(firstPointPressures[0]['tankIndex'], 0);
        expect(firstPointPressures[1]['tankIndex'], 1);
        expect(firstPointPressures[0]['pressure'], closeTo(200.5, 0.1));
        expect(firstPointPressures[1]['pressure'], closeTo(219.5, 0.1));
      },
    );

    test(
      'treats empty and whitespace tankdata ids as missing for fallback mapping',
      () async {
        const uddfContent = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2025-09-01T14:18:24Z</datetime>
          <divenumber>235</divenumber>
        </informationbeforedive>
        <tankdata id="">
          <tankpressurebegin>20049962</tankpressurebegin>
          <tankpressureend>12879411</tankpressureend>
        </tankdata>
        <tankdata id="   ">
          <tankpressurebegin>21952916</tankpressurebegin>
          <tankpressureend>14244574</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <depth>1</depth>
            <divetime>0</divetime>
            <tankpressure ref="T1">20049962</tankpressure>
            <tankpressure ref="T2">21952916</tankpressure>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

        final result = await service.importAllDataFromUddf(uddfContent);
        expect(result.dives, hasLength(1));

        final dive = result.dives.first;
        final tanks = dive['tanks'] as List<Map<String, dynamic>>;
        final profile = dive['profile'] as List<Map<String, dynamic>>;
        final firstPointPressures =
            profile.first['allTankPressures'] as List<Map<String, dynamic>>;

        expect(tanks, hasLength(2));
        expect(tanks[0]['uddfTankId'], isNull);
        expect(tanks[1]['uddfTankId'], isNull);
        expect(firstPointPressures, hasLength(2));
        expect(firstPointPressures[0]['tankIndex'], 0);
        expect(firstPointPressures[1]['tankIndex'], 1);
      },
    );

    test('drops extra unmatched refs beyond available tank records', () async {
      const uddfContent = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2025-09-01T14:18:24Z</datetime>
          <divenumber>235</divenumber>
        </informationbeforedive>
        <tankdata>
          <tankpressurebegin>20049962</tankpressurebegin>
          <tankpressureend>12879411</tankpressureend>
        </tankdata>
        <tankdata>
          <tankpressurebegin>21952916</tankpressurebegin>
          <tankpressureend>14244574</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <depth>1</depth>
            <divetime>0</divetime>
            <tankpressure ref="o2">20049962</tankpressure>
            <tankpressure ref="he">21952916</tankpressure>
            <tankpressure ref="argon">15000000</tankpressure>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

      final result = await service.importAllDataFromUddf(uddfContent);
      final dive = result.dives.first;
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      final firstPointPressures =
          profile.first['allTankPressures'] as List<Map<String, dynamic>>;

      expect(firstPointPressures, hasLength(2));
      expect(firstPointPressures[0]['tankIndex'], 0);
      expect(firstPointPressures[1]['tankIndex'], 1);
    });

    test(
      'keeps the Shearwater tank gas mix from gasdefinitions instead of defaulting to air',
      () async {
        const uddfContent = '''
<uddf version="3.2.3">
  <gasdefinitions>
    <mix id="OC1:30/00">
      <name>OC1</name>
      <o2>0.3</o2>
      <he>0</he>
      <maximumpo2>1</maximumpo2>
    </mix>
  </gasdefinitions>
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2025-12-30T14:18:24Z</datetime>
          <divenumber>267</divenumber>
        </informationbeforedive>
        <tankdata>
          <tankpressurebegin>20000000</tankpressurebegin>
          <tankpressureend>5000000</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <batterychargecondition>1.51</batterychargecondition>
            <calculatedpo2>0.359999985</calculatedpo2>
            <depth>2</depth>
            <divetime>0</divetime>
            <switchmix ref="OC1:30/00" />
            <temperature>298.15</temperature>
            <divemode type="opencircuit" />
            <gradientfactor>0</gradientfactor>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

        final service = UddfFullImportService();

        final result = await service.importAllDataFromUddf(uddfContent);
        expect(result.dives, hasLength(1));

        final dive = result.dives.first;
        final tanks = dive['tanks'] as List<Map<String, dynamic>>;
        final gasMix = tanks.first['gasMix'] as GasMix;

        expect(tanks, hasLength(1));
        expect(gasMix.isAir, isFalse);
        expect(gasMix.o2, closeTo(30.0, 0.001));
        expect(gasMix.he, closeTo(0.0, 0.001));
        expect(gasMix.name, 'EAN30');
      },
    );

    test(
      'applies switchmix to the tank referenced by the active pressure data',
      () async {
        const uddfContent = '''
<uddf version="3.2.3">
  <gasdefinitions>
    <mix id="backgas">
      <o2>0.21</o2>
      <he>0</he>
    </mix>
    <mix id="deco50">
      <o2>0.5</o2>
      <he>0</he>
    </mix>
  </gasdefinitions>
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2025-12-30T14:18:24Z</datetime>
          <divenumber>267</divenumber>
        </informationbeforedive>
        <tankdata id="back-tank">
          <tankpressurebegin>20000000</tankpressurebegin>
          <tankpressureend>12000000</tankpressureend>
        </tankdata>
        <tankdata id="deco-tank">
          <tankpressurebegin>18000000</tankpressurebegin>
          <tankpressureend>9000000</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <depth>6</depth>
            <divetime>1200</divetime>
            <switchmix ref="deco50" />
            <tankpressure ref="deco-tank">18000000</tankpressure>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

        final service = UddfFullImportService();

        final result = await service.importAllDataFromUddf(uddfContent);
        final dive = result.dives.first;
        final tanks = dive['tanks'] as List<Map<String, dynamic>>;

        expect(tanks, hasLength(2));
        expect(tanks[0]['gasMix'], isNull);

        final gasMix = tanks[1]['gasMix'] as GasMix;
        expect(gasMix.o2, closeTo(50.0, 0.001));
        expect(gasMix.he, closeTo(0.0, 0.001));
        expect(gasMix.name, 'EAN50');
      },
    );

    test(
      'parses waypoint cns, otu, ndl, and rbt with remainingbottomtime precedence',
      () async {
        const uddfContent = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2025-09-01T14:18:24Z</datetime>
          <divenumber>235</divenumber>
        </informationbeforedive>
        <samples>
          <waypoint>
            <depth>5</depth>
            <divetime>0</divetime>
            <cns>3.5</cns>
            <otu>1.5</otu>
            <nodecotime>900</nodecotime>
            <remainingbottomtime>1200</remainingbottomtime>
            <remainingo2time>1500</remainingo2time>
          </waypoint>
          <waypoint>
            <depth>10</depth>
            <divetime>60</divetime>
            <cns>8.0</cns>
            <otu>4.0</otu>
            <remainingo2time>600</remainingo2time>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

        final result = await service.importAllDataFromUddf(uddfContent);
        final dive = result.dives.first;
        final profile = dive['profile'] as List<Map<String, dynamic>>;

        expect(profile[0]['cns'], 3.5);
        expect(profile[0]['ndl'], 900);
        expect(profile[0]['rbt'], 1200);
        expect(profile[1]['rbt'], 600);
        expect(dive['cnsEnd'], 8.0);
        expect(dive['otu'], 4.0);
      },
    );

    test(
      'maps decostop kind to decoType and leaves missing decostop null',
      () async {
        const uddfContent = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2025-09-01T14:18:24Z</datetime>
          <divenumber>235</divenumber>
        </informationbeforedive>
        <samples>
          <waypoint>
            <depth>5</depth>
            <divetime>0</divetime>
          </waypoint>
          <waypoint>
            <depth>6</depth>
            <divetime>60</divetime>
            <decostop kind="safetystop" />
          </waypoint>
          <waypoint>
            <depth>9</depth>
            <divetime>120</divetime>
            <decostop kind="decostop" />
          </waypoint>
          <waypoint>
            <depth>12</depth>
            <divetime>180</divetime>
            <decostop kind="vendor-extension" />
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

        final result = await service.importAllDataFromUddf(uddfContent);
        final dive = result.dives.first;
        final profile = dive['profile'] as List<Map<String, dynamic>>;

        expect(profile[0]['decoType'], isNull);
        expect(profile[1]['decoType'], 1);
        expect(profile[2]['decoType'], 2);
        expect(profile[3]['decoType'], 2);
      },
    );

    test('maps decostop decodepth to the sample ceiling (meters) and leaves it '
        'null when there is no decostop', () async {
      const uddfContent = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2025-09-01T14:18:24Z</datetime>
          <divenumber>235</divenumber>
        </informationbeforedive>
        <samples>
          <waypoint>
            <depth>30</depth>
            <divetime>0</divetime>
          </waypoint>
          <waypoint>
            <depth>12</depth>
            <divetime>600</divetime>
            <decostop kind="mandatory" decodepth="12" duration="60" />
          </waypoint>
          <waypoint>
            <depth>9</depth>
            <divetime>720</divetime>
            <decostop kind="mandatory" decodepth="9" duration="120" />
          </waypoint>
          <waypoint>
            <depth>6</depth>
            <divetime>900</divetime>
            <decostop kind="safetystop" decodepth="6" duration="180" />
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

      final result = await service.importAllDataFromUddf(uddfContent);
      final dive = result.dives.first;
      final profile = dive['profile'] as List<Map<String, dynamic>>;

      // A waypoint with no decostop carries no ceiling.
      expect(profile[0]['ceiling'], isNull);
      // decodepth (UDDF is SI: metres) maps straight to the ceiling.
      expect(profile[1]['ceiling'], 12.0);
      expect(profile[2]['ceiling'], 9.0);
      // A safety stop still records its stop depth as the ceiling.
      expect(profile[3]['ceiling'], 6.0);
    });

    test('recognizes UDDF spec decostop kinds: mandatory -> deco, safety -> '
        'safety', () async {
      const uddfContent = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2025-09-01T14:18:24Z</datetime>
          <divenumber>235</divenumber>
        </informationbeforedive>
        <samples>
          <waypoint>
            <depth>12</depth>
            <divetime>60</divetime>
            <decostop kind="mandatory" decodepth="12" duration="60" />
          </waypoint>
          <waypoint>
            <depth>6</depth>
            <divetime>120</divetime>
            <decostop kind="safety" decodepth="6" duration="180" />
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

      final result = await service.importAllDataFromUddf(uddfContent);
      final dive = result.dives.first;
      final profile = dive['profile'] as List<Map<String, dynamic>>;

      // UDDF 3.2.x spec kinds are `mandatory` and `safety`; both must be
      // recognized (no "unsupported kind" warning spam) and mapped correctly.
      expect(profile[0]['decoType'], 2);
      expect(profile[1]['decoType'], 1);
    });

    group('oxygen sample data', () {
      Future<List<Map<String, dynamic>>> profileFrom(
        String samples, {
        String equipment = '',
      }) async {
        final uddfContent =
            '''
<uddf version="3.2.3">
  <diver>
    <owner>
      <equipment>$equipment</equipment>
    </owner>
  </diver>
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2026-08-01T09:08:48Z</datetime>
        </informationbeforedive>
        <samples>$samples</samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';
        final result = await service.importAllDataFromUddf(uddfContent);
        return result.dives.first['profile'] as List<Map<String, dynamic>>;
      }

      const rebreather = '''
        <rebreather id="rb-1">
          <o2sensor id="o2sensor_1"><name>Cell 1</name></o2sensor>
          <o2sensor id="o2sensor_2"><name>Cell 2</name></o2sensor>
          <o2sensor id="o2sensor_3"><name>Cell 3</name></o2sensor>
        </rebreather>''';

      test('imports calculatedpo2 as the sample ppO2', () async {
        // Shearwater Cloud exports the aggregated loop ppO2 as
        // <calculatedpo2>, in bar rather than the spec's Pascal.
        final profile = await profileFrom('''
          <waypoint>
            <depth>12.4</depth>
            <divetime>60</divetime>
            <calculatedpo2>0.849999964</calculatedpo2>
          </waypoint>''');

        expect(profile.single['ppO2'], closeTo(0.85, 0.001));
      });

      test('converts a Pascal calculatedpo2 to bar', () async {
        // UDDF 3.2.3 mandates Pascal: 1.27e5 Pa is 1.27 bar.
        final profile = await profileFrom('''
          <waypoint>
            <depth>12.4</depth>
            <divetime>60</divetime>
            <calculatedpo2>1.27e5</calculatedpo2>
          </waypoint>''');

        expect(profile.single['ppO2'], closeTo(1.27, 0.001));
      });

      test('imports setpo2 as the sample setpoint', () async {
        final profile = await profileFrom('''
          <waypoint>
            <depth>30</depth>
            <divetime>120</divetime>
            <setpo2>1.3e5</setpo2>
          </waypoint>''');

        expect(profile.single['setpoint'], closeTo(1.3, 0.001));
      });

      test('imports repeated measuredpo2 into per-cell readings', () async {
        // The spec form: one <measuredpo2> per cell, each referencing a
        // declared <o2sensor>. Cell order follows the declaration order,
        // not the order the readings appear in the waypoint.
        final profile = await profileFrom('''
          <waypoint>
            <depth>30</depth>
            <divetime>120</divetime>
            <measuredpo2 ref="o2sensor_2">1.23e5</measuredpo2>
            <measuredpo2 ref="o2sensor_1">1.22e5</measuredpo2>
            <measuredpo2 ref="o2sensor_3">1.21e5</measuredpo2>
          </waypoint>''', equipment: rebreather);

        final point = profile.single;
        expect(point['o2Sensor1'], closeTo(1.22, 0.001));
        expect(point['o2Sensor2'], closeTo(1.23, 0.001));
        expect(point['o2Sensor3'], closeTo(1.21, 0.001));
      });

      test('imports the draft 3.3.0 ppo2 cell form', () async {
        // AP Diving DiveSight emits the unpublished 3.3.0 <ppo2 ref=...>
        // rename of <measuredpo2>.
        final profile = await profileFrom('''
          <waypoint>
            <depth>30</depth>
            <divetime>120</divetime>
            <ppo2 ref="o2sensor_1">1.22e5</ppo2>
            <ppo2 ref="o2sensor_2">1.23e5</ppo2>
            <ppo2 ref="o2sensor_3">1.21e5</ppo2>
          </waypoint>''', equipment: rebreather);

        final point = profile.single;
        expect(point['o2Sensor1'], closeTo(1.22, 0.001));
        expect(point['o2Sensor2'], closeTo(1.23, 0.001));
        expect(point['o2Sensor3'], closeTo(1.21, 0.001));
      });

      test('falls back to waypoint order for unresolvable cell refs', () async {
        // No <o2sensor> declarations to resolve against: keep the readings
        // rather than dropping them, in document order.
        final profile = await profileFrom('''
          <waypoint>
            <depth>30</depth>
            <divetime>120</divetime>
            <measuredpo2 ref="cell_a">1.22e5</measuredpo2>
            <measuredpo2 ref="cell_b">1.23e5</measuredpo2>
          </waypoint>''');

        final point = profile.single;
        expect(point['o2Sensor1'], closeTo(1.22, 0.001));
        expect(point['o2Sensor2'], closeTo(1.23, 0.001));
      });

      test('treats a bare measuredpo2 as the aggregate ppO2', () async {
        // The spec makes `ref` mandatory, but an exporter that omits it is
        // reporting one loop value rather than a cell, so it belongs on ppO2
        // instead of being dropped.
        final profile = await profileFrom('''
          <waypoint>
            <depth>30</depth>
            <divetime>120</divetime>
            <measuredpo2>1.22e5</measuredpo2>
          </waypoint>''');

        final point = profile.single;
        expect(point['ppO2'], closeTo(1.22, 0.001));
        expect(point['o2Sensor1'], isNull);
      });

      test('still reads the names our own exporter writes', () async {
        // Submersion exports bare <setpoint>/<ppo2> in bar; re-importing our
        // own file has to keep working.
        final profile = await profileFrom('''
          <waypoint>
            <depth>30</depth>
            <divetime>120</divetime>
            <setpoint>1.3</setpoint>
            <ppo2>1.21</ppo2>
          </waypoint>''');

        final point = profile.single;
        expect(point['setpoint'], closeTo(1.3, 0.001));
        expect(point['ppO2'], closeTo(1.21, 0.001));
      });

      test('reads the dive mode from waypoint divemode types', () async {
        // Shearwater marks the circuit on the samples, as a `type` attribute
        // using UDDF's spelling. Without it the dive imports as open circuit,
        // and the analysis discards every loop ppO2 reading it just imported
        // in favour of a depth x FO2 curve off the diluent.
        const uddfContent = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2026-08-01T09:08:48Z</datetime>
        </informationbeforedive>
        <samples>
          <waypoint>
            <depth>30</depth>
            <divetime>120</divetime>
            <divemode type="closedcircuit" />
            <calculatedpo2>1.2</calculatedpo2>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';
        final result = await service.importAllDataFromUddf(uddfContent);

        expect(result.dives.first['diveMode'], DiveMode.ccr);
      });

      test('reads a dive-level divemode from its type attribute', () async {
        // UDDF's own form is an empty element carrying `type`, so a file can
        // state the circuit at dive level with no inner text at all.
        const uddfContent = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2026-08-01T09:08:48Z</datetime>
          <divemode type="closedcircuit" />
        </informationbeforedive>
        <samples>
          <waypoint>
            <depth>30</depth>
            <divetime>120</divetime>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';
        final result = await service.importAllDataFromUddf(uddfContent);

        expect(result.dives.first['diveMode'], DiveMode.ccr);
      });

      test('reads a rebreather divemode from its type attribute', () async {
        const uddfContent = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2026-08-01T09:08:48Z</datetime>
        </informationbeforedive>
        <rebreather>
          <divemode type="semiclosedcircuit" />
        </rebreather>
        <samples>
          <waypoint>
            <depth>30</depth>
            <divetime>120</divetime>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';
        final result = await service.importAllDataFromUddf(uddfContent);

        expect(result.dives.first['diveMode'], DiveMode.scr);
      });

      test('maps UDDF circuit spellings to dive modes', () async {
        expect(
          UddfImportParsers.parseUddfDiveMode('semiclosedcircuit'),
          DiveMode.scr,
        );
        expect(UddfImportParsers.parseUddfDiveMode('opencircuit'), DiveMode.oc);
        // Our own exporter writes the enum name rather than UDDF's spelling.
        expect(UddfImportParsers.parseUddfDiveMode('ccr'), DiveMode.ccr);
        expect(UddfImportParsers.parseUddfDiveMode('apnoe'), isNull);
      });

      test('keeps oxygen data on the waypoint it came from', () async {
        // A waypoint without a depth is dropped from the profile, so a
        // second pass that indexes waypoints against profile points shifts
        // every later reading onto the wrong sample.
        final profile = await profileFrom('''
          <waypoint>
            <divetime>0</divetime>
            <setpoint>0.7</setpoint>
          </waypoint>
          <waypoint>
            <depth>30</depth>
            <divetime>120</divetime>
            <setpoint>1.3</setpoint>
          </waypoint>''');

        expect(profile, hasLength(1));
        expect(profile.single['setpoint'], closeTo(1.3, 0.001));
      });
    });
  });

  group('tankvolume normalization (#158)', () {
    // Liter-valued fixtures pass through the normalizer unchanged, so only
    // non-literal inputs prove the parse site still calls it.
    String docWith(
      String tankVolume, {
      String? unit,
      bool submersionMarker = false,
    }) {
      final unitAttr = unit == null ? '' : ' unit="$unit"';
      final appData = submersionMarker
          ? '<applicationdata><submersion version="1.0"/></applicationdata>'
          : '';
      return '''<uddf version="3.2.1">
  <profiledata>
    <repetitiongroup id="rg">
      <dive id="d1">
        <informationbeforedive>
          <divenumber>1</divenumber>
          <datetime>2026-01-15T09:00:00</datetime>
        </informationbeforedive>
        <tankdata>
          <tankvolume$unitAttr>$tankVolume</tankvolume>
          <tankpressurebegin>20000000</tankpressurebegin>
          <tankpressureend>5000000</tankpressureend>
        </tankdata>
        <samples>
          <waypoint><depth>5</depth><divetime>0</divetime></waypoint>
          <waypoint><depth>5</depth><divetime>60</divetime></waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
$appData
</uddf>''';
    }

    Future<double?> volumeFor(
      String tankVolume, {
      String? unit,
      bool submersionMarker = false,
    }) async {
      final result = await UddfFullImportService().importAllDataFromUddf(
        docWith(tankVolume, unit: unit, submersionMarker: submersionMarker),
      );
      final tanks = result.dives.first['tanks'] as List<Map<String, dynamic>>;
      return tanks.first['volume'] as double?;
    }

    test('converts spec cubic meters to liters', () async {
      expect(await volumeFor('0.0111'), closeTo(11.1, 0.001));
    });

    test('converts the Diving Log 10x-off quirk to liters', () async {
      expect(await volumeFor('0.111'), closeTo(11.1, 0.001));
    });

    test('leaves legacy liter-valued volumes unchanged', () async {
      expect(await volumeFor('24.0'), closeTo(24.0, 0.001));
    });

    test('a declared m3 unit converts exactly, so large tanks round-trip '
        'instead of hitting the quirk rung', () async {
      // 0.06 m3 = 60 L. Without the declared unit this lands on the
      // Diving Log rung and comes back as 6 L.
      expect(await volumeFor('0.06', unit: 'm3'), closeTo(60.0, 0.001));
      expect(await volumeFor('0.0111', unit: 'm3'), closeTo(11.1, 0.001));
    });

    test('a pre-fix Submersion export (marker present, LITERS, no declared '
        'unit) is not scaled by 1000', () async {
      // Exports before the unit attribute wrote liters into tankvolume and
      // carry the same <submersion version="1.0"> marker, so the marker
      // cannot be used to infer the convention.
      expect(
        await volumeFor('11.1', submersionMarker: true),
        closeTo(11.1, 0.001),
      );
      expect(
        await volumeFor('24.0', submersionMarker: true),
        closeTo(24.0, 0.001),
      );
    });

    test('a mislabelled unit still refuses an impossible volume', () async {
      // 11.1 m3 would be 11,100 L. Whatever the label says, that is liters.
      expect(await volumeFor('11.1', unit: 'm3'), closeTo(11.1, 0.001));
    });
  });
}

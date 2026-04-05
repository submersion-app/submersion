import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
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
  });
}

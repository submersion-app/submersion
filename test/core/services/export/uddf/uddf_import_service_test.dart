import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('UddfImportService', () {
    test(
      'maps T1/T2 refs to tanks by order when tankdata entries omit ids',
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
            <tankpressure ref="T1">20049962</tankpressure>
            <tankpressure ref="T2">21952916</tankpressure>
          </waypoint>
          <waypoint>
            <depth>3</depth>
            <divetime>10</divetime>
            <tankpressure ref="T1">19939646</tankpressure>
            <tankpressure ref="T2">21939126</tankpressure>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

        final service = UddfImportService();

        final result = await service.importDivesFromUddf(uddfContent);
        final dives = result['dives']!;

        expect(dives, hasLength(1));

        final dive = dives.first;
        final tanks = dive['tanks'] as List<Map<String, dynamic>>;
        final profile = dive['profile'] as List<Map<String, dynamic>>;

        expect(tanks, hasLength(2));
        expect(tanks[0]['uddfTankId'], isNull);
        expect(tanks[1]['uddfTankId'], isNull);

        final firstPointPressures =
            profile.first['allTankPressures'] as List<Map<String, dynamic>>;
        final secondPointPressures =
            profile.last['allTankPressures'] as List<Map<String, dynamic>>;

        expect(firstPointPressures, hasLength(2));
        expect(firstPointPressures[0]['tankIndex'], 0);
        expect(firstPointPressures[1]['tankIndex'], 1);
        expect(firstPointPressures[0]['pressure'], closeTo(200.5, 0.1));
        expect(firstPointPressures[1]['pressure'], closeTo(219.5, 0.1));

        expect(secondPointPressures, hasLength(2));
        expect(secondPointPressures[0]['tankIndex'], 0);
        expect(secondPointPressures[1]['tankIndex'], 1);
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

        final service = UddfImportService();

        final result = await service.importDivesFromUddf(uddfContent);
        final dives = result['dives']!;
        expect(dives, hasLength(1));

        final dive = dives.first;
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

    test(
      'maps non-T refs by tank order when tankdata entries omit ids',
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

        final service = UddfImportService();

        final result = await service.importDivesFromUddf(uddfContent);
        final dives = result['dives']!;

        expect(dives, hasLength(1));

        final dive = dives.first;
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

    test('drops unmatched refs beyond available tank records', () async {
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

      final service = UddfImportService();

      final result = await service.importDivesFromUddf(uddfContent);
      final dive = result['dives']!.first;
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

        final service = UddfImportService();

        final result = await service.importDivesFromUddf(uddfContent);
        final dives = result['dives']!;
        expect(dives, hasLength(1));

        final dive = dives.first;
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

        final service = UddfImportService();

        final result = await service.importDivesFromUddf(uddfContent);
        final dive = result['dives']!.first;
        final tanks = dive['tanks'] as List<Map<String, dynamic>>;

        expect(tanks, hasLength(2));
        expect(tanks[0]['gasMix'], isNull);

        final gasMix = tanks[1]['gasMix'] as GasMix;
        expect(gasMix.o2, closeTo(50.0, 0.001));
        expect(gasMix.he, closeTo(0.0, 0.001));
        expect(gasMix.name, 'EAN50');
      },
    );
  });
}

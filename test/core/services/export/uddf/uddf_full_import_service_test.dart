import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';

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
  });
}

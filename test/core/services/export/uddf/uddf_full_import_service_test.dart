import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';

void main() {
  group('UddfFullImportService', () {
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

        final service = UddfFullImportService();

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

        final service = UddfFullImportService();

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

      final service = UddfFullImportService();

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

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';

/// Tank-data cases the wider suite in uddf_full_import_service_test.dart does
/// not reach: Shearwater's positional T1/T2 pressure refs across several
/// waypoints, and the working pressure unit.
void main() {
  Future<Map<String, dynamic>> importOne(String content) async {
    final result = await UddfFullImportService().importAllDataFromUddf(content);
    expect(result.dives, hasLength(1));
    return result.dives.single;
  }

  test(
    'maps T1/T2 refs to tanks by order when tankdata entries omit ids',
    () async {
      final dive = await importOne('''
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
''');

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

  test('parses tankworkingpressure from Pascal to bar', () async {
    // 20684300 Pa = 206.843 bar (3000 psi)
    final dive = await importOne('''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2026-01-15T09:00:00Z</datetime>
          <divenumber>100</divenumber>
        </informationbeforedive>
        <tankdata id="tank-1">
          <tankvolume>11.1</tankvolume>
          <tankworkingpressure>20684300</tankworkingpressure>
          <tankpressurebegin>20684300</tankpressurebegin>
          <tankpressureend>5000000</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <depth>1</depth>
            <divetime>0</divetime>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''');

    final tanks = dive['tanks'] as List<Map<String, dynamic>>;
    expect(tanks, hasLength(1));
    expect(tanks[0]['workingPressure'] as double, closeTo(206.843, 0.001));
    expect(tanks[0]['volume'] as double, closeTo(11.1, 0.01));
  });
}

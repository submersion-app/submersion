import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_tank_ref_router.dart';

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

  group('Shearwater Cloud slot refs (issue #4347)', () {
    // Six bare tankdata as Shearwater Cloud writes them: T2 and T3 carry
    // pressures, the rest are 0/0 placeholders the importer drops. T3's first
    // sample arrives before T2's, which first-seen routing would swap.
    const sidemount = '''
<uddf version="3.2.3">
  <profiledata>
    <repetitiongroup>
      <dive id="dive-1">
        <informationbeforedive>
          <datetime>2025-09-01T14:18:24Z</datetime>
        </informationbeforedive>
        <tankdata>
          <tankpressurebegin>0</tankpressurebegin>
          <tankpressureend>0</tankpressureend>
        </tankdata>
        <tankdata>
          <tankpressurebegin>20049962</tankpressurebegin>
          <tankpressureend>12879411</tankpressureend>
        </tankdata>
        <tankdata>
          <tankpressurebegin>21952916</tankpressurebegin>
          <tankpressureend>14244574</tankpressureend>
        </tankdata>
        <tankdata>
          <tankpressurebegin>0</tankpressurebegin>
          <tankpressureend>0</tankpressureend>
        </tankdata>
        <tankdata>
          <tankpressurebegin>0</tankpressurebegin>
          <tankpressureend>0</tankpressureend>
        </tankdata>
        <tankdata>
          <tankpressurebegin>0</tankpressurebegin>
          <tankpressureend>0</tankpressureend>
        </tankdata>
        <samples>
          <waypoint>
            <depth>1</depth>
            <divetime>0</divetime>
            <tankpressure ref="T3">21952916</tankpressure>
          </waypoint>
          <waypoint>
            <depth>3</depth>
            <divetime>10</divetime>
            <tankpressure ref="T2">20049962</tankpressure>
            <tankpressure ref="T3">21939126</tankpressure>
          </waypoint>
        </samples>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

    test('a later transmitter reporting first keeps each pressure series on '
        'its own cylinder', () async {
      final dive = await importOne(sidemount);
      final profile = dive['profile'] as List<Map<String, dynamic>>;

      final first =
          profile.first['allTankPressures'] as List<Map<String, dynamic>>;
      final second =
          profile.last['allTankPressures'] as List<Map<String, dynamic>>;

      // Cylinder 0 begins at 200.5 bar (T2), cylinder 1 at 219.5 (T3).
      expect(first.single['tankIndex'], 1);
      expect(second.map((p) => p['tankIndex']), [0, 1]);
    });

    test('Shearwater refs record the slot on each parsed cylinder', () async {
      final dive = await importOne(sidemount);
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;

      expect(tanks.map((t) => t[kUddfSourceSlotKey]), [2, 3]);
    });

    test('the Petrel 3 Cloud export records slots 1 and 2', () async {
      final content = File(
        p.join('test', 'dives', '006_ccr_petrel3_shearwater-cloud-export.uddf'),
      ).readAsStringSync();
      final result = await UddfFullImportService().importAllDataFromUddf(
        content,
      );
      final tanks = result.dives.first['tanks'] as List<Map<String, dynamic>>;

      expect(tanks.map((t) => t[kUddfSourceSlotKey]), [1, 2]);
    });
  });
}

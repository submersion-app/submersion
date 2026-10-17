import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/uddf_restore.dart';

/// Issue #1878: Submersion's UDDF writers mark a dive's starting gas with a
/// `<switchmix>` on its first waypoint. Restoring the file turned that marker
/// into a gas switch the dive never had and, on a dive with no cylinders,
/// materialized an air cylinder the diver never logged.
///
/// A waypoint `<switchmix>` still means a real switch in other apps' files:
/// Shearwater Cloud marks the initial mix at t=0 that way and links no
/// `<tankdata>` to a mix, so only Submersion's own documents skip it.
void main() {
  const recorded = [
    DiveProfilePoint(timestamp: 10, depth: 4.5),
    DiveProfilePoint(timestamp: 600, depth: 18.0),
    DiveProfilePoint(timestamp: 1200, depth: 6.0),
  ];

  Dive dive({List<DiveTank> tanks = const []}) => Dive(
    id: 'dive-a',
    diveNumber: 1,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    bottomTime: const Duration(minutes: 20),
    maxDepth: 18.0,
    tanks: tanks,
    profile: recorded,
  );

  group('restore of a full backup', () {
    setUp(() async {
      await setUpTestDatabase();
      final now = DateTime.utc(2026, 3, 1);
      await DiverRepository().createDiver(
        Diver(
          id: 'me',
          name: 'Me',
          isDefault: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    tearDown(tearDownTestDatabase);

    Future<(Dive, List<GasSwitchWithTank>)> roundTrip(
      Dive original, {
      Map<String, List<GasSwitchWithTank>>? gasSwitches,
    }) async {
      final xml = await UddfFullExportService().generateAllDataXmlForTest(
        dives: [original],
        diveGasSwitches: gasSwitches,
      );
      await restoreUddfDives(xml, diverId: 'me');
      // Built per test: a repository keeps the database it was created on.
      final repository = DiveRepository();
      final listed = (await repository.getAllDives(diverId: 'me')).single;
      final restored = (await repository.getDiveById(listed.id))!;
      return (restored, await repository.getGasSwitchesForDive(restored.id));
    }

    test(
      'adds no cylinder or gas switch to a dive without cylinders',
      () async {
        final (restored, switches) = await roundTrip(dive());

        expect(restored.tanks, isEmpty);
        expect(switches, isEmpty);
      },
    );

    test('adds no gas switch to a single-cylinder dive', () async {
      final (restored, switches) = await roundTrip(
        dive(
          tanks: const [DiveTank(id: 'tank-a', gasMix: GasMix(o2: 32))],
        ),
      );

      expect(restored.tanks.map((t) => t.gasMix.o2), [32]);
      expect(switches, isEmpty);
    });

    test('keeps a gas switch the dive recorded', () async {
      final original = dive(
        tanks: const [
          DiveTank(id: 'tank-a', gasMix: GasMix(o2: 21)),
          DiveTank(id: 'tank-b', gasMix: GasMix(o2: 50), order: 1),
        ],
      );
      final (restored, switches) = await roundTrip(
        original,
        gasSwitches: {
          original.id: [
            GasSwitchWithTank(
              gasSwitch: GasSwitch(
                id: 'gs-1',
                diveId: original.id,
                timestamp: 600,
                tankId: 'tank-b',
                depth: 18.0,
                createdAt: DateTime.utc(2026, 3, 1),
              ),
              tankName: 'Deco',
              gasMix: 'EAN50',
              o2Fraction: 0.5,
            ),
          ],
        },
      );

      expect(restored.tanks.map((t) => t.gasMix.o2), unorderedEquals([21, 50]));
      expect(switches.map((s) => s.gasSwitch.timestamp), [600]);
      expect(switches.single.o2Fraction, closeTo(0.5, 1e-9));
    });
  });

  group('import of a hand-written document', () {
    String uddf({
      String generator = 'Submersion',
      String tankdata = '',
      required String waypoints,
      String otherDive = '',
    }) =>
        '''
<?xml version="1.0" encoding="UTF-8"?>
<uddf version="3.2.1">
  <generator><name>$generator</name><version>1.0</version></generator>
  <gasdefinitions>
    <mix id="mix_21_0"><name>Air</name><o2>0.21</o2><he>0.0</he></mix>
    <mix id="mix_32_0"><name>EAN32</name><o2>0.32</o2><he>0.0</he></mix>
  </gasdefinitions>
  <profiledata>
    <repetitiongroup id="rg1">
      <dive id="dive_1">
        <informationbeforedive><datetime>2026-03-01T09:00:00</datetime></informationbeforedive>
        $tankdata
        <samples>$waypoints</samples>
        <informationafterdive><greatestdepth>18.0</greatestdepth><diveduration>1200</diveduration></informationafterdive>
      </dive>
      $otherDive
    </repetitiongroup>
  </profiledata>
</uddf>
''';

    String wp(int time, String depth, {String? mix}) =>
        '<waypoint><divetime>$time</divetime><depth>$depth</depth>'
        '${mix == null ? '' : '<switchmix ref="$mix"/>'}</waypoint>';

    const linkedTank =
        '<tankdata id="tank_a"><link ref="mix_32_0"/>'
        '<tankvolume>11.1</tankvolume></tankdata>';

    // A dive that did log a cylinder: a full backup declares its <tankdata>,
    // which is what tells it apart from an old dives-only export.
    const cylinderDive =
        '<dive id="dive_2">'
        '<informationbeforedive><datetime>2026-03-02T09:00:00</datetime></informationbeforedive>'
        '$linkedTank'
        '</dive>';

    Future<Map<String, dynamic>> parse(String xml) async =>
        (await ExportService().importAllDataFromUddf(xml)).dives.first;

    test('an old backup of a dive without cylinders gains none', () async {
      // Before #1875 the marker sat on a separate (0 s, 0 m) waypoint.
      final dive = await parse(
        uddf(
          waypoints: [
            wp(0, '0', mix: 'mix_21_0'),
            wp(10, '4.5'),
            wp(600, '18.0'),
          ].join(),
          otherDive: cylinderDive,
        ),
      );

      expect(dive['tanks'], isNull);
      expect(dive['gasMix'], isNull);
      expect(dive['gasSwitches'], isNull);
    });

    test('an old backup of a single-cylinder dive gains no switch', () async {
      final dive = await parse(
        uddf(
          tankdata: linkedTank,
          waypoints: [
            wp(0, '0', mix: 'mix_32_0'),
            wp(10, '4.5'),
            wp(600, '18.0'),
          ].join(),
        ),
      );

      expect(dive['tanks'], hasLength(1));
      expect(dive['gasSwitches'], isNull);
    });

    test('a newer backup marking the first sample gains no switch', () async {
      final dive = await parse(
        uddf(
          tankdata: linkedTank,
          waypoints: [wp(10, '4.5', mix: 'mix_32_0'), wp(600, '18.0')].join(),
        ),
      );

      expect(dive['tanks'], hasLength(1));
      expect(dive['gasSwitches'], isNull);
    });

    test('an old dives-only export keeps its cylinder, not a switch', () async {
      // Before #1875 the dives-only export wrote no <tankdata> at all, so the
      // starting mix was the only record of the dive's cylinder.
      final dive = await parse(
        uddf(
          waypoints: [
            wp(0, '0', mix: 'mix_32_0'),
            wp(10, '4.5'),
            wp(600, '18.0'),
          ].join(),
        ),
      );

      expect(dive['gasMix'], const GasMix(o2: 32));
      expect(dive['gasSwitches'], isNull);
    });

    test('another app keeps its initial switch and breathed gases', () async {
      // Shearwater Cloud style: no <link> from <tankdata> to a mix, and every
      // switch, the initial mix included, marked on a waypoint.
      final dive = await parse(
        uddf(
          generator: 'Shearwater Cloud',
          tankdata:
              '<tankdata id="T1"><tankvolume>11.1</tankvolume></tankdata>',
          waypoints: [
            wp(0, '0', mix: 'mix_21_0'),
            wp(600, '18.0'),
            wp(900, '6.0', mix: 'mix_32_0'),
          ].join(),
        ),
      );

      final switches = dive['gasSwitches'] as List<Map<String, dynamic>>;
      expect(switches.map((s) => s['timestamp']), [0, 900]);
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(
        tanks.map((t) => t['uddfGasMixRef']),
        containsAll(['mix_21_0', 'mix_32_0']),
      );
    });
  });
}

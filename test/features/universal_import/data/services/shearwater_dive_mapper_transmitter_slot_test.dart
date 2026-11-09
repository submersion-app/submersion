import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_dive_mapper.dart';

/// Issue #4347: a Shearwater Cloud database names each tank's transmitter
/// slot, and its raw log carries the serial in that slot.
void main() {
  Map<String, dynamic> tank(Map<String, dynamic> transmitter) => {
    'StartPressurePSI': '2960',
    'EndPressurePSI': '1088',
    'GasProfile': {'O2Percent': 32, 'HePercent': 0},
    'DiveTransmitter': {'IsOn': true, ...transmitter},
  };

  List<Map<String, dynamic>> mapped(List<Map<String, dynamic>> tankData) =>
      ShearwaterDiveMapper.mapTanks(
        ShearwaterRawDive(
          diveId: 'd',
          footerJson: const {'UnitSystem': 1},
          tankProfileData: {'TankData': tankData},
        ),
      );

  group('mapTanks', () {
    test('takes the slot from the transmitter tank index', () {
      final tanks = mapped([
        tank({'TankIndex': 1, 'Name': 'T2'}),
        tank({'TankIndex': 2, 'Name': 'T3'}),
      ]);
      expect(tanks.map((t) => t['transmitterSlot']), [1, 2]);
    });

    test('falls back to the T name when the index is missing', () {
      final tanks = mapped([
        tank({'Name': 'T3'}),
      ]);
      expect(tanks.single['transmitterSlot'], 2);
    });

    test('a tank with neither has no slot', () {
      final tanks = mapped([
        tank({'Name': 'Left'}),
      ]);
      expect(tanks.single.containsKey('transmitterSlot'), isFalse);
    });
  });

  group('mergeWithParsedDive', () {
    pigeon.ParsedDive parsed(List<pigeon.TankInfo> tanks) => pigeon.ParsedDive(
      fingerprint: '',
      dateTimeYear: 2025,
      dateTimeMonth: 1,
      dateTimeDay: 1,
      dateTimeHour: 0,
      dateTimeMinute: 0,
      dateTimeSecond: 0,
      maxDepthMeters: 0,
      avgDepthMeters: 0,
      durationSeconds: 0,
      samples: const [],
      tanks: tanks,
      gasMixes: const [],
      events: const [],
    );

    test('copies the serial of the parsed tank in the same slot', () {
      final base = <String, dynamic>{
        'profile': <Map<String, dynamic>>[],
        'tanks': mapped([
          tank({'TankIndex': 0, 'Name': 'T1'}),
          tank({'TankIndex': 1, 'Name': 'T2'}),
        ]),
      };
      final result = ShearwaterDiveMapper.mergeWithParsedDive(
        base,
        parsed([
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: 0,
            transmitterSerial: 109623,
            transmitterSlot: 1,
          ),
          pigeon.TankInfo(index: 1, gasMixIndex: 0, transmitterSlot: 3),
        ]),
      );
      final tanks = result['tanks'] as List<Map<String, dynamic>>;
      expect(tanks.map((t) => t['transmitterSerial']), [null, '109623']);
    });

    test('no parsed tank in a slot leaves the serial unset', () {
      final base = <String, dynamic>{
        'profile': <Map<String, dynamic>>[],
        'tanks': mapped([
          tank({'TankIndex': 0, 'Name': 'T1'}),
        ]),
      };
      final result = ShearwaterDiveMapper.mergeWithParsedDive(
        base,
        parsed([
          pigeon.TankInfo(index: 0, gasMixIndex: 0, transmitterSerial: 5),
        ]),
      );
      final tanks = result['tanks'] as List<Map<String, dynamic>>;
      expect(tanks.single.containsKey('transmitterSerial'), isFalse);
    });
  });
}

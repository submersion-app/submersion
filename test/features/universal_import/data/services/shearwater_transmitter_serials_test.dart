import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_transmitter_serials.dart';

pigeon.TankInfo _parsed(int index, double? start, int? serial, {int? usage}) =>
    pigeon.TankInfo(
      index: index,
      gasMixIndex: 0,
      startPressureBar: start,
      transmitterSerial: serial,
      usage: usage,
    );

Map<String, dynamic> _meta(double? start) => {'startPressure': start};

void main() {
  group('withTransmitterSerials carries the Avelo Hydrotank (issue #4657)', () {
    // DC_USAGE_HYDROTANK: the fork's tag for the Avelo Hydrotank.
    const hydrotank = 4;

    test('a tank paired in slot order with the tagged tank is the '
        'Hydrotank', () {
      final tanks = withTransmitterSerials(
        [_meta(200.0), _meta(210.0)],
        [_parsed(0, 200.1, 12345, usage: hydrotank), _parsed(1, 210.1, 76287)],
      );

      expect(tanks[0]['role'], TankRole.hydrotank.name);
      expect(tanks[1].containsKey('role'), isFalse);
    });

    test('a tank paired by its start pressure with the tagged tank is the '
        'Hydrotank', () {
      final tanks = withTransmitterSerials(
        [_meta(null), _meta(150.3)],
        [_parsed(0, 150.2, 12345, usage: hydrotank)],
      );

      expect(tanks[0].containsKey('role'), isFalse);
      expect(tanks[1]['role'], TankRole.hydrotank.name);
    });

    test('an unpaired tank takes no role from the tagged tank', () {
      // Two metadata tanks equally close to the one parsed tank: neither
      // pairs, so neither may claim its tag.
      final tanks = withTransmitterSerials(
        [_meta(200.0), _meta(200.4)],
        [_parsed(0, 200.2, 12345, usage: hydrotank)],
      );

      expect(tanks.any((t) => t.containsKey('role')), isFalse);
    });
  });

  group('withTransmitterSerials (issue #4388)', () {
    test('gives each tank the serial of the parsed tank it pairs with', () {
      final tanks = withTransmitterSerials(
        [_meta(206.8), _meta(190.0), _meta(185.2)],
        [
          _parsed(0, 206.9, 12345),
          _parsed(1, 190.1, 76287),
          _parsed(2, 185.0, 76290),
        ],
      );

      expect(tanks.map((t) => t['transmitterSerial']), [
        '12345',
        '76287',
        '76290',
      ]);
    });

    test('pairs by pressure when the lists differ in length', () {
      // A transmitter that was on but never read a pressure is in the
      // metadata only; libdivecomputer drops it.
      final tanks = withTransmitterSerials(
        [_meta(null), _meta(190.0), _meta(150.3)],
        [_parsed(0, 150.2, 76290), _parsed(1, 190.1, 76287)],
      );

      expect(tanks.map((t) => t['transmitterSerial']), [
        null,
        '76287',
        '76290',
      ]);
    });

    test('equal pressures pair in slot order when both lists line up', () {
      final tanks = withTransmitterSerials(
        [_meta(206.8), _meta(206.8)],
        [_parsed(0, 206.9, 76287), _parsed(1, 206.7, 76290)],
      );

      expect(tanks.map((t) => t['transmitterSerial']), ['76287', '76290']);
    });

    test('leaves the serial empty when the pairing is unclear', () {
      final tanks = withTransmitterSerials(
        [_meta(206.8), _meta(206.8), _meta(100)],
        [_parsed(0, 206.9, 76287), _parsed(1, 206.7, 76290)],
      );

      expect(tanks.map((t) => t['transmitterSerial']), [null, null, null]);
    });

    test('never pairs across a pressure gap', () {
      final tanks = withTransmitterSerials(
        [_meta(206.8)],
        [_parsed(0, 180.0, 76287)],
      );

      expect(tanks.single.containsKey('transmitterSerial'), isFalse);
    });

    test('ignores parsed tanks that report no serial', () {
      final tanks = withTransmitterSerials(
        [_meta(206.8)],
        [_parsed(0, 206.8, null)],
      );

      expect(tanks.single.containsKey('transmitterSerial'), isFalse);
    });

    test('keeps every other key and returns new maps', () {
      final meta = {'startPressure': 206.8, 'name': 'T1'};
      final tanks = withTransmitterSerials([meta], [_parsed(0, 206.8, 12345)]);

      expect(tanks.single['name'], 'T1');
      expect(meta.containsKey('transmitterSerial'), isFalse);
    });
  });
}

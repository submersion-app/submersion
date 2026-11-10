import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/features/universal_import/data/services/shearwater_transmitter_serials.dart';

pigeon.TankInfo _parsed(int index, double? start, int? serial) =>
    pigeon.TankInfo(
      index: index,
      gasMixIndex: 0,
      startPressureBar: start,
      transmitterSerial: serial,
    );

Map<String, dynamic> _meta(double? start) => {'startPressure': start};

void main() {
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

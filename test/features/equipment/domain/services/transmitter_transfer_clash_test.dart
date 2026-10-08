import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/services/transmitter_transfer_clash.dart';

/// A transmitter moving to another profile must not break that profile's
/// serial and channel uniqueness (issue #2852).
void main() {
  TransmitterKey key(
    String id, {
    String? serial,
    String? computer,
    int? channel,
  }) =>
      (id: id, serial: serial, diveComputerId: computer, channelIndex: channel);

  test('the same serial with stray whitespace clashes', () {
    expect(
      transmitterClashes(key('m', serial: ' 1234AB '), [
        key('t', serial: '1234AB'),
      ]),
      isTrue,
    );
  });

  test('different serials do not clash', () {
    expect(
      transmitterClashes(key('m', serial: 'A'), [key('t', serial: 'B')]),
      isFalse,
    );
  });

  test('an all-zero serial is no serial and never clashes', () {
    expect(
      transmitterClashes(key('m', serial: '000'), [key('t', serial: '0')]),
      isFalse,
    );
  });

  test('the same computer and channel clash', () {
    expect(
      transmitterClashes(key('m', computer: 'c1', channel: 2), [
        key('t', computer: 'c1', channel: 2),
      ]),
      isTrue,
    );
  });

  test('no serial and no channel never clash', () {
    expect(transmitterClashes(key('m'), [key('t')]), isFalse);
  });

  test('a row never clashes with itself', () {
    expect(
      transmitterClashes(key('m', serial: 'A'), [key('m', serial: 'A')]),
      isFalse,
    );
  });
}

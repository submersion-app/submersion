import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// "Set up" (issue #3676): the diver saved the entry and it names a cylinder,
/// by a gear link or a size. The nudge and the registry matcher read it.
void main() {
  Transmitter entry({
    String serial = '4A21F',
    bool isConfigured = true,
    String? equipmentId,
    double? volumeL,
  }) => Transmitter(
    id: 'tx-$serial',
    transmitterSerial: serial,
    label: 'Transmitter $serial',
    isConfigured: isConfigured,
    equipmentId: equipmentId,
    volumeL: volumeL,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('an entry defaults to configured', () {
    expect(entry().isConfigured, isTrue);
  });

  test('isSetUp is false when the entry is not configured', () {
    expect(entry(isConfigured: false, volumeL: 11.1).isSetUp, isFalse);
  });

  test('isSetUp is false with no cylinder link and no volume', () {
    expect(entry().isSetUp, isFalse);
  });

  test('isSetUp is true with a volume and no link', () {
    expect(entry(volumeL: 11.1).isSetUp, isTrue);
  });

  test('isSetUp is true with a cylinder link and no volume', () {
    expect(entry(equipmentId: 'cyl-1').isSetUp, isTrue);
  });

  test('a zero volume does not count as a cylinder', () {
    expect(entry(volumeL: 0).isSetUp, isFalse);
  });

  test('setUpSerials skips entries that are not set up', () {
    final serials = Transmitter.setUpSerials([
      entry(serial: ' 4A21F ', volumeL: 11.1),
      entry(serial: '7C0B19', isConfigured: false, volumeL: 11.1),
      entry(serial: '9D0000'),
    ]);
    expect(serials, {'4A21F'});
  });

  test('isConfigured is part of an entry\'s identity', () {
    expect(entry(isConfigured: false), isNot(entry()));
  });

  test('copyWith changes isConfigured', () {
    expect(
      entry(isConfigured: false).copyWith(isConfigured: true).isConfigured,
      isTrue,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

Transmitter _entry(String id, String? serial) => Transmitter(
  id: id,
  transmitterSerial: serial,
  label: id,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
);

void main() {
  test('knownSerials normalizes and drops blank or all-zero values', () {
    final set = Transmitter.knownSerials([
      _entry('a', ' 180777 '),
      _entry('b', '109623'),
      _entry('c', '   '),
      _entry('d', '0000'),
      _entry('e', null),
    ]);

    expect(set, {'180777', '109623'});
  });

  test('hasSerial is false for whitespace or all-zero values', () {
    expect(_entry('a', '180777').hasSerial, isTrue);
    expect(_entry('b', '   ').hasSerial, isFalse);
    expect(_entry('c', '000').hasSerial, isFalse);
    expect(_entry('d', null).hasSerial, isFalse);
  });

  test('the transmitter gear link is part of an entry\'s identity', () {
    Transmitter linked(String? gear) => Transmitter(
      id: 'a',
      transmitterSerial: '1',
      label: 'a',
      transmitterEquipmentId: gear,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );
    expect(linked('tx'), linked('tx'));
    expect(linked('tx'), isNot(linked(null)));
  });
}

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
}

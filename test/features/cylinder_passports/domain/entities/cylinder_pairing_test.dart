import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

CylinderPairing pairing({
  String id = 'p1',
  String a = 'A',
  String b = 'B',
  required DateTime on,
  DateTime? off,
}) => CylinderPairing(
  id: id,
  cylinderAId: a,
  cylinderBId: b,
  pairedOn: on,
  unpairedOn: off,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  test('calendarDay keeps the wall-calendar date as UTC midnight', () {
    expect(calendarDay(DateTime(2026, 9, 14, 23, 59)), d(2026, 9, 14));
    expect(calendarDay(DateTime(2026, 9, 14, 0, 1)), d(2026, 9, 14));
    expect(calendarDay(DateTime.utc(2026, 9, 14, 22)), d(2026, 9, 14));
  });

  test('a pairing covers its start day and not its end day', () {
    final p = pairing(on: d(2026, 3, 3), off: d(2026, 9, 14));
    expect(p.coversDay(DateTime(2026, 3, 3, 23, 59)), isTrue);
    expect(p.coversDay(DateTime(2026, 9, 13, 8)), isTrue);
    expect(p.coversDay(DateTime(2026, 9, 14, 0, 1)), isFalse);
    expect(p.coversDay(DateTime(2026, 3, 2, 23, 59)), isFalse);
  });

  test('an open pairing covers every day from its start', () {
    final p = pairing(on: d(2026, 3, 3));
    expect(p.isOpen, isTrue);
    expect(p.coversDay(DateTime(2040, 1, 1)), isTrue);
  });

  test('partnerOf names the other cylinder from either side', () {
    final p = pairing(on: d(2026, 1, 1));
    expect(p.partnerOf('A'), 'B');
    expect(p.partnerOf('B'), 'A');
    expect(p.involves('A'), isTrue);
    expect(p.involves('C'), isFalse);
    expect(() => p.partnerOf('C'), throwsArgumentError);
  });

  test('copyWith changes what it names and can clear the end', () {
    final p = pairing(on: d(2026, 1, 1), off: d(2026, 6, 1));
    final moved = p.copyWith(
      id: 'p2',
      cylinderAId: 'X',
      cylinderBId: 'Y',
      pairedOn: d(2026, 2, 1),
      unpairedOn: d(2026, 7, 1),
      createdAt: DateTime.utc(2027),
      updatedAt: DateTime.utc(2027),
    );
    expect(moved.id, 'p2');
    expect(moved.partnerOf('X'), 'Y');
    expect(moved.pairedOn, d(2026, 2, 1));
    expect(moved.unpairedOn, d(2026, 7, 1));
    expect(moved.updatedAt, DateTime.utc(2027));
    expect(p.copyWith(clearUnpairedOn: true).isOpen, isTrue);
    expect(p.copyWith(), p);
  });
}

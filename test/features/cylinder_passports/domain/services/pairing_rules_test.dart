import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';
import 'package:submersion/features/cylinder_passports/domain/services/pairing_rules.dart';

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
  group('rangesOverlap', () {
    test('treats the end day as outside', () {
      expect(
        rangesOverlap(d(2026, 1, 1), d(2026, 2, 1), d(2026, 2, 1), null),
        isFalse,
      );
    });

    test('an open range overlaps a later start', () {
      expect(
        rangesOverlap(d(2026, 1, 1), null, d(2025, 1, 1), d(2026, 1, 2)),
        isTrue,
      );
      expect(rangesOverlap(d(2026, 1, 1), null, d(2027, 1, 1), null), isTrue);
    });

    test('ranges that end before the other starts do not overlap', () {
      expect(
        rangesOverlap(d(2025, 1, 1), d(2025, 6, 1), d(2026, 1, 1), null),
        isFalse,
      );
    });
  });

  group('pairingOn', () {
    test('on a swap day the new pairing counts', () {
      final old = pairing(
        id: 'p1',
        a: 'A',
        b: 'C',
        on: d(2026, 1, 1),
        off: d(2026, 9, 14),
      );
      final now = pairing(id: 'p2', a: 'A', b: 'B', on: d(2026, 9, 14));
      final r = resolvePairings([old, now]);
      expect(pairingOn(r, 'A', DateTime(2026, 9, 14, 10))!.partnerOf('A'), 'B');
      expect(pairingOn(r, 'A', DateTime(2026, 9, 13, 10))!.partnerOf('A'), 'C');
      expect(pairingOn(r, 'C', DateTime(2026, 9, 14, 10)), isNull);
    });

    test('no pairing before the first one started', () {
      final r = resolvePairings([pairing(on: d(2026, 9, 14))]);
      expect(pairingOn(r, 'A', DateTime(2026, 9, 13)), isNull);
    });
  });

  group('resolvePairings', () {
    test('two open pairings from two devices resolve to one, the same '
        'everywhere', () {
      final x = pairing(id: 'b', a: 'A', b: 'B', on: d(2026, 11, 1));
      final y = pairing(id: 'a', a: 'A', b: 'C', on: d(2026, 11, 1));
      expect(resolvePairings([x, y]).map((p) => p.id), ['a']);
      expect(resolvePairings([y, x]).map((p) => p.id), ['a']);
    });

    test('the newer start wins an overlap and the older one is dropped', () {
      final older = pairing(id: 'z', a: 'A', b: 'C', on: d(2026, 1, 1));
      final newer = pairing(id: 'y', a: 'A', b: 'B', on: d(2026, 6, 1));
      expect(resolvePairings([older, newer]).map((p) => p.id), ['y']);
    });

    test('pairings that do not overlap are all kept, newest first', () {
      final first = pairing(
        id: 'p1',
        a: 'A',
        b: 'C',
        on: d(2025, 1, 1),
        off: d(2026, 1, 1),
      );
      final second = pairing(id: 'p2', a: 'A', b: 'B', on: d(2026, 1, 1));
      expect(resolvePairings([first, second]).map((p) => p.id), ['p2', 'p1']);
    });
  });

  test('currentPairing is the open one', () {
    final r = resolvePairings([
      pairing(id: 'p1', a: 'A', b: 'C', on: d(2025, 1, 1), off: d(2026, 1, 1)),
      pairing(id: 'p2', a: 'A', b: 'B', on: d(2026, 1, 1)),
    ]);
    expect(currentPairing(r, 'A')!.id, 'p2');
    expect(currentPairing(r, 'C'), isNull);
  });

  test('clashesWith finds an overlap on either cylinder', () {
    final r = resolvePairings([
      pairing(id: 'bd', a: 'B', b: 'D', on: d(2026, 1, 1)),
      pairing(id: 'ce', a: 'C', b: 'E', on: d(2020, 1, 1), off: d(2021, 1, 1)),
    ]);
    final clashes = clashesWith(
      r,
      cylinderAId: 'A',
      cylinderBId: 'B',
      pairedOn: d(2026, 11, 6),
    );
    expect(clashes.map((p) => p.id), ['bd']);
    expect(
      clashesWith(
        r,
        cylinderAId: 'C',
        cylinderBId: 'A',
        pairedOn: d(2021, 1, 1),
      ),
      isEmpty,
    );
  });

  test('clashesWith ignores the pairing being changed', () {
    final r = resolvePairings([pairing(id: 'ab', on: d(2026, 1, 1))]);
    expect(
      clashesWith(
        r,
        cylinderAId: 'A',
        cylinderBId: 'B',
        pairedOn: d(2026, 1, 1),
        unpairedOn: d(2026, 5, 1),
        ignoreId: 'ab',
      ),
      isEmpty,
    );
  });

  test('a partner retired, sold, lost, loaned or in service is out of use', () {
    for (final s in EquipmentStatus.values) {
      expect(
        isPartnerOutOfUse(s),
        const {
          EquipmentStatus.retired,
          EquipmentStatus.sold,
          EquipmentStatus.lost,
          EquipmentStatus.loaned,
          EquipmentStatus.inService,
        }.contains(s),
        reason: s.name,
      );
    }
  });
}

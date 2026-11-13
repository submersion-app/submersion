import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/suit_type.dart';

void main() {
  group('SuitType.key (issue #4490)', () {
    test('a drysuit keys as drysuit', () {
      expect(const SuitType.drysuit().key, 'drysuit');
    });

    test('a wetsuit keys its thickness and style, leaving gaps empty', () {
      expect(
        const SuitType.wetsuit(mm: 5, style: 'full').key,
        'wetsuit:5:full',
      );
      expect(const SuitType.wetsuit(mm: 6.5).key, 'wetsuit:6.5:');
      expect(const SuitType.wetsuit(style: 'shorty').key, 'wetsuit::shorty');
      expect(const SuitType.wetsuit().key, 'wetsuit::');
    });

    test('fromKey reads every key back', () {
      for (final type in const [
        SuitType.drysuit(),
        SuitType.wetsuit(mm: 5, style: 'full'),
        SuitType.wetsuit(mm: 6.5),
        SuitType.wetsuit(style: 'semi_dry'),
        SuitType.wetsuit(),
      ]) {
        expect(SuitType.fromKey(type.key), type, reason: type.key);
      }
    });

    test('fromKey normalizes SQLite REAL text to the same key', () {
      // SQLite renders 5.0 as "5.0"; the key reads "5" like the chart label.
      expect(SuitType.fromKey('wetsuit:5.0:full')?.key, 'wetsuit:5:full');
      expect(SuitType.fromKey('wetsuit:5.0:')?.key, 'wetsuit:5:');
    });

    test('fromKey rejects a key that is not a suit', () {
      expect(SuitType.fromKey('fins'), isNull);
    });
  });

  group('SuitType ordering', () {
    test('thickness ascending, then catalog style order, drysuit last', () {
      final shuffled = [
        const SuitType.drysuit(),
        const SuitType.wetsuit(),
        const SuitType.wetsuit(style: 'shorty'),
        const SuitType.wetsuit(mm: 7, style: 'semi_dry'),
        const SuitType.wetsuit(mm: 5),
        const SuitType.wetsuit(mm: 5, style: 'two_piece'),
        const SuitType.wetsuit(mm: 5, style: 'full'),
        const SuitType.wetsuit(mm: 3, style: 'shorty'),
      ];

      expect([...shuffled]..sort(), const [
        SuitType.wetsuit(mm: 3, style: 'shorty'),
        SuitType.wetsuit(mm: 5, style: 'full'),
        SuitType.wetsuit(mm: 5, style: 'two_piece'),
        SuitType.wetsuit(mm: 5),
        SuitType.wetsuit(mm: 7, style: 'semi_dry'),
        SuitType.wetsuit(style: 'shorty'),
        SuitType.wetsuit(),
        SuitType.drysuit(),
      ]);
    });

    test('a style outside the catalog sorts after the known ones', () {
      final sorted = [
        const SuitType.wetsuit(mm: 5),
        const SuitType.wetsuit(mm: 5, style: 'zz_custom'),
        const SuitType.wetsuit(mm: 5, style: 'aa_custom'),
        const SuitType.wetsuit(mm: 5, style: 'semi_dry'),
      ]..sort();

      expect(sorted, const [
        SuitType.wetsuit(mm: 5, style: 'semi_dry'),
        SuitType.wetsuit(mm: 5, style: 'aa_custom'),
        SuitType.wetsuit(mm: 5, style: 'zz_custom'),
        SuitType.wetsuit(mm: 5),
      ]);
    });
  });

  group('SuitType value semantics', () {
    test('equal suit types hash alike and collapse in a set', () {
      const a = SuitType.wetsuit(mm: 5, style: 'full');
      const b = SuitType.wetsuit(mm: 5, style: 'full');
      expect(a.hashCode, b.hashCode);
      expect({a, b, const SuitType.drysuit()}, hasLength(2));
    });

    test('toString names the key', () {
      expect(
        const SuitType.wetsuit(mm: 3, style: 'shorty').toString(),
        'SuitType(wetsuit:3:shorty)',
      );
    });
  });
}

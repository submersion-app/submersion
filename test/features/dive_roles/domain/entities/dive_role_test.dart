import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

void main() {
  final now = DateTime(2024, 1, 1);
  final later = DateTime(2024, 6, 1);

  DiveRole base() => DiveRole(
    id: 'uuid-1',
    diverId: 'diver-1',
    name: 'Hekkensluiter',
    sortOrder: 9,
    createdAt: now,
    updatedAt: now,
  );

  group('DiveRole', () {
    test('builtInIds lists the nine seeded roles in seed order', () {
      expect(DiveRole.builtInIds, [
        'buddy',
        'diveGuide',
        'instructor',
        'student',
        'diveMaster',
        'solo',
        'rearGuard',
        'supportDiver',
        'safetyDiver',
      ]);
    });

    test('synthetic exposes the raw slug as both id and name', () {
      final role = DiveRole.synthetic('mysterySlug');
      expect(role.id, 'mysterySlug');
      expect(role.name, 'mysterySlug');
      expect(role.isBuiltIn, isFalse);
      expect(role.diverId, isNull);
    });

    test('builtInBuddy is the built-in buddy role', () {
      final role = DiveRole.builtInBuddy();
      expect(role.id, DiveRole.buddyId);
      expect(role.name, 'Buddy');
      expect(role.isBuiltIn, isTrue);
    });

    test('copyWith replaces only the given fields', () {
      final copy = base().copyWith(
        id: 'uuid-2',
        diverId: 'diver-2',
        name: 'Sweep',
        isBuiltIn: true,
        sortOrder: 3,
        createdAt: later,
        updatedAt: later,
      );
      expect(copy.id, 'uuid-2');
      expect(copy.diverId, 'diver-2');
      expect(copy.name, 'Sweep');
      expect(copy.isBuiltIn, isTrue);
      expect(copy.sortOrder, 3);
      expect(copy.createdAt, later);
      expect(copy.updatedAt, later);

      final unchanged = base().copyWith();
      expect(unchanged, base());
    });

    test('equality is value-based via props', () {
      expect(base(), base());
      expect(base() == base().copyWith(name: 'Sweep'), isFalse);
      expect(base().props, hasLength(7));
    });
  });
}

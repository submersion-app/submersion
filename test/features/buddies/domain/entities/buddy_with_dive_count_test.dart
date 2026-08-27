import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';

void main() {
  final buddy = Buddy(
    id: 'b1',
    name: 'Jane',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('BuddyWithDiveCount', () {
    test('aggregates default to null', () {
      final entry = BuddyWithDiveCount(buddy: buddy, diveCount: 2);
      expect(entry.lastDiveAt, isNull);
      expect(entry.usualRoleId, isNull);
    });

    test('is value-equal on every field', () {
      final a = BuddyWithDiveCount(
        buddy: buddy,
        diveCount: 2,
        lastDiveAt: DateTime(2026, 2, 2),
        usualRoleId: 'instructor',
      );
      final b = BuddyWithDiveCount(
        buddy: buddy,
        diveCount: 2,
        lastDiveAt: DateTime(2026, 2, 2),
        usualRoleId: 'instructor',
      );
      expect(a, equals(b));
    });
  });

  group('usualRoleFor', () {
    test('returns null for a buddy with no dives', () {
      expect(usualRoleFor(const {}), isNull);
    });

    test('picks the role with the highest count', () {
      expect(
        usualRoleFor(const {'buddy': 1, 'instructor': 3, 'student': 2}),
        'instructor',
      );
    });

    test('breaks ties on role id ascending so the answer is stable', () {
      expect(usualRoleFor(const {'instructor': 2, 'buddy': 2}), 'buddy');
      expect(
        usualRoleFor(const {'zzz-custom': 2, 'diveGuide': 2}),
        'diveGuide',
      );
    });
  });
}

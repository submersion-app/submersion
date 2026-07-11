import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

void main() {
  final now = DateTime(2024, 1, 1);
  Buddy buddy(String id, String name) =>
      Buddy(id: id, name: name, createdAt: now, updatedAt: now);

  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('DiveBuddiesNotifier', () {
    test('addBuddy appends a new buddy and replaces the role of an '
        'existing one', () {
      final notifier = DiveBuddiesNotifier(BuddyRepository(), null);

      notifier.addBuddy(buddy('b1', 'Alice'), DiveRole.builtInBuddy());
      notifier.addBuddy(buddy('b2', 'Bob'), DiveRole.builtInBuddy());
      expect(notifier.state, hasLength(2));

      // Re-adding the same buddy updates the role in place.
      notifier.addBuddy(
        buddy('b1', 'Alice'),
        DiveRole.synthetic(DiveRole.rearGuardId),
      );
      expect(notifier.state, hasLength(2));
      expect(notifier.state.first.role.id, DiveRole.rearGuardId);
    });

    test('updateRole changes only the matching buddy and removeBuddy '
        'drops it', () {
      final notifier = DiveBuddiesNotifier(BuddyRepository(), null);
      notifier.addBuddy(buddy('b1', 'Alice'), DiveRole.builtInBuddy());
      notifier.addBuddy(buddy('b2', 'Bob'), DiveRole.builtInBuddy());

      notifier.updateRole('b2', DiveRole.synthetic(DiveRole.instructorId));
      expect(notifier.state[0].role.id, DiveRole.buddyId);
      expect(notifier.state[1].role.id, DiveRole.instructorId);

      notifier.removeBuddy('b1');
      expect(notifier.state.single.buddy.id, 'b2');
    });
  });
}

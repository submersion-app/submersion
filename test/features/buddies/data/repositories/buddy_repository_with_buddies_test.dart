import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository dives;
  late BuddyRepository buddies;

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
    buddies = BuddyRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('withBuddies attaches every dive\'s buddies across id chunks, in the '
      'order given (#3039)', () async {
    final now = DateTime(2026, 1, 1);
    final created = <Dive>[];
    for (var i = 0; i < 5; i++) {
      created.add(
        await dives.createDive(
          Dive(id: 'd$i', dateTime: DateTime(2026, 1, i + 1)),
        ),
      );
    }
    // A buddy on every dive but the middle one, so each chunk of two holds
    // at least one linked dive and one chunk also holds an unlinked one.
    for (final i in [0, 1, 3, 4]) {
      final b = await buddies.createBuddy(
        Buddy(id: '', name: 'Buddy $i', createdAt: now, updatedAt: now),
      );
      await buddies.addBuddyToDive('d$i', b.id, DiveRole.buddyId);
    }

    final hydrated = await buddies.withBuddies(created, chunkSize: 2);

    expect(hydrated.map((d) => d.id), ['d0', 'd1', 'd2', 'd3', 'd4']);
    expect(hydrated.map((d) => d.buddies.map((b) => b.buddy.name).join()), [
      'Buddy 0',
      'Buddy 1',
      '',
      'Buddy 3',
      'Buddy 4',
    ]);
  });
}

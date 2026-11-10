import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide DiveComputer;
import 'package:submersion/features/dive_import/data/services/apple_watch_computer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Apple Watch dives (issue #637) belong to one "Apple Watch" computer per
/// diver, and each workout imports under an id two devices agree on.
void main() {
  group('appleWatchComputerFor', () {
    late AppDatabase db;
    final created = DateTime.utc(2026, 7, 1).millisecondsSinceEpoch;

    setUp(() async {
      db = await setUpTestDatabase();
      for (final id in ['a', 'b']) {
        await db
            .into(db.divers)
            .insert(
              DiversCompanion.insert(
                id: id,
                name: id,
                createdAt: created,
                updatedAt: created,
              ),
            );
      }
    });

    tearDown(() => tearDownTestDatabase());

    test('a diver gets one Apple Watch computer, made once', () async {
      final repo = DiveComputerRepository();

      final first = await appleWatchComputerFor(repo, 'a');
      final again = await appleWatchComputerFor(repo, 'a');
      final other = await appleWatchComputerFor(repo, 'b');

      expect(again.id, first.id);
      expect(other.id, isNot(first.id));
      expect(first.manufacturer, 'Apple');
      expect(first.model, 'Apple Watch');
    });
  });

  group('healthDiveId', () {
    test('is the same for the same workout and diver', () {
      expect(
        healthDiveId(diverId: 'a', workoutUuid: 'w1'),
        healthDiveId(diverId: 'a', workoutUuid: 'w1'),
      );
    });

    test('differs by workout and by diver', () {
      final id = healthDiveId(diverId: 'a', workoutUuid: 'w1');
      expect(healthDiveId(diverId: 'a', workoutUuid: 'w2'), isNot(id));
      expect(healthDiveId(diverId: 'b', workoutUuid: 'w1'), isNot(id));
    });
  });
}

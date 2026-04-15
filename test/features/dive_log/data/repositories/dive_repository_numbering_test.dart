import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Tests for diver-scoped dive numbering.
///
/// Dive numbers are a per-diver lifetime counter. Renumber operations
/// must respect the diver boundary or they corrupt other profiles'
/// numbering when a user has multiple diver profiles.
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiver(String diverId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(diverId),
            name: Value('Diver $diverId'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDive({
    required String id,
    required String diverId,
    required int entryTime,
    int? diveNumber,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: Value(entryTime),
            entryTime: Value(entryTime),
            diveNumber: Value(diveNumber),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<int?> diveNumberFor(String diveId) async {
    final row = await (db.select(
      db.dives,
    )..where((t) => t.id.equals(diveId))).getSingleOrNull();
    return row?.diveNumber;
  }

  group('renumberAllDives with diverId', () {
    test('only renumbers the specified diver\'s dives', () async {
      await insertDiver('alice');
      await insertDiver('bob');

      // Alice: 3 dives with sparse numbers (1, 5, 10)
      await insertDive(
        id: 'alice-1',
        diverId: 'alice',
        entryTime: 1000,
        diveNumber: 1,
      );
      await insertDive(
        id: 'alice-2',
        diverId: 'alice',
        entryTime: 2000,
        diveNumber: 5,
      );
      await insertDive(
        id: 'alice-3',
        diverId: 'alice',
        entryTime: 3000,
        diveNumber: 10,
      );
      // Bob: 2 dives with numbers that must not change
      await insertDive(
        id: 'bob-1',
        diverId: 'bob',
        entryTime: 1500,
        diveNumber: 100,
      );
      await insertDive(
        id: 'bob-2',
        diverId: 'bob',
        entryTime: 2500,
        diveNumber: 200,
      );

      await repository.renumberAllDives(startFrom: 1, diverId: 'alice');

      // Alice's dives become 1, 2, 3 in chronological order.
      expect(await diveNumberFor('alice-1'), 1);
      expect(await diveNumberFor('alice-2'), 2);
      expect(await diveNumberFor('alice-3'), 3);
      // Bob's dives are unchanged.
      expect(await diveNumberFor('bob-1'), 100);
      expect(await diveNumberFor('bob-2'), 200);
    });

    test('without diverId renumbers every dive (legacy behavior)', () async {
      await insertDiver('alice');
      await insertDiver('bob');
      await insertDive(
        id: 'alice-1',
        diverId: 'alice',
        entryTime: 1000,
        diveNumber: 1,
      );
      await insertDive(
        id: 'bob-1',
        diverId: 'bob',
        entryTime: 2000,
        diveNumber: 100,
      );

      await repository.renumberAllDives(startFrom: 1);

      expect(await diveNumberFor('alice-1'), 1);
      expect(await diveNumberFor('bob-1'), 2);
    });
  });

  group('assignMissingDiveNumbers with diverId', () {
    test('starts from the diver\'s own MIN, not the global MIN', () async {
      await insertDiver('alice');
      await insertDiver('bob');

      // Bob's min is 1, Alice's min is 50. Without scoping, Alice would
      // be renumbered from 1.
      await insertDive(
        id: 'bob-1',
        diverId: 'bob',
        entryTime: 500,
        diveNumber: 1,
      );
      await insertDive(
        id: 'alice-1',
        diverId: 'alice',
        entryTime: 1000,
        diveNumber: 50,
      );
      await insertDive(
        id: 'alice-2',
        diverId: 'alice',
        entryTime: 2000,
        diveNumber: null,
      );

      await repository.assignMissingDiveNumbers(diverId: 'alice');

      // Alice starts from her own min (50) and renumbers chronologically.
      expect(await diveNumberFor('alice-1'), 50);
      expect(await diveNumberFor('alice-2'), 51);
      // Bob is untouched.
      expect(await diveNumberFor('bob-1'), 1);
    });
  });

  group('getDiveNumberingInfo with diverId', () {
    test('detects gaps only in that diver\'s sequence', () async {
      await insertDiver('alice');
      await insertDiver('bob');

      // Alice: numbered 1, 2, 4 (missing 3).
      await insertDive(
        id: 'alice-1',
        diverId: 'alice',
        entryTime: 1000,
        diveNumber: 1,
      );
      await insertDive(
        id: 'alice-2',
        diverId: 'alice',
        entryTime: 2000,
        diveNumber: 2,
      );
      await insertDive(
        id: 'alice-3',
        diverId: 'alice',
        entryTime: 3000,
        diveNumber: 4,
      );
      // Bob: his numbers would form noisy global gaps if not scoped.
      await insertDive(
        id: 'bob-1',
        diverId: 'bob',
        entryTime: 1500,
        diveNumber: 500,
      );

      final info = await repository.getDiveNumberingInfo(diverId: 'alice');

      expect(info.totalDives, 3);
      expect(info.hasGaps, isTrue);
      expect(info.gaps.length, 1);
      expect(info.gaps.first.missingStart, 3);
      expect(info.gaps.first.missingEnd, 3);
    });
  });
}

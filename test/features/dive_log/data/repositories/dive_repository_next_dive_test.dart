import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> diver(String id) async {
    final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value(id),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  test('getNextDive returns the earliest dive at or after notBefore', () async {
    await diver('alice');
    await repository.createDive(
      domain.Dive(
        id: 'n1',
        diverId: 'alice',
        dateTime: DateTime.utc(2026, 5, 1, 9),
      ),
    );
    await repository.createDive(
      domain.Dive(
        id: 'n2',
        diverId: 'alice',
        dateTime: DateTime.utc(2026, 5, 1, 11),
        entryTime: DateTime.utc(2026, 5, 1, 11, 2),
      ),
    );
    await repository.createDive(
      domain.Dive(
        id: 'n3',
        diverId: 'alice',
        dateTime: DateTime.utc(2026, 5, 1, 14),
      ),
    );

    final next = await repository.getNextDive(
      diverId: 'alice',
      notBefore: DateTime.utc(2026, 5, 1, 10),
    );
    expect(next?.id, 'n2');
  });

  test('notBefore is inclusive of an exact match', () async {
    await diver('alice');
    await repository.createDive(
      domain.Dive(
        id: 'exact',
        diverId: 'alice',
        dateTime: DateTime.utc(2026, 5, 1, 11),
      ),
    );

    final next = await repository.getNextDive(
      diverId: 'alice',
      notBefore: DateTime.utc(2026, 5, 1, 11),
    );
    expect(next?.id, 'exact');
  });

  test(
    'prefers entryTime over the legacy dateTime when both are set',
    () async {
      // dateTime alone would put this dive before notBefore; entryTime moves
      // its effective start after it, so it should still be picked up.
      await diver('alice');
      await repository.createDive(
        domain.Dive(
          id: 'entry-shifted',
          diverId: 'alice',
          dateTime: DateTime.utc(2026, 5, 1, 8),
          entryTime: DateTime.utc(2026, 5, 1, 12),
        ),
      );

      final next = await repository.getNextDive(
        diverId: 'alice',
        notBefore: DateTime.utc(2026, 5, 1, 9),
      );
      expect(next?.id, 'entry-shifted');
    },
  );

  test('never crosses diver boundaries', () async {
    await diver('bob');
    await repository.createDive(
      domain.Dive(
        id: 'bobs-dive',
        diverId: 'bob',
        dateTime: DateTime.utc(2026, 5, 1, 12),
      ),
    );

    final next = await repository.getNextDive(
      diverId: 'alice',
      notBefore: DateTime.utc(2026, 5, 1, 9),
    );
    expect(next, isNull);
  });

  test('returns null when nothing qualifies', () async {
    await diver('alice');
    await repository.createDive(
      domain.Dive(
        id: 'too-early',
        diverId: 'alice',
        dateTime: DateTime.utc(2026, 5, 1, 9),
      ),
    );

    final next = await repository.getNextDive(
      diverId: 'alice',
      notBefore: DateTime.utc(2026, 5, 1, 10),
    );
    expect(next, isNull);
  });
}

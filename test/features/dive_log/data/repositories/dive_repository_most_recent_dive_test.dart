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

  test(
    'getMostRecentDiveTimes returns the latest dive at or before notAfter',
    () async {
      await diver('alice');
      await repository.createDive(
        domain.Dive(
          id: 'm1',
          diverId: 'alice',
          dateTime: DateTime.utc(2026, 5, 1, 9),
        ),
      );
      await repository.createDive(
        domain.Dive(
          id: 'm2',
          diverId: 'alice',
          dateTime: DateTime.utc(2026, 5, 1, 11),
          entryTime: DateTime.utc(2026, 5, 1, 11, 2),
        ),
      );
      await repository.createDive(
        domain.Dive(
          id: 'm3',
          diverId: 'alice',
          dateTime: DateTime.utc(2026, 5, 1, 14),
        ),
      );

      final mostRecent = await repository.getMostRecentDiveTimes(
        diverId: 'alice',
        notAfter: DateTime.utc(2026, 5, 1, 12),
      );
      expect(mostRecent?.id, 'm2');
    },
  );

  test('notAfter is inclusive of an exact match', () async {
    await diver('alice');
    await repository.createDive(
      domain.Dive(
        id: 'exact',
        diverId: 'alice',
        dateTime: DateTime.utc(2026, 5, 1, 11),
      ),
    );

    final mostRecent = await repository.getMostRecentDiveTimes(
      diverId: 'alice',
      notAfter: DateTime.utc(2026, 5, 1, 11),
    );
    expect(mostRecent?.id, 'exact');
  });

  test(
    'prefers entryTime over the legacy dateTime when both are set',
    () async {
      // dateTime alone would put this dive after notAfter; entryTime moves
      // its effective start before it, so it should still be picked up.
      await diver('alice');
      await repository.createDive(
        domain.Dive(
          id: 'entry-shifted',
          diverId: 'alice',
          dateTime: DateTime.utc(2026, 5, 1, 15),
          entryTime: DateTime.utc(2026, 5, 1, 10),
        ),
      );

      final mostRecent = await repository.getMostRecentDiveTimes(
        diverId: 'alice',
        notAfter: DateTime.utc(2026, 5, 1, 11),
      );
      expect(mostRecent?.id, 'entry-shifted');
    },
  );

  test('excludes planned (not yet executed) dives, even a future one that '
      'would otherwise sort first', () async {
    await diver('alice');
    await repository.createDive(
      domain.Dive(
        id: 'actual',
        diverId: 'alice',
        dateTime: DateTime.utc(2026, 5, 1, 9),
      ),
    );
    await repository.createDive(
      domain.Dive(
        id: 'planned-future',
        diverId: 'alice',
        dateTime: DateTime.utc(2026, 5, 10),
        isPlanned: true,
      ),
    );

    final mostRecent = await repository.getMostRecentDiveTimes(
      diverId: 'alice',
      notAfter: DateTime.utc(2026, 5, 2),
    );
    expect(mostRecent?.id, 'actual');
  });

  test('orders by effective time, not raw entry_time: a newer dive with no '
      'entryTime still outranks an older one that has one', () async {
    await diver('alice');
    await repository.createDive(
      domain.Dive(
        id: 'older-with-entry-time',
        diverId: 'alice',
        dateTime: DateTime.utc(2026, 5, 1, 9),
        entryTime: DateTime.utc(2026, 5, 1, 9, 2),
      ),
    );
    await repository.createDive(
      domain.Dive(
        id: 'newer-no-entry-time',
        diverId: 'alice',
        dateTime: DateTime.utc(2026, 5, 10, 9),
      ),
    );

    final mostRecent = await repository.getMostRecentDiveTimes(
      diverId: 'alice',
      notAfter: DateTime.utc(2026, 5, 11),
    );
    expect(mostRecent?.id, 'newer-no-entry-time');
  });

  test('never crosses diver boundaries', () async {
    await diver('alice');
    await diver('bob');
    await repository.createDive(
      domain.Dive(
        id: 'bobs-dive',
        diverId: 'bob',
        dateTime: DateTime.utc(2026, 5, 1, 12),
      ),
    );

    final mostRecent = await repository.getMostRecentDiveTimes(
      diverId: 'alice',
      notAfter: DateTime.utc(2026, 5, 2),
    );
    expect(mostRecent, isNull);
  });

  test('returns null when nothing qualifies', () async {
    await diver('alice');
    await repository.createDive(
      domain.Dive(
        id: 'too-late',
        diverId: 'alice',
        dateTime: DateTime.utc(2026, 5, 2),
      ),
    );

    final mostRecent = await repository.getMostRecentDiveTimes(
      diverId: 'alice',
      notAfter: DateTime.utc(2026, 5, 1),
    );
    expect(mostRecent, isNull);
  });

  test('breaks a tie on effective start by the higher dive number', () async {
    await diver('alice');
    // Inserted lowest number first, so a tie left to scan order would pick
    // the wrong dive.
    for (final (id, number) in [('first', 1), ('second', 2)]) {
      await repository.createDive(
        domain.Dive(
          id: id,
          diverId: 'alice',
          diveNumber: number,
          dateTime: DateTime.utc(2026, 5, 1, 9),
        ),
      );
    }

    final mostRecent = await repository.getMostRecentDiveTimes(
      diverId: 'alice',
      notAfter: DateTime.utc(2026, 5, 2),
    );
    expect(mostRecent?.id, 'second');
  });

  test(
    'getExecutedDiveTimesInRange skips planned dives and other divers',
    () async {
      await diver('alice');
      await diver('bob');
      await repository.createDive(
        domain.Dive(
          id: 'logged',
          diverId: 'alice',
          dateTime: DateTime.utc(2026, 5, 1, 9),
        ),
      );
      await repository.createDive(
        domain.Dive(
          id: 'planned',
          diverId: 'alice',
          dateTime: DateTime.utc(2026, 5, 2, 9),
          isPlanned: true,
        ),
      );
      await repository.createDive(
        domain.Dive(
          id: 'bobs-dive',
          diverId: 'bob',
          dateTime: DateTime.utc(2026, 5, 1, 10),
        ),
      );

      final dives = await repository.getExecutedDiveTimesInRange(
        DateTime.utc(2026, 4, 28),
        DateTime.utc(2026, 5, 5),
        diverId: 'alice',
      );
      expect(dives.map((d) => d.id), ['logged']);
    },
  );
}

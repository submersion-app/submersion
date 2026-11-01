import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Exposure history reads one diver's dives; the logbook's surface interval
/// still spans them all (#3923).
void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    final now = DateTime.utc(2026).millisecondsSinceEpoch;
    for (final diver in ['alice', 'bob']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: Value(diver),
              name: Value(diver),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> seed(String id, String? diverId, DateTime start) =>
      repository.createDive(
        domain.Dive(
          id: id,
          diverId: diverId,
          dateTime: start,
          entryTime: start,
          runtime: const Duration(minutes: 30),
        ),
      );

  final nine = DateTime.utc(2026, 10, 30, 9);
  final eleven = DateTime.utc(2026, 10, 30, 11);
  final noon = DateTime.utc(2026, 10, 30, 12);

  test('getDiveTimes carries the owner', () async {
    await seed('owned', 'alice', nine);
    await seed('unassigned', null, eleven);

    expect((await repository.getDiveTimes('owned'))?.diverId, 'alice');
    expect((await repository.getDiveTimes('unassigned'))?.diverId, isNull);
  });

  group('getPreviousDiveTimes', () {
    test('sameDiverOnly walks past another diver\'s later dive', () async {
      await seed('alice-prior', 'alice', nine);
      await seed('bob-prior', 'bob', eleven);
      await seed('alice-current', 'alice', noon);

      final own = await repository.getPreviousDiveTimes(
        'alice-current',
        sameDiverOnly: true,
      );

      expect(own?.id, 'alice-prior');
    });

    test(
      'sameDiverOnly finds nothing when only another diver dived before',
      () async {
        await seed('bob-prior', 'bob', eleven);
        await seed('alice-current', 'alice', noon);

        expect(
          await repository.getPreviousDiveTimes(
            'alice-current',
            sameDiverOnly: true,
          ),
          isNull,
        );
      },
    );

    test('by default it is still any diver in the logbook', () async {
      await seed('alice-prior', 'alice', nine);
      await seed('bob-prior', 'bob', eleven);
      await seed('alice-current', 'alice', noon);

      final previous = await repository.getPreviousDiveTimes('alice-current');

      expect(previous?.id, 'bob-prior');
    });

    test('unassigned dives share a history that stays apart from an assigned '
        'diver\'s', () async {
      await seed('solo-prior', null, nine);
      await seed('bob-prior', 'bob', eleven);
      await seed('solo-current', null, noon);
      await seed('bob-current', 'bob', noon.add(const Duration(hours: 1)));

      final solo = await repository.getPreviousDiveTimes(
        'solo-current',
        sameDiverOnly: true,
      );
      final bob = await repository.getPreviousDiveTimes(
        'bob-current',
        sameDiverOnly: true,
      );

      expect(solo?.id, 'solo-prior');
      expect(bob?.id, 'bob-prior');
    });
  });

  group('getSurfaceInterval', () {
    test('sameDiverOnly measures from the diver\'s own last dive', () async {
      await seed('alice-prior', 'alice', nine);
      await seed('bob-prior', 'bob', eleven);
      await seed('alice-current', 'alice', noon);

      expect(
        await repository.getSurfaceInterval(
          'alice-current',
          sameDiverOnly: true,
        ),
        const Duration(hours: 2, minutes: 30),
      );
    });

    test('by default it is still the logbook\'s gap', () async {
      await seed('alice-prior', 'alice', nine);
      await seed('bob-prior', 'bob', eleven);
      await seed('alice-current', 'alice', noon);

      expect(
        await repository.getSurfaceInterval('alice-current'),
        const Duration(minutes: 30),
      );
    });
  });

  group('getDiveTimesInRange', () {
    final start = DateTime.utc(2026, 10, 30);
    final end = DateTime.utc(2026, 10, 31);

    setUp(() async {
      await seed('alice-dive', 'alice', nine);
      await seed('bob-dive', 'bob', eleven);
      await seed('solo-dive', null, noon);
    });

    test('keeps the named diver\'s dives', () async {
      final dives = await repository.getDiveTimesInRange(
        start,
        end,
        diverId: 'alice',
      );

      expect(dives.map((d) => d.id), ['alice-dive']);
    });

    test('a null diver means the unassigned dives, not every diver', () async {
      final dives = await repository.getDiveTimesInRange(
        start,
        end,
        diverId: null,
      );

      expect(dives.map((d) => d.id), ['solo-dive']);
    });
  });
}

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// The bounded lookup behind the planner's Follow prompt (issue #4250): the
/// logged dive that ended last inside a window, read without loading the
/// diver's whole log.
void main() {
  late AppDatabase db;
  late DiveRepository repository;

  // Dive times are wall clock stored as UTC.
  final now = DateTime.utc(2026, 11, 7, 12);
  final endedAfter = now.subtract(const Duration(hours: 48));

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> diver(String id) async {
    final stamp = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value(id),
            createdAt: Value(stamp),
            updatedAt: Value(stamp),
          ),
        );
  }

  Future<void> dive(
    String id,
    DateTime start, {
    Duration? runtime = const Duration(minutes: 45),
    Duration? bottomTime,
    DateTime? exitTime,
    bool isPlanned = false,
    String? diverId,
  }) => repository.createDive(
    domain.Dive(
      id: id,
      diverId: diverId,
      dateTime: start,
      entryTime: start,
      exitTime: exitTime,
      runtime: runtime,
      bottomTime: bottomTime,
      isPlanned: isPlanned,
    ),
  );

  Future<String?> latest({String? diverId}) async =>
      (await repository.getLatestEndedDive(
        diverId: diverId,
        endedAfter: endedAfter,
        notAfter: now,
      ))?.id;

  test('picks the dive that ended last inside the window', () async {
    await dive('older', now.subtract(const Duration(hours: 30)));
    await dive('newer', now.subtract(const Duration(hours: 5)));
    await dive('ancient', now.subtract(const Duration(days: 30)));

    expect(await latest(), 'newer');
  });

  test('of two dives ending together, picks the later start', () async {
    final end = now.subtract(const Duration(hours: 5));
    await dive(
      'long',
      end.subtract(const Duration(minutes: 60)),
      exitTime: end,
    );
    await dive(
      'short',
      end.subtract(const Duration(minutes: 30)),
      exitTime: end,
    );

    expect(await latest(), 'short');
  });

  test('is null when the newest dive ended 48 hours ago or more', () async {
    await dive(
      'edge',
      now.subtract(const Duration(hours: 48, minutes: 45)),
      runtime: const Duration(minutes: 45),
    );
    await dive('ancient', now.subtract(const Duration(days: 30)));

    expect(await latest(), isNull);
  });

  test('is null for an empty log', () async {
    expect(await latest(), isNull);
  });

  test('passes over a planned dive', () async {
    await dive('logged', now.subtract(const Duration(hours: 20)));
    await dive(
      'planned',
      now.subtract(const Duration(hours: 2)),
      isPlanned: true,
    );

    expect(await latest(), 'logged');
  });

  test('passes over a dive that ends in the future', () async {
    await dive('logged', now.subtract(const Duration(hours: 20)));
    await dive('future', now.add(const Duration(days: 2)));
    // Started before now but still under water at now.
    await dive(
      'underway',
      now.subtract(const Duration(minutes: 10)),
      runtime: const Duration(minutes: 45),
    );

    expect(await latest(), 'logged');
  });

  test('a recorded exit time decides when the dive ended', () async {
    final start = now.subtract(const Duration(hours: 10));
    // Its runtime says it ended long before 'b', its exit time says after.
    await dive(
      'a',
      start,
      runtime: const Duration(minutes: 10),
      exitTime: start.add(const Duration(hours: 2)),
    );
    await dive('b', start.add(const Duration(minutes: 30)));

    expect(await latest(), 'a');
  });

  test('a dive with only a bottom time ends after it', () async {
    final start = now.subtract(const Duration(hours: 10));
    await dive(
      'bottom',
      start,
      runtime: null,
      bottomTime: const Duration(hours: 2),
    );
    await dive('b', start.add(const Duration(minutes: 30)));

    expect(await latest(), 'bottom');
  });

  test('a dive with no duration ends when it started', () async {
    final start = now.subtract(const Duration(hours: 10));
    await dive('bare', start, runtime: null);
    // Ends 15 minutes before 'bare' starts.
    await dive('b', start.subtract(const Duration(hours: 1)));

    expect(await latest(), 'bare');
  });

  test('a long dive that started before the window still counts', () async {
    await dive(
      'long',
      now.subtract(const Duration(hours: 50)),
      runtime: const Duration(hours: 4),
    );

    expect(await latest(), 'long');
  });

  test(
    'a dive that started more than a day before the window is not read',
    () async {
      // Ends inside the window, but its start is before the bounded range.
      await dive(
        'marathon',
        now.subtract(const Duration(hours: 73)),
        runtime: const Duration(hours: 30),
      );

      expect(await latest(), isNull);
    },
  );

  test('reads only the diver asked for, and every diver for none', () async {
    await diver('alice');
    await diver('bob');
    await dive(
      'alice-dive',
      now.subtract(const Duration(hours: 20)),
      diverId: 'alice',
    );
    await dive(
      'bob-dive',
      now.subtract(const Duration(hours: 2)),
      diverId: 'bob',
    );

    expect(await latest(diverId: 'alice'), 'alice-dive');
    expect(await latest(diverId: 'carol'), isNull);
    expect(await latest(), 'bob-dive');
  });

  test('a failed read is thrown, not taken for no recent dive', () async {
    await dive('logged', now.subtract(const Duration(hours: 3)));
    // The lookup's runtime chain reads the series table.
    await db.customStatement('DROP TABLE dive_profile_series');

    await expectLater(
      repository.getLatestEndedDive(endedAfter: endedAfter, notAfter: now),
      throwsA(anything),
    );
  });

  test('returns the dive read without its samples', () async {
    await dive('named', now.subtract(const Duration(hours: 3)));
    final found = await repository.getLatestEndedDive(
      endedAfter: endedAfter,
      notAfter: now,
    );

    expect(found?.runtime, const Duration(minutes: 45));
    expect(found?.entryTime, now.subtract(const Duration(hours: 3)));
  });

  // A downloaded dive often has no runtime and no water temperature, which
  // sends a full read through its samples.
  test('a dive only its profile measures ends with it, and decodes no '
      'sample', () async {
    final start = now.subtract(const Duration(hours: 10));
    await repository.createDive(
      domain.Dive(
        id: 'profiled',
        dateTime: start,
        entryTime: start,
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: 1800, depth: 20),
          domain.DiveProfilePoint(timestamp: 3600, depth: 0),
        ],
      ),
    );
    // Ends half an hour after 'profiled' starts, so before it by its span.
    await dive('earlier', start.subtract(const Duration(minutes: 15)));

    final found = await repository.getLatestEndedDive(
      endedAfter: endedAfter,
      notAfter: now,
    );

    expect(found?.id, 'profiled');
    expect(found?.profile, isEmpty);
    expect(found?.measuredRuntime, const Duration(hours: 1));
  });
}

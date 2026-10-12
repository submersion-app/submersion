import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Run time per dive for Insights (issue #3059).
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late InsightsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    repository = InsightsRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  DateTime day(int d) => DateTime.utc(2025, 3, d, 9);

  test('reads the recorded runtime in minutes, ordered by date', () async {
    await dives.createDive(
      domain.Dive(
        id: 'b',
        dateTime: day(2),
        runtime: const Duration(minutes: 62),
        bottomTime: const Duration(minutes: 50),
      ),
    );
    await dives.createDive(
      domain.Dive(
        id: 'a',
        dateTime: day(1),
        runtime: const Duration(minutes: 45, seconds: 30),
      ),
    );

    final points = await repository.getRuntimePerDive();

    expect(points.map((p) => p.diveId), ['a', 'b']);
    expect(points[0].value, closeTo(45.5, 1e-9));
    expect(points[1].value, closeTo(62, 1e-9));
    expect(points[0].date, day(1));
  });

  test('falls back to exit minus entry, then to the profile span', () async {
    await dives.createDive(
      domain.Dive(
        id: 'timestamps',
        dateTime: day(1),
        entryTime: day(1),
        exitTime: day(1).add(const Duration(minutes: 48)),
      ),
    );
    await dives.createDive(
      domain.Dive(
        id: 'profile',
        dateTime: day(2),
        profile: [
          for (var t = 0; t <= 2400; t += 10)
            domain.DiveProfilePoint(
              timestamp: t,
              depth: t == 0 || t == 2400 ? 0 : 15,
            ),
        ],
      ),
    );

    final points = await repository.getRuntimePerDive();

    expect(points.map((p) => p.diveId), ['timestamps', 'profile']);
    expect(points[0].value, closeTo(48, 1e-9));
    expect(points[1].value, closeTo(40, 1e-9));
  });

  test('never substitutes bottom time: a dive with only a bottom time is '
      'absent', () async {
    await dives.createDive(
      domain.Dive(
        id: 'table-era',
        dateTime: day(1),
        bottomTime: const Duration(minutes: 35),
      ),
    );
    await dives.createDive(domain.Dive(id: 'nothing', dateTime: day(2)));

    expect(await repository.getRuntimePerDive(), isEmpty);
  });

  test('a zero runtime is not a run time', () async {
    await dives.createDive(
      domain.Dive(id: 'zero', dateTime: day(1), runtime: Duration.zero),
    );

    expect(await repository.getRuntimePerDive(), isEmpty);
  });

  test('follows the diver and the Insights filter', () async {
    for (final id in ['me', 'them']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: Value(id),
              name: Value(id),
              medicalNotes: const Value(''),
              notes: const Value(''),
              isDefault: const Value(false),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
    await dives.createDive(
      domain.Dive(
        id: 'mine',
        dateTime: day(1),
        diverId: 'me',
        runtime: const Duration(minutes: 40),
      ),
    );
    await dives.createDive(
      domain.Dive(
        id: 'theirs',
        dateTime: day(2),
        diverId: 'them',
        runtime: const Duration(minutes: 50),
      ),
    );
    await dives.createDive(
      domain.Dive(
        id: 'excluded',
        dateTime: day(3),
        diverId: 'me',
        runtime: const Duration(minutes: 60),
        excludedFromStats: true,
      ),
    );
    await dives.createDive(
      domain.Dive(
        id: 'late',
        dateTime: day(20),
        diverId: 'me',
        runtime: const Duration(minutes: 70),
      ),
    );

    final mine = await repository.getRuntimePerDive(diverId: 'me');
    expect(mine.map((p) => p.diveId), ['mine', 'late']);

    final early = await repository.getRuntimePerDive(
      diverId: 'me',
      filter: DiveFilterState(endDate: day(10)),
    );
    expect(early.map((p) => p.diveId), ['mine']);
  });
}

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/presentation/providers/trip_day_picker_providers.dart';

import '../../../../helpers/test_database.dart';

/// The two reads behind the trip day picker, on a real database: which of a
/// trip's dives are plans nobody has dived, and when a dive's stored profile
/// may have changed. Widget tests stand in for both, so this is where their
/// own wiring is run.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  /// Longer than the repositories' 300 ms change-tick debounce.
  const settle = Duration(milliseconds: 450);

  /// Inserts a dive the way the app's own writes do: through Drift, naming
  /// the table, so the change streams hear it. A bare statement would not
  /// tick.
  Future<void> dive(String id, {bool planned = false}) => db.customInsert(
    'INSERT INTO dives (id, dive_date_time, trip_id, is_planned, is_draft, '
    'created_at, updated_at) VALUES (?, 0, ?, ?, 0, 0, 0)',
    variables: [
      Variable.withString(id),
      Variable.withString('t1'),
      Variable.withInt(planned ? 1 : 0),
    ],
    updates: {db.dives},
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO trips (id, name, start_date, end_date, created_at, '
      "updated_at) VALUES ('t1', 't1', 0, 0, 0, 0)",
    );
    container = ProviderContainer();
    addTearDown(container.dispose);
  });
  tearDown(tearDownTestDatabase);

  group('tripUndivedPlanIdsProvider', () {
    test('names the trip\'s plans nobody has dived', () async {
      await dive('logged');
      await dive('plan', planned: true);

      expect(await container.read(tripUndivedPlanIdsProvider('t1').future), {
        'plan',
      });
    });

    test('reads again after a dive is written', () async {
      await dive('plan', planned: true);
      // Kept listened to, as the trip page keeps it: unwatched, the provider
      // is dropped and the next read would be a fresh one whatever it heard.
      final sub = container.listen(tripUndivedPlanIdsProvider('t1'), (_, _) {});
      addTearDown(sub.close);
      expect(await container.read(tripUndivedPlanIdsProvider('t1').future), {
        'plan',
      });

      await dive('second', planned: true);
      await Future<void>.delayed(settle);

      expect(await container.read(tripUndivedPlanIdsProvider('t1').future), {
        'plan',
        'second',
      });
    });
  });

  group('tripProfileWritesProvider', () {
    /// Writes a dive's profile samples, as a download or an import does.
    Future<void> profile(String id, String diveId) => db.customInsert(
      'INSERT INTO dive_profile_series (id, dive_id, sample_count, '
      'start_timestamp, end_timestamp, max_depth, first_depth, last_depth, '
      'codec_version, samples, created_at, updated_at) '
      "VALUES (?, ?, 0, 0, 0, 0, 0, 0, 1, x'', 0, 0)",
      variables: [Variable.withString(id), Variable.withString(diveId)],
      updates: {db.diveProfileSeries},
    );

    late List<int> counts;

    setUp(() {
      counts = [];
      final sub = container.listen(tripProfileWritesProvider, (_, next) {
        final count = next.value;
        if (count != null) counts.add(count);
      }, fireImmediately: true);
      addTearDown(sub.close);
    });

    test('counts up on each write of a stored profile', () async {
      await dive('first');
      await Future<void>.delayed(settle);
      counts.clear();

      await profile('s1', 'first');
      await Future<void>.delayed(settle);
      expect(counts, [1]);

      // A different number each time: the same value twice would notify
      // nobody, and the trip story would not ask for its profiles again.
      await profile('s2', 'first');
      await Future<void>.delayed(settle);
      expect(counts, [1, 2]);
    });

    test('a dive edited without its profile does not count', () async {
      await dive('first');
      await dive('second');
      await Future<void>.delayed(settle);

      // Each count sends the trip story back to the database for every dive
      // it holds no samples for; an edit to a dive's notes must not.
      expect(counts, isEmpty);
    });
  });
}

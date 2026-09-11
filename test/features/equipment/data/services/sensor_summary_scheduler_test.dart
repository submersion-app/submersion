import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_worker.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final visited = <String>[];

  setUp(() async {
    db = await setUpTestDatabase();
    visited.clear();
    SensorSummaryScheduler.enabled = true;
    SensorSummaryScheduler.instance.repositoryFactory = () =>
        DiveSensorSummaryRepository(
          db: db,
          runner: (input) async {
            visited.add(input.diveId);
            return computeSensorSummaryFromBlobs(input);
          },
        );
    addTearDown(() {
      SensorSummaryScheduler.enabled = false;
      SensorSummaryScheduler.instance.repositoryFactory =
          SensorSummaryScheduler.defaultRepositoryFactory;
    });
    for (final (id, date) in [('d1', 1000), ('d2', 2000)]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: date,
              createdAt: date,
              updatedAt: date,
            ).copyWith(runtime: const Value(600)),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test('schedule refreshes the given dives once, merging bursts', () async {
    scheduleSensorSummaryRefresh(['d1']);
    scheduleSensorSummaryRefresh(['d1', 'd2']);
    await SensorSummaryScheduler.instance.idle;
    expect(visited.toSet(), {'d1', 'd2'});
    expect(visited.length, lessThanOrEqualTo(3));
  });

  test('a scheduled dive that is already current is not recomputed', () async {
    scheduleSensorSummaryRefresh(['d1']);
    await SensorSummaryScheduler.instance.idle;
    scheduleSensorSummaryRefresh(['d1']);
    await SensorSummaryScheduler.instance.idle;
    expect(visited, ['d1']);
  });

  test('scheduleStaleSweep visits every stale dive', () async {
    SensorSummaryScheduler.instance.scheduleStaleSweep();
    await SensorSummaryScheduler.instance.idle;
    expect(visited, ['d1', 'd2']);
  });

  test('disabled means no work', () async {
    SensorSummaryScheduler.enabled = false;
    scheduleSensorSummaryRefresh(['d1']);
    SensorSummaryScheduler.instance.scheduleStaleSweep();
    await SensorSummaryScheduler.instance.idle;
    expect(visited, isEmpty);
  });

  test('a failing repository factory does not poison the queue', () async {
    // The queue is one chained future. An error escaping the callback
    // leaves _tail completed with it, and every later schedule chains onto
    // a failed future and never runs: the scheduler is dead until restart.
    var broken = true;
    SensorSummaryScheduler.instance.repositoryFactory = () {
      if (broken) throw StateError('database not initialized');
      return DiveSensorSummaryRepository(
        db: db,
        runner: (input) async {
          visited.add(input.diveId);
          return computeSensorSummaryFromBlobs(input);
        },
      );
    };

    scheduleSensorSummaryRefresh(['d1']);
    await SensorSummaryScheduler.instance.idle;
    expect(visited, isEmpty);

    broken = false;
    scheduleSensorSummaryRefresh(['d2']);
    await SensorSummaryScheduler.instance.idle;
    expect(visited, ['d2']);
  });

  test('a failing dive does not poison the queue', () async {
    SensorSummaryScheduler.instance.repositoryFactory = () =>
        DiveSensorSummaryRepository(
          db: db,
          runner: (input) async {
            visited.add(input.diveId);
            if (input.diveId == 'd1') throw StateError('boom');
            return computeSensorSummaryFromBlobs(input);
          },
        );
    scheduleSensorSummaryRefresh(['d1']);
    scheduleSensorSummaryRefresh(['d2']);
    await SensorSummaryScheduler.instance.idle;
    expect(visited, containsAll(['d1', 'd2']));
  });
}

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_worker.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_sweep.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  final visited = <String>[];
  var failOn = <String>{};

  setUp(() async {
    db = await setUpTestDatabase();
    visited.clear();
    failOn = {};
    container = ProviderContainer(
      overrides: [
        diveSensorSummaryRepositoryProvider.overrideWithValue(
          DiveSensorSummaryRepository(
            db: db,
            runner: (input) async {
              visited.add(input.diveId);
              if (failOn.contains(input.diveId)) {
                throw StateError('boom ${input.diveId}');
              }
              return computeSensorSummaryFromBlobs(input);
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    for (final (id, date) in [('d1', 1000), ('d2', 2000), ('d3', 3000)]) {
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

  EquipmentConditionSweep sweep() =>
      container.read(equipmentConditionSweepProvider);

  test('visits stale dives oldest first and reports progress', () async {
    final progress = <(int, int)>[];
    final result = await sweep().run(
      onProgress: (done, total) => progress.add((done, total)),
    );
    expect(visited, ['d1', 'd2', 'd3']);
    expect(result.swept, 3);
    expect(result.failed, 0);
    expect(result.cancelled, isFalse);
    expect(progress, [(0, 3), (1, 3), (2, 3), (3, 3)]);
  });

  test('a second pass without force visits nothing', () async {
    await sweep().run();
    visited.clear();
    final result = await sweep().run();
    expect(visited, isEmpty);
    expect(result.swept, 0);
  });

  test('force visits every dive again', () async {
    await sweep().run();
    visited.clear();
    final result = await sweep().run(force: true);
    expect(visited, ['d1', 'd2', 'd3']);
    expect(result.swept, 3);
  });

  test('explicit dive ids are visited as given', () async {
    final result = await sweep().run(diveIds: ['d3', 'd1']);
    expect(visited, ['d3', 'd1']);
    expect(result.swept, 2);
  });

  test('a failing dive is counted and does not stop the sweep', () async {
    failOn = {'d2'};
    final result = await sweep().run();
    expect(visited, ['d1', 'd2', 'd3']);
    expect(result.swept, 3);
    expect(result.failed, 1);
  });

  test('cancel is polled before each dive', () async {
    var calls = 0;
    final result = await sweep().run(isCancelled: () => ++calls > 2);
    expect(visited, ['d1', 'd2']);
    expect(result.swept, 2);
    expect(result.cancelled, isTrue);
  });

  test('scopes to a diver', () async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'a',
            name: 'a',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await (db.update(db.dives)..where((t) => t.id.equals('d2'))).write(
      const DivesCompanion(diverId: Value('a')),
    );
    final result = await sweep().run(diverId: 'a');
    expect(visited, ['d2']);
    expect(result.swept, 1);
  });
}

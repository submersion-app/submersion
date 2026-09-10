import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_worker.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_sweep.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late MockSettingsNotifier settings;
  final visited = <String>[];
  var failOn = <String>{};

  setUp(() async {
    db = await setUpTestDatabase();
    visited.clear();
    failOn = {};
    settings = MockSettingsNotifier();
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
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

  Future<void> addEquipment(String id, {bool active = true}) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'regulator',
          createdAt: 1,
          updatedAt: 1,
        ).copyWith(isActive: Value(active)),
      );

  EquipmentFindingsRepository findings() => EquipmentFindingsRepository(db: db);

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

  test('the findings pass writes a marker for every active item', () async {
    await addEquipment('reg');
    await addEquipment('old', active: false);
    final progress = <(int, int)>[];
    final result = await sweep().run(
      onProgress: (done, total) => progress.add((done, total)),
    );
    expect(await findings().getReview('reg'), isNotNull);
    expect(await findings().getReview('old'), isNull);
    expect(result.swept, 3);
    expect(result.items, 1);
    expect(result.itemsFailed, 0);
    // Items count after dives in one progress bar.
    expect(progress.first, (0, 4));
    expect(progress.last, (4, 4));
  });

  test('findings: false skips the pass', () async {
    await addEquipment('reg');
    final result = await sweep().run(findings: false);
    expect(await findings().getReview('reg'), isNull);
    expect(result.items, 0);
  });

  test('the master toggle off skips the pass', () async {
    await addEquipment('reg');
    await settings.setConditionEngineEnabled(false);
    final result = await sweep().run();
    expect(await findings().getReview('reg'), isNull);
    expect(result.items, 0);
  });

  test('cancel is polled before each item too', () async {
    await addEquipment('reg');
    await addEquipment('reg2');
    var calls = 0;
    // Three dives pass, the first item runs, the second is cut off.
    final result = await sweep().run(isCancelled: () => ++calls > 4);
    expect(result.swept, 3);
    expect(result.items, 1);
    expect(result.cancelled, isTrue);
    expect(await findings().getReview('reg2'), isNull);
  });
}

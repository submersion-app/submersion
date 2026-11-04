import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/tools/apply_changes_tool.dart';
import 'package:submersion/features/agent_access/data/writes/change_set.dart';
import 'package:submersion/features/agent_access/data/writes/write_applier.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan_store.dart';
import 'package:submersion/features/agent_access/data/writes/write_planner.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/agent_access/domain/write_confirmer.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';

class _Allow implements WriteConfirmer {
  @override
  Future<bool> confirm(WriteConfirmation request) async => true;
}

void main() {
  late AppDatabase db;
  late WritePlanStore store;
  late ApplyChangesTool tool;
  late AgentToolContext context;
  late WriteCatalog writes;
  late RecordRepositories repositories;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await seedTwoDivers(db);
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diverId: const Value(kDiverA),
            diveDateTime: 1710408600000,
            createdAt: kSeedTime,
            updatedAt: kSeedTime,
          ),
        );
    repositories = RecordRepositories();
    writes = WriteCatalog(repositories);
    store = WritePlanStore();
    tool = ApplyChangesTool(
      store: store,
      applier: WriteApplier(
        catalog: writes,
        changeLog: ChangeLogRepository(),
        confirmer: _Allow(),
        confirmEnabled: () => true,
        afterDiveWrites: (_) {},
      ),
    );
    context = AgentToolContext(db: db, clientName: 'test');
  });

  tearDown(() => tearDownTestDatabase());

  Future<String> planned() async {
    final plan =
        await WritePlanner(
          writes: writes,
          records: RecordCatalog(repositories),
        ).preview(
          db,
          ChangeSet.parse({
            'label': 'Tidy',
            'operations': [
              {
                'op': 'update',
                'entity': 'dives',
                'id': 'd1',
                'fields': {'notes': 'x'},
              },
            ],
          }),
          resolveDiver: (id) async => id ?? kDiverA,
        );
    store.put(plan);
    return plan.id;
  }

  test('applies a stored plan and reports the operations', () async {
    final out = await tool.call({'plan_id': await planned()}, context);

    expectWireResult(out);
    expect(
      (out['operations']! as List).single,
      containsPair('diver_id', kDiverA),
    );
    expect(out['counts'], {
      'by_entity': {'dives': 1},
      'by_diver': {kDiverA: 1},
    });
  });

  test('a plan is single use', () async {
    final id = await planned();
    await tool.call({'plan_id': id}, context);

    expect(
      () => tool.call({'plan_id': id}, context),
      throwsA(
        isA<AgentToolException>().having(
          (e) => e.code,
          'code',
          AgentToolErrorCode.planNotFound,
        ),
      ),
    );
  });

  test('an expired plan is refused', () async {
    final clockStore = WritePlanStore(
      clock: () => DateTime.now().add(const Duration(hours: 1)),
    );
    final late = ApplyChangesTool(
      store: clockStore,
      applier: WriteApplier(
        catalog: writes,
        changeLog: ChangeLogRepository(),
        confirmer: _Allow(),
        confirmEnabled: () => false,
        afterDiveWrites: (_) {},
      ),
    );
    final id = await planned();
    clockStore.put(store.take(id));

    expect(
      () => late.call({'plan_id': id}, context),
      throwsA(
        isA<AgentToolException>().having(
          (e) => e.code,
          'code',
          AgentToolErrorCode.planExpired,
        ),
      ),
    );
  });

  test('a missing plan_id is refused', () {
    expect(
      () => tool.call({}, context),
      throwsA(
        isA<AgentToolException>().having(
          (e) => e.code,
          'code',
          AgentToolErrorCode.invalidArgument,
        ),
      ),
    );
  });
}

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/tools/revert_operation_tool.dart';
import 'package:submersion/features/agent_access/data/writes/change_set.dart';
import 'package:submersion/features/agent_access/data/writes/write_applier.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_planner.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/agent_access/domain/write_confirmer.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';

class _Allow implements WriteConfirmer {
  @override
  Future<bool> confirm(WriteConfirmation request) async => true;
}

void main() {
  late AppDatabase db;
  late RecordHarness h;
  late RecordRepositories repositories;
  late WriteCatalog writes;
  late ChangeLogRepository changeLog;
  late RevertOperationTool tool;
  late AgentToolContext context;

  Future<void> dive(String id, {String owner = kDiverA}) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(owner),
          diveDateTime: 1710408600000,
          createdAt: kSeedTime,
          updatedAt: kSeedTime,
          notes: const Value('seeded'),
        ),
      );

  Future<List<String>> apply(List<Map<String, Object?>> operations) async {
    final plan =
        await WritePlanner(
          writes: writes,
          records: RecordCatalog(repositories),
        ).preview(
          db,
          ChangeSet.parse({'label': 'Tidy', 'operations': operations}),
          resolveDiver: (id) async => id ?? kDiverA,
        );
    final result = await WriteApplier(
      catalog: writes,
      changeLog: changeLog,
      confirmer: _Allow(),
      confirmEnabled: () => false,
      afterDiveWrites: (_) {},
    ).apply(db, plan);
    return [for (final o in result.operations) o.operationId];
  }

  Map<String, Object?> note(String id, String text) => {
    'op': 'update',
    'entity': 'dives',
    'id': id,
    'fields': {'notes': text},
  };

  Future<String?> notes(String id) async =>
      (await h.one('dives', id))?['notes'] as String?;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = RecordHarness(db);
    await seedTwoDivers(db);
    repositories = RecordRepositories();
    writes = WriteCatalog(repositories);
    changeLog = ChangeLogRepository();
    tool = RevertOperationTool(
      revert: ChangeLogRevertService(
        repository: changeLog,
        afterDiveWrites: (_) {},
      ),
      changeLog: changeLog,
    );
    context = AgentToolContext(db: db, clientName: 'test');
    await dive('d1');
  });

  tearDown(() => tearDownTestDatabase());

  test('an applied update reverts to the old values', () async {
    final ids = await apply([note('d1', 'agent')]);

    final out = await tool.call({'operation_id': ids.single}, context);

    expectWireResult(out);
    expect(await notes('d1'), 'seeded');
    expect(out['reverted'], greaterThan(0));
    expect(out['kept'], 0);
    expect(out['operation_id'], isNotNull);
  });

  test('an applied delete brings the dive back with its tanks', () async {
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank-1', diveId: 'd1'));
    final ids = await apply([
      {'op': 'delete', 'entity': 'dives', 'id': 'd1'},
    ]);
    expect(await notes('d1'), isNull);

    await tool.call({'operation_id': ids.single}, context);

    final doc = await h.one('dives', 'd1', include: ['tanks']);
    expect(doc!['notes'], 'seeded');
    expect((doc['tanks']! as List).single, containsPair('id', 'tank-1'));
  });

  test('an applied create is removed', () async {
    final ids = await apply([
      {
        'op': 'create',
        'entity': 'buddies',
        'fields': {'name': 'Rui'},
      },
    ]);
    final row = await db.select(db.buddies).getSingle();

    await tool.call({'operation_id': ids.single}, context);

    expect(await h.one('buddies', row.id), isNull);
  });

  test('a record changed since is kept by default', () async {
    final ids = await apply([note('d1', 'agent')]);
    await repositories.dives.bulkAppendNotes(['d1'], 'diver');
    await changeLog.settleAll();

    final out = await tool.call({'operation_id': ids.single}, context);

    expect(await notes('d1'), contains('diver'));
    expect(out['kept'], greaterThan(0));
    expect(
      (out['kept_items']! as List).first,
      allOf(
        containsPair('id', 'd1'),
        containsPair('table', 'dives'),
        containsPair('changed_since', true),
      ),
    );
  });

  test('include_changed_since reverts it too', () async {
    final ids = await apply([note('d1', 'agent')]);
    await repositories.dives.bulkAppendNotes(['d1'], 'diver');
    await changeLog.settleAll();

    await tool.call({
      'operation_id': ids.single,
      'include_changed_since': true,
    }, context);

    expect(await notes('d1'), 'seeded');
  });

  test('an unknown operation is not_found', () {
    expect(
      () => tool.call({'operation_id': 'nope'}, context),
      throwsA(
        isA<AgentToolException>().having(
          (e) => e.code,
          'code',
          AgentToolErrorCode.notFound,
        ),
      ),
    );
  });

  test('an operation already reverted is refused', () async {
    final ids = await apply([note('d1', 'agent')]);
    await tool.call({'operation_id': ids.single}, context);

    expect(
      () => tool.call({'operation_id': ids.single}, context),
      throwsA(
        isA<AgentToolException>().having(
          (e) => e.code,
          'code',
          AgentToolErrorCode.invalidArgument,
        ),
      ),
    );
  });

  test('a split operation id reverts one diver', () async {
    await dive('d2', owner: kDiverB);
    final ids = await apply([note('d1', 'a'), note('d2', 'b')]);
    expect(ids, hasLength(2));
    final split = ids.firstWhere((id) => id.contains(':'));
    final owner = split.split(':').last;
    final (reverted, kept) = owner == kDiverB ? ('d2', 'd1') : ('d1', 'd2');

    await tool.call({'operation_id': split}, context);

    final doc = await h.one('dives', reverted, diverId: owner);
    expect(doc!['notes'], 'seeded');
    final other = owner == kDiverB ? kDiverA : kDiverB;
    expect(
      (await h.one('dives', kept, diverId: other))!['notes'],
      isNot('seeded'),
    );
  });

  test('an operation of another source can be reverted', () async {
    await changeLog.settleAll();
    late String id;
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.manual,
      label: 'bulk_edit',
      body: () async {
        id = ChangeLogScope.currentOperationId!;
        await repositories.dives.bulkAppendNotes(['d1'], 'diver');
      },
    );

    await tool.call({'operation_id': id}, context);

    expect(await notes('d1'), 'seeded');
  });

  test('a missing operation_id is refused', () {
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

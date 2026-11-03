import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/tools/preview_changes_tool.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan_store.dart';
import 'package:submersion/features/agent_access/data/writes/write_planner.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';

void main() {
  late AppDatabase db;
  late WritePlanStore store;
  late PreviewChangesTool tool;
  late AgentToolContext context;

  setUp(() async {
    db = await setUpTestDatabase();
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
    final repositories = RecordRepositories();
    store = WritePlanStore();
    final writes = WriteCatalog(repositories);
    tool = PreviewChangesTool(
      loader: DiverContextLoader(
        db: () => db,
        divers: DiverRepository(),
        settings: DiverSettingsRepository(),
        localeTag: 'en',
        activeDiverId: () async => kDiverA,
      ),
      planner: WritePlanner(
        writes: writes,
        records: RecordCatalog(repositories),
      ),
      store: store,
      writes: writes,
    );
    context = AgentToolContext(db: db, clientName: 'Test Client');
  });

  tearDown(() => tearDownTestDatabase());

  Map<String, Object?> args(String id) => {
    'label': 'Tidy',
    'operations': [
      {
        'op': 'update',
        'entity': 'dives',
        'id': id,
        'fields': {'water_temp_c': 24.5},
      },
    ],
  };

  test('stores an applicable plan under the id it returns', () async {
    final out = await tool.call(args('d1'), context);

    expectWireResult(out);
    final plan = store.take(out['plan_id']! as String);
    expect(plan.clientName, 'Test Client');
    expect(plan.label, 'Tidy');
  });

  test('stores nothing for a blocked plan', () async {
    final out = await tool.call(args('nope'), context);

    expect(out['applicable'], isFalse);
    expect(store.length, 0);
  });

  test('an unknown profile on a create is refused', () async {
    expect(
      () => tool.call({
        'label': 'Tidy',
        'operations': [
          {
            'op': 'create',
            'entity': 'buddies',
            'diver_id': 'nobody',
            'fields': {'name': 'Rui'},
          },
        ],
      }, context),
      throwsA(
        isA<AgentToolException>().having(
          (e) => e.code,
          'code',
          AgentToolErrorCode.unknownDiver,
        ),
      ),
    );
  });

  test('its schema requires a label and operations', () {
    expect(tool.inputSchema['required'], ['label', 'operations']);
    expect(tool.description, contains('apply_changes'));
    expect(tool.description, contains('dives'));
  });

  test('says how a record that belongs to a dive is created', () {
    expect(
      tool.description,
      contains(
        'Each dive_tanks, dive_weights, sightings record belongs to one '
        'record of dives: a create names it in dive_id',
      ),
    );
  });
}

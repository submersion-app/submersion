import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/tools/query_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';

void main() {
  late AppDatabase db;
  const t = kSeedTime;
  QueryTool tool() => QueryTool(
    loader: DiverContextLoader(
      db: () => db,
      divers: DiverRepository(),
      settings: DiverSettingsRepository(),
      localeTag: 'en',
      activeDiverId: () async => kDiverA,
    ),
    catalog: RecordCatalog(RecordRepositories()),
  );

  AgentToolContext ctx() => AgentToolContext(db: db, clientName: 'test');

  /// Gear whose only clock ran out years ago: a 30 day interval from a
  /// purchase in 2023.
  Future<void> overdueItem(String id, String owner) async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'regulator',
            createdAt: t,
            updatedAt: t,
            diverId: Value(owner),
            purchaseDate: const Value(t),
          ),
        );
    await db
        .into(db.serviceSchedules)
        .insert(
          ServiceSchedulesCompanion.insert(
            id: 'sch-$id',
            equipmentId: id,
            serviceKindId: 'annual',
            intervalDays: const Value(30),
            createdAt: t,
            updatedAt: t,
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await seedTwoDivers(db);
    await db
        .into(db.serviceKinds)
        .insert(
          ServiceKindsCompanion.insert(
            id: 'annual',
            name: 'Annual',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  test('serviceDue answers for the active diver', () async {
    await overdueItem('mine', kDiverA);
    final out = await tool().call({
      'root': 'equipment',
      'query': 'serviceDue = overdue',
    }, ctx());
    expect(out['ids'], ['mine']);
  });

  test('serviceDue answers for a named non-active diver', () async {
    await overdueItem('theirs', kDiverB);
    final out = await tool().call({
      'root': 'equipment',
      'query': 'serviceDue = overdue',
      'diver_id': kDiverB,
    }, ctx());
    expect(out['ids'], ['theirs']);
  });

  test('a stale ok row in the cache does not hide the verdict', () async {
    await overdueItem('theirs', kDiverB);
    await db
        .into(db.equipmentServiceStatus)
        .insert(
          EquipmentServiceStatusCompanion.insert(
            equipmentId: 'theirs',
            severity: 'ok',
            computedAt: t,
          ),
        );
    final out = await tool().call({
      'root': 'equipment',
      'query': 'serviceDue = overdue',
      'diver_id': kDiverB,
    }, ctx());
    expect(out['ids'], ['theirs']);
  });

  test('gear with no clock reads as ok', () async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'mask',
            name: 'Mask',
            type: 'mask',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
    final overdue = await tool().call({
      'root': 'equipment',
      'query': 'serviceDue = overdue',
    }, ctx());
    expect(overdue['ids'], isEmpty);
    final ok = await tool().call({
      'root': 'equipment',
      'query': 'serviceDue = ok',
    }, ctx());
    expect(ok['ids'], ['mask']);
  });

  test('nextServiceDue bounds by the named diver\'s date', () async {
    await overdueItem('theirs', kDiverB);
    final out = await tool().call({
      'root': 'equipment',
      'query': 'nextServiceDue in 2023',
      'diver_id': kDiverB,
    }, ctx());
    expect(out['ids'], ['theirs']);
  });

  test('no gear means nothing is due', () async {
    final out = await tool().call({
      'root': 'equipment',
      'query': 'serviceDue = overdue',
    }, ctx());
    expect(out['ids'], isEmpty);
    expect(out['total'], 0);
  });

  test('a serviceDue query writes nothing', () async {
    await overdueItem('mine', kDiverA);
    await pumpEventQueue();
    final ticks = <Object>[];
    final sub = db.tableUpdates().listen(ticks.add);
    await tool().call({
      'root': 'equipment',
      'query': 'serviceDue = overdue',
    }, ctx());
    await pumpEventQueue();
    await sub.cancel();
    expect(ticks, isEmpty);
  });

  test('the cache table is left as it was', () async {
    await overdueItem('mine', kDiverA);
    await tool().call({
      'root': 'equipment',
      'query': 'serviceDue = overdue',
    }, ctx());
    expect(await db.select(db.equipmentServiceStatus).get(), isEmpty);
  });
}

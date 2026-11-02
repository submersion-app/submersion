import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/tools/list_records_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

import '../../../../helpers/test_database.dart';

Matcher _throwsCode(AgentToolErrorCode code) =>
    throwsA(isA<AgentToolException>().having((e) => e.code, 'code', code));

void main() {
  late AppDatabase db;
  const a = 'diver-a';
  const b = 'diver-b';
  const t = 1700000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final (id, isDefault) in [(a, true), (b, false)]) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
              isDefault: Value(isDefault),
            ),
          );
    }
    for (final (id, owner) in [('a1', a), ('a2', a), ('b1', b)]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: t,
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
    }
    for (final (id, dive) in [
      ('t1', 'a1'),
      ('t2', 'a1'),
      ('t3', 'a2'),
      ('t4', 'b1'),
    ]) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: id,
              diveId: dive,
              volume: const Value(12),
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  ListRecordsTool tool() => ListRecordsTool(
    loader: DiverContextLoader(
      db: () => db,
      divers: DiverRepository(),
      settings: DiverSettingsRepository(),
      localeTag: 'en',
      activeDiverId: () async => a,
    ),
    catalog: RecordCatalog(RecordRepositories()),
  );

  AgentToolContext ctx() => AgentToolContext(db: db, clientName: 'test');

  test('is named list_records and requires an entity', () {
    expect(tool().name, 'list_records');
    expect(tool().inputSchema['required'], ['entity']);
  });

  test('the entity enum leaves the query roots out', () {
    final properties = tool().inputSchema['properties'] as Map;
    final entities = (properties['entity'] as Map)['enum'] as List;
    expect(entities, contains('dive_tanks'));
    expect(entities, isNot(contains('dives')));
  });

  test('lists one profile\'s records', () async {
    final out = await tool().call({'entity': 'dive_tanks'}, ctx());
    expect(out['entity'], 'dive_tanks');
    expect(out['diver_id'], a);
    expect(out['total'], 3);
    expect((out['records'] as List).cast<Map>().map((r) => r['id']), [
      't1',
      't2',
      't3',
    ]);
  });

  test('a named profile lists its own', () async {
    final out = await tool().call({
      'entity': 'dive_tanks',
      'diver_id': b,
    }, ctx());
    expect((out['records'] as List).cast<Map>().map((r) => r['id']), ['t4']);
  });

  test('pages with has_more', () async {
    final first = await tool().call({
      'entity': 'dive_tanks',
      'limit': 2,
    }, ctx());
    expect(first['has_more'], isTrue);
    expect((first['records'] as List), hasLength(2));
    final last = await tool().call({
      'entity': 'dive_tanks',
      'limit': 2,
      'offset': 2,
    }, ctx());
    expect(last['has_more'], isFalse);
    expect((last['records'] as List).cast<Map>().map((r) => r['id']), ['t3']);
    expect(last['offset'], 2);
    expect(last['limit'], 2);
  });

  test('parent_id narrows to one parent', () async {
    final out = await tool().call({
      'entity': 'dive_tanks',
      'parent_id': 'a2',
    }, ctx());
    expect(out['total'], 1);
    expect((out['records'] as List).cast<Map>().map((r) => r['id']), ['t3']);
  });

  test('parent_id cannot reach another profile\'s parent', () async {
    final out = await tool().call({
      'entity': 'dive_tanks',
      'parent_id': 'b1',
    }, ctx());
    expect(out['total'], 0);
  });

  test('an unknown diver is refused', () async {
    await expectLater(
      tool().call({'entity': 'dive_tanks', 'diver_id': 'nope'}, ctx()),
      _throwsCode(AgentToolErrorCode.unknownDiver),
    );
  });

  test('a root entity is refused and names query', () async {
    await expectLater(
      tool().call({'entity': 'dives'}, ctx()),
      throwsA(
        isA<AgentToolException>()
            .having((e) => e.code, 'code', AgentToolErrorCode.invalidArgument)
            .having((e) => e.message, 'message', contains('query')),
      ),
    );
  });

  test('an unknown entity is refused', () async {
    await expectLater(
      tool().call({'entity': 'nonsense'}, ctx()),
      _throwsCode(AgentToolErrorCode.invalidArgument),
    );
  });

  test('a limit past the maximum is refused', () async {
    await expectLater(
      tool().call({
        'entity': 'dive_tanks',
        'limit': kListRecordsMaxLimit + 1,
      }, ctx()),
      _throwsCode(AgentToolErrorCode.invalidArgument),
    );
  });
}

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/tools/query_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

Matcher _throwsCode(AgentToolErrorCode code) =>
    throwsA(isA<AgentToolException>().having((e) => e.code, 'code', code));

void main() {
  late AppDatabase db;
  const a = 'diver-a';
  const b = 'diver-b';
  const t = 1700000000000;

  Future<void> dive(
    String id,
    String diver,
    double depthM, {
    String? siteId,
    int offset = 0,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: t + offset,
          createdAt: t,
          updatedAt: t,
          diverId: Value(diver),
          maxDepth: Value(depthM),
          siteId: Value(siteId),
        ),
      );

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
    for (final (id, owner) in [('blue-hole', a), ('reef', b)]) {
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: id,
              name: id == 'blue-hole' ? 'Blue Hole' : 'Reef',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
    }
    await dive('a-20', a, 20, siteId: 'blue-hole');
    await dive('a-40', a, 40, siteId: 'blue-hole', offset: 1000);
    await dive('b-35', b, 35, siteId: 'reef');
    await DiverSettingsRepository().createSettingsForDiver(
      b,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );
  });
  tearDown(tearDownTestDatabase);

  QueryTool tool() => QueryTool(
    loader: DiverContextLoader(
      db: () => db,
      divers: DiverRepository(),
      settings: DiverSettingsRepository(),
      localeTag: 'en',
      activeDiverId: () async => a,
    ),
    dives: DiveRepository(),
  );

  AgentToolContext ctx() => AgentToolContext(db: db, clientName: 'test');

  group('QueryTool', () {
    test('is named query and requires root', () {
      expect(tool().name, 'query');
      expect(tool().inputSchema['required'], ['root']);
      final props = tool().inputSchema['properties'] as Map;
      expect((props['root'] as Map)['enum'], [
        'dives',
        'sites',
        'equipment',
        'trips',
        'buddies',
        'centers',
        'certifications',
        'courses',
        'species',
      ]);
    });

    test(
      'empty query returns every dive of the active diver, sorted',
      () async {
        final out = await tool().call({'root': 'dives'}, ctx());
        expect(out['root'], 'dives');
        expect(out['diver_id'], a);
        expect(out['total'], 2);
        expect(out['ids'], ['a-20', 'a-40']);
        expect(out['has_more'], isFalse);
        expect(out.containsKey('summaries'), isFalse);
      },
    );

    test('parses bare numbers in the named divers units', () async {
      final feet = await tool().call({
        'root': 'dives',
        'query': 'depth > 100',
        'diver_id': b,
      }, ctx());
      expect(feet['total'], 1, reason: '35 m is 114 ft');
      expect(feet['ids'], ['b-35']);
      final metric = await tool().call({
        'root': 'dives',
        'query': 'depth > 100',
      }, ctx());
      expect(metric['total'], 0, reason: 'nothing deeper than 100 m');
    });

    test('resolves names through the divers name index', () async {
      final out = await tool().call({
        'root': 'dives',
        'query': 'site:"Blue Hole"',
      }, ctx());
      expect(out['total'], 2);
    });

    test('parse failure surfaces offset and suggestions', () async {
      await expectLater(
        tool().call({'root': 'dives', 'query': 'dpeth > 3'}, ctx()),
        throwsA(
          isA<AgentToolException>()
              .having((e) => e.code, 'code', AgentToolErrorCode.parseError)
              .having((e) => e.details!['offset'], 'offset', 0)
              .having(
                (e) => e.details!['suggestions'],
                'suggestions',
                contains('depth'),
              ),
        ),
      );
    });

    test('unknown root is invalid_argument', () async {
      await expectLater(
        tool().call({'root': 'planets'}, ctx()),
        _throwsCode(AgentToolErrorCode.invalidArgument),
      );
    });

    test('unknown diver is unknown_diver', () async {
      await expectLater(
        tool().call({'root': 'dives', 'diver_id': 'nobody'}, ctx()),
        _throwsCode(AgentToolErrorCode.unknownDiver),
      );
    });

    test('paging honours limit and offset with has_more', () async {
      final first = await tool().call({'root': 'dives', 'limit': 1}, ctx());
      expect(first['ids'], ['a-20']);
      expect(first['total'], 2);
      expect(first['has_more'], isTrue);
      final second = await tool().call({
        'root': 'dives',
        'limit': 1,
        'offset': 1,
      }, ctx());
      expect(second['ids'], ['a-40']);
      expect(second['has_more'], isFalse);
    });

    test('include_summaries returns unit-named keys', () async {
      final out = await tool().call({
        'root': 'dives',
        'query': 'depth > 30',
        'include_summaries': true,
      }, ctx());
      final summaries = (out['summaries'] as List).cast<Map>();
      expect(summaries, hasLength(1));
      final s = summaries.single;
      expect(s['id'], 'a-40');
      expect(s['max_depth_m'], 40.0);
      expect(s['site_name'], 'Blue Hole');
      expect(s.keys, isNot(contains('maxDepth')));
      expect(s['date_time'], isA<String>());
    });

    test('other roots return ids and a total', () async {
      final out = await tool().call({'root': 'sites'}, ctx());
      expect(out['ids'], ['blue-hole']);
      expect(out['total'], 1);
    });

    test(
      'a query touching equipment_service_status is refused in this phase',
      () async {
        await expectLater(
          tool().call({'root': 'equipment', 'query': 'serviceDue:any'}, ctx()),
          _throwsCode(AgentToolErrorCode.invalidArgument),
        );
      },
    );
  });
}

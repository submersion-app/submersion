import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/tools/query_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
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
    catalog: RecordCatalog(RecordRepositories()),
  );

  AgentToolContext ctx() => AgentToolContext(db: db, clientName: 'test');

  group('QueryTool', () {
    test('describes the wall-clock time convention', () {
      expect(tool().description, contains('local wall clock'));
    });

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

    group('summaries', () {
      test('summaries for sites are a projection of the document', () async {
        final out = await tool().call({
          'root': 'sites',
          'include_summaries': true,
        }, ctx());
        final row = (out['summaries'] as List).cast<Map>().single;
        expect(row['id'], 'blue-hole');
        expect(row['name'], isNotNull);
        expect(row.containsKey('notes'), isFalse);
      });

      test('summaries keep id order', () async {
        for (final id in ['z-site', 'a-site']) {
          await db
              .into(db.diveSites)
              .insert(
                DiveSitesCompanion.insert(
                  id: id,
                  name: id,
                  createdAt: t,
                  updatedAt: t,
                  diverId: const Value(a),
                ),
              );
        }
        final out = await tool().call({
          'root': 'sites',
          'include_summaries': true,
        }, ctx());
        expect((out['summaries'] as List).cast<Map>().map((r) => r['id']), [
          ...(out['ids'] as List),
        ]);
      });

      test('every root answers with summaries', () async {
        await db
            .into(db.equipment)
            .insert(
              EquipmentCompanion.insert(
                id: 'reg',
                name: 'Reg',
                type: 'regulator',
                createdAt: t,
                updatedAt: t,
                diverId: const Value(a),
              ),
            );
        await db
            .into(db.trips)
            .insert(
              TripsCompanion.insert(
                id: 'trip',
                name: 'Trip',
                startDate: t,
                endDate: t,
                createdAt: t,
                updatedAt: t,
                diverId: const Value(a),
              ),
            );
        await db
            .into(db.buddies)
            .insert(
              BuddiesCompanion.insert(
                id: 'bud',
                name: 'Bud',
                createdAt: t,
                updatedAt: t,
                diverId: const Value(a),
              ),
            );
        await db
            .into(db.diveCenters)
            .insert(
              DiveCentersCompanion.insert(
                id: 'center',
                name: 'Center',
                createdAt: t,
                updatedAt: t,
                diverId: const Value(a),
              ),
            );
        await db
            .into(db.certifications)
            .insert(
              CertificationsCompanion.insert(
                id: 'cert',
                name: 'Open Water',
                agency: 'padi',
                createdAt: t,
                updatedAt: t,
                diverId: const Value(a),
              ),
            );
        await db
            .into(db.courses)
            .insert(
              CoursesCompanion.insert(
                id: 'course',
                diverId: a,
                name: 'Nitrox',
                agency: 'padi',
                startDate: t,
                createdAt: t,
                updatedAt: t,
              ),
            );
        await db
            .into(db.species)
            .insert(
              SpeciesCompanion.insert(
                id: 'turtle',
                commonName: 'Turtle',
                category: 'turtle',
              ),
            );
        for (final (root, id) in [
          ('equipment', 'reg'),
          ('trips', 'trip'),
          ('buddies', 'bud'),
          ('centers', 'center'),
          ('certifications', 'cert'),
          ('courses', 'course'),
          ('species', 'turtle'),
        ]) {
          final out = await tool().call({
            'root': root,
            'include_summaries': true,
          }, ctx());
          final rows = (out['summaries'] as List).cast<Map>();
          expect(rows.map((r) => r['id']), contains(id), reason: root);
        }
      });
    });
  });
}

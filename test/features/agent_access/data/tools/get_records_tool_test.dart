import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/tools/get_records_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
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
    for (final (id, owner, depth) in [
      ('a1', a, 20.0),
      ('a2', a, 40.0),
      ('b1', b, 35.0),
    ]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: t,
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
              maxDepth: Value(depth),
            ),
          );
    }
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion.insert(
            id: 'bud',
            name: 'Bud Dy',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(a),
          ),
        );
    await db
        .into(db.diveBuddies)
        .insert(
          DiveBuddiesCompanion.insert(
            id: 'db1',
            diveId: 'a1',
            buddyId: 'bud',
            createdAt: t,
          ),
        );
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion.insert(
            id: 'sp',
            commonName: 'Turtle',
            category: 'reptile',
          ),
        );
    await db
        .into(db.sightings)
        .insert(
          SightingsCompanion.insert(
            id: 'si1',
            diveId: 'a1',
            speciesId: 'sp',
            count: const Value(2),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  GetRecordsTool tool() => GetRecordsTool(
    loader: DiverContextLoader(
      db: db,
      divers: DiverRepository(),
      settings: DiverSettingsRepository(),
      localeTag: 'en',
      activeDiverId: () async => a,
    ),
    dives: DiveRepository(),
    buddies: BuddyRepository(),
    species: SpeciesRepository(),
    media: MediaRepository(),
    diveTypes: DiveTypeRepository(),
  );

  AgentToolContext ctx() => AgentToolContext(db: db, clientName: 'test');

  group('GetRecordsTool', () {
    test('is named get_records and requires entity and ids', () {
      expect(tool().name, 'get_records');
      expect(tool().inputSchema['required'], ['entity', 'ids']);
    });

    test(
      'returns documents for visible ids and lists the rest as missing',
      () async {
        final out = await tool().call({
          'entity': 'dives',
          'ids': ['a1', 'b1', 'nope'],
          'include': ['tanks'],
        }, ctx());
        expect(out['entity'], 'dives');
        final records = (out['records'] as List).cast<Map>();
        expect(records.map((r) => r['id']), ['a1']);
        expect(records.single['max_depth_m'], 20.0);
        expect(records.single.containsKey('tanks'), isTrue);
        expect(records.single.containsKey('buddies'), isFalse);
        expect(out['missing'], unorderedEquals(['b1', 'nope']));
      },
    );

    test('diver_id switches which dives are visible', () async {
      final out = await tool().call({
        'entity': 'dives',
        'ids': ['a1', 'b1'],
        'diver_id': b,
      }, ctx());
      expect((out['records'] as List).map((r) => r['id']), ['b1']);
      expect(out['missing'], ['a1']);
    });

    test('more than 50 ids is too_many_ids', () async {
      await expectLater(
        tool().call({
          'entity': 'dives',
          'ids': [for (var i = 0; i < 51; i++) 'id-$i'],
        }, ctx()),
        _throwsCode(AgentToolErrorCode.tooManyIds),
      );
    });

    test('an unsupported entity is invalid_argument', () async {
      await expectLater(
        tool().call({
          'entity': 'sites',
          'ids': ['x'],
        }, ctx()),
        _throwsCode(AgentToolErrorCode.invalidArgument),
      );
    });

    test('missing ids is invalid_argument', () async {
      await expectLater(
        tool().call({'entity': 'dives'}, ctx()),
        _throwsCode(AgentToolErrorCode.invalidArgument),
      );
    });

    test('buddies and sightings come from their repositories', () async {
      final out = await tool().call({
        'entity': 'dives',
        'ids': ['a1'],
        'include': ['buddies', 'sightings'],
      }, ctx());
      final record = (out['records'] as List).cast<Map>().single;
      final buddies = (record['buddies'] as List).cast<Map>();
      expect(buddies.single['name'], 'Bud Dy');
      expect(buddies.single['id'], 'bud');
      final sightings = (record['sightings'] as List).cast<Map>();
      expect(sightings.single['species_name'], 'Turtle');
      expect(sightings.single['count'], 2);
    });
  });
}

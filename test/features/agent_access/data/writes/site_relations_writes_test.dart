import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// A site's tags and expected species, linked as the site editor links
/// them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<void> tag(String id, String name, {required bool sites}) => db
      .into(db.tags)
      .insert(
        TagsCompanion.insert(
          id: id,
          name: name,
          createdAt: t,
          updatedAt: t,
          diverId: const Value(kDiverA),
          appliesToSites: Value(sites),
        ),
      );

  Map<String, Object?> link(
    String relation, {
    List<String> add = const [],
    List<String> remove = const [],
  }) => {
    'op': 'update',
    'entity': 'sites',
    'id': 's1',
    'relations': {
      relation: {'add': add, 'remove': remove},
    },
  };

  Future<Set<String>> linked(String table, String column) async => {
    for (final row
        in await db
            .customSelect(
              'SELECT $column AS v FROM $table WHERE site_id = ?',
              variables: [Variable.withString('s1')],
            )
            .get())
      row.read<String>('v'),
  };

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's1',
            name: 'Blue Hole',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
  });
  tearDown(() => tearDownTestDatabase());

  test('a site gains and loses tags', () async {
    await tag('wall', 'Wall', sites: true);
    await tag('deep', 'Deep', sites: true);

    await h.run([
      link('tags', add: ['wall', 'deep']),
    ]);
    expect(await linked('site_tags', 'tag_id'), {'wall', 'deep'});

    await h.run([
      link('tags', remove: ['wall']),
    ]);
    expect(await linked('site_tags', 'tag_id'), {'deep'});
  });

  test('a tag not used for sites cannot link to one', () async {
    await tag('night', 'Night', sites: false);

    final plan = await h.preview([
      link('tags', add: ['night']),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
    expect(plan.items.single.block!.detail, contains('night'));
  });

  // The set runs in order, so an earlier change to the tag is what the link
  // meets.
  test(
    'a tag the set first opens to sites can link, one it closes cannot',
    () async {
      await tag('night', 'Night', sites: false);
      await tag('wall', 'Wall', sites: true);

      final plan = await h.preview([
        updateOp('tags', 'night', {
          'scopes': ['dives', 'sites'],
        }),
        updateOp('tags', 'wall', {
          'scopes': ['dives'],
        }),
        link('tags', add: ['night', 'wall']),
      ]);

      expect(plan.items.last.block!.reason, BlockReason.invalidValue);
      expect(plan.items.last.block!.detail, contains('wall'));
      expect(plan.items.last.block!.detail, isNot(contains('night')));

      final opened = await h.preview([
        updateOp('tags', 'night', {
          'scopes': ['dives', 'sites'],
        }),
        link('tags', add: ['night']),
      ]);
      expect(opened.items.last.block, isNull);
      await h.apply(opened);
      expect(await linked('site_tags', 'tag_id'), {'night'});
    },
  );

  // Closing a tag's site scope takes it off every site first, so a later
  // link of that tag is a new link the site cannot take, not "already there".
  test(
    'a link a scope change takes away earlier in the set is not kept',
    () async {
      await tag('wall', 'Wall', sites: true);
      await h.run([
        link('tags', add: ['wall']),
      ]);

      final plan = await h.preview([
        updateOp('tags', 'wall', {
          'scopes': ['dives'],
        }),
        link('tags', add: ['wall']),
      ]);

      expect(plan.unchanged, isEmpty);
      expect(plan.items.last.block!.reason, BlockReason.invalidValue);
      expect(plan.items.last.block!.detail, contains('wall'));
    },
  );

  test('another diver\'s tag cannot link to a site', () async {
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 'theirs',
            name: 'Theirs',
            createdAt: kSeedTime,
            updatedAt: kSeedTime,
            diverId: const Value(kDiverB),
            appliesToSites: const Value(true),
          ),
        );

    final plan = await h.preview([
      link('tags', add: ['theirs']),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.otherProfileReference);
  });

  test('a site gains and loses expected species', () async {
    for (final (id, name) in [('nudi', 'Nudibranch'), ('ray', 'Manta')]) {
      await db
          .into(db.species)
          .insert(
            SpeciesCompanion.insert(id: id, commonName: name, category: 'fish'),
          );
    }

    await h.run([
      link('expected_species', add: ['nudi', 'ray']),
    ]);
    expect(await linked('site_species', 'species_id'), {'nudi', 'ray'});

    await h.run([
      link('expected_species', remove: ['ray']),
    ]);
    expect(await linked('site_species', 'species_id'), {'nudi'});
  });
}

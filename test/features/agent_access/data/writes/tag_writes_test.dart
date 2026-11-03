import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Tags, as the tag page keeps them: one per name for a diver, at least one
/// scope, and a scope turned off takes the tag off what that scope holds.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<void> tag(String id, String name, {bool sites = false}) => db
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

  Future<void> onDive(String linkId, String diveId, String tagId) => db
      .into(db.diveTags)
      .insert(
        DiveTagsCompanion.insert(
          id: linkId,
          diveId: diveId,
          tagId: tagId,
          createdAt: t,
        ),
      );

  Future<void> onSite(String linkId, String siteId, String tagId) => db
      .into(db.siteTags)
      .insert(
        SiteTagsCompanion.insert(
          id: linkId,
          siteId: siteId,
          tagId: tagId,
          createdAt: t,
        ),
      );

  Future<int> count(TableInfo table) async =>
      (await db.select(table).get()).length;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await h.dive('d3');
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

  test('a new tag applies to dives unless told', () async {
    final result = await h.run([
      createOp('tags', {'name': 'Night'}),
    ]);

    final doc = (await h.one('tags', result.created.single.id))!;
    expect(doc['name'], 'Night');
    expect(doc['scopes'], ['dives']);
  });

  test('a name another tag of the diver holds is a duplicate', () async {
    await tag('wreck', 'Wreck');
    await tag('reef', 'Reef');

    final plan = await h.preview([
      createOp('tags', {'name': ' wreck '}),
      updateOp('tags', 'reef', {'name': 'WRECK'}),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.duplicateRecord);
      expect(item.block!.detail, contains('wreck'));
    }
  });

  // createTag hands back the tag already holding a name, and updateTag
  // merges into it, so two claims on one name in a set must not both pass.
  test('two creates of one name in a set block the second', () async {
    final plan = await h.preview([
      createOp('tags', {'name': 'Wreck'}),
      createOp('tags', {'name': ' wreck '}),
    ]);

    expect(plan.items[0].block, isNull);
    expect(plan.items[1].block!.reason, BlockReason.duplicateRecord);
    expect(plan.items[1].block!.detail, contains('operation 0'));
  });

  test('a rename onto a name the set creates is blocked', () async {
    await tag('reef', 'Reef');

    final plan = await h.preview([
      createOp('tags', {'name': 'Wreck'}),
      updateOp('tags', 'reef', {'name': 'WRECK'}),
    ]);

    expect(plan.items[1].block!.reason, BlockReason.duplicateRecord);
  });

  test('two renames onto one name block the second', () async {
    await tag('reef', 'Reef');
    await tag('cave', 'Cave');

    final plan = await h.preview([
      updateOp('tags', 'reef', {'name': 'Wreck'}),
      updateOp('tags', 'cave', {'name': 'wreck'}),
    ]);

    expect(plan.items[0].block, isNull);
    expect(plan.items[1].block!.reason, BlockReason.duplicateRecord);
  });

  test('a name is planned as the repository stores it, trimmed', () async {
    await tag('reef', 'Reef');

    final plan = await h.preview([
      createOp('tags', {'name': '  Night '}),
      updateOp('tags', 'reef', {'name': ' Reef '}),
    ]);

    expect(plan.items.single.fields['name']!.newValue, 'Night');
    expect(plan.unchanged.single.id, 'reef');
  });

  // The set runs in order, so the rename frees the name before the create.
  test('a name an earlier rename in the set frees can be taken', () async {
    await tag('reef', 'Reef');

    final plan = await h.preview([
      updateOp('tags', 'reef', {'name': 'Reefs'}),
      createOp('tags', {'name': 'Reef'}),
    ]);

    expect(plan.items.last.block, isNull);
    await h.apply(plan);
    expect(await count(db.tags), 2);
  });

  test('a name taken after the preview refuses the apply', () async {
    final plan = await h.preview([
      createOp('tags', {'name': 'Wreck'}),
    ]);
    await tag('wreck', 'Wreck');

    await expectLater(h.apply(plan), throwsA(isA<AgentToolException>()));
    expect(await count(db.tags), 1);
  });

  test('a colour must be #RRGGBB', () async {
    await tag('reef', 'Reef');

    final plan = await h.preview([
      updateOp('tags', 'reef', {'color_hex': 'red'}),
      createOp('tags', {'name': 'Cave', 'color_hex': '#FFF'}),
      createOp('tags', {'name': 'Wall', 'color_hex': '#FF5733'}),
    ]);

    expect(plan.items[0].block!.reason, BlockReason.invalidValue);
    expect(plan.items[1].block!.reason, BlockReason.invalidValue);
    expect(plan.items[2].block, isNull);
  });

  test('turning off a scope lists the links it removes', () async {
    await tag('wreck', 'Wreck', sites: true);
    await onDive('dt1', 'd1', 'wreck');
    await onDive('dt2', 'd3', 'wreck');
    await onSite('st1', 's1', 'wreck');

    final plan = await h.preview([
      updateOp('tags', 'wreck', {
        'scopes': ['sites'],
      }),
    ]);
    expect(plan.items.single.block, isNull);
    expect(plan.items.single.reach.parts, {'dive_tags': 2});

    await h.apply(plan);
    expect(await count(db.diveTags), 0);
    expect(await count(db.siteTags), 1);
    expect((await h.one('tags', 'wreck'))!['scopes'], ['sites']);
  });

  test('a delete unlinks every item', () async {
    await tag('wreck', 'Wreck', sites: true);
    await onDive('dt1', 'd1', 'wreck');
    await onSite('st1', 's1', 'wreck');

    final plan = await h.preview([deleteOp('tags', 'wreck')]);
    expect(plan.items.single.reach.unlinked, {'dive_tags': 1, 'site_tags': 1});

    await h.apply(plan);
    expect(await count(db.diveTags), 0);
    expect(await count(db.siteTags), 0);
    expect(await h.one('tags', 'wreck'), isNull);
  });

  test('every codec key has a column', () async {
    await tag('reef', 'Reef');

    await h.run([
      updateOp('tags', 'reef', {
        'name': 'Coral reef',
        'color_hex': '#00AACC',
        'scopes': ['dives', 'sites'],
      }),
    ]);

    final doc = (await h.one('tags', 'reef'))!;
    expect(doc['name'], 'Coral reef');
    expect(doc['color_hex'], '#00AACC');
    expect(doc['scopes'], ['dives', 'sites']);
  });
}

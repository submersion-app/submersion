import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// A merge is a delete that names the record taking over its links, as the
/// tag page's merge does: every link moves, a link the survivor already has
/// goes, and the merged tag is gone.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<void> tag(String id, String name, {String owner = kDiverA}) => db
      .into(db.tags)
      .insert(
        TagsCompanion.insert(
          id: id,
          name: name,
          createdAt: t,
          updatedAt: t,
          diverId: Value(owner),
          appliesToSites: const Value(true),
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

  Future<Set<String>> divesWith(String tagId) async => {
    for (final row in await (db.select(
      db.diveTags,
    )..where((l) => l.tagId.equals(tagId))).get())
      row.diveId,
  };

  Future<Set<String>> sitesWith(String tagId) async => {
    for (final row in await (db.select(
      db.siteTags,
    )..where((l) => l.tagId.equals(tagId))).get())
      row.siteId,
  };

  Map<String, Object?> merge(String id, String into) => {
    'op': 'delete',
    'entity': 'tags',
    'id': id,
    'merge_into': into,
  };

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
    await tag('wrecks', 'Wrecks');
    await tag('wreck', 'Wreck');
    await onDive('dt1', 'd1', 'wrecks');
    await onDive('dt2', 'd3', 'wrecks');
    await onDive('dt3', 'd3', 'wreck');
    await db
        .into(db.siteTags)
        .insert(
          SiteTagsCompanion.insert(
            id: 'st1',
            siteId: 's1',
            tagId: 'wrecks',
            createdAt: t,
          ),
        );
  });
  tearDown(() => tearDownTestDatabase());

  test(
    'a merge moves every link to the survivor and deletes the source',
    () async {
      final plan = await h.preview([merge('wrecks', 'wreck')]);
      final item = plan.items.single;
      expect(item.block, isNull);
      expect(item.mergeInto, 'wreck');
      expect(item.mergeTitle, 'Wreck');
      expect(item.reach.moved, {'dive_tags': 1, 'site_tags': 1});
      expect(item.reach.parts, {'dive_tags': 1});

      await h.apply(plan);
      expect(await h.one('tags', 'wrecks'), isNull);
      expect(await divesWith('wreck'), {'d1', 'd3'});
      expect(await sitesWith('wreck'), {'s1'});
      expect(await divesWith('wrecks'), isEmpty);
    },
  );

  // After the first merge the survivor is on d1, so the second merge's link
  // there goes rather than moves.
  test('merges into one survivor are counted one after another', () async {
    await tag('ships', 'Ships');
    await onDive('dt9', 'd1', 'ships');

    final plan = await h.preview([
      merge('wrecks', 'wreck'),
      merge('ships', 'wreck'),
    ]);

    expect(plan.items[1].block, isNull);
    expect(plan.items[1].reach.moved, isEmpty);
    expect(plan.items[1].reach.parts, {'dive_tags': 1});
    await h.apply(plan);
    expect(await divesWith('wreck'), {'d1', 'd3'});
  });

  // Which links a merge finds depends on links the same set changes, which
  // a relation `set` hides until it runs.
  test('a merge beside a change to tag links is blocked', () async {
    final plan = await h.preview([
      merge('wrecks', 'wreck'),
      {
        'op': 'update',
        'entity': 'dives',
        'id': 'd1',
        'relations': {
          'tags': {
            'add': ['wreck'],
          },
        },
      },
    ]);

    expect(plan.items.first.block!.reason, BlockReason.notPermitted);
    expect(plan.items.first.block!.detail, contains('tags'));
  });

  test('a merge lists the survivor\'s wider scopes and the albums it '
      'repoints', () async {
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 'reefs',
            name: 'Reefs',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
            appliesToDives: const Value(false),
            appliesToSites: const Value(true),
          ),
        );
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 'reef',
            name: 'Reef',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
    await db
        .into(db.mediaSmartAlbums)
        .insert(
          MediaSmartAlbumsCompanion.insert(
            id: 'al1',
            name: 'Reef shots',
            filterJson: '{"tagIds":["reefs"]}',
            createdAt: t,
            updatedAt: t,
          ),
        );

    final plan = await h.preview([merge('reefs', 'reef')]);
    final item = plan.items.single;

    expect(item.fields['scopes']!.oldValue, ['dives']);
    expect(item.fields['scopes']!.newValue, ['dives', 'sites']);
    expect(item.fields['scopes']!.indirect, isTrue);
    expect(item.reach.moved['media_smart_albums'], 1);
  });

  // mergeTags keeps a merge of tags with no scope switched on a dive tag.
  test('a merge of tags with no scope makes the survivor a dive tag', () async {
    for (final (id, name) in [('a', 'Alpha'), ('b', 'Beta')]) {
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: id,
              name: name,
              createdAt: t,
              updatedAt: t,
              diverId: const Value(kDiverA),
              appliesToDives: const Value(false),
            ),
          );
    }

    final plan = await h.preview([merge('a', 'b')]);

    expect(plan.items.single.fields['scopes']!.oldValue, isEmpty);
    expect(plan.items.single.fields['scopes']!.newValue, ['dives']);
  });

  test('a merge that widens scopes the set also sets is blocked', () async {
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 'reef',
            name: 'Reef',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );

    final plan = await h.preview([
      updateOp('tags', 'reef', {
        'scopes': ['dives'],
      }),
      merge('wrecks', 'reef'),
    ]);

    expect(plan.items.last.block!.reason, BlockReason.notPermitted);
    expect(plan.items.last.block!.detail, contains('scopes'));
  });

  test('a merge into a tag the set merges away is blocked', () async {
    await tag('ships', 'Ships');

    final plan = await h.preview([
      merge('ships', 'wrecks'),
      merge('wrecks', 'wreck'),
    ]);

    expect(plan.items.first.block!.reason, BlockReason.referenceDeleted);
    expect(plan.items.last.block, isNull);
  });

  test('a merge keeps a rename of the survivor in the same set', () async {
    await h.run([
      updateOp('tags', 'wreck', {'name': 'Shipwreck'}),
      merge('wrecks', 'wreck'),
    ]);

    expect((await h.one('tags', 'wreck'))!['name'], 'Shipwreck');
    expect(await divesWith('wreck'), {'d1', 'd3'});
  });

  test('a merge into itself, a deleted survivor or another diver\'s tag is '
      'blocked', () async {
    await tag('theirs', 'Wreckage', owner: kDiverB);
    await tag('gone', 'Gone');
    await tag('other', 'Other');

    final plan = await h.preview([
      merge('wrecks', 'wrecks'),
      merge('wreck', 'gone'),
      deleteOp('tags', 'gone'),
      merge('other', 'theirs'),
    ]);
    final blocks = [for (final item in plan.items) item.block?.reason];

    expect(blocks, [
      BlockReason.invalidValue,
      BlockReason.referenceDeleted,
      null,
      BlockReason.otherProfileReference,
    ]);
  });

  test('a merge into a record that does not exist is blocked', () async {
    final plan = await h.preview([merge('wrecks', 'nowhere')]);

    expect(plan.items.single.block!.reason, BlockReason.unknownReference);
  });

  test('an entity that cannot merge refuses merge_into', () async {
    for (final id in ['b1', 'b2']) {
      await db
          .into(db.buddies)
          .insert(
            BuddiesCompanion.insert(
              id: id,
              name: 'Buddy $id',
              createdAt: t,
              updatedAt: t,
              diverId: const Value(kDiverA),
            ),
          );
    }

    final plan = await h.preview([
      {'op': 'delete', 'entity': 'buddies', 'id': 'b1', 'merge_into': 'b2'},
    ]);

    expect(plan.items.single.block!.reason, BlockReason.notPermitted);
  });

  test('a revert restores the source and its links', () async {
    final result = await h.run([merge('wrecks', 'wreck')]);

    await h.revert(result);

    expect((await h.one('tags', 'wrecks'))!['name'], 'Wrecks');
    expect(await divesWith('wrecks'), {'d1', 'd3'});
    expect(await sitesWith('wrecks'), {'s1'});
    expect(await divesWith('wreck'), {'d3'});
  });

  // A link moving to another dive changes neither tag's row nor the counts,
  // but it changes which links the merge moves.
  test('a moved link after the preview refuses the apply', () async {
    await h.dive('d4');
    final plan = await h.preview([merge('wrecks', 'wreck')]);
    await (db.update(db.diveTags)..where((l) => l.id.equals('dt1'))).write(
      const DiveTagsCompanion(diveId: Value('d4')),
    );

    await expectLater(
      h.apply(plan),
      throwsA(
        isA<AgentToolException>().having(
          (e) => e.code,
          'code',
          AgentToolErrorCode.planStale,
        ),
      ),
    );
  });

  // Swapping which album names the tag keeps the count but changes which
  // album the merge rewrites.
  test('a different album naming the tag refuses the apply', () async {
    Future<void> album(String id, String tagId) => db
        .into(db.mediaSmartAlbums)
        .insertOnConflictUpdate(
          MediaSmartAlbumsCompanion.insert(
            id: id,
            name: 'Album $id',
            filterJson: '{"tagIds":["$tagId"]}',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await album('al1', 'wrecks');
    final plan = await h.preview([merge('wrecks', 'wreck')]);
    await album('al1', 'wreck');
    await album('al2', 'wrecks');

    await expectLater(
      h.apply(plan),
      throwsA(
        isA<AgentToolException>().having(
          (e) => e.code,
          'code',
          AgentToolErrorCode.planStale,
        ),
      ),
    );
  });

  test(
    'a change to the survivor after the preview refuses the apply',
    () async {
      final plan = await h.preview([merge('wrecks', 'wreck')]);
      await (db.update(db.tags)..where((r) => r.id.equals('wreck'))).write(
        const TagsCompanion(name: Value('Renamed'), updatedAt: Value(t + 1)),
      );

      await expectLater(
        h.apply(plan),
        throwsA(
          isA<AgentToolException>().having(
            (e) => e.code,
            'code',
            AgentToolErrorCode.planStale,
          ),
        ),
      );
    },
  );
}

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

import '../../../../helpers/test_database.dart';

/// Duplicate-tag guards (issue #1032).
///
/// Two producers used to duplicate a dive's tag: a second `tags` row under a
/// different uuid but the same name, and a second `dive_tags` row for the same
/// (dive, tag) pair. Both are now blocked by unique indexes, so every writer
/// has to be conflict-safe -- an unguarded insert would throw instead of
/// silently duplicating, which is worse.
void main() {
  late TagRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = TagRepository();
  });

  tearDown(tearDownTestDatabase);

  Future<void> insertDiver(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insertOnConflictUpdate(
          DiversCompanion(
            id: Value(id),
            name: Value('Diver $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDive(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<int> junctionCount(String diveId, String tagId) async {
    final rows = await (db.select(
      db.diveTags,
    )..where((t) => t.diveId.equals(diveId) & t.tagId.equals(tagId))).get();
    return rows.length;
  }

  domain.Tag tagOf(String id, String name, {String? diverId}) => domain.Tag(
    id: id,
    diverId: diverId,
    name: name,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  // ---- Whitespace variants (PR #1033 review) ----
  //
  // The uniqueness slot is (diver scope, case-folded, TRIMMED name). Matching
  // on a trimmed name while storing the untrimmed one left the exact duplicate
  // this feature exists to forbid: " Wreck" and "Wreck" are one tag to every
  // lookup, but were two rows to the index.

  group('whitespace variants are the same tag', () {
    test('createTag stores the trimmed name', () async {
      final created = await repository.createTag(tagOf('', '  Wreck  '));

      expect(created.name, 'Wreck');
      final row = await (db.select(
        db.tags,
      )..where((t) => t.id.equals(created.id))).getSingle();
      expect(
        row.name,
        'Wreck',
        reason: 'what is stored must match what lookups compare against',
      );
    });

    test(
      'a padded name finds the existing tag rather than adding one',
      () async {
        await repository.createTag(tagOf('', 'Wreck'));

        final second = await repository.createTag(tagOf('', ' Wreck '));
        final all = await repository.getAllTags();

        expect(all.where((t) => t.name.trim() == 'Wreck'), hasLength(1));
        expect(second.name, 'Wreck');
      },
    );

    test(
      'the padded tag is created first, then the bare one folds into it',
      () async {
        // Order matters: this is the direction that used to slip through, because
        // the stored " Wreck" did not case-fold-equal the incoming "Wreck".
        await repository.createTag(tagOf('', ' Wreck'));

        await repository.createTag(tagOf('', 'Wreck'));

        expect(await repository.getAllTags(), hasLength(1));
      },
    );

    test('getTagByName finds a tag through surrounding whitespace', () async {
      await repository.createTag(tagOf('', 'Wreck'));

      expect(await repository.getTagByName('  Wreck  '), isNotNull);
    });

    test('the index itself rejects a padded duplicate', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.tags)
          .insert(
            TagsCompanion(
              id: const Value('a'),
              name: const Value('Wreck'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await expectLater(
        db
            .into(db.tags)
            .insert(
              TagsCompanion(
                id: const Value('b'),
                name: const Value(' wreck '),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            ),
        throwsA(anything),
        reason: 'the database is the backstop when a writer forgets to trim',
      );
    });
  });

  test(
    'creating the same tag concurrently returns one tag, never throws',
    () async {
      // The incumbent check is an await, so two callers can both pass it; the
      // loser used to throw on idx_tags_diver_name_unique even though the tag it
      // asked for now exists (PR #1033 review).
      final results = await Future.wait([
        repository.createTag(tagOf('', 'Wreck')),
        repository.createTag(tagOf('', 'Wreck')),
        repository.createTag(tagOf('', 'wreck')),
      ]);

      final all = await repository.getAllTags();
      expect(all, hasLength(1));
      expect(
        results.map((t) => t.id).toSet(),
        hasLength(1),
        reason: 'every caller must be handed the same surviving tag',
      );
      expect(results.first.id, all.single.id);
    },
  );

  test(
    'adding a tag twice concurrently still leaves one junction row',
    () async {
      // The old read-then-insert was racy: two callers could each observe
      // "missing" and the loser would throw on the unique index. A single
      // conflict-aware statement makes the duplicate a true no-op.
      await insertDive('dive-1');
      await repository.createTag(tagOf('tag-1', 'Wreck'));

      await Future.wait([
        repository.addTagToDive('dive-1', 'tag-1'),
        repository.addTagToDive('dive-1', 'tag-1'),
        repository.addTagToDive('dive-1', 'tag-1'),
      ]);

      final rows = await db.select(db.diveTags).get();
      expect(rows, hasLength(1));
    },
  );

  group('fresh database', () {
    test('carries both tag uniqueness indexes', () async {
      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final names = rows.map((r) => r.read<String>('name')).toSet();
      expect(names, contains('idx_tags_diver_name_unique'));
      expect(names, contains('idx_dive_tags_dive_tag_unique'));
    });
  });

  group('getTagByName', () {
    test('does not throw when two divers share a tag name', () async {
      // Unscoped lookup across two diver scopes used to hit
      // getSingleOrNull()'s "too many elements" and surface as the import
      // wizard's "tagging failed" warning.
      await insertDiver('d1');
      await insertDiver('d2');
      await repository.createTag(tagOf('tag-a', 'Wreck', diverId: 'd1'));
      await repository.createTag(tagOf('tag-b', 'Wreck', diverId: 'd2'));

      final found = await repository.getTagByName('Wreck');
      expect(found, isNotNull);
      expect(found!.id, 'tag-a', reason: 'lowest id wins, deterministically');
    });

    test('still scopes to the requested diver', () async {
      await insertDiver('d1');
      await insertDiver('d2');
      await repository.createTag(tagOf('tag-a', 'Wreck', diverId: 'd1'));
      await repository.createTag(tagOf('tag-b', 'Wreck', diverId: 'd2'));

      final found = await repository.getTagByName('Wreck', diverId: 'd2');
      expect(found?.id, 'tag-b');
    });
  });

  group('createTag', () {
    test('returns the existing tag instead of duplicating the name', () async {
      await insertDiver('d1');
      final first = await repository.createTag(
        tagOf('tag-a', 'Wreck', diverId: 'd1'),
      );
      final second = await repository.createTag(
        tagOf('tag-b', 'wreck', diverId: 'd1'),
      );

      expect(second.id, first.id);
      expect((await repository.getAllTags()).length, 1);
    });
  });

  group('updateTag', () {
    test('renaming onto an existing name folds the two together', () async {
      await insertDiver('d1');
      await insertDive('dive-1');
      await repository.createTag(tagOf('tag-a', 'Wreck', diverId: 'd1'));
      await repository.createTag(tagOf('tag-b', 'Wrek', diverId: 'd1'));
      await repository.addTagToDive('dive-1', 'tag-b');

      await repository.updateTag(tagOf('tag-b', 'Wreck', diverId: 'd1'));

      expect((await repository.getAllTags()).length, 1);
      final onDive = await repository.getTagsForDive('dive-1');
      expect(onDive.map((t) => t.name), ['Wreck']);
    });
  });

  group('getOrCreateTag', () {
    test('is idempotent for the same name', () async {
      await insertDiver('d1');
      final a = await repository.getOrCreateTag('Boat', diverId: 'd1');
      final b = await repository.getOrCreateTag('boat', diverId: 'd1');

      expect(b.id, a.id);
      expect((await repository.getAllTags()).length, 1);
    });
  });

  group('addTagToDive', () {
    test('adding the same tag twice keeps one junction row', () async {
      await insertDive('dive-1');
      await repository.createTag(tagOf('tag-a', 'Wreck'));

      await repository.addTagToDive('dive-1', 'tag-a');
      await repository.addTagToDive('dive-1', 'tag-a');

      expect(await junctionCount('dive-1', 'tag-a'), 1);
      expect((await repository.getTagsForDive('dive-1')).length, 1);
    });
  });

  group('setTagsForDive', () {
    test('a repeated tag in the list lands once', () async {
      await insertDive('dive-1');
      final tag = await repository.createTag(tagOf('tag-a', 'Wreck'));

      await repository.setTagsForDive('dive-1', [tag, tag]);

      expect(await junctionCount('dive-1', 'tag-a'), 1);
    });
  });

  group('bulk dive edits', () {
    test('bulkAddTags skips a tag the dive already carries', () async {
      await insertDive('dive-1');
      await repository.createTag(tagOf('tag-a', 'Wreck'));
      await repository.addTagToDive('dive-1', 'tag-a');

      await DiveRepository().bulkAddTags(['dive-1'], ['tag-a']);

      expect(await junctionCount('dive-1', 'tag-a'), 1);
    });

    test('bulkReplaceTags collapses a repeated tag id', () async {
      await insertDive('dive-1');
      await repository.createTag(tagOf('tag-a', 'Wreck'));

      await DiveRepository().bulkReplaceTags(['dive-1'], ['tag-a', 'tag-a']);

      expect(await junctionCount('dive-1', 'tag-a'), 1);
    });
  });
}

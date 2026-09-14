# Equipment Tags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver tag equipment items from the shared tag list (a third tag scope), and see, filter, search, bulk edit, sync, export and import those tags (issue #1942).

**Architecture:** A scope registry (`TagScopeTable`, one descriptor per scope) first replaces the per-scope booleans in the tag code, with no behavior change. Schema rung v219 then adds `tags.applies_to_equipment` and an `equipment_tags` junction, a clockless child of `equipment` (#1769) owned by a new `EquipmentTagRepository`. Tags never live on `EquipmentItem`; the UI reads them through providers, and the equipment list loads them in one batch query.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, go_router, `xml` builder, CSV codecs, `flutter gen-l10n` (11 ARB locales).

**Spec:** `docs/superpowers/specs/2026-09-13-equipment-tags-design.md`

## Global Constraints

- Base: main at 3387357b169. Branch `ericgriffin/equipment-tagging-ability-f140f6`. Issue #1942; the PR body says `Closes #1942`.
- Schema: `currentSchemaVersion` becomes 219 (v218 is #1899's site detail columns); `minimumCompatibleSchemaVersion` stays 210. If main claims 219 first, renumber at merge time.
- Existing tags migrate to `applies_to_equipment = 0`. A tag applies to at least one scope.
- Junction writers are conflict-safe (`DoNothing`), mark only the junction row pending (entity `equipmentTags`), and never mark or re-stamp the equipment row.
- `EquipmentItem` gains no tag field. `createEquipment` and `updateEquipment` never touch tags.
- Nouns: counts in Manage Tags and every delete/merge confirmation say "equipment item(s)"; the bulk sheet title and SnackBar say "items" ("Edit tags on 3 items"); bulk confirm headings say "equipment items".
- Delete and merge wording: one whole ICU message per combination of affected scopes.
- Translations land in the task that adds or rewords a key: all 10 non-English locales (ar, de, es, fr, he, hu, it, nl, pt, zh), then `flutter gen-l10n`, then `flutter test test/l10n/` green, then stage all 11 ARB files and the regenerated `lib/l10n/arb/app_localizations*.dart`. In `app_en.arb` insert beside the key's family (the `tags_manage_*` and `equipment_*` blocks are grouped by feature, not sorted); in the other locales insert beside a neighbouring key of the same family.
- Line numbers cited for a file are main's (3387357b169). When an earlier task in this plan has already changed that file, locate the edit point by the named symbol instead.
- Tests first. Run test files individually while iterating (`flutter test <file>`); never start overlapping `flutter test` runs. One full-suite run happens in Task 12 only.
- After adding or changing any `lib/` file, also run `flutter test test/architecture/` before calling the task green: those guards scan all of `lib/`.
- When a task changes a shared widget (adds `context.l10n`, a provider watch, or a constructor parameter), run every test file that pumps it (`grep -rl <WidgetName> test/`), not only the new test.
- `database.g.dart` and other generated Drift/Riverpod outputs are gitignored: regenerate with `dart run build_runner build --delete-conflicting-outputs` (or `bash scripts/setup.sh` if that command is refused) and never stage them.
- About 76 `.dart` files are committed with CRLF endings. Prefer the Edit tool; after any scripted edit check `git diff --numstat` for a whole-file rewrite.
- A `_db.batch` closure is synchronous: `markRecordPending` goes after it, never inside.
- Run `dart format .` before every commit. Stage explicit paths only, never `git add -A` or `git add .`.
- Commit messages: conventional commits ending in `(#1942)`, body in plain prose.
- No em-dashes anywhere (code, comments, commit messages); no en-dash, " -- " or " - " as prose punctuation; do not add new "--" in comments. No emojis. No tool or model attribution anywhere: no co-author trailers, no "generated with" lines, no session links, in commits, files or PR text.

## Task Order

| Task | Commit |
| --- | --- |
| 1a | Scope registry in the core layer (duplicate repair and sync fold) |
| 1b | `Tag.scopes`, per-scope usage maps, and every caller |
| 2 | Shared bulk-edit widgets moved to `lib/shared/bulk_edit/` |
| 3 | Schema v219, `EquipmentTagRepository`, equipment scope arms |
| 4 | Sync registration of `equipmentTags` |
| 5 | Equipment edit page Tags field and detail page chips |
| 6 | List chips, `EquipmentField.tags`, filter, search, tag navigation |
| 7 | Manage Tags delete and merge wording for three scopes |
| 8 | Bulk tag editing with undo |
| 9 | UDDF round trip |
| 10 | CSV round trip |
| 11 | Translation review |
| 12 | Verification |

---

## Design Notes

Findings from reading the code while planning. They explain choices the tasks make; read the notes for your task's area before starting it.

### Scope registry (Task 1)

1. **The older-peer scope rule is generic, not scope code.** The rule is that a
   `tags` row from an older peer with no scope key keeps the local value. It
   comes from `SyncService._overlayOntoLocal`
   (`lib/core/services/sync/sync_service.dart:2915`, `{...local, ...remote}`),
   which applies to every entity. It is pinned for sites by the "older peers"
   group in `test/core/services/sync/site_classification_sync_test.dart:310`.
   There is nothing to generalize in Task 1. Task 4 only needs an equipment
   copy of that test.
2. **The `site_tags` unique index is not in `tag_uniqueness.dart`.** It lives in
   `lib/core/database/site_classification_uniqueness.dart`
   (`kSiteTagsUniqueIndexName`, `assertSiteClassificationUniqueness`). Task 3
   decides where `idx_equipment_tags_equipment_tag_unique` goes; the spec's
   "next to the dive_tags and site_tags indexes" does not match the code.
3. **`collapseDuplicateTags` already skipped a missing `site_tags`**
   (`tag_uniqueness.dart:175`). The registry version generalizes that. Unifying
   the per-junction SQL brings two deliberate changes, both covered by tests:
   - `dive_tags` is now repointed with `UPDATE OR IGNORE`, like `site_tags`.
     Suppose the tags index is missing, `idx_dive_tags_dive_tag_unique` still
     stands, and one dive carries both a losing tag and its survivor. The old
     plain `UPDATE` then threw inside `beforeOpen`. The new code collapses the
     links instead. This is a strict fix.
   - Every junction also deletes the links still pointing at a losing tag,
     before the losers are deleted. The site orphan sweep
     (`DELETE FROM site_tags WHERE tag_id NOT IN tags`) is kept, as a
     registry flag, `TagScopeTable.sweepsOrphanLinks`, true for sites only:
     a blanket orphan sweep over `dive_tags` would break the v149 rule pinned
     by `migration_v149_tag_uniqueness_test.dart:226` ("a junction row whose
     tag is already gone survives untouched"). (Review of #1963: the first
     draft dropped the site sweep, which left orphaned site links in place.)
4. **The stats-scope census stops seeing three queries.**
   `test/core/database/dive_stats_scope_census_test.dart` matches the literal
   `FROM dive_tags`. The registry generates `FROM ${...}`, so `getTagUsage`,
   `getMergedUsage` and `getTagStatistics` drop out of its scan: 97 scanned
   members become 94, still well above the floor of 25. Their
   `stats-scope-exempt` markers are kept.
5. **`tagStatisticsProvider` refreshes a little more often.** It now also
   refreshes on `dive_tags` writes, because `watchTagLinkChanges` covers every
   junction. It already refreshed on every `dives` write, so this only adds
   refreshes.

### Schema and sync (Tasks 3 and 4)

Facts the steps rely on (verified against main): the `site_tags` unique
index lives in `lib/core/database/site_classification_uniqueness.dart`, not
`tag_uniqueness.dart`; parent-gated children reach `fetchRecords` through
`parentGatedTables`, so `equipmentTags` needs no `fetchRecords` case;
`_defaultTargets` in `lib/core/services/sync/conflict_reference.dart` already
maps `equipmentId` and `tagId`, so conflict references need no code; an older
peer's tag row without `appliesToEquipment` keeps the local value through
`SyncService._overlayOntoLocal` when the tag exists, and gets the column
default through `_withSchemaDefaults` (#858) when it does not.
`getTagsForEquipment` orders by name as `getTagsForSite` does;
`getTagIdsByEquipment` orders by `created_at, id`.
`DiverRepository.deleteDiver` deletes equipment with raw SQL and tombstones no
children (the same gap `site_tags` has); out of scope and unchanged.


### Bulk editing (Tasks 2 and 8)

1. **`absentStartsChecked`.** `_defaultChoice` (`bulk_membership_editor.dart:173-177` on main) starts a row that is on none of the selection as `ensureOn`, because the dive page lists only rows already on some dive or just picked. The equipment sheet lists every equipment-scoped tag, so with that default Apply would put every unused tag on every item. Task 2 adds `absentStartsChecked` (default `true`, dives unchanged); the sheet passes `false`, and tags picked through Add are switched on with the existing `ensureOn` request.
2. **All five row strings are caller-supplied.** Several locales make the row subtitles agree with the noun (es "en todas las {count}", fr "sur toutes les", it "su tutte le", hu "mind a {count} merülésen", zh "全部 {count} 次潜水"), so `BulkMembershipLabels` carries all five plus the add label, and equipment gets its own keys.
3. **Dives have no bulk tag sheet.** Dive bulk tags are one editor inside `DiveEditPage(bulkDiveIds:)`, applied by `BulkDiveEditService.apply`, which reads its snapshot outside the transaction. The equipment service reads inside, as the spec asks; dives are not changed.
4. **Cancel semantics.** Cancel on the confirm dialog returns to the sheet with the edits kept; closing the sheet (Cancel button, scrim, drag) returns `BulkActionOutcome.cancelled`. Both leave the selection and the data untouched.
5. **Undo guard.** Undo skips an item deleted since Apply and leaves out a tag deleted since, so it never recreates a link to a missing row (the foreign keys would throw and roll back every other item's restore).
6. **The dive add-tags dialog is not extracted.** `_bulkAddTags` in `dive_edit_page.dart` uses `diveLog_edit_cancel` / `diveLog_edit_add`, whose he and hu translations differ from `common_action_cancel` / `common_action_add`; extracting it would change the dive dialog's wording there. The sheet carries its own copy with the `common_action_*` keys.
7. **`app_en.arb` is not globally alphabetical.** Task 8 inserts its keys beside the `equipment_*` family, right after `equipment_appBar_title`.

### Equipment pages, list, filter, search (Tasks 5 and 6)

1. **Detail chips are a new `EquipmentTagChips`, not `TagChips`.** `TagChips` (`tag_input_widget.dart:251-298`) is the compact list widget: plain `Container`s, no tap, cut at `maxTags` with a "+N" box. The dive and site detail tags draw `ActionChip`s, so Task 5 draws `Chip`s and Task 6 turns them into `ActionChip`s. `TagChips(tags: tags, maxTags: 3)` is used on the detailed list tile.
2. **The save is two new repository methods, not a parameter on `createEquipment` / `updateEquipment`.** A new parameter would break test code that overrides those two (`uddf_entity_importer_test.mocks.dart`, `universal_adapter_test.mocks.dart`, `other_gear_retype_service_test.dart`) and would blur "`updateEquipment` never touches tags". `EquipmentListNotifier.addEquipment` / `.updateEquipment` gain an optional `List<String>? tagIds` (null leaves tags alone).
3. **`EquipmentFilterState.apply` takes a required `Map<String, Iterable<String>>`**, so no call site can forget it and silently match nothing on a tag filter. `EquipmentFieldAdapter` gains `tagNames`, so the domain constant file does not import the tags feature. `EquipmentListTile` gains `tags` and reads no provider, so no other tile test needs an override.
4. **The detail header shows name and type**, not brand and model (`_buildHeaderSection`); the chip row is the header text column's last child, which covers the full page and the master-detail pane.
5. **Card slots render nothing.** No equipment tile reads `equipmentDetailedCardConfigProvider` / `equipmentCompactCardConfigProvider`, so `EquipmentField.tags` shows in the table and the column picker, and the detailed tile shows chips through its own `tags` parameter.
6. **`openEquipmentWithTag` lands on the default status view**, which hides retired and sold gear. A chip on a retired item can therefore open a list without that item, so Task 6 adds `equipment_list_emptyState_noTagMatch`. Including retired items would need a new status value; out of scope.
7. **`equipmentSearchProvider` also ticks on tag changes**, since search now reads `equipment_tags` and `tags`.
8. **`createEquipment` notifies before the caller's transaction commits** when wrapped. The bus is debounced and the seeded clocks roll back with the row on failure; the new methods notify once more after the commit.

### Manage Tags and translations (Tasks 7 and 11)

- `app_en.arb` is not alphabetical in the `tags_manage_*` block (main
  12796-12982; #1849 and #1933 inserted beside each family), so Task 7
  inserts beside the family.
- #1933's Arabic dives and sites variants use only `=1`/`other`, which is
  wrong for 3 to 10 and for 11 and up. The new Arabic messages use
  `one`/`two`/`few`/`many`/`other`, as `trips_serviceAlert_count` already
  does; the existing #1933 lines are out of scope and stay. Hebrew keeps
  `=1`/`other` like #1933: the count is written as digits.
- The four reworded keys keep their names, so `arb_parity_test` cannot tell a
  stale translation from a fresh one. Task 7 rewrites all ten lines of each,
  and Task 11's guard test fails while any is still on its dives-and-sites
  text.

### UDDF and CSV (Tasks 9 and 10)

1. **The link pass also covers linked duplicates.** A flagged duplicate the diver skips or consolidates has its source id seeded into `equipmentIdMapping` by `preResolvedEquipmentIds` (#1824). The pass links every file item that resolves through that map, so re-importing a file unions its tags onto the existing item; `addTags` skips existing pairs, so this is idempotent.
2. **Widening goes by id.** `_linkSiteClassification` widens with `getOrCreateTag(tag.name, diverId: tag.diverId, ...)`, which for a tag with no diver is unscoped and can widen another profile's namesake. The equipment pass widens the exact row with `updateTag(tag.copyWith(scopes: ...))`. The site code is left alone.
3. **`PayloadDiverExpander` follows equipment tags.** Without it a multi-diver import sends an item's tag to the primary profile and drops the item's ref in the other profile. Task 9 adds the follow, as #1765 did for sites.
4. **CSV tag maps carry explicit scope flags.** `_importTags` defaults `appliesToDives` to true, so a CSV tag map with no flags would become a dive tag widened to equipment. The CSV parser writes dives false, sites false, equipment true; Task 9 moves the scope reading into `importedTagScopes` so both paths share one rule.
5. **No real-database `performImport` test existed.** Task 9 adds `wizard_import_harness.dart` (real repositories over the test database; buildBundle, checkDuplicates, performImport); Task 10 reuses it.
6. **`TagExtractor` is not reused** (#1848): it splits on commas while the equipment CSV uses the list codec, reads a different row shape, mints random uuids, dedupes by exact name rather than `lower(trim(name))`, and sets no scope. `EquipmentCsvTags` reproduces its output shape (`{id, uddfId, name}` plus `tagRefs`), so CSV and UDDF meet in one link pass.
7. **`PayloadMerger._enrich` does not union list fields.** When two files' namesake items fold, the survivor keeps its own `tagRefs`. Sites behave the same today. Not changed here.
8. **The metric CSV golden changes.** The Tags column is an agreed format change, so Task 10 regenerates `equipment_metric.csv`.
9. **The Excel equipment sheet gets no Tags column.** The spec names the CSV only.

---

### Task 1a: Scope registry in the core layer (duplicate repair and sync fold)

**Files:**
- Create: `lib/core/database/tag_scope_tables.dart`
- Modify: `lib/features/tags/domain/entities/tag.dart:1-5` (enum gains `table`; nothing else changes in 1a)
- Modify: `lib/features/tags/data/mappers/tag_row_mapper.dart` (add `tagScopesOf`, `tagScopeColumns`; `mapTagRow` unchanged in 1a)
- Modify: `lib/core/database/tag_uniqueness.dart:20` (import), `:67-188` (repoint, scope merge, collapse)
- Modify: `lib/core/services/sync/sync_data_serializer.dart:15`, `:23` (imports), `:2976-3001` (`_applyTagRecord` union), `:3016-3109` (`_foldTagInto`)
- Test (create): `test/core/database/tag_scope_tables_test.dart`
- Test (create): `test/core/database/tag_uniqueness_registry_test.dart`
- Test (create): `test/features/tags/data/mappers/tag_row_mapper_test.dart`

**Interfaces:**
- Consumes: the v217 schema (`tags.applies_to_dives`, `tags.applies_to_sites`, `dive_tags`, `site_tags`), `SyncRepository.hlcTargets`.
- Produces:
  - `class TagScopeTable { const TagScopeTable({required String scopeColumn, required String junctionTable, required String parentColumn, required String syncEntity, String? restampedParentTable}); }`
  - `const diveTagScopeTable`, `const siteTagScopeTable`, `const List<TagScopeTable> tagScopeTables = [diveTagScopeTable, siteTagScopeTable];`
  - `TagScopeTable get table` on `enum TagScope`
  - `Set<domain.TagScope> tagScopesOf(Tag row)`, `Map<String, Expression> tagScopeColumns(Set<domain.TagScope> scopes)`
  - `collapseDuplicateTags(DatabaseConnectionUser db)`, unchanged signature, now driven by the registry

- [ ] **Step 1: Write the failing tests**

Create `test/core/database/tag_scope_tables_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_scope_tables.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The tag scope registry (issue #1942): one entry per scope a tag can apply
/// to, shared by migrations, the tag repository and sync.
void main() {
  test('TagScope follows the registry, in registry order', () {
    expect([for (final scope in TagScope.values) scope.table], tagScopeTables);
  });

  test('dives and sites keep their columns, tables and parent rule', () {
    expect(TagScope.dives.table, same(diveTagScopeTable));
    expect(diveTagScopeTable.scopeColumn, 'applies_to_dives');
    expect(diveTagScopeTable.junctionTable, 'dive_tags');
    expect(diveTagScopeTable.parentColumn, 'dive_id');
    expect(diveTagScopeTable.syncEntity, 'diveTags');
    expect(diveTagScopeTable.restampedParentTable, 'dives');

    expect(TagScope.sites.table, same(siteTagScopeTable));
    expect(siteTagScopeTable.scopeColumn, 'applies_to_sites');
    expect(siteTagScopeTable.junctionTable, 'site_tags');
    expect(siteTagScopeTable.parentColumn, 'site_id');
    expect(siteTagScopeTable.syncEntity, 'siteTags');
    expect(
      siteTagScopeTable.restampedParentTable,
      isNull,
      reason: 'site links are clockless children (#1769)',
    );
  });

  test('no two scopes share a column, a junction or a sync entity', () {
    final columns = tagScopeTables.map((t) => t.scopeColumn).toList();
    final junctions = tagScopeTables.map((t) => t.junctionTable).toList();
    final entities = tagScopeTables.map((t) => t.syncEntity).toList();
    expect(columns.toSet(), hasLength(columns.length));
    expect(junctions.toSet(), hasLength(junctions.length));
    expect(entities.toSet(), hasLength(entities.length));
  });

  test('every registry entry names real schema', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    Future<Set<String>> columnsOf(String table) async => {
      for (final column
          in await db.customSelect("PRAGMA table_info('$table')").get())
        column.read<String>('name'),
    };

    final tagColumns = await columnsOf('tags');
    for (final entry in tagScopeTables) {
      expect(tagColumns, contains(entry.scopeColumn));
      expect(
        await columnsOf(entry.junctionTable),
        containsAll(['id', entry.parentColumn, 'tag_id', 'created_at', 'hlc']),
      );
      expect(
        db.allTables.map((t) => t.actualTableName),
        contains(entry.junctionTable),
        reason: 'registry-driven writes look the Drift table up by name',
      );
    }
  });

  test('a re-stamped parent is a synced entity of the same name', () {
    for (final entry in tagScopeTables) {
      final parent = entry.restampedParentTable;
      if (parent == null) continue;
      expect(SyncRepository.hlcTargets[parent]?.table, parent);
    }
  });
}
```

Create `test/core/database/tag_uniqueness_registry_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_uniqueness.dart';

/// A connection with no schema of its own and no migrations, so a test can
/// hand [collapseDuplicateTags] exactly the tables the v149 rung sees.
class _BareDb extends GeneratedDatabase {
  _BareDb(super.e);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

/// The duplicate-tag repair runs over the tag scope registry (issue #1942).
/// It runs from the v149 rung, long before v217 created `site_tags` and the
/// scope columns, so it must use only the schema that exists.
void main() {
  Future<List<String>> pairs(
    DatabaseConnectionUser db,
    String table,
    String parent,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT $parent AS p, tag_id FROM $table ORDER BY $parent, tag_id',
        )
        .get();
    return [
      for (final row in rows)
        '${row.read<String>('p')}|${row.read<String>('tag_id')}',
    ];
  }

  test('a v148 schema (no scope columns, no site_tags) collapses '
      'without error', () async {
    final db = _BareDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('''
      CREATE TABLE tags (
        id TEXT NOT NULL PRIMARY KEY,
        diver_id TEXT,
        name TEXT NOT NULL,
        color TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await db.customStatement('''
      CREATE TABLE dive_tags (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at) '
      "VALUES ('a', 'Wreck', 0, 0), ('b', ' wreck', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) VALUES '
      "('dt1', 'd1', 'b', 0), ('dt2', 'd1', 'a', 0), ('dt3', 'd2', 'b', 0), "
      "('orphan', 'd3', 'gone', 0)",
    );

    await collapseDuplicateTags(db);

    final tags = await db.customSelect('SELECT id, name FROM tags').get();
    expect(tags.map((r) => r.read<String>('id')), ['a']);
    expect(await pairs(db, 'dive_tags', 'dive_id'), [
      'd1|a',
      'd2|a',
      'd3|gone',
    ], reason: 'a link whose tag is already gone is left as it was');
  });

  test('a dive holding a loser and its survivor keeps one link while the '
      'dive_tags index stands', () async {
    // Before the registry the dive junction was repointed with a plain
    // UPDATE, which threw here on idx_dive_tags_dive_tag_unique.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('DROP INDEX IF EXISTS $kTagsUniqueIndexName');
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at) '
      "VALUES ('a', 'Night', 0, 0), ('b', 'night', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) '
      "VALUES ('x', 'd1', 'a', 0), ('y', 'd1', 'b', 0)",
    );

    await collapseDuplicateTags(db);

    final links = await db
        .customSelect('SELECT id, tag_id FROM dive_tags')
        .get();
    expect(
      links.map((r) => (r.read<String>('id'), r.read<String>('tag_id'))),
      [('x', 'a')],
    );
  });

  test('links on a losing tag move in every registry junction', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('DROP INDEX IF EXISTS $kTagsUniqueIndexName');
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_sites (id, name, created_at, updated_at) '
      "VALUES ('s1', 'Site', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites) '
      "VALUES ('a', 'To try', 0, 0, 1, 0), ('b', 'to try', 0, 0, 0, 1)",
    );
    await db.customStatement(
      'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) '
      "VALUES ('dt', 'd1', 'b', 0)",
    );
    await db.customStatement(
      'INSERT INTO site_tags (id, site_id, tag_id, created_at) '
      "VALUES ('st', 's1', 'b', 0)",
    );

    await collapseDuplicateTags(db);

    expect(await pairs(db, 'dive_tags', 'dive_id'), ['d1|a']);
    expect(await pairs(db, 'site_tags', 'site_id'), ['s1|a']);
    final survivor = await db
        .customSelect(
          'SELECT applies_to_dives AS d, applies_to_sites AS s FROM tags',
        )
        .getSingle();
    expect((survivor.read<int>('d'), survivor.read<int>('s')), (1, 1));
  });
}
```

Create `test/features/tags/data/mappers/tag_row_mapper_test.dart`:

```dart
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_scope_tables.dart';
import 'package:submersion/features/tags/data/mappers/tag_row_mapper.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart'
    show TagScope;

/// The row mapper converts between the `tags` flag columns and a set of
/// scopes (issue #1942).
void main() {
  Tag row({required bool dives, required bool sites}) => Tag(
    id: 't',
    name: 'T',
    createdAt: 0,
    updatedAt: 0,
    appliesToDives: dives,
    appliesToSites: sites,
  );

  test('reads each flag column into the set', () {
    expect(tagScopesOf(row(dives: true, sites: false)), {TagScope.dives});
    expect(tagScopesOf(row(dives: false, sites: true)), {TagScope.sites});
    expect(tagScopesOf(row(dives: true, sites: true)), {
      TagScope.dives,
      TagScope.sites,
    });
    expect(tagScopesOf(row(dives: false, sites: false)), isEmpty);
  });

  test('writes a value for every registry column', () {
    final columns = tagScopeColumns({TagScope.sites});
    expect(columns.keys, [for (final t in tagScopeTables) t.scopeColumn]);
    expect((columns['applies_to_sites']! as Variable<bool>).value, isTrue);
    expect((columns['applies_to_dives']! as Variable<bool>).value, isFalse);
  });
}
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `flutter test test/core/database/tag_scope_tables_test.dart test/core/database/tag_uniqueness_registry_test.dart test/features/tags/data/mappers/tag_row_mapper_test.dart`

Expected: FAIL to compile. The URI `package:submersion/core/database/tag_scope_tables.dart` does not exist, `table` is not defined for `TagScope`, and `tagScopesOf` / `tagScopeColumns` are not defined.

- [ ] **Step 3: Create the registry**

Create `lib/core/database/tag_scope_tables.dart`:

```dart
/// The tag scope registry (issue #1942): where each scope a tag can apply to
/// keeps its flag and its links.
///
/// One const entry per scope, shared by the migration code (which runs before
/// the typed tables exist, so it can only use names), the tag repository and
/// sync. Registry order is the display order, and `TagScope.values` follows
/// it. A new scope appends its entry to [tagScopeTables] and its member to
/// `TagScope`.
///
/// Deliberately import-free, so the domain `TagScope` can depend on it.
library;

/// Where one tag scope stores its flag and its links.
class TagScopeTable {
  const TagScopeTable({
    required this.scopeColumn,
    required this.junctionTable,
    required this.parentColumn,
    required this.syncEntity,
    this.restampedParentTable,
  });

  /// The `tags` flag column saying the tag is offered in this scope.
  final String scopeColumn;

  /// The junction linking a tag to the items of this scope. It has a
  /// surrogate `id`, [parentColumn], `tag_id`, `created_at` and `hlc`.
  final String junctionTable;

  /// The junction column naming the linked item.
  final String parentColumn;

  /// The sync entity type of the junction rows.
  final String syncEntity;

  /// The parent table a tag merge re-stamps when it relinks one of its rows
  /// (`updated_at` bumped, the row marked pending), or null when the links
  /// are clockless children that never touch their parent (#1769). The name
  /// doubles as the parent's sync entity type, which holds for `dives`.
  /// Narrowing a scope never re-stamps a parent.
  final String? restampedParentTable;
}

/// Dive tags. A tag merge has always re-stamped the dives it relinks.
const diveTagScopeTable = TagScopeTable(
  scopeColumn: 'applies_to_dives',
  junctionTable: 'dive_tags',
  parentColumn: 'dive_id',
  syncEntity: 'diveTags',
  restampedParentTable: 'dives',
);

/// Dive site tags (v217, issue #1765).
const siteTagScopeTable = TagScopeTable(
  scopeColumn: 'applies_to_sites',
  junctionTable: 'site_tags',
  parentColumn: 'site_id',
  syncEntity: 'siteTags',
);

/// Every scope, in display order.
const List<TagScopeTable> tagScopeTables = [
  diveTagScopeTable,
  siteTagScopeTable,
];
```

- [ ] **Step 4: Point `TagScope` at the registry**

In `lib/features/tags/domain/entities/tag.dart`, replace lines 1-5:

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Where a tag is offered (issue #1765). A tag applies to at least one.
enum TagScope { dives, sites }
```

with:

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/database/tag_scope_tables.dart';

/// Where a tag is offered (issues #1765, #1942). A tag applies to at least
/// one. Member order follows [tagScopeTables], which is the display order.
enum TagScope {
  dives,
  sites;

  /// Where this scope stores its flag and its links.
  TagScopeTable get table => switch (this) {
    TagScope.dives => diveTagScopeTable,
    TagScope.sites => siteTagScopeTable,
  };
}
```

- [ ] **Step 5: Add the mapper helpers**

Replace the whole of `lib/features/tags/data/mappers/tag_row_mapper.dart` with the following. `mapTagRow` keeps its body in this commit; Task 1b switches it to `tagScopesOf`.

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

/// Maps a `tags` row to its domain entity. Shared by every reader, so a new
/// column (like the v217 scope flags) is mapped in exactly one place.
domain.Tag mapTagRow(Tag row) {
  return domain.Tag(
    id: row.id,
    diverId: row.diverId,
    name: row.name,
    colorHex: row.color,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    appliesToDives: row.appliesToDives,
    appliesToSites: row.appliesToSites,
  );
}

/// The scopes a `tags` row's flag columns switch on (issue #1942). One arm
/// per scope, so a new scope does not compile until its column is read here.
Set<domain.TagScope> tagScopesOf(Tag row) => {
  for (final scope in domain.TagScope.values)
    if (switch (scope) {
      domain.TagScope.dives => row.appliesToDives,
      domain.TagScope.sites => row.appliesToSites,
    })
      scope,
};

/// The `tags` flag column values for [scopes], keyed by column name. Every
/// registry scope gets a value, true when [scopes] holds it, so a write can
/// never leave a flag at a stale value. Wrap in `RawValuesInsertable<Tag>`,
/// alone or spread beside a companion's `toColumns(false)`.
Map<String, Expression> tagScopeColumns(Set<domain.TagScope> scopes) => {
  for (final scope in domain.TagScope.values)
    scope.table.scopeColumn: Variable<bool>(scopes.contains(scope)),
};
```

- [ ] **Step 6: Drive the duplicate repair through the registry**

In `lib/core/database/tag_uniqueness.dart`, change the import block at line 20 from:

```dart
import 'package:drift/drift.dart';
```

to:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/tag_scope_tables.dart';
```

Then replace everything from line 67 (`/// Repoints every \`dive_tags\` row at the surviving tag of its group.`) through line 188 (the closing `}` of `collapseDuplicateTags`) with the block below. `_normalizeTagNamesSql` (lines 57-65) and `_tableExists` stay as they are, and the block re-declares `_tableExists` unchanged. Everything after line 188 (`assertTagUniqueness`, `_normalizeSql`) is unchanged.

```dart
/// Tag ids that lose the collapse: every id but the lexically lowest of its
/// (diver scope, case-folded name) group.
const String _losingTagIdsSql = '''
  SELECT id FROM tags WHERE id NOT IN (
    SELECT MIN(id) FROM tags GROUP BY COALESCE(diver_id, ''), lower(trim(name))
  )
''';

/// Repoints every link in [junction] at the surviving tag of its group.
///
/// The survivor is the lexically lowest `id` in the group. It has to be a
/// property of the rows themselves rather than of this device (oldest
/// `created_at` ties inside a single import millisecond, and "the one we had
/// first" differs per device), so every device that runs this, or the
/// equivalent merge-time reconciliation, lands on the same tag.
///
/// The `WHERE EXISTS` guard matters: `tag_id` is NOT NULL, and a row pointing
/// at an already-missing tag would otherwise resolve to NULL and abort the
/// statement. Such a row is left exactly as it is.
///
/// `OR IGNORE` because the junction's unique index can already exist when
/// this runs (`site_tags` has it from the day the table exists): an item
/// holding both the loser and the survivor keeps its survivor row, and
/// [_deleteLinksOnLosingTagsSql] sweeps the skipped one. Before the scope
/// registry (#1942) only `site_tags` had the `OR IGNORE`, and on `dive_tags`
/// that case threw instead.
String _repointToSurvivorSql(TagScopeTable junction) {
  final table = junction.junctionTable;
  return '''
  UPDATE OR IGNORE $table SET tag_id = (
    SELECT MIN(survivor.id) FROM tags survivor, tags mine
    WHERE mine.id = $table.tag_id
      AND COALESCE(survivor.diver_id, '') = COALESCE(mine.diver_id, '')
      AND lower(trim(survivor.name)) = lower(trim(mine.name))
  )
  WHERE EXISTS (SELECT 1 FROM tags t WHERE t.id = $table.tag_id)
''';
}

/// Links the `OR IGNORE` repoint skipped: rows still on a losing tag, whose
/// item already carries the survivor. Deleted before the losing tags go, so
/// the outcome does not depend on foreign keys cascading them.
String _deleteLinksOnLosingTagsSql(TagScopeTable junction) =>
    'DELETE FROM ${junction.junctionTable} '
    'WHERE tag_id IN ($_losingTagIdsSql)';

/// Gives the surviving tag of each group the union of the group's scopes, so
/// collapsing a dive tag and a site tag of the same name keeps both uses
/// (v217, issue #1765). [columns] are the scope flag columns that exist.
String _mergeScopesIntoSurvivorSql(List<String> columns) {
  final assignments = [
    for (final column in columns)
      '$column = (SELECT MAX(o.$column) FROM tags o '
          "WHERE COALESCE(o.diver_id, '') = COALESCE(tags.diver_id, '') "
          'AND lower(trim(o.name)) = lower(trim(tags.name)))',
  ];
  return 'UPDATE tags SET ${assignments.join(', ')}';
}

const String _deleteLosingTagsSql = '''
  DELETE FROM tags WHERE id NOT IN (
    SELECT MIN(id) FROM tags GROUP BY COALESCE(diver_id, ''), lower(trim(name))
  )
''';

/// Keeps one row per (item, tag) in [junction]. `rowid` is a total order, so
/// this can never leave a tie behind. A tie-blind cleanup keyed on
/// `created_at` would, and the unique index created straight afterwards
/// would then abort the whole migration and leave the database unopenable.
String _collapseDuplicateLinksSql(TagScopeTable junction) {
  final table = junction.junctionTable;
  return '''
  DELETE FROM $table WHERE rowid NOT IN (
    SELECT MIN(rowid) FROM $table GROUP BY ${junction.parentColumn}, tag_id
  )
''';
}

Future<bool> _tableExists(DatabaseConnectionUser db, String name) async {
  final rows = await db
      .customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(name)],
      )
      .get();
  return rows.isNotEmpty;
}

Future<Set<String>> _columnsOf(DatabaseConnectionUser db, String table) async {
  final columns = await db.customSelect("PRAGMA table_info('$table')").get();
  return {for (final column in columns) column.read<String>('name')};
}

/// Collapses duplicate tags and duplicate links, in the only order that
/// leaves no ties: normalize the names the grouping keys on, give each
/// survivor the union of its group's scopes, repoint every junction in the
/// tag scope registry at the surviving tag, drop the links that repoint
/// skipped, drop the losing tags, then collapse the duplicate links the
/// repoint created.
///
/// Idempotent: every statement is a no-op on already-clean data. It runs
/// from the v149 rung, before v217 created `site_tags` and the scope
/// columns, so each junction and each scope column is used only when the
/// schema already has it.
Future<void> collapseDuplicateTags(DatabaseConnectionUser db) async {
  final junctions = <TagScopeTable>[
    for (final junction in tagScopeTables)
      if (await _tableExists(db, junction.junctionTable)) junction,
  ];
  final tagColumns = await _columnsOf(db, 'tags');
  final scopeColumns = [
    for (final junction in tagScopeTables)
      if (tagColumns.contains(junction.scopeColumn)) junction.scopeColumn,
  ];

  await db.customStatement(_normalizeTagNamesSql);
  if (scopeColumns.isNotEmpty) {
    await db.customStatement(_mergeScopesIntoSurvivorSql(scopeColumns));
  }
  for (final junction in junctions) {
    await db.customStatement(_repointToSurvivorSql(junction));
  }
  for (final junction in junctions) {
    await db.customStatement(_deleteLinksOnLosingTagsSql(junction));
  }
  await db.customStatement(_deleteLosingTagsSql);
  for (final junction in junctions) {
    await db.customStatement(_collapseDuplicateLinksSql(junction));
  }
}
```

(This removes `_repointDiveTagsToSurvivorSql`, `_repointSiteTagsToSurvivorSql`, the const `_mergeScopesIntoSurvivorSql`, `_deleteOrphanSiteTagsSql`, `_collapseDuplicateSiteTagsSql`, `_collapseDuplicateDiveTagsSql` and `_columnExists`. Nothing outside the file referenced them: `grep -rn "_columnExists\|_repointDiveTags\|_collapseDuplicateDiveTags" lib` returns only these lines.)

- [ ] **Step 7: Drive the sync tag fold through the registry**

In `lib/core/services/sync/sync_data_serializer.dart`, add after line 15 (`import 'package:submersion/core/database/site_type_seed.dart';`):

```dart
import 'package:submersion/core/database/tag_scope_tables.dart';
```

and after line 23 (`import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';`):

```dart
import 'package:submersion/features/tags/data/mappers/tag_row_mapper.dart';
```

In `_applyTagRecord`, replace lines 2976-3001:

```dart
    final ids = [remote.id, for (final r in rivals) r.id]..sort();
    final survivor = ids.first;
    // The survivor keeps every use the folded rows had (v217, issue #1765):
    // folding a dive tag and a site tag of the same name must not drop
    // either scope.
    final anyDives =
        remote.appliesToDives || rivals.any((r) => r.appliesToDives);
    final anySites =
        remote.appliesToSites || rivals.any((r) => r.appliesToSites);
    for (final loser in ids.skip(1)) {
      await _foldTagInto(loser: loser, survivor: survivor);
    }
    if (survivor == remote.id) {
      await _db
          .into(_db.tags)
          .insertOnConflictUpdate(
            _normalizedTag(remote)
                .copyWith(appliesToDives: anyDives, appliesToSites: anySites)
                .toCompanion(false),
          );
    } else {
      await (_db.update(_db.tags)..where((t) => t.id.equals(survivor))).write(
        TagsCompanion(
          appliesToDives: Value(anyDives),
          appliesToSites: Value(anySites),
        ),
      );
    }
  }
```

with:

```dart
    final ids = [remote.id, for (final r in rivals) r.id]..sort();
    final survivor = ids.first;
    // The survivor keeps every use the folded rows had (v217, issue #1765):
    // folding a dive tag and a site tag of the same name must not drop
    // either scope. The union runs over the tag scope registry (#1942).
    final scopes = {
      ...tagScopesOf(remote),
      for (final rival in rivals) ...tagScopesOf(rival),
    };
    for (final loser in ids.skip(1)) {
      await _foldTagInto(loser: loser, survivor: survivor);
    }
    if (survivor == remote.id) {
      await _db
          .into(_db.tags)
          .insertOnConflictUpdate(
            RawValuesInsertable<Tag>({
              ..._normalizedTag(remote).toColumns(false),
              ...tagScopeColumns(scopes),
            }),
          );
    } else {
      await (_db.update(_db.tags)..where((t) => t.id.equals(survivor))).write(
        RawValuesInsertable<Tag>(tagScopeColumns(scopes)),
      );
    }
  }
```

Replace the first two lines of `_foldTagInto`'s doc comment (lines 3016-3017):

```dart
  /// Moves [loser]'s dive links onto [survivor], drops the losing tag row and
  /// remembers the alias.
```

with:

```dart
  /// Moves [loser]'s links onto [survivor] in every junction of the tag
  /// scope registry (#1942), drops the losing tag row and remembers the
  /// alias.
```

The rest of that doc comment stays. Replace the method body (lines 3039-3109, from `Future<void> _foldTagInto({` through its closing `}`) with:

```dart
  Future<void> _foldTagInto({
    required String loser,
    required String survivor,
  }) async {
    for (final junction in tagScopeTables) {
      await _foldTagLinks(junction, loser: loser, survivor: survivor);
    }
    await (_db.delete(_db.tags)..where((t) => t.id.equals(loser))).go();
    _tagIdAliases[loser] = survivor;
  }

  /// Repoints [junction]'s links from [loser] to [survivor], each marked
  /// pending. An item that already carries the survivor loses its loser link
  /// outright instead. Without the repoint, deleting the loser would cascade
  /// every link away. No parent is re-stamped (see [_foldTagInto]).
  Future<void> _foldTagLinks(
    TagScopeTable junction, {
    required String loser,
    required String survivor,
  }) async {
    final table = junction.junctionTable;
    final parent = junction.parentColumn;
    final moving = await _db
        .customSelect(
          'SELECT id, $parent AS parent_id FROM $table WHERE tag_id = ?',
          variables: [Variable.withString(loser)],
        )
        .get();
    if (moving.isEmpty) return;

    final covered = {
      for (final row in await _db
          .customSelect(
            'SELECT $parent AS parent_id FROM $table WHERE tag_id = ?',
            variables: [Variable.withString(survivor)],
          )
          .get())
        row.read<String>('parent_id'),
    };
    // Named so Drift refreshes the streams over this junction.
    final updates = {
      _db.allTables.firstWhere((t) => t.actualTableName == table),
    };
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in moving) {
      final id = row.read<String>('id');
      if (!covered.add(row.read<String>('parent_id'))) {
        await _db.customUpdate(
          'DELETE FROM $table WHERE id = ?',
          variables: [Variable.withString(id)],
          updates: updates,
          updateKind: UpdateKind.delete,
        );
        continue;
      }
      await _db.customUpdate(
        'UPDATE $table SET tag_id = ? WHERE id = ?',
        variables: [Variable.withString(survivor), Variable.withString(id)],
        updates: updates,
        updateKind: UpdateKind.update,
      );
      await _syncRepository.markRecordPending(
        entityType: junction.syncEntity,
        recordId: id,
        localUpdatedAt: now,
      );
    }
  }
```

(The fold still deletes a covered link outright rather than tombstoning it, and still re-stamps no parent. Both match the code it replaces.)

- [ ] **Step 8: Run the new tests and the regression set**

Run: `flutter test test/core/database/tag_scope_tables_test.dart test/core/database/tag_uniqueness_registry_test.dart test/features/tags/data/mappers/tag_row_mapper_test.dart`
Expected: PASS.

Run: `flutter test test/core/database/migration_v149_tag_uniqueness_test.dart test/core/database/tag_uniqueness_site_tags_test.dart test/core/database/migration_v217_site_classification_test.dart test/core/services/sync/sync_tag_identity_test.dart test/core/services/sync/site_classification_sync_test.dart`
Expected: PASS, unchanged. These are #1032's and #1849's intent: the v149 collapse rules, the site-tag OR, the loser-and-survivor site case, the fold keeping both scopes, and the older-peer scope rule.

Run: `flutter test test/architecture/`
Expected: PASS.

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 9: Commit**

```bash
dart format .
git add lib/core/database/tag_scope_tables.dart lib/core/database/tag_uniqueness.dart lib/core/services/sync/sync_data_serializer.dart lib/features/tags/domain/entities/tag.dart lib/features/tags/data/mappers/tag_row_mapper.dart test/core/database/tag_scope_tables_test.dart test/core/database/tag_uniqueness_registry_test.dart test/features/tags/data/mappers/tag_row_mapper_test.dart
git commit -m "refactor(tags): add the tag scope registry and repair and fold through it (#1942)" -m "A const registry in lib/core/database lists, for each tag scope, its flag column, junction table, parent column, sync entity and whether a relinked row re-stamps its parent. The duplicate-tag repair and the sync tag fold now loop over it instead of naming dive_tags and site_tags one by one. The repair uses only the junctions and scope columns the schema already has, since it runs from the v149 rung. It now repoints dive_tags with OR IGNORE as it did site_tags, so a dive carrying both a losing tag and its survivor no longer aborts the repair when the dive_tags index stands."
```

---

### Task 1b: `Tag.scopes`, per-scope usage maps, and every caller

**Files:**
- Modify: `lib/features/tags/domain/entities/tag.dart:15-105` (fields, constructor, `appliesTo`, `create`, `copyWith`, `props`)
- Modify: `lib/features/tags/data/mappers/tag_row_mapper.dart` (`mapTagRow` maps `scopes`)
- Modify: `lib/features/tags/data/repositories/tag_repository.dart` (import; `:27-30` watcher; `:45-52` `getAllTags`; `:171-185` `createTag` insert; `:279-301` `updateTag`; `:314-404` scope section and `getTagUsage`; `:649-689` `getTagStatistics`; `:714-748` `getMergedUsage`; `:803-943` `mergeTags` body; `:960-973` `TagStatistic`)
- Modify: `lib/features/tags/presentation/providers/tag_providers.dart:44`
- Create: `lib/features/tags/presentation/tag_scope_labels.dart`
- Modify: `lib/features/tags/presentation/tag_usage_messages.dart` (whole file)
- Modify: `lib/features/tags/presentation/pages/tag_manage_page.dart:11-12`, `:233-252`, `:276-277`, `:312-317`, `:334-344`, `:370-371`, `:405-410`, `:453-481`, `:558-628`, `:685-690`, `:727-733`
- Modify: `lib/features/tags/presentation/widgets/tag_merge_sheet.dart:26-35`, `:55-56`, `:172-177`, `:211-215`
- Modify: `lib/features/tags/presentation/widgets/tag_picker_sheet.dart:7-8`, `:66-88`, `:201-208`
- Modify: `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart:14`, `:766`
- Modify: `lib/features/dive_sites/presentation/widgets/site_filter_sheet.dart:505` (CRLF file: use the Edit tool only)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart:1092-1101`, `:1115-1119`, `:1226`
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart:1145-1152`
- Create (tests): `test/features/tags/tag_test_helpers.dart`, `test/features/tags/domain/entities/tag_test.dart`, `test/features/tags/presentation/tag_scope_labels_test.dart`, `test/features/tags/data/repositories/tag_scope_registry_test.dart`
- Modify (tests, spelling only): see Step 2

**Interfaces:**
- Consumes: Task 1a's `tagScopeTables`, `TagScopeTable`, `TagScope.table`, `tagScopesOf`, `tagScopeColumns`.
- Produces (the contract's fixed interfaces, plus CONTRACT CHANGES 3-4):
  - `Tag.scopes` (`Set<TagScope>`, default `const {TagScope.dives}`), `bool appliesTo(TagScope)`, `copyWith({..., Set<TagScope>? scopes})`, `Tag.create({..., TagScope scope = TagScope.dives})` sets exactly `{scope}`.
  - `Future<Map<TagScope, int>> getTagUsage(String tagId)`, `Future<Map<TagScope, int>> getMergedUsage(List<String> tagIds)`, both dense.
  - `Stream<void> watchTagLinkChanges()` (every registry junction); `watchSiteTagsChanges()` removed.
  - `class TagStatistic { final Tag tag; final Map<TagScope, int> counts; TagStatistic({required this.tag, this.counts = const {}}); int count(TagScope scope); }`. `getTagStatistics` orders by each scope's count DESC in registry order, then name.
  - `tagDeleteMessage(AppLocalizations l10n, String tagName, Map<TagScope, int> usage)`, `tagsBulkDeleteMessage(AppLocalizations l10n, Map<TagScope, int> usage)`, `tagsMergeAffectedMessage(AppLocalizations l10n, Map<TagScope, int> usage)`, `tagUsageCounts(AppLocalizations l10n, Map<TagScope, int> usage)`. All return exactly today's strings.
  - `tagScopeName`, `tagScopeUseForLabel`, `tagScopeCount`, `tagScopeNarrowLine` in `tag_scope_labels.dart`.

- [ ] **Step 1: Write the new failing tests**

Create `test/features/tags/tag_test_helpers.dart`:

```dart
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The dive and site entries of a usage map, so the #1849 and #1933
/// expectations written as `(dives: n, sites: m)` hold whatever other scopes
/// the registry gains. The `!` asserts the maps are dense: the repository
/// returns an entry for every scope.
({int dives, int sites}) divesAndSites(Map<TagScope, int> usage) =>
    (dives: usage[TagScope.dives]!, sites: usage[TagScope.sites]!);
```

Create `test/features/tags/domain/entities/tag_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// A tag's scopes are a set drawn from the registry (issue #1942).
void main() {
  final now = DateTime(2026);

  Tag tag({Set<TagScope>? scopes}) => scopes == null
      ? Tag(id: 't', name: 'T', createdAt: now, updatedAt: now)
      : Tag(id: 't', name: 'T', createdAt: now, updatedAt: now, scopes: scopes);

  test('a tag is a dive tag unless told otherwise', () {
    expect(tag().scopes, {TagScope.dives});
    expect(tag().appliesTo(TagScope.dives), isTrue);
    expect(tag().appliesTo(TagScope.sites), isFalse);
  });

  test('create offers the tag in exactly its one scope', () {
    for (final scope in TagScope.values) {
      expect(Tag.create(id: 't', name: 'T', scope: scope).scopes, {scope});
    }
  });

  test('copyWith replaces the scopes, and keeps them when not given', () {
    final both = tag().copyWith(scopes: const {TagScope.dives, TagScope.sites});
    expect(both.appliesTo(TagScope.sites), isTrue);
    expect(both.copyWith(name: 'U').scopes, both.scopes);
  });

  test('equality ignores the order the scopes were added in', () {
    final a = tag(scopes: {TagScope.dives, TagScope.sites});
    final b = tag(scopes: {TagScope.sites, TagScope.dives});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
```

Create `test/features/tags/presentation/tag_scope_labels_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_scope_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The per-scope wording of the tag screens (issue #1942) is today's
/// strings, looked up by scope.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('names each scope', () {
    expect(tagScopeName(l10n, TagScope.dives), 'Dives');
    expect(tagScopeName(l10n, TagScope.sites), 'Sites');
  });

  test('labels each scope checkbox', () {
    expect(tagScopeUseForLabel(l10n, TagScope.dives), 'Use for dives');
    expect(tagScopeUseForLabel(l10n, TagScope.sites), 'Use for sites');
  });

  test('counts each scope', () {
    expect(tagScopeCount(l10n, TagScope.dives, 1), '1 dive');
    expect(tagScopeCount(l10n, TagScope.sites, 3), '3 sites');
  });

  test('explains what turning each scope off removes', () {
    expect(
      tagScopeNarrowLine(l10n, TagScope.dives, 2),
      'This tag is on 2 dives. Turning off "Use for dives" removes it from '
      'those dives.',
    );
    expect(
      tagScopeNarrowLine(l10n, TagScope.sites, 1),
      'This tag is on 1 site. Turning off "Use for sites" removes it from '
      'that site.',
    );
  });
}
```

Create `test/features/tags/data/repositories/tag_scope_registry_test.dart`. These pin the results the per-scope code produced, on one fixture spanning both junctions. Every expectation holds on main today, apart from the new API spelling.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    show DiveTagsCompanion, SiteTagsCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';
import '../../tag_test_helpers.dart';

/// The tag scope registry drives every multi-scope path of TagRepository
/// (issue #1942). Same results as the per-scope code it replaced.
void main() {
  late TagRepository repository;

  Future<void> exec(String sql) =>
      DatabaseService.instance.database.customStatement(sql);

  Future<List<String>> rows(String sql) async => [
    for (final row
        in await DatabaseService.instance.database.customSelect(sql).get())
      row.data.values.join('|'),
  ];

  setUp(() async {
    await setUpTestDatabase();
    repository = TagRepository();
    await exec(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0), ('d2', 0, 0, 0)",
    );
    await exec(
      'INSERT INTO dive_sites (id, name, created_at, updated_at) '
      "VALUES ('s1', 'One', 0, 0), ('s2', 'Two', 0, 0)",
    );
    // Zulu: dives only. Bravo: sites only. Both: dives and sites.
    // Alpha: a dive tag nothing carries.
    await exec(
      'INSERT INTO tags (id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites) VALUES '
      "('zulu', 'Zulu', 0, 0, 1, 0), ('bravo', 'Bravo', 0, 0, 0, 1), "
      "('both', 'Both', 0, 0, 1, 1), ('idle', 'Alpha', 0, 0, 1, 0)",
    );
    await exec(
      'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) VALUES '
      "('dz1', 'd1', 'zulu', 0), ('dz2', 'd2', 'zulu', 0), "
      "('db1', 'd1', 'both', 0)",
    );
    await exec(
      'INSERT INTO site_tags (id, site_id, tag_id, created_at) VALUES '
      "('sb1', 's1', 'bravo', 0), ('sx1', 's1', 'both', 0), "
      "('sx2', 's2', 'both', 0)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  test('usage counts each scope separately', () async {
    expect(divesAndSites(await repository.getTagUsage('both')), (
      dives: 1,
      sites: 2,
    ));
    expect(divesAndSites(await repository.getTagUsage('idle')), (
      dives: 0,
      sites: 0,
    ));
  });

  test('usage maps carry every registry scope', () async {
    expect((await repository.getTagUsage('zulu')).keys, TagScope.values);
    expect((await repository.getMergedUsage(['zulu'])).keys, TagScope.values);
    expect((await repository.getMergedUsage([])).keys, TagScope.values);
  });

  test('merged usage counts an item carrying two of the tags once', () async {
    // d1 carries zulu and both; s1 carries bravo and both.
    final usage = await repository.getMergedUsage(['zulu', 'bravo', 'both']);
    expect(divesAndSites(usage), (dives: 2, sites: 2));
  });

  test('statistics order by dives, then sites, then name', () async {
    final stats = await repository.getTagStatistics();
    expect(stats.map((s) => s.tag.name), ['Zulu', 'Both', 'Bravo', 'Alpha']);
    final both = stats.singleWhere((s) => s.tag.id == 'both');
    expect(both.count(TagScope.dives), 1);
    expect(both.count(TagScope.sites), 2);
    expect(both.tag.scopes, {TagScope.dives, TagScope.sites});
  });

  test('a merge relinks every junction, unions the scopes and re-stamps '
      'only dives', () async {
    await repository.mergeTags(
      sourceTagIds: ['bravo', 'both'],
      survivingTagId: 'zulu',
      name: 'Zulu',
      colorHex: null,
    );

    expect(
      await rows('SELECT dive_id, tag_id FROM dive_tags ORDER BY dive_id'),
      ['d1|zulu', 'd2|zulu'],
    );
    expect(
      await rows('SELECT site_id, tag_id FROM site_tags ORDER BY site_id'),
      ['s1|zulu', 's2|zulu'],
    );
    expect((await repository.getTagById('zulu'))!.scopes, {
      TagScope.dives,
      TagScope.sites,
    });
    // Every source link is tombstoned, moved or dropped as covered.
    expect(
      await rows(
        'SELECT entity_type, record_id FROM deletion_log '
        "WHERE entity_type IN ('diveTags', 'siteTags') "
        'ORDER BY entity_type, record_id',
      ),
      ['diveTags|db1', 'siteTags|sb1', 'siteTags|sx1', 'siteTags|sx2'],
    );
    // A dive link re-stamps its dive; a site link is a clockless child.
    expect(
      await rows(
        "SELECT record_id FROM sync_records WHERE entity_type = 'dives'",
      ),
      ['d1'],
    );
    expect(
      await rows(
        "SELECT record_id FROM sync_records WHERE entity_type = 'diveSites'",
      ),
      isEmpty,
    );
    expect(await rows("SELECT updated_at FROM dives WHERE id = 'd2'"), ['0']);
  });

  test('narrowing removes and tombstones links and re-stamps no parent', () async {
    final tag = (await repository.getTagById('both'))!;
    await repository.updateTag(tag.copyWith(scopes: const {TagScope.sites}));

    expect(await rows("SELECT id FROM dive_tags WHERE tag_id = 'both'"), isEmpty);
    expect(
      await rows(
        "SELECT record_id FROM deletion_log WHERE entity_type = 'diveTags'",
      ),
      ['db1'],
    );
    expect(
      await rows(
        "SELECT record_id FROM sync_records WHERE entity_type = 'dives'",
      ),
      isEmpty,
      reason: 'narrowing never re-stamped the dives it unlinked',
    );
    expect(
      await rows(
        "SELECT site_id FROM site_tags WHERE tag_id = 'both' ORDER BY site_id",
      ),
      ['s1', 's2'],
    );
  });

  test('narrowing notifies the link watchers', () async {
    // A tags UPDATE does not cascade to the junctions, so this only emits if
    // the unlink tells Drift which junction it wrote.
    final emitted = <void>[];
    final sub = repository.watchTagLinkChanges().listen(emitted.add);
    addTearDown(sub.cancel);

    final tag = (await repository.getTagById('both'))!;
    await repository.updateTag(tag.copyWith(scopes: const {TagScope.dives}));
    await pumpEventQueue();

    expect(emitted, isNotEmpty);
  });

  test('link changes on every junction emit', () async {
    final db = DatabaseService.instance.database;
    final emitted = <void>[];
    final sub = repository.watchTagLinkChanges().listen(emitted.add);
    addTearDown(sub.cancel);

    // Typed inserts: Drift cannot tell which table a raw statement touched.
    await db
        .into(db.diveTags)
        .insert(
          DiveTagsCompanion.insert(
            id: 'new-dive-link',
            diveId: 'd2',
            tagId: 'both',
            createdAt: 0,
          ),
        );
    await pumpEventQueue();
    expect(emitted, isNotEmpty);

    emitted.clear();
    await db
        .into(db.siteTags)
        .insert(
          SiteTagsCompanion.insert(
            id: 'new-site-link',
            siteId: 's2',
            tagId: 'bravo',
            createdAt: 0,
          ),
        );
    await pumpEventQueue();
    expect(emitted, isNotEmpty);
  });
}
```

- [ ] **Step 2: Update the existing tests (spelling only; every assertion keeps its intent)**

Every file below changes only how it spells a tag's scopes, a statistic's counts or a usage value. No expected string, count or outcome changes.

**`test/features/tags/data/repositories/tag_scope_test.dart`** (#1849). Add `import '../../tag_test_helpers.dart';` after the `test_database.dart` import, then:

- Lines 30-36: rename the test to `'site tag changes emit on the link watcher, so the site counts refresh'` and replace `repository.watchSiteTagsChanges()` with `repository.watchTagLinkChanges()`.
- Lines 61-62, 64-65, 70-71, 82-83, 85, 94, 145-146, 175, 194-195: replace each `x.appliesToDives` with `x.appliesTo(TagScope.dives)` and each `x.appliesToSites` with `x.appliesTo(TagScope.sites)`. For example line 61 `expect(tag.appliesToSites, isTrue);` becomes `expect(tag.appliesTo(TagScope.sites), isTrue);`.
- Line 113: `tag.copyWith(appliesToDives: false, appliesToSites: false),` becomes `tag.copyWith(scopes: const {}),`.
- Line 119: `Tag.create(id: '', name: 'Nothing').copyWith(appliesToDives: false),` becomes `Tag.create(id: '', name: 'Nothing').copyWith(scopes: const {}),`.
- Line 133: `tag.copyWith(appliesToDives: true, appliesToSites: false),` becomes `tag.copyWith(scopes: const {TagScope.dives}),`.
- Line 170: `expect(await repository.getTagUsage(tag.id), (dives: 0, sites: 1));` becomes `expect(divesAndSites(await repository.getTagUsage(tag.id)), (dives: 0, sites: 1));`.
- Lines 173-174: `expect(stat.siteCount, 1);` / `expect(stat.diveCount, 0);` become `expect(stat.count(TagScope.sites), 1);` / `expect(stat.count(TagScope.dives), 0);`.

**`test/features/tags/data/repositories/tag_repository_test.dart`** (#1933). Add `import 'package:submersion/features/tags/domain/entities/tag.dart' show TagScope;` after line 5, and `import '../../tag_test_helpers.dart';` after line 7. In the `getMergedUsage` group:

- Lines 156, 170, 242, 260: `expect(usage, (dives: A, sites: B));` becomes `expect(divesAndSites(usage), (dives: A, sites: B));` (same A and B).
- Lines 188, 204: `expect(usage.dives, 2);` becomes `expect(usage[TagScope.dives], 2);`.
- Line 223: `expect(usage, (dives: 0, sites: 2));` becomes `expect(divesAndSites(usage), (dives: 0, sites: 2));`.

**`test/features/tags/presentation/tag_usage_messages_test.dart`** (#1933). Replace the file with the following. Every expected string is unchanged, and the last test is new.

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_usage_messages.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A tag can be scoped to dives, sites, or both (#1849), and deleting or
/// merging it rewrites every dive and site that carries it. These messages
/// name only what is actually affected (#1902). Usage arrives as a map per
/// scope (#1942).
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Map<TagScope, int> usage({int dives = 0, int sites = 0}) => {
    TagScope.dives: dives,
    TagScope.sites: sites,
  };

  group('tagDeleteMessage', () {
    test('names dives only', () {
      expect(
        tagDeleteMessage(l10n, 'Wreck', usage(dives: 12)),
        '"Wreck" will be removed from 12 dives. This cannot be undone.',
      );
    });

    test('names sites only, the case #1902 reported', () {
      expect(
        tagDeleteMessage(l10n, 'To try', usage(sites: 3)),
        '"To try" will be removed from 3 sites. This cannot be undone.',
      );
    });

    test('names dives and sites', () {
      expect(
        tagDeleteMessage(l10n, 'Reef', usage(dives: 12, sites: 1)),
        '"Reef" will be removed from 12 dives and 1 site. '
        'This cannot be undone.',
      );
    });

    test('says an unused tag is on nothing', () {
      expect(
        tagDeleteMessage(l10n, 'Old', usage()),
        '"Old" is not used on any dives or sites. This cannot be undone.',
      );
    });
  });

  group('tagsBulkDeleteMessage', () {
    test('names dives only', () {
      expect(
        tagsBulkDeleteMessage(l10n, usage(dives: 1)),
        'These tags will be removed from 1 dive total. This cannot be undone.',
      );
    });

    test('names sites only', () {
      expect(
        tagsBulkDeleteMessage(l10n, usage(sites: 4)),
        'These tags will be removed from 4 sites total. '
        'This cannot be undone.',
      );
    });

    test('names dives and sites', () {
      expect(
        tagsBulkDeleteMessage(l10n, usage(dives: 7, sites: 2)),
        'These tags will be removed from 7 dives and 2 sites total. '
        'This cannot be undone.',
      );
    });

    test('says unused tags are on nothing', () {
      expect(
        tagsBulkDeleteMessage(l10n, usage()),
        'These tags are not used on any dives or sites. '
        'This cannot be undone.',
      );
    });
  });

  group('tagsMergeAffectedMessage', () {
    test('names dives only', () {
      expect(
        tagsMergeAffectedMessage(l10n, usage(dives: 14)),
        'This will affect 14 dives total.',
      );
    });

    test('names sites only', () {
      expect(
        tagsMergeAffectedMessage(l10n, usage(sites: 1)),
        'This will affect 1 site total.',
      );
    });

    test('names dives and sites', () {
      expect(
        tagsMergeAffectedMessage(l10n, usage(dives: 3, sites: 5)),
        'This will affect 3 dives and 5 sites total.',
      );
    });

    test('says unused tags affect nothing', () {
      expect(
        tagsMergeAffectedMessage(l10n, usage()),
        'These tags are not used on any dives or sites.',
      );
    });
  });

  group('tagUsageCounts', () {
    test('shows dives alone when no site carries the tag', () {
      expect(tagUsageCounts(l10n, usage(dives: 12)), '12 dives');
    });

    test('adds sites when some carry the tag', () {
      expect(tagUsageCounts(l10n, usage(sites: 3)), '0 dives, 3 sites');
    });

    test('reads a scope the map lacks as zero', () {
      expect(tagUsageCounts(l10n, const {TagScope.sites: 2}), '0 dives, 2 sites');
    });
  });
}
```

**`test/features/tags/presentation/pages/tag_manage_page_test.dart`** (#1849, #1888, #1898, #1933):

- Line 36: `diveCount: 12,` becomes `counts: const {TagScope.dives: 12},`; line 47: `diveCount: 5,` becomes `counts: const {TagScope.dives: 5},`.
- Lines 111-119 become:
  ```dart
  class _MockTagRepository extends TagRepository {
    _MockTagRepository({
      this.mergedUsage = const {TagScope.dives: 0, TagScope.sites: 0},
    });

    /// What a bulk delete's preview reports for the selection.
    final Map<TagScope, int> mergedUsage;

    @override
    Future<Map<TagScope, int>> getMergedUsage(List<String> tagIds) async =>
        mergedUsage;
  ```
- Lines 525-529 (`siteStat`): `appliesToDives: forDives,` / `appliesToSites: true,` become `scopes: {if (forDives) TagScope.dives, TagScope.sites},`, and `diveCount: forDives ? 2 : 0,` / `siteCount: 3,` become `counts: {TagScope.dives: forDives ? 2 : 0, TagScope.sites: 3},`.
- Lines 873-874 and 1014-1015: `expect(x.appliesToDives, isFalse);` / `expect(x.appliesToSites, isTrue);` become `expect(x.appliesTo(TagScope.dives), isFalse);` / `expect(x.appliesTo(TagScope.sites), isTrue);`.
- Line 1009: `repository.usage.complete((dives: 0, sites: 0));` becomes `repository.usage.complete(const {TagScope.dives: 0, TagScope.sites: 0});`.
- Lines 1194-1195: `appliesToDives: false,` / `appliesToSites: true,` become `scopes: const {TagScope.sites},`. Lines 1199-1200: `diveCount: 0,` / `siteCount: 3,` become `counts: const {TagScope.dives: 0, TagScope.sites: 3},`.
- Line 1226: `_MockTagRepository(mergedUsage: (dives: 12, sites: 3))` becomes `_MockTagRepository(mergedUsage: const {TagScope.dives: 12, TagScope.sites: 3})`.
- Lines 1284-1287 become:
  ```dart
    final Completer<Map<TagScope, int>> usage = Completer();

    @override
    Future<Map<TagScope, int>> getTagUsage(String tagId) => usage.future;
  ```

**`test/features/tags/presentation/widgets/tag_merge_sheet_test.dart`** (#1933):

- Lines 80, 91, 102: `diveCount: 12,` / `3` / `1` become `counts: const {TagScope.dives: 12},` (and 3 and 1).
- Line 112: `).thenAnswer((_) async => (dives: 14, sites: 0));` becomes `).thenAnswer((_) async => const {TagScope.dives: 14, TagScope.sites: 0});`.
- Line 203: `).thenAnswer((_) async => (dives: 3, sites: 2));` becomes `).thenAnswer((_) async => const {TagScope.dives: 3, TagScope.sites: 2});`.
- Lines 223-224: `appliesToDives: false,` / `appliesToSites: true,` become `scopes: const {TagScope.sites},`. Lines 228-229: `diveCount: 0,` / `siteCount: 4,` become `counts: const {TagScope.dives: 0, TagScope.sites: 4},`.

**`test/features/tags/presentation/widgets/tag_picker_sheet_test.dart`**:

- Line 22: `diveCount: diveCount,` becomes `counts: {TagScope.dives: diveCount},`.
- Lines 102-106: `appliesToDives: false,` / `appliesToSites: true,` become `scopes: const {TagScope.sites},`, and `diveCount: 0,` / `siteCount: 3,` become `counts: const {TagScope.dives: 0, TagScope.sites: 3},`.
- Lines 127-131: `appliesToDives: forDives,` / `appliesToSites: true,` become `scopes: {if (forDives) TagScope.dives, TagScope.sites},`, and `diveCount: dives,` / `siteCount: sites,` become `counts: {TagScope.dives: dives, TagScope.sites: sites},`.

**`test/features/tags/presentation/widgets/tag_input_widget_scope_test.dart:105-106`**: `expect(picked.single.appliesToSites, isTrue);` / `expect(picked.single.appliesToDives, isFalse);` become `expect(picked.single.appliesTo(TagScope.sites), isTrue);` / `expect(picked.single.appliesTo(TagScope.dives), isFalse);`.

**`test/features/dive_sites/presentation/widgets/edit_sections/type_tags_section_test.dart`**:

- Lines 129-130: `appliesToDives: dives,` / `appliesToSites: sites,` become `scopes: {if (dives) TagScope.dives, if (sites) TagScope.sites},`.
- Lines 146-148 become:
  ```dart
          TagStatistic(tag: night, counts: const {TagScope.dives: 9}),
          TagStatistic(
            tag: toTry,
            counts: const {TagScope.dives: 0, TagScope.sites: 3},
          ),
          TagStatistic(
            tag: avoid,
            counts: const {TagScope.dives: 0, TagScope.sites: 1},
          ),
  ```

**`test/features/dive_log/presentation/pages/dive_edit_tag_picker_test.dart:64`**: `(ref) async => [TagStatistic(tag: wreck, diveCount: 42)],` becomes `(ref) async => [TagStatistic(tag: wreck, counts: const {TagScope.dives: 42})],`.

**Tags with the default dive scope plus sites.** Each `appliesToSites: true,` line below (no `appliesToDives`, so dives stayed `true`) becomes `scopes: const {TagScope.dives, TagScope.sites},`:
- `test/features/dive_sites/presentation/pages/site_detail_page_test.dart:1237`
- `test/features/dive_sites/presentation/providers/site_filter_state_classification_test.dart:23`
- `test/features/dive_sites/presentation/widgets/site_tags_card_test.dart:19`
- `test/features/dive_sites/presentation/widgets/site_list_tile_test.dart:334`
- `test/features/dive_sites/presentation/pages/site_detail_page_section_config_test.dart:210`

**Sites-only tags.** Each `appliesToDives: false,` plus `appliesToSites: true,` pair becomes `scopes: const {TagScope.sites},`:
- `test/features/dive_sites/presentation/widgets/site_filter_sheet_test.dart:214-215`
- `test/core/services/export/uddf/uddf_site_classification_export_test.dart:47-48`

**`test/core/services/export/uddf/uddf_site_classification_round_trip_test.dart:107-108`**: `expect(tags.single.appliesToSites, isTrue);` / `expect(tags.single.appliesToDives, isFalse);` become `expect(tags.single.appliesTo(TagScope.sites), isTrue);` / `expect(tags.single.appliesTo(TagScope.dives), isFalse);`.

Every file above already imports `package:submersion/features/tags/domain/entities/tag.dart` without a prefix (checked), so `TagScope` resolves. **No change is needed** in these files, which read Drift rows or raw SQL rather than the domain entity: `test/core/services/sync/site_classification_sync_test.dart`, `test/core/services/sync/sync_tag_identity_test.dart`, `test/features/tags/presentation/pages/tag_manage_page_scope_test.dart`, `test/features/tags/presentation/providers/tag_providers_test.dart`, `test/features/tags/data/repositories/tag_duplicate_guard_test.dart`, `test/features/tags/data/repositories/tag_repository_error_test.dart`, `test/features/dive_sites/data/repositories/site_classification_repository_test.dart` and `test/features/dive_sites/data/repositories/site_repository_classification_test.dart`.

The mockito outputs (`tag_merge_sheet_test.mocks.dart`, `uddf_entity_importer_test.mocks.dart`, `universal_adapter_test.mocks.dart`, `import_wizard_notifier_test.mocks.dart`) are untracked build_runner output. Step 12 regenerates them.

- [ ] **Step 3: Run the new tests and confirm they fail**

Run: `flutter test test/features/tags/domain/entities/tag_test.dart test/features/tags/presentation/tag_scope_labels_test.dart test/features/tags/data/repositories/tag_scope_registry_test.dart test/features/tags/presentation/tag_usage_messages_test.dart`

Expected: FAIL to compile. There is no named parameter `scopes` on `Tag` or `copyWith`, the getter `scopes` is not defined, `tag_scope_labels.dart` does not exist, `watchTagLinkChanges` and `count` are not defined, and `tagDeleteMessage` takes named `dives:`/`sites:` rather than a map.

- [ ] **Step 4: The entity**

In `lib/features/tags/domain/entities/tag.dart`, replace lines 15-20:

```dart
  /// Whether the tag is offered on dives (issue #1765).
  final bool appliesToDives;

  /// Whether the tag is offered on dive sites (issue #1765).
  final bool appliesToSites;
```

with:

```dart
  /// Where the tag is offered (issues #1765, #1942). Never empty once stored:
  /// TagRepository rejects a tag with no scope. Treat as read-only.
  final Set<TagScope> scopes;
```

Lines 29-30 (`this.appliesToDives = true,` / `this.appliesToSites = false,`) become `this.scopes = const {TagScope.dives},`.

Lines 46-50 become:

```dart
  /// Whether the tag is offered where [scope] is.
  bool appliesTo(TagScope scope) => scopes.contains(scope);
```

In `Tag.create`, lines 68-69 (`appliesToDives: scope == TagScope.dives,` / `appliesToSites: scope == TagScope.sites,`) become `scopes: {scope},`.

In `copyWith`, lines 80-81 (`bool? appliesToDives,` / `bool? appliesToSites,`) become `Set<TagScope>? scopes,`, and lines 90-91 become `scopes: scopes ?? this.scopes,`.

In `props`, lines 103-104 (`appliesToDives,` / `appliesToSites,`) become `scopes,`. Equatable compares sets as sets and hashes them order-independently, which `tag_test.dart` pins.

- [ ] **Step 5: The row mapper**

In `lib/features/tags/data/mappers/tag_row_mapper.dart`, change `mapTagRow`'s last two arguments:

```dart
    appliesToDives: row.appliesToDives,
    appliesToSites: row.appliesToSites,
```

to:

```dart
    scopes: tagScopesOf(row),
```

- [ ] **Step 6: The repository**

In `lib/features/tags/data/repositories/tag_repository.dart`:

Add after line 5 (`import 'package:submersion/core/database/database.dart';`):

```dart
import 'package:submersion/core/database/tag_scope_tables.dart';
```

Replace lines 27-30 (`watchSiteTagsChanges`) with:

```dart
  /// Emits when any tag link changes, on every junction in the tag scope
  /// registry, since each moves a count in [getTagStatistics] (#1765, #1942).
  Stream<void> watchTagLinkChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      for (final junction in tagScopeTables) _table(junction.junctionTable),
    ]),
  );
```

In `getAllTags`, update the doc on lines 32-33 to "[scope] limits the list to tags offered in that scope (issues #1765, #1942); null returns every tag." and replace lines 45-52 (the `switch (scope)`) with:

```dart
      if (scope != null) {
        final column = scope.table.scopeColumn;
        query.where(
          (t) =>
              (t.columnsByName[column]! as GeneratedColumn<bool>).equals(true),
        );
      }
```

In `createTag`, replace the insert argument (lines 174-183):

```dart
            TagsCompanion(
              id: Value(id),
              diverId: Value(tag.diverId),
              name: Value(name),
              color: Value(tag.colorHex),
              createdAt: Value(now),
              updatedAt: Value(now),
              appliesToDives: Value(tag.appliesToDives),
              appliesToSites: Value(tag.appliesToSites),
            ),
```

with:

```dart
            RawValuesInsertable<Tag>({
              ...TagsCompanion(
                id: Value(id),
                diverId: Value(tag.diverId),
                name: Value(name),
                color: Value(tag.colorHex),
                createdAt: Value(now),
                updatedAt: Value(now),
              ).toColumns(false),
              ...tagScopeColumns(tag.scopes),
            }),
```

In `updateTag`, update the doc on lines 253-255 to "Scope (issues #1765, #1942): turning off a scope for a tag also removes it from every item of that scope carrying it, each link tombstoned, so a link always implies its scope. The UI confirms before doing that." Then replace lines 279-301:

```dart
      await _db.transaction(() async {
        final stored = await getTagById(tag.id);
        await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(
          TagsCompanion(
            name: Value(name),
            color: Value(tag.colorHex),
            updatedAt: Value(now),
            appliesToDives: Value(tag.appliesToDives),
            appliesToSites: Value(tag.appliesToSites),
          ),
        );
        await _syncRepository.markRecordPending(
          entityType: 'tags',
          recordId: tag.id,
          localUpdatedAt: now,
        );
        if (stored != null && stored.appliesToSites && !tag.appliesToSites) {
          await _unlinkEverySite(tag.id);
        }
        if (stored != null && stored.appliesToDives && !tag.appliesToDives) {
          await _unlinkEveryDive(tag.id);
        }
      });
```

with:

```dart
      await _db.transaction(() async {
        final stored = await getTagById(tag.id);
        await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(
          RawValuesInsertable<Tag>({
            ...TagsCompanion(
              name: Value(name),
              color: Value(tag.colorHex),
              updatedAt: Value(now),
            ).toColumns(false),
            ...tagScopeColumns(tag.scopes),
          }),
        );
        await _syncRepository.markRecordPending(
          entityType: 'tags',
          recordId: tag.id,
          localUpdatedAt: now,
        );
        if (stored != null) {
          for (final scope in domain.TagScope.values) {
            if (stored.appliesTo(scope) && !tag.appliesTo(scope)) {
              await _unlinkAll(scope.table, tag.id);
            }
          }
        }
      });
```

Replace lines 314-404 (from the `// Scope (issue #1765)` banner through the end of `getTagUsage`) with:

```dart
  // ============================================================================
  // Scope (issues #1765, #1942)
  // ============================================================================

  void _requireScope(domain.Tag tag) {
    if (tag.scopes.isEmpty) {
      throw ArgumentError(
        'A tag must apply to at least one of: '
        '${domain.TagScope.values.map((s) => s.name).join(', ')}',
      );
    }
  }

  /// [tag] widened to also cover every scope [wanted] has.
  Future<domain.Tag> _widenTo(domain.Tag tag, domain.Tag wanted) async {
    var result = tag;
    for (final scope in domain.TagScope.values) {
      if (wanted.appliesTo(scope)) result = await _widen(result, scope);
    }
    return result;
  }

  /// Adds [scope] to [tag] if it lacks it, returning the stored result.
  Future<domain.Tag> _widen(domain.Tag tag, domain.TagScope scope) async {
    if (tag.appliesTo(scope)) return tag;
    final widened = tag.copyWith(scopes: {...tag.scopes, scope});
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(
      RawValuesInsertable<Tag>({
        ...tagScopeColumns(widened.scopes),
        ...TagsCompanion(updatedAt: Value(now)).toColumns(false),
      }),
    );
    await _syncRepository.markRecordPending(
      entityType: 'tags',
      recordId: tag.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    _log.info('Widened tag ${tag.id} to ${scope.name}');
    return widened;
  }

  /// The Drift table called [name], so a registry-driven write tells Drift
  /// what it touched and stream queries over that table refresh.
  TableInfo<Table, dynamic> _table(String name) =>
      _db.allTables.firstWhere((t) => t.actualTableName == name);

  /// Every link of [tagId] in [junction], as (link id, linked item id).
  Future<List<({String id, String parentId})>> _linksOf(
    TagScopeTable junction,
    String tagId,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT id, ${junction.parentColumn} AS parent_id '
          'FROM ${junction.junctionTable} WHERE tag_id = ?',
          variables: [Variable.withString(tagId)],
        )
        .get();
    return [
      for (final row in rows)
        (id: row.read<String>('id'), parentId: row.read<String>('parent_id')),
    ];
  }

  /// Removes [tagId] from every item in [junction], tombstoning each link.
  /// No parent is re-stamped, dives included: narrowing never did, and site
  /// links are clockless children (#1769).
  Future<void> _unlinkAll(TagScopeTable junction, String tagId) async {
    final links = await _linksOf(junction, tagId);
    if (links.isEmpty) return;
    await _db.customUpdate(
      'DELETE FROM ${junction.junctionTable} WHERE tag_id = ?',
      variables: [Variable.withString(tagId)],
      updates: {_table(junction.junctionTable)},
      updateKind: UpdateKind.delete,
    );
    for (final link in links) {
      await _syncRepository.logDeletion(
        entityType: junction.syncEntity,
        recordId: link.id,
      );
    }
  }

  /// How many items of each scope carry [tagId]; the scope editor confirms
  /// with these before narrowing a tag. Every registry scope has an entry.
  Future<Map<domain.TagScope, int>> getTagUsage(String tagId) async {
    final counts = [
      for (final scope in domain.TagScope.values)
        '(SELECT COUNT(*) FROM ${scope.table.junctionTable} '
            'WHERE tag_id = ?1) AS ${scope.name}',
    ];
    final row = await _db
        .customSelect(
          // stats-scope-exempt: usage indicator for the scope editor. Must see
          // every dive carrying the tag, excluded ones included.
          'SELECT ${counts.join(', ')}',
          variables: [Variable.withString(tagId)],
        )
        .getSingle();
    return {
      for (final scope in domain.TagScope.values)
        scope: row.read<int>(scope.name),
    };
  }
```

(`?1` binds the one id for every subquery. The same idiom is used in `lib/features/data_quality/data/services/quality_context_builder.dart:168`.)

Replace `getTagStatistics` (lines 649-689) with:

```dart
  /// Get tag statistics (usage counts per scope)
  Future<List<TagStatistic>> getTagStatistics({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'WHERE t.diver_id = ?' : '';
      final variables = diverId != null
          ? [Variable.withString(diverId)]
          : <Variable<Object>>[];
      const scopes = domain.TagScope.values;
      final countColumns = [
        for (final scope in scopes)
          '(SELECT COUNT(*) FROM ${scope.table.junctionTable} j '
              'WHERE j.tag_id = t.id) AS ${scope.name}_count',
      ];
      // Registry order, so the dive count comes first: the dive tag picker
      // lists "tags you use most" in exactly this order, and each later
      // scope's count only breaks ties (#1765, #1942).
      final order = [for (final scope in scopes) '${scope.name}_count DESC'];

      // stats-scope-exempt: usage counts for managing tags, not a
      // statistic. A planned or stats-excluded dive still carries the tag.
      final result = await _db.customSelect('''
        SELECT t.*, ${countColumns.join(', ')}
        FROM tags t
        $diverFilter
        ORDER BY ${order.join(', ')}, t.name
      ''', variables: variables).get();

      return result
          .map(
            (row) => TagStatistic(
              tag: mapTagRow(_db.tags.map(row.data)),
              counts: {
                for (final scope in scopes)
                  scope: row.read<int>('${scope.name}_count'),
              },
            ),
          )
          .toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get tag statistics',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

Replace `getMergedUsage` (lines 714-748) with:

```dart
  /// How many distinct items of each scope carry any of [tagIds] (union, not
  /// sum): an item carrying two of them counts once. Previews what a bulk
  /// delete or a merge rewrites (#1902). Every registry scope has an entry.
  Future<Map<domain.TagScope, int>> getMergedUsage(List<String> tagIds) async {
    if (tagIds.isEmpty) {
      return {for (final scope in domain.TagScope.values) scope: 0};
    }
    try {
      final rows = tagIds.map((_) => '(?)').join(', ');
      final counts = [
        for (final scope in domain.TagScope.values)
          '(SELECT COUNT(DISTINCT ${scope.table.parentColumn}) '
              'FROM ${scope.table.junctionTable} '
              'WHERE tag_id IN (SELECT tag_id FROM selected)) '
              'AS ${scope.name}',
      ];
      final row = await _db
          .customSelect(
            // stats-scope-exempt: delete and merge preview. Tells the diver
            // how many items the change rewrites, which is every one of
            // them. The ids bind once, in the CTE, and every count reads
            // from it: binding them per count would divide the selection
            // SQLite's bound-variable limit allows. Chunking would not do,
            // since a union count cannot be summed across chunks.
            'WITH selected(tag_id) AS (VALUES $rows) '
            'SELECT ${counts.join(', ')}',
            variables: tagIds.map((id) => Variable.withString(id)).toList(),
          )
          .getSingle();
      return {
        for (final scope in domain.TagScope.values)
          scope: row.read<int>(scope.name),
      };
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get merged tag usage',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

In `mergeTags`, update the doc on lines 783-784 to "Every link of a source tag, in every junction of the tag scope registry, moves to the surviving tag. A link whose item already has the surviving tag is removed." Then replace the transaction body (lines 803-943, `await _db.transaction(() async {` through its closing `});`) with:

```dart
      await _db.transaction(() async {
        // Items that already carry the surviving tag, per junction.
        final covered = <TagScopeTable, Set<String>>{};
        for (final junction in tagScopeTables) {
          covered[junction] = {
            for (final link in await _linksOf(junction, survivingTagId))
              link.parentId,
          };
        }

        // The survivor keeps every use the merged tags had (issue #1765). A
        // merge of rows that carry no scope at all stays a dive tag.
        final mergedRows = await (_db.select(
          _db.tags,
        )..where((t) => t.id.isIn([survivingTagId, ...sourceTagIds]))).get();
        final union = {for (final row in mergedRows) ...tagScopesOf(row)};
        await (_db.update(
          _db.tags,
        )..where((t) => t.id.equals(survivingTagId))).write(
          RawValuesInsertable<Tag>({
            ...TagsCompanion(
              name: Value(name),
              color: Value(colorHex),
              updatedAt: Value(now),
            ).toColumns(false),
            ...tagScopeColumns(
              union.isEmpty ? const {domain.TagScope.dives} : union,
            ),
          }),
        );
        await _syncRepository.markRecordPending(
          entityType: 'tags',
          recordId: survivingTagId,
          localUpdatedAt: now,
        );

        // Parents to re-stamp once at the end, by table: a dive link
        // re-stamps its dive; site links are clockless children (#1769).
        final restamp = <String, Set<String>>{};
        for (final sourceId in sourceTagIds) {
          for (final junction in tagScopeTables) {
            final updates = {_table(junction.junctionTable)};
            final carried = covered[junction]!;
            for (final link in await _linksOf(junction, sourceId)) {
              if (carried.add(link.parentId)) {
                // Move the link to the surviving tag.
                final newId = _uuid.v4();
                await _db.customInsert(
                  'INSERT INTO ${junction.junctionTable} '
                  '(id, ${junction.parentColumn}, tag_id, created_at) '
                  'VALUES (?, ?, ?, ?)',
                  variables: [
                    Variable.withString(newId),
                    Variable.withString(link.parentId),
                    Variable.withString(survivingTagId),
                    Variable.withInt(now),
                  ],
                  updates: updates,
                );
                await _syncRepository.markRecordPending(
                  entityType: junction.syncEntity,
                  recordId: newId,
                  localUpdatedAt: now,
                );
              }
              // Deleted explicitly (not by CASCADE) so sync tracks each one.
              await _db.customUpdate(
                'DELETE FROM ${junction.junctionTable} WHERE id = ?',
                variables: [Variable.withString(link.id)],
                updates: updates,
                updateKind: UpdateKind.delete,
              );
              await _syncRepository.logDeletion(
                entityType: junction.syncEntity,
                recordId: link.id,
              );
              final parentTable = junction.restampedParentTable;
              if (parentTable != null) {
                restamp
                    .putIfAbsent(parentTable, () => <String>{})
                    .add(link.parentId);
              }
            }
          }

          // Delete the source tag (inlined to avoid SyncEventBus inside txn)
          await (_db.delete(
            _db.tags,
          )..where((t) => t.id.equals(sourceId))).go();
          await _syncRepository.logDeletion(
            entityType: 'tags',
            recordId: sourceId,
          );
        }

        for (final entry in restamp.entries) {
          for (final parentId in entry.value) {
            await _db.customUpdate(
              'UPDATE ${entry.key} SET updated_at = ? WHERE id = ?',
              variables: [Variable.withInt(now), Variable.withString(parentId)],
              updates: {_table(entry.key)},
              updateKind: UpdateKind.update,
            );
            // The table name doubles as its sync entity type (see
            // TagScopeTable.restampedParentTable).
            await _syncRepository.markRecordPending(
              entityType: entry.key,
              recordId: parentId,
              localUpdatedAt: now,
            );
          }
        }
      });
```

Replace `TagStatistic` (lines 960-973) with:

```dart
/// Tag usage statistics
class TagStatistic {
  final domain.Tag tag;

  /// Items carrying the tag, per scope (issues #1765, #1942). The repository
  /// fills every scope; a hand-built statistic may leave some out.
  final Map<domain.TagScope, int> counts;

  TagStatistic({required this.tag, this.counts = const {}});

  /// How many items of [scope] carry the tag; 0 when [counts] lacks it.
  int count(domain.TagScope scope) => counts[scope] ?? 0;
}
```

- [ ] **Step 7: Providers**

In `lib/features/tags/presentation/providers/tag_providers.dart:44`, replace `ref.invalidateSelfWhen(repository.watchSiteTagsChanges());` with `ref.invalidateSelfWhen(repository.watchTagLinkChanges());`.

- [ ] **Step 8: Per-scope wording and the usage messages**

Create `lib/features/tags/presentation/tag_scope_labels.dart`:

```dart
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// The wording each tag scope brings to the tag screens (issue #1942). One
// exhaustive switch per phrase, so a new scope does not compile until it has
// all of its wording.

/// The scope's name in a tag's "Dives · Sites" line.
String tagScopeName(AppLocalizations l10n, TagScope scope) => switch (scope) {
  TagScope.dives => l10n.tags_manage_scope_dives,
  TagScope.sites => l10n.tags_manage_scope_sites,
};

/// The scope's checkbox in the tag editor.
String tagScopeUseForLabel(AppLocalizations l10n, TagScope scope) =>
    switch (scope) {
      TagScope.dives => l10n.tags_manage_useForDives,
      TagScope.sites => l10n.tags_manage_useForSites,
    };

/// How many items of the scope carry a tag, such as "3 sites".
String tagScopeCount(AppLocalizations l10n, TagScope scope, int count) =>
    switch (scope) {
      TagScope.dives => l10n.tags_manage_diveCount(count),
      TagScope.sites => l10n.tags_manage_siteCount(count),
    };

/// What turning the scope off removes, for the narrowing confirmation.
String tagScopeNarrowLine(AppLocalizations l10n, TagScope scope, int count) =>
    switch (scope) {
      TagScope.dives => l10n.tags_manage_narrowDialog_dives(count),
      TagScope.sites => l10n.tags_manage_narrowDialog_sites(count),
    };
```

Replace the whole of `lib/features/tags/presentation/tag_usage_messages.dart` with:

```dart
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_scope_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Wording for what deleting or merging tags touches (#1902).
//
// A tag can be scoped to dives, sites, or both (#1849), and deleting or
// merging it rewrites every dive and every site that carries it. Each message
// names only what is actually affected: dives, sites, both, or nothing. The
// "both" variants are single ICU messages with two plurals rather than two
// phrases joined here, so every locale controls its own word order.
//
// Usage arrives as a map per scope (#1942). A scope the map lacks counts as
// zero.

int _count(Map<TagScope, int> usage, TagScope scope) => usage[scope] ?? 0;

/// The confirmation for deleting one tag.
String tagDeleteMessage(
  AppLocalizations l10n,
  String tagName,
  Map<TagScope, int> usage,
) {
  final dives = _count(usage, TagScope.dives);
  final sites = _count(usage, TagScope.sites);
  return switch ((dives > 0, sites > 0)) {
    (true, true) => l10n.tags_manage_deleteMessage_divesAndSites(
      tagName,
      dives,
      sites,
    ),
    (true, false) => l10n.tags_manage_deleteMessage(tagName, dives),
    (false, true) => l10n.tags_manage_deleteMessage_sites(tagName, sites),
    (false, false) => l10n.tags_manage_deleteMessage_unused(tagName),
  };
}

/// The confirmation for deleting several tags. [usage] is the union across
/// the selection, so an item carrying two of them counts once.
String tagsBulkDeleteMessage(AppLocalizations l10n, Map<TagScope, int> usage) {
  final dives = _count(usage, TagScope.dives);
  final sites = _count(usage, TagScope.sites);
  return switch ((dives > 0, sites > 0)) {
    (true, true) => l10n.tags_manage_bulkDeleteMessage_divesAndSites(
      dives,
      sites,
    ),
    (true, false) => l10n.tags_manage_bulkDeleteMessage(dives),
    (false, true) => l10n.tags_manage_bulkDeleteMessage_sites(sites),
    (false, false) => l10n.tags_manage_bulkDeleteMessage_unused,
  };
}

/// The merge sheet's preview of what a merge rewrites, counted as a union
/// like [tagsBulkDeleteMessage].
String tagsMergeAffectedMessage(
  AppLocalizations l10n,
  Map<TagScope, int> usage,
) {
  final dives = _count(usage, TagScope.dives);
  final sites = _count(usage, TagScope.sites);
  return switch ((dives > 0, sites > 0)) {
    (true, true) => l10n.tags_manage_mergeAffected_divesAndSites(dives, sites),
    (true, false) => l10n.tags_manage_mergeAffectedDives(dives),
    (false, true) => l10n.tags_manage_mergeAffected_sites(sites),
    (false, false) => l10n.tags_manage_mergeAffected_unused,
  };
}

/// One tag's usage as a row subtitle, in registry order: its dives always,
/// and every other scope when something carries the tag. Shared by the
/// Manage Tags list and the merge sheet.
String tagUsageCounts(AppLocalizations l10n, Map<TagScope, int> usage) => [
  for (final scope in TagScope.values)
    if (scope == TagScope.dives || _count(usage, scope) > 0)
      tagScopeCount(l10n, scope, _count(usage, scope)),
].join(', ');
```

- [ ] **Step 9: Manage Tags page**

In `lib/features/tags/presentation/pages/tag_manage_page.dart`:

After line 11 (`import '.../presentation/providers/tag_providers.dart';`) add:

```dart
import 'package:submersion/features/tags/presentation/tag_scope_labels.dart';
```

Lines 233-248 (the row subtitle and the usage text) become:

```dart
      // Where the tag is offered (issues #1765, #1942).
      subtitle: Text(
        [
          for (final scope in TagScope.values)
            if (tag.appliesTo(scope)) tagScopeName(context.l10n, scope),
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tagUsageCounts(context.l10n, stat.counts),
```

(The `style:` argument and the rest of the row are unchanged.)

Create dialog: lines 276-277 (`bool forDives = true;` / `bool forSites = false;`) become `Set<TagScope> scopes = const {TagScope.dives};`. Lines 312-317 become:

```dart
                  ..._scopeEditor(
                    scopes: scopes,
                    onChanged: (next) => setDialogState(() => scopes = next),
                  ),
```

Lines 334-344 become:

```dart
                        final name = controller.text.trim();
                        if (name.isEmpty || scopes.isEmpty) return;
                        final newTag = Tag.create(
                          id: _uuid.v4(),
                          name: name,
                          colorHex: selectedColor,
                        ).copyWith(scopes: scopes);
```

Edit dialog: lines 370-371 (`bool forDives = tag.appliesToDives;` / `bool forSites = tag.appliesToSites;`) become `Set<TagScope> scopes = tag.scopes;`. Lines 405-410 become the same `_scopeEditor(scopes: scopes, onChanged: ...)` call as above. In the Save handler, lines 455-457:

```dart
                            final dives = forDives;
                            final sites = forSites;
                            if (name.isEmpty || (!dives && !sites)) return;
```

become:

```dart
                            // The editor replaces the set on every tick and
                            // never modifies it, so this reference is safe.
                            final chosen = scopes;
                            if (name.isEmpty || chosen.isEmpty) return;
```

Lines 465-469 (`_confirmNarrowing(tag, forDives: dives, forSites: sites)`) become `_confirmNarrowing(tag, scopes: chosen)`. Lines 478-479 (`appliesToDives: dives,` / `appliesToSites: sites,`) become `scopes: chosen,`.

Replace `_scopeEditor` and `_confirmNarrowing` up to the `showDialog` call (lines 558-608) with:

```dart
  /// One "Use for ..." checkbox per scope in the registry (issues #1765,
  /// #1942), with an error line while none is ticked. [onChanged] receives a
  /// new set; the one passed in is never modified.
  List<Widget> _scopeEditor({
    required Set<TagScope> scopes,
    required ValueChanged<Set<TagScope>> onChanged,
  }) {
    final l10n = context.l10n;
    return [
      for (final scope in TagScope.values)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tagScopeUseForLabel(l10n, scope)),
          value: scopes.contains(scope),
          onChanged: (v) => onChanged(
            (v ?? false) ? scopes.union({scope}) : scopes.difference({scope}),
          ),
        ),
      if (scopes.isEmpty)
        Text(
          l10n.tags_manage_scopeRequired,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ];
  }

  /// Turning off a scope removes the tag from every item of that scope
  /// carrying it (the repository does that so a link always implies its
  /// scope). Asks first when that would remove anything; true to go ahead.
  Future<bool> _confirmNarrowing(
    Tag tag, {
    required Set<TagScope> scopes,
  }) async {
    final dropping = [
      for (final scope in TagScope.values)
        if (tag.appliesTo(scope) && !scopes.contains(scope)) scope,
    ];
    if (dropping.isEmpty) return true;

    final l10n = context.l10n;
    final usage = await ref.read(tagRepositoryProvider).getTagUsage(tag.id);
    final messages = [
      for (final scope in dropping)
        if ((usage[scope] ?? 0) > 0)
          tagScopeNarrowLine(l10n, scope, usage[scope]!),
    ];
    if (messages.isEmpty || !mounted) return true;
```

(The `showDialog` that follows, lines 610-628, is unchanged.)

Lines 685-690 (bulk delete content) become `tagsBulkDeleteMessage(ctx.l10n, usage),`. Lines 727-733 (single delete content) become:

```dart
        content: Text(
          tagDeleteMessage(ctx.l10n, stat.tag.name, stat.counts),
        ),
```

- [ ] **Step 10: Merge sheet and picker sheet**

In `lib/features/tags/presentation/widgets/tag_merge_sheet.dart`, lines 26-28 become:

```dart
  /// The items the merge rewrites per scope, counted as a union; null until
  /// loaded.
  Map<TagScope, int>? _affected;
```

Line 33 becomes `sorted.sort((a, b) => b.count(TagScope.dives).compareTo(a.count(TagScope.dives)));`. Lines 55-56 become `/// mergeTags relinks every junction of the tag scope registry, so the preview counts each scope (#1902, #1942).`. Lines 172-177 (`tagUsageCounts(context.l10n, dives: stat.diveCount, sites: stat.siteCount,)`) become `tagUsageCounts(context.l10n, stat.counts),`. Lines 211-215 become `tagsMergeAffectedMessage(context.l10n, affected),`.

In `lib/features/tags/presentation/widgets/tag_picker_sheet.dart`, add after line 7:

```dart
import 'package:submersion/features/tags/presentation/tag_scope_labels.dart';
```

Replace lines 66-88 (`_inScope` and its doc) with:

```dart
  /// The tags this sheet offers, "tags you use most" first.
  ///
  /// The provider already orders by dive count, then each later scope's
  /// count, then name: exactly right for dives. A tag used only for sites
  /// ("to try") has no place on a dive, nor a dive-only tag on a site (issue
  /// #1765); from any other scope the order is by that scope's use instead.
  /// The sort is stable, so ties keep the provider's order.
  List<TagStatistic> _inScope(List<TagStatistic> stats) {
    final scope = widget.scope;
    final inScope = [
      for (final stat in stats)
        if (stat.tag.appliesTo(scope)) stat,
    ];
    if (scope != TagScope.dives) {
      mergeSort(inScope, compare: (a, b) => b.count(scope) - a.count(scope));
    }
    return inScope;
  }
```

Replace lines 201-208 (the subtitle's `switch`) with:

```dart
          subtitle: Text(
            tagScopeCount(
              context.l10n,
              widget.scope,
              stat.count(widget.scope),
            ),
          ),
```

- [ ] **Step 11: The remaining callers**

`lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart`: after line 14 add `import 'package:submersion/features/tags/domain/entities/tag.dart' show TagScope;`, and change line 766 `if (tag.appliesToDives) tag,` to `if (tag.appliesTo(TagScope.dives)) tag,`.

`lib/features/dive_sites/presentation/widgets/site_filter_sheet.dart:505` (CRLF; Edit tool only): `.where((t) => t.appliesToSites)` becomes `.where((t) => t.appliesTo(TagScope.sites))`.

`lib/features/dive_import/data/services/uddf_entity_importer.dart`: line 1092 `if (appliesToSites && !existing.appliesToSites) {` becomes `if (appliesToSites && !existing.appliesTo(TagScope.sites)) {`. Line 1099 `if (appliesToDives && !existing.appliesToDives) {` becomes `if (appliesToDives && !existing.appliesTo(TagScope.dives)) {`. Lines 1118-1119:

```dart
        appliesToDives: appliesToDives || !appliesToSites,
        appliesToSites: appliesToSites,
```

become:

```dart
        scopes: {
          if (appliesToDives || !appliesToSites) TagScope.dives,
          if (appliesToSites) TagScope.sites,
        },
```

Line 1226 `if (tag != null && !tag.appliesToSites) {` becomes `if (tag != null && !tag.appliesTo(TagScope.sites)) {`. The UDDF map keys `appliesToDives` / `appliesToSites` stay: they are the file format, not the entity.

`lib/core/services/export/uddf/uddf_export_builders.dart`: line 1147 `nest: tag.appliesToDives.toString(),` becomes `nest: tag.appliesTo(TagScope.dives).toString(),`, and line 1151 `nest: tag.appliesToSites.toString(),` becomes `nest: tag.appliesTo(TagScope.sites).toString(),`.

Confirm nothing is left:

Run: `grep -rn "appliesToDives\|appliesToSites\|watchSiteTagsChanges\|diveCount: \|siteCount: \|_unlinkEvery" lib/features/tags lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart lib/features/dive_sites/presentation/widgets/site_filter_sheet.dart lib/features/dive_import/data/services/uddf_entity_importer.dart lib/core/services/export/uddf/uddf_export_builders.dart | grep -v "tagData\['appliesTo\|tag\['appliesTo"`
Expected: only the Drift row reads inside `tagScopesOf` in `tag_row_mapper.dart`. Any other hit is a missed caller.

- [ ] **Step 12: Regenerate the mocks**

Mockito mocks of `TagRepository` are untracked build_runner output, and `getTagUsage`/`getMergedUsage`/`watchTagLinkChanges` changed. The Bash tool refuses a command containing a bare `build` token, so write a two-line script into your scratchpad and run it:

```bash
cat > "$SCRATCHPAD/codegen.sh" <<'EOF'
cd "$(git rev-parse --show-toplevel)"
dart run build_runner build --delete-conflicting-outputs
EOF
bash "$SCRATCHPAD/codegen.sh"
```

(Replace `$SCRATCHPAD` with your scratchpad directory.)

- [ ] **Step 13: Run the tests**

Run: `flutter test test/features/tags`
Expected: PASS. This includes the four new files, the #1849 and #1933 files with spelling-only changes, and the unchanged `tag_manage_page_scope_test.dart`, which drives the narrowing path end to end ("Dives · Sites", "0 dives, 1 site").

Run: `flutter test test/features/dive_sites/presentation test/features/dive_log/presentation/pages/dive_edit_tag_picker_test.dart test/features/dive_log/presentation/pages/bulk_membership_wiring_test.dart test/features/dive_log/presentation/pages/dive_filter_sheet_test.dart test/features/dive_log/presentation/widgets test/features/dive_import/data/services/uddf_entity_importer_test.dart test/features/import_wizard test/core/services/export/uddf test/integration/uddf_round_trip_test.dart`
Expected: PASS. Every test that pumps `TagPickerSheet`, `TypeTagsSection`, `DiveFilterSheet` or `SiteFilterSheet` is in this set (`grep -rl "TagPickerSheet\|TypeTagsSection\|DiveFilterSheet\|SiteFilterSheet" test`).

Run: `flutter test test/core/services/sync/site_classification_sync_test.dart test/core/services/sync/sync_tag_identity_test.dart test/core/database/dive_stats_scope_census_test.dart test/core/database/tag_scope_tables_test.dart test/core/database/tag_uniqueness_registry_test.dart test/features/tags/data/mappers/tag_row_mapper_test.dart`
Expected: PASS.

Run: `flutter test test/architecture/`
Expected: PASS (`tagStatisticsProvider` still self-invalidates; `watchTagLinkChanges` is picked up by the tick scanner as a `Stream<void> watch...()` declaration).

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 14: Commit**

```bash
dart format .
git add lib/features/tags/domain/entities/tag.dart lib/features/tags/data/mappers/tag_row_mapper.dart lib/features/tags/data/repositories/tag_repository.dart lib/features/tags/presentation/providers/tag_providers.dart lib/features/tags/presentation/tag_scope_labels.dart lib/features/tags/presentation/tag_usage_messages.dart lib/features/tags/presentation/pages/tag_manage_page.dart lib/features/tags/presentation/widgets/tag_merge_sheet.dart lib/features/tags/presentation/widgets/tag_picker_sheet.dart lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart lib/features/dive_sites/presentation/widgets/site_filter_sheet.dart lib/features/dive_import/data/services/uddf_entity_importer.dart lib/core/services/export/uddf/uddf_export_builders.dart test/features/tags/tag_test_helpers.dart test/features/tags/domain/entities/tag_test.dart test/features/tags/presentation/tag_scope_labels_test.dart test/features/tags/data/repositories/tag_scope_registry_test.dart test/features/tags/data/repositories/tag_scope_test.dart test/features/tags/data/repositories/tag_repository_test.dart test/features/tags/presentation/tag_usage_messages_test.dart test/features/tags/presentation/pages/tag_manage_page_test.dart test/features/tags/presentation/widgets/tag_merge_sheet_test.dart test/features/tags/presentation/widgets/tag_picker_sheet_test.dart test/features/tags/presentation/widgets/tag_input_widget_scope_test.dart test/features/dive_sites/presentation/widgets/edit_sections/type_tags_section_test.dart test/features/dive_log/presentation/pages/dive_edit_tag_picker_test.dart test/features/dive_sites/presentation/pages/site_detail_page_test.dart test/features/dive_sites/presentation/providers/site_filter_state_classification_test.dart test/features/dive_sites/presentation/widgets/site_tags_card_test.dart test/features/dive_sites/presentation/widgets/site_list_tile_test.dart test/features/dive_sites/presentation/pages/site_detail_page_section_config_test.dart test/features/dive_sites/presentation/widgets/site_filter_sheet_test.dart test/core/services/export/uddf/uddf_site_classification_export_test.dart test/core/services/export/uddf/uddf_site_classification_round_trip_test.dart
git diff --cached --numstat
git commit -m "refactor(tags): hold a tag's scopes as a set and count usage per scope (#1942)" -m "Tag replaces appliesToDives and appliesToSites with a set of scopes, and the repository reaches every scope through the registry: the scope check, widening, the unlink when a scope is turned off, merging, the scope filter, usage, merged usage and statistics. Usage and statistics now return a count per scope, and the delete, merge and usage wording takes that map and produces the same strings as before. The Manage Tags editor, row subtitle and narrowing confirmation are generated from the scopes, so they render exactly as before for dives and sites. A merge still re-stamps the dives it relinks and never a site."
```

(`git diff --cached --numstat` is the CRLF check: `site_filter_sheet.dart` must show a one-line change, not a whole-file rewrite.)

### Task 2: Shared bulk-edit widgets moved to lib/shared/bulk_edit/

**Files:**
- Move + modify: `lib/features/dive_log/presentation/widgets/bulk_membership_editor.dart` to `lib/shared/bulk_edit/bulk_membership_editor.dart` (whole file rewritten below)
- Move + modify: `lib/features/dive_log/presentation/widgets/bulk_change_summary.dart` to `lib/shared/bulk_edit/bulk_change_summary.dart` (whole file rewritten below)
- Create: `lib/features/dive_log/presentation/widgets/dive_bulk_membership_labels.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:90-91` (imports), `:1391-1437` (`_buildBulkCollectionsSection`), `:1986-1989` (`BulkChangeSummary`)
- Move + modify test: `test/features/dive_log/presentation/widgets/bulk_membership_editor_test.dart` to `test/shared/bulk_edit/bulk_membership_editor_test.dart`
- Move + modify test: `test/features/dive_log/presentation/widgets/bulk_membership_delta_test.dart` to `test/shared/bulk_edit/bulk_membership_delta_test.dart` (import only)
- Move + modify test: `test/features/dive_log/presentation/widgets/bulk_change_summary_test.dart` to `test/shared/bulk_edit/bulk_change_summary_test.dart`
- Create test: `test/features/dive_log/presentation/widgets/dive_bulk_membership_labels_test.dart`
- Modify test: `test/features/dive_log/presentation/pages/bulk_membership_wiring_test.dart:15` (import) and a new test before `:556`
- Modify test: `test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart:11` (import only)

Every consumer, verified with `grep -rln "BulkMembershipEditor\|bulk_membership_editor\|BulkChangeSummary\|MembershipDelta\|BulkMembershipItem\|summarizeBulkMembership" lib test`: `dive_edit_page.dart`, the two widget files themselves, and the five test files above. No architecture guard mentions `lib/shared` except `test/architecture/preference_aware_date_format_test.dart`, which scans it for date formatting; these widgets format no dates.

All touched files are LF (checked with `file`).

**Interfaces:**
- Consumes: nothing from Task 1. No ARB key is added or reworded: the dive screens keep their existing keys, now passed in by the caller.
- Produces (Task 8 and any later task use these exact names):
  - `lib/shared/bulk_edit/bulk_membership_editor.dart` holds `MembershipPresence`, `MembershipChoice`, `BulkMembershipItem`, `MembershipDelta` (all unchanged), the new `BulkMembershipLabels`, and `BulkMembershipEditor`.
  - `BulkMembershipLabels({required String Function(int total) onAll, required String Function(int count, int total) onSome, required String Function(int total) adding, required String removing, required String empty, required String add})`.
  - `BulkMembershipEditor({Key? key, required String title, required int total, required BulkMembershipLabels labels, required List<BulkMembershipItem> items, required Map<String, int> counts, required VoidCallback onAdd, required ValueChanged<MembershipDelta> onChanged, Widget? secondaryAction, Widget Function(BulkMembershipItem)? trailingBuilder, ({int serial, Set<String> ids})? ensureOn, bool absentStartsChecked = true})`. The old optional `addLabel` is removed: no caller passes it (verified with grep), and it is folded into `labels.add`. `absentStartsChecked` defaults to `true`, so dives are unchanged.
  - `lib/shared/bulk_edit/bulk_change_summary.dart` holds `BulkMembershipCollection`, `BulkChangeSection`, `summarizeBulkMembership` (all unchanged) and `BulkChangeSummary({Key? key, required List<BulkChangeSection> sections, required String addingHeading, required String removingHeading})`. `totalDives` is dropped rather than renamed: it only fed the two headings, which the caller now resolves with its own noun and count.
  - `BulkMembershipLabels diveBulkMembershipLabels(AppLocalizations l10n)` in `lib/features/dive_log/presentation/widgets/dive_bulk_membership_labels.dart`, returning the existing dive keys.

- [ ] **Step 1: Move the tests and write the failing ones**

```bash
mkdir -p test/shared/bulk_edit
git mv test/features/dive_log/presentation/widgets/bulk_membership_editor_test.dart test/shared/bulk_edit/bulk_membership_editor_test.dart
git mv test/features/dive_log/presentation/widgets/bulk_membership_delta_test.dart test/shared/bulk_edit/bulk_membership_delta_test.dart
git mv test/features/dive_log/presentation/widgets/bulk_change_summary_test.dart test/shared/bulk_edit/bulk_change_summary_test.dart
```

In `test/shared/bulk_edit/bulk_membership_delta_test.dart`, line 2 becomes:

```dart
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';
```

Replace the whole of `test/shared/bulk_edit/bulk_membership_editor_test.dart` with the following. The existing cases are kept word for word apart from `totalDives` becoming `total`; the wording now comes from plain test labels, so the shared widget is shown to use only what its caller supplies, and the file no longer needs the localization delegates. Three cases are new: the caller's empty and add wording, and `absentStartsChecked: false`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';

void main() {
  // a is on all 3 selected items, b on 2 of 3, c on none (just added via the
  // picker).
  const items = [
    BulkMembershipItem(id: 'a', label: 'Regulator'),
    BulkMembershipItem(id: 'b', label: 'Wetsuit'),
    BulkMembershipItem(id: 'c', label: 'Camera'),
  ];
  const counts = {'a': 3, 'b': 2, 'c': 0};

  // Plain wording, so these cases show the widget prints only what its
  // caller supplies. The dive wording has its own test beside the dive page.
  final labels = BulkMembershipLabels(
    onAll: (total) => 'on all $total',
    onSome: (count, total) => 'on $count of $total',
    adding: (total) => 'adding to all $total',
    removing: 'removing from all',
    empty: 'Nothing here yet',
    add: 'Add',
  );

  Future<void> pumpEditor(
    WidgetTester tester, {
    void Function(MembershipDelta)? onChanged,
    ({int serial, Set<String> ids})? ensureOn,
    List<BulkMembershipItem> rows = items,
    bool absentStartsChecked = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BulkMembershipEditor(
            title: 'Equipment',
            total: 3,
            labels: labels,
            items: rows,
            counts: counts,
            onAdd: () {},
            onChanged: onChanged ?? (_) {},
            ensureOn: ensureOn,
            absentStartsChecked: absentStartsChecked,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a presence subtitle per row', (tester) async {
    await pumpEditor(tester);
    expect(find.text('on all 3'), findsOneWidget); // a
    expect(find.text('on 2 of 3'), findsOneWidget); // b
    expect(find.text('adding to all 3'), findsOneWidget); // c (just added)
  });

  testWidgets('shows the add label and empty wording the caller supplies', (
    tester,
  ) async {
    await pumpEditor(tester, rows: const []);
    expect(find.widgetWithText(TextButton, 'Add'), findsOneWidget);
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('unchecking an on-all item yields a remove', (tester) async {
    MembershipDelta? last;
    await pumpEditor(tester, onChanged: (d) => last = d);
    await tester.tap(find.byKey(const ValueKey('membership-toggle-a')));
    await tester.pump();
    expect(last!.removeIds, contains('a'));
    expect(find.text('removing from all'), findsOneWidget);
  });

  testWidgets('a some-item is left unchanged; an added item is an add', (
    tester,
  ) async {
    MembershipDelta? last;
    await pumpEditor(tester, onChanged: (d) => last = d);
    // Baseline emitted post-frame: c (none) -> add; a (all) and b (some) no-op.
    expect(last, isNotNull);
    expect(last!.addIds, contains('c'));
    expect(last!.addIds, isNot(contains('b')));
    expect(last!.removeIds, isNot(contains('b')));
  });

  testWidgets('a some-item cycles leave -> add -> remove -> leave', (
    tester,
  ) async {
    MembershipDelta? last;
    await pumpEditor(tester, onChanged: (d) => last = d);
    final toggleB = find.byKey(const ValueKey('membership-toggle-b'));

    await tester.tap(toggleB); // -> ensureOn
    await tester.pump();
    expect(last!.addIds, contains('b'));

    await tester.tap(toggleB); // -> ensureOff
    await tester.pump();
    expect(last!.removeIds, contains('b'));
    expect(last!.addIds, isNot(contains('b')));

    await tester.tap(toggleB); // -> leaveAsIs
    await tester.pump();
    expect(last!.addIds, isNot(contains('b')));
    expect(last!.removeIds, isNot(contains('b')));
  });

  testWidgets(
    'unchecking a just-added item is a no-op with no false subtitle',
    (tester) async {
      MembershipDelta? last;
      await pumpEditor(tester, onChanged: (d) => last = d);
      // c (on none) starts checked -> "adding to all 3".
      expect(find.text('adding to all 3'), findsOneWidget);

      // Toggle c off: it changes nothing, so the subtitle must not still claim
      // "adding to all", and c must not appear in the delta.
      await tester.tap(find.byKey(const ValueKey('membership-toggle-c')));
      await tester.pump();
      expect(find.text('adding to all 3'), findsNothing);
      expect(last!.addIds, isNot(contains('c')));
      expect(last!.removeIds, isNot(contains('c')));
    },
  );

  // Issue #1942: the equipment tag sheet lists every equipment tag, so a row
  // on none of the items is an offer, not a pick.
  group('absentStartsChecked false', () {
    testWidgets('a row on none of the items starts unchecked and adds nothing', (
      tester,
    ) async {
      MembershipDelta? last;
      await pumpEditor(
        tester,
        onChanged: (d) => last = d,
        absentStartsChecked: false,
      );
      final c = tester.widget<Checkbox>(
        find.byKey(const ValueKey('membership-toggle-c')),
      );
      expect(c.value, isFalse);
      expect(find.text('adding to all 3'), findsNothing);
      expect(last!.isEmpty, isTrue);
    });

    testWidgets('ticking it adds it', (tester) async {
      MembershipDelta? last;
      await pumpEditor(
        tester,
        onChanged: (d) => last = d,
        absentStartsChecked: false,
      );
      await tester.tap(find.byKey(const ValueKey('membership-toggle-c')));
      await tester.pump();
      expect(last!.addIds, ['c']);
      expect(find.text('adding to all 3'), findsOneWidget);
    });

    testWidgets('an ensureOn request still switches it on', (tester) async {
      MembershipDelta? last;
      await pumpEditor(
        tester,
        onChanged: (d) => last = d,
        absentStartsChecked: false,
        ensureOn: (serial: 1, ids: {'c'}),
      );
      expect(last!.addIds, ['c']);
    });
  });

  // Issue #1754: applying an equipment set must put every item in the set on
  // all the selected dives, including rows that are already listed.
  group('ensureOn request', () {
    testWidgets('turns an unchecked on-all row back on', (tester) async {
      MembershipDelta? last;
      await pumpEditor(tester, onChanged: (d) => last = d);
      await tester.tap(find.byKey(const ValueKey('membership-toggle-a')));
      await tester.pump();
      expect(last!.removeIds, contains('a'));

      await pumpEditor(
        tester,
        onChanged: (d) => last = d,
        ensureOn: (serial: 1, ids: {'a'}),
      );
      expect(last!.removeIds, isNot(contains('a')));
      expect(find.text('removing from all'), findsNothing);
      expect(find.text('on all 3'), findsOneWidget);
    });

    testWidgets('puts an on-some row on every item', (tester) async {
      MembershipDelta? last;
      await pumpEditor(
        tester,
        onChanged: (d) => last = d,
        ensureOn: (serial: 1, ids: {'b'}),
      );
      expect(last!.addIds, contains('b'));
      expect(find.text('on 2 of 3'), findsNothing);
    });

    testWidgets('a rebuild with the same serial keeps a later uncheck', (
      tester,
    ) async {
      MembershipDelta? last;
      const request = (serial: 1, ids: {'a'});
      await pumpEditor(tester, onChanged: (d) => last = d, ensureOn: request);
      await tester.tap(find.byKey(const ValueKey('membership-toggle-a')));
      await tester.pump();
      expect(last!.removeIds, contains('a'));

      await pumpEditor(tester, onChanged: (d) => last = d, ensureOn: request);
      expect(last!.removeIds, contains('a'));
    });

    testWidgets('a new serial applies again after an uncheck', (tester) async {
      MembershipDelta? last;
      await pumpEditor(
        tester,
        onChanged: (d) => last = d,
        ensureOn: (serial: 1, ids: {'a'}),
      );
      await tester.tap(find.byKey(const ValueKey('membership-toggle-a')));
      await tester.pump();

      await pumpEditor(
        tester,
        onChanged: (d) => last = d,
        ensureOn: (serial: 2, ids: {'a'}),
      );
      expect(last!.removeIds, isNot(contains('a')));
    });
  });
}
```

Replace the whole of `test/shared/bulk_edit/bulk_change_summary_test.dart` (the `summarizeBulkMembership` group is unchanged; the widget group pumps caller-supplied headings and needs no localization):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/bulk_edit/bulk_change_summary.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';

void main() {
  const equipment = [
    BulkMembershipItem(id: 'e1', label: 'Wing'),
    BulkMembershipItem(id: 'e2', label: 'DSMB'),
    BulkMembershipItem(id: 'e3', label: 'camera'),
    BulkMembershipItem(id: 'e4', label: 'Knife'),
  ];
  const tags = [BulkMembershipItem(id: 't1', label: 'Nitrox')];

  group('summarizeBulkMembership', () {
    test('names the adds and removes of each changed collection', () {
      final sections = summarizeBulkMembership([
        (
          title: 'Tags',
          delta: const MembershipDelta([], ['t1']),
          members: tags,
        ),
        (
          title: 'Equipment',
          delta: const MembershipDelta(['e4'], ['e2', 'e3', 'e1']),
          members: equipment,
        ),
      ]);

      expect(sections.map((s) => s.title), ['Tags', 'Equipment']);
      expect(sections[0].added, isEmpty);
      expect(sections[0].removed, ['Nitrox']);
      expect(sections[1].added, ['Knife']);
      // Sorted case-insensitively, so the diver can scan for a name.
      expect(sections[1].removed, ['camera', 'DSMB', 'Wing']);
    });

    test('leaves out a collection with no change', () {
      final sections = summarizeBulkMembership([
        (title: 'Tags', delta: MembershipDelta.empty, members: tags),
        (
          title: 'Equipment',
          delta: const MembershipDelta(['e4'], []),
          members: equipment,
        ),
      ]);

      expect(sections.map((s) => s.title), ['Equipment']);
    });

    test('falls back to the id for an item with no listed row', () {
      final sections = summarizeBulkMembership([
        (
          title: 'Equipment',
          delta: const MembershipDelta(['gone'], []),
          members: equipment,
        ),
      ]);

      expect(sections.single.added, ['gone']);
    });
  });

  group('BulkChangeSummary', () {
    Future<void> pumpSummary(
      WidgetTester tester,
      List<BulkChangeSection> sections,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkChangeSummary(
              sections: sections,
              addingHeading: 'Adding to all 19 items',
              removingHeading: 'Removing from all 19 items',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows what is added to and removed from every item', (
      tester,
    ) async {
      await pumpSummary(tester, const [
        BulkChangeSection(
          title: 'Equipment',
          added: ['Knife'],
          removed: ['DSMB', 'Wing'],
        ),
      ]);

      expect(find.text('Equipment'), findsOneWidget);
      expect(find.text('Adding to all 19 items'), findsOneWidget);
      expect(find.text('Knife'), findsOneWidget);
      expect(find.text('Removing from all 19 items'), findsOneWidget);
      expect(find.text('DSMB, Wing'), findsOneWidget);
    });

    testWidgets('omits the heading of an empty side', (tester) async {
      await pumpSummary(tester, const [
        BulkChangeSection(title: 'Tags', added: [], removed: ['Nitrox']),
      ]);

      expect(find.text('Adding to all 19 items'), findsNothing);
      expect(find.text('Removing from all 19 items'), findsOneWidget);
    });
  });
}
```

Create `test/features/dive_log/presentation/widgets/dive_bulk_membership_labels_test.dart`. It pins every dive string the editor showed before the move, in English and in one translated locale:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_bulk_membership_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';

/// The dive bulk editor keeps its own wording after the editor moved to
/// lib/shared (issue #1942).
void main() {
  const rows = [
    BulkMembershipItem(id: 'a', label: 'Nitrox'),
    BulkMembershipItem(id: 'b', label: 'Night'),
    BulkMembershipItem(id: 'c', label: 'Wreck'),
  ];
  const counts = {'a': 3, 'b': 2, 'c': 0};

  Future<void> pumpEditor(
    WidgetTester tester, {
    required Locale locale,
    List<BulkMembershipItem> items = rows,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => BulkMembershipEditor(
              title: 'Tags',
              total: 3,
              labels: diveBulkMembershipLabels(context.l10n),
              items: items,
              counts: counts,
              onAdd: () {},
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('rows read as they did on the dive page', (tester) async {
    await pumpEditor(tester, locale: const Locale('en'));

    expect(find.text('on all 3'), findsOneWidget);
    expect(find.text('on 2 of 3'), findsOneWidget);
    expect(find.text('adding to all 3'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Add'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('membership-toggle-a')));
    await tester.pump();
    expect(find.text('removing from all'), findsOneWidget);
  });

  testWidgets('an empty collection keeps the dive empty state', (
    tester,
  ) async {
    await pumpEditor(tester, locale: const Locale('en'), items: const []);
    expect(find.text('No items on the selected dives yet'), findsOneWidget);
  });

  testWidgets('a translated locale keeps its dive wording', (tester) async {
    await pumpEditor(tester, locale: const Locale('de'));

    expect(find.text('auf allen 3'), findsOneWidget);
    expect(find.text('auf 2 von 3'), findsOneWidget);
    expect(find.text('wird zu allen 3 hinzugefügt'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Hinzufügen'), findsOneWidget);
  });
}
```

In `test/features/dive_log/presentation/pages/bulk_membership_wiring_test.dart`, line 15 becomes:

```dart
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';
```

and, directly above the comment `// Issue #1754: the confirmation must say what the save is about to change,` (line 556), add:

```dart
    // Issue #1942 moved the editor to lib/shared; the page still supplies
    // the dive wording, so a row and an empty collection read as before.
    testWidgets('the rows and the empty state keep their dive wording', (
      tester,
    ) async {
      await seedTag('t1', 'Nitrox');
      await seedDive('d1');
      await repository.bulkAddTags(['d1'], ['t1']);

      await pump(tester, ['d1']);

      final tags = editorFor('Tags');
      expect(
        find.descendant(of: tags, matching: find.text('on all 1')),
        findsOneWidget,
      );
      final toggle = find.byKey(const ValueKey('membership-toggle-t1'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: tags, matching: find.text('removing from all')),
        findsOneWidget,
      );
      // No buddy is on the dive.
      expect(
        find.descendant(
          of: editorFor('Buddies'),
          matching: find.text('No items on the selected dives yet'),
        ),
        findsOneWidget,
      );
    });

```

The existing cases in that file already pin the rest of the dive screens: four editors render (`:168`), "on 1 of 2" (`:173`), "adding to all 2" (`:179`), the editor Add buttons (`:137-145`), and the confirmation headings "Adding to all 2 dives" / "Removing from all 2 dives" (`:594-596`).

In `test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart`, line 11 becomes:

```dart
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `flutter test test/shared/bulk_edit/`
Expected: FAIL to compile: `Error when reading 'lib/shared/bulk_edit/bulk_membership_editor.dart': No such file or directory` (and the same for `bulk_change_summary.dart`).

Run: `flutter test test/features/dive_log/presentation/widgets/dive_bulk_membership_labels_test.dart`
Expected: FAIL to compile: `dive_bulk_membership_labels.dart` does not exist.

- [ ] **Step 3: Move the widgets**

```bash
mkdir -p lib/shared/bulk_edit
git mv lib/features/dive_log/presentation/widgets/bulk_membership_editor.dart lib/shared/bulk_edit/bulk_membership_editor.dart
git mv lib/features/dive_log/presentation/widgets/bulk_change_summary.dart lib/shared/bulk_edit/bulk_change_summary.dart
```

Replace the whole of `lib/shared/bulk_edit/bulk_membership_editor.dart`. Behavior is unchanged except for the new `absentStartsChecked` (default `true`, the old behavior); the l10n import goes, and every word comes from `labels`:

```dart
import 'package:flutter/material.dart';

/// Initial presence of an item across the selected entities.
enum MembershipPresence { all, some, none }

/// The desired end-state the user picked for an item in a bulk edit.
///
/// - [ensureOn]: the item must end up on ALL selected entities.
/// - [ensureOff]: the item must end up on NONE of the selected entities.
/// - [leaveAsIs]: do not change membership (the safe default for "on some").
enum MembershipChoice { ensureOn, ensureOff, leaveAsIs }

/// One row in the bulk membership editor: a display label + optional icon.
class BulkMembershipItem {
  final String id;
  final String label;
  final IconData? icon;
  const BulkMembershipItem({required this.id, required this.label, this.icon});
}

/// Pure derivation of the (addIds, removeIds) to apply, given each item's
/// initial presence across the selection and the user's chosen end-state.
///
/// A checked item that was not already on every selected entity becomes an
/// add; an unchecked item that was on some/all becomes a remove; "leave
/// as-is" (and no-op cases like checking an already-on-all item) produce
/// nothing.
class MembershipDelta {
  final List<String> addIds;
  final List<String> removeIds;
  const MembershipDelta(this.addIds, this.removeIds);

  static const empty = MembershipDelta([], []);

  bool get isEmpty => addIds.isEmpty && removeIds.isEmpty;

  static MembershipDelta from(
    Map<String, MembershipPresence> initial,
    Map<String, MembershipChoice> choices,
  ) {
    final add = <String>[];
    final remove = <String>[];
    for (final entry in choices.entries) {
      final presence = initial[entry.key] ?? MembershipPresence.none;
      switch (entry.value) {
        case MembershipChoice.ensureOn:
          if (presence != MembershipPresence.all) add.add(entry.key);
        case MembershipChoice.ensureOff:
          if (presence != MembershipPresence.none) remove.add(entry.key);
        case MembershipChoice.leaveAsIs:
          break;
      }
    }
    return MembershipDelta(add, remove);
  }
}

/// Every word a [BulkMembershipEditor] shows. Each caller supplies its own,
/// because several translations agree with the noun being edited (Spanish
/// "en todas las 3" is feminine for dives), so one set of strings cannot
/// serve dives and equipment items alike (issue #1942).
@immutable
class BulkMembershipLabels {
  const BulkMembershipLabels({
    required this.onAll,
    required this.onSome,
    required this.adding,
    required this.removing,
    required this.empty,
    required this.add,
  });

  /// Status line of a row already on every selected entity ("on all 3").
  final String Function(int total) onAll;

  /// Status line of a row on some of them, left as is ("on 2 of 3").
  final String Function(int count, int total) onSome;

  /// Status line of a row being put on all of them ("adding to all 3").
  final String Function(int total) adding;

  /// Status line of a row being taken off all of them.
  final String removing;

  /// Shown in place of the rows when there are none.
  final String empty;

  /// Label of the add button beside the title.
  final String add;
}

/// A tri-state membership editor for one id-based collection in bulk mode,
/// shared by the dive bulk editor and the equipment bulk tag sheet (#1942).
///
/// Shows every [items] row with a tri-state checkbox reflecting how many of
/// the [total] selected entities currently have it (from [counts]):
/// checked = on all, dash = on some (leave as-is), and lets the user ensure
/// an item onto all or off all of them. Reports the resulting add/remove
/// sets via [onChanged]. The parent owns the [items] list, handles [onAdd]
/// (opening the collection's picker to bring in new items), and supplies
/// every visible word through [labels].
class BulkMembershipEditor extends StatefulWidget {
  const BulkMembershipEditor({
    super.key,
    required this.title,
    required this.total,
    required this.labels,
    required this.items,
    required this.counts,
    required this.onAdd,
    required this.onChanged,
    this.secondaryAction,
    this.trailingBuilder,
    this.ensureOn,
    this.absentStartsChecked = true,
  });

  final String title;

  /// How many entities are selected; each value in [counts] is out of this.
  final int total;
  final BulkMembershipLabels labels;
  final List<BulkMembershipItem> items;
  final Map<String, int> counts;
  final VoidCallback onAdd;
  final ValueChanged<MembershipDelta> onChanged;
  final Widget? secondaryAction;

  /// Optional per-row control rendered at the trailing edge, for collections
  /// whose links carry an attribute beyond membership. Buddies use it for the
  /// role on each dive_buddies link (#1220); the attribute-free collections
  /// (tags, dive types, equipment) leave it null.
  final Widget Function(BulkMembershipItem item)? trailingBuilder;

  /// A one-shot instruction to put [ids] on every selected entity, whatever
  /// their rows currently say. An update carrying the same [serial] changes
  /// nothing, so a row the user unchecks afterwards stays unchecked; a fresh
  /// State (a remount) starts from the defaults and applies it again.
  /// Applying an equipment set sends one, because the set's items must end up
  /// on all the dives, including rows the user had already unchecked (#1754).
  /// The equipment tag sheet sends one for the tags picked through its Add
  /// button (#1942).
  final ({int serial, Set<String> ids})? ensureOn;

  /// Whether a row on none of the selected entities starts checked, as an
  /// add. The dive editor lists only rows already on some dive or just
  /// picked, so there an absent row is a pick and starts checked. A caller
  /// that lists a whole vocabulary (the equipment tag sheet lists every
  /// equipment tag) passes false: an absent row is then only an offer that
  /// changes nothing until ticked, and [ensureOn] switches picked rows on.
  final bool absentStartsChecked;

  @override
  State<BulkMembershipEditor> createState() => _BulkMembershipEditorState();
}

class _BulkMembershipEditorState extends State<BulkMembershipEditor> {
  final Map<String, MembershipChoice> _choices = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      _choices[item.id] = _defaultChoice(_presenceOf(item.id));
    }
    _applyEnsureOn();
    // Emit the baseline so the parent has a delta before any interaction.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(_delta());
    });
  }

  @override
  void didUpdateWidget(BulkMembershipEditor old) {
    super.didUpdateWidget(old);
    final ids = widget.items.map((e) => e.id).toSet();
    var changed = false;
    for (final item in widget.items) {
      if (!_choices.containsKey(item.id)) {
        _choices[item.id] = _defaultChoice(_presenceOf(item.id));
        changed = true;
      }
    }
    if (widget.ensureOn?.serial != old.ensureOn?.serial) {
      changed = _applyEnsureOn() || changed;
    }
    final before = _choices.length;
    _choices.removeWhere((id, _) => !ids.contains(id));
    changed = changed || _choices.length != before;
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(_delta());
      });
    }
  }

  /// Sets every listed row named by [BulkMembershipEditor.ensureOn] to
  /// [MembershipChoice.ensureOn]. Returns whether any choice changed.
  bool _applyEnsureOn() {
    final request = widget.ensureOn;
    if (request == null) return false;
    var changed = false;
    for (final item in widget.items) {
      if (!request.ids.contains(item.id)) continue;
      if (_choices[item.id] == MembershipChoice.ensureOn) continue;
      _choices[item.id] = MembershipChoice.ensureOn;
      changed = true;
    }
    return changed;
  }

  MembershipPresence _presenceOf(String id) {
    final c = widget.counts[id] ?? 0;
    if (widget.total > 0 && c >= widget.total) {
      return MembershipPresence.all;
    }
    if (c <= 0) return MembershipPresence.none;
    return MembershipPresence.some;
  }

  MembershipChoice _defaultChoice(MembershipPresence p) => switch (p) {
    MembershipPresence.all => MembershipChoice.ensureOn,
    MembershipPresence.none =>
      widget.absentStartsChecked
          ? MembershipChoice.ensureOn
          : MembershipChoice.ensureOff,
    MembershipPresence.some => MembershipChoice.leaveAsIs,
  };

  MembershipDelta _delta() => MembershipDelta.from({
    for (final item in widget.items) item.id: _presenceOf(item.id),
  }, _choices);

  void _cycle(String id) {
    final presence = _presenceOf(id);
    final current = _choices[id] ?? _defaultChoice(presence);
    setState(() => _choices[id] = _next(presence, current));
    widget.onChanged(_delta());
  }

  // "some" items cycle through all three states so the user can add-to-all,
  // remove-from-all, or leave the mix untouched; "all"/"none" items toggle.
  MembershipChoice _next(MembershipPresence p, MembershipChoice c) {
    if (p == MembershipPresence.some) {
      return switch (c) {
        MembershipChoice.leaveAsIs => MembershipChoice.ensureOn,
        MembershipChoice.ensureOn => MembershipChoice.ensureOff,
        MembershipChoice.ensureOff => MembershipChoice.leaveAsIs,
      };
    }
    return c == MembershipChoice.ensureOn
        ? MembershipChoice.ensureOff
        : MembershipChoice.ensureOn;
  }

  bool? _checkboxValue(MembershipChoice c) => switch (c) {
    MembershipChoice.ensureOn => true,
    MembershipChoice.ensureOff => false,
    MembershipChoice.leaveAsIs => null,
  };

  /// The status line for a row, or null when the choice is a no-op for this
  /// item (e.g. a just-added "none" item toggled back off) so the subtitle
  /// never claims a change the delta won't actually make.
  String? _subtitle(String id) {
    final labels = widget.labels;
    final presence = _presenceOf(id);
    final choice = _choices[id] ?? _defaultChoice(presence);
    final count = widget.counts[id] ?? 0;
    return switch (choice) {
      MembershipChoice.ensureOn =>
        presence == MembershipPresence.all
            ? labels.onAll(widget.total)
            : labels.adding(widget.total),
      // "off" on an item that is on none of them changes nothing, so there
      // is no status line.
      MembershipChoice.ensureOff =>
        presence == MembershipPresence.none ? null : labels.removing,
      // leaveAsIs only arises for a "some" item (all/none default to a
      // definite choice), so any other presence is a no-op with no line.
      MembershipChoice.leaveAsIs =>
        presence == MembershipPresence.some
            ? labels.onSome(count, widget.total)
            : null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(widget.title, style: theme.textTheme.titleMedium),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?widget.secondaryAction,
                  TextButton.icon(
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(widget.labels.add),
                  ),
                ],
              ),
            ],
          ),
          if (widget.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                widget.labels.empty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final item in widget.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Checkbox(
                  key: ValueKey('membership-toggle-${item.id}'),
                  tristate: true,
                  value: _checkboxValue(
                    _choices[item.id] ?? _defaultChoice(_presenceOf(item.id)),
                  ),
                  onChanged: (_) => _cycle(item.id),
                ),
                title: Row(
                  children: [
                    if (item.icon != null) ...[
                      Icon(item.icon, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: Text(item.label)),
                  ],
                ),
                subtitle: switch (_subtitle(item.id)) {
                  final s? => Text(s),
                  _ => null,
                },
                trailing: widget.trailingBuilder?.call(item),
                onTap: () => _cycle(item.id),
              ),
        ],
      ),
    );
  }
}
```

Replace the whole of `lib/shared/bulk_edit/bulk_change_summary.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';

/// One bulk-editable collection as the confirmation sees it: its heading,
/// the delta its editor reported, and the rows that name its ids.
typedef BulkMembershipCollection = ({
  String title,
  MembershipDelta delta,
  List<BulkMembershipItem> members,
});

/// What a bulk save will do to one collection, by name.
class BulkChangeSection {
  final String title;
  final List<String> added;
  final List<String> removed;

  const BulkChangeSection({
    required this.title,
    required this.added,
    required this.removed,
  });
}

/// Names every membership change a bulk save is about to make, one section per
/// collection that changes, so the confirmation can show the diver what comes
/// off every selected entity before it happens (#1754).
///
/// Names are sorted case-insensitively so a long list can be scanned. An id
/// with no listed row falls back to the id itself rather than disappearing.
List<BulkChangeSection> summarizeBulkMembership(
  List<BulkMembershipCollection> collections,
) {
  List<String> names(List<String> ids, Map<String, String> labels) =>
      [for (final id in ids) labels[id] ?? id]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return collections.where((c) => !c.delta.isEmpty).map((c) {
    final labels = {for (final m in c.members) m.id: m.label};
    return BulkChangeSection(
      title: c.title,
      added: names(c.delta.addIds, labels),
      removed: names(c.delta.removeIds, labels),
    );
  }).toList();
}

/// The body of a bulk-edit confirmation: per collection, what is being added
/// to and removed from every selected entity. Removals use the error color.
///
/// The caller words both headings with its own noun and count ("Adding to
/// all 5 dives"), so each feature and locale reads naturally (#1942).
class BulkChangeSummary extends StatelessWidget {
  const BulkChangeSummary({
    super.key,
    required this.sections,
    required this.addingHeading,
    required this.removingHeading,
  });

  final List<BulkChangeSection> sections;

  /// Heading over each section's additions.
  final String addingHeading;

  /// Heading over each section's removals.
  final String removingHeading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          Text(section.title, style: theme.textTheme.titleSmall),
          if (section.added.isNotEmpty) ...[
            Text(addingHeading, style: theme.textTheme.labelMedium),
            Text(section.added.join(', ')),
          ],
          if (section.removed.isNotEmpty) ...[
            Text(
              removingHeading,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            Text(
              section.removed.join(', '),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
```

Create `lib/features/dive_log/presentation/widgets/dive_bulk_membership_labels.dart`:

```dart
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';

/// The dive bulk editor's row wording, for [BulkMembershipEditor]. These are
/// the keys the editor used before it moved to lib/shared (issue #1942), so
/// the dive screens read exactly as they did, in every locale.
BulkMembershipLabels diveBulkMembershipLabels(AppLocalizations l10n) =>
    BulkMembershipLabels(
      onAll: l10n.diveLog_bulkEdit_membership_onAll,
      onSome: l10n.diveLog_bulkEdit_membership_onSome,
      adding: l10n.diveLog_bulkEdit_membership_adding,
      removing: l10n.diveLog_bulkEdit_membership_removing,
      empty: l10n.diveLog_bulkEdit_membership_empty,
      add: l10n.diveLog_edit_add,
    );
```

(The generated signatures, from `lib/l10n/arb/app_localizations.dart:42827-42851` and `:9052`, are `onAll(int count)`, `onSome(int count, int total)`, `adding(int total)`, and getters for `removing`, `empty` and `diveLog_edit_add`, so the tear-offs fit the typedefs.)

- [ ] **Step 4: Point the dive page at the shared widgets**

`lib/features/dive_log/presentation/pages/dive_edit_page.dart:90-91`, replace:

```dart
import 'package:submersion/features/dive_log/presentation/widgets/bulk_change_summary.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_membership_editor.dart';
```

with:

```dart
import 'package:submersion/features/dive_log/presentation/widgets/dive_bulk_membership_labels.dart';
import 'package:submersion/shared/bulk_edit/bulk_change_summary.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';
```

`:1391-1393`, replace:

```dart
  Widget _buildBulkCollectionsSection(UnitFormatter units) {
    final l10n = context.l10n;
    const ownedModes = [BulkCollectionMode.add, BulkCollectionMode.replace];
```

with:

```dart
  Widget _buildBulkCollectionsSection(UnitFormatter units) {
    final l10n = context.l10n;
    final total = widget.bulkDiveIds!.length;
    final labels = diveBulkMembershipLabels(l10n);
    const ownedModes = [BulkCollectionMode.add, BulkCollectionMode.replace];
```

Then Edit with `replace_all: true` (exactly four occurrences, lines 1401, 1409, 1417, 1433, all at ten spaces):

```dart
          totalDives: widget.bulkDiveIds!.length,
```

becomes:

```dart
          total: total,
          labels: labels,
```

`:1986-1989`, replace:

```dart
                      BulkChangeSummary(
                        sections: changes,
                        totalDives: ids.length,
                      ),
```

with:

```dart
                      BulkChangeSummary(
                        sections: changes,
                        addingHeading: l10n.diveLog_bulkEdit_confirmAdding(
                          ids.length,
                        ),
                        removingHeading: l10n
                            .diveLog_bulkEdit_confirmRemoving(ids.length),
                      ),
```

After this `grep -n "totalDives" lib/features/dive_log/presentation/pages/dive_edit_page.dart` prints nothing.

- [ ] **Step 5: Run the tests**

Run each, one at a time:

```bash
flutter test test/shared/bulk_edit/
flutter test test/features/dive_log/presentation/widgets/dive_bulk_membership_labels_test.dart
flutter test test/features/dive_log/presentation/pages/bulk_membership_wiring_test.dart
flutter test test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart
flutter test test/features/dive_log/presentation/pages/bulk_dive_edit_page_test.dart
flutter test test/architecture/
```

Expected: all PASS. The wiring, form and page tests are every test that pumps the dive bulk editor (`grep -rln "bulkDiveIds" test/`), so together with the labels test they show the dive screens render as before.

Then `flutter analyze lib/shared/bulk_edit lib/features/dive_log test/shared/bulk_edit test/features/dive_log`: No issues found.

- [ ] **Step 6: Commit**

The `git mv` renames are already staged.

```bash
dart format .
git add lib/shared/bulk_edit/bulk_membership_editor.dart lib/shared/bulk_edit/bulk_change_summary.dart lib/features/dive_log/presentation/widgets/dive_bulk_membership_labels.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/shared/bulk_edit/bulk_membership_editor_test.dart test/shared/bulk_edit/bulk_membership_delta_test.dart test/shared/bulk_edit/bulk_change_summary_test.dart test/features/dive_log/presentation/widgets/dive_bulk_membership_labels_test.dart test/features/dive_log/presentation/pages/bulk_membership_wiring_test.dart test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart
git status --short
git commit -m "refactor(shared): move the bulk membership widgets to lib/shared (#1942)" -m "BulkMembershipEditor, MembershipDelta and BulkChangeSummary move from the dive log to lib/shared/bulk_edit so equipment can reuse them for bulk tag editing. Their wording is now supplied by the caller: the row status lines translate differently per noun, so the dive page passes its existing keys through diveBulkMembershipLabels and resolves the confirmation headings itself. totalDives becomes total. The editor also gains absentStartsChecked, true by default, for callers that list a whole vocabulary. The dive screens render exactly as before."
```

`git status --short` must show only the renames and the paths above as staged.

---

### Task 3: Schema v219 and EquipmentTagRepository

**Files:**
- Modify: `lib/core/database/tag_scope_tables.dart` (created by Task 1a: new const `equipmentTagScopeTable` after `siteTagScopeTable`; entry appended to `tagScopeTables`)
- Modify: `lib/features/tags/domain/entities/tag.dart` (Task 1's `enum TagScope` and its `table` getter; the `Tag` class doc line)
- Modify: `lib/features/tags/data/mappers/tag_row_mapper.dart` (the `switch` inside Task 1's `tagScopesOf`)
- Modify: `lib/features/tags/presentation/tag_scope_labels.dart` (created by Task 1b: one arm in each of `tagScopeName`, `tagScopeUseForLabel`, `tagScopeCount`, `tagScopeNarrowLine`)
- Modify: `lib/features/tags/presentation/widgets/tag_picker_sheet.dart` (docs only: the class doc's `[scope]` paragraph and the `scope` field doc; main lines 20-22 and 42)
- Modify: `lib/core/database/database.dart` (`Tags` 2459-2467; new `EquipmentTags` after `SiteTags` ending at 2606; table list after `SiteTags,` at 4123; `currentSchemaVersion` 4184; `migrationVersions` after `218,` at 4789; `_assertChildHlcColumns` 5227-5228; `_assertTagScopeColumns` 8179-8197; new helper after `_assertSiteClassificationSchema` ending at 8220; `onCreate` after 8555; `onUpgrade` after 12188; `beforeOpen` 12191 and after 12304). Untouched by Tasks 1 and 2, so these are exact.
- Modify: `lib/core/database/tag_uniqueness.dart` (constants after `kCreateDiveTagsUniqueIndexSql`; new function after `assertTagUniqueness`, before `_normalizeSql`; Task 1a rewrote the middle of this file, so locate both by symbol)
- Modify: `lib/core/data/repositories/sync_repository.dart:149` (`hlcTargets`)
- Create: `lib/features/equipment/data/repositories/equipment_tag_repository.dart`
- Create: `lib/features/equipment/presentation/providers/equipment_tag_providers.dart`
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (imports 1-24; `deleteEquipment` doc 469-472 and body 519)
- Modify: all 11 ARB files `lib/l10n/arb/app_{en,ar,de,es,fr,he,hu,it,nl,pt,zh}.arb` (4 keys each) and the regenerated `lib/l10n/arb/app_localizations*.dart`
- Modify (test): `test/core/database/migration_v218_site_detail_sections_test.dart:9-14, 81`
- Modify (test, Task 1a's files): `test/core/database/tag_scope_tables_test.dart` (one new test), `test/features/tags/data/mappers/tag_row_mapper_test.dart` (whole file replaced)
- Modify (test, Task 1b's file): `test/features/tags/presentation/tag_scope_labels_test.dart` (one new test)
- Modify (test): `test/features/tags/presentation/widgets/tag_picker_sheet_test.dart` (new group after the `from a site (issue #1765)` group; main line 178)
- Test (create): `test/core/database/migration_v219_equipment_tags_test.dart`
- Test (create): `test/core/database/tag_uniqueness_equipment_tags_test.dart`
- Test (create): `test/features/tags/data/repositories/tag_scope_equipment_test.dart`
- Test (create): `test/features/tags/presentation/pages/tag_manage_page_equipment_scope_test.dart`
- Test (create): `test/features/equipment/data/repositories/equipment_tag_repository_test.dart`
- Test (create): `test/features/equipment/data/repositories/equipment_repository_tags_test.dart`
- Test (create): `test/features/equipment/presentation/providers/equipment_tag_providers_test.dart`

**Interfaces:**
- Consumes (Task 1): `TagScopeTable`, `diveTagScopeTable`, `siteTagScopeTable`, `tagScopeTables` (`lib/core/database/tag_scope_tables.dart`); `TagScope.table`; `tagScopesOf(Tag row)` and `tagScopeColumns(Set<domain.TagScope>)` (`tag_row_mapper.dart`); `tagScopeName`, `tagScopeUseForLabel`, `tagScopeCount`, `tagScopeNarrowLine` (`tag_scope_labels.dart`); `Tag.scopes`, `Tag.appliesTo`, `Tag.copyWith(scopes:)`, `Tag.create(scope:)`; `TagRepository.getTagUsage` / `getMergedUsage` returning dense `Map<TagScope, int>`; `TagStatistic({required Tag tag, Map<TagScope, int> counts = const {}})` and `count(scope)`; `TagRepository.watchTagLinkChanges()`; the registry-driven `collapseDuplicateTags`; `test/features/tags/tag_test_helpers.dart` (`divesAndSites`).
- Produces:
  - `TagScope.equipment` (last member); `const equipmentTagScopeTable = TagScopeTable(scopeColumn: 'applies_to_equipment', junctionTable: 'equipment_tags', parentColumn: 'equipment_id', syncEntity: 'equipmentTags')` (`restampedParentTable` null), appended last to `tagScopeTables`.
  - Drift table `EquipmentTags` (`equipment_tags`; data class `EquipmentTag`, companion `EquipmentTagsCompanion`, accessor `equipmentTags`); `Tags.appliesToEquipment` (`BoolColumn`, default false). `AppDatabase.currentSchemaVersion == 219`.
  - `kEquipmentTagsUniqueIndexName = 'idx_equipment_tags_equipment_tag_unique'`, `kCreateEquipmentTagsUniqueIndexSql`, `Future<void> assertEquipmentTagUniqueness(DatabaseConnectionUser db)` in `tag_uniqueness.dart`.
  - `SyncRepository.hlcTargets['equipmentTags']`.
  - `class EquipmentTagRepository` (no constructor arguments) with exactly the contract's methods.
  - `equipmentTagRepositoryProvider`, `tagsForEquipmentProvider` (`FutureProvider.family<List<Tag>, String>`), `tagsByEquipmentProvider` (`FutureProvider<Map<String, List<Tag>>>`).
  - ARB keys, translated in all 10 locales: `tags_manage_scope_equipment`, `tags_manage_useForEquipment`, `tags_manage_equipmentCount` (plural `count`), `tags_manage_narrowDialog_equipment` (plural `count`). Task 7 consumes them and adds none of them.
  - Behavior that ships here: Manage Tags shows the "Use for equipment" checkbox, "Equipment" in a row's scope line, the equipment count in the usage line and the equipment narrowing line; `TagPickerSheet(scope: TagScope.equipment)` lists equipment tags by equipment use.

- [ ] **Step 1: Write the failing registry and schema tests**

In `test/core/database/tag_scope_tables_test.dart` (created by Task 1a), add
this test directly after the test named
`'dives and sites keep their columns, tables and parent rule'`. The file's
other tests (`TagScope follows the registry, in registry order`, `no two
scopes share ...`, `every registry entry names real schema`, `a re-stamped
parent ...`) loop over the registry, so they cover the new entry without an
edit; `every registry entry names real schema` is what proves the v219 table
and column exist.

```dart
  test('equipment keeps its column, table and clockless links (v219)', () {
    expect(TagScope.equipment.table, same(equipmentTagScopeTable));
    expect(tagScopeTables.last, same(equipmentTagScopeTable));
    expect(equipmentTagScopeTable.scopeColumn, 'applies_to_equipment');
    expect(equipmentTagScopeTable.junctionTable, 'equipment_tags');
    expect(equipmentTagScopeTable.parentColumn, 'equipment_id');
    expect(equipmentTagScopeTable.syncEntity, 'equipmentTags');
    expect(
      equipmentTagScopeTable.restampedParentTable,
      isNull,
      reason: 'equipment links are clockless children (#1769)',
    );
  });
```

Create `test/core/database/migration_v219_equipment_tags_test.dart`:

```dart
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_uniqueness.dart';

/// Schema v219: equipment tags (issue #1942).
void main() {
  /// A v218 database: `tags` with the dive and site scope flags but no
  /// equipment scope, and no `equipment_tags`.
  NativeDatabase setupDb({int userVersion = 218, bool withEquipment = true}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        if (withEquipment) {
          rawDb.execute(
            'CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)',
          );
        }
        rawDb.execute('''
          CREATE TABLE tags (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            color TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT,
            applies_to_dives INTEGER NOT NULL DEFAULT 1
              CHECK (applies_to_dives IN (0, 1)),
            applies_to_sites INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_sites IN (0, 1))
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dive_tags (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            tag_id TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        rawDb.execute(
          "INSERT INTO tags (id, name, created_at, updated_at, "
          "applies_to_dives, applies_to_sites) "
          "VALUES ('t1', 'Night', 0, 0, 1, 1)",
        );
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  /// Column shape as SQLite reports it, for comparing two databases.
  Future<List<Map<String, Object?>>> tableInfo(
    AppDatabase db,
    String table,
  ) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return [
      for (final c in cols)
        {
          'name': c.data['name'],
          'type': c.data['type'],
          'notnull': c.data['notnull'],
          'dflt_value': c.data['dflt_value'],
          'pk': c.data['pk'],
        },
    ];
  }

  Future<String?> ddlOf(AppDatabase db, String type, String name) async {
    final rows = await db
        .customSelect(
          'SELECT sql FROM sqlite_master WHERE type = ? AND name = ?',
          variables: [Variable<String>(type), Variable<String>(name)],
        )
        .get();
    return rows.isEmpty ? null : rows.single.read<String?>('sql');
  }

  test('v219 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 219);
    expect(AppDatabase.migrationVersions, contains(219));
    expect(AppDatabase.migrationStepCount(218), 1);
    // Additive rung: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 210);
  });

  test('adds the equipment_tags junction', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await columnsOf(db, 'equipment_tags'),
      containsAll(<String>[
        'id',
        'equipment_id',
        'tag_id',
        'created_at',
        'hlc',
      ]),
    );
  });

  test('existing tags keep their scopes and gain no equipment scope', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final row = await db
        .customSelect(
          'SELECT applies_to_dives, applies_to_sites, applies_to_equipment '
          "FROM tags WHERE id = 't1'",
        )
        .getSingle();
    expect(row.read<int>('applies_to_dives'), 1);
    expect(row.read<int>('applies_to_sites'), 1);
    expect(row.read<int>('applies_to_equipment'), 0);
  });

  test('creates the equipment_tags unique index', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await ddlOf(db, 'index', kEquipmentTagsUniqueIndexName),
      isNotNull,
    );
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    expect(
      await tableInfo(upgraded, 'equipment_tags'),
      await tableInfo(fresh, 'equipment_tags'),
    );
    expect(
      await ddlOf(upgraded, 'table', 'equipment_tags'),
      await ddlOf(fresh, 'table', 'equipment_tags'),
    );
    expect(
      await ddlOf(upgraded, 'index', kEquipmentTagsUniqueIndexName),
      await ddlOf(fresh, 'index', kEquipmentTagsUniqueIndexName),
    );
    Map<String, Object?> flag(List<Map<String, Object?>> cols) =>
        cols.singleWhere((c) => c['name'] == 'applies_to_equipment');
    expect(
      flag(await tableInfo(upgraded, 'tags')),
      flag(await tableInfo(fresh, 'tags')),
    );
  });

  test('a database stamped v219 without the schema heals in beforeOpen', () async {
    // A parallel branch that claimed 219 first carries a device past the
    // rung; the beforeOpen backstop must build what the rung would have.
    final db = AppDatabase(setupDb(userVersion: 219));
    addTearDown(db.close);

    expect(await columnsOf(db, 'tags'), contains('applies_to_equipment'));
    expect(await columnsOf(db, 'equipment_tags'), contains('equipment_id'));
    expect(
      await ddlOf(db, 'index', kEquipmentTagsUniqueIndexName),
      isNotNull,
    );
  });

  test('a fixture without an equipment table skips the junction', () async {
    final db = AppDatabase(setupDb(withEquipment: false));
    addTearDown(db.close);

    expect(await columnsOf(db, 'equipment_tags'), isEmpty);
    expect(await columnsOf(db, 'tags'), contains('applies_to_equipment'));
  });

  test('a duplicate equipment tag pair is rejected by the index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('t1', 'Rental', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
      "VALUES ('a', 'e1', 't1', 0)",
    );

    await expectLater(
      db.customStatement(
        "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
        "VALUES ('b', 'e1', 't1', 0)",
      ),
      throwsA(anything),
    );
  });
}
```

Create `test/core/database/tag_uniqueness_equipment_tags_test.dart`:

```dart
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_uniqueness.dart';

/// The duplicate-tag repair and the equipment_tags index (v219, issue #1942).
void main() {
  Future<AppDatabase> openWithItem() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 0, 0)",
    );
    return db;
  }

  test(
    'collapsing duplicate tags repoints equipment_tags and ORs the scopes',
    () async {
      final db = await openWithItem();
      // A database that lost the tag index (a restore of an old file).
      await db.customStatement('DROP INDEX IF EXISTS $kTagsUniqueIndexName');
      await db.customStatement(
        "INSERT INTO tags (id, name, created_at, updated_at, "
        "applies_to_dives, applies_to_sites, applies_to_equipment) "
        "VALUES ('a', 'Rental', 0, 0, 1, 0, 0), "
        "('b', 'rental', 0, 0, 0, 0, 1)",
      );
      await db.customStatement(
        "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
        "VALUES ('et1', 'e1', 'b', 0)",
      );

      await collapseDuplicateTags(db);

      final tags = await db
          .customSelect(
            'SELECT id, applies_to_dives, applies_to_equipment FROM tags',
          )
          .get();
      expect(tags, hasLength(1));
      expect(tags.single.read<String>('id'), 'a');
      expect(tags.single.read<int>('applies_to_dives'), 1);
      expect(tags.single.read<int>('applies_to_equipment'), 1);

      final links = await db
          .customSelect('SELECT tag_id FROM equipment_tags')
          .get();
      expect(links.map((r) => r.read<String>('tag_id')).toList(), ['a']);
    },
  );

  test('an item holding both a loser and its survivor keeps one link', () async {
    final db = await openWithItem();
    await db.customStatement('DROP INDEX IF EXISTS $kTagsUniqueIndexName');
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('a', 'Rental', 0, 0), ('b', 'rental', 0, 0)",
    );
    // The equipment_tags unique index is present, so the repoint must not
    // abort on the (e1, a) pair that already exists.
    await db.customStatement(
      "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
      "VALUES ('x', 'e1', 'a', 0), ('y', 'e1', 'b', 0)",
    );

    await collapseDuplicateTags(db);

    final links = await db
        .customSelect('SELECT id, tag_id FROM equipment_tags')
        .get();
    expect(links, hasLength(1));
    expect(links.single.read<String>('tag_id'), 'a');
  });

  test('a lost junction index is rebuilt after its duplicates collapse', () async {
    final db = await openWithItem();
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('t1', 'Rental', 0, 0)",
    );
    await db.customStatement('DROP INDEX $kEquipmentTagsUniqueIndexName');
    await db.customStatement(
      "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
      "VALUES ('y', 'e1', 't1', 1), ('x', 'e1', 't1', 0)",
    );

    await assertEquipmentTagUniqueness(db);

    final links = await db.customSelect('SELECT id FROM equipment_tags').get();
    expect(links.map((r) => r.read<String>('id')).toList(), ['x']);
    final index = await db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = ?",
          variables: [Variable<String>(kEquipmentTagsUniqueIndexName)],
        )
        .get();
    expect(index, isNotEmpty);
  });
}
```

(A database from before v217/v219, with no `site_tags` or `equipment_tags`
at all, is already covered by Task 1a's
`test/core/database/tag_uniqueness_registry_test.dart` ("a v148 schema ...
collapses without error"): `collapseDuplicateTags` skips every registry
junction and scope column the schema lacks, the new entry included.)

- [ ] **Step 2: Run them and confirm they fail**

Run: `flutter test test/core/database/tag_scope_tables_test.dart test/core/database/migration_v219_equipment_tags_test.dart test/core/database/tag_uniqueness_equipment_tags_test.dart`
Expected: FAIL to compile (`equipmentTagScopeTable`, `TagScope.equipment`, `kEquipmentTagsUniqueIndexName` and `assertEquipmentTagUniqueness` are undefined).

- [ ] **Step 3: Registry entry and `TagScope.equipment`**

In `lib/core/database/tag_scope_tables.dart` (created by Task 1a), add after the `siteTagScopeTable` const:

```dart
/// Equipment tags (v219, issue #1942). A link never re-stamps its item: the
/// links are clockless children of the equipment row (#1769).
const equipmentTagScopeTable = TagScopeTable(
  scopeColumn: 'applies_to_equipment',
  junctionTable: 'equipment_tags',
  parentColumn: 'equipment_id',
  syncEntity: 'equipmentTags',
);
```

and replace the `tagScopeTables` list (Task 1a's, at the end of the file):

```dart
/// Every scope, in display order.
const List<TagScopeTable> tagScopeTables = [
  diveTagScopeTable,
  siteTagScopeTable,
];
```

with:

```dart
/// Every scope, in display order.
const List<TagScopeTable> tagScopeTables = [
  diveTagScopeTable,
  siteTagScopeTable,
  equipmentTagScopeTable,
];
```

In `lib/features/tags/domain/entities/tag.dart`, replace Task 1a's enum:

```dart
/// Where a tag is offered (issues #1765, #1942). A tag applies to at least
/// one. Member order follows [tagScopeTables], which is the display order.
enum TagScope {
  dives,
  sites;

  /// Where this scope stores its flag and its links.
  TagScopeTable get table => switch (this) {
    TagScope.dives => diveTagScopeTable,
    TagScope.sites => siteTagScopeTable,
  };
}
```

with:

```dart
/// Where a tag is offered (issues #1765, #1942). A tag applies to at least
/// one. Member order follows [tagScopeTables], which is the display order.
enum TagScope {
  dives,
  sites,
  equipment;

  /// Where this scope stores its flag and its links.
  TagScopeTable get table => switch (this) {
    TagScope.dives => diveTagScopeTable,
    TagScope.sites => siteTagScopeTable,
    TagScope.equipment => equipmentTagScopeTable,
  };
}
```

and, in the same file, the class doc line `/// Tag entity for organizing dives and dive sites`
(directly above `class Tag extends Equatable {`) becomes:

```dart
/// Tag entity for organizing dives, dive sites and equipment
```

From here until Step 11 the analyzer reports `non_exhaustive_switch_expression`
in `tagScopesOf` (`tag_row_mapper.dart`) and in the four functions of
`tag_scope_labels.dart`. Step 7 runs only test files whose imports do not
reach those two files; `flutter analyze` runs in Step 12.

- [ ] **Step 4: Schema in `database.dart`**

In `class Tags`, after `appliesToSites` (line 2467), add:

```dart
  /// Whether the tag is offered on equipment (v219, issue #1942). No tag
  /// that existed before v219 is an equipment tag.
  BoolColumn get appliesToEquipment =>
      boolean().withDefault(const Constant(false))();
```

and change the `appliesToSites` doc's last sentence to "A tag always applies to at least one scope; TagRepository enforces it."

After `class SiteTags` (ends at line 2606), add:

```dart
/// Junction table for an equipment item's tags (many-to-many, v219, issue
/// #1942), the twin of [SiteTags]. Surrogate uuid primary key, so a
/// re-inserted pair never collides with its predecessor's tombstone (#347);
/// the (equipment_id, tag_id) unique index lives in tag_uniqueness.dart.
class EquipmentTags extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}
```

In the `@DriftDatabase(tables: [...])` list, after `SiteTags,` (line 4123):

```dart
    // Equipment tags (v219, issue #1942)
    EquipmentTags,
```

Line 4184: `static const int currentSchemaVersion = 219;`

In `migrationVersions`, after `218,` (line 4789):

```dart
    // v219: equipment tags (issue #1942). tags.applies_to_equipment (off for
    // every existing tag) and the equipment_tags junction with its
    // (equipment_id, tag_id) unique index. Additive only, so the
    // compatibility floor stays.
    219,
```

In `_assertChildHlcColumns`, after `'site_tags',` (line 5228):

```dart
      'equipment_tags',
```

Replace `_assertTagScopeColumns` (lines 8179-8197; its doc comment currently sits under a stray v174 comment, leave that one as it is):

```dart
  /// Idempotent DDL for the tag scope flags: dives and sites (v217, issue
  /// #1765), equipment (v219, issue #1942). Existing tags are dive tags; none
  /// applies to sites or equipment until the diver says so.
  Future<void> _assertTagScopeColumns() async {
    final cols = await customSelect("PRAGMA table_info('tags')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('applies_to_dives')) {
      await customStatement(
        'ALTER TABLE tags ADD COLUMN applies_to_dives '
        'INTEGER NOT NULL DEFAULT 1 CHECK (applies_to_dives IN (0, 1))',
      );
    }
    if (!names.contains('applies_to_sites')) {
      await customStatement(
        'ALTER TABLE tags ADD COLUMN applies_to_sites '
        'INTEGER NOT NULL DEFAULT 0 CHECK (applies_to_sites IN (0, 1))',
      );
    }
    if (!names.contains('applies_to_equipment')) {
      await customStatement(
        'ALTER TABLE tags ADD COLUMN applies_to_equipment '
        'INTEGER NOT NULL DEFAULT 0 CHECK (applies_to_equipment IN (0, 1))',
      );
    }
  }
```

After `_assertSiteClassificationSchema` (ends at line 8220), add:

```dart
  /// Idempotent creation of the v219 equipment tag schema (issue #1942): the
  /// `equipment_tags` junction and its (equipment, tag) unique index. Called
  /// from the v219 rung and the beforeOpen backstop.
  ///
  /// Skipped on a partial migration-test fixture that lacks either parent
  /// table, so a fixture written for an older rung does not gain a junction
  /// whose foreign keys point nowhere.
  Future<void> _assertEquipmentTagSchema() async {
    for (final parent in const ['equipment', 'tags']) {
      final rows = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(parent)],
      ).get();
      if (rows.isEmpty) return;
    }
    await createMigrator().createTable(equipmentTags);
    await assertEquipmentTagUniqueness(this);
  }
```

In `onCreate`, after `await assertSiteClassificationUniqueness(this);` (line 8555):

```dart

        // Equipment tag junction unique index (v219, issue #1942), for the
        // same reason: createAll() never builds raw-SQL indexes.
        await assertEquipmentTagUniqueness(this);
```

In `onUpgrade`, after `if (from < 218) await reportProgress();` (line 12188):

```dart
        // v219: equipment tags (issue #1942). Column-and-table rung, no
        // backfill: existing tags stay off equipment.
        if (from < 219) {
          await _assertTagScopeColumns();
          await _assertEquipmentTagSchema();
        }
        if (from < 219) await reportProgress();
```

In `beforeOpen`, change the first comment (line 12191) to
`// v217 and v219 backstop: the tag scope flags.` (the call stays), and after
`await _assertSiteClassificationSchema();` (line 12304) add:

```dart

        // v219 backstop: the equipment tag junction and its index
        // (parallel-branch version-collision self-heal; all idempotent).
        await _assertEquipmentTagSchema();
```

- [ ] **Step 5: The junction index in `tag_uniqueness.dart`**

Directly after the `kCreateDiveTagsUniqueIndexSql` const (main lines 53-55; Task 1a did not touch the constants block, but locate it by name), add:

```dart
/// Unique index over the `equipment_tags` junction (v219, issue #1942), one
/// row per (item, tag). Like `site_tags`, the table has the index from the
/// day it exists, so the collapse below only runs on a database that lost it.
const String kEquipmentTagsUniqueIndexName =
    'idx_equipment_tags_equipment_tag_unique';

const String kCreateEquipmentTagsUniqueIndexSql =
    'CREATE UNIQUE INDEX IF NOT EXISTS $kEquipmentTagsUniqueIndexName '
    'ON equipment_tags(equipment_id, tag_id)';

/// Keeps the oldest row of each (item, tag) pair, `id` breaking ties, so
/// every device lands on the same survivor.
const String _collapseDuplicateEquipmentTagPairsSql = '''
  DELETE FROM equipment_tags WHERE rowid IN (
    SELECT rowid FROM (
      SELECT rowid, ROW_NUMBER() OVER (
        PARTITION BY equipment_id, tag_id ORDER BY created_at ASC, id ASC
      ) AS rn FROM equipment_tags
    ) WHERE rn > 1
  )
''';
```

After the closing `}` of `assertTagUniqueness` and before the `_normalizeSql` doc comment (main line 249; Task 1a rewrote the code above it, so locate it by name), add. `_tableExists` is the private helper Task 1a kept in this file:

```dart
/// Asserts the `equipment_tags` unique index exists, collapsing duplicate
/// pairs first so creating it cannot abort. One `sqlite_master` lookup when
/// the index is present. Self-guarding on the table existing, so partial
/// migration-test fixtures pass through.
///
/// Called from `onCreate` (`createAll()` never builds raw-SQL indexes), the
/// v219 rung and `beforeOpen`, through `_assertEquipmentTagSchema`.
Future<void> assertEquipmentTagUniqueness(DatabaseConnectionUser db) async {
  if (!await _tableExists(db, 'equipment_tags')) return;
  final present = await db
      .customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = ?",
        variables: const [Variable<String>(kEquipmentTagsUniqueIndexName)],
      )
      .get();
  if (present.isNotEmpty) return;
  await db.customStatement(_collapseDuplicateEquipmentTagPairsSql);
  await db.customStatement(kCreateEquipmentTagsUniqueIndexSql);
}
```

Do not edit `collapseDuplicateTags` or its helpers. Task 1a made them loop
over `tagScopeTables` (`_repointToSurvivorSql`, `_deleteLinksOnLosingTagsSql`,
`_mergeScopesIntoSurvivorSql`, `_collapseDuplicateLinksSql`), skipping any
junction table or scope column the schema lacks, so the new registry entry
brings `equipment_tags` and `applies_to_equipment` into the repair by itself.
The first two tests of `tag_uniqueness_equipment_tags_test.dart` pin that.
The pair collapse above is separate on purpose: it mirrors the `site_tags`
one in `site_classification_uniqueness.dart` (oldest `created_at`, then `id`),
and runs only when the junction index itself is missing.

- [ ] **Step 6: Register the junction's clock**

In `lib/core/data/repositories/sync_repository.dart`, after
`'siteTags': (table: 'site_tags', pk: 'id'),` (line 149):

```dart
    'equipmentTags': (table: 'equipment_tags', pk: 'id'),
```

- [ ] **Step 7: Regenerate Drift code, relax the v218 test, run the schema tests**

In `test/core/database/migration_v218_site_detail_sections_test.dart`, replace lines 9-14:

```dart
  test('v218 is at or below the current schema version and in the ladder', () {
    // Relaxed once v219 (equipment tags) landed on top; the newest rung owns
    // the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(218));
    expect(AppDatabase.migrationVersions, contains(218));
  });
```

and line 81:

```dart
    expect(
      version.read<int>('user_version'),
      AppDatabase.currentSchemaVersion,
    );
```

(`grep -rn "\b218\b" test` finds no other schema-version literal: the other
hits are issue #218 and fixture data.)

Regenerate the Drift code. The Bash tool refuses a command containing a bare
`build` token, so, as in Task 1b Step 12, write a two-line script into your
scratchpad and run it (replace `$SCRATCHPAD` with your scratchpad directory):

```bash
cat > "$SCRATCHPAD/codegen.sh" <<'SH'
cd "$(git rev-parse --show-toplevel)"
dart run build_runner build --delete-conflicting-outputs
SH
bash "$SCRATCHPAD/codegen.sh"
```

Then: `flutter test test/core/database/tag_scope_tables_test.dart test/core/database/migration_v219_equipment_tags_test.dart test/core/database/tag_uniqueness_equipment_tags_test.dart test/core/database/tag_uniqueness_registry_test.dart test/core/database/migration_v218_site_detail_sections_test.dart test/core/database/migration_v217_site_classification_test.dart test/core/database/tag_uniqueness_site_tags_test.dart test/core/database/migration_v149_tag_uniqueness_test.dart test/core/database/migration_v211_auto_tag_imports_test.dart`
Expected: PASS. None of these imports `tag_row_mapper.dart` or
`tag_scope_labels.dart`, whose switches are not exhaustive until Step 11.
The sync guards (`sync_hlc_target_registration_test.dart`, `child_hlc_test.dart`)
import `sync_data_serializer.dart`, which imports `tag_row_mapper.dart` since
Task 1a, so they run in Step 12.

- [ ] **Step 8: Write the failing scope-arm tests (mapper, labels, repository, picker, Manage Tags)**

(a) Replace the whole of `test/features/tags/data/mappers/tag_row_mapper_test.dart`
(created by Task 1a). Drift makes `appliesToEquipment` a required argument of
the generated `Tag` row constructor once Step 7's codegen ran, so Task 1a's
`row()` helper no longer compiles; the new file keeps Task 1a's two tests
(extended to the third column) and adds the equipment ones.

```dart
import 'package:drift/drift.dart' show Expression, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_scope_tables.dart';
import 'package:submersion/features/tags/data/mappers/tag_row_mapper.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart'
    show TagScope;

/// The row mapper converts between the `tags` flag columns and a set of
/// scopes (issue #1942).
void main() {
  Tag row({
    required bool dives,
    required bool sites,
    bool equipment = false,
  }) => Tag(
    id: 't',
    name: 'T',
    createdAt: 0,
    updatedAt: 0,
    appliesToDives: dives,
    appliesToSites: sites,
    appliesToEquipment: equipment,
  );

  bool? flag(Map<String, Expression> columns, String column) =>
      (columns[column]! as Variable<bool>).value;

  test('reads each flag column into the set', () {
    expect(tagScopesOf(row(dives: true, sites: false)), {TagScope.dives});
    expect(tagScopesOf(row(dives: false, sites: true)), {TagScope.sites});
    expect(tagScopesOf(row(dives: true, sites: true)), {
      TagScope.dives,
      TagScope.sites,
    });
    expect(tagScopesOf(row(dives: false, sites: false)), isEmpty);
  });

  test('reads the equipment flag (v219)', () {
    expect(
      tagScopesOf(row(dives: false, sites: false, equipment: true)),
      {TagScope.equipment},
    );
    expect(
      tagScopesOf(row(dives: true, sites: true, equipment: true)),
      TagScope.values.toSet(),
    );
  });

  test('writes a value for every registry column', () {
    final columns = tagScopeColumns({TagScope.sites});
    expect(columns.keys, [for (final t in tagScopeTables) t.scopeColumn]);
    expect(flag(columns, 'applies_to_sites'), isTrue);
    expect(flag(columns, 'applies_to_dives'), isFalse);
    expect(flag(columns, 'applies_to_equipment'), isFalse);
  });

  test('columns and set round-trip for every combination of scopes', () {
    const scopes = TagScope.values;
    for (var mask = 0; mask < (1 << scopes.length); mask++) {
      final set = {
        for (var i = 0; i < scopes.length; i++)
          if ((mask & (1 << i)) != 0) scopes[i],
      };
      final columns = tagScopeColumns(set);
      final back = tagScopesOf(
        row(
          dives: flag(columns, 'applies_to_dives')!,
          sites: flag(columns, 'applies_to_sites')!,
          equipment: flag(columns, 'applies_to_equipment')!,
        ),
      );
      expect(back, set, reason: 'scope mask $mask');
    }
  });
}
```

(b) In `test/features/tags/presentation/tag_scope_labels_test.dart` (created by
Task 1b), add this test as the last statement of `main()`, after the test
named `'explains what turning each scope off removes'`:

```dart
  test('has the equipment wording (#1942)', () {
    expect(tagScopeName(l10n, TagScope.equipment), 'Equipment');
    expect(
      tagScopeUseForLabel(l10n, TagScope.equipment),
      'Use for equipment',
    );
    expect(tagScopeCount(l10n, TagScope.equipment, 0), '0 equipment items');
    expect(tagScopeCount(l10n, TagScope.equipment, 1), '1 equipment item');
    expect(tagScopeCount(l10n, TagScope.equipment, 4), '4 equipment items');
    expect(
      tagScopeNarrowLine(l10n, TagScope.equipment, 1),
      'This tag is on 1 equipment item. Turning off "Use for equipment" '
      'removes it from that item.',
    );
    expect(
      tagScopeNarrowLine(l10n, TagScope.equipment, 3),
      'This tag is on 3 equipment items. Turning off "Use for equipment" '
      'removes it from those items.',
    );
  });
```

(c) Create `test/features/tags/data/repositories/tag_scope_equipment_test.dart`.
Every repository path it drives has been registry-generated since Task 1b;
these pin that the third registry entry reaches each of them, with usage maps
compared whole because they are dense.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    show EquipmentTagsCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';

/// The equipment tag scope through TagRepository (issue #1942). The
/// repository has been registry-driven since the scope refactor; these pin
/// that the third registry entry reaches every scope path.
void main() {
  late TagRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = TagRepository();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 1, 1), ('e2', 'Fins', 'fins', 1, 1)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> linkItem(String equipmentId, String tagId) =>
      DatabaseService.instance.database.customStatement(
        "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
        "VALUES ('et-$equipmentId-$tagId', '$equipmentId', '$tagId', 0)",
      );

  Future<int> count(String sql) async {
    final row = await DatabaseService.instance.database
        .customSelect(sql)
        .getSingle();
    return row.read<int>('n');
  }

  Future<void> expectItemsUntouched() async {
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = 'equipment'",
      ),
      0,
      reason: 'a link change never marks the item pending (#1769)',
    );
    expect(
      await count('SELECT COUNT(*) AS n FROM equipment WHERE updated_at <> 1'),
      0,
      reason: 'a link change never bumps the item',
    );
  }

  test('a tag created from the equipment picker applies to equipment only', () async {
    final tag = await repository.getOrCreateTag(
      'Rental',
      scope: TagScope.equipment,
    );
    expect(tag.scopes, {TagScope.equipment});
    final stored = await repository.getTagById(tag.id);
    expect(stored!.scopes, {TagScope.equipment});
  });

  test('a name collision widens the existing tag to equipment', () async {
    final diveTag = await repository.getOrCreateTag('Night');
    final widened = await repository.getOrCreateTag(
      'night',
      scope: TagScope.equipment,
    );

    expect(widened.id, diveTag.id);
    expect(widened.scopes, {TagScope.dives, TagScope.equipment});
    final stored = await repository.getTagById(diveTag.id);
    expect(stored!.appliesTo(TagScope.equipment), isTrue);
  });

  test('createTag on a colliding name widens the incumbent to equipment', () async {
    final diveTag = await repository.getOrCreateTag('Night');
    final result = await repository.createTag(
      Tag.create(id: '', name: 'NIGHT', scope: TagScope.equipment),
    );
    expect(result.id, diveTag.id);
    expect(result.appliesTo(TagScope.equipment), isTrue);
  });

  test('scope-filtered listing includes equipment', () async {
    await repository.getOrCreateTag('Night');
    await repository.getOrCreateTag('To try', scope: TagScope.sites);
    await repository.getOrCreateTag('Rental', scope: TagScope.equipment);

    final gear = await repository.getAllTags(scope: TagScope.equipment);
    final dives = await repository.getAllTags(scope: TagScope.dives);
    expect(gear.map((t) => t.name), ['Rental']);
    expect(dives.map((t) => t.name), ['Night']);
    expect(await repository.getAllTags(), hasLength(3));
  });

  test('turning off equipment removes and tombstones the links', () async {
    await repository.getOrCreateTag('Rental', scope: TagScope.equipment);
    final tag = await repository.getOrCreateTag('Rental');
    expect(tag.scopes, {TagScope.dives, TagScope.equipment});
    await linkItem('e1', tag.id);
    await linkItem('e2', tag.id);

    await repository.updateTag(tag.copyWith(scopes: {TagScope.dives}));

    final db = DatabaseService.instance.database;
    expect(await db.select(db.equipmentTags).get(), isEmpty);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log "
        "WHERE entity_type = 'equipmentTags'",
      ),
      2,
    );
    expect((await repository.getTagById(tag.id))!.scopes, {TagScope.dives});
    await expectItemsUntouched();
  });

  test('a plain rename keeps the equipment links', () async {
    final tag = await repository.getOrCreateTag(
      'Rental',
      scope: TagScope.equipment,
    );
    await linkItem('e1', tag.id);

    await repository.updateTag(tag.copyWith(name: 'Rented'));

    final db = DatabaseService.instance.database;
    expect(await db.select(db.equipmentTags).get(), hasLength(1));
  });

  test('usage and statistics count equipment separately', () async {
    final tag = await repository.getOrCreateTag(
      'Rental',
      scope: TagScope.equipment,
    );
    await linkItem('e1', tag.id);
    await linkItem('e2', tag.id);

    expect(await repository.getTagUsage(tag.id), {
      TagScope.dives: 0,
      TagScope.sites: 0,
      TagScope.equipment: 2,
    });

    final stat = (await repository.getTagStatistics()).singleWhere(
      (s) => s.tag.id == tag.id,
    );
    expect(stat.count(TagScope.equipment), 2);
    expect(stat.count(TagScope.dives), 0);
  });

  test('statistics break dive and site ties by equipment use', () async {
    final alpha = await repository.getOrCreateTag(
      'Alpha',
      scope: TagScope.equipment,
    );
    final zulu = await repository.getOrCreateTag(
      'Zulu',
      scope: TagScope.equipment,
    );
    await linkItem('e1', alpha.id);
    await linkItem('e1', zulu.id);
    await linkItem('e2', zulu.id);

    final names = (await repository.getTagStatistics())
        .map((s) => s.tag.name)
        .toList();
    expect(names, ['Zulu', 'Alpha']);
  });

  test('merged usage counts an item carrying two of the tags once', () async {
    final a = await repository.getOrCreateTag('A', scope: TagScope.equipment);
    final b = await repository.getOrCreateTag('B', scope: TagScope.equipment);
    await linkItem('e1', a.id);
    await linkItem('e1', b.id);
    await linkItem('e2', b.id);

    expect(await repository.getMergedUsage([a.id, b.id]), {
      TagScope.dives: 0,
      TagScope.sites: 0,
      TagScope.equipment: 2,
    });
  });

  test('merging unions the scopes and relinks equipment tags', () async {
    final survivor = await repository.getOrCreateTag('Night');
    final rental = await repository.getOrCreateTag(
      'Rental',
      scope: TagScope.equipment,
    );
    final travel = await repository.getOrCreateTag(
      'Travel kit',
      scope: TagScope.equipment,
    );
    await linkItem('e1', rental.id);
    await linkItem('e2', rental.id);
    // e2 carries both sources, so it must end with one survivor link.
    await linkItem('e2', travel.id);

    await repository.mergeTags(
      sourceTagIds: [rental.id, travel.id],
      survivingTagId: survivor.id,
      name: 'Night',
      colorHex: null,
    );

    final merged = await repository.getTagById(survivor.id);
    expect(merged!.scopes, {TagScope.dives, TagScope.equipment});
    expect(await repository.getTagById(rental.id), isNull);
    expect(await repository.getTagById(travel.id), isNull);
    final db = DatabaseService.instance.database;
    final links = await db.select(db.equipmentTags).get();
    expect(links, hasLength(2));
    expect(links.map((l) => (l.equipmentId, l.tagId)).toSet(), {
      ('e1', survivor.id),
      ('e2', survivor.id),
    });
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log "
        "WHERE entity_type = 'equipmentTags'",
      ),
      3,
      reason: 'every source link is tombstoned',
    );
    await expectItemsUntouched();
  });

  test('deleting a tag takes its equipment links with it', () async {
    final tag = await repository.getOrCreateTag(
      'Rental',
      scope: TagScope.equipment,
    );
    await linkItem('e1', tag.id);

    await repository.deleteTag(tag.id);

    final db = DatabaseService.instance.database;
    expect(await db.select(db.equipmentTags).get(), isEmpty);
  });

  test('an equipment link change emits the tag link tick', () async {
    final tag = await repository.getOrCreateTag(
      'Rental',
      scope: TagScope.equipment,
    );
    final emitted = <void>[];
    final sub = repository.watchTagLinkChanges().listen(emitted.add);
    addTearDown(sub.cancel);

    // A typed insert: Drift cannot tell which table a raw statement touched.
    final db = DatabaseService.instance.database;
    await db
        .into(db.equipmentTags)
        .insert(
          EquipmentTagsCompanion.insert(
            id: 'et1',
            equipmentId: 'e1',
            tagId: tag.id,
            createdAt: 0,
          ),
        );
    await pumpEventQueue();

    expect(emitted, isNotEmpty);
  });
}
```

(d) In `test/features/tags/presentation/widgets/tag_picker_sheet_test.dart`,
add this group directly after the `group('from a site (issue #1765)', ...)`
group closes (its last test is `'confirms the picks in the same site order'`;
main line 178, a few lines earlier after Task 1b's respelling), inside
`group('TagPickerSheet', ...)`. `TagPickerSheet` needs no code for it: since
Task 1b `_inScope` keeps `stat.tag.appliesTo(widget.scope)` rows and, for any
scope but dives, sorts them by `stat.count(widget.scope)`, and the subtitle
is `tagScopeCount(context.l10n, widget.scope, stat.count(widget.scope))`.

```dart
    group('from equipment (issue #1942)', () {
      TagStatistic gearStat(
        String id,
        String name, {
        required int items,
        int dives = 0,
        bool forDives = false,
      }) => TagStatistic(
        tag: Tag(
          id: id,
          name: name,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          scopes: {if (forDives) TagScope.dives, TagScope.equipment},
        ),
        counts: {TagScope.dives: dives, TagScope.equipment: items},
      );

      // Dive-first order, as tagStatisticsProvider returns it.
      final mixed = [
        ...testStats,
        gearStat('both', 'Favourite', items: 1, dives: 5, forDives: true),
        gearStat('travel', 'Travel kit', items: 7),
        gearStat('rental', 'Rental', items: 2),
      ];

      testWidgets('lists only equipment tags, most used on equipment first', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(stats: mixed, scope: TagScope.equipment),
        );
        await tester.pumpAndSettle();

        expect(renderedTagNames(tester), ['Travel kit', 'Rental', 'Favourite']);
      });

      testWidgets('shows how many equipment items use each tag', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(stats: mixed, scope: TagScope.equipment),
        );
        await tester.pumpAndSettle();

        expect(find.text('7 equipment items'), findsOneWidget);
        expect(find.text('1 equipment item'), findsOneWidget);
        expect(find.textContaining('dives'), findsNothing);
      });

      testWidgets('confirms the picks in the same equipment order', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(stats: mixed, scope: TagScope.equipment),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Favourite'));
        await tester.tap(find.text('Travel kit'));
        await tester.pump();
        await tester.tap(find.text('Add 2 tags'));
        await tester.pump();

        expect(picked!.map((t) => t.id), ['travel', 'both']);
      });

      testWidgets('a dive never lists an equipment-only tag', (tester) async {
        await tester.pumpWidget(buildTestWidget(stats: mixed));
        await tester.pumpAndSettle();

        expect(renderedTagNames(tester), [
          'Wreck',
          'Night',
          'Deco',
          'Training',
          'Favourite',
        ]);
      });
    });
```

(e) Create `test/features/tags/presentation/pages/tag_manage_page_equipment_scope_test.dart`.
After Task 1b the Manage Tags page builds its checkboxes, a row's scope line,
its usage line and the narrowing confirmation from `TagScope.values` through
`tag_scope_labels.dart`, so this task is where the equipment scope first
appears there. Real database, like `tag_manage_page_scope_test.dart`, so the
usage line and the narrowing run end to end. (The delete and merge wording
for equipment, and the reworded "choose a scope" line, are Task 7's; Task 7
adds its tests for them to this file.)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/presentation/pages/tag_manage_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The equipment scope on the Tags management page (issue #1942), against a
/// real database so the usage line and the narrowing path run end to end.
void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;

  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
    );
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_sites (id, name, created_at, updated_at) '
      "VALUES ('s1', 'Site', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at) '
      "VALUES ('e1', 'Wing', 'bcd', 0, 0), ('e2', 'Fins', 'fins', 0, 0)",
    );
    // Travel kit: equipment only, on both items. Everywhere: every scope,
    // on one item of each.
    await db.customStatement(
      'INSERT INTO tags (id, diver_id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites, applies_to_equipment) VALUES '
      "('kit', 'diver-1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('all', 'diver-1', 'Everywhere', 0, 0, 1, 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) '
      "VALUES ('et1', 'e1', 'kit', 0), ('et2', 'e2', 'kit', 0), "
      "('et3', 'e1', 'all', 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) '
      "VALUES ('dt1', 'd1', 'all', 0)",
    );
    await db.customStatement(
      'INSERT INTO site_tags (id, site_id, tag_id, created_at) '
      "VALUES ('st1', 's1', 'all', 0)",
    );
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });

  tearDown(() async => tearDownTestDatabase());

  Widget page() => ProviderScope(
    overrides: [
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TagManagePage(),
    ),
  );

  final useForEquipment = find.widgetWithText(
    CheckboxListTile,
    'Use for equipment',
  );

  Future<void> openEditor(WidgetTester tester) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag_edit_kit')));
    await tester.pumpAndSettle();
  }

  /// The items [tagId] is linked to, read from the database.
  Future<List<String>> itemsTaggedWith(
    WidgetTester tester,
    String tagId,
  ) async {
    final rows = await tester.runAsync(() async {
      final db = DatabaseService.instance.database;
      return (db.select(
        db.equipmentTags,
      )..where((t) => t.tagId.equals(tagId))).get();
    });
    return [for (final r in rows!) r.equipmentId];
  }

  /// Turns [openEditor]'s tag from equipment-only to dives-only and saves,
  /// which asks before unlinking the two items.
  Future<void> narrowToDives(WidgetTester tester) async {
    await openEditor(tester);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Use for dives'));
    await tester.ensureVisible(useForEquipment);
    await tester.tap(useForEquipment);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('a row names its equipment scope and counts equipment items', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    expect(find.text('Equipment'), findsOneWidget);
    // The dive count always shows, as it did before sites and equipment.
    expect(find.text('0 dives, 2 equipment items'), findsOneWidget);
    expect(find.text('Dives · Sites · Equipment'), findsOneWidget);
    expect(find.text('1 dive, 1 site, 1 equipment item'), findsOneWidget);
  });

  testWidgets('the editor offers every scope, equipment ticked', (
    tester,
  ) async {
    await openEditor(tester);

    final boxes = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(boxes.map((b) => (b.title! as Text).data), [
      'Use for dives',
      'Use for sites',
      'Use for equipment',
    ]);
    expect(boxes.map((b) => b.value), [false, false, true]);
  });

  testWidgets('turning off equipment confirms, then removes the links', (
    tester,
  ) async {
    await narrowToDives(tester);

    expect(
      find.text(
        'This tag is on 2 equipment items. Turning off "Use for equipment" '
        'removes it from those items.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(await itemsTaggedWith(tester, 'kit'), isEmpty);
    expect(
      await itemsTaggedWith(tester, 'all'),
      ['e1'],
      reason: 'another tag on the same item keeps its link',
    );
    expect(find.text('Dives'), findsOneWidget);
    expect(find.text('0 dives'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation keeps the equipment links', (
    tester,
  ) async {
    await narrowToDives(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await tester.pumpAndSettle();

    expect(
      await itemsTaggedWith(tester, 'kit'),
      unorderedEquals(['e1', 'e2']),
    );
    expect(find.text('Edit Tag'), findsOneWidget);
  });

  testWidgets('a new tag can be offered for equipment only', (tester) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Rental');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Use for dives'));
    await tester.ensureVisible(useForEquipment);
    await tester.tap(useForEquipment);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    final flags = await tester.runAsync(() async {
      final row = await DatabaseService.instance.database
          .customSelect(
            'SELECT applies_to_dives AS d, applies_to_sites AS s, '
            "applies_to_equipment AS e FROM tags WHERE name = 'Rental'",
          )
          .getSingle();
      return (row.read<int>('d'), row.read<int>('s'), row.read<int>('e'));
    });
    expect(flags, (0, 0, 1));
    expect(find.text('Rental'), findsOneWidget);
  });
}
```

- [ ] **Step 9: Run them and confirm they fail**

Run: `flutter test test/features/tags/data/mappers/tag_row_mapper_test.dart test/features/tags/presentation/tag_scope_labels_test.dart test/features/tags/data/repositories/tag_scope_equipment_test.dart test/features/tags/presentation/widgets/tag_picker_sheet_test.dart test/features/tags/presentation/pages/tag_manage_page_equipment_scope_test.dart`
Expected: FAIL to compile, every file: `non_exhaustive_switch_expression` in
`tagScopesOf` (`lib/features/tags/data/mappers/tag_row_mapper.dart`) and in
`tagScopeName`, `tagScopeUseForLabel`, `tagScopeCount` and `tagScopeNarrowLine`
(`lib/features/tags/presentation/tag_scope_labels.dart`): "The type
'TagScope' is not exhaustively matched by the switch cases since it doesn't
match 'TagScope.equipment'". Every file imports one of the two, directly or
through `TagRepository`, `TagPickerSheet` or `TagManagePage`.

- [ ] **Step 10: The four strings, in all 11 locales**

The ARB files are grouped by feature, not sorted: insert each key beside its
dives and sites siblings, as #1849 and #1933 did. Use the Edit tool (these
files are LF, but never rewrite them with a script). The English text and the
ten translations below are the ones drafted for Tasks 7 and 11
(part_task07_11.md); copy them byte for byte. Each locale's terms come from
its existing keys: the noun for an equipment item is the one
`dataQuality_carries_gear` and `trips_serviceAlert_count` use, the scope name
is the locale's `nav_equipment`, and the checkbox follows its
`tags_manage_useForSites` pattern. Arabic uses the CLDR categories
`zero`/`one`/`two`/`few`/`many`/`other` (the count is nominative, `قطعتا معدات`;
the narrowing line uses the genitive after على); Hebrew keeps `=1`/`other`
like the dives and sites lines, since the count is written as digits.

(a) `lib/l10n/arb/app_en.arb` (four edits):

Between the `@tags_manage_narrowDialog_dives` block and the
`"tags_manage_narrowDialog_sites"` line (main line 12840), insert:

```json
  "tags_manage_narrowDialog_equipment": "{count, plural, =1{This tag is on 1 equipment item. Turning off \"Use for equipment\" removes it from that item.} other{This tag is on {count} equipment items. Turning off \"Use for equipment\" removes it from those items.}}",
  "@tags_manage_narrowDialog_equipment": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
```

Between `"tags_manage_scope_dives": "Dives",` and `"tags_manage_scope_sites": "Sites",` (main 12850-12851), insert:

```json
  "tags_manage_scope_equipment": "Equipment",
```

Directly after the `@tags_manage_siteCount` block (closes at main line 12859), insert:

```json
  "tags_manage_equipmentCount": "{count, plural, =0{0 equipment items} =1{1 equipment item} other{{count} equipment items}}",
  "@tags_manage_equipmentCount": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
```

Between `"tags_manage_useForDives": "Use for dives",` and `"tags_manage_useForSites": "Use for sites",` (main 12860-12861), insert:

```json
  "tags_manage_useForEquipment": "Use for equipment",
```

(b) The ten other locales. None of them carries `@` metadata blocks, and all
ten share the `tags_manage_*` order, so each key is one line placed by the
same anchors (checked in every file):

| Key | Goes |
| --- | --- |
| `tags_manage_narrowDialog_equipment` | between the `tags_manage_narrowDialog_dives` and `tags_manage_narrowDialog_sites` lines |
| `tags_manage_scope_equipment` | between the `tags_manage_scope_dives` and `tags_manage_scope_sites` lines |
| `tags_manage_equipmentCount` | directly after the `tags_manage_siteCount` line |
| `tags_manage_useForEquipment` | between the `tags_manage_useForDives` and `tags_manage_useForSites` lines |

Each block lists that locale's four lines in the table's order. Keep them byte
for byte: the quote marks are each locale's own (German „…“, Hungarian „…”,
French and Spanish « », Chinese “…”), matching the neighbouring
`narrowDialog` lines.

`lib/l10n/arb/app_ar.arb` (Arabic):

```json
  "tags_manage_narrowDialog_equipment": "{count, plural, one{هذا الوسم على قطعة معدات واحدة. إيقاف \"استخدام للمعدات\" يزيله من تلك القطعة.} two{هذا الوسم على قطعتي معدات. إيقاف \"استخدام للمعدات\" يزيله من هاتين القطعتين.} few{هذا الوسم على {count} قطع معدات. إيقاف \"استخدام للمعدات\" يزيله من تلك القطع.} many{هذا الوسم على {count} قطعة معدات. إيقاف \"استخدام للمعدات\" يزيله من تلك القطع.} other{هذا الوسم على {count} قطعة معدات. إيقاف \"استخدام للمعدات\" يزيله من تلك القطع.}}",
  "tags_manage_scope_equipment": "المعدات",
  "tags_manage_equipmentCount": "{count, plural, zero{0 قطع معدات} one{قطعة معدات واحدة} two{قطعتا معدات} few{{count} قطع معدات} many{{count} قطعة معدات} other{{count} قطعة معدات}}",
  "tags_manage_useForEquipment": "استخدام للمعدات",
```

`lib/l10n/arb/app_de.arb` (German):

```json
  "tags_manage_narrowDialog_equipment": "{count, plural, =1{Dieser Tag ist an 1 Ausrüstungsteil. Wenn „Für Ausrüstung verwenden“ ausgeschaltet wird, wird er von diesem Ausrüstungsteil entfernt.} other{Dieser Tag ist an {count} Ausrüstungsteilen. Wenn „Für Ausrüstung verwenden“ ausgeschaltet wird, wird er von diesen Ausrüstungsteilen entfernt.}}",
  "tags_manage_scope_equipment": "Ausrüstung",
  "tags_manage_equipmentCount": "{count, plural, =0{0 Ausrüstungsteile} =1{1 Ausrüstungsteil} other{{count} Ausrüstungsteile}}",
  "tags_manage_useForEquipment": "Für Ausrüstung verwenden",
```

`lib/l10n/arb/app_es.arb` (Spanish):

```json
  "tags_manage_narrowDialog_equipment": "{count, plural, =1{Esta etiqueta está en 1 equipo. Desactivar «Usar en equipos» la quita de ese equipo.} other{Esta etiqueta está en {count} equipos. Desactivar «Usar en equipos» la quita de esos equipos.}}",
  "tags_manage_scope_equipment": "Equipo",
  "tags_manage_equipmentCount": "{count, plural, =0{0 equipos} =1{1 equipo} other{{count} equipos}}",
  "tags_manage_useForEquipment": "Usar en equipos",
```

`lib/l10n/arb/app_fr.arb` (French):

```json
  "tags_manage_narrowDialog_equipment": "{count, plural, =1{Cette étiquette est sur 1 équipement. Désactiver « Utiliser pour l'équipement » la retire de cet équipement.} other{Cette étiquette est sur {count} équipements. Désactiver « Utiliser pour l'équipement » la retire de ces équipements.}}",
  "tags_manage_scope_equipment": "Équipement",
  "tags_manage_equipmentCount": "{count, plural, =0{0 équipement} =1{1 équipement} other{{count} équipements}}",
  "tags_manage_useForEquipment": "Utiliser pour l'équipement",
```

`lib/l10n/arb/app_he.arb` (Hebrew):

```json
  "tags_manage_narrowDialog_equipment": "{count, plural, =1{התגית הזו מופיעה בפריט ציוד אחד. כיבוי \"שימוש לציוד\" יסיר אותה מפריט זה.} other{התגית הזו מופיעה ב-{count} פריטי ציוד. כיבוי \"שימוש לציוד\" יסיר אותה מפריטים אלה.}}",
  "tags_manage_scope_equipment": "ציוד",
  "tags_manage_equipmentCount": "{count, plural, =0{0 פריטי ציוד} =1{פריט ציוד אחד} other{{count} פריטי ציוד}}",
  "tags_manage_useForEquipment": "שימוש לציוד",
```

`lib/l10n/arb/app_hu.arb` (Hungarian):

```json
  "tags_manage_narrowDialog_equipment": "{count, plural, =1{Ez a címke 1 felszerelésen szerepel. A „Felszereléshez” kikapcsolása eltávolítja erről a felszerelésről.} other{Ez a címke {count} felszerelésen szerepel. A „Felszereléshez” kikapcsolása eltávolítja ezekről a felszerelésekről.}}",
  "tags_manage_scope_equipment": "Felszerelés",
  "tags_manage_equipmentCount": "{count, plural, =0{0 felszerelés} =1{1 felszerelés} other{{count} felszerelés}}",
  "tags_manage_useForEquipment": "Felszereléshez",
```

`lib/l10n/arb/app_it.arb` (Italian):

```json
  "tags_manage_narrowDialog_equipment": "{count, plural, =1{Questo tag è su 1 attrezzatura. Disattivando \"Usa per l'attrezzatura\" verrà rimosso da quell'attrezzatura.} other{Questo tag è su {count} attrezzature. Disattivando \"Usa per l'attrezzatura\" verrà rimosso da quelle attrezzature.}}",
  "tags_manage_scope_equipment": "Attrezzatura",
  "tags_manage_equipmentCount": "{count, plural, =0{0 attrezzature} =1{1 attrezzatura} other{{count} attrezzature}}",
  "tags_manage_useForEquipment": "Usa per l'attrezzatura",
```

`lib/l10n/arb/app_nl.arb` (Dutch):

```json
  "tags_manage_narrowDialog_equipment": "{count, plural, =1{Deze tag staat op 1 uitrustingsstuk. Als je \"Gebruiken voor uitrusting\" uitzet, wordt hij van dat uitrustingsstuk verwijderd.} other{Deze tag staat op {count} uitrustingsstukken. Als je \"Gebruiken voor uitrusting\" uitzet, wordt hij van die uitrustingsstukken verwijderd.}}",
  "tags_manage_scope_equipment": "Uitrusting",
  "tags_manage_equipmentCount": "{count, plural, =0{0 uitrustingsstukken} =1{1 uitrustingsstuk} other{{count} uitrustingsstukken}}",
  "tags_manage_useForEquipment": "Gebruiken voor uitrusting",
```

`lib/l10n/arb/app_pt.arb` (Portuguese):

```json
  "tags_manage_narrowDialog_equipment": "{count, plural, =1{Esta etiqueta está em 1 equipamento. Desativar \"Usar em equipamentos\" remove-a desse equipamento.} other{Esta etiqueta está em {count} equipamentos. Desativar \"Usar em equipamentos\" remove-a desses equipamentos.}}",
  "tags_manage_scope_equipment": "Equipamentos",
  "tags_manage_equipmentCount": "{count, plural, =0{0 equipamentos} =1{1 equipamento} other{{count} equipamentos}}",
  "tags_manage_useForEquipment": "Usar em equipamentos",
```

`lib/l10n/arb/app_zh.arb` (Chinese):

```json
  "tags_manage_narrowDialog_equipment": "{count, plural, =1{此标签用于 1 件装备。关闭“用于装备”将从该装备中移除它。} other{此标签用于 {count} 件装备。关闭“用于装备”将从这些装备中移除它。}}",
  "tags_manage_scope_equipment": "装备",
  "tags_manage_equipmentCount": "{count, plural, =0{0 件装备} =1{1 件装备} other{{count} 件装备}}",
  "tags_manage_useForEquipment": "用于装备",
```

(c) Regenerate and check:

Run: `flutter gen-l10n`
Expected: no "untranslated message" notes for these four keys.

Run: `flutter test test/l10n/`
Expected: PASS (`arb_parity_test.dart`: every locale defines every English key,
and the placeholders match English in every locale).

- [ ] **Step 11: The equipment arms**

(a) `lib/features/tags/data/mappers/tag_row_mapper.dart`, in Task 1a's
`tagScopesOf`, replace the switch:

```dart
    if (switch (scope) {
      domain.TagScope.dives => row.appliesToDives,
      domain.TagScope.sites => row.appliesToSites,
    })
```

with:

```dart
    if (switch (scope) {
      domain.TagScope.dives => row.appliesToDives,
      domain.TagScope.sites => row.appliesToSites,
      domain.TagScope.equipment => row.appliesToEquipment,
    })
```

`tagScopeColumns` and `mapTagRow` need nothing: the first is generated from
the registry, the second calls `tagScopesOf`.

(b) `lib/features/tags/presentation/tag_scope_labels.dart` (Task 1b's file):
add one arm to each of the four switches, after its `TagScope.sites` arm:

- in `tagScopeName`: `TagScope.equipment => l10n.tags_manage_scope_equipment,`
- in `tagScopeUseForLabel`: `TagScope.equipment => l10n.tags_manage_useForEquipment,`
- in `tagScopeCount`: `TagScope.equipment => l10n.tags_manage_equipmentCount(count),`
- in `tagScopeNarrowLine`: `TagScope.equipment => l10n.tags_manage_narrowDialog_equipment(count),`

(c) `lib/features/tags/presentation/widgets/tag_picker_sheet.dart`, docs only.
In the class doc, replace:

```dart
/// [scope] says what is being tagged (issue #1765): a dive lists only dive
/// tags, most used on dives first; a site lists only site tags, most used on
/// sites first, each with its site count.
```

with:

```dart
/// [scope] says what is being tagged (issues #1765, #1942): the sheet lists
/// only tags offered in that scope, most used there first, each with its
/// count in that scope.
```

and the `scope` field doc `/// Dive tags or site tags.` becomes
`/// Whose tags these are: dive, site or equipment tags.`

(d) Confirm no `TagScope` switch is left without its arm and no scope column
is named outside the registry's readers:

Run: `grep -rn "TagScope.sites =>" lib`
Expected: exactly five hits (`TagScope.table` in `tag.dart`, `tagScopesOf`,
and the four label functions), each followed by a `TagScope.equipment =>`
line. Then: `grep -rn "appliesToSites\|appliesToEquipment" lib | grep -v "\.g\.dart"`
Expected: the two column definitions in `database.dart`, the two row reads
in `tagScopesOf`, and the UDDF import code (`uddf_import_parsers.dart`'s
`tag['appliesToSites']` and `uddf_entity_importer.dart`'s
`tagData['appliesToSites']` plus the local `appliesToSites` flag read from
it): those are the file format, which Task 9 extends. Any other hit is a
place that bypasses the registry.

- [ ] **Step 12: Run the tag tests and everything that pumps a tag widget**

Run: `flutter test test/features/tags`
Expected: PASS. This covers Step 8's five files and every Task 1 test under
`test/features/tags` (the registry, the usage maps with the `divesAndSites`
helper, statistics, merge, narrowing, the Manage Tags page and scope tests,
the merge sheet and the picker), now with a third registry entry.

Run: `flutter test test/core/database/tag_scope_tables_test.dart test/core/database/tag_uniqueness_registry_test.dart test/core/services/sync/sync_hlc_target_registration_test.dart test/core/services/sync/child_hlc_test.dart test/core/services/sync/sync_tag_identity_test.dart test/core/services/sync/site_classification_sync_test.dart test/core/services/export/uddf/uddf_site_classification_export_test.dart test/features/dive_log/presentation/pages/dive_edit_tag_picker_test.dart test/features/dive_log/presentation/pages/bulk_membership_wiring_test.dart test/features/dive_sites/presentation/widgets/edit_sections/type_tags_section_test.dart`
Expected: PASS. The sync files compile again now that `tagScopesOf` is
exhaustive, and prove the registry fold and scope union still hold for dives
and sites; the last three pump `TagPickerSheet` or `TagInputWidget`
(`grep -rl "TagPickerSheet\|TagInputWidget\|TypeTagsSection" test`).

Run: `flutter test test/architecture/`
Expected: PASS.

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 13: Write the failing junction, provider and equipment repository tests**

Create `test/features/equipment/data/repositories/equipment_tag_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';

import '../../../../helpers/bound_variables.dart';
import '../../../../helpers/test_database.dart';

/// The equipment tag junction (issue #1942).
void main() {
  late EquipmentTagRepository repository;

  Future<void> seed() async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 1, 1), ('e2', 'Fins', 'fins', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) "
      "VALUES ('t1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('t2', 'Rental', 0, 0, 0, 0, 1)",
    );
  }

  setUp(() async {
    await setUpTestDatabase();
    repository = EquipmentTagRepository();
    await seed();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<int> count(String sql) async {
    final row = await DatabaseService.instance.database
        .customSelect(sql)
        .getSingle();
    return row.read<int>('n');
  }

  Future<Set<String>> tagIdsOf(String equipmentId) async =>
      ((await repository.getTagIdsByEquipment([equipmentId]))[equipmentId] ??
              const <String>[])
          .toSet();

  test('replaceTags sets the exact set and reads it back by name', () async {
    await repository.replaceTags('e1', ['t1', 't2']);
    final tags = await repository.getTagsForEquipment('e1');
    expect(tags.map((t) => t.name), ['Rental', 'Travel kit']);
  });

  test('replaceTags removes only what left the set and tombstones it', () async {
    final db = DatabaseService.instance.database;
    await repository.replaceTags('e1', ['t1', 't2']);
    final before = await db.select(db.equipmentTags).get();
    final keptId = before.firstWhere((r) => r.tagId == 't1').id;
    final droppedId = before.firstWhere((r) => r.tagId == 't2').id;

    await repository.replaceTags('e1', ['t1']);

    final after = await db.select(db.equipmentTags).get();
    expect(after.map((r) => r.id), [keptId], reason: 'a kept pair keeps its row');
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones
          .where((t) => t.entityType == 'equipmentTags')
          .map((t) => t.recordId),
      [droppedId],
    );
  });

  test('a failing replaceTags leaves the previous set whole', () async {
    await repository.replaceTags('e1', ['t1']);

    // 'missing' has no tags row, so its insert fails the foreign key after
    // t1's row was already deleted inside the same transaction.
    await expectLater(
      repository.replaceTags('e1', ['t2', 'missing']),
      throwsA(anything),
    );

    expect(await tagIdsOf('e1'), {'t1'});
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log "
        "WHERE entity_type = 'equipmentTags'",
      ),
      0,
    );
  });

  test('addTags unions across items and never removes', () async {
    await repository.addTags(['e1'], ['t1']);
    await repository.addTags(['e1', 'e2'], ['t1', 't2']);

    expect(await tagIdsOf('e1'), {'t1', 't2'});
    expect(await tagIdsOf('e2'), {'t1', 't2'});
    expect(await count('SELECT COUNT(*) AS n FROM equipment_tags'), 4);
  });

  test('a duplicate add is a no-op', () async {
    final db = DatabaseService.instance.database;
    await repository.addTags(['e1'], ['t1']);
    final first = (await db.select(db.equipmentTags).get()).single;
    await SyncRepository().clearAllSyncRecords();

    await repository.addTags(['e1', 'e1'], ['t1', 't1']);

    final rows = await db.select(db.equipmentTags).get();
    expect(rows.map((r) => r.id), [first.id]);
    expect(await count('SELECT COUNT(*) AS n FROM sync_records'), 0);
  });

  test('removeTags drops only the named pairs and tombstones each', () async {
    await repository.addTags(['e1'], ['t1', 't2']);
    await repository.addTags(['e2'], ['t1']);

    await repository.removeTags(['e1', 'e2'], ['t1']);

    expect(await tagIdsOf('e1'), {'t2'});
    expect(await tagIdsOf('e2'), isEmpty);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log "
        "WHERE entity_type = 'equipmentTags'",
      ),
      2,
    );
  });

  test('junction writes mark the rows pending, never the item', () async {
    await repository.replaceTags('e1', ['t1']);
    await repository.addTags(['e1', 'e2'], ['t2']);
    await repository.removeTags(['e2'], ['t2']);

    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records "
        "WHERE entity_type = 'equipmentTags'",
      ),
      3,
      reason: 'one pending mark per inserted row',
    );
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = 'equipment'",
      ),
      0,
    );
    expect(
      await count('SELECT COUNT(*) AS n FROM equipment WHERE updated_at <> 1'),
      0,
    );
    expect(
      await count('SELECT COUNT(*) AS n FROM equipment_tags WHERE hlc IS NULL'),
      0,
      reason: 'marking a link pending stamps its own clock',
    );
  });

  test('batch reads group by item', () async {
    await repository.replaceTags('e1', ['t1']);
    await repository.replaceTags('e2', ['t1', 't2']);

    final byItem = await repository.getTagsByEquipment();
    expect(byItem['e1']!.map((t) => t.name), ['Travel kit']);
    expect(byItem['e2']!.map((t) => t.name), ['Rental', 'Travel kit']);

    final ids = await repository.getTagIdsByEquipment(['e1', 'e2', 'e9']);
    expect(ids['e1'], ['t1']);
    expect(ids['e2'], ['t1', 't2'], reason: 'oldest link first');
    expect(ids.containsKey('e9'), isFalse);

    expect(await repository.tagCountsForEquipment(['e1', 'e2']), {
      't1': 2,
      't2': 1,
    });
    expect(await repository.tagCountsForEquipment(['e2']), {'t1': 1, 't2': 1});
  });

  test('empty inputs read and write nothing', () async {
    expect(await repository.getTagIdsByEquipment(const []), isEmpty);
    expect(await repository.tagCountsForEquipment(const []), isEmpty);
    await repository.addTags(const [], ['t1']);
    await repository.addTags(['e1'], const []);
    await repository.removeTags(['e1'], const []);
    expect(await count('SELECT COUNT(*) AS n FROM equipment_tags'), 0);
  });

  test('deleteLinksForEquipment deletes and tombstones one item', () async {
    await repository.addTags(['e1', 'e2'], ['t1']);

    await repository.deleteLinksForEquipment('e1');

    expect(await tagIdsOf('e1'), isEmpty);
    expect(await tagIdsOf('e2'), {'t1'});
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log "
        "WHERE entity_type = 'equipmentTags'",
      ),
      1,
    );
  });

  test('watchChanges emits on a link change', () async {
    final emitted = <void>[];
    final sub = repository.watchChanges().listen(emitted.add);
    addTearDown(sub.cancel);

    await repository.addTags(['e1'], ['t1']);
    await pumpEventQueue();

    expect(emitted, isNotEmpty);
  });

  test('a large selection binds within SQLite\'s variable limit', () async {
    await tearDownTestDatabase();
    final db = setUpLoggingTestDatabase();
    repository = EquipmentTagRepository();
    final ids = [for (var i = 0; i < 1000; i++) 'e$i'];
    await quietly(() async {
      await db.customStatement(
        'WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n '
        'WHERE i < 999) '
        'INSERT INTO equipment (id, name, type, created_at, updated_at) '
        "SELECT 'e' || i, 'Item', 'bcd', 0, 0 FROM n",
      );
      await db.customStatement(
        "INSERT INTO tags (id, name, created_at, updated_at, "
        "applies_to_equipment) VALUES ('t1', 'Travel kit', 0, 0, 1)",
      );
    });

    final most = await maxBoundVariables(() async {
      await repository.addTags(ids, ['t1']);
      await repository.getTagIdsByEquipment(ids);
      await repository.tagCountsForEquipment(ids);
      await repository.removeTags(ids, ['t1']);
    });

    expect(most, lessThanOrEqualTo(sqliteVariableLimit));
  });
}
```

Create `test/features/equipment/data/repositories/equipment_repository_tags_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

/// Equipment save and delete never lose or strand tag links (issue #1942).
void main() {
  late AppDatabase db;
  late EquipmentRepository equipment;
  late EquipmentTagRepository tags;

  setUp(() async {
    db = await setUpTestDatabase();
    equipment = EquipmentRepository();
    tags = EquipmentTagRepository();
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 1, 1), ('e2', 'Fins', 'fins', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) "
      "VALUES ('t1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('t2', 'Rental', 0, 0, 0, 0, 1)",
    );
  });

  tearDown(tearDownTestDatabase);

  Future<List<String>> tombstonedLinks() async {
    final rows = await db.select(db.deletionLog).get();
    return [
      for (final r in rows)
        if (r.entityType == 'equipmentTags') r.recordId,
    ];
  }

  test('deleteEquipment tombstones its tag links', () async {
    await tags.addTags(['e1'], ['t1', 't2']);
    await tags.addTags(['e2'], ['t1']);
    final doomed = [
      for (final r in await db.select(db.equipmentTags).get())
        if (r.equipmentId == 'e1') r.id,
    ];

    await equipment.deleteEquipment('e1');

    final left = await db.select(db.equipmentTags).get();
    expect(left.map((r) => r.equipmentId), ['e2']);
    expect(await tombstonedLinks(), unorderedEquals(doomed));
  });

  test('updateEquipment with a partial entity leaves tags untouched', () async {
    await tags.replaceTags('e1', ['t1', 't2']);

    // A partially loaded item, as the dive-joined mappers build one.
    await equipment.updateEquipment(
      const EquipmentItem(id: 'e1', name: 'Renamed wing', type: EquipmentType.bcd),
    );

    expect(
      (await tags.getTagsForEquipment('e1')).map((t) => t.id).toSet(),
      {'t1', 't2'},
    );
    expect(await tombstonedLinks(), isEmpty);
  });
}
```

Create `test/features/equipment/presentation/providers/equipment_tag_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';

import '../../../../helpers/test_database.dart';

/// The equipment tag providers refresh on their own when a link changes,
/// including a change made outside any notifier (a sync or an import).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_equipment) VALUES ('t1', 'Travel kit', 0, 0, 1)",
    );
  });

  tearDown(tearDownTestDatabase);

  ProviderContainer makeContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  Future<T> pollUntil<T>(
    Future<T> Function() read,
    bool Function(T) settled,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    var value = await read();
    while (!settled(value) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      value = await read();
    }
    return value;
  }

  test('tagsForEquipmentProvider follows a link written elsewhere', () async {
    final c = makeContainer();
    final sub = c.listen(tagsForEquipmentProvider('e1'), (_, _) {});
    addTearDown(sub.close);
    expect(await c.read(tagsForEquipmentProvider('e1').future), isEmpty);

    await EquipmentTagRepository().replaceTags('e1', ['t1']);

    final tags = await pollUntil(
      () => c.read(tagsForEquipmentProvider('e1').future),
      (v) => v.isNotEmpty,
    );
    expect(tags.map((t) => t.name), ['Travel kit']);
  });

  test('tagsByEquipmentProvider follows a link written elsewhere', () async {
    final c = makeContainer();
    final sub = c.listen(tagsByEquipmentProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await c.read(tagsByEquipmentProvider.future), isEmpty);

    await EquipmentTagRepository().addTags(['e1'], ['t1']);

    final byItem = await pollUntil(
      () => c.read(tagsByEquipmentProvider.future),
      (v) => v.isNotEmpty,
    );
    expect(byItem['e1']!.single.id, 't1');
  });
}
```

- [ ] **Step 14: Run them and confirm they fail**

Run: `flutter test test/features/equipment/data/repositories/equipment_tag_repository_test.dart test/features/equipment/data/repositories/equipment_repository_tags_test.dart test/features/equipment/presentation/providers/equipment_tag_providers_test.dart`
Expected: FAIL to compile (`equipment_tag_repository.dart` and `equipment_tag_providers.dart` do not exist).

- [ ] **Step 15: The repository**

Create `lib/features/equipment/data/repositories/equipment_tag_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/tags/data/mappers/tag_row_mapper.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

/// Reads and writes an equipment item's tags (issue #1942): the
/// `equipment_tags` junction, the equipment twin of `site_tags`.
///
/// The links are clockless children of the item. A write marks only the
/// junction rows it inserts pending and tombstones the rows it deletes. It
/// never touches the `equipment` row, neither its `updated_at` nor a pending
/// mark: a stale whole-row equipment snapshot from a peer must not be able
/// to beat a newer edit to the same item (#1769).
///
/// Every insert is `DoNothing`-guarded: the (equipment, tag) unique index
/// makes an unguarded duplicate throw. Writers take `notify: false` when
/// they run inside a caller's transaction; the caller notifies once
/// afterwards.
class EquipmentTagRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  static const String _entityType = 'equipmentTags';

  /// Ids bound per `IN (...)` list: under SQLite's 999-variable floor, with
  /// room for the one tag id [removeTags] binds beside them.
  static const int _idChunk = 900;

  /// Emits when an item gains or loses a tag, or when a tag itself changes
  /// (a rename or a new color shows on every item carrying it).
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([_db.equipmentTags, _db.tags]),
  );

  /// [equipmentId]'s tags, by name.
  Future<List<domain.Tag>> getTagsForEquipment(String equipmentId) async {
    final rows = await _db
        .customSelect(
          'SELECT t.* FROM equipment_tags et JOIN tags t ON t.id = et.tag_id '
          'WHERE et.equipment_id = ? ORDER BY t.name',
          variables: [Variable.withString(equipmentId)],
          readsFrom: {_db.equipmentTags, _db.tags},
        )
        .get();
    return [for (final r in rows) mapTagRow(_db.tags.map(r.data))];
  }

  /// Every item's tags, by name, in one query. An item with no tags has no
  /// entry.
  Future<Map<String, List<domain.Tag>>> getTagsByEquipment() async {
    final rows = await _db
        .customSelect(
          'SELECT et.equipment_id AS link_equipment_id, t.* '
          'FROM equipment_tags et JOIN tags t ON t.id = et.tag_id '
          'ORDER BY et.equipment_id, t.name',
          readsFrom: {_db.equipmentTags, _db.tags},
        )
        .get();
    final byItem = <String, List<domain.Tag>>{};
    for (final r in rows) {
      byItem
          .putIfAbsent(r.read<String>('link_equipment_id'), () => [])
          .add(mapTagRow(_db.tags.map(r.data)));
    }
    return byItem;
  }

  /// Raw tag ids per item for [equipmentIds], oldest link first, for bulk
  /// edit snapshots and exports. An item with no tags has no entry.
  Future<Map<String, List<String>>> getTagIdsByEquipment(
    List<String> equipmentIds,
  ) async {
    final byItem = <String, List<String>>{};
    for (final chunk in _chunks(equipmentIds.toSet().toList())) {
      final rows =
          await (_db.select(_db.equipmentTags)
                ..where((t) => t.equipmentId.isIn(chunk))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.createdAt),
                  (t) => OrderingTerm.asc(t.id),
                ]))
              .get();
      for (final r in rows) {
        byItem.putIfAbsent(r.equipmentId, () => []).add(r.tagId);
      }
    }
    return byItem;
  }

  /// How many of [equipmentIds] carry each tag, keyed by tag id: the
  /// tri-state seed of the bulk tag editor. The unique index allows one row
  /// per (item, tag), so the per-chunk counts sum exactly.
  Future<Map<String, int>> tagCountsForEquipment(
    List<String> equipmentIds,
  ) async {
    final counts = <String, int>{};
    for (final chunk in _chunks(equipmentIds.toSet().toList())) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT tag_id, COUNT(*) AS n FROM equipment_tags '
            'WHERE equipment_id IN ($placeholders) GROUP BY tag_id',
            variables: [for (final id in chunk) Variable.withString(id)],
            readsFrom: {_db.equipmentTags},
          )
          .get();
      for (final r in rows) {
        final tagId = r.read<String>('tag_id');
        counts[tagId] = (counts[tagId] ?? 0) + r.read<int>('n');
      }
    }
    return counts;
  }

  /// Makes [equipmentId]'s tags exactly [tagIds]. A pair that stays keeps
  /// its row, so its id and clock survive the save.
  Future<void> replaceTags(
    String equipmentId,
    List<String> tagIds, {
    bool notify = true,
  }) async {
    await _db.transaction(() async {
      final wanted = tagIds.toSet();
      final existing = await (_db.select(
        _db.equipmentTags,
      )..where((t) => t.equipmentId.equals(equipmentId))).get();
      for (final row in existing) {
        if (wanted.contains(row.tagId)) continue;
        await (_db.delete(
          _db.equipmentTags,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: _entityType,
          recordId: row.id,
        );
      }
      final have = {for (final r in existing) r.tagId};
      await _insertTags(equipmentId, [
        for (final id in wanted)
          if (!have.contains(id)) id,
      ]);
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  /// Adds every tag in [tagIds] to every item in [equipmentIds]; never
  /// removes one. A pair that already exists is skipped.
  Future<void> addTags(
    List<String> equipmentIds,
    List<String> tagIds, {
    bool notify = true,
  }) async {
    final items = equipmentIds.toSet().toList();
    final tags = tagIds.toSet().toList();
    if (items.isEmpty || tags.isEmpty) return;
    await _db.transaction(() async {
      final have = <(String, String)>{};
      for (final chunk in _chunks(items)) {
        final rows = await (_db.select(
          _db.equipmentTags,
        )..where((t) => t.equipmentId.isIn(chunk))).get();
        for (final r in rows) {
          have.add((r.equipmentId, r.tagId));
        }
      }
      for (final item in items) {
        await _insertTags(item, [
          for (final tag in tags)
            if (!have.contains((item, tag))) tag,
        ]);
      }
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  /// Removes every tag in [tagIds] from every item in [equipmentIds],
  /// tombstoning each removed link. A pair that does not exist is ignored.
  Future<void> removeTags(
    List<String> equipmentIds,
    List<String> tagIds, {
    bool notify = true,
  }) async {
    final items = equipmentIds.toSet().toList();
    final tags = tagIds.toSet().toList();
    if (items.isEmpty || tags.isEmpty) return;
    await _db.transaction(() async {
      for (final tagId in tags) {
        for (final chunk in _chunks(items)) {
          final rows =
              await (_db.select(_db.equipmentTags)..where(
                    (t) => t.tagId.equals(tagId) & t.equipmentId.isIn(chunk),
                  ))
                  .get();
          if (rows.isEmpty) continue;
          await (_db.delete(_db.equipmentTags)..where(
                (t) => t.tagId.equals(tagId) & t.equipmentId.isIn(chunk),
              ))
              .go();
          for (final row in rows) {
            await _syncRepository.logDeletion(
              entityType: _entityType,
              recordId: row.id,
            );
          }
        }
      }
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  /// Deletes and tombstones every tag link of [equipmentId], for
  /// `EquipmentRepository.deleteEquipment`. SQLite's cascade would remove
  /// the rows as well, but a cascade writes no tombstone, so a peer would
  /// keep them. Runs inside the caller's transaction and does not notify.
  Future<void> deleteLinksForEquipment(String equipmentId) async {
    final rows = await (_db.select(
      _db.equipmentTags,
    )..where((t) => t.equipmentId.equals(equipmentId))).get();
    if (rows.isEmpty) return;
    await (_db.delete(
      _db.equipmentTags,
    )..where((t) => t.equipmentId.equals(equipmentId))).go();
    for (final row in rows) {
      await _syncRepository.logDeletion(
        entityType: _entityType,
        recordId: row.id,
      );
    }
  }

  /// Inserts in the given order: `created_at` is `now + index`, because the
  /// raw read order is `created_at, id` and a shared timestamp would leave
  /// the order to random uuids. A pair that raced in since the caller's read
  /// comes back null from the guarded insert and is not marked pending.
  Future<void> _insertTags(String equipmentId, List<String> tagIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < tagIds.length; i++) {
      final id = _uuid.v4();
      final inserted = await _db
          .into(_db.equipmentTags)
          .insertReturningOrNull(
            EquipmentTagsCompanion.insert(
              id: id,
              equipmentId: equipmentId,
              tagId: tagIds[i],
              createdAt: now + i,
            ),
            onConflict: DoNothing<$EquipmentTagsTable, EquipmentTag>(
              target: const [],
            ),
          );
      if (inserted == null) continue;
      await _syncRepository.markRecordPending(
        entityType: _entityType,
        recordId: id,
        localUpdatedAt: now,
      );
    }
  }

  static Iterable<List<String>> _chunks(List<String> ids) sync* {
    for (var i = 0; i < ids.length; i += _idChunk) {
      yield ids.sublist(
        i,
        i + _idChunk < ids.length ? i + _idChunk : ids.length,
      );
    }
  }
}
```

- [ ] **Step 16: Providers**

Create `lib/features/equipment/presentation/providers/equipment_tag_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The equipment tag junction (issue #1942).
final equipmentTagRepositoryProvider = Provider<EquipmentTagRepository>((ref) {
  return EquipmentTagRepository();
});

/// One item's tags, by name. Refreshes on any link or tag change, including
/// one a sync or an import applies without a notifier.
final tagsForEquipmentProvider = FutureProvider.family<List<Tag>, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(equipmentTagRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  return repository.getTagsForEquipment(equipmentId);
});

/// Every item's tags in one query, for the list tiles, the Tags column and
/// the tag filter.
final tagsByEquipmentProvider = FutureProvider<Map<String, List<Tag>>>((
  ref,
) async {
  final repository = ref.watch(equipmentTagRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  return repository.getTagsByEquipment();
});
```

- [ ] **Step 17: `deleteEquipment` tombstones the links**

In `lib/features/equipment/data/repositories/equipment_repository_impl.dart`,
add beside the other equipment repository imports (after line 12):

```dart
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
```

Replace the first four lines of `deleteEquipment`'s doc comment (lines 469-472):

```dart
  /// Delete equipment. Service schedules, service records, and assembly
  /// component rows are first-class synced children cascade-deleted by
  /// SQLite, but cascades emit no deletion-log entries, so each is
  /// tombstoned explicitly (mirrors EquipmentSetRepository.deleteSet).
```

with the following. Line 473 (`/// Cylinders linked to the item are cleared and staged for sync.`) stays.

```dart
  /// Delete equipment. Service schedules, service records, assembly
  /// component rows and tag links are first-class synced children
  /// cascade-deleted by SQLite, but cascades emit no deletion-log entries, so
  /// each is tombstoned explicitly (mirrors EquipmentSetRepository.deleteSet).
```

and replace line 519:

```dart
        await (_db.delete(_db.equipment)..where((t) => t.id.equals(id))).go();
```

with:

```dart
        // Tag links (issue #1942): deleted and tombstoned before the row, so
        // the cascade finds nothing and every peer drops them too.
        await EquipmentTagRepository().deleteLinksForEquipment(id);
        await (_db.delete(_db.equipment)..where((t) => t.id.equals(id))).go();
```

`updateEquipment` (lines 400-450) writes only the `equipment` row and its
attributes. It gets no tag code, and Step 13's partial-entity test pins that.

- [ ] **Step 18: Run everything this task touched**

Run: `flutter test test/features/equipment/data/repositories test/features/equipment/presentation/providers/equipment_tag_providers_test.dart test/features/tags test/l10n test/core/database/tag_scope_tables_test.dart test/core/database/tag_uniqueness_registry_test.dart test/core/database/migration_v219_equipment_tags_test.dart test/core/database/tag_uniqueness_equipment_tags_test.dart test/core/database/migration_v218_site_detail_sections_test.dart test/core/database/migration_v217_site_classification_test.dart test/core/database/tag_uniqueness_site_tags_test.dart test/core/database/migration_v149_tag_uniqueness_test.dart test/core/services/sync/sync_hlc_target_registration_test.dart test/core/services/sync/child_hlc_test.dart test/core/services/sync/site_classification_sync_test.dart test/core/services/sync/sync_tag_identity_test.dart`
Expected: PASS.
Then: `flutter test test/architecture/`
Expected: PASS (the new providers subscribe to `watchChanges()`).
Then: `flutter analyze`
Expected: No issues found.

- [ ] **Step 19: Commit**

```bash
dart format .
git add lib/core/database/database.dart lib/core/database/tag_uniqueness.dart lib/core/database/tag_scope_tables.dart lib/core/data/repositories/sync_repository.dart lib/features/tags/domain/entities/tag.dart lib/features/tags/data/mappers/tag_row_mapper.dart lib/features/tags/presentation/tag_scope_labels.dart lib/features/tags/presentation/widgets/tag_picker_sheet.dart lib/features/equipment/data/repositories/equipment_tag_repository.dart lib/features/equipment/data/repositories/equipment_repository_impl.dart lib/features/equipment/presentation/providers/equipment_tag_providers.dart lib/l10n/arb/app_en.arb lib/l10n/arb/app_ar.arb lib/l10n/arb/app_de.arb lib/l10n/arb/app_es.arb lib/l10n/arb/app_fr.arb lib/l10n/arb/app_he.arb lib/l10n/arb/app_hu.arb lib/l10n/arb/app_it.arb lib/l10n/arb/app_nl.arb lib/l10n/arb/app_pt.arb lib/l10n/arb/app_zh.arb lib/l10n/arb/app_localizations.dart lib/l10n/arb/app_localizations_ar.dart lib/l10n/arb/app_localizations_de.dart lib/l10n/arb/app_localizations_en.dart lib/l10n/arb/app_localizations_es.dart lib/l10n/arb/app_localizations_fr.dart lib/l10n/arb/app_localizations_he.dart lib/l10n/arb/app_localizations_hu.dart lib/l10n/arb/app_localizations_it.dart lib/l10n/arb/app_localizations_nl.dart lib/l10n/arb/app_localizations_pt.dart lib/l10n/arb/app_localizations_zh.dart test/core/database/tag_scope_tables_test.dart test/core/database/migration_v219_equipment_tags_test.dart test/core/database/tag_uniqueness_equipment_tags_test.dart test/core/database/migration_v218_site_detail_sections_test.dart test/features/tags/data/mappers/tag_row_mapper_test.dart test/features/tags/presentation/tag_scope_labels_test.dart test/features/tags/data/repositories/tag_scope_equipment_test.dart test/features/tags/presentation/widgets/tag_picker_sheet_test.dart test/features/tags/presentation/pages/tag_manage_page_equipment_scope_test.dart test/features/equipment/data/repositories/equipment_tag_repository_test.dart test/features/equipment/data/repositories/equipment_repository_tags_test.dart test/features/equipment/presentation/providers/equipment_tag_providers_test.dart
git status --short
git commit -m "feat(equipment): schema v219 and the equipment tag scope (#1942)" -m "Adds tags.applies_to_equipment (off for every existing tag), the equipment_tags junction with its (equipment_id, tag_id) unique index, and the equipment entry in the tag scope registry, so tag usage, statistics, merging, narrowing, the duplicate repair and the sync fold cover equipment links. Manage Tags gains the Use for equipment checkbox, the equipment count and the narrowing line, and the tag picker can list equipment tags by equipment use, with the four new strings translated into every locale. EquipmentTagRepository reads and writes the links as clockless children: inserts are DoNothing-guarded and marked pending, removals are tombstoned, and the equipment row is never touched. deleteEquipment tombstones an item's links before the cascade removes them."
```

`database.g.dart` is gitignored (`*.g.dart`; CI regenerates it), so it is not
staged. `git status --short` must show no other modified tracked file; one
that appears is a file this task changed without listing it, so stop and
account for it before committing.

---

### Task 4: Sync registration of `equipmentTags`

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart`, next to each `siteTags` site: `class SyncData` (field, constructor, `toJson`, `SyncData.fromJson`), `_baseTables`, `parentGatedChildEntities`, `parentGatedTables`, `_buildSyncData`, `fetchRecord`, a new `_applyEquipmentTagRecord` after `_applySiteTagRecord`, `upsertRecord`, `upsertRecords`, `recordIdsFor`, `_syncTableFor`, `deleteRecord`, a new `_exportEquipmentTags` after `_exportSiteTags`. Task 1a edited this file (two imports, `_applyTagRecord`, `_foldTagInto`), so every edit point is located by symbol; the main line numbers quoted in the steps (main 3387357b169) are hints only. `_applyTagRecord` and `_foldTagInto` are NOT edited: Task 1a made both registry-driven.
- Modify: `lib/core/services/sync/sync_service.dart` (merge order 1520; `entityHasUpdatedAt` 2356; `parentRefs` 2541-2544)
- Modify tests: `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart:150`, `test/core/services/sync/sync_parent_refs_completeness_test.dart:97`, `test/core/services/sync/sync_serializer_fetch_record_test.dart:116, 318-333`, `test/core/services/sync/conflict_reference_resolver_test.dart` (new test after line 81), `test/core/services/sync/sync_base_streaming_parity_test.dart` (seed after line 87)
- Test: `test/core/services/sync/equipment_tags_sync_test.dart`

**Interfaces:**
- Consumes (Task 3): table `equipmentTags` (`EquipmentTag`, `$EquipmentTagsTable`), `Tags.appliesToEquipment`, `SyncRepository.hlcTargets['equipmentTags']`, `EquipmentTagRepository`, `tagScopeTables` with `equipmentTagScopeTable`, the `tagScopesOf` equipment arm. (Task 1a) `_foldTagInto` / `_foldTagLinks` looping over `tagScopeTables`, and `_applyTagRecord` unioning `tagScopesOf(remote)` with every rival's and writing it through `tagScopeColumns`; together with Task 3's registry entry they already fold equipment links and keep the equipment scope.
- Produces: `SyncData.equipmentTags` (`List<Map<String, dynamic>>`, JSON key `equipmentTags`); `equipmentTags` accepted by `fetchRecord`, `fetchRecords`, `upsertRecord`, `upsertRecords`, `recordIdsFor`, `deleteRecord`, `deleteAllRecords`; a parent-gated clockless child of `equipment`; `SyncService.entityHasUpdatedAt['equipmentTags'] == false`; `SyncService.parentRefs['equipmentTags']`.

The entity mirrors `siteTags` exactly: a clockless child exported through its
parent's clock (`equipment.hlc` here), a pending link traveling on its own,
and an apply that is `DoNothing` and runs through `_withTagAlias`.

- [ ] **Step 1: Point the guard tests at the new entity**

`test/core/services/sync/sync_data_serializer_batch_coverage_test.dart`, after line 150 (`(type: 'siteTags', ...)`):

```dart
          (type: 'equipmentTags', table: db.equipmentTags.actualTableName),
```

`test/core/services/sync/sync_parent_refs_completeness_test.dart`, after line 97 (`'site_tags': 'siteTags',`):

```dart
    'equipment_tags': 'equipmentTags',
```

`test/core/services/sync/sync_serializer_fetch_record_test.dart`: after
`'siteTags',` in `simpleTypes` (line 116) add `'equipmentTags',`, and after
the `site classification` group (ends at line 333) add:

```dart
  group('SyncDataSerializer.deleteRecord for equipment tags', () {
    test('deletes an equipment_tags row by id', () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await seedMinimalRow('equipment_tags', 'row-1');
      expect(await serializer.fetchRecord('equipmentTags', 'row-1'), isNotNull);

      await serializer.deleteRecord('equipmentTags', 'row-1');
      expect(await serializer.fetchRecord('equipmentTags', 'row-1'), isNull);
    });
  });
```

`test/core/services/sync/conflict_reference_resolver_test.dart`, after the
`diveTags` test (ends at line 81):

```dart
  test('resolves both foreign keys of an equipmentTags junction row', () async {
    // No resolver code of its own: equipmentId and tagId are already mapped
    // targets (issue #1942).
    await serializer.upsertRecord('equipment', {
      'id': 'eq-1',
      'name': 'Wing',
      'type': 'bcd',
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    await seedTag('tag-1', 'Travel kit');

    final refs = await resolver.resolve('equipmentTags', {
      'id': 'junction-1',
      'equipmentId': 'eq-1',
      'tagId': 'tag-1',
      'createdAt': 1000,
    });

    expect(refs, hasLength(2));
    expect(refFor(refs, 'tagId').name, 'Travel kit');
    final item = refFor(refs, 'equipmentId');
    expect(item.targetType, 'equipment');
    expect(item.name, 'Wing');
  });
```

`test/core/services/sync/sync_base_streaming_parity_test.dart`, in
`_seedRichLibrary` after the `siteSpecies` upsert (ends at line 87):

```dart
  // An equipment tag link (issue #1942): a mergeOrder entry the in-memory
  // apply would drop if it were missing, failing the byte comparison.
  await serializer.upsertRecord('equipment', {
    'id': 'eq-1',
    'name': 'Wing',
    'type': 'bcd',
    'createdAt': 1000,
    'updatedAt': 1000,
  });
  await serializer.upsertRecord('tags', {
    'id': 'tag-gear',
    'name': 'Travel kit',
    'createdAt': 1000,
    'updatedAt': 1000,
    'appliesToDives': false,
    'appliesToSites': false,
    'appliesToEquipment': true,
  });
  await serializer.upsertRecord('equipmentTags', {
    'id': 'et-1',
    'equipmentId': 'eq-1',
    'tagId': 'tag-gear',
    'createdAt': 1000,
  });
```

- [ ] **Step 2: Write the failing sync test**

Create `test/core/services/sync/equipment_tags_sync_test.dart`:

```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Sync of equipment tag links (issue #1942): the `equipmentTags` entity,
/// the equipment twin of `siteTags`.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 1, 1), ('e2', 'Fins', 'fins', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) "
      "VALUES ('t1', 'Travel kit', 1, 1, 0, 0, 1)",
    );
  });

  tearDown(tearDownTestDatabase);

  Future<void> link(String id, String equipmentId, String tagId) =>
      db.customStatement(
        "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
        "VALUES ('$id', '$equipmentId', '$tagId', 1)",
      );

  Future<int> pending(String entityType) async {
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM sync_records '
          "WHERE entity_type = '$entityType'",
        )
        .getSingle();
    return row.read<int>('n');
  }

  Future<Tag> tagRow(String id) =>
      (db.select(db.tags)..where((t) => t.id.equals(id))).getSingle();

  test('a link round-trips through fetch, delete and upsert', () async {
    await link('et1', 'e1', 't1');
    final json = await serializer.fetchRecord('equipmentTags', 'et1');
    expect(json, isNotNull);
    expect(await serializer.recordIdsFor('equipmentTags'), contains('et1'));
    expect(
      (await serializer.fetchRecords('equipmentTags', ['et1', 'x'])).keys,
      ['et1'],
    );

    await serializer.deleteRecord('equipmentTags', 'et1');
    expect(await serializer.fetchRecord('equipmentTags', 'et1'), isNull);
    await serializer.upsertRecord('equipmentTags', json!);

    final rows = await db.select(db.equipmentTags).get();
    expect(rows.single.tagId, 't1');
  });

  test('links round-trip between two databases', () async {
    await link('et1', 'e1', 't1');
    final payload = await serializer.exportData(
      deviceId: 'dev-a',
      deletions: const [],
    );
    final decoded = SyncData.fromJson(
      jsonDecode(jsonEncode(payload.data.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.equipmentTags.map((r) => r['id']), ['et1']);

    // The serializer reads DatabaseService.instance.database, so point the
    // service at the receiving database for the apply. The tearDown closes
    // that one; this closes the sender.
    addTearDown(db.close);
    final receiver = AppDatabase(NativeDatabase.memory());
    DatabaseService.instance.resetForTesting();
    DatabaseService.instance.setTestDatabase(receiver);
    final applier = SyncDataSerializer();
    await applier.applyInDeferredFkTransaction(() async {
      await applier.upsertRecords('equipment', decoded.equipment);
      await applier.upsertRecords('tags', decoded.tags);
      await applier.upsertRecords('equipmentTags', decoded.equipmentTags);
    });

    final links = await receiver.select(receiver.equipmentTags).get();
    expect(links.map((l) => (l.id, l.equipmentId, l.tagId)), [
      ('et1', 'e1', 't1'),
    ]);
  });

  test('a duplicate pair from a peer applies without throwing', () async {
    await link('local', 'e1', 't1');

    await serializer.upsertRecords('equipmentTags', [
      {
        'id': 'peer',
        'equipmentId': 'e1',
        'tagId': 't1',
        'createdAt': 2,
        'hlc': null,
      },
    ]);
    await serializer.upsertRecord('equipmentTags', {
      'id': 'peer2',
      'equipmentId': 'e1',
      'tagId': 't1',
      'createdAt': 3,
      'hlc': null,
    });

    final rows = await db.select(db.equipmentTags).get();
    expect(rows.map((r) => r.id), ['local']);
  });

  test("applying a peer's link never marks the item pending", () async {
    await serializer.upsertRecord('equipmentTags', {
      'id': 'et1',
      'equipmentId': 'e1',
      'tagId': 't1',
      'createdAt': 2,
      'hlc': null,
    });

    expect(await pending('equipment'), 0);
    final item = await (db.select(
      db.equipment,
    )..where((t) => t.id.equals('e1'))).getSingle();
    expect(item.hlc, isNull);
    expect(item.updatedAt, 1);
  });

  test('a pending link travels without its item', () async {
    const itemHlc = '2026-08-01T00:00:00.000Z-0000-peer';
    await db.customStatement(
      "UPDATE equipment SET hlc = '$itemHlc' WHERE id = 'e1'",
    );
    await EquipmentTagRepository().addTags(['e1'], ['t1']);

    final changeset = await serializer.exportChangeset(
      deviceId: 'dev-a',
      hlcWatermark: itemHlc,
      deletions: const [],
    );

    expect(changeset.data.equipment, isEmpty, reason: 'the item did not change');
    expect(changeset.data.equipmentTags.map((r) => r['tagId']), ['t1']);
    expect(await pending('equipment'), 0);
  });

  test("an incremental changeset carries only changed items' links", () async {
    const oldHlc = '2026-07-01T00:00:00.000Z-0000-peer';
    const newHlc = '2026-08-01T00:00:00.000Z-0000-peer';
    await db.customStatement(
      "UPDATE equipment SET hlc = '$oldHlc' WHERE id = 'e1'",
    );
    await db.customStatement(
      "UPDATE equipment SET hlc = '$newHlc' WHERE id = 'e2'",
    );
    await link('tag-e1', 'e1', 't1');
    await link('tag-e2', 'e2', 't1');

    final changeset = await serializer.exportChangeset(
      deviceId: 'dev-a',
      hlcWatermark: oldHlc,
      deletions: const [],
    );

    expect(changeset.data.equipmentTags.map((r) => r['id']), ['tag-e2']);
  });

  test('links follow a tag folded into a same-name rival', () async {
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) "
      "VALUES ('aaa', 'Rental', 1, 1, 1, 0, 0)",
    );
    // A peer's tag of the same name folds into the local survivor 'aaa'.
    await serializer.upsertRecord('tags', {
      'id': 'zzz',
      'diverId': null,
      'name': 'rental',
      'color': null,
      'createdAt': 2,
      'updatedAt': 2,
      'hlc': null,
      'appliesToDives': false,
      'appliesToSites': false,
      'appliesToEquipment': true,
    });
    await serializer.upsertRecord('equipmentTags', {
      'id': 'et1',
      'equipmentId': 'e1',
      'tagId': 'zzz',
      'createdAt': 3,
      'hlc': null,
    });

    final links = await db.select(db.equipmentTags).get();
    expect(links.single.tagId, 'aaa');
    final tag = await tagRow('aaa');
    expect(tag.appliesToEquipment, isTrue, reason: 'the fold keeps every scope');
    expect(tag.appliesToDives, isTrue);
  });

  test('a local link on a folded tag is repointed to the survivor', () async {
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) "
      "VALUES ('zzz', 'Avoid', 1, 1, 0, 0, 1)",
    );
    await link('et1', 'e1', 'zzz');
    await SyncRepository().clearAllSyncRecords();

    // A peer's same-name tag with a lower id wins the fold. The fold repoints
    // the link before the survivor row is written, so this runs inside the
    // deferred-FK transaction every real merge uses.
    await serializer.applyInDeferredFkTransaction(
      () => serializer.upsertRecord('tags', {
        'id': 'aaa',
        'diverId': null,
        'name': 'avoid',
        'color': null,
        'createdAt': 2,
        'updatedAt': 2,
        'hlc': null,
        'appliesToDives': true,
        'appliesToSites': false,
        'appliesToEquipment': false,
      }),
    );

    final links = await db.select(db.equipmentTags).get();
    expect(links.map((l) => (l.id, l.tagId)), [('et1', 'aaa')]);
    expect((await tagRow('aaa')).appliesToEquipment, isTrue);
    expect(await pending('equipmentTags'), 1, reason: 'the moved link');
    expect(await pending('equipment'), 0);
  });

  test('a folded tag drops its link on an item the survivor tags', () async {
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) "
      "VALUES ('zzz', 'Avoid', 1, 1, 0, 0, 1)",
    );
    await link('local', 'e1', 'zzz');
    await serializer.applyInDeferredFkTransaction(() async {
      // The peer's link to its own tag lands first (FKs are deferred), so
      // when the tag folds, e1 already carries the survivor.
      await link('peer', 'e1', 'aaa');
      await serializer.upsertRecord('tags', {
        'id': 'aaa',
        'diverId': null,
        'name': 'avoid',
        'color': null,
        'createdAt': 2,
        'updatedAt': 2,
        'hlc': null,
        'appliesToDives': false,
        'appliesToSites': false,
        'appliesToEquipment': true,
      });
    });

    final links = await db.select(db.equipmentTags).get();
    expect(links.map((r) => (r.id, r.tagId)), [('peer', 'aaa')]);
  });

  test('a new tag from an older peer applies with the equipment scope off', () async {
    // Passes as soon as the column exists: _withSchemaDefaults (#858) fills
    // the omitted key with the column default. Pinned for the new column.
    await serializer.upsertRecord('tags', {
      'id': 't9',
      'diverId': null,
      'name': 'Night',
      'color': null,
      'createdAt': 1,
      'updatedAt': 1,
      'hlc': null,
      'appliesToDives': true,
      'appliesToSites': false,
    });

    final tag = await tagRow('t9');
    expect(tag.appliesToEquipment, isFalse);
    expect(tag.appliesToDives, isTrue);
  });

  group('older peers', () {
    late FakeCloudStorageProvider cloud;

    setUp(() => cloud = FakeCloudStorageProvider());

    SyncPayload payloadOf(SyncData data) {
      final checksum = sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString();
      return SyncPayload(
        version: syncFormatVersion,
        exportedAt: 9000,
        deviceId: 'peer-dev',
        checksum: checksum,
        data: data,
        deletions: const {},
      );
    }

    test(
      'a tag row with no applies_to_equipment key keeps the local scope',
      () async {
        await db.customStatement(
          "UPDATE tags SET hlc = '2026-01-01T00:00:00.000Z-0000-deva' "
          "WHERE id = 't1'",
        );

        // The peer renamed the tag on a v218 build: its row carries the dive
        // and site flags, no equipment flag, and a newer clock, so it wins.
        final olderPeerRow = <String, dynamic>{
          'id': 't1',
          'diverId': null,
          'name': 'Travel kit (carry-on)',
          'color': null,
          'createdAt': 1,
          'updatedAt': 9,
          'hlc': '2026-09-01T00:00:00.000Z-0000-devb',
          'appliesToDives': false,
          'appliesToSites': false,
        };
        await seedPeerBaseFromPayload(
          cloud,
          'peer-dev',
          payloadOf(SyncData(tags: [olderPeerRow])),
        );

        final result = await SyncService(
          syncRepository: SyncRepository(),
          serializer: SyncDataSerializer(),
          cloudProvider: cloud,
        ).performSync();
        expect(result.status, isNot(SyncResultStatus.error));

        final tag = await tagRow('t1');
        expect(tag.name, 'Travel kit (carry-on)');
        expect(tag.appliesToEquipment, isTrue);
      },
    );
  });
}
```

- [ ] **Step 3: Run them and confirm they fail**

Run: `flutter test test/core/services/sync/equipment_tags_sync_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_serializer_fetch_record_test.dart test/core/services/sync/conflict_reference_resolver_test.dart`
Expected: FAIL. `SyncData` has no `equipmentTags` getter (compile error in the
new file). The batch coverage test reports `fetchRecord(equipmentTags) after
seed` null. The parent refs test lists `equipmentTags.equipmentId -> equipment`
and `equipmentTags.tagId -> tags` as missing. The `equipment tags` deleteRecord
test gets null from `fetchRecord`. The conflict resolver test passes already:
`_defaultTargets` in `lib/core/services/sync/conflict_reference.dart` maps
`equipmentId` to `equipment` and `tagId` to `tags`, both with labels in
`conflict_reference_labels.dart`, so it is a pin.

- [ ] **Step 4: `SyncData`**

In `lib/core/services/sync/sync_data_serializer.dart`, next to each `siteTags` line. Every line number in Steps 4 to 6 is main's (3387357b169). Task 1a added two imports near the top of this file and reshaped `_applyTagRecord` and `_foldTagInto`, so every later line has moved: find each anchor by the quoted text or the named member, not by number.

In `class SyncData`:

after the field `final List<Map<String, dynamic>> siteTags;` (main line 327):

```dart
  final List<Map<String, dynamic>> equipmentTags;
```

in the constructor, after `this.siteTags = const [],` (main line 416):

```dart
    this.equipmentTags = const [],
```

in `toJson`, after `'siteTags': siteTags,` (main line 504):

```dart
    'equipmentTags': equipmentTags,
```

in `SyncData.fromJson`, after `siteTags: _parseList(json['siteTags']),` (main line 597):

```dart
      equipmentTags: _parseList(json['equipmentTags']),
```

`_baseTables` must list exactly the `toJson` keys in the same order
(`base_publish_streaming_parity_test.dart`: "_baseTables lists exactly the
SyncData entities in order"), so Step 5 puts it right after `siteTags` there as
well.

- [ ] **Step 5: Export**

`_baseTables`, after `(key: 'siteTags', table: _db.siteTags, blob: false, full: null),` (main line 1070):

```dart
    (
      key: 'equipmentTags',
      table: _db.equipmentTags,
      blob: false,
      full: null,
    ),
```

`parentGatedChildEntities`, after `'siteTags',` (main line 1445):

```dart
    'equipmentTags',
```

`parentGatedTables`, after `'siteTags': 'site_tags',` (main line 1499):

```dart
    'equipmentTags': 'equipment_tags',
```

`_buildSyncData`, after the `siteTags: await _safeExport('siteTags', ...)` argument (main lines 1984-1991):

```dart
      equipmentTags: await _safeExport(
        'equipmentTags',
        () async => _withPendingChildren(
          'equipmentTags',
          await _exportEquipmentTags(hlcSince),
          pendingChildren,
        ),
      ),
```

After the closing `}` of `_exportSiteTags` (main line 6955):

```dart
  /// Equipment tag links (v219, issue #1942), gated on the parent item's
  /// clock like [_exportSiteTags]. A changed link travels on its own pending
  /// mark, never by re-stamping the item.
  Future<List<Map<String, dynamic>>> _exportEquipmentTags(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final modifiedItems = await (_db.select(
        _db.equipment,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final itemIds = modifiedItems.map((e) => e.id).toSet();
      if (itemIds.isEmpty) return [];

      return _childRowsOf(
        itemIds,
        (chunk) => (_db.select(
          _db.equipmentTags,
        )..where((t) => t.equipmentId.isIn(chunk))).get(),
      );
    }
    final rows = await _db.select(_db.equipmentTags).get();
    return rows.map((r) => r.toJson()).toList();
  }
```

- [ ] **Step 6: Fetch, apply, lookups, delete**

`fetchRecord`, after its `case 'siteTags':` (main lines 2440-2444):

```dart
      case 'equipmentTags':
        final row = await (_db.select(
          _db.equipmentTags,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

`fetchRecords` needs no case: a parent-gated child goes through
`_fetchParentGatedChildren` (called from `fetchRecords` at main line 2619), which reads `parentGatedTables`.

After the closing `}` of `_applySiteTagRecord` (main line 3175):

```dart

  /// Applies one incoming `equipment_tags` row (v219, issue #1942), the
  /// equipment twin of [_applySiteTagRecord]: the (equipment, tag) unique
  /// index makes a peer's copy of a pair this device holds under another id
  /// a no-op instead of a throw.
  Future<void> _applyEquipmentTagRecord(EquipmentTag record) async {
    await _db
        .into(_db.equipmentTags)
        .insert(
          record,
          onConflict: DoNothing<$EquipmentTagsTable, EquipmentTag>(
            target: const [],
          ),
        );
  }
```

`upsertRecord`, after its `case 'siteTags':` (main lines 3560-3562):

```dart
      case 'equipmentTags':
        await _applyEquipmentTagRecord(
          EquipmentTag.fromJson(_withTagAlias(data)),
        );
        return;
```

`upsertRecords`, after its `case 'siteTags':` (main lines 4513-4521):

```dart
      case 'equipmentTags':
        await _db.batch(
          (b) => b.insertAll(
            _db.equipmentTags,
            records
                .map((r) => EquipmentTag.fromJson(_withTagAlias(r)))
                .toList(),
            onConflict: DoNothing<$EquipmentTagsTable, EquipmentTag>(
              target: const [],
            ),
          ),
        );
        return;
```

`recordIdsFor`, after its `case 'siteTags':` (main lines 4987-4988):

```dart
      case 'equipmentTags':
        return plain(_db.equipmentTags, _db.equipmentTags.id);
```

`_syncTableFor`, after its `case 'siteTags':` (main lines 5360-5361). This also
serves `deleteAllRecords`, whose fallback (main line 5159) deletes the whole table,
and `_withSchemaDefaults`:

```dart
      case 'equipmentTags':
        return _db.equipmentTags;
```

`deleteRecord`, after its `case 'siteTags':` (main lines 5766-5770):

```dart
      case 'equipmentTags':
        await (_db.delete(
          _db.equipmentTags,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

- [ ] **Step 7: The tag fold needs no code; confirm it is registry-driven**

Do not edit `_applyTagRecord`, `_foldTagInto` or `_foldTagLinks`. Task 1a
already made them registry-driven: `_foldTagInto` calls `_foldTagLinks` for
every entry of `tagScopeTables` (which moves or drops the loser's links in
each junction and marks each moved link pending under the entry's
`syncEntity`), and `_applyTagRecord` builds the survivor's scopes as the
union of `tagScopesOf(remote)` and every rival's `tagScopesOf`, written
through `tagScopeColumns`. With Task 3's `equipmentTagScopeTable` and its
`tagScopesOf` arm, a fold moves `equipment_tags` links and keeps
`applies_to_equipment`. Confirm the code is still in that shape:

Run: `grep -n "for (final junction in tagScopeTables)\|tagScopesOf(remote)\|tagScopeColumns(scopes)" lib/core/services/sync/sync_data_serializer.dart`
Expected: one `for (final junction in tagScopeTables)` line inside
`_foldTagInto`, one `...tagScopesOf(remote),` line and two
`tagScopeColumns(scopes)` lines inside `_applyTagRecord`.

Run: `grep -n "appliesToDives\|appliesToSites" lib/core/services/sync/sync_data_serializer.dart`
Expected: no output. If either check fails, Task 1a was not applied as
planned: stop and fix Task 1a rather than adding equipment code here.

The four fold tests in `equipment_tags_sync_test.dart` (`links follow a tag
folded into a same-name rival`, `a local link on a folded tag is repointed to
the survivor`, `a folded tag drops its link on an item the survivor tags`,
and the scope assertions in them) pin this. The older-peer rule needs no code
either: `SyncService._overlayOntoLocal` (`sync_service.dart`, `{...local,
...remote}`) refills an omitted `appliesToEquipment` from the local row when
the tag exists, and `_withSchemaDefaults` (#858) fills the column default
(`false`) before `Tag.fromJson` when it does not. The `older peers` group and
`a new tag from an older peer applies with the equipment scope off` pin both.

- [ ] **Step 8: `sync_service.dart`**

`sync_service.dart` is untouched by Tasks 1 to 3, so its line numbers are exact.

Merge order, after the `siteTags` entry (line 1520). This is after both
parents, `equipment` (earlier in the list) and `tags` (line 1420):

```dart
          // After both parents (equipment and tags), issue #1942.
          (
            type: 'equipmentTags',
            records: data.equipmentTags,
            hasUpdatedAt: false,
          ),
```

`entityHasUpdatedAt`, after `'siteTags': false,` (line 2356):

```dart
    'equipmentTags': false,
```

`parentRefs`, after the `siteTags` entry (lines 2541-2544):

```dart
    // v219: an equipment item's tags (issue #1942), the siteTags twin.
    'equipmentTags': [
      (field: 'equipmentId', parent: 'equipment', nullable: false),
      (field: 'tagId', parent: 'tags', nullable: false),
    ],
```

Conflict references need no change: `_defaultTargets` in
`conflict_reference.dart` already resolves `equipmentId` and `tagId`, with
labels (the resolver test added in Step 1 pins it).

- [ ] **Step 9: Run the sync tests**

Run: `flutter test test/core/services/sync/equipment_tags_sync_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_serializer_fetch_record_test.dart test/core/services/sync/conflict_reference_resolver_test.dart test/core/services/sync/sync_base_streaming_parity_test.dart test/core/services/sync/base_publish_streaming_parity_test.dart test/core/services/sync/sync_data_serializer_record_ids_test.dart test/core/services/sync/sync_hlc_target_registration_test.dart test/core/services/sync/child_hlc_test.dart test/core/services/sync/pending_child_export_test.dart test/core/services/sync/site_classification_sync_test.dart test/core/services/sync/sync_tag_identity_test.dart test/core/services/sync/cross_version_roundtrip_test.dart`
Expected: PASS. `sync_tag_identity_test.dart` and
`site_classification_sync_test.dart` prove the registry fold still keeps the
dive and site behavior with three entries.
Then: `flutter test test/architecture/`
Expected: PASS.
Then: `flutter analyze`
Expected: No issues found.

- [ ] **Step 10: Commit**

```bash
dart format .
git add lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart test/core/services/sync/equipment_tags_sync_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_serializer_fetch_record_test.dart test/core/services/sync/conflict_reference_resolver_test.dart test/core/services/sync/sync_base_streaming_parity_test.dart
git commit -m "feat(sync): sync equipment tag links (#1942)" -m "Registers equipmentTags as a clockless child of equipment: exported through the item's clock, a pending link travels on its own, and the apply is DoNothing through the tag alias map, so a duplicate pair from a peer is a no-op. New tests pin that the registry-driven tag fold moves equipment links to the surviving tag and keeps the equipment scope, and that a tag row from an older peer keeps the local equipment scope."
```

### Task 5: Equipment edit page Tags field + detail page chip row (no tap handler yet)

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (Task 3 changed this file: new methods go directly after `updateEquipment`, found by symbol; main's line was 456)
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart:428-444` (`EquipmentListNotifier.addEquipment`, `.updateEquipment`)
- Create: `lib/features/equipment/presentation/widgets/equipment_tags_field.dart`
- Create: `lib/features/equipment/presentation/widgets/equipment_tag_chips.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart` (imports 1-20; state fields after line 67; `_initializeFromEquipment` line 161; new `_loadTags`; form after Notes, lines 454-464; `_saveEquipment` lines 1009-1018)
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (imports 1-42; `_buildHeaderSection` lines 409-422)
- Modify: `lib/l10n/arb/app_en.arb` (after the `"equipment_edit_statusLabel"` line, main line 7145), the ten locale files `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb` (after each file's own `"equipment_edit_statusLabel"` line) and the regenerated `lib/l10n/arb/app_localizations*.dart`
- Test (create): `test/features/equipment/data/repositories/equipment_repository_tags_save_test.dart`
- Test (create): `test/features/equipment/presentation/pages/equipment_edit_tags_test.dart`
- Test (create): `test/features/equipment/presentation/widgets/equipment_tag_chips_test.dart`
- Test (create): `test/features/equipment/presentation/pages/equipment_detail_tags_test.dart`

**Interfaces:**
- Consumes (Task 1): `Tag.scopes`, `Tag.appliesTo(TagScope)`, `Tag(..., scopes: {...})`.
- Consumes (Task 3): `TagScope.equipment` with its arms in both `tag_picker_sheet.dart` switches (`_inScope` and the row subtitle), so `showTagPickerSheet(scope: TagScope.equipment)` lists equipment tags most used first and `TagInputWidget(scope: TagScope.equipment)` suggests only them; the `tags.applies_to_equipment` column; `EquipmentTagRepository()` (no constructor arguments, database read lazily) with `replaceTags(String equipmentId, List<String> tagIds, {bool notify = true})` and `getTagsForEquipment(String equipmentId)` (ordered by name); `tagsForEquipmentProvider` (`FutureProvider.family<List<Tag>, String>`) in `lib/features/equipment/presentation/providers/equipment_tag_providers.dart`, which invalidates itself on `watchChanges()`; the `equipment_tag_repository.dart` import Task 3's `deleteEquipment` step added to `equipment_repository_impl.dart`. Existing (main): `TagListNotifier.getOrCreateTag(name, scope:)`, which Task 1 and Task 3 route through the registry, so `scope: TagScope.equipment` creates an equipment tag or widens a same-named one.
- Produces:
  - `EquipmentRepository.createEquipmentWithTags(EquipmentItem equipment, List<String> tagIds) -> Future<EquipmentItem>`
  - `EquipmentRepository.updateEquipmentWithTags(EquipmentItem equipment, List<String> tagIds) -> Future<void>`
  - `EquipmentListNotifier.addEquipment(EquipmentItem equipment, {List<String>? tagIds})`, `EquipmentListNotifier.updateEquipment(EquipmentItem equipment, {List<String>? tagIds})`
  - `EquipmentTagsField({required List<Tag> selectedTags, required ValueChanged<List<Tag>> onTagsChanged, bool enabled = true})`
  - `EquipmentTagChips({required String equipmentId})` (plain `Chip`s; Task 6 adds the tap)
  - ARB key `equipment_edit_tagsLabel`

- [ ] **Step 1: Write the failing repository test**

Create `test/features/equipment/data/repositories/equipment_repository_tags_save_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

/// The edit page saves an item and its tags together (issue #1942).
void main() {
  late EquipmentRepository equipment;
  late EquipmentTagRepository tags;

  setUp(() async {
    await setUpTestDatabase();
    equipment = EquipmentRepository();
    tags = EquipmentTagRepository();
    await DatabaseService.instance.database.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites, applies_to_equipment) VALUES '
      "('t1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('t2', 'Rental', 0, 0, 0, 0, 1)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<List<String>> tagIdsOf(String equipmentId) async => [
    for (final t in await tags.getTagsForEquipment(equipmentId)) t.id,
  ];

  Future<int> linkCount() async {
    final row = await DatabaseService.instance.database
        .customSelect('SELECT COUNT(*) AS n FROM equipment_tags')
        .getSingle();
    return row.read<int>('n');
  }

  test('createEquipmentWithTags writes the row and its tags', () async {
    final item = await equipment.createEquipmentWithTags(
      const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.bcd),
      ['t2', 't1'],
    );

    expect((await equipment.getEquipmentById(item.id))!.name, 'Wing');
    // Read back by name.
    expect(await tagIdsOf(item.id), ['t2', 't1']);
  });

  test('a failing tag write leaves no new item behind', () async {
    await expectLater(
      equipment.createEquipmentWithTags(
        const EquipmentItem(id: 'fixed', name: 'Doomed', type: EquipmentType.bcd),
        // A tag id with no tags row violates the equipment_tags foreign key,
        // after 't1' has already been linked.
        ['t1', 'missing'],
      ),
      throwsA(anything),
    );

    expect(await equipment.getEquipmentById('fixed'), isNull);
    expect(await linkCount(), 0);
  });

  test('updateEquipmentWithTags replaces the set with the row', () async {
    final item = await equipment.createEquipmentWithTags(
      const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.bcd),
      ['t1'],
    );

    await equipment.updateEquipmentWithTags(
      item.copyWith(name: 'Wing renamed'),
      ['t2'],
    );

    expect((await equipment.getEquipmentById(item.id))!.name, 'Wing renamed');
    expect(await tagIdsOf(item.id), ['t2']);
  });

  test('a failing tag write on update keeps the old row and the old set', () async {
    final item = await equipment.createEquipmentWithTags(
      const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.bcd),
      ['t1'],
    );

    await expectLater(
      equipment.updateEquipmentWithTags(
        item.copyWith(name: 'Wing renamed'),
        ['t2', 'missing'],
      ),
      throwsA(anything),
    );

    expect((await equipment.getEquipmentById(item.id))!.name, 'Wing');
    expect(await tagIdsOf(item.id), ['t1']);
  });

  test('updateEquipment with a partial entity leaves the tags alone', () async {
    final item = await equipment.createEquipmentWithTags(
      const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.bcd),
      ['t1', 't2'],
    );

    // A partially built entity, as the dive-joined mappers produce.
    await equipment.updateEquipment(
      EquipmentItem(id: item.id, name: 'Wing', type: EquipmentType.bcd),
    );

    expect(await tagIdsOf(item.id), ['t2', 't1']);
  });
}
```

(`getTagsForEquipment` orders by tag name: "Rental" before "Travel kit".)

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/features/equipment/data/repositories/equipment_repository_tags_save_test.dart`
Expected: compile error, `The method 'createEquipmentWithTags' isn't defined for the type 'EquipmentRepository'`.

- [ ] **Step 3: Repository methods**

In `lib/features/equipment/data/repositories/equipment_repository_impl.dart`, the `equipment_tag_repository.dart` import is already there (Task 3 added it in its `deleteEquipment` step); do not add it again.

Insert directly after `updateEquipment`: after its closing `}` and before the `/// Splits a dying item's attachments` doc comment of `_cascadeMediaForEquipmentDeletion` (main line 456; Task 3's added import shifts it by one, so find it by symbol):

```dart
  /// Creates [equipment] and gives it exactly [tagIds] (issue #1942), in one
  /// transaction: a tag write that fails leaves no item behind, and the
  /// best-effort service clocks [createEquipment] seeds roll back with it.
  ///
  /// The tag links are clockless children of the item: only the junction
  /// rows are marked pending, never the row again (#1769).
  Future<EquipmentItem> createEquipmentWithTags(
    EquipmentItem equipment,
    List<String> tagIds,
  ) async {
    final created = await transaction(() async {
      final item = await createEquipment(equipment);
      await EquipmentTagRepository().replaceTags(
        item.id,
        tagIds,
        notify: false,
      );
      return item;
    });
    SyncEventBus.notifyLocalChange();
    return created;
  }

  /// Rewrites [equipment]'s row and makes its tags exactly [tagIds]
  /// (issue #1942), in one transaction. The edit page is the only caller:
  /// it holds the whole entity and the tags the diver saw. [updateEquipment]
  /// itself never touches tags, because partially built entities reach it.
  Future<void> updateEquipmentWithTags(
    EquipmentItem equipment,
    List<String> tagIds,
  ) async {
    await transaction(() async {
      await updateEquipment(equipment);
      await EquipmentTagRepository().replaceTags(
        equipment.id,
        tagIds,
        notify: false,
      );
    });
    SyncEventBus.notifyLocalChange();
  }
```

`EquipmentTagRepository` reads `DatabaseService.instance.database` per call (as `ServiceScheduleRepository()` does, used inline in `createEquipment`), so constructing it inline is fine. Drift runs the nested `_db.transaction` inside `replaceTags` as a savepoint of the outer one.

Run: `flutter test test/features/equipment/data/repositories/equipment_repository_tags_save_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 4: Notifier**

In `lib/features/equipment/presentation/providers/equipment_providers.dart`, replace `addEquipment` and `updateEquipment` (lines 428-444):

```dart
  /// [tagIds], when given, become the new item's tags in the same
  /// transaction as its row (issue #1942).
  Future<EquipmentItem> addEquipment(
    EquipmentItem equipment, {
    List<String>? tagIds,
  }) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Always set diverId to the current validated diver for new items
    final equipmentWithDiver = validatedId != null
        ? equipment.copyWith(diverId: validatedId)
        : equipment;
    final newEquipment = tagIds == null
        ? await _repository.createEquipment(equipmentWithDiver)
        : await _repository.createEquipmentWithTags(
            equipmentWithDiver,
            tagIds,
          );
    await refresh();
    return newEquipment;
  }

  /// [tagIds], when given, replace the item's tags in the same transaction
  /// as its row (issue #1942). Null leaves the tags as they are.
  Future<void> updateEquipment(
    EquipmentItem equipment, {
    List<String>? tagIds,
  }) async {
    if (tagIds == null) {
      await _repository.updateEquipment(equipment);
    } else {
      await _repository.updateEquipmentWithTags(equipment, tagIds);
    }
    await refresh();
  }
```

- [ ] **Step 5: English string**

In `lib/l10n/arb/app_en.arb`, insert after `"equipment_edit_statusLabel": "Status",` (main line 7145; the file is grouped by feature, not alphabetical, so anchor on that key):

```json
  "equipment_edit_tagsLabel": "Tags",
```

- [ ] **Step 5b: Translations (all ten locales)**

In each locale file, insert the one line below, indented two spaces like its neighbours, directly after that file's own `"equipment_edit_statusLabel": ...,` line (in every locale it is followed by `"equipment_edit_parentLabel"`). The word is the locale's Manage Tags word (`tags_manage_title`, also used by the site edit page's `diveSites_edit_typeTags_tagsLabel`), so all equipment tag strings say "tags" the same way.

| File | Line to insert |
| --- | --- |
| `lib/l10n/arb/app_ar.arb` | `"equipment_edit_tagsLabel": "الوسوم",` |
| `lib/l10n/arb/app_de.arb` | `"equipment_edit_tagsLabel": "Tags",` |
| `lib/l10n/arb/app_es.arb` | `"equipment_edit_tagsLabel": "Etiquetas",` |
| `lib/l10n/arb/app_fr.arb` | `"equipment_edit_tagsLabel": "Étiquettes",` |
| `lib/l10n/arb/app_he.arb` | `"equipment_edit_tagsLabel": "תגיות",` |
| `lib/l10n/arb/app_hu.arb` | `"equipment_edit_tagsLabel": "Címkék",` |
| `lib/l10n/arb/app_it.arb` | `"equipment_edit_tagsLabel": "Tag",` |
| `lib/l10n/arb/app_nl.arb` | `"equipment_edit_tagsLabel": "Tags",` |
| `lib/l10n/arb/app_pt.arb` | `"equipment_edit_tagsLabel": "Etiquetas",` |
| `lib/l10n/arb/app_zh.arb` | `"equipment_edit_tagsLabel": "标签",` |

(de and nl use the English word "Tags" on purpose: it is their existing term, as in `tags_manage_title`.)

Run: `flutter gen-l10n`
Expected: completes; `lib/l10n/arb/app_localizations.dart` and the eleven `app_localizations_<locale>.dart` files gain `equipment_edit_tagsLabel`.

Run: `flutter test test/l10n/`
Expected: PASS (`arb_parity_test.dart` finds the key in all ten locales).

- [ ] **Step 6: Write the failing widget tests**

Create `test/features/equipment/presentation/widgets/equipment_tag_chips_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_tag_chips.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_app.dart';

/// The tag chip row on equipment detail (issue #1942).
void main() {
  final now = DateTime(2026);
  Tag tag(String id, String name) => Tag(
    id: id,
    name: name,
    colorHex: '#4CAF50',
    createdAt: now,
    updatedAt: now,
    scopes: const {TagScope.equipment},
  );
  final travel = tag('t1', 'Travel kit');
  final rental = tag('t2', 'Rental');

  Widget wrap(List<Tag> tags) => testApp(
    locale: const Locale('en'),
    overrides: [
      tagsForEquipmentProvider('e1').overrideWith((ref) async => tags),
    ],
    child: const EquipmentTagChips(equipmentId: 'e1'),
  );

  testWidgets('shows a chip per tag', (tester) async {
    await tester.pumpWidget(wrap([rental, travel]));
    await tester.pumpAndSettle();

    expect(find.text('Rental'), findsOneWidget);
    expect(find.text('Travel kit'), findsOneWidget);
  });

  testWidgets('renders nothing for an item without tags', (tester) async {
    await tester.pumpWidget(wrap(const []));
    await tester.pumpAndSettle();

    expect(find.byType(Wrap), findsNothing);
  });
}
```

Create `test/features/equipment/presentation/pages/equipment_detail_tags_test.dart` (harness copied from `equipment_detail_installed_in_test.dart:83-156`, which overrides every per-item provider the page reads):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_exposure_totals.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_trend_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_tag_chips.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _MockServiceRecordNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Tags in the equipment detail header (issue #1942).
void main() {
  late String? savedIntlLocale;
  setUp(() {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntlLocale);

  const id = 'wing';
  const wing = EquipmentItem(id: id, name: 'Wing', type: EquipmentType.bcd);
  final now = DateTime(2026);
  Tag tag(String tagId, String name) => Tag(
    id: tagId,
    name: name,
    colorHex: '#4CAF50',
    createdAt: now,
    updatedAt: now,
    scopes: const {TagScope.equipment},
  );

  Future<void> pump(WidgetTester tester, List<Tag> tags) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 2400);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/equipment/$id',
      routes: [
        GoRoute(
          path: '/equipment/:id',
          builder: (context, state) => const EquipmentDetailPage(equipmentId: id),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentItemProvider(id).overrideWith((ref) async => wing),
          equipmentDiveCountProvider(id).overrideWith((ref) async => 0),
          equipmentTripCountProvider(id).overrideWith((ref) async => 0),
          serviceRecordNotifierProvider(
            id,
          ).overrideWith((ref) => _MockServiceRecordNotifier()),
          serviceClockStatusesProvider(id).overrideWith((ref) async => const []),
          equipmentComponentsProvider(id).overrideWith((ref) async => const []),
          equipmentExposureTotalsProvider(
            id,
          ).overrideWith((ref) async => EquipmentExposureTotals.empty),
          equipmentConditionProvider(id).overrideWith((ref) async => const []),
          conditionTrendProvider((
            equipmentId: id,
            kind: null,
          )).overrideWith((ref) async => null),
          conditionTrendProvider((
            equipmentId: id,
            kind: ConditionTrendKind.scrubberMinutes,
          )).overrideWith((ref) async => null),
          childEquipmentProvider(id).overrideWith((ref) async => const []),
          observationsForEquipmentProvider(
            id,
          ).overrideWith((ref) async => const []),
          equipmentWorstClockProvider.overrideWith((ref) async => {}),
          equipmentRollupClockProvider.overrideWith((ref) async => {}),
          tagsForEquipmentProvider(id).overrideWith((ref) async => tags),
        ].cast(),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the header shows the tags under the name', (tester) async {
    await pump(tester, [tag('t2', 'Rental'), tag('t1', 'Travel kit')]);

    final header = find.byType(Card).first;
    final name = find.descendant(of: header, matching: find.text('Wing'));
    final chip = find.descendant(of: header, matching: find.text('Travel kit'));
    expect(chip, findsOneWidget);
    expect(
      find.descendant(of: header, matching: find.text('Rental')),
      findsOneWidget,
    );
    expect(tester.getTopLeft(chip).dy, greaterThan(tester.getTopLeft(name).dy));
  });

  testWidgets('an item without tags shows no tag row', (tester) async {
    await pump(tester, const []);

    expect(find.byType(EquipmentTagChips), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(EquipmentTagChips),
        matching: find.byType(Wrap),
      ),
      findsNothing,
    );
  });
}
```

Create `test/features/equipment/presentation/pages/equipment_edit_tags_test.dart` (harness from `equipment_edit_parent_picker_test.dart:20-60`: a real in-memory database plus `getBaseOverrides()`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The Tags field on the equipment edit page (issue #1942).
void main() {
  late EquipmentRepository repository;
  late EquipmentTagRepository tagRepository;

  setUp(() async {
    await setUpTestDatabase();
    repository = EquipmentRepository();
    tagRepository = EquipmentTagRepository();
    await DatabaseService.instance.database.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites, applies_to_equipment) VALUES '
      "('t1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('d1', 'Night', 0, 0, 1, 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpEditor(WidgetTester tester, String? equipmentId) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 4000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentRepositoryProvider.overrideWithValue(repository),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentEditPage(equipmentId: equipmentId, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final tagField = find.descendant(
    of: find.byType(TagInputWidget),
    matching: find.byType(TextField),
  );

  testWidgets('the Tags field follows Notes and shows the stored tags', (
    tester,
  ) async {
    final item = await repository.createEquipment(
      const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.bcd),
    );
    await tagRepository.replaceTags(item.id, ['t1']);

    await pumpEditor(tester, item.id);

    expect(find.text('Tags'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Tags')).dy,
      greaterThan(tester.getTopLeft(find.text('Notes')).dy),
    );
    expect(find.widgetWithText(Chip, 'Travel kit'), findsOneWidget);
  });

  testWidgets('removing a tag and saving writes the new set', (tester) async {
    final item = await repository.createEquipment(
      const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.bcd),
    );
    await tagRepository.replaceTags(item.id, ['t1']);
    await pumpEditor(tester, item.id);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(Chip, 'Travel kit'),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(await tagRepository.getTagsForEquipment(item.id), isEmpty);
  });

  testWidgets('suggestions list equipment tags only', (tester) async {
    await pumpEditor(tester, null);

    await tester.enterText(tagField, 'i');
    await tester.pumpAndSettle();

    expect(find.text('Travel kit'), findsOneWidget);
    expect(find.text('Night'), findsNothing);
  });

  testWidgets('a tag typed on a new item applies to equipment and is saved '
      'with it', (tester) async {
    await pumpEditor(tester, null);
    await tester.enterText(find.byType(TextFormField).first, 'Wing');
    await tester.enterText(tagField, 'Rental');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'Rental'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await repository.getAllEquipment()).single;
    final tags = await tagRepository.getTagsForEquipment(saved.id);
    expect(tags.single.name, 'Rental');
    expect(tags.single.appliesTo(TagScope.equipment), isTrue);
    expect(tags.single.appliesTo(TagScope.dives), isFalse);
  });
}
```

(The parent picker test already awaits repository reads after `pumpAndSettle` without `runAsync`, so the same shape holds here.)

- [ ] **Step 7: Run them and confirm they fail**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_tag_chips_test.dart`
Expected: compile error, `Target of URI doesn't exist: 'package:submersion/features/equipment/presentation/widgets/equipment_tag_chips.dart'`.

Run: `flutter test test/features/equipment/presentation/pages/equipment_edit_tags_test.dart`
Expected: FAIL, `Expected: exactly one matching candidate ... Found 0 widgets with text "Tags"` (and no `TagInputWidget` for the later tests).

- [ ] **Step 8: `EquipmentTagsField`**

Create `lib/features/equipment/presentation/widgets/equipment_tags_field.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Tags field on the equipment edit page (issue #1942): the tag input
/// plus a Browse button, both limited to equipment tags. A tag created here
/// applies to equipment; a name already used by a dive or site tag widens
/// that tag instead of creating a second one.
class EquipmentTagsField extends StatelessWidget {
  const EquipmentTagsField({
    super.key,
    required this.selectedTags,
    required this.onTagsChanged,
    this.enabled = true,
  });

  final List<Tag> selectedTags;
  final ValueChanged<List<Tag>> onTagsChanged;

  /// False when the stored tags could not be read. Editing then would save
  /// a set built without them, dropping them.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.sell_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.equipment_edit_tagsLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            // The same picker the dive and site pages open, listing the
            // diver's equipment tags most used first.
            TextButton.icon(
              key: const ValueKey('equipment_edit_tags_browse'),
              onPressed: enabled
                  ? () => showTagPickerSheet(
                      context,
                      selected: selectedTags,
                      onPicked: onTagsChanged,
                      scope: TagScope.equipment,
                    )
                  : null,
              icon: const Icon(Icons.label_outline, size: 18),
              label: Text(l10n.tags_action_browse),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TagInputWidget(
          selectedTags: selectedTags,
          onTagsChanged: onTagsChanged,
          enabled: enabled,
          scope: TagScope.equipment,
        ),
      ],
    );
  }
}
```

- [ ] **Step 9: Wire the edit page**

In `lib/features/equipment/presentation/pages/equipment_edit_page.dart`:

Imports: after `import 'package:flutter/material.dart';` (line 1) add

```dart
import 'package:flutter/foundation.dart' show setEquals;
```

and next to the other `submersion` imports add

```dart
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_tags_field.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
```

(`material.dart` re-exports only `Brightness` and `UniqueKey` from foundation, so the `setEquals` import is needed.)

State: after `List<int> _customReminderDays = [7, 14, 30];` (line 67) add

```dart

  /// The item's tags on this form (issue #1942) and the stored set a save
  /// compares against. Tags live beside the entity, not on it, so they load
  /// on their own.
  List<Tag> _selectedTags = [];
  Set<String> _originalTagIds = {};

  /// Set once the diver edits the tags, so a load that lands late does not
  /// replace a pick made before it.
  bool _tagsTouched = false;

  /// Set when the stored tags could not be read; the field is disabled so a
  /// save cannot drop them.
  bool _tagsLoadFailed = false;

  static final _log = LoggerService.forClass(EquipmentEditPage);
```

In `_initializeFromEquipment`, after `_customReminderDays = equipment.customReminderDays ?? const [7, 14, 30];` (line 161) add

```dart
    _loadTags(equipment.id);
```

Add the loader right after `_initializeFromEquipment` (after its closing `}`, before `void _handleCancel()`):

```dart
  /// Loads the item's tags into the Tags field (issue #1942). The stored set
  /// always becomes the baseline a save compares against, but it fills the
  /// field only if the diver has not edited it yet.
  Future<void> _loadTags(String equipmentId) async {
    // Called from build: yield before the first provider read, which
    // riverpod rejects while the tree is building (as media_item_view does).
    await null;
    if (!mounted) return;
    try {
      final tags = await ref.read(
        tagsForEquipmentProvider(equipmentId).future,
      );
      if (!mounted) return;
      setState(() {
        _originalTagIds = {for (final t in tags) t.id};
        if (!_tagsTouched) _selectedTags = tags;
      });
    } catch (e, stackTrace) {
      _log.error(
        'Could not load the tags of equipment $equipmentId',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _tagsLoadFailed = true);
    }
  }
```

Form: the Notes block (lines 454-464) reads

```dart
          // Notes
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: context.l10n.equipment_edit_notesLabel,
              prefixIcon: const Icon(Icons.notes),
              hintText: context.l10n.equipment_edit_notesHint,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
```

Insert directly after that `const SizedBox(height: 24),` and before `// Advanced (buoyancy metadata for weight prediction)`:

```dart
          // Tags (issue #1942), directly after Notes.
          EquipmentTagsField(
            selectedTags: _selectedTags,
            enabled: !_tagsLoadFailed,
            onTagsChanged: (tags) => setState(() {
              _selectedTags = tags;
              _tagsTouched = true;
              _hasChanges = true;
            }),
          ),
          const SizedBox(height: 24),
```

Save: in `_saveEquipment`, replace lines 1009-1018:

```dart
      final notifier = ref.read(equipmentListNotifierProvider.notifier);
      String savedId;

      if (widget.isEditing) {
        await notifier.updateEquipment(equipment);
        ref.invalidate(equipmentItemProvider(widget.equipmentId!));
        savedId = widget.equipmentId!;
      } else {
        final newEquipment = await notifier.addEquipment(equipment);
        savedId = newEquipment.id;
      }
```

with

```dart
      final notifier = ref.read(equipmentListNotifierProvider.notifier);
      String savedId;

      // Tags (issue #1942) are written with the row, in one transaction,
      // only when they differ from what the form loaded; a new item writes
      // them when it has any.
      final tagIds = [for (final t in _selectedTags) t.id];
      final tagsChanged = widget.isEditing
          ? !_tagsLoadFailed && !setEquals(tagIds.toSet(), _originalTagIds)
          : tagIds.isNotEmpty;

      if (widget.isEditing) {
        await notifier.updateEquipment(
          equipment,
          tagIds: tagsChanged ? tagIds : null,
        );
        ref.invalidate(equipmentItemProvider(widget.equipmentId!));
        savedId = widget.equipmentId!;
      } else {
        final newEquipment = await notifier.addEquipment(
          equipment,
          tagIds: tagsChanged ? tagIds : null,
        );
        savedId = newEquipment.id;
      }
```

(`tagsForEquipmentProvider` invalidates itself on `EquipmentTagRepository.watchChanges()`, so no manual invalidation is needed after the save.)

- [ ] **Step 10: `EquipmentTagChips` and the detail header**

Create `lib/features/equipment/presentation/widgets/equipment_tag_chips.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';

/// An equipment item's tags as colored chips, under the name in the detail
/// page header (issue #1942), styled like the tag chips on dive and site
/// detail. Renders nothing for an item without tags, so the header keeps
/// its height.
class EquipmentTagChips extends ConsumerWidget {
  const EquipmentTagChips({super.key, required this.equipmentId});

  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags =
        ref.watch(tagsForEquipmentProvider(equipmentId)).value ?? const [];
    if (tags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in tags)
            Chip(
              label: Text(tag.name),
              backgroundColor: tag.color.withValues(alpha: 0.2),
              side: BorderSide(color: tag.color),
              labelStyle: TextStyle(color: tag.color),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
```

In `lib/features/equipment/presentation/pages/equipment_detail_page.dart`, add the import beside the other `equipment/presentation/widgets` imports (lines 34-42):

```dart
import 'package:submersion/features/equipment/presentation/widgets/equipment_tag_chips.dart';
```

In `_buildHeaderSection`, the header's text column ends with the Retired chip (lines 409-422):

```dart
                      if (!equipment.isActive)
                        Chip(
                          label: Text(
                            context.l10n.equipment_detail_retiredChip,
                          ),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
```

Insert one line before that closing `],` so it becomes the column's last child:

```dart
                      // Tags (issue #1942), under the name and type.
                      EquipmentTagChips(equipmentId: equipment.id),
```

- [ ] **Step 11: Run the new tests**

Run each (one at a time):
- `flutter test test/features/equipment/data/repositories/equipment_repository_tags_save_test.dart`
- `flutter test test/features/equipment/presentation/widgets/equipment_tag_chips_test.dart`
- `flutter test test/features/equipment/presentation/pages/equipment_detail_tags_test.dart`
- `flutter test test/features/equipment/presentation/pages/equipment_edit_tags_test.dart`

Expected: PASS.

- [ ] **Step 12: Run every consumer of the changed pages and the architecture guards**

The edit page now holds a `TagInputWidget` (which watches `tagListNotifierProvider`) and reads `tagsForEquipmentProvider`; the detail page watches `tagsForEquipmentProvider` through `EquipmentTagChips`. Files that pump them (`grep -rln "EquipmentEditPage\|EquipmentDetailPage" test`):
- `test/features/equipment/presentation/equipment_edit_advanced_test.dart` (database)
- `test/features/equipment/presentation/equipment_edit_price_locale_test.dart` (database)
- `test/features/equipment/presentation/pages/equipment_edit_parent_picker_test.dart` (database)
- `test/features/equipment/presentation/pages/equipment_edit_service_section_test.dart` (database)
- `test/features/equipment/presentation/pages/equipment_detail_page_test.dart` (no database)
- `test/features/equipment/presentation/pages/equipment_detail_installed_in_test.dart` (no database)
- `test/features/equipment/presentation/pages/equipment_detail_rollup_test.dart` (no database)
- `test/features/equipment/presentation/pages/equipment_detail_service_test.dart` (no database)
- `test/features/equipment/presentation/pages/equipment_service_currency_test.dart` (no database)

In the no-database harnesses the tag provider fails with `StateError('Database not initialized...')`; riverpod does not retry an `Error` (`ProviderContainer.defaultRetry`), and `EquipmentTagChips` reads `.value`, so the row renders nothing. If one of them fails anyway, add `tagsForEquipmentProvider(<id>).overrideWith((ref) async => const [])` to that harness.

Run: `flutter test test/features/equipment`
Expected: PASS.

Run: `flutter test test/l10n/`
Expected: PASS.

Run: `flutter test test/architecture/`
Expected: PASS.

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 13: Commit**

```bash
dart format .
git add lib/features/equipment/data/repositories/equipment_repository_impl.dart \
  lib/features/equipment/presentation/providers/equipment_providers.dart \
  lib/features/equipment/presentation/widgets/equipment_tags_field.dart \
  lib/features/equipment/presentation/widgets/equipment_tag_chips.dart \
  lib/features/equipment/presentation/pages/equipment_edit_page.dart \
  lib/features/equipment/presentation/pages/equipment_detail_page.dart \
  lib/l10n/arb/app_en.arb lib/l10n/arb/app_ar.arb lib/l10n/arb/app_de.arb \
  lib/l10n/arb/app_es.arb lib/l10n/arb/app_fr.arb lib/l10n/arb/app_he.arb \
  lib/l10n/arb/app_hu.arb lib/l10n/arb/app_it.arb lib/l10n/arb/app_nl.arb \
  lib/l10n/arb/app_pt.arb lib/l10n/arb/app_zh.arb lib/l10n/arb/app_localizations*.dart \
  test/features/equipment/data/repositories/equipment_repository_tags_save_test.dart \
  test/features/equipment/presentation/pages/equipment_edit_tags_test.dart \
  test/features/equipment/presentation/pages/equipment_detail_tags_test.dart \
  test/features/equipment/presentation/widgets/equipment_tag_chips_test.dart
git commit -m "feat(equipment): edit equipment tags and show them on the detail page (#1942)" \
  -m "The edit page gains a Tags field after Notes, limited to equipment tags, with the shared tag picker. A save writes the item row and its tags in one transaction, so a failed tag write leaves neither. The detail header shows the item's tags under its name. The new label is translated into all ten locales."
```

(If `dart format .` touched files outside this task, stage only the paths above.)

---

### Task 6: List tile chips, EquipmentField.tags, filter, search, openEquipmentWithTag + detail chip tap

**Files:**
- Modify: `lib/features/equipment/domain/models/equipment_filter_state.dart` (whole class, lines 20-116)
- Modify: `lib/features/equipment/domain/constants/equipment_field.dart` (enum members 18-45; every switch getter 47-253; adapter 256-354)
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (imports 1-46; `build` 234-311; `_buildTableView` 637-653; `_buildActiveFiltersBar` 788-857; `_buildEquipmentList` 870-950; `_buildEmptyState` 962-1010; `EquipmentListTile` 1055-1150)
- Modify: `lib/features/equipment/presentation/widgets/equipment_filter_sheet.dart` (imports 1-11; state 41-56; section list 111-117; `_clearAll` 263-271; `_applyFilters` 273-285)
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (`searchEquipment`, found by symbol: Tasks 3 and 5 changed this file; main's lines were 758-783)
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart` (imports; `equipmentSearchProvider`, found by symbol: Task 5 changed this file; main's lines were 348-359)
- Create: `lib/features/equipment/presentation/equipment_tag_navigation.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_tag_chips.dart` (Task 5's file: `Chip` becomes `ActionChip`)
- Modify: `lib/l10n/arb/app_en.arb`, the ten locale files `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb` (each key beside the same neighbour key as in English) and the regenerated `lib/l10n/arb/app_localizations*.dart`
- Test (modify): `test/features/equipment/domain/models/equipment_filter_state_test.dart:61,67,140`
- Test (modify): `test/features/equipment/domain/constants/equipment_field_test.dart:57-60` and the "all fields except notes are sortable" test (~line 623)
- Test (modify): `test/features/equipment/presentation/widgets/equipment_tag_chips_test.dart` (Task 5's file)
- Test (create): `test/features/equipment/domain/models/equipment_filter_state_tags_test.dart`
- Test (create): `test/features/equipment/data/repositories/equipment_search_tags_test.dart`
- Test (create): `test/features/equipment/data/repositories/equipment_list_tags_statement_count_test.dart`
- Test (create): `test/features/equipment/presentation/widgets/equipment_list_tags_test.dart`
- Test (create): `test/features/equipment/presentation/widgets/equipment_filter_sheet_tags_test.dart`

**Interfaces:**
- Consumes (Task 1): `Tag.scopes`, `Tag.appliesTo(TagScope)`. (Task 3): `TagScope.equipment`, `tags.applies_to_equipment`, `equipment_tags`, `EquipmentTagRepository()` (no constructor arguments) with `replaceTags(String equipmentId, List<String> tagIds, {bool notify = true})`, `getTagsByEquipment()` (no arguments; every item's tags by name in one query, an untagged item has no entry) and `watchChanges()` (fires on `equipment_tags` and `tags`), `equipmentTagRepositoryProvider`, `tagsByEquipmentProvider` (`FutureProvider<Map<String, List<Tag>>>`, the one source for the list's tag filter, chips and Tags column), `tagsForEquipmentProvider` (family, detail chips). (Task 5): `EquipmentTagChips`. Existing: `tagsProvider` (`lib/features/tags/presentation/providers/tag_providers.dart:20`), `TagChips` (`tag_input_widget.dart:251`).
- Produces:
  - `EquipmentFilterState.tagIds` (`Set<String>`, default `const {}`), `copyWith({..., Set<String>? tagIds, bool clearTagIds = false})`, `List<EquipmentItem> apply(List<EquipmentItem> equipment, Map<String, Iterable<String>> tagIdsByEquipment)`; `hasActiveFilters`, `==`, `hashCode` cover `tagIds`.
  - `EquipmentField.tags` (appended last); `EquipmentFieldAdapter({Map<String, ServiceClockStatus> worstClocks, Map<String, int> componentCounts, Map<String, List<String>> tagNames = const {}})`.
  - `EquipmentListTile({..., List<Tag> tags = const []})`.
  - `void openEquipmentWithTag(BuildContext context, WidgetRef ref, String tagId)` in `lib/features/equipment/presentation/equipment_tag_navigation.dart`.
  - `searchEquipment` matches tag names.
  - ARB keys `enum_equipmentField_tags`, `enum_equipmentField_tags_short`, `equipment_detail_showEquipmentWith`, `equipment_filter_section_tags`, `equipment_list_emptyState_noTagMatch`.

- [ ] **Step 1: English strings**

In `lib/l10n/arb/app_en.arb` (the file's blocks are not strictly alphabetical here, so anchor on these keys):

After `"equipment_detail_serviceOverdue": "Service is overdue!",` (main line 7083):

```json
  "equipment_detail_showEquipmentWith": "Show equipment with {name}",
  "@equipment_detail_showEquipmentWith": {
    "description": "Tooltip on a tag chip on equipment detail; tapping it opens the equipment list filtered to that tag",
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  },
```

After `"equipment_list_emptyState_noStatusMatch": "No equipment with this status",`:

```json
  "equipment_list_emptyState_noTagMatch": "No equipment with these tags",
```

After `"equipment_filter_section_status": "Status",` (main line 7189; Task 5's insert shifted it by one):

```json
  "equipment_filter_section_tags": "Tags",
```

After `"enum_equipmentField_notes": "Notes",` (main line 19741):

```json
  "enum_equipmentField_tags": "Tags",
```

After `"enum_equipmentField_notes_short": "Notes",` (main line 19757):

```json
  "enum_equipmentField_tags_short": "Tags",
```

- [ ] **Step 1b: Translations (all ten locales)**

Insert each key into every locale file directly after that file's own copy of the same anchor key English uses, indented two spaces like its neighbours. The non-English files are grouped by feature, and in each of them the anchors are single lines followed by the same neighbours as below, so every insertion is one line:

| New key | Insert after | (next line in every locale) |
| --- | --- | --- |
| `equipment_detail_showEquipmentWith` | `equipment_detail_serviceOverdue` | `equipment_detail_sizeLabel` |
| `equipment_list_emptyState_noTagMatch` | `equipment_list_emptyState_noStatusMatch` | `equipment_list_emptyState_noTypeMatch` |
| `equipment_filter_section_tags` | `equipment_filter_section_status` | `equipment_filter_section_category` |
| `enum_equipmentField_tags` | `enum_equipmentField_notes` | `enum_equipmentField_itemName_short` |
| `enum_equipmentField_tags_short` | `enum_equipmentField_notes_short` | `enum_diveCenterField_centerName` |

Terminology: "Tags" is each locale's Manage Tags word (`tags_manage_title`, also the site filter's `diveSites_filter_section_tags`); "equipment" is the word the neighbouring `equipment_list_emptyState_noStatusMatch` uses; the tooltip follows the site twin `diveSites_detail_showSitesWith`. `{name}` stays a placeholder in every locale.

`lib/l10n/arb/app_ar.arb`:

```json
  "equipment_detail_showEquipmentWith": "عرض المعدات التي تحمل {name}",
  "equipment_list_emptyState_noTagMatch": "لا توجد معدات بهذه الوسوم",
  "equipment_filter_section_tags": "الوسوم",
  "enum_equipmentField_tags": "الوسوم",
  "enum_equipmentField_tags_short": "الوسوم",
```

`lib/l10n/arb/app_de.arb`:

```json
  "equipment_detail_showEquipmentWith": "Ausrüstung mit {name} anzeigen",
  "equipment_list_emptyState_noTagMatch": "Keine Ausrüstung mit diesen Tags",
  "equipment_filter_section_tags": "Tags",
  "enum_equipmentField_tags": "Tags",
  "enum_equipmentField_tags_short": "Tags",
```

`lib/l10n/arb/app_es.arb`:

```json
  "equipment_detail_showEquipmentWith": "Mostrar equipo con {name}",
  "equipment_list_emptyState_noTagMatch": "No hay equipo con estas etiquetas",
  "equipment_filter_section_tags": "Etiquetas",
  "enum_equipmentField_tags": "Etiquetas",
  "enum_equipmentField_tags_short": "Etiquetas",
```

`lib/l10n/arb/app_fr.arb`:

```json
  "equipment_detail_showEquipmentWith": "Afficher l'équipement avec {name}",
  "equipment_list_emptyState_noTagMatch": "Aucun équipement avec ces étiquettes",
  "equipment_filter_section_tags": "Étiquettes",
  "enum_equipmentField_tags": "Étiquettes",
  "enum_equipmentField_tags_short": "Étiquettes",
```

`lib/l10n/arb/app_he.arb`:

```json
  "equipment_detail_showEquipmentWith": "הצג ציוד עם {name}",
  "equipment_list_emptyState_noTagMatch": "אין ציוד עם תגיות אלה",
  "equipment_filter_section_tags": "תגיות",
  "enum_equipmentField_tags": "תגיות",
  "enum_equipmentField_tags_short": "תגיות",
```

`lib/l10n/arb/app_hu.arb`:

```json
  "equipment_detail_showEquipmentWith": "Felszerelés ezzel: {name}",
  "equipment_list_emptyState_noTagMatch": "Nincs felszerelés ezekkel a címkékkel",
  "equipment_filter_section_tags": "Címkék",
  "enum_equipmentField_tags": "Címkék",
  "enum_equipmentField_tags_short": "Címkék",
```

`lib/l10n/arb/app_it.arb`:

```json
  "equipment_detail_showEquipmentWith": "Mostra l'attrezzatura con {name}",
  "equipment_list_emptyState_noTagMatch": "Nessuna attrezzatura con questi tag",
  "equipment_filter_section_tags": "Tag",
  "enum_equipmentField_tags": "Tag",
  "enum_equipmentField_tags_short": "Tag",
```

`lib/l10n/arb/app_nl.arb`:

```json
  "equipment_detail_showEquipmentWith": "Uitrusting met {name} tonen",
  "equipment_list_emptyState_noTagMatch": "Geen uitrusting met deze tags",
  "equipment_filter_section_tags": "Tags",
  "enum_equipmentField_tags": "Tags",
  "enum_equipmentField_tags_short": "Tags",
```

`lib/l10n/arb/app_pt.arb`:

```json
  "equipment_detail_showEquipmentWith": "Mostrar equipamentos com {name}",
  "equipment_list_emptyState_noTagMatch": "Nenhum equipamento com estas etiquetas",
  "equipment_filter_section_tags": "Etiquetas",
  "enum_equipmentField_tags": "Etiquetas",
  "enum_equipmentField_tags_short": "Etiquetas",
```

`lib/l10n/arb/app_zh.arb`:

```json
  "equipment_detail_showEquipmentWith": "显示带有 {name} 的装备",
  "equipment_list_emptyState_noTagMatch": "没有带这些标签的装备",
  "equipment_filter_section_tags": "标签",
  "enum_equipmentField_tags": "标签",
  "enum_equipmentField_tags_short": "标签",
```

(Each block lists the five lines in the table's order; each goes after its own anchor, not as one block.)

Check the edits: every locale file still parses and holds each new key once, and `git diff --numstat lib/l10n/arb/` shows 5 added lines and 0 removed in each non-English file.

Run: `flutter gen-l10n`
Expected: completes; `app_localizations.dart` gains `equipment_detail_showEquipmentWith(String name)`, `equipment_list_emptyState_noTagMatch`, `equipment_filter_section_tags`, `enum_equipmentField_tags` and `enum_equipmentField_tags_short`.

Run: `flutter test test/l10n/`
Expected: PASS (`arb_parity_test.dart` finds each key in all ten locales, with `{name}` as the tooltip's only placeholder).

- [ ] **Step 2: Write the failing filter and field tests**

Create `test/features/equipment/domain/models/equipment_filter_state_tags_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';

EquipmentItem _item(String id, EquipmentType type) =>
    EquipmentItem(id: id, name: id, type: type);

EquipmentItem _hose(String id, String kind) => EquipmentItem(
  id: id,
  name: id,
  type: EquipmentType.hose,
  attributes: [
    EquipmentAttribute.curated(
      equipmentId: id,
      key: 'hose_type',
      valueText: kind,
    ),
  ],
);

/// The equipment list's tag axis (issue #1942).
void main() {
  final all = [
    _item('wing', EquipmentType.bcd),
    _item('reg', EquipmentType.regulator),
    _item('mask', EquipmentType.mask),
  ];
  const tagIdsByEquipment = {
    'wing': ['travel', 'rental'],
    'reg': ['travel'],
  };

  List<String> ids(EquipmentFilterState filter) => [
    for (final e in filter.apply(all, tagIdsByEquipment)) e.id,
  ];

  test('an item matches when it carries any selected tag', () {
    expect(ids(const EquipmentFilterState(tagIds: {'rental'})), ['wing']);
    expect(ids(const EquipmentFilterState(tagIds: {'rental', 'travel'})), [
      'wing',
      'reg',
    ]);
  });

  test('an item without tags never matches a tag filter', () {
    expect(ids(const EquipmentFilterState(tagIds: {'travel'})), [
      'wing',
      'reg',
    ]);
  });

  test('the tag axis is ANDed with the category', () {
    expect(
      ids(
        const EquipmentFilterState(
          type: EquipmentType.regulator,
          tagIds: {'rental'},
        ),
      ),
      isEmpty,
    );
    expect(
      ids(
        const EquipmentFilterState(
          type: EquipmentType.regulator,
          tagIds: {'travel'},
        ),
      ),
      ['reg'],
    );
  });

  test('the tag axis is ANDed with attribute conditions', () {
    final hoses = [_hose('hp1', 'hp'), _hose('hp2', 'hp'), _hose('lp1', 'lp')];
    const filter = EquipmentFilterState(
      type: EquipmentType.hose,
      attrConditions: [
        EquipmentAttrCondition(
          key: 'hose_type',
          choices: {'hp'},
          types: {EquipmentType.hose},
        ),
      ],
      tagIds: {'travel'},
    );
    final result = filter.apply(hoses, const {
      'hp1': ['travel'],
      'lp1': ['travel'],
    });
    expect(result.map((e) => e.id), ['hp1']);
  });

  test('no tag selected passes the list through', () {
    expect(const EquipmentFilterState().apply(all, tagIdsByEquipment), same(all));
  });

  test('a tag selection counts as an active filter', () {
    expect(const EquipmentFilterState(tagIds: {'travel'}).hasActiveFilters, isTrue);
    expect(
      const EquipmentFilterState(tagIds: {'travel'}).hasStatusFilter,
      isFalse,
    );
  });

  test('clearTagIds empties the axis and leaves the others', () {
    const filter = EquipmentFilterState(
      status: EquipmentStatus.retired,
      type: EquipmentType.bcd,
      tagIds: {'travel'},
    );
    final cleared = filter.copyWith(clearTagIds: true);
    expect(cleared.tagIds, isEmpty);
    expect(cleared.status, EquipmentStatus.retired);
    expect(cleared.type, EquipmentType.bcd);
  });

  test('a new category keeps the tags; other axes keep them too', () {
    const filter = EquipmentFilterState(tagIds: {'travel'});
    expect(filter.copyWith(type: EquipmentType.bcd).tagIds, {'travel'});
    expect(filter.copyWith(clearStatus: true).tagIds, {'travel'});
    expect(filter.copyWith(tagIds: {'rental'}).tagIds, {'rental'});
  });

  test('equality compares the tag sets by value', () {
    const a = EquipmentFilterState(tagIds: {'a', 'b'});
    // Built at runtime, so equality must compare elements, not identity.
    final b = EquipmentFilterState(tagIds: {'b', 'a'});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const EquipmentFilterState(tagIds: {'a'})));
    expect(a, isNot(const EquipmentFilterState()));
  });
}
```

In `test/features/equipment/domain/models/equipment_filter_state_test.dart`, pass the new argument at the three existing calls:
- line 61: `expect(filter.apply(equipment, const {}).map((e) => e.id), ['bcd']);`
- line 67: `expect(const EquipmentFilterState().apply(equipment, const {}), same(equipment));`
- line 140: `expect(filter.apply(equipment, const {}).map((e) => e.id), ['hp1']);`

In `test/features/equipment/domain/constants/equipment_field_test.dart`:

Add `import 'package:submersion/l10n/arb/app_localizations.dart';` to the imports.

Replace the test at lines 57-60:

```dart
    test('is the last value so saved column orders are stable', () {
      expect(EquipmentField.values.last, EquipmentField.components);
      expect(EquipmentField.components.categoryName, 'details');
    });
```

with

```dart
    test('keeps its place before the later appended tags', () {
      final values = EquipmentField.values;
      expect(values[values.length - 2], EquipmentField.components);
      expect(EquipmentField.components.categoryName, 'details');
    });
```

Add a group after the `EquipmentField.components` group:

```dart
  group('EquipmentField.tags', () {
    test('extracts the names from the adapter map and defaults to none', () {
      final adapter = EquipmentFieldAdapter(
        tagNames: {
          'equip-1': ['Rental', 'Travel kit'],
        },
      );
      expect(adapter.extractValue(EquipmentField.tags, testItem), [
        'Rental',
        'Travel kit',
      ]);
      expect(
        EquipmentFieldAdapter.instance.extractValue(
          EquipmentField.tags,
          testItem,
        ),
        isEmpty,
      );
    });

    test('a table cell is a comma list; no tags is the placeholder', () {
      final adapter = EquipmentFieldAdapter.instance;
      expect(
        adapter.formatValue(EquipmentField.tags, [
          'Rental',
          'Travel kit',
        ], units),
        'Rental, Travel kit',
      );
      expect(
        adapter.formatValue(EquipmentField.tags, <String>[], units),
        '--',
      );
    });

    test('is appended last, so saved layouts keep their order', () {
      expect(EquipmentField.values.last, EquipmentField.tags);
      expect(EquipmentField.tags.categoryName, 'other');
      expect(EquipmentField.tags.sortable, isFalse);
      expect(EquipmentField.tags.isRightAligned, isFalse);
      expect(
        EquipmentFieldAdapter.instance.fieldFromName('tags'),
        EquipmentField.tags,
      );
    });

    test('labels are localized', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(EquipmentField.tags.localizedDisplayName(l10n), 'Tags');
      expect(EquipmentField.tags.localizedShortLabel(l10n), 'Tags');
    });
  });
```

In the same file, the test `'all fields except notes are sortable'` (group `EquipmentField EntityField properties`) becomes:

```dart
    test('all fields except notes and tags are sortable', () {
      for (final field in EquipmentField.values) {
        if (field == EquipmentField.notes || field == EquipmentField.tags) {
          continue;
        }
        expect(field.sortable, isTrue, reason: field.name);
      }
    });
```

- [ ] **Step 3: Run them and confirm they fail**

Run: `flutter test test/features/equipment/domain/models/equipment_filter_state_tags_test.dart`
Expected: compile error, `No named parameter with the name 'tagIds'`.

Run: `flutter test test/features/equipment/domain/constants/equipment_field_test.dart`
Expected: compile error, `There's no constant named 'tags' in 'EquipmentField'`.

- [ ] **Step 4: `EquipmentFilterState`**

In `lib/features/equipment/domain/models/equipment_filter_state.dart`, extend the class doc's axis list (after the "Attribute conditions (#1805)" bullet, line 18):

```dart
/// - Tags (issue #1942) narrow client-side too: an item matches when it
///   carries any selected tag. Tags are not on the entity, so [apply] takes
///   the list's batch map of tag ids per item.
```

Add the field after `attrConditions` (line 34):

```dart
  /// Tag ids, any-of (issue #1942). Empty means no tag narrowing.
  final Set<String> tagIds;
```

Constructor: add `this.tagIds = const {},` after `this.attrConditions = const [],`.

`hasActiveFilters` becomes:

```dart
  bool get hasActiveFilters =>
      hasStatusFilter ||
      type != null ||
      attrConditions.isNotEmpty ||
      tagIds.isNotEmpty;
```

`apply` becomes:

```dart
  /// Narrow [equipment] to the selected category, its conditions and the
  /// selected tags. [tagIdsByEquipment] is each item's tag ids, keyed by
  /// item id (an item with no entry has no tags).
  ///
  /// The status axis is applied upstream by provider selection, so this is the
  /// only filtering the list itself has to do.
  List<EquipmentItem> apply(
    List<EquipmentItem> equipment,
    Map<String, Iterable<String>> tagIdsByEquipment,
  ) {
    final selected = type;
    if (selected == null && attrConditions.isEmpty && tagIds.isEmpty) {
      return equipment;
    }
    return equipment
        .where(
          (e) =>
              (selected == null || e.type == selected) &&
              attrConditions.every((c) => c.matches(e)) &&
              (tagIds.isEmpty ||
                  (tagIdsByEquipment[e.id] ?? const <String>[]).any(
                    tagIds.contains,
                  )),
        )
        .toList();
  }
```

`copyWith` gains the parameters and passes them through:

```dart
  EquipmentFilterState copyWith({
    EquipmentStatus? status,
    bool? serviceDueOnly,
    EquipmentType? type,
    List<EquipmentAttrCondition>? attrConditions,
    Set<String>? tagIds,
    bool clearStatus = false,
    bool clearType = false,
    bool clearAttrConditions = false,
    bool clearTagIds = false,
  }) {
    final nextType = clearType ? null : (type ?? this.type);
    final categoryChanged = nextType != this.type;
    return EquipmentFilterState(
      status: clearStatus ? null : (status ?? this.status),
      serviceDueOnly: clearStatus
          ? false
          : (serviceDueOnly ?? this.serviceDueOnly),
      type: nextType,
      attrConditions: clearAttrConditions
          ? const []
          : (attrConditions ??
                (categoryChanged ? const [] : this.attrConditions)),
      // Tags do not belong to the category, so a new one keeps them.
      tagIds: clearTagIds ? const {} : (tagIds ?? this.tagIds),
    );
  }
```

Equality, hash and `toString`:

```dart
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentFilterState &&
          other.status == status &&
          other.serviceDueOnly == serviceDueOnly &&
          other.type == type &&
          listEquals(other.attrConditions, attrConditions) &&
          setEquals(other.tagIds, tagIds);

  @override
  int get hashCode => Object.hash(
    status,
    serviceDueOnly,
    type,
    Object.hashAll(attrConditions),
    Object.hashAllUnordered(tagIds),
  );

  @override
  String toString() =>
      'EquipmentFilterState(status: $status, serviceDueOnly: $serviceDueOnly, '
      'type: $type, attrConditions: $attrConditions, tagIds: $tagIds)';
```

(`setEquals` comes from the `package:flutter/foundation.dart` import already at line 1.)

Run: `flutter test test/features/equipment/domain/models/`
Expected: PASS (both filter state files).

- [ ] **Step 5: `EquipmentField.tags`**

In `lib/features/equipment/domain/constants/equipment_field.dart`, the tail of the enum (lines 40-45) becomes:

```dart
  // Assemblies (issue #1487). Last so persisted column layouts keep their
  // order.
  components,

  // Tags (issue #1942). Appended for the same reason; never reordered.
  tags;
```

Add a `tags` arm to every exhaustive switch getter:

| Getter | `EquipmentField.tags =>` |
| --- | --- |
| `displayName` | `'Tags'` |
| `shortLabel` | `'Tags'` |
| `localizedDisplayName` | `l10n.enum_equipmentField_tags` |
| `localizedShortLabel` | `l10n.enum_equipmentField_tags_short` |
| `icon` | `Icons.sell_outlined` |
| `defaultWidth` | `160` |
| `minWidth` | `80` |
| `sortable` | `false` |
| `categoryName` | `'other'` |

(`isRightAligned` has a `_ => false` default and needs no arm.)

`EquipmentFieldAdapter` gains the side map, after `componentCounts`:

```dart
  /// Tag names per item id, in the list's order (issue #1942); absent means
  /// no tags. Same lifecycle as [worstClocks].
  final Map<String, List<String>> tagNames;

  EquipmentFieldAdapter({
    this.worstClocks = const {},
    this.componentCounts = const {},
    this.tagNames = const {},
  });
```

`extractValue` gains `EquipmentField.tags => tagNames[entity.id] ?? const <String>[],` after the `components` arm. `formatValue` gains, after the `components` arm:

```dart
      EquipmentField.tags => _formatTags(value as List<String>),
```

and next to `_formatDaysUntilService`:

```dart
  /// A comma list for the table cell; an item with no tags shows the same
  /// placeholder as any other empty cell.
  String _formatTags(List<String> names) =>
      names.isEmpty ? '--' : names.join(', ');
```

Run: `flutter test test/features/equipment/domain/constants/equipment_field_test.dart`
Expected: PASS.

- [ ] **Step 6: Write the failing search and statement-count tests**

Create `test/features/equipment/data/repositories/equipment_search_tags_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

/// Equipment search also matches tag names (issue #1942).
void main() {
  late EquipmentRepository equipment;
  late EquipmentTagRepository tags;

  setUp(() async {
    await setUpTestDatabase();
    equipment = EquipmentRepository();
    tags = EquipmentTagRepository();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('d1', 'Diver', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, diver_id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites, applies_to_equipment) VALUES '
      "('t1', 'd1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('t2', 'd1', 'Travel spares', 0, 0, 0, 0, 1), "
      "('t3', 'd1', 'Rental', 0, 0, 0, 0, 1)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<EquipmentItem> add(
    String name, {
    String? brand,
    List<String> tagIds = const [],
  }) async {
    final item = await equipment.createEquipment(
      EquipmentItem(
        id: '',
        diverId: 'd1',
        name: name,
        type: EquipmentType.bcd,
        brand: brand,
      ),
    );
    await tags.replaceTags(item.id, tagIds);
    return item;
  }

  test('a tag name match finds the item', () async {
    final wing = await add('Wing', tagIds: ['t1']);
    await add('Drysuit', tagIds: ['t3']);

    final found = await equipment.searchEquipment('kit');
    expect(found.map((e) => e.id), [wing.id]);
  });

  test('an item with two matching tags comes back once', () async {
    final wing = await add('Wing', tagIds: ['t1', 't2']);

    final found = await equipment.searchEquipment('travel');
    expect(found.map((e) => e.id), [wing.id]);
  });

  test('untagged items still match by name and brand', () async {
    final reg = await add('Primary', brand: 'Apeks');
    await add('Wing', tagIds: ['t1']);

    // The LEFT JOIN must keep items that have no tag rows at all.
    expect((await equipment.searchEquipment('apeks')).map((e) => e.id), [
      reg.id,
    ]);
    expect((await equipment.searchEquipment('prim')).map((e) => e.id), [
      reg.id,
    ]);
  });

  test('the diver filter still applies with the tags joined', () async {
    final wing = await add('Wing', tagIds: ['t1']);

    expect(
      (await equipment.searchEquipment('travel', diverId: 'd1')).map(
        (e) => e.id,
      ),
      [wing.id],
    );
    expect(
      await equipment.searchEquipment('travel', diverId: 'someone-else'),
      isEmpty,
    );
  });
}
```

Create `test/features/equipment/data/repositories/equipment_list_tags_statement_count_test.dart`:

```dart
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

/// The equipment list reads every item's tags in one batch (issue #1942):
/// its statement count must not grow with the number of items. Recipe:
/// a statement-logging database, prints captured in a zone.
void main() {
  tearDown(() async => tearDownTestDatabase());

  test('the list statement count does not grow with the item count', () async {
    DatabaseService.instance.setTestDatabase(
      AppDatabase(NativeDatabase.memory(logStatements: true)),
    );
    final equipment = EquipmentRepository();
    final tags = EquipmentTagRepository();
    await DatabaseService.instance.database.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites, applies_to_equipment) VALUES '
      "('t1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('t2', 'Rental', 0, 0, 0, 0, 1)",
    );

    Future<void> addItem(String name) async {
      final item = await equipment.createEquipment(
        EquipmentItem(id: '', name: name, type: EquipmentType.bcd),
      );
      await tags.replaceTags(item.id, ['t1', 't2']);
    }

    // What one list load runs: the default view's items (attributes are
    // batched, #1805) and the tags of every item.
    Future<int> countStatements() async {
      final logged = <String>[];
      await runZoned(
        () async {
          await equipment.getActiveEquipment();
          await tags.getTagsByEquipment();
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logged.add(line),
        ),
      );
      return logged.length;
    }

    // Fixtures are written OUTSIDE the zone so their writes are not counted.
    await addItem('One');
    final one = await countStatements();
    for (var i = 0; i < 5; i++) {
      await addItem('More $i');
    }
    final six = await countStatements();

    expect(one, greaterThan(0));
    expect(six, one);
    expect((await tags.getTagsByEquipment()).length, 6);
  });
}
```

- [ ] **Step 7: Run them and confirm the search test fails**

Run: `flutter test test/features/equipment/data/repositories/equipment_search_tags_test.dart`
Expected: FAIL, `'a tag name match finds the item'` with `Expected: ['<id>'] Actual: []` (the tag tests fail the same way; the untagged-name test passes).

Run: `flutter test test/features/equipment/data/repositories/equipment_list_tags_statement_count_test.dart`
Expected: PASS already. It pins a property of Task 3's batch read (`getTagsByEquipment` is one query) and guards the list against a later per-item read. If it fails here, Task 3's batch read issues a query per item and must be fixed there.

- [ ] **Step 8: Search by tag name**

In `lib/features/equipment/data/repositories/equipment_repository_impl.dart`, replace the doc line, the variables and the query of `searchEquipment` (find the method by name; Tasks 3 and 5 added lines above it, so main's 758-783 no longer apply):

```dart
  /// Search equipment by name, brand, model, serial number or tag name
  /// (issue #1942). Each item comes back once, however many of its tags
  /// match.
  Future<List<EquipmentItem>> searchEquipment(
    String query, {
    String? diverId,
  }) async {
    try {
      final searchTerm = '%${query.toLowerCase()}%';
      // Qualified: tags has a diver_id and a name column too.
      final diverFilter = diverId != null ? 'AND e.diver_id = ?' : '';
      final variables = [
        Variable.withString(searchTerm),
        Variable.withString(searchTerm),
        Variable.withString(searchTerm),
        Variable.withString(searchTerm),
        Variable.withString(searchTerm),
        if (diverId != null) Variable.withString(diverId),
      ];

      final results = await _db.customSelect('''
        SELECT DISTINCT e.* FROM equipment e
        LEFT JOIN equipment_tags et ON et.equipment_id = e.id
        LEFT JOIN tags t ON t.id = et.tag_id
        WHERE (LOWER(e.name) LIKE ?
           OR LOWER(e.brand) LIKE ?
           OR LOWER(e.model) LIKE ?
           OR LOWER(e.serial_number) LIKE ?
           OR LOWER(t.name) LIKE ?)
        $diverFilter
        ORDER BY e.is_active DESC, e.type ASC, e.name ASC
      ''', variables: variables).get();
```

The row mapping below it (`results.map((row) { ... row.data['id'] ... })`) is unchanged: `e.*` keeps the unprefixed column names.

In `lib/features/equipment/presentation/providers/equipment_providers.dart`, add the import:

```dart
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
```

and in `equipmentSearchProvider` (found by name; main's lines 348-359), after `ref.invalidateSelfWhen(repository.watchEquipmentChanges());` add:

```dart
      // Tag names match too (issue #1942): a rename or a new link must
      // refresh the results.
      ref.invalidateSelfWhen(
        ref.read(equipmentTagRepositoryProvider).watchChanges(),
      );
```

Run: `flutter test test/features/equipment/data/repositories/equipment_search_tags_test.dart`
Expected: PASS.

- [ ] **Step 9: Write the failing list, chip-tap and filter sheet tests**

Create `test/features/equipment/presentation/widgets/equipment_list_tags_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Tags on the equipment list (issue #1942).
void main() {
  final now = DateTime(2026);
  Tag tag(String id, String name) => Tag(
    id: id,
    name: name,
    colorHex: '#4CAF50',
    createdAt: now,
    updatedAt: now,
    scopes: const {TagScope.equipment},
  );
  final travel = tag('t1', 'Travel kit');
  final rental = tag('t2', 'Rental');
  const wing = EquipmentItem(id: 'e1', name: 'Wing', type: EquipmentType.bcd);
  const reg = EquipmentItem(
    id: 'e2',
    name: 'Reg',
    type: EquipmentType.regulator,
  );

  group('EquipmentListTile', () {
    Widget wrap(Widget child) => testApp(
      locale: const Locale('en'),
      overrides: [
        equipmentRollupClockProvider.overrideWith((ref) async => {}),
        equipmentComponentsIndexProvider.overrideWith(
          (ref) async => ComponentsIndex.empty,
        ),
        activeEquipmentProvider.overrideWith((ref) async => const [wing]),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: child,
    );

    testWidgets('shows up to three tags and a +N chip', (tester) async {
      final five = [
        tag('a', 'Travel kit'),
        tag('b', 'Rental'),
        tag('c', 'Cold water'),
        tag('d', 'Needs repair'),
        tag('e', 'Backup'),
      ];
      await tester.pumpWidget(wrap(EquipmentListTile(item: wing, tags: five)));
      await tester.pumpAndSettle();

      expect(find.text('Travel kit'), findsOneWidget);
      expect(find.text('Rental'), findsOneWidget);
      expect(find.text('Cold water'), findsOneWidget);
      expect(find.text('Needs repair'), findsNothing);
      expect(find.text('Backup'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('a tile given no tags draws no tag chips', (tester) async {
      await tester.pumpWidget(wrap(const EquipmentListTile(item: wing)));
      await tester.pumpAndSettle();

      expect(find.byType(TagChips), findsNothing);
    });
  });

  group('EquipmentListContent', () {
    Future<List<Override>> overrides({
      ListViewMode viewMode = ListViewMode.detailed,
      EquipmentFilterState filter = const EquipmentFilterState(),
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      return [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        activeEquipmentProvider.overrideWith((ref) async => const [wing, reg]),
        allEquipmentProvider.overrideWith((ref) async => const [wing, reg]),
        equipmentListViewModeProvider.overrideWith((ref) => viewMode),
        equipmentFilterProvider.overrideWith((ref) => filter),
        highlightedEquipmentIdProvider.overrideWith((ref) => null),
        tagsByEquipmentProvider.overrideWith(
          (ref) async => {
            'e1': [rental, travel],
          },
        ),
        tagsProvider.overrideWith((ref) async => [rental, travel]),
      ];
    }

    Future<void> pumpList(
      WidgetTester tester,
      List<Override> overrides,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('detailed tiles carry their tags', (tester) async {
      await pumpList(tester, await overrides());

      expect(find.text('Travel kit'), findsOneWidget);
      expect(find.text('Rental'), findsOneWidget);
    });

    testWidgets('compact tiles show no tags', (tester) async {
      await pumpList(tester, await overrides(viewMode: ListViewMode.compact));

      expect(find.text('Wing'), findsOneWidget);
      expect(find.text('Travel kit'), findsNothing);
    });

    testWidgets('a tag filter keeps only items carrying a selected tag', (
      tester,
    ) async {
      await pumpList(
        tester,
        await overrides(
          viewMode: ListViewMode.compact,
          filter: const EquipmentFilterState(tagIds: {'t1'}),
        ),
      );

      expect(find.text('Wing'), findsOneWidget);
      expect(find.text('Reg'), findsNothing);
    });

    testWidgets('the active filters bar names the tag and removes it', (
      tester,
    ) async {
      await pumpList(
        tester,
        await overrides(
          viewMode: ListViewMode.compact,
          filter: const EquipmentFilterState(tagIds: {'t1'}),
        ),
      );

      final chip = find.widgetWithText(InputChip, 'Travel kit');
      expect(chip, findsOneWidget);
      tester.widget<InputChip>(chip).onDeleted!();
      await tester.pumpAndSettle();

      expect(find.byType(InputChip), findsNothing);
      expect(find.text('Reg'), findsOneWidget);
    });

    testWidgets('a tag filter that matches nothing says so', (tester) async {
      await pumpList(
        tester,
        await overrides(
          filter: const EquipmentFilterState(tagIds: {'unused'}),
        ),
      );

      expect(find.text('No equipment with these tags'), findsOneWidget);
    });
  });
}
```

Append to `test/features/equipment/presentation/widgets/equipment_tag_chips_test.dart` (Task 5's file). Add imports:

```dart
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
```

and inside `main()`:

```dart
  Future<ProviderContainer> pumpRouted(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        tagsForEquipmentProvider('e1').overrideWith(
          (ref) async => [rental, travel],
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/equipment/e1',
      routes: [
        GoRoute(
          path: '/equipment',
          builder: (_, _) => const Scaffold(body: Text('EQUIPMENT_LIST')),
        ),
        GoRoute(
          path: '/equipment/:id',
          builder: (_, _) =>
              const Scaffold(body: EquipmentTagChips(equipmentId: 'e1')),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('tapping a chip opens the list filtered to that tag alone', (
    tester,
  ) async {
    final container = await pumpRouted(tester);
    // A leftover category would hide some of the tag's items.
    container.read(equipmentFilterProvider.notifier).state =
        const EquipmentFilterState(type: EquipmentType.regulator);

    await tester.tap(find.text('Travel kit'));
    await tester.pumpAndSettle();

    expect(find.text('EQUIPMENT_LIST'), findsOneWidget);
    expect(
      container.read(equipmentFilterProvider),
      const EquipmentFilterState(tagIds: {'t1'}),
    );
  });

  testWidgets('each chip says what a tap does', (tester) async {
    await pumpRouted(tester);

    expect(find.byTooltip('Show equipment with Travel kit'), findsOneWidget);
    expect(find.byTooltip('Show equipment with Rental'), findsOneWidget);
  });
```

Create `test/features/equipment/presentation/widgets/equipment_filter_sheet_tags_test.dart` (launcher and container shape from `equipment_filter_sheet_test.dart:20-104`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_filter_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _SheetLauncher extends ConsumerWidget {
  const _SheetLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showEquipmentFilterSheet(context, ref),
          child: const Text('open'),
        ),
      ),
    );
  }
}

/// The Tags group of the equipment filter panel (issue #1942).
void main() {
  final now = DateTime(2026);
  final travel = Tag(
    id: 't1',
    name: 'Travel kit',
    createdAt: now,
    updatedAt: now,
    scopes: const {TagScope.equipment},
  );
  final night = Tag(
    id: 'd1',
    name: 'Night',
    createdAt: now,
    updatedAt: now,
    scopes: const {TagScope.dives},
  );

  Future<ProviderContainer> open(
    WidgetTester tester, {
    required List<Tag> tags,
    EquipmentFilterState filter = const EquipmentFilterState(),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 2200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        allEquipmentProvider.overrideWith(
          (ref) async => const [
            EquipmentItem(id: 'e1', name: 'Wing', type: EquipmentType.bcd),
          ],
        ),
        equipmentFilterProvider.overrideWith((ref) => filter),
        tagsProvider.overrideWith((ref) async => tags),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _SheetLauncher(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return container;
  }

  final travelChip = find.byKey(const ValueKey('equipment_filter_tag_t1'));

  testWidgets('lists equipment tags only; Apply writes the picked ones', (
    tester,
  ) async {
    final container = await open(tester, tags: [night, travel]);

    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Night'), findsNothing);
    await tester.ensureVisible(travelChip);
    await tester.tap(travelChip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment_filter_apply')));
    await tester.pumpAndSettle();

    expect(container.read(equipmentFilterProvider).tagIds, {'t1'});
  });

  testWidgets('opens with the tags in force; Clear All empties them', (
    tester,
  ) async {
    final container = await open(
      tester,
      tags: [travel],
      filter: const EquipmentFilterState(tagIds: {'t1'}),
    );

    await tester.ensureVisible(travelChip);
    expect(tester.widget<FilterChip>(travelChip).selected, isTrue);
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment_filter_apply')));
    await tester.pumpAndSettle();

    expect(container.read(equipmentFilterProvider).tagIds, isEmpty);
  });

  testWidgets('no equipment tags hides the group', (tester) async {
    await open(tester, tags: [night]);

    expect(find.text('Tags'), findsNothing);
  });
}
```

- [ ] **Step 10: Run them and confirm they fail**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_list_tags_test.dart`
Expected: compile error, `No named parameter with the name 'tags'` (on `EquipmentListTile`).

Run: `flutter test test/features/equipment/presentation/widgets/equipment_tag_chips_test.dart`
Expected: FAIL, `'tapping a chip opens the list filtered to that tag alone'`: `EQUIPMENT_LIST` not found (a `Chip` has no tap), and the tooltip test finds no tooltip.

Run: `flutter test test/features/equipment/presentation/widgets/equipment_filter_sheet_tags_test.dart`
Expected: FAIL, `Found 0 widgets with text "Tags"`.

- [ ] **Step 11: `openEquipmentWithTag` and the chip tap**

Create `lib/features/equipment/presentation/equipment_tag_navigation.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

/// Opens the equipment list showing only the items tagged [tagId]
/// (issue #1942), the equipment twin of `openDivesWithTag` and
/// `openSitesWithTag`.
///
/// The filter is replaced rather than merged: a leftover category or
/// attribute condition would hide some of the tag's items. The status axis
/// returns to the default view, which hides retired and sold gear, as the
/// list always does. The filter chip on the list clears the tag again.
void openEquipmentWithTag(BuildContext context, WidgetRef ref, String tagId) {
  ref.read(equipmentFilterProvider.notifier).state = EquipmentFilterState(
    tagIds: {tagId},
  );
  context.go('/equipment');
}
```

In `lib/features/equipment/presentation/widgets/equipment_tag_chips.dart` (Task 5), add the imports

```dart
import 'package:submersion/features/equipment/presentation/equipment_tag_navigation.dart';
import 'package:submersion/l10n/l10n_extension.dart';
```

replace the class doc's first sentence with "An equipment item's tags as colored chips, under the name in the detail page header (issue #1942). Tapping one opens the equipment list filtered to that tag, as a dive's tag chip opens the dive list.", and replace the `Chip(...)` in the loop with:

```dart
            ActionChip(
              label: Text(tag.name),
              tooltip: context.l10n.equipment_detail_showEquipmentWith(
                tag.name,
              ),
              backgroundColor: tag.color.withValues(alpha: 0.2),
              side: BorderSide(color: tag.color),
              labelStyle: TextStyle(color: tag.color),
              visualDensity: VisualDensity.compact,
              onPressed: () => openEquipmentWithTag(context, ref, tag.id),
            ),
```

The list route is `/equipment` (`EquipmentDetailPage` already sends `context.go('/equipment?selected=...')` there, `equipment_detail_page.dart:76`).

Run: `flutter test test/features/equipment/presentation/widgets/equipment_tag_chips_test.dart`
Expected: PASS.

- [ ] **Step 12: Filter sheet Tags group**

In `lib/features/equipment/presentation/widgets/equipment_filter_sheet.dart`, add imports:

```dart
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
```

State (after `List<EquipmentAttrCondition> _attrConditions = const [];`, line 45):

```dart
  Set<String> _tagIds = const {};
```

`initState` (after `_attrConditions = filter.attrConditions;`, line 54):

```dart
    _tagIds = filter.tagIds;
```

Section list (lines 111-117) becomes:

```dart
                    children: [
                      _buildStatusSection(),
                      const SizedBox(height: 24),
                      _buildCategorySection(),
                      _buildTagSection(),
                    ],
```

New method after `_buildCategorySection` (before `_clearAll`):

```dart
  /// Equipment tags (issue #1942), any-of. Offers every equipment tag plus
  /// any tag already selected, so a filter on a tag that has since lost its
  /// equipment scope is still clearable from here.
  Widget _buildTagSection() {
    final tags = (ref.watch(tagsProvider).value ?? const <Tag>[])
        .where((t) => t.appliesTo(TagScope.equipment) || _tagIds.contains(t.id))
        .toList();
    if (tags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.equipment_filter_section_tags,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                FilterChip(
                  key: ValueKey('equipment_filter_tag_${tag.id}'),
                  avatar: CircleAvatar(backgroundColor: tag.color, radius: 6),
                  label: Text(tag.name),
                  selected: _tagIds.contains(tag.id),
                  onSelected: (selected) => setState(() {
                    _tagIds = selected
                        ? {..._tagIds, tag.id}
                        : _tagIds.where((id) => id != tag.id).toSet();
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
```

`_clearAll` gains `_tagIds = const {};` inside its `setState`. `_applyFilters` passes `tagIds: _tagIds,` after `attrConditions: _attrConditions,`.

Run: `flutter test test/features/equipment/presentation/widgets/equipment_filter_sheet_tags_test.dart`
Expected: PASS.

- [ ] **Step 13: The list: batch tags, filter, chips, table column, active chip, empty state**

In `lib/features/equipment/presentation/widgets/equipment_list_content.dart`:

Imports (alphabetical placement within the existing `submersion` block is not enforced; add them after the `equipment_providers.dart` import, line 38):

```dart
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
```

`build`: after `final filter = ref.watch(equipmentFilterProvider);` (line 234) add:

```dart
    // Tags ride beside the items, not on them (issue #1942): one batch read
    // for the whole list feeds the tag filter and the detailed tiles' chips.
    final tagsByEquipment =
        ref.watch(tagsByEquipmentProvider).value ??
        const <String, List<Tag>>{};
    final tagIdsByEquipment = {
      for (final entry in tagsByEquipment.entries)
        entry.key: [for (final t in entry.value) t.id],
    };
```

Line 251 becomes `filter.apply(equipment, tagIdsByEquipment),` and line 287 becomes
`filter.apply(equipmentAsync.value ?? const <EquipmentItem>[], tagIdsByEquipment),`.

Line 311 becomes:

```dart
            : _buildEquipmentList(
                context,
                ref,
                visibleGroups,
                arrangement,
                tagsByEquipment: tagsByEquipment,
              ),
```

`_buildEquipmentList` (line 870) gains the named parameter:

```dart
  Widget _buildEquipmentList(
    BuildContext context,
    WidgetRef ref,
    List<EquipmentGroup> groups,
    EquipmentArrangement arrangement, {
    required Map<String, List<Tag>> tagsByEquipment,
  }) {
```

and its `EquipmentListTile(` (line 936) gets, after `onCheckChanged: onCheckChanged,`:

```dart
              // Chips only in the detailed mode; compact stays one line.
              tags: viewMode == ListViewMode.detailed
                  ? tagsByEquipment[item.id] ?? const []
                  : const [],
```

`_buildTableView`: after the `final index = ... ComponentsIndex.empty;` statement (lines 637-639) add

```dart
        final tagsByEquipment =
            ref.watch(tagsByEquipmentProvider).value ??
            const <String, List<Tag>>{};
```

and the adapter (lines 644-652) gains, after the `componentCounts` map:

```dart
            tagNames: {
              for (final e in tagsByEquipment.entries)
                e.key: [for (final t in e.value) t.name],
            },
```

`_buildActiveFiltersBar`: at the top of the method, after `final colorScheme = Theme.of(context).colorScheme;`, add

```dart
    final tagNames = {
      for (final t in ref.watch(tagsProvider).value ?? const <Tag>[])
        t.id: t.name,
    };
```

and after the `for (final condition in filter.attrConditions)` entry (lines 837-846) add:

```dart
            for (final tagId in filter.tagIds)
              _buildActiveFilterChip(
                tagNames[tagId] ?? tagId,
                () => ref.read(equipmentFilterProvider.notifier).state = filter
                    .copyWith(
                      tagIds: filter.tagIds.where((id) => id != tagId).toSet(),
                    ),
                icon: Icons.sell_outlined,
              ),
```

`_buildEmptyState`: after `final blameCategory = filter.type != null && hadItemsBeforeTypeFilter;` (line 968) add

```dart
    // A tag filter (issue #1942) narrows the same way; a tag chip on a
    // retired item can land here, since the default view hides retired gear.
    final blameTags =
        !blameCategory && filter.tagIds.isNotEmpty && hadItemsBeforeTypeFilter;
```

The `filterText` chain (lines 970-983) becomes:

```dart
    String filterText;
    if (blameCategory) {
      filterText = context.l10n.equipment_list_emptyState_filterText_type(
        filter.type!.localizedName(context.l10n),
      );
    } else if (blameTags) {
      filterText = context.l10n.equipment_list_emptyState_filterText_equipment;
    } else if (filter.serviceDueOnly) {
      filterText = context.l10n.equipment_list_emptyState_filterText_serviceDue;
    } else if (filter.status == null) {
      filterText = context.l10n.equipment_list_emptyState_filterText_equipment;
    } else {
      filterText = context.l10n.equipment_list_emptyState_filterText_status(
        filter.status!.localizedName(context.l10n).toLowerCase(),
      );
    }
```

and in the subtitle expression (line 1001) insert the tag case after the category case:

```dart
            blameCategory
                ? context.l10n.equipment_list_emptyState_noTypeMatch
                : blameTags
                ? context.l10n.equipment_list_emptyState_noTagMatch
                : filter.serviceDueOnly
```

`EquipmentListTile`: add the field after `final ValueChanged<bool>? onCheckChanged;` (line 1061):

```dart

  /// The item's tags, handed in by the list (issue #1942), which reads every
  /// item's tags in one batch; the tile reads no provider for them. Up to
  /// three show, then a "+N" chip.
  final List<Tag> tags;
```

constructor: `this.tags = const [],` after `this.onCheckChanged,` (line 1070). After `final hasFullName = item.fullName != item.name;` (line 1099) add `final hasTags = tags.isNotEmpty;`, and the subtitle (lines 1135-1144) becomes:

```dart
        subtitle: hasFullName || hasChips || hasTags
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasFullName) Text(item.fullName),
                  if (hasChips) AssemblyChips(itemId: item.id),
                  if (hasTags)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TagChips(tags: tags, maxTags: 3),
                    ),
                ],
              )
            : null,
```

Run each:
- `flutter test test/features/equipment/presentation/widgets/equipment_list_tags_test.dart`
- `flutter test test/features/equipment/domain/models/equipment_filter_state_test.dart`

Expected: PASS.

- [ ] **Step 14: Run every consumer and the architecture guards**

Changed shared pieces and who pumps them (`grep -rln "EquipmentListTile\|EquipmentListContent\|EquipmentListPage\|EquipmentFilterSheet\|showEquipmentFilterSheet\|EquipmentSearchDelegate\|EquipmentDetailPage" test`):
- `test/features/equipment/presentation/widgets/equipment_list_content_test.dart`
- `test/features/equipment/presentation/pages/equipment_list_page_test.dart`
- `test/features/equipment/presentation/widgets/equipment_filter_sheet_test.dart`
- `test/features/equipment/presentation/widgets/dense_equipment_list_tile_test.dart`
- `test/features/equipment/presentation/widgets/equipment_tile_accent_test.dart`
- `test/features/equipment/presentation/widgets/equipment_tile_condition_badge_test.dart`
- `test/features/equipment/presentation/widgets/equipment_tile_rollup_badge_test.dart`
- `test/features/equipment/presentation/widgets/equipment_tile_service_badge_test.dart`
- the five detail page files listed in Task 5 Step 12 (the chips now call `context.l10n` and navigate)

`EquipmentField` users outside the feature: `test/features/settings/presentation/pages/column_config_page_test.dart`, `test/features/shared/entity_table_config_provider_integration_test.dart`, `test/features/providers/entity_highlighted_providers_test.dart`.

`EquipmentListContent` and the filter sheet now watch `tagsByEquipmentProvider` and `tagsProvider`. In the existing harnesses (no database) both fail with a `StateError`, which riverpod does not retry, and the widgets read `.value`, so they render as before. If a harness fails anyway, override `tagsByEquipmentProvider.overrideWith((ref) async => const {})` and `tagsProvider.overrideWith((ref) async => const [])` in it.

Run: `flutter test test/features/equipment`
Expected: PASS.

Run: `flutter test test/features/settings/presentation/pages/column_config_page_test.dart`
Run: `flutter test test/features/shared/entity_table_config_provider_integration_test.dart`
Run: `flutter test test/features/providers/entity_highlighted_providers_test.dart`
Expected: PASS.

Run: `flutter test test/l10n/`
Expected: PASS.

Run: `flutter test test/architecture/`
Expected: PASS (the provider tick guard sees the new `invalidateSelfWhen` in `equipmentSearchProvider`).

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 15: Commit**

```bash
dart format .
git add lib/features/equipment/domain/models/equipment_filter_state.dart \
  lib/features/equipment/domain/constants/equipment_field.dart \
  lib/features/equipment/presentation/widgets/equipment_list_content.dart \
  lib/features/equipment/presentation/widgets/equipment_filter_sheet.dart \
  lib/features/equipment/presentation/widgets/equipment_tag_chips.dart \
  lib/features/equipment/presentation/equipment_tag_navigation.dart \
  lib/features/equipment/data/repositories/equipment_repository_impl.dart \
  lib/features/equipment/presentation/providers/equipment_providers.dart \
  lib/l10n/arb/app_en.arb lib/l10n/arb/app_ar.arb lib/l10n/arb/app_de.arb \
  lib/l10n/arb/app_es.arb lib/l10n/arb/app_fr.arb lib/l10n/arb/app_he.arb \
  lib/l10n/arb/app_hu.arb lib/l10n/arb/app_it.arb lib/l10n/arb/app_nl.arb \
  lib/l10n/arb/app_pt.arb lib/l10n/arb/app_zh.arb lib/l10n/arb/app_localizations*.dart \
  test/features/equipment/domain/models/equipment_filter_state_test.dart \
  test/features/equipment/domain/models/equipment_filter_state_tags_test.dart \
  test/features/equipment/domain/constants/equipment_field_test.dart \
  test/features/equipment/data/repositories/equipment_search_tags_test.dart \
  test/features/equipment/data/repositories/equipment_list_tags_statement_count_test.dart \
  test/features/equipment/presentation/widgets/equipment_list_tags_test.dart \
  test/features/equipment/presentation/widgets/equipment_tag_chips_test.dart \
  test/features/equipment/presentation/widgets/equipment_filter_sheet_tags_test.dart
git commit -m "feat(equipment): tag chips, Tags column, tag filter and tag search in the equipment list (#1942)" \
  -m "Detailed list tiles show up to three tags and a +N chip, fed by one batch read for the whole list. The table gains a Tags column. The filter panel gains a Tags group (any of the selected tags, ANDed with status, category and attributes), shown in the active filters bar. Search matches tag names and returns each item once. A tag chip on the detail page opens the list filtered to that tag. The new strings are translated into all ten locales."
```

(If `dart format .` touched files outside this task, stage only the paths above.)

### Task 7: Manage Tags equipment scope (delete and merge wording)

**Files:**
- Modify: `lib/features/tags/presentation/tag_usage_messages.dart` (whole file, as Task 1 left it)
- Modify: `lib/features/tags/presentation/widgets/tag_merge_sheet.dart`: the `_sortedStats` getter (main 31-35; Task 1 respelled its comparison to `count(TagScope.dives)`)
- Modify: `lib/l10n/arb/app_en.arb`: `tags_manage_scopeRequired` and the three `_unused` lines (main 12849, 12900, 12943, 12981; Task 3 inserted lines into this block, so locate each by key)
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb` (the same four lines in each, located by key)
- Regenerate: `lib/l10n/arb/app_localizations.dart` and `lib/l10n/arb/app_localizations_*.dart`
- Test (replace): `test/features/tags/presentation/tag_usage_messages_test.dart` (Task 1's version)
- Test (create): `test/features/tags/presentation/pages/tag_manage_page_equipment_wording_test.dart`
- Test (modify): `test/features/tags/presentation/pages/tag_manage_page_test.dart` (import block, `_buildRoutedTestWidget` main 167-207, a helper after `_tagsFromStats` main 129-130, a new group at the end of `main()`)
- Test (modify): `test/features/tags/presentation/pages/tag_manage_page_scope_test.dart` (the two `'Choose dives, sites, or both'` assertions in `unticking both scopes shows an error and does not save`, main 134 and 139)
- Test (modify): `test/features/tags/presentation/widgets/tag_merge_sheet_test.dart` (end of group `TagMergeSheet`, main 237)
- No change: `lib/features/tags/presentation/pages/tag_manage_page.dart` and `lib/features/tags/presentation/tag_scope_labels.dart`. After Task 1 the page builds its checkboxes (`_scopeEditor`), row subtitle and usage line (`_buildTagRow`) and narrowing lines (`_confirmNarrowing`, through `tagScopeNarrowLine`) from `TagScope.values`, and Task 3 gave every label function its equipment arm. The page's single delete, bulk delete and merge sheet already pass a `Map<TagScope, int>` to the helpers this task rewrites. Equipment lists need no invalidation after a tag edit: Task 3's equipment tag providers refresh on `EquipmentTagRepository.watchChanges()` (`equipment_tags` and `tags`).

**Interfaces:**
- Consumes:
  - Task 1: `TagScope`, `Tag.scopes`, `Tag.appliesTo`, `Tag.copyWith(scopes:)`, `TagStatistic({required Tag tag, Map<TagScope, int> counts = const {}})` and `count(scope)`, dense `Map<TagScope, int>` from `TagRepository.getTagUsage` / `getMergedUsage`, `tagScopeCount` in `tag_scope_labels.dart`, the map-based `tag_usage_messages.dart`, and the `tag_manage_page_test.dart` doubles `_MockTagRepository({Map<TagScope, int> mergedUsage})` and `_MockTagListNotifier.added` / `.updated`.
  - Task 3: `TagScope.equipment`; table `equipment_tags` (Drift getter `equipmentTags`); column `tags.applies_to_equipment` (field `appliesToEquipment`); equipment counts in `getTagStatistics`, `getTagUsage` and `getMergedUsage` through the registry; the keys `tags_manage_scope_equipment`, `tags_manage_useForEquipment`, `tags_manage_equipmentCount` and `tags_manage_narrowDialog_equipment` in all 11 locales, with their `tag_scope_labels.dart` arms.
  - Task 6: `equipmentFilterProvider` holding `EquipmentFilterState.tagIds` (one test reads it).
- Produces:
  - `tag_usage_messages.dart`: the same four functions (`tagDeleteMessage`, `tagsBulkDeleteMessage`, `tagsMergeAffectedMessage`, `tagUsageCounts`), now covering all eight combinations of affected scopes.
  - 12 new keys, in all 11 locales: `tags_manage_deleteMessage_equipment`, `tags_manage_deleteMessage_divesAndEquipment`, `tags_manage_deleteMessage_sitesAndEquipment`, `tags_manage_deleteMessage_all`, `tags_manage_bulkDeleteMessage_equipment`, `tags_manage_bulkDeleteMessage_divesAndEquipment`, `tags_manage_bulkDeleteMessage_sitesAndEquipment`, `tags_manage_bulkDeleteMessage_all`, `tags_manage_mergeAffected_equipment`, `tags_manage_mergeAffected_divesAndEquipment`, `tags_manage_mergeAffected_sitesAndEquipment`, `tags_manage_mergeAffected_all`.
  - 4 reworded keys, in all 11 locales: `tags_manage_deleteMessage_unused`, `tags_manage_bulkDeleteMessage_unused`, `tags_manage_mergeAffected_unused`, `tags_manage_scopeRequired`.

- [ ] **Step 1: Write the failing message tests**

Replace the whole of `test/features/tags/presentation/tag_usage_messages_test.dart` (Task 1's version; each of its dives and sites cases survives below as a row of the table, and its missing-scope case as `a scope missing from the usage map counts as zero`) with:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_usage_messages.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _d = TagScope.dives;
const _s = TagScope.sites;
const _e = TagScope.equipment;

/// One combination of affected scopes and the English each family gives it.
typedef _Case = ({
  String name,
  Map<TagScope, int> usage,
  String delete,
  String bulk,
  String merge,
});

/// Every combination of affected scopes (#1902, #1942). A tag can carry any
/// mix of dives, sites and equipment, and each message names exactly what a
/// delete or merge rewrites, one whole sentence per combination.
const List<_Case> _cases = [
  (
    name: 'dives only',
    usage: {_d: 12},
    delete: '"Reef" will be removed from 12 dives. This cannot be undone.',
    bulk:
        'These tags will be removed from 12 dives total. '
        'This cannot be undone.',
    merge: 'This will affect 12 dives total.',
  ),
  (
    name: 'sites only',
    usage: {_s: 3},
    delete: '"Reef" will be removed from 3 sites. This cannot be undone.',
    bulk:
        'These tags will be removed from 3 sites total. '
        'This cannot be undone.',
    merge: 'This will affect 3 sites total.',
  ),
  (
    name: 'equipment only',
    usage: {_e: 5},
    delete:
        '"Reef" will be removed from 5 equipment items. '
        'This cannot be undone.',
    bulk:
        'These tags will be removed from 5 equipment items total. '
        'This cannot be undone.',
    merge: 'This will affect 5 equipment items total.',
  ),
  (
    name: 'dives and sites',
    usage: {_d: 12, _s: 1},
    delete:
        '"Reef" will be removed from 12 dives and 1 site. '
        'This cannot be undone.',
    bulk:
        'These tags will be removed from 12 dives and 1 site total. '
        'This cannot be undone.',
    merge: 'This will affect 12 dives and 1 site total.',
  ),
  (
    name: 'dives and equipment',
    usage: {_d: 1, _e: 2},
    delete:
        '"Reef" will be removed from 1 dive and 2 equipment items. '
        'This cannot be undone.',
    bulk:
        'These tags will be removed from 1 dive and 2 equipment items '
        'total. This cannot be undone.',
    merge: 'This will affect 1 dive and 2 equipment items total.',
  ),
  (
    name: 'sites and equipment',
    usage: {_s: 2, _e: 1},
    delete:
        '"Reef" will be removed from 2 sites and 1 equipment item. '
        'This cannot be undone.',
    bulk:
        'These tags will be removed from 2 sites and 1 equipment item '
        'total. This cannot be undone.',
    merge: 'This will affect 2 sites and 1 equipment item total.',
  ),
  (
    name: 'dives, sites and equipment',
    usage: {_d: 12, _s: 3, _e: 5},
    delete:
        '"Reef" will be removed from 12 dives, 3 sites and 5 equipment '
        'items. This cannot be undone.',
    bulk:
        'These tags will be removed from 12 dives, 3 sites and 5 '
        'equipment items total. This cannot be undone.',
    merge: 'This will affect 12 dives, 3 sites and 5 equipment items total.',
  ),
  (
    name: 'nothing',
    usage: {_d: 0, _s: 0, _e: 0},
    delete:
        '"Reef" is not used on any dives, sites or equipment. '
        'This cannot be undone.',
    bulk:
        'These tags are not used on any dives, sites or equipment. '
        'This cannot be undone.',
    merge: 'These tags are not used on any dives, sites or equipment.',
  ),
];

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('tagDeleteMessage', () {
    for (final c in _cases) {
      test('names ${c.name}', () {
        expect(tagDeleteMessage(l10n, 'Reef', c.usage), c.delete);
      });
    }
  });

  group('tagsBulkDeleteMessage', () {
    for (final c in _cases) {
      test('names ${c.name}', () {
        expect(tagsBulkDeleteMessage(l10n, c.usage), c.bulk);
      });
    }
  });

  group('tagsMergeAffectedMessage', () {
    for (final c in _cases) {
      test('names ${c.name}', () {
        expect(tagsMergeAffectedMessage(l10n, c.usage), c.merge);
      });
    }
  });

  test('each family gives every combination a message of its own', () {
    final families = <String Function(Map<TagScope, int>)>[
      (usage) => tagDeleteMessage(l10n, 'Reef', usage),
      (usage) => tagsBulkDeleteMessage(l10n, usage),
      (usage) => tagsMergeAffectedMessage(l10n, usage),
    ];
    for (final family in families) {
      expect(
        _cases.map((c) => family(c.usage)).toSet(),
        hasLength(_cases.length),
      );
    }
  });

  test('a scope missing from the usage map counts as zero', () {
    expect(
      tagDeleteMessage(l10n, 'Reef', const {}),
      '"Reef" is not used on any dives, sites or equipment. '
      'This cannot be undone.',
    );
    expect(
      tagsMergeAffectedMessage(l10n, const {_e: 5}),
      'This will affect 5 equipment items total.',
    );
  });

  group('tagUsageCounts', () {
    test('shows dives alone when nothing else carries the tag', () {
      expect(tagUsageCounts(l10n, const {_d: 12}), '12 dives');
    });

    test('adds sites when some carry the tag', () {
      expect(tagUsageCounts(l10n, const {_s: 3}), '0 dives, 3 sites');
    });

    test('adds equipment items when some carry the tag (#1942)', () {
      expect(
        tagUsageCounts(l10n, const {_e: 5}),
        '0 dives, 5 equipment items',
      );
      expect(
        tagUsageCounts(l10n, const {_d: 1, _e: 1}),
        '1 dive, 1 equipment item',
      );
    });

    test('lists every scope in registry order', () {
      expect(
        tagUsageCounts(l10n, const {_e: 5, _s: 3, _d: 12}),
        '12 dives, 3 sites, 5 equipment items',
      );
    });

    test('leaves out a zero site or equipment count', () {
      expect(tagUsageCounts(l10n, const {_d: 2, _s: 0, _e: 0}), '2 dives');
    });
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/features/tags/presentation/tag_usage_messages_test.dart`
Expected: FAIL, 17 of 31. It compiles (Task 3 added `TagScope.equipment`). Task 1's helpers switch on dives and sites only, so each family's four equipment cases get a dives, sites, dives-and-sites or unused message, the three `nothing` cases fail on "dives or sites", `each family gives every combination a message of its own` finds 7 distinct messages rather than 8, and the missing-scope test fails on its first expectation. The nine dives and sites cases and the five `tagUsageCounts` tests pass already: Task 1 generates the usage line from the registry, and Task 3 gave it the equipment count.

- [ ] **Step 3: Write the widget tests**

(a) Create `test/features/tags/presentation/pages/tag_manage_page_equipment_wording_test.dart` (real database, like `tag_manage_page_scope_test.dart`, so the required-scope error and the delete confirmation run end to end; Task 3's `tag_manage_page_equipment_scope_test.dart` already covers the row, checkboxes and narrowing):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/presentation/pages/tag_manage_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The equipment scope on the Tags management page (#1942), against a real
/// database so the usage line and the narrowing path run end to end.
void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;

  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
    );
    for (final id in ['e1', 'e2']) {
      await db.customStatement(
        'INSERT INTO equipment (id, name, type, created_at, updated_at) '
        "VALUES (?, ?, 'regulator', 0, 0)",
        [id, 'Gear $id'],
      );
    }
    await db.customStatement(
      'INSERT INTO tags (id, diver_id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites, applies_to_equipment) '
      "VALUES ('kit', 'diver-1', 'Travel kit', 0, 0, 0, 0, 1)",
    );
    await db.customStatement(
      'INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) '
      "VALUES ('et1', 'e1', 'kit', 0), ('et2', 'e2', 'kit', 0)",
    );
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });

  tearDown(() async => tearDownTestDatabase());

  Widget page() => ProviderScope(
    overrides: [
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TagManagePage(),
    ),
  );

  final useForEquipment = find.widgetWithText(
    CheckboxListTile,
    'Use for equipment',
  );

  Future<void> openEditor(WidgetTester tester) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag_edit_kit')));
    await tester.pumpAndSettle();
  }

  // The row, editor checkboxes and narrowing path for equipment are pinned
  // by Task 3's tag_manage_page_equipment_scope_test.dart. This file covers
  // only the wording Task 7 changes.

  testWidgets('unticking the only scope shows an error and saves nothing', (
    tester,
  ) async {
    await openEditor(tester);

    await tester.ensureVisible(useForEquipment);
    await tester.tap(useForEquipment);
    await tester.pumpAndSettle();

    const required = 'Choose at least one: dives, sites or equipment';
    expect(find.text(required), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text(required), findsOneWidget);
    final tag = await tester.runAsync(() async {
      final db = DatabaseService.instance.database;
      return db.select(db.tags).getSingle();
    });
    expect(tag!.appliesToEquipment, isTrue);
  });

  testWidgets('deleting from the editor names the equipment items', (
    tester,
  ) async {
    await openEditor(tester);

    await tester.tap(find.byKey(const ValueKey('tag_edit_delete')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '"Travel kit" will be removed from 2 equipment items. '
        'This cannot be undone.',
      ),
      findsOneWidget,
    );
  });
}
```

(b) In `test/features/tags/presentation/pages/tag_manage_page_scope_test.dart`, the two assertions at main lines 134 and 139 (in `unticking both scopes shows an error and does not save`) become:

```dart
    expect(
      find.text('Choose at least one: dives, sites or equipment'),
      findsOneWidget,
    );
```

(c) In `test/features/tags/presentation/pages/tag_manage_page_test.dart` (main line numbers; Task 1's edits shift the later ones by a few lines, so locate each point by name):

- Add `import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';` after the `dive_sites` provider import (main line 9).
- In `_buildRoutedTestWidget`, after the `/sites` route (main lines 183-187), add:

```dart
      GoRoute(
        path: '/equipment',
        builder: (context, state) =>
            const Scaffold(body: Text('EQUIPMENT_LIST_PAGE')),
      ),
```

- Add this helper after `_tagsFromStats` (main line 130):

```dart
/// A stat for a tag offered in [scopes] and used [counts] times per scope.
TagStatistic _scopedStat(
  String id,
  String name,
  Set<TagScope> scopes,
  Map<TagScope, int> counts,
) => TagStatistic(
  tag: Tag(
    id: id,
    diverId: 'diver1',
    name: name,
    colorHex: '#F97316',
    scopes: scopes,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  ),
  counts: counts,
);
```

- Add this group as the last statement of `main()` (after the `delete confirmations name sites as well as dives (#1902)` group, which closes at main line 1249):

```dart
  group('the equipment scope (#1942)', () {
    const d = TagScope.dives;
    const s = TagScope.sites;
    const e = TagScope.equipment;
    final kit = _scopedStat('kit', 'Travel kit', const {e}, const {e: 2});

    testWidgets('a row names every scope and its usage in each', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestWidget(
          stats: [
            _scopedStat('all', 'Everywhere', const {d, s, e}, const {
              d: 12,
              s: 3,
              e: 5,
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dives · Sites · Equipment'), findsOneWidget);
      expect(find.text('12 dives, 3 sites, 5 equipment items'), findsOneWidget);
    });

    testWidgets('an equipment tag row stays on the page', (tester) async {
      await tester.pumpWidget(_buildRoutedTestWidget(stats: [kit]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Travel kit'));
      await tester.pumpAndSettle();

      // Rows are inert outside selection (#1888), whatever the scope.
      expect(find.text('EQUIPMENT_LIST_PAGE'), findsNothing);
      expect(find.text('Edit Tag'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.text('Travel kit')),
      );
      expect(container.read(equipmentFilterProvider).tagIds, isEmpty);
    });

    testWidgets('a create can offer a tag for equipment only', (tester) async {
      final notifier = _MockTagListNotifier(_tagsFromStats(_testStats));
      await tester.pumpWidget(
        _buildTestWidget(stats: _testStats, notifier: notifier),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Rental');
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Use for dives'));
      final useForEquipment = find.widgetWithText(
        CheckboxListTile,
        'Use for equipment',
      );
      await tester.ensureVisible(useForEquipment);
      await tester.tap(useForEquipment);
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(notifier.added.single.scopes, {e});
    });

    testWidgets('widening a tag to equipment saves without asking', (
      tester,
    ) async {
      final notifier = _MockTagListNotifier(_tagsFromStats(_testStats));
      await tester.pumpWidget(
        _buildTestWidget(stats: _testStats, notifier: notifier),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tag_edit_tag1')));
      await tester.pumpAndSettle();
      final useForEquipment = find.widgetWithText(
        CheckboxListTile,
        'Use for equipment',
      );
      await tester.ensureVisible(useForEquipment);
      await tester.tap(useForEquipment);
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Remove tag from existing items?'), findsNothing);
      expect(notifier.updated.single.scopes, {d, e});
    });

    testWidgets('a bulk delete names dives, sites and equipment', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestWidget(
          stats: [..._testStats, kit],
          repository: _MockTagRepository(
            mergedUsage: const {d: 12, s: 3, e: 2},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Night Dive'));
      await tester.tap(find.text('Travel kit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_delete')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'These tags will be removed from 12 dives, 3 sites and 2 equipment '
          'items total. This cannot be undone.',
        ),
        findsOneWidget,
      );
    });
  });
```

(d) In `test/features/tags/presentation/widgets/tag_merge_sheet_test.dart`, add inside `group('TagMergeSheet', ...)` after its last test (main line 237):

```dart
    TagStatistic equipmentStat(String id, String name, int items) =>
        TagStatistic(
          tag: Tag(
            id: id,
            diverId: 'diver1',
            name: name,
            colorHex: '#F97316',
            scopes: const {TagScope.equipment},
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
          counts: {TagScope.equipment: items},
        );

    testWidgets('the preview names equipment too (#1942)', (tester) async {
      // mergeTags relinks equipment_tags as well, so the preview counts it.
      when(mockRepository.getMergedUsage(any)).thenAnswer(
        (_) async => const {TagScope.dives: 3, TagScope.equipment: 2},
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.text('This will affect 3 dives and 2 equipment items total.'),
        findsOneWidget,
      );
    });

    testWidgets('an equipment-only tag row shows its equipment (#1942)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          stats: [...testStats, equipmentStat('tag4', 'Travel kit', 4)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 dives, 4 equipment items'), findsOneWidget);
    });

    testWidgets('merging equipment-only tags starts from the one on the '
        'most items', (tester) async {
      // The less used tag comes first, so keeping the selection's order
      // (every dive count is 0) would seed the wrong name.
      await tester.pumpWidget(
        buildTestWidget(
          stats: [
            equipmentStat('rental', 'Rental', 1),
            equipmentStat('kit', 'Travel kit', 4),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'Travel kit');
    });
```

- [ ] **Step 4: Run them and confirm which fail**

Run each file on its own:
- `flutter test test/features/tags/presentation/pages/tag_manage_page_equipment_wording_test.dart`: Expected FAIL in both tests. `unticking the only scope shows an error and saves nothing` still finds "Choose dives, sites, or both", and `deleting from the editor names the equipment items` gets Task 1's unused message (its switch sees no dives or sites).
- `flutter test test/features/tags/presentation/pages/tag_manage_page_scope_test.dart`: Expected FAIL in `unticking both scopes shows an error and does not save` (the page still shows the old required line).
- `flutter test test/features/tags/presentation/pages/tag_manage_page_test.dart`: Expected FAIL in `a bulk delete names dives, sites and equipment` only (the dialog says "12 dives and 3 sites total"). The other four tests of `the equipment scope (#1942)` pass as pins.
- `flutter test test/features/tags/presentation/widgets/tag_merge_sheet_test.dart`: Expected FAIL in `the preview names equipment too (#1942)` ("This will affect 3 dives total.") and in the seeding test (the name field holds `Rental`). `an equipment-only tag row shows its equipment (#1942)` passes as a pin.

- [ ] **Step 5: Add and reword the English strings**

Edit `lib/l10n/arb/app_en.arb` with the Edit tool, locating each line by its key: Task 3 inserted `tags_manage_narrowDialog_equipment`, `tags_manage_scope_equipment`, `tags_manage_equipmentCount` and `tags_manage_useForEquipment` into this block, so main's line numbers are off by a few. The block is grouped by family, not sorted, so the new keys go beside their family, as #1933's did. None of the new plural keys has a `=0` branch: the helpers pick them only for a nonzero count, as with #1933's variants.

(a) The required line (main 12849). Replace:

```json
  "tags_manage_scopeRequired": "Choose dives, sites, or both",
```

with:

```json
  "tags_manage_scopeRequired": "Choose at least one: dives, sites or equipment",
```

(b) The single-delete family (main 12900). Replace:

```json
  "tags_manage_deleteMessage_unused": "\"{tagName}\" is not used on any dives or sites. This cannot be undone.",
```

with:

```json
  "tags_manage_deleteMessage_equipment": "\"{tagName}\" will be removed from {count, plural, =1{1 equipment item} other{{count} equipment items}}. This cannot be undone.",
  "@tags_manage_deleteMessage_equipment": {
    "placeholders": {
      "tagName": {
        "type": "String"
      },
      "count": {
        "type": "int"
      }
    }
  },
  "tags_manage_deleteMessage_divesAndEquipment": "\"{tagName}\" will be removed from {diveCount, plural, =1{1 dive} other{{diveCount} dives}} and {equipmentCount, plural, =1{1 equipment item} other{{equipmentCount} equipment items}}. This cannot be undone.",
  "@tags_manage_deleteMessage_divesAndEquipment": {
    "placeholders": {
      "tagName": {
        "type": "String"
      },
      "diveCount": {
        "type": "int"
      },
      "equipmentCount": {
        "type": "int"
      }
    }
  },
  "tags_manage_deleteMessage_sitesAndEquipment": "\"{tagName}\" will be removed from {siteCount, plural, =1{1 site} other{{siteCount} sites}} and {equipmentCount, plural, =1{1 equipment item} other{{equipmentCount} equipment items}}. This cannot be undone.",
  "@tags_manage_deleteMessage_sitesAndEquipment": {
    "placeholders": {
      "tagName": {
        "type": "String"
      },
      "siteCount": {
        "type": "int"
      },
      "equipmentCount": {
        "type": "int"
      }
    }
  },
  "tags_manage_deleteMessage_all": "\"{tagName}\" will be removed from {diveCount, plural, =1{1 dive} other{{diveCount} dives}}, {siteCount, plural, =1{1 site} other{{siteCount} sites}} and {equipmentCount, plural, =1{1 equipment item} other{{equipmentCount} equipment items}}. This cannot be undone.",
  "@tags_manage_deleteMessage_all": {
    "placeholders": {
      "tagName": {
        "type": "String"
      },
      "diveCount": {
        "type": "int"
      },
      "siteCount": {
        "type": "int"
      },
      "equipmentCount": {
        "type": "int"
      }
    }
  },
  "tags_manage_deleteMessage_unused": "\"{tagName}\" is not used on any dives, sites or equipment. This cannot be undone.",
```

(c) The bulk-delete family (main 12943). Replace:

```json
  "tags_manage_bulkDeleteMessage_unused": "These tags are not used on any dives or sites. This cannot be undone.",
```

with:

```json
  "tags_manage_bulkDeleteMessage_equipment": "These tags will be removed from {equipmentCount, plural, =1{1 equipment item} other{{equipmentCount} equipment items}} total. This cannot be undone.",
  "@tags_manage_bulkDeleteMessage_equipment": {
    "placeholders": {
      "equipmentCount": {
        "type": "int"
      }
    }
  },
  "tags_manage_bulkDeleteMessage_divesAndEquipment": "These tags will be removed from {diveCount, plural, =1{1 dive} other{{diveCount} dives}} and {equipmentCount, plural, =1{1 equipment item} other{{equipmentCount} equipment items}} total. This cannot be undone.",
  "@tags_manage_bulkDeleteMessage_divesAndEquipment": {
    "placeholders": {
      "diveCount": {
        "type": "int"
      },
      "equipmentCount": {
        "type": "int"
      }
    }
  },
  "tags_manage_bulkDeleteMessage_sitesAndEquipment": "These tags will be removed from {siteCount, plural, =1{1 site} other{{siteCount} sites}} and {equipmentCount, plural, =1{1 equipment item} other{{equipmentCount} equipment items}} total. This cannot be undone.",
  "@tags_manage_bulkDeleteMessage_sitesAndEquipment": {
    "placeholders": {
      "siteCount": {
        "type": "int"
      },
      "equipmentCount": {
        "type": "int"
      }
    }
  },
  "tags_manage_bulkDeleteMessage_all": "These tags will be removed from {diveCount, plural, =1{1 dive} other{{diveCount} dives}}, {siteCount, plural, =1{1 site} other{{siteCount} sites}} and {equipmentCount, plural, =1{1 equipment item} other{{equipmentCount} equipment items}} total. This cannot be undone.",
  "@tags_manage_bulkDeleteMessage_all": {
    "placeholders": {
      "diveCount": {
        "type": "int"
      },
      "siteCount": {
        "type": "int"
      },
      "equipmentCount": {
        "type": "int"
      }
    }
  },
  "tags_manage_bulkDeleteMessage_unused": "These tags are not used on any dives, sites or equipment. This cannot be undone.",
```

(d) The merge preview family (main 12981). Replace:

```json
  "tags_manage_mergeAffected_unused": "These tags are not used on any dives or sites.",
```

with:

```json
  "tags_manage_mergeAffected_equipment": "This will affect {count, plural, =1{1 equipment item} other{{count} equipment items}} total.",
  "@tags_manage_mergeAffected_equipment": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "tags_manage_mergeAffected_divesAndEquipment": "This will affect {diveCount, plural, =1{1 dive} other{{diveCount} dives}} and {equipmentCount, plural, =1{1 equipment item} other{{equipmentCount} equipment items}} total.",
  "@tags_manage_mergeAffected_divesAndEquipment": {
    "placeholders": {
      "diveCount": {
        "type": "int"
      },
      "equipmentCount": {
        "type": "int"
      }
    }
  },
  "tags_manage_mergeAffected_sitesAndEquipment": "This will affect {siteCount, plural, =1{1 site} other{{siteCount} sites}} and {equipmentCount, plural, =1{1 equipment item} other{{equipmentCount} equipment items}} total.",
  "@tags_manage_mergeAffected_sitesAndEquipment": {
    "placeholders": {
      "siteCount": {
        "type": "int"
      },
      "equipmentCount": {
        "type": "int"
      }
    }
  },
  "tags_manage_mergeAffected_all": "This will affect {diveCount, plural, =1{1 dive} other{{diveCount} dives}}, {siteCount, plural, =1{1 site} other{{siteCount} sites}} and {equipmentCount, plural, =1{1 equipment item} other{{equipmentCount} equipment items}} total.",
  "@tags_manage_mergeAffected_all": {
    "placeholders": {
      "diveCount": {
        "type": "int"
      },
      "siteCount": {
        "type": "int"
      },
      "equipmentCount": {
        "type": "int"
      }
    }
  },
  "tags_manage_mergeAffected_unused": "These tags are not used on any dives, sites or equipment.",
```

Then run `flutter gen-l10n` and check the signatures it generated in `lib/l10n/arb/app_localizations.dart`:
`grep -n "String tags_manage_deleteMessage_all\|String tags_manage_bulkDeleteMessage_all\|String tags_manage_mergeAffected_all" -A6 lib/l10n/arb/app_localizations.dart`
Expected: parameters in metadata order, `(String tagName, int diveCount, int siteCount, int equipmentCount)` for the delete one and `(int diveCount, int siteCount, int equipmentCount)` for the other two. gen-l10n reports the 12 new keys as untranslated in the ten locales until Step 9 adds them.

- [ ] **Step 6: The three-scope messages**

Replace the whole of `lib/features/tags/presentation/tag_usage_messages.dart` (Task 1's version) with the following. `tagUsageCounts` behaves exactly as Task 1's (dives always, every other scope when nonzero, registry order); only the three sentence families change.

```dart
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_scope_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Wording for what deleting or merging tags touches (#1902, #1942).
//
// A tag can be scoped to any mix of dives, sites and equipment, and deleting
// or merging it rewrites every item that carries it. Each message names only
// what is actually affected. Every combination is one whole ICU message
// rather than phrases joined here, so every locale controls its own word
// order and list punctuation.

/// [usage] as three counts. A scope missing from the map counts zero.
({int dives, int sites, int equipment}) _counts(Map<TagScope, int> usage) => (
  dives: usage[TagScope.dives] ?? 0,
  sites: usage[TagScope.sites] ?? 0,
  equipment: usage[TagScope.equipment] ?? 0,
);

/// The confirmation for deleting one tag.
String tagDeleteMessage(
  AppLocalizations l10n,
  String tagName,
  Map<TagScope, int> usage,
) {
  final (:dives, :sites, :equipment) = _counts(usage);
  return switch ((dives > 0, sites > 0, equipment > 0)) {
    (true, false, false) => l10n.tags_manage_deleteMessage(tagName, dives),
    (false, true, false) => l10n.tags_manage_deleteMessage_sites(
      tagName,
      sites,
    ),
    (false, false, true) => l10n.tags_manage_deleteMessage_equipment(
      tagName,
      equipment,
    ),
    (true, true, false) => l10n.tags_manage_deleteMessage_divesAndSites(
      tagName,
      dives,
      sites,
    ),
    (true, false, true) => l10n.tags_manage_deleteMessage_divesAndEquipment(
      tagName,
      dives,
      equipment,
    ),
    (false, true, true) => l10n.tags_manage_deleteMessage_sitesAndEquipment(
      tagName,
      sites,
      equipment,
    ),
    (true, true, true) => l10n.tags_manage_deleteMessage_all(
      tagName,
      dives,
      sites,
      equipment,
    ),
    (false, false, false) => l10n.tags_manage_deleteMessage_unused(tagName),
  };
}

/// The confirmation for deleting several tags. [usage] is the union across
/// the selection, so an item carrying two of them counts once.
String tagsBulkDeleteMessage(
  AppLocalizations l10n,
  Map<TagScope, int> usage,
) {
  final (:dives, :sites, :equipment) = _counts(usage);
  return switch ((dives > 0, sites > 0, equipment > 0)) {
    (true, false, false) => l10n.tags_manage_bulkDeleteMessage(dives),
    (false, true, false) => l10n.tags_manage_bulkDeleteMessage_sites(sites),
    (false, false, true) => l10n.tags_manage_bulkDeleteMessage_equipment(
      equipment,
    ),
    (true, true, false) => l10n.tags_manage_bulkDeleteMessage_divesAndSites(
      dives,
      sites,
    ),
    (true, false, true) =>
      l10n.tags_manage_bulkDeleteMessage_divesAndEquipment(dives, equipment),
    (false, true, true) =>
      l10n.tags_manage_bulkDeleteMessage_sitesAndEquipment(sites, equipment),
    (true, true, true) => l10n.tags_manage_bulkDeleteMessage_all(
      dives,
      sites,
      equipment,
    ),
    (false, false, false) => l10n.tags_manage_bulkDeleteMessage_unused,
  };
}

/// The merge sheet's preview of what a merge rewrites, counted as a union
/// like [tagsBulkDeleteMessage].
String tagsMergeAffectedMessage(
  AppLocalizations l10n,
  Map<TagScope, int> usage,
) {
  final (:dives, :sites, :equipment) = _counts(usage);
  return switch ((dives > 0, sites > 0, equipment > 0)) {
    (true, false, false) => l10n.tags_manage_mergeAffectedDives(dives),
    (false, true, false) => l10n.tags_manage_mergeAffected_sites(sites),
    (false, false, true) => l10n.tags_manage_mergeAffected_equipment(
      equipment,
    ),
    (true, true, false) => l10n.tags_manage_mergeAffected_divesAndSites(
      dives,
      sites,
    ),
    (true, false, true) => l10n.tags_manage_mergeAffected_divesAndEquipment(
      dives,
      equipment,
    ),
    (false, true, true) => l10n.tags_manage_mergeAffected_sitesAndEquipment(
      sites,
      equipment,
    ),
    (true, true, true) => l10n.tags_manage_mergeAffected_all(
      dives,
      sites,
      equipment,
    ),
    (false, false, false) => l10n.tags_manage_mergeAffected_unused,
  };
}

/// One tag's usage as a row subtitle: its dives always, then its sites and
/// equipment items when any carry it, in registry order ("12 dives, 3 sites,
/// 5 equipment items"). Shared by the Manage Tags list and the merge sheet.
String tagUsageCounts(AppLocalizations l10n, Map<TagScope, int> usage) => [
  for (final scope in TagScope.values)
    if (scope == TagScope.dives || (usage[scope] ?? 0) > 0)
      tagScopeCount(l10n, scope, usage[scope] ?? 0),
].join(', ');
```

- [ ] **Step 7: The merge sheet's seed**

In `lib/features/tags/presentation/widgets/tag_merge_sheet.dart`, replace the whole `_sortedStats` getter (main 31-35; after Task 1 its one comparison reads `b.count(TagScope.dives).compareTo(a.count(TagScope.dives))`) with:

```dart
  /// Most used first, in the Manage Tags list's order: dives, then sites,
  /// then equipment (#1942). The first one seeds the name and the color, so
  /// a merge of equipment-only tags starts from the one on the most items.
  List<TagStatistic> get _sortedStats {
    int byUse(TagStatistic a, TagStatistic b) {
      for (final scope in TagScope.values) {
        final order = b.count(scope).compareTo(a.count(scope));
        if (order != 0) return order;
      }
      return 0;
    }

    return [...widget.selectedStats]..sort(byUse);
  }
```

The file already imports `package:submersion/features/tags/domain/entities/tag.dart`. The row subtitle (`tagUsageCounts(context.l10n, stat.counts)`) and the preview (`tagsMergeAffectedMessage(context.l10n, affected)`) need no change after Task 1.

- [ ] **Step 8: Run the English tests**

Run, one at a time:
- `flutter test test/features/tags/presentation/tag_usage_messages_test.dart`: Expected PASS (31 tests).
- `flutter test test/features/tags/presentation/pages/tag_manage_page_equipment_wording_test.dart`
- `flutter test test/features/tags/presentation/pages/tag_manage_page_scope_test.dart`
- `flutter test test/features/tags/presentation/pages/tag_manage_page_test.dart`
- `flutter test test/features/tags/presentation/widgets/tag_merge_sheet_test.dart`

Expected: PASS. Then `flutter test test/features/tags/`: every test that pumps `TagManagePage` or `TagMergeSheet` or calls the helpers lives there (`grep -rl "TagManagePage\|TagMergeSheet\|tag_usage_messages" test/` lists only files under `test/features/tags/`). Expected: PASS.

- [ ] **Step 9: Translate into the ten locales**

Each of the ten non-English files gets the same four edits, made with the Edit tool and located by key. Verified on main: in all ten files each family's `_unused` line sits directly after its `_divesAndSites` line, and none of the ten carries `@` metadata, so every key is one line.

| Existing line | Replace it with |
| --- | --- |
| `tags_manage_bulkDeleteMessage_unused` | the block's five `tags_manage_bulkDeleteMessage_*` lines (the four new keys, then the reworded `_unused`) |
| `tags_manage_scopeRequired` | the block's `tags_manage_scopeRequired` line |
| `tags_manage_deleteMessage_unused` | the block's five `tags_manage_deleteMessage_*` lines |
| `tags_manage_mergeAffected_unused` | the block's five `tags_manage_mergeAffected_*` lines |

So each family reads `_divesAndSites`, the four new keys, then `_unused`. Each block below lists its lines in the table's order. Keep them byte for byte. Wording notes:
- Terms come from each locale's existing keys: the noun for one equipment item is the one `dataQuality_carries_gear` and `trips_serviceAlert_count` use (de Ausrüstungsteil, es equipo, fr équipement, he פריט ציוד, hu felszerelés, it attrezzatura, nl uitrustingsstuk, pt equipamento, zh 件装备, ar قطعة معدات); the scope words in `tags_manage_scopeRequired` are the locale's `tags_manage_scope_*` and `nav_equipment` words; the tag name keeps the quoting of the neighbouring `deleteMessage` lines (`\"{tagName}\"`, Chinese 「{tagName}」).
- Case follows #1933's sites variants: German dative after "von" (`Ausrüstungsteilen`) and accusative in the merge preview (`Ausrüstungsteile`); Hungarian `-ről`/`-ből` in the delete messages and accusative `-t` in the merge preview; Arabic genitive after من and على.
- Arabic uses its CLDR categories `one`, `two`, `few` (3 to 10), `many` (11 to 99) and `other` (100 and up) for every noun in these messages. Hebrew keeps `=1`/`other`, like #1933 (digits need no dual form).
- All three-scope messages join in the locale's list style: "A, B and C" in English; Chinese uses 、 then 和; Arabic and Hebrew repeat the conjunction and preposition (و…و…, מ-…, מ-… ומ-…).

`lib/l10n/arb/app_ar.arb` (Arabic):

```json
  "tags_manage_bulkDeleteMessage_equipment": "سيتم إزالة هذه الوسوم من {equipmentCount, plural, one{قطعة معدات واحدة} two{قطعتي معدات} few{{equipmentCount} قطع معدات} many{{equipmentCount} قطعة معدات} other{{equipmentCount} قطعة معدات}} إجمالاً. لا يمكن التراجع عن هذا الإجراء.",
  "tags_manage_bulkDeleteMessage_divesAndEquipment": "سيتم إزالة هذه الوسوم من {diveCount, plural, one{غوصة واحدة} two{غوصتين} few{{diveCount} غوصات} many{{diveCount} غوصة} other{{diveCount} غوصة}} و{equipmentCount, plural, one{قطعة معدات واحدة} two{قطعتي معدات} few{{equipmentCount} قطع معدات} many{{equipmentCount} قطعة معدات} other{{equipmentCount} قطعة معدات}} إجمالاً. لا يمكن التراجع عن هذا الإجراء.",
  "tags_manage_bulkDeleteMessage_sitesAndEquipment": "سيتم إزالة هذه الوسوم من {siteCount, plural, one{موقع واحد} two{موقعين} few{{siteCount} مواقع} many{{siteCount} موقعًا} other{{siteCount} موقع}} و{equipmentCount, plural, one{قطعة معدات واحدة} two{قطعتي معدات} few{{equipmentCount} قطع معدات} many{{equipmentCount} قطعة معدات} other{{equipmentCount} قطعة معدات}} إجمالاً. لا يمكن التراجع عن هذا الإجراء.",
  "tags_manage_bulkDeleteMessage_all": "سيتم إزالة هذه الوسوم من {diveCount, plural, one{غوصة واحدة} two{غوصتين} few{{diveCount} غوصات} many{{diveCount} غوصة} other{{diveCount} غوصة}} و{siteCount, plural, one{موقع واحد} two{موقعين} few{{siteCount} مواقع} many{{siteCount} موقعًا} other{{siteCount} موقع}} و{equipmentCount, plural, one{قطعة معدات واحدة} two{قطعتي معدات} few{{equipmentCount} قطع معدات} many{{equipmentCount} قطعة معدات} other{{equipmentCount} قطعة معدات}} إجمالاً. لا يمكن التراجع عن هذا الإجراء.",
  "tags_manage_bulkDeleteMessage_unused": "هذه الوسوم غير مستخدمة في أي غوصة أو موقع أو قطعة معدات. لا يمكن التراجع عن هذا الإجراء.",
  "tags_manage_scopeRequired": "اختر واحدًا على الأقل: الغوصات أو المواقع أو المعدات",
  "tags_manage_deleteMessage_equipment": "سيتم إزالة \"{tagName}\" من {count, plural, one{قطعة معدات واحدة} two{قطعتي معدات} few{{count} قطع معدات} many{{count} قطعة معدات} other{{count} قطعة معدات}}. لا يمكن التراجع عن هذا الإجراء.",
  "tags_manage_deleteMessage_divesAndEquipment": "سيتم إزالة \"{tagName}\" من {diveCount, plural, one{غوصة واحدة} two{غوصتين} few{{diveCount} غوصات} many{{diveCount} غوصة} other{{diveCount} غوصة}} و{equipmentCount, plural, one{قطعة معدات واحدة} two{قطعتي معدات} few{{equipmentCount} قطع معدات} many{{equipmentCount} قطعة معدات} other{{equipmentCount} قطعة معدات}}. لا يمكن التراجع عن هذا الإجراء.",
  "tags_manage_deleteMessage_sitesAndEquipment": "سيتم إزالة \"{tagName}\" من {siteCount, plural, one{موقع واحد} two{موقعين} few{{siteCount} مواقع} many{{siteCount} موقعًا} other{{siteCount} موقع}} و{equipmentCount, plural, one{قطعة معدات واحدة} two{قطعتي معدات} few{{equipmentCount} قطع معدات} many{{equipmentCount} قطعة معدات} other{{equipmentCount} قطعة معدات}}. لا يمكن التراجع عن هذا الإجراء.",
  "tags_manage_deleteMessage_all": "سيتم إزالة \"{tagName}\" من {diveCount, plural, one{غوصة واحدة} two{غوصتين} few{{diveCount} غوصات} many{{diveCount} غوصة} other{{diveCount} غوصة}} و{siteCount, plural, one{موقع واحد} two{موقعين} few{{siteCount} مواقع} many{{siteCount} موقعًا} other{{siteCount} موقع}} و{equipmentCount, plural, one{قطعة معدات واحدة} two{قطعتي معدات} few{{equipmentCount} قطع معدات} many{{equipmentCount} قطعة معدات} other{{equipmentCount} قطعة معدات}}. لا يمكن التراجع عن هذا الإجراء.",
  "tags_manage_deleteMessage_unused": "\"{tagName}\" غير مستخدم في أي غوصة أو موقع أو قطعة معدات. لا يمكن التراجع عن هذا الإجراء.",
  "tags_manage_mergeAffected_equipment": "سيؤثر هذا على {count, plural, one{قطعة معدات واحدة} two{قطعتي معدات} few{{count} قطع معدات} many{{count} قطعة معدات} other{{count} قطعة معدات}} إجمالاً.",
  "tags_manage_mergeAffected_divesAndEquipment": "سيؤثر هذا على {diveCount, plural, one{غوصة واحدة} two{غوصتين} few{{diveCount} غوصات} many{{diveCount} غوصة} other{{diveCount} غوصة}} و{equipmentCount, plural, one{قطعة معدات واحدة} two{قطعتي معدات} few{{equipmentCount} قطع معدات} many{{equipmentCount} قطعة معدات} other{{equipmentCount} قطعة معدات}} إجمالاً.",
  "tags_manage_mergeAffected_sitesAndEquipment": "سيؤثر هذا على {siteCount, plural, one{موقع واحد} two{موقعين} few{{siteCount} مواقع} many{{siteCount} موقعًا} other{{siteCount} موقع}} و{equipmentCount, plural, one{قطعة معدات واحدة} two{قطعتي معدات} few{{equipmentCount} قطع معدات} many{{equipmentCount} قطعة معدات} other{{equipmentCount} قطعة معدات}} إجمالاً.",
  "tags_manage_mergeAffected_all": "سيؤثر هذا على {diveCount, plural, one{غوصة واحدة} two{غوصتين} few{{diveCount} غوصات} many{{diveCount} غوصة} other{{diveCount} غوصة}} و{siteCount, plural, one{موقع واحد} two{موقعين} few{{siteCount} مواقع} many{{siteCount} موقعًا} other{{siteCount} موقع}} و{equipmentCount, plural, one{قطعة معدات واحدة} two{قطعتي معدات} few{{equipmentCount} قطع معدات} many{{equipmentCount} قطعة معدات} other{{equipmentCount} قطعة معدات}} إجمالاً.",
  "tags_manage_mergeAffected_unused": "هذه الوسوم غير مستخدمة في أي غوصة أو موقع أو قطعة معدات.",
```

`lib/l10n/arb/app_de.arb` (German):

```json
  "tags_manage_bulkDeleteMessage_equipment": "Diese Tags werden von insgesamt {equipmentCount, plural, =1{1 Ausrüstungsteil} other{{equipmentCount} Ausrüstungsteilen}} entfernt. Dies kann nicht rückgängig gemacht werden.",
  "tags_manage_bulkDeleteMessage_divesAndEquipment": "Diese Tags werden von insgesamt {diveCount, plural, =1{1 Tauchgang} other{{diveCount} Tauchgängen}} und {equipmentCount, plural, =1{1 Ausrüstungsteil} other{{equipmentCount} Ausrüstungsteilen}} entfernt. Dies kann nicht rückgängig gemacht werden.",
  "tags_manage_bulkDeleteMessage_sitesAndEquipment": "Diese Tags werden von insgesamt {siteCount, plural, =1{1 Tauchplatz} other{{siteCount} Tauchplätzen}} und {equipmentCount, plural, =1{1 Ausrüstungsteil} other{{equipmentCount} Ausrüstungsteilen}} entfernt. Dies kann nicht rückgängig gemacht werden.",
  "tags_manage_bulkDeleteMessage_all": "Diese Tags werden von insgesamt {diveCount, plural, =1{1 Tauchgang} other{{diveCount} Tauchgängen}}, {siteCount, plural, =1{1 Tauchplatz} other{{siteCount} Tauchplätzen}} und {equipmentCount, plural, =1{1 Ausrüstungsteil} other{{equipmentCount} Ausrüstungsteilen}} entfernt. Dies kann nicht rückgängig gemacht werden.",
  "tags_manage_bulkDeleteMessage_unused": "Diese Tags werden bei keinem Tauchgang, keinem Tauchplatz und keinem Ausrüstungsteil verwendet. Dies kann nicht rückgängig gemacht werden.",
  "tags_manage_scopeRequired": "Mindestens eines wählen: Tauchgänge, Tauchplätze oder Ausrüstung",
  "tags_manage_deleteMessage_equipment": "\"{tagName}\" wird von {count, plural, =1{1 Ausrüstungsteil} other{{count} Ausrüstungsteilen}} entfernt. Dies kann nicht rückgängig gemacht werden.",
  "tags_manage_deleteMessage_divesAndEquipment": "\"{tagName}\" wird von {diveCount, plural, =1{1 Tauchgang} other{{diveCount} Tauchgängen}} und {equipmentCount, plural, =1{1 Ausrüstungsteil} other{{equipmentCount} Ausrüstungsteilen}} entfernt. Dies kann nicht rückgängig gemacht werden.",
  "tags_manage_deleteMessage_sitesAndEquipment": "\"{tagName}\" wird von {siteCount, plural, =1{1 Tauchplatz} other{{siteCount} Tauchplätzen}} und {equipmentCount, plural, =1{1 Ausrüstungsteil} other{{equipmentCount} Ausrüstungsteilen}} entfernt. Dies kann nicht rückgängig gemacht werden.",
  "tags_manage_deleteMessage_all": "\"{tagName}\" wird von {diveCount, plural, =1{1 Tauchgang} other{{diveCount} Tauchgängen}}, {siteCount, plural, =1{1 Tauchplatz} other{{siteCount} Tauchplätzen}} und {equipmentCount, plural, =1{1 Ausrüstungsteil} other{{equipmentCount} Ausrüstungsteilen}} entfernt. Dies kann nicht rückgängig gemacht werden.",
  "tags_manage_deleteMessage_unused": "\"{tagName}\" wird bei keinem Tauchgang, keinem Tauchplatz und keinem Ausrüstungsteil verwendet. Dies kann nicht rückgängig gemacht werden.",
  "tags_manage_mergeAffected_equipment": "Dies betrifft insgesamt {count, plural, =1{1 Ausrüstungsteil} other{{count} Ausrüstungsteile}}.",
  "tags_manage_mergeAffected_divesAndEquipment": "Dies betrifft insgesamt {diveCount, plural, =1{1 Tauchgang} other{{diveCount} Tauchgänge}} und {equipmentCount, plural, =1{1 Ausrüstungsteil} other{{equipmentCount} Ausrüstungsteile}}.",
  "tags_manage_mergeAffected_sitesAndEquipment": "Dies betrifft insgesamt {siteCount, plural, =1{1 Tauchplatz} other{{siteCount} Tauchplätze}} und {equipmentCount, plural, =1{1 Ausrüstungsteil} other{{equipmentCount} Ausrüstungsteile}}.",
  "tags_manage_mergeAffected_all": "Dies betrifft insgesamt {diveCount, plural, =1{1 Tauchgang} other{{diveCount} Tauchgänge}}, {siteCount, plural, =1{1 Tauchplatz} other{{siteCount} Tauchplätze}} und {equipmentCount, plural, =1{1 Ausrüstungsteil} other{{equipmentCount} Ausrüstungsteile}}.",
  "tags_manage_mergeAffected_unused": "Diese Tags werden bei keinem Tauchgang, keinem Tauchplatz und keinem Ausrüstungsteil verwendet.",
```

`lib/l10n/arb/app_es.arb` (Spanish):

```json
  "tags_manage_bulkDeleteMessage_equipment": "Estas etiquetas se eliminarán de {equipmentCount, plural, =1{1 equipo} other{{equipmentCount} equipos}} en total. Esta acción no se puede deshacer.",
  "tags_manage_bulkDeleteMessage_divesAndEquipment": "Estas etiquetas se eliminarán de {diveCount, plural, =1{1 inmersión} other{{diveCount} inmersiones}} y {equipmentCount, plural, =1{1 equipo} other{{equipmentCount} equipos}} en total. Esta acción no se puede deshacer.",
  "tags_manage_bulkDeleteMessage_sitesAndEquipment": "Estas etiquetas se eliminarán de {siteCount, plural, =1{1 punto} other{{siteCount} puntos}} y {equipmentCount, plural, =1{1 equipo} other{{equipmentCount} equipos}} en total. Esta acción no se puede deshacer.",
  "tags_manage_bulkDeleteMessage_all": "Estas etiquetas se eliminarán de {diveCount, plural, =1{1 inmersión} other{{diveCount} inmersiones}}, {siteCount, plural, =1{1 punto} other{{siteCount} puntos}} y {equipmentCount, plural, =1{1 equipo} other{{equipmentCount} equipos}} en total. Esta acción no se puede deshacer.",
  "tags_manage_bulkDeleteMessage_unused": "Estas etiquetas no se usan en ninguna inmersión, ningún punto ni ningún equipo. Esta acción no se puede deshacer.",
  "tags_manage_scopeRequired": "Elige al menos uno: inmersiones, puntos o equipo",
  "tags_manage_deleteMessage_equipment": "\"{tagName}\" se eliminará de {count, plural, =1{1 equipo} other{{count} equipos}}. Esta acción no se puede deshacer.",
  "tags_manage_deleteMessage_divesAndEquipment": "\"{tagName}\" se eliminará de {diveCount, plural, =1{1 inmersión} other{{diveCount} inmersiones}} y {equipmentCount, plural, =1{1 equipo} other{{equipmentCount} equipos}}. Esta acción no se puede deshacer.",
  "tags_manage_deleteMessage_sitesAndEquipment": "\"{tagName}\" se eliminará de {siteCount, plural, =1{1 punto} other{{siteCount} puntos}} y {equipmentCount, plural, =1{1 equipo} other{{equipmentCount} equipos}}. Esta acción no se puede deshacer.",
  "tags_manage_deleteMessage_all": "\"{tagName}\" se eliminará de {diveCount, plural, =1{1 inmersión} other{{diveCount} inmersiones}}, {siteCount, plural, =1{1 punto} other{{siteCount} puntos}} y {equipmentCount, plural, =1{1 equipo} other{{equipmentCount} equipos}}. Esta acción no se puede deshacer.",
  "tags_manage_deleteMessage_unused": "\"{tagName}\" no se usa en ninguna inmersión, ningún punto ni ningún equipo. Esta acción no se puede deshacer.",
  "tags_manage_mergeAffected_equipment": "Esto afectará a {count, plural, =1{1 equipo} other{{count} equipos}} en total.",
  "tags_manage_mergeAffected_divesAndEquipment": "Esto afectará a {diveCount, plural, =1{1 inmersión} other{{diveCount} inmersiones}} y {equipmentCount, plural, =1{1 equipo} other{{equipmentCount} equipos}} en total.",
  "tags_manage_mergeAffected_sitesAndEquipment": "Esto afectará a {siteCount, plural, =1{1 punto} other{{siteCount} puntos}} y {equipmentCount, plural, =1{1 equipo} other{{equipmentCount} equipos}} en total.",
  "tags_manage_mergeAffected_all": "Esto afectará a {diveCount, plural, =1{1 inmersión} other{{diveCount} inmersiones}}, {siteCount, plural, =1{1 punto} other{{siteCount} puntos}} y {equipmentCount, plural, =1{1 equipo} other{{equipmentCount} equipos}} en total.",
  "tags_manage_mergeAffected_unused": "Estas etiquetas no se usan en ninguna inmersión, ningún punto ni ningún equipo.",
```

`lib/l10n/arb/app_fr.arb` (French):

```json
  "tags_manage_bulkDeleteMessage_equipment": "Ces étiquettes seront retirées de {equipmentCount, plural, =1{1 équipement} other{{equipmentCount} équipements}} au total. Cette action est irréversible.",
  "tags_manage_bulkDeleteMessage_divesAndEquipment": "Ces étiquettes seront retirées de {diveCount, plural, =1{1 plongée} other{{diveCount} plongées}} et de {equipmentCount, plural, =1{1 équipement} other{{equipmentCount} équipements}} au total. Cette action est irréversible.",
  "tags_manage_bulkDeleteMessage_sitesAndEquipment": "Ces étiquettes seront retirées de {siteCount, plural, =1{1 site} other{{siteCount} sites}} et de {equipmentCount, plural, =1{1 équipement} other{{equipmentCount} équipements}} au total. Cette action est irréversible.",
  "tags_manage_bulkDeleteMessage_all": "Ces étiquettes seront retirées de {diveCount, plural, =1{1 plongée} other{{diveCount} plongées}}, de {siteCount, plural, =1{1 site} other{{siteCount} sites}} et de {equipmentCount, plural, =1{1 équipement} other{{equipmentCount} équipements}} au total. Cette action est irréversible.",
  "tags_manage_bulkDeleteMessage_unused": "Ces étiquettes ne sont utilisées sur aucune plongée, aucun site ni aucun équipement. Cette action est irréversible.",
  "tags_manage_scopeRequired": "Choisissez au moins une option : plongées, sites ou équipement",
  "tags_manage_deleteMessage_equipment": "\"{tagName}\" sera retirée de {count, plural, =1{1 équipement} other{{count} équipements}}. Cette action est irréversible.",
  "tags_manage_deleteMessage_divesAndEquipment": "\"{tagName}\" sera retirée de {diveCount, plural, =1{1 plongée} other{{diveCount} plongées}} et de {equipmentCount, plural, =1{1 équipement} other{{equipmentCount} équipements}}. Cette action est irréversible.",
  "tags_manage_deleteMessage_sitesAndEquipment": "\"{tagName}\" sera retirée de {siteCount, plural, =1{1 site} other{{siteCount} sites}} et de {equipmentCount, plural, =1{1 équipement} other{{equipmentCount} équipements}}. Cette action est irréversible.",
  "tags_manage_deleteMessage_all": "\"{tagName}\" sera retirée de {diveCount, plural, =1{1 plongée} other{{diveCount} plongées}}, de {siteCount, plural, =1{1 site} other{{siteCount} sites}} et de {equipmentCount, plural, =1{1 équipement} other{{equipmentCount} équipements}}. Cette action est irréversible.",
  "tags_manage_deleteMessage_unused": "\"{tagName}\" n'est utilisée sur aucune plongée, aucun site ni aucun équipement. Cette action est irréversible.",
  "tags_manage_mergeAffected_equipment": "Cela affectera {count, plural, =1{1 équipement} other{{count} équipements}} au total.",
  "tags_manage_mergeAffected_divesAndEquipment": "Cela affectera {diveCount, plural, =1{1 plongée} other{{diveCount} plongées}} et {equipmentCount, plural, =1{1 équipement} other{{equipmentCount} équipements}} au total.",
  "tags_manage_mergeAffected_sitesAndEquipment": "Cela affectera {siteCount, plural, =1{1 site} other{{siteCount} sites}} et {equipmentCount, plural, =1{1 équipement} other{{equipmentCount} équipements}} au total.",
  "tags_manage_mergeAffected_all": "Cela affectera {diveCount, plural, =1{1 plongée} other{{diveCount} plongées}}, {siteCount, plural, =1{1 site} other{{siteCount} sites}} et {equipmentCount, plural, =1{1 équipement} other{{equipmentCount} équipements}} au total.",
  "tags_manage_mergeAffected_unused": "Ces étiquettes ne sont utilisées sur aucune plongée, aucun site ni aucun équipement.",
```

`lib/l10n/arb/app_he.arb` (Hebrew):

```json
  "tags_manage_bulkDeleteMessage_equipment": "תגיות אלו יוסרו מ-{equipmentCount, plural, =1{פריט ציוד אחד} other{{equipmentCount} פריטי ציוד}} בסך הכל. לא ניתן לבטל פעולה זו.",
  "tags_manage_bulkDeleteMessage_divesAndEquipment": "תגיות אלו יוסרו מ-{diveCount, plural, =1{צלילה אחת} other{{diveCount} צלילות}} ומ-{equipmentCount, plural, =1{פריט ציוד אחד} other{{equipmentCount} פריטי ציוד}} בסך הכל. לא ניתן לבטל פעולה זו.",
  "tags_manage_bulkDeleteMessage_sitesAndEquipment": "תגיות אלו יוסרו מ-{siteCount, plural, =1{אתר אחד} other{{siteCount} אתרים}} ומ-{equipmentCount, plural, =1{פריט ציוד אחד} other{{equipmentCount} פריטי ציוד}} בסך הכל. לא ניתן לבטל פעולה זו.",
  "tags_manage_bulkDeleteMessage_all": "תגיות אלו יוסרו מ-{diveCount, plural, =1{צלילה אחת} other{{diveCount} צלילות}}, מ-{siteCount, plural, =1{אתר אחד} other{{siteCount} אתרים}} ומ-{equipmentCount, plural, =1{פריט ציוד אחד} other{{equipmentCount} פריטי ציוד}} בסך הכל. לא ניתן לבטל פעולה זו.",
  "tags_manage_bulkDeleteMessage_unused": "תגיות אלו אינן בשימוש באף צלילה, אתר או פריט ציוד. לא ניתן לבטל פעולה זו.",
  "tags_manage_scopeRequired": "בחר לפחות אחד: צלילות, אתרים או ציוד",
  "tags_manage_deleteMessage_equipment": "\"{tagName}\" תוסר מ-{count, plural, =1{פריט ציוד אחד} other{{count} פריטי ציוד}}. לא ניתן לבטל פעולה זו.",
  "tags_manage_deleteMessage_divesAndEquipment": "\"{tagName}\" תוסר מ-{diveCount, plural, =1{צלילה אחת} other{{diveCount} צלילות}} ומ-{equipmentCount, plural, =1{פריט ציוד אחד} other{{equipmentCount} פריטי ציוד}}. לא ניתן לבטל פעולה זו.",
  "tags_manage_deleteMessage_sitesAndEquipment": "\"{tagName}\" תוסר מ-{siteCount, plural, =1{אתר אחד} other{{siteCount} אתרים}} ומ-{equipmentCount, plural, =1{פריט ציוד אחד} other{{equipmentCount} פריטי ציוד}}. לא ניתן לבטל פעולה זו.",
  "tags_manage_deleteMessage_all": "\"{tagName}\" תוסר מ-{diveCount, plural, =1{צלילה אחת} other{{diveCount} צלילות}}, מ-{siteCount, plural, =1{אתר אחד} other{{siteCount} אתרים}} ומ-{equipmentCount, plural, =1{פריט ציוד אחד} other{{equipmentCount} פריטי ציוד}}. לא ניתן לבטל פעולה זו.",
  "tags_manage_deleteMessage_unused": "\"{tagName}\" אינה בשימוש באף צלילה, אתר או פריט ציוד. לא ניתן לבטל פעולה זו.",
  "tags_manage_mergeAffected_equipment": "פעולה זו תשפיע על {count, plural, =1{פריט ציוד אחד} other{{count} פריטי ציוד}} בסך הכל.",
  "tags_manage_mergeAffected_divesAndEquipment": "פעולה זו תשפיע על {diveCount, plural, =1{צלילה אחת} other{{diveCount} צלילות}} ועל {equipmentCount, plural, =1{פריט ציוד אחד} other{{equipmentCount} פריטי ציוד}} בסך הכל.",
  "tags_manage_mergeAffected_sitesAndEquipment": "פעולה זו תשפיע על {siteCount, plural, =1{אתר אחד} other{{siteCount} אתרים}} ועל {equipmentCount, plural, =1{פריט ציוד אחד} other{{equipmentCount} פריטי ציוד}} בסך הכל.",
  "tags_manage_mergeAffected_all": "פעולה זו תשפיע על {diveCount, plural, =1{צלילה אחת} other{{diveCount} צלילות}}, על {siteCount, plural, =1{אתר אחד} other{{siteCount} אתרים}} ועל {equipmentCount, plural, =1{פריט ציוד אחד} other{{equipmentCount} פריטי ציוד}} בסך הכל.",
  "tags_manage_mergeAffected_unused": "תגיות אלו אינן בשימוש באף צלילה, אתר או פריט ציוד.",
```

`lib/l10n/arb/app_hu.arb` (Hungarian):

```json
  "tags_manage_bulkDeleteMessage_equipment": "Ezek a címkék eltávolításra kerülnek összesen {equipmentCount, plural, =1{1 felszerelésről} other{{equipmentCount} felszerelésről}}. Ez nem vonható vissza.",
  "tags_manage_bulkDeleteMessage_divesAndEquipment": "Ezek a címkék eltávolításra kerülnek összesen {diveCount, plural, =1{1 merülésből} other{{diveCount} merülésből}} és {equipmentCount, plural, =1{1 felszerelésről} other{{equipmentCount} felszerelésről}}. Ez nem vonható vissza.",
  "tags_manage_bulkDeleteMessage_sitesAndEquipment": "Ezek a címkék eltávolításra kerülnek összesen {siteCount, plural, =1{1 merülőhelyről} other{{siteCount} merülőhelyről}} és {equipmentCount, plural, =1{1 felszerelésről} other{{equipmentCount} felszerelésről}}. Ez nem vonható vissza.",
  "tags_manage_bulkDeleteMessage_all": "Ezek a címkék eltávolításra kerülnek összesen {diveCount, plural, =1{1 merülésből} other{{diveCount} merülésből}}, {siteCount, plural, =1{1 merülőhelyről} other{{siteCount} merülőhelyről}} és {equipmentCount, plural, =1{1 felszerelésről} other{{equipmentCount} felszerelésről}}. Ez nem vonható vissza.",
  "tags_manage_bulkDeleteMessage_unused": "Ezek a címkék egyetlen merülésen, merülőhelyen és felszerelésen sincsenek használatban. Ez nem vonható vissza.",
  "tags_manage_scopeRequired": "Válasszon legalább egyet: merülések, merülőhelyek vagy felszerelés",
  "tags_manage_deleteMessage_equipment": "A(z) \"{tagName}\" eltávolításra kerül {count, plural, =1{1 felszerelésről} other{{count} felszerelésről}}. Ez nem vonható vissza.",
  "tags_manage_deleteMessage_divesAndEquipment": "A(z) \"{tagName}\" eltávolításra kerül {diveCount, plural, =1{1 merülésből} other{{diveCount} merülésből}} és {equipmentCount, plural, =1{1 felszerelésről} other{{equipmentCount} felszerelésről}}. Ez nem vonható vissza.",
  "tags_manage_deleteMessage_sitesAndEquipment": "A(z) \"{tagName}\" eltávolításra kerül {siteCount, plural, =1{1 merülőhelyről} other{{siteCount} merülőhelyről}} és {equipmentCount, plural, =1{1 felszerelésről} other{{equipmentCount} felszerelésről}}. Ez nem vonható vissza.",
  "tags_manage_deleteMessage_all": "A(z) \"{tagName}\" eltávolításra kerül {diveCount, plural, =1{1 merülésből} other{{diveCount} merülésből}}, {siteCount, plural, =1{1 merülőhelyről} other{{siteCount} merülőhelyről}} és {equipmentCount, plural, =1{1 felszerelésről} other{{equipmentCount} felszerelésről}}. Ez nem vonható vissza.",
  "tags_manage_deleteMessage_unused": "A(z) \"{tagName}\" egyetlen merülésen, merülőhelyen és felszerelésen sincs használatban. Ez nem vonható vissza.",
  "tags_manage_mergeAffected_equipment": "Ez összesen {count, plural, =1{1 felszerelést} other{{count} felszerelést}} érint.",
  "tags_manage_mergeAffected_divesAndEquipment": "Ez összesen {diveCount, plural, =1{1 merülést} other{{diveCount} merülést}} és {equipmentCount, plural, =1{1 felszerelést} other{{equipmentCount} felszerelést}} érint.",
  "tags_manage_mergeAffected_sitesAndEquipment": "Ez összesen {siteCount, plural, =1{1 merülőhelyet} other{{siteCount} merülőhelyet}} és {equipmentCount, plural, =1{1 felszerelést} other{{equipmentCount} felszerelést}} érint.",
  "tags_manage_mergeAffected_all": "Ez összesen {diveCount, plural, =1{1 merülést} other{{diveCount} merülést}}, {siteCount, plural, =1{1 merülőhelyet} other{{siteCount} merülőhelyet}} és {equipmentCount, plural, =1{1 felszerelést} other{{equipmentCount} felszerelést}} érint.",
  "tags_manage_mergeAffected_unused": "Ezek a címkék egyetlen merülésen, merülőhelyen és felszerelésen sincsenek használatban.",
```

`lib/l10n/arb/app_it.arb` (Italian):

```json
  "tags_manage_bulkDeleteMessage_equipment": "Questi tag verranno rimossi da {equipmentCount, plural, =1{1 attrezzatura} other{{equipmentCount} attrezzature}} in totale. Questa azione non può essere annullata.",
  "tags_manage_bulkDeleteMessage_divesAndEquipment": "Questi tag verranno rimossi da {diveCount, plural, =1{1 immersione} other{{diveCount} immersioni}} e {equipmentCount, plural, =1{1 attrezzatura} other{{equipmentCount} attrezzature}} in totale. Questa azione non può essere annullata.",
  "tags_manage_bulkDeleteMessage_sitesAndEquipment": "Questi tag verranno rimossi da {siteCount, plural, =1{1 sito} other{{siteCount} siti}} e {equipmentCount, plural, =1{1 attrezzatura} other{{equipmentCount} attrezzature}} in totale. Questa azione non può essere annullata.",
  "tags_manage_bulkDeleteMessage_all": "Questi tag verranno rimossi da {diveCount, plural, =1{1 immersione} other{{diveCount} immersioni}}, {siteCount, plural, =1{1 sito} other{{siteCount} siti}} e {equipmentCount, plural, =1{1 attrezzatura} other{{equipmentCount} attrezzature}} in totale. Questa azione non può essere annullata.",
  "tags_manage_bulkDeleteMessage_unused": "Questi tag non sono usati in nessuna immersione, in nessun sito né in nessuna attrezzatura. Questa azione non può essere annullata.",
  "tags_manage_scopeRequired": "Scegli almeno uno tra immersioni, siti o attrezzatura",
  "tags_manage_deleteMessage_equipment": "\"{tagName}\" verrà rimosso da {count, plural, =1{1 attrezzatura} other{{count} attrezzature}}. Questa azione non può essere annullata.",
  "tags_manage_deleteMessage_divesAndEquipment": "\"{tagName}\" verrà rimosso da {diveCount, plural, =1{1 immersione} other{{diveCount} immersioni}} e {equipmentCount, plural, =1{1 attrezzatura} other{{equipmentCount} attrezzature}}. Questa azione non può essere annullata.",
  "tags_manage_deleteMessage_sitesAndEquipment": "\"{tagName}\" verrà rimosso da {siteCount, plural, =1{1 sito} other{{siteCount} siti}} e {equipmentCount, plural, =1{1 attrezzatura} other{{equipmentCount} attrezzature}}. Questa azione non può essere annullata.",
  "tags_manage_deleteMessage_all": "\"{tagName}\" verrà rimosso da {diveCount, plural, =1{1 immersione} other{{diveCount} immersioni}}, {siteCount, plural, =1{1 sito} other{{siteCount} siti}} e {equipmentCount, plural, =1{1 attrezzatura} other{{equipmentCount} attrezzature}}. Questa azione non può essere annullata.",
  "tags_manage_deleteMessage_unused": "\"{tagName}\" non è usato in nessuna immersione, in nessun sito né in nessuna attrezzatura. Questa azione non può essere annullata.",
  "tags_manage_mergeAffected_equipment": "Questo influenzerà {count, plural, =1{1 attrezzatura} other{{count} attrezzature}} in totale.",
  "tags_manage_mergeAffected_divesAndEquipment": "Questo influenzerà {diveCount, plural, =1{1 immersione} other{{diveCount} immersioni}} e {equipmentCount, plural, =1{1 attrezzatura} other{{equipmentCount} attrezzature}} in totale.",
  "tags_manage_mergeAffected_sitesAndEquipment": "Questo influenzerà {siteCount, plural, =1{1 sito} other{{siteCount} siti}} e {equipmentCount, plural, =1{1 attrezzatura} other{{equipmentCount} attrezzature}} in totale.",
  "tags_manage_mergeAffected_all": "Questo influenzerà {diveCount, plural, =1{1 immersione} other{{diveCount} immersioni}}, {siteCount, plural, =1{1 sito} other{{siteCount} siti}} e {equipmentCount, plural, =1{1 attrezzatura} other{{equipmentCount} attrezzature}} in totale.",
  "tags_manage_mergeAffected_unused": "Questi tag non sono usati in nessuna immersione, in nessun sito né in nessuna attrezzatura.",
```

`lib/l10n/arb/app_nl.arb` (Dutch):

```json
  "tags_manage_bulkDeleteMessage_equipment": "Deze tags worden verwijderd van in totaal {equipmentCount, plural, =1{1 uitrustingsstuk} other{{equipmentCount} uitrustingsstukken}}. Dit kan niet ongedaan worden gemaakt.",
  "tags_manage_bulkDeleteMessage_divesAndEquipment": "Deze tags worden verwijderd van in totaal {diveCount, plural, =1{1 duik} other{{diveCount} duiken}} en {equipmentCount, plural, =1{1 uitrustingsstuk} other{{equipmentCount} uitrustingsstukken}}. Dit kan niet ongedaan worden gemaakt.",
  "tags_manage_bulkDeleteMessage_sitesAndEquipment": "Deze tags worden verwijderd van in totaal {siteCount, plural, =1{1 duikstek} other{{siteCount} duikstekken}} en {equipmentCount, plural, =1{1 uitrustingsstuk} other{{equipmentCount} uitrustingsstukken}}. Dit kan niet ongedaan worden gemaakt.",
  "tags_manage_bulkDeleteMessage_all": "Deze tags worden verwijderd van in totaal {diveCount, plural, =1{1 duik} other{{diveCount} duiken}}, {siteCount, plural, =1{1 duikstek} other{{siteCount} duikstekken}} en {equipmentCount, plural, =1{1 uitrustingsstuk} other{{equipmentCount} uitrustingsstukken}}. Dit kan niet ongedaan worden gemaakt.",
  "tags_manage_bulkDeleteMessage_unused": "Deze tags worden bij geen enkele duik, duikstek of uitrustingsstuk gebruikt. Dit kan niet ongedaan worden gemaakt.",
  "tags_manage_scopeRequired": "Kies ten minste één: duiken, duikstekken of uitrusting",
  "tags_manage_deleteMessage_equipment": "\"{tagName}\" wordt verwijderd van {count, plural, =1{1 uitrustingsstuk} other{{count} uitrustingsstukken}}. Dit kan niet ongedaan worden gemaakt.",
  "tags_manage_deleteMessage_divesAndEquipment": "\"{tagName}\" wordt verwijderd van {diveCount, plural, =1{1 duik} other{{diveCount} duiken}} en {equipmentCount, plural, =1{1 uitrustingsstuk} other{{equipmentCount} uitrustingsstukken}}. Dit kan niet ongedaan worden gemaakt.",
  "tags_manage_deleteMessage_sitesAndEquipment": "\"{tagName}\" wordt verwijderd van {siteCount, plural, =1{1 duikstek} other{{siteCount} duikstekken}} en {equipmentCount, plural, =1{1 uitrustingsstuk} other{{equipmentCount} uitrustingsstukken}}. Dit kan niet ongedaan worden gemaakt.",
  "tags_manage_deleteMessage_all": "\"{tagName}\" wordt verwijderd van {diveCount, plural, =1{1 duik} other{{diveCount} duiken}}, {siteCount, plural, =1{1 duikstek} other{{siteCount} duikstekken}} en {equipmentCount, plural, =1{1 uitrustingsstuk} other{{equipmentCount} uitrustingsstukken}}. Dit kan niet ongedaan worden gemaakt.",
  "tags_manage_deleteMessage_unused": "\"{tagName}\" wordt bij geen enkele duik, duikstek of uitrustingsstuk gebruikt. Dit kan niet ongedaan worden gemaakt.",
  "tags_manage_mergeAffected_equipment": "Dit heeft betrekking op in totaal {count, plural, =1{1 uitrustingsstuk} other{{count} uitrustingsstukken}}.",
  "tags_manage_mergeAffected_divesAndEquipment": "Dit heeft betrekking op in totaal {diveCount, plural, =1{1 duik} other{{diveCount} duiken}} en {equipmentCount, plural, =1{1 uitrustingsstuk} other{{equipmentCount} uitrustingsstukken}}.",
  "tags_manage_mergeAffected_sitesAndEquipment": "Dit heeft betrekking op in totaal {siteCount, plural, =1{1 duikstek} other{{siteCount} duikstekken}} en {equipmentCount, plural, =1{1 uitrustingsstuk} other{{equipmentCount} uitrustingsstukken}}.",
  "tags_manage_mergeAffected_all": "Dit heeft betrekking op in totaal {diveCount, plural, =1{1 duik} other{{diveCount} duiken}}, {siteCount, plural, =1{1 duikstek} other{{siteCount} duikstekken}} en {equipmentCount, plural, =1{1 uitrustingsstuk} other{{equipmentCount} uitrustingsstukken}}.",
  "tags_manage_mergeAffected_unused": "Deze tags worden bij geen enkele duik, duikstek of uitrustingsstuk gebruikt.",
```

`lib/l10n/arb/app_pt.arb` (Portuguese):

```json
  "tags_manage_bulkDeleteMessage_equipment": "Estas etiquetas serão removidas de {equipmentCount, plural, =1{1 equipamento} other{{equipmentCount} equipamentos}} no total. Esta ação não pode ser desfeita.",
  "tags_manage_bulkDeleteMessage_divesAndEquipment": "Estas etiquetas serão removidas de {diveCount, plural, =1{1 mergulho} other{{diveCount} mergulhos}} e {equipmentCount, plural, =1{1 equipamento} other{{equipmentCount} equipamentos}} no total. Esta ação não pode ser desfeita.",
  "tags_manage_bulkDeleteMessage_sitesAndEquipment": "Estas etiquetas serão removidas de {siteCount, plural, =1{1 ponto} other{{siteCount} pontos}} e {equipmentCount, plural, =1{1 equipamento} other{{equipmentCount} equipamentos}} no total. Esta ação não pode ser desfeita.",
  "tags_manage_bulkDeleteMessage_all": "Estas etiquetas serão removidas de {diveCount, plural, =1{1 mergulho} other{{diveCount} mergulhos}}, {siteCount, plural, =1{1 ponto} other{{siteCount} pontos}} e {equipmentCount, plural, =1{1 equipamento} other{{equipmentCount} equipamentos}} no total. Esta ação não pode ser desfeita.",
  "tags_manage_bulkDeleteMessage_unused": "Estas etiquetas não são usadas em nenhum mergulho, nenhum ponto nem nenhum equipamento. Esta ação não pode ser desfeita.",
  "tags_manage_scopeRequired": "Escolha pelo menos um: mergulhos, pontos ou equipamentos",
  "tags_manage_deleteMessage_equipment": "\"{tagName}\" será removida de {count, plural, =1{1 equipamento} other{{count} equipamentos}}. Esta ação não pode ser desfeita.",
  "tags_manage_deleteMessage_divesAndEquipment": "\"{tagName}\" será removida de {diveCount, plural, =1{1 mergulho} other{{diveCount} mergulhos}} e {equipmentCount, plural, =1{1 equipamento} other{{equipmentCount} equipamentos}}. Esta ação não pode ser desfeita.",
  "tags_manage_deleteMessage_sitesAndEquipment": "\"{tagName}\" será removida de {siteCount, plural, =1{1 ponto} other{{siteCount} pontos}} e {equipmentCount, plural, =1{1 equipamento} other{{equipmentCount} equipamentos}}. Esta ação não pode ser desfeita.",
  "tags_manage_deleteMessage_all": "\"{tagName}\" será removida de {diveCount, plural, =1{1 mergulho} other{{diveCount} mergulhos}}, {siteCount, plural, =1{1 ponto} other{{siteCount} pontos}} e {equipmentCount, plural, =1{1 equipamento} other{{equipmentCount} equipamentos}}. Esta ação não pode ser desfeita.",
  "tags_manage_deleteMessage_unused": "\"{tagName}\" não é usada em nenhum mergulho, nenhum ponto nem nenhum equipamento. Esta ação não pode ser desfeita.",
  "tags_manage_mergeAffected_equipment": "Isso afetará {count, plural, =1{1 equipamento} other{{count} equipamentos}} no total.",
  "tags_manage_mergeAffected_divesAndEquipment": "Isso afetará {diveCount, plural, =1{1 mergulho} other{{diveCount} mergulhos}} e {equipmentCount, plural, =1{1 equipamento} other{{equipmentCount} equipamentos}} no total.",
  "tags_manage_mergeAffected_sitesAndEquipment": "Isso afetará {siteCount, plural, =1{1 ponto} other{{siteCount} pontos}} e {equipmentCount, plural, =1{1 equipamento} other{{equipmentCount} equipamentos}} no total.",
  "tags_manage_mergeAffected_all": "Isso afetará {diveCount, plural, =1{1 mergulho} other{{diveCount} mergulhos}}, {siteCount, plural, =1{1 ponto} other{{siteCount} pontos}} e {equipmentCount, plural, =1{1 equipamento} other{{equipmentCount} equipamentos}} no total.",
  "tags_manage_mergeAffected_unused": "Estas etiquetas não são usadas em nenhum mergulho, nenhum ponto nem nenhum equipamento.",
```

`lib/l10n/arb/app_zh.arb` (Chinese):

```json
  "tags_manage_bulkDeleteMessage_equipment": "这些标签将从总共 {equipmentCount, plural, =1{1 件装备} other{{equipmentCount} 件装备}} 中移除。此操作无法撤销。",
  "tags_manage_bulkDeleteMessage_divesAndEquipment": "这些标签将从总共 {diveCount, plural, =1{1 次潜水} other{{diveCount} 次潜水}}和 {equipmentCount, plural, =1{1 件装备} other{{equipmentCount} 件装备}} 中移除。此操作无法撤销。",
  "tags_manage_bulkDeleteMessage_sitesAndEquipment": "这些标签将从总共 {siteCount, plural, =1{1 个潜水点} other{{siteCount} 个潜水点}}和 {equipmentCount, plural, =1{1 件装备} other{{equipmentCount} 件装备}} 中移除。此操作无法撤销。",
  "tags_manage_bulkDeleteMessage_all": "这些标签将从总共 {diveCount, plural, =1{1 次潜水} other{{diveCount} 次潜水}}、{siteCount, plural, =1{1 个潜水点} other{{siteCount} 个潜水点}}和 {equipmentCount, plural, =1{1 件装备} other{{equipmentCount} 件装备}} 中移除。此操作无法撤销。",
  "tags_manage_bulkDeleteMessage_unused": "这些标签未用于任何潜水、潜水点或装备。此操作无法撤销。",
  "tags_manage_scopeRequired": "请至少选择一项：潜水、潜水点或装备",
  "tags_manage_deleteMessage_equipment": "「{tagName}」将从 {count, plural, =1{1 件装备} other{{count} 件装备}} 中移除。此操作无法撤销。",
  "tags_manage_deleteMessage_divesAndEquipment": "「{tagName}」将从 {diveCount, plural, =1{1 次潜水} other{{diveCount} 次潜水}}和 {equipmentCount, plural, =1{1 件装备} other{{equipmentCount} 件装备}} 中移除。此操作无法撤销。",
  "tags_manage_deleteMessage_sitesAndEquipment": "「{tagName}」将从 {siteCount, plural, =1{1 个潜水点} other{{siteCount} 个潜水点}}和 {equipmentCount, plural, =1{1 件装备} other{{equipmentCount} 件装备}} 中移除。此操作无法撤销。",
  "tags_manage_deleteMessage_all": "「{tagName}」将从 {diveCount, plural, =1{1 次潜水} other{{diveCount} 次潜水}}、{siteCount, plural, =1{1 个潜水点} other{{siteCount} 个潜水点}}和 {equipmentCount, plural, =1{1 件装备} other{{equipmentCount} 件装备}} 中移除。此操作无法撤销。",
  "tags_manage_deleteMessage_unused": "「{tagName}」未用于任何潜水、潜水点或装备。此操作无法撤销。",
  "tags_manage_mergeAffected_equipment": "这将影响总共 {count, plural, =1{1 件装备} other{{count} 件装备}}。",
  "tags_manage_mergeAffected_divesAndEquipment": "这将影响总共 {diveCount, plural, =1{1 次潜水} other{{diveCount} 次潜水}}和 {equipmentCount, plural, =1{1 件装备} other{{equipmentCount} 件装备}}。",
  "tags_manage_mergeAffected_sitesAndEquipment": "这将影响总共 {siteCount, plural, =1{1 个潜水点} other{{siteCount} 个潜水点}}和 {equipmentCount, plural, =1{1 件装备} other{{equipmentCount} 件装备}}。",
  "tags_manage_mergeAffected_all": "这将影响总共 {diveCount, plural, =1{1 次潜水} other{{diveCount} 次潜水}}、{siteCount, plural, =1{1 个潜水点} other{{siteCount} 个潜水点}}和 {equipmentCount, plural, =1{1 件装备} other{{equipmentCount} 件装备}}。",
  "tags_manage_mergeAffected_unused": "这些标签未用于任何潜水、潜水点或装备。",
```

After each file, check it is still valid JSON and that exactly the four old lines went and sixteen new ones came:

```bash
f=lib/l10n/arb/app_de.arb
jq empty "$f"
git diff -U0 -- "$f" | grep -c '^-  "'
git diff -U0 -- "$f" | grep -c '^+  "'
```

Expected: no output from `jq`, then `4`, then `16`.

- [ ] **Step 10: Check that nothing is missing, then regenerate**

```bash
for f in lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb; do
  jq empty "$f" || echo "INVALID JSON: $f"
  jq -r --slurpfile en lib/l10n/arb/app_en.arb \
    '. as $l | ($en[0] | keys_unsorted[]) as $k
     | select(($k | startswith("@")) | not) | select(($l | has($k)) | not) | $k' \
    "$f" | sed "s|^|missing in $f: |"
done
flutter gen-l10n
```

Expected: no `INVALID JSON` and no `missing in` lines (every earlier task translated its own keys); `flutter gen-l10n` exits 0 and prints no untranslated-message notes (`flutter gen-l10n 2>&1 | grep -i untranslated` prints nothing).

- [ ] **Step 11: Run the tests**

Run, one at a time:
- `flutter test test/l10n/`: Expected PASS (`arb_parity_test`: every English key in every locale, placeholders matching English).
- `flutter test test/features/tags/`: Expected PASS (the tests pin `Locale('en')`, so the translations change nothing there).
- `flutter test test/architecture/`: Expected PASS (two `lib/` files changed).
- `flutter analyze`: Expected no issues.

- [ ] **Step 12: Commit, then the pre-push hook's staleness check**

```bash
dart format .
git add lib/features/tags/presentation/tag_usage_messages.dart \
  lib/features/tags/presentation/widgets/tag_merge_sheet.dart \
  lib/l10n/arb/app_en.arb lib/l10n/arb/app_ar.arb lib/l10n/arb/app_de.arb \
  lib/l10n/arb/app_es.arb lib/l10n/arb/app_fr.arb lib/l10n/arb/app_he.arb \
  lib/l10n/arb/app_hu.arb lib/l10n/arb/app_it.arb lib/l10n/arb/app_nl.arb \
  lib/l10n/arb/app_pt.arb lib/l10n/arb/app_zh.arb \
  lib/l10n/arb/app_localizations.dart \
  lib/l10n/arb/app_localizations_*.dart \
  test/features/tags/presentation/tag_usage_messages_test.dart \
  test/features/tags/presentation/pages/tag_manage_page_equipment_wording_test.dart \
  test/features/tags/presentation/pages/tag_manage_page_scope_test.dart \
  test/features/tags/presentation/pages/tag_manage_page_test.dart \
  test/features/tags/presentation/widgets/tag_merge_sheet_test.dart
git diff --cached --numstat
git commit -m "feat(tags): name equipment in tag delete and merge messages (#1942)" \
  -m "Deleting, bulk deleting or merging tags now names every kind of item it rewrites: all eight combinations of dives, sites and equipment items, each one whole ICU message so every locale keeps its own word order. The unused variants and the scope-required line now say dives, sites or equipment, and the merge sheet seeds its name and color from the most used tag across all three scopes." \
  -m "The twelve new messages and the four reworded ones are translated into the ten other locales, Arabic with its full plural categories. Widget tests pin the equipment scope on Manage Tags end to end."
```

Then repeat the hook's generated-l10n check (`hooks/pre-push` lines 213-257), which is HEAD-relative:

```bash
flutter gen-l10n
git status --porcelain -- 'lib/l10n/arb/app_localizations*.dart' 'lib/l10n/arb/*.arb'
```

Expected: no output. Any `app_localizations*.dart` line means the committed generated files do not match the committed ARBs: review, `git add` those exact files and amend (`git commit --amend --no-edit`). CI's Analyze & Format job (`.github/workflows/ci.yaml` around line 253) runs the same check on the pushed tree.

---

### Task 8: Bulk tag editing with undo

**Files:**
- Create: `lib/features/equipment/data/services/bulk_equipment_tag_service.dart`
- Create: `lib/features/equipment/presentation/providers/bulk_equipment_tag_provider.dart`
- Create: `lib/features/equipment/presentation/widgets/bulk_equipment_tag_sheet.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (Task 6 rewrote this file, so locate by symbol: the import block, and `_bulkActions` with its doc comment; main's lines were `:43` and `:428-456`)
- Modify: `lib/l10n/arb/app_en.arb` (insert after the `equipment_appBar_title` line) and the ten locale files `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb` (insert after each file's own `equipment_appBar_title` line), then regenerate `lib/l10n/arb/app_localizations*.dart`
- Test (create): `test/features/equipment/data/services/bulk_equipment_tag_service_test.dart`
- Test (create): `test/features/equipment/presentation/widgets/bulk_equipment_tag_sheet_test.dart`
- Test (modify): `test/features/equipment/presentation/widgets/equipment_list_content_test.dart` (the `bulk actions` group, main's `:207-303`)

**How dives do it (read before implementing):** line numbers below are main's (3387357b169); Task 2 changed `dive_edit_page.dart` since, so find each spot by the symbol named.
- Dive bulk tags are one `BulkMembershipEditor` in `DiveEditPage(bulkDiveIds:)`, inside `_buildBulkCollectionsSection` (main `dive_edit_page.dart:1399-1406`), seeded by `_loadBulkMembers` (main `:3503-3577`, members sorted case-insensitively, tag rows with `Icons.label_outline`).
- Its Add button opens `_bulkAddTags` (main `:3651-3690`): a `StatefulBuilder` wrapping the whole `AlertDialog`, `TagInputWidget` as content, and Browse, Cancel, Add actions; Browse passes the dialog's `ctx` as `host` so the picker opens above the dialog (#1366).
- Save confirms with `summarizeBulkMembership` + `BulkChangeSummary` (the confirm dialog in the bulk save path, main `:1950-2008`, #1754), applies through `BulkDiveEditService.apply`, and shows the Undo SnackBar (main `:2031-2046`: 5 s, `persist: false`, `showCloseIcon: true`, #406).
- Selection bars declare `BulkAction`s (`lib/shared/selection/bulk_action.dart`); `SelectionAppBar` keys inline actions `selection_action_<id>` and overflow entries `selection_menu_<id>` (`selection_app_bar.dart:191-235`), and ends the mode only on `BulkActionOutcome.completed` (`:142-150`).
- The equipment bar (`_bulkActions` and `_buildSelectionBar` right after it in `equipment_list_content.dart`) has Retire and Reactivate with `maxInlineActions: shell == SelectionBarShell.pane ? 1 : 3`. Edit tags goes third, so it is inline in the app bar (three slots) and in the overflow in the pane (one slot, taken by Retire).

**Interfaces:**
- Consumes: Task 1 `Tag.appliesTo(TagScope)`, `TagScope`; Task 2 `BulkMembershipEditor` (`total`, `labels`, `ensureOn`, `absentStartsChecked`), `BulkMembershipLabels`, `BulkMembershipItem`, `MembershipDelta`, `summarizeBulkMembership`, `BulkChangeSummary(sections, addingHeading, removingHeading)`; Task 3 `TagScope.equipment` (with its arms in both `tag_picker_sheet.dart` switches, so `TagInputWidget(scope: TagScope.equipment)` suggests and `showTagPickerSheet(scope: TagScope.equipment)` lists equipment tags), `EquipmentTagRepository()` (no constructor arguments, database read lazily) with `getTagIdsByEquipment(List<String> equipmentIds)`, `tagCountsForEquipment(List<String> equipmentIds)`, `addTags(List<String> equipmentIds, List<String> tagIds, {bool notify = true})`, `removeTags(List<String> equipmentIds, List<String> tagIds, {bool notify = true})` and `replaceTags(String equipmentId, List<String> tagIds, {bool notify = true})`, each wrapping its writes in `_db.transaction` (a savepoint when nested), `equipmentTagRepositoryProvider` in `lib/features/equipment/presentation/providers/equipment_tag_providers.dart`, the `equipment_tags` table and `tags.applies_to_equipment`. Existing: `tagsProvider` (`lib/features/tags/presentation/providers/tag_providers.dart:20`).
- Produces:
  - `class BulkEquipmentTagService { BulkEquipmentTagService(EquipmentTagRepository repository); Future<Map<String, List<String>>> apply({required List<String> equipmentIds, required Set<String> addTagIds, required Set<String> removeTagIds}); Future<void> undo(Map<String, List<String>> prior); }`
  - `final bulkEquipmentTagServiceProvider = Provider<BulkEquipmentTagService>(...)`
  - `class BulkEquipmentTagSheet extends ConsumerStatefulWidget { const BulkEquipmentTagSheet({Key? key, required List<String> equipmentIds, required ScrollController scrollController}); }` (pops the confirmed `MembershipDelta`, or null)
  - `Future<BulkActionOutcome> showBulkEquipmentTagSheet(BuildContext context, WidgetRef ref, {required List<String> equipmentIds})`
  - `BulkAction` id `editTags`, icon `Icons.sell`.
  - ARB keys (all under `equipment_bulkTags_`), in English and all ten locales: `action`, `adding`, `applied`, `confirmAdding`, `confirmRemoving`, `confirmTitle`, `empty`, `failed`, `onAll`, `onSome`, `removing`, `tagsLabel`, `title`, `undo`. Nouns: the sheet title and SnackBar count "items"; the confirm headings count "equipment items".

- [ ] **Step 1: Write the failing service test**

Create `test/features/equipment/data/services/bulk_equipment_tag_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/data/services/bulk_equipment_tag_service.dart';

import '../../../../helpers/test_database.dart';

/// Bulk equipment tag edits and their undo (issue #1942).
void main() {
  late AppDatabase db;
  late EquipmentTagRepository repository;
  late BulkEquipmentTagService service;

  const ids = ['e1', 'e2', 'e3'];

  setUp(() async {
    db = await setUpTestDatabase();
    repository = EquipmentTagRepository();
    service = BulkEquipmentTagService(repository);
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) VALUES "
      "('e1', 'Wing', 'bcd', 0, 0), ('e2', 'Reg', 'regulator', 0, 0), "
      "('e3', 'Fins', 'fins', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) VALUES "
      "('t1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('t2', 'Rental', 0, 0, 0, 0, 1), "
      "('t3', 'Cold water', 0, 0, 0, 0, 1)",
    );
    // Partial overlap: e1 has Travel kit, e2 Travel kit and Rental, e3 none.
    // Seeded in SQL, so no sync record exists before the service runs.
    await db.customStatement(
      "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
      "VALUES ('l1', 'e1', 't1', 0), ('l2', 'e2', 't1', 1), "
      "('l3', 'e2', 't2', 2)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<Map<String, Set<String>>> tagSets() async {
    final byItem = await repository.getTagIdsByEquipment(ids);
    return {
      for (final id in ids) id: (byItem[id] ?? const <String>[]).toSet(),
    };
  }

  Future<int> count(String sql) async =>
      (await db.customSelect(sql).getSingle()).read<int>('n');

  test('apply adds and removes on every item and returns the prior sets', () async {
    final prior = await service.apply(
      equipmentIds: ids,
      addTagIds: {'t3'},
      removeTagIds: {'t1'},
    );

    expect(await tagSets(), {
      'e1': {'t3'},
      'e2': {'t2', 't3'},
      'e3': {'t3'},
    });
    // Every item is in the snapshot, e3 with an empty list, so Undo can take
    // the new tag back off an item that had none.
    expect(prior.map((id, tags) => MapEntry(id, tags.toSet())), {
      'e1': {'t1'},
      'e2': {'t1', 't2'},
      'e3': <String>{},
    });
  });

  test('undo restores the exact prior sets, including partial overlap', () async {
    final before = await tagSets();
    final prior = await service.apply(
      equipmentIds: ids,
      addTagIds: {'t2', 't3'},
      removeTagIds: {'t1'},
    );

    await service.undo(prior);

    expect(await tagSets(), before);
  });

  test('neither apply nor undo marks an equipment row pending', () async {
    final prior = await service.apply(
      equipmentIds: ids,
      addTagIds: {'t3'},
      removeTagIds: {'t1'},
    );
    await service.undo(prior);

    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records "
        "WHERE entity_type = 'equipment'",
      ),
      0,
    );
    expect(
      await count("SELECT COUNT(*) AS n FROM equipment WHERE updated_at != 0"),
      0,
    );
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records "
        "WHERE entity_type = 'equipmentTags'",
      ),
      greaterThan(0),
    );
  });

  test('adding a tag an item already has is a no-op', () async {
    await service.apply(
      equipmentIds: const ['e1'],
      addTagIds: {'t1'},
      removeTagIds: const {},
    );

    final rows = await db
        .customSelect("SELECT id FROM equipment_tags WHERE equipment_id = 'e1'")
        .get();
    expect(rows.map((r) => r.read<String>('id')), ['l1']);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records "
        "WHERE entity_type = 'equipmentTags'",
      ),
      0,
    );
  });

  test('an empty change writes nothing and returns an empty snapshot', () async {
    final prior = await service.apply(
      equipmentIds: ids,
      addTagIds: const {},
      removeTagIds: const {},
    );

    expect(prior, isEmpty);
    expect(await count("SELECT COUNT(*) AS n FROM sync_records"), 0);
  });

  test('apply and undo each notify once', () async {
    var notifications = 0;
    final sub = SyncEventBus.changes.listen((_) => notifications++);
    addTearDown(sub.cancel);

    final prior = await service.apply(
      equipmentIds: ids,
      addTagIds: {'t3'},
      removeTagIds: {'t1'},
    );
    await Future<void>.delayed(Duration.zero);
    expect(notifications, 1);

    await service.undo(prior);
    await Future<void>.delayed(Duration.zero);
    expect(notifications, 2);
  });

  test('a failure partway through apply leaves every item as it was', () async {
    final before = await tagSets();
    // The removal runs after the additions, so this aborts the transaction
    // with the new rows already written.
    await db.customStatement(
      'CREATE TEMP TRIGGER fail_removal BEFORE DELETE ON equipment_tags '
      "BEGIN SELECT RAISE(ABORT, 'removal refused'); END",
    );

    await expectLater(
      service.apply(equipmentIds: ids, addTagIds: {'t3'}, removeTagIds: {'t1'}),
      throwsA(anything),
    );

    expect(await tagSets(), before);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records "
        "WHERE entity_type = 'equipmentTags'",
      ),
      0,
    );
  });

  test('an item edit made between apply and undo survives the undo', () async {
    final prior = await service.apply(
      equipmentIds: ids,
      addTagIds: {'t3'},
      removeTagIds: const {},
    );
    await db.customStatement(
      "UPDATE equipment SET name = 'Travel wing' WHERE id = 'e1'",
    );

    await service.undo(prior);

    final row = await db
        .customSelect("SELECT name FROM equipment WHERE id = 'e1'")
        .getSingle();
    expect(row.read<String>('name'), 'Travel wing');
    expect((await tagSets())['e1'], {'t1'});
  });

  test('undo skips an item and a tag deleted since apply', () async {
    final prior = await service.apply(
      equipmentIds: ids,
      addTagIds: {'t3'},
      removeTagIds: {'t2'},
    );
    await db.customStatement("DELETE FROM equipment WHERE id = 'e3'");
    await db.customStatement("DELETE FROM tags WHERE id = 't2'");

    await service.undo(prior);

    expect(await tagSets(), {
      'e1': {'t1'},
      'e2': {'t1'},
      'e3': <String>{},
    });
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM equipment_tags WHERE equipment_id = 'e3'",
      ),
      0,
    );
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/features/equipment/data/services/bulk_equipment_tag_service_test.dart`
Expected: FAIL to compile: `Error when reading 'lib/features/equipment/data/services/bulk_equipment_tag_service.dart': No such file or directory`.

- [ ] **Step 3: Implement the service and its provider**

Create `lib/features/equipment/data/services/bulk_equipment_tag_service.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';

/// Puts tags on and takes them off many equipment items at once, with undo
/// (issue #1942).
///
/// Only `equipment_tags` rows change. No equipment row is written or marked
/// pending, so an edit made to an item between Apply and Undo survives both,
/// and a stale whole-item snapshot can never beat a peer's newer edit
/// (#1769).
class BulkEquipmentTagService {
  BulkEquipmentTagService(this._repository);

  final EquipmentTagRepository _repository;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Puts [addTagIds] on every item in [equipmentIds] and takes
  /// [removeTagIds] off every one, in one transaction, then notifies once.
  ///
  /// Returns each item's tag ids as they were before, with an empty list for
  /// an item that had none, for [undo]. The snapshot is read inside the same
  /// transaction as the writes, so a sync apply cannot land between the read
  /// and the write. A tag in both sets ends up removed. An empty change
  /// writes nothing and returns an empty map.
  Future<Map<String, List<String>>> apply({
    required List<String> equipmentIds,
    required Set<String> addTagIds,
    required Set<String> removeTagIds,
  }) async {
    if (equipmentIds.isEmpty || (addTagIds.isEmpty && removeTagIds.isEmpty)) {
      return const {};
    }
    final prior = await _db.transaction(() async {
      final before = await _repository.getTagIdsByEquipment(equipmentIds);
      if (addTagIds.isNotEmpty) {
        await _repository.addTags(
          equipmentIds,
          addTagIds.toList(),
          notify: false,
        );
      }
      if (removeTagIds.isNotEmpty) {
        await _repository.removeTags(
          equipmentIds,
          removeTagIds.toList(),
          notify: false,
        );
      }
      return <String, List<String>>{
        for (final id in equipmentIds)
          id: List<String>.unmodifiable(before[id] ?? const <String>[]),
      };
    });
    SyncEventBus.notifyLocalChange();
    return prior;
  }

  /// Puts every item in [prior] back to exactly its snapshot tag set, in one
  /// transaction, then notifies once.
  ///
  /// An item deleted since [apply] is skipped and a tag deleted since is left
  /// out, so Undo never recreates a link to a row that is gone (the foreign
  /// keys would refuse it and roll back every other item's restore).
  Future<void> undo(Map<String, List<String>> prior) async {
    if (prior.isEmpty) return;
    await _db.transaction(() async {
      final itemRows =
          await (_db.selectOnly(_db.equipment)
                ..addColumns([_db.equipment.id])
                ..where(_db.equipment.id.isIn(prior.keys.toList())))
              .get();
      final liveItems = {for (final r in itemRows) r.read(_db.equipment.id)!};

      final snapshotTagIds = {for (final tags in prior.values) ...tags};
      final tagRows =
          await (_db.selectOnly(_db.tags)
                ..addColumns([_db.tags.id])
                ..where(_db.tags.id.isIn(snapshotTagIds.toList())))
              .get();
      final liveTags = {for (final r in tagRows) r.read(_db.tags.id)!};

      for (final entry in prior.entries) {
        if (!liveItems.contains(entry.key)) continue;
        await _repository.replaceTags(entry.key, [
          for (final tagId in entry.value)
            if (liveTags.contains(tagId)) tagId,
        ], notify: false);
      }
    });
    SyncEventBus.notifyLocalChange();
  }
}
```

Create `lib/features/equipment/presentation/providers/bulk_equipment_tag_provider.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/services/bulk_equipment_tag_service.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';

/// Applies and undoes bulk tag edits across selected equipment (issue #1942).
final bulkEquipmentTagServiceProvider = Provider<BulkEquipmentTagService>(
  (ref) => BulkEquipmentTagService(ref.watch(equipmentTagRepositoryProvider)),
);
```

- [ ] **Step 4: Run the service test**

Run: `flutter test test/features/equipment/data/services/bulk_equipment_tag_service_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: English strings**

In `lib/l10n/arb/app_en.arb`, directly after the line `"equipment_appBar_title": "Equipment",` (line 6744 on main; earlier tasks insert only below it) and before `"equipment_deleteDialog_cancel"`, insert (sorted within the `equipment_` family):

```json
  "equipment_bulkTags_action": "Edit tags",
  "equipment_bulkTags_adding": "adding to all {total}",
  "@equipment_bulkTags_adding": {
    "placeholders": {
      "total": {
        "type": "int"
      }
    }
  },
  "equipment_bulkTags_applied": "{count, plural, =1{Updated tags on 1 item} other{Updated tags on {count} items}}",
  "@equipment_bulkTags_applied": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "equipment_bulkTags_confirmAdding": "{count, plural, =1{Adding to 1 equipment item} other{Adding to all {count} equipment items}}",
  "@equipment_bulkTags_confirmAdding": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "equipment_bulkTags_confirmRemoving": "{count, plural, =1{Removing from 1 equipment item} other{Removing from all {count} equipment items}}",
  "@equipment_bulkTags_confirmRemoving": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "equipment_bulkTags_confirmTitle": "Apply changes?",
  "equipment_bulkTags_empty": "No equipment tags yet",
  "equipment_bulkTags_failed": "Could not update tags: {error}",
  "@equipment_bulkTags_failed": {
    "placeholders": {
      "error": {
        "type": "String"
      }
    }
  },
  "equipment_bulkTags_onAll": "on all {count}",
  "@equipment_bulkTags_onAll": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "equipment_bulkTags_onSome": "on {count} of {total}",
  "@equipment_bulkTags_onSome": {
    "placeholders": {
      "count": {
        "type": "int"
      },
      "total": {
        "type": "int"
      }
    }
  },
  "equipment_bulkTags_removing": "removing from all",
  "equipment_bulkTags_tagsLabel": "Tags",
  "equipment_bulkTags_title": "{count, plural, =1{Edit tags on 1 item} other{Edit tags on {count} items}}",
  "@equipment_bulkTags_title": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "equipment_bulkTags_undo": "Undo",
```

`onSome` declares `count` before `total`, so the generated method is `equipment_bulkTags_onSome(int count, int total)`, matching `BulkMembershipLabels.onSome`.

- [ ] **Step 5b: Translations (all ten locales)**

In each locale file below, find that file's own `"equipment_appBar_title": ...,` line (the non-English files are grouped by feature, and in every one it is followed by `"equipment_deleteDialog_cancel"`, the same neighbour as English) and insert that locale's 14 lines directly after it. The non-English files carry no `@` metadata for these keys; gen-l10n reads the placeholders from `app_en.arb`. Use the Edit tool, anchored on the `equipment_appBar_title` line.

Terminology follows each locale's existing keys, and every placeholder name matches English (`test/l10n/arb_parity_test.dart` checks it):
- "tags" is the Manage Tags word (`tags_manage_title`): ar الوسوم, de Tags, es Etiquetas, fr Étiquettes, he תגיות, hu Címkék, it Tag, nl Tags, pt Etiquetas, zh 标签.
- "items" (sheet title, SnackBar) is the word `equipment_retypeOther_retypedSnackbar` uses: ar عنصر, de Teil, es elemento, fr élément, he פריט, hu elem, it elemento, nl item, pt item, zh 件物品.
- "equipment items" (confirm headings) is the noun Manage Tags uses for one equipment item: ar قطعة معدات, de Ausrüstungsteil, es equipo, fr équipement, he פריט ציוד, hu felszerelés, it attrezzatura, nl uitrustingsstuk, pt equipamento, zh 件装备.
- The row subtitles, confirm title and Undo follow the dive editor's `diveLog_bulkEdit_membership_*`, `diveLog_bulkEdit_confirmTitle` and `diveLog_bulkDelete_undo`, with gender and case agreeing with the equipment noun (es/fr/pt masculine "todos"/"tous"; it feminine "tutte le" for attrezzature; de "an" for a tag on an item).
- Plurals: Arabic uses its CLDR categories `one`, `two`, `few`, `many`, `other` (the count is never 0: it is the selection size); Hebrew and every other locale use `=1` / `other`, like their dive siblings.

`lib/l10n/arb/app_ar.arb`:

```json
  "equipment_bulkTags_action": "تعديل الوسوم",
  "equipment_bulkTags_adding": "إضافة إلى كل الـ {total}",
  "equipment_bulkTags_applied": "{count, plural, one{تم تحديث الوسوم على عنصر واحد} two{تم تحديث الوسوم على عنصرين} few{تم تحديث الوسوم على {count} عناصر} many{تم تحديث الوسوم على {count} عنصرًا} other{تم تحديث الوسوم على {count} عنصر}}",
  "equipment_bulkTags_confirmAdding": "{count, plural, one{إضافة إلى قطعة معدات واحدة} two{إضافة إلى قطعتي معدات} few{إضافة إلى كل الـ {count} قطع معدات} many{إضافة إلى كل الـ {count} قطعة معدات} other{إضافة إلى كل الـ {count} قطعة معدات}}",
  "equipment_bulkTags_confirmRemoving": "{count, plural, one{إزالة من قطعة معدات واحدة} two{إزالة من قطعتي معدات} few{إزالة من كل الـ {count} قطع معدات} many{إزالة من كل الـ {count} قطعة معدات} other{إزالة من كل الـ {count} قطعة معدات}}",
  "equipment_bulkTags_confirmTitle": "تطبيق التغييرات؟",
  "equipment_bulkTags_empty": "لا توجد وسوم معدات بعد",
  "equipment_bulkTags_failed": "تعذر تحديث الوسوم: {error}",
  "equipment_bulkTags_onAll": "في كل الـ {count}",
  "equipment_bulkTags_onSome": "في {count} من {total}",
  "equipment_bulkTags_removing": "إزالة من الكل",
  "equipment_bulkTags_tagsLabel": "الوسوم",
  "equipment_bulkTags_title": "{count, plural, one{تعديل الوسوم على عنصر واحد} two{تعديل الوسوم على عنصرين} few{تعديل الوسوم على {count} عناصر} many{تعديل الوسوم على {count} عنصرًا} other{تعديل الوسوم على {count} عنصر}}",
  "equipment_bulkTags_undo": "تراجع",
```

`lib/l10n/arb/app_de.arb`:

```json
  "equipment_bulkTags_action": "Tags bearbeiten",
  "equipment_bulkTags_adding": "wird zu allen {total} hinzugefügt",
  "equipment_bulkTags_applied": "{count, plural, =1{Tags von 1 Teil aktualisiert} other{Tags von {count} Teilen aktualisiert}}",
  "equipment_bulkTags_confirmAdding": "{count, plural, =1{Wird zu 1 Ausrüstungsteil hinzugefügt} other{Wird zu allen {count} Ausrüstungsteilen hinzugefügt}}",
  "equipment_bulkTags_confirmRemoving": "{count, plural, =1{Wird von 1 Ausrüstungsteil entfernt} other{Wird von allen {count} Ausrüstungsteilen entfernt}}",
  "equipment_bulkTags_confirmTitle": "Änderungen anwenden?",
  "equipment_bulkTags_empty": "Noch keine Ausrüstungs-Tags",
  "equipment_bulkTags_failed": "Tags konnten nicht aktualisiert werden: {error}",
  "equipment_bulkTags_onAll": "an allen {count}",
  "equipment_bulkTags_onSome": "an {count} von {total}",
  "equipment_bulkTags_removing": "wird von allen entfernt",
  "equipment_bulkTags_tagsLabel": "Tags",
  "equipment_bulkTags_title": "{count, plural, =1{Tags von 1 Teil bearbeiten} other{Tags von {count} Teilen bearbeiten}}",
  "equipment_bulkTags_undo": "Rückgängig",
```

`lib/l10n/arb/app_es.arb`:

```json
  "equipment_bulkTags_action": "Editar etiquetas",
  "equipment_bulkTags_adding": "añadiendo a todos ({total})",
  "equipment_bulkTags_applied": "{count, plural, =1{Etiquetas actualizadas en 1 elemento} other{Etiquetas actualizadas en {count} elementos}}",
  "equipment_bulkTags_confirmAdding": "{count, plural, =1{Añadiendo a 1 equipo} other{Añadiendo a todos los {count} equipos}}",
  "equipment_bulkTags_confirmRemoving": "{count, plural, =1{Quitando de 1 equipo} other{Quitando de todos los {count} equipos}}",
  "equipment_bulkTags_confirmTitle": "¿Aplicar cambios?",
  "equipment_bulkTags_empty": "Aún no hay etiquetas de equipo",
  "equipment_bulkTags_failed": "No se pudieron actualizar las etiquetas: {error}",
  "equipment_bulkTags_onAll": "en todos los {count}",
  "equipment_bulkTags_onSome": "en {count} de {total}",
  "equipment_bulkTags_removing": "quitando de todos",
  "equipment_bulkTags_tagsLabel": "Etiquetas",
  "equipment_bulkTags_title": "{count, plural, =1{Editar etiquetas de 1 elemento} other{Editar etiquetas de {count} elementos}}",
  "equipment_bulkTags_undo": "Deshacer",
```

`lib/l10n/arb/app_fr.arb`:

```json
  "equipment_bulkTags_action": "Modifier les étiquettes",
  "equipment_bulkTags_adding": "ajout à tous les {total}",
  "equipment_bulkTags_applied": "{count, plural, =1{Étiquettes mises à jour sur 1 élément} other{Étiquettes mises à jour sur {count} éléments}}",
  "equipment_bulkTags_confirmAdding": "{count, plural, =1{Ajout à 1 équipement} other{Ajout à tous les {count} équipements}}",
  "equipment_bulkTags_confirmRemoving": "{count, plural, =1{Retrait de 1 équipement} other{Retrait de tous les {count} équipements}}",
  "equipment_bulkTags_confirmTitle": "Appliquer les modifications ?",
  "equipment_bulkTags_empty": "Aucune étiquette d'équipement pour l'instant",
  "equipment_bulkTags_failed": "Impossible de mettre à jour les étiquettes : {error}",
  "equipment_bulkTags_onAll": "sur tous les {count}",
  "equipment_bulkTags_onSome": "sur {count} sur {total}",
  "equipment_bulkTags_removing": "retrait de tous",
  "equipment_bulkTags_tagsLabel": "Étiquettes",
  "equipment_bulkTags_title": "{count, plural, =1{Modifier les étiquettes de 1 élément} other{Modifier les étiquettes de {count} éléments}}",
  "equipment_bulkTags_undo": "Annuler",
```

`lib/l10n/arb/app_he.arb`:

```json
  "equipment_bulkTags_action": "עריכת תגיות",
  "equipment_bulkTags_adding": "מוסיף לכל {total}",
  "equipment_bulkTags_applied": "{count, plural, =1{התגיות של פריט אחד עודכנו} other{התגיות של {count} פריטים עודכנו}}",
  "equipment_bulkTags_confirmAdding": "{count, plural, =1{מוסיף לפריט ציוד אחד} other{מוסיף לכל {count} פריטי הציוד}}",
  "equipment_bulkTags_confirmRemoving": "{count, plural, =1{מסיר מפריט ציוד אחד} other{מסיר מכל {count} פריטי הציוד}}",
  "equipment_bulkTags_confirmTitle": "להחיל שינויים?",
  "equipment_bulkTags_empty": "אין עדיין תגיות ציוד",
  "equipment_bulkTags_failed": "לא ניתן לעדכן את התגיות: {error}",
  "equipment_bulkTags_onAll": "בכל {count}",
  "equipment_bulkTags_onSome": "ב-{count} מתוך {total}",
  "equipment_bulkTags_removing": "מסיר מהכול",
  "equipment_bulkTags_tagsLabel": "תגיות",
  "equipment_bulkTags_title": "{count, plural, =1{עריכת תגיות של פריט אחד} other{עריכת תגיות של {count} פריטים}}",
  "equipment_bulkTags_undo": "ביטול",
```

`lib/l10n/arb/app_hu.arb`:

```json
  "equipment_bulkTags_action": "Címkék szerkesztése",
  "equipment_bulkTags_adding": "hozzáadás mind a {total} felszereléshez",
  "equipment_bulkTags_applied": "{count, plural, =1{1 elem címkéi frissítve} other{{count} elem címkéi frissítve}}",
  "equipment_bulkTags_confirmAdding": "{count, plural, =1{Hozzáadás 1 felszereléshez} other{Hozzáadás mind a {count} felszereléshez}}",
  "equipment_bulkTags_confirmRemoving": "{count, plural, =1{Eltávolítás 1 felszerelésről} other{Eltávolítás mind a {count} felszerelésről}}",
  "equipment_bulkTags_confirmTitle": "Alkalmazza a módosításokat?",
  "equipment_bulkTags_empty": "Még nincsenek felszereléscímkék",
  "equipment_bulkTags_failed": "Nem sikerült frissíteni a címkéket: {error}",
  "equipment_bulkTags_onAll": "mind a {count} felszerelésen",
  "equipment_bulkTags_onSome": "{count}/{total} felszerelésen",
  "equipment_bulkTags_removing": "eltávolítás az összesről",
  "equipment_bulkTags_tagsLabel": "Címkék",
  "equipment_bulkTags_title": "{count, plural, =1{1 elem címkéinek szerkesztése} other{{count} elem címkéinek szerkesztése}}",
  "equipment_bulkTags_undo": "Visszavonás",
```

`lib/l10n/arb/app_it.arb`:

```json
  "equipment_bulkTags_action": "Modifica tag",
  "equipment_bulkTags_adding": "aggiunta a tutte le {total}",
  "equipment_bulkTags_applied": "{count, plural, =1{Tag aggiornati su 1 elemento} other{Tag aggiornati su {count} elementi}}",
  "equipment_bulkTags_confirmAdding": "{count, plural, =1{Aggiunta a 1 attrezzatura} other{Aggiunta a tutte le {count} attrezzature}}",
  "equipment_bulkTags_confirmRemoving": "{count, plural, =1{Rimozione da 1 attrezzatura} other{Rimozione da tutte le {count} attrezzature}}",
  "equipment_bulkTags_confirmTitle": "Applicare le modifiche?",
  "equipment_bulkTags_empty": "Ancora nessun tag per l'attrezzatura",
  "equipment_bulkTags_failed": "Impossibile aggiornare i tag: {error}",
  "equipment_bulkTags_onAll": "su tutte le {count}",
  "equipment_bulkTags_onSome": "su {count} di {total}",
  "equipment_bulkTags_removing": "rimozione da tutte",
  "equipment_bulkTags_tagsLabel": "Tag",
  "equipment_bulkTags_title": "{count, plural, =1{Modifica tag di 1 elemento} other{Modifica tag di {count} elementi}}",
  "equipment_bulkTags_undo": "Annulla",
```

`lib/l10n/arb/app_nl.arb`:

```json
  "equipment_bulkTags_action": "Tags bewerken",
  "equipment_bulkTags_adding": "toevoegen aan alle {total}",
  "equipment_bulkTags_applied": "{count, plural, =1{Tags van 1 item bijgewerkt} other{Tags van {count} items bijgewerkt}}",
  "equipment_bulkTags_confirmAdding": "{count, plural, =1{Toevoegen aan 1 uitrustingsstuk} other{Toevoegen aan alle {count} uitrustingsstukken}}",
  "equipment_bulkTags_confirmRemoving": "{count, plural, =1{Verwijderen van 1 uitrustingsstuk} other{Verwijderen van alle {count} uitrustingsstukken}}",
  "equipment_bulkTags_confirmTitle": "Wijzigingen toepassen?",
  "equipment_bulkTags_empty": "Nog geen uitrustingstags",
  "equipment_bulkTags_failed": "Kan tags niet bijwerken: {error}",
  "equipment_bulkTags_onAll": "op alle {count}",
  "equipment_bulkTags_onSome": "op {count} van {total}",
  "equipment_bulkTags_removing": "verwijderen van alle",
  "equipment_bulkTags_tagsLabel": "Tags",
  "equipment_bulkTags_title": "{count, plural, =1{Tags van 1 item bewerken} other{Tags van {count} items bewerken}}",
  "equipment_bulkTags_undo": "Ongedaan maken",
```

`lib/l10n/arb/app_pt.arb`:

```json
  "equipment_bulkTags_action": "Editar etiquetas",
  "equipment_bulkTags_adding": "adicionando a todos os {total}",
  "equipment_bulkTags_applied": "{count, plural, =1{Etiquetas atualizadas em 1 item} other{Etiquetas atualizadas em {count} itens}}",
  "equipment_bulkTags_confirmAdding": "{count, plural, =1{Adicionando a 1 equipamento} other{Adicionando a todos os {count} equipamentos}}",
  "equipment_bulkTags_confirmRemoving": "{count, plural, =1{Removendo de 1 equipamento} other{Removendo de todos os {count} equipamentos}}",
  "equipment_bulkTags_confirmTitle": "Aplicar alterações?",
  "equipment_bulkTags_empty": "Ainda não há etiquetas de equipamento",
  "equipment_bulkTags_failed": "Não foi possível atualizar as etiquetas: {error}",
  "equipment_bulkTags_onAll": "em todos os {count}",
  "equipment_bulkTags_onSome": "em {count} de {total}",
  "equipment_bulkTags_removing": "removendo de todos",
  "equipment_bulkTags_tagsLabel": "Etiquetas",
  "equipment_bulkTags_title": "{count, plural, =1{Editar etiquetas de 1 item} other{Editar etiquetas de {count} itens}}",
  "equipment_bulkTags_undo": "Desfazer",
```

`lib/l10n/arb/app_zh.arb`:

```json
  "equipment_bulkTags_action": "编辑标签",
  "equipment_bulkTags_adding": "添加到全部 {total} 件",
  "equipment_bulkTags_applied": "{count, plural, =1{已更新 1 件物品的标签} other{已更新 {count} 件物品的标签}}",
  "equipment_bulkTags_confirmAdding": "{count, plural, =1{添加到 1 件装备} other{添加到全部 {count} 件装备}}",
  "equipment_bulkTags_confirmRemoving": "{count, plural, =1{从 1 件装备移除} other{从全部 {count} 件装备移除}}",
  "equipment_bulkTags_confirmTitle": "应用更改？",
  "equipment_bulkTags_empty": "还没有装备标签",
  "equipment_bulkTags_failed": "无法更新标签：{error}",
  "equipment_bulkTags_onAll": "全部 {count} 件装备",
  "equipment_bulkTags_onSome": "{count}/{total} 件装备",
  "equipment_bulkTags_removing": "从全部移除",
  "equipment_bulkTags_tagsLabel": "标签",
  "equipment_bulkTags_title": "{count, plural, =1{编辑 1 件物品的标签} other{编辑 {count} 件物品的标签}}",
  "equipment_bulkTags_undo": "撤消",
```

After the edits, check each file is still valid JSON and holds all 14 keys exactly once:

```bash
for f in lib/l10n/arb/app_*.arb; do python3.14 -c "import json,sys; d=json.load(open('$f', encoding='utf-8')); ks=[k for k in d if k.startswith('equipment_bulkTags_')]; assert len(ks)==14, ('$f', ks)"; done
git diff --numstat lib/l10n/arb/
```

Expected: no assertion error; `--numstat` shows 14 added lines and 0 removed in each non-English file (more in `app_en.arb`, which carries the `@` blocks).

Run: `flutter gen-l10n`
Expected: completes; `lib/l10n/arb/app_localizations.dart` and all eleven `app_localizations_<locale>.dart` files change.

Run: `flutter test test/l10n/`
Expected: PASS (`arb_parity_test.dart` finds every key in all ten locales with English's placeholders).

- [ ] **Step 6: Write the failing sheet test**

Create `test/features/equipment/presentation/widgets/bulk_equipment_tag_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/presentation/widgets/bulk_equipment_tag_sheet.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_picker_sheet.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// The equipment bulk tag sheet end to end on a real database (issue #1942).
void main() {
  late AppDatabase db;
  late EquipmentTagRepository repository;
  BulkActionOutcome? outcome;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = EquipmentTagRepository();
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) VALUES "
      "('e1', 'Wing', 'bcd', 0, 0), ('e2', 'Reg', 'regulator', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) VALUES "
      "('t1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('t2', 'Rental', 0, 0, 0, 0, 1), "
      "('t3', 'Cold water', 0, 0, 0, 0, 1), "
      "('t4', 'Nitrox', 0, 0, 1, 0, 0), "
      "('t5', 'Night', 0, 0, 1, 0, 0)",
    );
    // e1: Travel kit, Rental and the dive-only Nitrox. e2: Travel kit.
    await db.customStatement(
      "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
      "VALUES ('l1', 'e1', 't1', 0), ('l2', 'e1', 't2', 1), "
      "('l3', 'e1', 't4', 2), ('l4', 'e2', 't1', 3)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<Set<String>> tagIdsOf(String equipmentId) async =>
      ((await repository.getTagIdsByEquipment([equipmentId]))[equipmentId] ??
              const <String>[])
          .toSet();

  /// Hosted in the shell shape, because the sheet opens dialogs and a sheet
  /// from a dialog (#1366).
  Future<void> openSheet(WidgetTester tester) async {
    outcome = null;
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testAppInShell(
        locale: const Locale('en'),
        overrides: overrides,
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async {
              outcome = await showBulkEquipmentTagSheet(
                context,
                ref,
                equipmentIds: const ['e1', 'e2'],
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Checkbox toggleOf(WidgetTester tester, String tagId) =>
      tester.widget<Checkbox>(find.byKey(ValueKey('membership-toggle-$tagId')));

  Future<void> tapToggle(WidgetTester tester, String tagId) async {
    final toggle = find.byKey(ValueKey('membership-toggle-$tagId'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  testWidgets(
    'lists equipment tags and tags already on an item, with tri-state counts',
    (tester) async {
      await openSheet(tester);

      expect(find.text('Edit tags on 2 items'), findsOneWidget);
      // Travel kit is on both items, Rental on one, Cold water on neither.
      expect(toggleOf(tester, 't1').value, isTrue);
      expect(find.text('on all 2'), findsOneWidget);
      expect(toggleOf(tester, 't2').value, isNull);
      expect(toggleOf(tester, 't3').value, isFalse);
      // Nitrox is a dive tag, listed only because an item carries it.
      expect(toggleOf(tester, 't4').value, isNull);
      expect(find.text('on 1 of 2'), findsNWidgets(2)); // Rental, Nitrox
      expect(find.text('Night'), findsNothing);
      // Nothing changed yet, so there is nothing to apply.
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('bulkEquipmentTags_apply')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('apply confirms the change, then Undo restores every item', (
    tester,
  ) async {
    await openSheet(tester);
    await tapToggle(tester, 't3'); // on none -> add to all
    await tapToggle(tester, 't1'); // on all -> remove from all

    await tester.tap(find.byKey(const ValueKey('bulkEquipmentTags_apply')));
    await tester.pumpAndSettle();

    expect(inDialog('Adding to all 2 equipment items'), findsOneWidget);
    expect(inDialog('Cold water'), findsOneWidget);
    expect(inDialog('Removing from all 2 equipment items'), findsOneWidget);
    expect(inDialog('Travel kit'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bulkEquipmentTags_confirm')));
    await tester.pumpAndSettle();

    expect(outcome, BulkActionOutcome.completed);
    expect(await tagIdsOf('e1'), {'t2', 't3', 't4'});
    expect(await tagIdsOf('e2'), {'t3'});
    expect(find.text('Updated tags on 2 items'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(await tagIdsOf('e1'), {'t1', 't2', 't4'});
    expect(await tagIdsOf('e2'), {'t1'});
  });

  testWidgets('cancelling the sheet changes nothing and reports cancelled', (
    tester,
  ) async {
    await openSheet(tester);
    await tapToggle(tester, 't3');

    await tester.tap(find.byKey(const ValueKey('bulkEquipmentTags_cancel')));
    await tester.pumpAndSettle();

    expect(outcome, BulkActionOutcome.cancelled);
    expect(await tagIdsOf('e1'), {'t1', 't2', 't4'});
    expect(await tagIdsOf('e2'), {'t1'});
  });

  testWidgets('cancelling the confirmation keeps the sheet and its edits', (
    tester,
  ) async {
    await openSheet(tester);
    await tapToggle(tester, 't3');
    await tester.tap(find.byKey(const ValueKey('bulkEquipmentTags_apply')));
    await tester.pumpAndSettle();

    await tester.tap(inDialog('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(toggleOf(tester, 't3').value, isTrue);
    expect(outcome, isNull);
    expect(await tagIdsOf('e2'), {'t1'});
  });

  testWidgets('a tag picked through Add is switched on for every item', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Browse'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(TagPickerSheet),
        matching: find.text('Cold water'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add 1 tag'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Add'),
      ),
    );
    await tester.pumpAndSettle();

    expect(toggleOf(tester, 't3').value, isTrue);
    expect(find.text('adding to all 2'), findsOneWidget);
  });
}
```

- [ ] **Step 7: Run it and confirm it fails**

Run: `flutter test test/features/equipment/presentation/widgets/bulk_equipment_tag_sheet_test.dart`
Expected: FAIL to compile: `Error when reading 'lib/features/equipment/presentation/widgets/bulk_equipment_tag_sheet.dart': No such file or directory`.

- [ ] **Step 8: Implement the sheet**

Create `lib/features/equipment/presentation/widgets/bulk_equipment_tag_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/equipment/presentation/providers/bulk_equipment_tag_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/bulk_edit/bulk_change_summary.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

/// Edits the tags of the equipment items in [equipmentIds] (issue #1942).
///
/// Opens [BulkEquipmentTagSheet]. Once the diver confirms, the tags go on
/// and come off every item in one transaction, and a SnackBar offers Undo.
/// Returns [BulkActionOutcome.cancelled] when the diver backs out, so the
/// selection survives, and [BulkActionOutcome.failed] when the write throws.
Future<BulkActionOutcome> showBulkEquipmentTagSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<String> equipmentIds,
}) async {
  if (equipmentIds.isEmpty) return BulkActionOutcome.cancelled;
  // Captured before the sheet opens: Undo can run after the list that
  // started this edit is gone.
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final errorColor = Theme.of(context).colorScheme.error;
  final service = ref.read(bulkEquipmentTagServiceProvider);

  final delta = await showModalBottomSheet<MembershipDelta>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => BulkEquipmentTagSheet(
        equipmentIds: equipmentIds,
        scrollController: scrollController,
      ),
    ),
  );
  if (delta == null || delta.isEmpty) return BulkActionOutcome.cancelled;

  try {
    final prior = await service.apply(
      equipmentIds: equipmentIds,
      addTagIds: delta.addIds.toSet(),
      removeTagIds: delta.removeIds.toSet(),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.equipment_bulkTags_applied(equipmentIds.length)),
        duration: const Duration(seconds: 5),
        // A SnackBar with an action defaults to persist: true, which stops
        // the auto-dismiss. Force the 5 s dismiss and add a close icon, so
        // the banner can go without tapping Undo (#406).
        persist: false,
        showCloseIcon: true,
        action: SnackBarAction(
          label: l10n.equipment_bulkTags_undo,
          onPressed: () => logFailure(
            service.undo(prior),
            BulkEquipmentTagSheet,
            'undo a bulk equipment tag edit',
          ),
        ),
      ),
    );
    return BulkActionOutcome.completed;
  } catch (e, stackTrace) {
    LoggerService.forClass(BulkEquipmentTagSheet).error(
      'Failed to edit equipment tags',
      error: e,
      stackTrace: stackTrace,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.equipment_bulkTags_failed('$e')),
        backgroundColor: errorColor,
      ),
    );
    return BulkActionOutcome.failed;
  }
}

/// The bulk tag editor for equipment: one tri-state row per tag (on all; on
/// some, left as is; on none) for every equipment tag and every tag already
/// on a selected item, an Add button, and Apply behind a confirmation that
/// names every change (#1754).
///
/// Pops the confirmed [MembershipDelta]; any other way out pops null.
class BulkEquipmentTagSheet extends ConsumerStatefulWidget {
  const BulkEquipmentTagSheet({
    super.key,
    required this.equipmentIds,
    required this.scrollController,
  });

  final List<String> equipmentIds;

  /// Supplied by the enclosing [DraggableScrollableSheet].
  final ScrollController scrollController;

  @override
  ConsumerState<BulkEquipmentTagSheet> createState() =>
      _BulkEquipmentTagSheetState();
}

class _BulkEquipmentTagSheetState extends ConsumerState<BulkEquipmentTagSheet> {
  late final Future<void> _loading;
  Map<String, int> _counts = const {};
  List<BulkMembershipItem> _members = const [];
  MembershipDelta _delta = MembershipDelta.empty;

  /// Switches on the tags picked through Add. Rows on none of the items
  /// start unchecked here, so appending them alone would add nothing.
  ({int serial, Set<String> ids})? _ensureOn;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  static BulkMembershipItem _member(String id, String label) =>
      BulkMembershipItem(id: id, label: label, icon: Icons.label_outline);

  static int _byLabel(BulkMembershipItem a, BulkMembershipItem b) =>
      a.label.toLowerCase().compareTo(b.label.toLowerCase());

  Future<void> _load() async {
    final counts = await ref
        .read(equipmentTagRepositoryProvider)
        .tagCountsForEquipment(widget.equipmentIds);
    final tags = await ref.read(tagsProvider.future);
    final known = {for (final t in tags) t.id};
    _counts = counts;
    _members = [
      for (final t in tags)
        if (t.appliesTo(TagScope.equipment) || (counts[t.id] ?? 0) > 0)
          _member(t.id, t.name),
      // A linked tag missing from the diver's list keeps its row, named by
      // its id, as the dive editor does.
      for (final id in counts.keys)
        if (!known.contains(id)) _member(id, id),
    ]..sort(_byLabel);
  }

  void _addMembers(List<Tag> tags) {
    if (tags.isEmpty) return;
    final listed = {for (final m in _members) m.id};
    setState(() {
      _members = [
        ..._members,
        for (final t in tags)
          if (!listed.contains(t.id)) _member(t.id, t.name),
      ]..sort(_byLabel);
      _ensureOn = (
        serial: (_ensureOn?.serial ?? 0) + 1,
        ids: {for (final t in tags) t.id},
      );
    });
  }

  /// The dialog the dive bulk editor opens from its Tags Add button, scoped
  /// to equipment tags.
  void _addTags() {
    final l10n = context.l10n;
    var picked = <Tag>[];
    showDialog<void>(
      context: context,
      // The StatefulBuilder wraps the whole dialog, not just its content, so
      // the Browse action in the button row can restage `picked` too.
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.equipment_bulkTags_tagsLabel),
          content: TagInputWidget(
            selectedTags: picked,
            onTagsChanged: (tags) => setDialogState(() => picked = tags),
            scope: TagScope.equipment,
          ),
          actions: [
            TextButton(
              // `ctx` is inside the dialog route, so the picker lands on the
              // same (root) navigator and opens above the dialog (#1366).
              onPressed: () => showTagPickerSheet(
                context,
                selected: picked,
                onPicked: (tags) => setDialogState(() => picked = tags),
                scope: TagScope.equipment,
                host: ctx,
              ),
              child: Text(l10n.tags_action_browse),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.common_action_cancel),
            ),
            FilledButton(
              onPressed: () {
                _addMembers(picked);
                Navigator.pop(ctx);
              },
              child: Text(l10n.common_action_add),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final l10n = context.l10n;
    final total = widget.equipmentIds.length;
    final sections = summarizeBulkMembership([
      (
        title: l10n.equipment_bulkTags_tagsLabel,
        delta: _delta,
        members: _members,
      ),
    ]);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.equipment_bulkTags_confirmTitle),
        content: SingleChildScrollView(
          child: BulkChangeSummary(
            sections: sections,
            addingHeading: l10n.equipment_bulkTags_confirmAdding(total),
            removingHeading: l10n.equipment_bulkTags_confirmRemoving(total),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            key: const ValueKey('bulkEquipmentTags_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.common_action_apply),
          ),
        ],
      ),
    );
    // Cancel returns to the sheet with the edits kept.
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop(_delta);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = widget.equipmentIds.length;
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.tags_picker_errorLoading('${snapshot.error}')),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                children: [
                  BulkMembershipEditor(
                    title: l10n.equipment_bulkTags_title(total),
                    total: total,
                    labels: BulkMembershipLabels(
                      onAll: l10n.equipment_bulkTags_onAll,
                      onSome: l10n.equipment_bulkTags_onSome,
                      adding: l10n.equipment_bulkTags_adding,
                      removing: l10n.equipment_bulkTags_removing,
                      empty: l10n.equipment_bulkTags_empty,
                      add: l10n.common_action_add,
                    ),
                    items: _members,
                    counts: _counts,
                    onAdd: _addTags,
                    onChanged: (delta) => setState(() => _delta = delta),
                    ensureOn: _ensureOn,
                    // Every equipment tag is listed, so a tag on none of the
                    // items is an offer and starts unchecked.
                    absentStartsChecked: false,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      key: const ValueKey('bulkEquipmentTags_cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.common_action_cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const ValueKey('bulkEquipmentTags_apply'),
                      onPressed: _delta.isEmpty ? null : _confirm,
                      child: Text(l10n.common_action_apply),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
```

Run: `flutter test test/features/equipment/presentation/widgets/bulk_equipment_tag_sheet_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 9: Write the failing selection bar tests**

In `test/features/equipment/presentation/widgets/equipment_list_content_test.dart`, the `bulk actions` group's `host` helper (main `:210-235`; find it by name inside `group('bulk actions', ...)`) gains a pane option. Replace:

```dart
    Future<Widget> host(List<EquipmentItem> items) async {
```

with:

```dart
    Future<Widget> host(
      List<EquipmentItem> items, {
      bool showAppBar = true,
    }) async {
```

and:

```dart
        child: const EquipmentListContent(showAppBar: true),
```

with:

```dart
        child: EquipmentListContent(showAppBar: showAppBar),
```

Then add after the `'cancelling deletes nothing and keeps the selection'` test (before the `bulk actions` group's closing `});`, main `:303`):

```dart
    // Issue #1942.
    testWidgets('edit tags sits beside retire and reactivate', (tester) async {
      final widget = await host(const [
        EquipmentItem(id: 'e1', name: 'Aaa Reg', type: EquipmentType.regulator),
        EquipmentItem(
          id: 'e2',
          name: 'Bbb BCD',
          type: EquipmentType.bcd,
          isActive: false,
        ),
      ]);
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      final editTags = find.byKey(const ValueKey('selection_action_editTags'));
      // Nothing checked yet.
      expect(tester.widget<IconButton>(editTags).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('selection_select_all')));
      await tester.pumpAndSettle();

      // A mixed selection turns retire and reactivate off; tags apply to any
      // selection.
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('selection_action_retire')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.widget<IconButton>(editTags).onPressed, isNotNull);
      expect(tester.widget<IconButton>(editTags).tooltip, 'Edit tags');
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: editTags, matching: find.byType(Icon)),
            )
            .icon,
        Icons.sell,
      );
    });

    testWidgets('in the pane, edit tags is in the overflow menu', (
      tester,
    ) async {
      final widget = await host([
        _makeEquipment(id: 'e1', name: 'Aaa Reg'),
      ], showAppBar: false);
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_select_all')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('selection_action_editTags')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('selection_overflow')));
      await tester.pumpAndSettle();
      final entry = find.byKey(const ValueKey('selection_menu_editTags'));
      expect(entry, findsOneWidget);
      expect(tester.widget<PopupMenuItem<String>>(entry).enabled, isTrue);
    });
```

(`EquipmentItem` has a const constructor and a separate `isActive` field, `equipment_item.dart:23, 55`; `_bulkActions` gates retire on `e.isActive` in its `retire` entry.)

Run: `flutter test test/features/equipment/presentation/widgets/equipment_list_content_test.dart --plain-name "bulk actions"`
Expected: FAIL: `Bad state: No element` for `selection_action_editTags`, and `findsOneWidget` fails for `selection_menu_editTags`.

- [ ] **Step 10: Add the action to the selection bar**

In `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (Task 6 changed this file, so every spot below is found by symbol, not by line; main's lines are given only as a hint), directly after the import line `import 'package:submersion/features/equipment/presentation/widgets/equipment_list_sort_sheet.dart';` (main line 43) add:

```dart
import 'package:submersion/features/equipment/presentation/widgets/bulk_equipment_tag_sheet.dart';
```

In the doc comment directly above `List<BulkAction> _bulkActions(List<EquipmentItem> equipment) {` (main `:431-433`), replace:

```dart
  /// Retire and reactivate are enabled only on a uniform selection -- every
  /// checked item active, or none of them -- so the action never has to guess
  /// what a mixed selection means.
```

with (the existing sentence is kept verbatim; only the new paragraph is added):

```dart
  /// Retire and reactivate are enabled only on a uniform selection -- every
  /// checked item active, or none of them -- so the action never has to guess
  /// what a mixed selection means.
  ///
  /// Edit tags works on any selection (issue #1942). It comes last, so the
  /// pane's single inline slot stays with Retire and it lands in the
  /// overflow there, while the app bar shows all three.
```

At the end of `_bulkActions`'s returned list (the `reactivate` entry and the list's closing `];`, main `:448-455`), replace:

```dart
      BulkAction(
        id: 'reactivate',
        icon: Icons.unarchive,
        label: context.l10n.equipment_menu_reactivate,
        isEnabled: (ids) => everyChecked(ids, (e) => !e.isActive),
        onInvoke: () => _applyRetirement(retire: false),
      ),
    ];
```

with:

```dart
      BulkAction(
        id: 'reactivate',
        icon: Icons.unarchive,
        label: context.l10n.equipment_menu_reactivate,
        isEnabled: (ids) => everyChecked(ids, (e) => !e.isActive),
        onInvoke: () => _applyRetirement(retire: false),
      ),
      BulkAction(
        id: 'editTags',
        icon: Icons.sell,
        label: context.l10n.equipment_bulkTags_action,
        onInvoke: () => showBulkEquipmentTagSheet(
          context,
          ref,
          equipmentIds: _selectedIds.toList(),
        ),
      ),
    ];
```

`maxInlineActions` in `_buildSelectionBar` (right after `_bulkActions`) is unchanged.

- [ ] **Step 11: Run the tests**

One at a time:

```bash
flutter test test/features/equipment/presentation/widgets/equipment_list_content_test.dart
flutter test test/features/equipment/presentation/pages/equipment_list_page_test.dart
flutter test test/features/equipment/presentation/widgets/bulk_equipment_tag_sheet_test.dart
flutter test test/features/equipment/data/services/bulk_equipment_tag_service_test.dart
flutter test test/shared/selection/
flutter test test/l10n/
flutter test test/architecture/
```

Expected: all PASS. (`equipment_list_page_test.dart` is the other test that pumps `EquipmentListContent`; the `equipment_tile_*` tests pump only `EquipmentListTile`, which this task does not touch.)

Then `flutter analyze lib/features/equipment lib/shared test/features/equipment`: No issues found.

- [ ] **Step 12: Commit**

```bash
dart format .
git add lib/features/equipment/data/services/bulk_equipment_tag_service.dart lib/features/equipment/presentation/providers/bulk_equipment_tag_provider.dart lib/features/equipment/presentation/widgets/bulk_equipment_tag_sheet.dart lib/features/equipment/presentation/widgets/equipment_list_content.dart lib/l10n/arb/app_en.arb lib/l10n/arb/app_ar.arb lib/l10n/arb/app_de.arb lib/l10n/arb/app_es.arb lib/l10n/arb/app_fr.arb lib/l10n/arb/app_he.arb lib/l10n/arb/app_hu.arb lib/l10n/arb/app_it.arb lib/l10n/arb/app_nl.arb lib/l10n/arb/app_pt.arb lib/l10n/arb/app_zh.arb lib/l10n/arb/app_localizations*.dart test/features/equipment/data/services/bulk_equipment_tag_service_test.dart test/features/equipment/presentation/widgets/bulk_equipment_tag_sheet_test.dart test/features/equipment/presentation/widgets/equipment_list_content_test.dart
git status --short
git commit -m "feat(equipment): edit tags on many items at once, with undo (#1942)" -m "The equipment selection bar gains Edit tags. It opens a sheet with one tri-state row per equipment tag and per tag already on a selected item, seeded from the items' tag counts, with the same Add dialog dives use scoped to equipment tags. Apply names every change in a confirmation, then BulkEquipmentTagService adds and removes the tags on every item in one transaction, reading the prior tag sets inside it, and notifies once. The SnackBar offers Undo for five seconds, which puts each item back to its exact prior set. Only equipment_tags rows change, so no equipment row is marked pending and an edit made between Apply and Undo survives. The new strings are translated into all ten locales."
```

`git status --short` must show nothing else staged.

### Task 9: UDDF round trip

**Files:**
- Create: `lib/core/services/export/uddf/uddf_tag_writers.dart`
- Create: `lib/core/services/export/uddf/uddf_equipment_tag_source.dart`
- Create: `lib/features/universal_import/data/models/import_tag_scopes.dart`
- Create: `lib/features/dive_import/data/services/import_equipment_tag_linker.dart`
- Modify: `lib/core/services/export/uddf/uddf_site_classification_writers.dart:29-38` (tag block of `writeSiteRefs`)
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (import after line 10; `buildApplicationData` parameters 731-757; equipment `<item>` nest 826-906; tag definitions 1130-1158, after the `appliestosites` element. Main's numbers: Task 1 changed two values in the tag block in place, without adding lines, but find each spot by the symbol named in Step 4)
- Modify: `lib/core/services/export/uddf/uddf_full_export_service.dart` (`_generateAllDataXml` 49-82 and its `buildApplicationData` call 365-388; wrappers 410-456, 460-529, 533-598)
- Modify: `lib/core/services/export/export_service.dart:473-599` (`exportAllDataToUddf`, `saveAllDataToUddfFile`)
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (imports 1-48; `exportDivesToUddf` 618-689; `saveUddfToFile` 1231-1302)
- Modify: `lib/core/services/export/uddf/uddf_import_parsers.dart` (`parseTag` 628-646; `parseFullSite` 919-926; `parseEquipmentItem` 983-1010)
- Modify: `lib/features/universal_import/data/services/payload_ref_keys.dart:37-42`
- Modify: `lib/features/universal_import/data/services/payload_merger.dart` (fields 67-68; `_namespaced` 291-298; `_rewriteAliases` 531-533)
- Modify: `lib/features/universal_import/data/services/payload_diver_expander.dart:319-347` (`_followLinks`)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (Task 1 changed this file, so locate by symbol: imports; the `ImportRepositories` class; directly after the `_importTags(...)` call in `import()`; the whole `_importTags` method. Main's lines were 110-138, 473-481 and 1058-1129; Task 1's scope rewrite inside `_importTags` added two lines)
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart:1867-1873` (`universalImportRepositories`)
- Create: `test/features/import_wizard/data/adapters/wizard_import_harness.dart` (helper, not a test)
- Test (create): `test/features/import_wizard/data/adapters/universal_adapter_equipment_tags_uddf_test.dart`
- Test (create): `test/core/services/export/uddf/uddf_equipment_tags_export_test.dart`
- Test (create): `test/features/universal_import/data/services/payload_merger_equipment_tag_refs_test.dart`
- Test (create): `test/features/universal_import/data/models/import_tag_scopes_test.dart`
- Test (create): `test/features/dive_import/data/services/import_equipment_tag_linker_test.dart`
- Test (create): `test/features/settings/presentation/providers/export_uddf_equipment_tags_test.dart`
- Test (modify): `test/core/services/export/uddf/uddf_equipment_item_parser_test.dart`
- Test (modify): `test/features/universal_import/data/services/payload_diver_expander_test.dart`
- Test (modify): `test/features/import_wizard/data/adapters/universal_adapter_repositories_test.dart`

**Interfaces:**
- Consumes: Task 1 `Tag.scopes`, `Tag.appliesTo(TagScope)`, `Tag.copyWith(scopes:)`, the default `Tag(...)` constructor giving `{TagScope.dives}`, `TagRepository.updateTag` widening a tag's scopes with no side effect but the row write (only narrowing unlinks), and Task 1b's "remaining callers" step's edits (the explicit `<appliestodives>` / `<appliestosites>` elements in `UddfExportBuilders.buildApplicationData`, values now `tag.appliesTo(...)`; `_importTags`'s scope lines); existing `TagRepository.getOrCreateTag(name, {diverId, scope})`, `getTagById`, `getTagByName`, `createTag`. Task 3 `TagScope.equipment`; `EquipmentTagRepository()` (no constructor arguments; a lazy `_db` getter, so constructing it needs no database) with `getTagIdsByEquipment(List<String> equipmentIds)`, `getTagsByEquipment()` (no arguments), `getTagsForEquipment(String equipmentId)` (ordered by name), `replaceTags(String equipmentId, List<String> tagIds, {bool notify = true})` and `addTags(List<String> equipmentIds, List<String> tagIds, {bool notify = true})` (skips existing pairs); `equipmentTagRepositoryProvider` (`lib/features/equipment/presentation/providers/equipment_tag_providers.dart`).
- Produces:
  - XML `<item>...<tags><tagref>tag_ID</tagref></tags></item>` under `<applicationdata><submersion><equipment>`; `<appliestoequipment>true|false</appliestoequipment>` in each `<tag>`.
  - `UddfTagWriters.writeTagRefs(XmlBuilder builder, List<String> tagIds)` in `lib/core/services/export/uddf/uddf_tag_writers.dart`.
  - `UddfEquipmentTagSource { Map<String, List<String>> tagIdsByItem; List<Tag> tags; }` and `Future<UddfEquipmentTagSource> loadEquipmentTagsForExport(EquipmentTagRepository repository, List<String> equipmentIds)` in `lib/core/services/export/uddf/uddf_equipment_tag_source.dart`.
  - Named parameter `Map<String, List<String>> equipmentTagIdsByItem = const {}` on `UddfExportBuilders.buildApplicationData`, `UddfFullExportService._generateAllDataXml`, `generateAllDataXmlForTest`, `exportAllDataToUddf`, `saveAllDataToUddfFile`, and `ExportService.exportAllDataToUddf` / `saveAllDataToUddfFile`.
  - `const Map<TagScope, String> importTagScopeKeys` and `Set<TagScope> importedTagScopes(Map<String, dynamic> data)` in `lib/features/universal_import/data/models/import_tag_scopes.dart`.
  - Equipment map key `tagRefs` (`List<String>`); tag map key `appliesToEquipment` (`bool?`).
  - `const Map<String, ImportEntityType> equipmentListRefTypes` in `payload_ref_keys.dart`.
  - `ImportRepositories.equipmentTagRepository` (`EquipmentTagRepository?`).
  - `ImportEquipmentTagLinker({required TagRepository tags, required EquipmentTagRepository links})` with `Future<void> link({required List<Map<String, dynamic>> items, required Map<String, String> equipmentIdMapping, required Map<String, String> tagIdMapping})` in `lib/features/dive_import/data/services/import_equipment_tag_linker.dart`.
  - Test helper `Future<UnifiedImportResult> importThroughWizard(WidgetTester tester, {required ImportPayload payload, required Diver diver, DuplicateAction duplicateAction = DuplicateAction.skip})` in `test/features/import_wizard/data/adapters/wizard_import_harness.dart`, for Task 10.
  - No ARB keys.

- [ ] **Step 1: Write the failing tests**

Create the harness `test/features/import_wizard/data/adapters/wizard_import_harness.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

/// Runs [payload] through [UniversalAdapter] the way the import wizard does:
/// buildBundle, checkDuplicates, then performImport. Every repository is the
/// real one over the current test database; only the parsed payload, the
/// active diver and the settings are supplied. Every item the review does
/// not flag is selected, and each flagged duplicate gets [duplicateAction].
///
/// [diver] must already exist in the database. Call from a testWidgets body
/// after setUpTestDatabase.
Future<UnifiedImportResult> importThroughWizard(
  WidgetTester tester, {
  required ImportPayload payload,
  required Diver diver,
  DuplicateAction duplicateAction = DuplicateAction.skip,
}) async {
  late UniversalAdapter adapter;
  await tester.pumpWidget(
    ProviderScope(
      // A fresh scope per import, so a second import in one test never
      // reads the first one's payload or cached lists.
      key: UniqueKey(),
      overrides: [
        universalImportNotifierProvider.overrideWith(
          (ref) => _PayloadImportNotifier(ref, payload),
        ),
        settingsProvider.overrideWith((ref) => _DefaultSettings()),
        currentDiverProvider.overrideWith((ref) async => diver),
        // The review's duplicate check reads the diver's gear and tags
        // through these; the other libraries stay empty.
        allEquipmentProvider.overrideWith(
          (ref) => EquipmentRepository().getAllEquipment(diverId: diver.id),
        ),
        tagsProvider.overrideWith(
          (ref) => TagRepository().getAllTags(diverId: diver.id),
        ),
        allTripsProvider.overrideWith((ref) async => []),
        sitesProvider.overrideWith((ref) async => []),
        allBuddiesProvider.overrideWith((ref) async => []),
        allDiveCentersProvider.overrideWith((ref) async => []),
        allCertificationsProvider.overrideWith((ref) async => []),
        diveTypesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            adapter = UniversalAdapter(ref: ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final result = await tester.runAsync(() async {
    final bundle = await adapter.checkDuplicates(await adapter.buildBundle());
    final selections = <ImportEntityType, Set<int>>{};
    final actions = <ImportEntityType, Map<int, DuplicateAction>>{};
    for (final MapEntry(key: type, value: group) in bundle.groups.entries) {
      selections[type] = {
        for (var i = 0; i < group.items.length; i++)
          if (!group.duplicateIndices.contains(i)) i,
      };
      actions[type] = {
        for (final i in group.duplicateIndices) i: duplicateAction,
      };
    }
    return adapter.performImport(bundle, selections, actions);
  });
  return result!;
}

class _PayloadImportNotifier extends UniversalImportNotifier {
  _PayloadImportNotifier(super.ref, ImportPayload payload) {
    state = state.copyWith(payload: payload);
  }
}

class _DefaultSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _DefaultSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
```

Create `test/features/import_wizard/data/adapters/universal_adapter_equipment_tags_uddf_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_equipment_tag_source.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../helpers/test_database.dart';
import 'wizard_import_harness.dart';

const _diverId = 'diver-1';
final _now = DateTime(2026);

Diver _diver() =>
    Diver(id: _diverId, name: 'Test Diver', createdAt: _now, updatedAt: _now);

const _travelReg = EquipmentItem(
  id: '',
  diverId: _diverId,
  name: 'Travel reg',
  type: EquipmentType.regulator,
);

/// Equipment tags through a UDDF backup and a restore driven by
/// UniversalAdapter.performImport (issue #1942). The wizard keeps only the
/// payload's entity lists, so a test of the entity importer alone could pass
/// while a real restore lost the links.
void main() {
  Future<ImportPayload> parse(String xml) =>
      UddfImportParser().parse(Uint8List.fromList(utf8.encode(xml)));

  /// Exports [reg] with its tags the way the export providers do.
  Future<String> exportWithTags(EquipmentItem reg) async {
    final source = await loadEquipmentTagsForExport(EquipmentTagRepository(), [
      reg.id,
    ]);
    return UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      equipment: [reg],
      tags: source.tags,
      equipmentTagIdsByItem: source.tagIdsByItem,
    );
  }

  /// The test database, started over with only the test diver in it.
  Future<void> freshDatabase(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tearDownTestDatabase();
      await setUpTestDatabase();
      await DiverRepository().createDiver(_diver());
    });
  }

  testWidgets(
    'equipment-only and shared tags survive a backup and restore',
    (tester) async {
      await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);

      final xml = (await tester.runAsync(() async {
        await DiverRepository().createDiver(_diver());
        final tags = TagRepository();
        final rental = await tags.getOrCreateTag(
          'Rental',
          diverId: _diverId,
          scope: TagScope.equipment,
        );
        // A dive tag the diver also uses on gear.
        await tags.getOrCreateTag('Cold water', diverId: _diverId);
        final cold = await tags.getOrCreateTag(
          'Cold water',
          diverId: _diverId,
          scope: TagScope.equipment,
        );
        final reg = await EquipmentRepository().createEquipment(_travelReg);
        await EquipmentTagRepository().replaceTags(reg.id, [
          rental.id,
          cold.id,
        ]);
        return exportWithTags(reg);
      }))!;

      await freshDatabase(tester);
      final payload = (await tester.runAsync(() => parse(xml)))!;
      final result = await importThroughWizard(
        tester,
        payload: payload,
        diver: _diver(),
      );
      expect(result.errorMessage, isNull);

      final restored = (await tester.runAsync(() async {
        final reg = (await EquipmentRepository().getAllEquipment(
          diverId: _diverId,
        )).single;
        return EquipmentTagRepository().getTagsForEquipment(reg.id);
      }))!;
      expect(restored.map((t) => t.name), ['Cold water', 'Rental']);
      expect(restored.first.scopes, {TagScope.dives, TagScope.equipment});
      expect(restored.last.scopes, {TagScope.equipment});
    },
  );

  testWidgets(
    'a tag defined without appliestoequipment is widened only when an item '
    'references it',
    (tester) async {
      await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      await tester.runAsync(() => DiverRepository().createDiver(_diver()));

      final exported = (await tester.runAsync(
        () => UddfFullExportService().generateAllDataXmlForTest(
          dives: const [],
          equipment: const [
            EquipmentItem(
              id: 'reg',
              name: 'Travel reg',
              type: EquipmentType.regulator,
            ),
          ],
          tags: [
            Tag(id: 'cold', name: 'Cold water', createdAt: _now, updatedAt: _now),
            Tag(id: 'night', name: 'Night', createdAt: _now, updatedAt: _now),
          ],
          equipmentTagIdsByItem: const {
            'reg': ['cold'],
          },
        ),
      ))!;
      // A file written before equipment tags existed.
      final xml = exported.replaceAll(
        RegExp(r'\s*<appliestoequipment>\w+</appliestoequipment>'),
        '',
      );
      expect(xml, isNot(contains('appliestoequipment')));

      final payload = (await tester.runAsync(() => parse(xml)))!;
      final result = await importThroughWizard(
        tester,
        payload: payload,
        diver: _diver(),
      );
      expect(result.errorMessage, isNull);

      final byName = (await tester.runAsync(() async {
        return {
          for (final t in await TagRepository().getAllTags(diverId: _diverId))
            t.name: t,
        };
      }))!;
      expect(byName['Cold water']!.scopes, {
        TagScope.dives,
        TagScope.equipment,
      });
      expect(byName['Night']!.scopes, {TagScope.dives});
    },
  );

  testWidgets(
    're-importing onto existing gear unions its tags and never removes one',
    (tester) async {
      await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);

      final xml = (await tester.runAsync(() async {
        await DiverRepository().createDiver(_diver());
        final tags = TagRepository();
        final rental = await tags.getOrCreateTag(
          'Rental',
          diverId: _diverId,
          scope: TagScope.equipment,
        );
        final cold = await tags.getOrCreateTag(
          'Cold water',
          diverId: _diverId,
          scope: TagScope.equipment,
        );
        final reg = await EquipmentRepository().createEquipment(_travelReg);
        await EquipmentTagRepository().replaceTags(reg.id, [
          rental.id,
          cold.id,
        ]);
        return exportWithTags(reg);
      }))!;

      // The same regulator on another device, tagged there with
      // "Needs repair" and its own "Rental".
      await freshDatabase(tester);
      final localId = (await tester.runAsync(() async {
        final tags = TagRepository();
        final repair = await tags.getOrCreateTag(
          'Needs repair',
          diverId: _diverId,
          scope: TagScope.equipment,
        );
        final rental = await tags.getOrCreateTag(
          'Rental',
          diverId: _diverId,
          scope: TagScope.equipment,
        );
        final reg = await EquipmentRepository().createEquipment(_travelReg);
        await EquipmentTagRepository().replaceTags(reg.id, [
          repair.id,
          rental.id,
        ]);
        return reg.id;
      }))!;

      final payload = (await tester.runAsync(() => parse(xml)))!;
      // Twice: the second run finds every tag already linked.
      for (var run = 0; run < 2; run++) {
        final result = await importThroughWizard(
          tester,
          payload: payload,
          diver: _diver(),
        );
        expect(result.errorMessage, isNull);
      }

      final (items, names, ids) = (await tester.runAsync(() async {
        final links = EquipmentTagRepository();
        return (
          await EquipmentRepository().getAllEquipment(diverId: _diverId),
          [for (final t in await links.getTagsForEquipment(localId)) t.name],
          (await links.getTagIdsByEquipment([localId]))[localId] ??
              const <String>[],
        );
      }))!;
      expect(
        items.map((e) => e.id),
        [localId],
        reason: 'the flagged duplicate links to the local item',
      );
      expect(names, ['Cold water', 'Needs repair', 'Rental']);
      expect(ids, hasLength(3), reason: 'a repeated import adds no link');
    },
  );
}
```

Create `test/core/services/export/uddf/uddf_equipment_tags_export_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:xml/xml.dart';

/// Equipment tags in the full backup (issue #1942).
void main() {
  final now = DateTime.utc(2026, 3, 1);
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
  );
  const fins = EquipmentItem(id: 'fins', name: 'Fins', type: EquipmentType.fins);
  final rental = Tag(
    id: 't1',
    name: 'Rental',
    createdAt: now,
    updatedAt: now,
    scopes: const {TagScope.equipment},
  );
  final night = Tag(id: 't2', name: 'Night', createdAt: now, updatedAt: now);
  final checkIn = EquipmentObservation(
    id: 'o1',
    equipmentId: 'reg',
    observedAt: now,
    status: ObservationStatus.issue,
    issueTags: const [ObservationTag.freeFlow],
    createdAt: now,
    updatedAt: now,
  );

  Future<XmlDocument> export() async => XmlDocument.parse(
    await UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      equipment: const [reg, fins],
      observations: [checkIn],
      tags: [rental, night],
      equipmentTagIdsByItem: const {
        'reg': ['t1'],
      },
    ),
  );

  XmlElement item(XmlDocument doc, String id) => doc
      .findAllElements('item')
      .singleWhere((e) => e.getAttribute('id') == 'equip_$id');

  test('a tagged item carries its tag refs as a direct child', () async {
    final doc = await export();
    final refs = item(
      doc,
      'reg',
    ).findElements('tags').expand((t) => t.findElements('tagref'));
    expect(refs.map((e) => e.innerText), ['tag_t1']);
    expect(item(doc, 'fins').findElements('tags'), isEmpty);
  });

  test("a check-in's tags stay inside the check-in", () async {
    final doc = await export();
    final observation = item(doc, 'reg').findAllElements('observation').single;
    expect(
      observation
          .findElements('tags')
          .single
          .findElements('tag')
          .map((e) => e.innerText),
      ['freeFlow'],
    );
    expect(item(doc, 'reg').findElements('tags').single.findElements('tag'), isEmpty);
  });

  test('each tag definition says whether it applies to equipment', () async {
    final doc = await export();
    String flag(String id) => doc
        .findAllElements('tag')
        .singleWhere((e) => e.getAttribute('id') == 'tag_$id')
        .findElements('appliestoequipment')
        .single
        .innerText;
    expect(flag('t1'), 'true');
    expect(flag('t2'), 'false');
  });
}
```

Append to `test/core/services/export/uddf/uddf_equipment_item_parser_test.dart`, inside `main()` after the existing group:

```dart
  group('parseEquipmentItem tags (#1942)', () {
    test("an item's own tag refs are read, never a check-in's tags", () {
      final item = UddfImportParsers.parseEquipmentItem(
        XmlDocument.parse('''
<item id="equip_reg">
  <name>Reg</name>
  <observations>
    <observation id="obs_1">
      <date>2026-03-14T11:00:00Z</date>
      <status>issue</status>
      <tags><tag>freeFlow</tag></tags>
    </observation>
  </observations>
  <tags><tagref>tag_t1</tagref><tagref> </tagref></tags>
</item>
''').rootElement,
      );
      expect(item['tagRefs'], ['tag_t1']);
      expect((item['observations'] as List).single['tags'], ['freeFlow']);
    });

    test('an untagged item carries no refs', () {
      final item = UddfImportParsers.parseEquipmentItem(
        XmlDocument.parse(
          '<item id="equip_fins"><name>Fins</name></item>',
        ).rootElement,
      );
      expect(item.containsKey('tagRefs'), isFalse);
    });
  });

  test('a tag definition reads its equipment flag, null when absent', () {
    Map<String, dynamic> parse(String body) => UddfImportParsers.parseTag(
      XmlDocument.parse(
        '<tag id="tag_t1"><name>Rental</name>$body</tag>',
      ).rootElement,
    );
    expect(
      parse('<appliestoequipment>true</appliestoequipment>')['appliesToEquipment'],
      isTrue,
    );
    expect(parse('')['appliesToEquipment'], isNull);
  });
```

Create `test/features/universal_import/data/services/payload_merger_equipment_tag_refs_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/payload_merger.dart';

/// Equipment tag references across a multi-file import (issue #1942).
void main() {
  const merger = PayloadMerger();

  ImportPayload payloadWithItem(String name, {bool definesTag = false}) =>
      ImportPayload(
        entities: {
          ImportEntityType.equipment: [
            {
              'uddfId': 'equip_1',
              'name': name,
              'type': 'regulator',
              'tagRefs': ['tag_1'],
            },
          ],
          if (definesTag)
            ImportEntityType.tags: [
              {'uddfId': 'tag_1', 'name': 'Rental'},
            ],
        },
      );

  List<Object?> refsOf(ImportPayload merged, String name) =>
      merged
              .entitiesOf(ImportEntityType.equipment)
              .firstWhere((e) => e['name'] == name)['tagRefs']
          as List<Object?>;

  test("item tag refs are namespaced per file, like a site's", () {
    final merged = merger.merge([
      FilePayload(
        fileId: 'a',
        fileName: 'a.uddf',
        payload: payloadWithItem('First reg'),
      ),
      FilePayload(
        fileId: 'b',
        fileName: 'b.uddf',
        payload: payloadWithItem('Second reg'),
      ),
    ]);
    expect(refsOf(merged, 'First reg'), ['a:tag_1']);
    expect(refsOf(merged, 'Second reg'), ['b:tag_1']);
  });

  test('an item follows its tag when the tag folds into a namesake', () {
    final merged = merger.merge([
      FilePayload(
        fileId: 'a',
        fileName: 'a.uddf',
        payload: payloadWithItem('First reg', definesTag: true),
      ),
      FilePayload(
        fileId: 'b',
        fileName: 'b.uddf',
        payload: payloadWithItem('Second reg', definesTag: true),
      ),
    ]);
    expect(merged.entitiesOf(ImportEntityType.tags), hasLength(1));
    expect(refsOf(merged, 'Second reg'), ['a:tag_1']);
  });
}
```

Append to `test/features/universal_import/data/services/payload_diver_expander_test.dart`, after the test `"a site's own tags follow the site (#1765)"` (ends at line 244):

```dart
  test("an item's own tags follow the item (#1942)", () {
    final out = _expand(
      const ImportPayload(
        entities: {
          ImportEntityType.dives: [
            {
              SourceDiver.mapKey: _bo,
              'equipmentRefs': ['fins'],
            },
            {SourceDiver.mapKey: _ann},
          ],
          ImportEntityType.equipment: [
            {
              'uddfId': 'fins',
              'tagRefs': ['Travel'],
            },
          ],
          ImportEntityType.tags: [
            {'uddfId': 'Travel', 'name': 'Travel'},
          ],
        },
        sourceDivers: [
          SourceDiver(key: _ann, name: 'Ann Lee', diveCount: 1),
          SourceDiver(key: _bo, name: 'Bo Ray', diveCount: 1),
        ],
      ),
    );
    expect(_targets(out, ImportEntityType.equipment, 'fins'), [_newBo]);
    expect(_targets(out, ImportEntityType.tags, 'Travel'), [_newBo]);
  });
```

Create `test/features/universal_import/data/models/import_tag_scopes_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/universal_import/data/models/import_tag_scopes.dart';

void main() {
  test('every tag scope has an import key', () {
    expect(importTagScopeKeys.keys.toSet(), TagScope.values.toSet());
  });

  test('a map that says nothing is a dive tag, as before scopes existed', () {
    expect(importedTagScopes(const {}), {TagScope.dives});
  });

  test('each flag the map sets is honoured', () {
    expect(
      importedTagScopes(const {
        'appliesToDives': false,
        'appliesToEquipment': true,
      }),
      {TagScope.equipment},
    );
    expect(importedTagScopes(const {'appliesToSites': true}), {
      TagScope.dives,
      TagScope.sites,
    });
  });

  test('a map turning every scope off is read as a dive tag', () {
    expect(
      importedTagScopes(const {
        'appliesToDives': false,
        'appliesToSites': false,
        'appliesToEquipment': false,
      }),
      {TagScope.dives},
    );
  });
}
```

Create `test/features/dive_import/data/services/import_equipment_tag_linker_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_import/data/services/import_equipment_tag_linker.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late String regId;
  late Tag night;
  late Tag rental;
  late ImportEquipmentTagLinker link;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime(2026);
    await DiverRepository().createDiver(
      Diver(id: 'd1', name: 'Diver', createdAt: now, updatedAt: now),
    );
    regId = (await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: '',
        diverId: 'd1',
        name: 'Reg',
        type: EquipmentType.regulator,
      ),
    )).id;
    night = await TagRepository().getOrCreateTag('Night', diverId: 'd1');
    rental = await TagRepository().getOrCreateTag(
      'Rental',
      diverId: 'd1',
      scope: TagScope.equipment,
    );
    link = ImportEquipmentTagLinker(
      tags: TagRepository(),
      links: EquipmentTagRepository(),
    );
  });

  tearDown(tearDownTestDatabase);

  Future<List<String>> tagNamesOfReg() async => [
    for (final t in await EquipmentTagRepository().getTagsForEquipment(regId))
      t.name,
  ];

  test('links resolved refs, drops unknown ones and widens a dive tag', () async {
    await link.link(
      items: const [
        {
          'uddfId': 'equip_1',
          'name': 'Reg',
          'tagRefs': ['tag_a', 'tag_b', 'tag_missing'],
        },
      ],
      equipmentIdMapping: {'equip_1': regId},
      tagIdMapping: {'tag_a': night.id, 'tag_b': rental.id},
    );
    expect(await tagNamesOfReg(), ['Night', 'Rental']);
    final widened = await TagRepository().getTagById(night.id);
    expect(widened!.scopes, {TagScope.dives, TagScope.equipment});
  });

  test('adds to the tags an item has and removes none', () async {
    await EquipmentTagRepository().replaceTags(regId, [rental.id]);
    await link.link(
      items: const [
        {
          'uddfId': 'equip_1',
          'tagRefs': ['tag_a'],
        },
      ],
      equipmentIdMapping: {'equip_1': regId},
      tagIdMapping: {'tag_a': night.id},
    );
    expect(await tagNamesOfReg(), ['Night', 'Rental']);
  });

  test('an item that resolved to no local item is left alone', () async {
    await link.link(
      items: const [
        {
          'uddfId': 'equip_unselected',
          'tagRefs': ['tag_b'],
        },
      ],
      equipmentIdMapping: const {},
      tagIdMapping: {'tag_b': rental.id},
    );
    expect(await tagNamesOfReg(), isEmpty);
  });
}
```

Create `test/features/settings/presentation/providers/export_uddf_equipment_tags_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Both full UDDF export paths pass each item's tag ids and every tag
/// definition those ids need (issue #1942).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String regId;
  late String rentalId;
  late String clubId;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.utc(2026, 3, 1);
    final divers = DiverRepository();
    await divers.createDiver(
      Diver(id: 'me', name: 'Me', isDefault: true, createdAt: now, updatedAt: now),
    );
    await divers.createDiver(
      Diver(id: 'other', name: 'Other', createdAt: now, updatedAt: now),
    );
    final reg = await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: '',
        diverId: 'me',
        name: 'Apeks XTX',
        type: EquipmentType.regulator,
      ),
    );
    final rental = await TagRepository().getOrCreateTag(
      'Rental',
      diverId: 'me',
      scope: TagScope.equipment,
    );
    // Another profile's tag on this diver's gear: the diver's own tag list
    // lacks it, so only the by-id lookup can supply its definition.
    final club = await TagRepository().getOrCreateTag(
      'Club kit',
      diverId: 'other',
      scope: TagScope.equipment,
    );
    await EquipmentTagRepository().replaceTags(reg.id, [rental.id, club.id]);
    regId = reg.id;
    rentalId = rental.id;
    clubId = club.id;
  });

  tearDown(tearDownTestDatabase);

  ProviderContainer make(_CapturingExportService export) {
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier()..state = 'me',
        ),
        settingsProvider.overrideWith((ref) => _FixedSettings()),
        exportServiceProvider.overrideWithValue(export),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  for (final save in [false, true]) {
    test('${save ? 'saving' : 'sharing'} passes item tag ids and their '
        'definitions', () async {
      final export = _CapturingExportService();
      final container = make(export);
      final notifier = container.read(exportNotifierProvider.notifier);
      await (save ? notifier.saveUddfToFile() : notifier.exportDivesToUddf());

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.success, reason: state.message);
      expect(export.tagIdsByItem!.keys, [regId]);
      expect(export.tagIdsByItem![regId], unorderedEquals([rentalId, clubId]));
      final ids = [for (final t in export.tags) t.id];
      expect(ids.where((id) => id == rentalId), hasLength(1));
      expect(ids, contains(clubId));
    });
  }
}

class _CapturingExportService implements ExportService {
  Map<String, List<String>>? tagIdsByItem;
  List<Tag> tags = const [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #exportAllDataToUddf || name == #saveAllDataToUddfFile) {
      tagIdsByItem =
          invocation.namedArguments[#equipmentTagIdsByItem]
              as Map<String, List<String>>;
      tags = invocation.namedArguments[#tags] as List<Tag>;
      return name == #exportAllDataToUddf
          ? Future<String>.value('/tmp/export.uddf')
          : Future<String?>.value('/tmp/export.uddf');
    }
    return null;
  }
}

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
```

In `test/features/import_wizard/data/adapters/universal_adapter_repositories_test.dart`, after line 29 (`expect(repos!.serviceRecordRepository, isNotNull);`) add:

```dart
    // Without it imported gear arrives with none of its tags (#1942).
    expect(repos!.equipmentTagRepository, isNotNull);
```

- [ ] **Step 2: Run them and confirm they fail**

Run each, one at a time:

- `flutter test test/core/services/export/uddf/uddf_equipment_tags_export_test.dart`; Expected: compile error, no named parameter `equipmentTagIdsByItem` on `generateAllDataXmlForTest`.
- `flutter test test/core/services/export/uddf/uddf_equipment_item_parser_test.dart`; Expected: the two existing tests pass; `an item's own tag refs are read` fails with `Expected: ['tag_t1'] Actual: <null>`; the equipment-flag test fails with `Expected: true Actual: <null>`.
- `flutter test test/features/universal_import/data/services/payload_merger_equipment_tag_refs_test.dart`; Expected: `Expected: ['a:tag_1'] Actual: ['tag_1']`.
- `flutter test test/features/universal_import/data/services/payload_diver_expander_test.dart`; Expected: the new test fails with `Expected: ['new:macdive:bo'] Actual: ['diver:active']` (the tag went to the primary profile).
- `flutter test test/features/universal_import/data/models/import_tag_scopes_test.dart`; Expected: compile error, `import_tag_scopes.dart` not found.
- `flutter test test/features/dive_import/data/services/import_equipment_tag_linker_test.dart`; Expected: compile error, `import_equipment_tag_linker.dart` not found.
- `flutter test test/features/import_wizard/data/adapters/universal_adapter_equipment_tags_uddf_test.dart`; Expected: compile error, `uddf_equipment_tag_source.dart` not found.
- `flutter test test/features/settings/presentation/providers/export_uddf_equipment_tags_test.dart`; Expected: a `TypeError` (null is not a `Map<String, List<String>>`) from `#equipmentTagIdsByItem`, reported as an error state.
- `flutter test test/features/import_wizard/data/adapters/universal_adapter_repositories_test.dart`; Expected: compile error, no getter `equipmentTagRepository`.

- [ ] **Step 3: Shared tag-ref writer**

Create `lib/core/services/export/uddf/uddf_tag_writers.dart`:

```dart
import 'package:xml/xml.dart';

/// UDDF writer for tag references, shared by every record that carries
/// tags outside a dive: dive sites (issue #1765) and equipment items (issue
/// #1942). Each reference names a `<tag id="tag_ID">` definition under
/// `<applicationdata><submersion><tags>`, which the full importer resolves.
class UddfTagWriters {
  const UddfTagWriters._();

  /// `<tags><tagref>tag_ID</tagref>...</tags>` for [tagIds], or nothing
  /// when there are none.
  static void writeTagRefs(XmlBuilder builder, List<String> tagIds) {
    if (tagIds.isEmpty) return;
    builder.element(
      'tags',
      nest: () {
        for (final id in tagIds) {
          builder.element('tagref', nest: 'tag_$id');
        }
      },
    );
  }
}
```

In `uddf_site_classification_writers.dart`, add the import
`import 'package:submersion/core/services/export/uddf/uddf_tag_writers.dart';`
after line 3, and replace lines 29-38:

```dart
    if (tagIds.isNotEmpty) {
      builder.element(
        'tags',
        nest: () {
          for (final id in tagIds) {
            builder.element('tagref', nest: 'tag_$id');
          }
        },
      );
    }
```

with:

```dart
    UddfTagWriters.writeTagRefs(builder, tagIds);
```

- [ ] **Step 4: Export builders and services**

`uddf_export_builders.dart`:

1. After line 10 add `import 'package:submersion/core/services/export/uddf/uddf_tag_writers.dart';`.
2. In `buildApplicationData`, after `List<EquipmentItem>? equipment,` (line 733) add:

```dart
    // Each item's tag ids (issue #1942); an item absent from it writes none.
    Map<String, List<String>> equipmentTagIdsByItem = const {},
```

3. Inside the equipment `<item>` nest, after the `if (mine.isNotEmpty) { ... }` observations block that ends at line 904 and before the nest's closing `},` at line 905, add:

```dart
                        // Tags (issue #1942): a direct child of the item, so
                        // the importer never reads a check-in's <tags>,
                        // which sits inside <observations>.
                        UddfTagWriters.writeTagRefs(
                          builder,
                          equipmentTagIdsByItem[item.id] ?? const [],
                        );
```

4. In the tag definitions block, after the `appliestosites` element (lines 1149-1152, whose value Task 1 changed to `tag.appliesTo(TagScope.sites).toString()`), add:

```dart
                        builder.element(
                          'appliestoequipment',
                          nest: tag.appliesTo(TagScope.equipment).toString(),
                        );
```

`uddf_full_export_service.dart`: add the parameter

```dart
    // Each exported item's tag ids (issue #1942).
    Map<String, List<String>> equipmentTagIdsByItem = const {},
```

after `Map<String, List<String>> siteTagIdsBySite = const {},` in all four
signatures (lines 70, 416, 481, 554), add
`equipmentTagIdsByItem: equipmentTagIdsByItem,` after
`siteTagIdsBySite: siteTagIdsBySite,` in the three forwarding calls (lines
439, 513, 586), and in the `buildApplicationData` call (line 367) add
`equipmentTagIdsByItem: equipmentTagIdsByItem,` right after
`equipment: equipment,`.

`export_service.dart`: add the same parameter after
`Map<String, List<String>> siteTagIdsBySite = const {},` in
`exportAllDataToUddf` (line 492) and `saveAllDataToUddfFile` (line 556), and
`equipmentTagIdsByItem: equipmentTagIdsByItem,` after
`siteTagIdsBySite: siteTagIdsBySite,` in their bodies (lines 523, 587).

- [ ] **Step 5: Export loader and providers**

Create `lib/core/services/export/uddf/uddf_equipment_tag_source.dart`:

```dart
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The tags a UDDF export writes for its equipment items (issue #1942).
class UddfEquipmentTagSource {
  /// Tag ids per exported item.
  final Map<String, List<String>> tagIdsByItem;

  /// Every tag those ids name.
  final List<Tag> tags;

  const UddfEquipmentTagSource({
    this.tagIdsByItem = const {},
    this.tags = const [],
  });
}

/// Loads the tags of [equipmentIds] and resolves each by id.
///
/// By id, not from the current diver's tag list: gear can carry a tag
/// another profile owns, and a reference written without its definition is
/// dropped on import. The same reasoning as the site tags (#1765).
Future<UddfEquipmentTagSource> loadEquipmentTagsForExport(
  EquipmentTagRepository repository,
  List<String> equipmentIds,
) async {
  final tagIdsByItem = await repository.getTagIdsByEquipment(equipmentIds);
  final tagsByItem = await repository.getTagsByEquipment();
  final tags = <String, Tag>{
    for (final id in equipmentIds)
      for (final tag in tagsByItem[id] ?? const <Tag>[]) tag.id: tag,
  };
  return UddfEquipmentTagSource(
    tagIdsByItem: tagIdsByItem,
    tags: tags.values.toList(),
  );
}
```

`export_providers.dart`:

1. Add imports, next to the existing ones at lines 15 and 29:
   `import 'package:submersion/core/services/export/uddf/uddf_equipment_tag_source.dart';`
   and
   `import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';`.
2. In `exportDivesToUddf`, after the `customSiteTypes` statement that ends at line 635, add:

```dart
      // Equipment tags (issue #1942): each item's tag ids and the tags they
      // name, resolved by id like the site tags above.
      final equipmentTags = await loadEquipmentTagsForExport(
        _ref.read(equipmentTagRepositoryProvider),
        [for (final e in equipment) e.id],
      );
```

   In its `exportAllDataToUddf` call, replace line 667
   (`tags: mergeById(tags, siteClassification.siteTags, (tag) => tag.id),`) with:

```dart
        tags: mergeById(
          mergeById(tags, siteClassification.siteTags, (tag) => tag.id),
          equipmentTags.tags,
          (tag) => tag.id,
        ),
```

   and after `siteTagIdsBySite: siteClassification.tagIdsBySite,` (line 672) add
   `equipmentTagIdsByItem: equipmentTags.tagIdsByItem,`.
3. Make the same three edits in `saveUddfToFile`: the loader after line 1248, the
   `tags:` replacement at line 1280, the new argument after line 1285.

- [ ] **Step 6: Parsers**

`uddf_import_parsers.dart`:

1. In `parseTag`, replace the comment at line 637 with
   `// Where the tag is offered (issues #1765, #1942); null when a file predates it.`
   and after the `appliesToSites` assignment (ends line 643) add:

```dart
    tag['appliesToEquipment'] = _parseBool(
      getElementText(tagElement, 'appliestoequipment'),
    );
```

2. Add a helper after `_parseBool` (line 652):

```dart
  /// The `<tagref>` values of [parent]'s own `<tags>` child (issues #1765,
  /// #1942). `findElements` matches direct children only, so a check-in's
  /// `<tags>` inside an item's `<observations>` is never read as the item's.
  static List<String> _tagRefsOf(XmlElement parent) => [
    for (final ref
        in parent
            .findElements('tags')
            .expand((s) => s.findElements('tagref')))
      if (ref.innerText.trim().isNotEmpty) ref.innerText.trim(),
  ];
```

3. In `parseFullSite`, replace lines 919-926 (the `final tagRefs = [ ... ];` list
   and the `if (tagRefs.isNotEmpty)` line) with:

```dart
    final tagRefs = _tagRefsOf(siteElement);
    if (tagRefs.isNotEmpty) site['tagRefs'] = tagRefs;
```

4. In `parseEquipmentItem`, before `return item;` (line 1010) add:

```dart
    // Tags (issue #1942), carried on the map because the import wizard
    // keeps only entity lists. The entity importer links them once the
    // file's tags exist.
    final tagRefs = _tagRefsOf(itemElement);
    if (tagRefs.isNotEmpty) item['tagRefs'] = tagRefs;
```

- [ ] **Step 7: Payload plumbing**

`payload_ref_keys.dart`, after `siteListRefTypes` (line 42):

```dart

/// Equipment map fields holding a list of entity references (issue #1942).
const Map<String, ImportEntityType> equipmentListRefTypes = {
  'tagRefs': ImportEntityType.tags,
};
```

`payload_merger.dart`:

1. After line 68 add:

```dart

  /// Equipment map fields holding a list of entity references (issue #1942).
  static final _equipmentListRefFields = equipmentListRefTypes.keys.toList();
```

2. Replace the equipment branch of `_namespaced` (lines 291-298):

```dart
    if (type == ImportEntityType.equipment) {
      _rewriteNested(
        item,
        'components',
        _componentRefFields,
        (ref) => '$fileId:$ref',
      );
    }
```

with:

```dart
    if (type == ImportEntityType.equipment) {
      _rewriteNested(
        item,
        'components',
        _componentRefFields,
        (ref) => '$fileId:$ref',
      );
      // An item's tag references point at namespaced tag ids, like a
      // site's (issue #1942).
      for (final field in _equipmentListRefFields) {
        final refs = item[field];
        if (refs is List) {
          item[field] = [
            for (final ref in refs)
              if (ref is String && ref.isNotEmpty) '$fileId:$ref' else ref,
          ];
        }
      }
    }
```

3. Replace the equipment loop of `_rewriteAliases` (lines 531-533):

```dart
    for (final item in entities[ImportEntityType.equipment] ?? const []) {
      _rewriteNested(item, 'components', _componentRefFields, resolve);
    }
```

with:

```dart
    for (final item in entities[ImportEntityType.equipment] ?? const []) {
      _rewriteNested(item, 'components', _componentRefFields, resolve);
      // An item's tag references follow a folded tag (issue #1942).
      for (final field in _equipmentListRefFields) {
        final refs = item[field];
        if (refs is List) {
          item[field] = [
            for (final ref in refs)
              if (ref is String) resolve(ref) else ref,
          ];
        }
      }
    }
```

`payload_diver_expander.dart`, in `_followLinks`: change the doc comment's
first sentence (lines 319-320) to
"Items reached through another item follow it: an item's components, parent
and tags, a set's items, a course's instructor, a site's tags." and replace
the equipment loop (lines 340-347):

```dart
      for (final item in source.entitiesOf(ImportEntityType.equipment)) {
        final components = item['components'];
        follow(ImportEntityType.equipment, ImportEntityType.equipment, item, [
          item['parentRef'],
          if (components is List)
            for (final c in components)
              if (c is Map) c[componentRefTypes.keys.single],
        ]);
      }
```

with:

```dart
      for (final item in source.entitiesOf(ImportEntityType.equipment)) {
        final components = item['components'];
        follow(ImportEntityType.equipment, ImportEntityType.equipment, item, [
          item['parentRef'],
          if (components is List)
            for (final c in components)
              if (c is Map) c[componentRefTypes.keys.single],
        ]);
        // An item's own tags follow it (issue #1942), like a site's.
        for (final MapEntry(:key, value: type)
            in equipmentListRefTypes.entries) {
          final refs = item[key];
          follow(ImportEntityType.equipment, type, item, [
            if (refs is List) ...refs,
          ]);
        }
      }
```

- [ ] **Step 8: Tag scopes on import**

Create `lib/features/universal_import/data/models/import_tag_scopes.dart`:

```dart
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The key each tag scope's flag rides under on an imported tag map
/// (issues #1765, #1942). Parsers write them and UddfEntityImporter reads
/// them. A missing key means the source said nothing about that scope.
const Map<TagScope, String> importTagScopeKeys = {
  TagScope.dives: 'appliesToDives',
  TagScope.sites: 'appliesToSites',
  TagScope.equipment: 'appliesToEquipment',
};

/// The scopes an imported tag map asks for. A scope the map says nothing
/// about keeps its old default: dives on, the others off, so a file that
/// predates scopes imports dive tags as it always did. A map that turns
/// every scope off is read as a dive tag, since a tag must apply somewhere.
Set<TagScope> importedTagScopes(Map<String, dynamic> data) {
  final scopes = {
    for (final MapEntry(key: scope, value: key) in importTagScopeKeys.entries)
      if (data[key] as bool? ?? scope == TagScope.dives) scope,
  };
  return scopes.isEmpty ? const {TagScope.dives} : scopes;
}
```

In `uddf_entity_importer.dart`, add
`import 'package:submersion/features/universal_import/data/models/import_tag_scopes.dart';`
next to the `import_enums.dart` import (main line 68, above every Task 1 edit), and replace the whole
`_importTags` method, found by name (main lines 1058-1129; Task 1 changed only its scope
lines) with:

```dart
  Future<int> _importTags(
    List<Map<String, dynamic>> items,
    Set<int> selected,
    TagRepository repository,
    String diverId,
    Map<String, String> idMapping,
    DateTime now,
    ImportProgressCallback? onProgress,
  ) async {
    if (selected.isEmpty) return 0;
    onProgress?.call(ImportPhase.tags, 0, selected.length);
    var count = 0;

    for (var i = 0; i < items.length; i++) {
      if (!selected.contains(i)) continue;
      final tagData = items[i];
      final name = tagData['name'] as String?;
      if (name == null || name.isEmpty) continue;

      final uddfId = tagData['uddfId'] as String?;

      // Reuse the tag this diver already has by that name rather than
      // minting a second uuid for it, the same guard _importDiveTypes
      // applies to colliding slugs. `tags` is uniquely indexed on (diver
      // scope, case-folded name) since v149, so a blind mint would collide
      // (#1032). Scopes (issues #1765, #1942): a file that says nothing
      // about one keeps its default, and a site or item that references
      // the tag widens it later.
      final scopes = importedTagScopes(tagData);

      final existing = await repository.getTagByName(name, diverId: diverId);
      if (existing != null) {
        if (uddfId != null) idMapping[uddfId] = existing.id;
        // Keep every use the file gives the tag.
        for (final scope in scopes) {
          if (!existing.appliesTo(scope)) {
            await repository.getOrCreateTag(
              name,
              diverId: diverId,
              scope: scope,
            );
          }
        }
        continue;
      }

      final newId = _uuid.v4();
      final tag = Tag(
        id: newId,
        diverId: diverId,
        name: name,
        // The parser stores the color under `colorHex`; reading `color`
        // alone dropped every imported tag's color. `color` stays as a
        // fallback for maps other adapters build.
        colorHex: tagData['colorHex'] as String? ?? tagData['color'] as String?,
        createdAt: now,
        updatedAt: now,
        scopes: scopes,
      );

      await repository.createTag(tag);
      if (uddfId != null) idMapping[uddfId] = newId;
      count++;
      onProgress?.call(ImportPhase.tags, count, selected.length);
    }

    return count;
  }
```

- [ ] **Step 9: The post-tags link pass**

Create `lib/features/dive_import/data/services/import_equipment_tag_linker.dart`:

```dart
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// Links imported equipment items to their tags (issue #1942).
///
/// Equipment imports before tags, so this runs once both have local ids.
/// It links every item of the file that resolved to a local item: one the
/// import created, or an existing one a flagged duplicate was linked to,
/// so re-importing a file unions its tags onto gear the diver already has.
/// A reference with no local tag (the tag was not selected, or the file
/// does not define it) is dropped. A linked tag is widened to equipment.
/// Nothing is ever unlinked. UDDF and the Submersion equipment CSV both
/// reach it through each item map's `tagRefs`.
class ImportEquipmentTagLinker {
  const ImportEquipmentTagLinker({required this.tags, required this.links});

  final TagRepository tags;
  final EquipmentTagRepository links;

  /// [items] are the file's equipment maps. [equipmentIdMapping] and
  /// [tagIdMapping] map the file's ids (or, for a duplicate linked by name,
  /// the name) to local ids.
  Future<void> link({
    required List<Map<String, dynamic>> items,
    required Map<String, String> equipmentIdMapping,
    required Map<String, String> tagIdMapping,
  }) async {
    final widened = <String>{};
    for (final data in items) {
      final refs = data['tagRefs'];
      if (refs is! List) continue;
      final key = (data['uddfId'] as String?) ?? (data['name'] as String?);
      final equipmentId = key == null ? null : equipmentIdMapping[key];
      if (equipmentId == null) continue;
      final tagIds = <String>{
        for (final ref in refs.whereType<String>()) ?tagIdMapping[ref],
      }.toList();
      if (tagIds.isEmpty) continue;
      for (final tagId in tagIds) {
        if (widened.add(tagId)) await _widenToEquipment(tagId);
      }
      await links.addTags([equipmentId], tagIds);
    }
  }

  /// Widens the exact row. A lookup by name (as getOrCreateTag does) is
  /// unscoped for a tag with no diver and could widen another profile's
  /// namesake instead.
  Future<void> _widenToEquipment(String tagId) async {
    final tag = await tags.getTagById(tagId);
    if (tag == null || tag.appliesTo(TagScope.equipment)) return;
    await tags.updateTag(
      tag.copyWith(scopes: {...tag.scopes, TagScope.equipment}),
    );
  }
}
```

In `uddf_entity_importer.dart`:

1. Add imports next to the other equipment imports (main lines 49-58; Task 1 added no import there):
   `import 'package:submersion/features/dive_import/data/services/import_equipment_tag_linker.dart';`
   and
   `import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';`.
2. In the `ImportRepositories` class, after the `siteClassificationRepository` field (main line 116) add:

```dart

  /// Optional so existing bundles keep compiling; when null, imported
  /// equipment is not linked to its tags (issue #1942).
  final EquipmentTagRepository? equipmentTagRepository;
```

   and `this.equipmentTagRepository,` after `this.siteClassificationRepository,` in its constructor (main line 137).
3. In `import()`, directly after the `final tagsCount = await _importTags(...);` statement (main line 481; Task 1's edits are all further down, inside `_importTags` and `_linkSiteClassification`) add:

```dart

    // Equipment tags (issue #1942). Equipment imported before its tags
    // existed, so the links are made now that both have local ids.
    final equipmentTagRepository = repositories.equipmentTagRepository;
    if (equipmentTagRepository != null) {
      await ImportEquipmentTagLinker(
        tags: repositories.tagRepository,
        links: equipmentTagRepository,
      ).link(
        items: data.equipment,
        equipmentIdMapping: equipmentIdMapping,
        tagIdMapping: tagIdMapping,
      );
    }
```

`universal_adapter.dart`, in `universalImportRepositories`, after the
`siteClassificationRepository:` argument (lines 1870-1872) add:

```dart
    // Equipment tags (issue #1942); without it imported gear arrives with
    // none of its tags.
    equipmentTagRepository: ref.read(equipmentTagRepositoryProvider),
```

and the import
`import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';`
next to the other equipment provider imports.

- [ ] **Step 10: Run the new tests, then the neighbours**

Run each file from Step 2 again, one at a time; Expected: all PASS.

Then, one at a time (never overlapping):

- `flutter test test/core/services/export`
- `flutter test test/features/universal_import`
- `flutter test test/features/import_wizard`
- `flutter test test/features/dive_import`
- `flutter test test/features/settings/presentation/providers`
- `flutter test test/integration/uddf_round_trip_test.dart`
- `flutter test test/l10n/`
- `flutter test test/architecture/`

Expected: PASS. `uddf_site_classification_export_test.dart` and
`uddf_site_classification_round_trip_test.dart` pin that sites write and
read their tags exactly as before the shared writer. Every existing
`ImportRepositories(...)` keeps compiling because the new field is optional.
`universal_adapter_test.dart` runs with no database and now constructs
`EquipmentTagRepository()` through `universalImportRepositories`; that is
safe because Task 3's repository reads `DatabaseService.instance.database`
lazily through a getter, as `SiteClassificationRepository` does. This task
adds no ARB key, so the `test/l10n/` run only confirms nothing drifted.

- [ ] **Step 11: Commit**

```bash
dart format .
git add \
  lib/core/services/export/uddf/uddf_tag_writers.dart \
  lib/core/services/export/uddf/uddf_equipment_tag_source.dart \
  lib/core/services/export/uddf/uddf_site_classification_writers.dart \
  lib/core/services/export/uddf/uddf_export_builders.dart \
  lib/core/services/export/uddf/uddf_full_export_service.dart \
  lib/core/services/export/uddf/uddf_import_parsers.dart \
  lib/core/services/export/export_service.dart \
  lib/features/settings/presentation/providers/export_providers.dart \
  lib/features/universal_import/data/models/import_tag_scopes.dart \
  lib/features/universal_import/data/services/payload_ref_keys.dart \
  lib/features/universal_import/data/services/payload_merger.dart \
  lib/features/universal_import/data/services/payload_diver_expander.dart \
  lib/features/dive_import/data/services/import_equipment_tag_linker.dart \
  lib/features/dive_import/data/services/uddf_entity_importer.dart \
  lib/features/import_wizard/data/adapters/universal_adapter.dart \
  test/features/import_wizard/data/adapters/wizard_import_harness.dart \
  test/features/import_wizard/data/adapters/universal_adapter_equipment_tags_uddf_test.dart \
  test/features/import_wizard/data/adapters/universal_adapter_repositories_test.dart \
  test/core/services/export/uddf/uddf_equipment_tags_export_test.dart \
  test/core/services/export/uddf/uddf_equipment_item_parser_test.dart \
  test/features/universal_import/data/services/payload_merger_equipment_tag_refs_test.dart \
  test/features/universal_import/data/services/payload_diver_expander_test.dart \
  test/features/universal_import/data/models/import_tag_scopes_test.dart \
  test/features/dive_import/data/services/import_equipment_tag_linker_test.dart \
  test/features/settings/presentation/providers/export_uddf_equipment_tags_test.dart
git commit -m "feat(uddf): carry equipment tags through a backup and restore (#1942)" -m "The full export writes each equipment item's tag references as a direct <tags> child of its <item>, through a tag-ref writer now shared with sites, and every tag definition gains <appliestoequipment>. The exported tag set is unioned with the tags the items reference, resolved by id.

The parser carries an item's refs on its map, the multi-file merger namespaces and alias-rewrites them, and a multi-diver split sends a tag with the item that uses it. After tags import, one link pass maps each ref to its local tag, widens the tag to equipment and unions it onto the item, including an existing item a flagged duplicate was linked to. Unknown refs are dropped; an import never removes a tag. A definition without <appliestoequipment> reads as false."
```

---

### Task 10: CSV round trip

**Files:**
- Create: `lib/features/universal_import/data/parsers/submersion_csv/equipment_csv_tags.dart`
- Modify: `lib/core/services/export/csv/csv_equipment_writer.dart` (doc 11-15; `write` 35-38; header 53-54; cells 85-89)
- Modify: `lib/core/services/export/csv/csv_export_service.dart` (`exportEquipmentToCsv` 67-79; `generateEquipmentCsvContent` 189-197; `saveEquipmentCsvToFile` 250-262)
- Modify: `lib/core/services/export/export_service.dart` (`exportEquipmentToCsv`, `generateEquipmentCsvContent`, `saveEquipmentCsvToFile`; main lines 95-103, 123-131, 153-163, above Task 9's edits, so unshifted)
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (Task 9 changed this file, so locate by symbol: new helper after `_componentNamesFor`; the `generate`/`export` call in `exportEquipmentToCsv`; the same in `saveEquipmentCsvToFile`. Main's lines were 142-153, 255-259 and 1165-1170)
- Modify: `lib/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser.dart` (60-61, 135-136, 138-163, 168-171)
- Modify: `test/core/services/export/csv/goldens/equipment_metric.csv` (regenerated, CRLF file)
- Test (create): `test/core/services/export/csv/csv_equipment_tags_test.dart`
- Test (create): `test/features/import_wizard/data/adapters/universal_adapter_equipment_tags_csv_test.dart`
- Test (modify): `test/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser_test.dart`
- Test (modify): `test/core/services/export/csv/codec/submersion_csv_signatures_test.dart`
- Test (modify): `test/features/settings/presentation/providers/export_csv_units_test.dart`

**Interfaces:**
- Consumes: Task 9 `importTagScopeKeys`, the equipment map key `tagRefs`, `ImportEquipmentTagLinker` (reached through `performImport`, which links with `EquipmentTagRepository.addTags(List<String> equipmentIds, List<String> tagIds, {bool notify = true})`), `importThroughWizard`, and the `equipment_tag_providers.dart` import Task 9 added to `export_providers.dart`; Task 3 `EquipmentTagRepository()` with `getTagsByEquipment()` (no arguments) and `replaceTags(String, List<String>, {bool notify})`, `equipmentTagRepositoryProvider`; Task 1 `Tag.scopes`.
- Produces: the `Tags` column (after `Components`) in the Submersion equipment CSV; named parameter `Map<String, List<String>> tagNames = const {}` on `CsvEquipmentWriter.write`, `CsvExportService.generateEquipmentCsvContent` / `exportEquipmentToCsv` / `saveEquipmentCsvToFile`, and the three `ExportService` wrappers; class `EquipmentCsvTags` in `lib/features/universal_import/data/parsers/submersion_csv/equipment_csv_tags.dart`. `SubmersionCsvSignatures._equipment` is unchanged, so files without the column still detect (`containsAll`). No ARB keys: `Tags` is a CSV header literal, like the file's other column names.

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/export/csv/csv_equipment_tags_test.dart`:

```dart
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// The equipment CSV lists each item's tags (issue #1942).
void main() {
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
  );
  const mask = EquipmentItem(
    id: 'mask',
    name: 'Mask',
    type: EquipmentType.mask,
  );

  List<List<String>> rows(String csv) => [
    for (final row in const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(csv))
      [for (final cell in row) '$cell'],
  ];

  test('a Tags column follows Components and joins names with the list '
      'codec', () {
    final table = rows(
      CsvExportService().generateEquipmentCsvContent(
        const [reg, mask],
        tagNames: const {
          'reg': ['Salt; fresh', 'Travel'],
        },
      ),
    );
    final at = table.first.indexOf('Tags');
    expect(table.first[at - 1], 'Components');
    expect(table[1][at], r'Salt\; fresh; Travel');
    expect(table[2][at], '', reason: 'an item with no tags gets an empty cell');
  });

  test('a cell starting with a formula character is guarded', () {
    final table = rows(
      CsvExportService().generateEquipmentCsvContent(
        const [reg],
        tagNames: const {
          'reg': ['=Deep'],
        },
      ),
    );
    expect(table[1][table.first.indexOf('Tags')], "'=Deep");
  });
}
```

Append a group to `test/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser_test.dart`, inside `main()` after the last test. Add the imports `import 'package:csv/csv.dart';`, `import 'package:submersion/core/constants/enums.dart';` and `import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';` if not already present:

```dart
  group('Tags column (#1942)', () {
    const reg = EquipmentItem(
      id: 'r',
      name: 'Reg',
      type: EquipmentType.regulator,
    );
    const mask = EquipmentItem(id: 'm', name: 'Mask', type: EquipmentType.mask);
    const fins = EquipmentItem(id: 'f', name: 'Fins', type: EquipmentType.fins);

    String csv() => CsvEquipmentWriter(CsvExportUnits.metric).write(
      const [reg, mask, fins],
      tagNames: const {
        'r': ['Salt; fresh', 'Travel'],
        'm': ['=Deep', 'travel '],
      },
    );

    test('each distinct name becomes one equipment tag the rows reference', () async {
      final payload = await const SubmersionEquipmentCsvParser().parse(
        _bytes(csv()),
      );
      expect(payload.warnings, isEmpty);
      final tags = payload.entitiesOf(ImportEntityType.tags);
      // "travel " is "Travel": the tags table is unique on lower(trim(name)).
      expect(tags.map((t) => t['name']), ['Salt; fresh', 'Travel', '=Deep']);
      for (final tag in tags) {
        expect(tag['appliesToEquipment'], isTrue);
        expect(tag['appliesToDives'], isFalse);
        expect(tag['appliesToSites'], isFalse);
      }
      final ids = {for (final t in tags) t['name']: t['uddfId']};
      final items = payload.entitiesOf(ImportEntityType.equipment);
      expect(_byName(items, 'Reg')['tagRefs'], [
        ids['Salt; fresh'],
        ids['Travel'],
      ]);
      expect(_byName(items, 'Mask')['tagRefs'], [ids['=Deep'], ids['Travel']]);
      expect(
        _byName(items, 'Fins').containsKey('tagRefs'),
        isFalse,
        reason: 'a blank cell adds nothing',
      );
    });

    test('a file from before the Tags column reads with no tags', () async {
      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
      ).convert(csv());
      final at = rows.first.indexOf('Tags');
      final legacy = const ListToCsvConverter().convert([
        for (final row in rows) [...row]..removeAt(at),
      ]);
      final payload = await const SubmersionEquipmentCsvParser().parse(
        _bytes(legacy),
      );
      expect(payload.entitiesOf(ImportEntityType.equipment), hasLength(3));
      expect(payload.entitiesOf(ImportEntityType.tags), isEmpty);
    });
  });
```

Append to `test/core/services/export/csv/codec/submersion_csv_signatures_test.dart`, inside `main()` after the units loop:

```dart
  test('an equipment export from before the Tags column still matches', () {
    // Detection uses containsAll over a fixed signature, so the new column
    // is optional (issue #1942).
    final headers = _headers(
      CsvEquipmentWriter(CsvExportUnits.metric).write(goldenEquipment()),
    )..remove('Tags');
    expect(
      SubmersionCsvSignatures.match(headers),
      SubmersionCsvKind.equipment,
    );
  });
```

(This one is green before and after the change; it pins that the signature must not gain `tags`.)

Update `test/features/settings/presentation/providers/export_csv_units_test.dart`:

1. Imports: add
   `import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';`,
   `import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';`
   and `import 'package:submersion/features/tags/domain/entities/tag.dart';`.
2. In `make()`, after the `equipmentComponentRepositoryProvider` override (line 44) add:

```dart
        equipmentTagRepositoryProvider.overrideWithValue(_OneTag()),
```

3. In `_FakeExportService`, add a field `Map<String, List<String>>? tagNames;`
   and to both `exportEquipmentToCsv` (line 155) and `saveEquipmentCsvToFile`
   (line 165) add the parameter `Map<String, List<String>> tagNames = const {},`
   after `componentNames`, with `this.tagNames = tagNames;` next to
   `this.units = units;`.
4. Add a test after `'sites and equipment exports get the My units too'`:

```dart
  test("the equipment CSV gets each exported item's tag names (#1942)", () async {
    final export = _FakeExportService();
    final notifier = (await loaded(
      export,
    )).read(exportNotifierProvider.notifier);
    for (final run in <Future<void> Function()>[
      () => notifier.exportEquipmentToCsv(),
      () => notifier.saveEquipmentCsvToFile(),
    ]) {
      export.tagNames = null;
      await run();
      expect(export.tagNames, {
        'e1': ['Travel'],
      });
    }
  });
```

5. Add the fake at the end of the file:

```dart
/// Tags for the exported item and for one that is not exported.
class _OneTag extends Fake implements EquipmentTagRepository {
  @override
  Future<Map<String, List<Tag>>> getTagsByEquipment() async {
    final now = DateTime.utc(2026);
    final travel = Tag(
      id: 't1',
      name: 'Travel',
      createdAt: now,
      updatedAt: now,
      scopes: const {TagScope.equipment},
    );
    return {
      'e1': [travel],
      'gone': [travel],
    };
  }
}
```

Create `test/features/import_wizard/data/adapters/universal_adapter_equipment_tags_csv_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    show ImportFormat;
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/services/format_detector.dart';

import '../../../../helpers/test_database.dart';
import 'wizard_import_harness.dart';

const _diverId = 'diver-1';
final _now = DateTime(2026);

Diver _diver() =>
    Diver(id: _diverId, name: 'Test Diver', createdAt: _now, updatedAt: _now);

/// Equipment tags through a Submersion equipment CSV export and a re-import
/// driven by UniversalAdapter.performImport (issue #1942).
void main() {
  // Skip links a flagged duplicate tag; import-as-new still reuses a tag of
  // the same name (#1032). Both must widen the dive tag, never duplicate it.
  for (final action in [DuplicateAction.skip, DuplicateAction.importAsNew]) {
    testWidgets(
      'tags survive an export and re-import (duplicate tag: ${action.name})',
      (tester) async {
        await setUpTestDatabase();
        addTearDown(tearDownTestDatabase);

        final csv = (await tester.runAsync(() async {
          await DiverRepository().createDiver(_diver());
          final tags = TagRepository();
          final travel = await tags.getOrCreateTag(
            'Travel',
            diverId: _diverId,
            scope: TagScope.equipment,
          );
          // The name holds the list delimiter itself.
          final salt = await tags.getOrCreateTag(
            'Salt; fresh',
            diverId: _diverId,
            scope: TagScope.equipment,
          );
          final equipment = EquipmentRepository();
          final reg = await equipment.createEquipment(
            const EquipmentItem(
              id: '',
              diverId: _diverId,
              name: 'Travel reg',
              type: EquipmentType.regulator,
            ),
          );
          await equipment.createEquipment(
            const EquipmentItem(
              id: '',
              diverId: _diverId,
              name: 'Fins',
              type: EquipmentType.fins,
            ),
          );
          await EquipmentTagRepository().replaceTags(reg.id, [
            travel.id,
            salt.id,
          ]);
          final byItem = await EquipmentTagRepository().getTagsByEquipment();
          return CsvExportService().generateEquipmentCsvContent(
            await equipment.getAllEquipment(diverId: _diverId),
            tagNames: {
              for (final MapEntry(:key, :value) in byItem.entries)
                key: [for (final t in value) t.name],
            },
          );
        }))!;
        expect(csv, contains(r'Salt\; fresh; Travel'));

        // Another device, where "Travel" is already a dive tag.
        final travelId = (await tester.runAsync(() async {
          await tearDownTestDatabase();
          await setUpTestDatabase();
          await DiverRepository().createDiver(_diver());
          return (await TagRepository().getOrCreateTag(
            'Travel',
            diverId: _diverId,
          )).id;
        }))!;

        final bytes = Uint8List.fromList(utf8.encode(csv));
        expect(
          const FormatDetector().detect(bytes).format,
          ImportFormat.submersionEquipmentCsv,
        );
        final payload = (await tester.runAsync(
          () => parserForFormat(
            ImportFormat.submersionEquipmentCsv,
          ).parse(bytes),
        ))!;
        final result = await importThroughWizard(
          tester,
          payload: payload,
          diver: _diver(),
          duplicateAction: action,
        );
        expect(result.errorMessage, isNull);

        final (tags, tagsByItem, items) = (await tester.runAsync(
          () async => (
            await TagRepository().getAllTags(diverId: _diverId),
            await EquipmentTagRepository().getTagsByEquipment(),
            await EquipmentRepository().getAllEquipment(diverId: _diverId),
          ),
        ))!;
        final travel = [
          for (final t in tags)
            if (t.name.toLowerCase() == 'travel') t,
        ];
        expect(
          travel.map((t) => t.id),
          [travelId],
          reason: 'the dive tag is widened, not duplicated',
        );
        expect(travel.single.scopes, {TagScope.dives, TagScope.equipment});
        final salt = tags.singleWhere((t) => t.name == 'Salt; fresh');
        expect(salt.scopes, {TagScope.equipment});

        final reg = items.singleWhere((e) => e.name == 'Travel reg');
        final fins = items.singleWhere((e) => e.name == 'Fins');
        expect(tagsByItem[reg.id]!.map((t) => t.name), [
          'Salt; fresh',
          'Travel',
        ]);
        expect(
          tagsByItem[fins.id] ?? const <Tag>[],
          isEmpty,
          reason: 'a blank cell adds nothing',
        );
      },
    );
  }
}
```

- [ ] **Step 2: Run them and confirm they fail**

- `flutter test test/core/services/export/csv/csv_equipment_tags_test.dart`; Expected: compile error, no named parameter `tagNames` on `generateEquipmentCsvContent`.
- `flutter test test/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser_test.dart`; Expected: compile error, no named parameter `tagNames` on `CsvEquipmentWriter.write`.
- `flutter test test/core/services/export/csv/codec/submersion_csv_signatures_test.dart`; Expected: PASS (the pin is green on both sides).
- `flutter test test/features/settings/presentation/providers/export_csv_units_test.dart`; Expected: compile error, `_FakeExportService.exportEquipmentToCsv` has a parameter `tagNames` its interface lacks (invalid override).
- `flutter test test/features/import_wizard/data/adapters/universal_adapter_equipment_tags_csv_test.dart`; Expected: compile error, no named parameter `tagNames`.

- [ ] **Step 3: Writer and export services**

`csv_equipment_writer.dart`:

1. Replace the class doc (lines 11-15) with:

```dart
/// Writes the equipment CSV. [write]'s `componentNames` maps an assembly's
/// id to its parts' names in template order (issue #1487), and `tagNames`
/// maps an item's id to its tag names (issue #1942); items absent from
/// either get an empty cell. Both lists use the list codec. Free-text cells
/// go through [sanitizeCsvField] so a spreadsheet never evaluates them as
/// formulas; the importer reverses it.
```

2. `write` signature (lines 35-38) becomes:

```dart
  String write(
    List<EquipmentItem> equipment, {
    Map<String, List<String>> componentNames = const {},
    Map<String, List<String>> tagNames = const {},
  }) {
```

3. In the header, after `'Components',` (line 54) add `'Tags',`.
4. In each row, after the Components cell (lines 85-89) add:

```dart
        sanitizeCsvField(
          tagNames[item.id] == null ? null : joinCsvList(tagNames[item.id]!),
        ),
```

`csv_export_service.dart`: add `Map<String, List<String>> tagNames = const {},`
after `componentNames` in `exportEquipmentToCsv` (line 70),
`generateEquipmentCsvContent` (line 193) and `saveEquipmentCsvToFile`
(line 253); forward `tagNames: tagNames,` in the two inner
`generateEquipmentCsvContent(...)` calls (lines 73-77, 257-261); and change
the writer call (lines 195-197) to:

```dart
  }) => CsvEquipmentWriter(
    units,
  ).write(equipment, componentNames: componentNames, tagNames: tagNames);
```

Extend its doc comment (lines 189-190) with: "[tagNames] maps an item's id to its tag names (issue #1942)."

`export_service.dart`: add the same parameter after `componentNames` in
`exportEquipmentToCsv` (line 97), `generateEquipmentCsvContent` (line 125)
and `saveEquipmentCsvToFile` (line 155), forwarding `tagNames: tagNames,`
after `componentNames: componentNames,` in each body.

`export_providers.dart`:

1. `equipment_tag_providers.dart` is already imported (Task 9 Step 5 added it); add nothing.
2. Directly after the `_componentNamesFor` method (main line 153; Task 9's two imports shifted it, so find it by name) add:

```dart

  /// Each exported item's tag names, by name, for the Tags column of the
  /// equipment CSV (issue #1942). One query for every item.
  Future<Map<String, List<String>>> _equipmentTagNamesFor(
    List<EquipmentItem> equipment,
  ) async {
    final byItem = await _ref
        .read(equipmentTagRepositoryProvider)
        .getTagsByEquipment();
    return {
      for (final item in equipment)
        if (byItem[item.id] case final tags? when tags.isNotEmpty)
          item.id: [for (final tag in tags) tag.name],
    };
  }
```

3. In `exportEquipmentToCsv`, after its `componentNames: await _componentNamesFor(equipment),` argument (main line 257) add
   `tagNames: await _equipmentTagNamesFor(equipment),`; the same after the matching argument in `saveEquipmentCsvToFile` (main line 1167; Task 9's edits above it shifted it).

- [ ] **Step 4: Parser**

Create `lib/features/universal_import/data/parsers/submersion_csv/equipment_csv_tags.dart`:

```dart
import 'package:submersion/core/services/export/csv/codec/csv_list_codec.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/universal_import/data/models/import_tag_scopes.dart';

/// The tags named in the Submersion equipment CSV's Tags column (issue
/// #1942), in the shape #1848 gave CSV dive tags: one tag map per distinct
/// name for the payload's tag list, and the refs each row's item links to.
///
/// Names are distinct by the key the tags table is unique on (trimmed,
/// case-folded), so "Travel" and "travel" are one tag, spelled as first
/// seen. Each map says it applies to equipment only, so the importer
/// creates a new tag for gear alone and widens an existing tag of the same
/// name (a dive tag, say) instead of adding a second one.
///
/// Not TagExtractor: that splits dive CSV cells on commas, while this
/// column uses the equipment CSV's list codec ('; ' between names, a ';'
/// inside one escaped), so a name holding either survives.
class EquipmentCsvTags {
  final _byKey = <String, Map<String, dynamic>>{};

  /// The refs for one Tags [cell], in order and without repeats. A blank
  /// or missing cell gives none.
  List<String> refsFor(String? cell) {
    if (cell == null) return const [];
    final refs = <String>{};
    for (final raw in splitCsvList(cell)) {
      final name = unescapeCsvListItem(raw).trim();
      if (name.isEmpty) continue;
      final tag = _byKey.putIfAbsent(name.toLowerCase(), () {
        final id = 'csv-tag-${_byKey.length}';
        return {
          'id': id,
          'uddfId': id,
          'name': name,
          for (final MapEntry(key: scope, value: key)
              in importTagScopeKeys.entries)
            key: scope == TagScope.equipment,
        };
      });
      refs.add(tag['uddfId'] as String);
    }
    return refs.toList();
  }

  /// Every tag seen so far, in first-seen order.
  List<Map<String, dynamic>> get tags => [..._byKey.values];
}
```

`submersion_equipment_csv_parser.dart`:

1. Import `equipment_csv_tags.dart` after line 14:
   `import 'package:submersion/features/universal_import/data/parsers/submersion_csv/equipment_csv_tags.dart';`.
2. Extend the class doc (line 17) to "equipment maps, attributes, assembly parts and tags included."
3. After `final componentCells = <int, String>{};` (line 61) add `final tags = EquipmentCsvTags();`.
4. After the two Components lines (135-136) add:

```dart
      // Tags (issue #1942): linked by the importer once the tags exist.
      final tagRefs = tags.refsFor(table.text(row, 'Tags'));
```

5. In the item map, after `if (attributes.isNotEmpty) 'attributes': attributes,` (line 161) add
   `if (tagRefs.isNotEmpty) 'tagRefs': tagRefs,`.
6. Replace the return (lines 168-171) with:

```dart
    return ImportPayload(
      entities: {
        if (items.isNotEmpty) ImportEntityType.equipment: items,
        if (tags.tags.isNotEmpty) ImportEntityType.tags: tags.tags,
      },
      warnings: warnings,
    );
```

- [ ] **Step 5: Regenerate the metric golden**

The Tags column is an agreed format change (spec, CSV section), so:

Run: `flutter test test/core/services/export/csv/csv_metric_golden_test.dart --dart-define=WRITE_CSV_GOLDENS=true`
Then: `flutter test test/core/services/export/csv/csv_metric_golden_test.dart`; Expected: PASS.
Check: `git diff --numstat test/core/services/export/csv/goldens/` shows only `equipment_metric.csv` changed, and `git diff test/core/services/export/csv/goldens/equipment_metric.csv` shows the header gaining `Tags` between `Components` and `Active` and every row gaining one empty field there, nothing else (the file stays CRLF, as the writer emits).

- [ ] **Step 6: Run the tests, then the neighbours**

Run each file from Step 2 again, one at a time; Expected: all PASS.

Then, one at a time:

- `flutter test test/core/services/export`
- `flutter test test/features/universal_import`
- `flutter test test/features/import_wizard`
- `flutter test test/features/settings`
- `flutter test test/l10n/`
- `flutter test test/architecture/`

Expected: PASS. `csv_round_trip_test.dart`, `csv_equipment_components_test.dart`
and `csv_sites_equipment_writer_test.dart` read columns by name, so the new
column does not disturb them.

- [ ] **Step 7: Commit**

```bash
dart format .
git add \
  lib/core/services/export/csv/csv_equipment_writer.dart \
  lib/core/services/export/csv/csv_export_service.dart \
  lib/core/services/export/export_service.dart \
  lib/features/settings/presentation/providers/export_providers.dart \
  lib/features/universal_import/data/parsers/submersion_csv/equipment_csv_tags.dart \
  lib/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser.dart \
  test/core/services/export/csv/goldens/equipment_metric.csv \
  test/core/services/export/csv/csv_equipment_tags_test.dart \
  test/core/services/export/csv/codec/submersion_csv_signatures_test.dart \
  test/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser_test.dart \
  test/features/settings/presentation/providers/export_csv_units_test.dart \
  test/features/import_wizard/data/adapters/universal_adapter_equipment_tags_csv_test.dart
git commit -m "feat(csv): export and import equipment tags in the equipment CSV (#1942)" -m "The Submersion equipment CSV gains a Tags column after Components, written with the list codec from each item's tag names. Format detection is unchanged, so files without the column still import.

On import each distinct name, keyed as the tags table is unique, becomes one equipment-scoped tag in the payload and each item carries refs to its own, the shape CSV dive tags already use. The UDDF link pass then attaches them, so a name that exists as a dive-only tag widens that tag instead of duplicating it. Blank or missing cells add nothing."
```

### Task 11: Translation review

Every task translated its own keys (D3). This task reviews them together:
every key the branch adds or rewords is present in all ten locales, none is
left in English or on its old text, each locale uses one word for equipment,
equipment item, item and tag across tasks, and every new Arabic plural has all
its categories. It adds one guard test and changes an ARB line only where the
review finds a problem.

**Files:**
- Test (create): `test/l10n/tag_equipment_strings_test.dart`
- Modify (only for a finding): `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`; regenerate `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Consumes: every key Tasks 1 to 10 added to or reworded in `app_en.arb`, each already translated by its own task; in particular Task 3's four Manage Tags equipment keys and Task 7's 12 new and 4 reworded keys, which the guard test reads.
- Produces: the guard test, and any translation fixes the review calls for.

- [ ] **Step 1: Write the guard test**

`arb_parity_test` only proves a key exists, and gen-l10n silently fills a missing key with English. This test proves the Manage Tags equipment strings (Task 3's four keys and Task 7's sixteen) are really translated, and that the four reworded ones are not still on their dives-and-sites text: every one must name equipment in the locale's own word (the word each locale already uses for gear: `nav_equipment`, `dataQuality_carries_gear`, `trips_serviceAlert_count`).

Create `test/l10n/tag_equipment_strings_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Equipment tags on Manage Tags (#1942) in every locale. Each new or
/// reworded string names equipment in the locale's own word, so a key left
/// in English (gen-l10n falls back to it silently) or a reworded one still on
/// its old dives-and-sites translation fails here. arb_parity_test only
/// checks that the key exists.
void main() {
  /// The word, or stem, each locale already uses for equipment.
  const equipmentWord = {
    'ar': 'معدات',
    'de': 'ausrüstung',
    'es': 'equipo',
    'fr': 'équipement',
    'he': 'ציוד',
    'hu': 'felszerel',
    'it': 'attrezzatur',
    'nl': 'uitrusting',
    'pt': 'equipament',
    'zh': '装备',
  };

  List<String> equipmentStrings(AppLocalizations l) => [
    l.tags_manage_scope_equipment,
    l.tags_manage_useForEquipment,
    l.tags_manage_scopeRequired,
    l.tags_manage_equipmentCount(5),
    l.tags_manage_narrowDialog_equipment(5),
    l.tags_manage_deleteMessage_equipment('X', 5),
    l.tags_manage_deleteMessage_divesAndEquipment('X', 2, 5),
    l.tags_manage_deleteMessage_sitesAndEquipment('X', 2, 5),
    l.tags_manage_deleteMessage_all('X', 2, 3, 5),
    l.tags_manage_deleteMessage_unused('X'),
    l.tags_manage_bulkDeleteMessage_equipment(5),
    l.tags_manage_bulkDeleteMessage_divesAndEquipment(2, 5),
    l.tags_manage_bulkDeleteMessage_sitesAndEquipment(2, 5),
    l.tags_manage_bulkDeleteMessage_all(2, 3, 5),
    l.tags_manage_bulkDeleteMessage_unused,
    l.tags_manage_mergeAffected_equipment(5),
    l.tags_manage_mergeAffected_divesAndEquipment(2, 5),
    l.tags_manage_mergeAffected_sitesAndEquipment(2, 5),
    l.tags_manage_mergeAffected_all(2, 3, 5),
    l.tags_manage_mergeAffected_unused,
  ];

  for (final MapEntry(key: code, value: word) in equipmentWord.entries) {
    test('$code names equipment in every equipment tag string', () {
      final strings = equipmentStrings(lookupAppLocalizations(Locale(code)));
      final missing = [
        for (final s in strings)
          if (!s.toLowerCase().contains(word)) s,
      ];
      expect(missing, isEmpty);
    });
  }

  test('Arabic counts equipment items in every plural category', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(ar.tags_manage_equipmentCount(1), 'قطعة معدات واحدة');
    expect(ar.tags_manage_equipmentCount(2), 'قطعتا معدات');
    expect(ar.tags_manage_equipmentCount(3), '3 قطع معدات');
    expect(ar.tags_manage_equipmentCount(11), '11 قطعة معدات');
    expect(ar.tags_manage_equipmentCount(100), '100 قطعة معدات');
  });
}
```

- [ ] **Step 2: Run it, and prove it bites**

Run: `flutter test test/l10n/tag_equipment_strings_test.dart`
Expected: PASS (11 tests), since Tasks 3 and 7 translated these keys. A failure lists the offending strings of one locale: fix that locale's line (the owning task's block is the reference text), not the test.

Then prove the guard catches a stale reword. Back up the German file first (`git checkout` would also throw away any fix made later in this task):

```bash
scratch=$(mktemp -d)
cp lib/l10n/arb/app_de.arb "$scratch/app_de.arb"
git show main:lib/l10n/arb/app_de.arb | grep '"tags_manage_mergeAffected_unused"'
```

With the Edit tool, replace the `tags_manage_mergeAffected_unused` line in `lib/l10n/arb/app_de.arb` with the line that printed (main's dives-and-sites text), then run `flutter gen-l10n` and `flutter test test/l10n/tag_equipment_strings_test.dart`.
Expected: FAIL in `de names equipment in every equipment tag string` only, listing the German merge line.

Restore and confirm:

```bash
cp "$scratch/app_de.arb" lib/l10n/arb/app_de.arb
flutter gen-l10n
git status --porcelain -- lib/l10n/arb/
```

Expected: no output from `git status`. Then the test passes again.

- [ ] **Step 3: List every key the branch adds or rewords**

The branch's own diff is the list, not a fixed one: any task may have added a key since this plan was written.

```bash
base_dir=$(mktemp -d)
git show main:lib/l10n/arb/app_en.arb > "$base_dir/en_main.arb"
# Keys added on this branch.
jq -r --slurpfile base "$base_dir/en_main.arb" \
  'keys_unsorted[] as $k | select(($k | startswith("@")) | not)
   | select(($base[0] | has($k)) | not) | $k' \
  lib/l10n/arb/app_en.arb > "$base_dir/added.txt"
# Keys whose English text changed on this branch.
jq -r --slurpfile base "$base_dir/en_main.arb" \
  '. as $cur | keys_unsorted[] as $k | select(($k | startswith("@")) | not)
   | select(($base[0] | has($k)) and ($base[0][$k] != $cur[$k])) | $k' \
  lib/l10n/arb/app_en.arb > "$base_dir/changed.txt"
cat "$base_dir/added.txt"; echo ---; cat "$base_dir/changed.txt"
```

(The same list, as a plain diff: `git diff main -- lib/l10n/arb/app_en.arb`.) The keys known when this plan was reconciled:

| Task | Added | Reworded |
| --- | --- | --- |
| 3 | `tags_manage_scope_equipment`, `tags_manage_useForEquipment`, `tags_manage_equipmentCount`, `tags_manage_narrowDialog_equipment` | none |
| 5, 6 | `equipment_edit_tagsLabel`, `equipment_detail_showEquipmentWith`, `equipment_filter_section_tags`, `equipment_list_emptyState_noTagMatch`, `enum_equipmentField_tags`, `enum_equipmentField_tags_short` | none |
| 7 | `tags_manage_deleteMessage_equipment`, `_divesAndEquipment`, `_sitesAndEquipment`, `_all`; the same four of `tags_manage_bulkDeleteMessage_*` and of `tags_manage_mergeAffected_*` | `tags_manage_deleteMessage_unused`, `tags_manage_bulkDeleteMessage_unused`, `tags_manage_mergeAffected_unused`, `tags_manage_scopeRequired` |
| 8 | `equipment_bulkTags_action`, `_title`, `_tagsLabel`, `_adding`, `_removing`, `_onAll`, `_onSome`, `_empty`, `_confirmTitle`, `_confirmAdding`, `_confirmRemoving`, `_applied`, `_undo`, `_failed` | none |
| 1, 2, 4, 9, 10 | none known | none known |

The diff wins over this table. A key in the output that no task names is a stray: find the task that added it before reviewing it. A key named here but absent from the output was dropped by its task: raise it with that task rather than adding it here.

- [ ] **Step 4: Presence and staleness**

```bash
for l in ar de es fr he hu it nl pt zh; do
  f=lib/l10n/arb/app_$l.arb
  git show main:$f > "$base_dir/${l}_main.arb"
  while read -r k; do
    jq -r --arg k "$k" --slurpfile en lib/l10n/arb/app_en.arb \
      'if has($k) | not then "MISSING \($k)"
       elif .[$k] == $en[0][$k] then "SAME AS ENGLISH \($k): \(.[$k])"
       else empty end' "$f" | sed "s|^|$l: |"
  done < "$base_dir/added.txt"
  while read -r k; do
    jq -r --arg k "$k" --slurpfile old "$base_dir/${l}_main.arb" \
      'if .[$k] == $old[0][$k] then "STALE \($k)" else empty end' \
      "$f" | sed "s|^|$l: |"
  done < "$base_dir/changed.txt"
done
```

Expected: no `MISSING` and no `STALE` lines. A `SAME AS ENGLISH` line is acceptable only when the English word is the locale's own established word for it (a `Tags` label in German or Dutch, where `tags_manage_title` is `Tags`); any other is an untranslated string, so translate it in that locale.

- [ ] **Step 5: One word per concept across tasks**

Each locale must use the same word for the same concept in every task's strings (Task 3's labels, Task 5 and 6's edit, detail, filter and field labels, Task 7's messages, Task 8's bulk sheet and SnackBar). The reference words come from keys already on main:

| Locale | Equipment: scope and section label (`nav_equipment`) | Equipment item: Manage Tags and delete/merge counts (`dataQuality_carries_gear`) | Item: bulk sheet title and SnackBar, D4 (`equipment_retypeOther_apply`) | Tag (`tags_manage_title`) |
| --- | --- | --- | --- | --- |
| ar | المعدات | قطعة معدات (dual قطعتا/قطعتي معدات, plural قطع معدات) | عنصر | وسم (plural وسوم) |
| de | Ausrüstung | Ausrüstungsteil | Teil | Tag (plural Tags) |
| es | Equipo | equipo | elemento | etiqueta |
| fr | Équipement | équipement | élément | étiquette |
| he | ציוד | פריט ציוד | פריט | תגית |
| hu | Felszerelés | felszerelés | elem | címke |
| it | Attrezzatura | attrezzatura | elemento | tag |
| nl | Uitrusting | uitrustingsstuk | item | tag |
| pt | Equipamentos | equipamento | item | etiqueta |
| zh | 装备 | 件装备 | 件物品 | 标签 |

(Hungarian `nav_equipment` is spelled `Felszereles` on main, without the accent; the new strings use `Felszerelés`, and fixing the nav key is out of scope.)

Print every line the branch added to each locale and read it against the table:

```bash
for l in ar de es fr he hu it nl pt zh; do
  echo "== $l"
  git diff -U0 main -- lib/l10n/arb/app_$l.arb | grep '^+  "'
done
```

A different word for the same concept (for example German `Ausrüstungsgegenstand` in one task beside `Ausrüstungsteil` in another, or Portuguese `tag` beside `etiqueta`) is a finding: change the odd line to the table's word, keeping its grammar (case, number, article). D4's split is deliberate and is not a finding: Manage Tags and every delete or merge confirmation count "equipment items", while the bulk sheet title and its SnackBar count plain "items".

- [ ] **Step 6: Arabic plurals**

Every new Arabic plural names its noun in each category Arabic has: `one`, `two`, `few` (3 to 10), `many` (11 to 99) and `other` (100 and up), `zero` optional (`trips_serviceAlert_count` is the pattern). List the branch's Arabic plurals that lack a category, counting per plural so a message with two plurals cannot hide a gap in one of them:

```bash
ar=lib/l10n/arb/app_ar.arb
while read -r k; do
  v=$(jq -r --arg k "$k" '.[$k] // ""' "$ar")
  n=$(printf '%s' "$v" | grep -o 'plural,' | wc -l | tr -d ' ')
  [ "$n" -eq 0 ] && continue
  for cat in one two few many other; do
    c=$(printf '%s' "$v" | grep -oE "[ ,}]${cat}[{]" | wc -l | tr -d ' ')
    [ "$c" -ge "$n" ] || echo "ar $k: $n plural(s), $c '$cat' branch(es)"
  done
done < "$base_dir/added.txt"
```

Expected: no output. The guard test additionally pins the forms of `tags_manage_equipmentCount` for 1, 2, 3, 11 and 100. Hebrew plurals keep `=1`/`other` (the count is a digit) and are not a finding.

- [ ] **Step 7: Fix what the review found, then regenerate and run**

For each finding, edit the locale line with the Edit tool (the owning task's English is the reference; keep every placeholder and the ICU structure). Then:

```bash
for f in lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb; do
  jq empty "$f" || echo "INVALID JSON: $f"
  jq -r --slurpfile en lib/l10n/arb/app_en.arb \
    '. as $l | ($en[0] | keys_unsorted[]) as $k
     | select(($k | startswith("@")) | not) | select(($l | has($k)) | not) | $k' \
    "$f" | sed "s|^|missing in $f: |"
done
flutter gen-l10n
```

Expected: no `INVALID JSON` and no `missing in` lines; `flutter gen-l10n` exits 0 and prints no untranslated-message notes.

Run, one at a time:
- `flutter test test/l10n/`: Expected PASS (the guard test and `arb_parity_test`).
- `flutter test test/features/tags/`: Expected PASS (English is unchanged; these pin `Locale('en')`).
- `flutter test test/features/equipment/`: only if Step 7 changed an `equipment_*` or `enum_equipmentField_*` line. Expected PASS.

- [ ] **Step 8: Commit, then the pre-push hook's staleness check**

Staging an unchanged ARB file is a no-op, so the list is the same whether or not Step 7 changed anything.

```bash
dart format .
git add test/l10n/tag_equipment_strings_test.dart \
  lib/l10n/arb/app_ar.arb lib/l10n/arb/app_de.arb lib/l10n/arb/app_es.arb \
  lib/l10n/arb/app_fr.arb lib/l10n/arb/app_he.arb lib/l10n/arb/app_hu.arb \
  lib/l10n/arb/app_it.arb lib/l10n/arb/app_nl.arb lib/l10n/arb/app_pt.arb \
  lib/l10n/arb/app_zh.arb lib/l10n/arb/app_localizations.dart \
  lib/l10n/arb/app_localizations_*.dart
git diff --cached --numstat
git commit -m "test(l10n): guard the equipment tag translations (#1942)" \
  -m "A new test fails when a Manage Tags equipment string is left in English in any locale, or when one of the four reworded messages is still on its old dives and sites translation. It also pins the Arabic plural forms of the equipment item count."
```

If Step 7 changed a translation, add a sentence to the body naming the locale and the key.

Then repeat the hook's generated-l10n check (`hooks/pre-push` lines 213-257), which is HEAD-relative:

```bash
flutter gen-l10n
git status --porcelain -- 'lib/l10n/arb/app_localizations*.dart' 'lib/l10n/arb/*.arb'
```

Expected: no output. Any `app_localizations*.dart` line means the committed generated files do not match the committed ARBs: review, `git add` those exact files and amend (`git commit --amend --no-edit`). CI's Analyze & Format job (`.github/workflows/ci.yaml` around line 253) runs the same check on the pushed tree.

---


### Task 12: Verification

**Files:**
- No new files. Fixes found here go into the task commit they belong to only if that commit is not yet pushed; otherwise into a new `fix(...)` commit.

**Interfaces:**
- Consumes: everything from Tasks 1a to 11.
- Produces: a branch that passes the pre-push hook and is ready for a PR.

- [ ] **Step 1: Regenerate code and localizations from a clean state**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
git status --short
```
Expected: `git status` shows no modified tracked files (the generated l10n files were committed with their ARB changes; `*.g.dart` is gitignored). If `lib/l10n/arb/app_localizations*.dart` shows as modified, a task committed an ARB edit without its regenerated output: commit the regenerated files as `chore(l10n): regenerate localizations (#1942)`.

- [ ] **Step 2: Format and analyze the whole project**

Run:
```bash
dart format --set-exit-if-changed .
flutter analyze
```
Expected: format reports 0 changed files and exits 0; analyze prints `No issues found!`. CI treats infos as fatal, so fix every info too. Do not pipe either command into `grep` or `tail`: a pipe hides the exit status.

- [ ] **Step 3: Scan the branch diff for forbidden punctuation and attribution**

Run:
```bash
git diff main --name-only | xargs grep -nP '\x{2014}|\x{2013}' || echo "no dashes"
git log main..HEAD --format=%B | grep -niE 'co-authored-by|generated with|session_' || echo "no attribution"
```
Expected: `no dashes` and `no attribution`. Pre-existing em-dashes in files the branch touched are left alone; only lines this branch added must be clean (`git diff main -U0 | grep -nP '^\+.*\x{2014}'` must print nothing).

- [ ] **Step 4: Run the architecture guards and the l10n tests**

Run:
```bash
flutter test test/architecture/
flutter test test/l10n/
```
Expected: both pass with 0 failures.

- [ ] **Step 5: Run the full test suite once**

Run (no pipe, so the exit status is real):
```bash
flutter test --reporter=failures-only
echo "exit=$?"
```
Expected: `exit=0`. If anything fails, run that file alone, fix it in a new commit, and rerun only the failing files. Do not rerun the whole suite unless a fix touched shared code (a widget, provider or repository used across features); in that case rerun the directories that import it.

- [ ] **Step 6: Check the schema ladder end to end**

Run:
```bash
flutter test test/core/database/
```
Expected: pass, including the v218 to v219 migration test and the fresh-install versus upgraded schema comparison.

- [ ] **Step 7: Smoke-test in the macOS app**

Run the app from a terminal that holds the photo library permission (the app aborts after its first frame when launched from a terminal without it; that is an environment issue, not this branch):
```bash
flutter run -d macos
```
Check by hand, in this order:
1. Settings > Manage > Tags: edit a tag, tick "Use for equipment", save; the row subtitle is unchanged until the tag is on an item.
2. Equipment > open an item > Edit: the Tags field sits after Notes; add the tag and a new tag typed in the field; save; the detail page shows both chips under the name and type.
3. Tap a chip: the equipment list opens filtered to that tag; clear the filter chip.
4. Equipment list > select three items > overflow or inline "Edit tags": tick one tag, untick another, Apply, confirm; the SnackBar says "Updated tags on 3 items"; Undo restores the previous tags.
5. Search the equipment list for a tag name: the tagged items appear once each.
6. Manage Tags: the row shows "N equipment items"; untick "Use for equipment" on a tag in use and confirm the narrow dialog names the equipment count.
7. Settings > Export > full UDDF, then import it into a fresh diver profile: the items carry their tags.

- [ ] **Step 8: Push and open the PR**

Only after the user asks for it. Push with the pre-push hook active (`git config core.hooksPath hooks`), never `--no-verify`:
```bash
git push -u origin ericgriffin/equipment-tagging-ability-f140f6
```
The PR body links the issue with `Closes #1942` on its own line, summarizes the twelve commits, and contains no attribution line.

# Equipment tags

Date: 2026-09-13
Issue: #1942
Builds on: main at 3387357b169, schema v218. That includes #1849 (issue
#1765, dive site types and tags, v217), #1888 (Manage Tags rows are inert),
#1898 (delete a tag from its edit dialog), #1933 (site-aware delete and merge
messages) and #1899 (site detail layout, v218).

Revised 2026-09-13 after #1849 merged: the base is now main, the rung is
v219, Manage Tags rows no longer navigate, the delete and merge messages
gain equipment variants, and the CSV importer reuses #1848's tag resolver.

## Problem

Dives carry tags, and PR #1849 added tags to dive sites. Equipment has no
equivalent. A diver cannot mark gear as "Travel kit", "Rental", "Cold water"
or "Needs repair", find it by that label, or filter the gear list by it.

The closest existing things do not fit. Custom attributes
(`EquipmentAttributes.isCustom`) are label/value pairs on one item, not a
shared vocabulary. Equipment sets group gear for a dive, not for browsing.
Observation issue tags (`EquipmentObservations.issueTags`) are a fixed
catalog of condition findings.

## Goals

- An equipment item can have any number of tags, drawn from the shared tag
  list, with a third tag scope so equipment tags never clutter the dive or
  site pickers.
- Tags are editable on the equipment edit page and in bulk from the list's
  selection bar, with undo.
- Tags are visible on the detail page (tap to filter), on list tiles, and as
  a layout column; filterable in the list; matched by equipment search.
- The Manage Tags page shows equipment usage and edits the equipment scope.
- Tags survive sync between devices, a UDDF export and re-import, and a
  Submersion equipment CSV export and re-import.

## Non-goals

- Tags on equipment sets.
- Any change to observation issue tags.
- Tag filtering in the dive editor's gear picker
  (`equipment_picker_filter_sheet.dart`).
- Equipment tags in the dives-only UDDF export, which carries no gear at all
  (#1718).
- A Tags column in the dive or site CSV formats.

## Decisions

| Question | Decision |
| --- | --- |
| Base | main (#1849 has merged) |
| Tag vocabulary | Shared `tags` table, third scope `equipment` |
| Scope model | A scope registry replaces the per-scope booleans in code |
| Existing tags | Not equipment-scoped after migration |
| New tags | Scoped to the context they are created in; a name collision widens |
| Tags on the entity | No; read through providers, written through a junction repository |
| Filter match | Any-of within the tag set, AND with the other filters |
| Bulk editing | Full dive parity: tri-state editor, confirm summary, undo |
| CSV | Tags column in the Submersion equipment CSV, export and import |
| Delete and merge copy | One whole ICU message per combination of affected scopes, extending #1933 |
| Gear noun in counts | "equipment items" ("1 equipment item", "5 equipment items"); the bulk sheet title and SnackBar say "items" |
| Translations | In the commit that adds each string, all 11 locales; a final review pass |
| Delivery | One PR, commits in the order listed under Delivery |

Rejected alternatives for the scope model:

- A third boolean copied beside `appliesToDives` and `appliesToSites`. Every
  bool-by-bool site in the tag repository, the uniqueness repair, the Manage
  Tags page and `TagStatistic` gains a third branch, none of them checked by
  the compiler, and the next taggable entity repeats the work.

## Data model

Schema rung v219. `currentSchemaVersion` becomes 219 (v218 is #1899's site
detail columns). If main claims 219 first, the rung is renumbered at merge
time. `minimumCompatibleSchemaVersion` stays at 210: the rung only adds a
table, a defaulted column and an index.

### `tags` (altered)

| Column | Type | Default |
| --- | --- | --- |
| `applies_to_equipment` | bool | false |

Every existing tag keeps its dive and site scope and gains no equipment
scope. The repository enforces that at least one scope is true.

### `equipment_tags` (new)

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text, primary key | Surrogate uuid, so a re-inserted row never collides with its predecessor's tombstone (#347). |
| `equipment_id` | text | FK to `equipment`, cascade delete. |
| `tag_id` | text | FK to `tags`, cascade delete. |
| `created_at` | int | Raw tag id reads (snapshots, export) are ordered by it. Tags for display are ordered by name, as site tags are. |
| `hlc` | text, nullable | |

Unique index on `(equipment_id, tag_id)`, created in `onCreate` and the v219
rung and re-asserted in `beforeOpen`, through its own
`assertEquipmentTagUniqueness` in `tag_uniqueness.dart` beside the
`dive_tags` index. (The `site_tags` index lives in
`site_classification_uniqueness.dart`.) `equipment_tags` joins
`_assertChildHlcColumns`.

### Scope registry

A const descriptor list in `lib/core/database/`, shared by migration code,
repositories and sync:

| Scope | Scope column | Junction table | Parent column | Sync entity |
| --- | --- | --- | --- | --- |
| dives | `applies_to_dives` | `dive_tags` | `dive_id` | `diveTags` |
| sites | `applies_to_sites` | `site_tags` | `site_id` | `siteTags` |
| equipment | `applies_to_equipment` | `equipment_tags` | `equipment_id` | `equipmentTags` |

- `enum TagScope { dives, sites, equipment }` maps each member to its
  descriptor. Registry order is the display order.
- `Tag` replaces `appliesToDives` and `appliesToSites` with
  `Set<TagScope> scopes` and `appliesTo(scope)`. The row mapper converts
  between the set and the columns. `Tag.create(scope:)` sets exactly one.
- Loops over the registry replace the bool-by-bool code in `_requireScope`,
  the widen helpers, the unlink-on-narrow path in `updateTag`, `mergeTags`
  (union of scopes, repoint of every junction), `getTagUsage` and
  `collapseDuplicateTags`.
- `collapseDuplicateTags` skips any junction table that does not exist yet.
  It runs from the v149 rung, which executes before v217 and v219 create
  `site_tags` and `equipment_tags`.
- `TagStatistic` replaces `diveCount` and `siteCount` with
  `Map<TagScope, int> counts`, filled by one generated subquery per scope.
- `getTagUsage` and #1933's `getMergedUsage` (distinct items across a set of
  tags) return `Map<TagScope, int>` in place of the `({int dives, int
  sites})` record, with an entry for every scope.
- A descriptor records whether a link re-stamps its parent: dive links do
  (as today, in `mergeTags` only), site and equipment links are clockless
  children (#1769) and never do.
- Per-scope wording (scope name, "Use for ..." label, usage count, narrow
  line) comes from one exhaustive switch each in `tag_scope_labels.dart`, so
  adding a scope fails to compile until every label exists.
- The rule that a `tags` row from an older peer lacking a scope key keeps the
  local value is already generic (`SyncService._overlayOntoLocal`); it needs
  tests, not code.

This refactor lands first, with dives and sites only, and changes no
behavior. #1849's tests keep their intent; only their spelling of the scope
fields changes.

### Domain

`EquipmentItem` does not gain tags. `updateEquipment` rewrites the whole row,
and partial `EquipmentItem`s exist (the dive-joined mappers in
`dive_repository_impl.dart` carry no `parentEquipmentId` or reminder
overrides). If tags lived on the entity, any such save would wipe them. This
follows #1849's reasoning for `DiveSite`.

## Repositories

### `EquipmentTagRepository` (new)

Owns the `equipment_tags` junction, mirroring #1849's
`SiteClassificationRepository`:

- `getTagsForEquipment(id)`, ordered by name
- batch `getTagsByEquipment()` for the list: every item's tags in one query,
  as `getTagsBySite()` does (no id list, so no bound-variable limit)
- `getTagIdsByEquipment(ids)`: raw tag ids, for snapshots and export
- `tagCountsForEquipment(ids)` for the bulk editor
- `replaceTags(id, tagIds)`: the exact set, tombstoning removed rows (edit
  page, bulk undo)
- `addTags(ids, tagIds)` and `removeTags(ids, tagIds)` (bulk edit, import);
  add skips existing pairs, so the unique index never throws
- `deleteLinksForEquipment(id)`: tombstones an item's links inside the
  delete's transaction
- `watchChanges()`

The repository takes no constructor arguments and reads the database lazily,
as `SiteClassificationRepository` does.

Every write marks inserted junction rows pending and tombstones deleted ones.
No write touches the `equipment` row: no `updatedAt` bump and no pending
mark. A stale whole-row equipment snapshot must never beat a peer's newer
equipment edit (the #1769 clockless-child rule).

### `TagRepository` (extended through the registry)

- `getAllTags(scope: equipment)` lists equipment-scoped tags.
- `getOrCreateTag(name, scope: equipment)` widens an existing tag of the
  same normalized name instead of failing the name uniqueness index.
- Turning the equipment scope off for a tag with equipment links deletes and
  tombstones those links. The UI confirms first.
- `mergeTags` relinks `equipment_tags` and unions the scopes.

### Equipment save and delete

- The edit page save writes the equipment row, then its tags, in one
  transaction, through two new repository methods,
  `createEquipmentWithTags` and `updateEquipmentWithTags`. A new item gets
  its id before the junction write. `createEquipment` and `updateEquipment`
  keep their signatures (mocks and other services override them) and never
  touch tags.
- `deleteEquipment` tombstones the item's `equipment_tags` rows explicitly,
  as it does for its other children; the cascade removes the rows.

## Sync

`equipmentTags` goes through the same checklist #1849 ran for `siteTags`:

- `SyncRepository.hlcTargets`
- the `SyncData` field, `toJson` and `fromJson`
- `_baseTables`
- export in `_buildSyncData` through `_withPendingChildren`, plus a new
  `_exportEquipmentTags` (junction rows of equipment whose clock is newer)
- `fetchRecord` and `fetchRecords`
- single apply in `upsertRecord` and bulk apply in `upsertRecords`, both
  through `_withTagAlias` and `DoNothing(target: const [])`
- the `recordIdsFor` and `_syncTableFor` switches and the `deleteRecord`
  tombstone case
- `parentGatedChildEntities` and `parentGatedTables` (which also covers
  `fetchRecords`)
- `_foldTagInto` and the scope union in `_applyTagRecord` repoint and widen
  through the registry, so the equipment entry covers them
- in `sync_service.dart`: `mergeOrder` after both `equipment` and `tags`,
  `entityHasUpdatedAt: false`, and `parentRefs` (`equipmentId` to
  `equipment`, `tagId` to `tags`)
- conflict references

Rules:

- A duplicate pair from a peer applies without throwing.
- A tag folded into a rival by name keeps its equipment links.
- The duplicate-tag repair run by every `beforeOpen` repoints
  `equipment_tags` onto the surviving tag before deleting the losers.
- A `tags` row from an older peer with no `applies_to_equipment` key keeps
  the local value instead of taking the column default (the generic overlay
  rule; pinned by tests).
- Known edge, no action while the floor stays 210: a v218 build that
  receives an equipment-only tag drops the unknown column, so there the tag
  has no scope and its Manage Tags editor refuses to save it unchanged.

## UI

### Equipment edit page

A Tags field directly after Notes: `TagInputWidget(scope: TagScope.equipment)`
with the Browse button that opens `TagPickerSheet`. It lists equipment-scoped
tags only. A tag created from it applies to equipment.

### Equipment detail page

A row of colored tag chips (`EquipmentTagChips`) in the header section,
under the name and type (brand and model sit in the Details card), hidden
when the item has no tags. `TagChips` is not reused here: it is not
tappable and cuts off after three. Tapping a chip opens the equipment list
filtered to that tag through a new `openEquipmentWithTag` helper, mirroring
`openDivesWithTag`. The list opens in its default view, which hides retired
and sold gear, so a tag filter that matches nothing shows its own
empty-state line.

### Equipment list

- `EquipmentListTile` in detailed mode shows up to 3 tag chips and a "+N"
  chip (`TagChips`). The list passes each item's tags in, so the tile
  watches no new provider.
- `EquipmentField` gains `tags`, appended at the end of the enum (saved
  layouts store members by name), not sortable. Table cells render a comma
  list. No equipment tile reads card slot configs today, so there is no
  card slot to render into.
- Tags come from `getTagsByEquipment`, one query per list load. A
  statement-count test shows the list's statement count does not grow with
  the number of items.

### Equipment filters

`EquipmentFilterState` gains `tagIds` (a set), with a `clearTagIds` flag,
`hasActiveFilters` coverage, and equality. Tags are not on the entity, so
`apply` takes the batch map: `apply(items, tagIdsByEquipment)`. An item
matches when it has any selected tag; the tag axis is ANDed with status,
category and attribute conditions. The filter sheet gets a Tags chip group
listing equipment-scoped tags. The active filters bar shows each selected
tag as a removable chip.

### Equipment search

`searchEquipment` also matches tag names: a LEFT JOIN through
`equipment_tags` to `tags` with `OR t.name LIKE ?`, returning each item once.
The search provider also refreshes when an item's tags change.

### Bulk tag editing

- The equipment selection bar gains an "Edit tags" `BulkAction` (sell icon)
  beside Retire and Reactivate, enabled for one or more selected items. The
  existing `maxInlineActions` places it inline on desktop and in the
  overflow in pane mode.
- It opens `BulkEquipmentTagSheet`, titled "Edit tags on N items":
  `BulkMembershipEditor` with one tri-state row per tag (on all; on some,
  left as is; on none), seeded from `tagCountsForEquipment`. It lists
  equipment-scoped tags plus any tag already on a selected item. A tag on
  none of the items starts unchecked (`absentStartsChecked: false`);
  otherwise Apply would add every listed tag to every item. Its Add button
  opens the same dialog dives use: `TagInputWidget` with the equipment scope
  and a Browse button; a tag picked there starts on.
- Apply shows a confirm dialog with `BulkChangeSummary` listing what will be
  added to and removed from every selected item (as dives do, #1754), under
  headings that say "equipment items". Cancelling the confirm returns to the
  sheet with its edits; closing the sheet returns
  `BulkActionOutcome.cancelled`. Both keep the selection.
- `BulkEquipmentTagService.apply` reads the prior tag ids of every item and
  runs `addTags` and `removeTags`, all in one transaction, then notifies
  once. It returns the snapshot. Reading the snapshot inside the transaction
  keeps a sync apply from landing between the read and the write.
- A SnackBar "Updated tags on N items" offers Undo, with the dive settings
  (5 s, `persist: false`, close icon; #406). Undo calls
  `replaceTags(id, prior[id])` per item in one transaction. It touches only
  junction rows, so an edit made to an item between Apply and Undo survives.
  Items and tags deleted since Apply are skipped, so one missing row cannot
  roll back every other item's restore.
- No replace mode is shown, matching dives: the tri-state editor already
  expresses a replacement.

`BulkMembershipEditor`, `MembershipDelta` and `BulkChangeSummary` move from
`lib/features/dive_log/presentation/widgets/` to `lib/shared/bulk_edit/`. The
dive wording becomes parameters: `totalDives` becomes `total`, and every
row status, count and confirm string is supplied by the caller through a
labels object (the status lines are dive-specific in translation, for
example "todas" or "merülésen"). The dive screens render exactly as before.

### Settings > Manage Tags

- Each row's usage comes from the registry through `tagUsageCounts`, for
  example "12 dives, 3 sites, 5 equipment items". The dive count always
  shows, as today; site and equipment counts show when nonzero.
- The edit dialog's scope checkboxes are generated from the registry, which
  adds "Use for equipment". At least one stays required. Turning one off for
  a tag in use confirms with the count of links that will be removed; the
  narrow dialog gains a `tags_manage_narrowDialog_equipment` line beside the
  dive and site lines.
- Rows stay inert outside selection mode (#1888). Nothing here navigates.
- The delete and merge wording in `tag_usage_messages.dart` (#1933) extends
  to three scopes. `tagDeleteMessage`, `tagsBulkDeleteMessage` and
  `tagsMergeAffectedMessage` take the `Map<TagScope, int>` usage and switch
  over which scopes are nonzero. Each combination is one whole ICU message,
  so every locale controls its own word order: the existing dives, sites,
  dives-and-sites and unused keys stay, and each family gains equipment,
  dives-and-equipment, sites-and-equipment and all-three variants (12 new
  keys). The unused variants are reworded to "dives, sites or equipment",
  and `tags_manage_scopeRequired` ("Choose dives, sites, or both") to
  "Choose at least one: dives, sites or equipment". The delete from the
  edit dialog (#1898) shares the same helper, so it gains the equipment
  wording with no change of its own.
- The merge sheet seeds the surviving name and color from the most used tag
  by dives, then sites, then equipment, so an all-equipment selection seeds
  sensibly.
- The scope checkbox, the equipment usage count and the narrow line arrive
  with the schema commit, because adding `TagScope.equipment` does not
  compile until every per-scope label exists. The Manage Tags commit adds
  the delete and merge combinations and the rewordings.

### Localization

Every new or reworded string lands in all 11 ARB files in the same commit
that introduces it, so `test/l10n/arb_parity_test.dart` and the pre-push
hook stay green on every commit. A final review pass checks terminology
across the branch (one word per locale for equipment, tag and item) and
adds a guard test that fails while a reworded string is stale in any
locale. Arabic uses the full plural set for new strings.

## UDDF

### Export

- In the full export's Submersion extension, each equipment `<item>` gets a
  direct `<tags><tagref>tag_<id></tagref></tags>` child. Observation tags
  sit deeper and do not collide, because `findElements` matches direct
  children only.
- #1849's `UddfSiteClassificationWriters.writeSiteRefs` tag writer becomes a
  shared `writeTagRefs` used by sites and equipment.
- `<tag>` definitions gain `<appliestoequipment>`. The exported tag set is
  unioned with equipment-only tags (`mergeById`).

### Import

- `parseEquipmentItem` puts `tagRefs` on the equipment map. It must ride on
  the map: the import wizard rebuilds `UddfImportResult` from entity lists
  only.
- `payload_merger` namespaces equipment `tagRefs` for multi-file imports, as
  it does for site refs.
- `_importEquipment` runs before `_importTags`, so links are made in a pass
  after tags (`ImportEquipmentTagLinker`, shared with CSV): each ref maps
  through the tag id map, the tag is widened to equipment by id, and
  `EquipmentTagRepository.addTags` unions it onto the item. Unknown refs are
  dropped. An import never removes a tag.
- The pass also covers items the review step skipped or consolidated as
  duplicates of existing gear, so a re-import unions tags onto the existing
  item. `addTags` skips existing pairs, so a repeat changes nothing.
- The multi-diver splitter (`PayloadDiverExpander`) carries an item's tags
  with the item.
- A tag definition without `<appliestoequipment>` means false, plus
  equipment if an imported item references it.
- The round-trip test drives `performImport` against a real database through
  a new wizard harness; no existing test did.

## CSV

- Export: `csv_equipment_writer` gains a `Tags` column after `Components`,
  written with `joinCsvList` from a `tagNames` side map (the way
  `componentNames` arrives). Format detection uses `containsAll`, so files
  without the column still detect.
- Import: `submersion_equipment_csv_parser` reads `Tags` with `splitCsvList`.
  It follows the shape #1848 (merged) gave CSV dive tags: tag entities keyed
  by normalized name go in the result's tag list, and each equipment map
  carries `tagRefs` naming them. CSV and UDDF then share the one post-tags
  link pass above, so a name that exists as a dive-only tag widens that tag
  instead of duplicating it, and the tags are unioned onto the item. Blank
  or missing cells add nothing. #1848's `TagExtractor` is not reused: it
  splits on commas (the equipment CSV list delimiter is `'; '` with
  escaping), mints random ids, matches names exactly and sets no scope. A
  small `EquipmentCsvTags` builds the same output shape. Each tag map it
  emits sets the import scope keys (`importTagScopeKeys`) to dives false,
  sites false and equipment true, so `importedTagScopes` reads it as
  `{TagScope.equipment}` and it arrives as an equipment-only tag. These are
  keys on the imported map, not fields of `Tag`.
- The metric CSV golden file is regenerated. The Excel equipment sheet gets
  no Tags column.

## Delivery

- Branch `ericgriffin/equipment-tagging-ability-f140f6`, based on main, with
  no upstream until pushed with `-u` to its own name. (The spec was first
  drafted on `ericgriffin/equipment-tags-support-8ac2d6`, a local branch on
  #1849's pre-squash history; it is not used.)
- The PR targets main, so CI runs on every push.
- The PR description links the issue with `Closes #1942`.
- Commits, in order (each green, with its own translations):
  1. Scope registry refactor (dives and sites, no behavior change), as two
     commits: the core layer, then the features layer
  2. Shared bulk-edit widgets moved to `lib/shared/bulk_edit/`
  3. Schema v219, `EquipmentTagRepository`, and the equipment scope arms
  4. Sync registration
  5. Edit and detail pages
  6. List chips, `EquipmentField.tags`, filter, search
  7. Manage Tags delete and merge wording
  8. Bulk tag editing with undo
  9. UDDF round trip
  10. CSV round trip
  11. Translation review
  12. Verification

## Testing

Tests are written first.

- Registry refactor: #1849's tag scope, Manage Tags scope and sync tests pass
  with only field spelling changed; `collapseDuplicateTags` on a v148
  database (no `site_tags`, no `equipment_tags`) runs without error.
- Migration: v218 to v219 adds the column (false on existing tags), the
  table and its unique index. A fresh `onCreate` database matches the
  upgraded one. Stale version literals in ladder tests are updated.
- Sync:
  - the hlc-registration, parent-refs-completeness and batch-coverage guards
    cover `equipmentTags`
  - junction rows round trip between two databases
  - a duplicate pair applies without throwing
  - a junction change never marks the equipment row pending
  - a tag folded by name keeps its equipment links
  - a tag row with no `applies_to_equipment` key keeps the local scope
- Repositories:
  - the edit save is transactional (a throw partway leaves no partial set)
  - removals are tombstoned
  - a name collision widens the existing tag
  - `mergeTags` unions scopes and relinks equipment tags
  - narrowing the equipment scope removes and tombstones links
  - `updateEquipment` with a partial entity leaves tags untouched
  - `deleteEquipment` tombstones its tag links
- List: a statement-count test for the batch tag query.
- Filter: any-of within the tag set, AND across axes, clear flag, equality.
- Search: a tag name match returns the item once.
- Bulk editing:
  - apply and undo restore the exact prior sets, including partial overlap
  - neither apply nor undo marks an equipment row pending
  - a duplicate add is a no-op
  - the sheet shows the right tri-state counts
  - the selection bar exposes the action
  - the SnackBar's Undo restores the tags
- UDDF: a round trip through `performImport` (not the entity importer alone)
  with equipment-only and shared tags, and the union on re-import.
- CSV: an export and re-import round trip through `performImport`, including
  a name that exists as a dive-only tag and a name containing the list
  delimiter.
- Tag messages: every one of the eight scope combinations picks its own key
  for single delete, bulk delete and merge; `getMergedUsage` counts an item
  carrying two of the tags once, per scope.
- Widgets: the edit page Tags field, detail chips and tap-to-filter, list
  tile chips, the filter sheet Tags group, the Manage Tags equipment scope
  and usage line, and the dive bulk edit screens after the widget move.

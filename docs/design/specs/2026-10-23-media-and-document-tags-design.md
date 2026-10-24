# Media and document tags

Date: 2026-10-23
Issue: #1970
Builds on: main at f826580b546, schema v308. Follows the equipment tags design
(`2026-09-13-equipment-tags-design.md`, #1942), whose tag scope registry this
feature extends.

The maintainer asked for document tags alongside media tags and chose to skip
the design questions, so every decision below is the builder's call, recorded
here for review.

## Problem

Dives, dive sites and equipment carry tags. Photos, videos and documents do
not. A diver cannot mark photos as "Wreck", "Funny" or "Site map", or
documents as "Travel" or "Club", and then find them by that label. Species
tagging on media is a fixed catalog of animals, not a free vocabulary.

## Goals

- A media item and a document can carry any number of tags from the shared
  tag list, through two new scopes so they never clutter the dive, site or
  equipment pickers.
- Media: edit tags on one item from the viewer, and on many from the library
  selection bar with undo; see them in the info panel; filter the media
  library by them; save that filter as a smart album.
- Documents: edit tags on the edit page; see them on the detail page and list
  tiles; filter and search the documents list by them.
- Manage Tags shows media and document usage and edits both scopes.
- Tags survive sync between devices.

## Non-goals

- Tags in UDDF or CSV: neither format carries media or documents today.
- Tags on media from the universal import (MacDive keywords and similar).
- Showing tags on media grid thumbnails.
- Multi-select on the documents list (it has none today), so no bulk
  document tagging.
- Tag filters in the per-dive, per-site and trip galleries; the media library
  is the place to browse by tag.
- Tag terms in the query language.

## Decisions

| Question | Decision |
| --- | --- |
| Vocabulary | Shared `tags` table, scopes `media` and `documents` appended to the registry |
| Existing tags | Neither new scope after migration (fresh scope, as equipment did) |
| New tags | Scoped to where they are created; a name collision widens the existing tag |
| Tags on the entities | No. `MediaItem` and `Document` stay tag-free; tags are read through providers and written through junction repositories, so a partial-entity save can never wipe them |
| Media filter match | Any of the selected tags, ANDed with the other library filters |
| Smart albums | Free: the album is a saved `MediaLibraryFilter`, which gains `tagIds` |
| Media edit UI | A Tags card in the viewer's info panel opening a Tags sheet that saves each change at once, like the species sheet |
| Media bulk edit | "Edit tags" in the library selection bar, the shared tri-state `BulkMembershipEditor`, confirm summary, Undo |
| Document edit UI | A Tags field on the edit page after Notes, saved in the document's own transaction |
| Document list | Up to 3 chips per tile, a tag filter chip row (any of), search matches tag names |
| Scope nouns (en) | "Media" / "media items" and "Documents" / "documents" |
| Delete and merge wording | One message per single scope (as today) plus one "removed from:" list form for two or more scopes. Per-combination messages do not scale to five scopes (32 per family), so the dives/sites/equipment combination keys retire |
| Document archive export | `manifest.csv` gains a Tags column |
| Translations | All 11 locales, in the commit that adds each string |
| Delivery | One PR |

## Data model

Schema rung v309 (`currentSchemaVersion` 308 to 309).
`minimumCompatibleSchemaVersion` is unchanged: the rung adds two defaulted
columns and two tables.

- `tags`: `applies_to_media` and `applies_to_documents`, both bool default
  false.
- `media_tags`: `id` (surrogate uuid pk, #347), `media_id` (FK `media`,
  cascade), `tag_id` (FK `tags`, cascade), `created_at`, `hlc`. Unique index
  on `(media_id, tag_id)`.
- `document_tags`: the same shape with `document_id` (FK `documents`,
  cascade).
- Both indexes are created in `onCreate` and the rung, and re-asserted in
  `beforeOpen` beside the equipment one. Both tables join the child hlc
  column backstop.
- Registry: `mediaTagScopeTable` and `documentTagScopeTable` append to
  `tagScopeTables`, with `sweepsOrphanLinks: true` and no re-stamped parent.
  `TagScope` gains `media` and `documents`. Every per-scope label switch
  gains its arms.

## Repositories

- `MediaTagRepository` and `DocumentTagRepository`, each mirroring
  `EquipmentTagRepository`: tags for one item, a batch map for lists, raw
  ids, counts for the bulk editor, `replaceTags`, `addTags`, `removeTags`,
  link deletion inside the parent's delete, `watchChanges`. Writes mark
  inserted links pending and tombstone removed ones, and never touch the
  parent row.
- `DocumentRepository.save` takes optional tag ids and writes them in its
  transaction; null leaves the links alone. `delete` tombstones the
  document's links.
- Media deletes (`deleteMedia`, `deleteMultipleMedia`) tombstone the items'
  links.
- `MediaLibraryRepository._baseWhere` adds an `EXISTS` over `media_tags` for
  `tagIds`, beside the species clause, so pages, counts and map points all
  honor it.
- Diver deletion removes the new links with the diver's tags, as it does for
  equipment links.

## Sync

Both junctions run the same registration checklist as `equipmentTags`
(payload field, JSON, changeset tables, fetch, single and bulk apply through
the tag alias, record ids, table map, tombstones, merge order after the
parent and `tags`, `entityHasUpdatedAt: false`, parent refs, conflict
references, hlc targets).

- Both are parent-gated children, exactly like `equipmentTags`: the export
  carries the links of items whose clock moved, and a link marked pending
  travels on its own (`_withPendingChildren`). That pending-children path is
  what fixed the problem that moved `mediaSpecies` onto its own clock
  (#1638), so the tag family stays uniform.
- The tag fold, scope union, duplicate-tag repair and older-peer overlay are
  registry driven and need tests, not code.

## UI

### Media

- Info panel: a Tags card, shown even with no tags, with the item's chips
  (tapping one closes the sheet and opens the library filtered to it) and
  Edit tags, which opens `MediaTagSheet`: the scoped tag input and Browse,
  each change saved at once like species tags.
- No viewer toolbar button: at a 400 px phone width the toolbar's four
  actions fit with no menu, and a fifth would push Adjust color into the
  overflow (#3520). The info card is the way in on every width.
- Library filter sheet: a Tags chip group (multi-select). Active filter chips
  show each selected tag. `MediaLibraryFilter` gains `tagIds` with JSON,
  equality and `hasActiveFilters`; an unknown tag id in a saved album is
  ignored.
- Selection bar: "Edit tags" opens `BulkMediaTagSheet` (tri-state rows seeded
  from counts, confirm summary, SnackBar with Undo, as equipment).

### Documents

- Edit page: a Tags field after Notes (`TagInputWidget(scope:
  TagScope.documents)`).
- Detail page: a chip row in the details card; tapping a chip opens the list
  filtered to it.
- List: tiles show up to 3 chips and "+N". A tag chip row under the type
  chips appears when any document carries a tag (and stays while a tag
  filter is set). Search also matches tag names.

### Manage Tags

- Scope checkboxes "Use for media" and "Use for documents", usage counts, and
  narrowing confirmations come from the registry.
- Delete and merge confirmations: a single affected scope keeps its whole
  message; two or more use a heading (`"Wreck" will be removed from:`)
  followed by one count line per affected scope. The "unused" variants say
  "not used anywhere", and the scope-required error names all five scopes
  (`tag_scope_required_strings_test` pins that).

## Testing

Tests first. Migration v308 to v309 and fresh-create parity; registry and
label coverage; both repositories (pending marks, tombstones, no parent
touch, duplicate add no-op); document save transaction and delete; media
delete; library filter SQL, JSON round trip and smart album; sync guards plus
a two-database round trip per junction; Manage Tags scopes and the new
message shapes; widget tests for the media sheet, info panel chips, filter
sheet, bulk sheet with undo, document edit field, detail chips, list filter
and search; ARB parity.

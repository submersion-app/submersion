# Dive sites: types and tags

Date: 2026-09-12
Issue: #1765

## Problem

A diver cannot classify a dive site. The reporter wants two things:

- Tags on sites, for personal status such as "to complete", "to try" or
  "to avoid".
- A site type, such as lake, wreck, wall, pool or cave.

Sites today carry a few categorical fields (`difficulty`, `waterType`,
`entryMethod`), none of which describe what kind of place the site is.
`SiteFeatureType.wreck` exists, but it is a map pin inside a site, not a
classification of the site itself.

## Goals

- A site can have any number of types, drawn from a translated built-in
  vocabulary plus diver-created custom types.
- A site can have any number of tags, drawn from the existing tag list, with
  each tag scoped to dives, sites, or both so site-status tags never clutter
  the dive tag picker.
- Types and tags are visible and editable on the site edit and detail pages,
  shown on site cards, selectable as layout columns, filterable in the site
  list, and summarized in statistics.
- Types and tags survive sync between devices (including devices one schema
  version behind), a UDDF export and re-import, and a site merge.
- Importers that know a site's environment populate its types.

## Non-goals

- A standard UDDF element for site type. UDDF has none; files from other apps
  carry no site types.
- Inferring site types from Subsurface dive tags ("cave", "wreck"). Those are
  dive tags and already import as dive tags.
- MacDive site environment. MacDive has no such column.
- Site types on compact and dense list tiles. Those layouts can show the new
  columns through `SiteField` instead.
- Dive-type-style display options (`shortName`, `showInDetailHeader`,
  `showInListView`) for site types.

## Decisions

| Question | Decision |
| --- | --- |
| Tag vocabulary | Shared `tags` table, with a per-tag scope |
| Existing tags | Scoped to dives only after migration |
| New tags | Scoped to the context they are created in |
| Types per site | Many (junction table) |
| Type vocabulary | Built-ins with stable slugs, plus custom per diver |
| Type storage | New `site_types` table mirroring `dive_types` |
| Filter match | Any-of within a filter set, AND across filters |
| Statistics | Dives per site type, horizontal bar chart |
| Delivery | One PR |

Rejected alternatives for type storage:

- Generalizing `dive_types` with a `kind` column. Every existing dive-type
  query, statistic and export would need a `kind = 'dive'` filter, and the
  `wreck` and `cave` slugs already exist as dive types.
- A slug-list text column on `dive_sites`. Filters and statistics become
  string matching, custom types have no home, and deleting a custom type
  rewrites every site row.

## Data model

Schema rung v212. `currentSchemaVersion` becomes 212.
`minimumCompatibleSchemaVersion` stays at 210: the rung only adds tables,
defaulted columns and indexes, which the floor's documented rules exempt.

### `site_types` (new)

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text, primary key | Slug. Built-ins use fixed slugs; custom slugs come from the unique-slug builder `createDiveType` uses. |
| `diver_id` | text, nullable | Null for built-ins. |
| `name` | text | |
| `is_built_in` | bool | |
| `sort_order` | int | |
| `created_at`, `updated_at` | int | |
| `hlc` | text, nullable | |

Built-in seed, in sort order, inserted with `INSERT OR IGNORE` in both
`onCreate` and the v212 migration:

| Slug | English name |
| --- | --- |
| `reef` | Reef |
| `wall` | Wall |
| `wreck` | Wreck |
| `artificial_reef` | Artificial reef |
| `cave` | Cave |
| `cavern` | Cavern |
| `cenote` | Cenote |
| `blue_hole` | Blue hole |
| `lake` | Lake |
| `quarry` | Quarry |
| `river` | River |
| `spring` | Spring |
| `pool` | Pool |
| `pier` | Pier / jetty |
| `muck` | Muck |
| `kelp_forest` | Kelp forest |

Built-in names are translated by id in a `builtInSiteTypeName` helper,
mirroring `builtInDiveTypeName`.

### `site_site_types` (new)

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text, primary key | Surrogate uuid, so a re-inserted row never collides with its predecessor's tombstone (#347). |
| `site_id` | text | FK to `dive_sites`, cascade delete. |
| `site_type_id` | text | No FK, for the same reason as `dive_dive_types.dive_type_id`: a custom type can arrive by sync after a junction row that references it. |
| `created_at` | int | Types read back ordered by it. |
| `hlc` | text, nullable | |

Unique index on `(site_id, site_type_id)`, created in `onCreate`, in the
migration and re-asserted in `beforeOpen`, following
`dive_type_uniqueness.dart`.

### `site_tags` (new)

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text, primary key | Surrogate uuid. |
| `site_id` | text | FK to `dive_sites`, cascade delete. |
| `tag_id` | text | FK to `tags`, cascade delete. |
| `created_at` | int | |
| `hlc` | text, nullable | |

Unique index on `(site_id, tag_id)`, handled like `dive_tags` in
`tag_uniqueness.dart`.

### `tags` (altered)

| Column | Type | Default |
| --- | --- | --- |
| `applies_to_dives` | bool | true |
| `applies_to_sites` | bool | false |

Every existing tag becomes dives-only. Two booleans rather than one scope
string keep filter SQL a plain predicate. The repository enforces that at
least one is true.

### Domain

- New `SiteType` entity: `id`, `diverId`, `name`, `isBuiltIn`, `sortOrder`,
  with `copyWith`.
- `Tag` gains `appliesToDives` and `appliesToSites`.
- `DiveSite` does not gain types or tags. Several code paths build a partial
  `DiveSite` and save it through the whole-row `updateSite` (the #1187 wipe).
  If types and tags lived on the entity, every such path would wipe them.
  They are read through providers and written only through explicit
  junction calls.

## Sync

`siteTypes`, `siteSiteTypes` and `siteTags` are registered as synced
entities through the full checklist:

- `SyncRepository.hlcTargets` (guarded by
  `sync_hlc_target_registration_test.dart`)
- the `SyncData` field, `toJson` and `fromJson`
- the export table list, single-record fetch, single apply and bulk apply
- both table-lookup switches and the tombstone delete switch
- `parentGatedChildEntities` and `parentGatedTables` for the two junctions
- in `sync_service.dart`: merge order, `entityHasUpdatedAt` (false for the
  junctions) and `parentRefs` (`siteId` for both junctions, plus `tagId` for
  `siteTags`)
- `_assertChildHlcColumns` for the two junctions

Rules:

- Built-in site types are never exported. Every device seeds the same slugs.
- Junction apply paths insert with `DoNothing(target: const [])`, so a
  duplicate pair from a peer never throws.
- Tag alias folding (`_withTagAlias`) also rewrites incoming `siteTags` rows,
  and `_foldTagInto` repoints local `site_tags` rows as it does `dive_tags`,
  so a tag folded into a rival by name keeps its site links.
- The duplicate-tag repair `collapseDuplicateTags` (`tag_uniqueness.dart`)
  repoints `site_tags` onto the surviving tag before deleting the losers.
  Without that, the repair (run by every `beforeOpen`) would cascade-delete
  the losing tag's site links.
- Deleting a diver deletes their custom site types, next to the existing
  custom dive type delete in `diver_repository.dart`. Diver merge needs no
  change: it discovers every table with a `diver_id` column.
- Sync conflict references resolve `siteTypeId` to `siteTypes`.
- The junctions are clockless children. A change marks the changed junction
  rows pending and tombstones removed rows. It never marks the parent site
  pending, so a stale whole-row site snapshot cannot overwrite a peer's newer
  site edit.
- The `tags` columns ride the existing whole-row `tags` sync. A v211 peer
  that edits a tag publishes a row with no `applies_to_*` keys. On apply, a
  missing key keeps the local value instead of taking the column default, so
  an older device cannot shrink a tag's scope to dives-only.

## Repositories

### `SiteTypeRepository` (new)

Mirrors `DiveTypeRepository`:

- `getSiteTypes(diverId)`: built-ins in seed order, then the diver's custom
  types.
- `createSiteType`, `updateSiteType`, `deleteSiteType`. Update and delete
  refuse built-ins. Delete tombstones the type and every junction row that
  references it.
- `getSiteTypeStatistics()` (site count per type) for the Manage page.

### `TagRepository` (extended)

- `getTags(diverId, scope:)` where scope is dives or sites.
- Create and update take the two scope flags.
- Creating a tag whose name collides with an existing tag of the other scope
  widens the existing tag to both and returns it, instead of failing the
  name uniqueness index.
- `mergeTags` ORs the scopes of the merged tags and relinks `site_tags` as
  well as `dive_tags`.
- Turning `applies_to_sites` off for a tag with site links deletes and
  tombstones those links. The UI confirms first. The same applies to
  `applies_to_dives` and dive links.
- Tag statistics report dive and site counts separately.

### `SiteClassificationRepository` (new)

Owns both site junctions, so the two sets are read and written in one place:

- `getTypeIdsForSite`, `getTagsForSite`
- batch `getTypeIdsBySite()` and `getTagsBySite()` for the site list
- `replaceTypes` / `replaceTags` (the edit page: exact set, tombstoning
  removed rows)
- `addTypes` / `addTags` (imports and bundled sites: union, never remove)

`SiteTypeRepository` and `TagRepository` keep vocabulary concerns only.

### Site save and merge

- The site edit save writes the site row, then types, then tags, inside one
  transaction. A new site gets its id before the junction writes.
- `updateSite` never touches the junctions.
- `mergeSites` moves types and tags onto the surviving site. The unique
  indexes drop duplicates, and every writer is conflict-safe.

## UI

### Site edit page

A new Type & Tags section directly after Identity:

- Types: a wrap of `FilterChip`s for every type the diver has, built-ins
  first, multi-select, ending with a "Manage types" link to `/site-types`.
- Tags: `TagInputWidget` with a new `scope` parameter. With `scope: sites` it
  lists only site-scoped tags, and a tag created from it applies to sites.

The site merge page needs no picker: `mergeSites` unions both sets.

### Site detail page

A chip row under the header: type chips (neutral) first, then tag chips
(colored, reusing `TagChips`). Hidden when both are empty. Tapping a chip
opens the site list filtered to that type or tag.

### Site list

- `SiteWithDiveCount` gains `siteTypes` and `tags`, filled by the two batch
  queries next to the existing `getFeatureTypesBySite` call. The list's
  statement count does not grow with the number of sites.
- `site_list_tile.dart` shows type chips, then feature chips, then up to 3
  tag chips and a "+N" chip. A wreck feature chip is hidden when the site is
  typed wreck.
- `SiteField` gains `siteTypes` and `tags`, appended at the end of the enum
  (saved layouts store members by name), in the `details` category. Table
  cells render a comma list; card slots render chips.

### Site filters

`SiteFilterState` gains `siteTypeIds` and `tagIds` sets, with `copyWith`
clear flags and `hasActiveFilters` coverage. A site matches a set when it has
any member of it. `site_filter_sheet.dart` renders both as chip groups; the
tag group lists site-scoped tags only.

### Settings > Manage Data

- A new Site Types page at `/site-types`, built from `dive_types_page.dart`:
  a read-only built-in section and a custom section, a lower-right extended
  FAB for create, and inline edit and delete icons per row. Deleting a type in
  use confirms with its site count.
- The Tags page shows each tag's scope and usage ("12 dives, 3 sites"). The
  edit dialog gets Use for dives and Use for sites checkboxes, with at least
  one required. Turning one off for a tag in use confirms with the count of
  links that will be removed.

### Dive side

The dive tag picker and the dive filter sheet list only tags that apply to
dives. Existing tags all apply to dives, so nothing a diver sees on dives
changes.

### Localization

Every new string and the 16 built-in type names are added to all 11 ARB
files.

## Statistics

`getSiteTypeDistribution` counts dives per site type, joining
`dives` to `site_site_types` through `dives.site_id`. It honors the stats
scope and the active view filter, following `getWaterTypeDistribution`. A
dive at a site with two types counts toward both, so the chart is a
horizontal bar chart of counts rather than a pie. Dives at untyped sites are
excluded, and the chart caption says so. It is shown on the Conditions page
next to Water Type.

No horizontal bar chart exists (`CategoryBarChart` is vertical, and rotating
an fl_chart `BarChart` rotates its labels too), so a new
`HorizontalCategoryBarChart` widget renders one row per category: label,
a bar proportional to the largest count, and the count.

## UDDF

### Export

- A `<sitetypes>` definitions block holds custom site types (id, name, sort
  order), next to the existing `<divetypes>` block. Built-ins are referenced
  by slug and not defined.
- `<tag>` definitions gain `<appliestodives>` and `<appliestosites>`. The
  exported tag set includes site-only tags.
- Each `<site>` gets `<sitetypes><sitetyperef>` and `<tags><tagref>`
  children. These are written by new shared static writers called from both
  site builders: `UddfExportBuilders.buildSiteElement` (full backup) and the
  hand-written site block in `UddfExportService.generateDivesUddfContent`
  (dives-only).

### Import

- `parseFullSite` puts `siteTypeRefs` and `tagRefs` on the site map. They
  must ride on the map: the import wizard rebuilds `UddfImportResult` from
  entity lists only, so data held elsewhere on the result is dropped.
- `_importSites` resolves refs. A built-in slug maps to itself. A custom type
  matches an existing custom type by case-insensitive name, and is created
  otherwise. A tag ref resolves through the `_importTags` id map, and the tag
  is widened to sites. Unknown refs are dropped.
- A missing `<appliestodives>` or `<appliestosites>` on an imported tag
  keeps today's meaning: dives only, plus sites if a site references it.
- When an import matches an existing site, types and tags are unioned with
  what the site has. An import never removes a type or tag.
- Custom site type definitions reach the importer through the payload
  metadata key `ImportPayload.customSiteTypesKey`, the route custom dive
  roles already use (`uddf_import_parser.dart`, `payload_merger.dart`,
  `UniversalAdapter._payloadToUddfResult`). A new top-level list on
  `UddfImportResult` alone would be dropped by the wizard.
- Fixed in passing: the parser stores a tag's color under `colorHex` but
  `_importTags` reads `color`, so every imported tag lost its color.
  `_importTags` reads `colorHex`.

## Import mappings

Mappings only add types. They never replace types a diver has set.

- Bundled site database (`assets/data/dive_sites.json`): the loader reads
  `features` and maps `wreck`, `wall`, `reef`, `lake`, `cave`, `speleology`
  (to `cave`) and `cavern`. No edit form sits between a bundled site and its
  save (the Import page, the map's add action and import-time site matching
  all save directly), so the mapped types are written with the site when it
  is added. The diver can remove them on the edit page.
- Shearwater: `Environment` Pool, Lake, Quarry and River become
  `siteTypeRefs` on the site map `shearwater_dive_mapper.dart` already
  builds. Ocean/Sea and Brackish map to nothing. Applied only when the import
  creates the site, or the matched site has no types.

## Testing

Tests are written first.

- Migration: v211 to v212 creates the tables, unique indexes and seeds, and
  sets existing tags to dives-only. A fresh `onCreate` database matches the
  upgraded one. Stale version literals in ladder tests are updated.
- Sync:
  - the hlc-registration guard covers the three entities
  - custom types and both junctions round trip between two databases
  - built-ins are never exported
  - a duplicate junction pair applies without throwing
  - a tag row with no `applies_to_*` keys keeps the local scope
  - a junction change never marks the parent site pending
  - a tag folded by name keeps its site links
- Repositories:
  - the site save is transactional (a throw partway leaves no partial set)
  - removals are tombstoned
  - a name collision widens the existing tag
  - `mergeTags` ORs scopes and relinks site tags
  - narrowing a scope removes and tombstones links
  - `mergeSites` relinks types and tags
  - `updateSite` with a partial entity leaves both junctions untouched
- Site list: a statement-count test shows the batch queries do not grow with
  the site count.
- Filters: any-of within a set, AND across filters, clear flags.
- Statistics: overlapping membership counts in each type; stats scope and view
  filter are honored.
- UDDF: a round trip through `performImport` (not the entity importer alone)
  for both the full and dives-only export paths, including custom types,
  site-only tags and the union on re-import.
- Mappings: Shearwater environments and bundled-database features.
- Widgets: the edit section, detail chips and tap-to-filter, the filter
  sheet, the Site Types page and the Tags page scope editor.

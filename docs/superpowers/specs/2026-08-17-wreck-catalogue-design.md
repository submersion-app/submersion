# Wreck Catalogue (Slice 3a) - Design

**Date:** 2026-08-17
**Status:** Approved (design dialogue with Eric, 2026-08-17)
**Part of:** the seascape usefulness program. Slices 1 and 2 and the
batch-3 unification are merged (#1073, #1076, #1082, #1083, #1114).
This is the first of three sub-projects that replace the original
single "slice 3: wreck suggestions".

## Problem

Divers know things about wrecks that no dive-site record can hold: what
the vessel was, how deep the deck sits versus the seabed, when and how
it sank, whether it is intact enough to penetrate, whether it is
protected. Today the only place to put any of that is a site's free-text
notes, or the `wreck` marker that slice 2 added, which carries a name
and a position and nothing else. A wreck also outlives any one dive
site: you can know about a wreck long before you log a site for it.

## Decomposition (Eric, 2026-08-17)

The original slice 3 sketch ("fetch wrecks from OSM and NOAA, offer them
as suggestions") assumed suggestions would write into `site_features`.
Eric asked instead for an editable wreck catalogue "similar to sites",
which makes the wreck a first-class entity and the external sources mere
writers into it. That is three subsystems, delivered in order:

- **3a (this spec): wreck catalogue core.** The synced, diver-editable
  entity, its pages, and its links. Manual entry only.
- **3b: external ingestion.** OSM Overpass and NOAA ENC behind one
  source interface, cached like reef data, matched against the
  catalogue, surfaced as suggestions with durable dismissals.
- **3c: integration.** Wrecks in the 3D seascape, wreck-to-site
  discovery, and any further reconciliation with `site_features`.

Splitting this way is what keeps the sources loosely coupled: they
become writers into a stable entity rather than a pipeline that owns its
own storage.

## Decisions (Eric, 2026-08-17)

- Sources: both OSM and NOAA ENC eventually, but neither in 3a.
- **The catalogue owns the wreck; features link to it.** A
  `site_feature` gains a nullable `wreckId`, so a wreck marker placed on
  a site points at the real record instead of duplicating its name and
  depth.
- **A wreck is independent with an optional site link.** It carries its
  own coordinates and a nullable `siteId`, so it can exist with no site
  at all.
- **Field set: diver-facing essentials.** Enough for a briefing and for
  3b to have somewhere to put what OSM and ENC actually provide, with no
  fields that would sit permanently empty.

## Design

### Data model (schema v153)

New `Wrecks` table, mirroring `DiveSites` structurally so ownership,
sharing, and sync behave identically:

| Column | Type | Notes |
| --- | --- | --- |
| `id` | TEXT PK | UUID v4 |
| `diverId` | TEXT nullable FK | references `Divers`, as on `DiveSites` |
| `siteId` | TEXT nullable FK | references `DiveSites`, `onDelete: KeyAction.setNull` |
| `name` | TEXT | required, as on `DiveSites` |
| `latitude` / `longitude` | REAL nullable | a wreck can be known before its position is |
| `vesselType` | TEXT nullable | enum NAME: `ship`, `aircraft`, `other` |
| `depthToDeckMeters` | REAL nullable | stored metric, displayed in diver units |
| `depthToSeabedMeters` | REAL nullable | stored metric |
| `lengthMeters` | REAL nullable | stored metric |
| `yearBuilt` | INT nullable | |
| `yearSunk` | INT nullable | |
| `causeOfSinking` | TEXT nullable | enum NAME: `foundered`, `collision`, `grounding`, `scuttled`, `war`, `fire`, `unknown` |
| `condition` | TEXT nullable | enum NAME: `intact`, `broken`, `debris` |
| `penetrationPossible` | BOOL nullable | null means unknown, which is not the same as no |
| `protectedStatus` | TEXT nullable | enum NAME: `none`, `permitRequired`, `protected`, `warGrave` |
| `notes` | TEXT | default `''` |
| `isShared` | BOOL | default false, as on `DiveSites` |
| `createdAt` / `updatedAt` | INT | Unix milliseconds |
| `hlc` | TEXT nullable | per-row clock; full LWW entity |

Every enum column stores the raw enum NAME and the domain entity keeps
the raw string alongside a nullable typed getter, exactly as
`site_features.type` does, so a row written by a newer build survives
sync and round-trips unchanged instead of being dropped.

Two columns are added to `site_features` in the same migration:

- `wreckId` TEXT nullable, references `Wrecks` with
  `onDelete: KeyAction.setNull`.
- `source` TEXT, default `'diver'`. Nothing today distinguishes a
  diver-placed feature from an imported one; 3b needs that distinction,
  and adding it now avoids a second migration a week later.

Migration v153 creates the table and adds the two columns idempotently,
called from BOTH `onUpgrade` and the `beforeOpen` backstop (the
parallel-branch version-collision self-heal). A raw index
`idx_wrecks_site` on `wrecks(site_id)` backs the per-site lookup.

### Repository, providers, sync

`WreckRepository` follows the house write ritual on every mutation:
write the row, `markRecordPending(entityType: 'wrecks', ...)`, then
`SyncEventBus.notifyLocalChange()`. There is no parent bump, because a
wreck is a top-level entity like a site rather than a child.

Providers mirror the sites feature: `wrecksProvider` for the list,
`wreckProvider(id)` for one, `wrecksForSiteProvider(siteId)` for the
site-detail section, each refreshed through `invalidateSelfWhen` on the
repository's table-update stream.

Sync enrolls `wrecks` as a conflict-capable LWW entity: the twelve
serializer points, the merge order with `hasUpdatedAt: true`,
`entityHasUpdatedAt`, `_hlcTargets`, and `parentRefs` naming both FKs
(`diverId` to `divers` nullable, `siteId` to `diveSites` nullable). The
delta export filters on the row's own `hlc`. The `site_features` entry
in `parentRefs` gains its new `wreckId` reference, also nullable. The
existing completeness suites enumerate every one of these and name any
that is missed.

### Lifecycle

Site delete nulls `wrecks.siteId` rather than cascading: a wreck must
outlive the diver's decision to stop logging a site for it. Site merge
re-points wrecks to the survivor inside the existing transaction and
records their prior `siteId` in `MergeSnapshot` so `undoMerge` restores
them, the same shape `_relinkSiteFeatures` uses.

### UI and navigation

Wrecks become a new routable nav destination (`/wrecks`, unpinned), so
it shows in the wide-screen rail and in the phone overflow sheet, and
any diver who dives wrecks often can promote it. The pinned set is
untouched.

Three pages, deliberately mirroring the sites feature and reusing its
widgets rather than building parallel ones:

- `WreckListPage` in the master-detail scaffold, with `?selected=`
  selection, search, and the shared list/table view modes.
- `WreckDetailPage`: a map card for the wreck's position (the existing
  `SiteScapeView` takes a location and a selected id and works here
  unchanged), the structured facts in display units, the linked site
  when there is one, and edit/delete actions.
- `WreckEditPage` following the site edit form conventions, including
  the shared location picker.

Two outward touchpoints:

- Site detail gains a "Wrecks here" section listing catalogue wrecks
  linked to that site, with an action to link an existing wreck or
  create one already linked.
- The feature edit sheet gains an optional wreck picker when the type is
  `wreck`, which is what sets `site_features.wreckId`. The picker
  resolves its list by AWAITING the provider future rather than reading
  it: the same `ref.read` shape silently dropped taps in slice 2 until
  the coverage pass caught it.

## Testing

- Repository CRUD with the write ritual asserted (pending mark, hlc
  stamp, no parent bump), and unknown-enum-name round-trips.
- Migration v153: table round-trip, `setNull` on site delete, and the
  two new `site_features` columns present with their defaults.
- Sync: the enforced completeness suites plus a round-trip asserting an
  edit exports by its own hlc and merges LWW.
- Merge: wrecks re-point to the survivor; snapshots restore on undo.
- Widget: list rendering and search, detail rendering in both unit
  systems, edit form save/validation, the site-detail "Wrecks here"
  section, and the feature-sheet wreck picker setting `wreckId`.
- Established traps apply: bounded pumps on map-hosting pages, settings
  notifier mocks, locale pinned to `en` wherever finders use English
  strings, l10n keys in all 11 arb files.

## Out of scope

- Any external source, suggestion, matching, or dedup logic (3b).
- Wreck-specific 3D rendering beyond the existing marker path (3c).
- Wreck merge (the sites merge flow is not generalized here).
- Photos or media attached to wrecks.
- User-extensible vessel types or conditions.

## File plan (indicative)

New: `lib/features/wrecks/domain/entities/wreck.dart`,
`lib/features/wrecks/data/repositories/wreck_repository.dart`,
`lib/features/wrecks/presentation/providers/wreck_providers.dart`,
`lib/features/wrecks/presentation/pages/wreck_list_page.dart`,
`wreck_detail_page.dart`, `wreck_edit_page.dart`,
`lib/features/wrecks/presentation/widgets/site_wrecks_section.dart`,
plus tests for each.

Touched: `database.dart` (table, two columns, v153),
`performance_indexes.dart`, the sync serializer/service/repository trio,
`site_repository_impl.dart` (merge relink and snapshot),
`nav_destinations.dart`, `app_router.dart`,
`site_detail_page.dart` (wrecks section),
`site_feature_sheet.dart` (wreck picker), the l10n arb files, and the
sync completeness tests.

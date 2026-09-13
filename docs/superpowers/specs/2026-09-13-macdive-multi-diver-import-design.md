# MacDive multi-diver import

Date: 2026-09-13
Issue: #1893

## Problem

A MacDive library can hold several divers. `ZDIVE.ZRELATIONSHIPDIVER` and
`ZCERTIFICATION.ZRELATIONSHIPDIVER` link each dive and certification to a
`ZDIVER` row. Submersion imports every dive into the active diver profile.
Since #912, `MacDiveDiveMapper` tags each dive with its MacDive diver's name
(`macdive_dive_mapper.dart:135-143`, `:935-940`) and warns that everything
lands in the current profile (`:254-266`). Certifications are not attributed
at all: the reader never reads their diver column, so every diver's cards
also land on the active profile.

The MacDive XML export carries the same information in a per-dive
`<diver>` element. In the reference library it is filled on 503 of 540
dives, empty on exactly the 37 dives whose SQLite FK is NULL. The parser
reads it into `MacDiveXmlDive.diver` and never uses it.

The import pipeline is single-diver throughout. `UddfEntityImporter.import`
takes one `diverId` and stamps it on every row
(`uddf_entity_importer.dart:354`). `UniversalAdapter.checkDuplicates` scopes
existing data through providers keyed to the active diver.

## Goals

- One MacDive import (SQLite or XML) writes each MacDive diver's dives and
  certifications to the Submersion profile the user chooses: an existing
  profile, a new one created during the import, or none.
- Library-wide reference data (sites, buddies, gear, tags, dive types, dive
  centers, trips, courses) follows the dives that use it, so each profile
  receives the items its own dives reference.
- Single-diver libraries import exactly as they do today.
- `UddfEntityImporter` is not modified.

## Non-goals

- Diver-aware resync matching (follow-up issue, see Risks).
- Multiple `<owner>` elements in UDDF; Subsurface multi-diver files
  (follow-up issue).
- Importing `ZDIVER` birthdate, address or photo. `Diver` has no birthdate
  or address field, and photos are links only.
- Renaming a new profile inside the wizard. It can be renamed in Settings.
- `UniversalImportNotifier._checkDuplicates`, which is unscoped but whose
  result the unified wizard never reads.

## Decisions

| Question | Decision |
| --- | --- |
| One pass or one diver per import | One pass, every MacDive diver mapped to a target |
| Shared reference data | Follows the dives; items no dive uses go to the primary target |
| Targets offered | Existing profile, "Create new profile", "Don't import" |
| Dives with no MacDive diver | Own row in the step, default the active profile |
| Diver-name tags | Only when two or more source rows land in the same profile |
| MacDive XML | Included, keyed by `<diver>` name |
| Architecture | Expand the payload, then slice it per target (approach A) |

## Design

### 1. Payload model and parsers

New value type `SourceDiver`
(`lib/features/universal_import/data/models/source_diver.dart`):

- `key`: `macdive:<ZUUID>` for SQLite, `name:<trimmed name>` for XML. The
  constant `SourceDiver.unownedKey` identifies dives and certifications with
  no diver.
- `name`, `diveCount`, `certificationCount`.
- Optional profile fields, SQLite only: `email` (`ZEMAILADDRESS`), `phone`
  (`ZPHONE`, falling back to `ZMOBILE`), `emergencyContact`
  (`ZEMERGENCYCONTACT`), `bloodType` (`ZBLOODTYPE`), `danNumber`
  (`ZINSURANCEDAN`).

`ImportPayload` gains a typed `sourceDivers` field (default empty), included
in `props`. It is a field rather than a metadata key because
`PayloadMerger` replaces `metadata` wholesale (`payload_merger.dart:180`).

Dive maps and certification maps gain `sourceDiverKey`. `PayloadMerger`
does not namespace it (the same person in two files is one diver) and merges
`sourceDivers` across files by key, summing counts.

The Divers step applies only when two or more real divers (not the unowned
row) have dives or certifications. When only one real diver exists, its
unowned dives are treated as that diver's and the payload behaves exactly
as today: no step, everything to the active profile.

SQLite changes:

- `MacDiveDbReader` reads `ZCERTIFICATION.ZRELATIONSHIPDIVER` and the extra
  `ZDIVER` columns.
- `MacDiveDiveMapper` stamps `sourceDiverKey` and builds `sourceDivers`.
- The diver-name tag emission and the "imported into the current diver
  profile" warning are removed. Name tags move to the expander (section 3).

XML changes:

- `MacDiveXmlParser` groups dives by trimmed `<diver>`; empty is unowned.
  XML divers carry a name only and have no certifications.
- The "rarely populated" comment in `macdive_xml_models.dart` is corrected.

### 2. Divers step

`DiverMappingStep`
(`lib/features/import_wizard/presentation/widgets/diver_mapping_step.dart`),
added to `UniversalAdapter.acquisitionSteps` between Map Fields and Photos.
It is always in the list, because the wizard derives page indices from the
list length (`unified_import_wizard.dart:135-138`). It uses
`autoAdvance: true` with `canAutoAdvance: universalAdapterSingleDiverProvider`,
the same pattern as the Photos step.

Layout: an explanatory line ("This MacDive library has dives for 3 divers.
Choose where each diver's dives go."), then one row per source diver,
ordered by dive count descending, with the name, "N dives, M
certifications", and a dropdown: every existing profile (from
`allDiversProvider`), "Create new profile <name>", "Don't import". When
unowned dives exist, a final row "Dives with no diver (N)" follows.

Defaults come from a pure
`defaultDiverMapping(sourceDivers, profiles, activeDiverId)`:

1. A profile whose name equals the diver's name, compared case-insensitively
   after trimming, is preselected.
2. Otherwise the highest-count unmatched diver gets the active profile,
   unless a name match already claimed it.
3. Every other diver gets "Create new".
4. The unowned row gets the active profile.

Two rows may map to the same profile. Choosing "Create new" for a diver
whose name matches an existing profile is allowed and creates a second
profile with that name; the default never does this. `canAdvance` requires
at least one row that is not "Don't import".

State: a sealed `DiverTarget` with `ExistingDiverTarget(diverId)`,
`NewDiverTarget(sourceKey)` and `SkipDiverTarget`. `UniversalImportNotifier`
state holds `diverMapping: Map<String, DiverTarget>` and keeps the parsed
payload as `sourcePayload`. The step's `onBeforeAdvance` expands
`sourcePayload` into `payload`. Going Back and changing the mapping
re-expands from `sourcePayload`, so expansion never runs on its own output.
Every existing consumer keeps reading `payload`.

All new strings are ARB keys translated in all 11 locales.

### 3. Payload expansion

Pure `PayloadDiverExpander.expand(source, mapping, activeDiverId)`
(`lib/features/universal_import/data/services/payload_diver_expander.dart`)
returns an `ImportPayload` whose every item carries `_targetKey`:
`diver:<id>` for an existing profile, `new:<sourceKey>` for a profile to be
created. Single-diver payloads never pass through it.

1. Dives and certifications take their source row's target. Rows mapped to
   `SkipDiverTarget` are dropped.
2. For each target, collect every reference its dives make: `site.uddfId`,
   `siteId`, `tripRef`, `diveCenterRef`, `courseRef`, `equipmentRefs`,
   `gearLinks` (`itemRef`, `viaRef`, `setRef`), custom `diveTypeIds`,
   `buddyRefs`, `diveGuideRefs`, `buddyRoleRefs`, `tagRefs`. Emit one copy
   of each referenced item per target, with `uddfId` unchanged (unique
   within a target). Follow indirect links transitively: equipment
   `parentRef` and `components[].componentRef`, equipment set
   `equipmentRefs`, course `instructorRef`, and service records via their
   `equipmentRef`. Equipment `observations[].diveRef` are filtered to the
   copy's own target's dives.
3. Items referenced only by dropped dives are dropped.
4. Items referenced by no dive go to the primary target: the active profile
   when any row maps to it, otherwise the target of the mapped row with the
   most dives.
5. Media follow their dive; `_diveIndex` is renumbered against the expanded
   dive list, and media of dropped dives are removed.
6. When one target receives dives from two or more source rows, a tag per
   source diver name is added to that target and to those dives'
   `tagRefs`. The unowned row gets no tag.

`sourceDivers` and warnings pass through unchanged.

The reference key lists that `PayloadMerger` keeps (`payload_merger.dart:50`,
`:58`) move to a shared `payload_ref_keys.dart` used by both the merger and
the expander. A key the expander misses degrades to "item goes to the
primary target", never to data loss.

### 4. Duplicate check and Review

`PayloadSlicer.slice(payload)` groups items by `_targetKey` into
`DiverSlice` objects: the target, a payload holding only that target's
items, and per entity type a slice-index to full-list-index map with
`toLocal` and `toGlobal` helpers. Media `_diveIndex` is renumbered within
each slice. A payload with no target keys yields one slice for the active
diver with an identity mapping, so the single-diver path runs through the
same code with no change in behaviour.

`UniversalAdapter.checkDuplicates` loops over slices:

- The active profile (and the untargeted single-diver payload) keeps
  today's provider-based load unchanged. Those providers call the same
  repository methods with the active id, and about 40 existing
  `checkDuplicates` tests override them.
- Any other existing profile: existing data is loaded through repository
  methods that take an explicit `diverId` (`getAllTrips`, `getAllSites`,
  `getAllEquipment`, `getAllBuddies`, `getAllDiveCenters`,
  `getAllCertifications`, `getAllTags`, `getAllDiveTypes`, `getAllDives`,
  `getSourceUuidByDiveId`). Only a non-null id reaches them, because a null
  id makes those filters return every diver's rows. Shared sites and trips
  still match for every profile.
- `new:` target: existing data is empty; the checker still runs for
  intra-batch duplicates.
- Each slice's result is mapped back to full-list indices and merged into
  the groups.

`EntityItem` gains an optional `target` (`ImportTarget`: key, name, isNew),
rendered as a small labelled line under the subtitle in `_NonDuplicateRow`,
`_EntityDuplicateCard` and `DuplicateActionCard` (all three share that
title and subtitle column). It is set only when there are two or more
targets and reads the profile name, or "New: <name>". Selections remain
full-list index sets.

Projected dive numbers in Review (`review_step.dart:43`, today
`nextDiveNumberProvider`) become a per-target lookup:
`getNextDiveNumber(diverId:)` for an existing profile, 1 for a new one.

Import tags from the Review tag field apply to all imported dives.
`_applyImportTags` (`import_wizard_providers.dart:906-932`) groups the
imported dive ids by profile and calls `getOrCreateTag(name, diverId:)` per
profile, so no profile's dives reference another profile's tag rows.

### 5. Import execution

`UniversalAdapter.performImport`:

1. Slice the expanded payload; the primary target runs first.
2. For each slice, in order:
   - For a `new:` target with at least one selected item, create the
     profile immediately before its slice with `DiverRepository.createDiver`
     and the `SourceDiver` profile fields (DAN number stored as
     `insurance.policyNumber` with provider "DAN"). A target with nothing
     selected creates no profile.
   - Map selections, `duplicateActions` and `entityMatches` to slice
     indices; build `preResolvedIdsFor` from the slice.
   - Run `importer.import(diverId: slice.diverId)` and map its result back
     to full-list indices, recording the dive ids per profile.
   - After the loop, consolidation, photo attachment, file outcomes and
     counts run once, unchanged, on the merged full-list result: every one
     of them already works in full-list indices.
3. Merge into one `UnifiedImportResult`: counts summed, plus a new
   `diverOutcomes` list with one entry per profile (id, name, whether new,
   counts). Background refreshes and the dive-number clash notice work by
   dive id or by each dive's own `diver_id`, so they need no change.
4. If a slice fails, stop. The result carries the completed profiles and
   the error. The importer has no enclosing transaction today, so partial
   imports on failure are existing behaviour; the Summary now reports where
   it stopped.

Stored source files need no change: `ImportedFileRepository.store` is
content-addressed (`id = sha256(bytes)`) and not diver-scoped, so every
slice resolves to the same `imported_files` row.

`UnifiedImportResult.importedDiveIds` holds only the active profile's
dives in a multi-profile import, because every reader of it ("View Dives",
the data-quality count, site matching) works in the active profile. Every
profile's dives are in `diverOutcomes`.

Summary step: with two or more outcomes, a "By profile" section lists each
profile, its dive count, and a "New profile" label where applicable. The
active profile does not change. "View Dives" opens the active profile's
imported dives; other profiles' rows read "Switch to <name> to see these
dives". `allDiversProvider` already self-invalidates on the divers table,
so a created profile appears without extra invalidation. When a later
slice fails, the result has both outcomes and an error message; the
Summary then shows the success view with the error above the "By profile"
section instead of the error-only view, so the completed profiles stay
visible.

The Divers step's defaults are seeded in the Map Fields step's
`onBeforeAdvance`, which the wizard runs even when Map Fields auto-skips,
after the next page is chosen and before it renders.

## Risks

- Resync: `DiveResyncOrchestrator` picks the best-matching dive across the
  whole re-parsed file regardless of diver. A buddy dive logged by two
  divers could resync from the other diver's samples. This exists today and
  is not made more likely by this change. Tracked as a follow-up issue.
- Index remapping: selections, `duplicateActions`, `matchResults`,
  `entityMatches`, `diveIdByIndex` and media `_diveIndex` are full-list
  indices. All remapping goes through `DiverSlice.toLocal` and `toGlobal`
  so there is one place to get it right.

## Testing

TDD throughout.

| Layer | Cases |
| --- | --- |
| SQLite reader and mapper | Extend `test/fixtures/macdive_sqlite/build_synthetic_db.dart` with a second diver, NULL-FK dives and certifications with a diver FK. Assert `sourceDivers`, `sourceDiverKey` on dives and certifications, the single-real-diver rule, and that the name tags and warning are gone (rewrite the #912 assertions). |
| XML parser | `<diver>` grouping, blank is unowned, name only. |
| `defaultDiverMapping` | Name match ignoring case and outer spaces, active profile to the top unmatched diver, active already claimed, unowned to active. |
| `PayloadDiverExpander` | Shared site copied per target; items used only by skipped dives dropped; unused items to the primary target, including when the active profile is unmapped; transitive links (components, sets, service records, course instructor, observations); media renumbered; name tags only on a merge and never for unowned; expanding the same source twice gives equal results. |
| `PayloadSlicer` | Index round trips; single-target identity. |
| `UniversalAdapter`, in-memory DB | Rows land with the right `diver_id`; a shared site is created once per profile; a dive duplicating an existing dive for one profile is new for another; a new profile gets the `ZDIVER` fields; no profile when all its items are deselected; a failure in the second slice keeps the first and reports it; import tags created per profile. |
| Widgets | Divers step defaults, dropdown, `canAdvance`, auto-skip for a single diver; the Review chip; the Summary "By profile" section. |

## Delivery

One PR, description `Closes #1893`. Follow-up issues filed for diver-aware
resync and for UDDF and Subsurface multi-diver files.

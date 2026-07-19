# Water Type from Dive Site — Design

- **Issue:** [#624 — Dive / Conditions – Water Type](https://github.com/submersion-app/submersion/issues/624)
- **Date:** 2026-07-18
- **Branch:** `worktree-site-water-type-autofill`

## Problem

The reporter notes that entering water type on every dive record "is a bit of a
faff to do separately." For them, water type is a property of the **dive site**
(a body of water is salt or fresh — that doesn't change dive to dive). They want
to enter it once at the site; once a site is assigned to a dive, the dive should
"automatically take that value." With no site, manual entry stays available.

Investigation shows the plumbing is *mostly already there but dead-ended*:

- `dives.waterType` (`database.dart:451`) is fully alive: a `WaterType` enum
  (`enums.dart:52` — `salt`/`fresh`/`brackish`), editable in the Conditions
  section of the dive form, saved/loaded, and consumed by exports (CSV/UDDF/
  Excel/PDF/KML), statistics, and the buoyancy/deco density math
  (`buoyancy_physics.dart:49`, `dive_environment.dart:55`).
- `dive_sites.waterType` (`database.dart:639`) **exists** (added in an earlier
  migration, `database.dart:4720`) and **already syncs** — `_exportDiveSites`
  serializes the whole row via `r.toJson()` (`sync_data_serializer.dart:3601`).
  But it is a **dormant column**: written only by importers
  (`applyImportedMetadata`, `site_repository_impl.dart:173`), **dropped** by the
  entity mapper `_mapRowToSite` (`site_repository_impl.dart:695` never sets
  `conditions`), **never persisted** by `_updateSiteRow`, and exposed by **no
  editor**. `SiteField.waterType` reads `site.conditions?.waterType`
  (`site_field.dart:460`), which is therefore always `null`.

So the issue's premise ("enter it once at the site") is not achievable today.
Delivering it is two parts: **(1) revive the site's water type** (hydrate +
persist + edit UI), then **(2) snap it onto the dive on assignment.**

## Decisions (confirmed with maintainer)

1. **Full scope.** Water type becomes a real, editable attribute of a dive site,
   *and* auto-fills onto the dive when a site is assigned. (Not import-only; not
   dive-only.)
2. **Snap-on-assign, stays editable.** Each time the user picks or changes the
   site, the dive's water type is set to that site's value **if the site has
   one**. A site with no water type never clears an existing value. The dive
   field remains manually editable afterward; re-picking a site re-applies its
   value. No "was it edited?" override flag (rejected as unnecessary state).
3. **Snapshot, not live-derive.** The dive keeps storing its own `waterType`; we
   *copy* the site value in. Chosen over computing `dive.site?.waterType` at read
   time because (a) snap-on-assign + manual override requires an independently
   stored per-dive value, (b) every existing reader of `dives.waterType` keeps
   working untouched, and (c) a dive retains its recorded water type even if the
   site is later edited or deleted (historically correct for a logbook).

## Non-goals

- **No schema migration / version bump.** `dive_sites.waterType` already exists
  and already syncs. This sidesteps the schema-version ladder entirely — no v123.
- **No change to sync serialization.** The column already round-trips through
  `toJson()`; reviving the UI is sufficient.
- **No backfill needed.** Sites previously imported from MacDive/UDDF already
  carry the column value; once hydration lands they simply start displaying and
  auto-filling. No data migration.
- **`SiteConditions` is not removed.** The dead `SiteConditions.waterType` String
  field (`dive_site.dart:219`) is left in place (out of scope), but water type no
  longer routes through it — it moves to a top-level entity field.
- **Planner water type untouched.** `dive_plans.waterType` (`database.dart:276`)
  is a separate deco-calc concern and is out of scope.

## Architecture

### 1. Domain & repository — revive the site column (no migration)

- **Entity** (`dive_sites/domain/entities/dive_site.dart`): add a top-level
  `final WaterType? waterType;` to `DiveSite` (mirroring the dive), threaded
  through the constructor, `copyWith`, and `props`. Import `WaterType` from
  `core/constants/enums.dart`.
- **Hydrate** (`site_repository_impl.dart:695`, `_mapRowToSite`): parse the
  column with a safe lookup, matching the dive repo's pattern
  (`dive_repository_impl.dart:2718`):
  `waterType: row.waterType == null ? null : WaterType.values.asNameMap()[row.waterType]`
  (null-safe; unknown string → null rather than a forced default, so we never
  fabricate a value the user didn't set).
- **Persist**: add `waterType: Value(site.waterType?.name)` to every
  `DiveSitesCompanion` builder that currently sets `difficulty`/`bodyOfWater` —
  the insert/upsert/import paths (`site_repository_impl.dart` ~79, ~133, ~508)
  and `_updateSiteRow` (~731).
- **Read path for the table view**: update only the value-extraction arm of
  `SiteField.waterType` (`site_field.dart:460`) to read
  `site.waterType?.displayName` instead of `site.conditions?.waterType`. The
  other `SiteField.waterType` `case` arms (label, column width, etc.) don't touch
  `conditions` and need no change. Bonus: the existing site-table water-type
  column (`site_providers.dart:680`) starts showing real values for free.

### 2. Site editor — a Water Type picker

- Add a water-type control to the **Dive Info** section of the site editor
  (`dive_sites/presentation/widgets/edit_sections/dive_info_section.dart`),
  alongside min/max depth, difficulty, and rating. Mirror the **difficulty**
  control's shape (a chip row over `WaterType.values`, using each value's
  `displayName`; null = unset).
- Wire the new state through `site_edit_page.dart` (a nullable `WaterType?`
  field, seeded from the loaded site, flushed into the `DiveSite` on save).
- **Merge-aware:** water type must participate in the site merge/import-conflict
  flow like difficulty/rating do. Add a `waterTypeExtras` `MergeFieldExtras?`
  (or route through the generic `mergeExtras('waterType')`) mirroring
  `difficultyExtras` (`merge_field_extras.dart`).
- **Localization:** add one new label string (site-editor water-type label) to
  `en` and all 10 non-en locales, then regenerate `app_localizations*` (repo
  l10n rule — new strings into all locales + regen).

### 3. Dive form — snap on assign

- Today `_selectedSite` is set in several scattered places in
  `dive_log/presentation/pages/dive_edit_page.dart`. Centralize the
  **user-initiated** assignments behind one helper:

  ```dart
  void _selectSite(DiveSite? site) {
    setState(() {
      _selectedSite = site;
      if (site?.waterType != null) _waterType = site!.waterType; // snap; never null-clobber
    });
  }
  ```

- Route these paths through `_selectSite`:
  - site picker result (`onPickSite: _showSitePicker`, `:1732`),
  - quick-create / photo-GPS site create (`:1920`),
  - new-dive prefill (`:453`, `if (p.site != null) …`).
- **Do NOT** route the load-existing-dive path (`:588` `_selectedSite =
  dive.site` / `:608` `_waterType = dive.waterType`) through `_selectSite`.
  Loading a saved dive must preserve its stored water type, not re-snap from the
  site's current value.
- **Clearing the site** (`onClearSite`, `:1735`) sets `_selectedSite = null` and
  leaves `_waterType` untouched.
- The dive's `EnumPickerRow<WaterType>` (`:3490`) and save wiring
  (`waterType: _waterType`, `:4363`; `waterType: _waterType?.name`, `:1001`) are
  unchanged — they already handle the value; we're only changing what pre-fills
  it.

## Data flow

```
Site editor  ──save──▶ DiveSite.waterType ──▶ DiveSitesCompanion(waterType: name)
                                                        │
                                              dive_sites.waterType (TEXT, existing)
                                                        │  (syncs via toJson today)
                          _mapRowToSite ◀───────────────┘
                                │  WaterType? (asNameMap lookup)
                                ▼
Dive form: _selectSite(site) ──snap──▶ _waterType ──save──▶ dives.waterType
                                            ▲
                                   manual override (EnumPickerRow) wins until
                                   the site is re-assigned
```

## Edge cases

- **Site has no water type:** assigning it does not change/clear the dive's
  current value.
- **Manual override then change unrelated field:** override persists (snap only
  fires on site assignment).
- **Change to a different site:** water type re-snaps to the new site's value
  (fixes the stale-value problem of a fill-only-when-empty rule).
- **Re-pick the same site after a manual override:** value re-snaps to the
  site's — accepted (rare; predictable minimal-state behavior).
- **Open an older dive whose water type is null but whose site now has one:**
  stays null on load (loading is not an assign). User can re-pick the site or set
  it manually. Intended.
- **Unknown/legacy string in the column** (defensive): `asNameMap` lookup yields
  null rather than crashing or defaulting.

## Testing (TDD — tests written first)

- **Repository round-trip** (`test/features/dive_sites/…`): save a site with each
  `WaterType`, reload via `_mapRowToSite`, assert equality; assert `null` when
  the column is null; assert an unknown string maps to `null`.
- **Sync round-trip**: export a site with a water type through
  `_exportDiveSites` and re-apply, asserting the value survives (guards the
  "already syncs" claim).
- **Dive auto-fill matrix** (`test/features/dive_log/…`, widget or notifier
  level):
  - assign site w/ type → `_waterType` snaps;
  - assign site w/o type → `_waterType` unchanged;
  - manual edit, then change an unrelated field → override retained;
  - change to a second site w/ a different type → re-snaps;
  - clear site → value retained;
  - load an existing dive → stored value preserved (not re-snapped).
- **Site editor widget test**: the water-type control is present, defaults to the
  loaded value, and a change persists into the saved `DiveSite`.
- **`SiteField.waterType`**: returns the `displayName` for a hydrated site.

## Open questions (flagged, non-blocking)

1. **Field placement in the site editor.** Proposed home is the Dive Info section
   (physical characteristics). Alternative: a dedicated Conditions grouping on the
   site (none exists today). Dive Info chosen to avoid inventing a section for one
   field; trivially movable.
2. **Control style.** Chip row (matches difficulty) vs. the shared
   `EnumPickerRow`. Proposed: chips, for visual parity within the section.

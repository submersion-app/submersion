# Default & geofenced equipment sets

- **Issue:** [#583 — Default equipment set](https://github.com/submersion-app/submersion/issues/583)
- **Date:** 2026-07-13
- **Status:** Design approved; ready for implementation planning
- **Worktree / branch:** `equipment-set-default-583` (off `main` @ `c0f9a930b1b`)

## 1. Summary

Let a diver mark one equipment set as their **default**, and optionally attach
one or more **geofences** to any set so the app auto-selects the right kit based
on where a dive happened. The default covers "I dive locally, my gear is set in
stone"; geofences cover "within X of this point, use my cold-water set."

Both features reduce to a single decision evaluated per dive:

```
bestSetForDive(divePoints):
  1. if any geofence contains one of the dive's known points  -> nearest-center geofence's set
  2. else if a global default set exists                       -> that set
  3. else                                                      -> none
```

A geofence is a *conditional default*; the plain default is the fallback when no
geofence matches. This keeps the feature to one pure selection function plus thin
wiring at the points where a dive is created or its location changes.

## 2. Goals / non-goals

**Goals**
- Mark exactly one equipment set as default, per diver.
- Attach any number of geofences (center + radius) to a set; seed the center from
  an existing dive site or a dropped map pin.
- Auto-apply the best-matching set **only when the dive has no equipment yet**, at
  the dive edit form, dive-computer downloads, and file imports.
- Match a dive against geofences using **all** of its known positions — the linked
  site's GPS plus the computer's entry and exit fixes.
- When a location change surfaces a better-matching set but the dive already has
  gear, **suggest** the swap (dismissible) rather than overwriting it.
- Everything syncs across devices and is scoped per diver.

**Non-goals (this iteration)**
- Conditions other than location (season/date, dive type, buddy).
- Live-linking a geofence to a site's GPS (we copy coordinates at creation).
- Applying defaults during merge/consolidation (a merged dive's gear comes from
  its source dives).
- Any push/notification surface outside the dive edit form.

## 3. User-facing behavior

### 3.1 Default set
- In the equipment-sets list and set detail, one set can be marked **Default**
  (badge + "Set as default" action), mirroring the existing default-diver UX.
- Setting a new default clears the flag from the diver's other sets (mutual
  exclusion, per diver).

### 3.2 Geofence definition
In the set editor, a **Geofences** section lists the set's geofences and offers
**Add geofence**. Each geofence editor:

```
Add geofence
  Center:  (o) From dive site   [ Monterey Bay      v ]
           ( ) Drop a pin        [ open map          ]
  Label:   [ Monterey Bay ]        (prefilled from source; editable)
  Radius:  [=====|--------]  15 mi (shown in the diver's unit; stored as meters)
```

Whichever source is chosen, we **copy** the resulting `latitude`/`longitude` and
store them with the geofence. The center does not track later edits to the source
site.

### 3.3 Matching a dive (multi-point, OR semantics)
A dive can present up to three known positions: its linked site's location, and
the computer's **entry** and **exit** fixes. A geofence **contains** the dive when
its center is within `radiusMeters` of **any** of those points.

Rationale: a named site's stored GPS is often a coarse centroid, while the entry
fix is the precise splash point; and drift dives move, so entry and exit can sit
in different regions. OR-matching over all points catches both.

**Overlap resolution:** among all containing geofences, pick the one whose center
is nearest to *any* of the dive's points; tie-break by smaller radius (more
specific), then set name. Deterministic and independent of iteration order.

### 3.4 Suggest, never overwrite
A single stateless rule, computed from durable data (no hidden session flags):

- **Empty equipment -> auto-apply silently.** At every opted-in creation seam. No
  location known -> global default. Location known (e.g. entry GPS on a download)
  -> geofence match.
- **A location change yields a geofence set that differs from the current gear ->
  suggest.** Shown only in the edit form as a dismissible banner:

```
Equipment
+---------------------------------------------+
| (pin) Near Monterey Bay                     |
|       Apply "Cold Water" set?     [ Apply ] |
+---------------------------------------------+
```

"Differs" = the matched set has at least one item not already on the dive. If the
matched set is already fully present, no suggestion appears. Dismissal is
remembered for the session so rebuilds don't re-nag.

Only **geofence** matches ever raise a suggestion. The global default is a passive
fallback: it auto-applies on empty and otherwise stays silent — it never prompts
to swap gear already on a dive.

Why stateless: an imported dive crosses create -> persist -> (later) reopen in a
fresh widget. Any "did I just auto-apply this?" flag evaporates at the DB
boundary, so the rule must decide from what is actually on the dive.

### 3.5 Where auto-apply runs (on empty only)
- Manual new dive in the edit form.
- Dive-computer downloads.
- File imports (UDDF/CSV/HealthKit) that arrive without equipment.
- **Excluded:** merge/consolidation.

Imported dives that already carry equipment from their source file are non-empty,
so the default never clobbers them — a free consequence of the on-empty rule.

## 4. Data model & migration

### 4.1 `EquipmentSets` gains a column
`lib/core/database/database.dart` (class `EquipmentSets`, line ~785):

```dart
BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
```

Mutual exclusion is enforced at the repository layer (per `diverId`), mirroring
`DiverRepository.setDefaultDiver` (`diver_repository.dart:516`). Because the
existing `equipmentSets` sync path already round-trips the whole row via
`EquipmentSet.fromJson(...).toCompanion(false)`, the new column syncs
automatically once codegen regenerates the data class.

### 4.2 New table `EquipmentSetGeofences`
Mirrors `EquipmentSetItems` (cascade child of a set) plus the HLC/timestamp
columns that synced entities carry:

```dart
class EquipmentSetGeofences extends Table {
  TextColumn get id => text()();
  TextColumn get setId =>
      text().references(EquipmentSets, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text().nullable()();       // display; from site name or user
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get radiusMeters => real()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();          // HLC for conflict resolution

  @override
  Set<Column> get primaryKey => {id};
}
```

- No `diverId`: geofences inherit their set's diver scope via `setId`.
- No `anchorSiteId` FK: we copy coordinates, keeping the geofence decoupled from
  later site edits/deletes. (Provenance lives in `label`; live-linking is a noted
  future enhancement.)
- Register the table in the `@DriftDatabase(tables: [...])` list (near line 2095 /
  2144) alongside `EquipmentSets`, `EquipmentSetItems`.

### 4.3 Migration
- Bump `currentSchemaVersion` (currently **108**, `database.dart:2171`) to the next
  free version.
  - **Ladder note:** PR #584 (buddy multi-cert) reserves v109/v110 on its branch.
    To avoid a collision, this feature should claim the next free version at merge
    time — likely **v111**. Confirm against `main` when the branch is finalized.
- `onCreate`: covered by Drift's `createAll()` for fresh/restored DBs.
- `onUpgrade` step: `m.addColumn(equipmentSets, equipmentSets.isDefault)` and
  `m.createTable(equipmentSetGeofences)`.
- Additive only; no data backfill. No new index needed (both tables are small and
  queried by primary/foreign key). If one is ever added, create it in **both**
  `onCreate` and `onUpgrade` per the project's index-parity rule.

## 5. Domain entities

### 5.1 `EquipmentSet` (extend)
`lib/features/equipment/domain/entities/equipment_set.dart`
- Add `final bool isDefault;` (default `false`).
- Add `final List<EquipmentSetGeofence> geofences;` (default `const []`,
  populated on demand like `items`).
- Extend `copyWith` and `props`.

### 5.2 `EquipmentSetGeofence` (new)
Equatable value object with `copyWith`:
`id, setId, label?, latitude, longitude, radiusMeters, createdAt, updatedAt`.
Expose a convenience `GeoPoint get center`.

## 6. Selection logic

### 6.1 `EquipmentSetSelector` (pure, unit-tested)
New file under `lib/features/equipment/domain/` (e.g.
`services/equipment_set_selector.dart`). No I/O.

```dart
EquipmentSet? bestSetFor({
  required List<GeoPoint> divePoints,          // any of site/entry/exit
  required List<EquipmentSet> sets,            // active diver's sets
  required List<EquipmentSetGeofence> geofences,
}) {
  // 1. geofences containing any dive point
  final containing = <(_Geofence, double distanceToNearestPoint)>[];
  for (final g in geofences) {
    final d = _minDistanceMeters(g.center, divePoints); // null-safe over empty
    if (d != null && d <= g.radiusMeters) containing.add((g, d));
  }
  if (containing.isNotEmpty) {
    containing.sort(_byDistanceThenRadiusThenName);
    return sets.firstWhereOrNull((s) => s.id == containing.first.$1.setId);
  }
  // 2. global default
  return sets.firstWhereOrNull((s) => s.isDefault);
  // 3. else null
}
```

- `divePoints` empty -> geofence step is skipped -> default (or null).
- Distance: reuse `distanceMeters(GeoPoint a, GeoPoint b)` (great-circle Haversine)
  from `lib/core/utils/geo_math.dart:10` — no new helper needed. `GeoPoint` is
  defined in `lib/features/dive_sites/domain/entities/dive_site.dart:203`.
- Guards: a set with no items still "wins" selection but applying it is a no-op
  (see 7.2), so an empty default/geofenced set never errors.

### 6.2 Resolving a dive's points
`divePoints` = non-null of `{ site.location, dive.entryLocation, dive.exitLocation }`.
- `Dive.entryLocation` / `Dive.exitLocation` are `GeoPoint?` (`dive.dart:30-31`).
- In the edit form, the site point is `_selectedSite?.location`
  (`dive_edit_page.dart:158`); entry/exit come from the dive being edited.
- At the download/import seam, all three come from the parsed dive (+ any resolved
  site) before persistence.

## 7. Applying the selection (`DiveEquipmentDefaulter`)

A thin service that owns the "apply on empty" behavior so all three seams share
one implementation. It does **not** live in `DiveRepository.createDive` (that
choke point also serves merges, which must be excluded).

### 7.1 Inputs / behavior
`resolveDefaultEquipment({ currentEquipmentIds, divePoints })`:
- If `currentEquipmentIds` is non-empty -> return unchanged (never clobber).
- Else compute `bestSetFor(...)` and return that set's item ids (or unchanged if
  none / empty set).

### 7.2 Seam wiring (all "on empty" only)
- **Edit form new dive:** after initial state is built, if `_selectedEquipment`
  is empty, apply. With no site yet this yields the global default.
- **Site selected/created** (`onSiteSelected`, `dive_edit_page.dart:1959/1978`):
  recompute points and:
  - empty gear -> apply silently;
  - non-empty and a geofence set differs -> set `_geofenceSuggestion` (banner).
- **Dive-computer download:** in the persistence path
  (`dive_computer_repository_impl.dart:879`), apply on empty using entry/exit GPS.
- **File import:** in `uddf_entity_importer.dart:1279` /
  `dive_import_providers.dart:381` / `healthkit_adapter.dart:269`, apply on empty
  per imported dive.
- **Never** during bulk import do we show suggestions; suggestions are an
  edit-form-only affordance.

### 7.3 Manual equipment edits
Any manual add/remove in the form marks the gear "present"; the on-empty rule then
naturally stops auto-applying, and only the differs-based suggestion can appear.

## 8. Repository & providers

### 8.1 `EquipmentSetRepository`
`lib/features/equipment/data/repositories/equipment_set_repository_impl.dart`
- `setAsDefault(String id, {String? diverId})`: clear `is_default` for the diver's
  sets, set it on `id`, `markRecordPending` each touched row, notify. Mirror
  `setDefaultDiver`.
- Geofence CRUD: `addGeofence`, `updateGeofence`, `removeGeofence` — each
  `markRecordPending` on write and `logDeletion` on remove (mirror the
  `equipmentSetItems` tombstone pattern in `updateSet`).
- `getSetById(..., {includeGeofences})` and a `getGeofencesForSet(setId)`.
- On `deleteSet`, geofences cascade at the DB level; mirror the existing
  set-deletion tombstone approach (the plan verifies child-tombstone semantics
  against the sync deletion rules).

### 8.2 Providers
`lib/features/equipment/presentation/providers/equipment_set_providers.dart`
- `defaultEquipmentSetProvider` (active diver's default, or null).
- `equipmentSetGeofencesProvider.family<..., String setId>`.
- `equipmentSetSelectionProvider` — exposes `bestSetFor` inputs assembled for the
  active diver, consumed by the defaulter/edit form.
- Notifier gains `setAsDefault`, `addGeofence`, `updateGeofence`, `removeGeofence`,
  invalidating the relevant providers (consistent with existing methods).

## 9. Sync serialization

`lib/core/services/sync/sync_data_serializer.dart` — extend the table-driven
plumbing for a new entity `equipmentSetGeofences`:
- Add a `List<Map<String, dynamic>> equipmentSetGeofences` payload field +
  `toJson`/`fromJson` entries (mirror `equipmentSetItems`, lines ~223/336/394).
- Register in the export entity list (line ~579) and add
  `_exportEquipmentSetGeofences`.
- Add insert/upsert case (line ~1831): because the entity carries HLC, use
  `EquipmentSetGeofence.fromJson(data).toCompanion(false)` with
  `insertOnConflictUpdate` (HLC entities use `toCompanion(false)`).
- Add the deletion/tombstone case alongside the other entities (lines ~1306/1598/
  2232).
- `equipmentSets.isDefault` needs **no** serializer change beyond codegen — it
  rides the existing full-row mapping.

## 10. UI

### 10.1 Set list / detail
- `equipment_set_list_content.dart`: a **Default** badge on the default set's tile;
  a small location-pin indicator when a set has geofences.
- Detail page + per-row menu: **Set as default** action (disabled/checked when
  already default), mirroring diver UX.

### 10.2 Set editor
`lib/features/equipment/presentation/pages/equipment_set_edit_page.dart`
- A **Default set** switch, initialized in `_initializeFromSet`, saved through the
  notifier.
- A **Geofences** section: list existing geofences (label + radius in diver unit),
  edit/remove each, and **Add geofence** opening the editor described in 3.2.
  - Center source toggle: dive-site dropdown (reuse the site picker) or map pin
    (reuse an existing map widget / interaction detector).
  - Radius input formatted with the diver's distance unit; stored as meters.
- Geofence edits are staged in local state and committed on save (consistent with
  the page's existing `_isInitialized` / draft pattern).

### 10.3 Dive edit banner
`dive_edit_page.dart` equipment section (around line 2752): a dismissible
`MaterialBanner`/inline card driven by `_geofenceSuggestion`. **Apply** merges the
set's items into `_selectedEquipment` (reuse the existing `onSetSelected` merge at
2925); **Dismiss** clears it and records session dismissal.

## 11. Edge cases & error handling
- No location on a dive -> default only; no default -> no-op (today's behavior).
- Empty set chosen as default/match -> applies nothing (guarded), no error.
- Deleting the default set -> simply no default remains.
- Geofence with no containing points -> ignored.
- Two adjacent geofences both matched (drift dive) -> nearest-center tiebreak.
- Session-scoped suggestion dismissal prevents re-nag on rebuild.
- Per-diver isolation throughout: selection considers only the active diver's sets;
  default mutual-exclusion is per `diverId`; geofences inherit set scope.
- Unit handling: radius always stored in meters; display/entry converts via the
  diver's active unit settings.

## 12. Testing strategy
- **Unit (`EquipmentSetSelector`, distance):** precedence (geofence > default >
  none); OR-match across site/entry/exit; radius boundary (just in/out);
  overlap tiebreak (nearest center, then radius, then name); empty `divePoints`;
  empty set guard; haversine correctness against known vectors.
- **Defaulter:** on-empty applies; non-empty never clobbers; download/import seams
  apply per dive; merge path untouched.
- **Repository:** default mutual-exclusion within a diver and independence across
  divers; geofence CRUD; sync round-trip (export -> import restores `isDefault`
  and geofences); deletion tombstones.
- **Widget:** default toggle + badge; geofence editor (site vs pin, radius units);
  dive-edit auto-apply-on-empty; suggestion banner appears when a site change
  yields a differing set and is suppressed when the set already matches; dismissal.
- Follow project widget-test conventions (zero theme-animation duration; wrap
  post-pump drift awaits in `tester.runAsync`; ensure-visible before tapping).

## 13. Localization
All new user-facing strings (default badge/action, geofence section + editor
labels, radius unit hints, suggestion banner) added to `app_en.arb` and **all 10
non-en locales**, then regenerate localizations.

## 14. Out of scope / future
- Multiple non-location conditions (season, dive type).
- `anchorSiteId` live-linking + "re-sync center from site."
- Suggestions outside the edit form (e.g. a post-download review surface).

## 15. Risks / open items
- **Schema-version ladder collision** with #584 (v109/v110). Claim the next free
  version at merge time and re-verify against `main`.
- **Child-tombstone semantics on set deletion** for geofences must match the
  project's sync deletion rules (resurrection / FK guards). The plan verifies this
  against the existing `equipmentSetItems` behavior rather than assuming it.
- **Map-pin picker** reuses existing map infrastructure; confirm a suitable
  reusable widget during planning to avoid new map-gesture surface.

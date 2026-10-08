# Water Conditions: Reframing Reef Health for Non-Reef Sites

**Date:** 2026-08-08
**Status:** Approved
**Branch:** `worktree-water-conditions`

## Problem

The "Reef" section on the site detail page and the "Reef Health" section on the
dive detail page present NOAA Coral Reef Watch data in coral-bleaching terms at
every site with coordinates. The underlying `dhw_5km` satellite product covers
the entire global ocean, so sea surface temperature and its anomaly are valid at
kelp forests, temperate wrecks, and muck sites — but the "Reef health" label,
bleaching alert level, and Degree Heating Weeks are coral-specific framing that
reads as nonsense there.

Two concrete defects fall out of the current design:

1. **Coastal freshwater leak.** `ReefHealthService.fetch` widens to a ±0.075°
   box when the site lands on a NOAA land pixel. A freshwater quarry or lake
   within ~8 km of a coast silently receives the nearest *ocean* pixel's
   temperature, presented as if it were the site's own water.
2. **Dead rows at non-reef sites.** Ocean non-reef sites see valid temperature
   data under a "Reef health" heading with a meaningless "No Stress" badge;
   inland sites see a permanent "no data" row; every non-reef site sees a
   permanent "Not on a reef" habitat row under a "Reef" heading.

## Decisions (made with the user)

1. The health card becomes a general **"Water conditions"** card for all ocean
   sites: SST and anomaly always; bleaching alert and DHW only when the site is
   on a reef.
2. Freshwater sites get an honest **"satellite water temperature covers oceans
   only"** state on the site page, and the NOAA fetch is skipped entirely for
   them — which also closes the coastal leak.
3. The site-page section is retitled **"Ecosystem"**. "Environment" was
   rejected because the dive detail page already has an "Environment" section
   (the diver's own logged air/water temp, visibility, current).
4. Implementation is **presentation-layer only** (Approach A): services, domain
   entities, cache schema, and existing cached rows are untouched. No new data
   sources (a lakes dataset was considered and rejected as YAGNI).

## Architecture

Two surfaces change; nothing below the repository layer does.

```
site_detail_page ──> ReefSection(location, waterType)      [retitled "Ecosystem"]
                       └─ reefSnapshotProvider(ReefSnapshotRequest)
                            └─ ReefRepository.snapshotFor(point, includeHealth:)
                       ├─ ReefHabitatCard        [hidden when status == empty]
                       ├─ WaterConditionsCard    [was ReefHealthCard]
                       ├─ ReefProtectionCard     [unchanged]
                       └─ NearbySpeciesTier      [unchanged]

dive_detail_page ──> _buildReefHealthSection    [registry name "Water Conditions"]
                       ├─ reefHealthForDiveProvider(...)   [existing, unchanged]
                       ├─ reefHabitatProvider(location)    [new, cache-aside]
                       └─ WaterConditionsCard
```

### Components

**`WaterConditionsCard`** (renamed from `ReefHealthCard`, file renamed to
`water_conditions_card.dart`). Inputs:

- `ReefPart<ReefHealth> health` — required.
- `ReefPart<ReefHabitat>? habitat` — nullable; the dive page passes its own
  lookup, and while that lookup is still loading it passes null.
- `WaterType? waterType` — from the site; null means unknown.

Render rules, in order of precedence:

1. `waterType == WaterType.fresh` → single line: freshwater coverage message.
   (Site page only; the dive page hides the whole section instead — see below.)
2. `health.status == unavailable` → existing "unavailable" line.
3. `health.status == empty` → existing "no data" line.
4. `health.status == ok` → lines, in order:
   - Bleaching alert level — only when `_reefPossible` (below).
   - Degree Heating Weeks — only when `_reefPossible`. Alert level and DHW
     remain inseparable when shown (the level is instantaneous, the damage is
     cumulative; see `bleaching_alert_level.dart`).
   - Sea surface temperature — always; absolute conversion to the diver's unit.
   - SST anomaly — always; **newly displayed** (fetched today but never
     rendered); signed (+/−); delta conversion (see Units).
   - Observation date — always; formatted in UTC as today (NOAA stamps one
     composite per UTC day).

`_reefPossible` is true unless habitat definitively rules a reef out:
`habitat == null || habitat.status != ReefDataStatus.empty`. Conservative on
purpose — an offline habitat provider must never hide an active bleaching alert
at a real reef; the cost is a spurious "No Stress" line at a wreck while
offline.

**`ReefSection`** gains `waterType` (nullable `WaterType`); the call site
(`site_detail_page.dart`, ReefSection instantiation) passes `site.waterType`.
Title becomes "Ecosystem" (existing key `reef_section_title`, value changed).
The habitat card is hidden when `habitat.status == empty`; it still renders in
its `ok` and `unavailable` states.

**`reefSnapshotProvider`** family key changes from `GeoPoint` to a new
Equatable `ReefSnapshotRequest { GeoPoint location; bool fetchHealth; }`.
`fetchHealth` is `waterType != WaterType.fresh`. Equality covers both fields.

**`ReefRepository.snapshotFor`** gains `{bool includeHealth = true}`. When
false, the health slot is `ReefPart<ReefHealth>.empty()` — no network request,
no cache read, no cache write. This is the coastal-leak fix: a freshwater site
never reaches the nearest-water-pixel fallback. Saltwater and brackish sites
keep the fallback, which is legitimate there (a shore site's pin rounding onto
a coastline pixel of the very water being dived).

**`ReefRepository.habitatFor(GeoPoint)`** — new, a thin sibling of the
existing `healthFor`: same `_resolve` cache-aside path, same in-flight dedupe,
provider id `ReefProviderId.habitat`, no variant. Backs a new
`reefHabitatProvider` `FutureProvider.family<ReefPart<ReefHabitat>, GeoPoint>`.

**Dive detail page.** `_buildReefHealthSection` additionally watches
`reefHabitatProvider` for the site location and passes both parts to
`WaterConditionsCard`. While habitat is loading it passes `habitat: null`
(which renders the stress lines — same conservative gate). For
`dive.site?.waterType == WaterType.fresh` the section returns
`SizedBox.shrink()` and issues neither fetch: on a dive page a permanent
coverage-explanation row on every quarry dive is noise, unlike the one-time
explanation on the site page. Section registry (`dive_detail_sections.dart`):
enum id `DiveDetailSectionId.reefHealth` and persisted user section configs are
**unchanged**; display name becomes "Water Conditions", description "Satellite
water conditions on the dive date", in both the l10n keys and the hardcoded
English fallbacks in that file.

### Freshwater semantics

Only `WaterType.fresh` triggers freshwater handling. `null` (unknown) and
`WaterType.brackish` are treated as ocean: brackish sites sit on coastal pixels
where SST is defensible, and unknown should not suppress valid data. Sites
without coordinates are unaffected (both surfaces already hide for them).

## Units

SST converts with the existing `TemperatureUnit.convert` (absolute). The
anomaly is a **delta**: converting +0.4 °C to Fahrenheit must scale only
(×9/5 → +0.7 °F) and never apply the +32 offset. `TemperatureUnit` gains
`convertDelta(double value, TemperatureUnit to)` in
`lib/core/constants/units.dart`, used only for the anomaly line. Degree
Heating Weeks stays in Celsius-weeks in every locale (no imperial equivalent
exists; documented on `ReefHealth.degreeHeatingWeeks`). All displayed values
respect the active diver's unit settings.

## l10n

All 11 locale ARBs (`lib/l10n/arb/app_*.arb`) get every new/changed string, not
just English:

- `reef_section_title` value → "Ecosystem".
- New water-conditions keys: card title, freshwater coverage message, anomaly
  line (parameterized, signed value + unit symbol).
- `diveDetailSection_reefHealth_name` / `_description` values → "Water
  Conditions" / "Satellite water conditions on the dive date".
- Obsolete `reef_health_*` keys that no longer have a consumer are removed in
  the same change; keys reused verbatim (unavailable / no data / DHW / SST /
  as-of lines, alert-level names) keep their existing names even though the
  card is renamed, to avoid churning 11 locales for identical values.

## Error handling

Per-part status handling is unchanged: each row independently renders
`ok` / `empty` / `unavailable`, one provider outage never blanks the section,
and `ReefSnapshot.allUnavailable` semantics are untouched. The dive page's
existing behavior of hiding on loading/error stays.

## Testing

- **Gate matrix** (widget tests on `WaterConditionsCard`): habitat
  {ok-on-reef, empty, unavailable, null} × health {ok, empty, unavailable} —
  stress lines appear exactly when habitat is not `empty`; SST/anomaly/date
  always appear for `ok`.
- **Freshwater skip** (repository test): `snapshotFor(includeHealth: false)`
  issues no health HTTP request and performs no health cache I/O; health slot
  is `empty`; other three parts fetch normally.
- **Delta conversion** (unit test): computed vectors for `convertDelta` — e.g.
  +0.5 °C → +0.9 °F, −1.0 °C → −1.8 °F, identity in Celsius.
- **Section behavior** (widget tests on `ReefSection`): habitat row hidden
  when `empty`, shown when `unavailable`; freshwater message shown for
  `WaterType.fresh`; title reads "Ecosystem".
- **Dive detail**: section hidden for freshwater sites; registry name updated.
- **Consumer sweep**: `ReefHealthCard` is used by both features; all existing
  reef tests (~75) and any dive-detail tests referencing it are updated for
  the rename and new constructor shape. Known repo trap: shared-widget changes
  break consumer tests — run the full reef + dive-detail test set, not just
  new tests.

## Out of scope

- No new data sources (lakes/Great Lakes surface temperature).
- No changes to `ReefHealthService` fetch logic, entities, cache schema, or
  cached rows.
- No changes to protection or species rows beyond the section retitle.
- No conditional section title (rejected: renames itself as data loads).

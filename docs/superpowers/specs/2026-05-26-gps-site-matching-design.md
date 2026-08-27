# Auto-match downloaded dives to dive sites — Design

- **Date:** 2026-05-26
- **Branch:** `feat/gps-site-matching`
- **Builds on:** `2026-05-22-shearwater-swift-gps-entry-exit-design.md` (which populates entry/exit GPS on downloaded dives)

## Goal

When a dive is downloaded from a dive computer and carries entry GPS, attempt to
match it automatically to a site — either an existing site in the user's
database or a site from the bundled "import" database
(`assets/data/dive_sites.json`). High-confidence matches apply automatically;
everything else is surfaced on a review screen for the user to resolve.

## Background — current state

- **GPS on downloaded dives** lives in `Dives.entryLatitude/entryLongitude/exitLatitude/exitLongitude`
  (decimal degrees, nullable). These are populated **only** by direct
  dive-computer download (Shearwater Swift), never by the Shearwater Cloud `.db`
  import path. The domain `Dive` exposes them as `entryLocation` / `exitLocation`
  (`GeoPoint?`).
- **Two pools of sites:** the user's own sites in `DiveSites` (where `diverId` is
  set), and ~3,600 bundled sites in `assets/data/dive_sites.json`, loaded via
  `DiveSiteApiService`.
- **Reusable primitives already exist:**
  - `lib/core/utils/geo_math.dart` — haversine `distanceMeters(GeoPoint, GeoPoint)`.
  - `DiveSiteApiService.searchNearby(lat, lng, radiusKm)` — distance-sorted
    proximity search over bundled sites.
  - `SiteRepository` — `getAllSites(diverId)`, `createSite`, etc.
  - `ExternalDiveSite.toDiveSite(diverId)` — converts a bundled site to a
    `DiveSite` (name, coords, depth, country/region, `notes: "Imported from ..."`).
  - The dive-edit page already sorts the site picker by distance from the
    **device's** GPS and flags sites within 50 km as "nearby" — but nothing uses a
    dive's **own** entry GPS, and nothing runs automatically.
- **A dive links to a site** via `Dives.siteId` (nullable TEXT FK → `DiveSites.id`).
  `siteId` is user-authored.

This feature is largely wiring of existing primitives plus one genuinely new
piece: the confidence rule that decides auto vs. ask.

## Locked behavior (decisions)

1. **Hybrid application:** auto-link high-confidence matches; surface the rest for
   review.
2. **Bundled matches auto-create + link:** a high-confidence match to a bundled
   site auto-creates the `DiveSites` row and links it, the same as an existing
   site.
3. **Existing user sites take precedence** over bundled sites to avoid duplicates.
4. **Trigger:** a post-download **review screen**. The download itself stays
   side-effect-free; the review screen runs the matcher.
5. **Backlog:** the same matcher/review is reachable from the **dives-list
   overflow menu**, covering dives already in the database that have GPS but no
   site.
6. **Two-tier, configurable radius:** an inner radius gates auto-apply, an outer
   radius gates suggestions; controlled by a sensitivity setting.
7. **Review UX:** clear matches are **pre-applied and shown for review** (with
   per-row Change / Unlink); the screen focuses attention on ambiguous / unmatched
   dives.

## Architecture (Approach A — pure matcher + provider-driven review screen)

```text
┌─ presentation ─────────────────────────────────────────────┐
│  SiteMatchReviewPage  ←  siteMatchReviewNotifier (Riverpod)  │
│     ↑ post-download entry        ↑ dives-list overflow entry │
├─ data ──────────────────────────────────────────────────────┤
│  SiteMatchingService                                          │
│   • gathers candidates (SiteRepository + DiveSiteApiService)  │
│   • runs the matcher per dive                                 │
│   • applies AutoMatch results (link existing / create+link)   │
├─ domain ─────────────────────────────────────────────────────┤
│  matchDive(entryPoint, candidates, thresholds) → outcome      │
│   • PURE. no I/O. all confidence logic. heavily unit-tested   │
└──────────────────────────────────────────────────────────────┘
```

### Domain — the matcher

New files under `lib/features/dive_sites/domain/matching/`.

```dart
class MatchCandidate {        // what the matcher reasons over
  final String id;            // existing site id, or bundled id
  final GeoPoint location;
  final bool isExisting;      // true = user site, false = bundled
}

class MatchThresholds {
  final double innerRadiusMeters;   // auto-apply gate
  final double outerRadiusMeters;   // suggestion gate
  final double separationMeters;    // runner-up must be this much farther
}                                   //   for the nearest to count as "clear"

class RankedCandidate {
  final MatchCandidate candidate;
  final double distanceMeters;
}

sealed class SiteMatchOutcome {}
class AutoMatch extends SiteMatchOutcome { final String siteId; final double distanceMeters; final bool isExisting; }
class Suggested extends SiteMatchOutcome { final List<RankedCandidate> candidates; } // 1+, distance-sorted
class NoMatch   extends SiteMatchOutcome {}
```

**`matchDive(...)` — the confidence rule, in order:**

1. Compute haversine distance (`geo_math.distanceMeters`) from the entry point to
   every candidate.
2. Keep candidates within `outerRadius` ("in range"). None → `NoMatch`.
3. **Existing-site precedence:** if any *existing* candidate is within
   `innerRadius`, restrict the auto-decision to existing candidates (never
   auto-create a bundled duplicate when the user already has a site essentially
   here).
4. Within the chosen pool, return `AutoMatch` only if the nearest is within
   `innerRadius` **and** the runner-up is either beyond `innerRadius` or farther by
   ≥ `separationMeters`. Otherwise return `Suggested` with all in-range candidates
   (both pools), distance-sorted. (`Suggested` therefore covers both "multiple
   sites too close to call" and "one site, but too loose to auto-commit".)

**GPS source:** use entry; fall back to exit if entry is null. Both null → the
dive is ineligible. A dive that already has a `siteId` is also ineligible (never
silently re-match).

### Data — `SiteMatchingService`

New file under `lib/features/dive_sites/data/services/`. Performs one matching
pass over a set of dives:

1. **Gather candidates** per dive's entry/exit point:
   - *User sites:* `SiteRepository.getAllSites(diverId)`, filtered to those with
     coordinates. Loaded once per pass and reused across dives (user-site counts
     are small).
   - *Bundled sites:* `DiveSiteApiService.searchNearby(lat, lng, radiusKm:
     outer/1000)`.
   - Merge into `List<MatchCandidate>` tagged `isExisting`.
2. **Run `matchDive`** → `AutoMatch | Suggested | NoMatch`.
3. **Apply only `AutoMatch`** in this pass:
   - *Existing* → write `dive.siteId = <existing id>`.
   - *Bundled* → **materialize then link** via the shared guarded helper.

**Materialize-bundled helper** (shared by the auto path and the review screen):

- **Batch dedup:** a `bundledId → createdSiteId` map ensures one row per bundled
  site per pass (N dives matching the same bundled site create it once, link all
  N).
- **Coincidence guard:** before creating, check existing user sites for one within
  ~100 m of the bundled point (matching the tolerance the import duplicate checker
  already uses). If found, link *that* existing site instead of creating — prevents
  a duplicate when the user already has the site under another name/source.
- Conversion uses `ExternalDiveSite.toDiveSite(diverId)`.

**Rollback:** the service (held by the review notifier for the session) tracks
which bundled rows it created and which dives reference them. If the user
unlinks/changes an auto-applied dive and a created row becomes orphaned, that row
is deleted — a wrong auto-match leaves no junk site behind.

### Settings — match sensitivity

A single `siteMatchSensitivity` enum on diver settings, mapped to threshold sets:

| Preset | inner | outer | separation |
|---|---|---|---|
| Strict | 100 m | 500 m | 100 m |
| **Balanced** (default) | 150 m | 1000 m | 75 m |
| Relaxed | 300 m | 2000 m | 50 m |

A preset (one key, one picker) rather than three free-form radii — still
configurable, but no nonsensical combinations (e.g. outer < inner) to validate.
Raw-meter control can be added later if requested.

> Implementation note: adding `siteMatchSensitivity` to the settings notifier
> requires updating the **four** `SettingsNotifier` test mocks; only
> `flutter analyze` flags a miss. The plan must list this explicitly.

### Presentation — review screen and entry points

**`SiteMatchReviewPage`** + **`siteMatchReviewNotifier`**, seeded with a set of
eligible dives. On open, the notifier runs one matching pass: `AutoMatch`es apply
immediately (pre-applied); `Suggested` / `NoMatch` wait for input.

Layout — a grouped list under a summary header (`"5 matched · 2 to review · 1 no
match"` + **Done**):

- **Matched** — per row: dive (date, depth) → site name · distance · badge
  (*existing* vs *newly added*) · actions **Change** / **Unlink**.
- **To review** (`Suggested`) — dive + ranked candidate radio list (nearest first,
  distance + source) · **Search manually…** · **Skip**. Picking a candidate
  applies it through the shared materialize/link helper.
- **No match** — dive + **Assign manually…** · **Skip**.

Manual assignment reuses the existing site search/import UI
(`externalSiteSearchProvider` / site picker). **Done** closes; skipped dives stay
unsited.

**Edge states:**
- Post-download with zero eligible dives (no GPS) → skip the screen entirely.
- Everything auto-matched → still show the screen (transparency is the point of
  "pre-applied, shown for review").
- Backlog action with nothing eligible → a friendly "nothing to match" message.

**Entry points** (same screen, two seeds):
1. **Post-download** — after the existing import summary, if any just-imported
   dives are eligible, navigate to the review screen seeded with them.
2. **Backlog** — a dives-list overflow action gathers all eligible dives (GPS + no
   site) and opens the same screen.

## Data flow

```text
download → import summary (no site changes)
   └─ eligible dives? ── yes ─→ SiteMatchReviewPage(seed = imported eligible dives)
                                   └─ notifier: matching pass
                                        ├─ AutoMatch  → apply now (link / materialize+link)
                                        ├─ Suggested  → await user choice
                                        └─ NoMatch    → await manual assign / skip

dives list ⋮ → "Match dives to sites" → SiteMatchReviewPage(seed = all eligible dives)
```

## Error handling & edge cases

- **No GPS / already sited:** dive excluded from the seed (ineligible).
- **Bundled asset load failure:** matching degrades to user-sites-only; surfaced as
  a non-fatal notice on the screen, not a crash.
- **Reverse geocoding** of created bundled sites (country/region when absent) is
  best-effort; failure leaves those fields null, consistent with the UDDF
  importer.
- **Orphaned created site** after unlink/change → deleted (rollback).
- **Same bundled site matched by multiple dives in one pass** → created once
  (batch dedup).
- **Bundled site coincides with an existing user site** (~100 m) → link existing,
  don't create (coincidence guard).

## Testing strategy (TDD — matcher first)

- **Matcher unit tests** (the bulk, zero mocks): clear-single, clear-separated,
  ambiguous-within-inner, loose-single → suggested, none, existing-precedence
  (existing within inner beats a closer bundled), entry/exit fallback, separation
  boundary, per-preset thresholds.
- **Service tests** (fake `SiteRepository` + fake `DiveSiteApiService`): candidate
  gathering, link-existing, materialize-bundled, batch dedup (3 dives → 1 row),
  coincidence guard, orphan rollback on unlink.
- **Settings test:** sensitivity persists and maps to thresholds (+ the 4-mock
  update).
- **Review-screen smoke test:** three sections render; Change / Unlink / Skip
  wired; all-matched and empty states.

## Out of scope (YAGNI)

- Matching on Shearwater Cloud `.db` imports (no GPS in that path).
- Re-matching dives that already have a site (no "rematch all").
- A map / pin-drop manual picker (manual assignment reuses existing search).
- Silent background matching with no review screen.
- Raw-meter radius fields (presets only).
- Matching entry and exit as separate points (entry, else exit).

## Guardrails / risks

- **`siteId` is user-authored** — the reparse path must never overwrite it. Add an
  assertion/test, since this codebase has a history of reparse silently dropping
  fields.
- **Auto-create safety** rests on two complementary guards: existing-site
  precedence (at match time, within inner radius of the dive) and the coincidence
  guard (at materialize time, within 100 m of the bundled point). Both must hold
  for "auto-create bundled" to stay duplicate-free.
- **Performance** is a non-issue at current scale (~3,600 bundled sites × a
  download's worth of dives is microseconds of haversine); no spatial index or
  bounding-box prefilter unless measurement later shows otherwise.

## Files (high-level — pinned exactly in the implementation plan)

**New:**
- `lib/features/dive_sites/domain/matching/match_candidate.dart`
- `lib/features/dive_sites/domain/matching/match_thresholds.dart`
- `lib/features/dive_sites/domain/matching/site_match_outcome.dart`
- `lib/features/dive_sites/domain/matching/site_matcher.dart` (`matchDive`)
- `lib/features/dive_sites/data/services/site_matching_service.dart`
- `lib/features/dive_sites/presentation/pages/site_match_review_page.dart`
- `lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart`
- Test files mirroring each of the above.

**Modified:**
- Diver settings (key/enum + notifier + the 4 test mocks) for `siteMatchSensitivity`.
- Post-download summary flow — navigate to the review screen when eligible dives exist.
- Dives-list overflow menu — add the "Match dives to sites" action.
- Settings UI — sensitivity picker.

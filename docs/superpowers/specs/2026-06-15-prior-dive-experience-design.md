# Prior Dive Experience (Career Totals) — Design

- **Date:** 2026-06-15
- **Issue:** [#331 — Dives/dive time prior to logging accounted for in stats](https://github.com/submersion-app/submersion/issues/331)
- **Branch / worktree:** `worktree-prior-dive-experience`
- **Status:** Approved design, pending spec review

## Problem

Experienced divers who started long before they used Submersion cannot represent
their full diving history. The Stats page computes lifetime totals purely from
app-logged dives, so a diver who has logged 43 hours in-app sees "43 hours" as
their grand total even though their real career spans decades. The number reads
as wrong and undermines trust in the app. Digitizing years of paper logbooks is
not realistic, so the diver needs a way to declare a lump-sum of prior experience.

Quoting the requester: "a way to simply tell Submersion I have XXXX amount of
dive time before ... I hate seeing 43 HOURS as a grand total."

## Goals

- Let a diver record experience accumulated **before** they started logging in
  Submersion: a prior dive count, a prior total dive time, and a "diving since" date.
- Fold the prior count and prior time into the two headline lifetime stats
  (Total Dives, Total Time) so they read as a correct career total.
- Show the breakdown (`logged + prior`) so the corrected total is transparent and
  does not look like a bug when it differs from the in-app dive list.
- Make this strictly per-diver (the app is multi-diver; every stat is filtered by
  `diver_id`).

## Non-Goals

- No effect on any stat other than Total Dives and Total Time. Averages, deepest
  dive, average dive length, charts, and per-dive history remain computed purely
  from logged dives. (There is no per-dive detail for the paper-log era, so any
  average/max/chart derived from a single lump figure would be fabricated.)
- No import of paper logbooks, no per-dive backfill, no career-best overrides
  (deepest/longest). These were explicitly considered and declined to keep the
  feature small and every other number truthful.

## Requirements (locked)

| Decision | Choice |
| --- | --- |
| What to capture | Prior dive **time** + prior dive **count** + "diving since" date |
| Display | Combined headline total with a `logged + prior` breakdown subtitle, plus a "Diving since YYYY" line |
| Scope | Only Total Dives and Total Time receive the offset |
| Granularity | Per-diver |

## Current State (as found on `origin/main`)

- **Totals are a live SQL aggregate, not stored.** `DiveRepository.getStatistics()`
  (`lib/features/dive_log/data/repositories/dive_repository_impl.dart:1790`) runs
  `COUNT(*)` and `SUM(COALESCE(runtime, bottom_time))` over the `dives` table,
  filtered by `diver_id`, and returns a `DiveStatistics`
  (`dive_repository_impl.dart:4329`) with `totalDives:int` and
  `totalTimeSeconds:int`. Time is in **seconds**.
- **Display is two stat cards** on `StatisticsOverviewPage`
  (`lib/features/statistics/presentation/pages/statistics_overview_page.dart`):
  "Total Dives" = `${stats.totalDives}` and "Total Time" =
  `stats.totalTimeFormatted` (hardcoded `"Xh Ym"`).
- **Per-diver data has a home.** The `Divers` table
  (`lib/core/database/database.dart:12`) holds profile facts (name, email,
  medical, insurance, notes) and is HLC-versioned for sync; the `DiverSettings`
  table holds preferences. Current Drift `schemaVersion` is `86`
  (`database.dart:1615`).
- **No existing prior-experience concept** in the schema, the `Diver` entity
  (`lib/features/divers/domain/entities/diver.dart:64`), or the roadmap.

## Architecture

**Chosen: Approach 1 — profile field + presentation-layer combine.**

Store the three values on the `Divers` table. Leave `getStatistics()` returning
logged-only numbers. Add a small, pure combine model in the presentation layer
that fuses logged stats with the active diver's prior values and exposes both the
combined totals and the breakdown components.

Rationale: the repository keeps answering "what did this diver actually log,"
and "career view" becomes a presentation concern layered on top. That separation
is also why the scope stays contained — averages and charts call the same
logged-only repository and are simply never handed the offset. Adding columns to
`Divers` is low sync-risk because every existing column on that table already
syncs via the row's HLC; the three new columns follow the identical mechanism.

**Rejected alternatives:**

- *Bake the offset into `getStatistics()`.* Changes the meaning of that method
  from "logged facts" to "career view," rippling to every other consumer and
  forcing a rewrite of existing stats tests; also makes the dive repository reach
  across into profile data. Muddier for no gain.
- *Store in `DiverSettings`.* Career facts are not preferences; this splits
  "things about the diver" across two tables and forces the profile-edit screen
  to read half its data from the settings table. Semantic mismatch.

## Detailed Design

### 1. Data model & storage

Add three nullable columns to the `Divers` table
(`lib/core/database/database.dart`):

- `priorDiveCount` — `IntColumn`, nullable.
- `priorDiveTimeSeconds` — `IntColumn`, nullable. Stored in seconds to match the
  existing `totalTimeSeconds`.
- `divingSince` — `IntColumn`, nullable. Stored as the **year integer** (e.g. 1990),
  not a timestamp, so the displayed year is timezone-stable across sync/restore;
  entered via a year picker.

Bump the Drift `schemaVersion` and add an `onUpgrade` step that adds the three
columns. Existing rows get `NULL`, which means "no prior experience" and reproduces
today's behavior exactly. Regenerate Drift codegen (`build_runner`) after the
schema change.

> Implementation note: pin the exact next `schemaVersion` at implementation time.
> The base is `86` on `origin/main`, but the in-flight incremental-sync work may
> merge first and move it. Do not hardcode `87` from this doc.

### 2. Domain entity

Extend the `Diver` entity (`lib/features/divers/domain/entities/diver.dart`) with
`priorDiveCount`, `priorDiveTimeSeconds`, and `divingSince`, including `copyWith`.
Update the diver repository mapping (row to entity and entity to companion) so the
new columns round-trip.

### 3. Entry UI

Add a "Prior experience" section to the diver profile edit page:

- Dive-count field (integer).
- Dive-time field: hours + optional minutes (minutes default 0). At lifetime
  scale minutes are mostly noise, but the pair keeps storage in seconds exact and
  matches the existing `"Xh Ym"` display vocabulary.
- "Diving since" year picker.

All fields optional; blank means zero offset for that quantity. Validation:
non-negative integers, minutes 0–59, year between 1900 and the current year.

### 4. Read & combine

- Add `earliestLoggedDiveDate` (a `MIN(dive_datetime)`) to the `getStatistics()`
  result so "diving since" can display the earlier of the entered year vs the
  first logged dive.
- Introduce a pure `CareerTotals` model (presentation layer) plus a provider that
  watches logged `DiveStatistics` and the **active** diver's prior values. It
  exposes:
  - `loggedDives`, `priorDives`, `combinedDives`
  - `loggedTimeSeconds`, `priorTimeSeconds`, `combinedTimeSeconds`
  - `divingSince` (reconciled; see edge cases)
  - `hasPriorExperience` flag
- The combine is a pure function (no I/O), making it trivial to unit-test.

### 5. Display

Update the two `_StatCard`s on `StatisticsOverviewPage`:

- Card value shows the **combined** total.
- When `hasPriorExperience` and the relevant prior value > 0, render a two-line
  subtitle stacked under the number — line 1 `312 logged`, line 2 `+ 1,200 prior`
  (and `43h logged` / `+ 1,150h prior` for the time card).
- Render a "Diving since YYYY" line below the grid when a reconciled date exists.
- When the diver has no prior experience, the page looks **exactly** as it does
  today: no subtitle, no since-line. Zero impact for the majority of users.

## Edge Cases & Error Handling

- **Null/zero prior:** behaves as today; no subtitle, no since-line.
- **Partial entry:** any field may be filled independently (e.g., count but not
  time). Each prior value offsets only its own total; the breakdown shows for
  whichever quantity is non-zero.
- **"Diving since" reconciliation:** displayed value is
  `min(enteredDate, earliestLoggedDive)`. Handles entered-only, logged-only, both,
  and neither.
- **Input validation:** reject negative counts/times, minutes outside 0–59, and
  years outside 1900..currentYear, with inline field errors.

## Sync

The three new columns ride the `Divers` row's existing HLC, exactly like the
other profile columns. **Verify at implementation** that the Divers sync
serialization enumerates columns generically rather than from a hardcoded list,
so the new columns propagate to other devices. This is the one real risk to
confirm given the app's incremental-sync machinery.

## Localization

All new user-facing strings ("Prior experience", field labels, "logged",
"prior", "Diving since {year}") must be added to the ARB files and translated
into all 10 non-English locales, not left as English fallbacks, then regenerated.

## Testing (TDD)

- **Pure combine function:** logged+prior, null/zero prior, partial entry;
  breakdown components correct.
- **"Diving since" reconciliation:** entered-only, logged-only, both, neither.
- **Migration:** upgrading an existing DB adds the columns with NULL defaults and
  leaves existing rows untouched.
- **Repository:** `getStatistics()` still returns logged-only totals; new
  `earliestLoggedDiveDate` is correct (and null on an empty log).
- **Widget:** stat cards show the combined total; subtitle appears only when prior
  > 0; "Diving since YYYY" line renders correctly; page is unchanged when no prior
  experience exists.
- **Entity:** `Diver.copyWith` round-trips the new fields.

## Out of Scope / Future

- Career-best overrides (deepest/longest dive reflecting the paper-log era).
- A user-configurable duration display format.
- Including prior experience in per-dive CSV export (it is not per-dive; full DB
  backup already captures it).

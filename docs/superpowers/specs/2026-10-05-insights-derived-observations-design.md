# Insights: derived observations

Date: 2026-10-05
Status: design approved in brainstorming, awaiting written-spec review
Issue: #2381 (umbrella, phase 4 of 4). This PR uses `Refs #2381`.

## 1. Problem

Insights shows numbers: charts, rankings and totals across ten categories.
It does not tell a diver what those numbers say. A diver whose gas consumption dropped
over the last year, who just logged their 200th dive, or whose ascents are
getting faster has to find that out by reading charts.

Issue #2381 splits the broadening of Insights into four phases. Phase 1
(the rename) merged in #2385. Phase 3 (a home for upcoming features) has
mostly happened through other programs: Connections is an Insights tile, and
natural-language search moved into the unified Dives search with an "Open in
Insights" handoff. Phase 2 (a findings-first landing page) needs content to
lead with. This spec is phase 4, derived observations, which supplies that
content. The phase 2 landing redesign follows in a later PR.

## 2. Goal and success criteria

Insights turns the diver's log into short, ranked, dismissible sentences.

- A diver with a reasonable log sees up to three observations at the top of
  the Insights landing on both layouts, and every observation on an
  Observations page.
- Every observation is a fact the existing Insights pages can confirm, in
  the diver's units and language.
- A trend appears only when the data supports it (section 4.1).
- Dismissing an observation hides it until its facts change. Muting a kind
  hides every observation from that rule until unmuted. Both sync.
- Nothing appears for a log too small to say anything, and the strip takes
  no space when it is empty.

## 3. Decisions

| Question | Decision |
| --- | --- |
| Scope of this PR | Phase 4 only. Observations show on the existing landing; the redesign is phase 2. |
| Kinds of observation | Trends, milestones and firsts, patterns and habits, safety-adjacent. |
| Dismissal | Dismiss hides one observation until its fingerprint changes. "Don't show this kind" mutes the rule; unmute from the Observations page. |
| Architecture | Compute on read. Only dismissals (synced table) and mutes (diver settings JSON column) persist. |
| Placement | Top-3 strip above the phone category list and at the top of the desktop Overview pane; "See all" opens an Observations page. |
| Insights filter | Ignored. Observations always read the whole log; under an active filter the strip and page say so. |

## 4. Rules

Every rule reads the whole log of the active diver through queries the
Insights repository already runs, without the view filter. Rules therefore
inherit the existing persistent exclusions (`DiveStatsScope`: dives excluded
from statistics and planned dives; for RMV also per-dive gas exclusions and
gauge mode). All
values print in the diver's units.

"Last 12 months" is the window ending now; "the year before" is the 12
months before that. "Recent" means the last 90 days.

### 4.1 Significance for trends

A trend fires only when all three hold:

1. Both periods have at least 8 qualifying dives (dives that have the
   metric).
2. The change passes the rule's minimum (table below).
3. The effect size, |mean_a - mean_b| / pooled standard deviation, is at
   least 0.5.

The effect-size check keeps a noisy log from producing confident sentences.
Dive frequency is a count, not a per-dive metric, so it uses only its own
minimum.

### 4.2 Catalog

| Kind | Rule id | Fires when | Fingerprint | Tap opens |
| --- | --- | --- | --- | --- |
| Trend | `rmvTrend` | RMV (surface gas consumption, L/min) changes by 8% or more | direction + 10% band | Gas |
| Trend | `maxDepthTrend` | average max depth changes by 15% or more | direction + 10% band | Progression |
| Trend | `diveTimeTrend` | average runtime changes by 15% or more | direction + 10% band | Progression |
| Trend | `weightTrend` | average weight carried changes by 1 kg or more | direction + 1 kg band | Equipment |
| Trend | `frequencyTrend` | dive count changes by 30% or more and by 6 dives or more | direction + 10% band | Time patterns |
| Milestone | `diveCountMilestone` | career count crossed 50, 100, 150, 200, 250, 300, 400, 500, then every 250, recently | milestone number | the dive that crossed it |
| Milestone | `diveHoursMilestone` | career hours crossed 25, 50, 100, then every 100, recently | milestone number | the dive that crossed it |
| Milestone | `deepestDive` | a new deepest dive, recently | dive id | that dive |
| Milestone | `longestDive` | a new longest dive by runtime, recently | dive id | that dive |
| Milestone | `newCountry` | first dive in a country, recently | country | Geographic |
| Milestone | `newSpecies` | first sightings of one or more species, recently | count + newest species id | Marine life |
| Pattern | `diveGap` | the last dive was 90 days ago or more | last dive id | Dive log |
| Pattern | `favouriteSite` | one site holds 25% or more of the last 12 months' dives, at least 5 dives | site id | that site |
| Pattern | `regularBuddy` | one buddy on 40% or more of the last 12 months' dives, at least 5 dives | buddy id | that buddy |
| Pattern | `busiestMonth` | one calendar month leads in at least 2 calendar years | month | Time patterns |
| Safety | `ascentRate` | last-12-month average ascent rate above 9 m/min over at least 5 profiled dives | whole m/min band | Profile |

Notes:

- The "band" of a trend is `floor(|percent change| / 10)`, so a dismissed
  "RMV 12% lower" returns as "RMV 23% lower" but not as "RMV 14% lower". A
  change of direction always returns.
- Career counts and hours include the diver's prior experience
  (`priorDiveCount`, `priorDiveTimeSeconds`) when set, the way the Overview
  page's career totals do. Without prior experience the sentence says
  "logged". A milestone that the prior count alone accounts for (no logged
  dive crossed it) never fires.
- Milestone rules that need a crossing dive pick the earliest logged dive at
  which the running career total reaches the milestone.
- `deepestDive` and `longestDive` need at least 10 logged dives, so a
  diver's first dives are not each "a new deepest dive".
- `ascentRate` uses the sustained-transit average the Profile page shows
  (`getAscentDescentRates`), scoped to the 12-month window.
- `diveGap` needs at least one logged dive.

### 4.3 Wording

- Trends and patterns state neutral facts: "Over the last 12 months your
  average max depth was 18% deeper than the year before."
- Only RMV uses "improved" and "rose", because lower consumption is better
  on every reading. The sentence says "RMV", the term the Gas page uses for
  the litres-per-minute lane ("SAC" is the pressure lane in this app).
- `ascentRate` states the number and the common guidance, "9 to 10 m/min or
  slower", converted to the diver's depth unit. It never praises a rate
  below the guidance; below the threshold the rule does not fire.
- `diveGap` states the gap only. It does not prescribe a refresher.
- Every sentence is an ICU message with plural forms, translated into all
  11 locales.

### 4.4 Ranking

Order by tier, then by score within the tier:

1. Safety.
2. Milestones, newest crossing dive first.
3. Trends, by effect size (frequency by percent change / 100).
4. Patterns, by share (gap by days / 365).

The strip takes the first three in that order, skipping any observation that
would make a kind appear a third time. The Observations page lists all of
them in the full order.

## 5. Architecture

Compute on read. The rules are pure functions over an inputs snapshot; only
the diver's dismissals and mutes persist.

### 5.1 Domain (`lib/features/insights/domain/observations/`)

| Unit | Purpose |
| --- | --- |
| `observation_rule_id.dart` | `ObservationRuleId` enum with a stable `dbValue` per rule and its `ObservationKind`. |
| `observation.dart` | Entity: rule id, fingerprint, score, typed facts, tap target. `copyWith`. |
| `observation_facts.dart` | Sealed facts classes (trend, milestone, dive record, place, species, gap, share, month, rate) carrying metric values only, no strings. |
| `observation_target.dart` | Sealed tap target: Insights category id, dive id, site id, buddy id, or the dive log. |
| `observation_inputs.dart` | Immutable snapshot: per-dive points with dates, career offsets, first-seen countries and species, buddy and site shares, ascent rates per window, `now`. |
| `observation_thresholds.dart` | Every threshold in section 4 as named constants. |
| `effect_size.dart` | Pooled-SD effect size and period mean helpers. |
| `rules/trend_rules.dart`, `rules/milestone_rules.dart`, `rules/pattern_rules.dart`, `rules/safety_rules.dart` | One function per rule: `Observation? evaluate(ObservationInputs)` (or a list for rules that can fire more than once). |
| `observation_engine.dart` | Runs every non-muted rule, catching and logging a throwing rule so the rest survive, then drops dismissed fingerprints and ranks. |
| `observation_ranker.dart` | Section 4.4 ordering and strip selection. |

### 5.2 Data (`lib/features/insights/data/`)

- `observation_inputs_loader.dart`: builds `ObservationInputs` for the
  current diver from `InsightsRepository` (and the diver for prior
  experience) with an empty `DiveFilterState`. New repository queries are
  added only where no existing one returns the data. Per-dive rows (date,
  max depth, effective runtime, weight, site and country) and per-dive
  buddies come from a new `observation_inputs_queries.dart`, so the
  3,000-line repository does not grow. RMV per dive reuses
  `getSacVolumePerDive`, ascent rates reuse `getAscentDescentRates` with a
  date-range filter per window, and species first sightings reuse
  `SeenSpeciesRepository.getSeenSpecies`.
- `repositories/observation_dismissals_repository.dart`: `dismiss`,
  `undismiss` (for Undo), `watchDismissedKeys(diverId)`; marks rows pending
  for sync.

### 5.3 Storage (schema 265)

One rung, following the split layout (tables in
`lib/core/database/tables/`, the rung in `migrations/`):

- New synced table `insight_observation_dismissals`: `id`, `diver_id` (FK
  to divers, cascade), `rule_id`, `fingerprint`, `dismissed_at` (nullable),
  `created_at`, `updated_at`, `hlc`. Modelled on `saved_queries` (a
  diver-scoped synced table with its own clock).
- The id is deterministic: `od_` plus the SHA-1 of
  `diverId|ruleId|fingerprint`, the way condition findings derive theirs.
  Two devices that dismiss the same observation write the same row, so sync
  merges it with a plain upsert (last writer wins on `updated_at`) and no
  unique key or rival-row reconciliation is needed. That also keeps diver
  merge safe: it repoints `diver_id` on every diver-owned table, and a
  repointed row can at worst duplicate a dismissal, which is harmless.
- Dismiss sets `dismissed_at`; Undo sets it back to null. Rows are never
  deleted by the feature, so no tombstone can race a later re-dismissal.
  Deleting a diver removes their rows (cascade, plus a delete step that
  tombstones them).
- New nullable column `diver_settings.insights_muted_observation_rules`: a
  JSON list of `ObservationRuleId.dbValue`. Null means none muted. Synced
  with the rest of diver settings. No existing row is rewritten.

An unknown rule id in either place (written by a newer build) is ignored on
read and preserved on write.

### 5.4 Presentation (`lib/features/insights/presentation/`)

- `providers/observations_providers.dart`: `observationsProvider` (ranked
  list for the current diver) refreshes on `watchInsightsChanges`, dive
  detail changes, dismissal changes, mute changes and diver switch.
  `observationStripProvider` selects the top 3.
- `formatters/observation_sentence.dart`: facts to a localized sentence
  using the unit formatter and settings.
- `widgets/observation_card.dart`: sentence, kind icon, tap to target,
  overflow with "Dismiss" and "Don't show this kind". Dismiss shows a
  snackbar with Undo.
- `widgets/observations_strip.dart`: header "Observations", up to three
  cards, "See all", and the filter note under an active filter. Renders
  nothing when empty; a card error with Retry on load failure.
- `pages/insights_observations_page.dart`: every observation, the filter
  note, an empty state ("Observations appear as your log grows"), and an
  app-bar overflow "Muted kinds" opening a sheet that lists muted rules with
  Unmute.
- Placement: the strip is added above the category list in
  `InsightsMobileContent` and at the top of `InsightsOverviewPage` when it is
  the desktop summary. The Observations page is master-detail id
  `observations` and route `/insights/observations`. "See all" selects the
  detail on desktop and pushes the route on phones. It is not added to the
  category list; the strip is its entry point.

## 6. Errors

- A throwing rule is logged and dropped; the others still show.
- An inputs load failure shows a card error with Retry, as Insights does
  since #2429, rather than an empty strip.
- A dismissal write failure shows a snackbar and leaves the observation
  visible.

## 7. Testing

- Rule unit tests: each rule's firing case, each threshold boundary (just
  below, at), the effect-size gate, sample minimums, fingerprint stability
  and band changes, prior-experience handling, unit-independent facts.
- Engine and ranker tests: mute filtering, dismissal filtering, a throwing
  rule, tier order, the two-per-kind strip cap, ties broken deterministically
  by rule id.
- Loader test against an in-memory database: the snapshot matches seeded
  dives and ignores the view filter and excluded dives.
- Migration test for rung 265 (renumbered while open: 261, 263 and 264 landed first, and #2991 holds 262); sync round-trip for dismissals and the mute
  column; diver delete removes dismissals.
- Widget tests: strip on phone and desktop, empty strip takes no space,
  dismiss with Undo, mute and unmute, filter note, page empty state, error
  card with Retry, sentences in metric and imperial.
- `test/architecture/` after adding the new `lib/` files.

## 8. Out of scope

- The phase 2 landing redesign (findings and trends leading the page,
  equipment and data-quality findings on the landing).
- Notifications or home-dashboard cards for observations.
- Observations that follow the Insights filter.
- User-tunable thresholds.
- Any rule beyond section 4.2.

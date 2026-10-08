# Home Page Redesign — Design

Date: 2026-07-24
Status: Approved (brainstorming session with visual companion)

## Problem

The Home tab (`lib/features/dashboard/presentation/pages/dashboard_page.dart`) is
the only page in the app with no responsive strategy. It renders a single
full-width scrolling column with no max-width, no breakpoints, and no grid, so
on desktop the cards stretch edge-to-edge with large empty regions between
sparse content. On phone it is acceptable, but the design should be one system
that reflows, not two experiences.

## Goals and decisions

Decisions made during brainstorming, in order:

1. **Scope: full rethink.** Reconsider the page's purpose, content, and layout
   together — not just a reflow of existing cards.
2. **Primary job: monitor-first, balanced mix.** The page leads with status
   (what needs attention), supported by reflect (recent diving life) and act
   (shortcuts to next actions).
3. **All-clear state: always-on gauges.** Monitor elements always display real
   values (service clock months remaining, no-fly 0:00, days since last dive)
   rather than appearing only when something is wrong. Green is quiet but
   present; the page never empties out just because everything is fine.
4. **Hero: keep the big animated ocean banner** (`HeroHeader` +
   `OceanBackground`), full width, with the app logo added on the left.
5. **Desktop arrangement: responsive card grid** (not a centered capped column,
   not a sidebar split). Cards reflow into 2–3 columns at desktop widths using
   the existing `ResponsiveBreakpoints`; phone stacks the same blocks in the
   same order in one column.
6. **Content: all five new reflect/act blocks accepted** — milestones,
   on-this-day, photo ribbon, recent-sites mini map, year-in-review — plus the
   carried-over blocks. **Personal Records is removed from Home** (remains in
   Statistics).
7. **Hero middle (desktop): quiet-column lifetime stats.** Dives, hours
   underwater, deepest, sites, countries — regular weight, ~85% opacity, tiny
   letter-spaced labels, hairline translucent dividers. Deliberately subdued;
   the greeting stays dominant. Below 800 px the hero collapses to the current
   phone layout (one-line stats under the greeting).

## Page structure

Ordered block list (drives BOTH form factors):

| # | Block | Span at 3 cols | Conditional? |
|---|-------|----------------|--------------|
| 1 | Hero (ocean banner, logo, greeting, quiet stats) | full | always |
| 2 | Gauge strip (always-on status chips) | full | always |
| 3 | Urgent banner row (overdue/expired only) | full | conditional |
| 4 | Pre-dive checklist card (existing) | full | conditional |
| 5 | Recent dives (3 rows, mini profiles) | 2/3 | always (CTA when empty) |
| 6 | Quick actions | 1/3 (stacked right) | always |
| 7 | Milestones | 1/3 (stacked right) | conditional |
| 8 | Photo ribbon | full | conditional |
| 9 | On this day | 1/3 | conditional |
| 10 | This year (year-in-review) | 1/3 | conditional |
| 11 | Course progress (existing) | 1/3 | conditional |
| 12 | Recent sites map | full | conditional |

Column count via `ResponsiveBreakpoints`
(`lib/shared/widgets/master_detail/responsive_breakpoints.dart`): 1 column
< 800, 2 columns 800–1199, 3 columns >= 1200. Blocks pack greedily in order;
at 1 column every block is full-width — that IS the phone layout. Conditional
blocks contribute nothing when empty and the grid backfills.

Packing rules, precisely:

- Blocks 5–7 (recent dives + quick actions + milestones) form a **row group**
  at >= 2 columns: recent dives on the left, the following `third` blocks
  stacked vertically in the remaining column (`IntrinsicHeight` row, like the
  current page's bottom row). At 1 column the group dissolves into the plain
  ordered stack.
- At 3 columns: `full` spans 3, `twoThirds` spans 2, `third` spans 1;
  consecutive `third` blocks share a row.
- At 2 columns: `full` spans 2; in the row group, recent dives takes one
  column and the side stack the other; standalone `third` blocks flow 2-up;
  a leftover odd `third` spans the full row.

## Component architecture

New:

- **`DashboardGrid`** — shared layout widget taking an ordered list of
  `DashboardBlock` entries (widget builder + span hint: `full`, `twoThirds`,
  `third`). `LayoutBuilder` + `ResponsiveBreakpoints` choose column count;
  greedy row packing; null builders skipped.
- **`GaugeStrip`** — replaces `ActivityStatsBar`, `AlertsCard`, and
  `ServiceDueCard`. Always-on chips: worst gear-service clock per category,
  insurance validity, no-fly time, days since last dive. Neutral when fine,
  amber when due soon, red when overdue. A separate compact banner row (block
  3) appears only for genuinely urgent items (overdue service, expired
  insurance) — same data, so no duplicate logic: one widget owns status
  display priority.
- **`MilestonesCard`** — next round-number dive milestone ("3 dives to #250")
  and upcoming certification anniversaries.
- **`PhotoRibbonCard`** — horizontal ribbon of newest dive photos.
- **`OnThisDayCard`** — dives from this month/day in prior years.
- **`YearInReviewCard`** — this year vs last year: dives, hours, max depth.
- **`RecentSitesMapCard`** — small map with pins for sites of the last ~10
  dives.

Modified:

- **`HeroHeader`** — keeps `OceanBackground` animation. Adds app logo (left),
  greeting + date beside it; at >= 800 px, quiet-column stats centered (dives,
  hours, deepest, sites, countries). Below 800 px, current phone layout.
- **`RecentDivesCard`** — widened to 2/3 span on desktop; empty state becomes a
  "Log your first dive" call to action.
- **`DashboardPage`** — becomes hero + `DashboardGrid` over the block list;
  pull-to-refresh invalidates the full provider set (existing pattern).

Removed:

- `PersonalRecordsCard`, `personalRecordsProvider` (records remain in the
  Statistics feature).
- `ActivityStatsBar`, `AlertsCard`, `ServiceDueCard` (folded into
  `GaugeStrip` + urgent banner row).

## Data / providers

All new providers live in
`lib/features/dashboard/presentation/providers/dashboard_providers.dart`,
following its existing self-invalidating, SQL-bounded patterns. No schema
changes; everything derives from existing tables. Read-only; no sync impact.

- `milestonesProvider` — dive count -> next milestone; certification
  anniversaries from the certifications repository.
- `onThisDayProvider` — dives matching today's month/day from prior years
  (SQL-bounded like `recentDivesProvider`).
- `recentPhotosProvider` — newest 12 photos from the media tables (the ribbon
  shows as many as fit its width and scrolls horizontally for the rest).
- `yearInReviewProvider` — current-year vs previous-year aggregates.
- `recentSitesProvider` — GPS-bearing sites from the last ~10 dives.
- `dashboardQuickStatsProvider` — extended with site and country counts for the
  hero stats.

Reused unchanged: `recentDivesProvider`, `dashboardDiverProvider`,
`daysSinceLastDiveProvider`, `dashboardAlertsProvider` (reshaped consumption),
`activeEquipmentClocksProvider`, `dueClocksProvider`,
`activeCoursesProgressProvider`, `settingsProvider`.

All displayed values respect the active diver's unit settings.

## Empty states

Two per-block policies:

- **Always-on** (hero, gauge strip, quick actions): render regardless of data.
  A gauge with nothing to measure (no gear registered) shows a quiet "Add
  gear" chip rather than disappearing.
- **Hide-when-empty** (milestones, photo ribbon, on-this-day, year-in-review,
  course progress, sites map, pre-dive checklist, urgent banner): return null;
  grid backfills.

Exception: `RecentDivesCard` never hides — with zero dives it shows a "Log
your first dive" CTA, so a brand-new user sees a coherent welcome page (hero +
gauges + CTA + quick actions) instead of a void.

## Error handling

Per-card `AsyncValue` containment: loading renders the card frame with a
subtle placeholder (no layout jump); errors render a compact retry affordance
inside the card. One failing provider never blanks the page. Refreshes keep
previous values visible while reloading (`AsyncValue.value` pattern) to avoid
flicker.

## Testing

- **Provider unit tests** (in-memory Drift): on-this-day month/day matching
  across years including Feb 29; milestone arithmetic; year aggregates; gauge
  threshold math (ok/amber/red boundaries).
- **Widget tests** per card: empty, populated, and warning states;
  `GaugeStrip` color thresholds; `HeroHeader` collapse below 800 px.
- **`DashboardGrid` tests**: span packing at 1/2/3 columns, conditional-block
  backfill, order preservation.
- **Full-suite run** in the plan: new provider dependencies in shared widgets
  can break other features' widget tests without `flutter analyze` noticing.
- All new user-facing strings added to l10n for all 10 non-English locales,
  with regeneration; `dart format .` before commit.

## Out of scope

- Personal records UI anywhere outside Statistics.
- Changes to the ocean animation itself.
- Navigation, routing, or nav-rail changes.
- Any database schema or sync changes.

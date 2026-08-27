# Statistics Overview Page — Design Spec

**Issue:** [#167 — Add basic summary statistics to statistics page](https://github.com/submersion-app/submersion/issues/167)
**Date:** 2026-04-15
**Status:** Approved design, ready for implementation planning

## Problem

In non-master-detail (phone, <1100px) mode, Submersion exposes no equivalent to the desktop Statistics Overview or Dive Log Summary pages. A phone user who opens the Statistics tab sees only a grid of category tiles — they must drill into a specific category before seeing any aggregate numbers. Common "at a glance" metrics such as total dives, total time underwater, deepest dive, and longest dive are not directly reachable.

On desktop (≥1100px), those metrics exist inside `StatisticsSummaryWidget`, shown in the detail pane when no category is selected. That widget mixes aggregate cards with detailed charts that largely duplicate the existing category pages.

## Goals

- Give phone users a top-level Overview view containing basic aggregate metrics and personal records.
- Unify the phone Overview with the desktop "no selection" state so both form factors render the same content.
- Reduce duplication: stop showing charts in the Overview that already exist in category pages, except two distribution pies that serve a specifically cross-cutting "breakdown" role.
- Add two new aggregates divers expect to see: average dives per month and average dives per year (lifetime basis).

## Non-Goals

- Rolling-window averages (last-12-months). Lifetime averaging is canonical; recency trends live in the progression category.
- Quick-action buttons (Log Dive / Import) on the populated Overview. Those actions appear only in the zero-dives empty state.
- Preserving all four charts from the current `StatisticsSummaryWidget`. The dives-by-month bar chart and tag-usage section remain in their existing category pages.
- Customizable Overview layout (user-chosen cards/sections).
- New domain metrics not requested in the issue (certification-level breakdowns, suit-type counts, buddy counts).

## User Experience

### Navigation

A new category tile labeled **"Overview"** (icon `Icons.dashboard_outlined`) is added as the first entry in the Statistics category list/grid. A subtle divider is rendered between the Overview tile and the first domain category (gas), to signal the Overview is structurally distinct from the 9 domain categories (gas, progression, conditions, social, geographic, marine-life, time-patterns, equipment, profile).

- **Phone (<1100px):** tapping the Overview tile pushes the full-page `StatisticsOverviewPage` via `context.go('/statistics/overview')`.
- **Desktop (≥1100px):** `MasterDetailScaffold.summaryBuilder` renders `StatisticsOverviewPage(embedded: true)` both when no category is selected and when "Overview" is explicitly selected.

### Page Content (top to bottom)

**1. Aggregate Stats Grid** — responsive grid, 2 columns below 600px width, 4 columns at or above 600px. Each card shows a label and a large value:

| Card | Source | Formatting |
|------|--------|------------|
| Total Dives | `DiveStatistics.totalDives` | Integer |
| Total Time | `DiveStatistics.totalTimeSeconds` | `Xh Ym` |
| Max Depth | `DiveStatistics.maxDepth` | `UnitFormatter.formatDepth()` |
| Avg Depth | `DiveStatistics.avgMaxDepth` | `UnitFormatter.formatDepth()` |
| Dives / Month | `DiveStatistics.divesPerMonth` (new getter) | 1 decimal; hidden when null |
| Dives / Year | `DiveStatistics.divesPerYear` (new getter) | 1 decimal; hidden when null |
| Sites Visited | `DiveStatistics.totalSites` | Integer |
| Avg Water Temp | `DiveStatistics.avgTemperature` | `UnitFormatter.formatTemperature()`; hidden when null |

**2. Distributions** — section titled "Distributions" containing two pie charts. Layout:

- Phone or narrow detail pane (<600px): charts stacked vertically, Depth on top.
- Wider (≥600px): charts side-by-side in a Row.

Charts:

- **Depth Distribution pie** — buckets 0–10m, 10–20m, 20–30m, 30–40m, 40m+ (relabeled to feet for imperial units). Source: `DiveStatistics.depthDistribution`. Legend: bucket label, dive count, percentage.
- **Dive Types pie** — buckets derived from each dive's `diveType` enum (Recreational, Technical, Freediving, etc.). Source: new `diveTypeDistributionProvider` (memoized on `allDivesProvider`). Legend: type label, count, percentage.

Hidden entirely when `totalDives == 0`.

**3. Personal Records** — card titled "Personal Records" with up to 4 tappable `ListTile` rows. Each row shows the record value, the site name, and the date; tapping navigates to that dive's detail page.

- Deepest Dive — depth
- Longest Dive — duration (`Xh Ym`)
- Coldest Dive — water temp (hidden if no temp data on any dive)
- Warmest Dive — water temp (hidden if no temp data on any dive)

With a single dive logged, the section collapses to one row labeled "First Dive" instead of showing the same dive four times.

Source: existing `diveRecordsProvider`.

**4. Most Visited Sites** — card titled "Most Visited Sites" with up to 5 tappable `ListTile` rows (site name + dive count subtitle). Tapping navigates to that site's detail page. Hidden entirely when `DiveStatistics.topSites` is empty (real case: dives logged without a site association).

Source: existing `DiveStatistics.topSites`.

### Edge Cases

- **Zero dives logged:** whole page body is replaced with a centered empty state: dive-mask icon, "No dives logged yet", and two action buttons — "Log a Dive" and "Import Dives". This is the only place quick-action buttons appear.
- **Tenure < 1 month:** Dives/Month and Dives/Year cards are hidden. Everything else renders.
- **Missing water-temp data on all dives:** Avg Water Temp card, Coldest record, Warmest record are hidden independently.
- **Fewer than 5 sites:** Most Visited Sites shows however many exist.
- **Corrupt or future `firstDiveDate`:** if `firstDiveDate` is after `DateTime.now()`, treat as missing and return `null` from the getters (hides both average cards).

## Architecture

### New files

- `lib/features/statistics/presentation/pages/statistics_overview_page.dart` — the page widget, with an `embedded` flag that skips its own `Scaffold` / `AppBar` when rendered inside `MasterDetailScaffold`.
- `lib/features/statistics/presentation/providers/statistics_providers.dart` — new `diveTypeDistributionProvider` and `DiveTypeCount` value type (if the file does not already exist; otherwise add to the existing one).

### Modified files

- `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
  - Extend the aggregate SQL in `getStatistics()` to select `MIN(dive_date_time) as first_dive_date`.
  - Add `firstDiveDate` field to `DiveStatistics`.
  - Add `monthsSinceFirstDive`, `divesPerMonth`, `divesPerYear` getters that return `null` when tenure < 1 month, `firstDiveDate` is null, or `firstDiveDate` is in the future relative to `DateTime.now()`.
- `lib/features/statistics/presentation/pages/statistics_page.dart`
  - Register "overview" as the first entry in the category list with `Icons.dashboard_outlined`, label "Overview", and a divider below it.
  - Change the `MasterDetailScaffold.summaryBuilder` to return `StatisticsOverviewPage(embedded: true)`.
  - Add phone-mode navigation target `/statistics/overview`.
- Router configuration (wherever `/statistics` sub-routes are declared)
  - Add `GoRoute(path: 'overview', builder: (_, __) => const StatisticsOverviewPage())`.

### Deleted files

- `lib/features/statistics/presentation/widgets/statistics_summary_widget.dart` — replaced entirely by `StatisticsOverviewPage`. Git history preserves the prior implementation; leaving a deprecated shim invites rot.

## Data Flow

```text
StatisticsOverviewPage
  ├── watch diveStatisticsProvider     → DiveStatistics (+ firstDiveDate, + getters)
  ├── watch diveRecordsProvider        → DiveRecords
  ├── watch diveTypeDistributionProvider (new) → List<DiveTypeCount>
  ├── currentDiverIdProvider            (implicit, upstream)
  └── settingsProvider via UnitFormatter (for depth/temp formatting)
```

All four providers invalidate automatically when the active diver changes or a dive is added/edited/deleted through existing invalidation plumbing.

### Lifetime averages (computed getters on `DiveStatistics`)

```dart
double? get monthsSinceFirstDive {
  if (firstDiveDate == null) return null;
  if (firstDiveDate!.isAfter(DateTime.now())) return null;
  final diff = DateTime.now().difference(firstDiveDate!).inDays / 30.44;
  return diff < 1 ? null : diff;
}

double? get divesPerMonth {
  final m = monthsSinceFirstDive;
  return m == null ? null : totalDives / m;
}

double? get divesPerYear {
  final m = monthsSinceFirstDive;
  return m == null ? null : totalDives / (m / 12);
}
```

Rationale for getter-based rather than SQL-computed: `DateTime.now()` is not a SQL concept, and two divisions in Dart are free. Keeps the SQL layer focused on raw aggregates.

### New `diveTypeDistributionProvider`

```dart
final diveTypeDistributionProvider = FutureProvider<List<DiveTypeCount>>((ref) async {
  final dives = await ref.watch(allDivesProvider.future);
  final grouped = <DiveType?, int>{};
  for (final d in dives) {
    grouped[d.diveType] = (grouped[d.diveType] ?? 0) + 1;
  }
  return grouped.entries
      .map((e) => DiveTypeCount(type: e.key, count: e.value))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));
});
```

`DiveTypeCount` is a small value type (`DiveType? type`, `int count`). A `null` type is legal and groups all untagged dives together; the legend renders it as "Unspecified." The implementation must confirm against the actual `Dive.diveType` nullability in the codebase — if the field is non-nullable, the `?` can be dropped.

## Error Handling & Loading

- **Loading (first resolve):** single centered `CircularProgressIndicator`. No skeleton — SQLite queries are typically <100ms.
- **Re-resolve (dive mutation triggers invalidation):** no full-page spinner; each section keeps previous data and updates in place when its provider emits. Avoids visible jumps on routine saves.
- **`diveStatisticsProvider` error:** full-page error card with icon, message "Couldn't load statistics", and a "Try again" button that calls `ref.invalidate(diveStatisticsProvider)`.
- **Per-section errors:** Personal Records or Distributions sections each render an inline error row and leave the rest of the page working. The depth-distribution pie can still render if it came through `diveStatisticsProvider` successfully even when `diveTypeDistributionProvider` failed.
- **Empty state:** guarded on `AsyncValue.data`, never on `loading`, to avoid race-condition flashes.

## Testing Strategy

### Unit tests — `test/features/statistics/`

- `DiveStatistics.divesPerMonth` / `DiveStatistics.divesPerYear`: verify computed values for known tenures (1 year, 5 years, new diver of 3 weeks, diver with `firstDiveDate` in the future, `firstDiveDate == null`).
- Empty-state triggers (zero dives, missing temp data, single dive).
- `diveTypeDistributionProvider`: groups correctly, sorts descending, returns empty list for zero dives.

### Widget tests

- `StatisticsOverviewPage` renders the expected card labels for a fixture `DiveStatistics` with non-null temp and multiple dives.
- Cards hide correctly when corresponding data is missing (temp null, tenure < 1 month, firstDiveDate in future).
- Tapping a Personal Records row invokes the correct `go_router` navigation target.
- Tapping a Most Visited Sites row invokes the correct site-detail navigation target.
- Unit formatting switches correctly when `settingsProvider` toggles metric ↔ imperial (override via a fake settings provider).
- Empty state renders when `totalDives == 0`, and its "Log a Dive" / "Import Dives" buttons navigate correctly.

### Integration test — `integration_test/`

- Navigate to `/statistics`, tap the "Overview" tile, confirm the overview page renders with seeded fixture data.
- Repeat at two MediaQuery sizes — narrow (phone) and wide (tablet master-detail) — to confirm the responsive grid and pie-chart layout both render.

### Coverage target

80% minimum on the new page and the new `DiveStatistics` getters, per `CLAUDE.md`.

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Desktop users lose "Dives by Month" bar chart and tag-usage section from today's summary | Medium | Both remain in the progression category (`/statistics/progression`) and tag filtering in the dive list. Release-notes mention. |
| `MIN(dive_date_time)` returns a corrupt or future date, producing absurd averages | Low | `monthsSinceFirstDive` returns `null` when `firstDiveDate` is in the future or tenure < 1 month. |
| Dive-type distribution provider recomputes on unrelated rebuilds | Low | Backed by `allDivesProvider` caching; widgets use `select()` to avoid listening to the full list. |
| Empty state flashes during loading | Low | Guard empty-state check on `AsyncValue.data`, never on `loading`. |
| Unit-setting change does not re-render depth buckets | Low | `UnitFormatter` watches `settingsProvider`; bucket labels derive from formatted strings. Widget test covers this. |

## Rollout

Single PR, shipped as one change. No feature flag — the scope is small (one new page, one modified page, one SQL field, one deleted widget, one new provider), and rolling back the PR is faster than toggling a flag on read-only display code.

Release-notes entry: "Statistics page now shows an Overview with your aggregate totals and personal records, available on all devices."

## Open Decisions (non-blocking)

- **Icon choice for the Overview tile:** `Icons.dashboard_outlined` proposed. `Icons.insights_outlined` or `Icons.summarize_outlined` are acceptable alternatives. Pickable during implementation.
- **Divider below the Overview tile:** proposed, to visually separate it from the 9 domain categories. Adjustable during implementation review.

## File & Line References (from exploration)

| Concern | File | Lines |
|---------|------|-------|
| Statistics page root | `lib/features/statistics/presentation/pages/statistics_page.dart` | 21–75 |
| Current summary widget (to be deleted) | `lib/features/statistics/presentation/widgets/statistics_summary_widget.dart` | 13–1031 |
| Reference dive summary widget | `lib/features/dive_log/presentation/widgets/dive_summary_widget.dart` | 11–412 |
| `DiveStatistics` class | `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | 3941–3971 |
| `DiveRecords` class | `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | 4035–4053 |
| `getStatistics()` SQL | `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | 1627–1759 |
| `getRecords()` | `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | 1763–1869 |
| `diveStatisticsProvider` | `lib/features/dive_log/presentation/providers/dive_providers.dart` | 167–171 |
| `diveRecordsProvider` | `lib/features/dive_log/presentation/providers/dive_providers.dart` | 174–178 |
| `UnitFormatter` | `lib/core/utils/unit_formatter.dart` | full class |
| `ResponsiveBreakpoints` | `lib/shared/widgets/master_detail/responsive_breakpoints.dart` | 9–48 |
| `MasterDetailScaffold` | `lib/shared/widgets/master_detail/master_detail_scaffold.dart` | 51–162 |

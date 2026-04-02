# Dashboard Revamp Design

## Problem

The current homepage has 7 vertically stacked sections that create excessive scrolling, redundant stat display (Activity Status row and Stats Grid overlap), monotonous visual layout (same card style repeated), and suboptimal information priority ordering.

## Goals

- Reduce sections from 7 to 4, cutting scroll depth by ~50%
- Eliminate stat redundancy by consolidating into the hero
- Add visual variety (two-tier hero, side-by-side bottom row)
- Prioritize recency/activity as the primary information focus
- Keep all existing content -- nothing is lost, just reorganized

## Design

### Section 1: Hero Header (Redesigned)

The hero keeps its animated ocean effects (caustic shimmer, rising bubbles, gradient) and `ClipRRect` with rounded corners. The greeting text is removed. All stats move into the hero.

**Layout:**

```
+---------------------------------------------------+
|  [142]        [87.5]         [Eric Griffin] [Icon] |
|  dives logged  hours underwater                    |
|  ------------------------------------------------- |
|  [12] days since  [3] this month  [28] this year   |
+---------------------------------------------------+
```

**Top-right corner: Diver name + app icon**
- Horizontal `Row`: diver's full name (first + last) at 20px (`titleLarge` with custom size), bold, white, positioned left of the app icon
- App icon: 52x52px `Image.asset`, same as current
- Name uses `ConstrainedBox(maxWidth: 120)` with `overflow: TextOverflow.ellipsis` and `maxLines: 1` so long names degrade gracefully on narrow screens
- Positioned via `Positioned(right: 16, top: 12)` inside the existing `Stack`
- If no diver name is set, show "Diver" as fallback
- Uses `dashboardDiverProvider` for the name (already available)

**Left side: Career totals**
- Two large stat blocks side by side with a vertical divider between them
- Total Dives: value at 36px (custom `TextStyle`, not a theme preset), bold, white. Label "dives logged" at `bodySmall`, white 70% opacity
- Hours Logged: same styling. Label "hours underwater"
- `padding-right` must account for the name+icon width (~190px) to avoid overlap
- Hours display: same `_formatHours` logic as current (< 1hr shows minutes, < 10 shows one decimal, >= 10 rounds)

**Below divider: Activity stats**
- Thin horizontal divider: `Container` height 1px, white 10% opacity
- Three inline stat pairs in a `Row` with `MainAxisAlignment.start` and ~16px gaps
- Each pair: value at `titleMedium` / 16px bold white + label at `labelSmall` white 60% opacity
- Stats: Days Since Last Dive | Dives This Month | Dives This Year (YTD)
- Uses existing providers: `daysSinceLastDiveProvider`, `monthlyDiveCountProvider`, `yearToDateDiveCountProvider`

**Responsive behavior:**
- Phone (<600px): Career stats and activity stats may wrap if needed. Name truncates via ellipsis.
- Tablet/desktop (>=600px): More breathing room, all elements fit comfortably.

**What is removed from the hero:**
- `_getGreeting()` method and all greeting text
- The `_buildHeadlineStats()` method (redundant with the new stat display)

### Section 2: Alerts Banner (Compact)

Replaces the full `AlertsCard` with a slim single-line banner.

**Layout:**

```
+---------------------------------------------------+
| [!] Regulator service overdue              [2] [>] |
+---------------------------------------------------+
```

- Single `Container` row: warning icon + text + badge count + chevron
- Background: `errorContainer` at 30% opacity with 1px border (same colors as current)
- Height: ~40px (down from ~100px+ current)
- Text shows the first alert from the existing provider list (insurance alerts appear first, then equipment -- same order as current)
- Badge shows total alert count
- Tappable: if only one alert, navigates directly to its target (equipment detail or settings). If multiple alerts, navigates to settings page where all alerts are actionable.
- Still conditionally hidden via `SizedBox.shrink()` when no alerts exist
- Border radius: 10px

### Section 3: Recent Dives (Unchanged)

No changes to the `RecentDivesCard` widget itself. It moves up in the layout from position 5 to position 2 (below alerts).

- Same `recentDivesProvider` (last 5 dives)
- Same `DiveListTile` format with profile sparklines, color coding, etc.
- Same header row with "Recent Dives" title + "View All" link
- Same empty state with "Log your first dive" button

### Section 4: Bottom Row (Records + Quick Actions Side by Side)

Two cards in a `Row` with `Expanded` children, separated by 8px gap.

**Left card: Personal Records**

```
+------------------------+
| [trophy] Records       |
| Deepest        42.1m   |
| Longest        68min   |
| Coldest        4C      |
| Warmest        29C     |
+------------------------+
```

- Card with 12px padding, rounded corners
- Header: trophy icon + "Records" text at `bodyMedium` bold
- 4 records in a `Column`: each is a `Row` with label (left, `bodySmall`, muted) and value (right, `bodyMedium` bold, colored by category)
- Colors: Deepest=indigo, Longest=teal, Coldest=blue, Warmest=orange (same as current)
- Each record row is tappable, navigates to that dive's detail page
- Uses existing `personalRecordsProvider`
- Site name subtitle dropped (accessible from dive detail)
- Hidden via `SizedBox.shrink()` when no records exist (if hidden, Quick Actions takes full width)

**Right card: Quick Actions**

```
+------------------------+
| Quick Actions          |
| [====Log Dive====]     |
| [----Plan Dive----]    |
| [....Statistics.....]  |
+------------------------+
```

- Card with 12px padding, rounded corners
- Header: "Quick Actions" at `bodyMedium` bold
- 3 buttons stacked vertically with 6px gap:
  - Log Dive: `FilledButton` style (solid primary)
  - Plan Dive: `FilledButton.tonal` style
  - Statistics: `OutlinedButton` style
- "Add Site" button removed (accessible from Sites tab)
- Buttons navigate to same routes as current

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/dashboard/presentation/pages/dashboard_page.dart` | Rebuild page layout: 4 sections instead of 7. Remove `_buildStatsSection`, `_buildStatsGrid`, `_buildStatsGridLoading`, `_buildStatsGridError`, `_formatHours`. Remove `StatSummaryCard` and `ActivityStatusRow` imports. |
| `lib/features/dashboard/presentation/widgets/hero_header.dart` | Major rewrite: remove greeting, add career stats + activity stats bar + name/icon layout. Keep ocean animation. Add providers for activity stats. |
| `lib/features/dashboard/presentation/widgets/alerts_card.dart` | Rewrite as compact single-line banner. Keep `DashboardAlerts` data class and provider. Simplify `_AlertsCardContent`. May keep `_EquipmentAlertTile` for navigation targets. |
| `lib/features/dashboard/presentation/widgets/personal_records_card.dart` | Restyle from `Wrap` chips to compact vertical list in a card. Remove `_RecordChip` widget. Remove site name subtitle. |
| `lib/features/dashboard/presentation/widgets/quick_actions_card.dart` | Restyle from wrapped buttons to vertical stack. Remove "Add Site" button. Remove card wrapper (parent Row provides the card). |

## Files to Delete (or stop importing)

| File | Reason |
|------|--------|
| `lib/features/dashboard/presentation/widgets/activity_status_row.dart` | Stats merged into hero. Widget no longer used. |
| `lib/features/dashboard/presentation/widgets/stat_summary_card.dart` | Stats merged into hero. Widget no longer used. |
| `lib/features/dashboard/presentation/widgets/quick_stats_row.dart` | Already unused in dashboard page. Can be deleted. |

## Providers (No Changes)

All existing providers remain unchanged:
- `diveStatisticsProvider` (total dives, hours, max depth, sites)
- `daysSinceLastDiveProvider`
- `monthlyDiveCountProvider`
- `yearToDateDiveCountProvider`
- `dashboardAlertsProvider`
- `recentDivesProvider`
- `personalRecordsProvider`
- `dashboardDiverProvider` (used for name)

## Stats Kept vs Dropped

| Stat | Status | Location |
|------|--------|----------|
| Total Dives | Kept | Hero career stats (large) |
| Hours Logged | Kept | Hero career stats (large) |
| Days Since Last Dive | Kept | Hero activity row |
| Dives This Month | Kept | Hero activity row |
| Dives This Year (YTD) | Kept | Hero activity row |
| Max Depth | Dropped from dashboard | Available in Statistics page + Personal Records |
| Sites Visited | Dropped from dashboard | Available in Statistics page |

## Testing

- Existing dashboard widget tests will need updating to reflect the new layout
- Verify hero renders correctly with: no diver, short name, long name
- Verify hero renders with: 0 dives, 1 dive, many dives
- Verify alerts banner: 0 alerts (hidden), 1 alert, multiple alerts
- Verify bottom row: no records (Quick Actions takes full width), all records present
- Verify responsive behavior at 375px, 600px, and 1024px widths
- Verify all navigation targets still work (dive detail, equipment detail, settings, etc.)

## Localization

All existing localization keys remain valid. New keys needed:
- `dashboard_hero_divesLogged` (label for career stat)
- `dashboard_hero_hoursUnderwaterLabel` (label for career stat)
- `dashboard_hero_daysSinceLastDive` (activity row label)
- `dashboard_hero_thisMonth` (activity row label)
- `dashboard_hero_thisYear` (activity row label)

Removed keys (can be cleaned up):
- `dashboard_greeting_morning`, `dashboard_greeting_afternoon`, `dashboard_greeting_evening`
- `dashboard_greeting_withName`, `dashboard_greeting_withoutName`
- `dashboard_stats_totalDives`, `dashboard_stats_hoursLogged`, `dashboard_stats_maxDepth`, `dashboard_stats_sitesVisited`

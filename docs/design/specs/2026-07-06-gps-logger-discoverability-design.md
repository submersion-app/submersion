# GPS Logger Discoverability - Design

**Date:** 2026-07-06
**Depends on:** GPS track logging (PR #497, branch `worktree-gps-track-logging`)
**Status:** Approved design, pending implementation plan

## Problem

The GPS Logger shipped as the last tile in the Planning tools list, where
divers will not find it: Planning is the wrong conceptual home for a
data-capture feature (validated with user), the tile sits below the fold,
and once recording starts nothing outside the logger page shows a session
is active. Two discoverability problems to solve (moment-of-use nudges were
considered and explicitly deferred):

1. **Findability** - users never encounter the feature in navigation.
2. **State visibility** - an active recording is invisible in-app.

## Design

### 1. Navigation: "GPS Log" becomes a top-level section

- New route `/gps-log` (name `gpsLog`) registered directly under the
  `MainScaffold` ShellRoute in `app_router.dart`, rendering the existing
  `GpsLoggerPage` unchanged.
- GoRouter redirect from `/planning/gps-logger` to `/gps-log` so stale
  deep links keep working. Internal references (the match-result snackbar
  navigation and any tests) are updated to the new path.
- New destination in `MainScaffold`'s destination model:
  - Mobile: appears in the "More" overflow sheet with icon
    `Icons.gps_fixed`, title from new `nav_gpsLog` l10n key, subtitle
    reusing `tools_gpsLogger_subtitle` ("Record a surface track").
  - Desktop: appears in the navigation rail below existing sections.
  - Selection highlighting keys off the `/gps-log` route prefix, matching
    existing destinations.
- Removals:
  - Planning hub tile (`planning_page.dart`).
  - Planning desktop sidebar item (`planning_shell.dart`).
  - GPS Logger card in the dead `ToolsPage` (reverts that file to its
    state on main).
  - The nested `gps-logger` route under `/planning` (replaced by the
    redirect).
- New l10n: `nav_gpsLog` in all 11 locales; regenerate localizations.

### 2. Dashboard Quick Action

Fourth action in the dashboard's existing Quick Actions card
(`quick_actions_card.dart`): `OutlinedButton.icon` with `Icons.gps_fixed`
and the existing `tools_gpsLogger_title` string, navigating to `/gps-log`.
Matches the card's current visual style. Shown on all platforms (desktop
manages synced tracks and runs the match sweep). No live state in the
button; the card stays a plain layout widget with no providers.

### 3. Recording status strip

- New widget `GpsRecordingStrip` (`ConsumerWidget`) in
  `lib/features/gps_log/presentation/widgets/`.
- Watches the existing `gpsRecorderStateProvider`, falling back to
  `recorder.state` before the stream's first event (same pattern as
  `GpsLoggerPage`).
- Idle: renders `SizedBox.shrink()`. Recording: slim full-width bar with a
  red dot, "Recording GPS track · N points" (new l10n key with ICU plural
  forms, all 11 locales), and a chevron. Tapping navigates to `/gps-log`.
- Placement: `MainScaffold` wraps its `child` in a `Column` (content
  expanded, strip at bottom) in both layouts. Phones: strip sits directly
  above the bottom nav bar. Rail layouts: strip sits at the bottom of the
  content area. No platform gating - the strip renders purely from
  recorder state, which never reaches `recording` on desktop. This keeps
  the strip working on wide-screen iPads, which use the rail layout but
  can record.
- Live point count updates from the same state stream the logger page
  uses: one provider, two consumers, no new plumbing.
- Lifecycle: `gpsTrackRecorderProvider` is a keepalive singleton, so an
  app-wide watcher adds no risk. After a force-kill the fresh recorder is
  idle and the strip is correctly hidden; the logger page's existing
  orphan-recovery notice covers the interrupted-track case.

## Error handling

Nothing new. The strip is display-and-navigate only (no start/stop
controls), the redirect covers stale links, and all recording error paths
remain on the logger page.

## Testing

- `GpsRecordingStrip` widget tests: hidden when idle; visible with correct
  pluralized count when recording; tap navigates. Fake recorder via the
  provider-override pattern from `gps_logger_page_test.dart` (note the
  `tester.runAsync` requirement for post-pump drift calls).
- `MainScaffold` test: strip region present above the bottom nav while
  recording, absent when idle.
- Router test: `/planning/gps-logger` redirects to `/gps-log`.
- Planning page test: GPS Logger assertion removed; equivalent assertion
  added for the More-sheet destination list.
- l10n: new keys translated in all locales, `flutter gen-l10n` output
  committed, whole-project analyze clean.

## Out of scope (deferred)

- Moment-of-use nudges (post-import "these dives had no GPS" education,
  dive-day prompts).
- Live start/stop controls on the dashboard (Approach B, rejected in
  favor of one control surface).
- Any change to the logger page itself.

## Build target

Lands as additional commits on `worktree-gps-track-logging` (PR #497): the
work depends on unmerged #497 code, and making the feature discoverable is
part of shipping it.

## Key integration points

| Concern | Location |
| --- | --- |
| Shell + destinations + strip placement | `lib/shared/widgets/main_scaffold.dart` |
| Route + redirect | `lib/core/router/app_router.dart` |
| Quick Actions card | `lib/features/dashboard/presentation/widgets/quick_actions_card.dart` |
| Planning removals | `lib/features/planning/presentation/pages/planning_page.dart`, `lib/features/planning/presentation/widgets/planning_shell.dart` |
| Recorder state provider | `lib/features/gps_log/presentation/providers/gps_log_providers.dart` |
| Match snackbar navigation | `lib/features/gps_log/presentation/pages/gps_logger_page.dart` |

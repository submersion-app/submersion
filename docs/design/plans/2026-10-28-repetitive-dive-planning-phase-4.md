# Repetitive dive planning, phase 4: implementation plan

Issue: #3565. Spec:
[../specs/2026-10-27-repetitive-dive-planning-design.md](../specs/2026-10-27-repetitive-dive-planning-design.md).

Phase 4 builds on phase 1 directly; phases 2 and 3 are not needed for it.

1. **Follow apart from replan.** The series holds the follow
   (`PlanSeries.follow`, a `SeriesFollow`) in memory. `sourceDiveId` is left
   to "Replan this dive" alone, so its compare strip and overlay, and the
   reset when the planner closes, no longer fire for a followed dive. The
   editor's `setFollowedDive`/`clearFollowedDive` go.
2. **Domain.** `loggedDiveChain` (the followed dive back to the first
   48-hour gap, planned and later dives left out), `followSurfaceInterval`,
   `followedTankPressures` (logged end pressures matched by gas), the first
   dive's carry in `carriedState`, logged OTU in the rolling 24-hour total,
   and the `followDive`/`unfollow` edits, with Fill on a followed first dive
   and removal of the first dive. Tests: `logged_dive_chain_test.dart`,
   `plan_series_follow_test.dart`.
3. **Providers.** `seriesFollowProvider` (chain, OTU per dive, end tissues,
   CNS and tanks from the dive log's analysis), `followLoggedDive`,
   `followSuggestionProvider`, the dismissed prompts, and the viewed logged
   dive. The series notifier's `followDive`/`unfollow`. Tests:
   `plan_series_notifier_test.dart`.
4. **UI.** Logged dives in the series bar; `PlanLoggedDiveView` in place of
   the planner; `PlanFollowPrompt` under the bar; the Follow sheet offers
   every logged dive and the Following chip is gone; "Plan repetitive dive"
   after "Replan this dive" in both dive detail menus.
   Strings in every locale. Tests: `plan_series_follow_ui_test.dart`,
   `follow_dive_test.dart`, `dive_detail_page_test.dart`.
5. **Finish.** This record, screenshots (phone and desktop, light and dark),
   `dart format`.

# Delete a dive plan from the plan canvas

**Date:** 2026-07-22
**Status:** Approved (design)
**Scope:** Additive UI + a thin capture/restore wrapper. No schema change, no migration, no new table.

## Problem

There is no way to delete the dive plan you are currently editing. Deletion
exists in the codebase, but it is only reachable through the saved-plans bottom
sheet (`⋮` overflow menu → "Saved plans" → per-row trash icon). A user sitting
inside an open saved plan (`PlanCanvasPage`) has no in-place delete affordance
and must back out to find it. The `/planning` hub tiles also lack delete, but
that is out of scope for this pass.

Delete must not be confused with the existing **Reset** action: Reset clears the
in-memory working plan back to defaults; Delete removes the persisted
`DivePlans` row (plus its tanks, segments, and equipment junction) and writes
sync tombstones.

## Goal

Give a discoverable, in-place way to delete the plan currently open in the
canvas, matching the app's established **confirm-then-undo** deletion convention
(as used by dives and sites), without stranding the editor on a now-dead
`/planning/dive-planner/:planId` route.

## Non-goals (YAGNI)

- No changes to the `/planning` hub recent-plan tiles (missing-delete gap noted
  as a possible follow-up, not addressed here).
- No changes to the saved-plans sheet, which already has working delete.
- No swipe-to-dismiss; the app convention is confirm + undo, not swipe.

## Design

### 1. Affordance and visibility

- Append a destructive **"Delete plan"** item (menu value `'delete'`) to the
  existing `⋮` `PopupMenuButton` in
  `lib/features/planner/presentation/pages/plan_canvas_page.dart`, placed
  **last, after Reset**.
- Render it visually distinct: `Icons.delete_outline` and the theme error color,
  so it reads as destructive and separate from the neutral items and from Reset.
- **Visible only when the current plan is persisted** — the notifier's current
  plan id appears in `divePlanSummariesProvider`'s loaded value. This covers
  both "opened a saved plan via `:planId`" and "built a new plan and saved it
  this session" (where `widget.planId` is still null but a real record exists).
  If summaries have not loaded yet, fall back to `widget.planId != null`.
- Rationale for the gate: `widget.planId` is only set when a plan is *opened*
  via the `:planId` route. A freshly-saved new plan keeps the `/planning/
  dive-planner` route with no id, so gating purely on `widget.planId != null`
  would wrongly hide Delete for a plan just created this session.

### 2. Interaction flow

1. Tap **Delete plan** → `AlertDialog` with Cancel / **Delete**, the Delete
   action in the error color, naming the plan (e.g. "Delete '<name>'?").
2. On confirm: **capture** the full plan first via `repository.getPlan(id)`
   (returns tanks, segments, equipmentIds) plus its summary numbers
   (`summaryMaxDepth` / `summaryRuntimeSeconds` / `summaryTtsSeconds` from the
   row, as a `PlanSummaryData`), then call `repository.deletePlan(id)`.
3. **Navigate** `context.go('/planning')` to leave the dead `:planId` route and
   land on the hub.
4. Show an **undo SnackBar** ("Plan deleted" / **UNDO**) via a
   `ScaffoldMessenger` reference captured *before* navigating, so it survives the
   route change.

### 3. Restore (undo)

- `deletePlan` is currently one-way. Restore is implemented by **re-saving the
  captured plan**: `repository.savePlan(capturedPlan, summary: capturedSummary)`.
- `savePlan` round-trips the same id, tanks, segments, and equipment junction —
  this is exactly what `duplicatePlan` already relies on — so no new persistence
  code is required, only a captured `domain.DivePlan` + `PlanSummaryData` held in
  the undo closure.
- Undo re-inserts with fresh HLC events that supersede the tombstones written by
  `deletePlan`; this is the same last-writer-wins undo mechanism dives and sites
  already use. The live `divePlanSummariesProvider` re-shows the plan on the hub
  automatically.

### 4. Sync

- `deletePlan` already writes tombstones for the plan, its tanks, and its
  segments, and calls `SyncEventBus.notifyLocalChange()`.
- Undo's `savePlan` writes newer HLC events that win over those tombstones on
  other devices.
- Purely additive: no schema change, no new migration, no new table.

## Files touched

- `lib/features/planner/presentation/pages/plan_canvas_page.dart` — add the
  menu item, the visibility gate, the confirm dialog, capture + delete +
  navigate + undo SnackBar wiring (`_onMenu` `case 'delete'` plus a
  `_deletePlan` helper).
- l10n ARB files — new strings: delete menu label, confirm dialog title/body,
  Cancel/Delete actions, "Plan deleted" SnackBar, UNDO action. Translate all
  non-en locales and regenerate.
- No repository change required (reuse `getPlan` / `deletePlan` / `savePlan`),
  unless a small named `restorePlan` wrapper is preferred for readability — if
  added, it is a thin alias over `savePlan` and needs its own test.

## Testing

- Widget test: overflow menu shows "Delete plan" for a persisted plan and hides
  it for an unsaved one; the confirm dialog gates the delete; after confirm the
  plan is absent from `divePlanSummariesProvider` and the route is `/planning`.
- Restore test: capture → `deletePlan` → `savePlan` restores the plan with
  identical tanks, segments, and equipment ids.
- Reuse the in-memory Drift DB pattern from the existing planner repository
  tests.

## Open questions

- None blocking. Optional: whether to add a named `restorePlan` wrapper vs.
  calling `savePlan` directly from the undo closure — decided at implementation
  time, both are equivalent.

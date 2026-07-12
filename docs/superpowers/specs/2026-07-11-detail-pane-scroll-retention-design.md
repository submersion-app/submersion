# Detail Pane Scroll Retention

**Date:** 2026-07-11
**Status:** Superseded by the 2026-07-12 revision below — the `PageStorageKey`
approach in the body of this doc shipped, then failed manual testing (offset
degraded to 0 after ~3 selections). See "Revision" at the end for the mechanism
that replaced it. The Problem / Root cause / Scope / Semantics sections still
hold; only the mechanism changed.
**Branch/worktree:** `worktree-detail-scroll-retention`

## Problem

In the wide-screen master-detail layout (list on the left, detail on the
right, `>= 800px`), scrolling a detail pane down to a section and then selecting
a different item in the list **resets the detail pane to the top**. This forces
the user to re-scroll to the same section for every item, which defeats the
common workflow of scrolling to a section (e.g. Marine Life, Cylinders) and
quickly comparing that section across several dives/sites/etc.

Desired behavior: when you switch the selected item, the detail pane **keeps its
scroll offset** so the same region stays in view.

## Root cause

`MasterDetailScaffold._DetailPane`
(`lib/shared/widgets/master_detail/master_detail_scaffold.dart`) renders the
detail via an `AnimatedSwitcher` whose child is wrapped in
`KeyedSubtree(key: ValueKey('detail_$selectedId'))`. When `selectedId` changes,
the `ValueKey` changes, so Flutter tears down the old detail element subtree and
builds a brand-new one. The detail page's top-level `SingleChildScrollView`
(e.g. `dive_detail_page.dart`'s `body`) therefore gets a fresh `ScrollPosition`
starting at offset 0.

The per-id `ValueKey` is **intentional**: it isolates each item's local UI
state (active data source, expanded panels, etc.), so it must stay. We need
scroll retention *without* removing that key.

## Approach: `PageStorage` offset retention

Flutter's `Scrollable` automatically saves and restores its scroll offset to the
nearest ancestor `PageStorageBucket`, keyed by the chain of `PageStorageKey`s
between the bucket and the scrollable. Crucially, a plain `ValueKey` is **not** a
`PageStorageKey` and does not participate in that path. So when a detail page's
scroll view carries a **stable** `PageStorageKey`, every item reads and writes
the **same** storage slot — exactly the cross-item retention we want — while
each item still gets a fresh element (no state leakage) and its own
`ScrollController` (so the `AnimatedSwitcher` cross-fade, which briefly mounts
both panes, causes no controller conflict).

### Why the fix is *only* adding keys (spike finding, 2026-07-11)

The real reason the app resets today is that Flutter's
`PageStorageBucket._computeIdentifier` returns `null` when there is **no
`PageStorageKey`** in the scrollable's ancestry, making `writeState` /
`readState` silent no-ops. The current detail scroll views have no key, so their
offset is never persisted.

A spike (`MasterDetailScaffold` in a `GoRouter` at desktop width, dummy detail
items) confirmed the mechanism end-to-end:

- **Tagged** scroll view (`PageStorageKey` present) → offset **retained** across
  selection, using the ambient route-provided `PageStorageBucket` — *with no
  scaffold change at all*.
- **Untagged** scroll view → resets to 0.

Every routed page in Flutter already exposes a `PageStorageBucket` (via
`ModalRoute`), and each section is its own route with a unique key string, so
there is **nothing to isolate** and **no bucket to add** at the scaffold level.
An earlier draft of this design added a scaffold-owned `PageStorageBucket`; the
spike showed it to be redundant, so it was dropped (YAGNI). The scaffold change
is reduced to a single explanatory comment.

### Each in-scope detail page tags its scroll view

Add a constant `PageStorageKey` to the top-level vertical scroll view of each
in-scope detail page. The key string is descriptive and unique per page:

| Page | File | Scroll view | Key |
| ---- | ---- | ----------- | --- |
| Dive | `dive_detail_page.dart` | `body = SingleChildScrollView` | `PageStorageKey('diveDetailScroll')` |
| Site | `dive_sites/.../site_detail_page.dart` | `body = SingleChildScrollView` | `PageStorageKey('siteDetailScroll')` |
| Course | `courses/.../course_detail_page.dart` | `body = SingleChildScrollView` | `PageStorageKey('courseDetailScroll')` |
| Certification | `certifications/.../certification_detail_page.dart` | `body = SingleChildScrollView` | `PageStorageKey('certificationDetailScroll')` |
| Dive center | `dive_centers/.../dive_center_detail_page.dart` | `body = SingleChildScrollView` | `PageStorageKey('diveCenterDetailScroll')` |
| Equipment | `equipment/.../equipment_detail_page.dart` | `body = SingleChildScrollView` | `PageStorageKey('equipmentDetailScroll')` |
| Buddy | `buddies/.../buddy_detail_page.dart` | `body = SingleChildScrollView` | `PageStorageKey('buddyDetailScroll')` |
| Trip | `trips/.../trip_detail_page.dart` | tabbed — each tab's scroll view (`TripOverviewTab` and siblings) | `PageStorageKey('trip<Tab>Scroll')` per tab |

Notes:

- Most pages expose a single `final body = SingleChildScrollView(...)`; adding
  `key:` to that widget is a one-line change and is applied whether or not the
  page is in `embedded` mode (the key sits on the scroll view itself).
- **Trips** is the exception: its detail is a `TabBarView` (`body =
  TripOverviewTab(...)`), so the scroll views live one level deeper inside each
  tab. Tag each tab's own scroll view. Retaining scroll *per trip* is the goal;
  per-tab scroll retention within a trip is a natural side benefit.

## Scope

- **In:** dives, sites, courses, certifications, dive centers, equipment,
  buddies, trips.
- **Out:** statistics, settings, transfer (sectioned/config panes, not
  comparable entity records), and species (reference data). These use
  `MasterDetailScaffold` too but are explicitly excluded.

No opt-out logic is needed for the excluded sections: their detail scroll views
carry no `PageStorageKey`, so `PageStorageBucket` treats them as no-ops and
nothing is saved or restored.

## Semantics & edge cases

- **Pixel offset, clamped.** The restored offset is the raw pixel value,
  clamped by `Scrollable` to the new content's scroll extent. A shorter item
  lands at its own bottom. This matches "I don't have to re-scroll to roughly
  the same place"; true section-anchoring is intentionally out of scope (YAGNI —
  sections are user-reorderable and vary in height per item).
- **Cross-fade preserved.** The existing `AnimatedSwitcher` stays. Each pane
  keeps its own controller; the two panes only share a saved-offset value, so
  the brief double-mount during the fade is safe (both write the same value).
- **Mobile unaffected.** On narrow layouts each detail is its own route with a
  fresh `PageStorageBucket` and no sibling to compare against, so it still opens
  at the top. No regression.
- **Edit/create/summary untouched.** Only the view-mode scroll view is tagged.
  Edit forms and the empty-state summary keep current behavior.
- **Section switching (dives -> sites).** Different routes -> different
  buckets -> independent offsets. No contamination.

## Testing

### Widget test (primary)

New file `test/shared/widgets/master_detail/master_detail_scaffold_scroll_test.dart`,
modeled on the existing `master_detail_scaffold_focus_test.dart` harness
(`GoRouter` + `MediaQuery` at width 1200 to force the desktop layout). Because
the harness supplies its own `detailBuilder`, the test proves the scaffold
wiring without depending on any real detail page:

1. `detailBuilder: (_, id) => SingleChildScrollView(key: const
   PageStorageKey('testDetailScroll'), child: SizedBox(height: 3000, child:
   Text('Detail $id')))`.
2. Render at `/test?selected=1`, scroll the detail pane to a known offset (e.g.
   `drag`/`jumpTo` to 800), `pumpAndSettle`.
3. Drive selection to item 2 (navigate to `/test?selected=2`), `pumpAndSettle`.
4. Assert the detail pane's `ScrollPosition.pixels == 800` (retained).
5. Second case: item 2's content is shorter (e.g. height 400); assert the
   offset **clamps** to `maxScrollExtent` rather than throwing or staying at
   800.
6. Regression guard: assert an untagged detail scroll view (no
   `PageStorageKey`) still resets to 0, documenting that the key is what opts a
   section in.

### Manual verification (run skill, macOS)

Scroll a dive detail to Marine Life / Cylinders, click a different dive in the
list, confirm the pane stays scrolled. Repeat for at least one other in-scope
section (e.g. sites) and confirm an excluded section (settings) still resets.

## Files touched

- 7 single-scroll detail pages (dive, site, course, certification, dive center,
  equipment, buddy) — one `PageStorageKey` each on `body`.
- Trips (3 files) — `trip_overview_tab.dart`, `trip_itinerary_tab.dart`, and the
  three in-page tab builders in `trip_detail_page.dart` (photos, dives,
  checklist) — one `PageStorageKey` per scroll view.
- `lib/shared/widgets/master_detail/master_detail_scaffold.dart` — a single
  explanatory comment near the `ValueKey('detail_$id')` noting that scroll
  retention rides on per-page `PageStorageKey`s (no behavior change).
- `test/shared/widgets/master_detail/master_detail_scaffold_scroll_test.dart` —
  new widget test.

---

## Revision (2026-07-12): PageStorageKey approach replaced with a retainer

The `PageStorageKey` mechanism above shipped but **failed manual testing**: the
detail offset held for a couple of selections, then reset to the top. Root cause
(confirmed against the Flutter SDK and reproduced in a widget test):

- `ScrollPosition.saveScrollOffset()` writes to the shared `PageStorage` slot
  from `didEndScroll()` — i.e. on the end of *any* scroll activity, including the
  involuntary settle when a just-restored offset is **clamped** because the
  detail's content has not finished loading its height yet (real pages are
  `async.when(loading: spinner, data: scrollview)` and their sections — profile
  chart, photos, marine life — keep growing after the scroll view mounts).
- So each restore-into-still-loading content clamped the offset and **saved the
  clamped (smaller) value back** into the shared slot, ratcheting it toward 0
  over successive selections. PageStorage offers no hook to distinguish a user
  scroll from a transient clamp. The original synchronous, single-selection
  widget test never exercised this.

### New mechanism: `DetailScrollRetainer`

`lib/shared/widgets/master_detail/detail_scroll_retainer.dart`:

- The scaffold owns the retained offset (`_detailScrollOffset`, mutated on scroll
  without `setState`) and wraps each view-mode detail in a `DetailScrollRetainer`
  inside the per-id `KeyedSubtree`.
- The retainer creates a **per-detail** `ScrollController(keepScrollOffset:
  false)` — so `PageStorage` never runs and cannot be corrupted — and exposes it
  via a `DetailScrollController` `InheritedWidget`. A per-detail controller means
  the `AnimatedSwitcher` cross-fade (two details briefly mounted) causes no
  controller conflict.
- Each detail page attaches that controller to its primary scroll view with
  `controller: DetailScrollController.maybeOf(context)` (replacing the
  `PageStorageKey`). `InheritedWidget` injection is used rather than
  `PrimaryScrollController` because the latter auto-inherits only on mobile and
  would also be adopted by *nested* vertical scrollables (→ "attached to multiple
  positions" crash); the explicit `controller:` targets exactly one scroll view.
- **Capture:** a `NotificationListener` records the offset from user scrolls only
  (it is inert during the retainer's own restore jumps; content growth does not
  move `pixels`, so it emits no spurious capture).
- **Restore:** a deferred, extent-guarded post-frame loop jumps to
  `min(target, maxScrollExtent)` and re-checks while the content is still growing
  (tolerating brief pauses, hard-capped), so a still-short viewport can never
  clamp-and-corrupt the value.

### Scope change

- **In (retainer):** dives, sites, courses, certifications, dive centers,
  equipment, buddies — each `body` scroll view swaps its `PageStorageKey` for
  `controller: DetailScrollController.maybeOf(context)`.
- **Trips dropped:** its liveaboard layout is a 5-tab `TabBarView` (multiple
  scroll views per detail), which a single injected controller cannot serve
  without per-tab wiring. Trips reverts to no retention (its `PageStorageKey`s
  were removed). A future change could give each trip tab its own retainer.

### Testing (revised)

The widget test now uses content that **grows after the scroll view mounts** and
drives **five sequential selections**, asserting the offset survives — the exact
scenario the shipped approach failed. Plus the clamp case and an opt-out
(no-controller → resets) guard.

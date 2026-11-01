# Alignment Page: Cap the Controls Panel So the Map Stays Visible

**Goal:** On the underwater track alignment page, the map must never be
squeezed to a sliver or pushed off-screen by the controls panel below it,
on any screen size (issue #3994).

**Architecture:** `_AlignPageBody`'s `Column` lays out the map with
`Expanded` and `_ControlsPanel` with its natural (unbounded) height, so a
tall panel just takes however much space it wants and the map gets
whatever is left, down to nothing. The fix wraps the body in a
`LayoutBuilder` and caps the panel in a `ConstrainedBox` at a fraction of
the available height, mirroring the established pattern in
`lib/features/media/presentation/widgets/color_adjust/color_adjust_layout.dart`
(viewer above, adjustment panel below, phone layout): a `LayoutBuilder`
with a `ConstrainedBox(maxHeight: constraints.maxHeight * <fraction>)`
around a `SafeArea`-wrapped `SingleChildScrollView`. Unlike `ListView`,
`SingleChildScrollView` has no `shrinkWrap` parameter at all and does
not need one: with a single child it always sizes itself to that
child's height in the scroll axis, clamped to whatever the incoming
constraints allow. So the `ConstrainedBox` only ever matters when the
panel's natural content height exceeds the cap; a short panel (fewer
start chips, no terrain line) keeps its own smaller size on a tablet or
desktop exactly as it does today.

**Tech Stack:** Flutter, no new packages.

**Cap:** 45% of the body height (`Scaffold.body`'s own height, below the
app bar), the same fraction `color_adjust_layout.dart` uses for the same
viewer-plus-panel shape. The map (`Expanded`) therefore never drops below
55% of that height, regardless of panel content, wherever the cap applies.

**Where it applies:** everywhere except a desktop-width body at least 540px
tall, which shows the whole panel so Save is on screen without scrolling.
Width alone is not enough for that exemption: a phone in landscape is
desktop-width (844 wide) with a body of about 334, shorter than the panel
itself, so an uncapped panel leaves no map and pushes Save off-screen.

**Scope decision:** `color_adjust_layout.dart` also docks its panel into
a side column from the desktop breakpoint instead of capping it. The
issue here is specifically about phone portrait, the alignment page has
no existing desktop-specific layout to extend, and a side dock is a
layout redesign, not a bug fix. This plan applies only the height cap;
Task 1's wide-screen tests confirm that a tall desktop window stays
uncapped and that a wide but short one does not. A side-docked desktop
layout, if wanted later, is a separate, larger follow-up.

## Global Constraints

- No em-dashes anywhere. No mention of any AI tool in commits, code or docs.
- `dart format .` after each task. Stage explicit paths, never a directory.
- No new widget abstraction: this is a two-widget change in
  `nav_track_align_page.dart`, not a shared layout widget. A second caller
  with the same shape would be the time to extract one.

## Review Focus

1. **The map must have a real minimum height on a phone**, not just
   "non-zero": a 1px-tall map is still technically visible but not
   "usable" per the issue. Test asserts a concrete lower bound.
2. **A short panel must not be stretched to the cap.** Regression check:
   a route with no linked dive and no site (fewest start chips) on a
   tablet-sized surface keeps the map at its current, much larger share
   instead of dropping to 55%.
3. **The Save/Cancel row stays reachable** when the panel is scrolling
   internally: a diver must be able to scroll the capped panel and
   still tap Save.
4. **Landscape is capped; a tall desktop window is not.** The cap only
   ever shrinks the panel below its natural size when that natural size
   exceeds 45% of the body height; it never enlarges the panel.

---

### Task 1: Cap the controls panel, phone-overflow test first

**Files:**
- Modify: `lib/features/nav_track/presentation/pages/nav_track_align_page.dart`
- Test: `test/features/nav_track/presentation/pages/nav_track_align_page_test.dart`

**Interfaces:** No new public API; both changed widgets are private
(`_AlignPageBody`, `_ControlsPanel`) to this file.

- [ ] **Step 1: Write the failing phone-layout tests**

Add a new group near the end of the existing test file, following the
`tester.view.physicalSize` pattern already used in
`test/features/import_wizard/presentation/widgets/review_step_phone_layout_test.dart`:

- Give the `LayoutBuilder` added in Step 3 a `ValueKey(
  'nav-track-align-body')` on the `Column` it returns, so tests read the
  true body height straight from that `RenderBox` instead of
  reconstructing it from `kToolbarHeight`/status bar math, which would
  silently drift if the app bar's effective height ever changes.
  Likewise give the `ConstrainedBox` from Step 3 a
  `ValueKey('nav-track-align-controls-panel')`.
- `'the map keeps at least 55% of the body height on a phone-sized
  screen (#3994)'`: `tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);`.
  Pump a route with a linked dive AND a site (so the Start row renders
  its "From dive entry" and "From site" chips) and the pre-dive-fix
  fixture the existing `'the "From GPS" chip...'` tests already build
  (so the GPS chip renders too; all three present at once is the
  widest the Start row gets), through `_pump`. Read `bodyHeight =
  tester.getSize(find.byKey(const ValueKey('nav-track-align-body'))).
  height`. Assert `tester.getSize(find.byType(FlutterMap)).height >=
  bodyHeight * 0.55 - 1` (a 1px slack for rounding).
- `'the controls panel does not exceed 45% of the body height on a
  phone-sized screen (#3994)'`: same pump, assert
  `tester.getSize(find.byKey(const ValueKey(
  'nav-track-align-controls-panel'))).height <= bodyHeight * 0.45 + 1`.
- `'no RenderFlex overflow is reported on the phone-sized screen
  (#3994)'`: same pump, `expect(tester.takeException(), isNull)`, the
  regression check for the "disappears entirely" case, where the
  uncapped panel's natural height could exceed the whole body and clip
  the `Expanded` map to a negative-turned-zero size with a debug
  overflow warning.
- `'a short panel is not stretched to the cap on a wide screen'`:
  `tester.view.physicalSize = const Size(1200, 900); devicePixelRatio =
  1;`. Pump a route with no linked dive, no site, and no pre-dive fix
  (today's narrowest Start row: only the "Place on map" button, no
  chips). Assert the panel's rendered height is well under 45% of the
  body height, e.g. `< bodyHeight * 0.3`, proving the `ConstrainedBox`
  only clamps a panel that actually needs it and does not force a short
  panel up to the cap.
- `'Save is reachable by scrolling when the panel is capped'`: reuse the
  390x844 pump from the first case, `tester.ensureVisible(find.byKey(
  const ValueKey('nav-track-align-save')))`, then tap it and verify
  `repository.lastRouteId` is set, exactly like the existing save test
  but on the capped phone layout.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/nav_track/presentation/pages/nav_track_align_page_test.dart`
Expected: the new cases fail (no cap exists yet, so the map's height is
not bounded below and/or the new `ValueKey` does not exist).

- [ ] **Step 3: Implement the cap**

In `_AlignPageBody.build`, wrap the returned `Scaffold`'s `body: Column(
...)` in a `LayoutBuilder` and compute `maxControlsHeight =
constraints.maxHeight * 0.45`. Give the `Column` itself `key: const
ValueKey('nav-track-align-body')` (purely for the tests above to read
the true body height; no behavior change). Wrap the existing
`_ControlsPanel(...)` in `ConstrainedBox(key: const ValueKey(
'nav-track-align-controls-panel'), constraints: BoxConstraints(
maxHeight: maxControlsHeight))`. Leave the `Expanded(child: Stack(...))`
map untouched.

In `_ControlsPanel.build`, wrap the existing `Padding(...)` (currently
the direct child of the top-level `SafeArea`) in a plain
`SingleChildScrollView(...)` (no `shrinkWrap`: that parameter does not
exist on it), keeping `SafeArea(top: false, ...)` as the outermost
widget so its bottom inset still applies after scrolling.

Add a one-line doc comment on the `ConstrainedBox` pointing at
`color_adjust_layout.dart` as the precedent.

- [ ] **Step 4: Run the new and existing tests**

Run: `flutter test test/features/nav_track/presentation/pages/nav_track_align_page_test.dart`
Expected: all pass, including the full existing suite in that file (over
40 cases) with no change to any of them: this is a pure layout change,
not a behavior change.

- [ ] **Step 5: `flutter analyze`**

Expected: no new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/nav_track/presentation/pages/nav_track_align_page.dart test/features/nav_track/presentation/pages/nav_track_align_page_test.dart
git commit -m "fix(nav-track): keep the alignment map visible under a tall controls panel"
```

### Task 2: Confirm on the real app and screenshots

- [ ] **Step 1: Hot Build**

Run the Windows hot build, open a dive's underwater track alignment
page for a route with a linked dive and a site (widest Start row), at a
narrow window width approximating a phone, and confirm the map stays a
usable size and the panel scrolls to reveal Save/Cancel.

- [ ] **Step 2: Screenshots for the PR**

Phone-width before/after (the bug, then the fix) at minimum; desktop
width after, to show no regression. Follow
`docs/contributing/pull-requests.md#screenshots-for-ui-changes` for the
gist flow.

- [ ] **Step 3: Final whole-file checks**

`dart format .`, `flutter analyze`, then the single test file again.

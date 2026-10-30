# Connections Simpler Starting View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connections opens on Who dives where (buddy and site, only sites
dived with a buddy), every graph carries a caption saying what it is and how
to read a line, and every device is moved onto the new start once.

**Architecture:** The start preset and the "shared with" rule live on
`ConnectionPreset` and are read off the view state; the map loader passes the
rule into the node SQL as an `EXISTS` on the dive. The caption text is a pure
function beside the share caption (which it shares its title with); the
caption widget reports its height so the page can push the existing overlays
and the camera fit down. A one-shot SharedPreferences migration rewrites the
stored view and display before either notifier restores.

**Tech Stack:** Flutter, Riverpod (StateNotifier), Drift custom SQL,
SharedPreferences, ARB l10n (12 locales).

**Spec:** `docs/design/specs/2026-10-25-connections-simpler-default-design.md`
(issue #3679).

## Global Constraints

- No node cap on the opening map: budgets stay 80 compact / 160 wide / 400.
- `minSharedDives` default stays 1; presets, their order, layouts on offer,
  Around mode and saved maps are unchanged.
- Every new string in all 12 ARB files (`ar de en es fr he hu it nl pt zh`
  plus `en`), keys prefixed `connections_caption_`; run `flutter gen-l10n`.
- No em dashes anywhere (code, comments, ARB, commits).
- `dart format .`, `flutter analyze`, the connections tests, and
  `test/architecture/` + `test/shared/` before each commit that adds a `lib/`
  file.

## Review Focus

1. **A diver with no buddies at all** opening the new start: expect the
   `connections_empty_buddies` message, never a field of site dots (Task 5,
   page test).
2. **A saved or edited map with the same kinds as Who dives where**: expect
   every site, solo-only ones included (Task 2, loader test; Task 1,
   `mapSharedWith` is empty unless the unedited preset is applied).
3. **A returning device whose stored view is Around mode on a buddy**: after
   the move it opens in Map mode on Who dives where, and switching to Around
   still finds the same centre, kinds and hops (Task 3).
4. **Large text on a phone**: the caption wraps fully and the insight strip,
   legend and hidden chip sit below it, not under it (Task 5, widget test at
   textScaler 2.0).
5. **The move runs once**: a second provider build after the diver picks
   another preset keeps that preset (Task 3).

---

### Task 1: Start preset and the "shared with" rule in the domain

**Files:**
- Modify: `lib/features/connections/domain/views/connection_presets.dart`
- Modify: `lib/features/connections/domain/views/connections_view_state.dart`
- Test: `test/features/connections/domain/views/connections_view_state_test.dart`,
  `test/features/connections/domain/views/map_spec_test.dart` (only if it pins
  `circle` as the start)

**Interfaces:**
- Produces: `ConnectionPreset.sharedWith` (`Map<ConnectionKind, ConnectionKind>`,
  default `const {}`); the `where` preset has `{site: buddy}`.
- Produces: `ConnectionPresets.startId = 'where'`.
- Produces: `ConnectionsViewState.initial` = Map mode, `where` spec,
  `presetId: 'where'`.
- Produces: `Map<ConnectionKind, ConnectionKind> get mapSharedWith` on
  `ConnectionsViewState`: the applied preset's `sharedWith` when
  `mode == map` and `presetId != null`, else `const {}`.
- Produces: `ConnectionsViewState toStart()` = `applyPreset(start preset)`
  (keeps focus, aroundKinds, hops, highlight; clears saved and edited ids).

- [ ] **Step 1: Write the failing tests**

```dart
test('the page starts on Who dives where in Map mode', () {
  expect(ConnectionsViewState.initial.mode, ConnectionsMode.map);
  expect(ConnectionsViewState.initial.presetId, 'where');
  expect(ConnectionsViewState.initial.mapSpec,
      ConnectionPresets.byId('where')!.spec);
});
test('only the unedited Who dives where preset requires a buddy at a site', () {
  final start = ConnectionsViewState.initial;
  expect(start.mapSharedWith,
      {ConnectionKind.site: ConnectionKind.buddy});
  expect(start.editMap(start.mapSpec).mapSharedWith, isEmpty);
  expect(start.applySavedMap('m1', start.mapSpec).mapSharedWith, isEmpty);
  expect(start.centreOn(NodeRef(ConnectionKind.buddy, 'b')).mapSharedWith,
      isEmpty);
  expect(start.applyPreset(ConnectionPresets.byId('circle')!).mapSharedWith,
      isEmpty);
});
test('toStart keeps Around settings and drops saved and edited ids', () {
  final s = ConnectionsViewState.initial
      .applySavedMap('m1', ConnectionPresets.byId('gear')!.spec)
      .withHops(3)
      .withHighlight(HighlightMode.groups)
      .centreOn(NodeRef(ConnectionKind.buddy, 'b'));
  final t = s.toStart();
  expect(t.mode, ConnectionsMode.map);
  expect(t.presetId, 'where');
  expect(t.savedMapId, isNull);
  expect(t.editedFromPresetId, isNull);
  expect(t.focus, NodeRef(ConnectionKind.buddy, 'b'));
  expect(t.hops, 3);
  expect(t.highlight, HighlightMode.groups);
});
```

Also change any existing expectation that the initial or legacy-fallback
view is `circle` to `where` (legacy lens `circle` still maps to `circle`).

- [ ] **Step 2: Run, expect FAIL** (`initial.presetId` is `circle`,
  `mapSharedWith`/`toStart` undefined)

Run: `flutter test test/features/connections/domain`

- [ ] **Step 3: Implement** the Interfaces above.

- [ ] **Step 4: Run** `flutter test test/features/connections` and fix every
  test that pinned the old start (view provider, view controls, share
  caption/renderer tests that build `initial`). Expected: PASS.

- [ ] **Step 5: Commit** `feat(connections): open on Who dives where`

### Task 2: Sites only where a buddy dived (loader and SQL)

**Files:**
- Modify: `lib/features/connections/data/connections_node_sql.dart`
- Modify: `lib/features/connections/data/connections_reader.dart`
- Modify: `lib/features/connections/data/connections_map_loader.dart`
- Modify: `lib/features/connections/data/repositories/connections_repository.dart`
- Modify: `lib/features/connections/presentation/providers/connections_providers.dart`
- Test: `test/features/connections/data/connections_map_loader_test.dart`,
  `test/features/connections/data/connections_sql_test.dart`

**Interfaces:**
- Consumes: `ConnectionsViewState.mapSharedWith` (Task 1).
- Produces: `buildNodeSql(..., ConnectionKind? sharedWith)` and
  `buildNodeCountSql(..., ConnectionKind? sharedWith)`: when set, adds
  `HAVING MAX(EXISTS (SELECT 1 FROM (${membershipSql(sharedWith)}) sw WHERE sw.dive_id = d.id)) = 1`
  to the inner grouped query, so an entity is kept only if one of its
  in-scope dives also has a `sharedWith` entity. Every one of its dives still
  counts, so a site's dive count matches Show dives. (Revised after the branch
  review; the first draft filtered in WHERE and counted only buddy dives.)
- Produces: `ConnectionsReader.nodes(..., ConnectionKind? sharedWith)` and
  `nodeCount(..., ConnectionKind? sharedWith)`.
- Produces: `MapLoader.load(spec, {..., Map<ConnectionKind, ConnectionKind> sharedWith = const {}})`,
  passing `sharedWith[k]` per kind; `ConnectionsRepository.loadMap` gains the
  same named parameter; `connectionGraphProvider` passes
  `view.mapSharedWith`.

- [ ] **Step 1: Write the failing tests** in the loader test, seeding with
  the existing fixtures: buddy B on dives at site S1 and S2, a solo dive at
  site S3.

```dart
test('sharedWith keeps only sites dived with a buddy', () async {
  final g = await MapLoader(reader).load(_whereMap, diverId: 'me',
      filter: const DiveFilterState(), nodeBudget: 80,
      sharedWith: {ConnectionKind.site: ConnectionKind.buddy});
  expect(g.nodes.map((n) => n.ref.id), containsAll(['S1', 'S2', 'B']));
  expect(g.nodes.map((n) => n.ref.id), isNot(contains('S3')));
  expect(g.hiddenNodeCount, 0);
});
test('without sharedWith the solo site stays as an island', () async {
  final g = await MapLoader(reader).load(_whereMap, diverId: 'me',
      filter: const DiveFilterState(), nodeBudget: 80);
  expect(g.nodes.map((n) => n.ref.id), contains('S3'));
});
test('a log with no buddies gives an empty Who dives where', () async {
  // seed only solo dives at sites
  expect(g.isEmpty, isTrue);
});
```

  And in the SQL test: `buildNodeSql(kind: site, sharedWith: buddy, ...)`
  contains `EXISTS (SELECT 1 FROM (SELECT dive_id, buddy_id AS entity_id FROM dive_buddies) sw WHERE sw.dive_id = d.id)`;
  without `sharedWith` it does not contain `EXISTS`.

- [ ] **Step 2: Run, expect FAIL** (no `sharedWith` parameter).

- [ ] **Step 3: Implement** the Interfaces above.

- [ ] **Step 4: Run** `flutter test test/features/connections/data test/features/connections/presentation/providers test/core/database/dive_stats_scope_census_test.dart`.
  Expected: PASS.

- [ ] **Step 5: Commit** `feat(connections): Who dives where shows only sites dived with a buddy`

### Task 3: Move every device onto the new start once

**Files:**
- Create: `lib/features/connections/presentation/providers/connections_start_reset.dart`
- Modify: `lib/features/connections/presentation/providers/connections_view_provider.dart`
- Modify: `lib/features/connections/presentation/providers/connections_display_provider.dart`
- Test: `test/features/connections/presentation/providers/connections_start_reset_test.dart`

**Interfaces:**
- Consumes: `ConnectionsViewState.toStart()` (Task 1).
- Produces: `const kConnectionsStartResetKey = 'connections_start_reset_3679';`
- Produces: `void resetConnectionsStartOnce(SharedPreferences prefs)`. If the
  marker is set, returns. Otherwise: if a view or legacy lens is stored,
  writes `kConnectionsViewKey` = `ConnectionsViewNotifier.restore(prefs).toStart()`;
  if a display is stored, writes `kConnectionsDisplayKey` with
  `mapLayout: web, view: graph`, every other field kept; then writes the
  marker. Writes are not awaited (SharedPreferences updates its cache at
  once, so a restore right after sees them); a failed write is logged.
- Produces: `ConnectionsViewNotifier.restore` and
  `ConnectionsDisplayNotifier.restore` become public statics (were `_restore`).
- Both providers call `resetConnectionsStartOnce(prefs)` before building
  their notifier.

- [ ] **Step 1: Write the failing tests** (`SharedPreferences.setMockInitialValues`,
  a fresh `ProviderContainer` with `sharedPreferencesProvider` overridden):
  - stored view on `circle` with a saved map id and Around hops 2 and focus
    `buddy:b` gives `connectionsViewProvider` = Map mode, `where`, hops 2,
    focus `buddy:b`, `savedMapId` null.
  - stored display `{mapLayout: circle, view: matrix, labels: all}` gives
    `mapLayout: web`, `view: graph`, `labels: all`.
  - stored legacy lens `gear` only gives the `where` start.
  - nothing stored gives `ConnectionsViewState.initial` and sets the marker.
  - marker set and stored view `travel`: view stays `travel` (the move runs
    once); a second container after `update(applyPreset(gear))` keeps `gear`.

- [ ] **Step 2: Run, expect FAIL** (file missing).

Run: `flutter test test/features/connections/presentation/providers/connections_start_reset_test.dart`

- [ ] **Step 3: Implement** the Interfaces above.

- [ ] **Step 4: Run** `flutter test test/features/connections/presentation/providers test/architecture test/shared`.
  Expected: PASS.

- [ ] **Step 5: Commit** `feat(connections): move every device onto the new start once`

### Task 4: Caption text, shared with the share caption

**Files:**
- Create: `lib/features/connections/presentation/widgets/connections_caption_text.dart`
- Modify: `lib/features/connections/presentation/share/connections_share_caption.dart`
- Modify: `lib/l10n/arb/app_*.arb` (12 files), then `flutter gen-l10n`
- Test: `test/features/connections/presentation/widgets/connections_caption_text_test.dart`

**Interfaces:**
- Produces: `String connectionsMapTitle({required AppLocalizations l10n, required ConnectionsViewState view, required ConnectionGraph graph, required Map<String, String> savedMapNames})`:
  the logic now inline in `ConnectionsShareCaption.of` (Around centre via
  `connections_share_aroundName`, else saved name, preset label, or
  `connections_editor_title`). `ConnectionsShareCaption.of` calls it.
- Produces: `class ConnectionsCaptionText { final String title; final String sentence; }`
  with `static ConnectionsCaptionText of({required AppLocalizations l10n, required ConnectionsViewState view, required ConnectionGraph graph, required EdgeMode edges, required Map<String, String> savedMapNames})`.
  `sentence` = the base sentence, plus `' '` + `connections_caption_thicker`
  unless `edges == EdgeMode.thin`.
- Base sentence: Around mode uses `connections_caption_around(hops)`; Map
  mode with `presetId` uses that preset's key; otherwise (saved, edited,
  custom) `connections_caption_custom`.

ARB keys (en wording; translate the rest, keep each short):

| Key | en |
| --- | --- |
| `connections_caption_circle` | A line joins two buddies who dived together. |
| `connections_caption_where` | A line means you dived at that site with that buddy. |
| `connections_caption_trips` | A line means that buddy was on that trip. |
| `connections_caption_life` | A line means you saw that species at that site. |
| `connections_caption_gear` | A line joins gear used on the same dive. |
| `connections_caption_centers` | A line means you dived with that buddy through that center. |
| `connections_caption_travel` | Buddies, trips and sites; a line means they share dives. |
| `connections_caption_reef` | Sites, marine life and dive types; a line means they share dives. |
| `connections_caption_gearRoad` | Gear, trips and centers; a line means they share dives. |
| `connections_caption_custom` | {kinds}; a line means they share a dive. |
| `connections_caption_kindSeparator` | `, ` (ar `، `, zh `、`) |
| `connections_caption_around` | `{hops, plural, =1{Everything that shares a dive with this centre.} other{Everything within {hops} steps of this centre, linked by shared dives.}}` |
| `connections_caption_thicker` | Thicker lines mean more dives. |

The custom sentence names the map's kinds, in kind order, joined by
`connections_caption_kindSeparator` ("Buddies, Sites; a line means they
share a dive."): on a wide screen the legend is in the panel, not on the
canvas. (Revised after the branch review; the first draft used a fixed
sentence.)

- [ ] **Step 1: Write the failing tests** (`lookupAppLocalizations(const Locale('en'))`):
  - `initial` view, weighted: title `Who dives where`, sentence
    `A line means you dived at that site with that buddy. Thicker lines mean more dives.`
  - same with `EdgeMode.thin`: sentence has no `Thicker`.
  - same with `EdgeMode.selectedOnly`: sentence ends `Thicker lines mean more dives.`
  - edited map: title `Custom map`, sentence starts `A line joins two entries`.
  - saved map `m1` named `Fiji 2024`: title `Fiji 2024`, custom sentence.
  - Around on `buddy:b` labelled `Sam`, hops 1: title from
    `connections_share_aroundName('Sam')`, sentence starts `Everything that shares a dive with this centre.`;
    hops 2 contains `within 2 steps`.
  - every preset in `ConnectionPresets.all` yields a non-empty sentence that
    differs from the custom one.
  - existing `connections_share_caption_test.dart` still passes.

- [ ] **Step 2: Run, expect FAIL** (file missing).

- [ ] **Step 3: Implement**, add the ARB keys in all locales, run `flutter gen-l10n`.

- [ ] **Step 4: Run** `flutter test test/features/connections/presentation test/l10n test/architecture test/shared`.
  Expected: PASS (orphan-key and diacritics guards included).

- [ ] **Step 5: Commit** `feat(connections): caption text for every map`

### Task 5: Caption on the canvas, overlays below it, empty Who dives where

**Files:**
- Create: `lib/features/connections/presentation/widgets/connections_caption.dart`
- Modify: `lib/features/connections/presentation/pages/connections_graph_stack.dart`
- Modify: `lib/features/connections/presentation/pages/connections_page.dart`
- Test: `test/features/connections/presentation/widgets/connections_caption_test.dart`,
  `test/features/connections/presentation/pages/connections_page_test.dart`

**Interfaces:**
- Consumes: `ConnectionsCaptionText.of` (Task 4), `mapSharedWith` (Task 1).
- Produces: `ConnectionsCaption({required ConnectionsCaptionText text, required ValueChanged<double> onHeight})`,
  key `ValueKey('connections-caption')`: a Card like the legend's, title in
  `titleSmall` (one line, ellipsis), sentence in `bodySmall` (wraps, no max
  lines). It reports its laid-out height through `onHeight` after layout
  whenever it changes (a private `RenderProxyBox` that schedules the callback
  post-frame).
- `ConnectionsGraphStack` gains `required ConnectionsCaptionText caption`,
  `required double captionInset`, `required ValueChanged<double> onCaptionHeight`.
  The caption sits at `left: 12, right: 12, top: 8`; the insight strip moves
  to `top: 8 + captionInset`; the page adds `captionInset` to `stripHeight`
  (the canvas `topInset`) and `belowStrip`. The semantics label is
  `'${caption.title}. $summary'`.
- The page holds `double _captionHeight = 0`;
  `captionInset = _captionHeight == 0 ? 0 : _captionHeight + 8`; it builds
  `savedMapNames` from `savedConnectionMapsProvider` and the caption text from
  `ConnectionsCaptionText.of(..., edges: display.edges)`.
- Empty: `showCanvas` is also false when `view.mapSharedWith.isNotEmpty &&
  graph.edges.isEmpty`, so the page shows `ConnectionsEmptyState`, which
  already picks `connections_empty_buddies` for a map with buddies.
- Tables (pairs, entities, matrix) and the empty state get no caption.

- [ ] **Step 1: Write the failing tests**
  - caption widget: renders title and full sentence; at `textScaler 2.0` in a
    360 px box the sentence's `Text` has no `maxLines` and is not clipped
    (`tester.getSize` height > one line); `onHeight` fires with the box height.
  - page (desktop and phone): with the default view, `find.byKey(ValueKey('connections-caption'))`
    finds one and `find.text('Who dives where')` is inside it; the insight
    strip's top (`tester.getTopLeft(find.byKey(ValueKey('connections-insights'))).dy`)
    is at least the caption's bottom.
  - page: default view with a graph of one buddy and two sites and no edges
    shows `ConnectionsEmptyState` with the `No buddies are linked` text and no
    canvas.
  - page: same no-edge graph on the `circle` preset still shows the canvas
    (rule is Who dives where only).
  - page: `display.view = matrix` shows no caption.

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** the Interfaces above. Keep `connections_page.dart`
  under 800 lines.

- [ ] **Step 4: Run** `flutter test test/features/connections test/architecture test/shared`.
  Expected: PASS.

- [ ] **Step 5: Commit** `feat(connections): caption on the canvas`

### Task 6: Verify and capture

- [ ] `dart format .`, `flutter analyze` (no issues).
- [ ] `flutter test test/features/connections test/features/insights test/architecture test/shared test/l10n`.
- [ ] After screenshots: rerun the throwaway screenshot harness
  (`test/features/connections/presentation/pages/tmp_shot_test.dart`, not
  committed) with `SHOT_TAG=after`, plus a solo-diver phone shot; copy to the
  scratchpad as `03-connections-after-phone.png`,
  `04-connections-after-desktop.png`, `05-connections-after-no-buddies-phone.png`;
  then delete the harness and its `goldens/` directory.

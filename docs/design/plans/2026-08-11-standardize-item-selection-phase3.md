# Standardized Selection Phase 3: Sites, Buddies, Tags, Dive Media

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the four remaining hand-rolled multi-select surfaces to
`lib/shared/selection/`, so all five selectable surfaces satisfy one contract and
four duplicate state machines are deleted.

**Architecture:** Each surface replaces its local `_isSelectionMode` / `_selectedIds`
trio with a `SelectionController`, its bar builders with `SelectionAppBar`, and its
hand-rolled checkbox with `SelectionLeading`. Each gains a keyed `Select` button, a
`SelectableListScope` for Escape / Ctrl-A / back, `pruneTo` on filter change, and a
`verifySelectionContract` call.

**Tech Stack:** Flutter 3.x, Material 3, Riverpod, `flutter_test`, ARB localization.

## Scope

Phase 3 of the spec `docs/superpowers/specs/2026-08-11-standardize-item-selection-design.md`.
Phases 4-5 (ten surfaces with no selection today) and Phase 6 (cleanup) follow.

**Stacked PR:** this branch (`worktree-selection-phase3`) is cut from
`worktree-standardize-selection`, not `main`, because the shared package is not on
`main` yet. Its PR must be **retargeted to `main` after PR #981 merges**.

### Explicitly out of scope

- **Adding delete undo to buddies, tags, media.** Only sites has an undo buffer
  today. The others need repository support (`restoreBuddies`, `restoreTags`) that
  does not exist. Recorded as a follow-up, deliberately not silently added here.
- **Making `DragSelectGridView` id-based.** The media section bridges
  indices to ids at its boundary instead. Converting the grid itself would also
  touch `photo_picker_page.dart`, which is not part of this phase.

## Global Constraints

- `dart format .` must produce no changes. Run before every commit.
- `flutter analyze` must be clean. CI treats analyzer **infos** as fatal.
- Every user-facing string must exist in all 11 locales in `lib/l10n/arb/`.
  Reuse the existing `common_selection_*` keys wherever possible; only add new
  keys when a surface needs wording those do not cover.
- No emojis in code, comments, or documentation.
- Commit messages must NOT contain `Co-Authored-By`, the Claude Code attribution
  line, or a session URL.
- Work in `.claude/worktrees/selection-phase3` on `worktree-selection-phase3`.

## Prerequisite change to the shared bar

`SelectionAppBar.onDelete` becomes nullable again, having been made required
during PR #981 review. The dive media section is the counterexample that review
did not have: it unlinks media from a dive without destroying files, so a trash
control there would misdescribe what it does.

This is not a straight revert. Before review the callback was nullable *and* the
button still rendered, so an omitting surface shipped a trash icon that looked
available and did nothing. Now a null callback omits the control entirely, which
keeps the property the reviewer was protecting -- no dead controls -- while
letting a surface with no true delete opt out honestly.

## Icon canon

One glyph per concept, applied to every surface in this phase:

| Concept | Icon | Replaces |
| --- | --- | --- |
| Merge | `Icons.merge_type` | `Icons.merge` (tags) |
| Delete | `Icons.delete_outline` | `Icons.delete` (sites, buddies, tags) |
| Enter selection | `Icons.checklist` | -- |

Delete is supplied by `SelectionAppBar`, so surfaces get the canonical delete icon
automatically by deleting their own delete button.

## Reference conversion

`lib/features/dive_log/presentation/widgets/dive_list_content.dart` is the worked
example. Read it before starting: controller field :114, entry :230, `pruneTo` in
build :733, `SelectableListScope` :739, `_bulkActions` :1118, both shells
:1159 and :1174.

---

### Task 1: Convert Dive Sites

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/compact_site_list_tile.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/dense_site_list_tile.dart`
- Test: `test/features/dive_sites/presentation/widgets/site_list_content_test.dart`

**Interfaces:**
- Consumes: `SelectionController`, `SelectionAppBar`, `SelectionBarShell`,
  `SelectionLeading`, `SelectableListScope`, `BulkAction` (signatures in the
  survey; all under `lib/shared/selection/`).
- Produces: `_SiteListContentState._selection`, `_bulkActions(List<SiteWithDiveCount>)`.

Sites is first because it is the closest analogue to dives: it already has an
overflow `Select` item, both bar shells, and undo on both merge and delete.

- [ ] **Step 1: Write the failing contract test**

Add to `site_list_content_test.dart`. Model the pump on the file's existing
`group('selection mode')` at :623 and its override builder.

```dart
    testWidgets('satisfies the shared selection contract', (tester) async {
      // Build with at least 3 sites and a notifier whose visible list can be
      // narrowed, mirroring _MockPaginatedNotifier.showOnly in
      // test/features/dive_log/presentation/widgets/dive_list_content_test.dart.
      await verifySelectionContract(
        tester,
        build: () => /* testApp(...) with SiteListContent(showAppBar: true) */,
        selectButton: find.byKey(const ValueKey('enter_selection')),
        firstRow: /* finder for the first site row */,
        applyFilter: (tester) async {
          /* narrow the visible site list to one */
        },
        visibleAfterFilter: 1,
      );
    });
```

Import `'../../../../helpers/selection_contract.dart'`.

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_list_content_test.dart`
Expected: FAIL -- no widget keyed `enter_selection`.

- [ ] **Step 3: Replace the state machine**

In `_SiteListContentState`:

- Delete `_isSelectionMode` :77 and `_selectedIds` :78. Add
  `final SelectionController _selection = SelectionController();` and dispose it.
- Add the mirrors used by the reference conversion:

```dart
  bool get _isSelectionMode => _selection.value.isActive;
  Set<String> get _selectedIds => _selection.value.checkedIds;
```

- Delete `_enterSelectionMode` :168, `_exitSelectionMode` :178,
  `_toggleSelection` :185, `_selectAll` :198, `_deselectAll` :204. Replace calls:
  the overflow `Select` item calls `_selection.enterExplicit()`, long-press calls
  `_selection.enterImplicit(id)`, row taps call `_selection.toggle(id)`.
- Keep `_deletedSites` and `_mergeSnapshot`; undo behaviour is unchanged.

- [ ] **Step 4: Replace both bar builders**

Delete `_buildCompactSelectionAppBar` :695 and `_buildSelectionAppBar` :755. Add:

```dart
  /// Site-specific extras. Select-all, deselect-all and delete come from
  /// SelectionAppBar.
  List<BulkAction> _bulkActions(List<SiteWithDiveCount> sites) {
    return [
      BulkAction(
        id: 'merge',
        icon: Icons.merge_type,
        label: context.l10n.diveSites_list_selection_mergeTooltip,
        minCount: 2,
        onInvoke: _startMerge,
      ),
    ];
  }

  SelectionAppBar _buildSelectionAppBar(List<SiteWithDiveCount> sites) {
    return SelectionAppBar(
      controller: _selection,
      selectableIds: sites.map((s) => s.site.id).toList(),
      actions: _bulkActions(sites),
      shell: SelectionBarShell.appBar,
      onDelete: _confirmAndDelete,
    );
  }

  Widget _buildCompactSelectionAppBar(
    BuildContext context,
    List<SiteWithDiveCount> sites,
  ) {
    return SelectionAppBar(
      controller: _selection,
      selectableIds: sites.map((s) => s.site.id).toList(),
      actions: _bulkActions(sites),
      shell: SelectionBarShell.pane,
      maxInlineActions: 1,
      onDelete: _confirmAndDelete,
    );
  }
```

Verify the exact id accessor on `SiteWithDiveCount` before writing this -- it may
be `s.site.id` or `s.id`. Read the type first.

- [ ] **Step 5: Add the Select button, scope, and pruning**

- Add to both non-selection app bars, immediately left of the overflow:

```dart
IconButton(
  key: const ValueKey('enter_selection'),
  icon: const Icon(Icons.checklist),
  tooltip: context.l10n.common_selection_enterTooltip,
  onPressed: _selection.enterExplicit,
),
```

  Keep the existing overflow `Select` item too -- it is an additional path, and
  removing it would be an unrelated regression.
- Wrap the built subtree in `SelectableListScope(controller: _selection,
  selectableIds: visibleIds, child: ...)` and a
  `ValueListenableBuilder<SelectionState>` so rows rebuild on check changes.
  Build the list content *inside* the builder, as the dives conversion does.
- Call `_selection.pruneTo(visibleIds)` from a post-frame callback in `build`.

- [ ] **Step 6: Route the tile checkboxes through SelectionLeading**

In `SiteListTile` (:1212), `CompactSiteListTile`, and `DenseSiteListTile`, replace
the hand-rolled `Checkbox` with `SelectionLeading(isSelectionMode:, isChecked:,
onChanged: (_) => onTap?.call(), child: <existing leading widget>)`.

Note the parameter meanings differ per tile today: `CompactSiteListTile.isSelected`
means *checked* while `SiteListTile.isSelected` means *highlighted*. Normalise all
three to `isChecked` + `isHighlighted` as the dive tiles were, and fix the call
sites at :812-815 and :841-867 accordingly.

- [ ] **Step 7: Run the tests**

```bash
flutter test test/features/dive_sites/
flutter analyze lib/features/dive_sites test/features/dive_sites
```
Expected: PASS, no analyzer output. Existing selection tests that assert
`Icons.delete` must be updated to the canonical `Icons.delete_outline`, and any
asserting an action is *hidden* below its gate must assert *disabled* instead.

- [ ] **Step 8: Commit**

```bash
dart format lib test
git add lib test
git commit -m "refactor(sites): adopt the shared selection package"
```

---

### Task 2: Convert Buddies

**Files:**
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_content.dart`
- Modify: `lib/features/buddies/presentation/widgets/dense_buddy_list_tile.dart`
- Test: `test/features/buddies/presentation/widgets/buddy_list_content_test.dart`

**Interfaces:**
- Consumes: the shared package, plus the conversion shape proven in Task 1.
- Produces: `_BuddyListContentState._selection`,
  `_bulkActions(List<BuddyWithDiveCount>)`.

Buddies is structurally identical to sites with two differences: it has **no**
`Select` menu item anywhere (long-press is the only way in), and delete has **no**
undo.

- [ ] **Step 1: Write the failing contract test**

`buddy_list_content_test.dart` has no selection coverage at all today. Add a
`group('selection')` containing the `verifySelectionContract` call, shaped exactly
as in Task 1 but against `BuddyListContent`.

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/features/buddies/presentation/widgets/buddy_list_content_test.dart`
Expected: FAIL -- no `enter_selection` key.

- [ ] **Step 3: Apply the Task 1 conversion**

Same six moves: controller replaces `_isSelectionMode` :61 / `_selectedIds` :62;
delete the five methods at :146, :156, :163, :176, :182; both bar builders at :633
and :693 become `SelectionAppBar`; `_bulkActions` declares only merge
(`Icons.merge_type`, `minCount: 2`, `_startMerge`); `SelectableListScope`,
`ValueListenableBuilder`, and post-frame `pruneTo` are added.

- [ ] **Step 4: Add the Select button**

Buddies has no `Select` affordance today, so this is the discoverability fix that
motivated the whole project. Add the keyed `IconButton` to **both** the inline
`AppBar` (:409-470) and `_buildCompactAppBar` (:556), left of the overflow.

- [ ] **Step 5: Normalise the tiles**

`BuddyListTile` (:864) has `isSelected` (highlight) and `isChecked` (checkbox);
`DenseBuddyListTile` has both plus `isHighlighted`, and the call site at :789-794
does not pass `isSelected` at all. Normalise both to `isChecked` + `isHighlighted`
and route the checkbox through `SelectionLeading`.

- [ ] **Step 6: Run the tests**

```bash
flutter test test/features/buddies/
flutter analyze lib/features/buddies test/features/buddies
```
Expected: PASS, clean.

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib test
git commit -m "refactor(buddies): adopt the shared selection package"
```

---

### Task 3: Convert Tags

**Files:**
- Modify: `lib/features/tags/presentation/pages/tag_manage_page.dart`
- Test: `test/features/tags/presentation/pages/tag_manage_page_test.dart`

**Interfaces:**
- Consumes: the shared package.
- Produces: `_TagManagePageState._selection`, `_bulkActions(List<TagStatistic>)`.

Tags is a full page, not a master-detail pane, so it needs only the `appBar` shell.
It has no `_selectAll`/`_deselectAll` today and gains both from `SelectionAppBar`.

- [ ] **Step 1: Write the failing contract test**

Add `verifySelectionContract` to `tag_manage_page_test.dart`. `applyFilter` types
into the existing search field (`_searchController`, filtering at :96-101), which
is the real filter path and currently does **not** prune the selection.

- [ ] **Step 2: Run it and confirm it fails**

Expected: FAIL on the missing `enter_selection` key, and -- once that is added --
on pruning, because typing a query today leaves off-screen tags checked.

- [ ] **Step 3: Convert**

- Controller replaces `_isSelectionMode` :21 / `_selectedIds` :22; delete
  `_enterSelectionMode` :385, `_exitSelectionMode` :395, `_toggleSelection` :402.
- Replace `_buildSelectionAppBar` :268 with `SelectionAppBar`, shell `appBar`,
  `onDelete: () => _confirmDelete(context)`, and one extra:

```dart
BulkAction(
  id: 'merge',
  icon: Icons.merge_type,
  label: context.l10n.tags_manage_mergeAction,
  minCount: 2,
  onInvoke: () => _showMergeSheet(context),
),
```

  Note the icon changes from `Icons.merge` to the canonical `Icons.merge_type`.
- Route the `leading:` checkbox at :128-133 through `SelectionLeading`, keeping the
  `CircleAvatar(radius: 16, backgroundColor: tag.color)` as its `child` so the tag
  colour stays visible outside selection mode.
- Add the keyed `Select` button to the page app bar.
- Wrap in `SelectableListScope` and add post-frame `pruneTo(visibleTagIds)` using
  the **filtered** list from `_buildTagList`.
- **Keep the search bar visible during selection.** It is hidden today (`if
  (!_isSelectionMode)` at :57); the spec requires search to stay available so
  narrowing mid-selection is a supported move, and the contract test's
  `applyFilter` depends on it.

- [ ] **Step 4: Run the tests**

```bash
flutter test test/features/tags/
flutter analyze lib/features/tags test/features/tags
```
Expected: PASS. The existing tests `'merge button disabled when fewer than 2
selected'` :217 and `'merge button enabled when 2 tags selected'` :240 should keep
passing unchanged -- they already assert disabled-not-hidden, which matches the
shared bar's behaviour.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib test
git commit -m "refactor(tags): adopt the shared selection package"
```

---

### Task 4: Convert the Dive Media section

**Files:**
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart`
- Test: `test/features/media/presentation/widgets/dive_media_section_selection_test.dart` (create)

**Interfaces:**
- Consumes: the shared package plus the existing
  `DragSelectGridView<T>` (`lib/shared/widgets/drag_select_grid_view.dart`),
  whose selection API stays `Set<int>`.
- Produces: `_DiveMediaSectionState._selection` plus the index/id bridge.

This is the task that tests the abstraction hardest: the grid is positional and the
controller is id-based.

- [ ] **Step 1: Write the failing test**

Create `dive_media_section_selection_test.dart`. The existing media test file is 18
lines and has zero selection coverage. Cover at minimum:

```dart
    testWidgets('checked ids survive a media reorder', (tester) async {
      // Pump the section with media [a, b, c] and check 'c'.
      // Rebuild with the list reordered to [c, b, a].
      // Assert the checked item is still 'c', not whatever now sits at c's
      // old index. Index-based selection silently fails this.
    });

    testWidgets('unlink acts on the checked ids', (tester) async {
      // Check two items, invoke unlink, and assert deleteMultipleMedia was
      // called with exactly those two ids.
    });
```

Replace the comments with concrete bodies; use `ProviderScope` overrides for
`mediaListNotifierProvider(diveId)`.

- [ ] **Step 2: Run it and confirm it fails**

Expected: the reorder test FAILS -- today `_selectedIndices` holds positions, so a
reorder repoints the selection at different files.

- [ ] **Step 3: Add the index/id bridge**

Keep `DragSelectGridView` index-based; bridge at the boundary:

```dart
  final SelectionController _selection = SelectionController();

  /// Indices for the grid, derived from the checked ids against the current
  /// ordering. Deriving every build is what makes a reorder safe: the ids are
  /// the truth and positions are recomputed, rather than the reverse.
  Set<int> _indicesFor(List<MediaItem> media) => {
    for (var i = 0; i < media.length; i++)
      if (_selection.value.isChecked(media[i].id)) i,
  };

  /// Ids for the controller, derived from the grid's indices.
  List<String> _idsFor(List<MediaItem> media, Set<int> indices) => indices
      .where((i) => i >= 0 && i < media.length)
      .map((i) => media[i].id)
      .toList();
```

Wire the grid:

```dart
initialSelection: _indicesFor(media),
onSelectionChanged: (indices) =>
    _selection.selectAll(_idsFor(media, indices)),
onSelectionModeChanged: (isSelecting) {
  if (!isSelecting) _selection.exit();
},
```

`selectAll` is the right call here rather than `toggle`: the grid reports its
complete selection each time, not a delta.

- [ ] **Step 4: Replace `_SelectionHeader` with SelectionAppBar**

Delete `_SelectionHeader` :467. Render
`SelectionAppBar(shell: SelectionBarShell.pane, ...)` in its place, with one extra:

```dart
BulkAction(
  id: 'unlink',
  icon: Icons.link_off,
  label: context.l10n.media_diveMediaSection_unlinkSelectedButton(
    _selection.value.count,
  ),
  onInvoke: () => _unlinkSelected(context, media),
),
```

Unlink is not delete -- the files are not destroyed -- so media passes
`onDelete: null` and declares unlink as its only extra. `SelectionAppBar.onDelete`
is nullable for exactly this case, and **omits the delete control entirely** when
null rather than rendering it disabled, so the bar never shows a dead button.
Every surface that can genuinely delete must still pass the callback.

- [ ] **Step 5: Add the Select affordance**

The section header (`:344-378`) has add/scan `IconButton`s. Add the keyed
`enter_selection` button beside them, calling `_selection.enterExplicit()`.

- [ ] **Step 6: Rewrite `_unlinkSelected` against ids**

Replace the index conversion at :138-141 with
`final selectedIds = _selection.value.checkedIds.toList();`. The
`where((i) => i < media.length)` staleness guard becomes unnecessary; add a
post-frame `_selection.pruneTo(media.map((m) => m.id).toList())` instead.

- [ ] **Step 7: Run the tests**

```bash
flutter test test/features/media/ test/shared/widgets/drag_select_grid_view_test.dart
flutter analyze lib/features/media test/features/media
```
Expected: PASS, clean. `drag_select_grid_view_test.dart` must be untouched and
still green -- the grid's own API did not change.

- [ ] **Step 8: Commit**

```bash
dart format lib test
git add lib test
git commit -m "refactor(media): adopt the shared selection package"
```

---

### Task 5: Verify and open the stacked PR

**Files:** none modified.

- [ ] **Step 1: Full verification**

```bash
dart format .
flutter analyze
flutter test
```
Expected: no formatting changes, silent analyzer, all tests pass. Do not proceed
on a failure; fix the cause.

- [ ] **Step 2: Confirm all five surfaces assert the contract**

```bash
grep -rn "verifySelectionContract" test/ | sort
```
Expected: five call sites -- dives, sites, buddies, tags, media.

- [ ] **Step 3: Confirm the duplicate machines are gone**

```bash
grep -rn "_isSelectionMode = \|_selectedIds = {}" lib/features/
```
Expected: no matches. Any hit is a surface still holding its own state.

- [ ] **Step 4: Open the PR against the phase 2 branch**

```bash
git push -u origin worktree-selection-phase3
gh pr create --base worktree-standardize-selection \
  --head worktree-selection-phase3 --title "..." --body-file <path>
```

The PR body must state prominently that it is **stacked on #981 and must be
retargeted to `main` after #981 merges**.

## Definition of Done

- `dart format .` clean, `flutter analyze` silent, `flutter test` green.
- All five selectable surfaces call `verifySelectionContract`.
- No `lib/features/**` file declares its own selection mode boolean or id set.
- Merge is `Icons.merge_type` and delete is `Icons.delete_outline` everywhere.
- Sites, buddies, tags and media each expose a keyed `enter_selection` button.
- Media selection survives a reorder of the underlying list.

## Follow-ups deliberately not done here

- **Delete undo for buddies, tags, media.** Needs repository restore support that
  does not exist. Sites keeps its undo; the others still delete without one, as
  they do today.
- **Making `DragSelectGridView` id-based.** Would also touch
  `photo_picker_page.dart`. The boundary bridge in Task 4 is sufficient and
  strictly smaller.
- **Phases 4-6.** Ten surfaces with no selection today, then cleanup.

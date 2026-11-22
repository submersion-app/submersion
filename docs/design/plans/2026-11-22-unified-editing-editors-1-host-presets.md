# Unified editing phase 4, plan 1: the editor host, tank presets and weight presets

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shared host that gives an editor with no read page the
unlocked record bar, the leave check and a one-transaction Save, and move the
tank preset and weight preset editors onto it.

**Architecture:** A mixin on `ConsumerState`, `RecordEditorHost<W, D>`, opens
a `RecordEditController<D>` already unlocked over a **draft**: a small value
the editor builds from what its form shows. Dirty means the draft differs
from the one the form was filled with. The bar, leave guard, exit blocker and
shortcuts are the record pages' own pieces; Save runs the editor's existing
writes inside `runRecordSitting`. Each editor keeps its form, its
controllers and its parsing.

**Tech Stack:** Flutter, Riverpod, go_router, Drift; the record editing
pieces in `lib/shared/widgets/record_editing/` and
`lib/core/services/change_log/record_sitting_writer.dart`.

**Spec:** [docs/design/specs/2026-11-22-unified-editing-phase-4-design.md](../specs/2026-11-22-unified-editing-phase-4-design.md)
(phase 4 of [the pattern](../specs/2026-11-14-unified-editing-pattern-design.md)).
Read its "What is generalised", "Rules every phase 4 editor follows", "Tank
presets" and "Weight presets" before starting.

## Global Constraints

- Never write an em-dash, or an en-dash or double hyphen as sentence
  punctuation, in code, comments, tests, commits or the PR.
- Nothing written to the repo or GitHub names the tools used to write it:
  no tool attribution and no co-author trailers.
- Every pull request says `Refs #4527`. This plan's PR also carries the
  design note (`docs/design/specs/2026-11-22-unified-editing-phase-4-design.md`),
  by Eric's decision.
- Goes live as it merges: no build switch (decision 6).
- The bar is `RecordEditBar` as it stands, tinted, no back arrow, Save
  disabled until there is a change (decision 2).
- Every new string goes into all locales. This plan should need none: the
  bar's Cancel and Save, the discard dialog and the editors' titles exist.
- Run only the test files you wrote or changed, by path. Never a folder,
  never the whole suite; the pre-push hook runs the rest.
- Run `dart format` on changed files before each commit.
- Never launch a dev build of the app (it can open the diver's real log or
  sync). Screenshots come from headless widget tests.
- Commit only on this branch; push and open the PR only with Eric's say-so.

## Review Focus

1. **A preset loaded in other units reads as unchanged.** A tank preset in
   psi and cubic feet, opened and left alone, has Save disabled and Back asks
   nothing. The draft holds the field texts as shown, never values converted
   back. Test in Task 2.
2. **Back after a discard leaves one page, not two.** Back with changes,
   Discard: the editor leaves and the preset list under it stays. Test in
   Task 1 (host) and Task 3 (weight presets, pushed from a list).
3. **A double Save writes once.** Save tapped twice, or Save and Cmd+S
   together, gives one write and one History entry. Test in Task 1.
4. **A failed Save keeps everything.** The repository throws: the page stays
   with every value, Save still enabled, a snackbar says it failed, and a new
   weight preset leaves no row behind. Tests in Task 1 and Task 3.
5. **A diver switch never creates under the new diver.** A new preset, typed
   in and not saved, closes when the active diver changes, and nothing is
   written for either diver. Test in Task 1 and Task 2.

---

### Task 0: Before screenshots

**Files:**
- Create (scratch, not committed): a throwaway test under the session
  scratchpad, or a temporary file under `test/` deleted before commit

- [ ] **Step 1: Capture the editors as they are today**

Headless widget-test captures (`matchesGoldenFile` or `toImage`, as the
phase 3 PRs did; see `test/features/planner/chart/plan_profile_chart_golden_test.dart`
for the golden setup) of: the tank preset editor (edit, filled), the weight
preset editor (edit, two rows), each at phone width (390 x 844) and desktop
width (1280 x 800), light and dark. Save them outside the repo, named
`<nn>-<screen>-<width>-<theme>-before.png`.

- [ ] **Step 2: Check nothing is staged**

Run: `git status --short`
Expected: no new or changed file under `lib/` or `test/`.

---

### Task 1: The editor host

**Files:**
- Create: `lib/shared/widgets/record_editing/record_editor_host.dart`
- Test: `test/shared/widgets/record_editing/record_editor_host_test.dart`

**Interfaces:**
- Consumes: `RecordEditController<D>` (`onSave`, `creating`, `unlock`,
  `lock`, `save`, `session`, `isDirty`, `isSaving`, `isBusy`, `saveError`),
  `EditField<D, D>`, `EditSession<D>.set`, `RecordEditBar`,
  `RecordEditLeaveGuard<D>`, `cancelSitting`, `RecordSittingExitBlocker<D>`,
  `recordSittingPageOf`, `appExitGuardProvider`,
  `recordEditShortcutTargetsProvider`, `RecordEditShortcutTarget`,
  `runRecordSitting`, `RecordSittingRefusal`, `currentDiverIdProvider`.
- Produces, for Tasks 2 and 3 and every later phase 4 plan:

```dart
mixin RecordEditorHost<W extends ConsumerStatefulWidget, D>
    on ConsumerState<W> {
  // Supplied by the editor.
  String get editorTable;            // change log table, e.g. 'tank_presets'
  String? get editorStoredId;        // null when creating
  String editorTitle(BuildContext context);
  D readEditorDraft();               // the form as it reads now
  bool validateEditor();             // false: nothing is written
  Future<void> writeEditor(String recordId); // runs inside the transaction
  void afterEditorSaved(ScaffoldMessengerState messenger) {} // after commit

  // Provided by the host.
  late final String newEditorRecordId; // a v4 uuid, made once
  String get editorRecordId;           // editorStoredId ?? newEditorRecordId
  bool get editorCreating;             // editorStoredId == null
  RecordEditController<D> get editorController;
  bool get editorOpen;
  void openEditor();                   // starts the sitting on readEditorDraft()
  void editorChanged();                // hands readEditorDraft() to the sitting
  Future<void> saveEditor();
  Future<void> cancelEditor();
  Widget editorScaffold(BuildContext context, {required Widget body});
  void disposeEditor();                // call from dispose
}

/// The one card id an editor's sitting uses; its History entry names no
/// card, so it reads "Edited" (or "Added" for a create).
const recordEditorCardId = 'editor';
```

What each provided member does (the tests below pin each):

- `openEditor()` unlocks the controller on `readEditorDraft()` once; the
  editor calls it when its form is filled (after a load, or at once for a
  new record). It also notes the active diver id at that moment.
- `editorChanged()` sets the one `EditField<D, D>` (id `'draft'`, card
  `recordEditorCardId`, read and write the whole draft) to
  `readEditorDraft()`. A draft equal to the first is no change
  (`EditSession.set` already clears it), so a change typed back is clean.
  The editor calls it from its controllers' listeners and after each
  `setState` that changes the form.
- `saveEditor()`: does nothing while a save runs; returns if
  `validateEditor()` is false; otherwise `editorController.save()`, whose
  `onSave` is `runRecordSitting(table: editorTable, recordId:
  editorRecordId, changedCardIds: const [], body: () =>
  writeEditor(editorRecordId))`. On success it captures the messenger, calls
  `afterEditorSaved`, then leaves (pops once). On failure it stays and shows
  `recordEdit_saveFailed`, or the refusal's message for a
  `RecordSittingRefusal`, as `RecordEditHost.saveAndReport` does.
- `cancelEditor()`: `cancelSitting(context, editorController)`; when it
  returns true, leaves.
- `editorScaffold`: before `openEditor`, a plain `Scaffold` with an `AppBar`
  showing `editorTitle` and the editor's back arrow (a loading or not-found
  state). After, `RecordEditLeaveGuard<D>` around a `Scaffold` whose bar is
  `RecordEditBar(title: editorTitle, canSave: isDirty, isSaving, isBusy,
  onCancel: cancelEditor, onSave: saveEditor)`. It wraps `body` in
  `RecordEditScope<D>`.
- Leaving: one `_leaving` flag; the page pops once, by `Navigator.pop` on
  its own route. A sitting that ends any other way (the exit blocker's
  discard on a tab switch or a quit, a diver switch) leaves once the page
  is current, from `build`, after the frame, as
  `RecordCreating._leaveIfEnded` does. Back is the leave guard's: it pops
  itself, so the host must not pop as well.
- Diver switch (decision 7): `editorScaffold` listens to
  `currentDiverIdProvider`; a change from the id noted at `openEditor`
  locks the controller without asking (the switcher has already asked
  through the exit guard) and the page leaves.
- The exit blocker is created with the controller, as `RecordEditHost`
  does (confirm: `cancelSitting`; page: `recordSittingPageOf(context)`).
- Shortcuts: one `RecordEditShortcutTarget` (unlock does nothing, save
  `saveEditor`, cancel `cancelEditor`, current while mounted, the route is
  current and `editorOpen`), registered in `initState`, removed in
  `disposeEditor`.

No menu and no read-only mode in this plan: the menu comes with its first
user (plan 2, Remove key), read-only views with plan 3.

- [ ] **Step 1: Write the failing tests**

In `record_editor_host_test.dart`, a `_FakeEditorPage` (a
`ConsumerStatefulWidget` with one `TextField` whose draft is its text, and a
`writes` list the fake `writeEditor` appends `recordId` to, or throws when
told to), pushed from a `_ListPage` with a GoRouter so popping is visible.
`setUpTestDatabase()` in `setUp`. Tests:

```dart
testWidgets('opens on the tinted bar with Save disabled and no back arrow', ...);
  // find.byType(RecordEditBar) one; Save's AppBarTextAction onPressed null;
  // find.byType(BackButton) none.
testWidgets('typing enables Save; typing it back disables it again', ...);
testWidgets('Cancel with no change closes at once, asking nothing', ...);
  // find.byType(AlertDialog) none; _ListPage shown.
testWidgets('Cancel with a change asks; Keep editing keeps the text', ...);
testWidgets('Back with a change asks; Discard leaves one page only', ...);
  // after Discard: _ListPage shown, its route still there (not popped too).
testWidgets('Save writes once, in one change log operation, then leaves', ...);
  // writes == ['rec-1']; one row in change_log_operations whose label
  // decodes (RecordEditLabel.decode) to table 'fake', id 'rec-1', no cards.
testWidgets('Save tapped twice writes once', ...);
testWidgets('validateEditor false writes nothing and stays', ...);
testWidgets('a write that throws stays with the text and says it failed', ...);
  // snackbar recordEdit_saveFailed; Save enabled; field text unchanged.
testWidgets('a new record writes under its own new id', ...);
  // editorStoredId null: writes == [state.newEditorRecordId], a uuid.
testWidgets('the app exit guard asks while there is a change', ...);
  // ref.read(appExitGuardProvider).mayLeave() shows the discard dialog.
testWidgets('a change of active diver closes the page, clean or changed', ...);
  // MockCurrentDiverIdNotifier.setCurrentDiver('b'): _ListPage shown,
  // writes empty, no dialog.
testWidgets('Cmd+S saves and Escape cancels', ...);
```

Model the harness on `record_edit_host_test.dart` (shortcuts and exit guard
wiring) and the change log check on
`test/features/marine_life/data/services/species_edit_save_service_test.dart`
(`operations()` after `ChangeLogRepository().settleAll()`).

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/shared/widgets/record_editing/record_editor_host_test.dart`
Expected: FAIL, `record_editor_host.dart` does not exist.

- [ ] **Step 3: Implement `RecordEditorHost` in `record_editor_host.dart`**

As the Interfaces block describes. Lift from `RecordEditHost` and
`RecordCreating` rather than rewriting: controller and exit blocker creation,
shortcut registration, `saveAndReport`'s error reporting,
`_leaveIfEnded`. Doc comments say what each member is for, in the voice of
the neighbouring files.

- [ ] **Step 4: Run the tests to see them pass**

Run: `flutter test test/shared/widgets/record_editing/record_editor_host_test.dart`
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

Run: `dart format lib/shared/widgets/record_editing/record_editor_host.dart test/shared/widgets/record_editing/record_editor_host_test.dart && flutter analyze lib/shared/widgets/record_editing/record_editor_host.dart test/shared/widgets/record_editing/record_editor_host_test.dart`
Expected: no issues.

```bash
git add lib/shared/widgets/record_editing/record_editor_host.dart test/shared/widgets/record_editing/record_editor_host_test.dart
git commit -m "feat(record-editing): a host for editors with no read page"
```

---

### Task 2: Tank presets on the host

**Files:**
- Modify: `lib/features/tank_presets/presentation/pages/tank_preset_edit_page.dart`
- Modify: `lib/core/router/app_router.dart` (the `new` and `:presetId/edit`
  routes under `/tank-presets`, about lines 2174-2186)
- Test: `test/features/tank_presets/presentation/pages/tank_preset_edit_page_test.dart`

**Interfaces:**
- Consumes: `RecordEditorHost<TankPresetEditPage, TankPresetDraft>` (Task 1).
- Produces: `typedef TankPresetDraft = ({String name, String volume,
  String pressure, TankMaterial material, String description});` in the page
  file (a record: value equality for free). Fields hold the controllers'
  text as shown, untrimmed.

- [ ] **Step 1: Write the failing tests, and retarget the old ones**

Add `setUpTestDatabase()` to the file's setup (the Save now runs in a
transaction). Retarget `'save converts pressure to bar for storage'`: change
the name first (Save is disabled with no change), then assert as before. New
tests:

```dart
testWidgets('a preset opened in psi and cuft and left alone is unchanged', ...);
  // Save disabled; Back pops with no dialog. (Review Focus 1)
testWidgets('the bar is the tinted Cancel and Save bar, with no close button', ...);
  // find.byType(RecordEditBar) one; find.byIcon(Icons.close) none.
testWidgets('Back after changing the name asks before leaving', ...);
testWidgets('a new preset is written under the page id, then the list refreshes', ...);
  // _MockTankPresetRepository records createPreset's preset.id ==
  // state.newEditorRecordId and its diverId == the validated diver.
testWidgets('a new preset typed in closes on a diver switch, writing nothing', ...);
  // (Review Focus 5)
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/tank_presets/presentation/pages/tank_preset_edit_page_test.dart`
Expected: the new tests FAIL (close button still there, no leave check).

- [ ] **Step 3: Move the page onto the host**

- Mix in `RecordEditorHost<TankPresetEditPage, TankPresetDraft>`:
  `editorTable` `'tank_presets'`, `editorStoredId` `widget.presetId`,
  `editorTitle` the existing `tankPresets_edit_title` or
  `tankPresets_new_title`.
- `readEditorDraft()` reads the four controllers' text and `_material`.
- `openEditor()` after `_loadPreset` fills the form, or in a post-frame
  callback from `initState` for a new preset. Listeners on the four
  controllers and the material `setState` call `editorChanged()`.
- `validateEditor()` is `_formKey.currentState!.validate()`.
- `writeEditor(id)`: today's parsing, then the repository directly, not
  the list notifier (which reloads inside the transaction): `updatePreset`,
  or `createPreset(TankPresetEntity.create(id: id, diverId: <validated
  diver id read before the write>, ...))`. A missing diver throws
  `StateError`, which fails the Save.
- `afterEditorSaved(messenger)`: `tankPresetListNotifierProvider.notifier
  .refresh()`, invalidate `customTankPresetsProvider`, and today's
  updated or created snackbar.
- `build` returns `editorScaffold(context, body: ...)` with today's body;
  the `AppBar`, its close button and `AppBarTextAction` go. `_isLoading`
  now covers the load only.
- `dispose` calls `disposeEditor()`.
- In `app_router.dart` both routes gain `onExit: confirmLeaveRecordSitting`.

- [ ] **Step 4: Run the tests to see them pass**

Run: `flutter test test/features/tank_presets/presentation/pages/tank_preset_edit_page_test.dart`
Expected: all pass, the four existing ones included.

- [ ] **Step 5: Format, analyze, commit**

Run: `dart format` and `flutter analyze` on the three files.
Expected: no issues.

```bash
git add lib/features/tank_presets/presentation/pages/tank_preset_edit_page.dart lib/core/router/app_router.dart test/features/tank_presets/presentation/pages/tank_preset_edit_page_test.dart
git commit -m "feat(tank-presets): edit a preset on the shared Cancel and Save bar"
```

---

### Task 3: Weight presets on the host

**Files:**
- Modify: `lib/features/weight_presets/presentation/pages/weight_preset_editor_page.dart`
- Modify: `lib/features/weight_presets/data/repositories/weight_preset_repository.dart`
  (`createPreset`, about line 124)
- Modify: `lib/core/router/app_router.dart` (the routes under
  `/weight-presets`, about lines 2195-2207)
- Test: `test/features/weight_presets/presentation/pages/weight_preset_editor_page_test.dart`
- Test: `test/features/weight_presets/data/repositories/weight_preset_repository_test.dart`
  (create it if absent)

**Interfaces:**
- Consumes: `RecordEditorHost` (Task 1).
- Produces:
  - `WeightPresetRepository.createPreset({String? id, required String
    diverId, required String displayName, required List<WeightEntryDraft>
    entries})`: the preset row takes `id` when given, a fresh v4 uuid when
    not. Every other caller is unchanged.
  - `typedef WeightRowDraft = ({WeightType type, String amount, String
    label});` and a `WeightPresetDraft` class (`name`, `rows`) with `==` and
    `hashCode` over `name` and `listEquals(rows)`, in the page file.

- [ ] **Step 1: Write the failing tests, and retarget the old ones**

Repository test:

```dart
test('createPreset writes the preset under the id it is given', ...);
  // getPresetById('given-id') != null, with its entries.
test('createPreset without an id still makes one', ...);
```

Page tests: `_RecordingRepo.createPreset` gains `String? id` and records
it. Existing tests that tap Save on an untouched edit page change a field
first. New:

```dart
testWidgets('a new preset with its one blank row is unchanged', ...);
  // Save disabled; Back pops with no dialog: the blank belt row is a
  // default, not a seed.
testWidgets('adding a row is a change; removing it again is not', ...);
testWidgets('Back after editing an amount asks; Discard leaves the list', ...);
  // Pushed from a stand-in list route: after Discard the list shows.
  // (Review Focus 2)
testWidgets('no positive weight says so and writes nothing', ...);
testWidgets('a new preset is created under the page id', ...);
  // createPreset's id == state.newEditorRecordId.
testWidgets('a create that throws keeps the rows and writes no preset', ...);
  // With the real repository over the test database and an entry that
  // fails to insert: no weight_presets row afterwards. (Review Focus 4)
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/weight_presets/data/repositories/weight_preset_repository_test.dart test/features/weight_presets/presentation/pages/weight_preset_editor_page_test.dart`
Expected: FAIL (no `id` parameter; no leave check).

- [ ] **Step 3: Add the `id` parameter, then move the page onto the host**

- `createPreset` uses `id ?? _uuid.v4()` for the preset row.
- Mix in `RecordEditorHost<WeightPresetEditorPage, WeightPresetDraft>`:
  `editorTable` `'weight_presets'`, `editorStoredId` `widget.presetId`,
  `editorTitle` today's title strings.
- `readEditorDraft()`: the name text and each row's type, amount text and
  label text, in order.
- `openEditor()` after `_load` fills the rows, or post-frame from
  `initState` for a new preset (after its blank belt row is added). Each
  row's controllers, the name controller, the type dropdown's `setState`,
  add row and remove row call `editorChanged()`.
- `validateEditor()`: the form validates, and at least one row has a
  positive amount, else today's `weightPresets_editor_needWeight` snackbar
  and false.
- `writeEditor(id)`: today's entries, then `updatePreset(id: id, ...)` or
  `createPreset(id: id, diverId: <validated diver id>, ...)`; a missing
  diver throws `StateError`. The repository's own transactions nest inside
  the sitting's.
- A preset that no longer exists keeps today's snackbar and pop, before
  `openEditor` is ever called.
- `build` returns `editorScaffold`; the `AppBar`, close button and
  `AppBarTextAction` go. `dispose` calls `disposeEditor()`.
- Both routes gain `onExit: confirmLeaveRecordSitting`.

- [ ] **Step 4: Run the tests to see them pass**

Run: `flutter test test/features/weight_presets/data/repositories/weight_preset_repository_test.dart test/features/weight_presets/presentation/pages/weight_preset_editor_page_test.dart`
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

Run: `dart format` and `flutter analyze` on the changed files.
Expected: no issues.

```bash
git add lib/features/weight_presets lib/core/router/app_router.dart test/features/weight_presets
git commit -m "feat(weight-presets): edit a preset on the shared Cancel and Save bar"
```

---

### Task 4: After screenshots and the pull request

- [ ] **Step 1: Capture the after shots**

The same screens, widths and themes as Task 0, with the same harness, named
`-after.png`. Add one of each editor with a change made (Save enabled).

- [ ] **Step 2: Ask Eric before anything goes out**

Show the before and after shots, and ask whether to push and open the PR.

- [ ] **Step 3: On his yes, push and open the PR**

Title: `feat(editing): editors with no read page get the shared Cancel and
Save bar (Unified Editing, phase 4, plan 1)`. Body: what changed, `Refs
#4527`, the design note and this plan linked, the screenshots attached
through the project's secret gist as the contributing guide and the
maintainer's rules describe (`<pr>-<nn>-<screen>-<state>.png`, raw URLs
pinned to the gist commit). Bind the PR and report its checks.

## After the build

Built natively on 2026-11-22 (commits 81d29d104a8 to afb700eb24d). What
changed from this plan, for plan 2 to build on:

- **The host gained two members.** `String? get editorDiverId`: the active
  diver as Save resolved it, read before the transaction opens; a new
  record is created under it (read it in `writeEditor`, never
  `validatedCurrentDiverIdProvider` inside the write, which could wait on
  the transaction's lock). `String? get editorLeaveLocation`: where the
  page goes when nothing is under it (each editor returns its list route);
  null stays.
- **Save also closes the editor when the diver changed** while it resolved
  the diver or while a failed write ran.
- **A throw in `afterEditorSaved`** is logged; the page leaves anyway.
- **The shared leave guard** (`record_edit_leave_guard.dart`) no longer pops
  after its discard question when the page was closed meanwhile (an
  editor's page sits in the shell navigator, the question in the root one).
  This touches every record page; no record page test changed.
- **New records open their sitting in `initState`**, not after the first
  frame, so the first frame shows the tinted bar. Stored records open once
  their load has filled the form.
- **A tank preset that is missing or fails to load** says so and goes back
  to the list, as the weight editor did. New string
  `tankPresets_edit_notFound` in all locales. `tankPresets_edit_errorSaving`
  stays: the dive's tank card uses it.
- **Review rounds after the build changed the host further.** The diver is
  tracked as `validatedCurrentDiverIdProvider` resolves it, noted in
  `initState` (`_noteDiver`, `_isAnotherDiver`): the first diver known is
  the editor's, a repair of the raw id that resolves to the same diver is
  no switch, and a switch while a stored record loads leaves the page
  unopened. Save sets `_saving` with a rebuild, so the bar shows the save
  (Cancel disabled) while the diver resolves, validates only after that
  wait, and leaves when the sitting ended meanwhile. `D? editorStartDraft`
  is the draft the sitting opened on: write only the fields whose text
  changed (the tank editor keeps an untouched volume and pressure, and in
  cubic feet a pressure change also recomputes the volume). `leaveEditor()`
  is the one way an editor leaves on its own (a record that cannot open);
  it falls back to `editorLeaveLocation`. Each editor's update refuses a
  record deleted elsewhere with a `RecordSittingRefusal` carrying its
  not-found message.
- **An update starts from the record as stored at Save**, read inside the
  sitting (the same read refuses a record deleted elsewhere), never from
  the copy the page loaded: only fields whose text changed since the form
  was filled are written, so a value synced in meanwhile is kept. The tank
  editor applies this field by field; the weight editor renames only
  (`renamePreset`, the weights untouched) when its rows are unchanged, keeps
  the stored name when only rows changed, and a row whose amount text is
  unchanged keeps its stored kilograms. Plan 2's editors (cylinder
  configurations, transmitter keys) follow the same rule.
- **Read a retained value with `AsyncValue.value`, not the repo's
  `valueOrNull`.** The extension in `lib/core/providers/async_value_extensions.dart`
  returns null while a provider reloads after a dependency change (a
  refresh from `invalidate` keeps the value), while Riverpod 3's `value`
  keeps the value being replaced. The host notes the editor's diver with
  `value`; a test of that case must reload the provider through a
  dependency (change the raw diver id), not `invalidate` it.
- **A test that holds Save on the diver** must refresh the provider
  (`container.invalidate(validatedCurrentDiverIdProvider)`) after setting
  its gate, since the host has read it at start, and step frames instead of
  `pumpAndSettle` while the bar shows the save.
- **Tests that type and tap Save in the same frame** need a `pump()` between:
  Save enables on the next frame.
- **A first-frame test must look offstage** (`skipOffstage: false`): a
  pushed route's first frame builds offstage.
- The weight preset repository test lives in
  `test/features/weight_presets/weight_preset_repository_test.dart`.

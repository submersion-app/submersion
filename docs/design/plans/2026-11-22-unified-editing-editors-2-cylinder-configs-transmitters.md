# Unified editing phase 4, plan 2: cylinder configurations and transmitter keys

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the cylinder configuration editor and the transmitter key
editor onto the shared editor host, so each Save is one transaction and one
History entry, each asks before its changes are left behind, and the
transmitter's Remove key and post-save Apply go through the same gates as
the rest of the app.

**Architecture:** Plan 1's `RecordEditorHost<W, D>` gains four small members
this plan's editors need: a seed (a new record that opens already changed),
a menu of whole-record operations in the bar, a result handed back to the
page underneath on Save, and a hook for an editor that shows a refused Save
in its own form. The cylinder configuration's config row and its cylinders
are written in one sitting. The transmitter key and its sibling keys' setup
are written in one sitting; a takeover's placeholder fold, the serial copy
onto the item and the findings refresh run after the commit. The "Saved"
snackbar moves from the editor to the item page's Transmitter card, so its
Apply is the card's own Apply flow.

**Tech Stack:** Flutter, Riverpod, go_router, Drift; the record editing
pieces in `lib/shared/widgets/record_editing/` and
`lib/core/services/change_log/record_sitting_writer.dart`.

**Spec:** [docs/design/specs/2026-11-22-unified-editing-phase-4-design.md](../specs/2026-11-22-unified-editing-phase-4-design.md)
(phase 4 of [the pattern](../specs/2026-11-14-unified-editing-pattern-design.md)).
Read its "What is generalised", "Rules every phase 4 editor follows",
"Cylinder configurations" and "Transmitter keys" sections, and
[plan 1](2026-11-22-unified-editing-editors-1-host-presets.md), including its
"After the build", before starting.

## Global Constraints

- Never write an em-dash, or an en-dash or double hyphen as sentence
  punctuation, in code, comments, tests, commits or the PR.
- Nothing written to the repo or GitHub names the tools used to write it:
  no tool attribution and no co-author trailers.
- The PR says `Refs #4527`.
- Goes live as it merges: no build switch (decision 6).
- The bar is `RecordEditBar` as it stands, tinted, no back arrow, Save
  disabled until there is a change (decision 2).
- An editor's Delete (here: Remove key) goes in a menu in the bar, runs
  through the operation gate, is disabled with "Save or cancel your changes
  first" while there are unsaved changes, and never shows on a new record
  (decision 3).
- Every editor closes when the active diver changes under it (decision 7);
  the host already does this.
- A draft holds the form as shown (texts as typed, choices as picked), never
  values converted back. An update writes only the fields whose text changed
  since the form was filled (`editorStartDraft`), on top of the record as
  stored at Save, read inside the sitting (plan 1, "After the build").
- Every new string goes into all 11 locales (`lib/l10n/arb/app_*.arb`), then
  `flutter gen-l10n`. This plan adds two: `cylinderConfigs_edit_notFound`
  and `transmitters_edit_notFound`.
- If a write listed as held cannot run inside the transaction, stop and
  raise it with Eric. Do not split the Save silently.
- Units shown follow the active diver's unit settings, as today.
- Keep every file under 800 lines; split by responsibility when one would
  pass it.
- Run only the test files you wrote or changed, by path. Never a folder,
  never the whole suite; the pre-push hook runs the rest.
- Never run `build_runner` with `--build-filter`.
- Run `dart format` on changed files before each commit.
- Never launch a dev build of the app (it can open the diver's real log or
  sync). Screenshots come from headless widget tests.
- Commit only on this branch; push and open the PR only with Eric's say-so.

## Review Focus

1. **A Save that fails partway writes nothing.** A cylinder configuration
   whose cylinder write throws after its config row was written leaves no
   config row (new) and the old name (edit); the page stays with every
   value. A transmitter save whose sibling setup write throws leaves the
   key as it was. Tests in Task 3 and Task 6.
2. **A takeover is one History entry for the key, then the fold.** Saving a
   serial an unclaimed downloaded key holds writes the key and its siblings
   in one operation labelled with the taken-over key's id; the placeholder
   fold, when it runs, is a second operation after it. A clash with a key
   that is set up writes nothing and shows the duplicate error under the
   serial, with Save still enabled. Tests in Task 6.
3. **The snackbar's Apply never rewrites dives without asking.** It shows
   the counts and the confirmation; Cancel writes nothing; on an unlocked
   item page with unsaved changes it is refused with "Save or cancel your
   changes first" and writes nothing. Tests in Task 7.
4. **Conversion never reads as a change, and a seed always does.** A
   configuration or key opened in cubic feet and psi and left alone has Save
   disabled and Back asks nothing; a new configuration from a unit, a new
   key prefilled with the item's serial, and a downloaded key not yet set
   up each open with Save enabled. Tests in Task 3 and Task 6.
5. **After-commit work survives the page closing.** The fold, the serial
   copy onto an item with none, and the findings refresh run after the page
   has gone, and read nothing through the page's `ref`. Test in Task 6.

---

### Task 0: Before screenshots

**Files:**
- Create (scratch, not committed): a throwaway golden harness in the
  session scratchpad, modelled on plan 1's (`scratchpad/phase4_shots_test.dart`
  in the sibling notes; copy it into `test/` only while capturing, then
  delete it)

- [ ] **Step 1: Capture the editors as they are today**

Headless captures of: the cylinder configuration editor (an existing one
with two cylinders; a new one opened from a unit), and the transmitter key
editor (an existing set-up key, showing Remove key at the end of the form;
a new key), each at phone width (390 x 844) and desktop width (1280 x 800),
light and dark. Save them outside the repo, named
`<nn>-<screen>-<width>-<theme>-before.png`.

- [ ] **Step 2: Check nothing is staged**

Run: `git status --short`
Expected: no new or changed file under `lib/` or `test/`.

---

### Task 1: The host gains seeds, a menu, a Save result and a refusal hook

**Files:**
- Modify: `lib/shared/widgets/record_editing/record_editor_host.dart`
- Create: `test/shared/widgets/record_editing/record_editor_host_harness.dart`
  (the fake editor page and its router, moved out of the host test so a
  second file can use them; not a test file)
- Modify: `test/shared/widgets/record_editing/record_editor_host_test.dart`
  (imports the harness; its tests unchanged)
- Test: `test/shared/widgets/record_editing/record_editor_host_menu_test.dart`

**Interfaces:**
- Consumes: plan 1's host; `recordOperationRunnerOf`,
  `recordOperationsAvailable`, `recordOperationMenuCaption`
  (`record_operation_gate.dart`); `RecordEditBar.actions`.
- Produces, for Tasks 3 and 6 and every later phase 4 plan:

```dart
/// A whole-record operation in an editor's bar menu (decision 3).
class RecordEditorOperation {
  const RecordEditorOperation({
    required this.key,
    required this.icon,
    required this.label,
    required this.run,
    this.destructive = false,
  });
  final Key key;
  final IconData icon;
  final String label;
  /// Asks its own confirmation, writes, and answers whether it wrote. The
  /// page leaves when it did.
  final Future<bool> Function() run;
  /// Drawn in the error colour, as a record page's Delete is.
  final bool destructive;
}

// New members of RecordEditorHost<W, D>:
void openEditor({D? from});   // was openEditor()
List<RecordEditorOperation> editorOperations(BuildContext context) =>
    const [];                 // editor supplies; none by default
Object? get editorSavedResult => null; // editor supplies; popped with on Save
bool editorSaveFailed(Object error) => false; // editor supplies
```

What each does (the tests pin each):

- `openEditor({D? from})`: with `from`, the sitting opens on `from` (the
  record before its seed) and the form as it reads now is handed to it at
  once, so a seed is a change and Save is enabled on the first frame. A
  `from` equal to the form is no change. Without `from`, as today.
- `editorOperations`: when non-empty and the editor is not creating,
  `editorScaffold` puts a `PopupMenuButton<int>` (key
  `ValueKey('recordEditorMenu')`, `Icons.more_vert`, tooltip
  `MaterialLocalizations.showMenuTooltip`) in `RecordEditBar.actions`: first
  `recordOperationMenuCaption` for the controller, then one `PopupMenuItem`
  per operation (a `ListTile` with icon and label, in the error colour when
  `destructive`), enabled only while `recordOperationsAvailable`. Choosing
  one runs it through `recordOperationRunnerOf(editorController, record:
  '$editorTable $editorRecordId')`; when it answers true the page leaves
  (`leaveEditor()`). The menu shows on a stored record only.
- `editorSavedResult`: read after a committed Save, after
  `afterEditorSaved`; the page pops with it (`Navigator.pop(result)`), so a
  caller that pushed the editor and awaits the push gets it. Back, Cancel
  and every other way of leaving pop with null.
- `editorSaveFailed(error)`: asked when a Save's write throws, before the
  host shows anything. True means the editor has shown the failure in its
  own form (the transmitter's duplicate serial): the host shows no snackbar.
  The page stays with every value either way.

- [ ] **Step 1: Move the harness, then write the failing tests**

Move `_FakeEditorPage`, its state and the router helper from
`record_editor_host_test.dart` into `record_editor_host_harness.dart` as
public `FakeEditorPage` and `pumpFakeEditor(...)`, adding constructor
options the new tests need (`seed`, `operations`, `savedResult`,
`failWith`, `handlesFailure`). Run the old test file to confirm it still
passes before adding anything. Then in `record_editor_host_menu_test.dart`:

```dart
testWidgets('a seeded new record opens with Save enabled', ...);
  // openEditor(from: blank) with the field prefilled: Save onPressed
  // non-null on the first frame; Cancel asks (showDiscardDialog).
testWidgets('a seed equal to the form is no change', ...);
testWidgets('the menu shows on a stored record and not on a new one', ...);
  // find.byKey(ValueKey('recordEditorMenu')) one / none.
testWidgets('the menu operation is disabled while there are changes', ...);
  // Type: the item is disabled and the caption reads
  // recordEdit_saveOrCancelFirst; typing back enables it again.
testWidgets('an operation that writes leaves the page', ...);
  // run returns true: the list page shows; nothing was written by Save.
testWidgets('an operation that writes nothing keeps the page', ...);
testWidgets('Save pops with the editor result', ...);
  // The list page pushed the editor with context.push<Object?>() and
  // recorded the result: it equals savedResult.
testWidgets('Back and Cancel pop with no result', ...);
testWidgets('a failure the editor shows itself shows no snackbar', ...);
  // failWith: StateError, handlesFailure: true: no SnackBar; page stays,
  // field text unchanged, Save enabled.
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/shared/widgets/record_editing/record_editor_host_menu_test.dart`
Expected: FAIL (`openEditor` takes no `from`; no `editorOperations`).

- [ ] **Step 3: Implement the four members in `record_editor_host.dart`**

`_pop` takes an optional result. In `saveEditor`, the failure branch asks
`editorSaveFailed(controller.saveError!)` before choosing the snackbar. Doc
comments in the voice of the file. The file stays under 800 lines; if it
would not, move the menu into `record_editor_menu.dart`.

- [ ] **Step 4: Run both host test files to see them pass**

Run: `flutter test test/shared/widgets/record_editing/record_editor_host_test.dart test/shared/widgets/record_editing/record_editor_host_menu_test.dart`
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

Run: `dart format` and `flutter analyze` on the four files.
Expected: no issues.

```bash
git add lib/shared/widgets/record_editing/record_editor_host.dart test/shared/widgets/record_editing/record_editor_host_harness.dart test/shared/widgets/record_editing/record_editor_host_test.dart test/shared/widgets/record_editing/record_editor_host_menu_test.dart
git commit -m "feat(record-editing): editor host seeds, bar menu and Save result"
```

---

### Task 2: A sitting can name the record it actually wrote

A transmitter takeover saves over the unclaimed key's row, so the id written
is not the one the sitting opened with (note, "Transmitter keys"). The
operation's label is written as the scope opens, before the body runs.

**Files:**
- Modify: `lib/core/services/change_log/record_sitting_writer.dart`
- Test: `test/core/services/change_log/record_sitting_writer_test.dart`

**Interfaces:**
- Consumes: `ChangeLogScope.currentOperationId`, `RecordEditLabel.encode`,
  `db.changeLogOperations`.
- Produces:

```dart
/// Inside [runRecordSitting]'s body: labels the running sitting with
/// [recordId] of [table] in place of the id it opened with. Does nothing
/// outside a scope.
Future<void> relabelRecordSitting({
  required String table,
  required String recordId,
  Iterable<String> changedCardIds = const [],
});
```

- [ ] **Step 1: Write the failing tests**

```dart
test('a sitting relabelled in its body is labelled with the new id', ...);
  // runRecordSitting(table: 'fake', recordId: 'a', body: write a row, then
  // relabelRecordSitting(table: 'fake', recordId: 'b')): after settleAll,
  // the one operation's label decodes to id 'b'.
test('a relabelled sitting that throws leaves no operation', ...);
test('relabelling outside a sitting does nothing', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/core/services/change_log/record_sitting_writer_test.dart`
Expected: FAIL, `relabelRecordSitting` is not defined.

- [ ] **Step 3: Implement `relabelRecordSitting`**

An update of the current operation's `label` column, by
`ChangeLogScope.currentOperationId`, on the transaction's executor. If the
change log triggers log that update, or the update cannot run inside the
transaction, stop and raise it.

- [ ] **Step 4: Run the tests to see them pass**

Run: `flutter test test/core/services/change_log/record_sitting_writer_test.dart`
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/core/services/change_log/record_sitting_writer.dart test/core/services/change_log/record_sitting_writer_test.dart
git commit -m "feat(change-log): a sitting can name the record it wrote"
```

---

### Task 3: Cylinder configurations on the host

**Files:**
- Modify: `lib/features/cylinder_configs/data/repositories/cylinder_config_repository.dart`
  (`createConfig`, about line 148)
- Modify: `lib/features/cylinder_configs/presentation/widgets/cylinder_config_item_editor.dart`
  (its text formatting becomes shared functions)
- Create: `lib/features/cylinder_configs/presentation/pages/cylinder_config_draft.dart`
- Modify: `lib/features/cylinder_configs/presentation/pages/cylinder_config_edit_page.dart`
- Modify: `lib/core/router/app_router.dart` (the `new` and `:configId` routes
  under `cylinder-configs`, about lines 846-859)
- Modify: the 11 `lib/l10n/arb/app_*.arb` files (`cylinderConfigs_edit_notFound`:
  "This configuration no longer exists.")
- Test: `test/features/cylinder_configs/data/cylinder_config_repository_test.dart`
- Test: `test/features/cylinder_configs/presentation/cylinder_config_draft_test.dart`
- Test: `test/features/cylinder_configs/presentation/cylinder_config_edit_page_test.dart`

**Interfaces:**
- Consumes: `RecordEditorHost` with `openEditor(from:)` (Task 1).
- Produces:
  - `CylinderConfigRepository.createConfig({String? id, String? diverId,
    String? equipmentId, required String name, String description = '',
    int sortOrder = 0})`: the row takes `id` when given, a fresh v4 uuid when
    not. Every other caller is unchanged.
  - In `cylinder_config_item_editor.dart`, top-level and used by both the
    item editor and the draft: `String cylinderVolumeText(UnitFormatter
    units, double? liters, double? workingPressureBar)`, `String
    cylinderPressureText(UnitFormatter units, double? bar)`, `String
    cylinderShareText(double percent)`. Bodies are today's `_volumeText`,
    `_pressureText` and `_trim`.
  - In `cylinder_config_draft.dart`:

```dart
typedef CylinderRowDraft = ({
  String id,
  String label,        // item.label ?? ''
  TankRole role,
  String volume,       // cylinderVolumeText
  String pressure,     // cylinderPressureText
  String o2,           // cylinderShareText
  String he,
  String mod,          // the MOD as TankModField fills its text, '' for none
  TankMaterial? material,
});

/// The editor's form as shown: name text, unit, cylinders in order.
class CylinderConfigDraft {
  const CylinderConfigDraft({required this.name, this.equipmentId,
      required this.rows});
  final String name;
  final String? equipmentId;
  final List<CylinderRowDraft> rows;
  // == and hashCode over name, equipmentId and listEquals(rows).
}

CylinderRowDraft cylinderRowDraft(CylinderConfigItem item, UnitFormatter units);
```

  A row's draft is built from the item the item editor emits, formatted the
  way its fields show it, so a value typed in cubic feet or psi and typed
  back reads as unchanged, and an untouched row never reads as changed.

- [ ] **Step 1: Write the failing tests, and retarget the old ones**

Repository:

```dart
test('createConfig writes the config under the id it is given', ...);
test('createConfig without an id still makes one', ...);
```

Draft (`cylinder_config_draft_test.dart`), with a cuft and psi
`UnitFormatter`:

```dart
test('a row of 11.1 L at 207 bar reads 81 cuft at 3000 psi', ...);
test('a row whose volume is typed back from cuft is equal to its start', ...);
  // 11.1 L stored; emitted item from "80" then "81": rows equal.
test('drafts differing only in row order are not equal', ...);
```

Page tests: add `setUpTestDatabase()` where missing. Tests that tap Save on
an untouched edit page change a field first. New:

```dart
testWidgets('the bar is the tinted Cancel and Save bar with no back arrow', ...);
testWidgets('a configuration opened in cuft and psi and left alone is unchanged', ...);
  // Save disabled; Back pops with no dialog. (Review Focus 4)
testWidgets('a new configuration with no cylinders and no name is unchanged', ...);
testWidgets('a new configuration from a unit opens with Save enabled', ...);
  // CylinderConfigEditPage(equipmentId: 'rb-1'): Save enabled; Cancel asks.
  // (Review Focus 4)
testWidgets('Back after renaming asks; Discard leaves the list', ...);
testWidgets('reordering the cylinders is a change; reordering back is not', ...);
testWidgets('Save writes config and cylinders in one change log operation', ...);
  // One change_log_operations row whose label decodes to table
  // 'cylinder_configs' and the config id.
testWidgets('a cylinder write that throws leaves no new configuration', ...);
  // A repository subclass whose saveItems throws: no cylinder_configs row,
  // page still open with its name, snackbar recordEdit_saveFailed.
  // (Review Focus 1)
testWidgets('a cylinder write that throws keeps the stored name', ...);
  // Edit: rename, saveItems throws: stored name unchanged. (Review Focus 1)
testWidgets('a new configuration is created under the page id', ...);
testWidgets('a rename keeps a cylinder changed in storage meanwhile', ...);
  // Rows untouched: saveItems not called; a volume written to the stored
  // item after the page opened survives.
testWidgets('a configuration deleted while open is refused at Save', ...);
  // Snackbar cylinderConfigs_edit_notFound; nothing written.
testWidgets('a configuration that is missing says so and goes back', ...);
testWidgets('a new configuration closes on a diver switch, writing nothing', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/cylinder_configs/data/cylinder_config_repository_test.dart test/features/cylinder_configs/presentation/cylinder_config_draft_test.dart test/features/cylinder_configs/presentation/cylinder_config_edit_page_test.dart`
Expected: FAIL (no `id` parameter, no draft file, no leave check).

- [ ] **Step 3: Add the `id` parameter, the draft and the shared text functions**

`createConfig` uses `id ?? _uuid.v4()`. The item editor calls the new
top-level functions in place of its private ones; nothing it shows changes.

- [ ] **Step 4: Move the page onto the host**

- Mix in `RecordEditorHost<CylinderConfigEditPage, CylinderConfigDraft>`:
  `editorTable` `'cylinder_configs'`, `editorStoredId` `widget.configId`,
  `editorTitle` today's `cylinderConfigs_new` or `cylinderConfigs_title`,
  `editorLeaveLocation` `'/equipment/cylinder-configs'`.
- `readEditorDraft()`: the name text, `_equipmentId`, and
  `cylinderRowDraft` of each of `_items` with the page's
  `unitFormatterProvider` value.
- New configuration: `openEditor` in `initState`; with `widget.equipmentId`
  set, `openEditor(from: <the same draft with equipmentId null>)`, so the
  unit is a seed. Stored configuration: `openEditor()` once `_load` has
  filled the form; a missing configuration says
  `cylinderConfigs_edit_notFound` and `leaveEditor()`, a load that throws
  says `recordEdit_loadFailed` and leaves, as the tank editor's
  `_leaveUnopened` does.
- The name controller's listener, and every `setState` that changes
  `_items` or `_equipmentId` (add, change, remove, reorder, unit), call
  `editorChanged()`.
- `validateEditor()` is `_formKey.currentState?.validate() ?? false`.
- `writeEditor(id)`:
  - New: `createConfig(id: id, diverId: editorDiverId, equipmentId:
    _equipmentId, name: <trimmed name>)`, then `saveItems(id, _items)` when
    there are any. A null `editorDiverId` throws `StateError` (a null
    diver_id hides the configuration from every diver-scoped list).
  - Stored: `getConfigById(id)` inside the sitting; null throws
    `RecordSittingRefusal((l10n) => l10n.cylinderConfigs_edit_notFound)`.
    Name and unit are written only when their draft values differ from
    `editorStartDraft`'s, on the stored row (`updateConfig(stored.copyWith(
    ...))`), and only when one of them changed. `saveItems` runs only when
    the rows differ from the start's; then each row whose draft equals its
    start row (same id) is written as the stored item with that id when it
    still exists, and every other row as the page's item.
- `afterEditorSaved(_)`: `invalidateCylinderConfigs(ref, configId:
  editorRecordId)`. No snackbar (there is none today).
- `build` returns `editorScaffold(context, body: ...)` with today's body;
  the `AppBar`, `AppBarTextAction` and `_saving` go. `dispose` calls
  `disposeEditor()` first.
- Both routes gain `onExit: confirmLeaveRecordSitting`.

- [ ] **Step 5: Add the string and generate**

Add `cylinderConfigs_edit_notFound` to all 11 arb files (English above;
each locale in its own words, as plan 1 did for `tankPresets_edit_notFound`),
then `flutter gen-l10n`.

- [ ] **Step 6: Run the tests to see them pass**

Run: the Step 2 command, plus
`flutter test test/features/cylinder_configs/presentation/cylinder_config_item_editor_test.dart test/features/cylinder_configs/presentation/unit_configurations_card_test.dart`
Expected: all pass, the existing ones included.

- [ ] **Step 7: Format, analyze, commit**

Run: `dart format` and `flutter analyze` on the changed files.
Expected: no issues.

```bash
git add lib/features/cylinder_configs lib/core/router/app_router.dart lib/l10n test/features/cylinder_configs
git commit -m "feat(cylinder-configs): edit a configuration on the shared Cancel and Save bar"
```

---

### Task 4: A key write that leaves the placeholder fold for later

**Files:**
- Modify: `lib/features/transmitters/data/services/transmitter_key_adoption.dart`
- Test: `test/features/transmitters/data/services/transmitter_key_adoption_test.dart`

**Interfaces:**
- Consumes: `TransmitterRepository.create`, `update`, `takeOverKey`;
  `EquipmentItemFold`.
- Produces:

```dart
/// A key written by [writeTransmitterKey]: the key as saved, and the
/// unclaimed key it took over, whose placeholder item may still be folded.
typedef TransmitterKeyWrite = ({Transmitter saved, Transmitter? tookOver});

/// [saveTransmitterKey] without the fold: safe inside a sitting.
Future<TransmitterKeyWrite> writeTransmitterKey(
  Transmitter entry, {
  required bool isNew,
  required TransmitterRepository repository,
});

/// The fold [adoptTransmitterKey] runs after a takeover, on its own:
/// best effort, logged, never throws. Does nothing when [write] took
/// nothing over or the placeholder is not a downloaded item.
Future<void> foldTakenOverPlaceholder(
  TransmitterKeyWrite write, {
  EquipmentItemFold? itemFold,
});
```

`saveTransmitterKey` and `adoptTransmitterKey` keep their signatures and
behaviour (the agent write family and their tests use them), now built from
the two: write, then fold. `tookOver` is the unclaimed key only when the
saved key has its id.

- [ ] **Step 1: Write the failing tests**

```dart
test('writeTransmitterKey takes over an unclaimed key without folding', ...);
  // The placeholder item is still there; tookOver is the unclaimed key.
test('foldTakenOverPlaceholder folds what the write took over', ...);
test('foldTakenOverPlaceholder does nothing for a plain write', ...);
test('a fold that throws is logged, not passed on', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/transmitters/data/services/transmitter_key_adoption_test.dart`
Expected: FAIL, the new functions are not defined.

- [ ] **Step 3: Split the functions**

- [ ] **Step 4: Run the tests to see them pass**

Run: the Step 2 command, plus `flutter test test/features/agent_access/data/writes/transmitter_writes_test.dart`.
Expected: all pass, the existing ones unchanged.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/transmitters/data/services/transmitter_key_adoption.dart test/features/transmitters/data/services/transmitter_key_adoption_test.dart
git commit -m "refactor(transmitters): write a key and fold its placeholder separately"
```

---

### Task 5: The transmitter key's draft and the key Save writes

The page is 808 lines today, so its draft and its parsing move to a file of
their own, as pure functions with unit tests.

**Files:**
- Create: `lib/features/transmitters/presentation/pages/transmitter_key_draft.dart`
- Test: `test/features/transmitters/presentation/pages/transmitter_key_draft_test.dart`

**Interfaces:**
- Produces, for Task 6:

```dart
typedef TransmitterKeyDraft = ({
  String serial,        // as typed, untrimmed
  String? computerId,
  String channel,       // as typed
  TankRole role,
  String? cylinderId,
  String? presetName,
  String volume,        // as shown, in the diver's unit
  String pressure,
  TankMaterial? material,
  bool configured,      // what Save will write: always true from the form
});

/// The key Save writes for [itemId]: a new key with [id] when [stored] is
/// null; otherwise [stored] with each field whose draft value differs from
/// [start]'s taken from [draft], the rest kept as stored. Labelled
/// [itemName], configured. Assumes the form has validated.
Transmitter transmitterKeyToSave({
  required TransmitterKeyDraft draft,
  required TransmitterKeyDraft? start,
  required Transmitter? stored,
  required String id,
  required String? diverId,
  required String itemId,
  required String itemName,
  required AppSettings settings,
  required DateTime now,
});
```

Field rules: the serial (trimmed; blank is none); computer and channel as a
pair (a channel only with a computer and a number of 1 or more, stored
zero-based); role; cylinder; preset; volume and working pressure as the tank
preset editor does (a pressure change in cubic feet also recomputes the
volume; cuft to litres is `cuft * 28.3168 / bar`); material. A new key, or
a `start` of null, takes every field from the draft.

- [ ] **Step 1: Write the failing tests**

```dart
test('a new key takes every field from the draft', ...);
test('an untouched volume in cuft keeps the stored litres', ...);
test('a pressure change in cuft recomputes the volume', ...);
test('a changed role keeps a serial changed in storage meanwhile', ...);
test('a channel with no computer is no channel', ...);
test('the saved key is labelled with the item name and configured', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/transmitters/presentation/pages/transmitter_key_draft_test.dart`
Expected: FAIL, the file does not exist.

- [ ] **Step 3: Implement `transmitter_key_draft.dart`**

Lift today's parsing from `_save` (`transmitter_edit_page.dart` lines
311-340) and `_validatedNumber`.

- [ ] **Step 4: Run the tests to see them pass**

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/transmitters/presentation/pages/transmitter_key_draft.dart test/features/transmitters/presentation/pages/transmitter_key_draft_test.dart
git commit -m "feat(transmitters): the key editor's draft and the key it saves"
```

---

### Task 6: Transmitter keys on the host

**Files:**
- Modify: `lib/features/transmitters/presentation/pages/transmitter_edit_page.dart`
- Create: `lib/features/transmitters/presentation/pages/transmitter_key_saved.dart`
- Modify: `lib/core/router/app_router.dart` (the `transmitter` and
  `:transmitterId` routes under `:equipmentId`, about lines 906-921)
- Modify: the 11 `lib/l10n/arb/app_*.arb` files (`transmitters_edit_notFound`:
  "This transmitter key no longer exists.")
- Modify: `test/features/transmitters/presentation/pages/transmitter_edit_page_test.dart`
- Test: `test/features/transmitters/presentation/pages/transmitter_edit_page_sitting_test.dart`

**Interfaces:**
- Consumes: Task 1 (`openEditor(from:)`, `editorOperations`,
  `editorSavedResult`, `editorSaveFailed`), Task 2
  (`relabelRecordSitting`), Task 4 (`writeTransmitterKey`,
  `foldTakenOverPlaceholder`), Task 5 (`TransmitterKeyDraft`,
  `transmitterKeyToSave`).
- Produces, for Task 7:

```dart
/// What a committed save of the key editor hands back to the page that
/// pushed it: whether to offer "Apply to existing dives" (a first setup,
/// a downloaded key confirmed, or a takeover).
class TransmitterKeySaved {
  const TransmitterKeySaved({required this.offerApply});
  final bool offerApply;
}
```

- [ ] **Step 1: Write the failing tests, and retarget the old ones**

In `transmitter_edit_page_test.dart`: tests that tap Save on an untouched
stored, configured key change a field first; the remove-key tests open the
bar menu (`ValueKey('recordEditorMenu')`) and choose Remove key; the two
post-save Apply tests (lines 701-758) move to Task 7. Its `_buildPage`
router gains `onExit: confirmLeaveRecordSitting` on the edit route.

In the new `transmitter_edit_page_sitting_test.dart` (same harness):

```dart
testWidgets('the bar is the tinted Cancel and Save bar with no close button', ...);
testWidgets('a set-up key opened in cuft and psi and left alone is unchanged', ...);
  // (Review Focus 4)
testWidgets('a new key prefilled with the item serial opens with Save enabled', ...);
testWidgets('a new key on an item with no serial and no keys is unchanged', ...);
testWidgets('a downloaded key not yet set up opens with Save enabled', ...);
  // isConfigured false: Save enabled at once; one tap writes isConfigured
  // true. (Review Focus 4)
testWidgets('Remove key is in the menu, disabled while there are changes', ...);
testWidgets('a new key has no menu', ...);
testWidgets('the key and its siblings are one change log operation', ...);
testWidgets('a sibling write that throws leaves the key as it was', ...);
  // A repository subclass whose saveSetup throws: the key's role unchanged
  // in storage; page open; snackbar recordEdit_saveFailed. (Review Focus 1)
testWidgets('a takeover is labelled with the key it took over', ...);
  // The unclaimed downloaded key on a placeholder item: one operation for
  // the save, its label's id the unclaimed key's; the fold, after it, is
  // another operation. (Review Focus 2)
testWidgets('a clash with a set-up key shows the duplicate under the serial', ...);
  // No snackbar; serial errorText transmitters_validation_duplicate; no
  // write; Save still enabled. (Review Focus 2)
testWidgets('the serial copy onto the item runs after the page has gone', ...);
  // Item with no serial: after Save the page is gone and the item gains
  // the key's serial; no error logged from a disposed ref. (Review Focus 5)
testWidgets('Save pops with offerApply for a first setup, not for an edit', ...);
testWidgets('a key deleted while open is refused at Save', ...);
testWidgets('a key that is missing says so and goes back', ...);
testWidgets('Back after changing the role asks before leaving', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/transmitters/presentation/pages/transmitter_edit_page_test.dart test/features/transmitters/presentation/pages/transmitter_edit_page_sitting_test.dart`
Expected: FAIL (close button still there, no menu, no leave check).

- [ ] **Step 3: Move the page onto the host**

- Mix in `RecordEditorHost<TransmitterEditPage, TransmitterKeyDraft>`:
  `editorTable` `'transmitters'`, `editorStoredId` `widget.transmitterId`,
  `editorTitle` today's `transmitters_edit_title` or
  `transmitters_new_title`, `editorLeaveLocation`
  `'/equipment/${widget.equipmentId}'`.
- `readEditorDraft()` reads the four controllers' text and the page's
  fields, with `configured: true`.
- `_load` fills the form as today, then opens the sitting:
  - a new key: `openEditor(from: <the draft of an empty form: blank texts,
    role backGas, nothing picked, configured true>)`, so the item's serial
    and the siblings' setup are a seed, and a key with neither is clean;
  - a stored key not set up (`!editing.isConfigured`): `openEditor(from:
    <the form's draft with configured false>)`;
  - any other stored key: `openEditor()`;
  - a stored key that is missing: `transmitters_edit_notFound`, then
    `leaveEditor()`; a load that throws: `recordEdit_loadFailed`, then
    `leaveEditor()`.
- Every controller's listener, and every `setState` that changes a draft
  field (computer, role, cylinder pick and clear, the role suggestion,
  preset, material), calls `editorChanged()`.
- `validateEditor()`: clears `_keyError` and `_duplicateError`, runs the
  form's validators, then today's serial-or-channel check (sets `_keyError`
  and answers false).
- `writeEditor(id)`: for a stored key, `getById` inside the sitting (null
  throws `RecordSittingRefusal((l10n) => l10n.transmitters_edit_notFound)`);
  `transmitterKeyToSave(...)` with `editorStartDraft`, the stored key and
  `editorDiverId` (a new key with a null diver throws `StateError`);
  `writeTransmitterKey`; when the saved id is not `id`,
  `relabelRecordSitting(table: 'transmitters', recordId: saved.id)`; then
  `saveSetup(widget.equipmentId, ..., exceptKeyId: saved.id)` with the
  saved key's setup. Keep the write's result and whether it offers Apply
  (`stored == null || !stored.isConfigured || tookOver != null`) in fields
  for after the commit.
- `editorSaveFailed(error)`: a `TransmitterConflictException` sets
  `_duplicateError` to `transmitters_validation_duplicate(e.existing.label)`
  and answers true; anything else false.
- `afterEditorSaved(_)`: reads from `ref`, before any await, everything the
  work after the page needs (the transmitter, equipment and equipment list
  notifier), then starts, unawaited and logged, in order: the fold
  (`foldTakenOverPlaceholder`), `scheduleConditionFindingsRefresh({widget
  .equipmentId})`, and the serial copy (today's `_fillItemSerial`, taking
  what it read as parameters) when the key has a serial and the item had
  none at load. No snackbar: the item page shows it (Task 7).
- `editorSavedResult`: `TransmitterKeySaved(offerApply: ...)`.
- `editorOperations`: for a stored key, one `RecordEditorOperation`
  (key `ValueKey('transmitter_remove_key')`, `Icons.delete_outline`,
  `transmitters_key_remove`, destructive) whose `run` is today's
  `_confirmRemoveKey` without its navigation, answering true when it
  removed the key. The body button and its `Align` go.
- `build` returns `editorScaffold(context, body: ...)` with today's form;
  the `AppBar`, close button, `AppBarTextAction` and `_loading` spinner
  logic for the bar go (the host shows the plain bar while loading).
  `dispose` calls `disposeEditor()` first.
- Both routes gain `onExit: confirmLeaveRecordSitting`.
- The page ends under 800 lines.

- [ ] **Step 4: Add the string and generate**

`transmitters_edit_notFound` in all 11 arb files, then `flutter gen-l10n`.

- [ ] **Step 5: Run the tests to see them pass**

Run: the Step 2 command.
Expected: all pass.

- [ ] **Step 6: Format, analyze, commit**

```bash
git add lib/features/transmitters/presentation/pages lib/core/router/app_router.dart lib/l10n test/features/transmitters/presentation/pages
git commit -m "feat(transmitters): edit a key on the shared Cancel and Save bar"
```

---

### Task 7: The snackbar's Apply is the Transmitter card's Apply

**Files:**
- Modify: `lib/features/transmitters/presentation/widgets/transmitter_section.dart`
- Test: `test/features/transmitters/presentation/widgets/transmitter_section_test.dart`

**Interfaces:**
- Consumes: `TransmitterKeySaved` (Task 6);
  `applyTransmitterSetupToExistingDives`; `recordOperationBlockOf`,
  `recordOperationRunnerOf`, `recordOperationReason`;
  `RecordEditScope.maybeOf<EquipmentItem>`.
- Produces: nothing new outside the file.

The card's three ways into the editor (Add key, a key row, Set up) push it
and await a `TransmitterKeySaved`. On one, the card shows
`transmitters_saved`, with a `transmitters_action_apply` action when
`offerApply`. The card's own Apply button and the snackbar's call one
function in the file:

```dart
/// The card's Apply, from its button or from the snackbar after a save:
/// refused with "Save or cancel your changes first" while the item page
/// holds unsaved changes or is busy; through the item page's operation gate
/// while it is unlocked; at once on a locked page or one with no editing.
/// The counts and the confirmation are applyTransmitterSetupToExistingDives'.
Future<void> _runApply(BuildContext context, WidgetRef ref, {
  required String equipmentId,
  required List<Transmitter> keys,
});
```

The button keeps its `RecordOperationButton` and stays disabled on a locked
page, as phase 3 left it. The snackbar's action reads the keys afresh
(`getForEquipment`) and the item page's controller at the moment it is
tapped, and does nothing when the card is no longer mounted.

- [ ] **Step 1: Write the failing tests**

Move the two post-save Apply tests from the editor's test file here,
driving the editor from the card. New:

```dart
testWidgets('a first setup saved shows Saved with Apply', ...);
testWidgets('an edit saved shows Saved with no Apply', ...);
testWidgets('the snackbar Apply shows the counts and asks first', ...);
  // TransmitterApplyDialog shown; the tank is unchanged until it is
  // confirmed; filled after. (Review Focus 3)
testWidgets('cancelling the snackbar Apply writes nothing', ...);
testWidgets('the snackbar Apply is refused while the item has changes', ...);
  // A RecordEditScope<EquipmentItem> whose controller is unlocked and
  // dirty: snackbar recordEdit_saveOrCancelFirst; no dialog; nothing
  // written. (Review Focus 3)
testWidgets('the snackbar Apply runs through the gate of an unlocked page', ...);
  // Unlocked and clean: the controller is operating while the dialog shows.
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/transmitters/presentation/widgets/transmitter_section_test.dart`
Expected: FAIL (the card shows no snackbar).

- [ ] **Step 3: Implement `_runApply` and the awaited pushes**

- [ ] **Step 4: Run the tests to see them pass**

Run: the Step 2 command, plus the two transmitter page test files.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/transmitters/presentation/widgets/transmitter_section.dart test/features/transmitters/presentation/widgets/transmitter_section_test.dart
git commit -m "feat(transmitters): the saved snackbar's Apply is the card's Apply"
```

---

### Task 8: After screenshots, review, and the question to Eric

- [ ] **Step 1: Capture the after shots**

The same screens, widths and themes as Task 0, with the same harness, named
`-after.png`. Add: a configuration with a change made (Save enabled), and
the transmitter key's bar menu open showing Remove key.

- [ ] **Step 2: Review the branch**

Run the `code-review` skill on the branch with `--max-findings all`. Fix
every valid finding test-first, one commit per fix or per related group.
Re-run only the test files touched.

- [ ] **Step 3: Write "After the build" into this plan and commit it**

What changed from the plan, for plan 3 to build on, as plan 1 did.

- [ ] **Step 4: Ask Eric before anything goes out**

Show the before and after shots and the review outcome, and ask whether to
push and open the PR.

- [ ] **Step 5: On his yes, push and open the PR**

Title: `feat(editing): cylinder configurations and transmitter keys get the
shared Cancel and Save bar (Unified Editing, phase 4, plan 2)`. Body: what
changed, `Refs #4527`, the design note and this plan linked, the screenshots
attached through the project's highest-numbered secret gist
(`PR screenshots: submersion-app/submersion (N)`, pngquant first,
`<pr>-<nn>-<screen>-<state>.png`, raw URLs pinned to the gist commit). Bind
the PR and report its checks.

## After the build

Built natively on 2026-11-22 (commits 7f7dfcb to the PR head). What changed
from this plan, for plan 3 to build on:

- **The menu lives in its own file.** `RecordEditorOperation` and the bar's
  `RecordEditorMenu` are in `record_editor_menu.dart`; the host re-exports
  `RecordEditorOperation`, so an editor imports only the host.
- **An editor leaves only once its route has come in.** A record found
  missing while its page was still being pushed popped mid-push, and on a
  route with `onExit` that trips a Navigator assertion. The host's `_pop`
  now waits for the route's push animation, then a frame. This was latent
  in plan 1's tank and weight editors too.
- **The host's fake editor is shared.** `EditorProbe` and `FakeEditorPage`
  are in `test/shared/widgets/record_editing/record_editor_host_harness.dart`;
  each test file keeps its own pump.
- **Widget tests read sittings by label.** `ChangeLogRepository().settleAll()`
  hangs inside `testWidgets`' fake time, so the tests select
  `change_log_operations` rows whose label starts `record_edit:`. A sitting
  that rolled back leaves an empty operation row until the log settles, so
  "nothing written" means no events under it, not no row.
- **The transmitter page is split** to stay under 800 lines:
  `transmitter_key_draft.dart` (the draft, `blankTransmitterKeyDraft`,
  `transmitterKeyToSave`, `transmitterDraftNamesKey`),
  `transmitter_key_after_save.dart` (`afterTransmitterKeySaved`: fold,
  findings refresh, serial copy, each read from `ref` before the page goes),
  `transmitter_key_saved.dart` and `transmitter_edit_routes.dart`.
- **The two key routes are siblings now** (`transmitter` and
  `transmitter/:transmitterId`), not parent and child: going to a key's
  address built the new-key editor beneath it, with a seeded sitting of its
  own. go_router's `push` builds only the leaf, `go` the whole chain.
- **A configuration's cylinders merge onto storage at Save.** A cylinder the
  diver left alone follows storage (kept, or gone when removed elsewhere), a
  cylinder they changed or added is written as the form has it, and one
  added elsewhere meanwhile stays. A configuration that fails to load logs
  why.
- **The card shows "Saved" through a messenger it holds before the push**,
  so the message survives the card being rebuilt; the Apply offer goes with
  the card that opened the editor.
- **The snackbar's Apply on a locked item page runs at once**, with its
  counts and confirmation, as the note reads; the card's own Apply button
  stays disabled while locked, as phase 3 left it.
- **A snackbar action is tapped, not called, in tests:** calling
  `onPressed()` leaves the snackbar up, and the next one queues behind it.
- **Review (code-review, high, all findings):** five findings, four fixed
  test-first (the cylinder merge, the sibling routes, the load log, the
  "Saved" message); a new key with no resolved diver refusing Save stays,
  as the rule every phase 4 editor follows.
- **Later review rounds on the PR (#4894)** changed this further:
  - A transmitter size in cubic feet with no working pressure is shown and
    read at the 200 bar the app assumes for a tank with none
    (`assumedWorkingPressureBar`, as `UnitFormatter.formatTankVolume`
    does); before, it was saved as that many litres.
  - Removing a key (`TransmitterRepository.delete`) runs in
    `ChangeLogScope.bulk` labelled `deleted_record`, as a record page's
    Delete does, so it is a labelled History entry of its own, and part of
    the item's operation when the item itself is deleted. A phase 4
    editor's menu operation needs its write labelled the same way.
  - The cylinder name looked up as the key editor opens is guarded: a
    failure is logged and the key opens without it.
  - The snackbar's Apply reads the item's keys afresh
    (`ref.refresh(...future)`), not the card's cached list.
  - The field note widget moved to
    `widgets/transmitter_field_note.dart` to keep the page under 800 lines.
  - Left as it was: the key editor shows a cylinder's ideal-gas capacity
    (81.1 cuft for 11.1 L at 207 bar), where the card shows the rated one
    (80); a test pins it.

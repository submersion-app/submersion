# Unified editing phase 4, plan 3: checklist templates and pre-dive templates

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the checklist template editor and the pre-dive template editor
onto the shared editor host, so each Save is one transaction and one History
entry, each asks before its changes are left behind, and a built-in pre-dive
template's View stays read only with no sitting.

**Architecture:** Both editors keep their forms, item dialogs and section
editors, and mix in plan 1's `RecordEditorHost<W, D>`. Each gets a draft of
its form as shown (header texts, sections and items in the order shown, with
no stamps), and a save function that reads the template, its sections and
its items as stored at Save, inside the sitting, and writes only what the
diver changed on top of them. A small shared helper merges an edited list of
rows onto the list as stored, so both editors (and later ones) apply the
same rule plan 2's cylinders do. Neither editor needs a seed, a menu or a
Save result.

**Tech Stack:** Flutter, Riverpod, go_router, Drift; the record editing
pieces in `lib/shared/widgets/record_editing/` and
`lib/core/services/change_log/record_sitting_writer.dart`.

**Spec:** [docs/design/specs/2026-11-22-unified-editing-phase-4-design.md](../specs/2026-11-22-unified-editing-phase-4-design.md)
(phase 4 of [the pattern](../specs/2026-11-14-unified-editing-pattern-design.md)).
Read its "What is generalised", "Rules every phase 4 editor follows",
"Checklist templates" and "Pre-dive templates" sections, and
[plan 1](2026-11-22-unified-editing-editors-1-host-presets.md) and
[plan 2](2026-11-22-unified-editing-editors-2-cylinder-configs-transmitters.md),
each with its "After the build", before starting.

## Global Constraints

- Never write an em-dash, or an en-dash or double hyphen as sentence
  punctuation, in code, comments, tests, commits or the PR. The two pages
  being changed carry `--` in old comments; rewrite any such comment you
  touch or move.
- Nothing written to the repo or GitHub names the tools used to write it:
  no tool attribution and no co-author trailers.
- The PR says `Refs #4527`.
- Goes live as it merges: no build switch (decision 6).
- The bar is `RecordEditBar` as it stands, tinted, no back arrow, Save
  disabled until there is a change (decision 2).
- Read-only views get no sitting: a built-in pre-dive template opens with a
  plain bar, a back arrow and no Save, as today (note, "Rules every phase 4
  editor follows").
- Every editor closes when the active diver changes under it (decision 7);
  the host already does this.
- A draft holds the form as shown, never values converted back or stamped:
  no `createdAt`, no `updatedAt` (the item dialogs stamp `updatedAt` on
  every OK), no `sortOrder` (Save assigns it from the order shown). An
  update writes only what changed since the form was filled
  (`editorStartDraft`), on top of the template as stored at Save, read
  inside the sitting.
- Every new string goes into all 11 locales (`lib/l10n/arb/app_*.arb`), then
  `flutter gen-l10n`. This plan adds two:
  `checklists_template_edit_notFound` and `preDive_edit_notFound`.
- If a write listed as held cannot run inside the transaction, stop and
  raise it with Eric. Do not split the Save silently. (The repositories'
  `saveSections` and `saveItems` open their own `_db.transaction`, which
  Drift nests as a savepoint inside the sitting's; plan 2's cylinders do
  the same.)
- Keep every file under 800 lines. `pre_dive_template_edit_page_test.dart`
  is already 1,112 lines: new tests for both editors go in new
  `_sitting_test.dart` files.
- Run only the test files you wrote or changed, by path. Never a folder,
  never the whole suite; the pre-push hook runs the rest.
- Never run `build_runner` with `--build-filter`.
- Run `dart format` on changed files before each commit.
- Never launch a dev build of the app (it can open the diver's real log or
  sync). Screenshots come from headless widget tests.
- Commit only on this branch; push and open the PR only with Eric's say-so.

## Shared code this plan changes

Plans 4 (rules and incidents) and 5 (diver profile and chamber form) are
written and built at the same time as this one, in sibling worktrees. The
host is used as plans 1 and 2 shipped it; this plan changes nothing in
`record_editor_host.dart`, `record_editor_menu.dart`, the leave guard, the
exit blocker or `record_sitting_writer.dart`.

- **Added:** `lib/shared/widgets/record_editing/editor_row_merge.dart`
  (`mergeEditorRows`, Task 1), a new file with one pure function. Nothing
  else imports it until this plan merges; plans 4 and 5 may adopt it after.
- **Added after review:** `lib/shared/widgets/section_list_editor.dart`
  gains an optional `onTitleChanged(sectionId, text)`, told of each
  keystroke in a section title (a rename still commits only when the field
  lets go). Additive: the trip checklist leaves it null and is unchanged.
- **Edited, shared with other plans:** `lib/core/router/app_router.dart`
  (`onExit` on four routes: `/checklist-templates/new`,
  `/checklist-templates/:templateId/edit`, `/pre-dive-checklists/new`,
  `/pre-dive-checklists/:templateId/edit`); the 11
  `lib/l10n/arb/app_*.arb` files (two keys:
  `checklists_template_edit_notFound`, `preDive_edit_notFound`) and the
  files `flutter gen-l10n` writes from them
  (`lib/l10n/arb/app_localizations.dart` and the 11
  `app_localizations_*.dart`). A clash in any of these after another plan
  merges is resolved by merging main in and keeping both sides, then
  running `flutter gen-l10n` again.

**Read-only views need no host support.** The host already draws a plain
`AppBar` (the editor's title, the back arrow, no actions) for as long as
`openEditor` has not run, and while unopened it holds no sitting:
`RecordEditLeaveGuard` is not in the tree, the exit blocker's controller is
locked and clean, the shortcut target answers `isCurrent` false (Escape and
Cmd or Ctrl+S do nothing), and the diver listener locks nothing. A
read-only view is therefore an editor that loads its record and never calls
`openEditor`, with `editorTitle` returning its view title while
`editorOpen` is false. The built-in pre-dive template does exactly this
(Task 6), and its test pins each point. Plan 4's read-only rule can do the
same with no shared change; if a later plan wants a named member for it, it
is additive (`bool get editorReadOnly`), not part of this plan.

## Review Focus

1. **A Save that fails partway writes nothing.** Today a template saves in
   three writes with no transaction. With a repository whose `saveItems`
   throws: a new template leaves no template row and no section rows; an
   edited one keeps its stored name and sections; the page stays with every
   value and says `recordEdit_saveFailed`. Tests in Task 4 and Task 6.
2. **Confirming an item unchanged is no change.** The item dialogs stamp
   `updatedAt` on every OK, and the pre-dive dialog reads its thresholds
   back from text. Opening an item and pressing OK without changing it
   leaves Save disabled, and a threshold such as `0.30000000000000004`
   shown as `0.3` keeps its stored value when something else is saved.
   Tests in Task 3, Task 5 and Task 6.
3. **A section removed elsewhere meanwhile does not break Save.**
   `section_id` is a foreign key. When sync removes a section while the
   editor is open and the diver changes an item, Save succeeds, and an item
   naming that section is written with no section (as the page already
   shows a dangling section). An item or section added elsewhere meanwhile
   is kept. Tests in Task 3 and Task 5.
4. **A built-in pre-dive template stays a viewer.** Its View shows the plain
   bar with a back arrow and no Save, Back leaves at once, Escape and
   Cmd or Ctrl+S do nothing, and nothing is written. Test in Task 6.
5. **A template that is gone is not created again.** Today a template id
   that no longer loads opens an empty form whose Save creates a new
   template under a fresh id. Now it says it no longer exists and goes back
   to the list; one deleted while open is refused at Save. Tests in Task 4
   and Task 6.

---

### Task 0: Before screenshots

**Files:**
- Create (scratch, not committed): a throwaway golden harness in the
  session scratchpad, modelled on plan 2's
  (`scratchpad/phase4_plan2_shots_test.dart` in the sibling notes); copy it
  into `test/` only while capturing, then delete it.

- [ ] **Step 1: Capture the editors as they are today**

Headless captures of: the checklist template editor (an existing template
with two sections and four items; a new one, empty), the pre-dive template
editor (an existing user template with a section and three items, one a
recorded value; a new one, empty) and a built-in pre-dive template's View,
each at phone width (390 x 844) and desktop width (1280 x 800), light and
dark. Save them outside the repo, named
`<nn>-<screen>-<width>-<theme>-before.png`.

- [ ] **Step 2: Check nothing is staged**

Run: `git status --short`
Expected: no new or changed file under `lib/` or `test/`.

---

### Task 1: A shared merge of edited rows onto storage

Plan 2 merged a configuration's cylinders onto storage inline. Both template
editors merge two lists each (sections, items) by the same rule, so the
rule moves into one pure function.

**Files:**
- Create: `lib/shared/widgets/record_editing/editor_row_merge.dart`
- Test: `test/shared/widgets/record_editing/editor_row_merge_test.dart`

**Interfaces:**
- Produces, for Tasks 3 and 5:

```dart
/// The rows a Save writes for a list the diver edited on a form, merged
/// onto the list as stored at Save, so a change made elsewhere meanwhile
/// (a sync) to a row the diver left alone is kept (issue #4527, phase 4):
///
/// - a form row whose draft equals its start draft (same id) follows
///   storage: the stored row with that id, or nothing when it was removed
///   elsewhere meanwhile;
/// - a form row the diver changed or added is written as the form has it;
/// - a start row missing from the form (the diver removed it) is not
///   written;
/// - a stored row neither the start nor the form had (added elsewhere
///   meanwhile) is kept, after the form's rows, in stored order.
///
/// With [startDrafts] null (a new record) every form row is written as the
/// form has it. [formRows] and [formDrafts] are parallel lists in the order
/// shown.
List<T> mergeEditorRows<T, R>({
  required List<T> formRows,
  required List<R> formDrafts,
  required List<R>? startDrafts,
  required List<T> storedRows,
  required String Function(T row) rowId,
  required String Function(R draft) draftId,
});
```

- [ ] **Step 1: Write the failing tests**

With `T` a small record `({String id, String text})` and `R` the same type
(a draft equal to its row):

```dart
test('a new record writes every form row as the form has it', ...);
test('a row left alone follows its stored copy', ...);
  // start a:'x', form a:'x', stored a:'y' (synced): result [a:'y'].
test('a row left alone that was removed elsewhere is dropped', ...);
test('a changed row is written as the form has it', ...);
  // start a:'x', form a:'z', stored a:'y': result [a:'z'].
test('a row added on the form is written', ...);
test('a row the diver removed is not written, even if changed elsewhere', ...);
test('a row added elsewhere is kept after the form rows', ...);
test('rows keep the form order, stored-only rows after them', ...);
  // form [b, a], stored [a, c, b]: result [b, a, c].
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/shared/widgets/record_editing/editor_row_merge_test.dart`
Expected: FAIL, the file does not exist.

- [ ] **Step 3: Implement `mergeEditorRows`**

Maps by id for the start drafts and the stored rows; one pass over the form
in order, then one over storage for the rows neither had.

- [ ] **Step 4: Run the tests to see them pass**

Run: the Step 2 command.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/shared/widgets/record_editing/editor_row_merge.dart test/shared/widgets/record_editing/editor_row_merge_test.dart
git commit -m "feat(record-editing): merge an editor's edited rows onto storage"
```

---

### Task 2: The checklist editor's item types and dialog in files of their own

No behaviour changes. The draft (Task 3) needs the editor's item and section
types, which are private to the page today, and the page gains the host in
Task 4. This mirrors the pre-dive editor, whose types and dialog are already
in `pre_dive_editable_item.dart` and `pre_dive_item_dialog.dart`.

**Files:**
- Create: `lib/features/checklists/presentation/pages/checklist_editable_item.dart`
- Create: `lib/features/checklists/presentation/pages/checklist_item_dialog.dart`
- Modify: `lib/features/checklists/presentation/pages/checklist_template_edit_page.dart`

**Interfaces:**
- Produces, for Tasks 3 and 4:
  - `EditableChecklistItem` (today's `_EditableTemplateItem`, same fields
    and `copyWith({Object? sectionId})`) and `EditableChecklistSection`
    (today's `_EditableTemplateSection`), in `checklist_editable_item.dart`.
  - `ChecklistItemDialog` (today's `_ChecklistItemDialog`, same
    constructor: `item`, `defaultSortOrder`, `sections`), in
    `checklist_item_dialog.dart`.

- [ ] **Step 1: Run the existing tests to see them pass before moving**

Run: `flutter test test/features/checklists/presentation/pages/checklist_template_edit_page_test.dart`
Expected: all pass.

- [ ] **Step 2: Move the types and the dialog**

Doc comments move with them, rewritten where they used `--` as
punctuation. The page imports both files.

- [ ] **Step 3: Run the tests again to see nothing changed**

Run: the Step 1 command.
Expected: all pass, unchanged.

- [ ] **Step 4: Format, analyze, commit**

```bash
git add lib/features/checklists/presentation/pages/checklist_editable_item.dart lib/features/checklists/presentation/pages/checklist_item_dialog.dart lib/features/checklists/presentation/pages/checklist_template_edit_page.dart
git commit -m "refactor(checklists): the template editor's item types and dialog in their own files"
```

---

### Task 3: The checklist template's draft and the writes its Save makes

**Files:**
- Create: `lib/features/checklists/presentation/pages/checklist_template_draft.dart`
- Create: `lib/features/checklists/presentation/pages/checklist_template_save.dart`
- Test: `test/features/checklists/presentation/pages/checklist_template_draft_test.dart`
- Test: `test/features/checklists/presentation/pages/checklist_template_save_test.dart`

**Interfaces:**
- Consumes: `mergeEditorRows` (Task 1); `EditableChecklistItem`,
  `EditableChecklistSection` (Task 2); `ChecklistTemplateRepository`
  (`getTemplateById`, `getSectionsForTemplate`, `getItemsForTemplate`,
  `createTemplate`, `updateTemplate`, `saveSections`, `saveItems`);
  `RecordSittingRefusal`.
- Produces, for Task 4:

```dart
// checklist_template_draft.dart

/// A section as the editor shows it.
typedef ChecklistSectionDraft = ({String id, String title});

/// An item as the editor shows it: no stamps, no sort order.
typedef ChecklistItemDraft = ({
  String id,
  String title,
  String? sectionId,
  String notes,
  int? dueOffsetDays,
});

/// The checklist template editor's form as shown: header texts as typed,
/// sections in order, items in the order shown (section by section, then
/// the unsectioned ones).
class ChecklistTemplateDraft {
  const ChecklistTemplateDraft({
    required this.name,
    required this.description,
    required this.sections,
    required this.items,
  });
  final String name;          // as typed, untrimmed
  final String description;
  final List<ChecklistSectionDraft> sections;
  final List<ChecklistItemDraft> items;
  // == and hashCode over name, description, listEquals(sections),
  // listEquals(items).
}

ChecklistTemplateDraft checklistTemplateDraft({
  required String name,
  required String description,
  required List<EditableChecklistSection> sections,
  required List<EditableChecklistItem> itemsInDisplayOrder,
});

// checklist_template_save.dart

/// Writes a checklist template editor's Save, inside its sitting. A new
/// template ([start] null) is created under [templateId] and [diverId] with
/// every section and item. A stored one is read as stored now; the name and
/// description are written only when their text changed from [start]'s,
/// the sections only when they differ from [start]'s, the items only when
/// they differ from [start]'s, each list merged onto
/// storage with [mergeEditorRows]. An item naming a section that is not
/// written is written with no section. Item sort order is its position.
/// Throws [RecordSittingRefusal] with `checklists_template_edit_notFound`
/// when the stored template is gone, and [StateError] for a new template
/// with no [diverId].
Future<void> writeChecklistTemplate({
  required ChecklistTemplateRepository repository,
  required String templateId,
  required String? diverId,
  required ChecklistTemplateDraft draft,
  required ChecklistTemplateDraft? start,
  required List<EditableChecklistSection> sections,
  required List<EditableChecklistItem> itemsInDisplayOrder,
});
```

The new-template case keeps today's behaviour (every section, every item,
in display order), now under the sitting's id. Header text is trimmed as
today.

- [ ] **Step 1: Write the failing tests**

Draft (`checklist_template_draft_test.dart`):

```dart
test('items differing only in their stamps are equal', ...);
  // Same fields, updatedAt one second apart: drafts equal.
test('items in another order are not equal', ...);
test('a renamed section is a change', ...);
test('a name with a trailing space is a change', ...);
  // The draft holds text as typed.
```

Save (`checklist_template_save_test.dart`, `setUpTestDatabase()`, the real
repository):

```dart
test('a new template is written under the given id with its lists', ...);
  // createTemplate under 'tpl-1', two sections, three items: sortOrder
  // 0..2 in display order; diverId as given.
test('a new template with no diver writes nothing and throws', ...);
test('a rename writes the name and leaves the lists alone', ...);
  // Lists unchanged: saveSections and saveItems not called (a counting
  // repository subclass); a description synced meanwhile is kept.
test('an item left alone keeps a title changed in storage meanwhile', ...);
  // Start and form have item a 'Fins'; storage now 'Long fins'; the diver
  // edits item b: a stays 'Long fins'.
test('an item added elsewhere meanwhile is kept', ...);
test('a section removed elsewhere leaves its items unsectioned', ...);
  // Storage loses section s; the diver edits an item in s: Save succeeds;
  // the item's sectionId is null. (Review Focus 3)
test('a template deleted meanwhile is refused', ...);
  // RecordSittingRefusal; nothing written.
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/checklists/presentation/pages/checklist_template_draft_test.dart test/features/checklists/presentation/pages/checklist_template_save_test.dart`
Expected: FAIL, the files do not exist.

- [ ] **Step 3: Implement the draft and `writeChecklistTemplate`**

Sections write through `saveSections` before items, as today (the items'
foreign key). The sections an item may name are the merged sections when
they are written, the stored ones otherwise.

- [ ] **Step 4: Run the tests to see them pass**

Run: the Step 2 command.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/checklists/presentation/pages/checklist_template_draft.dart lib/features/checklists/presentation/pages/checklist_template_save.dart test/features/checklists/presentation/pages/checklist_template_draft_test.dart test/features/checklists/presentation/pages/checklist_template_save_test.dart
git commit -m "feat(checklists): the template editor's draft and the writes its Save makes"
```

---

### Task 4: Checklist templates on the host

**Files:**
- Modify: `lib/features/checklists/presentation/pages/checklist_template_edit_page.dart`
- Modify: `lib/core/router/app_router.dart` (the `new` and
  `:templateId/edit` routes under `/checklist-templates`, about lines
  2213-2225)
- Modify: the 11 `lib/l10n/arb/app_*.arb` files
  (`checklists_template_edit_notFound`: "This template no longer exists.")
- Modify: `test/features/checklists/presentation/pages/checklist_template_edit_page_test.dart`
- Test: `test/features/checklists/presentation/pages/checklist_template_edit_page_sitting_test.dart`

**Interfaces:**
- Consumes: `RecordEditorHost` (plan 1, with plan 2's members unused);
  Tasks 2 and 3.
- Produces: nothing new outside the page.

- [ ] **Step 1: Write the failing tests, and retarget the old ones**

In the existing test file: tests that tap Save find it in the bar
(`RecordEditBar`); a test that saves an untouched form changes a field
first. Its cases stay.

In the new `checklist_template_edit_page_sitting_test.dart` (the template
list under a `GoRouter`, the editor pushed onto it with `context.push`, the
edit route carrying `onExit: confirmLeaveRecordSitting`, as plan 2's
transmitter tests do):

```dart
testWidgets('the bar is the tinted Cancel and Save bar with no back arrow', ...);
testWidgets('a stored template left alone has Save disabled and Back asks nothing', ...);
testWidgets('an item opened and confirmed unchanged is no change', ...);
  // Open item, OK: Save still disabled. (Review Focus 2)
testWidgets('a new template with nothing entered closes on Cancel at once', ...);
testWidgets('Back after renaming asks; Keep editing keeps the name', ...);
testWidgets('moving an item and moving it back is no change', ...);
testWidgets('Save writes the template, sections and items in one change log operation', ...);
  // One change_log_operations row labelled record_edit: whose label
  // decodes to table 'checklist_templates' and the template id, with
  // events for the template, a section and an item under it.
testWidgets('an item write that throws leaves no new template', ...);
  // checklistTemplateRepositoryProvider overridden with a subclass whose
  // saveItems throws: no checklist_templates row and no section rows; page
  // open with its name; snackbar recordEdit_saveFailed. (Review Focus 1)
testWidgets('an item write that throws keeps the stored name and sections', ...);
  // (Review Focus 1)
testWidgets('a new template is created under the page id', ...);
testWidgets('a template deleted while open is refused at Save', ...);
  // Snackbar checklists_template_edit_notFound; nothing written.
testWidgets('a template that is missing says so and goes back to the list', ...);
  // Not created again on any path. (Review Focus 5)
testWidgets('a new template closes on a diver switch, writing nothing', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/checklists/presentation/pages/checklist_template_edit_page_test.dart test/features/checklists/presentation/pages/checklist_template_edit_page_sitting_test.dart`
Expected: FAIL (no tinted bar, no leave check, three writes).

- [ ] **Step 3: Move the page onto the host**

- Mix in `RecordEditorHost<ChecklistTemplateEditPage, ChecklistTemplateDraft>`:
  `editorTable` `'checklist_templates'`, `editorStoredId`
  `widget.templateId`, `editorTitle` today's
  `checklists_templates_addTemplate` or `checklists_templates_editTemplate`,
  `editorLeaveLocation` `'/checklist-templates'`.
- `readEditorDraft()`: `checklistTemplateDraft(...)` of the two
  controllers' text, `_sections` and `_itemsInDisplayOrder()`.
- New template: `openEditor()` in `initState`. Stored template:
  `openEditor()` once `_load` has filled the form. A template that is
  missing says `checklists_template_edit_notFound` and `leaveEditor()`; a
  load that throws logs it, says `recordEdit_loadFailed` and leaves, as the
  cylinder configuration editor's `_leaveUnopened` does. `_existing` goes.
- Both controllers' listeners, and every `setState` that changes
  `_sections` or `_items` (the item dialog's result, and each
  `SectionListEditor` callback), call `editorChanged()`.
- `validateEditor()` is `_formKey.currentState?.validate() ?? false`.
- `writeEditor(id)`: `writeChecklistTemplate(...)` with `editorDiverId`,
  `readEditorDraft()`, `editorStartDraft` (null when creating), `_sections`
  and `_itemsInDisplayOrder()`.
- No `afterEditorSaved`: the template list and the trip checklist pickers
  read templates through providers that refresh on the tables' changes,
  and there is no snackbar today.
- `build` returns `editorScaffold(context, body: ...)` with today's body;
  the `AppBar`, `AppBarTextAction` and `_loading` bar logic go (the host
  shows the plain bar while loading). `dispose` calls `disposeEditor()`
  first.
- Both routes gain `onExit: confirmLeaveRecordSitting`.

- [ ] **Step 4: Add the string and generate**

Add `checklists_template_edit_notFound` to all 11 arb files (English above;
each locale in its own words, as plans 1 and 2 did), with its `@`
description in `app_en.arb`, then `flutter gen-l10n`.

- [ ] **Step 5: Run the tests to see them pass**

Run: the Step 2 command, plus
`flutter test test/features/checklists/presentation/pages/checklist_templates_page_test.dart`
Expected: all pass, the existing ones included.

- [ ] **Step 6: Format, analyze, commit**

Run: `dart format` and `flutter analyze` on the changed files.
Expected: no issues.

```bash
git add lib/features/checklists/presentation/pages/checklist_template_edit_page.dart lib/core/router/app_router.dart lib/l10n test/features/checklists/presentation/pages/checklist_template_edit_page_test.dart test/features/checklists/presentation/pages/checklist_template_edit_page_sitting_test.dart
git commit -m "feat(checklists): edit a template on the shared Cancel and Save bar"
```

---

### Task 5: The pre-dive template's draft and the writes its Save makes

**Files:**
- Create: `lib/features/pre_dive/presentation/pages/pre_dive_template_draft.dart`
- Create: `lib/features/pre_dive/presentation/pages/pre_dive_template_save.dart`
- Test: `test/features/pre_dive/presentation/pages/pre_dive_template_draft_test.dart`
- Test: `test/features/pre_dive/presentation/pages/pre_dive_template_save_test.dart`

**Interfaces:**
- Consumes: `mergeEditorRows` (Task 1);
  `EditablePreDiveItem`, `EditablePreDiveSection`;
  `PreDiveTemplateRepository` (the same seven methods as Task 3's);
  `formatDecimalForInput` (`lib/core/utils/number_input.dart`).
- Produces, for Task 6:

```dart
// pre_dive_template_draft.dart

/// A section as the editor shows it.
typedef PreDiveSectionDraft = ({String id, String title});

/// A pre-dive item as the editor shows it: no stamps, no sort order, the
/// thresholds as the item dialog shows them.
typedef PreDiveItemDraft = ({
  String id,
  String? sectionId,
  String title,
  String notes,
  PreDiveItemType itemType,
  String? valueLabel,
  String? valueUnit,
  String valueMin,      // formatDecimalForInput, '' for none
  String valueMax,
  bool isRequired,
  String? equipmentId,
  String? sourceItemId,
});

class PreDiveTemplateDraft {
  const PreDiveTemplateDraft({
    required this.name,
    required this.description,
    required this.category,
    required this.strictOrder,
    required this.sections,
    required this.items,
  });
  final String name;          // as typed
  final String description;
  final String category;
  final bool strictOrder;
  final List<PreDiveSectionDraft> sections;
  final List<PreDiveItemDraft> items;   // in the order shown
  // == and hashCode over every field, lists by listEquals.
}

PreDiveTemplateDraft preDiveTemplateDraft({
  required String name,
  required String description,
  required String category,
  required bool strictOrder,
  required List<EditablePreDiveSection> sections,
  required List<EditablePreDiveItem> itemsInDisplayOrder,
});

// pre_dive_template_save.dart

/// [writeChecklistTemplate] for a pre-dive template: the same rules, with
/// category (blank is none) and strict order as header fields. Throws
/// [RecordSittingRefusal] with `preDive_edit_notFound` when the stored
/// template is gone.
Future<void> writePreDiveTemplate({
  required PreDiveTemplateRepository repository,
  required String templateId,
  required String? diverId,
  required PreDiveTemplateDraft draft,
  required PreDiveTemplateDraft? start,
  required List<EditablePreDiveSection> sections,
  required List<EditablePreDiveItem> itemsInDisplayOrder,
});
```

An item whose draft is unchanged is written as stored, so a threshold the
dialog would read back from its shown text keeps its stored value.

- [ ] **Step 1: Write the failing tests**

Draft:

```dart
test('items differing only in their stamps are equal', ...);
test('a threshold of 0.30000000000000004 and one of 0.3 draft alike', ...);
test('turning strict order on is a change', ...);
test('a cleared source link is a change', ...);
```

Save (`setUpTestDatabase()`, the real repository):

```dart
test('a new template is written under the given id with its lists', ...);
  // Category blank is stored null; strict order as given; items' sort
  // order in display order.
test('a new template with no diver writes nothing and throws', ...);
test('an untouched threshold keeps its stored value', ...);
  // Stored valueMin 0.30000000000000004; the diver edits another item:
  // the stored value is unchanged. (Review Focus 2)
test('turning strict order on keeps a name synced meanwhile', ...);
test('an item left alone keeps a change made in storage meanwhile', ...);
test('a section removed elsewhere leaves its items unsectioned', ...);
  // (Review Focus 3)
test('a template deleted meanwhile is refused', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/pre_dive/presentation/pages/pre_dive_template_draft_test.dart test/features/pre_dive/presentation/pages/pre_dive_template_save_test.dart`
Expected: FAIL, the files do not exist.

- [ ] **Step 3: Implement the draft and `writePreDiveTemplate`**

As Task 3's, with today's category rule (`trim()`, empty is null).

- [ ] **Step 4: Run the tests to see them pass**

Run: the Step 2 command.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/pre_dive/presentation/pages/pre_dive_template_draft.dart lib/features/pre_dive/presentation/pages/pre_dive_template_save.dart test/features/pre_dive/presentation/pages/pre_dive_template_draft_test.dart test/features/pre_dive/presentation/pages/pre_dive_template_save_test.dart
git commit -m "feat(pre-dive): the template editor's draft and the writes its Save makes"
```

---

### Task 6: Pre-dive templates on the host, built-ins still read only

**Files:**
- Modify: `lib/features/pre_dive/presentation/pages/pre_dive_template_edit_page.dart`
- Modify: `lib/core/router/app_router.dart` (the `new` and
  `:templateId/edit` routes under `/pre-dive-checklists`, about lines
  2234-2246)
- Modify: the 11 `lib/l10n/arb/app_*.arb` files (`preDive_edit_notFound`:
  "This checklist no longer exists.")
- Modify: `test/features/pre_dive/presentation/pages/pre_dive_template_edit_page_test.dart`
- Test: `test/features/pre_dive/presentation/pages/pre_dive_template_edit_page_sitting_test.dart`

**Interfaces:**
- Consumes: `RecordEditorHost`; Task 5.
- Produces: nothing new outside the page.

- [ ] **Step 1: Write the failing tests, and retarget the old ones**

In the existing test file: Save is found in the bar; a test that saves an
untouched form changes a field first. The loading-frame group keeps its
claims: while a template loads the plain bar shows the View title and no
Save; a built-in never shows the tinted bar; "a brand new template still
gets Save immediately" becomes "a brand new template shows the tinted bar
on its first frame" (Save shown, disabled until a change, looked up with
`skipOffstage: false`). Its other cases stay.

In the new `pre_dive_template_edit_page_sitting_test.dart` (the template
list under a `GoRouter`, the editor pushed, the edit route carrying
`onExit: confirmLeaveRecordSitting`):

```dart
testWidgets('a user template shows the tinted Cancel and Save bar', ...);
testWidgets('a built-in View has the plain bar, a back arrow and no Save', ...);
  // No RecordEditBar; BackButton found; Back leaves at once; Escape and
  // Cmd+S do nothing; no change_log_operations row. (Review Focus 4)
testWidgets('a stored template left alone has Save disabled and Back asks nothing', ...);
testWidgets('an item opened and confirmed unchanged is no change', ...);
  // A recorded value item with thresholds. (Review Focus 2)
testWidgets('toggling strict order is a change; toggling back is not', ...);
testWidgets('deleting a source item is a change that clears its dependant', ...);
  // The source-cleared snackbar still shows; Save enabled.
testWidgets('Save writes the template, sections and items in one change log operation', ...);
  // Label decodes to table 'pre_dive_checklist_templates' and the id.
testWidgets('an item write that throws leaves no new template', ...);
  // (Review Focus 1)
testWidgets('an item write that throws keeps the stored template', ...);
  // (Review Focus 1)
testWidgets('a template deleted while open is refused at Save', ...);
testWidgets('a template that is missing says so and goes back to the list', ...);
  // (Review Focus 5)
testWidgets('a new template closes on a diver switch, writing nothing', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/pre_dive/presentation/pages/pre_dive_template_edit_page_test.dart test/features/pre_dive/presentation/pages/pre_dive_template_edit_page_sitting_test.dart`
Expected: FAIL (no tinted bar, no leave check, three writes).

- [ ] **Step 3: Move the page onto the host**

- Mix in `RecordEditorHost<PreDiveTemplateEditPage, PreDiveTemplateDraft>`:
  `editorTable` `'pre_dive_checklist_templates'`, `editorStoredId`
  `widget.templateId`, `editorLeaveLocation` `'/pre-dive-checklists'`.
- `editorTitle`: `preDive_edit_titleNew` when creating;
  `preDive_edit_titleEdit` once `editorOpen`; `preDive_edit_titleView`
  otherwise (loading, or a built-in), which keeps today's loading-frame
  rule that no edit title is claimed before it is known.
- `_readOnly` stays the built-in flag of the loaded template, kept in a
  field (`_builtIn`) once `_existing` goes; `_editable` becomes
  `editorOpen`.
- New template: `openEditor()` in `initState`. Stored template, once `_load`
  has filled the form: a built-in does not open the sitting (the host keeps
  its plain bar, with the back arrow and no Save); any other opens it with
  `openEditor()`. Missing: `preDive_edit_notFound` and `leaveEditor()`; a
  load that throws: logged, `recordEdit_loadFailed`, `leaveEditor()`.
- The three controllers' listeners, the strict order switch, and every
  `setState` that changes `_sections` or `_items` (the item dialog's
  result, `_removeItems`, each `SectionListEditor` callback) call
  `editorChanged()`.
- `validateEditor()`, `writeEditor(id)` as Task 4's, with
  `writePreDiveTemplate`.
- `build` returns `editorScaffold(context, body: ...)` with today's body;
  the `AppBar` and `AppBarTextAction` go. `dispose` calls
  `disposeEditor()` first.
- Both routes gain `onExit: confirmLeaveRecordSitting`. A built-in View has
  no sitting, so the route lets it go without asking.

- [ ] **Step 4: Add the string and generate**

`preDive_edit_notFound` in all 11 arb files, then `flutter gen-l10n`.

- [ ] **Step 5: Run the tests to see them pass**

Run: the Step 2 command, plus
`flutter test test/features/pre_dive/presentation/pages/pre_dive_templates_page_test.dart test/features/pre_dive/presentation/pages/pre_dive_templates_page_hide_test.dart`
Expected: all pass.

- [ ] **Step 6: Format, analyze, commit**

```bash
git add lib/features/pre_dive/presentation/pages/pre_dive_template_edit_page.dart lib/core/router/app_router.dart lib/l10n test/features/pre_dive/presentation/pages/pre_dive_template_edit_page_test.dart test/features/pre_dive/presentation/pages/pre_dive_template_edit_page_sitting_test.dart
git commit -m "feat(pre-dive): edit a template on the shared Cancel and Save bar"
```

---

### Task 7: After screenshots, review, and the question to Eric

- [ ] **Step 1: Capture the after shots**

The same screens, widths and themes as Task 0, with the same harness, named
`-after.png`. Add: a template with a change made (Save enabled), and the
discard question after Back with changes.

- [ ] **Step 2: Review the branch**

Run the `code-review` skill on the branch with `--max-findings all`. Fix
every valid finding test-first, one commit per fix or per related group.
Re-run only the test files touched.

- [ ] **Step 3: Write "After the build" into this plan and commit it**

What changed from the plan, for plan 4 (rules and incidents) to build on,
as plans 1 and 2 did.

- [ ] **Step 4: Ask Eric before anything goes out**

Show the before and after shots and the review outcome, and ask whether to
push and open the PR.

- [ ] **Step 5: On his yes, push and open the PR**

Title: `feat(editing): checklist and pre-dive templates get the shared
Cancel and Save bar (Unified Editing, phase 4, plan 3)`. Body: what
changed, `Refs #4527`, the design note and this plan linked, the
screenshots attached through the project's highest-numbered secret gist
(`PR screenshots: submersion-app/submersion (N)`, pngquant first,
`<pr>-<nn>-<screen>-<state>.png`, raw URLs pinned to the gist commit). Bind
the PR and report its checks.

## After the build

Built natively on 2026-11-22 (commits 9c46a78 to the branch head). What
changed from this plan, for plan 4 (rules and incidents) and plan 5 to build
on:

- **The host is unchanged, as planned.** A read-only view is an editor that
  loads and never calls `openEditor`. Its title must not follow
  `editorOpen`: the controller locks as a page leaves (a Save, a discard, a
  change of diver), so a title read from the sitting turns to the view
  title during the exit animation. The pre-dive editor reads it from what
  was loaded (`_loaded && !_builtIn`); a test steps the exit frame by frame.
- **Each not-found string landed with its save function** (Tasks 3 and 5),
  since the refusal needs it, and sits beside its feature's keys in each
  arb file rather than at the end, to stay clear of other plans' strings.
- **The writers number the items they write by position.** A merged stored
  row carries its stored `sortOrder`; the repositories renumber anyway, but
  a caller (or a test fake) reading the list gets the order shown.
- **A threshold drafts locale-free** (15 significant digits, a dot), so a
  change of number locale while the editor is open is no change.
- **An untouched template is no longer rewritten.** Before, every Save
  rewrote both lists in display order; every view groups items by section
  and the editor shows stored order within one, so nothing visible is lost.
- **The checklist editor's item types and dialog are public**
  (`EditableChecklistItem`, `EditableChecklistSection`,
  `ChecklistItemDialog`), as the pre-dive editor's already were.
- **Old test files needed:** a database in `setUp` even with a fake
  repository (Save is a transaction and a change log operation); a diver
  for a new template (it refuses Save with none); a field changed before
  any Save (an untouched form, or an item confirmed unchanged, is no
  change); a `pump()` between typing and Save; dialog buttons scoped to the
  dialog (the bar has its own Cancel). A drag in the pre-dive reorder test
  never reordered anything; it passed before only because Save wrote
  everything. The section editor also moves rows with up and down arrows,
  which tests can tap.
- **The test database seeds six pre-dive templates**, so a rollback test
  counts rows before and after rather than expecting none.
- **Review (code-review, high, all findings):** three findings. Fixed
  test-first: the title flash above, and the locale-dependent threshold
  text. No change: an untouched template's stored sort order is no longer
  renumbered by a no-op Save (nothing shows it).
- **A second review (code-review, xhigh, all findings, after the PR
  opened):** six findings, all fixed. A section title being typed is now a
  change: the section editor reports each keystroke (`onTitleChanged`),
  and each page drafts and saves from the titles as shown, trimmed, the old
  title when typed blank. An item's draft is built as its dialog would
  write it (trimmed text, no dangling section, no value fields, device or
  source its type does not use), so a stored item in another form confirmed
  unchanged is no change. A section the diver changed that was deleted
  elsewhere is created again and the items the form shows in it go back in
  with it. Stale doc comments, the first-frame test and the new strings'
  `@` descriptions were brought up to date.
- **A third review (code-review, xhigh, all findings):** two findings,
  both fixed test-first. A re-created section takes back only the items its
  delete left with no section, each otherwise as stored (a title synced in
  meanwhile is kept, an item moved elsewhere stays). The item dialog's
  section picker offers a title as it is being typed.

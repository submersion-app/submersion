# Unified editing phase 4, plan 4: rules and incidents

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the logbook rule editor and the near-miss incident editor
onto the shared editor host, so each Save is one transaction and one History
entry, each asks before its changes are left behind, and the incident's
Save and Delete move into the bar.

**Architecture:** Both editors mix in plan 1's `RecordEditorHost` as plan 2
left it. The rule's draft holds its name, triggers, condition tree and
actions as the editor shows them, compared by value. The incident's draft
holds its fields as picked and typed. Each update writes only what changed
since the form was filled, as named columns on the row as stored (a column
patch in each repository), never a copy loaded when the page opened. A rule
that cannot be saved (newer version, unknown action) never opens a sitting.

**Tech Stack:** Flutter, Riverpod, go_router, Drift; the record editing
pieces in `lib/shared/widgets/record_editing/` and
`lib/core/services/change_log/record_sitting_writer.dart`.

**Spec:** [docs/design/specs/2026-11-22-unified-editing-phase-4-design.md](../specs/2026-11-22-unified-editing-phase-4-design.md)
(phase 4 of [the pattern](../specs/2026-11-14-unified-editing-pattern-design.md)).
Read its "What is generalised", "Rules every phase 4 editor follows",
"Rules" and "Incidents" sections, and plans
[1](2026-11-22-unified-editing-editors-1-host-presets.md) and
[2](2026-11-22-unified-editing-editors-2-cylinder-configs-transmitters.md),
each including its "After the build", before starting.

## Global Constraints

- Never write an em-dash, or an en-dash or double hyphen as sentence
  punctuation, in code, comments, tests, commits or the PR.
- Nothing written to the repo or GitHub names the tools used to write it:
  no tool attribution and no co-author trailers.
- The PR says `Refs #4527`.
- Goes live as it merges: no build switch (decision 6).
- The bar is `RecordEditBar` through the host, tinted, no back arrow
  (decision 2).
- The incident's Delete goes in the host's bar menu, runs through the
  operation gate, is disabled with "Save or cancel your changes first" while
  there are unsaved changes, never shows on a new incident, and is labelled
  `ChangeLogLabels.deletedRecord` in History (decision 3; plan 2, "After the
  build").
- Every editor closes when the active diver changes under it (decision 7);
  the host already does this.
- A draft holds the form as shown, never values converted back or encoded
  (`conditionJson`, `actionsJson`, `updatedAt`). An update writes only the
  fields whose draft value changed since the form was filled
  (`editorStartDraft`), as columns on the row as stored at Save.
- List actions are unchanged: rule reorder, enabled switch, run on all,
  duplicate, delete; the rule history page's undo, delete run and clear.
- Every new string goes into all 11 locales (`lib/l10n/arb/app_*.arb`), then
  `flutter gen-l10n`. This plan adds `rules_edit_notFound` and removes
  `incidentEdit_save`, which nothing else uses.
- If a write listed as held cannot run inside the transaction, stop and
  raise it with Eric. Do not split the Save silently.
- Units shown follow the active diver's unit settings, as today (the rule's
  action values and match count, the incident's date).
- Keep every file under 800 lines; split by responsibility when one would
  pass it.
- Run only the test files you wrote or changed, by path. Never a folder,
  never the whole suite; the pre-push hook runs the rest.
- Never run `build_runner` with `--build-filter`.
- Never rebase, never force-push, never `git add -A` or bare `git stash`;
  stage explicit paths.
- Run `dart format` on changed files before each commit.
- Never launch a dev build of the app (it can open the diver's real log or
  sync). Screenshots come from headless widget tests.
- Commit only on this branch; push and open the PR only with Eric's say-so.

## Working alongside plans 3 and 5

Plans 3 (checklist and pre-dive templates) and 5 (diver profile, chamber
form) are written and built at the same time, each on a branch from the same
main. Whichever merges later merges main in (never a rebase) and adapts.

### Shared code this plan changes

- `lib/shared/widgets/record_editing/record_editor_host.dart`: one new
  member, `bool get editorCanSave => true;`, read in two places (the bar's
  `canSave` and `saveEditor`'s early return). Additive; every existing
  editor keeps its behaviour (Task 1). **Pending Eric's choice**, see
  "Choices for Eric" below: with option A this file is not touched.
- `test/shared/widgets/record_editing/record_editor_host_harness.dart`: one
  new `EditorProbe` field, `canSave` (built there, beside the probe's other
  options, rather than as a `FakeEditorPage` constructor parameter; Task 1,
  option B only).
- `lib/core/router/app_router.dart`: `onExit: confirmLeaveRecordSitting` on
  the four routes `/rules/new`, `/rules/:id`, `/incidents/new` and
  `/incidents/:incidentId`. No other route changes.
- The 11 `lib/l10n/arb/app_*.arb` files and the generated
  `app_localizations*.dart`: one key added, one removed.

Nothing else outside `lib/features/rules/` and `lib/features/safety/` (and
their tests) changes. No change log, sitting writer, leave guard, exit
blocker or menu code changes.

### Read-only rules stay local

The host already supports a page that never opens its sitting: before
`openEditor` its `editorScaffold` shows a plain `AppBar` with the title and a
back arrow, no Save, no leave check, no shortcuts, and `onExit` asks nothing
when no sitting is dirty. A read-only rule uses exactly that: it is never
opened. So this plan needs no shared read-only support. Plan 3 owns any it
adds for the built-in pre-dive template; if it adds some, the rule editor can
move onto it in a later change.

## Choices for Eric

Eric approved the plan on 2026-11-22 and picked option B for choice 1; the
other choices stand as written.

1. **Save while a rule is incomplete.** Today Save is disabled while the
   rule has no name, no action, or a condition whose text does not parse.
   The host enables Save on any change.
   - **B (planned):** keep today's behaviour. The host gains
     `editorCanSave` (one additive member), the rule answers it, and the
     existing tests "Save stays disabled with no actions" and "Save waits
     while the condition text does not parse" stay as they are.
   - **A:** no host change. Save enables on any change; tapping it on an
     incomplete rule writes nothing and says why in the form: the name
     field shows a new `rules_edit_nameRequired` ("Give the rule a name."),
     the existing "Add at least one action." line turns the error colour,
     and the condition shows its own parse error, as it already does. The
     two tests above are retargeted.
2. **A read-only rule on a diver switch** stays open, as today: it holds
   nothing to write. Every editor with a sitting closes.
3. **A new incident with no resolved diver** is still written with no
   diver, as today (the near-miss log lists diver-less reports for every
   diver). Presets and transmitter keys refuse Save instead.
4. **The incident's Save refusal** when the report was deleted while open
   reuses `incidents_notFound` ("Near-miss report not found"); the rule's
   gets a new `rules_edit_notFound` ("This rule no longer exists.").
5. **A rule or incident that fails to load** keeps today's error page
   (incidents: the note says so; rules: the same, for symmetry), now under
   the host's plain bar with the editor's title.

## Review Focus

1. **An untouched rule is unchanged.** A stored rule with a condition and
   actions, opened and left alone, has Save disabled and Back asks nothing:
   the condition editor commits nothing until the diver types, and nothing
   is re-encoded. The same for a rule whose condition did not load (an
   unresolved reference). Tests in Task 4.
2. **A report deleted while open is never brought back.** Today's
   `updateIncident` is an insert-or-update, so a Save of a deleted report
   would re-insert it. The patch updates by id only; a missing row is
   refused with `incidents_notFound` and nothing is written. The same for a
   rule. Tests in Tasks 2, 4, 5 and 7.
3. **What the diver did not touch keeps its stored value.** A rule renamed
   keeps the enabled switch flipped on the list meanwhile and its stored
   actions JSON. An incident whose severity changed keeps lessons synced in
   meanwhile, and keeps a raw check-in link that does not currently stand
   (the domain reads it as null; writing that null back would erase a link
   peers keep, #3062). Tests in Tasks 3, 4, 6 and 7.
4. **A seed always reads as a change.** A new incident from a dive, or from
   a check-in, opens with Save enabled and Cancel asks; a check-in deleted
   before the form opened leaves a plain new form, clean. Tests in Task 7.
5. **A read-only rule offers nothing to save.** No tinted bar, no Save, no
   menu, Back leaves without a question, nothing is written. Test in Task 4.

---

### Task 0: Before screenshots

**Files:**
- Create (scratch, not committed): a throwaway golden harness in the session
  scratchpad, modelled on plan 2's (`scratchpad/phase4_plan2_shots_test.dart`
  in that session's notes); copy it into `test/` only while capturing, then
  delete it

- [ ] **Step 1: Capture the editors as they are today**

Headless captures of: the rule editor (a stored dive rule with a condition
and two actions; a new rule; a read-only rule from a newer version) and the
incident editor (a stored report with an item and a check-in, scrolled to
show the bottom Save; a new report from a dive), each at phone width
(390 x 844) and desktop width (1280 x 800), light and dark. Save them outside
the repo, named `<nn>-<screen>-<width>-<theme>-before.png`.

- [ ] **Step 2: Check nothing is staged**

Run: `git status --short`
Expected: no new or changed file under `lib/` or `test/`.

---

### Task 1: The host asks whether Save is allowed (option B only)

Skip this task if Eric picks option A.

**Files:**
- Modify: `lib/shared/widgets/record_editing/record_editor_host.dart`
- Modify: `test/shared/widgets/record_editing/record_editor_host_harness.dart`
  (`FakeEditorPage` gains `final bool Function()? canSave`)
- Test: `test/shared/widgets/record_editing/record_editor_host_can_save_test.dart`

**Interfaces:**
- Produces, for Task 4:

```dart
/// Whether the form, as it reads now, may be saved at all (a rule with no
/// name or no action may not). Save is enabled only while this holds and
/// something has changed; Cmd or Ctrl+S does nothing otherwise. True by
/// default. Read on every build of the bar, so the editor rebuilds (a
/// setState) when its answer changes.
bool get editorCanSave => true;
```

`editorScaffold` passes `canSave: controller.isDirty && editorCanSave`;
`saveEditor` returns at once when `!editorCanSave`, beside its `isDirty`
check.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('Save stays disabled while the editor says it cannot save', ...);
  // canSave: () => text.isNotEmpty with the field typed empty from 'a':
  // dirty, Save onPressed null; typing 'b' enables it.
testWidgets('Cmd+S does nothing while the editor says it cannot save', ...);
  // writes empty after the shortcut.
testWidgets('an editor that says nothing saves as before', ...);
  // canSave null: typing enables Save.
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/shared/widgets/record_editing/record_editor_host_can_save_test.dart`
Expected: FAIL, `FakeEditorPage` has no `canSave`.

- [ ] **Step 3: Implement `editorCanSave` and the harness option**

- [ ] **Step 4: Run the three host test files to see them pass**

Run: `flutter test test/shared/widgets/record_editing/record_editor_host_can_save_test.dart test/shared/widgets/record_editing/record_editor_host_test.dart test/shared/widgets/record_editing/record_editor_host_menu_test.dart`
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/shared/widgets/record_editing/record_editor_host.dart test/shared/widgets/record_editing/record_editor_host_harness.dart test/shared/widgets/record_editing/record_editor_host_can_save_test.dart
git commit -m "feat(record-editing): an editor can hold Save back while its form is incomplete"
```

---

### Task 2: The rule repository creates under a given id and patches columns

**Files:**
- Modify: `lib/features/rules/data/repositories/rule_repository.dart`
- Test: `test/features/rules/data/rule_repository_test.dart`

**Interfaces:**
- Produces, for Tasks 3 and 4:

```dart
/// What a Save changes on a stored rule; a null part is left as stored.
/// [condition] is wrapped so "match everything" (a null tree) can be told
/// from "unchanged".
typedef RuleChanges = ({
  String? name,
  Set<RuleTrigger>? triggers,
  ({QueryNode? node})? condition,
  List<RuleAction>? actions,
});

// RuleRepository:
Future<String> create({String? id, required String diverId, ...}); // as today
/// Writes only the parts of [changes] given, on the row as stored, stamped
/// for sync. Triggers keep any a newer version added (formatRuleTriggers'
/// `keeping`). False, writing nothing, when the rule no longer exists.
Future<bool> patch(String id, RuleChanges changes);
```

`create` uses `id ?? _uuid.v4()`. `patch` reads the stored row, returns
false when it is gone, then writes `name` (trimmed), `triggers`,
`conditionJson` (`encodeRuleCondition`) and `actionsJson` only for the parts
given, through `_update`. `update` stays for its other callers.

- [ ] **Step 1: Write the failing tests**

```dart
test('create writes the rule under the id it is given', ...);
test('patch writes only the parts it is given', ...);
  // A rule renamed by patch keeps its enabled flag (set false after create),
  // its conditionJson and actionsJson byte for byte.
test('patch keeps a trigger a newer version added', ...);
  // Stored triggers 'afterImport,someFutureTrigger': patch(triggers:
  // {afterManualCreate}) keeps 'someFutureTrigger'.
test('patch can clear the condition', ...);
  // condition: (node: null): conditionJson is ''.
test('patch of a rule that is gone writes nothing and says so', ...);
  // false; no rules row with that id afterwards.
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/rules/data/rule_repository_test.dart`
Expected: FAIL, no `id` parameter and no `patch`.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run the tests to see them pass**

Run: the Step 2 command.
Expected: all pass, the existing ones included.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/rules/data/repositories/rule_repository.dart test/features/rules/data/rule_repository_test.dart
git commit -m "feat(rules): create a rule under a given id and patch only what changed"
```

---

### Task 3: The rule editor's draft

**Files:**
- Create: `lib/features/rules/presentation/pages/rule_draft.dart`
- Test: `test/features/rules/presentation/rule_draft_test.dart`

**Interfaces:**
- Consumes: `RuleChanges` (Task 2).
- Produces, for Task 4:

```dart
/// The rule editor's form as shown: the name as typed, what it applies to,
/// when it runs, the condition tree the editor holds and whether its text
/// parses, and the actions in order. Compared by value: QueryNode and
/// RuleAction define ==, so nothing is re-encoded to tell a change.
class RuleDraft {
  const RuleDraft({
    required this.name,
    required this.subject,
    required this.triggers,
    required this.condition,
    required this.conditionValid,
    required this.actions,
  });
  final String name;
  final RuleSubject subject;
  final Set<RuleTrigger> triggers;
  final QueryNode? condition;
  /// False while the condition's text does not parse: the tree is then the
  /// last one that did, which is not what the diver sees, so the draft
  /// reads as changed.
  final bool conditionValid;
  final List<RuleAction> actions;
  // == and hashCode over every field: setEquals(triggers),
  // listEquals(actions).
}

/// The blank form of a new rule: no name, dives, after import, no
/// condition, no actions.
const blankRuleDraft = RuleDraft(...);

/// The draft of [rule] as the editor fills its form from it.
RuleDraft ruleDraftOf(Rule rule);

/// What Save writes on a stored rule: each part whose draft value differs
/// from [start]'s; the subject never (it is fixed once a rule exists).
RuleChanges ruleChanges(RuleDraft draft, RuleDraft start);
```

- [ ] **Step 1: Write the failing tests**

```dart
test('a rule and its own draft are equal however often it is read', ...);
  // ruleDraftOf(rule) == ruleDraftOf(rule) for a rule with an AndNode
  // condition and two actions (rules_fixture).
test('triggers compare as sets', ...);
test('actions in another order are a change', ...);
test('a condition that does not parse is a change', ...);
test('ruleChanges names only what changed', ...);
  // Name changed: (name: 'x', triggers: null, condition: null, actions:
  // null).
test('ruleChanges carries a cleared condition', ...);
  // start condition non-null, draft null: condition == (node: null).
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/rules/presentation/rule_draft_test.dart`
Expected: FAIL, the file does not exist.

- [ ] **Step 3: Implement `rule_draft.dart`**

- [ ] **Step 4: Run the tests to see them pass**

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/rules/presentation/pages/rule_draft.dart test/features/rules/presentation/rule_draft_test.dart
git commit -m "feat(rules): the rule editor's draft and what its Save changes"
```

---

### Task 4: The rule editor on the host

**Files:**
- Modify: `lib/features/rules/presentation/pages/rule_edit_page.dart`
- Modify: `lib/core/router/app_router.dart` (`/rules/new` and `/rules/:id`,
  about lines 2106-2132)
- Modify: the 11 `lib/l10n/arb/app_*.arb` files (`rules_edit_notFound`:
  "This rule no longer exists.")
- Modify: `test/features/rules/presentation/rule_edit_page_test.dart`
- Test: `test/features/rules/presentation/rule_edit_page_sitting_test.dart`

**Interfaces:**
- Consumes: the host (plans 1 and 2; `editorCanSave` from Task 1 under
  option B), `RuleChanges` and `patch` (Task 2), `RuleDraft`,
  `blankRuleDraft`, `ruleDraftOf`, `ruleChanges` (Task 3).
- Produces: nothing new outside the file.

- [ ] **Step 1: Write the failing tests, and retarget the old ones**

In `rule_edit_page_test.dart`: tests that find Save by
`ValueKey('rule_save')` find the bar's Save
(`find.descendant(of: find.byType(RecordEditBar), matching: find.text('Save'))`);
`'editing keeps the id and the subject'` and `'renaming a rule whose
condition no longer loads keeps it'` change a field first and check the
stored row afterwards. Under option A, `'Save stays disabled with no
actions'` and `'Save waits while the condition text does not parse'` become
"tapping Save on ... writes nothing and says why".

In the new `rule_edit_page_sitting_test.dart`, a router with a stand-in
`/rules` list under `/rules/new` and `/rules/:id` (both with
`onExit: confirmLeaveRecordSitting`), pushed from the list; the test
database; the diver as plan 1's tank preset test sets it:

```dart
testWidgets('the bar is the tinted Cancel and Save bar with no back arrow', ...);
testWidgets('a stored rule opened and left alone is unchanged', ...);
  // Save disabled; Back pops to the list with no dialog. (Review Focus 1)
testWidgets('a rule whose condition did not load is unchanged when left alone', ...);
  // A condition naming a site the name index lacks. (Review Focus 1)
testWidgets('a new rule with nothing entered closes on Cancel at once', ...);
testWidgets('adding an action and removing it again is no change', ...);
testWidgets('a condition that does not parse is a change', ...);
  // Type 'depth >' into the condition: Back asks.
testWidgets('Back after renaming asks; Discard leaves the list', ...);
testWidgets('Save writes one change log operation labelled with the rule', ...);
  // change_log_operations rows labelled 'record_edit:': one, decoding to
  // table 'rules' and the rule id.
testWidgets('a new rule is created under the page id', ...);
  // The rules row's id == state.newEditorRecordId; diver_id the diver's.
testWidgets('a rename keeps the enabled switch flipped meanwhile', ...);
  // setEnabled(id, false) after the page opened; rename, Save: enabled
  // stays false, actions_json unchanged. (Review Focus 3)
testWidgets('a rule deleted while open is refused at Save', ...);
  // delete(id) after the page opened; rename, Save: snackbar
  // rules_edit_notFound; no rules row; page open. (Review Focus 2)
testWidgets('a rule from a newer version opens with a plain bar and no Save', ...);
  // No RecordEditBar, a BackButton, no 'Save'; Back pops with no dialog;
  // the stored row unchanged. (Review Focus 5)
testWidgets('a new rule typed in closes on a diver switch, writing nothing', ...);
testWidgets('a rule that will not load keeps the error text under a plain bar', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/rules/presentation/rule_edit_page_test.dart test/features/rules/presentation/rule_edit_page_sitting_test.dart`
Expected: FAIL (no tinted bar, no leave check).

- [ ] **Step 3: Move the page onto the host**

- Mix in `RecordEditorHost<RuleEditPage, RuleDraft>`: `editorTable`
  `'rules'`, `editorStoredId` `widget.ruleId`, `editorTitle` today's
  `rules_edit_titleNew` or `rules_edit_titleEdit`, `editorLeaveLocation`
  `'/rules'`.
- Loading: in `initState`, a new rule opens at once (`openEditor()` on
  `blankRuleDraft`'s form). A stored rule is read with `ref.listenManual(
  ruleByIdProvider(id), fireImmediately: true, ...)`, which keeps the
  auto-dispose provider alive while it loads; on its first `AsyncData` with
  a rule, `_seed` fills the form and the subscription closes; then
  `openEditor()` unless `_readOnly`. A missing rule or an error closes the
  subscription and shows today's `common_error_tryAgain`. Later ticks are
  ignored, as today.
- `build` returns `editorScaffold(context, body: ...)`. The body is the
  spinner while loading, the error text, or today's `ListView`; the
  `Scaffold`, `AppBar` and `AppBarTextAction` go. A read-only rule is never
  opened, so it keeps the host's plain bar with its back arrow.
- `readEditorDraft()` builds a `RuleDraft` from `_name.text`, `_subject`,
  `_triggers`, `_condition`, `_conditionValid` and `_actions`.
- `editorChanged()` after every `setState` that changes one of them: the
  name listener, subject, triggers, the condition's `onChanged` and
  `onValidityChanged`, add, edit and remove action.
- Option B: `editorCanSave` is today's `_canSave` less `_saving` and
  `_readOnly` (the host owns both): `_conditionValid`, a trimmed name, at
  least one action. `validateEditor()` answers the same.
  Option A: `validateEditor()` sets `_nameError` (shown as the name field's
  `errorText`) and `_actionsMissing` (the "Add at least one action." line in
  the error colour) and answers false when either is missing or
  `!_conditionValid`.
- `writeEditor(id)`:
  - New: `create(id: id, diverId: editorDiverId, ...)` from the draft; a
    null `editorDiverId` throws `StateError`, as today.
  - Stored: `patch(id, ruleChanges(readEditorDraft(), editorStartDraft!))`;
    false throws `RecordSittingRefusal((l10n) => l10n.rules_edit_notFound)`.
  The repository is read from `ref` before the first await.
- No `afterEditorSaved`: the lists watch the table. `_saving`, `_save` and
  `showRulesError` here go (the host shows `recordEdit_saveFailed`).
- `_matchCount` keeps `_conditionTouched` as today.
- `dispose` calls `disposeEditor()` first.
- Both routes gain `onExit: confirmLeaveRecordSitting`.

- [ ] **Step 4: Add the string and generate**

`rules_edit_notFound` in all 11 arb files (English above; each locale in its
own words, as plan 2 did for `transmitters_edit_notFound`), then
`flutter gen-l10n`. Option A adds `rules_edit_nameRequired` the same way.

- [ ] **Step 5: Run the tests to see them pass**

Run: the Step 2 command, plus
`flutter test test/features/rules/presentation/rules_page_test.dart`.
Expected: all pass.

- [ ] **Step 6: Format, analyze, commit**

```bash
git add lib/features/rules/presentation/pages/rule_edit_page.dart lib/core/router/app_router.dart lib/l10n test/features/rules/presentation/rule_edit_page_test.dart test/features/rules/presentation/rule_edit_page_sitting_test.dart
git commit -m "feat(rules): edit a rule on the shared Cancel and Save bar"
```

---

### Task 5: The incident repository creates under a given id, patches columns, and labels its delete

**Files:**
- Create: `lib/features/safety/domain/entities/incident_changes.dart`
- Modify: `lib/features/safety/data/repositories/incident_repository.dart`
- Test: `test/features/safety/data/repositories/incident_repository_test.dart`

**Interfaces:**
- Produces, for Tasks 6 and 7:

```dart
/// What a Save changes on a stored near-miss report; a null field is left
/// as stored. Clearable fields are wrapped so "clear" can be told from
/// "unchanged".
class IncidentChanges {
  const IncidentChanges({
    this.occurredAt,
    this.category,
    this.severity,
    this.narrative,
    this.contributingFactors,
    this.lessonsLearned,
    this.equipmentId,
    this.link,
  });
  final DateTime? occurredAt;
  final IncidentCategory? category;
  final IncidentSeverity? severity;
  final String? narrative;
  final ({String? value})? contributingFactors;
  final ({String? value})? lessonsLearned;
  final ({String? value})? equipmentId;
  /// The dive and check-in links, written together.
  final ({String? diveId, String? observationId})? link;
  bool get isEmpty;
  // == and hashCode over every field, for tests.
}

// IncidentRepository:
Future<Incident> createIncident({String? id, ...}); // as today
/// Writes only the fields of [changes] given, on the row as stored, with a
/// new updatedAt, stamped for sync. An update by id only: false, writing
/// nothing, when the report no longer exists (never re-inserted).
Future<bool> applyIncidentChanges(String id, IncidentChanges changes);
/// As today, inside ChangeLogScope.bulk labelled
/// ChangeLogLabels.deletedRecord, so the editor's Delete is a labelled
/// History entry of its own, and part of an operation already running.
Future<void> deleteIncident(String id);
```

`updateIncident` stays for its other callers (the agent write family).

- [ ] **Step 1: Write the failing tests**

```dart
test('createIncident writes the report under the id it is given', ...);
test('applyIncidentChanges writes only the fields it is given', ...);
  // Severity changed: narrative, lessons and occurred_at as stored.
test('applyIncidentChanges keeps a check-in link that does not stand', ...);
  // A report linked to a check-in since marked OK: getIncidentById reads
  // observationId null; a severity change leaves observation_id in the row.
  // (Review Focus 3)
test('applyIncidentChanges can clear the item and the lessons', ...);
test('applyIncidentChanges on a report that is gone writes nothing', ...);
  // false; no incidents row with that id. (Review Focus 2)
test('deleteIncident is one operation labelled deleted record', ...);
  // After ChangeLogRepository().settleAll(): one operation whose label is
  // ChangeLogLabels.deletedRecord.
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/safety/data/repositories/incident_repository_test.dart`
Expected: FAIL, no `id` parameter, no `applyIncidentChanges`, delete
unlabelled.

- [ ] **Step 3: Implement**

`applyIncidentChanges` writes an `IncidentsCompanion` whose untouched
columns are `Value.absent()`, by `update(...)..where(id)`, and reports
whether a row was written. Doc comments in the voice of the file.

- [ ] **Step 4: Run the tests to see them pass**

Run: the Step 2 command, plus
`flutter test test/features/agent_access/data/writes/safety_writes_test.dart`
(it calls `deleteIncident` and `updateIncident`).
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/safety/domain/entities/incident_changes.dart lib/features/safety/data/repositories/incident_repository.dart test/features/safety/data/repositories/incident_repository_test.dart
git commit -m "feat(safety): create a near-miss under a given id and patch only what changed"
```

---

### Task 6: The incident editor's draft

**Files:**
- Create: `lib/features/safety/presentation/pages/incident_draft.dart`
- Test: `test/features/safety/presentation/pages/incident_draft_test.dart`

**Interfaces:**
- Consumes: `IncidentChanges` (Task 5).
- Produces, for Task 7:

```dart
/// The incident editor's form as shown: choices as picked, texts as typed
/// (untrimmed), and the two dives the form tells apart. A record type, so
/// it compares by value.
typedef IncidentDraft = ({
  IncidentCategory category,
  IncidentSeverity severity,
  DateTime occurredAt,     // wall-clock UTC date, as the form holds it
  String? equipmentId,
  String? observationId,
  String? diveId,          // the report's own dive
  String? checkInDiveId,   // the dive that came with the chosen check-in
  String narrative,
  String factors,
  String lessons,
});

/// A new report's blank form on [today]: other, minor, nothing linked,
/// nothing typed. A new report opened from a dive or a check-in opens its
/// sitting on this, so what was filled in is a change.
IncidentDraft blankIncidentDraft(DateTime today);

/// The dive a report saves with when [linkable] is the check-in that can
/// still be linked: its own, else the check-in's; the check-in's goes when
/// the check-in has. Today's rule, shared by create and update.
String? incidentSavedDiveId(IncidentDraft draft, String? linkable);

/// What Save writes on a stored report: each field whose draft value
/// differs from [start]'s, texts trimmed and blank ones cleared; the links
/// only when observationId, diveId or checkInDiveId changed, then as
/// [linkable] and [incidentSavedDiveId].
IncidentChanges incidentChanges({
  required IncidentDraft draft,
  required IncidentDraft start,
  required String? linkable,
});
```

- [ ] **Step 1: Write the failing tests**

```dart
test('a blank draft is equal to another blank draft of the same day', ...);
test('a severity change is the only change', ...);
test('texts are trimmed and a blank one is cleared', ...);
test('an untouched link writes no link even when it no longer stands', ...);
  // start and draft both observationId 'o1', linkable null: link is null.
test('a check-in picked writes its link and its dive', ...);
test('a check-in that has gone takes its dive with it', ...);
  // draft observationId 'o1', checkInDiveId 'd2', diveId null, linkable
  // null: link == (diveId: null, observationId: null).
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/safety/presentation/pages/incident_draft_test.dart`
Expected: FAIL, the file does not exist.

- [ ] **Step 3: Implement `incident_draft.dart`**

- [ ] **Step 4: Run the tests to see them pass**

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/safety/presentation/pages/incident_draft.dart test/features/safety/presentation/pages/incident_draft_test.dart
git commit -m "feat(safety): the near-miss editor's draft and what its Save changes"
```

---

### Task 7: The incident editor on the host

**Files:**
- Modify: `lib/features/safety/presentation/pages/incident_edit_page.dart`
- Modify: `lib/core/router/app_router.dart` (`new` and `:incidentId` under
  `/incidents`, about lines 1486-1507)
- Modify: the 11 `lib/l10n/arb/app_*.arb` files (remove `incidentEdit_save`)
- Modify: `test/features/safety/presentation/pages/incident_edit_page_test.dart`
- Modify: `test/features/safety/presentation/pages/incident_check_in_link_test.dart`
- Test: `test/features/safety/presentation/pages/incident_edit_page_sitting_test.dart`

**Interfaces:**
- Consumes: the host (plans 1 and 2: `openEditor(from:)`,
  `editorOperations`, `RecordEditorOperation`, `editorDiverId`,
  `editorStartDraft`, `leaveEditor`), Task 5 (`createIncident(id:)`,
  `applyIncidentChanges`, `deleteIncident`), Task 6 (`IncidentDraft`,
  `blankIncidentDraft`, `incidentSavedDiveId`, `incidentChanges`).
- Produces: nothing new outside the file.

- [ ] **Step 1: Write the failing tests, and retarget the old ones**

Both existing files add `setUpTestDatabase()` to their setup (Save now runs
in a transaction). Their `_FakeIncidentRepository` gains `createIncident`'s
`id` (recorded) and an `applyIncidentChanges` that records its changes and
answers `result != null`. Taps on `find.widgetWithText(FilledButton,
'Save')` tap the bar's Save; tests that save an untouched stored report
change a field first; `'a save that fails says so and keeps the form'`
expects `recordEdit_saveFailed`; `'editing and saving calls updateIncident
and pops'` checks the recorded `IncidentChanges`; the delete tests open the
bar menu (`ValueKey('recordEditorMenu')`) and choose Delete. `'leaving while
a save runs still files the report'` stays: `writeEditor` reads both
repositories from `ref` before its first await.

In the new `incident_edit_page_sitting_test.dart`, the real
`IncidentRepository` over the test database where the test reads the change
log or storage, the fakes elsewhere, and a stand-in `/incidents` list under
the two edit routes (with `onExit`):

```dart
testWidgets('the bar is the tinted Cancel and Save bar, with no Save at the bottom', ...);
  // One RecordEditBar; no FilledButton labelled Save; no BackButton.
testWidgets('a stored report opened and left alone is unchanged', ...);
testWidgets('a new report from a dive opens with Save enabled', ...);
  // /incidents/new?diveId=d1: Save enabled at once; Cancel asks.
  // (Review Focus 4)
testWidgets('a new report from a check-in opens with Save enabled', ...);
  // (Review Focus 4)
testWidgets('a check-in gone before the form opened leaves a clean form', ...);
  // Cancel closes with no dialog. (Review Focus 4)
testWidgets('a plain new report is clean until something is entered', ...);
testWidgets('Save writes one change log operation labelled with the report', ...);
testWidgets('a new report is created under the page id', ...);
testWidgets('a severity change keeps lessons synced in meanwhile', ...);
  // (Review Focus 3)
testWidgets('a report deleted while open is refused and not brought back', ...);
  // Snackbar incidents_notFound; no incidents row. (Review Focus 2)
testWidgets('Delete is in the menu, disabled while there are changes', ...);
testWidgets('a new report has no menu', ...);
testWidgets('Delete asks, removes the report in its own History entry, and leaves', ...);
  // One operation labelled deletedRecord; the list shows; the item's
  // findings refresh is scheduled.
testWidgets('a check-in added from the picker survives Cancel', ...);
  // Add check-in, then Cancel and Discard: the equipment_observations row
  // stays.
testWidgets('the findings refresh runs after the commit, for both items', ...);
  // Moving a report from item A to B: scheduled for {A, B} once Save has
  // committed.
testWidgets('a new report typed in closes on a diver switch, writing nothing', ...);
testWidgets('a report that will not load keeps the error page with no tinted bar', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/safety/presentation/pages/incident_edit_page_test.dart test/features/safety/presentation/pages/incident_check_in_link_test.dart test/features/safety/presentation/pages/incident_edit_page_sitting_test.dart`
Expected: FAIL (Save at the bottom, no leave check, no menu).

- [ ] **Step 3: Move the page onto the host**

- Mix in `RecordEditorHost<IncidentEditPage, IncidentDraft>`:
  `editorTable` `'incidents'`, `editorStoredId` `widget.incidentId`,
  `editorTitle` today's `incidentEdit_title_new` or
  `incidentEdit_title_edit`, `editorLeaveLocation` `'/incidents'`.
- `readEditorDraft()` reads the fields named in `IncidentDraft`.
  `_categoryTouched`, `_dateTouched` and `_defaultDate` steer the form and
  are not in the draft.
- Opening:
  - a plain new report: `openEditor(from: blankIncidentDraft(today))` in
    `initState`, so a `widget.diveId` is a seed and no dive is clean;
  - from a check-in: once `_startFromCheckIn` has filled the form (or found
    nothing), `openEditor(from: blankIncidentDraft(today))`;
  - a stored report: `openEditor()` once the load has filled the form; a
    missing report or a load that fails keeps today's not-found and error
    texts, never opened, so the host's plain bar shows.
- `editorChanged()` after every `setState` that changes a draft field
  (category, severity, date, item, check-in adopt and clear, the matched
  check-in) and from the three text controllers' listeners.
- `validateEditor()` is `_formKey.currentState?.validate() ?? false`.
- `writeEditor(id)`: read the incident and check-in repositories from `ref`
  first. `linkable` is today's `_linkableObservationId`. New:
  `createIncident(id: id, diverId: editorDiverId, ...)` from the draft,
  texts trimmed, dive `incidentSavedDiveId`. A null diver writes a
  diver-less report, as today. Stored: `getIncidentById(id)` inside the
  sitting (null throws `RecordSittingRefusal((l10n) =>
  l10n.incidents_notFound)`), note its `equipmentId`, then
  `applyIncidentChanges(id, incidentChanges(...))` (false throws the same
  refusal). Keep the items touched (the written item, the stored one) in a
  field.
- `afterEditorSaved(_)`: `scheduleConditionFindingsRefresh(touched)` when
  any.
- `editorOperations`: one `RecordEditorOperation` (key
  `ValueKey('incident_delete')`, `Icons.delete_outline`,
  `common_action_delete`, destructive) whose `run` asks today's
  `incidents_delete_confirm` dialog, reads the stored report's item,
  `deleteIncident(id)`, schedules that item's findings refresh, and answers
  true; false when the dialog is cancelled. The bar's `IconButton` goes.
- `build` returns `editorScaffold(context, body: ...)`; the `Scaffold`,
  `AppBar` and bottom `FilledButton` go; `_saving`, `_save` and `_write`
  go. The not-found and error bodies stay.
- `dispose` calls `disposeEditor()` first.
- Both routes gain `onExit: confirmLeaveRecordSitting`.
- The page ends under 800 lines; if not, `_GearOption` and `_EquipmentName`
  move to `widgets/incident_gear_option.dart`.

- [ ] **Step 4: Remove the unused string and generate**

Remove `incidentEdit_save` from all 11 arb files (check first that nothing
else reads it), then `flutter gen-l10n`.

- [ ] **Step 5: Run the tests to see them pass**

Run: the Step 2 command, plus
`flutter test test/features/safety/presentation/pages/incidents_list_page_test.dart`.
Expected: all pass.

- [ ] **Step 6: Format, analyze, commit**

```bash
git add lib/features/safety/presentation/pages lib/core/router/app_router.dart lib/l10n test/features/safety/presentation/pages
git commit -m "feat(safety): edit a near-miss on the shared Cancel and Save bar"
```

---

### Task 8: After screenshots, review, and the question to Eric

- [ ] **Step 1: Capture the after shots**

The same screens, widths and themes as Task 0, with the same harness, named
`-after.png`. Add: a rule with a change made (Save enabled), and the
incident's bar menu open showing Delete.

- [ ] **Step 2: Analyze the whole repo**

Run: `flutter analyze`
Expected: no issues (a fake elsewhere may need `createIncident`'s or
`create`'s new `id`).

- [ ] **Step 3: Review the branch**

Run the `code-review` skill on the branch with `--max-findings all`. Fix
every valid finding test-first, one commit per fix or per related group.
Re-run only the test files touched.

- [ ] **Step 4: Write "After the build" into this plan and commit it**

What changed from the plan, for plan 5 and any later change to build on.

- [ ] **Step 5: Ask Eric before anything goes out**

Show the before and after shots and the review outcome, and ask whether to
push and open the PR.

- [ ] **Step 6: On his yes, merge main, push and open the PR**

Merge `origin/main` in (never rebase), analyze, then push. Title:
`feat(editing): rules and near-miss reports get the shared Cancel and Save
bar (Unified Editing, phase 4, plan 4)`. Body: what changed, `Refs #4527`,
the design note and this plan linked, the screenshots attached through the
project's highest-numbered secret gist
(`PR screenshots: submersion-app/submersion (N)`, pngquant first,
`<pr>-<nn>-<screen>-<state>.png`, raw URLs pinned to the gist commit). Bind
the PR and report its checks.

## After the build

Built natively on 2026-11-22 (commits after the plan commit, to the branch
head). What changed from this plan, for plan 5 and any later change to build
on:

- **Option B shipped.** The host's one new member is `editorCanSave`
  (`record_editor_host.dart`); the fake editor's switch for it is
  `EditorProbe.canSave`, beside the probe's other options, not a
  `FakeEditorPage` parameter. Its tests are
  `record_editor_host_can_save_test.dart`.
- **The rule editor loads once.** `ruleByIdProvider` is read with
  `ref.listenManual(fireImmediately: true)`; the form is filled from the
  first value only (`_settled`), and a subscription that answered at once
  is closed after `listenManual` returns. A later tick (a sync, the list's
  enabled switch) never overwrites what the diver is editing (review fix).
- **A rule that will not load** keeps today's error text under the host's
  plain bar, which now carries the editor's title.
- **The near-miss link is rewritten when the item changes**, as well as
  when the check-in or a dive does: a check-in belongs to one item, so a
  link stored on the old item, even one that reads as none, does not follow
  (review fix).
- **Tests.** The "link that does not stand" repository test and the "check-in
  added from the picker survives Cancel" page test live in the two
  `incident_check_in_link_test.dart` files (data and page), where their
  helpers are. Older page tests with no diver override gained
  `validatedCurrentDiverIdProvider` answering null: Save now resolves the
  diver first. As in plans 1 and 2, the bar's Save enables a frame after an
  edit, so tests pump between typing and tapping it.
- **Generated code.** This worktree's `*.g.dart` and mocks were stale; they
  were copied from a sibling worktree cut from the same commit with the same
  schema sources, not regenerated.
- **Review (code-review, high, all findings):** three findings. Two fixed
  test-first (the rule editor's re-seed, the near-miss link on a move). One
  left as it is: the findings refresh is skipped if the editor is gone
  before its Save commits, but no app path closes the editor mid-commit
  (its leave guard holds Back while busy, and a `go` asks through the exit
  check, which refuses while busy); only a forced pop in a test does.
- **A second review (code-review, xhigh, all findings, on the PR):** five
  findings. Fixed: a rule whose stored condition did not load can again be
  cleared to match every dive (the draft carries `replacesBrokenCondition`,
  which the old Save read as `_conditionTouched`); a failed near-miss Save is
  logged again (`editorSaveFailed`); a new rule opens from `blankRuleDraft`;
  a new near-miss's blank draft is dated before anything is awaited. Left as
  the plan chose: a rule that will not load keeps today's error text.
- **The agent write coverage guard** (`test/architecture/agent_write_coverage_covered.dart`)
  lists `applyIncidentChanges` as covered, reached through the near-miss
  writer's `updateIncident`. That writer still writes the check-in link from
  the domain copy, so an agent edit can erase a link that does not stand:
  a follow-up of its own.
- **Review on the PR (Copilot):** `RuleRepository.patch` read the rule and
  updated it in two statements and answered true whatever the update
  wrote. It is now one transaction (nested inside the sitting's when the
  editor calls it) answering whether a row was written, and `_update`
  answers its row count and stamps a rule for sync only when it wrote one,
  so `setEnabled` and the agent's `update` no longer stamp a rule that is
  gone.
- **The near-miss link is split (Copilot, on the PR).** `IncidentChanges`
  carries `diveId` and `observationId` separately in place of the `link`
  pair Task 5 planned. The check-in is written, as the one that can still
  be linked, when the check-in, a dive or the item changed, and a check-in
  written takes its item with it. The dive is written only when the dive
  the report saves with differs from the one it started with, so a change
  of check-in alone leaves a dive synced in meanwhile as stored. Left as it
  was, on purpose: a stored report cannot tell whether its dive came from
  its check-in, so clearing the check-in keeps the dive, as before this
  plan.
- **Shared files touched:** `record_editor_host.dart` (one getter, two
  reads), `record_editor_host_harness.dart` (one probe option),
  `app_router.dart` (`onExit` on the four rule and near-miss editing
  routes), the 11 arb files and their generated localizations
  (`rules_edit_notFound` added, `incidentEdit_save` removed).

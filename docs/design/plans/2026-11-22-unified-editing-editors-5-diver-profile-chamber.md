# Unified editing phase 4, plan 5: the diver profile pages and the chamber form

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the five diver profile edit pages, the new-diver page and the
chamber form onto the shared editor host, so each Save is one transaction
and one History entry, pinned to the diver the page opened with; and give
the body weight delete a confirmation.

**Architecture:** Plans 1 and 2's `RecordEditorHost<W, D>` is used as it
shipped, with no change to shared code. A feature-local mixin,
`DiverProfileEditor<W, D>`, sits on top of the host for the five pages that
edit a stored diver: it pins the diver the page was filled from, makes that
diver's id the sitting's record id, and at Save reads the diver row as
stored and applies only the fields the page owns whose text changed since
the form was filled. Each page's draft and its "apply" are pure functions
in one file. The new-diver page becomes its own widget on the host (a
new-record sitting), sharing the personal fields with the personal page.
The chamber form is a new-record sitting on the host.

**Tech Stack:** Flutter, Riverpod, go_router, Drift; the record editing
pieces in `lib/shared/widgets/record_editing/` and
`lib/core/services/change_log/record_sitting_writer.dart`.

**Spec:** [docs/design/specs/2026-11-22-unified-editing-phase-4-design.md](../specs/2026-11-22-unified-editing-phase-4-design.md)
(phase 4 of [the pattern](../specs/2026-11-14-unified-editing-pattern-design.md)).
Read its "What is generalised", "Rules every phase 4 editor follows",
"Diver profile" and "Chamber" sections, decisions 1 and 7, and plans
[1](2026-11-22-unified-editing-editors-1-host-presets.md) and
[2](2026-11-22-unified-editing-editors-2-cylinder-configs-transmitters.md),
including both "After the build" sections, before starting.

## Global Constraints

- Never write an em-dash, or an en-dash or double hyphen as sentence
  punctuation, in code, comments, tests, commits or the PR.
- Nothing written to the repo or GitHub names the tools used to write it:
  no tool attribution and no co-author trailers.
- The PR says `Refs #4527` (plans 3 and 4 may still be open; whichever
  phase 4 PR merges last decides whether it says `Closes #4527`).
- Goes live as it merges: no build switch (decision 6).
- The bar is `RecordEditBar` through the host, tinted, no back arrow, Save
  disabled until there is a change (decision 2). No profile page and not
  the chamber form has a menu: none has a whole-record operation.
- Every editor closes when the active diver changes under it, whether or
  not it had changes (decision 7); the host already does this. A profile
  page returns to the hub.
- A draft holds the form as shown (texts as typed, choices as picked),
  never values parsed back. An update writes only the fields whose draft
  value differs from `editorStartDraft`'s, onto the diver row as stored at
  Save, read inside the sitting (plan 1, "After the build").
- Writes inside `writeEditor` go to repositories directly, never through
  `diverListNotifierProvider` (its `updateDiver` and `addDiver` reload the
  list inside the transaction). Reloads go in `afterEditorSaved`.
- Every new string goes into all 11 locales (`lib/l10n/arb/app_*.arb`),
  then `flutter gen-l10n`. This plan adds three: `divers_edit_notFound`,
  `bodyWeight_deleteConfirmTitle`, `bodyWeight_deleteConfirmBody`.
- Strings the pages stop using (`divers_edit_discardDialogTitle`,
  `divers_edit_discardDialogContent`, `divers_edit_keepEditingButton`,
  `divers_edit_discardButton`, `divers_edit_saveButton`,
  `divers_edit_errorSaving`, `addChamber_save`) stay in the arb files: no
  check fails on an unused key, and leaving them keeps the arb diff small
  while plans 3 and 4 also edit those files. (Choice for Eric, see the
  question at the end.)
- If a write listed as held cannot run inside the transaction, stop and
  raise it with Eric. Do not split the Save silently.
- Units shown follow the active diver's unit settings, as today (the body
  weight list's weight, height and date).
- Keep every file under 800 lines.
- Run only the test files you wrote or changed, by path. Never a folder,
  never the whole suite; the pre-push hook runs the rest.
- Never run `build_runner` with `--build-filter`.
- Run `dart format` on changed files before each commit.
- Never launch a dev build of the app (it can open the diver's real log or
  sync). Screenshots come from headless widget tests.
- Commit only on this branch; push and open the PR only with Eric's say-so.
- Test traps from plans 1 and 2: read sittings by `change_log_operations`
  rows whose label starts `record_edit:` (never `settleAll` inside
  `testWidgets`); "nothing written" means no change log events under the
  operation, not no row; `pump()` between typing and tapping Save; a test
  that holds Save on the diver steps frames instead of `pumpAndSettle`.

## Shared code this plan changes

Plans 3 and 4 run at the same time in sibling worktrees, so this list is
the whole of what this plan touches outside the diver profile, body weight
and chamber files:

- `lib/shared/widgets/record_editing/`: **nothing.** The host is used as
  plan 2 shipped it. The profile pages override `editorCreating` (a
  getter the host already lets an editor override) to stay "editing"
  before the diver has loaded.
- `lib/core/router/app_router.dart`: the `diver-profile` routes (about lines
  1976-2044). `new` builds `NewDiverPage`; `new`, `personal`, `emergency`,
  `medical`, `notes`, `prior` and `emergency-card/add-chamber` gain
  `onExit: confirmLeaveRecordSitting`. Plans 3 and 4 edit other routes in
  the same file; a merge conflict there is line-local.
- `lib/l10n/arb/app_*.arb` (11 files) and the generated
  `lib/l10n/arb/app_localizations*.dart` (12 files): three new keys. A
  conflict with plans 3 and 4 in the generated files is resolved by taking
  both sides' arb keys and running `flutter gen-l10n` again.
- `lib/features/safety/data/repositories/emergency_chamber_repository.dart`:
  `createChamber` gains an optional `id`. Plan 4 works in
  `lib/features/safety/` too (incidents), in other files.

## Review Focus

1. **Save never writes another diver.** Unsaved medical changes for diver
   A; Save is held while the diver resolves; the active diver becomes B;
   Save ends: neither A nor B changed, and the page has closed. This is the
   bug the note names (`medical_info_edit_page.dart` wrote onto whoever was
   active at Save). Test in Task 2.
2. **A value changed in storage meanwhile survives Save.** A blood type
   synced in while the diver edits allergies, a name changed while the
   diver edits the email, the secondary contact changed while the diver
   edits the primary's phone: each survives. Tests in Tasks 2, 4 and 5.
3. **A new diver takes over without the page asking about itself.** After
   Save, the new diver becomes active with no dialog; a page underneath
   with unsaved work is asked, and declining leaves the old diver active
   with the new one created. Tests in Task 3.
4. **An untouched page is not dirty.** Prior experience stored as 90 h 5 m
   and shown as "90" and "5", a diver with no prior time (blank fields), a
   diving-since year, a diver with no sex set: opened and left alone, Save
   is disabled and Back asks nothing. Tests in Tasks 4 and 5.
5. **Going to a clearance document and back keeps the medical edits.** Type
   allergies, Add clearance, come back: the text is there and Save is
   enabled; a tab switch from the document page still asks about the
   medical changes. Test in Task 2.

---

### Task 0: Before screenshots

**Files:**
- Create (scratch, not committed): a golden harness copied into `test/`
  only while capturing, then deleted

- [ ] **Step 1: Capture the pages as they are today**

Headless captures of: personal info, medical info (with one clearance),
emergency contacts, notes, prior experience, the new-diver page, the body
weight list (two entries), and the add-chamber form, each at phone width
(390 x 844) and desktop width (1280 x 800), light and dark. Save them in
the session scratchpad, named `<nn>-<screen>-<width>-<theme>-before.png`.

- [ ] **Step 2: Check nothing is staged**

Run: `git status --short`
Expected: no new or changed file under `lib/` or `test/`.

---

### Task 1: The profile drafts and what each page writes

Pure functions, so the field-by-field rule is pinned without widgets.

**Files:**
- Create: `lib/features/settings/presentation/pages/diver_profile_drafts.dart`
- Test: `test/features/settings/presentation/pages/diver_profile_drafts_test.dart`

**Interfaces:**
- Consumes: `Diver.copyWith` (its sentinel lets `null` clear a field),
  `EmergencyContact`, `DiverSex`, `readNumber` (`number_input_validation.dart`).
- Produces, for Tasks 2 to 5:

```dart
typedef PersonalInfoDraft = ({String name, String email, String phone,
    String social, DiverSex? sex, String birthYear});
typedef MedicalInfoDraft = ({String bloodType, String allergies,
    String medications, String medicalNotes});
typedef EmergencyContactsDraft = ({String name1, String phone1,
    String relation1, String name2, String phone2, String relation2});
typedef DiverNotesDraft = ({String notes});
typedef PriorExperienceDraft = ({String diveCount, String hours,
    String minutes, int? divingSinceYear});

/// [stored] with each field whose text differs between [start] and [draft]
/// set from [draft]; every other field keeps its stored value.
Diver applyPersonalInfoDraft(Diver stored, PersonalInfoDraft start, PersonalInfoDraft draft);
Diver applyMedicalInfoDraft(Diver stored, MedicalInfoDraft start, MedicalInfoDraft draft);
Diver applyEmergencyContactsDraft(Diver stored, EmergencyContactsDraft start, EmergencyContactsDraft draft);
Diver applyDiverNotesDraft(Diver stored, DiverNotesDraft start, DiverNotesDraft draft);
Diver applyPriorExperienceDraft(Diver stored, PriorExperienceDraft start, PriorExperienceDraft draft);

/// A new diver from the new-diver page's form, under [id].
Diver newDiverFromDraft(String id, PersonalInfoDraft draft, DateTime now);
```

Parsing is today's, moved here: optional texts are trimmed, blank is null
(`email`, `phone`, `socialHandle`, `bloodType`, `allergies`, `medications`,
each contact field); `name`, `medicalNotes` and `notes` are trimmed
strings; birth year and prior counts read with `readNumber(integer: true)`
as the pages do today. Prior time is one value: when `hours` or `minutes`
changed, it is recomputed from both texts (both blank is null, otherwise
`h * 3600 + m * 60`). `divingSinceYear` changed writes `DateTime(year)` or
null. An emergency contact is rebuilt field by field
(`EmergencyContact(name: changed ? draft : stored.name, ...)`), since its
`copyWith` cannot clear a field.

- [ ] **Step 1: Write the failing tests**

```dart
test('an unchanged draft returns the stored diver as it is', ...);
  // For each apply: stored differs from start (a sync landed); start ==
  // draft; the result equals stored.
test('a changed optional field is written trimmed; others keep storage', ...);
  // Medical: start allergies '' -> draft ' nuts '; stored bloodType 'A+'
  // (synced, start had ''): result allergies 'nuts', bloodType 'A+'.
test('clearing an optional field writes null', ...);
test('a changed name keeps an email synced meanwhile', ...);
test('a changed primary phone keeps the stored secondary contact', ...);
test('a changed relation keeps the stored name and phone of that contact', ...);
test('changing minutes recomputes the prior time from both fields', ...);
  // start hours '90' minutes '5', draft minutes '10': 90*3600 + 600.
test('blanking both time fields writes no prior time', ...);
test('an untouched time keeps stored seconds that are not whole minutes', ...);
  // stored 5430 s; start == draft: result 5430.
test('clearing diving since writes null', ...);
test('notes are written trimmed', ...);
test('a new diver is built from the draft under the given id', ...);
  // newDiverFromDraft('n1', ...): id 'n1', name trimmed, blank email null,
  // birthYear parsed, createdAt == updatedAt == now.
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/settings/presentation/pages/diver_profile_drafts_test.dart`
Expected: FAIL, the file does not exist.

- [ ] **Step 3: Implement `diver_profile_drafts.dart`**

The typedefs and functions above, with doc comments in the voice of the
neighbouring files. A private `_changed(String a, String b)` and the
parsers keep each apply short.

- [ ] **Step 4: Run them to see them pass**

Run: the Step 2 command. Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/settings/presentation/pages/diver_profile_drafts.dart test/features/settings/presentation/pages/diver_profile_drafts_test.dart
git commit -m "feat(diver-profile): drafts that write only the fields a page changed"
```

---

### Task 2: The profile editor, the medical page on it, and the switch-diver fix

**Files:**
- Create: `lib/features/settings/presentation/pages/diver_profile_editor.dart`
- Modify: `lib/features/settings/presentation/pages/medical_info_edit_page.dart`
- Modify: `lib/core/router/app_router.dart` (the `medical` route)
- Modify: the 11 `lib/l10n/arb/app_*.arb` files (`divers_edit_notFound`:
  "This diver no longer exists.")
- Test: `test/features/settings/presentation/pages/medical_info_edit_page_test.dart`
- Test: `test/features/settings/presentation/pages/diver_profile_switch_test.dart`

**Interfaces:**
- Consumes: `RecordEditorHost` (plans 1 and 2: `openEditor`,
  `editorChanged`, `editorStartDraft`, `editorScaffold`, `disposeEditor`),
  `RecordSittingRefusal`, `currentDiverProvider`, `diverRepositoryProvider`,
  `diverListNotifierProvider`, `diverByIdProvider`, Task 1's medical draft.
- Produces, for Tasks 4 and 5:

```dart
/// A page that edits the active diver's own profile (issue #4527, phase 4):
/// the editor host, pinned to the diver the page was filled from.
mixin DiverProfileEditor<W extends ConsumerStatefulWidget, D>
    on ConsumerState<W>, RecordEditorHost<W, D> {
  // Supplied by the page.
  void fillFromDiver(Diver diver);     // sets its controllers and choices
  Diver applyEditorDraft(Diver stored, D start, D draft); // Task 1's apply

  // Provided.
  String? get profileDiverId;          // pinned once, from the first diver
  void openProfileEditor();            // call at the end of initState
  Widget profileScaffold(BuildContext context, {required WidgetBuilder form});
  // Overrides of the host:
  //   editorTable 'divers'; editorStoredId profileDiverId;
  //   editorCreating false; editorLeaveLocation '/settings/diver-profile';
  //   writeEditor; afterEditorSaved.
}
```

What each provided member does (the tests pin each):

- `openProfileEditor()`: `ref.listenManual(currentDiverProvider, ...,
  fireImmediately: true)`. On the first value with a diver, and only then:
  pin `profileDiverId = diver.id`, `fillFromDiver(diver)`, `openEditor()`,
  rebuild. Later values are ignored: the page keeps the diver it showed
  (a switch is the host's to act on, by closing the page). An error before
  the pin rebuilds, so `profileScaffold` can show it.
- `editorCreating` is false from the start, so the controller made in the
  host's `initState` is an edit sitting even before the diver has loaded.
  `editorRecordId` is read only at Save, when the pin is set.
- `profileScaffold`: `editorScaffold(context, body: ...)` with, before the
  pin, today's states (the error text, or a spinner), and `form(context)`
  after.
- `writeEditor(recordId)`: `getDiverById(recordId)` on
  `ref.read(diverRepositoryProvider)`, inside the sitting; null throws
  `RecordSittingRefusal((l10n) => l10n.divers_edit_notFound)`; otherwise
  `updateDiver(applyEditorDraft(stored, editorStartDraft as D,
  readEditorDraft()))`. `recordId` is the pinned diver, never the active
  one, which is the switch-diver fix: the page's Save can only write the
  diver it showed, and the host closes the page when another becomes
  active.
- `afterEditorSaved(messenger)`: `diverListNotifierProvider.notifier
  .refresh()` (not awaited), invalidate `diverByIdProvider(profileDiverId)`,
  and today's `settings_profileHub_saved` snackbar.

Medical page: `_MedicalInfoEditPageState extends
ConsumerState<MedicalInfoEditPage> with RecordEditorHost<MedicalInfoEditPage,
MedicalInfoDraft>, DiverProfileEditor<MedicalInfoEditPage,
MedicalInfoDraft>`. `editorTitle` `settings_profileHub_medicalInfo`;
`readEditorDraft` the four controllers' text; `validateEditor`
`_formKey.currentState?.validate() ?? false`; `applyEditorDraft`
`applyMedicalInfoDraft`. The four controllers' listeners call
`editorChanged()`. `PopScope`, `_hasChanges`, `_isSaving`,
`_showDiscardDialog`, `_save` and the `AppBarTextAction` go; the bar's
Cancel and Save and the shared discard dialog replace them.
`_MedicalClearancesCard` is unchanged.

- [ ] **Step 1: Retarget the medical tests, and write the failing ones**

The file moves from `_CapturingNotifier` to the test database:
`setUpTestDatabase()` in `setUp`, a `divers` row for `diver-1`,
`currentDiverIdProvider` overridden with a `MockCurrentDiverIdNotifier` set
to `diver-1`, `getBaseOverrides(ownerDocuments: ...)` kept for the
clearance list. Saved values are read back with
`DiverRepository().getDiverById('diver-1')`. The six existing tests keep
their names and assertions. New:

```dart
testWidgets('the bar is the tinted Cancel and Save bar, with no back arrow', ...);
testWidgets('an untouched page has Save disabled and Back asks nothing', ...);
testWidgets('Back after typing asks; Keep editing keeps the text', ...);
testWidgets('Save writes one change log operation labelled with the diver', ...);
  // One record_edit: row whose label decodes to table 'divers', id
  // 'diver-1', no cards; then the hub stand-in shows.
testWidgets('a blood type changed in storage meanwhile survives an allergies Save', ...);
  // After the page opens, write bloodType 'B-' straight to the row; type
  // allergies; Save: bloodType 'B-', allergies as typed. (Review Focus 2)
testWidgets('an avatar set meanwhile survives Save', ...);
  // Write photoPath on the row after the page opens: still there after
  // Save.
testWidgets('a diver gone at Save is refused and nothing is written', ...);
  // validatedCurrentDiverIdProvider overridden to a constant 'diver-1' (so
  // no switch closes the page first); delete the row; Save: snackbar
  // 'This diver no longer exists.', page still open.
testWidgets('a clearance document opened and closed keeps the medical edits', ...);
  // GoRouter with /documents/new stand-in: type allergies, Add clearance,
  // pop back: text kept, Save enabled; with the document page on top,
  // appExitGuardProvider.mayLeave() shows the discard dialog.
  // (Review Focus 5)
```

`diver_profile_switch_test.dart`: the test database with divers `a`
("Alice") and `b` ("Bob"), `MockCurrentDiverIdNotifier` at `a`, a GoRouter
whose `/settings/diver-profile` is a hub stand-in (`Text('Hub')`) and whose
`medical` child is the real page with `onExit:
confirmLeaveRecordSitting`, pushed from the hub. A switch "as the switcher
does" is `diver_switcher_sheet.dart`'s two lines: `if (await
guard.mayLeave()) await notifier.setCurrentDiver('b')`; the banner's is
`setCurrentDiver('b')` alone.

```dart
testWidgets('a switch with unsaved changes asks; Discard closes and writes neither diver', ...);
  // Hub shown; both rows as seeded.
testWidgets('Keep editing on the switch question keeps the page and the diver', ...);
  // currentDiverIdProvider still 'a'; text kept.
testWidgets('a switch that does not ask closes the page and writes nothing', ...);
  // The misplaced logbook banner's path.
testWidgets('a Save held while the diver resolves, then a switch, writes neither diver', ...);
  // validatedCurrentDiverIdProvider overridden to watch currentDiverIdProvider
  // and await a gate before answering; type allergies; set the gate;
  // invalidate the provider; tap Save; setCurrentDiver('b'); release the
  // gate; step frames: Hub shown, a and b unchanged. (Review Focus 1)
testWidgets('the active diver deleted elsewhere closes the page', ...);
  // Delete row 'a' through the database: the active diver resolves to 'b',
  // the page closes, nothing is written to 'b'.
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/settings/presentation/pages/medical_info_edit_page_test.dart test/features/settings/presentation/pages/diver_profile_switch_test.dart`
Expected: the new tests FAIL (no tinted bar; the switch and held-Save
cases write or keep the page).

- [ ] **Step 3: Implement `DiverProfileEditor`, move the medical page onto it**

As the Interfaces block says. The route gains `onExit:
confirmLeaveRecordSitting`.

- [ ] **Step 4: Add the string and generate**

Add `divers_edit_notFound` to all 11 arb files (English above; each
locale in its own words, as plan 2 did for `cylinderConfigs_edit_notFound`),
then `flutter gen-l10n`.

- [ ] **Step 5: Run the tests to see them pass**

Run: the Step 2 command. Expected: all pass, the existing ones included.

- [ ] **Step 6: Format, analyze, commit**

```bash
git add lib/features/settings/presentation/pages/diver_profile_editor.dart lib/features/settings/presentation/pages/medical_info_edit_page.dart lib/core/router/app_router.dart lib/l10n test/features/settings/presentation/pages/medical_info_edit_page_test.dart test/features/settings/presentation/pages/diver_profile_switch_test.dart
git commit -m "feat(diver-profile): medical info saves only the diver it opened with"
```

---

### Task 3: The new-diver page as a new-record sitting

**Files:**
- Create: `lib/features/settings/presentation/widgets/personal_info_fields.dart`
- Create: `lib/features/settings/presentation/pages/new_diver_page.dart`
- Modify: `lib/features/settings/presentation/pages/personal_info_edit_page.dart`
  (`isNewDiver` and its branch go; its form uses the shared fields, with no
  other change until Task 4)
- Modify: `lib/core/router/app_router.dart` (the `new` route)
- Test: `test/features/settings/presentation/pages/new_diver_page_test.dart`
- Modify: `test/features/settings/presentation/pages/personal_info_edit_page_test.dart`
  (its new-diver tests move to the new file)

**Interfaces:**
- Consumes: `RecordEditorHost` (no profile mixin: there is no stored
  diver), `newDiverFromDraft` (Task 1), `DiverRepository.createDiver` (its
  own transaction nests in the sitting's; it writes the diver's settings
  row too), `appExitGuardProvider`, `currentDiverIdProvider`.
- Produces, for Task 4:

```dart
/// The personal page's fields and their state, shared by the personal
/// page and the new-diver page.
class PersonalInfoForm {
  final TextEditingController name, email, phone, social, birthYear;
  DiverSex? sex;
  PersonalInfoDraft get draft;
  void fill(Diver diver);                  // today's _populateFromDiver
  void addListener(VoidCallback listener); // on the five controllers
  void dispose();
}

/// Today's fields, validators and body-estimate note, unchanged.
class PersonalInfoFields extends StatelessWidget {
  const PersonalInfoFields({super.key, required this.form,
      required this.onSexChanged});
  final PersonalInfoForm form;
  final ValueChanged<DiverSex?> onSexChanged;
}

class NewDiverPage extends ConsumerStatefulWidget {
  const NewDiverPage({super.key});
}
```

`_NewDiverPageState with RecordEditorHost<NewDiverPage, PersonalInfoDraft>`:
`editorTable` `'divers'`, `editorStoredId` null, `editorTitle`
`settings_profileHub_createDiverTitle`, `editorLeaveLocation`
`'/settings/diver-profile'`, `readEditorDraft` `form.draft`,
`validateEditor` the form's checks. `openEditor()` in `initState` (a blank
form is the starting record, not a seed); the form's listener and the sex
dropdown call `editorChanged()`. `writeEditor(id)`:
`ref.read(diverRepositoryProvider).createDiver(newDiverFromDraft(id,
readEditorDraft(), DateTime.now()))`. `afterEditorSaved(messenger)`: the
`settings_profileHub_saved` snackbar, then, with the list notifier, the
exit guard and the current-diver notifier read from `ref` first (the page
is leaving), not awaited:

```dart
/// The new diver becomes active once the app may leave what is open: the
/// page's own sitting has ended by now (a committed Save locks it, which
/// releases its exit blocker), so only other pages are asked.
static Future<void> adoptNewDiver({
  required DiverListNotifier list,
  required AppExitGuard guard,
  required CurrentDiverIdNotifier current,
  required String diverId,
});
// await list.refresh(); if (await guard.mayLeave()) await current.setCurrentDiver(diverId);
```

- [ ] **Step 1: Write the failing tests**

Test database, `MockCurrentDiverIdNotifier` at an existing diver `a`,
pushed from a hub stand-in.

```dart
testWidgets('a blank new diver has Save disabled; Cancel closes without asking', ...);
testWidgets('typing a name enables Save; Back then asks', ...);
testWidgets('Save creates the diver under the page id, with its settings', ...);
  // divers row with id == state.newEditorRecordId; a diver_settings row
  // for it; one record_edit: operation labelled 'divers' and that id.
testWidgets('the new diver becomes active and nothing asks about the page', ...);
  // No AlertDialog; currentDiverIdProvider == the new id; hub shown.
  // (Review Focus 3)
testWidgets('a new diver waits on the page underneath before taking over', ...);
  // Moved from the personal test: a held AppExitBlocker that refuses:
  // the diver is created, the active diver stays 'a'. (Review Focus 3)
testWidgets('a create that throws keeps the form and leaves no diver', ...);
  // diverRepositoryProvider overridden with a subclass whose createDiver
  // calls super then throws: no divers row for the id; name still typed;
  // snackbar recordEdit_saveFailed.
testWidgets('an empty name or a bad birth year writes nothing', ...);
testWidgets('a new diver typed in closes on a diver switch, writing nothing', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/settings/presentation/pages/new_diver_page_test.dart`
Expected: FAIL, `new_diver_page.dart` does not exist.

- [ ] **Step 3: Extract the fields, build `NewDiverPage`, drop `isNewDiver`**

`PersonalInfoFields` holds today's `TextFormField`s and
`_bodyEstimateFields` verbatim, reading `form`; the personal page builds
its body from them. The `new` route builds `const NewDiverPage()` with
`onExit: confirmLeaveRecordSitting`. The hub's two `context.push(
'/settings/diver-profile/new')` calls are unchanged.

- [ ] **Step 4: Run the tests to see them pass**

Run: `flutter test test/features/settings/presentation/pages/new_diver_page_test.dart test/features/settings/presentation/pages/personal_info_edit_page_test.dart test/features/settings/presentation/pages/diver_profile_hub_page_test.dart`
Expected: all pass (the personal page's edit tests unchanged).

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/settings/presentation/widgets/personal_info_fields.dart lib/features/settings/presentation/pages/new_diver_page.dart lib/features/settings/presentation/pages/personal_info_edit_page.dart lib/core/router/app_router.dart test/features/settings/presentation/pages/new_diver_page_test.dart test/features/settings/presentation/pages/personal_info_edit_page_test.dart
git commit -m "feat(diver-profile): a new diver is a new-record sitting"
```

---

### Task 4: Personal info on the profile editor

**Files:**
- Modify: `lib/features/settings/presentation/pages/personal_info_edit_page.dart`
- Modify: `lib/core/router/app_router.dart` (the `personal` route)
- Test: `test/features/settings/presentation/pages/personal_info_edit_page_test.dart`
- Test: `test/features/settings/presentation/pages/diver_profile_switch_test.dart`

**Interfaces:**
- Consumes: `DiverProfileEditor` (Task 2), `PersonalInfoForm` and
  `PersonalInfoFields` (Task 3), `applyPersonalInfoDraft` (Task 1).
- Produces: nothing new.

The page mixes in the host and `DiverProfileEditor` with
`PersonalInfoDraft`: `editorTitle` `settings_profileHub_personalInfo`,
`readEditorDraft` `form.draft`, `fillFromDiver` `form.fill`,
`validateEditor` the form's checks, `applyEditorDraft`
`applyPersonalInfoDraft`. The sex dropdown's change sets `form.sex` and
calls `editorChanged()`. Its `PopScope`, `_hasChanges`, `_isSaving`,
discard dialog and `_save` go.

- [ ] **Step 1: Retarget the personal tests, and write the failing ones**

Same move to the test database as Task 2. The edit tests keep their names
and assertions. New:

```dart
testWidgets('the bar is the tinted Cancel and Save bar, with no back arrow', ...);
testWidgets('an untouched page with no sex set has Save disabled', ...);
  // (Review Focus 4)
testWidgets('picking a sex is a change; picking it back is not', ...);
testWidgets('a name changed in storage meanwhile survives an email Save', ...);
  // (Review Focus 2)
testWidgets('an empty name keeps the page open and writes nothing', ...);
```

In `diver_profile_switch_test.dart`, add the personal page as a route and:

```dart
testWidgets('personal info closes on a switch, clean or changed', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/settings/presentation/pages/personal_info_edit_page_test.dart test/features/settings/presentation/pages/diver_profile_switch_test.dart`
Expected: the new tests FAIL.

- [ ] **Step 3: Move the page onto the profile editor**

The `personal` route gains `onExit: confirmLeaveRecordSitting`.

- [ ] **Step 4: Run the tests to see them pass**

Run: the Step 2 command. Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/settings/presentation/pages/personal_info_edit_page.dart lib/core/router/app_router.dart test/features/settings/presentation/pages/personal_info_edit_page_test.dart test/features/settings/presentation/pages/diver_profile_switch_test.dart
git commit -m "feat(diver-profile): personal info on the shared Cancel and Save bar"
```

---

### Task 5: Emergency contacts, notes and prior experience on the profile editor

**Files:**
- Modify: `lib/features/settings/presentation/pages/emergency_contacts_edit_page.dart`
- Modify: `lib/features/settings/presentation/pages/notes_edit_page.dart`
- Modify: `lib/features/settings/presentation/pages/prior_experience_edit_page.dart`
- Modify: `lib/core/router/app_router.dart` (the `emergency`, `notes` and
  `prior` routes)
- Test: `test/features/settings/presentation/pages/emergency_contacts_edit_page_test.dart`
- Test: `test/features/settings/presentation/pages/notes_edit_page_test.dart`
- Test: `test/features/settings/presentation/pages/prior_experience_edit_page_test.dart`
- Test: `test/features/settings/presentation/pages/diver_profile_switch_test.dart`

**Interfaces:**
- Consumes: `DiverProfileEditor` (Task 2); Task 1's emergency, notes and
  prior drafts and applies.
- Produces: nothing new.

Each page as the medical page in Task 2: titles
`settings_profileHub_emergencyContacts`, `settings_profileHub_notes`,
`divers_edit_priorExperienceSection`. The notes page has no `Form`, so its
`validateEditor` is `true`. The prior page's `_divingSince` becomes
`_divingSinceYear` (`int?`); the year picker and the clear button call
`editorChanged()` after their `setState`. Each page's private `PopScope`,
`_hasChanges`, `_isSaving`, discard dialog and `_save` go.

- [ ] **Step 1: Retarget the three test files, and write the failing tests**

The move to the test database as in Task 2; existing tests keep their
names and assertions. New, in each file:

```dart
testWidgets('the bar is the tinted Cancel and Save bar, with no back arrow', ...);
testWidgets('an untouched page has Save disabled and Back asks nothing', ...);
testWidgets('Back after a change asks; Discard returns to the hub', ...);
testWidgets('Save writes one change log operation labelled with the diver', ...);
```

And per page:

```dart
// emergency_contacts_edit_page_test.dart
testWidgets('a secondary contact changed meanwhile survives a primary phone Save', ...);
  // (Review Focus 2)
// prior_experience_edit_page_test.dart
testWidgets('90 h 5 m and a diving-since year, left alone, are unchanged', ...);
testWidgets('a diver with no prior time, left alone, is unchanged', ...);
  // (Review Focus 4, both)
testWidgets('typing the minutes back to what they were is no change', ...);
testWidgets('clearing diving since is a change and saves no year', ...);
// notes_edit_page_test.dart
testWidgets('notes typed back to the stored text are no change', ...);
```

In `diver_profile_switch_test.dart`, the three pages as routes and:

```dart
testWidgets('every profile page closes on a switch and writes nothing', ...);
  // A loop over personal, medical, emergency, notes, prior: open, change a
  // field, switch without asking: hub shown, diver 'a' as seeded.
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/settings/presentation/pages/emergency_contacts_edit_page_test.dart test/features/settings/presentation/pages/notes_edit_page_test.dart test/features/settings/presentation/pages/prior_experience_edit_page_test.dart test/features/settings/presentation/pages/diver_profile_switch_test.dart`
Expected: the new tests FAIL.

- [ ] **Step 3: Move the three pages onto the profile editor**

The three routes gain `onExit: confirmLeaveRecordSitting`.

- [ ] **Step 4: Run the tests to see them pass**

Run: the Step 2 command. Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/settings/presentation/pages/emergency_contacts_edit_page.dart lib/features/settings/presentation/pages/notes_edit_page.dart lib/features/settings/presentation/pages/prior_experience_edit_page.dart lib/core/router/app_router.dart test/features/settings/presentation/pages/emergency_contacts_edit_page_test.dart test/features/settings/presentation/pages/notes_edit_page_test.dart test/features/settings/presentation/pages/prior_experience_edit_page_test.dart test/features/settings/presentation/pages/diver_profile_switch_test.dart
git commit -m "feat(diver-profile): contacts, notes and prior experience on the shared bar"
```

---

### Task 6: Deleting a body weight entry asks first

**Files:**
- Modify: `lib/features/settings/presentation/pages/body_weight_edit_page.dart`
- Modify: the 11 `lib/l10n/arb/app_*.arb` files
- Test: `test/features/settings/presentation/pages/body_weight_edit_page_test.dart`

**Interfaces:**
- Consumes: `units.formatWeight`, `units.formatDate`, `common_action_cancel`,
  `common_action_delete`.
- Produces: two strings.
  - `bodyWeight_deleteConfirmTitle`: "Delete this measurement?"
  - `bodyWeight_deleteConfirmBody`: "{weight} on {date} will be deleted.
    This cannot be undone." (`weight` and `date` are `String`s, formatted
    in the diver's units)

The trash button opens an `AlertDialog` with those, Cancel
(`common_action_cancel`) and Delete (`common_action_delete`, a
`FilledButton` in the error colour); only Delete deletes. Adding an entry
is unchanged; the page gains no bar (it is a list, not an editor).

- [ ] **Step 1: Retarget the delete test, and write the failing one**

```dart
testWidgets('deletes a measurement from the list', ...);
  // Now taps Delete on the question before asserting it is gone.
testWidgets('deleting asks first, in the diver units; Cancel keeps the entry', ...);
  // Imperial: the question names "176.4 lbs" (80 kg) and the date; Cancel:
  // the entry is still listed and still stored.
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/settings/presentation/pages/body_weight_edit_page_test.dart`
Expected: both FAIL (no question).

- [ ] **Step 3: Add the strings and the question**

All 11 arb files, then `flutter gen-l10n`; then the dialog.

- [ ] **Step 4: Run the tests to see them pass**

Run: the Step 2 command. Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/settings/presentation/pages/body_weight_edit_page.dart lib/l10n test/features/settings/presentation/pages/body_weight_edit_page_test.dart
git commit -m "feat(body-weight): ask before deleting a measurement"
```

---

### Task 7: The chamber form as a new-record sitting

**Files:**
- Modify: `lib/features/safety/data/repositories/emergency_chamber_repository.dart`
  (`createChamber`, line 33)
- Modify: `lib/features/safety/presentation/pages/add_chamber_page.dart`
- Modify: `lib/core/router/app_router.dart` (the `add-chamber` route)
- Test: `test/features/safety/data/repositories/emergency_chamber_repository_test.dart`
- Test: `test/features/safety/presentation/pages/add_chamber_page_test.dart`
  (new)

**Interfaces:**
- Consumes: `RecordEditorHost` (`editorDiverId`, `newEditorRecordId`).
- Produces:
  - `EmergencyChamberRepository.createChamber({String? id, required String
    name, ...})`: the row takes `id` when given, a fresh v4 uuid when not.
    The other caller (`safety_writes.dart`) is unchanged.
  - `typedef ChamberDraft = ({String name, String country, String city,
    String phone, String notes});` in the page file.

`_AddChamberPageState with RecordEditorHost<AddChamberPage, ChamberDraft>`:
`editorTable` `'emergency_chambers'`, `editorStoredId` null, `editorTitle`
`addChamber_title`, `editorLeaveLocation`
`'/settings/diver-profile/emergency-card'`. `openEditor()` in `initState`;
the five controllers' listeners call `editorChanged()`. `validateEditor`
the form's checks. `writeEditor(id)`: a null `editorDiverId` throws
`StateError` (a null-diver row is a global chamber; the card already hides
Add with no diver); otherwise today's `createChamber` arguments with `id:
id, diverId: editorDiverId`. No `afterEditorSaved`: the card's listing
refreshes on the table's changes, and there is no snackbar today. The body
`FilledButton` goes. The design note lists "position" among the fields; the
form has none today and gains none (fields do not change).

- [ ] **Step 1: Write the failing tests**

Repository:

```dart
test('createChamber writes the chamber under the id it is given', ...);
test('createChamber without an id still makes one', ...);
```

Page (pushed from an emergency card stand-in; test database; diver `d1`):

```dart
testWidgets('the bar is the tinted Cancel and Save bar; no Save in the body', ...);
testWidgets('a blank form has Save disabled; Cancel closes without asking', ...);
testWidgets('Back after typing asks; Discard returns to the card', ...);
testWidgets('a missing name, country or phone writes nothing', ...);
testWidgets('Save creates the chamber under the page id for the diver', ...);
  // emergency_chambers row id == state.newEditorRecordId, diverId 'd1',
  // country upper-cased, blank city and notes null; one record_edit:
  // operation labelled 'emergency_chambers' and that id; card shown.
testWidgets('a create that throws keeps the form and says it failed', ...);
testWidgets('a chamber typed in closes on a diver switch, writing nothing', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/safety/data/repositories/emergency_chamber_repository_test.dart test/features/safety/presentation/pages/add_chamber_page_test.dart`
Expected: FAIL (no `id` parameter; no tinted bar).

- [ ] **Step 3: Add the `id` parameter, then move the page onto the host**

The `add-chamber` route gains `onExit: confirmLeaveRecordSitting`.

- [ ] **Step 4: Run the tests to see them pass**

Run: the Step 2 command, plus
`flutter test test/features/safety/presentation/pages/emergency_card_page_test.dart`.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
git add lib/features/safety/data/repositories/emergency_chamber_repository.dart lib/features/safety/presentation/pages/add_chamber_page.dart lib/core/router/app_router.dart test/features/safety/data/repositories/emergency_chamber_repository_test.dart test/features/safety/presentation/pages/add_chamber_page_test.dart
git commit -m "feat(safety): add a chamber on the shared Cancel and Save bar"
```

---

### Task 8: After screenshots, review, and the question to Eric

- [ ] **Step 1: Capture the after shots**

The same screens, widths and themes as Task 0, with the same harness,
named `-after.png`. Add: the medical page with a change (Save enabled),
and the body weight delete question.

- [ ] **Step 2: Review the branch**

Run the `code-review` skill on the branch with `--max-findings all`. Fix
every valid finding test-first, one commit per fix or per related group.
Re-run only the test files touched. Then `flutter analyze` on the whole
repo once (a change to `createChamber` or the personal page's constructor
can break a caller elsewhere).

- [ ] **Step 3: Write "After the build" into this plan and commit it**

What changed from the plan, as plans 1 and 2 did.

- [ ] **Step 4: Ask Eric before anything goes out**

Show the before and after shots and the review outcome, list the shared
files touched (for plans 3 and 4), and ask whether to push and open the PR.

- [ ] **Step 5: On his yes, merge main in (never rebase), push and open the PR**

Title: `feat(editing): the diver profile pages and the chamber form get the
shared Cancel and Save bar (Unified Editing, phase 4, plan 5)`. Body: what
changed, the switch-diver fix, `Refs #4527` (or `Closes #4527` if plans 3
and 4 have merged and nothing else in the program is open), the design
note and this plan linked, the screenshots attached through the project's
highest-numbered secret gist (`PR screenshots: submersion-app/submersion
(N)`, pngquant first, `<pr>-<nn>-<screen>-<state>.png`, raw URLs pinned
to the gist commit). Bind the PR and report its checks.

## After the build

Built natively on 2026-11-22 (commits 5801707 to the PR head, #4915). What
changed from this plan, for the plans after it:

- **No shared code changed.** `lib/shared/widgets/record_editing/` is as
  plan 2 left it. Shared files touched: `lib/core/router/app_router.dart`
  (the diver-profile routes only), the 11 arb files and the 12 generated
  localisation files (three new keys), and
  `emergency_chamber_repository.dart` (`createChamber` takes an `id`).
- **A profile page opens only on a settled diver the host agrees on.**
  `currentDiverProvider` keeps the diver it replaces while it reloads
  (Riverpod 3), and the host tracks `validatedCurrentDiverIdProvider`, which
  may not be known yet as the page opens. `openProfileEditor` listens to
  both and pins only when the diver has loaded and the id names the same
  diver, so a page pushed mid-switch never shows one diver while the host
  watches another (two review findings, fixed test-first).
- **A Save that comes to what is stored writes nothing** (a value typed
  with a trailing space, or one synced in meanwhile): no row write, no
  History entry.
- **`locale_numeric_input_test.dart` changed too.** Its prior experience
  group saved through the old mocked diver list; the pre-push hook caught
  it, and it now reads the stored diver through the profile harness. The
  same file holds plan 3's pre-dive template checks (untouched here), so a
  plan merging after this one may meet it in a merge.
- **The body weight add and delete read what they need before asking.** A
  page gone while its dialog was up threw on `ref`; both now hold the
  repository and the container from before the dialog (review findings;
  the add was older than this plan).
- **Task 3 left the personal page's fields alone**; Task 4 moved it onto
  the mixin and `PersonalInfoFields` in one step.
- **The profile tests share a harness**,
  `test/features/settings/presentation/pages/diver_profile_harness.dart`
  (seed, pump over a hub stand-in, switch as the switcher does or as the
  banner does, read sittings). It was not named in the plan.
- **A test that simulates a sync delete must go through Drift** (`db.delete`),
  not `customStatement`: a raw statement tells no table watcher, so the
  active diver never re-resolves.
- **A test that pumps a whole app twice in one `testWidgets` misbehaves**;
  split it into one test per case.
- **Review (code-review, high, all findings):** two findings, both fixed
  test-first. Whole-repo analyze clean.
- **Review (code-review, xhigh, all findings, on the PR):** seven findings;
  five fixed (the diver agreement above, the no-op Save, the body weight
  add, the test import order, this record). Two left: the write reads the
  form after the transaction opens rather than the draft that was
  validated (closing it needs the shared host to hand the validated draft
  to `writeEditor`), and a profile page that cannot load the diver shows
  the raw error text, as before this plan.
- **Second review (code-review, xhigh, all findings, on the PR):** four
  findings, all fixed: the diving-since picker no longer fails on a year
  after this one (one synced from a device already in the next year), and
  three tests now pin what had none: `Diver` equality covers every field a
  page writes (the no-op Save relies on it), a diver that fails to load
  opens no sitting, and the chamber form with no active diver writes
  nothing. Each new test was checked to fail with its guard removed.
- Unused strings (`divers_edit_discardDialog*`, `divers_edit_keepEditingButton`,
  `divers_edit_discardButton`, `divers_edit_saveButton`,
  `divers_edit_errorSaving`, `addChamber_save`) stay, by Eric's
  confirmation, to be removed once plans 3 to 5 have merged.

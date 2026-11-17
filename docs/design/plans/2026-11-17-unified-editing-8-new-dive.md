# Unified Editing, Plan 8: A New Dive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new dive opens on the dive page itself, already unlocked, with the Dive card and the starter set (Tanks, Buddies, Notes) laid out open and every other card in the Add strip. Save creates the dive and shows it locked; Cancel leaves without creating anything, asking first when something was entered. `/dives/new` and the list pane's `?mode=new` open it. Still behind `--dart-define=UNLOCK_EDITING=true` (issue #4527).

**Architecture:** A new dive is a sitting whose stored record is a **seed**: a `Dive` that exists only in memory, with a fresh id and today's defaults (the entry time now, the next number, the default cylinder, the default equipment set). The seed is the sitting's base, so defaults are not changes; anything a prefill brings (a scan, a passport cylinder, the trip board's slot, the logbook photo) is applied after unlock through the cards' own functions, so it is a change, with its card's dot. The page is `DiveDetailPage.newDive`: it builds the same header block, section list, strip and bar from the seed instead of `diveProvider`, and reads nothing that writes on viewing. Save goes through a new `DiveEditSaveService.create`, which inserts the dive and runs the sitting's held writes in one transaction and one change log operation, then the page runs what today's form runs after creating (weather, tide, rules, buddy mirror) and moves to the dive, locked.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), go_router 17, drift (SQLite), `flutter gen-l10n` (no new strings expected).

**Spec:** `docs/design/specs/2026-11-14-unified-editing-pattern-design.md`. Read "A new record", "Saving, cancelling, leaving", "History" and phase 1's "A new dive". The names used here are the ones plans 1 to 7, 9 and 10 built: read "For plans ..." and "After the review" in each `docs/design/plans/2026-11-1*-unified-editing-*.md`. Plan 7's PR is #4661.

## What a new dive is made of

| Part | Where it comes from | Counts as a change |
| --- | --- | --- |
| Id | `const Uuid().v4()`, made once per page | No |
| Diver | `validatedCurrentDiverIdProvider` | No |
| Entry time | now, to the whole minute, as the header's time row stores a time it picks | No |
| Number | `diveRepository.getNextDiveNumber(diverId:)`; none for a planned dive | No |
| Planned | the request (Plan dive) | No |
| Mode, dive types | `Dive`'s own defaults (open circuit; `diveTypeIds` as today's form, `['recreational']`) | No |
| First cylinder | `newSittingTank` with the default preset (`settings.defaultTankPreset` through `DefaultTankPresetResolver`) | No |
| Gear, weights, cylinders of the default set | `EquipmentSetSelector.bestSetFor(divePoints: const [], ...)` used through `useSetInSitting(auto: true)` on a throwaway sitting over the seed | No |
| Scan values (`DivePrefill`) | after unlock, through `setEntryTime`, the field sets, `assignDiveSite`, `setTanks` | Yes |
| Passport cylinder (`DivePrefill.tank`) | after unlock, `setTanks(..., replaced: true)` | Yes |
| Trip and slot (`tripId`, `tripCylinderId`) | after unlock, `setDiveTrip`, then the slot's cylinder over the first, `tankSlotChosen` | Yes |
| Logbook photo (`DivePrefill.photoPath`) | after unlock, held as a media add (`HeldMediaRow`) | Yes |

Laid out open at unlock: the header card (`diveHeaderCardId`), `tanks`, `buddies`, `notes`, and every card a prefill writes to: `environment` (air temperature), `weights` (`weightKg`), `details` (a trip), `media` (a logbook photo). Each is also marked added, as a card brought in from the strip, so a card the diver has hidden is laid out and is hidden again once the dive is saved.

## What happens at Save

Inside one transaction and one change log operation labelled `RecordEditLabel.encode(table: 'dives', id: <new id>, cardIds: <changed cards>)`, source manual:

1. `DiveRepository.createDive` with the merged dive (`diveSittingApply(session, seed)`), keeping the seed's id.
2. `assignMissingDiveNumbers(diverId:)` when the dive has no number and is neither planned nor a draft, as `PaginatedDiveListNotifier.addDive` does.
3. The trip's dates stretched to cover the dive when it has a trip (`stretchToCoverDives`).
4. The sitting's held writes (`session.runHeldWrites`): buddies, sightings, annotations, signatures, route links, the plan link, document owners, media rows, a site's altitude or location. They come after the dive, as each points at it.

After the commit, each best effort and guarded as `DiveSittingFollowUp` guards its steps: the list shows the new dive (`refreshAfterCreate`), the site list refreshes when a held write reached a site, `DiveSittingFollowUp.run` (with the seed as `before`, and the gear refresh always, since a new dive's quality scan, sensor summary and derived metrics have never run), then the steps only a new dive has, in today's order (`dive_edit_page.dart:6494-6725`): the weather fetch, the tide record, the logbook rules (not for a planned dive), the buddy mirror question (not for a planned dive). Then the page moves on: the full page replaces itself with `/dives/<id>`, the pane calls `onSaved(id)`, which selects the dive.

## Calls made in this plan, for Eric to check

Eric's standing choices apply: a locked record allows no change; one Save per unlock; day-to-day logging needs the unlock; a new dive opens already unlocked with the starter cards. Where a case could go either way the stricter, uniform option is written below first.

**Eric confirmed all thirteen as written on 2026-11-17** (calls 1 and 2 the stricter way), and chose "Native" to build the plan.

1. **Save is disabled until something is entered.** The seed's defaults (now, the next number, the default cylinder, the default set) are not entries, so an untouched new dive has nothing to save, the same rule as an unlocked dive with no changes. Cmd/Ctrl+S on it does nothing and the page stays. The other way: Save enabled from the start, as the mockup draws it and as today's form allows, creating a dive from the defaults alone.
2. **A prefill is an entry.** A scan, a passport cylinder, the trip board's slot and a logbook photo give their cards the dot, and Cancel asks before dropping them. Today's form drops a whole scan on Back without asking. The other way: prefills form part of the seed, and Cancel asks only once the diver types something.
3. **The weather fetch after Save is skipped when the sitting changed the Environment card.** The fetch writes wind, cloud, rain, humidity and the description over whatever the dive holds; a diver who typed or fetched weather in the sitting keeps it. Today's form fetches regardless. The other way: always fetch, as today.
4. **History reads "Added" for a new dive.** The entry's own action already reads Added (an insert at its root); its subtitle names the cards entered without "Edited:" (`Dive, Tanks, Notes`). The other way: leave the subtitle as for any sitting, "Edited: Dive, Tanks, Notes" beside Added.
5. **The bar's title is today's form title, "Log Dive"** (`diveLog_edit_appBarNew`), for a planned dive too, as today. No new string. The mockup wrote "New dive"; the other way is a new string `diveLog_newDive_title`.
6. **The unlocked bar of a new dive has no menu.** It has no operation to offer (plan 7), and History, export and display options have nothing to act on yet. The other way: a menu with Display options alone.
7. **The starter cards are laid out even when the diver has hidden them**, and are hidden again once the dive is saved, as a card brought in from the strip is.
8. **No banner and no site suggestion while creating.** A planned new dive's banner offers Mark as logged and Download now, both acting on a stored dive; today's form shows neither on a new dive. Every operation's button elsewhere on the page (a gear row's check-in chip) is disabled with "Save or cancel your changes first".
9. **After Save the page moves to the dive, locked**: the full page replaces itself with `/dives/<id>` (as today's form does), the pane selects the new row.
10. **The logbook photo is held in the sitting**, a pending tile on the Media card, and written in Save's transaction, as the spec says. Today it is attached after the write and a failure shows `ocrImport_editPage_photoAttachFailed`; a failure now fails the Save, which leaves the page unlocked with everything entered. A new `MediaImportService.prepareLocalFileForDive` copies the file and builds the row without writing it.
11. **A new dive left with nothing entered goes without asking**, by any route, and leaves nothing behind: no row, no History entry, no file.
12. **The steps after Save are today's**: weather (call 3), tide record, logbook rules and the buddy mirror question (neither for a planned dive), the quality scan and derived metrics. They run after the commit, before the page moves on, each best effort.
13. **The pane's `?mode=new` stays a plain new dive** (no prefill, not planned), as today.

## Not in this plan

- Plan 11, the switch-over: the old form, its Edit buttons and `&mode=edit` stay; with the switch off `/dives/new` and `?mode=new` open the old form exactly as today.
- Plan 7's left-open minors.
- A starter set that learns (spec non-goal), and creating other record types.
- Bulk edit and the table editor.

## Global Constraints

- With `kUnlockEditing` false, `/dives/new`, the pane's `?mode=new`, the dive page, the save service's existing `save`, the dive list and History build and behave exactly as today.
- Nothing is written before Save: no `dives` row, no change log operation, no safety review, no tide record, no media row or copied file kept after Cancel. Records created from a picker (a site, a buddy, a trip, a dive center, a species, a document) stay created after Cancel, as today.
- One Save is one transaction and one change log operation. A Save that fails writes nothing and leaves the page unlocked with every entry and dot intact; Save can be tried again.
- A new dive's card behaves as on an existing dive's page: same editors, same rules across cards, same validation. Nothing on the page moves when a card is opened.
- Anything that acts after an `await` checks `mounted`, reads `ref` and `context` before its first `await`, and a session it holds checks `isDisposed` and `isFrozen`. Work a save must wait for is `session.track`ed.
- Every value shown or typed follows the active diver's units. Settings are read with `settingsProvider.select(...)`.
- No file over 800 lines. `dive_detail_page.dart` is at 669 and `dive_detail_page_editing.dart` at 453: new page code goes in a new part file. `dive_list_page.dart` (1,259), `app_router.dart` (2,706) and `dive_edit_page.dart` must not grow beyond the lines named in their tasks. `record_edit_controller.dart` is at 589, `dive_providers.dart` at 1,671 (already over: add only the one method).
- Every new string goes in all 11 ARB files with a real translation, then `flutter gen-l10n`. This plan expects none (call 5).
- No em-dash characters anywhere; no emojis; no mention of any AI tool in code, commits or pull requests.
- Tests restore global state: `tester.view` via `addTearDown`, the test database via `tearDownTestDatabase()`, any provider override, singleton or `ShortcutCatalog` entry they install.
- `session.set(field, 10)` with a whole-number literal on a `double?` field fails at run time: tests spell `10.0`.
- Before each commit: `dart format .`, `flutter analyze`, and the test files the task wrote or changed, by path. Never a folder and never the whole suite: the pre-push hook runs the architecture and shared guards and the affected tests. Do not pipe `flutter test` into `grep` or `tail` to judge the result.
- Do not push or open a pull request; that waits for Eric.

## Review Focus

1. **Opening a new dive and leaving it writes nothing.** The page's viewing reads (the first safety review, the overlay sources, the tide card, the profile section) must not run for an id with no row, and Cancel after a picker made a site leaves the site but no dive, operation or media file. Pinned in Task 8, on the real test database.
2. **A Save that fails partway.** A held buddy write throws after `createDive`: no `dives` row, no operation, the page unlocked with its entries; a second Save creates the dive with the same id. Pinned in Tasks 3 and 8.
3. **Leaving a new dive with something entered, by each route**: Back, Cancel, Escape, a tab, another row in the pane, `?mode=new` again in the pane. Each asks; "Keep editing" stays with every entry; with nothing entered each goes without asking. Pinned in Tasks 6 and 7.
4. **A new dive from the trip board.** The slot's cylinder replaces the default one, the trip is set, Details and Tanks are open with dots, Cancel asks; Save writes the slot link and stretches the trip. Pinned in Tasks 5 and 8.
5. **A planned new dive**: no number at unlock and none assigned at Save, no banner while creating, no logbook rules or mirror question after; it opens locked with its planned banner. Pinned in Tasks 4, 6 and 7.

## Preparation

- [ ] Work on a branch cut from current `origin/main` (plans 1 to 7, 9 and 10 merged; head at or after `7f259faea0a`).
- [ ] In a fresh worktree: `git submodule update --init --recursive`, `flutter pub get`, then `dart run build_runner build --delete-conflicting-outputs` with no build filter.
- [ ] `flutter analyze` on the whole repository is clean before any change.
- [ ] Take the pull request's "before" pictures now, before any code changes, by the macOS window route (a dev build with `--dart-define=UNLOCK_EDITING=true` and its own `SUBMERSION_DB_PATH` on a copy of seeded sample data, never the live database): `/dives/new` at phone and desktop width, the pane's `?mode=new`, a planned new dive, and the trip board's Log dive. Light only: no colour changes.

## File Structure

New:

| File | Responsibility |
| --- | --- |
| `lib/features/dive_log/domain/entities/new_dive_request.dart` | `NewDiveRequest`: the prefill, the trip and its slot, whether planned |
| `lib/features/dive_log/presentation/widgets/dive_detail/editing/new_dive_seed.dart` | `newDiveSeed`, the seed's defaults |
| `lib/features/dive_log/presentation/widgets/dive_detail/editing/new_dive_prefill.dart` | `newDiveLaidOutCards`, `applyNewDivePrefill` |
| `lib/features/dive_log/presentation/pages/dive_detail_page_creating.dart` | Part file: the page while creating (the seed, the bar, Cancel, the steps after Save, moving on) |
| `lib/features/dive_log/presentation/pages/new_dive_after_create.dart` | `NewDiveAfterCreate`: weather, tide, rules and mirror after a create, read before the write as `DiveSittingFollowUp` is |
| `lib/features/dive_log/presentation/pages/dive_create_builder.dart` | `newDivePaneBuilder`: the pane's `createBuilder`, under the switch |

Modified, by task: see each task's Files.

---

### Task 1: A sitting that creates its record

**Files:**
- Modify: `lib/shared/widgets/record_editing/record_edit_controller.dart`, `lib/shared/widgets/record_editing/edit_session.dart`
- Test: `test/shared/widgets/record_editing/record_edit_controller_creating_test.dart`

**Interfaces:**
- Produces:
  - `EditSession<T>(T stored, {bool isNew = false})` and `bool get isNew`: the stored record is a seed that is not in the database.
  - `RecordEditController<T>({..., bool creating = false})` and `bool get isCreating`. Its sessions are made with `isNew: creating`.
  - `void unlock(T stored, {Iterable<String> laidOut = const []})`: each id in `laidOut` is opened and marked added in the same notification as the unlock, with no reveal request, before `onStart` runs.
  - While creating, `save()` on a clean sitting returns false, writes nothing and keeps the sitting (call 1). A dirty one saves as any other.

- [ ] **Step 1: Write the failing tests**

```dart
test('laid-out cards are open and added from the first notification', () {
  final c = RecordEditController<Note>(onSave: (_) async {});
  var seen = <Set<String>>[];
  c.addListener(() => seen.add({...c.openCardIds}));
  c.unlock(const Note('a'), laidOut: const ['header', 'notes']);
  expect(c.openCardIds, {'header', 'notes'});
  expect(c.addedCardIds, containsAll(['header', 'notes']));
  expect(seen.first, {'header', 'notes'});
  expect(c.revealRequest, isNull);
});
test('a creating sitting is new', () {
  final c = RecordEditController<Note>(onSave: (_) async {}, creating: true);
  c.unlock(const Note('a'));
  expect(c.isCreating, isTrue);
  expect(c.session!.isNew, isTrue);
});
test('saving a clean new record does nothing and keeps the sitting', () async {
  var saves = 0;
  final c = RecordEditController<Note>(onSave: (_) async => saves++, creating: true);
  c.unlock(const Note('a'));
  final session = c.session;
  expect(await c.save(), isFalse);
  expect(saves, 0);
  expect(c.isUnlocked, isTrue);
  expect(c.session, same(session));
});
test('saving a new record with a change calls onSave and ends the sitting', ...);
test('an existing record still locks on a clean save', () async {
  // creating: false; save() returns true, isUnlocked false, no onSave.
});
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/shared/widgets/record_editing/record_edit_controller_creating_test.dart`
Expected: FAIL, `creating`, `laidOut` and `isNew` are not defined.

- [ ] **Step 3: Implement** as specified. `laidOut` adds to `_addedCardIds` and `_openCardIds` without `_requestReveal`; `_restart` (after an operation) keeps `isNew: creating`.
- [ ] **Step 4: Run the new test file and `test/shared/widgets/record_editing/record_edit_controller_test.dart`.** Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing/record_edit_controller.dart lib/shared/widgets/record_editing/edit_session.dart test/shared/widgets/record_editing/record_edit_controller_creating_test.dart
git commit -m "feat(record-editing): a sitting that creates its record, with cards laid out at unlock"
```

---

### Task 2: History reads Added for a created record

**Files:**
- Modify: `lib/features/change_log/presentation/change_log_labels.dart`, `lib/features/change_log/presentation/widgets/change_log_entry_tile.dart`, `lib/features/change_log/presentation/pages/change_log_entry_page.dart`
- Test: `test/features/change_log/presentation/change_log_labels_test.dart` (add cases)

**Interfaces:**
- Produces: `changeLogSubtitle(l, units, operation, peerNames, {ChangeLogAction? rootAction})`. With `rootAction == ChangeLogAction.insert`, a sitting label reads its card names joined by `changeLog_label_recordEditSeparator`, without `changeLog_label_recordEdit`'s "Edited:" (call 4). Any other action, or none, reads as today. The tile passes `preview?.rootAction`; the entry page passes the action it already shows for the root (`change_log_entry_page.dart:298`).

- [ ] **Step 1: Write the failing tests**

```dart
test('a sitting that created its record names its cards without Edited', () {
  final op = operation(label: RecordEditLabel.encode(table: 'dives', id: 'd1', cardIds: ['notes', 'header']));
  expect(changeLogSubtitle(l, units, op, const {}, rootAction: ChangeLogAction.insert),
      endsWith('Dive, Notes'));  // header reads diveLog_detail_section_header
  expect(changeLogSubtitle(l, units, op, const {}, rootAction: ChangeLogAction.insert),
      isNot(contains('Edited')));
});
test('an edited record still reads Edited:', () {
  expect(changeLogSubtitle(l, units, op, const {}, rootAction: ChangeLogAction.update),
      contains('Edited: Dive, Notes'));
});
```

Use the file's existing `operation(...)` fixture helper and the English strings it already reads; check the header card's English title against `diveLog_detail_section_header` and spell the expectation with it.

- [ ] **Step 2: Run to see it fail.** `flutter test test/features/change_log/presentation/change_log_labels_test.dart`. Expected: FAIL, no `rootAction` parameter.
- [ ] **Step 3: Implement.** Split `_recordEditLabel` into the card-name list and its "Edited:" wrapping; the subtitle uses the list alone for an insert.
- [ ] **Step 4: Run the file and `test/features/change_log/presentation/change_log_entry_page_test.dart`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(change-log): a sitting that created its record reads as added`.

---

### Task 3: Creating a dive in one transaction

**Files:**
- Modify: `lib/features/dive_log/data/services/dive_edit_save_service.dart`, `lib/features/dive_log/presentation/providers/dive_providers.dart`
- Modify: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_harness.dart` (`FakeSave.create`), and any other `implements DiveEditSaveService` fake (`grep -rln "implements DiveEditSaveService" test`)
- Test: `test/features/dive_log/data/services/dive_edit_save_service_create_test.dart`, `test/features/dive_log/presentation/providers/dive_list_refresh_after_create_test.dart`

**Interfaces:**
- Produces:
  - `Future<({Dive after, List<TripDateStretch> tripDateStretches})> DiveEditSaveService.create({required Dive dive, required Iterable<String> changedCardIds, Future<void> Function()? alsoWrite})`: the four steps of "What happens at Save", in that order, inside `ChangeLogScope.run(..., source: ChangeLogSource.manual, label: RecordEditLabel.encode(table: 'dives', id: dive.id, cardIds: changedCardIds))` and `_db.transaction`. `after` is the dive read back by id at the end of the transaction (its number may have been assigned). It throws `StateError` when `dive.id` is empty or a dive with that id exists.
  - `Future<void> PaginatedDiveListNotifier.refreshAfterCreate(Dive created)`: what `addDive` does after `createDive`, shared with it: reload when `created.diverId` is not the current diver, a silent reload under a filter, else prepend; invalidate `diveNumberingInfoProvider` when a number may have been assigned, the statistics, the related providers and the old provider.
  - `FakeSave.create` in the harness: records `(dive, cards)` in a `creates` list, honours `failWith` and `hold`, runs `alsoWrite`, sets `stored` to the dive and returns it.

- [ ] **Step 1: Write the failing tests** (on the test database, `setUpTestDatabase()` / `tearDownTestDatabase()`; repositories built in `setUp`)

```dart
test('creates the dive with its own id in one manual operation', () async {
  final r = await service.create(dive: seed(id: 'new-1', notes: 'Wall'), changedCardIds: ['notes']);
  expect(r.after.id, 'new-1');
  expect((await diveRepo.getDiveById('new-1'))!.notes, 'Wall');
  final ops = await changeLog.operations();
  expect(ops, hasLength(1));
  expect(ops.single.label, RecordEditLabel.encode(table: 'dives', id: 'new-1', cardIds: ['notes']));
  expect(ops.single.source, ChangeLogSource.manual);
});
test('held writes run after the dive, inside the operation', () async {
  // alsoWrite links a buddy row to new-1 (BuddyRepository.setBuddiesForDive);
  // the link exists and its event belongs to the same operation.
});
test('a held write that throws leaves no dive and no operation', () async {
  await expectLater(service.create(dive: seed(id: 'new-2'), changedCardIds: ['notes'],
      alsoWrite: () async => throw StateError('boom')), throwsStateError);
  expect(await diveRepo.getDiveById('new-2'), isNull);
  expect(await changeLog.operations(), isEmpty);
  // and a second create with the same id succeeds
});
test('an unnumbered logged dive is numbered; a planned one is not', ...);
test('a dive with a trip stretches the trip to cover it', ...);  // tripDateStretches has one entry
test('an id already stored is refused', ...);
// dive_list_refresh_after_create_test.dart
test('the created dive is prepended and counted', ...);
test('numbering info is read again', ...);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/dive_log/data/services/dive_edit_save_service_create_test.dart test/features/dive_log/presentation/providers/dive_list_refresh_after_create_test.dart`
Expected: FAIL, `create` and `refreshAfterCreate` are not defined.

- [ ] **Step 3: Implement** `create`, then move `addDive`'s tail into `refreshAfterCreate` and call it from `addDive` (the diver-switch counter `addDive` reads before its write stays in `addDive`, which passes it on as an optional `diverSwitchesAtStart`). Add `FakeSave.create`.
- [ ] **Step 4: Run the two new files and `test/features/dive_log/data/services/dive_edit_save_service_test.dart`, `dive_edit_save_service_history_test.dart`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): create a dive and its sitting's writes in one transaction`.

---

### Task 4: The seed

**Files:**
- Create: `lib/features/dive_log/domain/entities/new_dive_request.dart`, `lib/features/dive_log/presentation/widgets/dive_detail/editing/new_dive_seed.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/new_dive_seed_test.dart`

**Interfaces:**
- Produces:
  - `class NewDiveRequest { const NewDiveRequest({this.prefill, this.tripId, this.tripCylinderId}); final DivePrefill? prefill; final String? tripId; final String? tripCylinderId; bool get isPlanned => prefill?.isPlanned ?? false; }`
  - `Future<Dive> newDiveSeed(ProviderRead read, NewDiveRequest request, {DateTime Function() now = DateTime.now, String Function()? newId})`: the "not a change" rows of the table under "What a new dive is made of". The number and the preset are read inside a `try`; a failure leaves the number empty or the built-in default cylinder, as the form does. The default set is applied with `useSetInSitting(EditSession(seed, isNew: true), set, items, read: read, auto: true)`, awaited, and the seed is that sitting's `working`; a failure to read the sets leaves the seed without them (`dive_edit_page.dart:4448`). A planned request has no number.

- [ ] **Step 1: Write the failing tests** (a `ProviderContainer` with the repositories faked or on the test database)

```dart
test('a new dive starts now, numbered, with the default cylinder', () async {
  final seed = await newDiveSeed(container.read, const NewDiveRequest(), now: () => DateTime(2026, 11, 17, 9, 30, 41));
  expect(seed.id, isNotEmpty);
  expect(seed.diverId, 'diver-1');
  expect(seed.diveNumber, 43);                  // stored max is 42
  expect(seed.tanks.single.volume, 11.1);       // the default preset's
  expect(seed.tanks.single.startPressure, 200.0);
  expect(seed.isPlanned, isFalse);
});
test('the entry reads back as the time it was opened, to the minute', () async {
  // diveEntryField.read(seed) shown by the header's time row reads 09:30.
});
test('a planned dive has no number', ...);
test('the default equipment set is on the seed', ...);       // gear, its weights
test('a number that cannot be read leaves it empty', ...);
test('equipment sets that cannot be read leave none', ...);
```

Before writing the time test, read how `DiveTimeRow` turns a picked time into the stored instant (`pickedInstant`, plan 4) and build the seed's entry the same way (`wholeMinute`), so the row reads back what the clock said.

- [ ] **Step 2: Run to see them fail.** `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/new_dive_seed_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): the seed a new dive's sitting starts from`.

---

### Task 5: Prefills, and the cards laid out

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/new_dive_prefill.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_trip_rows.dart` (extract `setDiveTrip`), `dive_tank_rules.dart` (`suggestTankSlots` on a new sitting), `lib/features/media/data/services/media_import_service.dart` (`prepareLocalFileForDive`)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/new_dive_prefill_test.dart`, `test/features/media/data/services/media_import_service_prepare_local_test.dart`

**Interfaces:**
- Consumes: `NewDiveRequest` (Task 4), `EditSession.isNew` (Task 1), `assignDiveSite` through `DiveSiteAssigner`, `setEntryTime`, `setTanks`, `tankSlotChosen`, `tankFromTripCylinder`, `addMediaToSitting`, `HeldMediaRow`.
- Produces:
  - `List<String> newDiveLaidOutCards(NewDiveRequest request)`: `diveHeaderCardId`, `tanks`, `buddies`, `notes`, then `environment` when the prefill has an air temperature, `weights` when it has `weightKg`, `details` when there is a `tripId`, `media` when it has a `photoPath`.
  - `void setDiveTrip(EditSession<Dive> session, Trip? trip, {required TripSlotReader readSlots})`: the body of `_DiveTripRowState._set`, which now calls it.
  - `void applyNewDivePrefill(EditSession<Dive> session, NewDiveRequest request, {required DiveSiteAssigner assignSite, required ProviderRead read, required String diveId})`: each `DivePrefill` value through the card function a diver's edit uses (the mapping at `dive_edit_page.dart:894-1014`: the date always and the time of day only with `hasTimeOfDay`, `durationMinutes` as the bottom time in seconds, temperatures and depth in metres as stored, `weightKg` as one `DiveWeight(type: WeightType.mixed)`, a tank with a volume replacing the first cylinder's spec and one without keeping it); then the trip (`tripRepositoryProvider.getTripById`, `setDiveTrip`) and its slot (the state of `tripCylinderId` at the entry time replaces the first cylinder through `tankFromTripCylinder`, `setTanks(replaced: true)`, `tankSlotChosen(none: false)`); then the logbook photo (`prepareLocalFileForDive`, `addMediaToSitting(session, [HeldMediaRow(prepared)])`). The async parts are `session.track`ed and drop their result when the sitting has ended or is frozen.
  - In `suggestTankSlots`, a cylinder of a new sitting's seed is eligible for a slot, as the form treats its starter cylinder (`storedIds` is empty when `session.isNew`).
  - `Future<PreparedMedia> MediaImportService.prepareLocalFileForDive({required File sourceFile, required String diveId, DateTime? takenAt, String subdirectory = kScannedLogsSubdirectory})`: the copy and the row `importLocalFileForDive` builds, without the insert; `importLocalFileForDive` becomes prepare plus insert, unchanged in behaviour.

- [ ] **Step 1: Write the failing tests**

```dart
test('the starter cards are laid out, and the cards a prefill fills', () {
  expect(newDiveLaidOutCards(const NewDiveRequest()), [diveHeaderCardId, 'tanks', 'buddies', 'notes']);
  expect(newDiveLaidOutCards(const NewDiveRequest(prefill: DivePrefill(airTempCelsius: 28, weightKg: 4)), tripId: 't1'),
      containsAll(['environment', 'weights', 'details']));
});
test('a scan is entered: its cards carry the dot', () async {
  // seed via a hand-built Dive; prefill maxDepthMeters 18.2, notes 'Turtle', rating 4,
  // dateTime 2024-03-12 with hasTimeOfDay false.
  expect(session.valueOf(diveMaxDepthField), 18.2);
  expect(session.valueOf(diveNotesField), 'Turtle');
  expect(session.changedCardIds, containsAll([diveHeaderCardId, 'notes']));
  expect(session.valueOf(diveEntryField).day, 12);
  expect(session.valueOf(diveEntryField).hour, seed.effectiveEntryTime.hour);
});
test('a scanned site goes through the site rules', ...);    // assignSite called once with it
test('a passport cylinder replaces the default one', ...);
test('the trip board slot puts its cylinder first and sets the trip', ...);
test('a trip on a new dive suggests a slot for the starter cylinder', ...);
test('a prefill that answers after Cancel changes nothing', ...);  // session disposed before the trip read returns
test('the logbook photo is held, not written', ...);              // a held media add; no media row
// media_import_service_prepare_local_test.dart
test('prepareLocalFileForDive copies the file and writes no row', ...);
```

- [ ] **Step 2: Run to see them fail.** `flutter test` on the two new files. Expected: FAIL.
- [ ] **Step 3: Implement.** Move `_set`'s body out of `DiveTripRow` without changing what the row does.
- [ ] **Step 4: Run the two new files and the trip row's and tank rules' existing tests** (`grep -rln "DiveTripRow\|suggestTankSlots\|importLocalFileForDive" test`, by file). Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): a new dive's prefills go through the cards' own rules`.

---

### Task 6: The page while creating

**Files:**
- Create: `lib/features/dive_log/presentation/pages/dive_detail_page_creating.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`, `dive_detail_page_editing.dart`, `dive_detail_page_actions.dart` (the `diveId` getter), `dive_detail_page_operations.dart`, `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_header_block.dart`, the pane header (`dive_detail_embedded_header.dart` or wherever its banners are built)
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_new_dive_test.dart`; the harness gains `pumpNewDivePage`

**Interfaces:**
- Consumes: Tasks 1, 4 and 5.
- Produces:
  - `const DiveDetailPage.newDive({Key? key, NewDiveRequest request = const NewDiveRequest(), bool embedded = false, ValueChanged<String>? onCreated, VoidCallback? onCreateCancelled, bool unlockEditing = kUnlockEditing})`, with `final NewDiveRequest? newDiveRequest` on the widget (null on the existing constructor) and `diveId` `''`.
  - In the state: `String get diveId` (in `_DiveDetailPageActions`) is the page's new id while `widget.newDiveRequest != null`; every `widget.diveId` in the page's library reads `diveId` instead. `bool get isCreating`: a new dive not yet created.
  - `_DiveDetailPageCreating` (the new part): `Future<void> _openNewDive()` (from `initState` when `unlockEditing` and creating: `newDiveSeed`, then `editController.unlock(seed, laidOut: newDiveLaidOutCards(request))`, then `applyNewDivePrefill`), `Widget _buildCreating(BuildContext context)`, `Future<void> _cancelNewDive()` (`cancelSitting`, then `_leaveNewDive()`), `void _leaveNewDive()` (pane: `onCreateCancelled`; page: `pop` when it can, else `context.go('/dives')`).
  - The controller is made with `creating: widget.newDiveRequest != null`.
  - `DiveDetailHeaderBlock(creating:)` and the pane header: no banner and no site suggestion while creating (call 8).
  - `operationBlock` is `RecordOperationBlock.unsaved` while creating.

What the page does while creating:

- **Build.** Before the seed is ready: the loading scaffold with the title `diveLog_edit_appBarNew`. Then `_buildContent(context, seed)` as for a stored dive, with `shownDive` reading the sitting. The page does not watch `diveProvider`, does not call `followStoredDive`, and does not listen to `safetyReviewProvider` or `overlaySourcesProvider` (they read, and the review writes, for a stored dive). It does not redirect to the master-detail split. If the sitting has ended without a create (a Back already leaving) it draws an empty `Scaffold`.
- **Bar.** `RecordEditBar(title: l10n.diveLog_edit_appBarNew, canSave: isDirty, actions: const [] /* call 6 */, onCancel: _cancelNewDive, onSave: _saveAndReport)`; the pane's editing row the same.
- **Keys.** The shortcut target's unlock does nothing while creating; its cancel is `_cancelNewDive`.
- **Leaving.** Back goes through `RecordEditLeaveGuard` as for any sitting; a tab, a pane row and quitting through `RecordSittingExitBlocker`, which asks only when there is something entered.

- [ ] **Step 1: Write the failing tests** (through `pumpNewDivePage(tester, {NewDiveRequest request, bool embedded, ...})` in the harness, which overrides `diveEditSaveServiceProvider` with `FakeSave`, routes `/dives/new` to `DiveDetailPage.newDive(unlockEditing: true)` with `onExit: confirmLeaveRecordSitting`, and seeds the seed's reads)

```dart
testWidgets('opens unlocked with the Dive card and the starter set open', (tester) async {
  await pumpNewDivePage(tester);
  expect(find.text('Log Dive'), findsOneWidget);
  expect(action(tester, 'Save').onPressed, isNull);          // call 1
  final controller = editControllerOf(tester);  // RecordEditScope.maybeOf<Dive> from the page
  expect(controller.openCardIds, {diveHeaderCardId, 'tanks', 'buddies', 'notes'});
  expect(find.text('Done'), findsNWidgets(4));     // each open card's header, as the unlock tests find it
  expect(find.byKey(const ValueKey('addStrip_equipment')), findsOneWidget);
  expect(find.byIcon(Icons.lock_outline), findsNothing);
});
testWidgets('typing a note enables Save', ...);
testWidgets('Cancel with nothing entered leaves without asking', ...);  // location back to /dives
testWidgets('Cancel with a note asks; Keep editing keeps it; Discard leaves', ...);
testWidgets('Escape cancels as the bar does', ...);
testWidgets('Back with a note asks', ...);
testWidgets('a tab with a note asks', ...);                 // router.go('/sites') refused on Keep editing
testWidgets('Cmd+S on an untouched new dive stays', ...);
testWidgets('a hidden Notes card is laid out', ...);       // visible: {tags}
testWidgets('a planned new dive shows no banner and no number', ...);
testWidgets('the menu offers nothing', ...);                // no overflow button in the bar
testWidgets('a gear check-in chip is disabled with its reason', ...); // the default set's gear row
testWidgets('the trip board request opens Details and Tanks with dots', ...);
```

- [ ] **Step 2: Run to see them fail.** `flutter test test/features/dive_log/presentation/pages/dive_detail_page_new_dive_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** `wc -l` each page file before and after: `dive_detail_page.dart` must stay under 700, `dive_detail_page_editing.dart` under 500.
- [ ] **Step 4: Run the new file and the existing page files that cover what moved**: `dive_detail_page_test.dart`, `dive_detail_page_unlock_test.dart`, `dive_detail_page_unlock_leave_test.dart`, `dive_detail_page_unlock_menu_test.dart`, `dive_detail_page_unlock_header_block_test.dart`, `dive_detail_page_unlock_pane_test.dart`, `dive_detail_page_unlock_shortcuts_test.dart`. Expected: PASS, the existing ones unchanged.
- [ ] **Step 5: Commit** `feat(dive-log): a new dive opens on the dive page, unlocked, with the starter cards`.

---

### Task 7: Save creates the dive

**Files:**
- Create: `lib/features/dive_log/presentation/pages/new_dive_after_create.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_creating.dart`, `dive_detail_page_editing.dart` (`_saveSitting` and `_saveAndReport` hand a creating sitting to the part)
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_new_dive_save_test.dart`, `test/features/dive_log/presentation/pages/new_dive_after_create_test.dart`

**Interfaces:**
- Consumes: `DiveEditSaveService.create`, `refreshAfterCreate` (Task 3), `DiveSittingFollowUp`.
- Produces:
  - `class NewDiveAfterCreate { NewDiveAfterCreate.read(BuildContext context, WidgetRef ref); Future<void> run(BuildContext context, {required Dive created, required Set<String> changedCardIds}); }`: read before the write (the weather and tide repositories, `TideCalculator`, `captureRulesAfterCreate(context, ref)`, `diveMirrorServiceProvider`). `run`, each step in its own guard, in this order: the weather fetch when the dive has a site with coordinates and `changedCardIds` does not hold `environment` (call 3), not awaited, as today; `recordDiveTide` when it has a site with coordinates; then, not for a planned dive, `rulesAfterCreate(subject: RuleSubject.dives, ids: [id])` and, when `context` is mounted and there are candidates, `showMirrorDiveDialog` and `runDiveMirror` (`dive_edit_page.dart:6626-6725`).
  - `_createSitting(EditSession<Dive> session)` in the part, the `onSave` of a creating controller: `service.create(dive: diveSittingApply(session, session.stored), changedCardIds: session.changedCardIds, alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null)` inside `undoMediaOnFailure`; then `refreshAfterCreate`, the site refresh, `followUp.run(before: session.stored, after: created, ...)` with the gear refresh forced on (`changedCardIds` plus `tanks`), and keeps `_created`.
  - `_saveAndReport` while creating: `NewDiveAfterCreate.read` before `controller.save()`; when it returns true, `await afterCreate.run(context, created: _created!, ...)`, then the page moves on: pane `widget.onCreated?.call(id)`, page `context.pushReplacement('/dives/$id')` (call 9). A failed save reports as for any sitting and the page stays.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('Save creates the dive and opens it locked', (tester) async {
  final (:router, :save) = await pumpNewDivePage(tester);
  await typeNote(tester, 'First dive');
  await tester.tap(find.text('Save'));
  await settle(tester);
  expect(save.creates.single.dive.notes, 'First dive');
  expect(save.creates.single.cards, contains('notes'));
  expect(location(router), '/dives/${save.creates.single.dive.id}');
});
testWidgets('in the pane, Save hands the new id to onCreated', ...);
testWidgets('a Save that fails stays unlocked with the note', ...);   // FakeSave.failWith; snackbar recordEdit_saveFailed
testWidgets('a held buddy is written by the same create', ...);       // alsoWrite ran
// new_dive_after_create_test.dart (fakes for each repository)
test('weather and tide for a site with coordinates', ...);
test('no weather when the sitting changed the Environment card', ...);
test('a planned dive runs no rules and asks no mirror question', ...);
test('a step that throws does not stop the next', ...);
```

- [ ] **Step 2: Run to see them fail.** Both new files. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the two new files, `dive_detail_page_new_dive_test.dart` and `dive_detail_page_unlock_test.dart`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): Save creates a new dive, then runs what a new dive is owed`.

---

### Task 8: The routes, the pane, and nothing written before Save

**Files:**
- Create: `lib/features/dive_log/presentation/pages/dive_create_builder.dart`
- Modify: `lib/core/router/app_router.dart` (`newDivePage`, the `newDive` route's `onExit`), `lib/features/dive_log/presentation/pages/dive_list_page.dart` (both `createBuilder`s, `:245` and `:487`)
- Modify: `test/features/dive_log/presentation/pages/dive_edit_trip_cylinder_test.dart` (its `newDivePage` test reads the page it built as `DiveEditPage`)
- Test: `test/core/router/new_dive_route_test.dart`, `test/features/dive_log/presentation/pages/new_dive_end_to_end_test.dart`

**Interfaces:**
- Produces:
  - `Widget newDivePage(GoRouterState state, {bool unlockEditing = kUnlockEditing})`: with the switch, `DiveDetailPage.newDive(request: NewDiveRequest(prefill: state.extra as DivePrefill?, tripId: ..., tripCylinderId: ...), unlockEditing: true)`; without it, today's `DiveEditPage`, unchanged.
  - The `newDive` route gains `onExit: confirmLeaveRecordSitting`, as `diveDetail` has, so a `go` from `/dives/new` to the dive list asks.
  - `Widget Function(BuildContext, void Function(String), VoidCallback) newDivePaneBuilder({bool unlockEditing = kUnlockEditing})`: `DiveDetailPage.newDive(embedded: true, onCreated: onSaved, onCreateCancelled: onCancel, unlockEditing: true)` with the switch, today's `DiveEditPage(embedded: true, ...)` without. Both of `dive_list_page.dart`'s `createBuilder`s use it; that file must not grow.

- [ ] **Step 1: Write the failing tests**

```dart
// new_dive_route_test.dart
testWidgets('with the switch, /dives/new opens the dive page creating, with its request', ...);
testWidgets('without it, the form, with the trip and slot', ...);
testWidgets('the pane builder follows the switch', ...);
// new_dive_end_to_end_test.dart: the real test database, the real DiveEditSaveService,
// the page through pumpNewDivePage, which this task gives `realSave: true` (no FakeSave override).
testWidgets('opening a new dive and cancelling writes nothing', (tester) async {
  final before = await counts();            // dives, dive_safety_findings, tide_records, media, change log operations
  await pumpNewDivePage(tester, realSave: true);
  await tester.tap(find.text('Cancel'));
  await settle(tester);
  expect(await counts(), before);
});
testWidgets('a site made from the picker survives Cancel; no dive does', ...);
testWidgets('Save writes one dive and one operation, with its buddy', ...);
testWidgets('a Save that fails on the buddy leaves nothing, and saves on the second try', ...);
testWidgets('the trip board new dive saves its slot link and stretches the trip', ...);
testWidgets('in the pane, a new dive with a note asks before another row', ...);
testWidgets('in the pane, a new dive with nothing entered goes to another row without asking', ...);
```

- [ ] **Step 2: Run to see them fail.** Both new files. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the two new files, `dive_edit_trip_cylinder_test.dart`, `test/core/router/app_router_test.dart` and `dive_detail_page_unlock_pane_test.dart`.** Expected: PASS.
- [ ] **Step 5: Run `flutter analyze` on the whole repository and `dart format .`.** Expected: no issues, no changes.
- [ ] **Step 6: Commit** `feat(dive-log): /dives/new and the pane's new dive open the dive page, behind the switch`.

---

## Pull request

One, `Refs #4527`. It touches `lib/**/presentation/` and the History wording, so it carries the "before" pictures from Preparation and the same views after, by the macOS window route with the switch on: `/dives/new` at phone and desktop width, a note typed (Save lit, the Notes dot), the pane's new dive, a planned new dive, the trip board's Log dive, the new dive opened locked after Save, and its History entry reading Added. A line says the page is unreachable without the build switch; with the switch off nothing looks different. Pushing and opening it waits for Eric.

## For plan 11

- **The switch-over.** `newDivePage`'s and `newDivePaneBuilder`'s `DiveEditPage` branches go with the form. `DivePrefill` stays: it is the scan's and the passport's hand-over, now read by `applyNewDivePrefill`.
- **The form's create-only tests** (`dive_edit_trip_cylinder_test.dart`, the prefill and planned tests of `dive_edit_page*_test.dart`) have their replacements in Tasks 4 to 8; plan 11 deletes them with the form.

---

## After the review

The plan was built as written in one session (Eric chose "Native"), then reviewed as a whole branch (`/code-review xhigh --fix`). This is what differs from the task text above, for whoever writes plan 11.

### Names that changed, or were added

| Above | Now |
| --- | --- |
| `applyNewDivePrefill(..., read:, diveId:)` | Takes its reads as seams: `readTrip`, `readSlots`, `preparePhoto` (`LogbookPhotoPreparer`), and `onPhotoFailed` |
| `setDiveTrip` extracted from `DiveTripRow` | Not extracted: the prefill sets `diveTripField`, puts the chosen slot on the first cylinder, then calls `suggestTankSlots`. A new dive has no stored trip to relink, and `tanksAfterTripChange`'s suggestion would race the chosen slot |
| `NewDiveAfterCreate.run(context, {created, changedCardIds})` | `run({required Dive created})`, its steps injected; the mirror question captures the page's context in `.read` |
| The weather is skipped when the sitting changed Environment | Skipped when the created dive holds any weather a fetch writes (`NewDiveAfterCreate.hasWeather`): a site's entry method is written on the Environment card and is no weather of the diver's |
| `newDivePage(state, {unlockEditing = kUnlockEditing})` returns the page | `newDivePage(state, {bool? unlockEditing})` forwards to `newDiveRoutePage` in `dive_create_builder.dart`, so `lib/core` does not import the switch |
| The operation gate untouched | `recordOperationBlockOf` answers `unsaved` for a creating controller, so every card that asks its controller agrees |
| `isCreating`: until the dive is created | For the page's whole life: once created it only moves on |
| `DiveDetailPage.newDive(unlockEditing: kUnlockEditing)` | Defaults to `true`; the routes pick the old form while the switch is off |

### Fixed from the review

- **Between the create and moving on, the page takes no input.** It showed the created dive with a live lock, whose Save tried to create the dive a second time; Save and Cancel now do nothing once it is created.
- **A sitting ended in place opens a fresh new dive.** The pane's + asked again (the same `?mode=new` address) or Back in the pane left the pane empty.
- **A scan's `importSource` ('ocr') is stored again**, on the seed: where the dive came from is not an entry.
- **The scanned page copied for a sitting is removed** when it ends without a create (Cancel, leaving, a fresh sitting).
- **A scanned page that cannot be copied is said**, with a new string `ocrImport_newDive_photoHoldFailed`, "The scanned page could not be attached to this dive" (all 11 locales); the form's own message says the dive was saved, which it is not yet.
- `create` checks that its id is free with one `SELECT 1`.

### Left open

- The held logbook photo takes its time from the entry when the page opens: a date changed afterwards is not followed (the form used the date at Save).
- `create` reads the dive back in full after the held writes: `createDive` returns its input, which can differ from what it stored.
- The end-to-end test drives no site picker and no master-detail scaffold; the blocker the pane asks through is pinned by "another route with a note asks".
- PR pictures are owed by the macOS window route when Eric says to open the PR ("before" from a main build).

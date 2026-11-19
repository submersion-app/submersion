# Unified editing, phase 3, plan 3: buddies, dive centres and certifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A certification, a buddy and a dive centre each open locked and edit in place, every card of each held in one sitting written as one History entry, behind `kUnlockRecordEditing` (issue #4527, phase 3). That includes what each page writes at once today: a certification's currency, a buddy's certifications, favourite and lent gear, a centre's rental notes. Buddy merge moves to a page of its own. The three edit forms stay until the switch-over plan; new records are plan 11's.

**Architecture:** As plan 2: each page's state mixes in `RecordEditHost` and `RecordOpenUnlocked`, its cards are `EditCard`s keyed by the card ids plan 1 shipped (`CertificationCardId`, `BuddyCardId`, `DiveCenterCardId`), and each type gets a save service on `writeRecordSitting`. Rows that belong to the record without being columns of it (buddy certifications, currency events, rental notes) are `SittingList`s; writes to other records (currency preferences across a rule group, lent and returned gear) are held writes in the same transaction, filed under the record by its History label. The certification's card editors are built once and used twice: on its page, and in the buddy's Certifications dialog, which replaces the form's staging mode. The lend and return flows are split into a plan step (the questions, asked when the diver acts) and a write step (run at Save). Buddy merge gets its own page holding only what merge uses, as phase 2's plan 7 does for sites.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift, go_router, `flutter gen-l10n`.

**Spec:** [docs/design/specs/2026-11-18-unified-editing-phase-3-records-design.md](../specs/2026-11-18-unified-editing-phase-3-records-design.md), sections "Design: buddies", "Design: dive centres", "Design: certifications", "Design: rules every phase 3 type follows", "Values shown nowhere today" (a centre's fill hours) and "Testing"; on top of plans 1 and 2 ([records-1](2026-11-19-unified-editing-records-1-shared.md), [records-2](2026-11-19-unified-editing-records-2-documents-species.md)).

## Questions for Eric

The plan is written to the recommended answer of each; a different answer changes only the task named.

1. **One pull request or three.** This plan is about one and a half times plan 2. **Recommended:** one PR, as plans 1 and 2, built and reviewed as one. The other way: three PRs in order (certifications; buddies with merge; dive centres), each merged before the next starts, at the cost of three review and CI rounds. (Task 15.)
2. **The buddy favourite outside the buddy page.** The spec makes the list row's star show state only. The buddy picker (a dive's buddies) has the same one-tap star. **Recommended:** with the switch on, both show state only; the favourite is set on the buddy's header block. The other way: the picker's star keeps writing at once. (Task 7.)
3. **Removing a rental note or a lent item's return in a sitting.** Today removing a rental note asks first because it is final. **Recommended:** inside a sitting a removal asks nothing, as every other held removal (Cancel brings it back). The other way: keep the confirmation. (Tasks 10, 13.)

## Calls made in this plan, for Eric to check

1. **The rental note sheet opened from a dive's Details card** (`RentalMemoryCard`, phase 1) keeps writing at once: it adds a note to the centre, another record, as a record created from a picker does. Only the centre page holds its notes.
2. **Lend gear asks its questions when the diver lends** (parts too? change status?), and the answers are written at Save; the place "with <buddy>" is created at Save, inside the sitting, so a Cancel leaves no place behind. A part moved underneath meanwhile follows the answer as stored at Save.
3. **Currency status rows stay as stored while unlocked.** The Currency editor lists events and preferences as the sitting holds them (held ones with the changed dot); the status above is recalculated after Save.
4. **The certification staging mode stays in `CertificationEditPage`** until the switch-over, since the buddy form still uses it; the buddy page uses the new dialog.
5. **Buddy merge's code leaves `BuddyEditPage` now** (its `mergeBuddies` parameter goes), since nothing else uses it; site merge keeps its form code until its form is deleted only because that form goes in the same plan.
6. **`/buddies/merge` with fewer than two ids goes back to `/buddies`**, as phase 2's plan 7 makes `/sites/merge` do.

## Global Constraints

- Phase 2's plan 7 (the site switch-over, branch `ericgriffin/unified-editing-sites-7-switch-over`, no PR yet) is built in parallel. It deletes `kUnlockSiteEditing` and `site_edit_page.dart`, moves site merge into `SiteMergePage`, and changes the site routes in `app_router.dart`. **The one file both plans touch is `lib/core/router/app_router.dart`**: this plan changes only the buddy, dive centre and certification routes there. This plan changes nothing under `lib/shared/` and no site file. Merge origin/main before each task with a merge (never a rebase or a force-push), adapt to any renamed names, and run a whole-repo `flutter analyze` after each merge.
- Built on the names already shipped: everything plan 2 lists, plus `DocumentsSection<T>(owner:, editing:)` and `holdDocumentLinks(session, read, owner:, cardId:)` (`documents/presentation/editing/record_document_links_sitting.dart`), `SittingList<T, E>` (`load`, `loadNone`, `current`, `set`, `wroteChange`), `EditSession.holdChange`, `holdWrite`, `track`, `remember`, `recall`, `applyTo`, `RecordSittingRefusal(message)`, `pickSiteLocationOnMap`, `CoordinateFieldGroup`, `InstructorPickerField`, `pickProfilePhoto`.
- With `kUnlockRecordEditing` false (the default) all three pages, their list panes, table modes, routes and the buddy list rows look and behave exactly as today: no existing test changes its expectations. Each page takes `unlockEditing` defaulting to the switch.
- A locked page writes nothing on any tap. History labels: `record_edit:certifications:<id>:<cards>`, `record_edit:buddies:<id>:<cards>`, `record_edit:dive_centers:<id>:<cards>`, source "manual". Writes to other tables in a sitting (card images under `documents`, currency rows, equipment moves and status) are in that one entry.
- Only what changed is written: each sitting's changes are applied to the record as stored at Save (`EditSession.applyTo`), and each type has a field census test. `Buddy`, `DiveCenter` and `Certification` `copyWith` cannot clear most fields, so each type's fields build the entity through one private `_with` that copies every field, as plan 2 did for species.
- Rules move from the forms unchanged (listed per task). Units follow the active diver's settings.
- No new strings are expected: every label comes from the forms or the read pages. A task that finds one missing names it, and it goes into all eleven ARB files, translated, then `flutter gen-l10n`.
- Files over 800 lines (`certification_detail_page.dart` 1,049, `dive_center_detail_page.dart` 941, `app_router.dart`) do not grow: editing goes in `part` files and `*_edit_routes.dart`; the router gains only references to them.
- Never use em-dashes, and never en-dashes, double hyphens or spaced hyphens as prose punctuation, in code, comments, commits or the PR. Commits, the PR and files follow the repository guide's Attribution section.
- Imports grouped dart, flutter, packages, local. `dart format` changed files before each commit. Anything acting after an `await` checks `mounted` and reads `ref` and `context` before its first `await`.
- Test runs: only the test FILES a task writes or changes, by path. Never a folder, never the whole suite, never `test/architecture/` or `test/shared/` by hand: the pre-push hook runs them.
- Never `--build-filter` build_runner. Never let a debug build open `~/Documents/Submersion/submersion.db`.

## Review Focus

1. **Gear lent in a sitting, then Cancel.** The item stays where it was with its status, and no "with <buddy>" place is created. Pinned in Task 9.
2. **A profile linked to the buddy that another device has meanwhile linked to a different buddy.** Save is refused whole with today's message naming that buddy, nothing is written (not the name, not the certifications), and the page stays unlocked. Pinned in Tasks 6 and 7.
3. **A currency preference changed on a collapsed rule group, then Cancel.** No member's preference is written; with Save, every member's is, in the one entry. Pinned in Task 4.
4. **An address typed on a centre with no coordinates, then Save at once.** Save waits for the lookup and stores what it found; a lookup that fails or finds nothing saves without coordinates and says nothing. Pinned in Task 12.
5. **A buddy's certification edited in the dialog, Done, then the buddy's Cancel.** Nothing is written; the dialog's own Cancel changes nothing in the sitting. Pinned in Task 8.

## Preparation

- [ ] The worktree is initialised (`git submodule update --init --recursive`, `flutter pub get`); generate code unfiltered in the background if fresh: `dart run build_runner build --delete-conflicting-outputs`.
- [ ] `git fetch origin main`, merge it, and run `flutter analyze` on the whole repository. Expected: clean.
- [ ] Before any code changes, take the "before" goldens (headless widget tests, switch off): the three pages locked at phone and desktop width, the buddy merge page.
- [ ] Commit this plan: `git add docs/design/plans/2026-11-19-unified-editing-records-3-buddies-centres-certifications.md && git commit -m "docs(editing): phase 3 plan 3, buddies, dive centres and certifications"`.

## File Structure

New, certifications (`lib/features/certifications/...`):

| File | Responsibility |
| --- | --- |
| `data/services/certification_edit_save_service.dart` | `CertificationEditSaveService`, provider |
| `presentation/editing/certification_edit_fields.dart` | Fields and rules (credentials, title, number, dates, instructor, photos, notes) |
| `presentation/editing/certification_card_editors.dart` | Details, Dates, Instructor, Card photos editors, over any `EditSession<Certification>` |
| `presentation/editing/certification_edit_cards.dart` | `certificationEditCards` |
| `presentation/editing/certification_currency_sitting.dart` | Held currency events and preferences |
| `presentation/pages/certification_detail_page_editing.dart` | `part`: the page's use of the host |
| `presentation/pages/certification_edit_routes.dart` | Redirect, pane |

New, buddies (`lib/features/buddies/...`):

| File | Responsibility |
| --- | --- |
| `presentation/pages/buddy_merge_page_fields.dart`, `buddy_merge_page_save.dart` | `part`s: merge's fields and its save, moved out of the form |
| `data/services/buddy_edit_save_service.dart` | `BuddyEditSaveService`, provider |
| `presentation/editing/buddy_edit_fields.dart` | Fields and rules |
| `presentation/editing/buddy_edit_cards.dart`, `buddy_header_card_editor.dart`, `buddy_contact_card_editor.dart` | Cards and editors |
| `presentation/editing/buddy_certifications_sitting.dart`, `buddy_certification_dialog.dart` | The held certifications and their dialog |
| `presentation/editing/buddy_gear_sitting.dart` | Held lends and returns |
| `presentation/pages/buddy_detail_page_editing.dart` | `part` |
| `presentation/pages/buddy_edit_routes.dart` | Redirects, pane |

New, dive centres (`lib/features/dive_centers/...`):

| File | Responsibility |
| --- | --- |
| `data/services/dive_center_edit_save_service.dart` | `DiveCenterEditSaveService`, provider |
| `presentation/editing/dive_center_edit_fields.dart` | Fields and rules |
| `presentation/editing/dive_center_edit_cards.dart`, `dive_center_header_card_editor.dart`, `dive_center_contact_card_editor.dart`, `dive_center_map_card_editor.dart` | Cards and editors |
| `presentation/editing/dive_center_rental_sitting.dart` | Held rental notes |
| `presentation/pages/dive_center_detail_page_editing.dart` | `part` |
| `presentation/pages/dive_center_edit_routes.dart` | Redirect, pane |

Modified: the three detail pages, their list pages (`editBuilder` in `MasterDetailScaffold` and `TableModeLayout`), `buddy_edit_page.dart` (merge removed), `buddy_merge_page.dart`, `buddy_gear_section.dart`, `buddy_list_tile.dart`, `buddy_picker.dart`, `certification_currency_section.dart`, `rental_gear_section.dart`, `rental_gear_note_sheet.dart`, `equipment_move_flow.dart`, `equipment_return_flow.dart`, `lend_gear_flow.dart`, `return_equipment_sheet.dart`, `app_router.dart`, `test/architecture/markdown_notes_adoption_test.dart` (new Markdown editors; not run by hand).

---

### Task 1: Buddy merge gets a page of its own

**Files:**
- Modify: `lib/features/buddies/presentation/pages/buddy_merge_page.dart`, `buddy_edit_page.dart` (merge removed), `lib/core/router/app_router.dart` (the `mergeBuddy` route only)
- Create: `buddy_merge_page_fields.dart`, `buddy_merge_page_save.dart` (same folder, `part of`), `buddy_edit_routes.dart` (`buddyMergeRedirect` only for now)
- Test: `test/features/buddies/presentation/pages/buddy_merge_page_test.dart` (create), `buddy_merge_country_test.dart` and `buddy_list_page_test.dart` (existing, unchanged expectations)

**Interfaces:**
- Produces: `BuddyMergePage({required List<String> buddyIds})`, its state holding only what merge uses: the six text controllers, photo, `BuddyMergeFormController` and its cycle buttons, the confirmation (`_confirmMerge`), `buddyListNotifier.mergeBuddies`, the pop of `BuddyMergeResult`, the refusal for different linked profiles (`buddies_merge_refusedDifferentLinks`). The not-enough scaffold stays for ids that fail to load.
- Produces: `String? buddyMergeRedirect(BuildContext context, GoRouterState state)`: `/buddies` when `state.extra` is not a list of at least two ids, else null; the `mergeBuddy` route gets it.
- `BuddyEditPage` loses `mergeBuddies`, `isMerging` and every merge branch.

- [ ] **Step 1: Write the failing tests** in `buddy_merge_page_test.dart`: `the merge page cycles each text field` (name, email, phone, social, country, notes, each cycles through the distinct values); `merging confirms, merges and pops the result`; `different linked profiles are refused`; `fewer than two ids goes back to the list` (`buddyMergeRedirect` with `['b1']`, `[]`, `null` answers `/buddies`, with two ids null); `the merge page builds no linked profile or certifications section`.
- [ ] **Step 2:** Run `flutter test test/features/buddies/presentation/pages/buddy_merge_page_test.dart`. Expected: `buddyMergeRedirect` undefined.
- [ ] **Step 3:** Move the merge code out of `buddy_edit_page.dart` into the page and its parts; remove it from the form.
- [ ] **Step 4:** Run it, `buddy_merge_country_test.dart`, `buddy_list_page_test.dart` and the `buddy_edit_*_test.dart` files. Expected: all pass.
- [ ] **Step 5: Commit** `feat(buddies): merge gets a page of its own`.

### Task 2: The certification save service and fields

**Files:**
- Create: `lib/features/certifications/data/services/certification_edit_save_service.dart`, `presentation/editing/certification_edit_fields.dart`
- Test: `test/features/certifications/data/services/certification_edit_save_service_test.dart`, `test/features/certifications/presentation/editing/certification_edit_fields_test.dart`

**Interfaces:**
- Produces:
  - `class CertificationEditSaveService { CertificationEditSaveService(CertificationRepository certifications); Future<({Certification before, Certification after})?> save({required String certificationId, required Certification Function(Certification stored) apply, required Iterable<String> changedCardIds, Future<void> Function()? alsoWrite, bool alsoWriteIsAChange = false}) }`: `writeRecordSitting<Certification>(table: 'certifications', read: () => getCertificationById(id), write: (_, merged) => updateCertification(merged, notify: false))`. `updateCertification` already refreshes the course's representative and writes the card images (`saveCardImages`, a no-op for unchanged bytes); inside the sitting they are in its transaction. `certificationEditSaveServiceProvider`.
  - Fields, card `details`: `certificationCredentialsField` (`List<CertificationCredential>`, row 0 being `agency`/`level` and the rest `additionalCredentials`), `certificationTitleField` (`String?`), `certificationCardNumberField`; card `dates`: issue and expiry; card `instructor`: `certificationInstructorField` (`({String? id, String? name, String? number})`, one field so a pick is one change); card `cardPhotos`: front and back (`Uint8List?`); card `notes`. Blank text stores null.
  - Rules, pure: `List<CertificationCredential> setCredentialAgency(List<CertificationCredential> rows, int index, String agency)` (drops a level not the agency's), `List<CertificationCredential> removeCredential(rows, int index)` (row 0 removed promotes the next), `bool certificationHasTitleOrLevel(Certification c)`, `({String? id, String? name, String? number}) instructorPicked(Buddy? buddy, Certification? instructorCert, previous)` (fills name and number; clearing the pick keeps the text).
- Consumes: `writeRecordSitting`.

- [ ] **Step 1: Write the failing tests** (test database; certification `c1`, PADI Open Water, card number `123`, front image bytes, linked to course `k1`):
  - Service: `writes a card number change as one History entry` (label `record_edit:certifications:c1:details`); census `a field the sitting did not touch keeps its newer value`, one assertion per column `updateCertification` writes; `new card photos are written in the same entry` (one operation, the document page under `documentCertificationCardId('c1')` holds the new bytes); `the course's representative follows a renamed certification`; `unchanged returns null`; `a certification that has gone throws`.
  - Fields: `changing an agency drops a level not the agency's`; `removing the first credential promotes the next`; `a title or a level is required`; `picking an instructor fills the name and number`.
- [ ] **Step 2:** Run the two files. Expected: fail to compile.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(certifications): save a certification's editing sitting as one History entry`.

### Task 3: The certification page on the host

**Files:**
- Create: `certification_card_editors.dart`, `certification_edit_cards.dart`, `lib/features/certifications/presentation/pages/certification_detail_page_editing.dart` (part)
- Modify: `certification_detail_page.dart`, `test/architecture/markdown_notes_adoption_test.dart`
- Test: `test/features/certifications/presentation/pages/certification_detail_page_unlock_harness.dart`, `certification_detail_page_unlock_test.dart`, `test/features/certifications/presentation/editing/certification_card_editors_test.dart`

**Interfaces:**
- Produces:
  - `CertificationDetailsCardEditor`, `CertificationDatesCardEditor`, `CertificationInstructorCardEditor`, `CertificationCardPhotosEditor({..., Future<Uint8List?> Function()? pickPhoto})`, each `({required EditSession<Certification> session})`: the form's widgets (`CertificationAgencyDropdown`, the level dropdown with `showCertificationLevelDialog`, "Add recognition", the date pickers, `InstructorPickerField`, the photo cards, `MarkdownNotesField`) bound to Task 2's fields.
  - `certificationEditCards`: `details` (`isValid: certificationHasTitleOrLevel`), `dates`, `instructor` (`isEmpty`: no id, name or number), `cardPhotos` (`isEmpty`: no photos), `documents` (`DocumentsSection<Certification>(excludeCards: true, editing:)`, its links held by `holdDocumentLinks`), `notes` (`isEmpty`: blank), `currency` (Task 4).
  - `CertificationDetailPage({..., bool unlockEditing = kUnlockRecordEditing, bool openUnlocked = false, VoidCallback? onSittingEnded})` on `RecordEditHost<CertificationDetailPage, Certification>` and `RecordOpenUnlocked`; `followStored(certificationByIdProvider(id))`; `editingTitle` from the header title. The status banner fades as calculated; Training course reads only. Instructor, Card photos and Notes are offered in the strip when empty.
- Consumes: Task 2.

- [ ] **Step 1: Write the failing tests**: editors: `each editor sets only its card's fields`; page: `with the switch off there is no lock`; `locked, no tap writes`; `editing the card number and saving writes one sitting and locks`; `a certification with neither title nor level cannot be saved`; `a new front photo is a change of Card photos`; `empty Instructor, Card photos and Notes are offered in the strip`; `the documents card holds a detach until Save`; `Cancel with changes asks first`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement; add the notes editor to the Markdown guard's list.
- [ ] **Step 4:** Run them, and `certification_detail_page_test.dart` unchanged. Expected: all pass.
- [ ] **Step 5: Commit** `feat(certifications): unlock a certification page to edit it in place, behind a switch`.

### Task 4: Currency held in the sitting

**Files:**
- Create: `lib/features/certifications/presentation/editing/certification_currency_sitting.dart`
- Modify: `certification_currency_section.dart`, `certification_edit_cards.dart`, `certification_detail_page_editing.dart`
- Test: `test/features/certifications/presentation/editing/certification_currency_sitting_test.dart`, `certification_currency_section_test.dart` (existing; add cases), `certification_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `final certificationEventsList = SittingList<Certification, CurrencyEvent>(key: 'certification.currencyEvents', cardId: 'currency', read: <events for the certification>, write: <createEvent for new ids, deleteEvent for removed ones>)`.
  - `void holdCurrencyPrefs(EditSession<Certification> session, CurrencyGroup group, CurrencyPref Function(CurrencyPref current) change, ProviderRead read)`: the section's `_writePrefs` logic moved into a pure `List<CurrencyPref> currencyPrefsFor(CurrencyGroup group, Map<String, CurrencyPref> stored, CurrencyPref Function(CurrencyPref) change)` (each member's own pref, else the inherited superseded-rule pref, else a new one), held per pref id on card `currency`, written at Save with `upsertPref` each. `currencyPrefsInSitting(session, stored)` for the editor.
  - `CertificationCurrencySection({required Certification certification, EditSession<Certification>? editing})`: with a session its row actions log (`showCurrencyEventDialog`, then held), set interval, mapping and mute (held), and delete an event (held, no confirmation, Question 3); without one, as today. Locked with the switch on, its actions are hidden.
  - The Currency card is built only when `certificationCurrencyGroupsProvider` has groups or there are events; offered in the strip only when a group applies and the card is not shown.
- Consumes: Task 3's `saveSitting`, whose `alsoWrite` runs the held writes.

- [ ] **Step 1: Write the failing tests**: sitting: `a logged event is written at Save`; `a deleted event is deleted at Save`; `a preference on a collapsed group writes every member's` (Review Focus 3, with Save) and `Cancel writes no preference` (Review Focus 3); `prefs fall back to the inherited pref as today` (moved from the section's tests). Section: `locked with the switch on, no action is offered`; `in a sitting, logging writes nothing until Save`. Page: `currency changes and a card number change are one History entry`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass, including the existing section cases.
- [ ] **Step 5: Commit** `feat(certifications): currency logged on a certification page waits for Save`.

### Task 5: Certification hosts, routes and Delete

**Files:**
- Create: `lib/features/certifications/presentation/pages/certification_edit_routes.dart`
- Modify: `certification_detail_page.dart`, `certification_detail_page_editing.dart`, `certification_list_page.dart`, `app_router.dart`
- Test: `certification_detail_page_unlock_test.dart`, `test/features/certifications/presentation/pages/certification_list_page_test.dart` (existing; add cases), `test/core/router/app_router_test.dart`

**Interfaces:**
- Produces: `certificationEditLocation(id, {unlockEditing})`, `certificationEditRedirect`, `Widget certificationEditPane(BuildContext, String id, void Function(String) onSaved, VoidCallback onCancel, {VoidCallback? onDeleted, bool unlockEditing = kUnlockRecordEditing})` (the page unlocked with the switch, else the form), used by both `editBuilder`s (master-detail and table mode); `createBuilder` stays the form. The detail route passes `openUnlocked` from `?mode=edit`; the certification routes get `onExit: confirmLeaveRecordSitting`; the desktop redirect keeps `&mode=edit`. Delete runs through `recordOperationRunnerOf`; History works locked; the wallet reads only.
- Consumes: Tasks 3 and 4.

- [ ] **Step 1: Write the failing tests**: `opened with mode=edit, the page is unlocked`; `the pane's and table mode's edit open the page unlocked, Cancel returns to view`; `the edit address redirects with the switch on, not off`; `locked, Delete is disabled under "Unlock to use these"`; `unlocked and clean, Delete asks and deletes`; `with the switch off the pane opens the form`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(certifications): edit addresses and panes open the page unlocked; delete as a whole-record operation`.

### Task 6: The buddy save service and fields

**Files:**
- Create: `lib/features/buddies/data/services/buddy_edit_save_service.dart`, `presentation/editing/buddy_edit_fields.dart`
- Test: `test/features/buddies/data/services/buddy_edit_save_service_test.dart`, `test/features/buddies/presentation/editing/buddy_edit_fields_test.dart`

**Interfaces:**
- Produces:
  - `class BuddyEditSaveService { BuddyEditSaveService(BuddyRepository buddies, BuddyProfileLinkRepository links); Future<({Buddy before, Buddy after})?> save({required String buddyId, required Buddy Function(Buddy stored) apply, required Iterable<String> changedCardIds, Future<void> Function()? alsoWrite, bool alsoWriteIsAChange = false}) }`: `writeRecordSitting<Buddy>(table: 'buddies', read: getBuddyById, write: (stored, merged) async { <when merged.linkedDiverId is set and differs from stored's: links.assertLinkAllowed(ownerDiverId: merged.diverId, linkedDiverId:, buddyId:), a BuddyLinkRefused rethrown as RecordSittingRefusal with today's message (buddies_linkedProfile_refusedSelf, or buddies_linkedProfile_refusedTaken(name))>; await buddies.updateBuddy(merged); })`. `updateBuddy` re-derives the country code against the stored row, as the form relies on. `buddyEditSaveServiceProvider`.
  - Fields: card `header`: photo (`Uint8List?`, with `photoPath` cleared as `clearPhoto` does), name, favourite; card `contact`: email, phone, social handle, country (`BuddyCountryColumns.text`), linked profile (`String?`, cleared through `clearLinkedDiver`); card `statistics`: excluded from rankings; card `notes`. Card details are not fields (imported).
  - `bool buddyEmailValid(String? email)` (the form's regex), `bool buddyNameValid(String name)`.
- Consumes: `writeRecordSitting`.

- [ ] **Step 1: Write the failing tests** (test database; buddy `b1` Alex, with card details from a received card):
  - Service: `writes a phone change as one History entry`; census, one assertion per column `updateBuddy` writes, card detail columns included (`a received card's details survive a save`); `a linked profile taken by another buddy refuses the whole save` (Review Focus 2: link the profile to `b2` underneath, save a name and a link: `RecordSittingRefusal` naming `b2`'s name, `b1` unchanged, no operation); `linking the diver themselves is refused`; `the country code follows a changed country`.
  - Fields: `a bad email is invalid`; `clearing the photo clears its path`; `clearing the linked profile stores null`.
- [ ] **Step 2:** Run the two files. Expected: fail to compile.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(buddies): save a buddy's editing sitting as one History entry`.

### Task 7: The buddy page on the host

**Files:**
- Create: `buddy_edit_cards.dart`, `buddy_header_card_editor.dart`, `buddy_contact_card_editor.dart`, `lib/features/buddies/presentation/pages/buddy_detail_page_editing.dart` (part)
- Modify: `buddy_detail_page.dart`, `buddy_list_tile.dart`, `buddy_picker.dart`, `buddy_favorite_button.dart`, `test/architecture/markdown_notes_adoption_test.dart`
- Test: `test/features/buddies/presentation/pages/buddy_detail_page_unlock_harness.dart`, `buddy_detail_page_unlock_test.dart`, `test/features/buddies/presentation/editing/buddy_contact_card_editor_test.dart`, `test/features/buddies/presentation/widgets/buddy_favorite_button_test.dart` (existing; add a case)

**Interfaces:**
- Produces:
  - `BuddyHeaderCardEditor`: photo (`pickProfilePhoto(allowContacts: isContactImportSupported, contactPhotoLoader: loadContactPhoto)`), name (required), favourite switch.
  - `BuddyContactCardEditor`: email (format error while invalid), phone, social, `BuddyCountryField`, `LinkedProfileField` and the `linkedProfileSuggestionProvider` suggestion banner, as the form. Picking a profile runs `assertLinkAllowed` at once and shows today's refusal under the field without setting it; the check runs again at Save (Task 6).
  - `buddyEditCards`: `header` (`isValid`: name), `contact` (`isValid`: email; `isEmpty`: no contact info, social, country or link), `statistics` (editor: the "exclude from rankings" switch above the read-only statistics), `notes`, `documents` (`DocumentsSection<Buddy>`), `certifications` (Task 8), `gear` (Task 9). Shared dives and Photos fade as calculated; Card details is labelled imported (`RecordCardFade` with the imported label phase 1 uses).
  - `BuddyDetailPage({..., bool unlockEditing = kUnlockRecordEditing, bool openUnlocked = false, VoidCallback? onSittingEnded})` on the host. `BuddyFavoriteButton({..., bool readOnly = false})`: read only it shows the state and writes nothing. With the switch on: the page's bar favourite, the list row's and the picker's are read only (Question 2), and the menu's Lend item goes (lending is on the Gear card). Share dives works locked.
- Consumes: Task 6.

- [ ] **Step 1: Write the failing tests**: editor: `a profile taken by another buddy is refused when picked`; `a bad email is flagged`. Page: `with the switch off there is no lock and the star toggles`; `locked, no tap writes` (the bar star included); `favourite and phone in one sitting save as one entry`; `a refused link at Save leaves the page unlocked with the message` (Review Focus 2); `excluded from rankings is set on Statistics`; `empty Contact and Notes are offered in the strip`; `the menu offers no Lend with the switch on`; `Cancel with changes asks first`. Button: `read only, a tap writes nothing`.
- [ ] **Step 2:** Run the four files. Expected: failures.
- [ ] **Step 3:** Implement; add the notes editor to the Markdown guard's list.
- [ ] **Step 4:** Run them, and `buddy_detail_page_test.dart`, `buddy_detail_country_test.dart`, `buddy_rankings_form_detail_test.dart` unchanged. Expected: all pass.
- [ ] **Step 5: Commit** `feat(buddies): unlock a buddy page to edit it in place, behind a switch`.

### Task 8: The buddy's certifications

**Files:**
- Create: `buddy_certifications_sitting.dart`, `buddy_certification_dialog.dart`
- Modify: `buddy_edit_cards.dart`, `buddy_detail_page.dart` (the Certifications card shows the sitting's list)
- Test: `test/features/buddies/presentation/editing/buddy_certification_dialog_test.dart`, `buddy_certifications_sitting_test.dart`, `buddy_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `final buddyCertificationsList = SittingList<Buddy, Certification>(key: 'buddy.certifications', cardId: 'certifications', read: (b) => certifications.getCertificationsByBuddy(b.id), write: (b, _, current) => certifications.replaceBuddyCertifications(b.id, current))`.
  - `Future<Certification?> showBuddyCertificationDialog(BuildContext context, {required Certification initial})`: a dialog holding its own `EditSession<Certification>` over `initial` with Task 3's Details, Dates, Instructor, Card photos and Notes editors; Done checks `certificationHasTitleOrLevel` and returns `session.applyTo(initial)`, Cancel returns null. A new one starts from `Certification.empty().copyWith(buddyId:)` with a fresh id, as staging does.
  - The Certifications card's editor: add, edit (the dialog), remove; each a change of `certifications`, held rows with the changed dot.
- Consumes: Task 3's editors, Task 7's `saveSitting` (`alsoWrite`).

- [ ] **Step 1: Write the failing tests**: dialog: `Done returns the edited certification`; `Cancel returns null`; `neither title nor level keeps it open`. Sitting: `an added certification is written with the buddy`; `a removed one is deleted`. Page: `edited in the dialog, Done, then the buddy's Cancel writes nothing` (Review Focus 5); `a certification change and a name change are one entry`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and `buddy_detail_cert_subtitle_test.dart` unchanged. Expected: all pass.
- [ ] **Step 5: Commit** `feat(buddies): a buddy's certifications are edited on its page`.

### Task 9: Lent and returned gear held

**Files:**
- Create: `lib/features/buddies/presentation/editing/buddy_gear_sitting.dart`
- Modify: `lib/features/equipment/data/services/equipment_move_flow.dart`, `equipment_return_flow.dart`, `lib/features/equipment/presentation/widgets/lend_gear_flow.dart`, `move_equipment_sheet.dart`, `return_equipment_sheet.dart`, `lib/features/buddies/presentation/widgets/buddy_gear_section.dart`, `buddy_edit_cards.dart`
- Test: `test/features/equipment/data/services/equipment_move_flow_test.dart`, `equipment_return_flow_test.dart` (existing; add cases), `test/features/buddies/presentation/editing/buddy_gear_sitting_test.dart`, `buddy_gear_section_test.dart` (existing; add cases), `buddy_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `class EquipmentMovePlan { final List<String> itemIds; final DateTime movedAt; final String note; final bool withParts; final EquipmentStatus? status; }`. `EquipmentMoveFlow.plan({required List<EquipmentItem> items, required EquipmentLocationKind? targetKind, ...}) -> Future<EquipmentMovePlan>`: asks the parts and status questions (as `run` does) and writes nothing. `EquipmentMoveFlow.write(EquipmentMovePlan plan, {required EquipmentLocation? target}) -> Future<int>`: finds the parts again when `withParts`, records the moves, and sets the status on the eligible ids when `status` is set. `run` is `plan` then `write`; its tests stay as they are.
  - `EquipmentReturnPlan` and `EquipmentReturnFlow.plan` / `write` the same way (`write` recomputes each item's place before the loan and the groups).
  - `setStatus` in held writes is `EquipmentRepository.setStatusForMany` (the repository's, inside the transaction), not the notifier's.
  - `Future<HeldLend?> planLendGear(BuildContext, WidgetRef, Buddy buddy)` (`lend_gear_flow.dart`): the picker, the move sheet on the buddy, the questions; returns `HeldLend(items, plan)`. `Future<HeldReturn?> planEquipmentReturn(BuildContext, WidgetRef, {items, buddyId})`. `showLendGearFlow` and `showEquipmentReturnFlow` are plan then write, as today.
  - In `buddy_gear_sitting.dart`: `holdBuddyLend`, `holdBuddyReturn`, `releaseBuddyGearMove(session, index)` (held moves in order, one change of `gear`); the held write runs them in order: a lend resolves the buddy's place with `findOrCreateForBuddy` then `write`. `List<BuddyGearRow> buddyGearInSitting(session, stored)`: stored rows less returned items plus lent ones, held rows marked.
  - `BuddyGearSection({..., EditSession<Buddy>? editing})`: with a session Lend, All returned and Returned are held; locked with the switch on, they are hidden. The Gear card is offered in the strip when nothing is lent.
- Consumes: Task 7.

- [ ] **Step 1: Write the failing tests**: flows: `plan asks and writes nothing`; `write records the moves and the status the plan chose`; `run still moves and asks as before`. Sitting: `a held lend is written at Save, place created then`; `a held return goes back to the place before the loan`; `a lend then its release is no change`. Page: `gear lent in a sitting, then Cancel` (Review Focus 1: the item's place and status unchanged, no buddy place created); `lend and a phone change are one entry`; `locked, the Gear card offers no action`.
- [ ] **Step 2:** Run the five files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and `test/features/equipment/presentation/widgets/move_equipment_sheet_test.dart` and `return_equipment_sheet_test.dart` unchanged. Expected: all pass.
- [ ] **Step 5: Commit** `feat(buddies): gear lent and returned on a buddy page waits for Save`.

### Task 10: Buddy hosts, routes and Delete

**Files:**
- Modify: `buddy_edit_routes.dart`, `buddy_detail_page.dart`, `buddy_detail_page_editing.dart`, `buddy_list_page.dart`, `app_router.dart`
- Test: `buddy_detail_page_unlock_test.dart`, `buddy_list_page_test.dart` (existing; add cases), `test/core/router/app_router_test.dart`

**Interfaces:**
- Produces: `buddyEditLocation`, `buddyEditRedirect`, `buddyEditPane(...)` as Task 5's, for both `editBuilder`s; `createBuilder` and `/buddies/new` stay the form. The detail route reads `?mode=edit`; buddy routes get `onExit: confirmLeaveRecordSitting`. Delete through `recordOperationRunnerOf`; Share dives, History and Open in Connections work locked.
- Consumes: Tasks 7 to 9.

- [ ] **Step 1: Write the failing tests**: as Task 5's six, for buddies; plus `Share dives works locked`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(buddies): edit addresses and panes open the page unlocked; delete as a whole-record operation`.

### Task 11: The dive centre save service and fields

**Files:**
- Create: `lib/features/dive_centers/data/services/dive_center_edit_save_service.dart`, `presentation/editing/dive_center_edit_fields.dart`
- Test: `test/features/dive_centers/data/services/dive_center_edit_save_service_test.dart`, `test/features/dive_centers/presentation/editing/dive_center_edit_fields_test.dart`

**Interfaces:**
- Produces:
  - `DiveCenterEditSaveService(DiveCenterRepository centers)` with `save(...)` as Task 2's shape over `writeRecordSitting<DiveCenter>(table: 'dive_centers', read: getDiveCenterById, write: (_, merged) => updateDiveCenter(merged))`. `updateDiveCenter` writes neither `createdAt` nor `diverId`, so the form's `createdAt: now` slip does not arise. `diveCenterEditSaveServiceProvider`.
  - Fields: card `header`: logo, name, rating (`double?`), street, city, state, postal code, country, affiliations (`List<String>`, `equals` as sets), permanently closed; card `map`: coordinates (`({double latitude, double longitude})?`, one field); card `contact`: phone, email, website, fill hours (`({int? opensAt, int? closesAt})`); card `notes`.
  - Rules: `String? diveCenterCoordinateError(double? lat, double? lon)` (the form's ranges); fill hours checked with the shipped `fillHoursProblem`; email with the form's regex.
- Consumes: `writeRecordSitting`.

- [ ] **Step 1: Write the failing tests**: service: `writes a website change as one History entry`; census, one assertion per column `updateDiveCenter` writes; `clearing the rating stores null`; `clearing the coordinates stores nulls`. Fields: `latitude 91 is out of range`; `fill hours with only an opening are a problem`; `closing before opening is a problem`.
- [ ] **Step 2:** Run the two files. Expected: fail to compile.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(dive-centers): save a dive centre's editing sitting as one History entry`.

### Task 12: The dive centre page on the host

**Files:**
- Create: `dive_center_edit_cards.dart`, `dive_center_header_card_editor.dart`, `dive_center_contact_card_editor.dart`, `dive_center_map_card_editor.dart`, `lib/features/dive_centers/presentation/pages/dive_center_detail_page_editing.dart` (part)
- Modify: `dive_center_detail_page.dart`, `test/architecture/markdown_notes_adoption_test.dart`
- Test: `test/features/dive_centers/presentation/pages/dive_center_detail_page_unlock_harness.dart`, `dive_center_detail_page_unlock_test.dart`, `test/features/dive_centers/presentation/editing/dive_center_map_card_editor_test.dart`

**Interfaces:**
- Produces:
  - `DiveCenterHeaderCardEditor`: `DiveCenterLogoField` (`pickProfilePhoto(allowContacts: false)`), name, the rating selector, the address fields, the affiliation chips, the closed switch. When every address field has lost focus, the centre has no coordinates in the sitting and the address is not blank, it looks them up (`LocationService.instance.forwardGeocode` through `locationServiceProvider`) as `session.track(...)`, so Save waits (Review Focus 4), and sets the coordinates as a change of `map`; a failed or empty lookup sets nothing and says nothing.
  - `DiveCenterMapCardEditor({required EditSession<DiveCenter> session, Future<PickedLocation?> Function(BuildContext, LatLng?) pickLocation = pickSiteLocationOnMap})`: `CoordinateFieldGroup` with `diveCenterCoordinateError`, Use my location (`getCurrentLocation(includeGeocoding: true, languageCode:)`), Pick from map, Look up from the address.
  - `DiveCenterContactCardEditor`: phone, email, website, `DiveCenterFillHoursSection` (its problem shown at once, not only after a blocked save).
  - `diveCenterEditCards`: `header` (`isValid`: name), `map` (`isEmpty`: no coordinates, `isValid`: in range), `contact` (`isValid`: email and fill hours; `isEmpty`: none of the five), `notes`, `documents` (`DocumentsSection<DiveCenter>`), `rentalGear` (Task 13). The Contact card gains a Fill hours row when set (the form's fill hours label and time format). Dives fades as calculated; `GearHereSection` reads only.
  - `DiveCenterDetailPage({..., bool unlockEditing = kUnlockRecordEditing, bool openUnlocked = false, VoidCallback? onSittingEnded})` on the host.
- Consumes: Task 11.

- [ ] **Step 1: Write the failing tests**: editor: `pick from map sets the coordinates`; `out of range coordinates are invalid`. Page: `with the switch off there is no lock`; `locked, no tap writes`; `website and closed in one sitting save as one entry`; `an address typed with no coordinates looks them up before Save` (Review Focus 4, a fake location service answering after a delay: the fake save sees the coordinates); `a failed lookup saves without coordinates`; `fill hours show on Contact when set`; `a centre with no coordinates offers Map in the strip`; `fill hours closing before opening stop Save`; `Cancel with changes asks first`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement; add the notes editor to the Markdown guard's list.
- [ ] **Step 4:** Run them, and `dive_center_detail_page_test.dart`, `dive_center_detail_page_closed_test.dart`, `dive_center_detail_page_logo_test.dart` unchanged. Expected: all pass.
- [ ] **Step 5: Commit** `feat(dive-centers): unlock a dive centre page to edit it in place, behind a switch`.

### Task 13: Rental notes held

**Files:**
- Create: `lib/features/dive_centers/presentation/editing/dive_center_rental_sitting.dart`
- Modify: `rental_gear_note_sheet.dart`, `rental_gear_section.dart`, `dive_center_edit_cards.dart`
- Test: `test/features/dive_centers/presentation/editing/dive_center_rental_sitting_test.dart`, `rental_gear_note_sheet_test.dart` and `rental_gear_section_test.dart` (existing; add cases), `dive_center_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `showRentalGearNoteSheet(..., {bool holdOnly = false})` returning `Future<DiveCenterGearNote?>`: with `holdOnly` its Save writes nothing and returns the note (a fresh uuid for a new one); without it, as today (the dive's `RentalMemoryCard` keeps it, call 1).
  - `final diveCenterRentalList = SittingList<DiveCenter, DiveCenterGearNote>(key: 'diveCenter.rentalNotes', cardId: 'rentalGear', read: getForCenter, write: <create new ids, update changed, delete removed>)`.
  - `RentalGearSection({required String centerId, EditSession<DiveCenter>? editing})`: with a session, add and edit are held, a remove is held with no confirmation (Question 3), held rows show the changed dot; locked with the switch on, add and tap are off.
- Consumes: Task 12.

- [ ] **Step 1: Write the failing tests**: sheet: `hold-only writes nothing and returns the note`. Sitting: `added, edited and removed notes are written at Save`; `a note added underneath survives a save` (the diff leaves it). Section: `locked with the switch on, no add is offered`. Page: `a rental note and a phone change are one entry`; `Cancel writes no note`.
- [ ] **Step 2:** Run the four files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass, including the existing cases.
- [ ] **Step 5: Commit** `feat(dive-centers): rental notes on a dive centre page wait for Save`.

### Task 14: Dive centre hosts, routes and Delete

**Files:**
- Create: `lib/features/dive_centers/presentation/pages/dive_center_edit_routes.dart`
- Modify: `dive_center_detail_page.dart`, `dive_center_detail_page_editing.dart`, `dive_center_list_page.dart`, `app_router.dart`
- Test: `dive_center_detail_page_unlock_test.dart`, `test/features/dive_centers/presentation/pages/dive_center_list_page_test.dart` (existing; add cases), `test/core/router/app_router_test.dart`

**Interfaces:**
- Produces: `diveCenterEditLocation`, `diveCenterEditRedirect`, `diveCenterEditPane(...)` as Task 5's; the detail route reads `?mode=edit`; routes get `onExit: confirmLeaveRecordSitting`. Delete (with `readDiveCenterDeleteUsage` and its confirmation) through `recordOperationRunnerOf`; History and Open in Connections work locked.
- Consumes: Tasks 12 and 13.

- [ ] **Step 1: Write the failing tests**: as Task 5's six, for dive centres.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(dive-centers): edit addresses and panes open the page unlocked; delete as a whole-record operation`.

### Task 15: Push, open the pull request, track it to green

- [ ] **Step 1:** Merge origin/main once more; whole-repo `flutter analyze`; `dart format` every changed file. Expected: clean.
- [ ] **Step 2:** Push in the background (`git push -u origin HEAD`), touching no `lib/` or `test/` file while it runs. Fix any hook failure in its own commit.
- [ ] **Step 3:** `/code-review xhigh --fix --max-findings all`; fix every valid finding test first; push again.
- [ ] **Step 4:** Screenshots from headless widget-test goldens with the switch on (never `flutter test ... -d macos`): each page locked (before) and unlocked, with a card open (the certification's Details, the buddy's Contact, the centre's Map), the buddy certification dialog, the buddy Gear card with a held lend, and the merge page before and after; light and dark for the unlocked bars; phone and desktop for the panes. Attached through the project's current secret screenshot gist.
- [ ] **Step 5:** `gh pr create` from the template, title `feat(editing): buddies, dive centres and certifications edit in place, behind a switch`, body with `Refs #4527`, the files shared with the site switch-over named, and the screenshots; bind it, turn Auto-fix on, and follow it until every check is green, fixing each failure and review comment as it comes.

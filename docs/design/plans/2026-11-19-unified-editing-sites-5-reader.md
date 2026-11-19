# Unified Editing, Phase 2, Plan 5: A Library Reader's Sitting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A shared site library reader suggests changes from the site page itself: the unlock reads "Suggest changes", the reader's private notes, rating and attachments are written as one History entry, and the changed shared fields, types and tags go to the owner as a suggestion with an optional note.

**Architecture:** The reader's sitting is the page's ordinary sitting with a different end. The page offers a sitting to a connected reader as well as an editor; which cards are open to the reader comes from one card rule (`siteReaderCardRule`); and at Save the role as stored then decides between today's save and a Send: a private write through the site save service (`privateOnly: true`, which skips the edit check and runs only the private cards' held writes), then `SuggestionService.propose` with the working site and the type and tag lists. The few shared pieces it needs (a save label, a hook before Save, a "Library" fade, an edge label and held writes by card) go under `lib/shared/widgets/record_editing/`, named for what they do.

**Tech Stack:** Flutter, Riverpod 3, drift (test database through `setUpTestDatabase`), `flutter gen-l10n` with 11 ARB locales.

**Spec:** `docs/design/specs/2026-11-17-unified-editing-phase-2-sites-design.md`, "Design: a library reader", decision 3, the "Calls made in this note" lines on a reader, and the test notes ("A reader's Send writes only the private fields to the row and proposes the rest; Cancel writes nothing"). Plans 1 to 4b (`docs/design/plans/2026-11-17-unified-editing-sites-1-shared-host.md` to `2026-11-18-unified-editing-sites-4b-attachments.md`) shipped the names used here.

## Questions for Eric

The plan is written to the recommended answer of each; a different answer changes only the task named.

1. **The note dialog when nothing goes to the owner.** Recommended: Send asks for the note only when the sitting holds changes that go to the owner (shared fields, types, tags); a sitting that changed only notes, rating or attachments writes at once and says "Your notes and rating are saved." The alternative is to always ask, as the form's note field was always there. (Task 4.)
2. **An editor whose role drops to reader during a sitting.** The spec decides at Send from the role as stored then. Recommended: a sitting opened as a reader's that finds the profile an editor at Send saves as an edit, as the spec says; a sitting opened as an editor's whose role drops to reader ends as withdrawn, as it does today, since it may hold changes a reader cannot send (features, expected species). The alternative turns it into a Send and drops those changes. (Tasks 2 and 4.)
3. **A reader's Remove from profile.** Once a reader is offered a sitting, the page's whole-record operations go through it, as an editor's do (plan 4): Remove waits for the unlock with nothing unsaved, under "Unlock to use these". Recommended: yes, the same rule for everyone on a page that offers a sitting. The alternative keeps a reader's Remove running at once, as today. (Task 2.)
4. **The "saved privately" words.** A reader's attachments are now private changes too, but today's message names only notes and rating. Recommended: keep `sharedLibrary_suggest_savedPrivate` as it is. The alternative is new copy, "Your own changes are saved", in all 11 languages. (Task 4.)

## Global Constraints

- Behind `kUnlockSiteEditing`: with it off, the page, its "Suggest changes" button and `/sites/:id/edit?suggest=1` behave exactly as today.
- A reader's sitting never writes the library site: no scalar library field, type, tag, feature or species row changes on Send (spec anti-goal).
- Private to the reader: notes, rating, and the reader's media and document attachments. Shared (suggested): the header block's name, water type and types, and the description, location, depth, altitude, difficulty, hazards, access and tags cards. Library (faded, no pencil): features and expected species (`marineLife`). Sharing is not offered (the header editor already hides it on a library site).
- A library not connected on this device offers no unlock at all, and keeps its "Connect on this device" button.
- The role is read again at Send from the store (`libraryRoleNow`), not from `?suggest=1` and not from the providers.
- Existing strings: `sharedLibrary_suggest_title` "Suggest changes", `sharedLibrary_suggest_send` "Send", `sharedLibrary_suggest_note_label`, `sharedLibrary_suggest_sent`, `sharedLibrary_suggest_savedPrivate`, `sharedLibrary_suggest_nothingChanged`. New strings go into all 11 ARB files with an `@key` description in `app_en.arb`, then `flutter gen-l10n`.
- Shared changes live in `lib/shared/widgets/record_editing/`, each named for what it does, since phase 3 builds on them; the dive page is unchanged.
- Never an em-dash or en-dash as punctuation; nothing names Claude, Claude Code or Anthropic.
- Test commands name test FILES by path, never a folder, `test/architecture/` or `test/shared/`.
- `dart format` the changed files before each commit.

## Review Focus

1. A reader's Send that changed only notes: no suggestion is made and the shared fields are untouched. Pinned in Task 4.
2. The role reloading (a sync) while a reader's sitting is open: the sitting stays, as an editor's does (plan 2's `_libraryAccessSettled`). Pinned in Task 2.
3. A reader opening `/sites/:id/edit?suggest=1` with the switch on lands on the page in a reader's sitting, not the form; an editor at the same address edits. Pinned in Task 2.
4. Cancel after changing notes and a shared field: nothing written, nothing proposed. Pinned in Task 4.
5. A Send whose private write fails: nothing proposed, the page stays unlocked with the sitting. Pinned in Task 4.

## File Structure

- `lib/shared/widgets/record_editing/record_edit_bar.dart`, `record_edit_pane_header.dart` (modify): an optional `saveLabel`.
- `lib/shared/widgets/record_editing/record_edit_host.dart` (modify): `String? get saveLabel` and `Future<bool> beforeSave()`, passed to the bars and asked by `saveAndReport`.
- `lib/shared/widgets/record_editing/record_card_fade.dart` (modify): `RecordCardFadeReason.library`, and `RecordCardEdgeLabel` (the same word on the card's edge, with no fade).
- `lib/shared/widgets/record_editing/edit_session.dart` (modify): `runHeldWrites` takes the cards whose writes run.
- `lib/features/dive_sites/presentation/editing/site_reader_sitting.dart` (create): the reader's card rule, the sitting's reader mark, and `libraryRoleNow` moved out of the form.
- `lib/features/dive_sites/presentation/editing/site_reader_send.dart` (create): the Send: private write, then the proposal.
- `lib/features/dive_sites/data/services/site_edit_save_service.dart` (modify): `privateOnly`.
- `lib/features/dive_sites/presentation/pages/site_detail_page_editing.dart`, `site_detail_page_bars.dart`, `site_detail_page.dart`, `site_edit_routes.dart` (modify): offer, unlock control, card framing, Save.
- `lib/features/dive_sites/presentation/editing/site_header_card_editor.dart` (modify): the catalogue offer reads only in a reader's sitting.
- `lib/features/dive_sites/presentation/pages/site_edit_page.dart` (modify): uses the moved `libraryRoleNow`.

---

### Task 1: The shared pieces a reader's sitting needs

**Files:**
- Modify: `lib/shared/widgets/record_editing/record_edit_bar.dart`, `record_edit_pane_header.dart`, `record_edit_host.dart`, `record_card_fade.dart`, `edit_session.dart`
- Modify: `lib/l10n/arb/app_*.arb` (11 files)
- Test: `test/shared/widgets/record_editing/record_edit_bar_test.dart`, `record_edit_pane_header_test.dart`, `record_edit_host_test.dart`, `record_card_fade_test.dart`, `edit_session_test.dart`

**Interfaces:**
- Produces: `RecordEditBar({..., String? saveLabel})` and `RecordEditPaneHeader({..., String? saveLabel})`: the Save button's text, `l10n.forms_save` when null.
- Produces: in `RecordEditHost<W, T>`, `String? get saveLabel => null;` passed by `editScaffold` and `editingPaneRow` to the bars, and `Future<bool> beforeSave() async => true;`, which `saveAndReport` awaits before `controller.save()`; false leaves the sitting as it is and saves nothing.
- Produces: `RecordCardFadeReason.library`, drawn with `l10n.recordEdit_library` "Library"; and `RecordCardEdgeLabel<T>({required String label, required Widget child})`: while its record is unlocked, [label] on the card's top edge as the fade draws its word, with no fade and no tap; locked, or with no scope, [child] alone.
- Produces: `EditSession.runHeldWrites({bool beforeRecord = false, Set<String>? cardIds})`: with [cardIds], only the held changes of those cards run (a held write with no card never does).
- Produces: ARB keys `recordEdit_library` en "Library", `recordEdit_onlyYou` en "Only you".

- [ ] **Step 1: Write the failing tests:**
  - `record_edit_bar_test.dart`: `a save label replaces Save`: `RecordEditBar(saveLabel: 'Send', ...)` shows "Send" and no "Save"; tapping it calls `onSave`.
  - `record_edit_pane_header_test.dart`: the same for `RecordEditPaneHeader`.
  - `record_edit_host_test.dart` (its `_NotePage` gains a `saveLabel` and a `beforeSave` answer): `the host's save label reaches the bar`; `a beforeSave that answers false saves nothing and keeps the sitting` (one edit, Save; `probe.saves` empty; `RecordEditBar` still shown); `a beforeSave that answers true saves`.
  - `record_card_fade_test.dart`: `library fades with its word while unlocked`; `an edge label shows its word while unlocked and does not fade` (`Opacity` absent or 1.0 around the child); `locked, the edge label draws only the child`.
  - `edit_session_test.dart`: `held changes run only for the cards named` (two `holdChange`s on cards `a` and `b`, `runHeldWrites(cardIds: {'a'})` runs only `a`'s); `a held write with no card does not run when cards are named`.
- [ ] **Step 2: Run them; they fail.**
  `flutter test test/shared/widgets/record_editing/record_edit_bar_test.dart test/shared/widgets/record_editing/record_edit_pane_header_test.dart test/shared/widgets/record_editing/record_edit_host_test.dart test/shared/widgets/record_editing/record_card_fade_test.dart test/shared/widgets/record_editing/edit_session_test.dart`
- [ ] **Step 3: Implement** the five changes and the ARB keys (then `flutter gen-l10n`). `RecordCardFade` draws its word through `RecordCardEdgeLabel`'s label widget, so the two look alike.
- [ ] **Step 4: Run them, with the dive page's host tests; all pass.** The same command plus `test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart`.
- [ ] **Step 5: Commit** `feat(record-editing): a save label, a check before Save, a Library fade and held writes by card`.

### Task 2: The reader's unlock

**Files:**
- Create: `lib/features/dive_sites/presentation/editing/site_reader_sitting.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page_editing.dart`, `site_detail_page_bars.dart`, `site_detail_page.dart`, `site_edit_routes.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart` (`_libraryRoleNow` replaced by the moved function)
- Test: `test/features/dive_sites/presentation/pages/site_detail_page_reader_test.dart` (create), `test/core/router/app_router_test.dart`

**Interfaces:**
- Consumes: Task 1's `saveLabel`.
- Produces in `site_reader_sitting.dart`:
  - `Future<SharedLibraryRole?> libraryRoleNow(ProviderRead read, String libraryId)`: the body of `_SiteEditPageState._libraryRoleNow`, unchanged (the effective role from the store, null when the library is not connected here).
  - `void markReaderSitting(EditSession<DiveSite> session)` and `bool isReaderSitting(EditSession<DiveSite>? session)`, through `session.remember('site.readerSitting', true)`.
- Produces in the page: `_offersEditingNow({bool watch = false})` now also offers a sitting on a connected library whose settled role may suggest (`canSuggestOnLibrarySite`), so the lock, the keys, `_endWithdrawn` and the whole-record operations (Question 3) follow it. `bool _suggestsNow({bool watch = false})`: offered, and not `_canEditSite`.
- Produces: the unlock control in the full page's bar and the pane header: `lockButton(site)` for an editor; for a reader, a `TextButton.icon` (icon `Icons.rate_review_outlined`, label `sharedLibrary_suggest_title`, key `ValueKey('site_suggest_unlock')`) that calls `editController.unlock(site)`. `onSittingStart` calls `markReaderSitting` when `_suggestsNow()`. `editingTitle` returns `sharedLibrary_suggest_title` and `saveLabel` returns `sharedLibrary_suggest_send` in a reader's sitting.
- Produces: with the switch on, the page offers no separate "Suggest changes" button (`_libraryButtons` keeps "Connect on this device"), and `siteEditLocation(siteId, query)` returns `/sites/<id>?mode=edit` for `?suggest=1` too.

- [ ] **Step 1: Write the failing tests** in `site_detail_page_reader_test.dart`, on `pumpSitePage` with a library site (`sharedLibraryId: 'L'`) and the overrides plan 4's operations test uses for a reader (`libraryRoleProvider('L')` reader, `libraryConnectedHereProvider('L')` true, `siteLibraryStateProvider`, `libraryMemberNamesProvider`, `currentMembershipProvider`):
  - `a reader's unlock reads Suggest changes`: `site_suggest_unlock` shows, no `Icons.lock_outline`, no separate "Suggest changes" button besides it.
  - `the reader's bar is titled Suggest changes and saves with Send`: unlock; `RecordEditBar` shows "Suggest changes" and "Send".
  - `an editor sees the lock`: role editor; `Icons.lock_outline`, no `site_suggest_unlock`.
  - `a library not connected here offers no unlock`: connected false; neither control; "Connect on this device" shows.
  - `a role still loading offers no unlock yet`: the role provider never completes; neither control.
  - `a role that reloads keeps the reader's sitting` (Review Focus 2): as plan 2's reload test, with the reader role.
  - `an editor's sitting whose role drops to reader ends withdrawn` (Question 2): editor unlocks; role becomes reader (settled); the sitting ends with `diveSites_edit_editingWithdrawn`.
  - `with the switch off the page is as today`: `unlockEditing: false`; the "Suggest changes" button shows and no unlock control.
  - `a reader's Remove waits for the unlock` (Question 3): locked, the menu's Remove is disabled under "Unlock to use these"; unlocked with nothing to save, it runs. Plan 4's `a library reader still removes the site from the profile` in `site_detail_page_operations_test.dart` changes to this.
  - In `app_router_test.dart`: `siteEditLocation sends ?suggest=1 to the page in edit mode` (Review Focus 3): `siteEditLocation('s1', {'suggest': '1'}, unlockEditing: true)` is `/sites/s1?mode=edit`; with `unlockEditing: false`, null.
- [ ] **Step 2: Run them; they fail.**
  `flutter test test/features/dive_sites/presentation/pages/site_detail_page_reader_test.dart test/core/router/app_router_test.dart`
- [ ] **Step 3: Implement** the offer, the unlock control, the reader mark, the title and save label, the button and the route.
- [ ] **Step 4: Run them, with the page's own tests and the form's suggest test; all pass.**
  `flutter test test/features/dive_sites/presentation/pages/site_detail_page_reader_test.dart test/core/router/app_router_test.dart test/features/dive_sites/presentation/pages/site_detail_page_unlock_test.dart test/features/dive_sites/presentation/pages/site_detail_page_unlock_pane_test.dart test/features/dive_sites/presentation/pages/site_detail_page_operations_test.dart test/features/dive_sites/presentation/pages/site_edit_suggest_mode_test.dart`
- [ ] **Step 5: Commit** `feat(sites): a library reader unlocks the site page to suggest changes`.

### Task 3: The cards in a reader's sitting

**Files:**
- Modify: `lib/features/dive_sites/presentation/editing/site_reader_sitting.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page_editing.dart` (`_framed`, `addStripEntries`)
- Modify: `lib/features/dive_sites/presentation/editing/site_header_card_editor.dart`
- Test: `test/features/dive_sites/presentation/pages/site_detail_page_reader_test.dart`, `test/features/dive_sites/presentation/editing/site_reader_sitting_test.dart` (create)

**Interfaces:**
- Consumes: Task 1's `RecordCardFadeReason.library`, `RecordCardEdgeLabel`, `recordEdit_onlyYou`; Task 2's `isReaderSitting`.
- Produces: `enum SiteReaderCard { suggested, private, library }` and `SiteReaderCard siteReaderCardRule(String cardId)`: `private` for `notes`, `rating`, `media`, `documents`; `library` for `features`, `marineLife`; `suggested` for every other card, the header block included.
- Produces: in a reader's sitting `_framed` frames a `library` card in `RecordCardFade<DiveSite>(reason: RecordCardFadeReason.library)` with no pencil, and wraps the frame of `notes` and `rating` in `RecordCardEdgeLabel<DiveSite>(label: l10n.recordEdit_onlyYou)`; `addStripEntries` offers no `library` card. The header editor passes `reviewable: false` to `SiteCatalogueOfferLine` in a reader's sitting.

- [ ] **Step 1: Write the failing tests:**
  - `site_reader_sitting_test.dart`: `the rule names each card` (every key of `siteEditCards` plus `siteHeaderCardId` gets the value listed above, as a table test).
  - `site_detail_page_reader_test.dart`: `features and expected species fade as Library with no pencil` (reader unlocked; "Library" twice; no `RecordPencilIcon` inside those two cards); `notes and rating say Only you and keep their pencils`; `the strip offers no Library card` (no `AddStripEntry` for `features` or `marineLife` in a site with neither); `the catalogue offer reads only` (with `catalogueGapPairForSiteProvider` overridden to a pair, the header editor shows no Review button); `an editor's sitting shows no Library or Only you`.
- [ ] **Step 2: Run them; they fail.**
  `flutter test test/features/dive_sites/presentation/editing/site_reader_sitting_test.dart test/features/dive_sites/presentation/pages/site_detail_page_reader_test.dart`
- [ ] **Step 3: Implement** the rule and its use in `_framed`, `addStripEntries` and the header editor.
- [ ] **Step 4: Run them, with the cards' tests; all pass.**
  `flutter test test/features/dive_sites/presentation/editing/site_reader_sitting_test.dart test/features/dive_sites/presentation/pages/site_detail_page_reader_test.dart test/features/dive_sites/presentation/pages/site_detail_page_unlock_cards_test.dart`
- [ ] **Step 5: Commit** `feat(sites): a reader's sitting edits private cards, suggests shared ones, and leaves the library's`.

### Task 4: Send

**Files:**
- Create: `lib/features/dive_sites/presentation/editing/site_reader_send.dart`
- Modify: `lib/features/dive_sites/data/services/site_edit_save_service.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page_editing.dart` (`beforeSave`, `saveSitting`)
- Test: `test/features/dive_sites/data/services/site_edit_save_service_test.dart`, `test/features/dive_sites/presentation/editing/site_reader_send_test.dart` (create), `test/features/dive_sites/presentation/pages/site_detail_page_reader_test.dart`

**Interfaces:**
- Consumes: Task 1's `beforeSave`, `runHeldWrites(cardIds:)`; Task 2's `libraryRoleNow`, `isReaderSitting`; Task 3's `siteReaderCardRule`.
- Produces: `SiteEditSaveService.save({..., bool privateOnly = false})`: with it, the `mayEdit` check is skipped and the site's write is kept to its private fields (`SiteRepository.updateSite` already does this for a profile that may not edit); everything else (one transaction, one change log operation, the stamps) as today.
- Produces in `site_reader_send.dart`:
  - `bool readerSendProposes(EditSession<DiveSite> session)`: whether the sitting changed a `suggested` card (a field of one, or `siteTypesList` or `siteTagsList`).
  - `Future<String?> askSuggestionNote(BuildContext context)`: an `AlertDialog` titled `sharedLibrary_suggest_title` with one text field labelled `sharedLibrary_suggest_note_label` and Cancel and `sharedLibrary_suggest_send`; the note, or null when cancelled.
  - `Future<SiteReaderSent> sendReaderSitting(EditSession<DiveSite> session, {required SiteEditSaveService service, required SuggestionService suggestions, required String diverId, required String note, required Future<Map<String, String>> Function() typeNames})`, `enum SiteReaderSent { sent, savedPrivate, nothingChanged }`. In order: `service.save(privateOnly: true, apply: session.applyTo, changedCardIds:` the changed `private` cards, `alsoWrite: () => session.runHeldWrites(cardIds: {media, documents})`); then, when `readerSendProposes`, `suggestions.propose(proposed: session.working, diverId, note, childFields: suggestionChildFields(...))` from the two lists' `loaded` and `current`. A failed private write throws and proposes nothing.
- Produces: the page's `beforeSave`: for a library site, `libraryRoleNow` decides; a reader (or null) remembers a Send, and asks `askSuggestionNote` only when `readerSendProposes` (Question 1), answering false when it is cancelled. `saveSitting` runs `sendReaderSitting` for a Send and says `sent`, `savedPrivate` or `nothingChanged` with the existing snack bar strings; otherwise today's save.

- [ ] **Step 1: Write the failing tests:**
  - `site_edit_save_service_test.dart`: `privateOnly writes a reader's notes and rating and nothing else` (a library site the acting profile only reads; `apply` changes notes, rating and name; one change log operation; the stored name unchanged); `without privateOnly a reader's save is refused` (today's `SiteEditRefused`, kept).
  - `site_reader_send_test.dart`, on the test database with a fake `SuggestionService` that records its calls: `notes only: saved privately, nothing proposed` (Review Focus 1); `a shared field and notes: the notes are written and the field proposed, the site's field untouched`; `types and tags go to the proposal by name`; `a failed private write proposes nothing` (a service whose `save` throws; the fake has no calls) (Review Focus 5); `held media is written, held type changes are not`.
  - `site_detail_page_reader_test.dart`: `Send asks for a note when something goes to the owner`; `Send with only notes asks nothing and says saved privately`; `cancelling the note dialog keeps the sitting`; `Cancel writes nothing and proposes nothing` (Review Focus 4); `a reader's sitting that finds the profile an editor at Send saves as an edit` (`libraryRoleNow` reads editor from the store; the save service gets `privateOnly: false`).
- [ ] **Step 2: Run them; they fail.**
  `flutter test test/features/dive_sites/data/services/site_edit_save_service_test.dart test/features/dive_sites/presentation/editing/site_reader_send_test.dart test/features/dive_sites/presentation/pages/site_detail_page_reader_test.dart`
- [ ] **Step 3: Implement** `privateOnly`, the Send file and the page's `beforeSave` and `saveSitting`.
- [ ] **Step 4: Run them, with the save census and the page's tests; all pass.**
  `flutter test test/features/dive_sites/data/services/site_edit_save_service_test.dart test/features/dive_sites/data/services/site_edit_save_census_test.dart test/features/dive_sites/presentation/editing/site_reader_send_test.dart test/features/dive_sites/presentation/pages/site_detail_page_reader_test.dart test/features/dive_sites/presentation/pages/site_detail_page_unlock_test.dart`
- [ ] **Step 5: Commit** `feat(sites): a reader's Send writes their own changes and proposes the rest`.

### Finish

- [ ] `/code-review` at the agreed level with `--max-findings all`, every valid finding fixed.
- [ ] Open the PR: `Refs #4527`; screenshots of a reader's locked page (the "Suggest changes" unlock), the reader's sitting (Library and Only you), and the note dialog, phone and desktop widths, light only, from headless goldens in a throwaway scratchpad test never committed, through the current secret gist; Auto-fix on.

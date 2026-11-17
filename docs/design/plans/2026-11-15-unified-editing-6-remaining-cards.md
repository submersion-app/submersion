# Unified Editing, Plan 6: The Remaining Cards, the Fullscreen Profile and Dropped Files Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every dive card that has something to edit an in-place editor (Profile annotations, Safety review, Underwater track, Buddies, Signatures, Sightings, Media, Documents, Custom fields, Compare), fade the calculated and imported cards while unlocked, make the fullscreen profile obey the sitting, and send files dropped on a dive through the sitting (issue #4527).

**Architecture:** Custom fields and the diver's own role are columns `updateDive` already writes, so they are `EditField`s like plans 2 to 5. Everything else on these cards is child rows `getDiveById` never loads: buddies, sightings, signatures, annotations, finding dismissals, route links, the plan link, document owners and media rows. Each becomes a held collection: read when the sitting starts, changed in the sitting, shown by its read card from the sitting once changed, and written as a held change inside Save's transaction (`EditSession.holdChange`). A new shared `SittingList` carries that pattern once. Writes that land in another database (media uploads, remote blob deletes) and cache clears run after the commit, guarded, as the follow-up does. The widgets that write today gain a read-only state for a locked page and a sitting target for an open card. Still behind `kUnlockEditing`.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift (SQLite), go_router, `desktop_drop`, `flutter gen-l10n`.

**Spec:** `docs/design/specs/2026-11-14-unified-editing-pattern-design.md`. Read the Cards table, "Cards when unlocked", "Pages opened from a record's page", "What is held, and what is not" and "What a locked dive page no longer shows". Plan 5 is `docs/design/plans/2026-11-15-unified-editing-5-tanks-equipment-weights.md`; its "For plans 6 to 8" and "After the review", and the same sections of plans 2 to 4, list the names as built. This plan uses those names. Facts gathered for it are in the session notes file `plan-6-findings.md`, with file and line for each seam.

## What each card owns, shows and leaves alone

Card ids are the section's `name` (`DiveDetailSectionId.x.name`), as for every card so far.

| Card | Held in the sitting | Written at Save by | Today |
| --- | --- | --- | --- |
| `customFields` | `diveCustomFieldsField`, `List<DiveCustomField>` | `updateDive` (`_writeCustomFieldDiff`) | form only (`_customFieldsChild`, `dive_edit_page.dart:2867`) |
| `buddies` | buddies with roles (`SittingList`), `diveDiverRoleIdsField` | `BuddyRepository.setBuddiesForDive`; `updateDive` for the role | form (`BuddyPicker`), read card's legacy Link writes at once |
| `sightings` | sightings (`SittingList`) | `SpeciesRepository.addSighting`, `updateSighting`, `deleteSighting` | form (`_sightingsChild`, reused by bulk) |
| `signatures` | captures and deletes (`SittingList` of `HeldSignature`) | `SignatureStorageService.saveSignature`, `saveBuddySignature`, `deleteSignature` | read card writes at once |
| `profile` | annotations: placed, moved, removed, and pins placed from the notes | `AnnotationRepository.reconcile`, then `moveAnnotation` | read card and fullscreen write at once |
| `safetyReview` | dismissals and restores by finding id | `SafetyFindingsRepository.setDismissed` | read card and chart callouts write at once |
| `navTrack` | `DiveRouteLinkDraft` with a primary | `applyDiveRouteLinkDraft`, then `NavTrackRepository.setPrimary` | form (draft), read card menu writes at once |
| `diveLab` | the linked plan id | `DivePlanRepository.linkPlanToDive`, `unlinkPlan` | read card and the lab page write at once |
| `documents` | documents to attach, documents to detach | `DocumentRepository.setDiveOwner` (new) | Add creates an owned document at once |
| `media` | photos, videos and media documents added; rows unlinked; links replaced | `MediaRepository.createMedia` and `saveEnrichment`, `NetworkFetchPipeline.insertResolved`, `MediaRepository.unlinkFromDive` and `deleteMultipleMedia`, `MediaRepairService` | read card writes at once |

Each entry's title is the string its read card already shows: `diveLog_detail_section_diveProfile`, `safetyReview_sectionTitle`, `diveLog_detail_section_buddies`, `diveLog_detail_section_marineLife`, `media_diveMediaSection_title`, `documents_section_title`, `diveLog_detail_section_customFields`; Signatures, Underwater track and Compare have no single title string on their read card, so theirs is `DiveDetailSectionId.x.localizedDisplayName(context.l10n)`.

Cards with nothing to edit fade while unlocked and say why: "Calculated" for `decoStatus`, `tissueLoading`, `sacSegments`, `tide`, `buoyancy`; "Imported" for `health`, `surfaceGps`. `dataSources` has no held edits: its buttons are plan 7's.

## Rules that cross these cards

| Change | Effect | Built in |
| --- | --- | --- |
| A pin placed on the profile, or from the notes | A linked line joins the notes (Notes gets its dot) and a pending annotation joins Profile | Tasks 10 and 12 |
| An annotation removed | Its words in the notes are unlinked (Notes gets its dot) | Task 10 |
| Notes changed in any way | Save reconciles annotations with the notes as saved, so a link deleted from the text deletes its row | Task 10 |
| Runtime, bottom time, exit (header) | Bound annotation times, through `annotationTimeLimits`, read from the sitting | Task 10 |
| Buddies (this plan) | A buddy added in the sitting can be asked for a signature; one removed takes its held request with it | Task 9 |
| Courses (Details) | A training signature is offered while the sitting has a course | Task 9 |
| Site (header) | Species suggestions follow `session.working.site` (plan 4's note) | Task 8 |
| Planned switch (header) | Hides the route editor; held route links are not written for a planned dive | Task 15 |

## Where these cards differ from today, and why

1. **Every write on these cards waits for Save.** Today the Signatures, Safety review, Underwater track, Compare, Media and Documents cards, the profile and the fullscreen page write at once. Why: the spec holds them.
2. **Annotations are reconciled whenever the notes change.** A sitting that edited the notes left annotation rows whose link was gone (they were hidden on read by `dropOrphanAnnotations`). Now Save settles them, as the form's save does.
3. **The chart callout offers no Dismiss with the switch on.** A finding is dismissed in the open Safety review card, the one place (call 1).
4. **A new document is filed as Personal first.** It is created at once, as a record of its own, and joined to the dive at Save. Cancel leaves it in the library (Eric's choice).
5. **The Files tab, opened from a sitting, links only this dive.** Files that match another dive are left out, with a line saying how many (Eric's choice).
6. **A drop on a locked dive is refused** with a one-line hint, in the page and in the dives list pane (Eric's choice). During a sitting it opens the Media card and the picker with the files staged.
7. **The dive lab page's Link and Unlink menu items are hidden** with the switch on. Linking moves to the Compare card's editor (Eric's choice).
8. **The fullscreen profile and the dashboard preview's fullscreen read only**, unless opened from the open Profile card in a sitting (Eric's choices).

## Not in this plan

- The Data sources card's buttons, set primary source on the profile's source bar, Edit profile, add heart rate, link or unlink a pre-dive checklist, mark logged and the rest: whole-record operations, plan 7. They stay as they are here.
- The embedded list pane's lock (plan 7): until then a drop on the pane is refused (difference 6).
- A new dive and its starter set (plan 8).
- History for the tables the change log does not yet log as edits or under the dive: finding dismissals, document owners, plan links, route links (plan 9). The writes are in the sitting's transaction already.
- The photo viewer's own lock (plan 10). Opening a photo from the Media card keeps working during a sitting.
- Bulk edit. It keeps `BuddyPicker`, the sightings editor (moved to a file of its own in Task 7, behaviour unchanged) and its own role pickers.

## The form's own tests

The form and its tests stay until plan 11 deletes the form. Read each at the start of the task named and add to that task's tests any behaviour it pins that the list there does not.

| Form test (`test/features/dive_log/presentation/pages/`) | Replaced in |
| --- | --- |
| `dive_edit_page_coverage_test.dart` (custom fields, sightings) | Tasks 4 and 8 |
| `dive_edit_buddy_owner_test.dart`, `dive_edit_preserves_hidden_fields_test.dart` (role) | Tasks 5 and 6 |
| `dive_edit_site_species_suggestions_test.dart` | Task 8 |
| `dive_edit_annotations_test.dart` | Tasks 10 and 12 |
| `dive_edit_route_links_test.dart` | Task 15 |
| `bulk_dive_edit_form_test.dart`, `bulk_membership_wiring_test.dart`, `bulk_dive_edit_site_test.dart` | Unchanged; run in Tasks 7 and 23 |

## Calls made in this plan, for Eric to check

Eric chose, on 2026-11-15: one plan and one pull request; chart write controls only in the open card; the fullscreen profile edits only from the open Profile card, and reads only from the dashboard; documents created at once with the link held; pending photos drawn as tiles; the Files tab links only this dive; drops on a locked dive refused, pane included; the lab page's link items hidden; the legacy buddy Link held; URL photos fetched at once and stored at Save. These were made in writing the plan and are not confirmed:

1. **The chart callout's Dismiss is hidden with the switch on**, on the card, the pinned copy and the fullscreen page. Dismissing lives in the open Safety review card only, which follows "only in the open card" with one place to do it.
2. **The Profile card, open or closed, draws the sitting's annotations and gas switches** during a sitting, as an editable card shows its working values. The pinned squashed copy reads only, with the same values.
3. **Annotations are not checked against the dive's times at Save.** A stored annotation past the end (the agent path allows 24 hours when there is no profile) must not stop a note being saved. The time sheet still refuses a time past the end, as today.
4. **Removing an annotation unlinks its words in the notes**, as today, so Notes gets its dot with Profile.
5. **Add strip:** Custom fields, Buddies, Sightings, Media, Documents, and Underwater track (not for a planned dive) are offered when empty. Profile, Safety review, Signatures (without a buddy or a course in the sitting) and Compare (not eligible and not linked) are not: each has nothing to edit until something else exists.
6. **Custom fields: a reorder is a change**, and a row with an empty key is dropped at Save, as the form does.
7. **A photo unlinked in a sitting that belongs to nothing else is deleted at Save**, as today; its remote copy and caches are cleared after the write, best effort. Uploads for added photos and for a replaced link are queued after the write, best effort: they live in another database.
8. **A drop during a sitting opens the Media card** (from the strip if it is not on the page) and then the picker with the files staged.
9. **Set primary on a route is held**, like unlink, and `DiveRouteLinkDraft` gains a primary.
10. **Compare's editor can unlink as well as link**, held, with today's confirm. "Ask a what-if" and the saved what-ifs stay usable while locked: a what-if is a record of its own.
11. **The document editor, opened from a sitting, hides its owner choice**: the new document is Personal until Save joins it to the dive. Remove on the card detaches (held); the document stays in the library. The card offers no picker of existing documents, as today.
12. **The fade label sits at the header's right** without changing its height.
13. **A buddy added in the sitting can be asked for a signature**; the signature is written after the buddies.
14. **Four new strings** (Task 3, Task 19, Task 21): `recordEdit_calculated` "Calculated", `recordEdit_imported` "Imported", `diveLog_media_dropUnlockHint` "Unlock this dive to add photos to it.", `media_picker_otherDivesLeftOut` "{count, plural, =1{1 file matches another dive and was left out} other{{count} files match other dives and were left out}}". Card titles reuse the read cards' own.

## Global Constraints

- With `kUnlockEditing` false the dive page, the fullscreen profile, the dashboard preview, the dive lab page, the photo picker and the drop target build and behave exactly as today.
- A locked page shows no control on these cards that writes. A card does not move on the page when unlocked, nor while its editor is open, whatever is typed or picked in it or another card.
- A value the diver did not change is never written. Opening each card and closing it leaves the sitting clean. A held collection the diver has not changed follows the stored rows when they change, and writes nothing.
- Every held write runs inside `DiveEditSaveService.save`'s transaction, through `session.runHeldWrites`. Nothing that runs there writes to another database, clears a cache or shows UI: that is the follow-up's (Task 22).
- Records created from a picker stay created after Cancel, as today: a buddy, a role, a species, a document, an unlinked route imported from a file, a buddy from the legacy Link. Only the dive's link to them is held.
- Every value shown or typed follows the active diver's units (`unitFormatterProvider`), annotation depths and times included.
- Typed numbers are read only through `readNumber`; the architecture guard forbids `tryParse` in presentation code. A text field that shows a value of the sitting gets it through `FieldTextBinding` or `replaceTextKeepingCaret`.
- Anything that writes to a sitting after an `await` (a picker, a sheet, a capture, a fetch, a read) checks `mounted` where it has one, then `session.isDisposed` and `session.isFrozen`, and drops its result when the input it was asked about changed meanwhile. It reads `ref` and `context` before the first `await`. Work a save must wait for is `session.track`ed.
- Each new held key joins `diveOwnHeldWriteKeys` (`dive_edit_cards.dart`): none of them reaches the site list.
- Settings are read with `settingsProvider.select(...)`.
- No file over 800 lines. `dive_detail_page.dart` is at 783: add nothing to it but what Task 21 needs (one line if any). `dive_detail_section_list.dart` is at 746: Task 1 makes room. `dive_edit_page.dart` must not grow. `dive_media_section.dart`, `fullscreen_profile_page.dart` and `photo_picker_page.dart`: check `wc -l` before adding and split first when the addition would pass 800.
- Every new string goes in all 11 ARB files with a real translation, then `flutter gen-l10n`. This plan expects four (call 14).
- No em-dash characters anywhere; no emojis; no mention of any AI tool in code, commits or pull requests. Do not join two parts of a label with a spaced hyphen.
- Tests restore global state: `tester.view` via `addTearDown`, the test database via `tearDownTestDatabase()`, any provider or singleton override they install. Build repositories in `setUp`.
- `session.set(field, 10)` with a whole-number literal on a `double?` field fails at run time: tests spell `10.0`. Type list literals.
- Before each commit: `dart format .`, `flutter analyze`, the affected test files, plus `flutter test test/architecture/ test/shared/` when files under `lib/` were added. Never the whole suite. Do not pipe `flutter test` into `grep` or `tail` to judge the result.
- Do not push or open a pull request; that waits for Eric.

## Review Focus

1. **Cancel after a change on every new card.** Every table is as it was: no media row, signature, sighting, buddy link, annotation row, dismissal, route link, plan link or document owner changed. The buddy, species and document created on the way remain. Pinned in Task 23.
2. **A Save that fails after some held writes ran.** Sightings written, then the media insert throws: no sighting is left, nothing is queued for upload, the page stays unlocked with its dots. Pinned in Tasks 2 and 23.
3. **The stored rows change under a card the diver has not touched** (a sync adds a sighting, a buddy, a photo). The card shows it and Save does not remove it; on a touched card, the diver's list wins for the rows it loaded and a row it never saw is kept. Pinned in Tasks 2, 8 and 18.
4. **An annotation placed and taken back in one sitting** (removed, or its line deleted from the notes): no row is written and the notes are as stored. Pinned in Task 10.
5. **A drop at the wrong moment.** On a locked page, on the list pane, with the picker already open, on a planned dive's page during a sitting: refused or staged, never written before Save. Pinned in Task 21.

## Preparation

- [ ] Work on a branch cut from current `origin/main` (plans 1 to 5 merged; head at or after `82dde28a0d2`).
- [ ] In a fresh worktree: `git submodule update --init --recursive`, `flutter pub get`, then `dart run build_runner build --delete-conflicting-outputs` with no build filter.
- [ ] `flutter analyze` on the whole repository is clean before any change.
- [ ] Take the pull request's "before" pictures now, before any code changes: each of the ten cards and the seven calculated or imported cards locked and unlocked, light and dark, phone and desktop width; the fullscreen profile from the dive page and from the dashboard.

## File Structure

New, shared (`lib/shared/widgets/record_editing/`):

| File | Responsibility |
| --- | --- |
| `sitting_list.dart` | `SittingList<E>`: a child collection read once, changed, shown and written as one held change |
| `record_card_fade.dart` | `RecordCardFade`: a card with nothing to edit, faded while unlocked, with its reason |

New, dive (`lib/features/dive_log/presentation/widgets/dive_detail/editing/`):

| File | Responsibility |
| --- | --- |
| `dive_custom_fields_card_editor.dart` | `diveCustomFieldsField`, `DiveCustomFieldsCardEditor` |
| `dive_buddies_sitting.dart` | `diveBuddiesList`, `diveDiverRoleIdsField`, the legacy link held |
| `dive_buddies_card_editor.dart` | `DiveBuddiesCardEditor` |
| `dive_sightings_sitting.dart` | `diveSightingsList` and its write |
| `dive_sightings_card_editor.dart` | `DiveSightingsCardEditor` |
| `dive_signatures_sitting.dart` | `HeldSignature`, `diveSignaturesList` and its write |
| `dive_signatures_card_editor.dart` | `DiveSignaturesCardEditor` |
| `dive_annotations_sitting.dart` | `SittingAnnotations`: place, move, remove, notes pins, limits, the reconcile at Save |
| `dive_profile_card_editor.dart` | `DiveProfileCardEditor` |
| `dive_safety_sitting.dart` | Dismissals held by finding id |
| `dive_route_links_sitting.dart` | The route link draft held |
| `dive_nav_track_card_editor.dart` | `DiveNavTrackCardEditor` |
| `dive_plan_link_sitting.dart` | The plan link held |
| `dive_document_links_sitting.dart` | Documents attached and detached |
| `dive_documents_card_editor.dart` | `DiveDocumentsCardEditor` |
| `dive_media_sitting.dart` | `SittingMedia`: added, unlinked, replaced; the write and the after-commit work |
| `dive_media_card_editor.dart` | `DiveMediaCardEditor` |

New, elsewhere:

| File | Responsibility |
| --- | --- |
| `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_content.dart` | Part file: `_sectionContent` and `_buildPairCards`, moved |
| `lib/features/dive_log/presentation/widgets/edit_sections/sightings_editor.dart` | `SightingsEditor`, extracted from the form for the form, bulk and the card |
| `lib/features/dive_log/presentation/widgets/dive_detail/annotation_edits.dart` | `AnnotationEdits`: where the profile's annotation actions write |
| `lib/features/media/domain/value_objects/media_hold.dart` | `HeldMediaAdd` and `MediaHoldSink`: what a picker hands a sitting instead of writing |
| `lib/features/dive_log/presentation/providers/open_dive_sitting_provider.dart` | `openDiveSittingProvider`: the sitting the page has open, for the drop target |

Modified, by task: see each task's Files.

---

### Task 1: Room in the section list, and cards whose content is not on the record

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_content.dart` (part of `dive_detail_section_list.dart`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart`
- Modify: `lib/shared/widgets/record_editing/edit_card.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_card_presence.dart` (`diveCardIsShown`, `diveCardIsOnPage` gain `session`)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart` (`_addStripEntries`)
- Test: `test/shared/widgets/record_editing/edit_card_test.dart` (new), `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_card_presence_test.dart` (add cases), `test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart` (one case)

**Interfaces:**
- Produces:

```dart
// EditCard gains
/// Whether the Add strip offers this card while it is off the page, as
/// distinct from hidden by the diver. Null is always. A card that has
/// nothing to edit until something else exists says no.
final bool Function(EditSession<T> session)? offeredWhenEmpty;

/// For a card whose content is rows of its own rather than values of the
/// record (buddies, sightings, media): whether it has nothing to show in
/// [session]. Asked in place of [isEmpty] while unlocked. Locked, such a
/// card's read widget decides for itself, as today, and its [isEmpty]
/// returns false.
final bool Function(EditSession<T> session)? isEmptyInSitting;
```

  `diveCardIsShown` and `diveCardIsOnPage` gain `EditSession<Dive>? session`; with one, a card with `isEmptyInSitting` is asked that. While an editor is open (`layoutRecord` non-null) the answer is the one given when the first editor opened, kept per card for that layout, so a list card that gains its first row waits for the editors to close, as a record card does. The section list and the strip pass the scope's session. `_addStripEntries` leaves out a card whose `offeredWhenEmpty` says no, unless the diver hid it (a hidden card is always offered, as now). `_sectionContent` and `_buildPairCards` move unchanged into the part file as an extension on `DiveDetailSectionList`; the library keeps every import.

- [ ] **Step 1: Write the failing tests**

```dart
test('offeredWhenEmpty and isEmptyInSitting default to null', ...);
test('a card with isEmptyInSitting is asked it during a sitting, and isEmpty when locked', ...);
test('while an editor is open, a list card that gained a row keeps the answer it had', ...);
testWidgets('an empty card that is not offered when empty stays out of the strip; hidden, it is offered', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the two test files.
Expected: FAIL to compile.

- [ ] **Step 3: Move the two methods, then add the parameter and the strip rule**

- [ ] **Step 4: Run and confirm they pass**

Run: the two test files, then `flutter test test/features/dive_log/presentation/widgets/dive_detail/ test/features/dive_log/presentation/pages/dive_detail_page_paired_sections_test.dart`, and `wc -l` on both section list files.
Expected: PASS; the library under 650 lines.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation lib/shared/widgets/record_editing test
git commit -m "refactor(dive-log): make room in the section list, and let a card stay out of the Add strip"
```

---

### Task 2: `SittingList`, a child collection held in a sitting

**Files:**
- Create: `lib/shared/widgets/record_editing/sitting_list.dart`
- Test: `test/shared/widgets/record_editing/sitting_list_test.dart`

**Interfaces:**
- Consumes: `holdChange`, `releaseWrite`, `isHeld`, `remember`, `recall`, `track` (`edit_session.dart`).
- Produces:

```dart
/// A list of rows that belong to a record without being part of it (a
/// dive's buddies, its sightings), held in a sitting as one change of
/// [cardId] under [key].
@immutable
class SittingList<T, E> {
  const SittingList({
    required this.key,
    required this.cardId,
    required this.read,
    required this.write,
    this.same,
  });

  final String key;
  final String cardId;

  /// The rows as stored, for [session]'s record.
  final Future<List<E>> Function(T record) read;

  /// Writes [current] over [loaded] at Save, inside the save's transaction:
  /// rows in [loaded] missing from [current] go, changed ones are updated,
  /// new ones added. A row stored since that [loaded] never had is not
  /// touched. [record] is the record as the save writes it.
  final Future<void> Function(T record, List<E> loaded, List<E> current) write;

  /// Whether two lists are the same change. Null is `listEquals`.
  final bool Function(List<E> a, List<E> b)? same;

  /// Reads the rows unless the diver has changed them in this sitting, so
  /// an untouched list follows what is stored. Tracked. A read answering
  /// after the list was changed, or the sitting ended, is dropped.
  void load(EditSession<T> session);

  /// The loaded rows, or null before the first load.
  List<E>? loaded(EditSession<T> session);

  /// What the sitting has now: the diver's list once changed, else loaded.
  List<E>? current(EditSession<T> session);

  /// Whether the diver has changed the list in this sitting.
  bool isChanged(EditSession<T> session);

  /// Sets the diver's list. One the same as [loaded] releases the change.
  /// Does nothing before the load, or while frozen or disposed.
  void set(EditSession<T> session, List<E> next);
}
```

  `write` is held through `session.holdChange(key, cardId:, write: () => write(session.working, loaded, current))`, reading `loaded` and `current` when it runs. Loading keeps the rows with `remember` and does not notify: until the list is changed the read card shows its provider's rows, which are the same, so a load never makes the sitting dirty. `startDiveSitting` loads each list as the sitting starts; a card's editor calls `load` again when it opens, which reads afresh only while the list is unchanged.

- [ ] **Step 1: Write the failing tests**

```dart
test('load reads once per open while unchanged, and an unchanged list writes nothing', ...);
test('set holds one change of the card; setting it back releases it', ...);
test('a changed list is not read again: the diver\'s list stays', ...);
test('the held write gets the loaded and current lists as they are when it runs', ...);
test('a read answering after the list was changed is dropped', ...);
test('a read answering after the sitting ended sets nothing', ...);
test('set before the load does nothing', ...);
test('a custom same: the same rows in another order are no change', ...);
test('a write that throws stops the save; nothing after it runs', () async {
  // two SittingLists over the test database; the second write throws inside a transaction: the first list's rows are rolled back.
});
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/shared/widgets/record_editing/sitting_list_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/shared/ test/architecture/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing/sitting_list.dart test/shared/widgets/record_editing/sitting_list_test.dart
git commit -m "feat(shared): a sitting can hold a record's child rows as one change"
```

---

### Task 3: Calculated and imported cards fade while unlocked

**Files:**
- Create: `lib/shared/widgets/record_editing/record_card_fade.dart`
- Modify: `dive_detail_section_list.dart` and `dive_detail_section_list_content.dart` (wrap the seven, single and in pairs)
- Modify: the 11 ARB files (`recordEdit_calculated`, `recordEdit_imported`)
- Test: `test/shared/widgets/record_editing/record_card_fade_test.dart`, `test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_fade_test.dart` (new; reuse `dive_detail_section_list_harness.dart`)

**Interfaces:**
- Produces:

```dart
/// Why a card has nothing to edit.
enum RecordCardFadeReason { calculated, imported }

/// A card with nothing to edit. Locked, or with no [RecordEditScope], [child]
/// as it is. Unlocked, [child] drawn at reduced opacity with [reason]'s
/// word laid over its top right corner, so its size does not change and
/// reading interactions inside it keep working.
class RecordCardFade<T> extends StatelessWidget {
  const RecordCardFade({super.key, required this.reason, required this.child});
}
```

  The label reads `recordEdit_calculated` or `recordEdit_imported` in `labelMedium`, on the card's surface colour; opacity from the theme (`disabledColor`'s alpha or 0.6, the implementer picks one and uses it everywhere). Calculated: `decoStatus`, `tissueLoading`, `sacSegments`, `tide`, `buoyancy`. Imported: `health`, `surfaceGps`. The deco and tissue row variants in a pair each fade on their own.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('locked or without a scope: the child as it is, no label', ...);
testWidgets('unlocked: faded, the label shows, and the size is unchanged', ...);
testWidgets('a tap inside a faded card still reaches it', ...);
// section list
testWidgets('unlocked: the five calculated cards say Calculated and the two imported say Imported', ...);
testWidgets('no card moves or changes height on unlock, single and paired at 1000 px', ...);
testWidgets('editing off: no fade anywhere', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the two test files.
Expected: FAIL to compile.

- [ ] **Step 3: Add the strings, then implement**

Add both strings beside `recordEdit_hiddenCard` in all 11 ARB files, then `flutter gen-l10n`.

- [ ] **Step 4: Run and confirm they pass**

Run: the two test files, then `flutter test test/features/dive_log/presentation/widgets/dive_detail/ test/l10n/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): calculated and imported cards fade while a dive is unlocked"
```

---

### Task 4: Custom fields

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_custom_fields_card_editor.dart`
- Modify: `dive_edit_cards.dart` (the `customFields` entry)
- Modify: `dive_detail_section_list_content.dart` (the read card takes `this.dive`)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_custom_fields_card_test.dart`

**Interfaces:**
- Consumes: `CustomFieldInputRow`, `customFieldKeySuggestionsProvider`, `FieldTextBinding`.
- Produces:

```dart
/// The dive's custom fields in their order. A row with an empty key is
/// dropped when written, as the form does. Compared by id, key, value and
/// order, so a reorder is a change (call 6).
final EditField<Dive, List<DiveCustomField>> diveCustomFieldsField;   // id 'customFields'

class DiveCustomFieldsCardEditor extends StatelessWidget {
  const DiveCustomFieldsCardEditor({super.key, required this.session});
}
```

  The entry: title `diveLog_detail_section_customFields`, `isEmpty: (d) => d.customFields.isEmpty`. The editor: a reorderable list of `CustomFieldInputRow`, each row's text through the sitting, and Add, which appends a row with a fresh id and an empty key, focused. An added row left empty is no change.

- [ ] **Step 1: Write the failing tests**

```dart
test('a row with an empty key is dropped when written', ...);
test('the same rows reordered are a change; renumbered back, none', ...);
testWidgets('opening and closing leaves the sitting clean', ...);
testWidgets('add, type a key and value, Done: the read card shows it', ...);
testWidgets('an added row left empty is no change and the card goes back to the strip', ...);
testWidgets('remove a row, and a reorder by drag', ...);
testWidgets('key suggestions offer the diver\'s other keys', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_custom_fields_card_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_log/presentation/pages/dive_edit_page_coverage_test.dart test/features/dive_log/data/services/dive_edit_save_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): edit a dive's custom fields on its card"
```

---

### Task 5: Buddies and the diver's own role in the sitting

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting.dart`
- Modify: `dive_edit_cards.dart` (`startDiveSitting` loads the buddies; the key joins `diveOwnHeldWriteKeys`)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting_test.dart`

**Interfaces:**
- Consumes: `SittingList` (Task 2); `BuddyRepository.getBuddiesForDive`, `setBuddiesForDive` (`buddy_repository.dart:446`, `:651`); `LegacyBuddyConversionService.planFor`, `applyLegacyBuddyPlans` (`legacy_buddy_conversion_actions.dart`).
- Produces:

```dart
/// The dive's buddies with their roles, card 'buddies'. Compared by buddy
/// id and role ids, ignoring order. Written with setBuddiesForDive, which
/// writes only what changed.
final SittingList<Dive, BuddyWithRole> diveBuddiesList;

/// The diver's own roles on the dive, card 'buddies'.
final EditField<Dive, List<String>> diveDiverRoleIdsField;   // id 'diverRoleIds'

/// Links the legacy free-text buddies: the buddy records the plan names
/// are created at once (records of their own) and join [diveBuddiesList]
/// in the sitting. The dive's legacy text columns are left as the
/// immediate path leaves them.
Future<void> linkLegacyBuddiesInSitting(EditSession<Dive> session, {required ProviderRead read, required Future<List<ConversionPlan>?> Function(List<ConversionPlan> plans) review});
```

  Read `applyLegacyBuddyPlans` first: if it writes the dive row as well as creating buddies, split it into the part that creates buddies (kept immediate) and the part that writes the dive (held through this function), and have the immediate path call both. Name what you find in the commit.

- [ ] **Step 1: Write the failing tests**

```dart
test('buddies load as the sitting starts; untouched, Save writes none', ...);
test('a buddy added and a role changed: one held change of buddies, written once', ...);
test('the same buddies in another order are no change', ...);
test('a buddy linked on another device during the sitting is kept by a Save that removed a different one', ...);
test('my role changed is a field of the buddies card and written by updateDive', ...);
test('legacy link: the buddies are created at once, the link is held, and Cancel leaves them unlinked', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/buddies/ test/features/dive_log/data/repositories/dive_repository_diver_roles_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): a dive's buddies and own role held in a sitting"
```

---

### Task 6: The Buddies card editor and its read card

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_card_editor.dart`
- Modify: `dive_edit_cards.dart` (the `buddies` entry)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_buddies_section.dart` (shows the sitting's buddies and role)
- Modify: `lib/features/buddies/presentation/widgets/legacy_buddy_text_section.dart` (Link hidden while locked; in the open card it calls `linkLegacyBuddiesInSitting`)
- Modify: `dive_detail_section_list_content.dart` (the buddies and signatures pair reads the sitting's buddies)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_card_test.dart`

**Interfaces:**
- Consumes: Task 5; `BuddyPicker(diveId:, selectedBuddies:, keepRoleIds:, diverRoleIds:, diveOwnerId:, onDiverRoleChanged:, onChanged:)` unchanged.
- Produces: `DiveBuddiesCardEditor({required EditSession<Dive> session})`; the entry: title `diveLog_detail_section_buddies`, `isEmpty: (_) => false` (the read card decides while locked, Task 1), `isEmptyInSitting: (s) => (diveBuddiesList.current(s) ?? const []).isEmpty && s.valueOf(diveDiverRoleIdsField).isEmpty`. `keepRoleIds` is the set of role ids loaded with the sitting, so a hidden role stays offered (#401).
  - `DiveBuddiesSection` during a sitting draws `diveBuddiesList.current` and the sitting's own role; locked it is as today.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('opening and closing leaves the sitting clean', ...);
testWidgets('a buddy picked with a role, Done: the read card lists them', ...);
testWidgets('a new buddy made from the picker exists after Cancel, unlinked', ...);
testWidgets('my role set from the Me chip shows on the read card after Done', ...);
testWidgets('a dive with no buddies and no role: the card is in the strip and opens there', ...);
testWidgets('locked: the legacy Link is hidden; in the open card it links in the sitting', ...);
testWidgets('the pair with Signatures follows the sitting\'s buddies only after the editors close', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_card_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_log/presentation/widgets/dive_detail/dive_detail_buddies_section_test.dart test/features/dive_log/presentation/pages/dive_detail_text_buddy_test.dart test/features/buddies/presentation/widgets/ test/features/dive_log/presentation/pages/bulk_membership_wiring_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): edit a dive's buddies and own role on its Buddies card"
```

---

### Task 7: The sightings editor moves to a file of its own

The form's `_sightingsChild` (`dive_edit_page.dart:6116-6317`, with `_showSpeciesPicker`, `_editSighting`, `_addSuggestedSighting`) is used by the form and by bulk edit (`:2139`). The card needs the same widget, and neither may depend on the other.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/sightings_editor.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (calls it; must shrink, not grow)
- Test: `test/features/dive_log/presentation/widgets/edit_sections/sightings_editor_test.dart`

**Interfaces:**
- Produces:

```dart
/// A dive's sightings: rows with their amount, tap to edit, remove, Add
/// (the species picker) and, given [siteId], the site's suggestions.
/// Sightings added here carry an empty id until written.
class SightingsEditor extends ConsumerWidget {
  const SightingsEditor({
    super.key,
    required this.sightings,
    required this.onChanged,
    this.siteId,
    this.siteName,
    this.excludeDiveId,
  });
  final List<Sighting> sightings;
  final ValueChanged<List<Sighting>> onChanged;
  final String? siteId;        // null: no suggestions (bulk)
  final String? siteName;
  final String? excludeDiveId;
}
```

  The form passes its `_sightings` and `setState` in `onChanged`; bulk passes no site. The form's save keeps its own id rule (a sighting whose id is not among `_originalSightingIds` is added). New sightings get an empty id here; the form's temporary ids are not relied on anywhere else: check with a search before changing them.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('rows show each sighting with its amount; remove calls back without it', ...);
testWidgets('Add opens the species picker and calls back with the new sighting', ...);
testWidgets('a tap opens the edit sheet; delete there removes it', ...);
testWidgets('with a site, suggestions show and add a Seen sighting; with none, nothing', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/edit_sections/sightings_editor_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Extract, and have the form and bulk call it**

- [ ] **Step 4: Run and confirm they pass, and the form is unchanged**

Run: the Step 2 command, then `flutter test test/features/dive_log/presentation/pages/dive_edit_page_coverage_test.dart test/features/dive_log/presentation/pages/dive_edit_site_species_suggestions_test.dart test/features/dive_log/presentation/pages/bulk_dive_edit_site_test.dart test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart test/features/dive_log/presentation/widgets/pickers/`
Expected: PASS; `wc -l dive_edit_page.dart` smaller than before.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "refactor(dive-log): the sightings editor in a file of its own, for the form, bulk and the card"
```

---

### Task 8: Sightings

**Files:**
- Create: `dive_sightings_sitting.dart`, `dive_sightings_card_editor.dart` (in `editing/`)
- Modify: `dive_edit_cards.dart` (the `sightings` entry; `startDiveSitting` loads them; the key joins `diveOwnHeldWriteKeys`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_sightings_section.dart` (draws the sitting's list once changed)
- Test: `dive_sightings_sitting_test.dart`, `dive_sightings_card_test.dart` (in `test/.../editing/`)

**Interfaces:**
- Consumes: Tasks 2 and 7; `SpeciesRepository.getSightingsForDive`, `addSighting`, `updateSighting`, `deleteSighting`.
- Produces:

```dart
/// The dive's sightings, card 'sightings'. Written as the form's save does
/// (`dive_edit_page.dart:6717`): loaded ids missing now are deleted, kept
/// ones updated when changed, ones with an empty id added.
final SittingList<Dive, Sighting> diveSightingsList;

class DiveSightingsCardEditor extends ConsumerWidget {
  const DiveSightingsCardEditor({super.key, required this.session});
}
```

  The editor is `SightingsEditor` over `diveSightingsList`, with `siteId` and `siteName` from `session.working.site` and `excludeDiveId: session.stored.id`. The entry: title `diveLog_detail_section_marineLife`, `isEmpty: (_) => false`, `isEmptyInSitting` when `current` is empty. The read card in a sitting draws `current` with the species' photo counts as stored; a sighting not yet written has no photos.

- [ ] **Step 1: Write the failing tests**

```dart
test('untouched: nothing written; a sighting added, one changed and one removed: written once each', ...);
test('a sighting added on another device during the sitting survives a Save that removed another', ...);
testWidgets('opening and closing leaves the sitting clean', ...);
testWidgets('a species picked with an amount, Done: the read card shows it', ...);
testWidgets('suggestions follow a site picked on the header in the same sitting', ...);
testWidgets('a species created from the picker exists after Cancel', ...);
testWidgets('no sightings: the card is in the strip', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the two test files.
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the two test files, then `flutter test test/features/marine_life/ test/features/dive_log/presentation/widgets/dive_sighting_row_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): edit a dive's sightings on its card"
```

---

### Task 9: Signatures

**Files:**
- Create: `dive_signatures_sitting.dart`, `dive_signatures_card_editor.dart` (in `editing/`)
- Modify: `dive_edit_cards.dart` (the `signatures` entry; loaded at start; key joins `diveOwnHeldWriteKeys`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_signature_section.dart` (`_TrainingSignatureCard` capture and delete hidden while locked; the read card draws held signatures)
- Modify: `lib/features/signatures/presentation/widgets/buddy_signatures_section.dart`, `buddy_signature_card.dart` (Request hidden while locked; `onCaptured` may be passed in)
- Test: `dive_signatures_sitting_test.dart`, `dive_signatures_card_test.dart` (in `test/.../editing/`)

**Interfaces:**
- Consumes: Tasks 2 and 5 (`diveBuddiesList` for who may sign); `SignatureStorageService.strokesToPng`, `saveSignature`, `saveBuddySignature`, `deleteSignature`, `getAllSignaturesForDive`; `showSignatureCaptureSheet`, `showBuddySignatureRequestSheet`.
- Produces:

```dart
/// A signature in a sitting: one stored, or one captured and not yet
/// written (an empty id, with its PNG bytes).
@immutable
class HeldSignature {
  final String id;                 // '' until written
  final Uint8List imageBytes;
  final String signerName;
  final String? signerId;          // instructor id, or the buddy's id
  final String? buddyRole;         // null: the training signature
}

/// Card 'signatures'. Written after the buddies: deleted, then captured
/// ones saved. A buddy signature whose buddy is no longer on the dive is
/// not written.
final SittingList<Dive, HeldSignature> diveSignaturesList;
```

  The entry: title `DiveDetailSectionId.signatures.localizedDisplayName`, `isEmpty: (_) => false`, `isEmptyInSitting` when no signature is held and the sitting has neither a buddy nor a course, `offeredWhenEmpty` false in that same case (call 5). The editor: the training signature (capture, or delete the one there) while the sitting has a course, and one request row per buddy in `diveBuddiesList.current`. Capturing renders the strokes with `strokesToPng` at once, so the bytes are what is shown and what Save writes. Read `saveBuddySignature` first: it writes a `media` row naming the buddy, and if it needs no `dive_buddies` row the order of the buddies and signatures writes does not matter. If it does need one, the signatures write reads the buddies the save writes and runs after them; say which in the code.

- [ ] **Step 1: Write the failing tests**

```dart
test('a captured signature is written at Save with its bytes; Cancel writes nothing', ...);
test('a deleted signature is deleted at Save', ...);
test('a buddy added in the sitting can sign, and is written before the signature', ...);
test('a buddy removed after signing: the signature is not written', ...);
testWidgets('locked: no capture, no delete, no Request', ...);
testWidgets('in the open card: capture shows the signature at once', ...);
testWidgets('no buddy and no course: not in the strip; a buddy added: offered', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the two test files.
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the two test files, then `flutter test test/features/signatures/ test/features/dive_log/presentation/widgets/dive_detail/dive_detail_signature_section_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): capture and delete signatures in a sitting, written at Save"
```

---

### Task 10: Annotations held in a sitting

An annotation is a `ProfileEvent` row in `dive_profile_events` and a `[words](annotation:id)` link in the notes. The form holds new ones as `PendingAnnotation`s and calls `AnnotationRepository.reconcile` at save (`dive_edit_page_annotations.dart:42`).

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_annotations_sitting.dart`
- Modify: `dive_edit_cards.dart` (loaded at start; key joins `diveOwnHeldWriteKeys`)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_annotations_sitting_test.dart`

**Interfaces:**
- Consumes: `diveNotesField`; `annotationLinkMarkdown`, `unlinkAnnotation`, `annotationIdsInNotes`, `annotationTimeCap`, `dropOrphanAnnotations` (`annotation_links.dart`); `AnnotationRepository.annotationsForDive`, `reconcile`, `moveAnnotation`; `gasSwitchTimeLimits` (plan 5).
- Produces:

```dart
const String annotationsKey = 'annotations';            // the change of 'profile'
const String annotationsWriteKey = 'annotationsWrite';  // the write, held at load

/// What a sitting holds for the dive's annotations.
@immutable
class SittingAnnotations {
  final List<ProfileEvent> loaded;
  final List<PendingAnnotation> placed;                 // new in this sitting
  final Map<String, ({int timestamp, double? depth})> moved;   // stored ids
  final Set<String> removed;                            // stored ids
}

SittingAnnotations? sittingAnnotations(EditSession<Dive> session);

/// The annotations as the sitting has them: loaded and placed, moved where
/// moved, and only those the sitting's notes still link.
List<ProfileEvent> sittingAnnotationEvents(EditSession<Dive> session);

void loadDiveAnnotations(EditSession<Dive> session, ProviderRead read);

/// Places one: appends its linked line to the notes (diveNotesField) and
/// holds it as placed. Returns its id.
String placeAnnotation(EditSession<Dive> session, {required int seconds, double? depth, required String words});

/// For a pin placed from the notes editor, whose link the editor writes
/// itself: holds it as placed, nothing more.
void holdNotesPin(EditSession<Dive> session, PendingAnnotation pin);

void moveSittingAnnotation(EditSession<Dive> session, String id, {required int seconds, double? depth});

/// Unlinks its words in the notes; a placed one is dropped, a stored one
/// goes at Save with its link.
void removeSittingAnnotation(EditSession<Dive> session, String id);

/// The earliest and latest second an annotation may fall on: 0, and
/// `annotationTimeCap` over `gasSwitchTimeLimits(session).max`.
({int min, int max}) annotationTimeLimits(EditSession<Dive> session);
```

  Two held entries. The write, under `annotationsWriteKey`, is held with `holdWrite` as the annotations load (so it makes nothing dirty) and runs after the dive: when the sitting's notes differ from the stored notes, or anything is placed, moved or removed, it calls `reconcile(diveId:, notes: <the notes as written>, create: <placed still linked>)` and then `moveAnnotation` for each moved id still linked; otherwise it does nothing. So a link deleted from the notes text deletes its row (difference 2) with no annotation change held. The change, under `annotationsKey`, is a `holdChange` of `'profile'` with a write that does nothing, held while `placed`, `moved` or `removed` is not empty and released when all are, so Profile carries its dot and the History label names it. A placed annotation whose words were cut from the notes again is dropped from `placed`.

- [ ] **Step 1: Write the failing tests**

```dart
test('placing appends a linked line to the notes and holds one placed: Notes and Profile both changed', ...);
test('placed then removed: the notes are as stored and nothing is held', ...);
test('placed, then its line deleted in the notes: nothing is written', () async { /* test database */ });
test('a stored annotation moved: moveAnnotation at Save; moved back: no change', ...);
test('a stored annotation removed: its words stay in the notes as plain text and its row goes at Save', ...);
test('notes edited to drop a link, nothing else: Save deletes that row', ...);
test('limits: the profile end, else the runtime, capped as today', ...);
test('loads once per sitting; a read answering after Cancel sets nothing', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_annotations_sitting_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_log/data/repositories/annotation_repository_test.dart test/features/dive_log/domain/services/annotation_links_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): annotations placed, moved and removed in a sitting, settled with the notes at Save"
```

---

### Task 11: The profile's annotation actions write where they are told, or not at all

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/annotation_edits.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_annotation_actions.dart`
- Modify: `lib/features/dive_log/presentation/widgets/annotation_marker_popup.dart` (or wherever `showAnnotationMarkerPopup` lives: write actions omitted when read-only)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart_host.dart` (`onSafetyFindingDismiss` null with the switch on, call 1)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/dive_detail_annotation_actions_test.dart` (add cases), `annotation_marker_popup_test.dart` (add cases)

**Interfaces:**
- Produces:

```dart
/// Where the profile's annotation actions write.
abstract interface class AnnotationEdits {
  Future<void> add({required int seconds, double? depth, required String words});
  Future<void> move(String id, {required int seconds, double? depth});
  Future<void> remove(String id);
  int maxSeconds(int fallback);
}

/// Today's: straight to the repository.
class RepositoryAnnotationEdits implements AnnotationEdits { const RepositoryAnnotationEdits(this.repository, this.diveId); }

/// A sitting's (Task 10).
class SittingAnnotationEdits implements AnnotationEdits { const SittingAnnotationEdits(this.session); }

// DiveDetailAnnotationActions gains
final AnnotationEdits? edits;   // null: read only. No pin, no placement, no secondary-tap menu; the popup offers Open in Notes alone
```

  Callers pass `RepositoryAnnotationEdits` when `kUnlockEditing` is false, so nothing changes with the switch off. The Notes card's fallback (`_scrollToProfileAndFocus`, `dive_detail_page.dart:246`) calls `editTime` only when it has edits; read only, it scrolls to the profile and highlights, as for a dive with a profile.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('read only: no pin, a tap on the chart places nothing, the popup has only Open in Notes', ...);
testWidgets('sitting edits: add, move and remove reach the sitting, not the repository', ...);
testWidgets('repository edits: as today', ...);
testWidgets('with the switch on, the chart callout offers no Dismiss', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the two test files.
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the two test files, then `flutter test test/features/dive_log/presentation/widgets/dive_detail/dive_detail_annotation_flow_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_annotations_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_placement_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): the profile's annotation actions write to a sitting, or read only"
```

---

### Task 12: The Profile card editor, and pins from the notes

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_profile_card_editor.dart`
- Modify: `dive_edit_cards.dart` (the `profile` entry)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart` (gains `editing: EditSession<Dive>?`; draws `sittingAnnotationEvents` and the sitting's gas switches during a sitting; read only while locked and while closed)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` only if the pinned copy needs a flag (`readOnly: true`); keep at 783 or below
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_notes_card_editor.dart` (`onAnnotate`)
- Test: `dive_profile_card_test.dart`, `dive_notes_card_editor_test.dart` (both new, in `test/.../editing/`)

**Interfaces:**
- Consumes: Tasks 10 and 11; `sittingGasSwitches` and `diveTanksField` (plan 5) mapped to the chart's `GasSwitchWithTank`; `showAnnotationTimeSheet`.
- Produces:
  - The entry: title `diveLog_detail_section_diveProfile`, `isEmpty: (_) => false` (the profile or its estimated outline is always on the page), `offeredWhenEmpty: (_) => false`.
  - `DiveProfileCardEditor({required EditSession<Dive> session})`: the profile section with `editing: session` and `SittingAnnotationEdits`, so the open card is the chart with its pin, placement and popup actions live. The fullscreen button stays in it (Task 13).
  - During a sitting, the closed card and the pinned copy draw `sittingAnnotationEvents` and the sitting's switches, read only (call 2).
  - The Notes editor's `onAnnotate(words)`: opens `showAnnotationTimeSheet` with `annotationTimeLimits(session).max` and the stored profile, then `holdNotesPin` and returns `(id:, words:)` as the form's `_requestAnnotation` does.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('locked and closed: no pin, nothing placed by a tap', ...);
testWidgets('open: a pin placed shows on the chart; Profile and Notes get their dots', ...);
testWidgets('open: a marker moved and one removed; Done keeps them on the closed card', ...);
testWidgets('a runtime shortened on the header bounds the time sheet', ...);
testWidgets('a pin from the notes editor joins the profile after Done', ...);
testWidgets('the sitting\'s gas switches show on the closed card during a sitting', ...);
testWidgets('the card does not change height on unlock', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the two test files.
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the two test files, then `flutter test test/features/dive_log/presentation/widgets/dive_detail/dive_notes_section_annotations_test.dart test/features/dive_log/presentation/pages/dive_detail_fullscreen_root_nav_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): place, move and remove annotations on the open Profile card and from the notes"
```

---

### Task 13: The fullscreen profile obeys the sitting

`FullscreenProfilePage` is pushed on the root navigator (`dive_detail_profile_section.dart:241`), outside the page's `RecordEditScope`, so it is handed what it needs.

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart`
- Modify: `dive_detail_profile_section.dart` (`_showFullscreenProfile` passes the open card's session)
- Modify: `lib/features/dashboard/presentation/widgets/recent_dive_profile_preview.dart` (read only with the switch on)
- Test: `test/features/dive_log/presentation/pages/fullscreen_profile_sitting_test.dart` (new)

**Interfaces:**
- Produces: `FullscreenProfilePage` gains

```dart
/// The sitting it edits, when opened from the open Profile card. Null with
/// [readOnly] false: as today, writing at once (the switch off).
final EditSession<Dive>? session;

/// Shows no control that writes: no pin, no placement, no Dismiss, the
/// popup with Open in Notes alone.
final bool readOnly;
```

  With a session it draws `sittingAnnotationEvents` and the sitting's gas switches, and its annotation actions use `SittingAnnotationEdits`. The dive page passes the session only when the Profile card is open; otherwise `readOnly: kUnlockEditing` (Eric's choice). The dashboard passes `readOnly: kUnlockEditing`. A sitting that ends while the page is open (the dive deleted elsewhere) writes nothing more: every write checks `session.isDisposed` and `isFrozen` first, and the page draws read only from its next build once the session is disposed.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('opened from the open card: a pin placed reaches the sitting; back on the page Profile has its dot', ...);
testWidgets('opened from the closed card in a sitting: read only', ...);
testWidgets('opened from a locked page: read only', ...);
testWidgets('from the dashboard with the switch on: read only', ...);
testWidgets('the sitting\'s gas switches and moved annotations are drawn', ...);
testWidgets('switch off: as today', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/pages/fullscreen_profile_sitting_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart test/features/dive_log/presentation/pages/fullscreen_profile_annotations_test.dart test/features/dashboard/presentation/widgets/recent_dive_profile_preview_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): the fullscreen profile edits a sitting only from the open Profile card"
```

---

### Task 14: Safety review dismissals

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_safety_sitting.dart`
- Modify: `lib/features/dive_log/presentation/widgets/safety_review_section.dart` (gains `editing: EditSession<Dive>?`: dismiss, restore and the bulk footer reach the sitting; with a scope and no open card, none shows)
- Modify: `dive_edit_cards.dart` (the `safetyReview` entry; key joins `diveOwnHeldWriteKeys`)
- Test: `dive_safety_sitting_test.dart` (in `test/.../editing/`), `test/features/dive_log/presentation/widgets/safety_review_section_test.dart` (add cases)

**Interfaces:**
- Consumes: `safetyReviewProvider`, `SafetyFindingsRepository.setDismissed`, `hasVisibleSafetyFindings`.
- Produces:

```dart
const String safetyDismissalsKey = 'safetyDismissals';

/// Whether each finding the diver touched is dismissed, by id.
Map<String, bool> sittingDismissals(EditSession<Dive> session);

/// Sets one. Back to its stored state, it is dropped; none left, the held
/// change is released. Written at Save for findings that still exist.
void setFindingDismissed(EditSession<Dive> session, SafetyFinding finding, {required bool dismissed});
void setAllFindingsDismissed(EditSession<Dive> session, List<SafetyFinding> findings, {required bool dismissed});

/// [review] with the sitting's dismissals laid over it, for every reader
/// during a sitting: the card, the chart's callouts, the fullscreen page.
SafetyReview reviewInSitting(EditSession<Dive> session, SafetyReview review);
```

  The entry: title `safetyReview_sectionTitle`, `isEmpty: (_) => false` (the section decides for itself, as now), `offeredWhenEmpty: (_) => false`. The editor is `SafetyReviewSection(editing: session)` with "Show dismissed" as today. A review recomputed during the sitting keeps finding ids for findings that still fire (`saveReview`): a held dismissal of a finding that stopped firing is skipped at Save.

- [ ] **Step 1: Write the failing tests**

```dart
test('a finding dismissed and restored again is no change', ...);
test('dismissed in the sitting: written at Save with setDismissed; Cancel writes nothing', ...);
test('a finding that stopped firing before Save is skipped', ...);
testWidgets('locked: no dismiss, no restore, no Dismiss all', ...);
testWidgets('open: Dismiss all holds every visible finding; Done shows them dismissed', ...);
testWidgets('the chart callout reads the sitting\'s dismissals', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the two test files.
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the two test files, then `flutter test test/features/dive_log/presentation/widgets/dive_safety_summary_section_test.dart test/features/dive_log/presentation/providers/safety_review_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): dismiss and restore safety findings in a sitting, written at Save"
```

---

### Task 15: Underwater track links

**Files:**
- Modify: `lib/features/nav_track/domain/dive_route_link_draft.dart` (gains a primary)
- Modify: `lib/features/nav_track/application/dive_route_link_applier.dart` (sets it)
- Create: `dive_route_links_sitting.dart`, `dive_nav_track_card_editor.dart` (in `editing/`)
- Modify: `lib/features/nav_track/presentation/widgets/nav_track_section.dart` (row menu: Unlink and Set primary only in the open card, into the sitting; Open and 3D always)
- Modify: `dive_edit_cards.dart` (the `navTrack` entry; loaded at start; key joins `diveOwnHeldWriteKeys`)
- Modify: `dive_detail_section_list_content.dart` (the card's presence through `diveCardIsOnPage`)
- Test: `test/features/nav_track/domain/dive_route_link_draft_test.dart`, `test/features/nav_track/application/dive_route_link_applier_test.dart` (add cases), `dive_nav_track_card_test.dart` (in `test/.../editing/`)

**Interfaces:**
- Consumes: `DiveRouteLinkDraft.initial`, `.add`, `.remove`, `.updated`, `hasChanges`; `applyDiveRouteLinkDraft`; `showRouteLinkSheet`, `RouteRow`; `navTracksForDiveProvider`; `NavTrackRepository.setPrimary`.
- Produces:

```dart
// DiveRouteLinkDraft gains
final String? primaryId;                    // null: as linked
DiveRouteLinkDraft withPrimary(String routeId);
// hasChanges counts a primary that differs from the original's

// applyDiveRouteLinkDraft: after linking, setPrimary(primaryId) when set and still linked

// dive_route_links_sitting.dart
const String routeLinksKey = 'routeLinks';
DiveRouteLinkDraft? sittingRouteDraft(EditSession<Dive> session);
void loadDiveRouteLinks(EditSession<Dive> session, ProviderRead read);
void setRouteDraft(EditSession<Dive> session, DiveRouteLinkDraft next);   // no changes: released
```

  The held write applies the draft unless `session.working.isPlanned` (plan 4's note); a skipped id is logged, as the form shows a snackbar (the follow-up shows it, Task 22). A route imported from a file in the sheet is created at once, unlinked, as today. The entry: title `DiveDetailSectionId.navTrack.localizedDisplayName`, `isEmpty: (_) => false`, `isEmptyInSitting` when the draft links none, `offeredWhenEmpty: (s) => !s.working.isPlanned`. The editor: `RouteRow` and the sheet over the sitting's draft, nothing for a planned dive.

- [ ] **Step 1: Write the failing tests**

```dart
test('withPrimary is a change; back to the original, none', ...);
test('the applier sets the primary after linking', ...);
test('a route unlinked and another made primary: written at Save; Cancel writes nothing', ...);
test('a planned dive: the held draft is not written', ...);
testWidgets('locked: the row menu offers Open and 3D only', ...);
testWidgets('open: link a route from the sheet; Done lists it', ...);
testWidgets('no routes: in the strip, except for a planned dive', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the three test files.
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the three test files, then `flutter test test/features/nav_track/ test/features/dive_log/presentation/pages/dive_edit_route_links_test.dart test/features/dive_log/presentation/pages/dive_nav_track_section_visibility_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): link, unlink and pick the primary route in a sitting"
```

---

### Task 16: The Compare card's plan link

**Files:**
- Modify: `lib/features/planner/presentation/plan_link_actions.dart` (the confirm split from the write)
- Create: `dive_plan_link_sitting.dart` (in `editing/`)
- Modify: `lib/features/dive_lab/presentation/widgets/compare_section.dart` (gains `editing: EditSession<Dive>?`; Link and Unlink only in the open card; draws the sitting's plan)
- Modify: `lib/features/dive_lab/presentation/pages/dive_lab_page.dart` (Link and Unlink menu items hidden with the switch on)
- Modify: `dive_edit_cards.dart` (the `diveLab` entry; loaded at start; key joins `diveOwnHeldWriteKeys`)
- Test: `test/features/planner/presentation/plan_link_actions_test.dart` (add cases), `dive_plan_link_sitting_test.dart`, `dive_compare_card_test.dart` (in `test/.../editing/`)

**Interfaces:**
- Consumes: `pickPlanAndLink`'s sheet (`LinkPlanSheet`), `DivePlanRepository.getPlanByLinkedDiveId`, `linkPlanToDive`, `unlinkPlan`, `linkedPlanComparisonProvider`, `isDiveLabEligible`.
- Produces:

```dart
// plan_link_actions.dart gains
/// Asks what linkPlanWithConfirm asks (move from another dive, replace this
/// dive's plan), and writes nothing. True to go ahead.
Future<bool> confirmPlanLink(BuildContext context, WidgetRef ref, {required String planId, required String diveId});
// linkPlanWithConfirm calls it, then writes, as today.

// dive_plan_link_sitting.dart
const String planLinkKey = 'planLink';
/// The plan linked in the sitting: null for none. Unloaded: absent.
({String? planId})? sittingPlanLink(EditSession<Dive> session);
void loadDivePlanLink(EditSession<Dive> session, ProviderRead read);
void setPlanLink(EditSession<Dive> session, String? planId);   // the stored one: released
```

  At Save: `linkPlanToDive(planId, diveId)` for a plan, `unlinkPlan(storedPlanId)` for none. The follow-up adopts the link in `divePlanNotifierProvider` as `linkPlanWithConfirm` does (Task 22). The entry: title `DiveDetailSectionId.diveLab.localizedDisplayName`, `isEmpty: (_) => false` (the card decides), `offeredWhenEmpty: (_) => false`. "Ask a what-if" and the saved what-ifs work while locked (call 10).

- [ ] **Step 1: Write the failing tests**

```dart
test('confirmPlanLink asks and writes nothing', ...);
test('a plan linked in the sitting: written at Save; Cancel leaves the old link', ...);
test('unlinked in the sitting: unlinkPlan at Save; linked back: no change', ...);
testWidgets('locked: no Link button; Ask a what-if still opens the lab', ...);
testWidgets('open: Link asks the confirm, then the card shows the plan', ...);
testWidgets('with the switch on, the lab page offers no Link or Unlink', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the three test files.
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the three test files, then `flutter test test/features/dive_lab/ test/features/planner/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): link and unlink a plan on the Compare card in a sitting"
```

---

### Task 17: Documents

**Files:**
- Modify: `lib/features/documents/data/repositories/document_repository.dart` (`setDiveOwner`, public, over `_setOwners`)
- Modify: `lib/features/documents/presentation/pages/document_edit_page.dart` (gains `ownerFixed`)
- Create: `dive_document_links_sitting.dart`, `dive_documents_card_editor.dart` (in `editing/`)
- Modify: `lib/features/documents/presentation/widgets/documents_section.dart` (gains `editing: EditSession<Dive>?`; Add only in the open card; draws the sitting's documents)
- Modify: `dive_edit_cards.dart` (the `documents` entry; key joins `diveOwnHeldWriteKeys`)
- Test: `test/features/documents/data/repositories/document_repository_test.dart` (add a group), `test/features/documents/presentation/pages/document_edit_page_test.dart` (one case), `dive_documents_card_test.dart` (in `test/.../editing/`)

**Interfaces:**
- Produces:

```dart
// DocumentRepository gains
/// Files each of [documentIds] under the dive [diveId], or as Personal for
/// null, marking each pending. Opens no transaction of its own beyond the
/// one it nests in.
Future<void> setDiveOwner(List<String> documentIds, String? diveId);

// DocumentEditPage gains
/// The owner it starts with is the one it saves with: the owner picker is
/// not shown.
final bool ownerFixed;

// dive_document_links_sitting.dart
const String documentLinksKey = 'documentLinks';
({Set<String> attach, Set<String> detach}) sittingDocumentLinks(EditSession<Dive> session);
void attachDocument(EditSession<Dive> session, String documentId);
void detachDocument(EditSession<Dive> session, String documentId);   // attached in the sitting: dropped
```

  In the open card, Add pushes `DocumentEditPage(owner: const DocumentOwner.personal(), ownerFixed: true, onSaved: (id) => attachDocument(session, id))`, through the same route the card uses, with the route's query parameters for both (call 11). Each row gains Remove, held. The card in a sitting draws the stored documents minus detached plus attached (read by id through `documentsForOwnerProvider` for the dive and the document repository for the attached ones). The entry: title `documents_section_title`, `isEmpty: (_) => false`, `isEmptyInSitting` when the sitting has no document, offered when empty.

- [ ] **Step 1: Write the failing tests**

```dart
test('setDiveOwner files documents under a dive and back to Personal', ...);
testWidgets('ownerFixed hides the owner picker and saves with the owner given', ...);
testWidgets('locked: no Add, no Remove; a tap still opens the document', ...);
testWidgets('open: a new document is created at once as Personal and joins the dive at Save', ...);
testWidgets('Cancel: the new document stays Personal in the library', ...);
testWidgets('Remove detaches at Save; the document stays in the library', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the three test files.
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the three test files, then `flutter test test/features/documents/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): attach and detach documents on the Documents card in a sitting"
```

---

### Task 18: Media held in a sitting

**Files:**
- Create: `lib/features/media/domain/value_objects/media_hold.dart`
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_media_sitting.dart`
- Modify: `lib/features/media/data/services/media_import_service.dart` (`mediaItemsForAssets`, building what `importPhotosForDive` writes, without writing)
- Modify: `lib/features/media/data/services/repair/media_repair_service.dart` (the queue stage separable: `applyInTransaction` returning its after-commit work)
- Test: `test/features/media/data/services/media_import_service_test.dart` (one group), `test/features/media/data/repair/media_repair_service_test.dart` (one group), `dive_media_sitting_test.dart` (in `test/.../editing/`)

**Interfaces:**
- Produces:

```dart
// media_hold.dart
/// What a picker hands a sitting in place of writing.
sealed class HeldMediaAdd { const HeldMediaAdd(); }
/// A row built as the picker would write it, with a fresh id so it can be
/// shown and keyed; its enrichment, worked out at Save.
final class HeldMediaRow extends HeldMediaAdd { final MediaItem item; }
/// Fetched network media, inserted at Save by the pipeline.
final class HeldNetworkMedia extends HeldMediaAdd { final NetworkInsertRequest request; final MediaItem preview; }

typedef MediaHoldSink = void Function(List<HeldMediaAdd> adds);

// MediaImportService gains
Future<List<MediaItem>> mediaItemsForAssets({required List<AssetInfo> selectedAssets, required Dive dive});   // duplicates skipped as importPhotosForDive skips them

// dive_media_sitting.dart
const String mediaKey = 'media';
@immutable
class SittingMedia {
  final List<HeldMediaAdd> added;
  final Set<String> unlinked;                      // stored media ids
  final Map<String, RepairProposal> replaced;      // stored media id -> proposal
}
SittingMedia sittingMedia(EditSession<Dive> session);
void addMediaToSitting(EditSession<Dive> session, List<HeldMediaAdd> adds);
void unlinkMediaInSitting(EditSession<Dive> session, Set<String> ids);   // added ones are dropped
void replaceLinkInSitting(EditSession<Dive> session, String id, RepairProposal proposal);

/// [stored] as the sitting has it: unlinked gone, replaced shown replaced,
/// added after, in taken-at order as the grid orders.
List<MediaItem> mediaInSitting(EditSession<Dive> session, List<MediaItem> stored);

/// What must happen after the write commits: uploads queued for the rows
/// written, remote copies of deleted rows marked for deletion, caches
/// cleared, the repair stage C. Filled by the held write; run by Task 22.
List<Future<void> Function()> mediaAfterCommit(EditSession<Dive> session);
```

  The held write, card `'media'`, after the dive: `createMedia` and `saveEnrichment` for each `HeldMediaRow` (as `importPhotosForDive` does), `insertResolved` for the network ones, then the unlinks as `MediaUnlinkService.unlinkFromDive` splits them (kept rows `unlinkFromDive`, the rest `MediaRepository.deleteMultipleMedia` without the coordinator's queue and cache work), then `applyInTransaction` for each replaced link. Every after-commit step it owes goes into `mediaAfterCommit`. A save that fails leaves `mediaAfterCommit` empty.

- [ ] **Step 1: Write the failing tests**

```dart
test('mediaItemsForAssets builds the rows importPhotosForDive writes, and writes none', ...);
test('applyInTransaction writes the repair and returns its queue work unrun', ...);
test('an added photo and an unlinked one: written at Save, after-commit work listed; Cancel writes nothing', () async { /* test database */ });
test('a photo added then unlinked in the sitting: nothing held', ...);
test('mediaInSitting: unlinked gone, added shown, a photo synced in meanwhile kept', ...);
test('a failing write leaves no media row and no after-commit work', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the three test files.
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the three test files, then `flutter test test/features/media/data/ test/features/media_store/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): photos added, unlinked and relinked in a sitting, written at Save"
```

---

### Task 19: The photo picker hands a sitting what it would write

**Files:**
- Modify: `lib/features/media/presentation/pages/photo_picker_page.dart` (`showPhotoPicker` gains `onHold`)
- Modify: `lib/features/media/presentation/providers/files_tab_providers.dart` (`_persistOne` split into building the row and writing it; `heldRows` for one dive)
- Modify: `lib/features/media/presentation/widgets/files_tab.dart` (with a sink: hand over, no Undo snackbar, the left-out line)
- Modify: `lib/features/media/presentation/widgets/url_tab.dart`, `url_tab_providers.dart` (with a sink: hand over the resolved requests, no Undo)
- Modify: `lib/features/media/presentation/helpers/photo_import_helper.dart` (`importPhotosForDive` gains `onHold`; the gallery path builds with `mediaItemsForAssets`)
- Modify: the 11 ARB files (`media_picker_otherDivesLeftOut`)
- Test: `test/features/media/presentation/providers/files_tab_providers_test.dart`, `url_tab_providers_test.dart` (add groups), `test/features/media/presentation/helpers/photo_import_helper_test.dart` (new)

**Interfaces:**
- Consumes: Task 18.
- Produces:

```dart
// showPhotoPicker and PhotoImportHelper.importPhotosForDive gain
MediaHoldSink? onHold,   // null: as today, writing at once

// FilesTabNotifier gains
/// The rows commit would write for [diveId] only, built and not written,
/// and how many staged files matched another dive and were left out.
Future<({List<MediaItem> rows, int leftOut})> heldRows(String diveId);
```

  With a sink every tab writes nothing: the gallery's assets become `HeldMediaRow`s, the Files tab's matched files for this dive become `HeldMediaRow`s (the rest counted in `media_picker_otherDivesLeftOut`), the URL tab's resolved requests become `HeldNetworkMedia` (the fetch runs at once, so a bad link is reported then; Eric's choice). `offerSiteReviewAfterImport` is not offered from a sitting. Scan gallery (`_scanGalleryForDive`) takes the same sink.

- [ ] **Step 1: Write the failing tests**

```dart
test('heldRows builds this dive\'s rows, writes none, and counts the others', ...);
test('with a sink, the URL tab hands over resolved requests and inserts nothing', ...);
testWidgets('with a sink, the gallery hands over rows and writes none', ...);
testWidgets('with a sink, the Files tab shows how many files were left out', ...);
testWidgets('with no sink, every tab writes as today', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the three test files.
Expected: FAIL.

- [ ] **Step 3: Add the string, then implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the three test files, then `flutter test test/features/media/presentation/ test/l10n/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(media): the photo picker can hand a sitting what it would write"
```

---

### Task 20: The Media card editor

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_media_card_editor.dart`
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart` (gains `editing: EditSession<Dive>?` and `readOnly`; split first if it would pass 800 lines)
- Modify: `lib/features/media/presentation/helpers/document_open_helper.dart` (`pickAndAttach` gains `onHold`)
- Modify: `lib/features/media/presentation/helpers/media_link_replacer.dart` (`replaceMediaLink` gains `onHold: void Function(RepairProposal)?`)
- Modify: `dive_edit_cards.dart` (the `media` entry; key joins `diveOwnHeldWriteKeys`)
- Modify: `dive_detail_section_list_content.dart` (the media case passes the scope's state)
- Test: `dive_media_card_test.dart` (in `test/.../editing/`), `test/features/media/presentation/widgets/dive_media_section_test.dart` (add cases)

**Interfaces:**
- Consumes: Tasks 18 and 19.
- Produces: `DiveMediaCardEditor({required EditSession<Dive> session})`: the grid of `mediaInSitting`, with Add photos, Scan gallery, Add document (a media document), selection and Unlink, and Replace link on a local file, each into the sitting. The entry: title `media_diveMediaSection_title`, `isEmpty: (_) => false`, `isEmptyInSitting` when `mediaInSitting` is empty, offered when empty. `DiveMediaSection` locked (`readOnly`): no add menu, no scan, no selection mode, no Replace link; a tap still opens the photo viewer or the document, Show in Finder still works. During a sitting the closed card draws `mediaInSitting`. The enrichment backfill on build keeps running (derived data, outside the rule).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('locked: no add, scan, select or replace; a tap opens the viewer', ...);
testWidgets('open: photos from the picker show as tiles at once; nothing is written', ...);
testWidgets('open: two selected and unlinked are gone from the grid; Done keeps them gone', ...);
testWidgets('a media document added from the menu shows in the grid, held', ...);
testWidgets('Replace link held: the tile shows the new file; Save writes the repair', ...);
testWidgets('no media: the card is in the strip and opens there', ...);
testWidgets('switch off: the card as today', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the two test files.
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the two test files, then `flutter test test/features/media/presentation/widgets/ test/features/media/presentation/helpers/ test/features/dive_log/presentation/pages/dive_detail_media_hover_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): add, unlink and relink a dive's photos on its Media card"
```

---

### Task 21: Files dropped on a dive go through the sitting

**Files:**
- Create: `lib/features/dive_log/presentation/providers/open_dive_sitting_provider.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart` (sets and clears it)
- Modify: `lib/features/media/presentation/helpers/media_drop_import.dart` (`importDroppedMedia`)
- Modify: the 11 ARB files (`diveLog_media_dropUnlockHint`)
- Test: `test/features/media/presentation/helpers/media_drop_import_test.dart` (new), `test/shared/widgets/global_drop_target_test.dart` (add cases)

**Interfaces:**
- Produces:

```dart
/// The sitting the dive page has open, with how to show the Media card for
/// a drop, or null. Set by the page that offers editing while it is
/// unlocked; cleared when it locks or goes.
final openDiveSittingProvider = StateProvider<OpenDiveSitting?>((ref) => null);

@immutable
class OpenDiveSitting {
  final String diveId;
  final EditSession<Dive> session;
  /// Opens the Media card where it is, or adds it from the strip.
  final VoidCallback showMediaCard;
}
```

  `importDroppedMedia`, for a `DiveAttachTarget` with `kUnlockEditing` on: when `openDiveSittingProvider` names that dive and its session is neither frozen nor disposed, calls `showMediaCard`, then `PhotoImportHelper.importPhotosForDive(initialFilePaths:, onHold: (adds) => addMediaToSitting(session, adds))`; otherwise shows `diveLog_media_dropUnlockHint` in a snackbar and does nothing else (the page and the list pane alike; Eric's choice). Drops the target already refuses (wizard or picker open) are refused as today. Non-media drops (dive logs, routes, buddy cards) are unchanged: they create records. With the switch off, as today.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('a locked dive page: the hint, and no picker', ...);
testWidgets('the list pane with the switch on: the hint', ...);
testWidgets('in a sitting: the Media card opens and the picker shows the files staged; nothing is written', ...);
testWidgets('a sitting being saved: the hint', ...);
testWidgets('a dive log dropped on a locked dive still opens the import wizard', ...);
testWidgets('switch off: as today', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the two test files.
Expected: FAIL.

- [ ] **Step 3: Add the string, then implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the two test files, then `flutter test test/features/media/presentation/helpers/media_drop_destination_test.dart test/features/media/presentation/pages/photo_picker_page_dropped_files_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): a file dropped on a dive is held in its sitting, and refused while locked"
```

---

### Task 22: After the write: refreshes, uploads and messages

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_sitting_follow_up.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart` (`_saveSitting` reads `mediaAfterCommit` and the skipped route ids before the session ends)
- Test: `test/features/dive_log/presentation/pages/dive_sitting_follow_up_test.dart` (new: no file tests the follow-up on its own yet)

**Interfaces:**
- Produces: `DiveSittingFollowUp.run` gains `required List<Future<void> Function()> mediaAfterCommit` and runs, each in its own guarded step, only for the cards in `changedCardIds`:
  - `buddies`: the providers the form invalidates (`dive_edit_page.dart:6756-6771`) for the old and new buddy ids.
  - `sightings`: `diveSightingsProvider`, `siteSpottedSpeciesProvider` for the stored and saved site.
  - `profile` or `notes`: `diveAnnotationsProvider`.
  - `signatures`, `safetyReview`, `navTrack`, `diveLab`, `documents`: their read providers; `diveLab` also adopts the link in `divePlanNotifierProvider`; `navTrack` shows the form's snackbar for skipped routes when the page is still mounted.
  - `media`: each `mediaAfterCommit` step, then `mediaForDiveProvider`, `mediaCountForDiveProvider`, `divePhotoGpsProvider`, `allDivePhotoGpsProvider`.

- [ ] **Step 1: Write the failing tests**

```dart
test('a media upload queue that throws after the write is not a failed save; the rest still run', ...);
test('each card\'s providers are invalidated only when it changed', ...);
test('the plan link is adopted after a Compare change', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the Step 1 file.
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 1 file.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(dive-log): after a sitting, refresh what the new cards changed and queue their uploads"
```

---

### Task 23: The page, end to end

**Files:**
- Modify: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_harness.dart` (buddies, sightings, signatures, annotations, findings, routes, a linked plan, documents, media)
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_remaining_test.dart` (new), `dive_detail_page_unlock_media_test.dart` (new, so neither passes 800 lines)

**Interfaces:**
- Consumes: every task above.

- [ ] **Step 1: Write the tests**

```dart
testWidgets('each new card has a pencil and opens where it sits; the seven fade', ...);
testWidgets('opening and closing every card in imperial units leaves the sitting clean', ...);
testWidgets('a change on every card: Save is one History entry naming them all', ...);
testWidgets('Cancel after a change on every card: every table as it was; the buddy, species and document made on the way remain', ...);
testWidgets('a Save whose media write throws: no sighting, buddy or annotation written, the page still unlocked with its dots', ...);
testWidgets('a sighting synced in during the sitting survives a Save that changed Buddies', ...);
testWidgets('a locked page makes no write on any tap in the ten cards', ...);
// tap every button, chip, tile, row menu item and the chart on each card: no repository write; the viewer, Open, 3D and Show in Finder still open.
testWidgets('the fullscreen profile from the open card, from the closed card and locked', ...);
testWidgets('a drop in a sitting and on the locked page', ...);
```

- [ ] **Step 2: Run them**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_remaining_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_media_test.dart`
Expected: PASS. Each test that passes at first run is checked by breaking the code it pins and seeing it fail, then restored.

- [ ] **Step 3: Format, analyse, run the guards and the page tests**

Run: `dart format .`
Run: `flutter analyze`
Expected: no issues.
Run: `flutter test test/architecture/ test/shared/ test/l10n/ test/core/database/`
Run: every `test/features/dive_log/presentation/pages/dive_detail*_test.dart`, `dive_edit_*_test.dart`, `bulk_*_test.dart` and `fullscreen_profile*_test.dart` file, `test/features/dive_log/presentation/widgets/`, `test/features/dive_log/data/`, `test/features/buddies/`, `test/features/marine_life/`, `test/features/signatures/`, `test/features/nav_track/`, `test/features/dive_lab/`, `test/features/planner/`, `test/features/documents/`, `test/features/media/`, `test/features/media_store/`, `test/features/dashboard/` and `test/features/change_log/`.
Expected: PASS.
Run: `wc -l` on every file this plan created or changed.
Expected: none over 800; `dive_detail_page.dart` at most 784.

- [ ] **Step 4: Look at it**

Render the page in a throwaway widget test (real fonts from the SDK's `material_fonts` folder, deleted afterwards): each of the ten cards locked, unlocked, open full and open empty; the seven faded; the fullscreen profile from the open card and read only; pending photo tiles; a drop's hint. Light and dark, phone and desktop width, metric and imperial. Check by eye that no card moves or grows on unlock and that the fade label does not cover a value. Fix what is wrong with a test first, and keep the pictures, with the "before" ones from Preparation, for the pull request.

- [ ] **Step 5: Commit**

```bash
git add test/features/dive_log/presentation/pages
git commit -m "test(dive-log): the remaining cards end to end in a sitting"
```

---

## Pull request

One, `Refs #4527`. It touches `lib/**/presentation/` and `lib/shared/widgets/`, so it carries the "before" pictures from Preparation and the pictures from Task 23 Step 4, with a line saying the unlocked page is unreachable without the build switch. With the switch off nothing looks different; say so. Pushing and opening it waits for Eric.

## For plans 7 to 10

- **Plan 7.** The Data sources card's buttons, set primary source on the profile's source bar (card and pinned copy), Edit profile, add heart rate and the pre-dive checklist link become listed whole-record operations. The list pane gains the lock, and with it the drop: `openDiveSittingProvider` is set from the pane's sitting too, and Task 21's hint then reads only for a locked pane.
- **Plan 8 (new dive).** A new dive has no stored rows: every `SittingList` loads an empty list for it, and the follow-up's media uploads run as for an existing dive. Buddies is in the starter set.
- **Plan 9.** Finding dismissals, document owners (`documents` is a change log root), plan links (`dive_plans` is a root) and route links (`nav_tracks` is a root) join the dive's History entry. Annotations (`dive_profile_events`), sightings, buddies, custom fields and media rows are already children of the dive.
- **Plan 10.** The photo viewer opened from the Media card during a sitting keeps its own lock; a photo only held in the sitting (not yet written) opens read only, as it has no row.
- **Any plan giving a card an editor:** none is left on the dive page.

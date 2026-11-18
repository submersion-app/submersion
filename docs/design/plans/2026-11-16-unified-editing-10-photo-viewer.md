# Unified Editing, Plan 10: The Photo Viewer's Own Lock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The photo viewer opens locked wherever it is opened from. Unlocking it starts a sitting of its own, on the shared edit session and the shared bar: the controls that write are hidden until then, their changes are held until one Save, and "Write dive data to photo" becomes a whole-record operation (issue #4527).

**Architecture:** A photo's sitting is an `EditSession<PhotoRecord>`. `PhotoRecord` bundles the `MediaItem`, its species tags, its people tags and its dive's media time shift, read once from the stored rows and followed while it changes underneath. Scalar values (colour, the pinned time, the dive shift, a site attachment's category and size) are ordinary `EditField`s. Tags are held as edits (added, changed, removed), so a tag synced in during the sitting is kept. Writes to other records (the buddy added to the dive, colour applied to the dive's other photos) are `holdChange`s. A new `PhotoEditSaveService` writes the sitting in one transaction and one change log operation, as `DiveEditSaveService` does for a dive. One mixin, `PhotoViewerEditing`, gives both viewers (`MediaViewerPage` and `SiteMediaViewerPage`) the lock, the bar, the leave check and the step check. Still behind `kUnlockEditing`.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift (SQLite), `photo_view`, `flutter gen-l10n`.

**Spec:** `docs/design/specs/2026-11-14-unified-editing-pattern-design.md`. Read "The rule", "Saving, cancelling, leaving", "Whole-record operations", "Pages opened from a record's page" and "The photo viewer". The shared pieces are described as built in the "For plans ..." and "After the review" sections of plans 1 to 5 (`docs/design/plans/2026-11-14-unified-editing-1-skeleton.md` to `2026-11-15-unified-editing-5-tanks-equipment-weights.md`). Plan 6 (`2026-11-15-unified-editing-6-remaining-cards.md`, on branch `ericgriffin/nifty-tereshkova-be3a99`, not merged) holds a dive's media in its sitting; only Task 13 here needs it.

## What a photo's sitting holds

Card ids name a change in the History label and in `changedCardIds`. The viewer has no cards: the ids are labels only.

| Id | Held | Today written by | Written at Save by |
| --- | --- | --- | --- |
| `species` | `photoSpeciesField`: `SpeciesTagEdits` | `SpeciesTaggingService.tagPhoto` / `untagPhoto`, at once (a tag adds the dive's sighting when none exists) | the same two calls |
| `people` | `photoPeopleField`: `PersonTagEdits`; held change `'photo:addBuddyToDive'` | `MediaPeopleRepository.addTag` / `updateTag` / `removeTag`; `offerAddToDive` adds the buddy at once | the same three calls; `BuddyRepository.addBuddyToDiveWithRoles(diveId, buddyId, const [])` |
| `time` | `photoPinField` (`MediaItem.manualElapsedSeconds`), `photoDiveShiftField` (`Dive.mediaTimeOffsetSeconds`) | `MediaTimePinner.apply` | `MediaRepository.setManualElapsedSeconds`, `DiveRepository.setMediaTimeOffsetSeconds`; after the commit, `DiveMediaEnricher.enrichMissingForDive` |
| `color` | `photoColorField` (`MediaItem.colorAdjustment`); held change `'photo:colorToDive'` | `MediaColorAdjustmentRepository.setColorAdjustment`, `applySlidersToDive` | the same two calls |
| `details` | `photoSiteCategoryField`, `photoDisplaySizeField` (site attachments only) | `SiteAttachmentRepository.setAttachmentDetails` | the same call |
| `file` | held change `'photo:relink'` (Task 13) | `replaceMediaLink` (the info sheet's "Locate file...") | plan 6's `MediaRepairService.applyInTransaction` |

Not held, and outside the rule: the Perdix overlay toggle and its drag (display settings), the enrichment backfill on view (derived), Check now, Back up now / Retry upload, Re-upload (the copy in the media store, Eric's choice), share, show info, play and pause, Go to dive, Open in Lightroom, the species and people chips' links, holding Original in the colour panel. A buddy or species created from a picker during the sitting stays created after Cancel, as on the dive page.

"Write dive data to photo" is a whole-record operation: it changes the file. Listed but disabled while locked, enabled when unlocked with no changes, disabled while there are changes; it keeps its confirmation and acts at once (Eric's choice).

## Rules

| Event | Effect |
| --- | --- |
| Unlock | Offered only for a photo or video with a stored row, on a device that can attach media (`deviceCapabilitiesProvider.mediaAttach`), with the switch on |
| Previous, next, arrow keys | With changes: `showDiscardDialog`, then lock and step. With none: lock and step. Every photo opens locked |
| Swipe between photos | Off while unlocked, as in people tag mode |
| Close button, swipe down, Escape, system back | Escape is Cancel (the viewer stays open). The rest go through `RecordEditLeaveGuard`: asked with changes, locked without |
| Go to dive | `cancelSitting` first; on false nothing happens |
| The sitting's photo leaves the list | The viewer follows it to its new index. If it is gone, the sitting ends and the viewer says so (`media_viewer_photoGoneWhileEditing`) |
| Lock, by any route | Closes the colour panel, Pick white and people tag mode; drops the colour draft |
| Unlocked chrome | The bar never hides (a tap on the photo, a playing video); fullscreen is not offered |
| Set time | The chips, the mini profile and the dive computer face show the held time at once (`photoShownItem`) |
| Species tagged on a dive photo | Save adds the dive's sighting as today, in the same transaction |
| Info sheet | In the viewer: Set time and Locate follow the lock. Opened from the library grid or a status badge, with the switch on: neither is shown (Eric's choice) |
| Opened from a dive's sitting | That sitting does not end; the photo's lock is its own. A photo only held in that sitting (no stored row) opens read only (Task 13) |

## Calls made in this plan, for Eric to check

Eric chose on 2026-11-16: writes to the dive (time shift, add buddy, the sighting) held to the photo's Save; Apply to this dive held, confirmed with its count when tapped, Undo dropped; Locate held, built last; Write dive data shown disabled while locked; the site viewer gets the same lock, with Edit details held (its Save becomes Done); media store actions outside the rule; the info sheet outside the viewer reads only. Made in writing the plan, not confirmed:

1. **Swiping is off while unlocked.** A swipe cannot stop halfway to ask; the arrows and keys step through the check.
2. **Escape is Cancel**, as the spec gives the dive page; it does not close the viewer.
3. **The bar never hides while unlocked, and fullscreen is not offered.** Both hide Cancel and Save.
4. **A photo removed under an open sitting ends it** with one line saying the changes were not saved. A photo removed elsewhere in the list keeps the sitting, and the viewer stays on its photo.
5. **Tags are held as edits.** A person or species tagged on another device during the sitting is kept at Save, as plan 6 keeps an unseen sighting.
6. **The History label reads "Edited photo: Species, Color"**, a string of its own, so a photo's entry in the dive's History is not read as the dive's own cards. A dive photo's entry sits under the dive, as its rows already do (`media` is a child of `dives` in `change_log_policy.dart`); a photo with no dive is its own root.
7. **No History icon in the viewer.** The spec puts one on record pages; the viewer's History is the dive's.
8. **Unlock is not offered where the toolbar is read only** (`mediaAttach` false: a library reader on the web, issue #4121).
9. **After Save, the enrichment pass runs best effort**, outside the History entry, as `MediaTimePinner.apply` runs it today: the positions are derived.
10. **The unlocked bar is `RecordEditBar` with the viewer's actions in it**, at the viewer's 64 px band, so the photo and the dive computer face do not move on unlock.
11. **Two pull requests if plan 6 has not merged:** Tasks 1 to 12 first, Task 13 after plan 6.
12. **New strings** (Task 3, 4, 5): `recordEdit_unlockToUseThis` "Unlock to use this", `recordEdit_saveOrCancelFirst` "Save or cancel your changes first", `media_viewer_editingPhoto` "Editing photo", `media_viewer_editingVideo` "Editing video", `media_viewer_photoGoneWhileEditing` "This photo was removed. Your changes were not saved.", `changeLog_label_photoEdit` "Edited photo: {cards}", `media_editCard_people` "People", `media_editCard_timeInDive` "Time in dive", `media_editCard_color` "Color", `media_editCard_details` "Details", `media_editCard_file` "File" (Task 13). `species` reuses `media_species_actionTooltip` "Species"; the unlock tooltip reuses `recordEdit_unlockTooltip`. Plan 7 can reuse the first two for the dive's menu.

## Not in this plan

- The dive page's whole-record operations and menus (plan 7), a new dive (plan 8), the change log extension (plan 9), the switch-over (plan 11).
- The rest of the media library: the library grid's selection bar (bulk tag, bulk unlink), the media map, smart albums, the document viewer (`DocumentViewerPage` also opens `showAttachmentDetailsSheet`; it stays as it is).
- The species, trip, buddy and gear wrappers need no change of their own: they open `MediaViewerPage`, which gets the lock.

## Global Constraints

- With `kUnlockEditing` false both viewers, the info sheet, the species sheet, the colour panel and the attachment details sheet build and behave exactly as today. No existing test changes its expectations.
- A locked viewer shows no control that writes, opened from a dive, the media library, a site, a trip, a species, a buddy or gear.
- A value the diver did not change is never written. Opening every sheet and panel and closing it leaves the sitting clean.
- Every held write runs inside `PhotoEditSaveService.save`'s transaction. Nothing in it writes to another database, clears a cache or shows UI.
- Anything that writes to a sitting after an `await` (a sheet, a picker, a dialog, a colour sample) checks `mounted` where it has one, then `session.isDisposed` and `session.isFrozen`, and drops its result when the sitting's photo is no longer the one it was asked about. It reads `ref` and `context` before the first `await`.
- Units follow the active diver's settings (`unitFormatterProvider`), as the chips do today.
- Typed numbers are read only through `readNumber`; the architecture guard forbids `tryParse` in presentation code.
- Settings are read with `settingsProvider.select(...)`.
- No file over 800 lines. `media_viewer_page.dart` is 1,982 lines: Task 1 splits it to at most 700 before anything is added, and it ends at most 750. `site_media_viewer_page.dart` (534), `media_info_panel.dart` (739), `media_viewer_toolbar.dart` (366): `wc -l` before adding, and move code out first when an addition would pass 800.
- Every new string goes in all 11 ARB files (`en es fr de it nl pt hu ar he zh`) with a real translation, beside a key of the same group, then `flutter gen-l10n`. This plan expects the eleven in call 12.
- No em-dash characters anywhere; no emojis; no mention of any AI tool in code, commits or pull requests. Imports are `package:submersion/...`, with trailing commas.
- Tests restore global state: `tester.view` via `addTearDown`, the test database via `tearDownTestDatabase()`, any provider or singleton override they install. Build repositories in `setUp`.
- Before each commit: `dart format .`, `flutter analyze`, the affected test files, plus `flutter test test/architecture/ test/shared/` when files under `lib/` were added. Never the whole suite. Do not pipe `flutter test` into `grep` or `tail` to judge the result.
- Do not push or open a pull request; that waits for Eric.

## Review Focus

1. **The list changes under an open sitting.** A sync removes a photo before the current one, so the index now points at another photo: the viewer stays on the sitting's photo. The sitting's own photo is removed: the sitting ends with the message, and no write lands on any photo. Pinned in Task 5.
2. **Leaving by a route `PopScope` does not see.** The close button and the swipe down call `Navigator.pop()`, and Go to dive calls `pushOrReturnTo`, which pops. With changes each asks first; without, each locks on the way. Pinned in Task 5.
3. **Stored values change during the sitting.** Another device recolours the photo, pins its time, tags a person. Untouched values follow; Save does not write them back; a tag the sitting never saw survives a Save that changed other tags. Pinned in Tasks 2, 3 and 7.
4. **A Save that fails partway.** The people tags are written, then the dive shift throws: no tag, sighting or colour is left, nothing is enriched, and the viewer stays unlocked with the changes. Pinned in Task 3.
5. **A late answer.** The species picker, the person picker, the Set time dialog or a Pick white sample answers after the diver has stepped to another photo, cancelled, or saved: nothing lands in the new sitting. Pinned in Tasks 6, 7, 8 and 9.

## Preparation

- [ ] Work on a branch cut from current `origin/main` (plans 1 to 5 merged). Plan 6 is not needed before Task 13.
- [ ] In a fresh worktree: `git submodule update --init --recursive`, `flutter pub get`, then `dart run build_runner build --delete-conflicting-outputs` with no build filter.
- [ ] `flutter analyze` on the whole repository is clean before any change.
- [ ] Take the pull request's "before" pictures now, before any code changes: the viewer's toolbar and bottom chips on a dive photo, a library photo with no dive and a video, the colour panel, the info sheet, the site viewer on an attachment; light and dark, phone and desktop width.

## File Structure

New:

| File | Responsibility |
| --- | --- |
| `lib/features/media/domain/entities/photo_record.dart` | `PhotoRecord`: what one photo's sitting is over |
| `lib/features/media/domain/value_objects/photo_tag_edits.dart` | `SpeciesTagEdits`, `PersonTagEdits`: tag changes held as edits |
| `lib/features/media/data/services/photo_record_reader.dart` | `PhotoRecordReader`: the stored `PhotoRecord` |
| `lib/features/media/data/services/photo_edit_save_service.dart` | `PhotoEditSaveService`: one transaction, one operation |
| `lib/features/media/presentation/providers/photo_editing_providers.dart` | `photoRecordProvider`, `photoRecordReaderProvider`, `photoEditSaveServiceProvider` |
| `lib/features/media/presentation/editing/photo_edit_fields.dart` | Card ids, the `EditField`s, the time rules, `photoShownItem` |
| `lib/features/media/presentation/editing/photo_held_writes.dart` | Held changes to other records: buddy to the dive, colour to the dive |
| `lib/features/media/presentation/editing/photo_sitting_shown.dart` | What the chips, boxes and sheets show: the sitting's tags, or the stored ones |
| `lib/features/media/presentation/editing/photo_viewer_editing.dart` | `PhotoViewerEditing`: the lock, the bar, Save, the leave and step checks, for both viewers |
| `lib/features/media/presentation/pages/media_viewer_gallery.dart` | Part file: `_PhotoGallery`, `_PhotoItem`, `_ConnectorVideoItem`, moved |
| `lib/features/media/presentation/pages/media_viewer_video_item.dart` | Part file: `_VideoItem`, moved |
| `lib/features/media/presentation/pages/media_viewer_bottom_metadata.dart` | Part file: `_BottomMetadataOverlay`, `_MetadataChip`, moved |
| `lib/features/media/presentation/pages/media_viewer_write_metadata.dart` | Part file: the write-metadata flow, moved |
| `lib/features/media/presentation/pages/media_viewer_chrome.dart` | Part file: the overlay chrome (toolbar, labels, arrows, mini profile, chips), moved |

Modified, by task: see each task's Files. Tests mirror the source paths under `test/`.

---

### Task 1: The viewer page split into part files

No behaviour changes. Every later task adds to the viewer, which is 1,982 lines.

**Files:**
- Create: the five part files in the File Structure.
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart` (gains five `part` lines; the moved code leaves)

**Interfaces:**
- Produces: `_MediaViewerPageState` as now, with the chrome built by `Widget _overlayChrome({...})` in `media_viewer_chrome.dart` (lines 691 to 805 today) and `Future<void> _writeMetadataToPhoto(MediaItem item)` in `media_viewer_write_metadata.dart` (lines 954 to 1085), both as extension methods `on _MediaViewerPageState` or mixin members, the implementer's choice; private classes keep their names.

- [ ] **Step 1: Run the viewer's tests before moving anything**

Run: `flutter test test/features/media/presentation/pages/ test/features/media/presentation/media_viewer_launcher_test.dart test/features/media/presentation/media_selection_test.dart test/features/buddies/presentation/widgets/buddy_photos_section_test.dart`
Expected: PASS. Note the count.

- [ ] **Step 2: Move the code**

Cut and paste only; the moved code keeps its comments. A part file cannot import: every import stays in `media_viewer_page.dart`.

- [ ] **Step 3: Run the same tests and check the sizes**

Run: the Step 1 command.
Expected: PASS, same count.
Run: `wc -l lib/features/media/presentation/pages/media_viewer*.dart`
Expected: `media_viewer_page.dart` at most 700; every part file under 800.

- [ ] **Step 4: Commit**

```bash
git add lib/features/media/presentation/pages/
git commit -m "refactor(media): split the media viewer page into part files"
```

---

### Task 2: `PhotoRecord`, its fields and its edits

**Files:**
- Create: `photo_record.dart`, `photo_tag_edits.dart`, `photo_edit_fields.dart`
- Test: `test/features/media/domain/value_objects/photo_tag_edits_test.dart`, `test/features/media/presentation/editing/photo_edit_fields_test.dart`

**Interfaces:**
- Produces:

```dart
// photo_record.dart
@immutable
class PhotoRecord extends Equatable {
  const PhotoRecord({required this.item, required this.species, required this.people, this.diveShiftSeconds});
  final MediaItem item;
  final List<SpeciesTagChip> species;      // as getTagChipsForMedia returns them
  final List<MediaPersonChip> people;      // as getChipsForMedia returns them
  final int? diveShiftSeconds;             // the dive's mediaTimeOffsetSeconds; null with no dive
  PhotoRecord copyWith({MediaItem? item, List<SpeciesTagChip>? species, List<MediaPersonChip>? people, int? diveShiftSeconds});
}

// photo_tag_edits.dart
@immutable
class SpeciesTagEdits extends Equatable {
  const SpeciesTagEdits({this.added = const {}, this.removed = const {}});
  static const none = SpeciesTagEdits();
  final Map<String, SpeciesTagChip> added;   // by species id
  final Set<String> removed;                 // stored species ids
  bool get isEmpty;
  SpeciesTagEdits toggled(SpeciesTagChip chip, {required bool tagged, required List<SpeciesTagChip> stored});
  List<SpeciesTagChip> applyTo(List<SpeciesTagChip> stored);  // stored minus removed, then added not already there
}

@immutable
class PersonTagEdits extends Equatable {
  const PersonTagEdits({this.added = const [], this.changed = const {}, this.removed = const {}});
  static const none = PersonTagEdits();
  final List<MediaPersonChip> added;          // tags with a local id, not yet stored
  final Map<String, MediaPersonChip> changed; // stored tag id -> the tag as changed
  final Set<String> removed;                  // stored tag ids
  bool get isEmpty;
  PersonTagEdits add(MediaPersonChip chip, {required List<MediaPersonChip> shown});
  PersonTagEdits change(MediaPersonChip chip, {required List<MediaPersonChip> stored});
  PersonTagEdits remove(String tagId, {required List<MediaPersonChip> stored});
  List<MediaPersonChip> applyTo(List<MediaPersonChip> stored);
}

// photo_edit_fields.dart
const photoSpeciesCardId = 'species', photoPeopleCardId = 'people', photoTimeCardId = 'time',
    photoColorCardId = 'color', photoDetailsCardId = 'details', photoFileCardId = 'file';
final EditField<PhotoRecord, SpeciesTagEdits> photoSpeciesField;   // read: none; write: species = edits.applyTo(record.species)
final EditField<PhotoRecord, PersonTagEdits> photoPeopleField;     // likewise
final EditField<PhotoRecord, int?> photoPinField;                  // item.manualElapsedSeconds
final EditField<PhotoRecord, int?> photoDiveShiftField;            // diveShiftSeconds
final EditField<PhotoRecord, ColorAdjustment?> photoColorField;    // item.colorAdjustment
final EditField<PhotoRecord, SiteAttachmentCategory?> photoSiteCategoryField;
final EditField<PhotoRecord, AttachmentDisplaySize?> photoDisplaySizeField;

void applyTimeChoice(EditSession<PhotoRecord> session, MediaTimeChoice choice, {MediaAutomaticTime? automatic});
int? elapsedInSitting(EditSession<PhotoRecord> session);   // null: the stored enrichment stands
MediaItem photoShownItem(EditSession<PhotoRecord> session, List<DiveProfilePoint> profile);
```

  `applyTimeChoice` mirrors `MediaTimePinner.apply` onto the fields: Pinned sets the pin; Reset clears it; DiveShifted sets the shift and clears the pin; DiveShiftRemoved sets the shift to 0. It remembers `automatic` under `'photo:automatic'` (`session.remember`). `elapsedInSitting`: the pin when set; else, when the shift or the pin changed and the automatic time is known, `automatic.elapsedSeconds + (shift - automatic.diveShiftSeconds)`; else null. `photoShownItem` is `working.item` with, when `elapsedInSitting` is not null, an enrichment built from `EnrichmentService.calculateEnrichmentAtElapsed` as `DiveMediaEnricher` builds one (`dive_media_enricher.dart:86`; extract that construction into a shared function if it is private) and `isManual` true for a pin.

  `PersonTagEdits.add` follows `isDuplicatePersonTag` (`media_person_tag.dart:15`) against what is shown: a tag duplicating one shown moves that one's box, as `MediaPeopleRepository.addTag` does. A change or removal of an added tag edits `added`. A change back to the stored tag drops it from `changed`.

- [ ] **Step 1: Write the failing tests**

```dart
// photo_tag_edits_test.dart
test('species toggled on and off again is no edit', ...);              // isEmpty, == none
test('a stored species untagged then tagged again is no edit', ...);
test('applyTo keeps a stored tag the edits never named', ...);          // a tag synced in meanwhile survives
test('a person added then removed is no edit', ...);
test('a person added who duplicates a shown tag moves its box', ...);   // one chip, the new box
test('a stored tag changed back is no edit', ...);
test('applyTo drops a change to a tag no longer stored', ...);

// photo_edit_fields_test.dart
test('each field reads and writes its value on PhotoRecord', ...);
test('a shift chosen clears the pin and shows the shifted time', () {
  // stored: pin 300, shift 0; automatic (elapsedSeconds: 120, diveShiftSeconds: 0)
  // applyTimeChoice(MediaTimeDiveShifted(60)) -> pin null, shift 60, elapsedInSitting == 180
});
test('a pin shows at once; Reset with no automatic time shows the stored enrichment', ...);
test('photoShownItem: depth from the profile at the held time; isManual for a pin', ...);
test('a session rebased onto a stored tag added elsewhere keeps the held edits', ...);
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `flutter test test/features/media/domain/value_objects/photo_tag_edits_test.dart test/features/media/presentation/editing/photo_edit_fields_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run them and confirm they pass**

Run: the Step 2 command, then `flutter test test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media test/features/media
git commit -m "feat(media): a photo's sitting, with its tags held as edits"
```

---

### Task 3: Saving a photo's sitting, and its History label

**Files:**
- Create: `photo_record_reader.dart`, `photo_edit_save_service.dart`, `photo_editing_providers.dart`, `photo_held_writes.dart`
- Modify: `lib/features/change_log/presentation/change_log_labels.dart` (`_recordEditLabel` for table `media`)
- Modify: the 11 ARB files (`changeLog_label_photoEdit`, `media_editCard_people`, `media_editCard_timeInDive`, `media_editCard_color`, `media_editCard_details`)
- Test: `test/features/media/data/services/photo_edit_save_service_test.dart` (test database), `test/features/change_log/presentation/change_log_labels_test.dart` (add cases)

**Interfaces:**
- Consumes: Task 2.
- Produces:

```dart
class PhotoRecordReader {
  PhotoRecordReader({required MediaRepository media, required MediaSpeciesRepository species,
      required MediaPeopleRepository people, required DiveRepository dives});
  /// Null when the media row does not exist.
  Future<PhotoRecord?> read(String mediaId, {required String? diverId});
}

class PhotoEditSaveService {
  PhotoEditSaveService({required PhotoRecordReader reader, required SpeciesTaggingService tagging,
      required MediaPeopleRepository people, required MediaRepository media,
      required MediaColorAdjustmentRepository colors, required SiteAttachmentRepository attachments,
      required DiveRepository dives});
  /// Applies [apply] to the record as stored now and writes what differs, then
  /// [alsoWrite], in one transaction and one ChangeLogScope operation
  /// (source manual, label RecordEditLabel.encode(table: 'media', cardIds: changedCardIds)).
  /// Null when nothing differed and [alsoWrite] is not a change. Throws StateError
  /// when the media row is gone.
  Future<({PhotoRecord before, PhotoRecord after})?> save({
    required String mediaId, required String? diverId,
    required PhotoRecord Function(PhotoRecord stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite, bool alsoWriteIsAChange = false,
  });
}

final photoRecordProvider = FutureProvider.autoDispose.family<PhotoRecord?, String>(...);  // ticks on media, tag, buddy and dive changes
final photoRecordReaderProvider = Provider<PhotoRecordReader>(...);
final photoEditSaveServiceProvider = Provider<PhotoEditSaveService>(...);

// photo_held_writes.dart
void holdAddBuddyToDive(EditSession<PhotoRecord> session, {required String diveId, required Buddy buddy, required BuddyRepository repository});
void holdColorToDive(EditSession<PhotoRecord> session, {required String diveId, required ColorAdjustment source, required MediaColorAdjustmentRepository repository});
```

  The writes, in this order inside the transaction: species added (`tagPhoto`) and removed (`untagPhoto`); people removed, changed (`updateTag`), added (`addTag`, with the held box and moment); the pin; the colour; category and size (`setAttachmentDetails` with `diffAttachmentDetails`); the dive shift; then `alsoWrite`. `holdColorToDive` holds `applySlidersToDive(diveId:, sourceMediaId:, source:)` under `'photo:colorToDive'` and card `color`; it reads the source from the sitting when it runs, so the colour saved is the colour applied. `holdAddBuddyToDive` holds under `'photo:addBuddyToDive:<buddyId>'` and card `people`, and does nothing at Save when the buddy is on the dive by then.

  `_recordEditLabel`: a `media` label reads `changeLog_label_photoEdit` with the cards named `species` `media_species_actionTooltip`, `people` `media_editCard_people`, `time` `media_editCard_timeInDive`, `color` `media_editCard_color`, `details` `media_editCard_details` (and `file` `media_editCard_file`, added in Task 13), joined by `changeLog_label_recordEditSeparator`.

- [ ] **Step 1: Write the failing tests**

```dart
test('a sitting that tags a species, a person and a colour is one operation, labelled', () async {
  // test database: a dive with a profile and one photo
  // ops = rows of change_log_operations after save; expect(ops, hasLength(1));
  // expect(ops.single.label, 'record_edit:media:color,people,species');
  // the dive gained a sighting of the species; the operation's root is the dive
});
test('only what changed is written: a colour stored meanwhile on an untouched photo field survives', ...);
test('a tag added on another device during the sitting survives a Save that removed another', ...);
test('a pin and a dive shift are written; the enrichment pass is not part of the save', ...);
test('a save whose dive shift throws leaves no tag, sighting, colour or pin', () async {
  // the service built with a DiveRepository whose setMediaTimeOffsetSeconds throws
  // (a subclass of the real one over the test database); every table as before
});
test('a photo with no dive: the species tag adds no sighting; the label names species', ...);
test('Apply to this dive held: the other photos get the saved sliders at Save, in the same operation', ...);
test('add buddy held: added at Save; already on the dive by then: nothing written', ...);
test('nothing changed: null, and no operation left behind', ...);
test('a media row deleted before Save: StateError, nothing written', ...);

// change_log_labels_test.dart
test('a photo sitting reads "Edited photo: Species, Color"', ...);
test('an unknown photo card id is shown as written', ...);
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `flutter test test/features/media/data/services/photo_edit_save_service_test.dart test/features/change_log/presentation/change_log_labels_test.dart`
Expected: FAIL.

- [ ] **Step 3: Add the strings, run `flutter gen-l10n`, then implement**

- [ ] **Step 4: Run them and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/media/data/ test/features/change_log/ test/l10n/ test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(media): save a photo's sitting in one transaction and one History entry"
```

---

### Task 4: The bar and the toolbar learn the lock

**Files:**
- Modify: `lib/shared/widgets/record_editing/record_edit_bar.dart` (`actions`)
- Modify: `lib/features/media/presentation/widgets/media_viewer_toolbar.dart`
- Modify: the 11 ARB files (`recordEdit_unlockToUseThis`, `recordEdit_saveOrCancelFirst`, `media_viewer_editingPhoto`, `media_viewer_editingVideo`)
- Test: `test/shared/widgets/record_editing/record_edit_bar_test.dart`, `test/features/media/presentation/widgets/media_viewer_toolbar_test.dart` (add cases)

**Interfaces:**
- Produces:

```dart
// RecordEditBar gains
final List<Widget> actions;   // default const []; drawn between the title and Save

// MediaViewerAction gains
final String? disabledReason; // non-null: drawn disabled, the reason as tooltip and menu subtitle

// MediaViewerToolbar gains
final VoidCallback? onUnlock;                 // non-null: a lock action ('unlock', Icons.lock_outline, recordEdit_unlockTooltip, priority 0)
final bool writeControls;                     // default true; false drops species, people and adjust colour
final String? writeMetadataDisabledReason;    // the write_metadata action drawn disabled with it
final MediaViewerEditBar? editBar;            // non-null: drawn as RecordEditBar, see below

@immutable
class MediaViewerEditBar {
  const MediaViewerEditBar({required this.title, required this.canSave, required this.isSaving,
      required this.onCancel, required this.onSave});
  final String title; final bool canSave; final bool isSaving;
  final VoidCallback onCancel; final VoidCallback onSave;
}
```

  With `editBar`, the toolbar draws a `RecordEditBar` inside its 64 px band (below the status bar padding, as now): no close, no fullscreen, no page indicator; its actions are the toolbar's own action list without `unlock`, split by `splitToolbarActions` over at most half the bar's width, the rest in the overflow menu. Every default leaves the toolbar as today.

- [ ] **Step 1: Write the failing tests**

```dart
// record_edit_bar_test.dart
testWidgets('actions sit between the title and Save; none by default', ...);

// media_viewer_toolbar_test.dart
testWidgets('defaults: the same actions as today', ...);
testWidgets('onUnlock: a lock action is shown, and stays visible at phone width', ...);
testWidgets('writeControls false: no species, people or adjust colour', ...);
testWidgets('write_metadata with a reason: disabled, the reason as tooltip; in the overflow menu disabled with the reason', ...);
testWidgets('editBar: Cancel, the title, the actions and Save; no close or fullscreen; the band is 64 px', ...);
testWidgets('editBar at 360 px wide: the actions that do not fit are in the overflow menu', ...);
testWidgets('a read-only device: no lock action even with onUnlock', ...);   // deviceCapabilitiesProvider mediaAttach false
```

- [ ] **Step 2: Run them and confirm they fail**

Run: the two test files.
Expected: FAIL.

- [ ] **Step 3: Add the strings, run `flutter gen-l10n`, then implement**

- [ ] **Step 4: Run them and confirm they pass**

Run: the two test files, then `flutter test test/features/media/presentation/widgets/ test/shared/ test/l10n/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(media): the viewer toolbar offers the lock and becomes the editing bar"
```

---

### Task 5: The viewer opens locked, unlocks, and guards every way out

**Files:**
- Create: `lib/features/media/presentation/editing/photo_viewer_editing.dart`, `photo_sitting_shown.dart`
- Modify: `media_viewer_page.dart` and its part files (`unlockEditing` parameter; the mixin; close, swipe down, Escape, Go to dive, stepping; the gallery draws the working item)
- Modify: the 11 ARB files (`media_viewer_photoGoneWhileEditing`)
- Test: `test/features/media/presentation/pages/media_viewer_unlock_harness.dart` (new), `media_viewer_unlock_test.dart` (new)

**Interfaces:**
- Consumes: Tasks 2 to 4.
- Produces:

```dart
// MediaViewerPage gains
final bool unlockEditing;   // default kUnlockEditing

// photo_viewer_editing.dart
mixin PhotoViewerEditing<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  bool get editingOffered;                         // the page's unlockEditing, and mediaAttach
  RecordEditController<PhotoRecord> get photoEditController;
  EditSession<PhotoRecord>? get photoSitting;
  bool get photoUnlocked;
  /// Call from build with the media on screen: follows photoRecordProvider,
  /// rebases the sitting, ends it when its photo is gone.
  void followStoredPhoto(MediaItem onScreen);
  bool canUnlock(MediaItem item);                  // a stored row, offered, not a document
  void unlockPhoto();
  Future<void> savePhotoAndReport();               // recordEdit_saveFailed on failure, as the dive page
  /// Steps through the check: with changes asks, then locks and calls [step].
  Future<void> stepGuarded(VoidCallback step);
  /// For routes PopScope does not see (close, swipe down, Go to dive).
  Future<bool> leaveGuarded();
  /// The stored list with the sitting's photo drawn as photoShownItem.
  List<MediaItem> shownMediaList(List<MediaItem> stored, List<DiveProfilePoint> profile);
  /// The index of the sitting's photo in [list], or null when it is not there.
  int? sittingIndexIn(List<MediaItem> list);
  /// Wraps the page body in RecordEditLeaveGuard and RecordEditScope<PhotoRecord>.
  Widget photoEditScope({required Widget child});
  /// Told on every lock, so the page closes its panels and modes: here it sets
  /// colorPanelOpen and pickingWhite false and leaves people tag mode; Task 9
  /// replaces the first two with closeColorEditing().
  void onPhotoLocked();
  void disposePhotoEditing();
}

// photo_sitting_shown.dart
List<SpeciesTagChip> speciesChipsShown(WidgetRef ref, String mediaId, EditSession<PhotoRecord>? sitting);
List<MediaPersonChip> peopleChipsShown(WidgetRef ref, String mediaId, EditSession<PhotoRecord>? sitting);
```

  The controller is a `RecordEditController<PhotoRecord>` whose `onSave` calls `PhotoEditSaveService.save` with `apply: session.applyTo`, `alsoWrite: session.runHeldWrites` when `hasHeldWrites`, `alsoWriteIsAChange: hasHeldChanges`, reading every provider before the first `await`; after the commit it runs `diveMediaEnricherProvider.enrichMissingForDive` when `time` changed, in a `try` of its own (call 9). The chips helpers return the stored provider's value unless `sitting` is the sitting of `mediaId`, then `sitting.working`'s list.

  In the page, with `editingOffered`: the toolbar gets `onUnlock` when locked and `canUnlock`, `writeControls: photoUnlocked`, and `editBar` when unlocked (title `media_viewer_editingVideo` for a video, else `media_viewer_editingPhoto`); `_stepPage` callers go through `stepGuarded`; the pager's physics are `NeverScrollableScrollPhysics` while unlocked; `onClose` and the swipe down call `Navigator.maybePop`; Escape while unlocked is `cancelSitting`; Go to dive awaits `leaveGuarded` first; the overlay is always shown and Enter fullscreen is not offered while unlocked; the gallery is handed `shownMediaList`; when the list changes and `sittingIndexIn` differs from the index on screen, the pager jumps to it. With `editingOffered` false none of this is built.

- [ ] **Step 1: Write the harness and the failing tests**

The harness pumps `MediaViewerPage(unlockEditing: true)` over the test database with a dive (profile, one sighting, one buddy), three photos and a video. Every table the viewer writes is tracked by the change log, so "no write" is `expect(await eventCount(), mark)`, where `eventCount()` counts `db.changeLogEvents` rows and `mark` was read before the taps. The file write of Write dive data goes through `MethodChannel('com.submersion.app/metadata')`, which the harness mocks and records as `media_viewer_write_metadata_test.dart` does (with `MetadataWriteService.debugSupportedOverride`, put back in `addTearDown`). It offers `unlock()`, `save()`, `cancel()`, `next()`.

```dart
testWidgets('locked: no species, people or adjust colour; write data disabled with "Unlock to use this"', ...);
testWidgets('locked: tapping every control writes nothing, opened as from a dive and as from the library', ...);  // the spec's test
testWidgets('unlocked: the bar is Cancel, "Editing photo", the actions and Save; Save disabled', ...);
testWidgets('unlocking moves nothing: the photo and the toolbar band keep their rects', ...);
testWidgets('the close button with changes asks; keep editing keeps them', ...);
testWidgets('a swipe down with changes asks; with none it locks and closes', ...);
testWidgets('Escape is Cancel: with changes asks, then locks; the viewer stays', ...);
testWidgets('Go to dive with changes asks; discard locks and goes', ...);
testWidgets('next with changes asks; discard steps and the next photo is locked', ...);
testWidgets('next with no changes locks and steps', ...);
testWidgets('a swipe does not page while unlocked', ...);
testWidgets('a photo removed before the current one: the sitting stays on its photo', ...);
testWidgets('the sitting\'s photo removed: the sitting ends with the message; nothing written', ...);
testWidgets('a tap on the photo and a playing video keep the bar up; no fullscreen while unlocked', ...);
testWidgets('a photo with no stored row offers no unlock', ...);
testWidgets('a read-only device offers no unlock', ...);
testWidgets('switch off: the toolbar, the close and the swipe as today', ...);
testWidgets('pushed over a dive page in a sitting: Save and Cancel here leave that sitting open', ...);
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `flutter test test/features/media/presentation/pages/media_viewer_unlock_test.dart`
Expected: FAIL.

- [ ] **Step 3: Add the string, run `flutter gen-l10n`, then implement**

- [ ] **Step 4: Run them and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/media/presentation/pages/ test/features/media/presentation/media_viewer_launcher_test.dart test/l10n/ test/architecture/ test/shared/`
Expected: PASS; `media_viewer_page.dart` at most 750 lines.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(media): the photo viewer opens locked and guards a sitting on every way out"
```

---

### Task 6: Species tags held

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_species_sheet.dart` (`showMediaSpeciesSheet` and `MediaSpeciesSheet` gain `sitting`)
- Modify: `lib/features/media/presentation/widgets/media_species_chips_row.dart` (reads `speciesChipsShown`)
- Modify: `media_viewer_chrome.dart` (passes the sitting)
- Test: `test/features/media/presentation/widgets/media_species_sheet_test.dart`, `media_species_chips_row_test.dart` (add cases), `media_viewer_unlock_test.dart` (add cases)

**Interfaces:**
- Consumes: Tasks 2 and 5.
- Produces: `showMediaSpeciesSheet(BuildContext context, MediaItem item, {EditSession<PhotoRecord>? sitting})`. With a sitting, the chips show `sitting.working.species`, a toggle sets `photoSpeciesField` through `SpeciesTagEdits.toggled`, and Other species adds the picked species as a `SpeciesTagChip` built from the `Species` the picker returns (`speciesId`, `name`, `category`, `isBuiltIn`). A sighting chip is built from the sighting, its `isBuiltIn` read with `SpeciesRepository.getSpeciesById` before the toggle lands. Nothing is written. A species created in the picker stays.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('with a sitting: a toggle holds the tag; the chip row shows it; no tag written', ...);
testWidgets('with a sitting: a species from the picker is held; a new custom species stays after Cancel', ...);
testWidgets('the picker answering after the sitting ended changes nothing', ...);
testWidgets('no sitting: the sheet writes as today', ...);
testWidgets('end to end: tag, Save, the dive has the sighting and one History entry', ...);
```

- [ ] **Step 2: Run them and confirm they fail**

Run: the three test files.
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run them and confirm they pass**

Run: the three test files, then `flutter test test/features/media/presentation/widgets/ test/features/media/data/services/species_tagging_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(media): species tags held in a photo's sitting"
```

---

### Task 7: People tags held, and the add-to-dive offer

**Files:**
- Modify: `lib/features/media/presentation/widgets/people_tags/people_tag_viewer_mixin.dart` (writes go to the sitting when there is one)
- Modify: `add_to_dive_offer.dart` (`offerAddToDive` gains `onAdd`)
- Modify: `media_people_chips_row.dart`, `face_box_layer.dart`, `video_people_layer.dart`, `people_tag_hint.dart` (read `peopleChipsShown`)
- Test: `test/features/media/presentation/widgets/people_tags/people_tag_mode_test.dart`, `add_to_dive_offer_test.dart`, `media_people_chips_row_test.dart`, `face_box_layer_test.dart` (add cases), `media_viewer_unlock_test.dart` (add cases)

**Interfaces:**
- Consumes: Tasks 2, 3 and 5.
- Produces:

```dart
// PeopleTagViewerMixin gains
EditSession<PhotoRecord>? get peopleSitting;   // the host returns photoSitting; null keeps today's writes

// offerAddToDive gains
void Function(Buddy buddy)? onAdd,             // non-null: the offer's Add calls it instead of writing
```

  With a sitting, `_tagWith`, `changeTaggedPerson`, `removePeopleTag` and `movePeopleTag` set `photoPeopleField` through `PersonTagEdits`; a held tag gets a local id (`const Uuid().v4()`), so it can be selected and moved. The offer checks the dive's buddies as today and also the sitting's held adds; its Add calls `holdAddBuddyToDive`. A buddy created in the person picker stays.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('with a sitting: a placed box is a held tag; its chip and box show; no row written', ...);
testWidgets('with a sitting: a held tag moved, re-assigned, removed; removing it leaves the sitting clean', ...);
testWidgets('with a sitting: the offer\'s Add is held; Save adds the buddy; Cancel adds nothing', ...);
testWidgets('a person tagged on another device meanwhile is kept by a Save that removed another', ...);
testWidgets('the picker answering after a step to another photo changes nothing', ...);
testWidgets('a video tag keeps its moment', ...);
testWidgets('no sitting: every write as today', ...);
```

- [ ] **Step 2: Run them and confirm they fail**

Run: the five test files.
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run them and confirm they pass**

Run: the five test files, then `flutter test test/features/media/presentation/widgets/people_tags/ test/features/media/presentation/widgets/people_filter/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(media): people tags and the add-to-dive offer held in a photo's sitting"
```

---

### Task 8: Time in the dive held, and the info sheet's writes

**Files:**
- Modify: `media_viewer_page.dart` (`_setTimeInDive` holds; the shown item)
- Modify: `lib/features/media/presentation/widgets/media_info_sheet.dart`, `media_info_panel.dart` (`sitting`, `readOnly`)
- Modify: `lib/features/media/presentation/widgets/media_library_grid.dart:71`, `media_status_badge.dart:64` and `:168` (`readOnly: kUnlockEditing`)
- Test: `test/features/media/presentation/widgets/media_info_panel_test.dart` (add cases), `test/features/media/presentation/pages/media_viewer_manual_time_test.dart` (add a group), `media_viewer_unlock_test.dart` (add cases)

**Interfaces:**
- Consumes: Tasks 2 and 5.
- Produces:

```dart
Future<void> showMediaInfoSheet(BuildContext context, MediaItem item,
    {EditSession<PhotoRecord>? sitting, bool readOnly = false});
// MediaInfoPanel gains the same two parameters.
```

  `readOnly` hides Set time and Locate. Until Task 13 gives Locate a hold, it is shown only with neither parameter set (as today). With a sitting, Set time awaits `pinner.automaticTimeFor(item)` alongside the dialog and calls `applyTimeChoice`; nothing is written and the enricher does not run. The viewer passes `sitting: photoSitting`, and `readOnly: true` while locked with editing offered. The dialog is seeded from the shown item, so a held pin reopens where it was left.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('with a sitting: a pin moves the chip, the mini profile marker and the depth at once; nothing written', ...);
testWidgets('with a sitting: a dive shift shows this photo shifted; Save writes the shift and clears the pin; the enricher runs after', ...);
testWidgets('the dialog reopened in the sitting starts at the held time', ...);
testWidgets('the dialog answering after Cancel, or after a step to another photo, changes nothing', ...);
testWidgets('locked with the switch on: no Set time in the bottom chips or the info sheet', ...);
testWidgets('the info sheet from the library grid and a status badge: no Set time, no Locate', ...);
testWidgets('switch off: the info sheet and the chip as today', ...);
```

- [ ] **Step 2: Run them and confirm they fail**

Run: the three test files.
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run them and confirm they pass**

Run: the three test files, then `flutter test test/features/media/presentation/widgets/ test/features/media/presentation/pages/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(media): time in the dive held in a photo's sitting; the info sheet reads only outside it"
```

---

### Task 9: Colour held, Apply to this dive included

**Files:**
- Modify: `lib/features/media/presentation/widgets/color_adjust/color_adjust_panel.dart` (`sitting`)
- Modify: `color_adjust_viewer_mixin.dart` (passes the sitting; `closeColorEditing()` for the lock)
- Modify: `lib/features/media/presentation/helpers/color_pick_white.dart` (`applyPickedWhite` gains `sitting`)
- Modify: `apply_to_dive_action.dart` (`runApplyToDive` gains `sitting`)
- Test: `test/features/media/presentation/widgets/color_adjust/color_adjust_panel_test.dart`, `apply_to_dive_action_test.dart` (add cases), `test/features/media/presentation/pages/media_viewer_color_panel_test.dart` (add a group)

**Interfaces:**
- Consumes: Tasks 2, 3 and 5.
- Produces:

```dart
// ColorAdjustPanel gains
final EditSession<PhotoRecord>? sitting;
// ColorAdjustViewerMixin gains
EditSession<PhotoRecord>? get colorSitting;   // the host returns photoSitting
void closeColorEditing();                    // panel closed, Pick white off, the draft cleared
// applyPickedWhite and runApplyToDive gain
EditSession<PhotoRecord>? sitting,
```

  With a sitting, `_save` sets `photoColorField` and clears the draft at once (the working item draws the held colour, `effectiveAdjustment` reads it); Reset sets null; Pick white sets the white point. `runApplyToDive` asks with the count as today, then calls `holdColorToDive` and shows no snackbar and no Undo. Original still peeks.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('with a sitting: a drag draws live and holds on release; nothing written; Done keeps it drawn', ...);
testWidgets('with a sitting: Cancel draws the stored colour again', ...);
testWidgets('with a sitting: Pick white holds the white point; a sample answering after the sitting ended changes nothing', ...);
testWidgets('with a sitting: Apply to this dive confirms with the count, holds, offers no Undo; Save writes both', ...);
testWidgets('locking closes the panel and Pick white', ...);
testWidgets('no sitting: the panel saves as today', ...);
```

- [ ] **Step 2: Run them and confirm they fail**

Run: the three test files.
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run them and confirm they pass**

Run: the three test files, then `flutter test test/features/media/presentation/widgets/color_adjust/ test/features/media/presentation/widgets/color_corrected_test.dart test/features/media/presentation/widgets/video_color_filter_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(media): colour held in a photo's sitting, Apply to this dive included"
```

---

### Task 10: Write dive data to photo, a whole-record operation

**Files:**
- Modify: `media_viewer_chrome.dart` (the toolbar's `writeMetadataDisabledReason`), `media_viewer_write_metadata.dart` (refused unless unlocked and clean)
- Test: `test/features/media/presentation/pages/media_viewer_write_metadata_test.dart` (add a group)

**Interfaces:**
- Consumes: Tasks 4 and 5.
- Produces: the reason is `recordEdit_unlockToUseThis` while locked, `recordEdit_saveOrCancelFirst` while `photoEditController.isDirty`, null otherwise. The flow is today's: its confirmation, then the write at once. The viewer stays unlocked and clean after it.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('locked: disabled, "Unlock to use this"; no dialog on tap', ...);
testWidgets('unlocked with no changes: confirms and writes at once; still unlocked, clean', ...);
testWidgets('unlocked with a change: disabled, "Save or cancel your changes first"', ...);
testWidgets('switch off: as today', ...);
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `flutter test test/features/media/presentation/pages/media_viewer_write_metadata_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run it and confirm it passes**

Run: the Step 2 command.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(media): writing dive data to a photo needs the unlock and a clean sitting"
```

---

### Task 11: The site viewer gets the same lock

**Files:**
- Modify: `lib/features/media/presentation/pages/site_media_viewer_page.dart` (`unlockEditing`; `PhotoViewerEditing`; `_TopOverlay` gains `onUnlock` and the edit bar)
- Modify: `lib/features/media/presentation/widgets/attachment_details_sheet.dart` (`showAttachmentDetailsSheet` gains `onHold`)
- Test: `test/features/media/presentation/pages/site_media_viewer_page_test.dart` (add a group), `test/features/media/presentation/widgets/attachment_details_sheet_test.dart` (add cases)

**Interfaces:**
- Consumes: Tasks 2 to 5 and 9.
- Produces: `showAttachmentDetailsSheet(context, item:, siteId:, void Function(SiteAttachmentCategory?, AttachmentDisplaySize?)? onHold)`. With `onHold`, the sheet's button reads `common_action_done`, writes nothing and hands over its choice; the viewer sets `photoSiteCategoryField` and `photoDisplaySizeField`. `_TopOverlay` while locked: no Adjust color, no Edit details, plus the lock; unlocked it is drawn as `RecordEditBar` with Adjust color, Edit details and Share as its actions. Leaving, stepping, swiping, the photo leaving the list and the chrome follow Task 5's rules, through the same mixin.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('locked: no Adjust color or Edit details; tapping every control writes nothing', ...);
testWidgets('unlocked: a colour and new details are held; Save writes both in one entry', ...);
testWidgets('Edit details with onHold: Done, nothing written; without: Save writes as today', ...);
testWidgets('next with changes asks; the close button with changes asks', ...);
testWidgets('switch off: as today', ...);
```

- [ ] **Step 2: Run them and confirm they fail**

Run: the two test files.
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run them and confirm they pass**

Run: the two test files, then `flutter test test/features/media/presentation/pages/site_media_viewer_page_test.dart test/features/media/presentation/widgets/ test/features/dive_sites/`
Expected: PASS; `site_media_viewer_page.dart` under 800 lines.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(media): the site media viewer opens locked; colour and details held"
```

---

### Task 12: The viewer, end to end

**Files:**
- Test: `test/features/media/presentation/pages/media_viewer_unlock_end_to_end_test.dart` (new)

**Interfaces:**
- Consumes: every task above.

- [ ] **Step 1: Write the tests**

```dart
testWidgets('a change of every kind: one History entry under the dive, "Edited photo: Species, People, Time in dive, Color"', ...);
testWidgets('Cancel after a change of every kind: every table as it was; a buddy and a species made on the way remain', ...);
testWidgets('reverting the entry puts back the tags, the pin, the shift, the colour, the sighting and the dive buddy', ...);
testWidgets('a Save whose last write throws: nothing written, still unlocked, the changes shown', ...);
testWidgets('in imperial units the chips and the Set time dialog follow the diver', ...);
testWidgets('the wrappers (trip, species, buddy, gear, library) open locked and write nothing locked', ...);
```

- [ ] **Step 2: Run them**

Run: `flutter test test/features/media/presentation/pages/media_viewer_unlock_end_to_end_test.dart`
Expected: PASS. Each test that passes at first run is checked by breaking the code it pins and seeing it fail, then restored.

- [ ] **Step 3: Format, analyse, run the guards and the media tests**

Run: `dart format .`
Run: `flutter analyze`
Expected: no issues.
Run: `flutter test test/architecture/ test/shared/ test/l10n/ test/features/media/ test/features/media_store/ test/features/change_log/ test/features/buddies/ test/features/marine_life/ test/features/dive_sites/ test/features/equipment/ test/features/trips/`
Expected: PASS.
Run: `wc -l` on every file this plan created or changed.
Expected: none over 800; `media_viewer_page.dart` at most 750.

- [ ] **Step 4: Look at it**

Render the viewer in a throwaway widget test (real fonts from the SDK's `material_fonts` folder, deleted afterwards): locked and unlocked on a dive photo, a video and a library photo with no dive; the colour panel, the species sheet and people tag mode in a sitting; write data disabled with each reason; the site viewer locked and unlocked; light and dark, phone and desktop width. Check by eye that the photo and the dive computer face do not move on unlock and that the overflow menu holds what does not fit. Fix what is wrong with a test first, and keep the pictures, with the "before" ones from Preparation, for the pull request.

- [ ] **Step 5: Commit**

```bash
git add test/features/media/presentation/pages
git commit -m "test(media): the photo viewer's sitting end to end"
```

---

### Task 13: After plan 6: held photos, Locate held, and the dive's sitting

Built once plan 6 has merged. It needs plan 6's `mediaInSitting`, `MediaRepairService.applyInTransaction` and `replaceMediaLink(onHold:)` (plan 6 Tasks 18 and 20).

**Files:**
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart` (in a sitting, a tile opens `MediaViewerPage` on `mediaInSitting`)
- Modify: `media_info_panel.dart` (Locate in a sitting holds), `photo_held_writes.dart` (`holdRelink`), `photo_edit_save_service.dart` (the relink's after-commit work), `photo_edit_fields.dart` (`photoShownItem` draws a held relink)
- Modify: `change_log_labels.dart` and the 11 ARB files (`media_editCard_file`)
- Test: `test/features/media/presentation/pages/media_viewer_held_media_test.dart` (new), `photo_edit_save_service_test.dart` and `media_info_panel_test.dart` (add cases)

**Interfaces:**
- Consumes: plan 6 Tasks 18 and 20; Tasks 3, 5 and 8.
- Produces: `void holdRelink(EditSession<PhotoRecord> session, RepairProposal proposal, {required MediaRepairService service})`, key `'photo:relink'`, card `file`, run with `applyInTransaction`; its returned after-commit work runs after the photo's save, guarded, as plan 6's `mediaAfterCommit` does for the dive. While a relink is held the viewer draws the proposal's file, as plan 6's `mediaInSitting` draws a replaced link.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('a photo only held in the dive\'s sitting opens on itself, read only, no unlock', ...);
testWidgets('a photo opened from the dive\'s sitting: its Save adds a sighting; the dive\'s sitting then Saves and the sighting survives', ...);
testWidgets('a buddy the photo\'s Save added survives the dive\'s Save that changed Buddies', ...);
testWidgets('Locate in a sitting: held, the viewer shows the new file, Save relinks in the same entry; Cancel leaves the link', ...);
test('a relink held with a tag: one operation; the upload is queued after the commit', ...);
```

- [ ] **Step 2: Run them and confirm they fail**

Run: the three test files.
Expected: FAIL.

- [ ] **Step 3: Add the string, run `flutter gen-l10n`, then implement**

- [ ] **Step 4: Run them and confirm they pass**

Run: the three test files, then `flutter test test/features/media/ test/features/dive_log/presentation/pages/dive_detail_page_unlock_media_test.dart test/l10n/ test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(media): held photos open read only; Locate held in a photo's sitting"
```

---

## Pull request

Tasks 1 to 12 are one pull request, `Refs #4527`. Task 13 joins it if plan 6 has merged by then, otherwise it is a second pull request after plan 6 (call 11). Both touch `lib/**/presentation/` and `lib/shared/widgets/`, so they carry the "before" pictures from Preparation and the pictures from Task 12 Step 4, with a line saying the lock is unreachable without the build switch. With the switch off nothing looks different; say so. Pushing and opening them waits for Eric.

## For plans 7, 9 and 11

- **Plan 7.** `recordEdit_unlockToUseThis` and `recordEdit_saveOrCancelFirst` exist; the dive's menu caption can reuse the second and add a plural of the first. `RecordEditBar.actions` is where the unlocked dive bar's menu goes.
- **Plan 9.** A photo's sitting writes only tracked tables (`media`, `media_species`, `media_people`, `sightings`, `dive_buddies`, `dives`), so its History entry is complete without plan 9. `media_enrichment` stays `deleteCopyOnly`: it is derived, and the pass runs after the save.
- **Plan 11.** The switch-over turns both viewers' `unlockEditing` on with the dive page's, and removes the immediate paths each widget keeps for `sitting == null` only where nothing else calls them (the library selection bar still tags at once).

---

## After the review

Tasks 1 to 12 were built as written in one session (Eric chose "Native"), then reviewed as a whole branch by a fresh reviewer, then by three more review rounds and the PR's own review (PR #4646). Task 13 is not built: it waits for plan 6. This is what differs from the task text above, for whoever builds Task 13 and writes plan 11.

### Decided by Eric after the review (2026-11-16)

- **The photo's own tags (#1970) are held.** The info sheet's Edit tags wrote at once, even locked; the plan had missed them. Locked, and wherever the info sheet opens outside the viewer, Edit tags is not offered. In a sitting the tag sheet holds the chosen tags (`photoTagsField`, `MediaTagEdits`, card id `tags`, read in History as "Tags" with the existing `media_info_tags`), written by `TagLinkRepository.replaceTags` in the sitting's transaction.
- **A photo that leaves the viewer's list keeps its sitting** while its row exists (another device untagging the species, moving the dive out of a trip, unlinking it): `keepSittingPhoto` keeps it on screen in its place. Only the photo's deletion ends the sitting with `media_viewer_photoGoneWhileEditing`.

### Names that changed, or were added

| Above | Now |
| --- | --- |
| `PersonTagEdits.add(chip, {shown, isVideo})` | `add(chip, {stored, isVideo})`, like `change` and `remove`: it works out what is shown |
| `holdAddBuddyToDive(session, {diveId, buddy, repository})` | Takes `buddyId` |
| `holdColorToDive(session, {diveId, source, repository})` | No `source`: the colour is read from the sitting when the write runs |
| `PhotoRecordReader({media, species, people, dives})` | `({media, species, people, tags})`: the dive shift is one column query, not `DiveRepository.getDiveById` (which loads the profile) |
| `PhotoEditSaveService.save(...)` | Gains `diveAtStart`: a photo moved to another dive since the sitting began is refused with `PhotoMovedError`, and a photo no longer stored with `PhotoGoneError` (both `StateError`s), so the viewer can say which |
| `followStoredPhoto(onScreen)` returns nothing | Returns the stored `PhotoRecord` of the photo on screen; `canUnlock(item, stored)` and `unlockPhoto(stored)` take it |
| `photo_sitting_shown.dart` in Task 5 | Created in Task 6, where it is first used |
| `MediaInfoPanel` | Its tags section (`MediaInfoTagsSection`) and tag sheet (`showMediaTagSheet`) take `readOnly` and `sitting` too |
| `PhotoViewerPage` | Gains `unlockEditing`, passed to the viewer, so a test can open the dive's viewer with the lock |
| `editingOffered` as the read-only test | `photoLocked` (`unlockEditing && !photoUnlocked`): built with the lock, a device that cannot unlock (a browser) reads only; `editingOffered` still decides whether Unlock is offered |
| Each viewer's own close | `closeGuarded()` in the mixin, for the close button and the swipe down of both viewers |
| `MediaViewerToolbar._buttons` | `toolbarActionButtons(context, split, color)`, shared with the site viewer's editing bar |
| `media_info_panel.dart` | Its File section and Set time button are in the part file `media_info_file_section.dart`, under the 800-line cap |

### Added

- **The viewer redraws on every change to its sitting** (the mixin listens to the session); the chip and box widgets take the sitting as a parameter rather than each listening.
- **Both editing bars are semantics containers of their own.** Without it, in the site viewer, a dialog closing over a dirty sitting tripped Flutter's `node.built` semantics check.
- **The editing bar's actions take what Cancel, Save and the title leave**, up to half the bar, so a phone still reads the title.
- **The add-to-dive offer made in a sitting closes when the sitting ends** (`dismissHeldOffer`), so a late Add is never dropped unsaid; an offer still being made as the sitting ends is closed as it appears.
- **When a sitting ends, the sheets and dialogs over the viewer close** (`PopupRoute`s only; a page the diver opened from a chip stays): `EditSession.dispose` does not notify, so an open sheet would otherwise go on showing held values.
- **A library link from the viewer asks its guard.** `openMediaWithFilter` popped every pageless route, and `Navigator.pop` ignores `PopScope`, so the Me chip or a tag chip closed a viewer with unsaved changes and dropped them. A route that refuses to pop is asked instead (`maybePop`), and the library is not opened.
- **Escape backs out one step at a time in a sitting:** Pick white, then the colour panel, then people tag mode, then Cancel.
- **A photo deleted while its save runs** ends the sitting when the save fails on the missing row, with the one gone message.
- **Messages:** `media_viewer_videoGoneWhileEditing` for a video's sitting ending; `media_viewer_movedWhileEditing` when Save is refused for a photo moved to another dive (Cancel, then unlock again).
- **The info sheet in a sitting** shows the held time in dive and starts Set time from it, and its sheets read only once their sitting has ended.
- **Held tag edits follow the store.** `SpeciesTagEdits.toggled` leaves a species the way the diver asked even when the store moved underneath (tagged or untagged on another device), and each time the stored photo changes the viewer drops the edits the store has made moot (`prunedTo` on the species, people and tag edits), so a sitting with nothing left to save is clean.
- **The colour field counts null and the neutral adjustment as the same colour**, as the repository stores a cleared one as neutral.
- **`media_viewer_page.dart`** was split by moving the gallery, the video item, the bottom chips, the Perdix resolver, the write to the file, the controls' actions and the toolbar's construction into part files (`media_viewer_*.dart`, extensions on the page state). It ends at 758 lines.

### Left open

- The add-to-dive snackbar covers tag mode's bar for its four seconds (as before this plan).
- Check now, Back up now and Retry upload stay in the locked info sheet: they act on the file check and the media store copy, outside the lock (Eric's choice, restated on the PR).

### Cleared later (PR #4670, after Task 13)

- Save reads the located file again: one gone or edited since fails the save with `LocatedFileChangedError` and `media_viewer_locatedFileChanged`.
- `withHeldRelink` draws the relink by the repair's own rule (`relinkedToFile`, also the repair's same-bytes check), pinned against the stored row.
- One helper, `undoHeldWritesOnFailure`, takes back held writes for the dive's media and the photo's relink.

### For Task 13 and plan 11

- **Task 13.** Locate is hidden in a sitting until it can be held. `MediaInfoPanel(sitting:)` is where its hold goes; `PhotoEditSaveService.save(alsoWrite:)` takes the relink. The Media card opening the viewer on `mediaInSitting` gets "no unlock" for a held photo for free: `canUnlock` needs a stored row.
- **Plan 11.** Both viewers' `unlockEditing` default to `kUnlockEditing`; nothing else reads the switch here except the library grid and the status badge (`readOnly: kUnlockEditing` on the info sheet). Inside the viewers the read-only gates (`photoLocked`, `colorLockOffered`) follow `unlockEditing`, not the device's capability, so turning the switch on never leaves a device that cannot unlock writing at once.

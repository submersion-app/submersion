# Unified editing, phase 3, plan 1: shared pieces Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shared pieces every phase 3 record page needs before any of them moves (issue #4527, phase 3): phase 3's one build switch, a card id list per record type with History naming those cards, a satellite page that joins its parent's sitting or holds its own, tab support for the trip page, and one sharing sitting over the trip and gear repositories. No page uses them yet, so nothing a diver sees changes.

**Architecture:** Card ids are an enum per record type in that feature's `presentation/editing/`, and `change_log_labels.dart` names a sitting's cards through them, as it does for dives and sites. A satellite is a `RecordEditHost` page whose `joinedSitting` is its parent page's controller when it was pushed during that sitting: it then shows a Done bar and holds no lock, keys or exit blocker of its own; otherwise it is an ordinary host on the parent's record with the parent's save. Tabs are a mixin `on RecordEditHost`, beside `RecordOpenUnlocked`: the strip offers the tab in view, a card asked to show itself on another tab brings that tab forward, and a keep-alive holds every tab while a sitting is open. The sharing sitting is a generic held write over a two-method adapter, with one adapter for `ItemSharesRepository` (trips) and one for `EquipmentShareRepository` (gear).

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift (SQLite), `flutter gen-l10n` (ten new card titles).

**Spec:** [docs/design/specs/2026-11-18-unified-editing-phase-3-records-design.md](../specs/2026-11-18-unified-editing-phase-3-records-design.md), on top of [phase 2](../specs/2026-11-17-unified-editing-phase-2-sites-design.md) and [the pattern](../specs/2026-11-14-unified-editing-pattern-design.md).

## Global Constraints

- Phase 2's plans 6 and 7 may still change `lib/shared/widgets/record_editing/`. So merge origin/main before each task, and adapt to any renamed names. Bring main in with a merge (never a rebase or a force-push) and run a whole-repo `flutter analyze` after each merge.
- Nothing a diver sees changes in this plan: no page, route or opener reads the new pieces yet.
- The switch: `const bool kUnlockRecordEditing = bool.fromEnvironment('UNLOCK_RECORD_EDITING');`, one for all of phase 3 (decision 6), read later through a widget parameter defaulting to it, as `kUnlockSiteEditing` is.
- A phase 3 sitting's History label is `record_edit:<table>:<id>:<cardIds>` (`RecordEditLabel.encode`), with `<table>` the record's own table (`buddies`, `dive_centers`, `certifications`, `courses`, `documents`, `species`, `gps_tracks`, `nav_tracks`, `trips`, `equipment`, `equipment_sets`). A satellite's sitting is labelled with its parent's table and id.
- `lib/shared/widgets/record_editing/` imports nothing from `lib/features/`. Adapters that know a repository live in that repository's feature.
- New strings only where a card has no plain title today: the ten marked "New" in Task 1's table. Each goes into all eleven ARB files, translated, then `flutter gen-l10n`. A header block card is named by its record's kind, as "Dive" and "Site" name theirs.
- Never use em-dashes, and never en-dashes, double hyphens or spaced hyphens as prose punctuation, in code, comments, commits or the PR. Commits, the PR and files follow the repository guide's Attribution section.
- Imports grouped dart, flutter, packages, local. Run `dart format` on changed files before each commit.
- Test runs: only the test files a task writes or changes, by path. Never a folder, never the whole suite, never `test/architecture/` or tagged `test/shared/` guards by hand: the pre-push hook runs format, whole-repo analyze, the guards and the affected tests.
- Never `--build-filter` build_runner. Never let a debug build open `~/Documents/Submersion/submersion.db`.

## Review Focus

1. **A satellite pushed during the parent's sitting, then Done with an open card holding unreadable text.** Done is refused as closing that card is: the page stays, the field shows itself, and the parent's sitting keeps the rest. Pinned in Task 4.
2. **A satellite pushed from a locked parent.** It opens locked with a lock of its own; Unlock, change, Save writes one sitting labelled with the parent's table and id, and the parent page under it follows the stored record. Pinned in Task 4.
3. **A trip sitting with a card open on Gear, the diver moves to Checklist and back.** The open card is still open, and unreadable text typed in it is still there (today the tab view drops an off-screen tab). Pinned in Task 5.
4. **Save refused for a card on a tab not in view.** The page moves to that tab and the card shows itself. Pinned in Task 5.
5. **Sharing a gear item the profile no longer owns** (it changed hands on another device mid-sitting). Save fails whole with the sharing refusal message and writes nothing. Pinned in Task 3.

## Preparation

- [ ] The worktree is initialised (`git submodule update --init --recursive`, `flutter pub get`). Generate code, unfiltered, in the background: `dart run build_runner build --delete-conflicting-outputs`. Wait for it to finish.
- [ ] `git fetch origin main`, merge it, and run `flutter analyze` on the whole repository. Expected: clean.
- [ ] Commit the design note's Delivery update and this plan:

```bash
git add docs/design/specs/2026-11-18-unified-editing-phase-3-records-design.md docs/design/plans/2026-11-19-unified-editing-records-1-shared.md
git commit -m "docs(editing): phase 3 runs beside phase 2's last plans; phase 3 plan 1"
```

## File Structure

New, shared (`lib/shared/widgets/record_editing/`):

| File | Responsibility |
| --- | --- |
| `unlock_record_editing_flag.dart` | `kUnlockRecordEditing` |
| `record_satellite_bar.dart` | `RecordSatelliteBar`: the joined satellite's top bar (title and Done) |
| `record_satellite.dart` | `pushRecordSatellite`: pushes a satellite page, handing it the sitting in progress |
| `record_edit_tabs.dart` | `RecordEditTabs<W, T>` (mixin on `RecordEditHost`) and `RecordEditKeepAlive<T>` |
| `record_sharing_sitting.dart` | `RecordSharingAdapter<S>`, `RecordSharingSitting<T, S>` |

New, per feature:

| File | Responsibility |
| --- | --- |
| `lib/features/buddies/presentation/editing/buddy_card_ids.dart` | `BuddyCardId` |
| `lib/features/dive_centers/presentation/editing/dive_center_card_ids.dart` | `DiveCenterCardId` |
| `lib/features/certifications/presentation/editing/certification_card_ids.dart` | `CertificationCardId` |
| `lib/features/courses/presentation/editing/course_card_ids.dart` | `CourseCardId` |
| `lib/features/documents/presentation/editing/document_card_ids.dart` | `DocumentCardId` |
| `lib/features/marine_life/presentation/editing/species_card_ids.dart` | `SpeciesCardId` |
| `lib/features/gps_log/presentation/editing/gps_track_card_ids.dart` | `GpsTrackCardId` |
| `lib/features/nav_track/presentation/editing/nav_track_card_ids.dart` | `NavTrackCardId` |
| `lib/features/trips/presentation/editing/trip_card_ids.dart` | `TripCardId`, with each card's tab |
| `lib/features/equipment/presentation/editing/gear_item_card_ids.dart` | `GearItemCardId`, including the passports' cards |
| `lib/features/equipment/presentation/editing/equipment_set_card_ids.dart` | `EquipmentSetCardId` |
| `lib/features/divers/presentation/editing/item_shares_sharing_adapter.dart` | `ItemSharesSharingAdapter` (trips; sites later) |
| `lib/features/equipment/presentation/editing/equipment_shares_sharing_adapter.dart` | `EquipmentSharesSharingAdapter` (gear) |

Modified:

| File | Change |
| --- | --- |
| `lib/shared/widgets/record_editing/record_edit_host.dart` | `joinedSitting`; a joined page uses the parent's controller, shows `RecordSatelliteBar`, and holds no exit blocker, keys or leave guard |
| `lib/features/change_log/presentation/change_log_labels.dart` | Card names for the eleven phase 3 tables; `gps_tracks` gets a kind name |
| `lib/features/change_log/data/services/change_log_settler.dart` | A species entry is titled by its common name |

---

### Task 1: The switch and the card ids

**Files:**
- Create: `lib/shared/widgets/record_editing/unlock_record_editing_flag.dart`
- Create: the eleven `*_card_ids.dart` files in the File Structure table
- Modify: `lib/l10n/arb/app_*.arb` (the ten new strings, in all eleven) and the generated `lib/l10n/arb/app_localizations*.dart`
- Test: `test/shared/widgets/record_editing/record_card_ids_test.dart`

**Interfaces:**
- Produces:
  - `const bool kUnlockRecordEditing = bool.fromEnvironment('UNLOCK_RECORD_EDITING');`
  - One enum per type, its values in page order, each value's `name` being the card id written into History labels. Each file also has `extension <Enum>Names on <Enum> { String localizedDisplayName(AppLocalizations l) }`, returning the title key in the table below (the header block's key directly, so the card id files do not import `change_log_labels.dart`, which imports them).
  - `TripCardId` also has `TripDetailTab? get tab` (null for the header block, which is on every tab), from `trip_detail_tabs.dart`'s `TripDetailTab`.
  - The values and title keys are those in "Card ids" below.

#### Card ids

Only cards with something to hold get an id: calculated and imported cards
never change, so History never names them and the strip never offers them.
A header block value is named by its record's kind, the word History already
uses for that table. "New" marks one of the ten strings this task adds.

| Enum (table) | Value | Title | Tab |
| --- | --- | --- | --- |
| `BuddyCardId` (`buddies`) | `header` | `settings_conflict_ref_buddy` | |
| | `contact` | `buddies_section_contact` | |
| | `certifications` | `buddies_section_certifications` | |
| | `statistics` | `buddies_section_diveStatistics` | |
| | `gear` | New `buddies_editCard_gear`: "Gear lent" | |
| | `notes` | `buddies_section_notes` | |
| | `documents` | `documents_section_title` | |
| `DiveCenterCardId` (`dive_centers`) | `header` | `settings_conflict_ref_diveCenter` | |
| | `map` | New `diveCenters_editCard_map`: "Map" | |
| | `contact` | `diveCenters_section_contact` | |
| | `notes` | `diveCenters_section_notes` | |
| | `documents` | `documents_section_title` | |
| | `rentalGear` | `diveCenters_rental_sectionTitle` | |
| `CertificationCardId` (`certifications`) | `details` | `certifications_detail_sectionTitle_details` | |
| | `dates` | `certifications_detail_sectionTitle_dates` | |
| | `currency` | `certifications_detail_sectionTitle_currency` | |
| | `instructor` | `certifications_detail_sectionTitle_instructor` | |
| | `cardPhotos` | `certifications_detail_sectionTitle_cardPhotos` | |
| | `documents` | `documents_section_title` | |
| | `notes` | `certifications_detail_sectionTitle_notes` | |
| `CourseCardId` (`courses`) | `status` (the header block) | `settings_conflict_ref_course` | |
| | `details` | `courses_section_details` | |
| | `instructor` | `courses_section_instructor` | |
| | `earnedCertifications` | `courses_section_earnedCertifications` | |
| | `requirements` | `courses_section_requirements` | |
| | `notes` | `courses_section_notes` | |
| | `documents` | `documents_section_title` | |
| `DocumentCardId` (`documents`) | `pages` | `documents_pages_title` | |
| | `details` | New `documents_editCard_details`: "Details" | |
| `SpeciesCardId` (`species`) | `header` | `settings_conflict_ref_species` | |
| | `description` | `marineLife_speciesDetail_descriptionTitle` | |
| | `photos` | New `marineLife_editCard_photos`: "Photos" | |
| `GpsTrackCardId` (`gps_tracks`) | `header` | `gpsTrack_detail_title` | |
| | `trim` | New `gpsTrack_editCard_trim`: "Trim" | |
| `NavTrackCardId` (`nav_tracks`) | `header` | `changeLog_table_navTrack` | |
| | `dive` | New `navTrack_editCard_dive`: "Dive" | |
| | `site` | New `navTrack_editCard_site`: "Site" | |
| | `device` | New `navTrack_editCard_device`: "Device" | |
| | `correction` | New `navTrack_editCard_correction`: "Correction" | |
| `TripCardId` (`trips`) | `header` | `settings_conflict_ref_trip` | null (every tab) |
| | `plan` | `trips_overview_plan` | `overview` |
| | `vessel` | `trips_detail_sectionTitle_vessel` | `overview` |
| | `notes` | `trips_detail_sectionTitle_notes` | `overview` |
| | `documents` | `documents_section_title` | `overview` |
| | `itineraryDays` | `trips_detail_tab_itinerary` | `itinerary` |
| | `packedGear` | `trips_gear_section_packed` | `gear` |
| | `cylinders` (the cylinder board's) | `trips_gear_section_cylinders` | `gear` |
| | `checklists` | `trips_detail_tab_checklist` | `checklist` |
| | `dives` | `trips_detail_tab_dives` | `dives` |
| | `photos` | `trips_photos_sectionTitle` | `photos` |
| `GearItemCardId` (`equipment`) | `header` | `settings_conflict_ref_equipment` | |
| | `diveComputer` | `diveComputer_title` | |
| | `details` | `equipment_detail_detailsTitle` | |
| | `location` | `equipment_location_card_title` | |
| | `twinSet` | `twinSet_title` | |
| | `serviceClocks` | `equipment_serviceClocks_title` | |
| | `conditionFindings` | `equipmentCondition_findings_title` | |
| | `photos` | `equipment_photos_title` | |
| | `observations` | `equipmentObservation_card_title` | |
| | `components` | `equipment_components_title` | |
| | `legacyFiles` | `equipment_documents_linkedTitle` | |
| | `serviceHistory` | `equipment_service_historyTitle` | |
| | `notes` | `equipment_detail_notesTitle` | |
| | `documents` | `documents_section_title` | |
| | `passportFills` (log, edit, delete fills) | `passport_history_title` | |
| | `passportService` (O2 clean) | `passport_service_title` | |
| | `passportTag` (both passports) | `passport_tag_title` | |
| | `passportTrip` (pack, unpack; both passports) | `passport_trip_title` | |
| `EquipmentSetCardId` (`equipment_sets`) | `header` | `settings_conflict_ref_equipmentSet` | |
| | `figure` | `equipment_setEdit_figureSwitch_title` | |
| | `members` | `equipment_setDetail_equipmentInSetTitle` | |
| | `bundle` | New `equipment_setEdit_bundleTitle`: "Bundle" | |
| | `geofences` | `equipment_setDetail_geofencesTitle` | |

Left out on purpose, as they hold nothing: the gear item's Transmitter card
(it opens another record's page) and Parts card (replace is a whole-record
operation, Add part opens a new item), and the trip day page's Day plan,
whose passage is the Notes field, so its changes are named Notes.

- [ ] **Step 1: Write the failing tests** in `record_card_ids_test.dart`, with English `AppLocalizations` (`lookupAppLocalizations(const Locale('en'))`):
  - `the switch is off by default`: `kUnlockRecordEditing` is false.
  - `every card id is unique within its type and none is empty`: for each enum, `values.map((v) => v.name).toSet().length == values.length`.
  - `every card has a title`: for each value of each enum, `localizedDisplayName(l)` is not empty and is not the id itself.
  - `a header block is named by its record's kind`: `BuddyCardId.header.localizedDisplayName(l) == 'Buddy'`, `SpeciesCardId.header... == 'Species'`, `GpsTrackCardId.header... == 'GPS Track'`.
  - `trip cards know their tab`: `TripCardId.header.tab` is null; `TripCardId.packedGear.tab` and `TripCardId.cylinders.tab` are `TripDetailTab.gear`; `TripCardId.checklists.tab == TripDetailTab.checklist`; `TripCardId.photos.tab == TripDetailTab.photos`.
  - `the new titles read as written`: `DiveCenterCardId.map` is `Map`, `GpsTrackCardId.trim` is `Trim`, `BuddyCardId.gear` is `Gear lent`, `EquipmentSetCardId.bundle` is `Bundle`.
- [ ] **Step 2:** Run `flutter test test/shared/widgets/record_editing/record_card_ids_test.dart`. Expected: fails to compile.
- [ ] **Step 3:** Add the ten strings to `app_en.arb` (each with an `@` description saying it is a card's title in an unlocked record page and in History), then to the other ten ARB files translated, then run `flutter gen-l10n`.
- [ ] **Step 4:** Create the flag and the eleven files as the Interfaces block says. Each enum's doc comment names its page and says its values are the cards that can be edited, in page order, and that a value's name is stored in History labels and must not be renamed.
- [ ] **Step 5:** Run the test file. Expected: all pass.
- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/record_editing/unlock_record_editing_flag.dart lib/features/*/presentation/editing/*_card_ids.dart lib/l10n/arb/ test/shared/widgets/record_editing/record_card_ids_test.dart
git commit -m "feat(editing): phase 3's build switch, and the cards each record page can edit"
```

### Task 2: History names phase 3's cards and records

**Files:**
- Modify: `lib/features/change_log/presentation/change_log_labels.dart`
- Modify: `lib/features/change_log/data/services/change_log_settler.dart` (`_labelOf`)
- Test: `test/features/change_log/presentation/change_log_labels_test.dart`, `test/features/change_log/data/services/change_log_settler_test.dart`

**Interfaces:**
- Consumes: the card id enums (Task 1).
- Produces:
  - `_recordCardName` gains one arm per phase 3 table, each through a top-level `asNameMap()` of its enum built once, as `_siteSectionsByName` is: `buddies` (`BuddyCardId`), `dive_centers`, `certifications`, `courses`, `documents`, `species`, `gps_tracks`, `nav_tracks`, `trips`, `equipment` (`GearItemCardId`), `equipment_sets`. An unknown id is shown as written.
  - `changeLogTableLabel` gains `'gps_tracks' => l.gpsTrack_detail_title`.
  - The settler's `_labelOf` reads `common_name` after `name`, `title`, `label` and `display_name`, so a species entry is titled by its common name.

- [ ] **Step 1: Write the failing tests.**
  - In `change_log_labels_test.dart`, beside the `record_edit:dive_sites:` cases:
    - `changeLogStoredLabel(l, 'record_edit:buddies:b1:header,contact')` equals `l.changeLog_label_recordEdit([BuddyCardId.header.localizedDisplayName(l), BuddyCardId.contact.localizedDisplayName(l)].join(l.changeLog_label_recordEditSeparator))`.
    - The same shape for one card of each other phase 3 table: `dive_centers:rentalGear`, `certifications:currency`, `courses:requirements`, `documents:pages`, `species:photos`, `gps_tracks:trim`, `nav_tracks:correction`, `trips:checklists`, `equipment:serviceClocks`, `equipment:passportFills`, `equipment_sets:members`.
    - `record_edit:trips:t1:notes,zzz` names Notes and shows `zzz` as written.
    - `changeLogTableLabel(l, 'gps_tracks') == 'GPS Track'`.
  - In `change_log_settler_test.dart`, beside `labels survive the root being deleted`: `a species entry is titled by its common name`: insert a `species` row with `common_name` `Manta Ray` (the test's own insert helper style, raw SQL), settle, and the operation whose `rootTable` is `species` has `rootLabel == 'Manta Ray'`.
- [ ] **Step 2:** Run the two test files. Expected: the new cases fail (ids shown raw, `gps_tracks` humanised, species label null).
- [ ] **Step 3:** Implement as the Interfaces block says.
- [ ] **Step 4:** Run the two test files. Expected: all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/features/change_log/presentation/change_log_labels.dart lib/features/change_log/data/services/change_log_settler.dart test/features/change_log/presentation/change_log_labels_test.dart test/features/change_log/data/services/change_log_settler_test.dart
git commit -m "feat(history): name the cards of every phase 3 record's sitting"
```

### Task 3: One sharing sitting, over trips and gear

**Files:**
- Create: `lib/shared/widgets/record_editing/record_sharing_sitting.dart`
- Create: `lib/features/divers/presentation/editing/item_shares_sharing_adapter.dart`
- Create: `lib/features/equipment/presentation/editing/equipment_shares_sharing_adapter.dart`
- Test: `test/shared/widgets/record_editing/record_sharing_sitting_test.dart`, `test/features/divers/presentation/editing/item_shares_sharing_adapter_test.dart`, `test/features/equipment/presentation/editing/equipment_shares_sharing_adapter_test.dart`

**Interfaces:**
- Consumes: `EditSession` (`remember`, `recall`, `track`, `holdChange`, `releaseWrite`, `isDisposed`, `isFrozen`), `RecordSittingRefusal`, `sharingRefusedMessage` (`lib/shared/widgets/shared_items/item_sharing_field.dart`).
- Produces:
  - `abstract interface class RecordSharingAdapter<S> { Future<S> read(String recordId); Future<bool> write(String recordId, S sharing, {required String? actingDiverId}); }`: `write` returns false when the repository refused (the profile may not share the record), and throws only when the write failed.
  - `class RecordSharingSitting<T, S> { const RecordSharingSitting({required String key, required String cardId, required String Function(T record) recordIdOf}); }` with:
    - `Future<void> load(EditSession<T> session, RecordSharingAdapter<S> adapter)`: remembers the adapter, reads the sharing of `recordIdOf(session.stored)`, tracked; a read that throws is logged and marks the sitting unread.
    - `S? inSitting(EditSession<T> session)`, `S? loaded(EditSession<T> session)`, `bool unread(EditSession<T> session)`.
    - `void set(EditSession<T> session, S next, {required String? actingDiverId})`: back to what was loaded releases the held write; otherwise holds a change under `key` on `cardId` whose write calls `adapter.write` and throws `const RecordSittingRefusal(sharingRefusedMessage)` when it returns false. Does nothing on a disposed or frozen session, or before the read has answered.
    - Notes are kept under `'$key.adapter'`, `'$key.loaded'`, `'$key.current'`, `'$key.unread'`.
    - The behaviour is `site_sharing_sitting.dart`'s, member for member, with the site's library check left to the caller (who simply does not call `load`).
  - `class ItemSharesSharingAdapter implements RecordSharingAdapter<ItemSharing> { ItemSharesSharingAdapter(ItemSharesRepository repository, SharedItemKind kind); }`: `read` is `sharingOf(kind, id)`; `write` is `setSharing(kind, id, sharing, actingDiverId:)`.
  - `class EquipmentSharesSharingAdapter implements RecordSharingAdapter<Set<String>> { EquipmentSharesSharingAdapter(EquipmentShareRepository repository); }`: `read` is the `diverId`s of `getSharesFor(id)`; `write` returns false when `actingDiverId` is null, else calls `setShares(equipmentId:, diverIds:, actingDiverId:)` and returns false when the result has `skippedNotOwned > 0` or `rejected > 0`.
- Site sharing stays on `site_sharing_sitting.dart` in this plan: phase 2's plans 6 and 7 are still changing the site. It moves onto `RecordSharingSitting` in the first phase 3 plan written after phase 2's plan 7 has merged.

- [ ] **Step 1: Write the failing tests.**
  - `record_sharing_sitting_test.dart`, over a session on a small fake record (`_Rec(id, name)`) and a fake adapter recording writes, answering `read` from a field, and refusing on demand:
    - `loads what the record is shared with`: after `await load`, `loaded` and `inSitting` are the adapter's value and `unread` is false.
    - `a read that fails leaves it unread`: the adapter's `read` throws; `unread` is true and `inSitting` is null.
    - `a choice is a change of its card`: `set` to a new value; `session.changedCardIds == {cardId}` and `inSitting` is the new value.
    - `back to what was read is no change`: set a new value, then the loaded one; the session is clean.
    - `the held write writes the choice by the acting profile`: run the session's held writes (as `held_write_undo_test.dart` does); the adapter saw one write with the new value and `actingDiverId: 'me'`.
    - `a refusal fails with the sharing message`: the adapter refuses; running the held write throws a `RecordSittingRefusal`.
    - `nothing is held before the read answers`: `set` before `load` completes leaves the session clean.
  - `item_shares_sharing_adapter_test.dart` (test database, `setUpTestDatabase()`, `addTearDown(SyncCoordinator.reset)`): two divers `me` and `sam`, a trip owned by `me`; `write` with `ItemSharing(profileIds: {'sam'})` by `me` returns true and `read` returns it; by `sam` returns false and the sharing is unchanged.
  - `equipment_shares_sharing_adapter_test.dart` (same set-up): an item owned by `me`; `write({'sam'})` by `me` returns true and `read` is `{'sam'}`; by `sam` returns false; with `actingDiverId: null` returns false and nothing is written.
- [ ] **Step 2:** Run the three test files. Expected: fail to compile.
- [ ] **Step 3:** Implement as the Interfaces block says.
- [ ] **Step 4:** Run the three test files. Expected: all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing/record_sharing_sitting.dart lib/features/divers/presentation/editing/item_shares_sharing_adapter.dart lib/features/equipment/presentation/editing/equipment_shares_sharing_adapter.dart test/shared/widgets/record_editing/record_sharing_sitting_test.dart test/features/divers/presentation/editing/item_shares_sharing_adapter_test.dart test/features/equipment/presentation/editing/equipment_shares_sharing_adapter_test.dart
git commit -m "feat(editing): one held sharing write for trips and gear"
```

### Task 4: Satellite pages

**Files:**
- Modify: `lib/shared/widgets/record_editing/record_edit_host.dart`
- Create: `lib/shared/widgets/record_editing/record_satellite_bar.dart`
- Create: `lib/shared/widgets/record_editing/record_satellite.dart`
- Create: `test/shared/widgets/record_editing/fake_note_record.dart` (a small record, its cards and a parent and a satellite page, shared by this task's and Task 5's tests)
- Test: `test/shared/widgets/record_editing/record_satellite_test.dart`

**Interfaces:**
- Consumes: `RecordEditHost`, `RecordEditController`, `RecordEditScope`, `AddStripLayout`, `AppBarTextAction`.
- Produces:
  - On `RecordEditHost<W, T>`: `RecordEditController<T>? get joinedSitting => null;` A page overrides it to return the parent page's controller it was handed. While it is non-null and unlocked:
    - `editController` and `maybeEditController` return it; the page creates no controller and no `RecordSittingExitBlocker`, registers no shortcut target (in `initState`, as for `hostsEditing` false), and `disposeEditing` disposes nothing of it.
    - `editScaffold` puts `RecordSatelliteBar(title: editingTitle(record), onDone: finishJoinedSitting)` in place of `RecordEditBar`, and no `RecordEditLeaveGuard`: leaving keeps the changes in the parent's sitting.
    - `Future<void> finishJoinedSitting()`: closes each of `hostEditCards` that is open (`controller.closeCard`); when any of them is still open afterwards (unreadable input, or its check failed) it stays and shows `recordEdit_fixInvalid`; otherwise it pops the page (`Navigator.of(context).maybePop()`).
    - A joined sitting that has been locked by its owner while the page is on top leaves the page reading only: the locked bar, with no lock button (`lockButton` is not shown while `joinedSitting != null`).
  - `class RecordSatelliteBar extends StatelessWidget implements PreferredSizeWidget { const RecordSatelliteBar({super.key, required String title, required VoidCallback onDone}); }`: the `RecordEditBar`'s tint and accent underline, no back arrow, the title, and one `AppBarTextAction(label: l10n.common_action_done)`.
  - `Future<R?> pushRecordSatellite<T, R>(BuildContext context, {required Widget Function(RecordEditController<T>? joined) builder, bool rootNavigator = true})`: reads the nearest `RecordEditScope<T>` without listening (`getInheritedWidgetOfExactType`), passes its controller to `builder` only while it is unlocked, and pushes a `MaterialPageRoute`.
  - A satellite's cards are among its parent page's `hostEditCards` too, so the parent's Save checks them; each type's plan lists them so.
  - A satellite opened with no sitting to join is an ordinary host on the parent's record: its `saveSitting` calls the parent's save service, so its Save is one History entry labelled with the parent's table and id. No new code is needed for that; the test proves it.

- [ ] **Step 1: Write the fake and the failing tests.** `fake_note_record.dart` holds `FakeNote(id, title, text, extra)` with value equality, `fakeTextField`/`fakeTextCard` (id `text`) and `fakeExtraField`/`fakeExtraCard` (id `extra`, `isValid` false when `extra == 'bad'`), a `FakeNoteProbe` (stored notes by id, saves recorded as card id sets) and its providers, `FakeNotePage` (host for both cards, with a button that calls `pushRecordSatellite<FakeNote, void>` to open `FakeSatellitePage`) and `FakeSatellitePage({required String noteId, RecordEditController<FakeNote>? joined})` (host for the `extra` card only, `joinedSitting` returning `joined`, `saveSitting` recording to the same probe). Each test builds its own `ProviderScope` with `appExitGuardProvider` and `recordEditShortcutTargetsProvider`, as `record_edit_host_test.dart` does. Tests in `record_satellite_test.dart`:
  - `pushed during the parent's sitting it joins it`: unlock the parent, open the satellite; it shows `RecordSatelliteBar` and no lock; change `extra`; tap Done; back on the parent, still unlocked, `isDirty`, and its Save records one save with `{'extra'}`.
  - `Done with a card that fails its check stays`: joined, set `extra` to `bad`; Done; the satellite is still shown with the `recordEdit_fixInvalid` snack bar; the parent is still unlocked.
  - `leaving a joined satellite asks nothing`: joined with a change, press back; no dialog; the parent keeps the change.
  - `the parent's sitting stays open while the satellite is on top`: joined, `parent.isSittingOpen` is true throughout, and the satellite's open card does not end it.
  - `pushed from a locked parent it has its own lock`: the satellite shows the lock; unlock, change `extra`, Save; one save with `{'extra'}` recorded by the satellite; the satellite locks; the parent is locked and shows the saved `extra` after the probe's stored note changes.
  - `opened alone it opens locked`: pump `FakeSatellitePage(noteId: 'n1')` with no parent; the lock is shown and nothing is saved on any tap while locked.
  - `a joined sitting locked underneath leaves the satellite reading only`: joined, then call the parent's `editController.lock()`; the satellite shows no Done and no lock.
- [ ] **Step 2:** Run `flutter test test/shared/widgets/record_editing/record_satellite_test.dart`. Expected: fails to compile.
- [ ] **Step 3:** Implement as the Interfaces block says.
- [ ] **Step 4:** Run the satellite test file and `test/shared/widgets/record_editing/record_edit_host_test.dart` (the host changed; its own tests must pass unchanged). Expected: all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing/record_edit_host.dart lib/shared/widgets/record_editing/record_satellite_bar.dart lib/shared/widgets/record_editing/record_satellite.dart test/shared/widgets/record_editing/fake_note_record.dart test/shared/widgets/record_editing/record_satellite_test.dart
git commit -m "feat(editing): satellite pages join their record's sitting, or hold their own"
```

### Task 5: Tabbed record pages

**Files:**
- Create: `lib/shared/widgets/record_editing/record_edit_tabs.dart`
- Modify: `test/shared/widgets/record_editing/fake_note_record.dart` (a two-tab page)
- Test: `test/shared/widgets/record_editing/record_edit_tabs_test.dart`

**Interfaces:**
- Consumes: `RecordEditHost`, `RecordEditController.revealRequest`, `AddStripEntry`.
- Produces:
  - `mixin RecordEditTabs<W extends ConsumerStatefulWidget, T> on RecordEditHost<W, T>`:
    - Supplied by the page: `int? tabOfCard(String cardId)` (null: a card on every tab, such as a header block); `int get tabInView`; `void showTab(int tab)`; `List<AddStripEntry> addStripEntriesOnEveryTab(T working)`.
    - Provided: `addStripEntries(T working)`, the page's entries whose `tabOfCard` is null or `tabInView`. An `onEditChanged` override (calling `super`) that, when `editController.revealRequest` names a card whose tab is not `tabInView`, calls `showTab` with that tab, once per request serial. The card's frame on the new tab answers the request as it mounts, as on any page.
    - The page calls `setState` (or `onEditChanged`) when the tab in view changes, so the strip follows it.
  - `class RecordEditKeepAlive<T> extends StatefulWidget { const RecordEditKeepAlive({super.key, required Widget child}); }`: wraps one tab's view; keeps it alive (`AutomaticKeepAliveClientMixin`) while the nearest `RecordEditScope<T>` is unlocked, and lets it go once locked, so a locked page keeps today's behaviour of building only the tab in view.

- [ ] **Step 1: Write the fake and the failing tests.** `FakeTabbedPage` in `fake_note_record.dart`: a host with `RecordEditTabs`, a `DefaultTabController` of two tabs (tab 0 holds the `text` card, tab 1 the `extra` card, each left out while empty), a `TabBarView` whose children are wrapped in `RecordEditKeepAlive<FakeNote>`, `tabOfCard` from that map, `showTab` animating the controller, and `addStripEntriesOnEveryTab` offering each empty card. Tests in `record_edit_tabs_test.dart`:
  - `the strip offers the tab in view`: a note with both fields empty, unlocked on tab 0; the strip shows `Text` and not `Extra`; move to tab 1; it shows `Extra` and not `Text`.
  - `an open card survives a visit to the other tab`: open `text`, type `half`, move to tab 1 and back; the editor is open and reads `half`.
  - `unreadable input survives a visit to the other tab`: the `text` editor marks `12a` invalid through `setFieldInvalid` as a number row does; after moving away and back the field still reads `12a` and Save is refused.
  - `Save refused for a card on the other tab shows that tab`: on tab 0, set `extra` to `bad` (through the session), Save; tab 1 is in view and the `extra` card's frame is on screen.
  - `locked, an off-screen tab is not kept`: locked, a `State` on tab 0 counts its disposals; moving to tab 1 disposes it once (today's behaviour).
- [ ] **Step 2:** Run `flutter test test/shared/widgets/record_editing/record_edit_tabs_test.dart`. Expected: fails to compile.
- [ ] **Step 3:** Implement as the Interfaces block says.
- [ ] **Step 4:** Run the tabs test file and `test/shared/widgets/record_editing/record_satellite_test.dart` (the fake file changed). Expected: all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing/record_edit_tabs.dart test/shared/widgets/record_editing/fake_note_record.dart test/shared/widgets/record_editing/record_edit_tabs_test.dart
git commit -m "feat(editing): a record sitting spans a tabbed page"
```

### Task 6: Push and open the pull request

- [ ] **Step 1:** Merge origin/main once more and run `flutter analyze` on the whole repository. `dart format` every changed Dart file. Expected: clean.
- [ ] **Step 2:** Push in the background (`git push -u origin HEAD`) and touch no `lib/` or `test/` file while it runs: the hook tests the working tree. If the hook's affected tests fail, fix the cause, commit the fix on its own, and push again.
- [ ] **Step 3:** Run `/code-review` with `--max-findings all`, fix every valid finding, and push again.
- [ ] **Step 4:** Open the PR with `gh pr create` from the repository's template: title `feat(editing): shared pieces for phase 3 of in-place editing, behind a switch`; the body says `Refs #4527`, lists the pieces, and ticks "No visible UI change" with the reason (no page, route or opener reads them yet; the switch is off). Then bind it and turn Auto-fix on.

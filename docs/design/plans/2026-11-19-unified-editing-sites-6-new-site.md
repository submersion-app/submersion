# Unified Editing, Phase 2, Plan 6: A New Site and Duplicate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new site, and a duplicate, open on the site page itself, already unlocked: the header block and the starter cards (Location, Depth, Notes) laid out open, every other card in the Add strip. Save creates the site in one transaction and one History entry; Cancel leaves without creating anything, asking first when something was entered. Still behind `kUnlockSiteEditing` (issue #4527).

**Architecture:** As plan 8's new dive, a new site is a sitting whose stored record is a **seed**: a `DiveSite` that exists only in memory, with a fresh id, the active diver and the sharing every new site gets (`shareByDefaultProvider`), and nothing else. Defaults are part of the seed, so they are not changes. Everything a seed request brings (a name from the site picker, a point from the map and the place names and altitude found for it) and everything a duplicate copies (every field, types, tags, expected species, features, sharing) is put on the sitting after unlock through the cards' own functions, so each is a change with its card's dot. The page is `SiteDetailPage.newSite`: the same `_SiteDetailContent`, built on the seed instead of `siteProvider`, with a new part file holding what only a new site does (`_SiteDetailPageCreating`). Save goes through a new `SiteEditSaveService.create`: insert the row, then the sitting's held writes, in one transaction and one change log operation.

**Tech Stack:** Flutter, Riverpod 3, go_router, drift (test database through `setUpTestDatabase`), `flutter gen-l10n` (no new strings expected).

**Spec:** `docs/design/specs/2026-11-17-unified-editing-phase-2-sites-design.md`: "Design: a new site", decisions 1, 4 and 6, the "Duplicate" row of the held table, the last line of "Calls made in this note" (sharing by default is part of the starting record; a duplicate's sharing is a prefill), and the test line "A new site and a duplicate: seeds and prefills are changes, Cancel asks, Save creates and returns the id to the site picker." The model is phase 1's plan 8 (`docs/design/plans/2026-11-17-unified-editing-8-new-dive.md`) and its page part `lib/features/dive_log/presentation/pages/dive_detail_page_creating.dart`. Plans 1 to 5 of phase 2 shipped every other name used here.

## Questions for Eric

**Eric chose the recommended answer on 2026-11-19** ("Yes, open it").

1. **Where a full-page Save ends.** The spec says Save "shows the site locked", and that a page pushed by the site picker pops with the new id, as the form does. Recommended: the page always pops with the new id, as the form does, so its openers keep their contract: the site picker returns the site to the dive's sitting, Duplicate shows the copy (unchanged), and the three openers that ignore the id today (the site list's Add button on a phone, the list's empty state, the map page's Add) open the new site, locked, with it. In the list pane `?mode=new` selects the new site, as today. The other way is to leave those three as they are, which returns the diver to the list or the map without seeing the site. (Task 4.)

## Calls made in this plan, for Eric to check

Each follows a call Eric confirmed for a new dive on 2026-11-17 (plan 8), or the phase 2 spec.

1. **Save is disabled until something is entered.** The seed's defaults are not entries (plan 8, call 1). A new site from the list has no seed, so Save waits for the first entry; one from the picker carries its name as a change, so Save is enabled at once.
2. **The bar's titles are today's form titles**: `diveSites_edit_appBar_newSite` and, for a duplicate, `diveSites_edit_appBar_duplicateSite`. No new string (plan 8, call 5).
3. **The unlocked bar of a new site has no menu.** Every operation acts on a stored site, and History and display options have nothing to act on yet (plan 8, call 6).
4. **The starter cards are laid out even when the diver has hidden them**, and hidden again once the site is saved, as a card brought in from the strip is (plan 8, call 7). So is every card a seed or a duplicate fills (spec: "Cards holding a seed are laid out open").
5. **No calculated card while creating** (spec): Dive Photos, Tide, Seascape, Reef Health and Dive Statistics are not shown until the site exists.
6. **A seeded point looks up its place names and its altitude**, as the form does: the place names fill only empty fields, the altitude only an empty altitude, and both are changes of their cards. A lookup that fails fills nothing and says nothing, as today.
7. **A duplicate copies what the form copies**: every field (the name as "Copy of ..." through `diveSites_edit_duplicateName`), the active diver's own types and tags, expected species, features, and sharing (the diver's own site keeps its sharing with everyone and with named profiles; another profile's site, and a library site, are shared as a new site is). Not copied, as today: the library link, media, documents, the catalogue link.
8. **A duplicate's features are part of the one Save.** Today they are copied after the site is created, and a failure only says so (`diveSites_edit_snackbar_featuresNotCopied`); now a failure fails the whole Save, which leaves the page unlocked with everything entered (spec: Save is all or nothing).
9. **A sitting that ends without a create while the page stays leaves**, as Cancel does. Plan 8's new dive opened a fresh sitting instead, for a pane address asked twice; the site list pane has no such path.
10. **Nothing is written before Save**: no `dive_sites` row, no change log operation, no feature, species, type, tag or share row. A type or tag created from a picker stays created after Cancel, as on any sitting.

## Not in this plan

- Plan 7, the switch-over: the form, its Edit buttons, merge's own page, and the switch turned on. With `kUnlockSiteEditing` off, `/sites/new`, `?duplicateOf=`, the list pane's `?mode=new` and the site picker's Create open the form exactly as today.
- Creating a site anywhere but the site page (import, the built-in catalogue's "Add to my sites", the site suggestion card): each writes a record directly and is unchanged.
- A new site in the dive list's pane: no opener creates one there.

## Global Constraints

- Behind `kUnlockSiteEditing`: with it off, every opener, route and pane builder named here opens `SiteEditPage` exactly as today.
- Nothing is written before Save (call 10). One Save is one transaction and one change log operation, labelled `RecordEditLabel.encode(table: 'dive_sites', id: <new id>, cardIds: <changed cards>)`, source manual. A Save that fails writes nothing and leaves the page unlocked with every entry and dot intact; Save can be tried again and creates the site once.
- Every value shown or typed follows the active diver's units, as each card already does.
- No file over 800 lines. `site_detail_page.dart` is at 2,385 (already over): it grows only by the lines Task 3 names. `site_detail_page_editing.dart` is at 697 and `app_router.dart` at 2,729: each changes only the lines its task names. New page code goes in the new part file `site_detail_page_creating.dart`.
- **Shared files.** This plan changes nothing under `lib/shared/widgets/record_editing/`: it uses the host's existing creating hooks (`isCreating`, `saveNewRecord`, `cancelNewRecord`, `RecordEditController.unlock(laidOut:)`, `creating`). PR #4746 (phase 3, plan 1, open) changes `record_edit_host.dart` and `record_edit_bar.dart` there; neither is touched here, so whichever PR merges second takes main with a plain merge. The site's sharing stays in `site_sharing_sitting.dart` (PR #4746 leaves it for phase 2's switch-over). If a task finds it must change a shared file after all, the change is additive (a new member with a default, nothing renamed or moved) and is named in the PR.
- Existing strings only (calls 2 and 7). Should a new string turn out to be needed, it goes into all 11 ARB files with an `@key` description in `app_en.arb`, then `flutter gen-l10n`.
- Never an em-dash or en-dash as punctuation; nothing names the coding assistant or its maker.
- Test commands name test FILES by path, never a folder, `test/architecture/` or `test/shared/`.
- `dart format` the changed files before each commit.

## Review Focus

1. A seeded point whose place lookup answers after the diver typed a country: the typed country stays, the empty region fills, and Save waits for the lookup rather than writing without it. Pinned in Task 2.
2. Save pressed on a duplicate before its copied lists have arrived: Save waits for them, and the site is created with the copied types, tags, species and features. Pinned in Task 2 (tracked prefill) and Task 3.
3. A Save whose held write fails: no site, no feature or type row, the page unlocked with every entry; a second Save creates the site once. Pinned in Tasks 1 and 3.
4. A duplicate of another profile's site, or of a library site: the copy is the active diver's, in no library, shared as a new site is, with the original's notes and rating. Pinned in Task 2.
5. Cancel: an untouched new site leaves without asking and writes nothing; one opened from the picker with a name asks first. Pinned in Task 3.

## File Structure

- `lib/features/dive_sites/data/services/site_edit_save_service.dart` (modify): `create`.
- `lib/features/dive_sites/presentation/editing/site_new_sitting.dart` (create): the seed, the duplicate's source, the laid-out cards, and the prefill.
- `lib/features/dive_sites/presentation/editing/site_sharing_sitting.dart` (modify): a new site's sharing starts from the seed, unread.
- `lib/features/dive_sites/presentation/pages/site_detail_page_creating.dart` (create, a part of `site_detail_page.dart`): the new-site loader and `_SiteDetailPageCreating`.
- `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (modify): `SiteDetailPage.newSite`, the part directive, the mixin, the unlocked bar's menu.
- `lib/features/dive_sites/presentation/pages/site_detail_page_editing.dart` (modify): `_framed` leaves calculated cards out while creating.
- `lib/features/dive_sites/presentation/pages/site_edit_routes.dart` (modify): `newSitePage` and `newSitePane`, each choosing the page or the form by the switch.
- `lib/core/router/app_router.dart`, `lib/features/dive_sites/presentation/pages/site_list_page.dart`, `site_map_page.dart`, `lib/features/dive_sites/presentation/widgets/site_list_content.dart` (modify): the route, the pane, and the openers of Question 1.
- `test/features/dive_sites/presentation/pages/site_detail_page_unlock_harness.dart` (modify): `FakeSiteSave.create`, and `pumpNewSitePage`.

---

### Task 1: `SiteEditSaveService.create`

**Files:**
- Modify: `lib/features/dive_sites/data/services/site_edit_save_service.dart`
- Modify: `test/features/dive_sites/presentation/pages/site_detail_page_unlock_harness.dart` (`FakeSiteSave` implements the service without `Fake`, so it must gain `create`)
- Test: `test/features/dive_sites/data/services/site_edit_save_service_test.dart`

**Interfaces:**
- Produces: `Future<DiveSite> SiteEditSaveService.create({required DiveSite site, required Iterable<String> changedCardIds, Future<void> Function()? alsoWrite})`. Inside `runRecordSitting(table: 'dive_sites', recordId: site.id, ...)`: throws `StateError` when `site.id` is empty or a stored site already has it (checked with a `SELECT 1 FROM dive_sites WHERE id = ?`, as `DiveEditSaveService.create` checks dives); `SiteRepository.createSite(site)` (no classification: types and tags are held lists); then `alsoWrite`; returns the site read back (`getSiteById`), falling back to the created copy.
- Produces: in the harness, `FakeSiteSave.creates`, a list of `({DiveSite site, List<String> cards, bool hasHeldWrites})`, and `create` returning `site` (or throwing `failWith`).

- [ ] **Step 1: Write the failing tests** in `site_edit_save_service_test.dart`, a new group `create`:
  - `creates the site with its id, as one History entry`: `create(site: DiveSite(id: 'n1', diverId: <the test diver>, name: 'Blue Hole', notes: 'Deep'), changedCardIds: ['header', 'notes'])`; `getSiteById('n1')` has the name and notes; exactly one change log operation, source manual, whose label decodes (`RecordEditLabel`) to table `dive_sites`, id `n1`, cards `{header, notes}`, and which holds the `dive_sites` insert.
  - `held writes run after the row, in the same entry`: an `alsoWrite` that reads `getSiteById('n1')` (not null) and adds a feature (`SiteFeatureRepository().addFeature(siteId: 'n1', ..., stampLibrary: false)`); the feature exists afterwards and the one operation holds both.
  - `a held write that throws leaves nothing`: `alsoWrite` throws `StateError`; `create` throws; no `n1` row, no feature, no change log operation once the log settles.
  - `an id already stored is refused`: create `n1` twice; the second throws `StateError` and the first row is unchanged.
  - `an empty id is refused` with nothing written.
- [ ] **Step 2: Run** `flutter test test/features/dive_sites/data/services/site_edit_save_service_test.dart`. Expected: the new group fails to compile (`create` undefined).
- [ ] **Step 3: Implement `create`** beside `save`, with a doc comment in the file's style, and `FakeSiteSave.create` in the harness.
- [ ] **Step 4: Run** the same file. Expected: all pass.
- [ ] **Step 5: Commit** `feat(sites): the site save service creates a site as one sitting`.

### Task 2: A new site's sitting: seed, duplicate, laid-out cards, prefill

**Files:**
- Create: `lib/features/dive_sites/presentation/editing/site_new_sitting.dart`
- Modify: `lib/features/dive_sites/presentation/editing/site_sharing_sitting.dart`
- Test: `test/features/dive_sites/presentation/editing/site_new_sitting_test.dart` (create), `test/features/dive_sites/presentation/editing/site_sharing_sitting_test.dart`

**Interfaces:**
- Consumes: `NewSiteSeed` (`lib/features/dive_sites/domain/models/new_site_seed.dart`), `siteSittingFields`, `siteNameField`, `moveSiteTo`, `applyPlaceLookup`, `scheduleAltitudeAfterMove`, `siteTypesList`, `siteTagsList`, `siteSpeciesList`, `siteFeaturesList`, `setSiteSharing`, `SiteDetailSectionId`, `siteHeaderCardId`.
- Produces: `Future<DiveSite> newSiteSeed(ProviderRead read, {required String id})`: `DiveSite(id: id, diverId: <validatedCurrentDiverIdProvider>, name: '', isShared: <shareByDefaultProvider>)`, nothing else set. A diver or default that cannot be read leaves `diverId` null and `isShared` false, as the form does.
- Produces: `typedef SiteDuplicateSource = ({DiveSite site, List<SiteTypeEntity> types, List<Tag> tags, List<SiteSpeciesEntry> species, List<SiteFeature> features, ItemSharing sharing});` and `Future<SiteDuplicateSource?> readSiteDuplicate(ProviderRead read, String siteId)`: null when the site is gone. Types and tags are the active diver's own (`isOwnOrUnowned`), as the form's `_loadClassification(ownOnly: true)`; the lists come from each `SittingList.read`; `sharing` follows the form's `_loadDuplicateSharing` and library rule (own non-library site: `ItemSharing(everyone: site.isShared, profileIds: <ItemSharesRepository.storedProfileIds>)`; otherwise all or none by `shareByDefaultProvider`).
- Produces: `List<String> newSiteLaidOutCards({NewSiteSeed? seed, SiteDuplicateSource? duplicate, required DiveSite base})`: `[siteHeaderCardId, location, depth, notes]`; a seed with a point adds `altitude`, where its found altitude lands; a duplicate adds every card a copied field or list lands on (the card of each field in `siteSittingFields` whose value differs from [base], `tags` when it has tags, `marineLife` when it has species, `features` when it has features). Order as `SiteDetailSectionId`, no repeats.
- Produces: `Future<void> applyNewSitePrefill(EditSession<DiveSite> session, {NewSiteSeed? seed, SiteDuplicateSource? duplicate, String? duplicateName, required Future<PlaceLookup> Function(GeoPoint point) lookUpPlace, required Future<double?> Function(GeoPoint point) fetchElevation, Duration altitudeDelay = const Duration(seconds: 1)})` (the delay passed to `scheduleAltitudeAfterMove`, so tests need not wait a second), tracked (`session.track`) so Save waits for it:
  - seed name: `session.set(siteNameField, name)`.
  - seed point: `moveSiteTo(session, point)`, then `applyPlaceLookup(session, await lookUpPlace(point), overwrite: false)` (a lookup that throws fills nothing), and `scheduleAltitudeAfterMove(session, fetchElevation)`.
  - duplicate: `session.set(field, field.read(duplicate.site))` for each of `siteSittingFields`, then `siteNameField` to [duplicateName]; after `await session.settled()` (the held lists' loads, which find nothing for a new id), `set` each list to the duplicate's and `setSiteSharing(session, duplicate.sharing, actingDiverId: session.stored.diverId)`.
  - Every step checks `session.isDisposed || session.isFrozen` after each `await` and stops.
- Modifies: `loadSiteSharing(session, read)`: for `session.isNew`, keeps the repository (`_repoKey`) and remembers `ItemSharing(everyone: session.stored.isShared)` as loaded, without reading: no row exists yet to read, and the seed's sharing is the starting record.

- [ ] **Step 1: Write the failing tests.** In `site_new_sitting_test.dart` (test database, a `ProviderContainer` for `read`, overriding `validatedCurrentDiverIdProvider` and `shareByDefaultProvider`):
  - `a seed is the active diver's, shared by default, with nothing else`: `newSiteSeed(read, id: 'n1')` with share-by-default true gives `id 'n1'`, the diver, `isShared` true, empty name, null location, and `EditSession(seed, isNew: true).isDirty` is false.
  - `a seed's name is a change of the header block`: after `applyNewSitePrefill(seed: NewSiteSeed(name: 'Blue Hole'))`, `session.isDirty` and `session.changedCardIds == {'header'}`.
  - `a seed's point fills empty place names and the altitude, as changes`: point (12, 34); `lookUpPlace` answers country "Egypt", region "Red Sea"; `fetchElevation` answers 120 in one case and -5 (below sea level, which fills nothing) in another, with `altitudeDelay: Duration.zero`; after `session.settled()` the country and region are set and `changedCardIds` contains `location`, plus `altitude` for 120 only.
  - Review Focus 1: `a typed country survives a late lookup`: the lookup waits on a `Completer`; the test sets the country to "Sinai" meanwhile; once it completes the country is still "Sinai" and the region is "Red Sea"; `session.isSettled` was false until then.
  - `a lookup that fails fills nothing`: `lookUpPlace` throws; the location is set, the country stays null, nothing is thrown.
  - Review Focus 2: `a duplicate's lists are set once the loads settle, and Save waits for them`: a stored site `s1` with a type, a tag, a species and a feature; `readSiteDuplicate(read, 's1')`; a sitting on a seed; after `applyNewSitePrefill(duplicate: ..., duplicateName: 'Copy of Lake')` without awaiting, `session.isSettled` is false; after `await session.settled()`, each list's `current` holds the copied rows and `changedCardIds` contains `header`, `tags`, `marineLife`, `features` and every card whose field differs.
  - Review Focus 4: `a duplicate of another profile's or a library site is shared as a new site is`: `readSiteDuplicate` on a site of diver `other` gives `sharing` all when share-by-default is on and none when off; on a library site (`sharedLibraryId: 'L'`) the same; after the prefill the working site's `sharedLibraryId` is null and its notes and rating are the original's.
  - `a duplicate keeps the diver's own sharing with named profiles`: own site, `isShared` false, stored profile ids `{p2}`: `sharing == ItemSharing(everyone: false, profileIds: {'p2'})`.
  - `a duplicate of a site that is gone reads null`.
  - `the laid-out cards`: no seed gives `[header, location, depth, notes]`; a point seed adds `altitude`; a duplicate with a hazard and features adds `hazards` and `features`.
  - In `site_sharing_sitting_test.dart`: `a new site's sharing is the seed's, read from nowhere`: a repository fake whose `sharingOf` throws; `loadSiteSharing` on `EditSession(DiveSite(id: 'n1', isShared: true), isNew: true)` leaves `siteSharingLoaded == ItemSharing(everyone: true)`, `siteSharingUnread` false, and `setSiteSharing(..., ItemSharing.none)` holds a change.
- [ ] **Step 2: Run** `flutter test test/features/dive_sites/presentation/editing/site_new_sitting_test.dart test/features/dive_sites/presentation/editing/site_sharing_sitting_test.dart`. Expected: compile failure for the new names, and the sharing test fails on the read.
- [ ] **Step 3: Implement** `site_new_sitting.dart` (with a library doc comment naming issue #4527, phase 2, plan 6) and the `isNew` branch of `loadSiteSharing`.
- [ ] **Step 4: Run** the same two files. Expected: all pass.
- [ ] **Step 5: Commit** `feat(sites): a new site's seed, a duplicate's copy and their prefill, as changes`.

### Task 3: The new-site page

**Files:**
- Create: `lib/features/dive_sites/presentation/pages/site_detail_page_creating.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (the `newSite` constructor and fields, about 20 lines; a branch at the top of `_SiteDetailPageState.build` to the loader; the `part` directive; `_SiteDetailPageCreating` in `_SiteDetailContentState`'s mixins after `_SiteDetailPageEditing`; `unlockedActions: isCreating ? const [] : [...]`)
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page_editing.dart` (`_framed`: a section with no edit card returns null while `isCreating`, two lines)
- Modify: `test/features/dive_sites/presentation/pages/site_detail_page_unlock_harness.dart` (`pumpNewSitePage`)
- Test: `test/features/dive_sites/presentation/pages/site_detail_page_new_test.dart` (create)

**Interfaces:**
- Consumes: Task 1's `create`, Task 2's `newSiteSeed`, `readSiteDuplicate`, `newSiteLaidOutCards`, `applyNewSitePrefill`; `captureRulesAfterCreate`; `locationServiceProvider`, `placeNameLanguageProvider`, `elevationServiceProvider`.
- Produces: `SiteDetailPage.newSite({Key? key, NewSiteSeed? seed, String? duplicateOfId, bool embedded = false, void Function(String siteId)? onCreated, VoidCallback? onCreateCancelled})`, with `unlockEditing` true. On `SiteDetailPage`: `final ({NewSiteSeed? seed, String? duplicateOfId})? newSite;`, `onCreated`, `onCreateCancelled`; `siteId` is `''` for a new site and never read while `newSite` is set.
- Produces: in the part file, `_NewSiteLoader` (a `ConsumerStatefulWidget`): makes the id once (`const Uuid().v4()`), reads the seed and, for a duplicate, `readSiteDuplicate`; shows the loading scaffold meanwhile (title `diveSites_edit_appBar_newSite` or `_duplicateSite`), the existing not-found scaffold for a duplicate whose site is gone, then `_SiteDetailContent(site: seed, siteId: seed.id, embedded:, unlockEditing: true, newSite: <the request and the read source>)`. `_SiteDetailContent` gains `final _NewSite? newSite;` (a small private class in the part file holding the seed request, the duplicate source and the callbacks).
- Produces: `mixin _SiteDetailPageCreating on ConsumerState<_SiteDetailContent>, _SiteDetailPageEditing`:
  - `isCreating => widget.newSite != null`; `editingTitle` returns the form's titles while creating, else `super`.
  - on first build (`initState` post-frame): `editController.unlock(widget.site, laidOut: newSiteLaidOutCards(...))`, then `applyNewSitePrefill` with `lookUpPlace` from `locationServiceProvider.reverseGeocode(..., languageCode: placeNameLanguageProvider)`, `fetchElevation` from `elevationServiceProvider.fetchElevation`, and `duplicateName: l10n.diveSites_edit_duplicateName(source.site.name)`.
  - `saveSitting` while creating: a seed whose diver could not be read when the page opened takes the diver active now (`validatedCurrentDiverIdProvider`, read before the first `await`, as the form does at Save); then `SiteEditSaveService.create(site: session.applyTo(session.stored), changedCardIds: session.changedCardIds, alsoWrite: session.hasHeldWrites ? () async { await session.runHeldWrites(beforeRecord: true); await session.runHeldWrites(); } : null)` inside `undoMediaOnFailure`; then sets `_created`; then, guarded each, the site list refresh and `ref.invalidate` of `sitesProvider` and `sitesWithCountsProvider`, as the form does. Otherwise `super.saveSitting`.
  - `saveNewRecord`: reads `captureRulesAfterCreate(context, ref)` first; `controller.save()`; on refusal or failure the snack bars of `_saveNewDive`; once created, runs the rules (`subject: RuleSubject.sites, ids: [id]`), then `onCreated(id)` when embedded, else `context.pop(id)`. While the rules run the page shows the created site locked under `AbsorbPointer`, as the dive's does.
  - `cancelNewRecord`: `cancelSitting(context, editController)` (asks only when dirty), then leaves: `onCreateCancelled` when embedded, else `context.pop()` when it can, else `context.go('/sites')`.
  - A sitting that ends without a create while the page is current leaves the same way (call 9).

- [ ] **Step 1: Write the failing tests** in `site_detail_page_new_test.dart` with `pumpNewSitePage(tester, {NewSiteSeed? seed, String? duplicateOfId, bool embedded = false})` (it records `onCreated`, `onCreateCancelled` and the popped value, and overrides `locationServiceProvider` and `elevationServiceProvider` with fakes, so no test reaches the network):
  - `a new site opens unlocked with the header and starter cards open`: `RecordEditBar` shown, titled `diveSites_edit_appBar_newSite`; the header, Location, Depth and Notes editors open; no menu button in the bar.
  - `Save waits for the first entry`: Save disabled; after typing a name, enabled.
  - `a name from the picker is a change`: `seed: NewSiteSeed(name: 'Blue Hole')`: the header shows its dot and Save is enabled at once.
  - `calculated cards are not shown`: with every section switched on, no Dive Photos, Tide, Seascape, Reef Health or Dive Statistics card.
  - Review Focus 5: `an untouched new site leaves without asking` (Cancel: no discard dialog, `onCreateCancelled` or a pop, `save.creates` empty); `a seeded name asks before leaving` (Cancel shows the discard dialog; Keep editing stays; Discard leaves with nothing created).
  - `Save creates the site and pops with its id`: type a name, Save: `save.creates.single.site.name` is it, `cards` holds `header`, and the page popped with the seed's id. Embedded: `onCreated` gets the id.
  - Review Focus 3: `a Save that fails keeps everything`: `save.failWith = StateError(...)`; Save shows `recordEdit_saveFailed`, the bar stays with the name still typed; clear `failWith`, Save again: one more create, the same id.
  - `a duplicate opens titled Duplicate, prefilled as changes`: a stored site with a description; `duplicateOfId`: title `diveSites_edit_appBar_duplicateSite`, the name field reads "Copy of ...", the description card is open with its dot, Save enabled at once.
  - Review Focus 2 at the page: `Save on a duplicate waits for its lists`: Save tapped at once: the one create's `hasHeldWrites` is true.
  - `a duplicate of a site that is gone says so`: the not-found body, no bar.
  - `nothing is written before Save`: open, type, then Cancel and Discard: `save.creates` and `save.calls` empty.
- [ ] **Step 2: Run** `flutter test test/features/dive_sites/presentation/pages/site_detail_page_new_test.dart`. Expected: compile failure (`SiteDetailPage.newSite` undefined).
- [ ] **Step 3: Implement** the part file, the small changes to `site_detail_page.dart` and `_framed`, and `pumpNewSitePage`.
- [ ] **Step 4: Run** `flutter test test/features/dive_sites/presentation/pages/site_detail_page_new_test.dart test/features/dive_sites/presentation/pages/site_detail_page_unlock_test.dart test/features/dive_sites/presentation/pages/site_detail_page_reader_test.dart`. Expected: all pass (the last two prove an existing site's page did not change).
- [ ] **Step 5: Commit** `feat(sites): a new site and a duplicate open unlocked on the site page, behind the switch`.

### Task 4: Routes, the list pane and the openers

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_routes.dart`
- Modify: `lib/core/router/app_router.dart` (the `newSite` route's builder, and `onExit: confirmLeaveRecordSitting` on it, as `newDive` has)
- Modify: `lib/features/dive_sites/presentation/pages/site_list_page.dart` (both `createBuilder`s, and the phone Add button of Question 1)
- Modify: `lib/features/dive_sites/presentation/pages/site_map_page.dart`, `lib/features/dive_sites/presentation/widgets/site_list_content.dart` (Question 1's other two openers)
- Test: `test/core/router/app_router_test.dart`, `test/features/dive_sites/presentation/pages/site_list_page_test.dart`

**Interfaces:**
- Produces: `Widget newSitePage(Object? extra, {String? duplicateOfId, bool unlockEditing = kUnlockSiteEditing})`: with the switch, `SiteDetailPage.newSite(seed: NewSiteSeed.fromRouteExtra(extra), duplicateOfId: duplicateOfId)`; without, `SiteEditPage.fromNewSiteExtra(extra, duplicateOfId: duplicateOfId)`.
- Produces: `Widget newSitePane(BuildContext context, void Function(String savedId) onSaved, VoidCallback onCancel, {bool unlockEditing = kUnlockSiteEditing})`: `SiteDetailPage.newSite(embedded: true, onCreated: onSaved, onCreateCancelled: onCancel)`, or the form as today.
- Produces: `Future<void> openNewSite(BuildContext context, {Object? extra, bool unlockEditing = kUnlockSiteEditing})` in `site_edit_routes.dart`: pushes `/sites/new` and, with the switch on, opens `/sites/<id>` with the id it gets back (Question 1); with it off, pushes and ignores the result, as today. The three openers call it in place of `context.push('/sites/new')`. The site picker and Duplicate keep their own code.

- [ ] **Step 1: Write the failing tests.**
  - `app_router_test.dart`: `the new site address opens the page with the switch on`: `newSitePage(null, unlockEditing: true)` is a `SiteDetailPage` with `newSite` set; with `duplicateOfId: 's1'` it carries it; `newSitePage(NewSiteSeed(name: 'X'), unlockEditing: false)` is a `SiteEditPage`; the `newSite` route's `onExit` is `confirmLeaveRecordSitting` and its builder uses `newSitePage`.
  - `site_list_page_test.dart`: `the pane's new site is the page with the switch on`: `newSitePane(..., unlockEditing: true)` is a `SiteDetailPage` with `embedded` and `newSite` set, and its `onCreated` is the pane's `onSaved`; with the switch off, a `SiteEditPage`.
  - `site_list_page_test.dart`: `Add on a phone opens the new site once created` (switch on): a router whose `/sites/new` pops `'n1'` at once; after tapping Add, the location is `/sites/n1`.
- [ ] **Step 2: Run** `flutter test test/core/router/app_router_test.dart test/features/dive_sites/presentation/pages/site_list_page_test.dart`. Expected: compile failure for the new names.
- [ ] **Step 3: Implement** `newSitePage`, `newSitePane`, `openNewSite`, the route and the four call sites.
- [ ] **Step 4: Run** the same two files. Expected: all pass.
- [ ] **Step 5: Commit** `feat(sites): /sites/new, the list pane and the Add buttons open the new site page behind the switch`.

## After the plan

- Screenshots for the PR (light and dark, phone and desktop): a new site with the starter cards open, one from the picker with its name, and a duplicate, from a build with `--dart-define=UNLOCK_SITE_EDITING=true` (the mac-shots route).
- The PR body: `Refs #4527`; it names `site_detail_page.dart` as still over the size guard (it was before), and says it changes no file under `lib/shared/widgets/record_editing/`.
- For plan 7: `diveSites_edit_snackbar_featuresNotCopied` loses its last reader when the form is deleted.

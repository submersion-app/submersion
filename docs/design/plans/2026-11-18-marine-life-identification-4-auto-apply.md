# Marine life identification piece 4: Find species, auto-apply and review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver analyse a whole dive's photos and videos on request, tag confident matches automatically as "not yet confirmed" tags, and settle everything the app found on one review page.

**Architecture:** Three nullable columns on the synced `media_species` table carry the app's mark; confirming and rejecting live in the media layer's `SpeciesTaggingService`, so every platform can settle a tag. Applying is a pure rule beside the reconcile rules, called by `MediaIdentificationService` after each item; a Find species run feeds a dive's media into that service through a second, lower-priority lane. One review page, scoped to a dive or the whole log, holds its changes until Save.

**Tech Stack:** Flutter, Riverpod 3, Drift (schema 378), SharedPreferences, the existing sync serializer and change log.

**Spec:** [docs/design/specs/2026-11-18-marine-life-identification-4-auto-apply-design.md](../specs/2026-11-18-marine-life-identification-4-auto-apply-design.md). Read it first; this plan does not repeat its reasoning.

## Global Constraints

- Schema version 378 (main is at 377); `minimumCompatibleSchemaVersion` rises from 350 to 378.
- A null in any of the three new columns means "the diver's own tag". No backfill.
- Auto-apply reads only the stored `confident` flag; it never computes a bar. It considers only undecided identifications; on a video only nameable tracks of a video whose `run.scanComplete` is true.
- Analysis, Find species, suggestions and the two settings follow `marineLifeIdEnabled` and an installed pack. The tag mark, Confirm, Remove, the guards, the review page, the dive card's review link and the Species page banner never read `marineLifeIdEnabled` or the pack.
- Settings are per device (`SettingsKeys`): auto-apply off by default; sighting timing "when I confirm" by default.
- Every new user-facing string goes into all 11 ARB files. No emojis. No em-dashes.
- Each automatic apply from the viewer is one `ChangeLogScope.automatic` operation; a run's applies are one operation; the review page's Save is one `ChangeLogScope.bulk` operation.
- New repository write methods need entries in `test/architecture/agent_write_coverage_exempt.dart` (the pre-push hook runs that guard).
- After changing the table: `dart run build_runner build --delete-conflicting-outputs` (unfiltered, in the background) and `dart run tool/generate_sql_column_notes.dart`.
- Run only the test files this plan names, by path. Never a folder.

## Review Focus

1. A tag the app writes while the same photo's sitting is open in the viewer, then the diver saves: the app's tag must survive unchanged and the diver's edits apply on top (test in Task 4).
2. A peer's payload that omits the new keys (an older or partial row): the merge must keep the local values, while an explicit null clears them (test in Task 2).
3. The same species applied "straight away" on two photos of one dive: the second links to the first's sighting and records that it did not create it; removing the first keeps the sighting (test in Task 3).
4. Another logbook opened, or the dive deleted, while a run is going: the run stops without writing into the wrong logbook and without throwing (test in Task 10).
5. A device with `marineLifeIdEnabled` false that receives an unconfirmed tag: the chip, the sheet's Confirm, the card link, the banner and the review page all work, with thumbnails and no Suggested section (tests in Tasks 5, 12 and 13).

---

### Task 1: Schema 378, the tag columns and the repository

**Files:**
- Modify: `lib/core/database/tables/media_tables.dart` (class `MediaSpecies`, about line 179)
- Create: `lib/core/database/migrations/helpers/app_tag_migrations.dart` (a `part of '../app_database_migrations.dart'`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (add the part)
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (rung 378)
- Modify: `lib/core/database/migrations/before_open_table_backstops.dart` (backstop 378)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion = 378`, `migrationVersions` gains 378, `minimumCompatibleSchemaVersion = 378` with a doc paragraph in the style of the #4337 raise)
- Modify: `lib/features/media/domain/entities/media_item.dart` (`MediaSpeciesTag`)
- Modify: `lib/features/media/domain/entities/species_tag_chip.dart` (`SpeciesTagChip`)
- Modify: `lib/features/media/data/repositories/media_species_repository.dart`
- Modify: `lib/features/agent_access/data/resources/sql_column_notes.generated.dart` (regenerated)
- Modify: `test/architecture/agent_write_coverage_exempt.dart`
- Test: `test/core/database/migrations/media_species_app_tag_columns_test.dart`
- Test: `test/features/media/data/media_species_repository_app_tag_test.dart`

**Interfaces:**
- Produces, on `MediaSpecies`: `IntColumn get unconfirmed`, `IntColumn get createdSighting`, `IntColumn get createdSpecies`, each `integer().nullable()()`, SQL names `unconfirmed`, `created_sighting`, `created_species`. Doc comment on the class: no longer write-once.
- Produces, on `MediaSpeciesTag`: `final bool unconfirmed; final bool createdSighting; final bool createdSpecies; final String? hlc;` (defaults false/null; `copyWith` covers them).
- Produces, on `SpeciesTagChip`: `final bool unconfirmed` (default false), in `copyWith` and `props`.
- Produces, on `MediaSpeciesRepository`:
  - `addTag({required String mediaId, required String speciesId, String? sightingId, bool unconfirmed = false, bool createdSighting = false, bool createdSpecies = false})`: writes 1 or null.
  - `Future<MediaSpeciesTag?> findTag(String mediaId, String speciesId)` (public form of `_findTag` mapped to the entity).
  - `Future<void> confirmTag({required String mediaId, required String speciesId, String? sightingId})`: sets the three columns to null and, when given, `sighting_id`; `markRecordPending('mediaSpecies', id, now)`; `SyncEventBus.notifyLocalChange()`. No-op when the tag is absent or already confirmed.
  - `Future<List<MediaSpeciesTag>> unconfirmedTags({String? diveId})`: every unconfirmed tag, or those on media of `diveId`.
  - `getTagChipsForMedia` selects `ms.unconfirmed` and fills `SpeciesTagChip.unconfirmed`.

- [ ] **Step 1: Write the failing migration test** `media_species_app_tag_columns_test.dart`: open a database built at 377 (follow the existing v377 scanned-ranges migration test's setup), upgrade, and assert `PRAGMA table_info(media_species)` lists `unconfirmed`, `created_sighting`, `created_species`; assert an existing row reads null in all three; assert `AppDatabase.minimumCompatibleSchemaVersion == 378` and `AppDatabase.currentSchemaVersion == 378`.
- [ ] **Step 2: Write the failing repository test** `media_species_repository_app_tag_test.dart`:
  - `addTag(unconfirmed: true, createdSighting: true)` then `findTag` returns `unconfirmed == true`, `createdSighting == true`, `createdSpecies == false`.
  - `confirmTag(sightingId: 's1')` clears all three, sets `sightingId == 's1'`, and leaves a pending sync record for the tag id.
  - `unconfirmedTags(diveId: 'd1')` returns only unconfirmed tags on d1's media.
  - `getTagChipsForMedia` returns `unconfirmed: true` for the app's tag and false for a hand tag.
- [ ] **Step 3: Run both tests; expect FAIL** (missing columns and methods).
  Run: `flutter test test/core/database/migrations/media_species_app_tag_columns_test.dart test/features/media/data/media_species_repository_app_tag_test.dart`
- [ ] **Step 4: Implement** the columns, the helper `_assertMediaSpeciesAppTagColumns()` (three `_addColumnIfMissing('media_species', <name>, 'INTEGER')`), the rung `if (from < 378) ...; reportProgress()`, the backstop call, the version and floor changes, the entity and repository changes. Then run build_runner in the background and wait for it; run `dart run tool/generate_sql_column_notes.dart`; add the three new repository write methods to the agent write exemptions.
- [ ] **Step 5: Run both tests; expect PASS.** Then `flutter analyze` (whole repo, expect no issues).
- [ ] **Step 6: Commit** `feat(media): mark species tags the app applied, schema 378`.

### Task 2: Sync of the tag columns

**Files:**
- Modify (only if the test shows a gap): `lib/core/services/sync/sync_data_serializer.dart`, `lib/core/services/sync/sync_service.dart`
- Test: `test/core/services/sync/media_species_app_tag_sync_test.dart`

**Interfaces:**
- Consumes: Task 1's columns and `confirmTag`.

- [ ] **Step 1: Write the failing test.** Follow the closest existing mediaSpecies or mediaPeople sync test for the harness. Cases:
  - `exports the three columns`: an unconfirmed tag exported by `_exportMediaSpecies` (through the serializer's public export) carries `unconfirmed: 1, createdSighting: 1, createdSpecies: null`.
  - `merge applies an explicit null`: local row unconfirmed; incoming same id, newer hlc, `unconfirmed: null` explicitly; after merge the local row is confirmed.
  - `merge keeps local values for omitted keys`: incoming payload without the three keys at a tie hlc; local values stay.
  - `strictly older remote copy is skipped`: local confirmed with a newer hlc; incoming unconfirmed with an older hlc; local stays confirmed.
- [ ] **Step 2: Run; expect FAIL or PASS per case.** A case that already passes stays as a pin.
  Run: `flutter test test/core/services/sync/media_species_app_tag_sync_test.dart`
- [ ] **Step 3: Fix only what fails** (the merge's omitted-key refill must cover the new columns).
- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** `feat(sync): carry the app-applied tag columns`.

### Task 3: Applying, confirming and rejecting a tag, with the guards

**Files:**
- Create: `lib/features/media/domain/services/app_tag_guards.dart` (pure)
- Modify: `lib/features/media/data/services/species_tagging_service.dart`
- Modify: `test/architecture/agent_write_coverage_exempt.dart` (if the new service writes count)
- Test: `test/features/media/domain/app_tag_guards_test.dart`
- Test: `test/features/media/data/species_tagging_service_app_tag_test.dart`

**Interfaces:**
- Produces, pure:
  - `bool mayRemoveCreatedSighting({required Sighting sighting, required int otherTagsPointingAtIt})`: true only when `otherTagsPointingAtIt == 0`, `sighting.count == 1`, `sighting.abundance` is the exact-count value (the domain's equivalent of a null column), and `sighting.notes.isEmpty`.
  - `bool mayRemoveCreatedSpecies({required Species species, required String? speciesHlc, required String? tagHlc, required bool inUseElsewhere})`: true only when `!species.isBuiltIn`, `!inUseElsewhere`, and `speciesHlc` is null or `speciesHlc.compareTo(tagHlc ?? '') <= 0` (the species has not been written since the tag was).
- Produces, on `SpeciesTaggingService` (constructor unchanged):
  - `enum SightingTiming { onConfirm, straightAway }` in `lib/features/media/domain/value_objects/sighting_timing.dart`.
  - `Future<MediaSpeciesTag> applyAppTag({required String mediaId, required String speciesId, required SightingTiming timing, required bool createdSpecies})`: no-op returning the existing tag when one exists. `onConfirm`: links the dive's existing sighting of the species if any, else no sighting. `straightAway`: finds or creates it, `createdSighting` true only when created. Site-only media: no sighting.
  - `Future<void> confirmTag({required String mediaId, required String speciesId, required SightingTiming timing})`: on a dive photo with no linked sighting, finds or creates the sighting and links it (regardless of timing: a confirmed tag behaves as a hand tag); then `MediaSpeciesRepository.confirmTag`.
  - `Future<void> rejectTag({required String mediaId, required String speciesId})`: reads the tag; removes it; if it was unconfirmed and `createdSighting`, removes the sighting when `mayRemoveCreatedSighting`; then if unconfirmed and `createdSpecies`, removes the species through `SpeciesRepository.deleteSpecies` when `mayRemoveCreatedSpecies` (with `inUseElsewhere` = `isSpeciesInUse` or any `site_species` row). A confirmed tag: plain `untagPhoto`.
  - `untagPhoto` stays as is (used for hand tags).

- [ ] **Step 1: Write the failing guard tests**, one per guard failing alone and one all-pass, for both functions (for example `keeps a sighting another tag points at`, `keeps a sighting whose count changed`, `keeps a species written after the tag`, `keeps a built-in species`).
- [ ] **Step 2: Write the failing service tests** against an in-memory database (follow the existing `species_tagging_service_test.dart` setup):
  - `applyAppTag onConfirm with no sighting writes an unconfirmed tag and no sighting`.
  - `applyAppTag onConfirm links an existing sighting without creating one`.
  - `applyAppTag straightAway creates the sighting and records it`.
  - `second straightAway tag of the same species links and does not record creation` (Review Focus 3).
  - `confirmTag logs the sighting and clears the marks`.
  - `rejectTag removes a created sighting and species when nothing else uses them`.
  - `rejectTag keeps the sighting when another tag points at it` (Review Focus 3).
  - `rejectTag on a confirmed tag never removes the sighting`.
- [ ] **Step 3: Run; expect FAIL.**
  Run: `flutter test test/features/media/domain/app_tag_guards_test.dart test/features/media/data/species_tagging_service_app_tag_test.dart`
- [ ] **Step 4: Implement** the guards, the enum and the three methods. Count "other tags pointing at it" with a `media_species` query on `sighting_id` excluding the tag being removed.
- [ ] **Step 5: Run; expect PASS.**
- [ ] **Step 6: Commit** `feat(media): confirm and reject tags the app applied, with sighting and species guards`.

### Task 4: Confirm and reject through the photo sitting

**Files:**
- Modify: `lib/features/media/domain/value_objects/photo_tag_edits.dart` (`SpeciesTagEdits`)
- Modify: `lib/features/media/data/services/photo_edit_save_service.dart` (`_writeSpecies`)
- Modify: `lib/features/media/presentation/editing/photo_edit_fields.dart` (only if `applyTo` callers need it)
- Test: `test/features/media/domain/photo_tag_edits_confirm_test.dart`
- Test: `test/features/media/data/photo_edit_save_service_app_tag_test.dart`

**Interfaces:**
- Produces, on `SpeciesTagEdits`: `final Set<String> confirmed` (species ids confirmed in the sitting); `SpeciesTagEdits confirming(String speciesId)`; `applyTo` returns the confirmed chips with `unconfirmed: false`; `isEmpty` counts `confirmed`.
- Produces, in `PhotoEditSaveService._writeSpecies`: for a species removed whose stored chip was unconfirmed, `rejectTag`; for one kept whose `before` chip is unconfirmed and `after` chip is not, `confirmTag` with the device's `SightingTiming`. The save service gains a `SightingTiming Function() sightingTiming` constructor argument, wired in its provider from Task 7's preference.

- [ ] **Step 1: Write the failing tests**: `confirming marks the chip confirmed in applyTo`; `untagging an unconfirmed chip in a sitting rejects it on save` (guards run); `confirming in a sitting confirms on save`; `a tag the app wrote under an open sitting survives the save and the diver's edits apply` (Review Focus 1: stored gains an unconfirmed tag after the sitting opened; the sitting added another species; after save both exist and the app's is still unconfirmed).
- [ ] **Step 2: Run; expect FAIL.**
  Run: `flutter test test/features/media/domain/photo_tag_edits_confirm_test.dart test/features/media/data/photo_edit_save_service_app_tag_test.dart`
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** `feat(media): confirm or remove the app's tags in a photo's sitting`.

### Task 5: The viewer's unconfirmed look and Confirm

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_species_chips_row.dart`
- Modify: `lib/features/media/presentation/widgets/media_tagged_species_section.dart`
- Modify: `lib/l10n/arb/app_en.arb` (keys below; other languages in Task 14)
- Test: `test/features/media/presentation/media_species_chips_row_unconfirmed_test.dart`
- Test: `test/features/media/presentation/media_tagged_species_section_confirm_test.dart`

**Interfaces:**
- Consumes: `SpeciesTagChip.unconfirmed` (Task 1), `SpeciesTagEdits.confirming` (Task 4).
- New strings: `media_species_unconfirmed_semantics` ("{name}, tagged by the app, not yet confirmed"), `media_species_confirm` ("Confirm").

- [ ] **Step 1: Write the failing widget tests**: an unconfirmed chip is drawn after confirmed tags and before suggestions, with a dashed border (find by a `Key('unconfirmed-chip-<speciesId>')`) and the semantics label; it is inert on a locked photo; the section lists unconfirmed first with a Confirm button that calls `confirming` on the sitting; all of it with `marineLifeIdEnabled = false` (Review Focus 5; restore the flag with `resetMarineLifeIdEnabled` in `addTearDown`).
- [ ] **Step 2: Run; expect FAIL.**
  Run: `flutter test test/features/media/presentation/media_species_chips_row_unconfirmed_test.dart test/features/media/presentation/media_tagged_species_section_confirm_test.dart`
- [ ] **Step 3: Implement** with a dashed outline (a `CustomPainter` or the dashed border helper if the project has one; search `Dashed` under `lib/shared/widgets/` first) and a small `Icons.auto_awesome_outlined` glyph.
- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** `feat(media): show the app's unconfirmed tags apart in the viewer`.

### Task 6: Video labels for unconfirmed tags

**Files:**
- Modify: `lib/features/species_id/domain/services/track_labels.dart` (`labelKind`, `labelsAt`)
- Modify: `lib/features/species_id/presentation/widgets/video_identification_layer.dart` (pass the set)
- Test: `test/features/species_id/domain/track_labels_unconfirmed_test.dart`

**Interfaces:**
- Produces: `labelKind(track, {required bool playing, int minDotMs = 1000, bool unconfirmed = false})`: an accepted track with `unconfirmed` gives `TrackLabelKind.confident`. `labelsAt(shown, ms, {required bool playing, int maxLabels = 6, Set<String> unconfirmedSpeciesIds = const {}})`: a track is unconfirmed when its `decidedSpeciesId` is in the set; its label carries `candidate: track.top`.
- The layer builds the set from the shown chips (`speciesChipsShown`) whose `unconfirmed` is true.

- [ ] **Step 1: Write the failing tests**: `an accepted track whose species is unconfirmed is outlined`; `it turns filled once the species leaves the set`; `playing still shows it` (confident shows while playing).
- [ ] **Step 2: Run; expect FAIL.**
  Run: `flutter test test/features/species_id/domain/track_labels_unconfirmed_test.dart`
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** `feat(species-id): keep the app's name outlined over a fish until its tag is confirmed`.

### Task 7: The two settings

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`SettingsKeys.speciesIdAutoApply = 'species_id_auto_apply'`, `SettingsKeys.speciesIdSightingTiming = 'species_id_sighting_timing'`, both device-local)
- Modify: `lib/features/species_id/presentation/providers/species_id_providers.dart`
- Modify: `lib/core/providers/root_overrides.dart`
- Create: `lib/features/species_id/presentation/widgets/auto_apply_settings_section.dart`
- Modify: `lib/features/species_id/presentation/pages/marine_life_identification_page.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/species_id/presentation/auto_apply_settings_section_test.dart`

**Interfaces:**
- Produces: `autoApplyProvider` (`StateNotifierProvider<AutoApplyNotifier, bool>`, unstored false, stored default false) and `sightingTimingProvider` (`StateNotifierProvider<SightingTimingNotifier, SightingTiming>`, default `onConfirm`, stored by enum name, unknown name reads as `onConfirm`). If `DeviceBadgeToggleNotifier` cannot take a false default, give it an optional `defaultValue` parameter defaulting to true.
- Produces: `bool packCanApply(NamingConfig naming)`: `naming.confidentScore <= 1 || naming.confidentScoreNoLocation <= 1`; `bool packAppliesOnlyWithPlace(NamingConfig naming)`: `naming.confidentScore <= 1 && naming.confidentScoreNoLocation > 1`. Pure, in `lib/features/species_id/domain/services/auto_apply_rules.dart` (created here, extended in Task 8).
- Copy (English, from the spec): title "Tag confident matches automatically"; description "The app adds a species tag when it is sure of a match. You confirm each one in Species to review."; never line "The installed model isn't yet sure enough of any species to tag on its own. Suggestions still appear for you to add."; place note "Only for photos and videos with a location."; "Log sightings for these tags"; "When I confirm the tag"; "Straight away".

- [ ] **Step 1: Write the failing tests**: rows hidden with no pack; switch disabled and off, with the never line, when both bars exceed 1; enabled with the place note when only `confidentScore <= 1`; the timing choice disabled while the switch is off; choices persist through SharedPreferences (mock prefs, restored in tearDown); `packCanApply` and `packAppliesOnlyWithPlace` truth table.
- [ ] **Step 2: Run; expect FAIL.**
  Run: `flutter test test/features/species_id/presentation/auto_apply_settings_section_test.dart`
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** `feat(species-id): settings to tag confident matches and choose when they log sightings`.

### Task 8: The apply rule and the applier

**Files:**
- Modify: `lib/features/species_id/domain/services/auto_apply_rules.dart`
- Create: `lib/features/species_id/data/services/auto_applier.dart`
- Modify: `lib/features/species_id/data/services/media_identification_service.dart` (call the applier after `reconcile` in `_process`)
- Modify: `lib/features/species_id/presentation/providers/species_id_providers.dart` (wire it)
- Modify: `lib/core/services/change_log/change_log_scope.dart` (`ChangeLogLabels.marineLifeId = 'marine_life_id'`)
- Modify: `lib/features/change_log/presentation/change_log_labels.dart`, `lib/l10n/arb/app_en.arb` (`changeLog_label_marineLifeId`: "Marine life identification")
- Test: `test/features/species_id/domain/auto_apply_rules_test.dart`
- Test: `test/features/species_id/data/auto_applier_test.dart`
- Test: `test/features/species_id/data/media_identification_service_apply_test.dart`

**Interfaces:**
- Produces, pure: `class SpeciesToApply { final NamedCandidate candidate; final List<String> identificationIds; }` and `List<SpeciesToApply> identificationsToApply(List<MediaIdentification> all, List<TaggedSpecies> tagged, {required bool isVideo, required bool scanComplete})`: undecided, `confident`, has a top; on video only tracks that are `suggestable` and only when `scanComplete`; grouped by top candidate (same key as `groupSuggestions`); species already tagged (by `candidateMatches`) skipped.
- Produces: `class AutoApplier` with `Future<int> apply(String mediaId, {required bool isVideo})` returning how many species it tagged. It reads identifications, run and tagged species from `MediaIdentificationRepository`; resolves each candidate with `SuggestionAcceptor`, recording `createdSpecies` when the acceptor created the species (give `SuggestionAcceptor.resolve` a return of `({Species species, bool created})`); writes with `SpeciesTaggingService.applyAppTag(timing: <preference>)`; then `MediaIdentificationService.reconcile(mediaId)`. It does nothing unless `autoApply` is on and `marineLifeIdEnabled`.
- Produces: `AutoApplier.applyInScope(...)`: wraps a single item's writes in `ChangeLogScope.automatic(label: ChangeLogLabels.marineLifeId)`. When a zone-level run collector is active (Task 10), it instead records the pending writes for the run to flush.
- Service hook: `_process` calls `onItemSettled(item)` (a constructor callback, default no-op) after `reconcile`, for photos always and for videos when the job is not put back. It is also called when no pack is installed (the early return for a missing pack reconciles and settles instead of returning at once), so stored confident rows are applied after the model is removed, as the spec proposes.

- [ ] **Step 1: Write the failing rule tests**: `skips decided`, `skips not confident`, `skips a video whose scan is incomplete`, `skips an unsuggestable track`, `groups two confident crops of one species`, `skips a species already tagged`.
- [ ] **Step 2: Write the failing applier tests** (in-memory DB, fake service callbacks): `tags confident species unconfirmed and reconciles them to accepted`; `records createdSpecies when the acceptor created the species`; `does nothing with the setting off`; `does nothing with the feature off`; `one change log operation labelled marine_life_id per item`.
- [ ] **Step 3: Write the failing service test**: `onItemSettled runs after reconcile for a photo needing nothing`, `not for a video put back mid-scan`, and `runs with no pack installed`.
- [ ] **Step 4: Run; expect FAIL.**
  Run: `flutter test test/features/species_id/domain/auto_apply_rules_test.dart test/features/species_id/data/auto_applier_test.dart test/features/species_id/data/media_identification_service_apply_test.dart`
- [ ] **Step 5: Implement.** Update `suggestion_acceptor.dart` callers for the new return type.
- [ ] **Step 6: Run; expect PASS.** Also run `test/features/species_id/data/media_identification_service_test.dart` (touched file's existing test).
- [ ] **Step 7: Commit** `feat(species-id): tag confident matches automatically`.

### Task 9: The run lane in the identification service

**Files:**
- Modify: `lib/features/species_id/data/services/media_identification_service.dart`
- Modify: `lib/features/species_id/data/services/media_identification_video.dart` (job resolver)
- Modify: `lib/features/species_id/presentation/providers/species_id_providers.dart` (split gate)
- Test: `test/features/species_id/data/media_identification_service_run_lane_test.dart`

**Interfaces:**
- Produces: `enum RunItemOutcome { done, unreadable, tooHot, notForeground, failed, skipped }`.
- Produces: `Future<RunItemOutcome> requestFromRun(MediaItem item, {GeoPoint? location, required Future<IdentificationImage?> Function(MediaItem) resolveImage, required Future<VideoFileReader?> Function(MediaItem) resolveVideo})`.
- `_Job` gains `final bool fromRun`, the two resolver overrides, and a `Completer<RunItemOutcome>`. `_pump` takes the newest viewer job first; a run job only when no viewer job waits. `cancelPending` from the viewer never drops a run job; `cancelRun(String mediaId)` does.
- The constructor's `enabled` becomes two gates: `viewerEnabled` (today's `marineLifeIdEnabled && identifyFishOnOpen`) and `runEnabled` (`marineLifeIdEnabled`).
- Outcome mapping: no image or video file: `unreadable`; `VisionEngineException.tooHot`: `tooHot`; `notForeground`: `notForeground`; other exception: `failed`; not a photo or video: `skipped`.

- [ ] **Step 1: Write the failing tests** (fake engine, as the existing service test does): `a viewer request runs before a waiting run request`; `cancelPending from the viewer leaves a run request queued`; `a run request is served with identify-on-open off`; `an unreadable item reports unreadable`; `a too-hot refusal reports tooHot`; `a run video scans to the end, yielding to a viewer request between chunks`.
- [ ] **Step 2: Run; expect FAIL.**
  Run: `flutter test test/features/species_id/data/media_identification_service_run_lane_test.dart`
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; expect PASS**, and rerun `test/features/species_id/data/media_identification_service_test.dart`.
- [ ] **Step 5: Commit** `feat(species-id): a run lane behind the viewer in the identification service`.

### Task 10: The Find species run

**Files:**
- Create: `lib/features/species_id/domain/entities/dive_species_run_state.dart`
- Create: `lib/features/species_id/data/services/dive_species_run.dart`
- Create: `lib/features/species_id/data/services/run_media_resolvers.dart`
- Create: `lib/features/media/domain/services/media_location.dart` (move `_photoLocation` out of `media_viewer_actions.dart` as `GeoPoint? mediaLocation(MediaItem item, Dive? dive)`; the viewer calls it)
- Modify: `lib/features/media/presentation/pages/media_viewer_actions.dart`
- Modify: `lib/features/species_id/presentation/providers/species_id_providers.dart`
- Test: `test/features/species_id/data/dive_species_run_test.dart`
- Test: `test/features/media/domain/media_location_test.dart`

**Interfaces:**
- Produces: `class DiveSpeciesRunState` with `diveId`, `total`, `done`, `phase` (`DiveRunPhase { running, paused, finished, cancelled }`), `pauseReason` (`DiveRunPause { background, tooHot }`, nullable), and a `DiveRunSummary { photos, videos, speciesTagged, toReview, unreadable }`.
- Produces: `class DiveSpeciesRun` (a `StateNotifier<Map<String, DiveSpeciesRunState>>`, keyed by dive id, owned by `diveSpeciesRunProvider`, kept alive). Methods: `Future<void> start(String diveId)`, `void cancel(String diveId)`, `void resume(String diveId)`, `void appPaused()`, `void appResumed()`. One dive runs at a time; others wait in start order.
- Produces: `int notOnDeviceCount(List<MediaItem> items)` (pure, in `run_media_resolvers.dart`): items with no `localPath`, or whose local file does not open.
- Run resolvers: photos via the same path as `_imageOf` (moved beside it so both use one function); videos via `resolvedFilePathProvider(item)` with the bookmark access `videoFileReaderProvider` uses, never touching `videoPlaybackProvider`.
- Ordering: photos then videos, each in `getMediaForDive` order.
- History: the run sets a zone value the applier sees (Task 8) and collects each item's apply as `(mediaId, isVideo)`; on finish or cancel it runs one `ChangeLogScope.automatic(label: marineLifeId)` that calls `AutoApplier.apply` for each collected item. The summary's `speciesTagged` is the sum.
- Stops: database generation change or the dive no longer existing: phase `cancelled`, no writes (Review Focus 4).

- [ ] **Step 1: Write the failing tests** (fake service and repositories): `runs photos before videos`; `counts done items and reports finished with a summary`; `skips nothing it was given and counts unreadable`; `pauses on tooHot and resumes on resume()`; `pauses on appPaused and continues on appResumed`; `cancel stops after the item in progress`; `a second start waits for the first`; `logbook switch mid-run cancels without writing` and `a deleted dive cancels` (Review Focus 4); `all of a run's applies land in one change log operation`; `a diver save during the run is not filed under it`. And `mediaLocation` cases: own position, else site, else entry, else null.
- [ ] **Step 2: Run; expect FAIL.**
  Run: `flutter test test/features/species_id/data/dive_species_run_test.dart test/features/media/domain/media_location_test.dart`
- [ ] **Step 3: Implement.** Hook `appPaused`/`appResumed` from a `WidgetsBindingObserver` created with the provider.
- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** `feat(species-id): find species in a whole dive's photos and videos`.

### Task 11: What the review page lists

**Files:**
- Create: `lib/features/species_id/domain/entities/species_review.dart`
- Create: `lib/features/species_id/domain/services/species_review_rules.dart` (pure)
- Create: `lib/features/species_id/data/repositories/species_review_repository.dart`
- Create: `lib/features/species_id/presentation/providers/species_review_providers.dart`
- Test: `test/features/species_id/domain/species_review_rules_test.dart`
- Test: `test/features/species_id/data/species_review_repository_test.dart`

**Interfaces:**
- Produces, entities: `ReviewScope` (sealed: `DiveReviewScope(diveId)`, `LogReviewScope()`); `ReviewItem { mediaId, MediaSpeciesTag? tag, SpeciesSuggestion? suggestion, String? cropIdentificationId }`; `ReviewRow { key, displayName, speciesId (nullable for a suggestion-only row), NamedCandidate? candidate, double? bestScore, List<ReviewItem> items, int taggedCount, int suggestedCount, bool get isTagged => taggedCount > 0 }`; `ReviewGroup { ReviewGroupKind kind (dive, sitePhotos, otherPhotos), String? diveId, String? siteId, List<ReviewRow> tagged, List<ReviewRow> suggested }`.
- Produces, pure: `List<ReviewGroup> buildReviewGroups({required List<ReviewMedia> media, required Map<String, List<MediaSpeciesTag>> unconfirmedByMedia, required Map<String, List<SpeciesSuggestion>> suggestionsByMedia, required Map<String, Species> speciesById})` where `ReviewMedia { mediaId, diveId, siteId, diveDateTime }`. A suggestion joins the tagged row of its species when `candidateMatches(suggestion.top.candidate, TaggedSpecies(speciesId, scientificName))`; otherwise rows key by GBIF key. Groups: dives newest first, then site photos, then other photos. `int reviewCount(List<ReviewGroup>)` counts rows.
- Produces, repository: `Future<List<ReviewGroup>> load(ReviewScope scope, {required bool withSuggestions})`: unconfirmed tags (Task 1), the media of the scope (dive: `getMediaForDive`; log: media with an unconfirmed tag or an undecided suggestable identification), suggestions per media through `groupSuggestions` when `withSuggestions`.
- Produces, providers: `speciesReviewProvider(ReviewScope)` (`FutureProvider.autoDispose.family`), invalidated on tag changes and identification changes; `speciesReviewCountProvider(ReviewScope)`. `withSuggestions` is `marineLifeIdEnabled`.

- [ ] **Step 1: Write the failing rule tests**: `a species tagged on 2 and suggested on 3 is one tagged row with counts 2 and 3`; `a suggestion-only species is a suggested row`; `groups order dives newest first then site photos then other photos`; `reviewCount counts rows`.
- [ ] **Step 2: Write the failing repository test**: dive scope lists that dive's unconfirmed tags and suggestions; log scope lists across dives; `withSuggestions: false` leaves the suggested lists empty.
- [ ] **Step 3: Run; expect FAIL.**
  Run: `flutter test test/features/species_id/domain/species_review_rules_test.dart test/features/species_id/data/species_review_repository_test.dart`
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run; expect PASS.**
- [ ] **Step 6: Commit** `feat(species-id): gather the app's tags and suggestions for review`.

### Task 12: The Species to review page

**Files:**
- Create: `lib/features/species_id/domain/value_objects/species_review_edits.dart` (pure)
- Create: `lib/features/species_id/data/services/species_review_saver.dart`
- Create: `lib/features/species_id/presentation/pages/species_review_page.dart`
- Create: `lib/features/species_id/presentation/widgets/species_review_row.dart`
- Modify: `lib/core/router/app_router.dart` (route `review` under `/species`, declared before `:speciesId`, name `speciesReview`, query `dive=<id>` for the dive scope; not in `webUnavailableRoutePrefixes`)
- Modify: `lib/core/services/change_log/change_log_scope.dart` (`ChangeLogLabels.speciesReview = 'species_review'`), `lib/features/change_log/presentation/change_log_labels.dart`, `lib/l10n/arb/app_en.arb`
- Test: `test/features/species_id/domain/species_review_edits_test.dart`
- Test: `test/features/species_id/data/species_review_saver_test.dart`
- Test: `test/features/species_id/presentation/species_review_page_test.dart`

**Interfaces:**
- Produces: `enum ReviewDecision { confirm, remove, add, dismiss }`; `class SpeciesReviewEdits` keyed by `(rowKey, mediaId)`: `decideRow(ReviewRow row, ReviewDecision d)` applies to every unsettled item of the row (Confirm on a mixed row: `confirm` for tagged items and `add` for suggested ones; Remove: `remove` and `dismiss`); `decideItem(rowKey, mediaId, ReviewDecision d)`; `ReviewDecision? decisionFor(rowKey, mediaId)`; `isEmpty`.
- Produces: `class SpeciesReviewSaver` with `Future<void> save(SpeciesReviewEdits edits, List<ReviewGroup> groups)`: one `ChangeLogScope.bulk(label: ChangeLogLabels.speciesReview)`; `confirm` calls `SpeciesTaggingService.confirmTag`; `remove` calls `rejectTag`; `add` resolves the suggestion's candidate with `SuggestionAcceptor` and calls `tagPhoto` (a confirmed tag); `dismiss` calls `MediaIdentificationService.reject(mediaId, ids)`; then `reconcile` for each touched media item. `add` and `dismiss` are skipped where `marineLifeIdEnabled` is false (they cannot occur there: no Suggested rows).
- Page: `SpeciesReviewPage({required ReviewScope scope})`, top bar Cancel and Save (Save disabled while edits are empty), leave check with `showDiscardDialog`, sections "Tagged by the app, not yet confirmed" and "Suggested", rows expand to items, a settled row shows its decision line, a crop from `IdentificationCropStore` else the media thumbnail (`MediaItemView` thumbnail), score only with an identification.
- Strings (English): "Species to review", "Tagged by the app, not yet confirmed", "Suggested", "Confirm", "Remove", "Confirm all", "Add", "on {count} photos", "on {count} videos", "({tagged} tagged, {suggested} suggested)", "Confirmed", "Removed", "Added", "Dismissed", "Site photos", "Other photos", "Nothing to review".

- [ ] **Step 1: Write the failing edits tests**: `Confirm on a mixed row confirms tags and adds suggestions`; `Remove on a mixed row removes tags and dismisses suggestions`; `an item decision overrides the row for that item`; `undoing a decision empties the edits`.
- [ ] **Step 2: Write the failing saver tests** (in-memory DB): `one change log operation for the whole save`; `confirm logs the sighting with onConfirm`; `remove runs the guards`; `add creates a confirmed tag`.
- [ ] **Step 3: Write the failing page tests**: sections and counts render from a fake provider; tapping Confirm shows "Confirmed" without writing; Save calls the saver once; Cancel with edits asks to discard; leaving with edits asks; with `marineLifeIdEnabled = false` the page shows tags with thumbnails and no Suggested section (Review Focus 5); `Nothing to review` when empty.
- [ ] **Step 4: Run; expect FAIL.**
  Run: `flutter test test/features/species_id/domain/species_review_edits_test.dart test/features/species_id/data/species_review_saver_test.dart test/features/species_id/presentation/species_review_page_test.dart`
- [ ] **Step 5: Implement**, including the route.
- [ ] **Step 6: Run; expect PASS.**
- [ ] **Step 7: Commit** `feat(species-id): a page to confirm, remove or add what the app found`.

### Task 13: Entry points: the dive's Marine life card and the Species page banner

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_sightings_section.dart`
- Create: `lib/features/species_id/presentation/widgets/dive_find_species_panel.dart`
- Create: `lib/features/species_id/presentation/widgets/species_review_banner.dart`
- Modify: `lib/features/marine_life/presentation/pages/species_page.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/species_id/presentation/dive_find_species_panel_test.dart`
- Test: `test/features/species_id/presentation/species_review_banner_test.dart`
- Test: `test/features/dive_log/presentation/dive_detail_sightings_section_review_test.dart`

**Interfaces:**
- Consumes: `diveSpeciesRunProvider` (Task 10), `speciesReviewCountProvider` (Task 11), `installedSpeciesPackProvider`, `mediaForDiveProvider`.
- `DiveSightingsSection` shows the card when sightings exist, or the dive's review count is above 0, or (`marineLifeIdEnabled` and a pack is installed and the dive has a photo or video). With no sightings it shows only the panel. While the record is unlocked (a `RecordEditScope` session exists) the panel is not shown.
- `DiveFindSpeciesPanel({required Dive dive})` states: idle "Find species in photos" button (feature and pack only); confirm dialog when `notOnDeviceCount > 0`: "{photos} photos and {videos} videos aren't on this device. Finding species will download them." with "Download and find" and "Cancel"; running "Finding species: {done} of {total}" with Cancel; paused "Paused: device too warm" with Resume; all checked "All photos checked" (disabled) when every item has a run with the installed pack and the review count is 0; and the link "{count} species to review" opening `/species/review?dive=<id>` on every device.
- On finish, a snackbar: "Checked {photos} photos and {videos} videos. Tagged {tagged} species; {toReview} to review." plus " {unreadable} could not be opened." when above 0.
- `SpeciesReviewBanner` at the top of `SpeciesPage`: "{count} species to review" opening `/species/review`; hidden at 0; on every device.

- [ ] **Step 1: Write the failing tests** for each state above (fake providers), including: the card shows on a dive with only unconfirmed tags and the feature off (Review Focus 5); no Find button with the feature off; no panel while unlocked; the banner hidden at 0 and shown at 12.
- [ ] **Step 2: Run; expect FAIL.**
  Run: `flutter test test/features/species_id/presentation/dive_find_species_panel_test.dart test/features/species_id/presentation/species_review_banner_test.dart test/features/dive_log/presentation/dive_detail_sightings_section_review_test.dart`
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; expect PASS.** Also rerun the existing `test/features/dive_log/presentation/widgets/dive_detail/dive_detail_sightings_section_test.dart` if it exists (find it with `ls`).
- [ ] **Step 5: Commit** `feat(species-id): find species from a dive and reach the review from the dive and the Species page`.

### Task 14: Translations, developer docs and final checks

**Files:**
- Modify: the other 10 `lib/l10n/arb/app_*.arb` files and the generated `app_localizations*.dart` (`flutter gen-l10n`)
- Modify: `docs/developer/species-identification.md` (a section "Find species, auto-apply and review": the run lane, the apply rule, the tag columns and floor, how to test with a pack whose confident bar is reachable by editing a local manifest)

- [ ] **Step 1: Translate** every key added in Tasks 5, 7, 8, 12 and 13 into ar, de, es, fr, he, hu, it, nl, pt, zh, keeping placeholders; regenerate.
- [ ] **Step 2: Run** `dart format .` and `flutter analyze` (expect no issues), then every test file this plan created or changed, by path, in one `flutter test` command.
- [ ] **Step 3: Commit** `feat(species-id): translations and developer notes for find species and review`.

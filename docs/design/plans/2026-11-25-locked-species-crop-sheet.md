# Species crop sheet on a locked photo or video: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On a locked photo or video, a tapped species tag opens a sheet showing that species' crops from this media, with a Species page button.

**Architecture:** A pure domain function picks the accepted identifications of one species on a media item and orders them. A new view-only sheet in `species_id/presentation/widgets` draws them with the existing `IdentificationCrop`, opened by a helper that falls back to the species page when there is no crop. `speciesChipWidgets` gains an explicit way to route tag taps to that helper; the viewer's bottom panel and the "+N" list sheet turn it on while locked.

**Tech Stack:** Flutter, Riverpod, go_router, Drift-backed `MediaIdentificationRepository`, ARB l10n (12 locales).

**Spec:** `docs/design/specs/2026-11-25-locked-species-crop-sheet-design.md` (issue #5024)

## Global Constraints

- Unlocked photos and videos keep their current behaviour exactly.
- Suggestion chips stay inert while locked.
- A tap never opens an empty sheet: no crop means the species page, as today.
- Large crop at most 320 logical pixels high, `BoxFit.contain`.
- Count and thumbnails only with more than one crop.
- Photos ordered left to right by box (`box.x`, then `box.y`); videos by `startMs`.
- Every new string translated in all 12 ARB files; plurals follow the repo's guards (Arabic needs zero/one/two/few/many/other).
- No em-dashes anywhere; code comments cite issue #5024.

## Review Focus

1. A species with a crop on this device for one identification and none for another: the sheet still opens, the missing one shows the "Image not on this device" placeholder (owned by Task 2's test `a crop not on this device shows the placeholder`).
2. Marine life labels feature off (`marineLifeLabelsShown` false): every tag opens the species page, never a sheet (Task 1 opener test).
3. A pending video track (`isPending`, no crop yet) accepted for the species: never listed (Task 1 domain test).
4. A school of dozens of crops: the thumbnail row scrolls horizontally inside the sheet at phone width without overflow (Task 2 test pumping 30 crops at 375 wide).
5. The sheet's Species page button pops the sheet before pushing, so Back returns to the viewer, not to the sheet (Task 2 test).

---

### Task 1: Pick a species' crops, and the opener

**Files:**
- Create: `lib/features/species_id/domain/services/species_crops.dart`
- Create: `lib/features/species_id/presentation/widgets/species_crop_sheet.dart` (opener only in this task; the sheet body in Task 2)
- Test: `test/features/species_id/domain/services/species_crops_test.dart`
- Test: `test/features/species_id/presentation/widgets/species_crop_sheet_test.dart`

**Interfaces:**
- Produces: `List<MediaIdentification> cropsOfSpecies(Iterable<MediaIdentification> all, String speciesId)`
- Produces: `Future<void> openSpeciesCrops(BuildContext context, WidgetRef ref, {required MediaItem item, required SpeciesTagChip chip})`

- [ ] **Step 1: Domain tests** in `species_crops_test.dart`:
  - `keeps only accepted identifications of the species`: undecided, rejected, and accepted-of-another-species rows are dropped.
  - `drops a pending track`: an accepted track with `startMs` set and `bestMs` null is dropped.
  - `orders a photo's crops left to right, then top to bottom`.
  - `orders a video's crops by when the animal first appears` (`startMs`).
- [ ] **Step 2:** Run `flutter test test/features/species_id/domain/services/species_crops_test.dart`; expect a compile failure.
- [ ] **Step 3:** Implement `cropsOfSpecies` (filter `decision == accepted && decidedSpeciesId == speciesId && !isPending`; sort by `startMs` when every row is a track, else by `box.x` then `box.y`; return a new list).
- [ ] **Step 4:** Run the test; expect PASS.
- [ ] **Step 5: Opener tests** in `species_crop_sheet_test.dart` (harness as in `media_species_list_sheet_test.dart`: GoRouter with `/viewer` and `/species/:id`, `mediaIdentificationRepositoryProvider` overridden by a fake whose `forMedia` returns fixed rows, `identificationCropProvider` overridden):
  - `with no crop the tag opens the species page`.
  - `with labels off the tag opens the species page` (set `marineLifeIdEnabled = false`, restored with `addTearDown(resetMarineLifeIdEnabled)`).
  - `with a crop the sheet opens` (finds `ValueKey('species_crop_sheet')`).
- [ ] **Step 6:** Implement `openSpeciesCrops`: when `!marineLifeLabelsShown` push `/species/<id>`; else read `ref.read(mediaIdentificationRepositoryProvider).forMedia(item.id)` (a direct read, not an autoDispose provider's future), apply `cropsOfSpecies`, return if `!context.mounted`, push the species page when empty, else `showModalBottomSheet(useSafeArea: true, isScrollControlled: true)` with `SpeciesCropSheet(item:, chip:, crops:)` (a minimal keyed shell is enough here).
- [ ] **Step 7:** Run both test files; expect PASS. `dart format`, `flutter analyze`.
- [ ] **Step 8:** Commit `feat(species-id): pick a species' crops on a media item and open them`.

### Task 2: The crop sheet

**Files:**
- Modify: `lib/features/species_id/presentation/widgets/species_crop_sheet.dart`
- Modify: `lib/l10n/arb/app_*.arb` (12 files), regenerate with `flutter gen-l10n`
- Test: `test/features/species_id/presentation/widgets/species_crop_sheet_test.dart`

**Interfaces:**
- Consumes: `cropsOfSpecies` output (non-empty), `IdentificationCrop(mediaId:, identificationId:, fit:, showReason:)`, `speciesProvider(speciesId)` for the scientific name, `localizedSpeciesName(l10n, speciesId, storedName)`.
- Produces: `class SpeciesCropSheet extends ConsumerStatefulWidget { SpeciesCropSheet({required MediaItem item, required SpeciesTagChip chip, required List<MediaIdentification> crops}) }`
- New strings: `media_species_cropCountPhoto` ("{count, plural, one{1 in this photo} other{{count} in this photo}}"), `media_species_cropCountVideo` (same, "video"), `media_species_openSpeciesPage` ("Species page").

- [ ] **Step 1: Tests** (extend the Task 1 file):
  - `shows the name, the scientific name and the crop large` (`find.text('Blue Tang')`, the scientific name from an overridden `speciesProvider`, `ValueKey('species_crop_large')`).
  - `one crop shows no count and no thumbnails` (`ValueKey('species_crop_thumbs')` findsNothing).
  - `three crops show the count and thumbnails; tapping one shows it large` (`'3 in this photo'`; tap `ValueKey('species_crop_thumb_<id>')`, the large `IdentificationCrop` now has that `identificationId`).
  - `a video says video` (`'3 in this video'`).
  - `a crop not on this device shows the placeholder` (crop provider returns null for one id; `Image not on this device` shown large).
  - `Species page closes the sheet and opens the page; Back returns to the viewer`.
  - `thirty crops scroll in one row at phone width` (view 375 x 812, no overflow exception, the row is a horizontal `ListView`).
- [ ] **Step 2:** Run; expect FAIL.
- [ ] **Step 3:** Add the three strings to all 12 ARB files (feature-grouped next to `media_species_cropUnavailable`; Arabic plurals with every category), run `flutter gen-l10n`.
- [ ] **Step 4:** Implement the sheet: a scrollable column with padding 16; title `titleLarge`, scientific name `bodyMedium` italic in `onSurfaceVariant` when non-empty; `ClipRRect(radius 12)` around `ConstrainedBox(maxHeight 320)` with the selected crop (`fit: BoxFit.contain, showReason: true`, key `species_crop_large`); when more than one crop, the count (`bodySmall`) and a 64-high horizontal `ListView` (key `species_crop_thumbs`) of 56 x 56 rounded thumbnails, the selected one outlined 2 px in `colorScheme.primary`, each a `Semantics(button, selected)`; then a full-width `OutlinedButton.icon` (key `species_crop_species_page`, chevron) that captures `GoRouter.of(context)`, pops the sheet, then pushes `/species/<id>`.
- [ ] **Step 5:** Run; expect PASS. Format, analyze.
- [ ] **Step 6:** Commit `feat(species-id): the crop sheet for a species on a photo or video`.

### Task 3: Locked tag chips open the crops

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_species_chips_row.dart` (`speciesChipWidgets`, `MediaSpeciesChipsRow`)
- Modify: `lib/features/media/presentation/widgets/media_species_list_sheet.dart`
- Modify: `lib/features/media/presentation/pages/media_viewer_bottom_metadata.dart`
- Test: `test/features/media/presentation/widgets/media_species_chips_row_test.dart`, `media_species_list_sheet_test.dart`

**Interfaces:**
- Consumes: `openSpeciesCrops` (Task 1).
- Produces: `speciesChipWidgets(..., MediaItem? cropsOf)`: when given, every tag chip, the diver's or the app's unconfirmed one, calls `openSpeciesCrops(context, ref, item: cropsOf, chip: chip)`; it wins over `openUnconfirmed` and `onSuggestionTap` for tags only. `MediaSpeciesChipsRow({..., bool tagsOpenCrops = false})`, passing `cropsOf: tagsOpenCrops ? item : null`. `_BottomMetadataOverlay({..., bool locked = false})` passes `tagsOpenCrops: locked`; `_bottomPanel` passes `locked: photoLocked`.

- [ ] **Step 1: Tests:**
  - chips row: `locked, a tag opens its crops` and `locked, an app tag opens its crops` (sheet key found), `locked, a suggestion stays inert`, `unlocked, a tag still opens its species page`.
  - list sheet: replace `a tag opens its species page` and `a tag the app applied opens its species page too` with crop-sheet expectations when crops exist, and keep a species-page expectation for a tag with no crop.
- [ ] **Step 2:** Run both files; expect FAIL.
- [ ] **Step 3:** Implement the parameters above. The list sheet passes `cropsOf: item`. Confirm `photoLocked` is true for a locked video as well as a photo before wiring it; if it is photo-only, use the sitting being null instead and say so in the commit.
- [ ] **Step 4:** Run both files plus `media_species_unconfirmed_test.dart` and `media_species_chips_row_suggestions_test.dart`; expect PASS. Format, analyze.
- [ ] **Step 5:** Commit `feat(media): a species tag on a locked photo or video opens its crops`.

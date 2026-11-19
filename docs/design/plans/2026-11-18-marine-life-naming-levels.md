# Marine Life Naming Levels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The diver picks how sure the app must be before it names a fish (Surer, Balanced, Eager), each level measured per pack and applied at read time to media the installed pack named.

**Architecture:** The scorer measures two extra suggest-bar pairs per pack under the same junk cap and held-out gate, and the manifest carries them as optional `naming.levels`. The app parses them, adopts a same-version manifest in place when only levels, precision and credits changed, and recomputes `suggestable` from stored fields against the level in force wherever suggestions, video labels and tag reconciliation read it. Stored columns never change meaning.

**Tech Stack:** Python 3.14 standard library (`tool/species_pack/`), Flutter/Dart with Riverpod, SharedPreferences, ARB l10n.

**Spec:** `docs/design/specs/2026-11-18-marine-life-naming-levels-design.md`

## Global Constraints

- Levels: `surer` (the pack's own `suggestScore` / `suggestScoreNoLocation`), `balanced` (target 0.75), `eager` (target 0.65). Targets use the one-sided 95% Wilson lower bound, as `bars.meets` does.
- A level moves only the two suggest bars. `minCropSide`, `minOpenScore` and the confident bars are the pack's at every level.
- A level's bars are never above Surer's, and Eager's never above Balanced's; a level whose bars equal the one above it is left out.
- Junk: each level at most `max_junk_rate` 0.02 on the tune half (`bars.junk_rate`); a failing level is raised 0.01 at a time and left out when it reaches Surer's bars.
- No manifest `formatVersion` change. `naming.precision` and `naming.levels` are optional.
- The stored `suggestable` column keeps meaning "suggestable at the pack's own bars when named". No write stores a level-applied value.
- The level applies only to rows whose run's `packVersion` equals the installed pack's.
- Shown accuracy: measured precision rounded down to a multiple of 5.
- Per device preference, default Surer. Hidden when the installed pack carries no levels.
- No em-dashes in any file. No AI tool named anywhere. Run only the test files touched, by path.

## Review Focus

1. A pack with no levels (older or provisional manifest): the setting is hidden and every reader behaves exactly as today. Pinned in Tasks 5 and 7.
2. The diver chose Eager and an update drops it: Balanced (or Surer) is in force, and the stored preference is untouched so it returns if a later pack carries Eager. Pinned in Task 5.
3. Rows named by another pack version, or with no run: the stored flag stands. Pinned in Task 5.
4. A pending video track (no candidates, no best moment) at Eager: still not suggestable, still no pill. Pinned in Task 5.
5. A same-version manifest that changes a bar, a file or a detector: not adopted, nothing downloaded, state as today. Pinned in Task 4.

---

### Task 1: Level bar search (Python)

**Files:**
- Modify: `tool/species_pack/bars.py`
- Test: `tool/species_pack/bars_test.py`

**Interfaces:**
- Produces: `LEVEL_TARGETS = (("balanced", 0.75), ("eager", 0.65))`; `level_bars(with_location, no_location, junk_with, junk_without, *, surer: Bars, ceiling: Bars, min_side, target, max_junk_rate=0.02) -> Bars | None`; `level_gate(level: Bars, surer: Bars, with_location, no_location, *, min_side, target) -> bool` (True when the level survives).

- [ ] **Step 1: Write the failing tests** in a new `class LevelTests(unittest.TestCase)`, using the file's `s()` and `both()` helpers:
  - `test_level_is_lower_than_surer`: 100 crops `s(0.6, 0.9, True)`, 60 `s(0.6, 0.55, True)`, 40 `s(0.6, 0.55, False)`; surer = `Bars(0.5, 0.80, 0.80, NEVER, NEVER)`; `level_bars(..., surer=surer, ceiling=surer, target=0.65)` returns bars with `suggest < 0.80`, `min_open == 0.5`, `confident == NEVER`.
  - `test_level_never_above_ceiling`: all crops right at top 0.95; ceiling suggest 0.70; the level's suggest is `<= 0.70`.
  - `test_level_equal_to_ceiling_is_none`: crops where nothing below Surer's bar meets the target; returns `None`.
  - `test_junk_raises_the_level`: fish as in the first test plus 10 junk `s(0.6, 0.56, False)`; the level's suggest ends `> 0.56` (junk named at most 2%).
  - `test_junk_that_cannot_pass_drops_the_level`: 10 junk `s(0.6, 0.79, False)` with surer suggest 0.80: raising past 0.79 reaches 0.80, so it returns `None`.
  - `test_gate_drops_a_level_whose_interval_is_below_target` and `test_gate_keeps_a_level_that_meets_target`, via `level_gate` on held-out crops (10 of 100 right at the level's bar fails 0.65; 90 of 100 passes).
- [ ] **Step 2: Run** `python3.14 tool/species_pack/bars_test.py`. Expected: the new tests ERROR with `AttributeError` on `level_bars`.
- [ ] **Step 3: Implement** `level_bars` and `level_gate` in `bars.py`. `level_bars`: with `limited = [c for c in with_location if c.limited]`, take `_best_bar(limited, min_open=surer.min_open, min_side=..., target=target)` and the same over `no_location`; a `NEVER` result keeps `ceiling`'s bar; clamp each to `ceiling`'s; while `junk_rate(...) > max_junk_rate`, raise each bar still below `ceiling`'s by 0.01 (rounded to 2 places, clamped); return `None` when both bars equal `ceiling`'s, else `replace(surer, suggest=..., suggest_no_location=...)`. `level_gate`: for each of the two bars that is below Surer's, the two-sided Wilson interval of the crops named at the level (same filter as `held_out_gate.fails`) must not lie wholly below `target`, and the level must name something; otherwise False.
- [ ] **Step 4: Run** `python3.14 tool/species_pack/bars_test.py`. Expected: OK.
- [ ] **Step 5: Commit** `feat(species-id): measure naming level bars in the pack scorer`.

### Task 2: Levels in the scorer, report and manifest builder (Python)

**Files:**
- Modify: `tool/species_pack/score.py` (`evaluate`, `_measured_entry`, `main`), `tool/species_pack/report.py`, `tool/species_pack/manifest.py`
- Create: `tool/species_pack/relevel_manifest.py`
- Test: `tool/species_pack/manifest_test.py`

**Interfaces:**
- Consumes: Task 1's `level_bars`, `level_gate`, `LEVEL_TARGETS`.
- Produces: each evaluation gains `"levels"`: list of `{"id", "target", "bars": Bars.__dict__, "held-out": {"precision": rate, "coverage": rate, "junk named": rate}}` and `"surer precision"`: float. `_measured_entry(evaluation, manifest, detector_ids, crop_fit)` writes `naming["precision"]` (3 places) and `naming["levels"] = [{"id", "target", "suggestScore", "suggestScoreNoLocation", "precision"}]` (bars 2 places, precision 3). `manifest.relevel(published: dict, measured=NAMING_MEASURED) -> dict` returns the published manifest with `naming` from `naming_for(...)`, raising `ValueError` if any naming key other than `precision` and `levels` would change, or if the pack has no measured entry.

- [ ] **Step 1: Write the failing tests** in `manifest_test.py`:
  - `class RelevelTests`: a manifest from `build_manifest` for the measured pack, with `measured` holding one entry whose naming adds `"precision": 0.9` and a balanced level, gets `naming["levels"][0]["id"] == "balanced"`, the same `packVersion` and `files`; a measured entry whose `suggestScore` differs raises `ValueError`; a pack whose contents match no entry raises `ValueError`.
  - `class MeasuredLevelsTests`: for every `NAMING_MEASURED` entry with `levels`, ids are a subset of `{"balanced", "eager"}` in that order, each bar `<=` the entry's own suggest bars, eager's `<=` balanced's, and `0 < precision <= 1`.
  - `test_naming_for_copies_levels`: mutating the returned `levels` list leaves `NAMING_MEASURED` unchanged (deep copy).
- [ ] **Step 2: Run** `python3.14 tool/species_pack/manifest_test.py`. Expected: FAIL (`relevel` missing; shallow copy).
- [ ] **Step 3: Implement.** `naming_for` returns `copy.deepcopy(entry["naming"])`. Add `relevel`. `relevel_manifest.py` is a CLI: `--in PATH --out PATH`, reads JSON, writes `relevel(...)` with `write_manifest`. In `score.py` `evaluate`, after the gate, compute each level from the tune half against `ceiling` = Surer's gated bars then the previous kept level's, keep it when `level_gate` passes on the held-out half, and record held-out precision, coverage (via `bar_search.named` and `metrics.coverage_precision`, with location) and held-out junk named; record `"surer precision"` from `summary(held_nat)`. Change `_measured_entry` to take the evaluation. In `report.py` add a "Naming levels" table: run, level, target, suggest, suggest no location, precision, coverage, junk named.
- [ ] **Step 4: Run** `python3.14 tool/species_pack/manifest_test.py` and `python3.14 tool/species_pack/bars_test.py`. Expected: OK.
- [ ] **Step 5: Commit** `feat(species-id): carry measured naming levels into the pack manifest`.

### Task 3: Parse naming levels (Dart)

**Files:**
- Create: `lib/features/species_id/domain/entities/naming_level.dart`
- Modify: `lib/features/species_id/domain/entities/species_pack_manifest.dart` (`NamingConfig`, `parse`)
- Test: `test/features/species_id/domain/species_pack_manifest_test.dart`, `test/features/species_id/domain/entity_copy_with_test.dart`, `test/features/species_id/domain/manifest_fixture.dart`

**Interfaces:**
- Produces: `enum NamingLevel { surer, balanced, eager }` with `String get id` and `static NamingLevel? fromId(String? id)`. `class MeasuredNamingLevel extends Equatable { level: NamingLevel, target: double, suggestScore: double, suggestScoreNoLocation: double, precision: double; copyWith }`. `NamingConfig` gains `double? precision` and `List<MeasuredNamingLevel> levels` (default `const []`), both in `copyWith` and `props`.

- [ ] **Step 1: Write the failing tests** in `species_pack_manifest_test.dart` (`group('naming levels')`), editing the fixture's naming map:
  - parses `precision: 0.897` and two levels into `naming.levels` in enum order (eager listed first in JSON comes out second);
  - no `levels` key gives `[]` and `precision == null`;
  - drops an entry with id `surer`, an unknown id, a duplicate id, a non-number bar, a bar above the block's own, a precision of 0 or above 1, and eager whose bar is above balanced's; the pack still parses;
  - `precision` outside (0, 1] parses as null.
  - In `entity_copy_with_test.dart`: `MeasuredNamingLevel.copyWith` and `NamingConfig.copyWith(levels:, precision:)`.
- [ ] **Step 2: Run** `flutter test test/features/species_id/domain/species_pack_manifest_test.dart test/features/species_id/domain/entity_copy_with_test.dart`. Expected: compile failure on `levels`.
- [ ] **Step 3: Implement** the enum, entity and parsing (a private `_levels(naming, suggest, suggestNoLocation)` that never throws for a bad entry).
- [ ] **Step 4: Run** the same command. Expected: all pass.
- [ ] **Step 5: Commit** `feat(species-id): read naming levels from the pack manifest`.

### Task 4: Adopt a same-version manifest in place (Dart)

**Files:**
- Modify: `lib/features/species_id/domain/entities/species_pack_manifest.dart`, `lib/features/species_id/data/pack/species_pack_store.dart`, `lib/features/species_id/presentation/providers/species_pack_controller.dart`
- Test: `test/features/species_id/domain/species_pack_manifest_test.dart`, `test/features/species_id/data/species_pack_store_test.dart`, `test/features/species_id/presentation/species_pack_controller_test.dart`

**Interfaces:**
- Consumes: Task 3's `NamingConfig.levels`, `precision`.
- Produces: `bool SpeciesPackManifest.adoptableFrom(SpeciesPackManifest published)`: same `packVersion`, not equal, and equal once this manifest takes `published`'s `naming.levels`, `naming.precision` and `credits`. `Future<InstalledPack> SpeciesPackStore.adoptManifest(InstalledPack pack, SpeciesPackManifest manifest)`: writes `manifest.source` to `manifest.json.tmp` in `pack.directory`, flushes, renames over `manifest.json`, returns the pack with the new manifest.

- [ ] **Step 1: Write the failing tests:**
  - manifest: `adoptableFrom` true for added levels, added precision, changed credits; false for a changed `suggestScore`, file sha256, detector, `packVersion`, and for an identical manifest.
  - store: after `adoptManifest`, `installed()` returns the new manifest's levels; no `.tmp` file remains.
  - controller (with the test file's fakes): installed and published share a version and `adoptableFrom` holds, so `refresh()` ends `PackInstalled` with `updateBytes == null`, the published credits, and the store holding the published manifest; `installedSpeciesPackProvider` re-reads it. A same-version manifest with a changed bar leaves the installed manifest as it was.
- [ ] **Step 2: Run** `flutter test test/features/species_id/domain/species_pack_manifest_test.dart test/features/species_id/data/species_pack_store_test.dart test/features/species_id/presentation/species_pack_controller_test.dart`. Expected: compile failures.
- [ ] **Step 3: Implement.** In `_refresh`, after `_published = published`, when `installed != null && published != null && installed.manifest.adoptableFrom(published)`, replace `installed` with `await store.adoptManifest(installed, published)` and `ref.invalidate(installedSpeciesPackProvider)`; a failed write logs and keeps the installed one.
- [ ] **Step 4: Run** the same command. Expected: all pass.
- [ ] **Step 5: Commit** `feat(species-id): take a republished pack manifest without downloading`.

### Task 5: The level in force, applied to stored identifications (pure Dart)

**Files:**
- Create: `lib/features/species_id/domain/services/naming_levels.dart`
- Test: `test/features/species_id/domain/naming_levels_test.dart`

**Interfaces:**
- Consumes: Task 3's types.
- Produces:
  - `class LevelInForce extends Equatable { level: NamingLevel, packVersion: String, minCropSide: int, minOpenScore: double, suggestScore: double, suggestScoreNoLocation: double }`
  - `List<NamingLevel> offeredLevels(NamingConfig naming)`: `[]` when `levels` is empty, else `surer` then the carried levels.
  - `LevelInForce? levelInForce(SpeciesPackManifest? manifest, NamingLevel chosen)`: null with no manifest; the chosen level if carried, else the nearest surer one carried, else Surer from the block's own bars.
  - `double? precisionOf(NamingConfig naming, NamingLevel level)`
  - `int accuracyPercent(double precision)`: rounded down to a multiple of 5, with a 1e-9 allowance so 0.90 gives 90.
  - `bool suggestableAt(MediaIdentification i, LevelInForce level)`: the spec's formula.
  - `List<MediaIdentification> applyNamingLevel(List<MediaIdentification> all, {required LevelInForce? level, required String? namedWithPack})`: unchanged list when `level` is null or `namedWithPack != level.packVersion`; otherwise copies with `suggestable: suggestableAt(i, level)`, other fields untouched.

- [ ] **Step 1: Write the failing tests** (fixtures from `test/features/species_id/data/identification_fixtures.dart`):
  - `levelInForce`: chosen eager with both carried gives eager's bars; eager not carried gives balanced; neither gives Surer; null manifest gives null.
  - `offeredLevels`: no levels gives `[]`; balanced only gives `[surer, balanced]`.
  - `accuracyPercent(0.897) == 85`, `(0.90) == 90`, `(0.7999) == 75`, `(1.0) == 100`.
  - `applyNamingLevel` at Surer leaves every `suggestable` equal to the stored flag for rows named with the same bars; at Eager a row with top 0.6 and location turns suggestable when Eager's bar is 0.55; a row with `openScore` under the floor, a box under `minCropSide`, or no candidates (a pending track) stays not suggestable; rows with `namedWithPack` of another version, or null, are returned unchanged; `decision`, `confident` and `specific` are never changed.
- [ ] **Step 2: Run** `flutter test test/features/species_id/domain/naming_levels_test.dart`. Expected: compile failure.
- [ ] **Step 3: Implement** in `naming_levels.dart`.
- [ ] **Step 4: Run** the same command. Expected: all pass.
- [ ] **Step 5: Commit** `feat(species-id): work out suggestions at the chosen naming level`.

### Task 6: Preference, providers and the service (Dart)

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`SettingsKeys.marineLifeNamingLevel = 'species_id_naming_level'`), `lib/features/species_id/presentation/providers/species_id_providers.dart`, `lib/core/providers/root_overrides.dart`, `lib/features/species_id/data/services/media_identification_service.dart`
- Test: `test/features/species_id/presentation/species_id_providers_test.dart`, `test/features/species_id/data/media_identification_service_test.dart`

**Interfaces:**
- Consumes: Task 5's functions; `installedSpeciesPackProvider`; `MediaIdentificationRepository.runFor`.
- Produces: `class NamingLevelNotifier extends StateNotifier<NamingLevel>` with `NamingLevelNotifier(SharedPreferences prefs)`, `NamingLevelNotifier.unstored(NamingLevel level)`, `Future<void> setLevel(NamingLevel level)` (writes serialised as `DeviceBadgeToggleNotifier.setEnabled` does; an unknown stored id reads as Surer). `namingLevelProvider` (unstored Surer by default, overridden in `rootProviderOverrides`). `levelInForceProvider = FutureProvider<LevelInForce?>`. `MediaIdentificationService` gains optional `Future<LevelInForce?> Function()? namingLevel`.

- [ ] **Step 1: Write the failing tests:**
  - providers: with an installed pack carrying eager and `namingLevelProvider` at eager, `mediaSuggestionsProvider` offers a suggestion for a row whose top score is between Eager's and Surer's bars, and not at Surer; the same row under a run of another pack version is not offered at eager; `videoTracksProvider` returns the track with `suggestable` true at eager.
  - notifier: `setLevel(eager)` persists `'eager'`; a stored `'bogus'` reads as surer.
  - service: `reconcile` with `namingLevel` returning Eager accepts a track whose top name matches the tag and whose score is between Eager's and Surer's bars; without `namingLevel` it does not (today's behaviour). The written row's `suggestable` column stays false.
- [ ] **Step 2: Run** `flutter test test/features/species_id/presentation/species_id_providers_test.dart test/features/species_id/data/media_identification_service_test.dart`. Expected: compile failures.
- [ ] **Step 3: Implement.** `levelInForceProvider` watches `installedSpeciesPackProvider.future` and `namingLevelProvider`. `mediaSuggestionsProvider` and `videoTracksProvider` watch `levelInForceProvider.future`, read `runFor(mediaId)` only when a level is in force, and pass `applyNamingLevel(...)` output on. The service applies the same before `reconcileDecisions`; `mediaIdentificationServiceProvider` passes `namingLevel: () => ref.read(levelInForceProvider.future)`.
- [ ] **Step 4: Run** the same command. Expected: all pass.
- [ ] **Step 5: Commit** `feat(species-id): apply the chosen naming level to suggestions and labels`.

### Task 7: The settings section and strings (Dart)

**Files:**
- Create: `lib/features/species_id/presentation/widgets/naming_level_section.dart`
- Modify: `lib/features/species_id/presentation/pages/marine_life_identification_page.dart` (below the `species_id_toggle` tile), all 11 `lib/l10n/arb/app_*.arb`, generated `app_localizations*.dart`
- Test: `test/features/species_id/presentation/marine_life_identification_page_test.dart`

**Interfaces:**
- Consumes: `namingLevelProvider`, `installedSpeciesPackProvider`, Task 5's `offeredLevels`, `levelInForce`, `precisionOf`, `accuracyPercent`.
- Produces: `NamingLevelSection` (a `ConsumerWidget`), keys `species_id_level_<id>`. Strings: `settings_speciesId_levelTitle` "Name a fish when the app is", `settings_speciesId_levelSurer` "Surer", `settings_speciesId_levelBalanced` "Balanced", `settings_speciesId_levelEager` "Eager", `settings_speciesId_levelSurerAccuracy` "Fewest names. About {percent}% right", `settings_speciesId_levelSurerUnmeasured` "Fewest names, most often right", `settings_speciesId_levelBalancedAccuracy` "More names. About {percent}% right", `settings_speciesId_levelEagerAccuracy` "Most names. About {percent}% right" (`percent` is an `int`).

- [ ] **Step 1: Write the failing widget tests:** no pack, or a pack with no levels, shows no `species_id_level_surer`; a pack with balanced and eager shows three radios with "About 85% right" for precision 0.897 on Surer and the measured figures on the others; tapping Eager sets `namingLevelProvider` to eager; with Eager chosen and a pack carrying only balanced, Balanced shows selected.
- [ ] **Step 2: Run** `flutter test test/features/species_id/presentation/marine_life_identification_page_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the section with a `RadioGroup<NamingLevel>` (as `lib/features/settings/presentation/widgets/network/proxy_mode_selector.dart` uses), selected value from `levelInForce(...)`. Add the strings to `app_en.arb` with descriptions and translated text to the other ten ARB files, then `flutter gen-l10n`.
- [ ] **Step 4: Run** the same command. Expected: pass. (The pre-push hook runs the architecture guards over the new `lib/` files.)
- [ ] **Step 5: Commit** `feat(species-id): choose a naming level in marine life settings`.

### Task 8: Developer docs

**Files:**
- Modify: `docs/developer/species-identification.md`

- [ ] **Step 1:** Add a "Naming levels" section: the three levels and what moves; how `score.py` measures them (targets, junk cap, gate) and where they land (`results.json` `measured`, `NAMING_MEASURED`); republishing with `relevel_manifest.py` under the same `packVersion`, re-uploading only `manifest.json` with `--clobber`; the app's in-place adoption rule and read-time application.
- [ ] **Step 2:** `python3.14 scripts/check_docs_links.py`. Expected: no failures.
- [ ] **Step 3: Commit** `docs(species-id): document naming levels`.

### Task 9: Measure and record (maintainer run)

- [ ] **Step 1:** The maintainer runs, on the Mac, `.venv-species-pack/bin/python -I tool/species_pack/score.py --pack build/species_pack` against the pack `2026.11.18.0356` files, and shares `results.json`'s `measured` entries and the report's "Naming levels" table.
- [ ] **Step 2:** Copy each set's `precision` and `levels` into `NAMING_MEASURED`; run `python3.14 tool/species_pack/manifest_test.py`. Expected: OK.
- [ ] **Step 3:** Add a "Naming levels" section to `docs/design/findings/2026-11-17-marine-life-measured-accuracy.md` with the table.
- [ ] **Step 4:** Download the published manifest (`gh release download species-pack -p manifest.json -D <scratch>`), run `relevel_manifest.py`, and diff: only `naming.precision` and `naming.levels` change.
- [ ] **Step 5: Commit** `feat(species-id): measured naming levels for the published pack`. Re-upload `manifest.json` only on the maintainer's explicit go-ahead.

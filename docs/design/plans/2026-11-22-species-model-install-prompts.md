# Species Model Install Prompts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Offer the species identification model in the first-run setup wizard (a new step after Photos) and on Home (a banner once the library has photos or videos), on eligible devices only.

**Architecture:** Both surfaces read the facts behind the existing `speciesDownloadPromptProvider` (issue #4773). Home watches a new `homeSpeciesBannerProvider` (prompt provider AND library has a photo or video AND not demo mode) and renders the existing `SpeciesDownloadPrompt(banner: true)`. The wizard holds a one-shot `speciesModelOfferProvider` through the container until it answers, stores the answer on the draft as `speciesModelOffered`, and `computeSteps` inserts `SetupStepId.speciesModel` after `setUpPhotos`. The step widget drives `SpeciesPackController`.

**Tech Stack:** Flutter, Riverpod (`core/providers/provider.dart`), Drift via `MediaRepository`, ARB l10n (11 locales).

**Spec:** `docs/design/specs/2026-11-22-species-model-install-prompts-design.md`

## Global Constraints

- Never shown where the model cannot run: every surface requires `marineLifeIdEnabled` and `VisionAvailability.available`.
- No dialog anywhere: the wizard step's size line is the confirmation; Home is a non-modal banner.
- One dismiss for every offer: the existing `SettingsKeys.speciesIdDownloadPromptDismissed` via `speciesDownloadPromptDismissedNotifierProvider`. No new preference.
- Settings' Set up this device card, `SetUpStep` and its "n of 4" count do not change.
- Every new string goes into all 11 ARBs (`lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`) with real translations, inserted beside a neighbouring key of the same feature group; `flutter gen-l10n` runs after every ARB has them.
- No em-dashes in code, comments, strings or commits. No new file over 400 lines; `setup_wizard_page.dart` (479 lines) stays under 800.
- Run only the test files this plan touches, by path. Never a folder or the suite.

## Review Focus

1. **Download tapped, then Back from Finish:** the controller moves to `PackDownloading`, which turns the prompt provider off; the step must stay in the list and Back must land on it, showing the progress line. Test in Task 4.
2. **Availability resolves late, while the diver is already on Finish:** the step must not be inserted (it would shift Finish's index under them). Test in Task 4.
3. **Offline at setup (`PackFailed` from `refresh()`):** the step shows the "find it later in Settings" line and a working Next, never a dead Download. Test in Task 3.
4. **Demo mode with photos:** the sample logbook has photos, so without the demo check the banner would show and a dismissal would carry into the real setup. Test in Task 1.
5. **A run from Settings after the diver removed the model:** removal sets the dismissed flag, so the step must be left out. Test in Task 2.

---

### Task 1: Home banner

**Files:**
- Modify: `lib/features/species_id/presentation/providers/species_download_prompt_providers.dart` (add two providers)
- Create: `lib/features/species_id/presentation/widgets/home_species_banner.dart`
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart` (one sliver after `DemoModeDashboardCard`)
- Test: `test/features/species_id/presentation/home_species_banner_test.dart` (new)
- Test: `test/features/dashboard/presentation/pages/dashboard_page_test.dart` (one case)

**Interfaces:**
- Produces: `final libraryHasPhotosOrVideosProvider = FutureProvider.autoDispose<bool>` (reads `mediaRepositoryProvider`, `invalidateSelfWhen(media.watchMediaChanges())`, returns `await media.countPhotosAndVideos() > 0`, as `setUpPhotoCountProvider` does).
- Produces: `final homeSpeciesBannerProvider = Provider.autoDispose<bool>` (auto-disposed, so the media watch ends when Home goes): `speciesDownloadPromptProvider && libraryHasPhotosOrVideosProvider.value == true && !demoModeActiveProvider`.
- Produces: `class HomeSpeciesBanner extends ConsumerWidget` (const constructor): `SizedBox.shrink()` unless `homeSpeciesBannerProvider`, else `SpeciesDownloadPrompt(banner: true)`.

- [ ] **Step 1: Write the failing tests** in `home_species_banner_test.dart`, reusing the `_FixedPackController` pattern and override list from `test/features/species_id/presentation/species_download_prompt_test.dart`, with `libraryHasPhotosOrVideosProvider` and `demoModeActiveProvider` overridden:
  - `shows the banner when the offer applies and the library has a photo or video`: `find.byKey(ValueKey('species_download_prompt'))` finds one.
  - `hides it when the library has no photos or videos` (override false): finds nothing.
  - `hides it while the media count is loading` (a never-completing future): finds nothing.
  - `hides it in demo mode` (Review Focus 4): finds nothing.
  - `hides it when the offer was dismissed`, and `when a pack is installed`: finds nothing.
  - `the close button dismisses it`: tap `species_download_prompt_dismiss`, pump; prompt gone and the dismissed notifier state is `true`.
- [ ] **Step 2: Run** `flutter test test/features/species_id/presentation/home_species_banner_test.dart`. Expected: FAIL (`HomeSpeciesBanner` undefined).
- [ ] **Step 3: Implement** the two providers and `HomeSpeciesBanner` per Interfaces. Doc comments cite issue #4881.
- [ ] **Step 4: Run** the same file. Expected: PASS.
- [ ] **Step 5: Add to Home.** In `dashboard_page.dart`, right after `const SliverToBoxAdapter(child: DemoModeDashboardCard())`, add `const SliverToBoxAdapter(child: HomeSpeciesBanner())`. In `dashboard_page_test.dart` add `testWidgets('Home holds the species model banner slot under the demo card', ...)` using `pumpHome`, asserting `find.byType(HomeSpeciesBanner)` finds one.
- [ ] **Step 6: Run** `flutter test test/features/dashboard/presentation/pages/dashboard_page_test.dart`. Expected: PASS (all existing cases too; if `pumpHome` lacks overrides the banner needs, override `homeSpeciesBannerProvider` to `false` in `pumpHome`).
- [ ] **Step 7: Commit** `feat(species-id): offer the species model on Home once the library has photos` (the five files above).

### Task 2: Wizard offer flag and step list

**Files:**
- Modify: `lib/features/species_id/presentation/providers/species_download_prompt_providers.dart`
- Modify: `lib/features/setup_wizard/domain/setup_wizard_models.dart`
- Modify: `lib/features/setup_wizard/presentation/providers/setup_wizard_providers.dart`
- Test: `test/features/setup_wizard/domain/setup_wizard_models_test.dart`
- Test: `test/features/species_id/presentation/species_model_offer_provider_test.dart` (new)

**Interfaces:**
- Produces: `final speciesModelOfferProvider = FutureProvider.autoDispose<bool>`: false unless `marineLifeIdEnabled`; then `await visionAvailabilityProvider.future == VisionAvailability.available && await installedSpeciesPackProvider.future == null && !ref.read(speciesDownloadPromptDismissedNotifierProvider)`. Reads, never watches the dismissed flag or the controller (the answer is a snapshot).
- Produces: `SetupStepId.speciesModel` (enum value, after `setUpPhotos`); `SetupWizardDraft.speciesModelOffered` (`bool`, default `false`, carried by `copyWith`); `SetupWizardNotifier.offerSpeciesModel()` sets it to `true` (never back to false).
- Produces: `computeSteps` inserts `SetupStepId.speciesModel` immediately after `SetupStepId.setUpPhotos` when `draft.speciesModelOffered`, applied after the browser trimming (so a list without `setUpPhotos` never gets it).

- [ ] **Step 1: Write the failing tests.**
  - In `setup_wizard_models_test.dart`, group `computeSteps with the species model offered (#4881)`:
    - fresh path: `[welcomeFork, profile, units, setUpAccount, setUpSync, setUpBackups, setUpPhotos, speciesModel, finish]`.
    - cloud sync: `speciesModel` directly after `setUpPhotos`, before `finish` (and before `profile` when `needsProfile`).
    - settings mode: `[units, ...kSetUpWizardSteps, speciesModel, finish]`.
    - not offered: lists identical to today's.
    - skip, restore, open folder, and a browser (both modes): no `speciesModel` even when offered.
    - `SetupWizardDraft.copyWith` keeps `speciesModelOffered`.
  - In `species_model_offer_provider_test.dart`: true when enabled, available, no pack, not dismissed; false for each of: feature off, `deviceNotEligible`, a pack installed, dismissed (Review Focus 5); and the value stays `true` after the controller override moves to `PackDownloading` (read the provider, change state, read again in the same container).
- [ ] **Step 2: Run** both files. Expected: FAIL (undefined names).
- [ ] **Step 3: Implement** per Interfaces.
- [ ] **Step 4: Run** both files plus `test/features/setup_wizard/presentation/providers/setup_wizard_providers_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(setup-wizard): add the species model step to the step list when it is offered`.

### Task 3: The step widget and its strings

**Files:**
- Create: `lib/features/setup_wizard/presentation/widgets/steps/species_model_step.dart`
- Modify: 11 ARBs, then regenerate `lib/l10n/arb/app_localizations*.dart`
- Test: `test/features/setup_wizard/presentation/widgets/steps/species_model_step_test.dart` (new)

**Interfaces:**
- Consumes: `speciesPackControllerProvider` (`refresh()`, `download()`, `downloadFetchesHardwareEngine()`), `SetUpStepScaffold`, `formatBytes`, `visionVideoRuns(defaultTargetPlatform)`.
- Produces: `class SpeciesModelStep extends ConsumerStatefulWidget { const SpeciesModelStep({super.key, required VoidCallback onNext, required VoidCallback? onBack}); }`

Strings (en values fixed here; key group `setup_speciesModel_*`, inserted after the `setup_step_*` keys):

| Key | en |
| --- | --- |
| `setup_speciesModel_title` | `Species identification` |
| `setup_speciesModel_intro` | `Suggests the species in your dive photos and videos. It runs on this device, and nothing is uploaded.` |
| `setup_speciesModel_introPhotos` | `Suggests the species in your dive photos. It runs on this device, and nothing is uploaded.` |
| `setup_speciesModel_size` (`{size}` String) | `Download: {size}` |
| `setup_speciesModel_wifi` | `Wi-Fi recommended` |
| `setup_speciesModel_hardware` | `Windows may also download an engine for your graphics card or NPU from Microsoft.` |
| `setup_speciesModel_downloading` | `Downloading. You can follow it in Settings > Data > Photos & videos > Species identification.` |
| `setup_speciesModel_installed` | `Installed on this device` |
| `setup_speciesModel_later` | `Can't reach the download right now. You'll find it later in Settings > Data > Photos & videos > Species identification.` |

Buttons reuse `settings_setUpDevice_skip`, `settings_setUpDevice_next`, `common_action_back`, and `settings_speciesId_download(size)` for Download.

- [ ] **Step 1: Write the failing tests** (controller fixed by a `_FixedPackController` subclass that records `download()` and `refresh()` calls; `marineLifeIdEnabled = true` with `addTearDown(resetMarineLifeIdEnabled)`; `debugDefaultTargetPlatformOverride` set per case and reset in `addTearDown`):
  - `PackNotInstalled(bytes: 633 MB)`: shows `Download: <formatBytes(bytes)>`, a Download button labelled `settings_speciesId_download(formatBytes(bytes))` and Skip; on iOS shows `Wi-Fi recommended`, on macOS does not.
  - tapping Download calls `download()` once and `onNext` once, and `onNext` runs before the download future completes (the fake's `download()` returns a never-completing future).
  - tapping Skip calls `onNext` and leaves the dismissed notifier `false`.
  - `PackFailed`: shows `setup_speciesModel_later`, primary is Next and calls `onNext` (Review Focus 3); no Download button.
  - `PackDownloading` / `PackInstalling`: progress line `setup_speciesModel_downloading`, primary Next.
  - `PackInstalled`: `Installed on this device`, primary Next.
  - `PackChecking`: Download is shown with `onPrimary: null` and a spinner in the size line.
  - `PackNotPublished`: the `later` line and Next.
  - the step calls `refresh()` once when it opens.
  - `downloadFetchesHardwareEngine()` true adds the `setup_speciesModel_hardware` line.
- [ ] **Step 2: Run** the file. Expected: FAIL.
- [ ] **Step 3: Add the strings** to `app_en.arb` and the translations to the other 10 ARBs; run `flutter gen-l10n` last; check `grep -A1 "get setup_speciesModel_title" lib/l10n/arb/app_localizations_de.dart` shows German.
- [ ] **Step 4: Implement `SpeciesModelStep`** with `SetUpStepScaffold`: `refresh()` in a post-frame callback of `initState`; the hardware question asked once in `initState` into a `bool _fetchesEngine`; body and buttons per the spec's state table; Download does `unawaited(controller.download())` then `widget.onNext()`. Wi-Fi line when `defaultTargetPlatform` is iOS or Android.
- [ ] **Step 5: Run** the file. Expected: PASS.
- [ ] **Step 6: Commit** the ARBs and generated files as `i18n(setup-wizard): strings for the species model step`, then the widget and test as `feat(setup-wizard): species model step`.

### Task 4: Wire the step into the wizard

**Files:**
- Modify: `lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart`
- Test: `test/features/setup_wizard/presentation/pages/setup_wizard_page_test.dart`

**Interfaces:**
- Consumes: Task 2's `speciesModelOfferProvider`, `SetupStepId.speciesModel`, `offerSpeciesModel()`; Task 3's `SpeciesModelStep`.

- [ ] **Step 1: Write the failing tests** with the existing `pumpStubbed` setup, adding a `speciesModelOfferProvider` override:
  - `an offered species step runs after Photos and before Finish`: walk the fresh path with stubs; after Photos' Next the `SpeciesModelStep` shows; its Skip reaches Finish.
  - `not offered, Photos goes straight to Finish`.
  - `the species step shares the Data dot` (the indicator row has the same dot count as without it).
  - `Back from Finish returns to the species step after a download started` (Review Focus 1): controller fake whose `download()` never completes; tap Download, then Back; `SpeciesModelStep` shows the downloading line.
  - `an offer resolving on Finish does not add the step` (Review Focus 2): offer future completed only after reaching Finish; Finish stays on screen and `computeSteps` has no `speciesModel`.
- [ ] **Step 2: Run** the file. Expected: FAIL.
- [ ] **Step 3: Implement.** Add `SetupStepId.speciesModel` to `_indicatorZone`, map it to the Data dot in `_indicatorDot` and `_stepLabel`; a `_defFor` case with `hideBottomBar: true` building `SpeciesModelStep(onNext: _advance, onBack: _back)`. In `initState`, await `ProviderScope.containerOf(context, listen: false).awaitFuture(speciesModelOfferProvider.future)`: a plain `ref.read(...future)` drops its listener, and the auto-disposed provider is disposed while the vision engine answers on a cold first run. On `true`, if mounted and `speciesModelOfferFits(computeSteps(draft), _currentIndex)` (the diver has not passed Photos), call `offerSpeciesModel()`. A failed future is logged and leaves the step out.
- [ ] **Step 4: Run** the file. Expected: PASS, existing cases included.
- [ ] **Step 5:** `dart format .`, `flutter analyze`, then the test files from Tasks 1 to 4 by path.
- [ ] **Step 6: Commit** `feat(setup-wizard): offer the species model after the Photos step`.

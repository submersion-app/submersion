# Settings > Data phase 7: first run Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (chosen: Native, inline). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The first-run wizard and Settings > Manage > Setup assistant run the four shared set-up steps from #3620 in place of the wizard's Backups & Sync and Connect cloud sync steps, which are deleted.

**Architecture:** The step widgets stay in `lib/features/settings/presentation/widgets/set_up_device/` and learn which host runs them through a `SetUpHost` on `SetUpStepNavigation`. The wizard maps its own step ids to those widgets, hides its bottom bar on them, and keeps only the profile and units in its draft. Finish creates the diver only when the device has none.

**Tech Stack:** Flutter, Riverpod 3 (flutter_riverpod 3.4.2), go_router, ARB l10n (11 locales).

**Spec:** `docs/design/specs/2026-10-17-settings-data-setup-and-accounts-design.md` section 6.6 (amended 2026-10-25), with 6.3 and 6.4 for the steps. Issue #3482; PR body says `Refs #3482`.

## Global Constraints

- Each step writes when its primary button is tapped, in the wizard exactly as in Settings; Finish applies only the profile and the units.
- Finish creates the diver from the Profile name and the Units only when the device holds no diver once the steps are done.
- Fresh path order: Welcome, Profile, Units, Step 1, Step 2, Step 3, Step 4, Finish; "Skip setup" keeps Welcome, Profile, Finish.
- Existing-data "Connect cloud sync": Welcome, existing choice, Step 1, Step 2, Step 3, Step 4, Finish. Restore and Open an existing folder unchanged.
- Setup assistant: Units, the four steps pre-filled from the current state, Finish. Subtitle: "Revisit units, backups, sync and photos".
- No "Keep fresh": a found library on the fresh path offers only Download library.
- In the wizard: Step 1 shows no "I have a backup file instead" (first run only); Step 1's Not now skips Step 2 and opens Step 3; Not now on Steps 2 and 3 moves on; Skip on Step 4 settles it.
- Step 2 "in step" state: "The dives here are in step with your library in {account}." with Next.
- Never use the em-dash character in code, comments, strings or docs. No mention of the tooling anywhere in the repository or on GitHub.
- New strings go into all 11 ARBs (en, de, es, fr, it, nl, pt, hu, zh, ar, he) with the scratchpad `arb_tool.py`, then `flutter gen-l10n`; Arabic plurals need two, few and many forms; a changed English string is a changed key value in all 11.

## Review Focus

1. A fresh-path wizard quit after Step 2 uploaded, then rerun: Step 2 finds the device's own upload, Download library brings no diver, and Finish must still create the diver (Task 4 test `creates the diver when the device has none after a download`).
2. Step 3's "Open Backups" link on first run navigates while no diver exists, and the router's `/welcome` redirect would bounce it back into a second wizard: hidden on first run (Task 1 test `first run hides Open Backups`).
3. Existing-data path where the downloaded library holds no diver and the draft has no name: Finish must ask for a name instead of throwing `Diver name must not be empty` (Task 4 test `asks for a name when there is no diver and no name`).
4. The account chosen in Step 1 must survive the existing-data path's fall back to Profile and Units when the account holds no library (`setUpFlowProvider` is autoDispose): Task 5 test `the account survives the fall back to the fresh path`.
5. The Setup assistant's Finish must not touch backup settings any more, so re-entry never resets a schedule the steps did not show (Task 4 test `settings-mode Finish leaves backups as they are`).

---

### Task 1: Hosts for the shared steps

**Files:**
- Modify: `lib/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart`
- Modify: `.../set_up_device/set_up_account_step.dart`, `.../set_up_device/set_up_backups_step.dart`
- Test: `test/features/settings/presentation/widgets/set_up_device/set_up_account_step_test.dart`, `.../set_up_backups_step_test.dart`

**Interfaces:**
- Produces: `enum SetUpHost { settingsPage, firstRun, assistant }` with `bool get inWizard => this != settingsPage`; `SetUpStepNavigation({required onNext, required onBack, required onNotNow, VoidCallback? onSkip, VoidCallback? onNoLibrary, SetUpHost host = SetUpHost.settingsPage})`.

- [ ] **Step 1: Write the failing tests.**
  - Account step, `host: firstRun`: no "I have a backup file instead"; the back button reads "Back" and calls `onBack`; a "Not now" button calls `onNotNow`.
  - Account step, default host: unchanged (back reads "Not now", calls `onBack`; link shown).
  - Backups step, `host: firstRun` with no account: `first run hides Open Backups` (explanation shown, link absent).
  - Backups step, `host: assistant` with prefs `backup_enabled: false`, `backup_cloud_enabled: false`: both switches start off; with `backup_enabled: true` and a copy pinned, both start on.
- [ ] **Step 2: Run** `flutter test` on the two files. Expected: FAIL (no `host` parameter).
- [ ] **Step 3: Implement.** In the wizard the account step's scaffold uses `common_action_back` for back and a `TextButton` "Not now" (`settings_setUpDevice_notNow`) as `secondary`; the link shows only when `host != firstRun`. The backups step hides the link when `host == firstRun`, and with `host == assistant` seeds `_auto` from `settings.enabled` and `_copy` from `settings.cloudBackupEnabled` once, in `initState`.
- [ ] **Step 4: Run** the two files plus `test/features/settings/presentation/pages/set_up_device_page_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): set up steps know their host`.

### Task 2: Step 2 in step, and the wizard's no-library hand-off

**Files:**
- Modify: `.../set_up_device/set_up_sync_actions.dart`, `.../set_up_device/set_up_sync_step.dart`
- Test: `.../set_up_device/set_up_sync_step_test.dart`, `test/features/settings/presentation/widgets/sync/sync_account_switch_test.dart`

**Interfaces:**
- Consumes: `SetUpStepNavigation.onNoLibrary` (Task 1).
- Produces: `enum SetUpConnect { connected, inStep, failed }`; `Future<SetUpConnect> SetUpSyncActions.connect(BuildContext, WidgetRef, AccountGroup)`, `inStep` when sync already named the account before the call and `syncStateProvider.lastSync != null`.

- [ ] **Step 1: Write the failing tests.**
  - `sync_account_switch_test`: the existing "reports the account sync already uses as connected" becomes `inStep` when the host's `SyncState(lastSync: _t)`, `connected` with no lastSync; the Git-without-keys case reads `failed`.
  - Sync step with the fake answering `inStep`: shows "The dives here are in step with your library in Google Drive." and Next calls `onNext`; the library is never probed (`probes == 0`).
  - Sync step with `onNoLibrary` set and `NoLibrary(0)`: shows the `setup_syncPull_noLibrary_title` and `_message` texts and a primary "Start a new logbook" (`setup_syncPull_startFresh`, below) that calls `onNoLibrary`; without `onNoLibrary` the "Turn on sync" body is unchanged.
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement**, adding strings `settings_setUpDevice_sync_inStep` ("The dives here are in step with your library in {account}.") and `setup_syncPull_startFresh` ("Start a new logbook") in all 11 locales. `_connect` stores the `SetUpConnect`; `inStep` skips `refreshSetUpLibrary` and the body.
- [ ] **Step 4: Run** both files and `test/l10n`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): step 2 knows a device already in step`.

### Task 3: The wizard's steps and draft

**Files:**
- Modify: `lib/features/setup_wizard/domain/setup_wizard_models.dart`, `lib/features/setup_wizard/presentation/providers/setup_wizard_providers.dart`
- Test: `test/features/setup_wizard/domain/setup_wizard_models_test.dart`, `test/features/setup_wizard/presentation/providers/setup_wizard_providers_test.dart`

**Interfaces:**
- Produces: `SetupStepId` without `backupSync` and `syncConnect`, with `setUpAccount, setUpSync, setUpBackups, setUpPhotos`; `SetupWizardDraft` without `backupEnabled`, `backupFrequency`, `cloudBackupEnabled`, `connectedProvider`, with `bool needsProfile = false`; `SetupWizardNotifier.requireProfile()`; `const kSetUpWizardSteps = [setUpAccount, setUpSync, setUpBackups, setUpPhotos]`.

- [ ] **Step 1: Write the failing tests** for `computeSteps`: fresh `[welcomeFork, profile, units, ...kSetUpWizardSteps, finish]`; skip `[welcomeFork, profile, finish]`; existing cloudSync `[welcomeFork, existingChoice, ...kSetUpWizardSteps, finish]`, and with `needsProfile` `profile` inserted before `finish`; restore and openFolder unchanged; settings mode `[units, ...kSetUpWizardSteps, finish]`. Provider test: settings-mode seed reads only `settingsProvider`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement**; remove the backup setters and `setConnectedProvider`.
- [ ] **Step 4: Run** the two files. Expected: PASS (other wizard files fail to compile until Tasks 4 and 5; run only these).
- [ ] **Step 5: No commit yet**: Tasks 3 to 5 commit together once the wizard compiles.

### Task 4: Finish applies the profile and units only

**Files:**
- Modify: `lib/features/setup_wizard/data/setup_apply_service.dart`, `.../steps/finish_step.dart`
- Test: `test/features/setup_wizard/data/setup_apply_service_test.dart`, `.../steps/finish_step_test.dart`

**Interfaces:**
- Produces: `Future<FirstRunApply> SetupApplyService.applyFirstRun(draft, {deviceLanguageCodes})` with `enum FirstRunApply { created, keptExisting, needsName }`: `keptExisting` when `diverRepository.getDiverCount() > 0` (writes nothing), `needsName` when no diver and the name is blank (writes nothing), else creates as today without `_applyBackupChoices`. `applySettingsMode` keeps the unit and appearance setters and drops `_applyBackupChoices`, which is deleted. `FinishStep({required mode, VoidCallback? onNeedsName})`.

- [ ] **Step 1: Write the failing tests:** `creates the diver when the device has none after a download` (no divers, name set: created, diver exists); `keeps the library's divers` (one diver: `keptExisting`, count stays 1, its settings untouched); `asks for a name when there is no diver and no name` (`needsName`, nothing created); `settings-mode Finish leaves backups as they are` (backup prefs enabled with a pinned copy survive `applySettingsMode`). Finish step: on `needsName` it calls `onNeedsName` and does not navigate.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** On `needsName` Finish calls `onNeedsName`; the page (Task 5) calls `requireProfile()` and moves to the inserted Profile step.
- [ ] **Step 4: Run** the two files. Expected: PASS once Task 5 compiles; run with Task 5.

### Task 5: The wizard hosts the four steps; old steps deleted

**Files:**
- Modify: `lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart`
- Delete: `.../steps/backup_sync_step.dart`, `.../steps/sync_connect_step.dart`, their tests `backup_sync_step_test.dart`, `sync_connect_step_test.dart`
- Modify: `.../steps/existing_choice_step.dart` only if it imports a deleted file
- Test: `test/features/setup_wizard/presentation/pages/setup_wizard_page_test.dart`, `existing_data_steps_test.dart`, `first_run_redirect_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 4.
- Produces: the step indicator shows the four set up steps as one dot labelled with the existing `settings_section_data_title` ("Data"), so the fresh path keeps four dots and fits a phone (changed in review from four per-step labels, which overflowed at 320 pt); `setup_step_backup` deleted.

- [ ] **Step 1: Write the failing tests** (step bodies stubbed where a step needs the network, through the existing page test harness):
  - fresh path pages in spec order, the bottom bar hidden on the four steps;
  - Step 1 Not now lands on Step 3; Step 2 and Step 3 Not now move on; Step 4 Skip lands on Finish with `setup_photos_skipped` true;
  - existing cloudSync path: Step 2 `onNoLibrary` switches to the fresh path at Profile, and `the account survives the fall back to the fresh path` (Step 1 then shows the account chosen);
  - Finish `onNeedsName` moves to the inserted Profile page;
  - settings mode runs Units, the four steps with `SetUpHost.assistant`, Finish.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** `_defFor` builds each set-up step with `hideBottomBar: true` and a `SetUpStepNavigation` whose `host` is `firstRun` or `assistant` by mode: `onNext` advances; `onBack` goes back; `onNotNow` jumps to `setUpBackups` from `setUpAccount` and advances otherwise; `onSkip` (photos) advances; `onNoLibrary` only on the existing-data path. The page watches `setUpFlowProvider` so the choice outlives page changes. Remove `_offerAdoptPivot` and the `setup_sync_libraryFound_*` strings with every other key only the deleted files used (grep each before deleting).
- [ ] **Step 4: Run** `test/features/setup_wizard`, `test/features/settings`, `test/core/router`, `test/architecture`, `test/l10n`. Expected: PASS, 0 `[E]` lines in the log.
- [ ] **Step 5: Commit** Tasks 3 to 5 as `feat(setup-wizard): first run runs the shared set-up steps`.

### Task 6: The Setup assistant's words and the user guide

**Files:**
- Modify: ARBs (`settings_manage_setupAssistant_subtitle` = "Revisit units, backups, sync and photos" in 11 locales)
- Modify: `docs/user/set-up-this-device.md` (a "On first launch" section and the Setup assistant), `docs/user/first-dive.md` (the wizard's steps), `docs/user/settings.md` (Manage > Setup assistant), `docs/user/multi-device-sync.md` (step 1 of Adding More Devices)

- [ ] **Step 1:** Change the string in 11 locales; `flutter gen-l10n`; run `test/l10n` and `test/features/settings/presentation/pages/manage_section_content_test.dart` if it asserts the subtitle.
- [ ] **Step 2:** Update the guides; run `python3.14 scripts/check_docs_links.py`. Expected: ok.
- [ ] **Step 3: Commit** `docs(user): first run uses the set up steps`.

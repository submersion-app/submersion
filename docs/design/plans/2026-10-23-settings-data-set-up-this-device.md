# Settings > Data, PR 6: Set up this device Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One re-runnable "Set up this phone" flow with four steps (account, sync, backups, photos), shown as a card on the Data page and the Settings root. It replaces the "Finish setting up this device" pending card and the Photos page's guided-setup checklist, and makes replace and join (PR 5) reachable from step 2.

**Architecture:**
- **Derived state.** The card and each step's mark are computed by a pure function over facts the app already has: accounts signed in here, sync established, the backup settings and the photo attachment. Two device-local prefs, hidden and photos skipped, are the only state the card owns. A third pref marks the one-time upgrade seed as done.
- **One card widget, two forms.** `SetUpDeviceCard` renders the full form on the Data page and the compact form on the Settings root. Below the steps it lists the pending setup service's items (spec 6.5), so `PendingSetupCard` is deleted and its three call sites go.
- **A pushed flow page.** `SetUpDevicePage` lives at `/settings/setup`, mapped into the Data pane like every other Data sub-page. It hosts four step widgets and a done view, each built on one shared `SetUpStepScaffold`. The step widgets take callbacks, not routes, so the wizard (PR 7) can host them in its own shell.
- **Step 2 adds no new sync path.** It reads the account with `SyncInitializer.firstContactLibraryState` and the device footprints, then acts through `SyncNotifier.performSync`, the adopt dialog, the encryption unlock and `replaceAndJoinServiceProvider`. The replace runs on a full-screen page that ends in `restartApp()`, as Reset Database and Restore do.

**Tech Stack:** Flutter, Riverpod 3, SharedPreferences, go_router with the settings pane navigator, the l10n ARB files (11 locales), and `flutter_test` with provider overrides and the fake cloud provider.

**Spec:** `docs/design/specs/2026-10-17-settings-data-setup-and-accounts-design.md`, sections 5, 6.1-6.5 (6.6 is PR 7), 10, 11 (phase 6), 12 and the appendix rows for the pending card, the Photos checklist and the wizard. Phases 1-5 shipped as #3485, #3500, #3527, #3541, #3547 and #3572.

**Delivery (decided by the user):** two PRs. PR 6a is Part A (Tasks 1-6), where Continue and the rows' Set up buttons still open today's pages. PR 6b is Part B (Tasks 7-14). Ruling 3 was approved as written. Screenshots are listed in each PR for the maintainer to capture.

## Global Constraints

- **No schema change and no sync-format change.** The step 2 sentence names the device and time from the manifest only; there is no dive count (spec 12).
- **Nothing is persisted until a step's primary button is tapped** (spec 6.3), with the one sanctioned exception in ruling 3.
- **Every string goes in all 11 ARB files** under new `settings_setUpDevice_*` keys. Keys that lose their last reader are deleted from all 11. Sentence case throughout.
- **Device word:** "phone", "tablet" or "computer" from `deviceKindOf(context)`, "device" otherwise. It goes through an ARB `select`, never string concatenation.
- **Files stay under 800 lines; new files stay under 400.** `data_section_content.dart` (183 lines) and `account_sheet.dart` (359) must not cross 400.
- **Step widgets never read `GoRouter` or push routes for their own navigation.** They call `onNext` / `onBack` / `onNotNow` / `onSkip`, so PR 7 can host them in the wizard.
- **Writing style:** no em dashes and no tool names or attribution. Every commit and the PR say `Refs #3482`.
- **Tests restore any global state they replace.** After adding files under `lib/`, run `test/architecture` and `test/shared`.

## Rulings and deferrals

Calls this plan makes where the spec leaves a choice, or the code contradicts it. Each is cheap to reverse.

1. **The `deviceKind` select does not exist.** The spec (12) says the ARB files already have one; they have only a conflict-side `thisDevice/otherDevice` select. This PR adds `enum DeviceKind { phone, tablet, computer, other }`:
   - iOS and Android give `phone`, or `tablet` when `shortestSide >= 600`.
   - macOS, Windows and Linux give `computer`.
   - Anything else gives `other`.

   "Laptop" cannot be told apart from a desktop, so it is never used.
2. **The steps count as settled when done or skipped.** The "2 of 4" count is settled steps. The card disappears when all four are settled, and "Set up this phone again" then appears under Advanced.
3. **Step 2 points sync at the chosen account when it opens.**
   - **Why:** a library can only be read once sync names the account (`cloudStorageProviderProvider` is the sync selection), so step 2 cannot say "Found your library" otherwise.
   - **What it does:** it calls `useAccountForSync` (the wizard writes the same provider connection at connect time today, which spec 6.6 keeps). It runs no sync and leaves automatic sync as it was.
   - **What is confirmed first:** a switch away from an account this device already synced with, shown by step 1 through `syncSwitchConsequence`, exactly as the Sync page's Change does.
   - **Not now:** sync stays pointed at the account and has not run; the Sync row reads as set up but never synced.
4. **Done rules** (spec 6.4, read literally):

   | Step | Done when |
   |---|---|
   | Account | A feature names an account here: sync is selected, the backup copy is pinned (while the copy is on, to a row the roster still has), or photos are attached. (Changed in review: no account status is probed on the Settings root or the Data page.) |
   | Sync | `isSyncEnabledProvider` is on and `syncStateProvider.lastSync != null`, which `refreshState` now clears for a backend never synced with. |
   | Backups | `enabled` and either a cloud copy with somewhere to go (pinned to a row the roster has, or following a selected sync account) or `backupLocation != null`. |
   | Photos | `mediaStoreAttachedProvider` is true, or the step was skipped. |

   A custom database folder (`storageConfig` custom) settles Account and Sync. The diver chose where the data lives, and nagging them to pick an account would contradict that choice. On Android the folder is a device volume no service keeps in step (the Sync row reads "Only on this device"), so there it settles neither (changed in review).
5. **The upgrade seed runs at startup, once.** It runs in the startup sequence's account-migration step, with the database open and before the app mounts, so the card's first build reads the seeded values (moved there in review from the `diverCountProvider` listener in `lib/app.dart`). A failure is logged and retried next launch.
   - Prefs already there: either `setup_card_hidden` or `setup_photos_skipped` present marks the seed done and changes nothing else.
   - Database holds a diver: writes hidden and skipped, then marks the seed done.
   - No diver (a fresh install): only marks the seed done.

   Without the done mark, a fresh install would be seeded as soon as its wizard created the first diver.
6. **Pending items under the steps** (spec 6.5) keep `PendingSetupService` and its dismiss keys unchanged.
   - **Sign-in item:** the button "Sign in" runs `signInToGroup` for that account, when this build can sign in to its kind; otherwise it opens the page that resolves the item. The line names what pauses from the account's uses: sync, backups, both or neither.
   - **Attach item:** opens the photos step. The full card leaves it out while its steps show photos as outstanding, since the step already covers it; the compact card always lists it.
   - **Reconnect item:** opens Photos & videos.
   - **Every page the card opens** goes through its host: the Data page pushes in the pane, the desktop settings list opens the Data pane, a phone's list pushes. While Settings > Data is selected on desktop, the list shows no card.
   - **Hidden card:** the items still show; only the steps section hides.
7. **Removed outright, with no redirect:**
   - the Photos checklist page (`PhotosMediaSetupPage`, `setupGuideStatusProvider`) and its route `/settings/photos-media/setup`;
   - the toolbar icon that opens it.

   No caller outside the page itself and the router reaches the route.
8. **"Start fresh" stays in the wizard.** For an unfinished upload, step 2 in Settings offers only "Check again". There, starting fresh means overwriting the account's half-written library, which is the separate Advanced action "Replace the library with this phone's copy".
9. **Step 4 on a second device states no count.** The announced store's descriptor does not know how many copies another device made, so the sentence reads "Your other devices keep copies of your photos and videos in {account}". The first-device subtitle counts this device's own attached items with `mediaUploadProgressProvider.total`.
10. **"Use cellular data" in step 4 writes what the Photos page's switch writes** (`setPhotosOnCellular`). The step starts it off, as the spec asks, even though the policy default is on.
11. **The done screen's "Upload everything already attached" queues immediately.** It calls `mediaBackfillServiceProvider.enqueueAll()` and drains the worker, as Advanced does, and shows the existing snackbar.
12. **The new typed-word confirm is a shared widget,** `TypedWordConfirmDialog`. The three existing copies (Reset Database, Replace cloud library, Delete diver) are left as they are; moving them is outside this PR.

## Review Focus

1. **An upgraded device** (prefs absent, divers present) never shows the steps after launch. A fresh install that finishes the wizard does show them (Task 2).
2. **Step 2 on a device whose sync account is locked by encryption:** the passphrase field appears, a wrong secret shows the unlock error, and nothing syncs until it is unlocked (Task 9).
3. **Replace on a device with dives:**
   - Cancelling the typed-word dialog, or a `photosBusy`, `noLibrary`, `newerSchema` or `needsPassphrase` outcome, changes nothing and keeps the diver on the step with a message.
   - Only `replaced` reaches the reload page (Task 10).
4. **Leaving any step with Back or Not now writes nothing.** This is asserted on the prefs and the backup settings (Tasks 8, 11, 12).
5. **The card in the master-detail pane on desktop:** Continue opens the flow inside the Data pane, not over the whole window (Task 6).

---

## Part A: the card (Tasks 1-6)

### Task 1: The setup progress model

**Files:** Create `lib/features/settings/domain/setup/set_up_progress.dart`; Test `test/features/settings/domain/setup/set_up_progress_test.dart`

**Produces:**
- `enum SetUpStep { account, sync, backups, photos }`
- `enum SetUpMark { done, next, notYet, skipped }`
- `class SetUpInputs({required bool accountHere, required bool syncEstablished, required bool customFolder, required bool backupsAuto, required bool backupOffDevice, required bool photosAttached, required bool photosSkipped, required bool hidden})`
- `class SetUpProgress { Map<SetUpStep, SetUpMark> marks; int settled; SetUpStep? next; bool anyDone; bool get complete => next == null; bool showsSteps; }`
- `SetUpProgress setUpProgress(SetUpInputs inputs)`

- [ ] Write a table test. Each row gives inputs and the expected marks, `settled`, `next`, `anyDone` and `showsSteps`. Rows:
  - all false;
  - account only;
  - custom folder;
  - all done;
  - photos skipped with the rest done (complete, `showsSteps` false);
  - hidden with steps outstanding (`showsSteps` false, `next` still set);
  - sync done but backups not (backups is `next`, photos `notYet`).
- [ ] Run it and see it fail: the file is missing.
- [ ] Implement the rules of rulings 2 and 4. `next` is the first step neither done nor skipped. `showsSteps` is `!hidden && !complete`.
- [ ] Run and see it pass; commit `feat(settings): derive set up this device progress`.

### Task 2: Card prefs and the upgrade seed

**Files:**
- Create `lib/features/settings/data/set_up_card_prefs.dart`.
- Modify `lib/app.dart`, in the `diverCountProvider` listener.
- Test `test/features/settings/data/set_up_card_prefs_test.dart` and `test/app_set_up_seed_test.dart`, or the nearest existing app test harness.

**Produces:**
- `class SetUpCardPrefs(SharedPreferences prefs)` with keys `setup_card_hidden`, `setup_photos_skipped` and `setup_card_seed_done`.
- Getters `hidden` and `photosSkipped`; setters `setHidden(bool)` and `setPhotosSkipped(bool)`.
- `Future<void> seedOnce({required int diverCount})`.
- `final setUpCardPrefsProvider = NotifierProvider<SetUpCardPrefsNotifier, ({bool hidden, bool photosSkipped})>`. Its setters write through, so the card rebuilds.

- [ ] Write the tests:
  - `seedOnce` with divers hides the card and skips photos;
  - with 0 divers it writes only the done mark;
  - a second call after divers appear changes nothing;
  - an existing `setup_card_hidden=false` is kept and marks the seed done.
- [ ] Add an app test: an upgraded device (divers, no prefs) ends with hidden true after the first frame.
- [ ] Run them and see them fail.
- [ ] Implement ruling 5. Seed on the listener's first `next.hasValue`, guarded so it runs once per process.
- [ ] Run and see them pass; commit `feat(settings): hide the set up card on upgraded devices`.

### Task 3: The progress provider

**Files:** Create `lib/features/settings/presentation/providers/set_up_progress_provider.dart`; Test `test/features/settings/presentation/providers/set_up_progress_provider_test.dart`

**Produces:** `final setUpProgressProvider = Provider.autoDispose<SetUpProgress?>`. It is null while any input is loading. It watches:
- `accountGroupsProvider`, filtered by `syncAccountKinds` and `signedInHere`;
- `isSyncEnabledProvider` and `lastSyncTimeProvider`;
- `storageConfigNotifierProvider`, for the custom folder;
- `backupSettingsProvider`;
- `mediaStoreAttachedProvider`;
- `setUpCardPrefsProvider`.

- [ ] Write provider tests with overrides, one per input, each showing the mark it moves. Add a loading case that returns null.
- [ ] Run them and see them fail.
- [ ] Implement.
- [ ] Run and see them pass; commit `feat(settings): set up progress from live state`.

### Task 4: The device word and the card's strings

**Files:**
- Create `lib/shared/utils/device_kind.dart`.
- Modify all 11 `lib/l10n/arb/app_*.arb`.
- Test `test/shared/utils/device_kind_test.dart`.

**Produces:**
- `enum DeviceKind { phone, tablet, computer, other }`
- `DeviceKind deviceKindOf(BuildContext context)`
- `String deviceKindArg(DeviceKind kind)`, which gives `'phone' | 'tablet' | 'computer' | 'other'` for ARB selects.

- [ ] Write tests:
  - Android at 390x844 gives phone;
  - iOS at 820x1180 gives tablet;
  - macOS gives computer.

  Use `debugDefaultTargetPlatformOverride`, restored in `addTearDown`.
- [ ] Run them and see them fail.
- [ ] Implement.
- [ ] Add the card's keys with translations through the scratchpad `arb_tool.py`. Each title has a `{device, select, ...}` argument:
  - `settings_setUpDevice_title`: "Set up this {device}"
  - `settings_setUpDevice_titleFinish`: "Finish setting up this {device}"
  - `settings_setUpDevice_count`: "{done} of {total}"
  - `settings_setUpDevice_continue`: "Continue"
  - `settings_setUpDevice_hide`: "Hide this card"
  - the four step names;
  - the four mark labels, used for semantics;
  - `settings_setUpDevice_again`: "Set up this {device} again"
  - the three pending-item texts and "Sign in".
- [ ] Run `flutter gen-l10n`, then `test/l10n` if present. Commit `feat(settings): device word and set up card strings`.

### Task 5: `SetUpDeviceCard`, replacing `PendingSetupCard`

**Files:**
- Create:
  - `lib/features/settings/presentation/widgets/set_up_device/set_up_device_card.dart`
  - `.../set_up_step_marks.dart`
  - `.../set_up_pending_items.dart`
- Modify:
  - `settings_page.dart` and `settings_list_content.dart` (row 0);
  - `photos_videos_page.dart` (drop the card, `_showUsingRow` and the Guided setup icon);
  - `app_router.dart` and `data_settings_pane.dart` (drop `photos-media/setup`).
- Delete:
  - `pending_setup_card.dart` and `photos_media_setup_page.dart`, with their tests;
  - the router-test and smoke-test entries for them;
  - the ARB keys that lose their last reader (`settings_setup_*`, `settings_setupGuide_*`, `settings_photosMedia_guidedSetup`).
- Move `pendingSetupItemsProvider` and its tick providers to `lib/features/settings/presentation/providers/pending_setup_items_provider.dart`. The four readers keep reading it.
- Test `test/features/settings/presentation/widgets/set_up_device/set_up_device_card_test.dart`.

**Produces:** `SetUpDeviceCard({bool compact = false, required ValueChanged<SetUpStep> onOpenStep})`.

- [ ] Write widget tests:
  - **Full form:** title "Set up this phone" with no step done, "Finish setting up this phone" once one is; "1 of 4"; four marks; Continue calls `onOpenStep(next)`.
  - **Hide:** the overflow's Hide writes `setup_card_hidden`.
  - **Compact form:** title, count and Continue, with no marks.
  - **Hidden:** a sign-in item still shows. Its Sign in calls the injected sign-in; its close writes the existing dismiss key.
  - **Attach item:** not shown while photos is outstanding in the steps; shown when photos was skipped.
  - **Nothing to show:** renders `SizedBox.shrink()`.
- [ ] Run them and see them fail.
- [ ] Implement.
- [ ] Rewire the three call sites:
  - the Settings root (both layouts) gets `compact: true`;
  - the Photos page gets none (its status line already says "finish setting up" and "reconnect");
  - the Data page is Task 6.
- [ ] Update `photos_videos_page_layout_test.dart` and `photos_videos_page_self_route_test.dart`, dropping the guided-setup and pending-card groups.
- [ ] Delete the replaced files and keys.
- [ ] Run `test/features/settings`, `test/features/media_store`, `test/core/router` and `test/architecture`. Commit `feat(settings): one set up card replaces the pending card and the photos checklist`.

### Task 6: The Data page

**Files:**
- Modify `data_section_content.dart`, so the card sits between the strip and the facts line (spec 5).
- Modify `data_row_tile.dart` callers so each row passes `setUpRoute`.
- Test: extend `data_section_content_test.dart`.

Until Part B lands, a step opens today's page:

| Step | Opens |
|---|---|
| Account | `/settings/connected-accounts` |
| Sync | `/settings/cloud-sync` |
| Backups | `/settings/backup` |
| Photos | `/settings/photos-media` |

The function `String setUpStepRoute(SetUpStep step)` holds this mapping, so Part B changes one function.

- [ ] Write tests:
  - the card renders under the strip;
  - "Set up this phone again" is under Advanced only when the card is hidden or complete, and tapping it clears hidden;
  - in the pane (width 1280) Continue opens inside the Data pane; on a phone it pushes.
- [ ] Run them and see them fail.
- [ ] Implement.
- [ ] Run and see them pass.
- [ ] Run `dart format .`, `flutter analyze`, `test/features/settings`, `test/architecture` and `test/shared`. Commit `feat(settings): the set up card on the Data page`.

---

## Part B: the flow (Tasks 7-14)

**Reconciled with PR 6a's review (Part B rulings):**

- B1. `setUpStepRoute` returns `/settings/setup?step=<name>`; the card, the rows and the desktop list's `dataPaneLocation` follow, the query carried into the Data pane as `dataPage=setup?step=<name>`.
- B2. "Set up this phone again" opens `/settings/setup?again=true`, and the page clears "hidden" when it opens that way (the destination carries the un-hide), so `DataRowTile.onOpen` goes.
- B3. The page owns which step shows; `setUpFlowProvider` holds only the account chosen in step 1, which later steps read.
- B4. The rows' Set up buttons, removed in 6a as a no-op, come back in Task 13 now that they open a step.
- B5. Steps 3 and 4 take the `SetUpStepNavigation` object steps 1 and 2 take, not three callbacks.
- B6. Step 4 on a later device names the account only ("Your other devices keep photo and video copies in {account}"): the announced store carries neither the peer's name nor a count. Copies whose account this device cannot name open the account sheet on Next, as the Photos row does. A flow account that cannot hold photos (Git) shows the note alone.
- B7. Step 4 signs in first when the copies' account is not signed in here, whether or not it is the flow's account; "Same account. Nothing to type." shows when it is the flow's account.
- B8. The photo count is the library's photos and videos (`MediaRepository.countPhotosAndVideos`), the same rows a store keeps copies of; signatures and documents are not counted.
- B10. Sync's Set up always opens step 1 (PR review): the Sync row offers Set up only while sync is off, when step 2 has no account to read, and the card's account mark also counts a backup copy or photo store.
- B9. The done view's four outcome lines are the Data page's own rows (Connected accounts, Sync, Backups, Photos & videos) through `dataRowStatusText`, so the two read the same words.

### Task 7: Flow page, route and shared scaffold

**Files:**
- Create:
  - `lib/features/settings/presentation/pages/set_up_device_page.dart`
  - `lib/features/settings/presentation/widgets/set_up_device/set_up_step_scaffold.dart`
  - `lib/features/settings/presentation/providers/set_up_flow_provider.dart`
- Modify `app_router.dart` (`/settings/setup`, with query `step` and `again`), `data_settings_pane.dart` (`['setup']`) and `setUpStepRoute` (now `/settings/setup?step=<name>`).
- Test `test/features/settings/presentation/pages/set_up_device_page_test.dart`.

**Produces:**
- `SetUpDevicePage({SetUpStep? start, bool again = false})`
- `final setUpFlowProvider = NotifierProvider.autoDispose<SetUpFlowNotifier, SetUpFlowState>`, where `SetUpFlowState({AccountGroup? account, SetUpStep step, bool showDone})`
- `SetUpStepScaffold({required String title, String? intro, required List<Widget> children, required String backLabel, required VoidCallback onBack, required String primaryLabel, required VoidCallback? onPrimary, bool busy = false, Widget? secondary})`

Navigation:
- Start: `start ?? progress.next ?? SetUpStep.account`.
- `again` starts at Account with every step shown.
- Back moves to the previous step; on Account its label is "Not now", which pops.
- Not now on Sync or Backups pops to the Data page.
- After Photos (Next or Skip) comes the done view.

- [ ] Write tests:
  - the page opens at the progress's next step;
  - `again` opens at Account;
  - "Not now" pops;
  - the route resolves in the pane map and in the router (add to the `app_router_test` pane-parity list).
- [ ] Run them and see them fail.
- [ ] Implement, with placeholder step bodies.
- [ ] Run and see them pass; commit `feat(settings): set up this device flow page`.

### Task 8: Step 1, the account

**Files:**
- Modify `account_sheet.dart`: extract the public `AccountChooser`, which `_AccountSheet` then wraps.
- Create `.../set_up_device/set_up_account_step.dart`.
- Modify `backup_actions.dart`: make `_restoreFromFile` public as `restoreFromFile`.
- Test `set_up_account_step_test.dart`; the existing `account_sheet_test.dart` must stay green.

**Produces:**
- `AccountChooser({Set<AccountKind>? allowedKinds, String? currentKey, String? Function(AccountGroup)? consequenceOf, required ValueChanged<AccountGroup> onChosen, ScrollController? controller})`
- `SetUpAccountStep({required ValueChanged<AccountGroup> onNext, required VoidCallback onNotNow})`

Strings:
- titles "Where should Submersion keep your data?" and "Where is your data?", the second used when a library is found later; Settings mode uses the first;
- the four offer subtitles from spec 6.4;
- the note "Your dives are stored only in the account you choose. Submersion has no server of its own.";
- the link "I have a backup file instead".

- [ ] Write tests:
  - signed-in accounts are listed first;
  - choosing one stores it in `setUpFlowProvider` and calls `onNext`, writing no prefs and leaving the sync selection null;
  - with a synced current account, choosing another shows the switch consequence first;
  - the backup-file link calls `restoreFromFile`.
- [ ] Run them and see them fail.
- [ ] Implement, with `allowedKinds: syncAccountKinds` and `consequenceOf: syncSwitchConsequence`.
- [ ] Run, plus `test/features/settings/presentation/widgets/accounts`; commit `feat(settings): step 1 chooses the account`.

### Task 9: Step 2, reading the library

**Files:** Create `lib/features/settings/presentation/providers/set_up_library_probe.dart`; Test `test/features/settings/presentation/providers/set_up_library_probe_test.dart`, using the fake cloud provider from `test/helpers/sync_test_helpers.dart`.

**Produces:**
- `sealed class SetUpLibrary` with:
  - `NoLibrary(int localDives)`
  - `LibraryFound({String? deviceName, DateTime? changedAt, int localDives})`
  - `LibraryLocked()`
  - `LibraryIncomplete()`
  - `LibraryAwaitingAdoption(LibraryEpochMarker marker)`
- `Future<SetUpLibrary> probeSetUpLibrary(Ref ref)`

The probe works in this order:
1. Count the local dives with `diveRepository.getDiveCount()`.
2. If `syncStateProvider.notifier.libraryReplaceInfo()` is non-null, return awaiting adoption.
3. Classify with `syncInitializerProvider.firstContactLibraryState(cloudStorageProviderProvider, localLibraryIsEmpty: localDives == 0)`.
4. For a library, take the newest non-self footprint from `SyncDeviceFootprints.list`. If every peer footprint is `unreadable`, return locked.

- [ ] Write tests, one per outcome:
  - no peer files;
  - a peer manifest named "Eric's iPhone" (deviceName and time come through);
  - an encrypted peer manifest without a key;
  - a base-less marker;
  - a replace marker.
- [ ] Run them and see them fail.
- [ ] Implement.
- [ ] Run and see them pass; commit `feat(sync): read the account's library for set up`.

### Task 10: Step 2, the step and replace and join

**Files:**
- Create:
  - `.../set_up_device/set_up_sync_step.dart`
  - `.../set_up_device/set_up_sync_actions.dart`
  - `lib/shared/widgets/typed_word_confirm_dialog.dart`
  - `lib/features/settings/presentation/pages/replace_join_page.dart`
- Modify `encryption_settings_section.dart`: extract `Future<void> unlockSyncLibrary(WidgetRef ref, String secret)` from `runEncryptionUnlockFlow`'s `onSubmit`, which then calls it.
- Test `set_up_sync_step_test.dart`, `replace_join_page_test.dart` and `typed_word_confirm_dialog_test.dart`.

**Produces:**
- `SetUpSyncStep({required VoidCallback onNext, required VoidCallback onBack, required VoidCallback onNotNow})`
- `Future<bool> runSetUpFirstSync(WidgetRef ref, {required bool keepInStep, required bool realignDiver})`. It calls `performSync()`. On success, with `keepInStep`, it calls `setAutoSyncEnabled`, `setSyncOnLaunch` and `setSyncOnResume`, all true. With `realignDiver` it runs `realignActiveDiverAfterDataReplace` and invalidates `allDiversProvider`. It returns false on `SyncStatus.error` or `needsPassphrase`.
- `TypedWordConfirmDialog.show(context, {title, body, word, hint, confirmLabel})`, which returns `Future<bool>`.
- `ReplaceJoinPage.show(context, {required int diveCount})`. It pushes on the root navigator, runs `replaceAndJoinServiceProvider.run(backupNote:)`, and either shows the completion text with Reload (`restartApp()`) or pops with a `ReplaceJoinOutcome`, or with an error that becomes "Nothing was changed".

The step, in order:
1. On entry, `useAccountForSync(context, ref, flow.account, current: currentSyncGroup(groups))` (ruling 3), then `probeSetUpLibrary`.
2. It renders the spec 6.4 variant for the probe result. The adopt and incomplete states use today's texts: `setup_syncPull_incomplete_*` with "Check again", and the adopt dialog keys.
3. The "Keep devices in step automatically" switch is on by default.
4. Progress shows in place from `syncStateProvider.message`.
5. The primary button, by state:

   | State | Button | Action |
   |---|---|---|
   | No library | "Turn on sync" | first sync |
   | Library found, device empty | "Download library" | first sync, then realign |
   | Library found, Combine chosen | "Combine and download" | first sync; the Combine dialog is not shown again, since the step already asked |
   | Library found, Replace chosen | "Replace and download" | `TypedWordConfirmDialog` with the word `settings_cloudSync_replaceLibrary_confirmWord`, then `ReplaceJoinPage` |
   | Locked | (field shown) | the passphrase field calls `unlockSyncLibrary`, then probes again |

6. Replace outcomes: `needsPassphrase` shows the field; `noLibrary`, `stillUploading`, `newerSchema` (naming `newerSchemaPeerNames`) and `photosBusy` each show one line and stay on the step.

Strings:
- the spec 6.4 sentences, including "Found your library in {account}, last changed {when} on {device}";
- "Before joining the library, {date}";
- the dialog body "This {device}'s {n} dives are replaced by the library in {account}. A backup of them is saved first and stays under Backups.";
- the completion text "Your {n} dives were set aside and the library was downloaded. Submersion will reload.";
- one line per refusal.

- [ ] Write the tests:
  - each probe variant renders its sentence and primary label;
  - Turn on sync with the switch on writes the three sync behavior settings, and with it off writes none;
  - Not now writes nothing beyond ruling 3;
  - Replace: cancelling the dialog runs nothing; a fake service returning each refusal keeps the step with its line; `replaced` shows the completion page, whose Reload calls an injected restart;
  - the passphrase field: a wrong secret shows the error, a right one probes again.
- [ ] Run them and see them fail.
- [ ] Implement.
- [ ] Run, plus `test/features/settings/presentation/widgets/encryption*`; commit `feat(settings): step 2 joins or starts the library`.

### Task 11: Step 3, backups

**Files:**
- Create `.../set_up_device/set_up_backups_step.dart`.
- Modify `backup_copy_row.dart`: extract `Future<void> applyBackupCopyChoice(WidgetRef ref, AccountSheetChoice choice, {AccountGroup? syncGroup})`, which the row then calls.
- Test `set_up_backups_step_test.dart`.

**Produces:** `SetUpBackupsStep({required VoidCallback onNext, required VoidCallback onBack, required VoidCallback onNotNow})`

Next writes:
- `setEnabled(auto)`, keeping the frequency;
- if the copy is on, `applyBackupCopyChoice(ChoseAccount(account), syncGroup:)`, so the sync account gives "copy follows sync" and any other account pins the copy; if off, `setNoCopy()`.

With no account, the copy switch is replaced by the explanation and a link to Backups. The desktop subtitle uses `DeviceKind.computer`.

- [ ] Write the tests:
  - the defaults are both on;
  - Next with the sync account gives `cloudBackupEnabled` true and no pinned account;
  - with another account, it is pinned;
  - with the copy off, `setNoCopy`;
  - Back writes nothing;
  - with no account, the switch is absent.
- [ ] Run them and see them fail.
- [ ] Implement.
- [ ] Run, plus `test/features/backup`; commit `feat(settings): step 3 turns on backups`.

### Task 12: Step 4, photos

**Files:**
- Create `.../set_up_device/set_up_photos_step.dart`.
- Modify `photos_using_row.dart`: extract `Future<bool> attachPhotosAccount(BuildContext context, WidgetRef ref, AccountGroup group, {PhotosCopies? copies})` from L89-158 (the certificate retry and the "started separate" snackbar), which the row then calls.
- Test `set_up_photos_step_test.dart`.

**Produces:** `SetUpPhotosStep({required VoidCallback onNext, required VoidCallback onBack, required VoidCallback onSkip})`

- **First device** (no store in `photosCopiesProvider`): the switch is off. When it is on, the auto-upload switch shows (on) and cellular (off).
- **Second device** (a store is announced): the switch is on.
  - When the store's account is the flow's account, the subtitle reads "Same account. Nothing to type."
  - Otherwise Next first runs `signInToGroup` for the store's group.

Next:
1. If the switch is on, `attachPhotosAccount`, then `setAutoUpload` and `setPhotosOnCellular`.
2. Then `onNext`.

Skip calls `setPhotosSkipped(true)`, then `onSkip`.

- [ ] Write the tests:
  - the first-device defaults, and the count in the subtitle;
  - the second device on the same account says "Nothing to type";
  - on another account, Next signs in first;
  - Next with the switch off writes nothing;
  - Skip writes the pref;
  - Back writes nothing.
- [ ] Run them and see them fail.
- [ ] Implement.
- [ ] Run, plus `test/features/media_store`; commit `feat(settings): step 4 shares photo copies`.

### Task 13: The done view and the Data rows

**Files:**
- Create `.../set_up_device/set_up_done_view.dart`.
- Modify `data_section_content.dart`: rows pass `setUpRoute: setUpStepRoute(step)`. The Sync row opens Account when the account step is not done.
- Test `set_up_done_view_test.dart`; extend `data_section_content_test.dart`.

The done view shows "This {device} is set up" and one line per outcome. The lines come from the existing row-status texts where they exist, so they cannot drift from the Data page. Then come the "On your other devices..." sentence, "Upload everything already attached" (ruling 11; shown when attached and the upload total is above the copied count) and Done, which pops.

- [ ] Write the tests:
  - the outcome lines for a fully set up device and for one with photos skipped;
  - the upload button queues once;
  - each row's Set up opens its step.
- [ ] Run them and see them fail.
- [ ] Implement.
- [ ] Run and see them pass; commit `feat(settings): set up done screen`.

### Task 14: The user guide

**Files:**
- Create `docs/user/set-up-this-device.md`.
- Modify:
  - `docs/user/README.md` (a "Start here" link);
  - `docs/user/settings.md` (the Data section);
  - `docs/user/media-sync.md` (L18 "Guided setup", and the setup section pointing at the card);
  - `docs/user/multi-device-sync.md` ("Adding more devices", with Combine or Replace and the set-aside backup).

- [ ] Write the guide: the four steps, hiding and reopening, the second device, replace and join and its backup, what the card shows later.
- [ ] Run `python3.14 scripts/check_docs_links.py`.
- [ ] Commit `docs(user): set up this device guide`.

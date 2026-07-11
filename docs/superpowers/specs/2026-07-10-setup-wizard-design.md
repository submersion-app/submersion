# Setup Wizard for New Databases — Design

**Date:** 2026-07-10
**Source:** [Discussion #523](https://github.com/submersion-app/submersion/discussions/523)
**Status:** Implemented (PR #544)

## Revisions (post-implementation)

- **Appearance step removed** from the fresh path per user feedback during
  device testing. Theme, map style, and language stay in Settings. The fresh
  path is now Profile → Units → Backup & Sync → Finish. The `previewLocale`
  locale-preview mechanism (below) was removed with it — the sections
  describing Appearance and locale preview are retained for history but no
  longer reflect the shipped flow.
- **S3 config opens on the root navigator**, not `context.push`. During first
  run the database has zero divers, so the router's onboarding redirect
  bounces any go_router navigation back to `/welcome`; S3 config is a modal
  action pushed above the wizard instead.
- **Every step past the fork is reversible.** The existing-data steps (choice,
  restore, sync, open-folder) render a top back bar; the form-zone steps keep
  their bottom-bar Back button.

## Problem

Submersion's first-run experience is a single name-only welcome page
(`lib/features/onboarding/presentation/pages/welcome_page.dart`). Every other
piece of configuration — units, sync, backups, appearance — is deferred to
scattered Settings pages that casual users may never discover. Two concrete
failures today:

1. **US divers silently get metric.** Unit settings are per-diver
   (`DiverSettings` table) and default to meters/celsius/bar. The welcome page
   never asks.
2. **Returning users on a new device have no path.** A user with an existing
   backup or cloud-synced library must create a throwaway diver profile just
   to reach Settings → Data → restore/sync. Restore-before-profile is not
   possible.

"New database" is broader than fresh install: it also occurs on storage-folder
switch to an empty folder and after resets. All of these funnel through the
same zero-divers router gate.

## Goals

- Replace the name-only welcome page with a multi-step setup wizard that runs
  whenever the database has zero divers.
- Offer an **existing-data path** (restore backup, connect cloud sync and
  adopt, open an existing storage folder) *before* any profile is created.
- Configure the essentials on the fresh path: profile name, units,
  appearance (theme, map style, language), backups, and optional cloud sync.
- End with a feature-discovery screen ("Submersion can also…").
- Make the wizard re-runnable from Settings so existing users get the same
  discoverability (with data-sensitive steps hidden).
- Every step after the profile name is skippable; a "skip setup" escape
  reproduces today's minimal flow exactly.

## Non-Goals

- Interactive coach-marks/overlay tour of the real UI.
- Exposing Google Drive (stays hidden, matching `CloudSyncPage`).
- Deco/GF or diving-defaults configuration in the wizard (novice-hostile;
  the 50/85 defaults stand).
- A trimmed wizard for creating *additional* divers.
- Prior-experience fields on the profile step (considered, rejected — stays
  in Settings → Diver Profile).
- Persisting draft wizard state across app restarts.

## User-Facing Flow

One page, two modes.

### First-run mode

Trigger: existing zero-divers redirect in `app_router.dart` sends the user to
`/welcome`, which now renders `SetupWizardPage(mode: firstRun)`.

```
Welcome (fork)
├─ "Set up a new logbook"          → FRESH PATH
│    1. Profile      name (required; sole mandatory input)
│    2. Units        Metric | Imperial preset + advanced per-unit fine-tune
│    3. Backup&Sync  scheduled-backup toggle (+ frequency); optional cloud
│                    provider connect; cloud-copy toggle once connected
│    4. Finish       feature highlights → "Start logging"
│         └─ applies draft: create diver → set current → write settings
│            → navigate to /dashboard
│
└─ "I have existing Submersion data" → EXISTING-DATA PATH (choose one)
     a. Restore a backup file  → pick file → confirm → restore → soft restart
     b. Connect cloud sync     → pick provider → connect → adopt library →
                                  pull progress → "Adopted N dives" → done
     c. Open existing folder   → pick storage folder → use existing database
                                  → swap + restart
```

Flow rules:

- **Fork first, profile later.** Each existing-data option ends with divers
  present, so the wizard exits without creating a profile. Restore and
  folder-adopt exit via the existing soft restart (`restartApp()` /
  `SubmersionRestart`); sync-adopt exits when the user acknowledges the
  completion screen.
- **Draft-and-apply.** Nothing is written until Finish (see Architecture).
  Abandoning the wizard mid-flow leaves the database untouched; next launch
  starts the wizard fresh.
- **Skippable steps.** Units, Appearance, and Backup & Sync each have a Skip
  affordance; skipping accepts the draft defaults. A "Skip setup" escape on
  the fork step asks only for the name, then applies all defaults —
  byte-for-byte today's outcome.
- **Locale-aware unit preset.** The Units step preselects Imperial when the
  device locale is US, Liberia, or Myanmar; Metric otherwise. The user
  confirms rather than configures. The advanced expander exposes the same
  seven unit preferences plus time/date format that Settings → Units has,
  driving the existing `UnitPreset {metric, imperial, custom}` semantics.
- **Cross-path pivots.** If a fresh-path user connects a provider that already
  holds a library, offer "Adopt the existing library instead?" (jumps to path
  b semantics, discarding the draft). If an existing-data user's provider has
  no library, offer "Start fresh instead?" and continue the fresh path with
  the provider already connected. No dead ends.
- **Finish screen.** Feature highlights with tap-to-go links: dive computer
  download, file import, statistics, dive sites map, gear service tracking.
  Links navigate after apply completes, so the app is fully initialized.

### Re-entry mode

Trigger: a "Setup assistant" tile in Settings pushes
`/settings/setup-assistant` → `SetupWizardPage(mode: settings)`.

- Hidden: fork, existing-data steps, Profile step (name editing lives in
  Diver Profile).
- Shown: Units, Appearance, Backup & Sync, Finish.
- The draft seeds from the **current diver's live settings** instead of
  defaults; apply updates that diver's `DiverSettings` row (no diver
  creation).
- If a sync provider is already connected, the Backup & Sync step shows
  connection status instead of connect prompts.

## Architecture

### Feature module

```
lib/features/setup_wizard/
├── presentation/
│   ├── pages/setup_wizard_page.dart          # shell: PageController + step list
│   ├── providers/setup_wizard_providers.dart # SetupWizardNotifier (draft state)
│   └── widgets/steps/
│       welcome_fork_step.dart, profile_step.dart, units_step.dart,
│       appearance_step.dart, backup_sync_step.dart, finish_step.dart,
│       restore_step.dart, sync_connect_step.dart, open_folder_step.dart
```

`lib/features/onboarding/` (the old `WelcomePage`) is deleted; docs that
reference it are updated.

### Shared wizard primitives (the one refactor)

`WizardStepDef` (`import_wizard/domain/models/wizard_step_def.dart`) and
`WizardStepIndicator` (`import_wizard/presentation/widgets/`) move to
`lib/shared/widgets/wizard/`. The import wizard updates imports only; its
shell (`UnifiedImportWizard`) is untouched. The setup wizard builds its own
small shell because it needs what the import shell does not model: branching
at the fork, mode-dependent step lists, and no hardcoded
Review → Import → Summary tail.

### State: draft-and-apply

`SetupWizardNotifier` holds a pure-Dart draft:

- `mode` (firstRun | settings), `path` (fresh | existingData | undecided)
- `name`
- draft `AppSettings` — seeded from `const AppSettings()` in first-run mode,
  from the live `settingsProvider` value in re-entry mode
- backup schedule choice (enabled + `BackupFrequency`)

Apply order on Finish (first-run):

1. `diverListNotifier.addDiver(...)` — create the diver (`isDefault: true`).
   `DiverRepository.createDiver` also seeds a defaults `DiverSettings` row.
2. Overwrite that row with the draft via
   `DiverSettingsRepository.updateSettingsForDiver(id, draft)` — BEFORE the
   diver becomes current. Switching the current diver fires an unawaited
   `SettingsNotifier` reload that would race (and clobber) any post-switch
   settings writes; writing first means the reload simply loads the drafted
   row. No new `SettingsNotifier` API is needed, so no settings mocks change.
3. `setCurrentDiver(id)` — existing dual-write to SharedPreferences + the
   `Settings` table; the notifier reload now picks up the drafted settings.
4. Apply backup choices via `backupSettingsProvider`: schedule (`setEnabled`,
   `setFrequency`) and, when a cloud provider was connected in the wizard and
   the user opted in, `cloudBackupEnabled`. These are device-level
   SharedPreferences-backed values (`BackupPreferences`), not per-diver rows.

**Live actions vs. draft settings.** External handshakes cannot be drafted:
sync provider connect (OAuth, iCloud availability, S3 validation), restore,
adopt, and folder swap act immediately when the user confirms them, exactly
as their Settings counterparts do. Everything else (name, units, appearance,
backup schedule) stays in the draft until Finish.

### Existing-data path: purpose-built UI over existing engines

| Wizard step | Reused engine | Exit |
|---|---|---|
| Restore backup | backup/restore services behind `BackupSettingsPage` (`backupOperationProvider`, restore confirmation semantics) | soft restart → divers exist → gate passes |
| Connect sync | provider connect logic from `CloudSyncPage` (iCloud availability, Dropbox OAuth, S3 config validation); adopt + pull via existing sync machinery | pull completes → user acknowledges → wizard navigates |
| Open existing folder | `DatabaseLocationService` + the `ExistingDatabaseChoice.useExisting` path from `ExistingDatabaseDialog` | database swap + restart |

The wizard re-skins presentation (wizard-native cards/forms) but calls the
same services, so config logic keeps one source of truth.

### Routing

- `/welcome` keeps its route name and its zero-divers redirect, now building
  `SetupWizardPage(mode: firstRun)`.
- New route `/settings/setup-assistant` builds
  `SetupWizardPage(mode: settings)`; a Settings tile launches it.
- **No redirect race exists.** The router has no `refreshListenable`; the
  redirect only evaluates on navigation events and reads
  `hasAnyDiversProvider.future` fresh each time (`app_router.dart`).
  Divers appearing mid-wizard (sync adopt) therefore cannot yank the user
  off the wizard; the wizard exits by navigating itself, at which point the
  gate re-evaluates and passes. `allDiversProvider` self-invalidates from
  `watchDiversChanges()`, so the value is fresh by then.

### Locale preview

Draft-and-apply would leave the wizard rendering in the old language after
the user picks a new one. A small `previewLocaleProvider` (in the setup
wizard's providers) is consulted by the app's existing `_resolveLocale`
(`app.dart`): when set, it overrides the settings locale for rendering.
Cleared/persisted at Finish. First-run mode has no diver row, so this is the
only way a language choice can take effect mid-wizard.

### Layout

Full-screen steps on mobile; centered constrained-width card over
`OceanBackground` on desktop (macOS/Windows/Linux) — the same visual family
as the splash and the old welcome page. `WizardStepIndicator` heads the fresh
path; the fork and existing-data screens are indicator-free (they are choices,
not progress). All layouts must be direction-agnostic for RTL locales
(ar, he).

## Edge Cases and Error Handling

Principle: no step dead-ends, no partial state.

- **Restore fails** → inline error with retry / back-to-fork. The database is
  untouched on failure (existing restore-service guarantees). Same for
  folder-adopt.
- **Provider connect fails** → inline error on the provider card, retry or
  pick another provider; never blocks Back.
- **Sync connects, no library found** (existing-data path) → offer "Start
  fresh instead?" → continues into the fresh path with the provider already
  connected.
- **Sync connects, library found** (fresh path) → offer "Adopt the existing
  library instead?" → switches to the adopt flow; draft is discarded.
- **App killed mid-wizard** → draft was in-memory; next launch lands back at
  the wizard start. Acceptable for a two-minute flow.
- **Platform gating** → provider cards reuse existing gates: iCloud only on
  Apple platforms and hidden in Developer ID builds; Google Drive hidden
  everywhere; S3/Dropbox on all platforms.
- **Migration interplay** → none: `StartupWrapper` completes migrations before
  the router renders anything, and the redirect skips while
  `DatabaseService.instance.isMigrating`.
- **Re-entry with sync configured** → Backup & Sync step becomes a status
  view (connected provider, last backup) with a link to Settings → Data.

## Testing

Per the repo's 80% coverage bar:

- **Unit — `SetupWizardNotifier`:** step-list computation per mode and path
  (first-run shows fork; settings mode hides fork/profile; existing-data path
  replaces fresh steps), draft mutations, apply ordering
  (create → select → settings → backup), locale→preset detection
  (`en_US` → Imperial, `de_DE` → Metric).
- **Widget — steps in isolation:** profile name validation (empty name blocks
  advance), units preset toggle drives the advanced fields, appearance
  choices update the draft, skip affordances advance without mutating the
  draft, fork branching renders the right next step.
- **Widget — shell:** next/back navigation across the branch, "Skip setup"
  fast-path, re-entry mode step visibility.
- **Integration-style (in-memory Drift):** Finish produces exactly one diver
  (`isDefault: true`, current) and a `DiverSettings` row matching the draft —
  e.g. Imperial preset writes all seven unit columns; backup schedule lands in
  backup settings.
- **Regression:** import wizard tests pass untouched after the
  `WizardStepDef`/`WizardStepIndicator` move; router tests confirm the
  zero-divers redirect still lands on the wizard and that completing the
  wizard reaches `/dashboard`.
- Known widget-test traps apply (theme animation duration zero; wrap
  post-pump Drift awaits in `tester.runAsync`; `FormSection` uppercases
  labels).

## Localization

- All new strings in `lib/l10n/arb/app_en.arb` plus the 10 other locales,
  regenerated. Estimate 60–80 keys under a `setup_` prefix.
- The ~10 `onboarding_welcome_*` keys are removed with the old welcome page.
- RTL: no special-casing beyond Material defaults, but step indicator and
  fork cards must not hardcode left/right.

## Documentation

- `docs/developer/navigation.md` — first-run guard section and route table.
- `docs/guide/first-dive.md` + user-guide wiki source — new first-run flow.
- `docs/ARCHITECTURE.md` / `docs/developer/architecture.md` — feature list
  (onboarding → setup_wizard).
- `FEATURE_ROADMAP.md` — entry for the setup wizard.

## Resolved Questions (verified in code)

- **Map style is a real setting:** `MapStyle {openStreetMap, openTopoMap,
  esriSatellite}` on `AppSettings.mapStyle` with an existing notifier setter —
  included in the Appearance step.
- **Auto-backup exists:** `backupSettingsProvider` with `setEnabled` /
  `setFrequency(BackupFrequency)` and a `cloudBackupEnabled` flag — the
  Backup & Sync step drives it. `cloudBackupEnabled` (SharedPreferences,
  default false) only takes effect when a cloud provider is configured
  (`cloudStorageProviderProvider`), so the wizard surfaces the toggle only
  after a provider connects — mirroring `BackupSettingsPage`.
- **No router refresh race:** redirect is navigation-driven only; wizard
  controls its own exit (see Routing).

# Setup Wizard for New Databases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the name-only welcome page with a multi-step setup wizard (units, appearance, backup/sync, existing-data restore/adopt paths) per the approved spec `docs/superpowers/specs/2026-07-10-setup-wizard-design.md` (discussion #523).

**Architecture:** New `lib/features/setup_wizard/` feature with a draft-and-apply `StateNotifier` and a small `PageView` shell; `WizardStepDef`/`WizardStepIndicator` move to `lib/shared/widgets/wizard/` and are shared with the import wizard. Existing-data paths re-skin presentation over the existing restore, sync, and storage engines. First-run settings are seeded via `DiverSettingsRepository.createSettingsForDiver(id, settings: draft)` BEFORE `setCurrentDiver` (avoids the SettingsNotifier reload race — this supersedes the spec's `applySettings()` bulk-method idea; amend the spec in Task 5).

**Tech Stack:** Flutter 3 / Material 3, Riverpod (StateNotifier), go_router, Drift (via existing repositories), file_picker, flutter gen-l10n (11 locales).

## Global Constraints

- All user-facing strings via `context.l10n.*`; new keys added to `lib/l10n/arb/app_en.arb` AND translated in all 10 other arb files (ar, de, es, fr, he, hu, it, nl, pt, zh); regenerate with `flutter gen-l10n` (generated `app_localizations*.dart` files are checked in — commit them).
- No emojis in code/comments/docs. Immutability (copyWith, no mutation). `dart format .` must produce no changes before each commit.
- Tests: run SPECIFIC test files (never the whole suite — it times out). Widget tests wrap post-pump Drift awaits in `tester.runAsync`; `FormSection` uppercases labels; never dispose controllers in `whenComplete()`.
- Commit after each task with `git add <files>` (never `git add -A`; the worktree may contain untracked build dirs). Do not push (pre-push hook runs against the MAIN tree; push is out of scope).
- Import order: dart, flutter, packages, local. Files 200-400 lines typical, 800 max.
- Riverpod 3: no provider mutation in `dispose()`; use `Future.microtask` + `mounted` guards where a callback mutates providers.
- Existing engines are called, never modified, except: `app.dart` gains a preview-locale hook (Task 9) and the router swaps the `/welcome` builder (Task 13).

**Key facts (verified in code — trust these over guesses):**
- `DiverListNotifier.addDiver(Diver)` returns `Future<Diver>` with the real id (`diver_providers.dart:251`).
- `CurrentDiverIdNotifier.setCurrentDiver(String)` triggers an UNAWAITED `SettingsNotifier` reload that resets `_validatedDiverId` and later overwrites state with fresh defaults — settings setters called immediately after `setCurrentDiver` are silently dropped. Sequence: create diver → seed settings row → THEN setCurrentDiver.
- `DiverSettingsRepository.createSettingsForDiver(String diverId, {AppSettings? settings})` seeds a full row in one insert (`diver_settings_repository.dart:45`); `getSettingsForDiver(diverId)` returns `AppSettings?`; `updateSettingsForDiver(diverId, settings)` updates. Provider: `diverSettingsRepositoryProvider` (settings_providers.dart).
- `SettingsNotifier` existing setters: `setMetric()`, `setImperial()` (6 units, NOT sacUnit), `setDepthUnit/setTemperatureUnit/setPressureUnit/setVolumeUnit/setWeightUnit/setAltitudeUnit/setSacUnit`, `setTimeFormat`, `setDateFormat`, `setThemeMode(ThemeMode)`, `setThemePresetId(String)`, `setMapStyle(MapStyle)`, `setLocale(String)`. Do NOT add methods to SettingsNotifier (3 hand-written full-implementer mocks would break).
- `AppSettings` fields used: 7 units + `timeFormat` + `dateFormat` + `themeMode` (Flutter `ThemeMode`) + `themePresetId` (String: submersion|console|tropical|minimalist|deep) + `locale` (String, 'system' or code) + `mapStyle` (`MapStyle{openStreetMap,openTopoMap,esriSatellite}` in `lib/core/constants/map_style.dart`). `UnitPreset{metric,imperial,custom}` lives in settings_providers.dart; `AppSettings.unitPreset` getter checks the 6 core units.
- Backup: `backupSettingsProvider` → `BackupSettingsNotifier.setEnabled(bool)/setFrequency(BackupFrequency{daily,weekly,monthly})/setCloudBackupEnabled(bool)`; state `BackupSettings{enabled=false, frequency=weekly, cloudBackupEnabled=false}` (SharedPreferences-backed).
- Restore: `FilePicker.pickFiles(type: FileType.any)` → temp `BackupRecord` → `RestoreConfirmationDialog.show(context, record, currentSchemaVersion: AppDatabase.currentSchemaVersion, offerReplace: ...)` → `RestoreMode?` → `ref.read(backupOperationProvider.notifier).restoreFromFilePath(path, mode: mode)`; listen for `BackupOperationStatus.restoreComplete` → `RestoreCompletePage.show(context)` (its Continue button calls `restartApp()`).
- Folder adopt: `ref.read(storageConfigNotifierProvider.notifier)`: `pickCustomFolder({chooser})` → `FolderPickResultWithBookmark?`; `checkForExistingDatabase(path)` → `ExistingDatabaseInfo?`; `switchToExistingDatabase(path)` → `MigrationResult` (`.success`). Wizard calls `restartApp()` after success (per spec).
- Sync activation contract (mirror `CloudSyncPage._selectProvider`): set `selectedCloudProviderTypeProvider.notifier.state = type` → `await cloudProviderInstanceFor(type).authenticate()` (`Future<void>`, throws on failure) → `await ref.read(syncInitializerProvider).saveProvider(type)` → `ref.read(syncStateProvider.notifier).refreshState()`. On failure reset selection to null.
- iCloud gate: `isApplePlatformProvider` AND `iCloudAvailabilityProvider != ICloudAvailability.unsupported`. Dropbox gate: `dropboxConfiguredProvider`; connect via `showDialog<bool>(builder: (_) => DropboxConnectDialog(provider: ref.read(dropboxStorageProviderInstanceProvider)))`. S3: push existing route `/settings/cloud-sync/s3-config` (S3ConfigPage activates S3 itself on save). Google Drive stays hidden.
- Remote-library detection: `await ref.read(syncInitializerProvider).peerSyncFiles(providerInstance)` → `List<CloudFileInfo>`; non-empty = existing library.
- Pull: `ref.read(syncStateProvider.notifier).performSync()`; on a zero-dive DB it auto-adopts replaced libraries and plain-pulls otherwise. Watch `syncStateProvider` (`SyncState{status: SyncStatus{idle,syncing,success,error,hasConflicts}, progress, message}`). After success call `realignActiveDiverAfterDataReplace(ref.read(sharedPreferencesProvider))` (from diver_providers.dart) before leaving the wizard.
- Router: `/welcome` is a top-level GoRoute OUTSIDE the ShellRoute (`app_router.dart:169`); redirect gate reads `hasAnyDiversProvider.future` on navigation events only (no refreshListenable — no mid-wizard yank). Settings children are relative-path GoRoutes under `/settings` with plain `builder:`.
- Test helpers: `testApp({child, overrides})` / `testAppRouter({router, overrides})` in `test/helpers/test_app.dart`; `setUpTestDatabase()`/`tearDownTestDatabase()` in `test/helpers/test_database.dart`; `SharedPreferences.setMockInitialValues({})` then `sharedPreferencesProvider.overrideWithValue(prefs)`; `getBaseOverrides()` in `test/helpers/mock_providers.dart`.

---

### Task 1: Move wizard primitives to lib/shared/widgets/wizard/

**Files:**
- Move: `lib/features/import_wizard/domain/models/wizard_step_def.dart` → `lib/shared/widgets/wizard/wizard_step_def.dart`
- Move: `lib/features/import_wizard/presentation/widgets/wizard_step_indicator.dart` → `lib/shared/widgets/wizard/wizard_step_indicator.dart`
- Modify (import line only): `lib/features/import_wizard/data/adapters/healthkit_adapter.dart:19`, `lib/features/import_wizard/data/adapters/universal_adapter.dart:36`, `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart:28`, `lib/features/import_wizard/domain/services/step_skip_calculator.dart:1`, `lib/features/import_wizard/domain/adapters/import_source_adapter.dart:6`, `lib/features/import_wizard/presentation/pages/unified_import_wizard.dart:20,28`
- Modify (test imports): `test/features/import_wizard/domain/services/step_skip_calculator_test.dart:5`, `test/features/import_wizard/domain/models/wizard_step_def_test.dart:4`, `test/features/import_wizard/domain/adapters/import_source_adapter_test.dart:8`, `test/features/import_wizard/presentation/pages/unified_import_wizard_test.dart:15`, `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.mocks.dart:22`, `test/features/import_wizard/presentation/widgets/review_step_test.dart:14`, `test/features/import_wizard/presentation/widgets/review_step_pending_test.dart:12`, `test/features/import_wizard/presentation/widgets/import_summary_step_test.dart:14`, `test/features/import_wizard/presentation/widgets/import_progress_step_test.dart:11`, `test/features/import_wizard/presentation/widgets/wizard_step_indicator_test.dart:3`

**Interfaces:**
- Produces: `package:submersion/shared/widgets/wizard/wizard_step_def.dart` exporting `WizardStepDef` (unchanged API) and `package:submersion/shared/widgets/wizard/wizard_step_indicator.dart` exporting `WizardStepIndicator({required List<String> labels, required int currentStep})`. Later tasks import from these paths.

- [ ] **Step 1: Move files with git mv**

```bash
mkdir -p lib/shared/widgets/wizard
git mv lib/features/import_wizard/domain/models/wizard_step_def.dart lib/shared/widgets/wizard/wizard_step_def.dart
git mv lib/features/import_wizard/presentation/widgets/wizard_step_indicator.dart lib/shared/widgets/wizard/wizard_step_indicator.dart
```

- [ ] **Step 2: Update every import site**

In each of the 16 files listed above, replace the old import string with the new one (both old strings map to the matching new path):

```dart
// OLD
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';
// NEW
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

// OLD
import 'package:submersion/features/import_wizard/presentation/widgets/wizard_step_indicator.dart';
// NEW
import 'package:submersion/shared/widgets/wizard/wizard_step_indicator.dart';
```

Note `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.mocks.dart` is a GENERATED file but is checked in — edit its import line the same way (build_runner would regenerate identically from the new path).

- [ ] **Step 3: Verify no stale imports remain**

Run: `rg -n "import_wizard/domain/models/wizard_step_def|import_wizard/presentation/widgets/wizard_step_indicator" lib test`
Expected: no matches.

- [ ] **Step 4: Run the import wizard test suite**

Run: `flutter test test/features/import_wizard/`
Expected: all tests PASS (move is behavior-neutral).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/shared/widgets/wizard lib/features/import_wizard test/features/import_wizard
git commit -m "refactor: move wizard step primitives to lib/shared/widgets/wizard"
```

---

### Task 2: Localization strings for the setup wizard

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (add ~65 `setup_*` + 2 `settings_manage_setupAssistant*` keys, alphabetically placed)
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb` (same keys, translated)
- Regenerate: `lib/l10n/arb/app_localizations*.dart` via `flutter gen-l10n`

**Interfaces:**
- Produces: `context.l10n.setup_*` getters used by Tasks 6-13. Key names below are load-bearing — later tasks reference them verbatim.

- [ ] **Step 1: Add the English keys to `app_en.arb`**

Insert each key in correct alphabetical position (the file is sorted; `setup_*` sorts after `settings_*`). Placeholder keys need `@`-metadata blocks as shown:

```json
"settings_manage_setupAssistant": "Setup assistant",
"settings_manage_setupAssistant_subtitle": "Revisit units, appearance, and backup choices",
"setup_appearance_language": "Language",
"setup_appearance_mapStyle": "Map style",
"setup_appearance_mapStyle_esriSatellite": "Satellite",
"setup_appearance_mapStyle_openStreetMap": "Street",
"setup_appearance_mapStyle_openTopoMap": "Topographic",
"setup_appearance_subtitle": "Make Submersion yours. Everything here can be changed later.",
"setup_appearance_theme": "Theme",
"setup_appearance_themeDark": "Dark",
"setup_appearance_themeLight": "Light",
"setup_appearance_themePreset": "Color theme",
"setup_appearance_themeSystem": "System",
"setup_appearance_title": "Appearance",
"setup_backup_cloudCopy": "Keep a backup copy in the cloud",
"setup_backup_frequency": "Frequency",
"setup_backup_frequency_daily": "Daily",
"setup_backup_frequency_monthly": "Monthly",
"setup_backup_frequency_weekly": "Weekly",
"setup_backup_scheduleSubtitle": "Back up your logbook on a schedule",
"setup_backup_scheduleToggle": "Automatic backups",
"setup_backup_subtitle": "Protect your dive log from day one.",
"setup_backup_title": "Backups & Sync",
"setup_common_back": "Back",
"setup_common_next": "Next",
"setup_common_skip": "Skip",
"setup_existing_folder_subtitle": "Point Submersion at a folder that already contains a library",
"setup_existing_folder_title": "Open an existing folder",
"setup_existing_restore_subtitle": "Pick a backup file exported from Submersion",
"setup_existing_restore_title": "Restore a backup file",
"setup_existing_subtitle": "Choose how to load your existing Submersion library",
"setup_existing_sync_subtitle": "Pull your library from iCloud, Dropbox, or S3",
"setup_existing_sync_title": "Connect cloud sync",
"setup_existing_title": "Bring your data",
"setup_finish_applying": "Setting up...",
"setup_finish_error": "Could not complete setup: {error}",
"@setup_finish_error": { "placeholders": { "error": { "type": "Object" } } },
"setup_finish_feature_diveComputer": "Download dives from your dive computer",
"setup_finish_feature_gear": "Track gear and service intervals",
"setup_finish_feature_import": "Import logs from files and other apps",
"setup_finish_feature_sites": "Map your dive sites",
"setup_finish_feature_statistics": "Explore statistics about your diving",
"setup_finish_start": "Start logging",
"setup_finish_subtitle": "Submersion can also...",
"setup_finish_title": "You're all set",
"setup_folder_notFound_message": "The selected folder does not contain a Submersion database.",
"setup_folder_notFound_title": "No library in that folder",
"setup_folder_pick": "Choose folder",
"setup_folder_switching": "Opening library...",
"setup_folder_title": "Open existing folder",
"setup_profile_nameHint": "Enter your name",
"setup_profile_nameLabel": "Your Name",
"setup_profile_nameValidation": "Please enter your name",
"setup_profile_subtitle": "Enter your name to get started. You can add more details later in Settings.",
"setup_profile_title": "Create Your Profile",
"setup_restore_inProgress": "Restoring...",
"setup_restore_pick": "Choose backup file",
"setup_restore_title": "Restore backup",
"setup_step_appearance": "Appearance",
"setup_step_backup": "Backup",
"setup_step_finish": "Done",
"setup_step_profile": "Profile",
"setup_step_units": "Units",
"setup_sync_connectedTo": "Connected to {provider}",
"@setup_sync_connectedTo": { "placeholders": { "provider": { "type": "String" } } },
"setup_sync_error": "Could not connect: {error}",
"@setup_sync_error": { "placeholders": { "error": { "type": "Object" } } },
"setup_sync_header": "Cloud sync",
"setup_sync_icloudUnavailable": "iCloud is not available on this device",
"setup_sync_libraryFound_adopt": "Adopt existing library",
"setup_sync_libraryFound_keepFresh": "Start fresh",
"setup_sync_libraryFound_message": "This account already contains a Submersion library. Adopt it instead of starting fresh?",
"setup_sync_libraryFound_title": "Existing library found",
"setup_sync_manageInSettings": "Manage in Settings",
"setup_sync_notConnected": "Not connected",
"setup_sync_subtitle": "Sync your logbook across devices",
"setup_syncPull_continue": "Continue",
"setup_syncPull_noLibrary_message": "No existing Submersion library was found on this account. Start fresh instead? Your connection will be kept.",
"setup_syncPull_noLibrary_title": "No library found",
"setup_syncPull_success": "Library adopted",
"setup_syncPull_syncing": "Pulling your library...",
"setup_syncPull_title": "Connect and pull",
"setup_units_advanced": "Fine-tune units",
"setup_units_altitude": "Altitude",
"setup_units_dateFormat": "Date format",
"setup_units_depth": "Depth",
"setup_units_imperial": "Imperial",
"setup_units_metric": "Metric",
"setup_units_pressure": "Pressure",
"setup_units_sac": "SAC rate",
"setup_units_subtitle": "Choose how measurements are displayed. You can fine-tune each unit.",
"setup_units_temperature": "Temperature",
"setup_units_timeFormat": "Time format",
"setup_units_title": "Units",
"setup_units_volume": "Volume",
"setup_units_weight": "Weight",
"setup_welcome_existingData_subtitle": "Restore a backup, connect cloud sync, or open an existing folder",
"setup_welcome_existingData_title": "I have existing Submersion data",
"setup_welcome_skipSetup": "Skip setup",
"setup_welcome_startFresh_subtitle": "Create your diver profile and configure the app",
"setup_welcome_startFresh_title": "Set up a new logbook",
"setup_welcome_subtitle": "Advanced dive logging and analytics",
"setup_welcome_title": "Welcome to Submersion"
```

- [ ] **Step 2: Translate the same keys into the 10 other arb files**

For each of `app_ar.arb, app_de.arb, app_es.arb, app_fr.arb, app_he.arb, app_hu.arb, app_it.arb, app_nl.arb, app_pt.arb, app_zh.arb`: add every key above (same alphabetical placement, same `@`-metadata blocks copied verbatim) with a fluent translation of the English value, matching the tone of each file's existing `onboarding_welcome_*` / `settings_*` translations. Keep the placeholders `{error}` / `{provider}` untranslated. Product name "Submersion", provider names (iCloud, Dropbox, S3), and "SAC" stay untranslated.

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: exits 0; `lib/l10n/arb/app_localizations*.dart` files regenerate with the new getters and no "untranslated message" warnings for the new keys.

- [ ] **Step 4: Verify compilation**

Run: `flutter analyze lib/l10n`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n
git commit -m "feat(l10n): add setup wizard strings in all locales"
```

---

### Task 3: Domain model — draft, step list, unit-preset detection

**Files:**
- Create: `lib/features/setup_wizard/domain/setup_wizard_models.dart`
- Create: `lib/features/setup_wizard/domain/unit_preset_detector.dart`
- Test: `test/features/setup_wizard/domain/setup_wizard_models_test.dart`
- Test: `test/features/setup_wizard/domain/unit_preset_detector_test.dart`

**Interfaces:**
- Consumes: `AppSettings`, `UnitPreset` from `package:submersion/features/settings/presentation/providers/settings_providers.dart`; `BackupFrequency` from `package:submersion/features/backup/domain/entities/backup_settings.dart`; `CloudProviderType` from `package:submersion/core/data/repositories/sync_repository.dart`.
- Produces (used by Tasks 4-13): `SetupWizardMode{firstRun, settings}`, `SetupPath{undecided, fresh, existingData}`, `ExistingDataSource{none, restoreBackup, cloudSync, openFolder}`, `SetupStepId{welcomeFork, profile, units, appearance, backupSync, finish, existingChoice, restore, syncConnect, openFolder}`, `class SetupWizardDraft` (fields below, `copyWith`), `List<SetupStepId> computeSteps(SetupWizardDraft draft)`, `UnitPreset presetForLocale(Locale locale)`.

- [ ] **Step 1: Write the failing tests**

`test/features/setup_wizard/domain/setup_wizard_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';

void main() {
  group('computeSteps', () {
    test('first run starts with fork only while path undecided', () {
      const draft = SetupWizardDraft(mode: SetupWizardMode.firstRun);
      expect(computeSteps(draft), [SetupStepId.welcomeFork]);
    });

    test('fresh path shows full first-run flow', () {
      const draft = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.fresh,
      );
      expect(computeSteps(draft), [
        SetupStepId.welcomeFork,
        SetupStepId.profile,
        SetupStepId.units,
        SetupStepId.appearance,
        SetupStepId.backupSync,
        SetupStepId.finish,
      ]);
    });

    test('skip setup collapses fresh path to profile then finish', () {
      const draft = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.fresh,
        skipRequested: true,
      );
      expect(computeSteps(draft), [
        SetupStepId.welcomeFork,
        SetupStepId.profile,
        SetupStepId.finish,
      ]);
    });

    test('existing-data path shows choice, then source step', () {
      const undecided = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.existingData,
      );
      expect(computeSteps(undecided), [
        SetupStepId.welcomeFork,
        SetupStepId.existingChoice,
      ]);

      const restore = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.existingData,
        source: ExistingDataSource.restoreBackup,
      );
      expect(computeSteps(restore), [
        SetupStepId.welcomeFork,
        SetupStepId.existingChoice,
        SetupStepId.restore,
      ]);

      const sync = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.existingData,
        source: ExistingDataSource.cloudSync,
      );
      expect(computeSteps(sync).last, SetupStepId.syncConnect);

      const folder = SetupWizardDraft(
        mode: SetupWizardMode.firstRun,
        path: SetupPath.existingData,
        source: ExistingDataSource.openFolder,
      );
      expect(computeSteps(folder).last, SetupStepId.openFolder);
    });

    test('settings mode hides fork and profile', () {
      const draft = SetupWizardDraft(mode: SetupWizardMode.settings);
      expect(computeSteps(draft), [
        SetupStepId.units,
        SetupStepId.appearance,
        SetupStepId.backupSync,
        SetupStepId.finish,
      ]);
    });
  });

  group('SetupWizardDraft', () {
    test('applyUnitPreset imperial sets the six core units', () {
      const draft = SetupWizardDraft(mode: SetupWizardMode.firstRun);
      final imperial = draft.applyingUnitPreset(UnitPreset.imperial);
      expect(imperial.settings.depthUnit, DepthUnit.feet);
      expect(imperial.settings.temperatureUnit, TemperatureUnit.fahrenheit);
      expect(imperial.settings.pressureUnit, PressureUnit.psi);
      expect(imperial.settings.volumeUnit, VolumeUnit.cubicFeet);
      expect(imperial.settings.weightUnit, WeightUnit.pounds);
      expect(imperial.settings.altitudeUnit, AltitudeUnit.feet);
      // sacUnit untouched by preset
      expect(imperial.settings.sacUnit, const AppSettings().sacUnit);
      // and back to metric
      final metric = imperial.applyingUnitPreset(UnitPreset.metric);
      expect(metric.settings.unitPreset, UnitPreset.metric);
    });
  });
}
```

Add these imports at the top of the test (needed by the assertions): `import 'package:submersion/core/constants/units.dart';` and `import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';`

`test/features/setup_wizard/domain/unit_preset_detector_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/domain/unit_preset_detector.dart';

void main() {
  test('US, Liberia, Myanmar map to imperial', () {
    expect(presetForLocale(const Locale('en', 'US')), UnitPreset.imperial);
    expect(presetForLocale(const Locale('en', 'LR')), UnitPreset.imperial);
    expect(presetForLocale(const Locale('my', 'MM')), UnitPreset.imperial);
  });

  test('everything else maps to metric', () {
    expect(presetForLocale(const Locale('de', 'DE')), UnitPreset.metric);
    expect(presetForLocale(const Locale('en', 'GB')), UnitPreset.metric);
    expect(presetForLocale(const Locale('en')), UnitPreset.metric);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/setup_wizard/`
Expected: FAIL — files under `lib/features/setup_wizard/domain/` do not exist.

- [ ] **Step 3: Implement the domain files**

`lib/features/setup_wizard/domain/setup_wizard_models.dart`:

```dart
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Whether the wizard runs at first launch or from Settings.
enum SetupWizardMode { firstRun, settings }

/// Which top-level branch the user chose on the fork step.
enum SetupPath { undecided, fresh, existingData }

/// Which existing-data source the user chose.
enum ExistingDataSource { none, restoreBackup, cloudSync, openFolder }

/// Identity of every wizard step; the shell maps these to widgets.
enum SetupStepId {
  welcomeFork,
  profile,
  units,
  appearance,
  backupSync,
  finish,
  existingChoice,
  restore,
  syncConnect,
  openFolder,
}

/// Immutable wizard draft. Nothing is persisted until Finish applies it.
class SetupWizardDraft {
  final SetupWizardMode mode;
  final SetupPath path;
  final ExistingDataSource source;
  final bool skipRequested;
  final String name;
  final AppSettings settings;
  final bool backupEnabled;
  final BackupFrequency backupFrequency;
  final bool cloudBackupEnabled;
  final CloudProviderType? connectedProvider;

  const SetupWizardDraft({
    required this.mode,
    this.path = SetupPath.undecided,
    this.source = ExistingDataSource.none,
    this.skipRequested = false,
    this.name = '',
    this.settings = const AppSettings(),
    this.backupEnabled = false,
    this.backupFrequency = BackupFrequency.weekly,
    this.cloudBackupEnabled = false,
    this.connectedProvider,
  });

  SetupWizardDraft copyWith({
    SetupPath? path,
    ExistingDataSource? source,
    bool? skipRequested,
    String? name,
    AppSettings? settings,
    bool? backupEnabled,
    BackupFrequency? backupFrequency,
    bool? cloudBackupEnabled,
    CloudProviderType? connectedProvider,
  }) {
    return SetupWizardDraft(
      mode: mode,
      path: path ?? this.path,
      source: source ?? this.source,
      skipRequested: skipRequested ?? this.skipRequested,
      name: name ?? this.name,
      settings: settings ?? this.settings,
      backupEnabled: backupEnabled ?? this.backupEnabled,
      backupFrequency: backupFrequency ?? this.backupFrequency,
      cloudBackupEnabled: cloudBackupEnabled ?? this.cloudBackupEnabled,
      connectedProvider: connectedProvider ?? this.connectedProvider,
    );
  }

  /// Returns a copy with the six core units set to [preset].
  /// [UnitPreset.custom] returns this draft unchanged.
  SetupWizardDraft applyingUnitPreset(UnitPreset preset) {
    switch (preset) {
      case UnitPreset.metric:
        return copyWith(
          settings: settings.copyWith(
            depthUnit: DepthUnit.meters,
            temperatureUnit: TemperatureUnit.celsius,
            pressureUnit: PressureUnit.bar,
            volumeUnit: VolumeUnit.liters,
            weightUnit: WeightUnit.kilograms,
            altitudeUnit: AltitudeUnit.meters,
          ),
        );
      case UnitPreset.imperial:
        return copyWith(
          settings: settings.copyWith(
            depthUnit: DepthUnit.feet,
            temperatureUnit: TemperatureUnit.fahrenheit,
            pressureUnit: PressureUnit.psi,
            volumeUnit: VolumeUnit.cubicFeet,
            weightUnit: WeightUnit.pounds,
            altitudeUnit: AltitudeUnit.feet,
          ),
        );
      case UnitPreset.custom:
        return this;
    }
  }
}

/// Computes the ordered step list for the current draft state.
List<SetupStepId> computeSteps(SetupWizardDraft draft) {
  if (draft.mode == SetupWizardMode.settings) {
    return const [
      SetupStepId.units,
      SetupStepId.appearance,
      SetupStepId.backupSync,
      SetupStepId.finish,
    ];
  }
  switch (draft.path) {
    case SetupPath.undecided:
      return const [SetupStepId.welcomeFork];
    case SetupPath.fresh:
      if (draft.skipRequested) {
        return const [
          SetupStepId.welcomeFork,
          SetupStepId.profile,
          SetupStepId.finish,
        ];
      }
      return const [
        SetupStepId.welcomeFork,
        SetupStepId.profile,
        SetupStepId.units,
        SetupStepId.appearance,
        SetupStepId.backupSync,
        SetupStepId.finish,
      ];
    case SetupPath.existingData:
      final steps = [SetupStepId.welcomeFork, SetupStepId.existingChoice];
      switch (draft.source) {
        case ExistingDataSource.none:
          break;
        case ExistingDataSource.restoreBackup:
          steps.add(SetupStepId.restore);
        case ExistingDataSource.cloudSync:
          steps.add(SetupStepId.syncConnect);
        case ExistingDataSource.openFolder:
          steps.add(SetupStepId.openFolder);
      }
      return steps;
  }
}
```

`lib/features/setup_wizard/domain/unit_preset_detector.dart`:

```dart
import 'dart:ui';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Countries using imperial-style units for everyday measurement.
const _imperialCountries = {'US', 'LR', 'MM'};

/// Maps a device locale to the unit preset the wizard preselects.
UnitPreset presetForLocale(Locale locale) {
  final country = locale.countryCode?.toUpperCase();
  if (country != null && _imperialCountries.contains(country)) {
    return UnitPreset.imperial;
  }
  return UnitPreset.metric;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/setup_wizard/`
Expected: all PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/setup_wizard test/features/setup_wizard
git commit -m "feat(setup): setup wizard domain model and step computation"
```

---

### Task 4: SetupWizardNotifier and providers

**Files:**
- Create: `lib/features/setup_wizard/presentation/providers/setup_wizard_providers.dart`
- Test: `test/features/setup_wizard/presentation/providers/setup_wizard_providers_test.dart`

**Interfaces:**
- Consumes: Task 3 domain types.
- Produces (used by Tasks 5-13):
  - `final setupWizardProvider = StateNotifierProvider.autoDispose.family<SetupWizardNotifier, SetupWizardDraft, SetupWizardMode>(...)`
  - `SetupWizardNotifier` mutators: `void choosePath(SetupPath path)`, `void chooseSource(ExistingDataSource source)`, `void requestSkip()`, `void setName(String name)`, `void applyUnitPreset(UnitPreset preset)`, `void updateSettings(AppSettings settings)`, `void setBackupEnabled(bool value)`, `void setBackupFrequency(BackupFrequency value)`, `void setCloudBackupEnabled(bool value)`, `void setConnectedProvider(CloudProviderType? type)`
  - `final previewLocaleProvider = StateProvider<String?>((ref) => null);`

- [ ] **Step 1: Write the failing test**

`test/features/setup_wizard/presentation/providers/setup_wizard_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';

void main() {
  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('starts undecided in first-run mode, seeded from defaults', () {
    final container = makeContainer();
    final draft = container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.path, SetupPath.undecided);
    expect(draft.settings, const AppSettings());
  });

  test('mutators update the draft', () {
    final container = makeContainer();
    final notifier = container.read(
      setupWizardProvider(SetupWizardMode.firstRun).notifier,
    );
    notifier.choosePath(SetupPath.fresh);
    notifier.setName('  Eric  ');
    notifier.applyUnitPreset(UnitPreset.imperial);
    notifier.setBackupEnabled(true);

    final draft = container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.path, SetupPath.fresh);
    expect(draft.name, 'Eric');
    expect(draft.settings.unitPreset, UnitPreset.imperial);
    expect(draft.backupEnabled, isTrue);
    expect(
      computeSteps(draft),
      contains(SetupStepId.backupSync),
    );
  });

  test('requestSkip trims the fresh path', () {
    final container = makeContainer();
    final notifier = container.read(
      setupWizardProvider(SetupWizardMode.firstRun).notifier,
    );
    notifier.requestSkip();
    final draft = container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.path, SetupPath.fresh);
    expect(draft.skipRequested, isTrue);
    expect(computeSteps(draft), [
      SetupStepId.welcomeFork,
      SetupStepId.profile,
      SetupStepId.finish,
    ]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/setup_wizard/presentation/providers/setup_wizard_providers_test.dart`
Expected: FAIL — provider file does not exist.

- [ ] **Step 3: Implement the notifier**

`lib/features/setup_wizard/presentation/providers/setup_wizard_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/units.dart' as units;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';

/// Locale code the wizard previews before settings are applied at Finish.
/// Consulted by the app's locale resolution (see app.dart) so a language
/// choice takes effect immediately while the wizard is open.
final previewLocaleProvider = StateProvider<String?>((ref) => null);

/// Draft state for one wizard session, keyed by mode.
final setupWizardProvider = StateNotifierProvider.autoDispose
    .family<SetupWizardNotifier, SetupWizardDraft, SetupWizardMode>(
      (ref, mode) => SetupWizardNotifier(ref, mode),
    );

class SetupWizardNotifier extends StateNotifier<SetupWizardDraft> {
  final Ref _ref;

  SetupWizardNotifier(this._ref, SetupWizardMode mode)
    : super(SetupWizardDraft(mode: mode)) {
    if (mode == SetupWizardMode.settings) {
      // Seed the draft from the live settings so re-entry edits start
      // from what the diver already has.
      state = state.copyWith(settings: _ref.read(settingsProvider));
    }
  }

  void choosePath(SetupPath path) => state = state.copyWith(path: path);

  void chooseSource(ExistingDataSource source) =>
      state = state.copyWith(source: source);

  void requestSkip() =>
      state = state.copyWith(path: SetupPath.fresh, skipRequested: true);

  void setName(String name) => state = state.copyWith(name: name.trim());

  void applyUnitPreset(UnitPreset preset) =>
      state = state.applyingUnitPreset(preset);

  void updateSettings(AppSettings settings) =>
      state = state.copyWith(settings: settings);

  void setBackupEnabled(bool value) =>
      state = state.copyWith(backupEnabled: value);

  void setBackupFrequency(BackupFrequency value) =>
      state = state.copyWith(backupFrequency: value);

  void setCloudBackupEnabled(bool value) =>
      state = state.copyWith(cloudBackupEnabled: value);

  void setConnectedProvider(CloudProviderType? type) =>
      state = state.copyWith(connectedProvider: type);
}
```

Note: the `units` import alias is only needed if the analyzer flags an unused import — the draft's preset logic lives in the domain file. Remove the import if unused.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/setup_wizard/presentation/providers/setup_wizard_providers_test.dart`
Expected: PASS. (The settings-mode seeding path is exercised in Task 5's tests, where settingsProvider is overridable.)

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/setup_wizard test/features/setup_wizard
git commit -m "feat(setup): setup wizard draft notifier and preview locale provider"
```

---

### Task 5: Apply service — persist the draft at Finish

**Files:**
- Create: `lib/features/setup_wizard/data/setup_apply_service.dart`
- Test: `test/features/setup_wizard/data/setup_apply_service_test.dart`
- Modify: `docs/superpowers/specs/2026-07-10-setup-wizard-design.md` (Architecture item 3: replace the `applySettings()` bulk-method sentence with the seed-before-switch approach)

**Interfaces:**
- Consumes: `diverListNotifierProvider`, `currentDiverIdProvider`, `realignActiveDiverAfterDataReplace` (diver_providers.dart); `diverSettingsRepositoryProvider`, `settingsProvider` (settings_providers.dart); `backupSettingsProvider` (backup_providers.dart); Task 3/4 types.
- Produces (used by Task 11): `class SetupApplyService { SetupApplyService(this._ref); Future<void> applyFirstRun(SetupWizardDraft draft); Future<void> applySettingsMode(SetupWizardDraft draft); }` and `final setupApplyServiceProvider = Provider<SetupApplyService>(...)`.

- [ ] **Step 1: Write the failing test**

`test/features/setup_wizard/data/setup_apply_service_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/data/setup_apply_service.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('applyFirstRun creates default diver, seeds settings, sets current',
      () async {
    final container = makeContainer();
    final service = container.read(setupApplyServiceProvider);

    const draft = SetupWizardDraft(
      mode: SetupWizardMode.firstRun,
      path: SetupPath.fresh,
      name: 'Eric',
      backupEnabled: true,
      backupFrequency: BackupFrequency.daily,
    );
    final imperialDraft = draft.applyingUnitPreset(UnitPreset.imperial);

    await service.applyFirstRun(imperialDraft);

    final divers = await DiverRepository().getAllDivers();
    expect(divers, hasLength(1));
    expect(divers.single.name, 'Eric');
    expect(divers.single.isDefault, isTrue);

    // Settings row was seeded with the draft BEFORE the diver switch.
    final stored =
        await DiverSettingsRepository().getSettingsForDiver(divers.single.id);
    expect(stored, isNotNull);
    expect(stored!.depthUnit, DepthUnit.feet);
    expect(stored.pressureUnit, PressureUnit.psi);
    expect(stored.weightUnit, WeightUnit.pounds);

    // Current diver persisted to prefs.
    expect(prefs.getString(currentDiverIdKey), divers.single.id);

    // Backup schedule applied.
    final backup = container.read(backupSettingsProvider);
    expect(backup.enabled, isTrue);
    expect(backup.frequency, BackupFrequency.daily);
  });

  test('applyFirstRun with empty name throws ArgumentError and writes nothing',
      () async {
    final container = makeContainer();
    final service = container.read(setupApplyServiceProvider);
    const draft = SetupWizardDraft(mode: SetupWizardMode.firstRun);

    await expectLater(service.applyFirstRun(draft), throwsArgumentError);
    expect(await DiverRepository().getAllDivers(), isEmpty);
  });

  test('applySettingsMode updates the current diver via existing setters',
      () async {
    final container = makeContainer();

    // Seed a diver + make it current, mirroring a real re-entry session.
    final repo = DiverRepository();
    final now = DateTime.now();
    final diver = await repo.createDiver(Diver(
      id: '',
      name: 'Existing',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ));
    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver(diver.id);
    // Let the SettingsNotifier finish its reload before applying.
    await container.read(settingsProvider.notifier).stream.first;

    final service = container.read(setupApplyServiceProvider);
    const base = SetupWizardDraft(mode: SetupWizardMode.settings);
    final draft = base.applyingUnitPreset(UnitPreset.imperial);
    await service.applySettingsMode(draft);

    final stored =
        await DiverSettingsRepository().getSettingsForDiver(diver.id);
    expect(stored!.depthUnit, DepthUnit.feet);
    expect(stored.volumeUnit, VolumeUnit.cubicFeet);
  });
}
```

Add `import 'package:submersion/features/divers/domain/entities/diver.dart';` to the test imports (needed for the `Diver` constructor in the third test).

Note on the third test: if `settingsProvider.notifier.stream.first` proves flaky for awaiting the reload, replace it with a polling loop (`while (container.read(settingsProvider) == const AppSettings()) { await Future<void>.delayed(const Duration(milliseconds: 10)); }` bounded to ~1s) — the intent is only "reload settled before apply".

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/setup_wizard/data/setup_apply_service_test.dart`
Expected: FAIL — `setup_apply_service.dart` does not exist.

- [ ] **Step 3: Implement the apply service**

`lib/features/setup_wizard/data/setup_apply_service.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';

final setupApplyServiceProvider = Provider<SetupApplyService>(
  (ref) => SetupApplyService(ref),
);

/// Persists a completed wizard draft.
///
/// First-run ordering is load-bearing: the settings row is seeded through
/// the repository BEFORE the diver becomes current, because switching the
/// current diver triggers an unawaited SettingsNotifier reload that would
/// otherwise race the write (and create a defaults row that clobbers ours).
class SetupApplyService {
  final Ref _ref;

  SetupApplyService(this._ref);

  Future<void> applyFirstRun(SetupWizardDraft draft) async {
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw ArgumentError('Diver name must not be empty');
    }

    final now = DateTime.now();
    final newDiver = await _ref
        .read(diverListNotifierProvider.notifier)
        .addDiver(
          Diver(
            id: '',
            name: name,
            isDefault: true,
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Seed the settings row with the draft BEFORE the switch (see class doc).
    await _ref
        .read(diverSettingsRepositoryProvider)
        .createSettingsForDiver(newDiver.id, settings: draft.settings);

    await _ref
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver(newDiver.id);

    await _applyBackupChoices(draft);
  }

  Future<void> applySettingsMode(SetupWizardDraft draft) async {
    // Re-entry: the current diver's settings row exists and the
    // SettingsNotifier is loaded, so the existing setters are race-free.
    final notifier = _ref.read(settingsProvider.notifier);
    final s = draft.settings;
    await notifier.setDepthUnit(s.depthUnit);
    await notifier.setTemperatureUnit(s.temperatureUnit);
    await notifier.setPressureUnit(s.pressureUnit);
    await notifier.setVolumeUnit(s.volumeUnit);
    await notifier.setWeightUnit(s.weightUnit);
    await notifier.setAltitudeUnit(s.altitudeUnit);
    await notifier.setSacUnit(s.sacUnit);
    await notifier.setTimeFormat(s.timeFormat);
    await notifier.setDateFormat(s.dateFormat);
    await notifier.setThemeMode(s.themeMode);
    await notifier.setThemePresetId(s.themePresetId);
    await notifier.setMapStyle(s.mapStyle);
    await notifier.setLocale(s.locale);

    await _applyBackupChoices(draft);
  }

  Future<void> _applyBackupChoices(SetupWizardDraft draft) async {
    final backup = _ref.read(backupSettingsProvider.notifier);
    await backup.setEnabled(draft.backupEnabled);
    if (draft.backupEnabled) {
      await backup.setFrequency(draft.backupFrequency);
    }
    if (draft.connectedProvider != null && draft.cloudBackupEnabled) {
      await backup.setCloudBackupEnabled(true);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/setup_wizard/data/setup_apply_service_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Amend the spec's apply paragraph**

In `docs/superpowers/specs/2026-07-10-setup-wizard-design.md`, replace item 3 of the "Apply order on Finish (first-run)" list (the sentence proposing `SettingsNotifier.applySettings(AppSettings)` and its mock-cost note) with:

```markdown
3. Seed the draft settings into the new diver's `DiverSettings` row via
   `DiverSettingsRepository.createSettingsForDiver(id, settings: draft)`
   BEFORE step 2's diver switch. Switching current diver fires an unawaited
   `SettingsNotifier` reload that would race (and clobber) post-switch
   writes; seeding first means the reload simply loads the seeded row. No
   new `SettingsNotifier` API is needed, so no settings mocks change.
```

Renumber the surrounding list so the switch happens AFTER the seed (create diver → seed settings → set current → backup choices), matching the implementation.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/setup_wizard test/features/setup_wizard docs/superpowers/specs/2026-07-10-setup-wizard-design.md
git commit -m "feat(setup): draft apply service with race-safe settings seeding"
```

---

### Task 6: Wizard shell + fork + profile steps

**Files:**
- Create: `lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart`
- Create: `lib/features/setup_wizard/presentation/widgets/steps/welcome_fork_step.dart`
- Create: `lib/features/setup_wizard/presentation/widgets/steps/profile_step.dart`
- Create: `lib/features/setup_wizard/presentation/widgets/steps/placeholder_step.dart` (temporary; deleted as Tasks 7-11 land)
- Test: `test/features/setup_wizard/presentation/pages/setup_wizard_page_test.dart`

**Interfaces:**
- Consumes: Tasks 3-4 types/providers; `WizardStepIndicator` + `WizardStepDef` from `package:submersion/shared/widgets/wizard/...`; `OceanBackground` from `package:submersion/core/presentation/widgets/ocean_background.dart`.
- Produces: `SetupWizardPage({required SetupWizardMode mode})` — the widget Tasks 12's routes build. Internal contract for step widgets (Tasks 7-11): each content step is a plain widget reading/writing `setupWizardProvider(mode)`; choice steps receive explicit callbacks; the shell exposes `SetupShellController` (advance/back) via constructor injection to steps that own their controls.

- [ ] **Step 1: Write the failing widget test**

`test/features/setup_wizard/presentation/pages/setup_wizard_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/pages/setup_wizard_page.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('first run shows fork; fresh choice walks to profile and back',
      (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(testApp(
      overrides: overrides,
      child: const SetupWizardPage(mode: SetupWizardMode.firstRun),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Submersion'), findsOneWidget);
    expect(find.text('Set up a new logbook'), findsOneWidget);
    expect(find.text('I have existing Submersion data'), findsOneWidget);

    await tester.tap(find.text('Set up a new logbook'));
    await tester.pumpAndSettle();

    expect(find.text('Create Your Profile'), findsOneWidget);

    // Next disabled with empty name.
    final nextFinder = find.widgetWithText(FilledButton, 'Next');
    expect(tester.widget<FilledButton>(nextFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextFormField), 'Eric');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(nextFinder).onPressed, isNotNull);

    await tester.tap(nextFinder);
    await tester.pumpAndSettle();
    // Units placeholder page (real step lands in Task 7).
    expect(find.text('Units'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
    await tester.pumpAndSettle();
    expect(find.text('Create Your Profile'), findsOneWidget);
  });

  testWidgets('skip setup jumps from profile straight to finish placeholder',
      (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(testApp(
      overrides: overrides,
      child: const SetupWizardPage(mode: SetupWizardMode.firstRun),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip setup'));
    await tester.pumpAndSettle();
    expect(find.text('Create Your Profile'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Eric');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.text("You're all set"), findsOneWidget);
  });

  testWidgets('settings mode starts at units with no fork', (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(testApp(
      overrides: overrides,
      child: const SetupWizardPage(mode: SetupWizardMode.settings),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Submersion'), findsNothing);
    expect(find.text('Units'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/setup_wizard/presentation/pages/setup_wizard_page_test.dart`
Expected: FAIL — `setup_wizard_page.dart` does not exist.

- [ ] **Step 3: Implement the shell and first two steps**

`lib/features/setup_wizard/presentation/widgets/steps/welcome_fork_step.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// First-run fork: start fresh, bring existing data, or skip setup.
class WelcomeForkStep extends StatelessWidget {
  final VoidCallback onStartFresh;
  final VoidCallback onExistingData;
  final VoidCallback onSkipSetup;

  const WelcomeForkStep({
    super.key,
    required this.onStartFresh,
    required this.onExistingData,
    required this.onSkipSetup,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 96,
                  height: 96,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.setup_welcome_title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setup_welcome_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _ForkCard(
            icon: Icons.add_circle_outline,
            title: l10n.setup_welcome_startFresh_title,
            subtitle: l10n.setup_welcome_startFresh_subtitle,
            onTap: onStartFresh,
          ),
          const SizedBox(height: 12),
          _ForkCard(
            icon: Icons.cloud_download_outlined,
            title: l10n.setup_welcome_existingData_title,
            subtitle: l10n.setup_welcome_existingData_subtitle,
            onTap: onExistingData,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: onSkipSetup,
            child: Text(l10n.setup_welcome_skipSetup),
          ),
        ],
      ),
    );
  }
}

class _ForkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ForkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
```

`lib/features/setup_wizard/presentation/widgets/steps/profile_step.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Collects the diver name (the wizard's only mandatory input).
class ProfileStep extends ConsumerStatefulWidget {
  final SetupWizardMode mode;

  const ProfileStep({super.key, required this.mode});

  @override
  ConsumerState<ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends ConsumerState<ProfileStep> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(setupWizardProvider(widget.mode)).name,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(setupWizardProvider(widget.mode).notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.setup_profile_title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setup_profile_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.setup_profile_nameLabel,
              hintText: l10n.setup_profile_nameHint,
              prefixIcon: const Icon(Icons.person),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: notifier.setName,
          ),
        ],
      ),
    );
  }
}
```

`lib/features/setup_wizard/presentation/widgets/steps/placeholder_step.dart` (temporary scaffolding so the shell compiles before Tasks 7-11; each later task replaces one usage):

```dart
import 'package:flutter/material.dart';

/// Temporary stand-in for steps implemented in later tasks.
class PlaceholderStep extends StatelessWidget {
  final String title;

  const PlaceholderStep({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
```

`lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/presentation/widgets/ocean_background.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/placeholder_step.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/profile_step.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/welcome_fork_step.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_indicator.dart';

/// Multi-step setup wizard for new databases (first run) and Settings
/// re-entry. See docs/superpowers/specs/2026-07-10-setup-wizard-design.md.
class SetupWizardPage extends ConsumerStatefulWidget {
  final SetupWizardMode mode;

  const SetupWizardPage({super.key, required this.mode});

  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

/// Steps that show the progress indicator and the shared Next/Back bar.
const _formZone = {
  SetupStepId.profile,
  SetupStepId.units,
  SetupStepId.appearance,
  SetupStepId.backupSync,
};

class _SetupWizardPageState extends ConsumerState<SetupWizardPage> {
  final _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _animateTo(int index) async {
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    if (mounted) setState(() => _currentIndex = index);
  }

  void _advance() {
    final steps = computeSteps(ref.read(setupWizardProvider(widget.mode)));
    if (_currentIndex < steps.length - 1) {
      _animateTo(_currentIndex + 1);
    }
  }

  void _back() {
    if (_currentIndex > 0) _animateTo(_currentIndex - 1);
  }

  /// Choice steps mutate the draft (growing the step list), then advance
  /// after the rebuild that adds the next page.
  void _chooseAndAdvance(void Function() mutate) {
    mutate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _advance();
    });
  }

  String _stepLabel(SetupStepId id) {
    final l10n = context.l10n;
    switch (id) {
      case SetupStepId.profile:
        return l10n.setup_step_profile;
      case SetupStepId.units:
        return l10n.setup_step_units;
      case SetupStepId.appearance:
        return l10n.setup_step_appearance;
      case SetupStepId.backupSync:
        return l10n.setup_step_backup;
      case SetupStepId.finish:
        return l10n.setup_step_finish;
      default:
        return '';
    }
  }

  WizardStepDef _defFor(SetupStepId id) {
    final mode = widget.mode;
    final notifier = ref.read(setupWizardProvider(mode).notifier);
    switch (id) {
      case SetupStepId.welcomeFork:
        return WizardStepDef(
          label: '',
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => WelcomeForkStep(
            onStartFresh: () =>
                _chooseAndAdvance(() => notifier.choosePath(SetupPath.fresh)),
            onExistingData: () => _chooseAndAdvance(
              () => notifier.choosePath(SetupPath.existingData),
            ),
            onSkipSetup: () => _chooseAndAdvance(notifier.requestSkip),
          ),
        );
      case SetupStepId.profile:
        return WizardStepDef(
          label: _stepLabel(id),
          canAdvance: setupWizardProvider(
            mode,
          ).select((d) => d.name.trim().isNotEmpty),
          builder: (_) => ProfileStep(mode: mode),
        );
      case SetupStepId.units:
        return WizardStepDef(
          label: _stepLabel(id),
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const PlaceholderStep(title: 'Units'),
        );
      case SetupStepId.appearance:
        return WizardStepDef(
          label: _stepLabel(id),
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const PlaceholderStep(title: 'Appearance'),
        );
      case SetupStepId.backupSync:
        return WizardStepDef(
          label: _stepLabel(id),
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const PlaceholderStep(title: 'Backups & Sync'),
        );
      case SetupStepId.finish:
        return WizardStepDef(
          label: _stepLabel(id),
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const PlaceholderStep(title: "You're all set"),
        );
      case SetupStepId.existingChoice:
        return WizardStepDef(
          label: '',
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const PlaceholderStep(title: 'Bring your data'),
        );
      case SetupStepId.restore:
        return WizardStepDef(
          label: '',
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const PlaceholderStep(title: 'Restore backup'),
        );
      case SetupStepId.syncConnect:
        return WizardStepDef(
          label: '',
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const PlaceholderStep(title: 'Connect and pull'),
        );
      case SetupStepId.openFolder:
        return WizardStepDef(
          label: '',
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const PlaceholderStep(title: 'Open existing folder'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(setupWizardProvider(widget.mode));
    final steps = computeSteps(draft);
    if (_currentIndex >= steps.length) {
      _currentIndex = steps.length - 1;
    }
    final defs = steps.map(_defFor).toList();
    final currentId = steps[_currentIndex];
    final inFormZone = _formZone.contains(currentId);

    // Indicator covers the contiguous labelled tail of the flow (profile or
    // units onward, plus finish); choice steps stay indicator-free.
    final labelledIds = steps
        .where((s) => _formZone.contains(s) || s == SetupStepId.finish)
        .toList();
    final labelledIndex = labelledIds.indexOf(currentId);

    return Scaffold(
      body: OceanBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      if (labelledIndex >= 0)
                        WizardStepIndicator(
                          labels: labelledIds.map(_stepLabel).toList(),
                          currentStep: labelledIndex,
                        ),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (final def in defs)
                              Builder(builder: def.builder),
                          ],
                        ),
                      ),
                      if (inFormZone) _buildBottomBar(defs[_currentIndex]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(WizardStepDef def) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (_currentIndex > 0)
              OutlinedButton(
                onPressed: _back,
                child: Text(l10n.setup_common_back),
              ),
            const Spacer(),
            if (_currentIndex < computeStepCount() - 1 &&
                _skippable(currentStepId()))
              TextButton(
                onPressed: _advance,
                child: Text(l10n.setup_common_skip),
              ),
            const SizedBox(width: 8),
            _NextButton(def: def, onNext: _advance),
          ],
        ),
      ),
    );
  }

  SetupStepId currentStepId() {
    final steps = computeSteps(ref.read(setupWizardProvider(widget.mode)));
    return steps[_currentIndex];
  }

  int computeStepCount() {
    return computeSteps(ref.read(setupWizardProvider(widget.mode))).length;
  }

  bool _skippable(SetupStepId id) => id != SetupStepId.profile;
}

class _NextButton extends ConsumerWidget {
  final WizardStepDef def;
  final VoidCallback onNext;

  const _NextButton({required this.def, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAdvance = ref.watch(def.canAdvance);
    return FilledButton(
      style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
      onPressed: canAdvance ? onNext : null,
      child: Text(context.l10n.setup_common_next),
    );
  }
}
```

Implementation note: `Expanded(child: PageView(...))` inside a `Card` inside `Center` needs bounded height — the `Center > ConstrainedBox > Padding > Card > Column` chain is height-unbounded on desktop. Wrap the `ConstrainedBox` content so the column gets the full safe-area height: replace `Center(child: ConstrainedBox(...))` with `Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: SizedBox.expand(child: ...)))` — `SizedBox.expand` inside `Center` clamps to the parent's max size and keeps the card full-height. If the first test run throws unbounded-height layout errors, this is the fix to apply.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/setup_wizard/presentation/pages/setup_wizard_page_test.dart`
Expected: 3 tests PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/setup_wizard test/features/setup_wizard
git commit -m "feat(setup): wizard shell with fork and profile steps"
```

---

### Task 7: Units step

**Files:**
- Create: `lib/features/setup_wizard/presentation/widgets/steps/units_step.dart`
- Modify: `lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart` (replace the units `PlaceholderStep` with `UnitsStep(mode: mode)`)
- Test: `test/features/setup_wizard/presentation/widgets/steps/units_step_test.dart`

**Interfaces:**
- Consumes: `setupWizardProvider`, `presetForLocale`, `UnitPreset`, the unit enums, `TimeFormat`, `DateFormatPreference`.
- Produces: `UnitsStep({required SetupWizardMode mode})`.

- [ ] **Step 1: Write the failing test**

`test/features/setup_wizard/presentation/widgets/steps/units_step_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/units_step.dart';

import '../../../../../helpers/test_app.dart';

void main() {
  testWidgets('preset toggle drives the draft units', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(testApp(
      child: Builder(builder: (context) {
        container = ProviderScope.containerOf(context);
        return const UnitsStep(mode: SetupWizardMode.firstRun);
      }),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Imperial'));
    await tester.pumpAndSettle();

    final draft =
        container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.settings.unitPreset, UnitPreset.imperial);
    expect(draft.settings.depthUnit, DepthUnit.feet);
  });

  testWidgets('advanced expander exposes per-unit overrides', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(testApp(
      child: Builder(builder: (context) {
        container = ProviderScope.containerOf(context);
        return const UnitsStep(mode: SetupWizardMode.firstRun);
      }),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fine-tune units'));
    await tester.pumpAndSettle();

    // Depth row: switch to feet only.
    await tester.ensureVisible(find.text('Depth'));
    await tester.tap(find.byKey(const ValueKey('setup-unit-depth-ft')));
    await tester.pumpAndSettle();

    final draft =
        container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.settings.depthUnit, DepthUnit.feet);
    expect(draft.settings.temperatureUnit, TemperatureUnit.celsius);
    expect(draft.settings.unitPreset, UnitPreset.custom);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/setup_wizard/presentation/widgets/steps/units_step_test.dart`
Expected: FAIL — `units_step.dart` does not exist.

- [ ] **Step 3: Implement the step**

`lib/features/setup_wizard/presentation/widgets/steps/units_step.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/domain/unit_preset_detector.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Metric/Imperial preset with an expander for per-unit fine-tuning.
class UnitsStep extends ConsumerStatefulWidget {
  final SetupWizardMode mode;

  const UnitsStep({super.key, required this.mode});

  @override
  ConsumerState<UnitsStep> createState() => _UnitsStepState();
}

class _UnitsStepState extends ConsumerState<UnitsStep> {
  @override
  void initState() {
    super.initState();
    // First-run: preselect the preset matching the device locale, once.
    if (widget.mode == SetupWizardMode.firstRun) {
      final draft = ref.read(setupWizardProvider(widget.mode));
      if (draft.settings.unitPreset == UnitPreset.metric) {
        final locale =
            WidgetsBinding.instance.platformDispatcher.locale;
        final preset = presetForLocale(locale);
        if (preset != UnitPreset.metric) {
          Future.microtask(() {
            if (mounted) {
              ref
                  .read(setupWizardProvider(widget.mode).notifier)
                  .applyUnitPreset(preset);
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final draft = ref.watch(setupWizardProvider(widget.mode));
    final notifier = ref.read(setupWizardProvider(widget.mode).notifier);
    final s = draft.settings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.setup_units_title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setup_units_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SegmentedButton<UnitPreset>(
            segments: [
              ButtonSegment(
                value: UnitPreset.metric,
                label: Text(l10n.setup_units_metric),
              ),
              ButtonSegment(
                value: UnitPreset.imperial,
                label: Text(l10n.setup_units_imperial),
              ),
            ],
            emptySelectionAllowed: true,
            selected: s.unitPreset == UnitPreset.custom
                ? const {}
                : {s.unitPreset},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                notifier.applyUnitPreset(selection.first);
              }
            },
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            title: Text(l10n.setup_units_advanced),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              _unitRow<DepthUnit>(
                label: l10n.setup_units_depth,
                keyPrefix: 'setup-unit-depth',
                values: DepthUnit.values,
                selected: s.depthUnit,
                symbol: (u) => u.symbol,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(depthUnit: u)),
              ),
              _unitRow<TemperatureUnit>(
                label: l10n.setup_units_temperature,
                keyPrefix: 'setup-unit-temperature',
                values: TemperatureUnit.values,
                selected: s.temperatureUnit,
                symbol: (u) => u.symbol,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(temperatureUnit: u)),
              ),
              _unitRow<PressureUnit>(
                label: l10n.setup_units_pressure,
                keyPrefix: 'setup-unit-pressure',
                values: PressureUnit.values,
                selected: s.pressureUnit,
                symbol: (u) => u.symbol,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(pressureUnit: u)),
              ),
              _unitRow<VolumeUnit>(
                label: l10n.setup_units_volume,
                keyPrefix: 'setup-unit-volume',
                values: VolumeUnit.values,
                selected: s.volumeUnit,
                symbol: (u) => u.symbol,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(volumeUnit: u)),
              ),
              _unitRow<WeightUnit>(
                label: l10n.setup_units_weight,
                keyPrefix: 'setup-unit-weight',
                values: WeightUnit.values,
                selected: s.weightUnit,
                symbol: (u) => u.symbol,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(weightUnit: u)),
              ),
              _unitRow<AltitudeUnit>(
                label: l10n.setup_units_altitude,
                keyPrefix: 'setup-unit-altitude',
                values: AltitudeUnit.values,
                selected: s.altitudeUnit,
                symbol: (u) => u.symbol,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(altitudeUnit: u)),
              ),
              _unitRow<SacUnit>(
                label: l10n.setup_units_sac,
                keyPrefix: 'setup-unit-sac',
                values: SacUnit.values,
                selected: s.sacUnit,
                symbol: (u) => u.symbol,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(sacUnit: u)),
              ),
              _unitRow<TimeFormat>(
                label: l10n.setup_units_timeFormat,
                keyPrefix: 'setup-unit-timeformat',
                values: TimeFormat.values,
                selected: s.timeFormat,
                symbol: (u) => u.displayName,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(timeFormat: u)),
              ),
              _unitRow<DateFormatPreference>(
                label: l10n.setup_units_dateFormat,
                keyPrefix: 'setup-unit-dateformat',
                values: DateFormatPreference.values,
                selected: s.dateFormat,
                symbol: (u) => u.displayName,
                onChanged: (u) =>
                    notifier.updateSettings(s.copyWith(dateFormat: u)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unitRow<T extends Enum>({
    required String label,
    required String keyPrefix,
    required List<T> values,
    required T selected,
    required String Function(T) symbol,
    required void Function(T) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SegmentedButton<T>(
            segments: [
              for (final v in values)
                ButtonSegment(
                  value: v,
                  label: Text(
                    symbol(v),
                    key: ValueKey('$keyPrefix-${_segmentKey(symbol(v))}'),
                  ),
                ),
            ],
            selected: {selected},
            showSelectedIcon: false,
            onSelectionChanged: (sel) => onChanged(sel.first),
          ),
        ],
      ),
    );
  }

  String _segmentKey(String symbol) =>
      symbol.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
```

(The depth "ft" segment therefore carries `ValueKey('setup-unit-depth-ft')`, matching the test.)

- [ ] **Step 4: Replace the placeholder in the shell**

In `setup_wizard_page.dart`, add `import 'package:submersion/features/setup_wizard/presentation/widgets/steps/units_step.dart';` and change the `SetupStepId.units` case builder from `const PlaceholderStep(title: 'Units')` to `UnitsStep(mode: mode)`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/setup_wizard/`
Expected: all PASS (the shell test's `find.text('Units')` assertion still matches the real step's title).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/setup_wizard test/features/setup_wizard
git commit -m "feat(setup): units step with locale-aware preset and fine-tuning"
```

---

### Task 8: Appearance step + locale preview hook

**Files:**
- Create: `lib/features/setup_wizard/presentation/widgets/steps/appearance_step.dart`
- Modify: `lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart` (replace appearance placeholder)
- Modify: `lib/app.dart` (preview-locale hook, 2 lines)
- Test: `test/features/setup_wizard/presentation/widgets/steps/appearance_step_test.dart`

**Interfaces:**
- Consumes: `previewLocaleProvider` (Task 4), `AppThemeRegistry` (`lib/core/theme/app_theme_registry.dart`, preset ids: submersion, console, tropical, minimalist, deep — display name via each preset's `nameKey` l10n key), `MapStyle`.
- Produces: `AppearanceStep({required SetupWizardMode mode})`; app-wide locale preview while the wizard is open.

- [ ] **Step 1: Write the failing test**

`test/features/setup_wizard/presentation/widgets/steps/appearance_step_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/appearance_step.dart';

import '../../../../../helpers/test_app.dart';

void main() {
  testWidgets('theme, map style, and language update draft and preview',
      (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(testApp(
      child: Builder(builder: (context) {
        container = ProviderScope.containerOf(context);
        return const AppearanceStep(mode: SetupWizardMode.firstRun);
      }),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Map style'));
    await tester.tap(find.text('Satellite'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch').last);
    await tester.pumpAndSettle();

    final draft =
        container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.settings.themeMode, ThemeMode.dark);
    expect(draft.settings.mapStyle, MapStyle.esriSatellite);
    expect(draft.settings.locale, 'de');
    expect(container.read(previewLocaleProvider), 'de');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/setup_wizard/presentation/widgets/steps/appearance_step_test.dart`
Expected: FAIL — `appearance_step.dart` does not exist.

- [ ] **Step 3: Implement the step**

`lib/features/setup_wizard/presentation/widgets/steps/appearance_step.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Language options offered by the wizard. Codes must stay in sync with
/// AppLocalizations.supportedLocales; names render in their own language.
const _localeOptions = <(String, String)>[
  ('system', ''),
  ('en', 'English'),
  ('es', 'Espanol'),
  ('fr', 'Francais'),
  ('de', 'Deutsch'),
  ('it', 'Italiano'),
  ('nl', 'Nederlands'),
  ('pt', 'Portugues'),
  ('hu', 'Magyar'),
  ('ar', 'العربية'),
  ('he', 'עברית'),
  ('zh', '简体中文'),
];

/// Theme mode, color theme, map style, and language.
class AppearanceStep extends ConsumerWidget {
  final SetupWizardMode mode;

  const AppearanceStep({super.key, required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final draft = ref.watch(setupWizardProvider(mode));
    final notifier = ref.read(setupWizardProvider(mode).notifier);
    final s = draft.settings;

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.setup_appearance_title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setup_appearance_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          sectionLabel(l10n.setup_appearance_theme),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.setup_appearance_themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.setup_appearance_themeLight),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l10n.setup_appearance_themeDark),
              ),
            ],
            selected: {s.themeMode},
            showSelectedIcon: false,
            onSelectionChanged: (sel) => notifier.updateSettings(
              s.copyWith(themeMode: sel.first),
            ),
          ),
          sectionLabel(l10n.setup_appearance_themePreset),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in AppThemeRegistry.presets)
                ChoiceChip(
                  label: Text(preset.id),
                  selected: s.themePresetId == preset.id,
                  onSelected: (_) => notifier.updateSettings(
                    s.copyWith(themePresetId: preset.id),
                  ),
                ),
            ],
          ),
          sectionLabel(l10n.setup_appearance_mapStyle),
          SegmentedButton<MapStyle>(
            segments: [
              ButtonSegment(
                value: MapStyle.openStreetMap,
                label: Text(l10n.setup_appearance_mapStyle_openStreetMap),
              ),
              ButtonSegment(
                value: MapStyle.openTopoMap,
                label: Text(l10n.setup_appearance_mapStyle_openTopoMap),
              ),
              ButtonSegment(
                value: MapStyle.esriSatellite,
                label: Text(l10n.setup_appearance_mapStyle_esriSatellite),
              ),
            ],
            selected: {s.mapStyle},
            showSelectedIcon: false,
            onSelectionChanged: (sel) => notifier.updateSettings(
              s.copyWith(mapStyle: sel.first),
            ),
          ),
          sectionLabel(l10n.setup_appearance_language),
          DropdownButtonFormField<String>(
            initialValue: s.locale,
            items: [
              for (final (code, nativeName) in _localeOptions)
                DropdownMenuItem(
                  value: code,
                  child: Text(
                    code == 'system'
                        ? l10n.setup_appearance_themeSystem
                        : nativeName,
                  ),
                ),
            ],
            onChanged: (code) {
              if (code == null) return;
              notifier.updateSettings(s.copyWith(locale: code));
              ref.read(previewLocaleProvider.notifier).state =
                  code == 'system' ? null : code;
            },
          ),
        ],
      ),
    );
  }
}
```

Note: theme preset chips label with the raw preset `id` — the registry's `nameKey` values (`theme_submersion` etc.) are existing l10n keys; if `context.l10n` exposes them via a lookup helper elsewhere in the codebase, prefer that. Check `rg -n "nameKey" lib --glob '*.dart'` for the existing resolution pattern (the appearance settings page uses one) and mirror it; fall back to capitalized ids only if no pattern exists.
Note: if the analyzer version in this repo rejects the `(String, String)` record-list syntax or `DropdownButtonFormField.initialValue` (older Flutter), use a small private class with `code`/`nativeName` fields and the `value:` parameter respectively.

- [ ] **Step 4: Wire the preview locale into app.dart**

In `lib/app.dart`:
1. Add import: `import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';`
2. In `build` (near line 269 where `localeProvider` is read): add `final previewLocale = ref.watch(previewLocaleProvider);`
3. Change the MaterialApp.router line `locale: _resolveLocale(localeSetting),` to `locale: _resolveLocale(previewLocale ?? localeSetting),`

- [ ] **Step 5: Replace the placeholder in the shell**

In `setup_wizard_page.dart`, import `appearance_step.dart` and change the `SetupStepId.appearance` case builder to `AppearanceStep(mode: mode)`.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/setup_wizard/ && flutter analyze lib/app.dart lib/features/setup_wizard`
Expected: tests PASS; analyze clean.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/features/setup_wizard lib/app.dart test/features/setup_wizard
git commit -m "feat(setup): appearance step with live language preview"
```

---

### Task 9: Backup & Sync step

**Files:**
- Create: `lib/features/setup_wizard/presentation/widgets/steps/backup_sync_step.dart`
- Modify: `lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart` (replace backupSync placeholder)
- Test: `test/features/setup_wizard/presentation/widgets/steps/backup_sync_step_test.dart`

**Interfaces:**
- Consumes: `backupSettingsProvider` state only for re-entry status display; draft fields for the toggles; sync gates `isApplePlatformProvider`, `iCloudAvailabilityProvider`, `dropboxConfiguredProvider`, `selectedCloudProviderTypeProvider`, `dropboxStorageProviderInstanceProvider`, `syncInitializerProvider`, `syncStateProvider`, `cloudProviderInstanceFor` (all from `lib/features/settings/presentation/providers/sync_providers.dart`); `DropboxConnectDialog`; `CloudProviderType`; `ICloudAvailability` from `lib/core/services/cloud_storage/icloud_native_service.dart`.
- Produces: `BackupSyncStep({required SetupWizardMode mode, this.onLibraryFound})` where `onLibraryFound: void Function()?` is invoked when a freshly connected provider already holds a library (fresh-path pivot; wired in Task 11).

- [ ] **Step 1: Write the failing test**

`test/features/setup_wizard/presentation/widgets/steps/backup_sync_step_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/backup_sync_step.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

void main() {
  testWidgets('backup toggle reveals frequency and updates draft',
      (tester) async {
    late ProviderContainer container;
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(testApp(
      overrides: [
        ...overrides,
        // Deterministic gates: not Apple, no Dropbox key.
        isApplePlatformProvider.overrideWithValue(false),
        dropboxConfiguredProvider.overrideWithValue(false),
      ],
      child: Builder(builder: (context) {
        container = ProviderScope.containerOf(context);
        return const BackupSyncStep(mode: SetupWizardMode.firstRun);
      }),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Frequency'), findsNothing);
    await tester.tap(find.text('Automatic backups'));
    await tester.pumpAndSettle();

    expect(find.text('Frequency'), findsOneWidget);
    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();

    final draft =
        container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.backupEnabled, isTrue);
    expect(draft.backupFrequency, BackupFrequency.daily);
  });

  testWidgets('non-Apple platform without Dropbox shows S3 card only',
      (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(testApp(
      overrides: [
        ...overrides,
        isApplePlatformProvider.overrideWithValue(false),
        dropboxConfiguredProvider.overrideWithValue(false),
      ],
      child: const BackupSyncStep(mode: SetupWizardMode.firstRun),
    ));
    await tester.pumpAndSettle();

    expect(find.text('iCloud'), findsNothing);
    expect(find.text('Dropbox'), findsNothing);
    expect(find.text('S3'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
  });
}
```

Override note: `isApplePlatformProvider` and `dropboxConfiguredProvider` are plain `Provider<bool>`s, so `overrideWithValue` is correct. If either is declared differently in `sync_providers.dart`, switch to `overrideWith((ref) => false)`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/setup_wizard/presentation/widgets/steps/backup_sync_step_test.dart`
Expected: FAIL — `backup_sync_step.dart` does not exist.

- [ ] **Step 3: Implement the step**

`lib/features/setup_wizard/presentation/widgets/steps/backup_sync_step.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/dropbox_connect_dialog.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Backup schedule plus optional cloud sync provider connection.
class BackupSyncStep extends ConsumerStatefulWidget {
  final SetupWizardMode mode;

  /// Fresh-path pivot: called when a just-connected provider already holds
  /// a Submersion library (Task 11 wires the adopt offer).
  final void Function()? onLibraryFound;

  const BackupSyncStep({super.key, required this.mode, this.onLibraryFound});

  @override
  ConsumerState<BackupSyncStep> createState() => _BackupSyncStepState();
}

class _BackupSyncStepState extends ConsumerState<BackupSyncStep> {
  bool _connecting = false;

  Future<void> _connect(CloudProviderType type) async {
    final notifier = ref.read(setupWizardProvider(widget.mode).notifier);
    setState(() => _connecting = true);
    try {
      if (type == CloudProviderType.dropbox) {
        final connected = await showDialog<bool>(
          context: context,
          builder: (_) => DropboxConnectDialog(
            provider: ref.read(dropboxStorageProviderInstanceProvider),
          ),
        );
        ref.invalidate(dropboxAuthDataProvider);
        if (connected != true) return;
      }
      // Activation contract mirrored from CloudSyncPage._selectProvider.
      ref.read(selectedCloudProviderTypeProvider.notifier).state = type;
      final instance = cloudProviderInstanceFor(type);
      await instance.authenticate();
      await ref.read(syncInitializerProvider).saveProvider(type);
      ref.read(syncStateProvider.notifier).refreshState();
      notifier.setConnectedProvider(type);

      // Fresh-path pivot check: does this account already hold a library?
      if (widget.onLibraryFound != null) {
        final peers = await ref
            .read(syncInitializerProvider)
            .peerSyncFiles(instance);
        if (peers.isNotEmpty && mounted) widget.onLibraryFound!();
      }
    } catch (e) {
      ref.read(selectedCloudProviderTypeProvider.notifier).state = null;
      notifier.setConnectedProvider(null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.setup_sync_error(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final draft = ref.watch(setupWizardProvider(widget.mode));
    final notifier = ref.read(setupWizardProvider(widget.mode).notifier);

    final isApple = ref.watch(isApplePlatformProvider);
    final iCloudAvailability =
        ref.watch(iCloudAvailabilityProvider).valueOrNull;
    final iCloudAvailable =
        isApple && iCloudAvailability != ICloudAvailability.unsupported;
    final dropboxConfigured = ref.watch(dropboxConfiguredProvider);
    final connected = draft.connectedProvider;

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.setup_backup_title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setup_backup_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.setup_backup_scheduleToggle),
            subtitle: Text(l10n.setup_backup_scheduleSubtitle),
            value: draft.backupEnabled,
            onChanged: notifier.setBackupEnabled,
          ),
          if (draft.backupEnabled) ...[
            sectionLabel(l10n.setup_backup_frequency),
            SegmentedButton<BackupFrequency>(
              segments: [
                ButtonSegment(
                  value: BackupFrequency.daily,
                  label: Text(l10n.setup_backup_frequency_daily),
                ),
                ButtonSegment(
                  value: BackupFrequency.weekly,
                  label: Text(l10n.setup_backup_frequency_weekly),
                ),
                ButtonSegment(
                  value: BackupFrequency.monthly,
                  label: Text(l10n.setup_backup_frequency_monthly),
                ),
              ],
              selected: {draft.backupFrequency},
              showSelectedIcon: false,
              onSelectionChanged: (sel) =>
                  notifier.setBackupFrequency(sel.first),
            ),
          ],
          sectionLabel(l10n.setup_sync_header),
          Text(
            l10n.setup_sync_subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (connected != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_done),
              title: Text(
                l10n.setup_sync_connectedTo(_providerName(connected)),
              ),
            )
          else ...[
            Text(
              l10n.setup_sync_notConnected,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (iCloudAvailable)
              _providerCard(
                icon: Icons.cloud,
                name: 'iCloud',
                onTap: _connecting
                    ? null
                    : () => _connect(CloudProviderType.icloud),
              ),
            if (dropboxConfigured)
              _providerCard(
                icon: Icons.cloud_queue,
                name: 'Dropbox',
                onTap: _connecting
                    ? null
                    : () => _connect(CloudProviderType.dropbox),
              ),
            _providerCard(
              icon: Icons.storage,
              name: 'S3',
              // S3ConfigPage performs its own activation on save.
              onTap: _connecting
                  ? null
                  : () => context.push('/settings/cloud-sync/s3-config'),
            ),
          ],
          if (connected != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.setup_backup_cloudCopy),
              value: draft.cloudBackupEnabled,
              onChanged: notifier.setCloudBackupEnabled,
            ),
        ],
      ),
    );
  }

  Widget _providerCard({
    required IconData icon,
    required String name,
    required VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon),
        title: Text(name),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _providerName(CloudProviderType type) {
    switch (type) {
      case CloudProviderType.icloud:
        return 'iCloud';
      case CloudProviderType.dropbox:
        return 'Dropbox';
      case CloudProviderType.s3:
        return 'S3';
      case CloudProviderType.googledrive:
        return 'Google Drive';
    }
  }
}
```

Re-entry nuance: in settings mode with a provider already active (`ref.watch(selectedCloudProviderTypeProvider) != null` and no draft connection), render the connected tile using that provider plus a `TextButton` labelled `l10n.setup_sync_manageInSettings` navigating `context.push('/settings/cloud-sync')` instead of the connect cards. Implement as: `final effectiveConnected = connected ?? (widget.mode == SetupWizardMode.settings ? ref.watch(selectedCloudProviderTypeProvider) : null);` and branch on `effectiveConnected`, showing the manage button only in settings mode.

S3 return detection: after `context.push('/settings/cloud-sync/s3-config')` resolves, S3ConfigPage has already activated S3 on save; add `.then((_) { final sel = ref.read(selectedCloudProviderTypeProvider); if (sel == CloudProviderType.s3 && mounted) { ref.read(setupWizardProvider(widget.mode).notifier).setConnectedProvider(sel); } })` to the push call so the wizard reflects it.

- [ ] **Step 4: Replace the placeholder in the shell**

In `setup_wizard_page.dart`, import `backup_sync_step.dart` and change the `SetupStepId.backupSync` builder to `BackupSyncStep(mode: mode)` (the `onLibraryFound` pivot is wired in Task 11).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/setup_wizard/`
Expected: all PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/setup_wizard test/features/setup_wizard
git commit -m "feat(setup): backup schedule and cloud sync connection step"
```

---

### Task 10: Finish step — feature highlights + apply

**Files:**
- Create: `lib/features/setup_wizard/presentation/widgets/steps/finish_step.dart`
- Modify: `lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart` (replace finish placeholder)
- Test: `test/features/setup_wizard/presentation/widgets/steps/finish_step_test.dart`

**Interfaces:**
- Consumes: `setupApplyServiceProvider` (Task 5), `previewLocaleProvider`, draft.
- Produces: `FinishStep({required SetupWizardMode mode})`. Navigation contract: first-run completion goes `context.go('/dashboard')` (or a tapped feature route); settings mode pops.

- [ ] **Step 1: Write the failing test**

`test/features/setup_wizard/presentation/widgets/steps/finish_step_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/finish_step.dart';

import '../../../../../helpers/test_app.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('start logging applies draft and navigates to dashboard',
      (tester) async {
    var dashboardShown = false;
    final router = GoRouter(
      initialLocation: '/wizard',
      routes: [
        GoRoute(
          path: '/wizard',
          builder: (context, state) => Consumer(
            builder: (context, ref, _) {
              // Seed a completed fresh-path draft before rendering.
              final notifier = ref.read(
                setupWizardProvider(SetupWizardMode.firstRun).notifier,
              );
              notifier.choosePath(SetupPath.fresh);
              notifier.setName('Eric');
              return const Scaffold(
                body: FinishStep(mode: SetupWizardMode.firstRun),
              );
            },
          ),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) {
            dashboardShown = true;
            return const Scaffold(body: Text('dashboard'));
          },
        ),
      ],
    );

    await tester.pumpWidget(testAppRouter(
      router: router,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    ));
    await tester.pumpAndSettle();

    expect(find.text("You're all set"), findsOneWidget);
    expect(find.text('Download dives from your dive computer'),
        findsOneWidget);

    await tester.tap(find.text('Start logging'));
    await tester.runAsync(() async {
      // Apply performs real DB writes; let them settle outside fake time.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(dashboardShown, isTrue);
    final divers = await tester.runAsync(() => DiverRepository().getAllDivers());
    expect(divers, hasLength(1));
    expect(divers!.single.name, 'Eric');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/setup_wizard/presentation/widgets/steps/finish_step_test.dart`
Expected: FAIL — `finish_step.dart` does not exist.

- [ ] **Step 3: Implement the step**

`lib/features/setup_wizard/presentation/widgets/steps/finish_step.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/setup_wizard/data/setup_apply_service.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Final step: feature discovery plus the apply-and-go action.
class FinishStep extends ConsumerStatefulWidget {
  final SetupWizardMode mode;

  const FinishStep({super.key, required this.mode});

  @override
  ConsumerState<FinishStep> createState() => _FinishStepState();
}

class _FinishStepState extends ConsumerState<FinishStep> {
  bool _applying = false;

  Future<void> _complete({String route = '/dashboard'}) async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      final draft = ref.read(setupWizardProvider(widget.mode));
      final service = ref.read(setupApplyServiceProvider);
      if (widget.mode == SetupWizardMode.firstRun) {
        await service.applyFirstRun(draft);
      } else {
        await service.applySettingsMode(draft);
      }
      // Locale now persists via settings; drop the preview override.
      ref.read(previewLocaleProvider.notifier).state = null;
      if (!mounted) return;
      if (widget.mode == SetupWizardMode.firstRun) {
        context.go(route);
      } else if (route != '/dashboard') {
        context.go(route);
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _applying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.setup_finish_error(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final features = <(IconData, String, String)>[
      (
        Icons.watch,
        l10n.setup_finish_feature_diveComputer,
        '/dive-computers/discover',
      ),
      (Icons.file_upload, l10n.setup_finish_feature_import, '/transfer'),
      (Icons.query_stats, l10n.setup_finish_feature_statistics, '/stats'),
      (Icons.map, l10n.setup_finish_feature_sites, '/sites'),
      (Icons.build, l10n.setup_finish_feature_gear, '/gear'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.check_circle,
              size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            l10n.setup_finish_title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setup_finish_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          for (final (icon, label, route) in features)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, color: theme.colorScheme.primary),
              title: Text(label),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: _applying ? null : () => _complete(route: route),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _applying ? null : _complete,
            icon: _applying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward),
            label: Text(
              _applying ? l10n.setup_finish_applying : l10n.setup_finish_start,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Replace the placeholder in the shell**

In `setup_wizard_page.dart`, import `finish_step.dart` and change the `SetupStepId.finish` builder to `FinishStep(mode: mode)`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/setup_wizard/`
Expected: all PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/setup_wizard test/features/setup_wizard
git commit -m "feat(setup): finish step applies draft and offers feature links"
```

---

### Task 11: Existing-data path — choice, restore, sync pull, open folder

**Files:**
- Create: `lib/features/setup_wizard/presentation/widgets/steps/existing_choice_step.dart`
- Create: `lib/features/setup_wizard/presentation/widgets/steps/restore_step.dart`
- Create: `lib/features/setup_wizard/presentation/widgets/steps/sync_connect_step.dart`
- Create: `lib/features/setup_wizard/presentation/widgets/steps/open_folder_step.dart`
- Modify: `lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart` (replace remaining placeholders, delete `placeholder_step.dart`, wire fresh-path `onLibraryFound` pivot)
- Test: `test/features/setup_wizard/presentation/widgets/steps/existing_data_steps_test.dart`

**Interfaces:**
- Consumes: `backupOperationProvider` + `RestoreConfirmationDialog` + `RestoreCompletePage` (backup feature); `storageConfigNotifierProvider` (storage_providers.dart); `syncStateProvider`, sync gates (Task 9's set); `realignActiveDiverAfterDataReplace`, `sharedPreferencesProvider`, `hasAnyDiversProvider`; `restartApp` from `package:submersion/main.dart`; `FilePicker` from `package:file_picker/file_picker.dart`; `AppDatabase.currentSchemaVersion`.
- Produces: the four step widgets; shell fully placeholder-free.

- [ ] **Step 1: Write the failing test**

`test/features/setup_wizard/presentation/widgets/steps/existing_data_steps_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/existing_choice_step.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

void main() {
  testWidgets('existing choice cards set the draft source', (tester) async {
    late ProviderContainer container;
    final overrides = await getBaseOverrides();
    var advanced = 0;
    await tester.pumpWidget(testApp(
      overrides: overrides,
      child: Builder(builder: (context) {
        container = ProviderScope.containerOf(context);
        return ExistingChoiceStep(
          mode: SetupWizardMode.firstRun,
          onChosen: () => advanced++,
        );
      }),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bring your data'), findsOneWidget);
    await tester.tap(find.text('Restore a backup file'));
    await tester.pumpAndSettle();

    final draft =
        container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.source, ExistingDataSource.restoreBackup);
    expect(advanced, 1);
  });
}
```

(Restore/sync/folder steps orchestrate platform pickers, dialogs, and app restarts — they get integration coverage via the full-wizard smoke run in Task 14; their pure logic lives in already-tested engines.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/setup_wizard/presentation/widgets/steps/existing_data_steps_test.dart`
Expected: FAIL — `existing_choice_step.dart` does not exist.

- [ ] **Step 3: Implement the four steps**

`lib/features/setup_wizard/presentation/widgets/steps/existing_choice_step.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Chooses which existing-data source to load from.
class ExistingChoiceStep extends ConsumerWidget {
  final SetupWizardMode mode;
  final VoidCallback onChosen;

  const ExistingChoiceStep({
    super.key,
    required this.mode,
    required this.onChosen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(setupWizardProvider(mode).notifier);

    void choose(ExistingDataSource source) {
      notifier.chooseSource(source);
      onChosen();
    }

    Widget card(IconData icon, String title, String subtitle,
        ExistingDataSource source) {
      return Card(
        child: ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => choose(source),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.setup_existing_title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setup_existing_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          card(
            Icons.restore,
            l10n.setup_existing_restore_title,
            l10n.setup_existing_restore_subtitle,
            ExistingDataSource.restoreBackup,
          ),
          card(
            Icons.cloud_sync,
            l10n.setup_existing_sync_title,
            l10n.setup_existing_sync_subtitle,
            ExistingDataSource.cloudSync,
          ),
          card(
            Icons.folder_open,
            l10n.setup_existing_folder_title,
            l10n.setup_existing_folder_subtitle,
            ExistingDataSource.openFolder,
          ),
        ],
      ),
    );
  }
}
```

`lib/features/setup_wizard/presentation/widgets/steps/restore_step.dart`:

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/presentation/pages/restore_complete_page.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/restore_confirmation_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Restores a backup file; exits the wizard via the existing
/// RestoreCompletePage -> restartApp() flow.
class RestoreStep extends ConsumerWidget {
  const RestoreStep({super.key});

  Future<void> _pickAndRestore(BuildContext context, WidgetRef ref) async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(type: FileType.any);
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null || !context.mounted) return;

    final file = File(filePath);
    final record = BackupRecord(
      id: 'setup-wizard',
      filename: result.files.single.name,
      timestamp: await file.lastModified(),
      sizeBytes: await file.length(),
      location: BackupLocation.local,
      diveCount: 0,
      siteCount: 0,
    );
    if (!context.mounted) return;

    final mode = await RestoreConfirmationDialog.show(
      context,
      record,
      currentSchemaVersion: AppDatabase.currentSchemaVersion,
    );
    if (mode != null) {
      await ref
          .read(backupOperationProvider.notifier)
          .restoreFromFilePath(filePath, mode: mode);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final operation = ref.watch(backupOperationProvider);

    ref.listen<BackupOperationState>(backupOperationProvider, (prev, next) {
      if (next.status == BackupOperationStatus.restoreComplete &&
          context.mounted) {
        RestoreCompletePage.show(context);
      }
    });

    final inProgress = operation.status == BackupOperationStatus.inProgress;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.setup_restore_title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            if (inProgress) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(operation.message ?? l10n.setup_restore_inProgress),
            ] else ...[
              if (operation.status == BackupOperationStatus.error &&
                  operation.message != null) ...[
                Text(
                  operation.message!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: () => _pickAndRestore(context, ref),
                icon: const Icon(Icons.folder_open),
                label: Text(l10n.setup_restore_pick),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

Check the actual `BackupRecord` import path/constructor before compiling (`rg -n "class BackupRecord" lib/features/backup`) — mirror `backup_settings_page.dart:208-254`, which is the canonical caller (including the `BackupLocation.local` enum import if it lives in a separate file, and `offerReplace:` which the wizard omits because a fresh install has no cloud provider yet).

`lib/features/setup_wizard/presentation/widgets/steps/sync_connect_step.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/backup_sync_step.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Existing-data path: connect a provider, pull the library, land on the
/// dashboard once data (and its divers) have arrived.
class SyncConnectStep extends ConsumerStatefulWidget {
  final SetupWizardMode mode;

  /// Called when the connected account has no library (pivot to fresh).
  final VoidCallback onNoLibrary;

  const SyncConnectStep({
    super.key,
    required this.mode,
    required this.onNoLibrary,
  });

  @override
  ConsumerState<SyncConnectStep> createState() => _SyncConnectStepState();
}

enum _PullPhase { connect, pulling, done, empty }

class _SyncConnectStepState extends ConsumerState<SyncConnectStep> {
  _PullPhase _phase = _PullPhase.connect;

  Future<void> _startPull() async {
    setState(() => _phase = _PullPhase.pulling);
    final connected = ref
        .read(setupWizardProvider(widget.mode))
        .connectedProvider;
    if (connected == null) {
      setState(() => _phase = _PullPhase.connect);
      return;
    }
    final instance = cloudProviderInstanceFor(connected);
    final peers = await ref
        .read(syncInitializerProvider)
        .peerSyncFiles(instance);
    if (peers.isEmpty) {
      if (mounted) setState(() => _phase = _PullPhase.empty);
      return;
    }
    await ref.read(syncStateProvider.notifier).performSync();
    await realignActiveDiverAfterDataReplace(
      ref.read(sharedPreferencesProvider),
    );
    final hasDivers = await ref.read(hasAnyDiversProvider.future);
    if (mounted) {
      setState(() => _phase = hasDivers ? _PullPhase.done : _PullPhase.empty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final syncState = ref.watch(syncStateProvider);

    switch (_phase) {
      case _PullPhase.connect:
        // Reuse the provider cards; a successful connect starts the pull.
        return Column(
          children: [
            Expanded(
              child: BackupSyncStep(mode: widget.mode),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _ConnectedGate(
                  mode: widget.mode,
                  onContinue: _startPull,
                ),
              ),
            ),
          ],
        );
      case _PullPhase.pulling:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(value: syncState.progress),
              const SizedBox(height: 12),
              Text(syncState.message ?? l10n.setup_syncPull_syncing),
            ],
          ),
        );
      case _PullPhase.done:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(l10n.setup_syncPull_success,
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/dashboard'),
                child: Text(l10n.setup_syncPull_continue),
              ),
            ],
          ),
        );
      case _PullPhase.empty:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.setup_syncPull_noLibrary_title,
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  l10n.setup_syncPull_noLibrary_message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.onNoLibrary,
                  child: Text(l10n.setup_sync_libraryFound_keepFresh),
                ),
              ],
            ),
          ),
        );
    }
  }
}

/// Continue button enabled once a provider is connected in the draft.
class _ConnectedGate extends ConsumerWidget {
  final SetupWizardMode mode;
  final VoidCallback onContinue;

  const _ConnectedGate({required this.mode, required this.onContinue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(
      setupWizardProvider(mode).select((d) => d.connectedProvider != null),
    );
    return FilledButton(
      onPressed: connected ? onContinue : null,
      child: Text(context.l10n.setup_syncPull_continue),
    );
  }
}
```

Add the l10n key `setup_syncPull_continue` ("Continue") to Task 2's key set if not already present — it IS present in the list as `setup_syncPull_continue`? If missing, add it to all 11 arb files in this task and regenerate. (Check: Task 2 defines `setup_syncPull_*` keys; `setup_syncPull_continue` must exist — add "setup_syncPull_continue": "Continue" if the Task 2 block lacks it.)

`lib/features/setup_wizard/presentation/widgets/steps/open_folder_step.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/main.dart' show restartApp;

/// Points the app at a folder that already contains a Submersion database.
class OpenFolderStep extends ConsumerStatefulWidget {
  const OpenFolderStep({super.key});

  @override
  ConsumerState<OpenFolderStep> createState() => _OpenFolderStepState();
}

class _OpenFolderStepState extends ConsumerState<OpenFolderStep> {
  bool _busy = false;
  String? _error;

  Future<void> _pickFolder() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = context.l10n;
    try {
      final notifier = ref.read(storageConfigNotifierProvider.notifier);
      final picked = await notifier.pickCustomFolder();
      if (picked == null) return;

      final existing = await notifier.checkForExistingDatabase(picked.path);
      if (existing == null) {
        setState(() => _error = l10n.setup_folder_notFound_message);
        return;
      }

      final result = await notifier.switchToExistingDatabase(picked.path);
      if (result.success) {
        // Full provider rebuild: the swapped database has divers, so the
        // relaunch lands on the dashboard.
        restartApp();
      } else {
        setState(() => _error = result.error ?? '');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.setup_folder_title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            if (_busy) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.setup_folder_switching),
            ] else ...[
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _pickFolder,
                icon: const Icon(Icons.folder_open),
                label: Text(l10n.setup_folder_pick),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

Verify `MigrationResult`'s error field name (`rg -n "class MigrationResult" -A 8 lib/core/services/database_migration_service.dart`) — use its actual field (e.g. `result.error` vs `result.message`). Verify `StorageConfigNotifier.pickCustomFolder`'s required params — `storage_settings_page.dart` passes `chooser: _chooseStorageVolume`; if `chooser` is required, port that page's `_chooseStorageVolume` dialog into this step as a private method (Android external-volume selection).

- [ ] **Step 4: Wire the shell**

In `setup_wizard_page.dart`:
1. Import the four new step files; delete `placeholder_step.dart` and its import.
2. `SetupStepId.existingChoice` builder → `ExistingChoiceStep(mode: mode, onChosen: () => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _advance(); }))` (reuse `_chooseAndAdvance` by passing `() {}` as the mutation — the step already mutates; simplest is `onChosen: () => _chooseAndAdvance(() {})`).
3. `SetupStepId.restore` builder → `const RestoreStep()`.
4. `SetupStepId.syncConnect` builder → `SyncConnectStep(mode: mode, onNoLibrary: () { ref.read(setupWizardProvider(mode).notifier).choosePath(SetupPath.fresh); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _animateTo(1); }); })` — pivoting to the fresh path re-enters at the profile step (index 1 of the fresh list) with the provider still connected in the draft.
5. `SetupStepId.openFolder` builder → `const OpenFolderStep()`.
6. `SetupStepId.backupSync` builder gains the fresh-path pivot: `BackupSyncStep(mode: mode, onLibraryFound: () => _offerAdoptPivot())` where `_offerAdoptPivot` shows an AlertDialog (`setup_sync_libraryFound_title` / `_message`, actions `setup_sync_libraryFound_keepFresh` → pop, `setup_sync_libraryFound_adopt` → pop then `notifier.choosePath(SetupPath.existingData); notifier.chooseSource(ExistingDataSource.cloudSync);` and post-frame `_animateTo(computeSteps(...).length - 1)` to land on the sync-pull step).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/setup_wizard/`
Expected: all PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/setup_wizard test/features/setup_wizard
git commit -m "feat(setup): existing-data path with restore, sync pull, and folder adopt"
```

---

### Task 12: Router swap, Settings entry, delete WelcomePage

**Files:**
- Modify: `lib/core/router/app_router.dart` (welcome builder swap at ~line 172; new settings child route; imports at lines 18/77-100)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (Setup assistant tile in the Manage section, after the tank-presets tile at ~line 1640)
- Delete: `lib/features/onboarding/presentation/pages/welcome_page.dart` (and the now-empty `lib/features/onboarding/` tree)
- Modify: all 11 `lib/l10n/arb/app_*.arb` (remove the 10 `onboarding_welcome_*` keys + the one `@onboarding_welcome_errorCreatingProfile` metadata block from each) + regenerate
- Test: `test/features/setup_wizard/presentation/pages/first_run_redirect_test.dart`

**Interfaces:**
- Consumes: `SetupWizardPage` (Task 6), `hasAnyDiversProvider`.
- Produces: `/welcome` renders the wizard; `/settings/setup-assistant` (name `setupAssistant`) renders re-entry mode; Settings Manage card gains the launcher tile.

- [ ] **Step 1: Write the failing redirect test**

`test/features/setup_wizard/presentation/pages/first_run_redirect_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/pages/setup_wizard_page.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('zero divers redirects initial route to the setup wizard',
      (tester) async {
    final overrides = await getBaseOverrides();
    final container = ProviderContainer(overrides: [
      ...overrides,
      hasAnyDiversProvider.overrideWith((ref) async => false),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: testAppRouter(router: router),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(SetupWizardPage), findsOneWidget);
    expect(find.text('Welcome to Submersion'), findsOneWidget);
  });
}
```

Adjust `testAppRouter` usage if it wraps its own ProviderScope (it does — see helper): in that case skip `UncontrolledProviderScope` and instead pass the overrides list directly to `testAppRouter(router: ..., overrides: [...])`, reading the router from a container built with the SAME overrides is not possible then — so mirror `test/core/router/app_router_test.dart`'s established pattern for constructing the router with overrides, which that file already solves; copy its approach exactly.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/setup_wizard/presentation/pages/first_run_redirect_test.dart`
Expected: FAIL — `/welcome` still builds the old `WelcomePage`, so `find.byType(SetupWizardPage)` finds nothing.

- [ ] **Step 3: Swap the router**

In `lib/core/router/app_router.dart`:

1. Replace the import at line 18:
```dart
// OLD
import 'package:submersion/features/onboarding/presentation/pages/welcome_page.dart';
// NEW
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/pages/setup_wizard_page.dart';
```
2. Replace the `/welcome` builder:
```dart
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) =>
            const SetupWizardPage(mode: SetupWizardMode.firstRun),
      ),
```
3. Inside the `/settings` route's `routes: [...]` list (after the `backup` child at ~line 892), add:
```dart
              GoRoute(
                path: 'setup-assistant',
                name: 'setupAssistant',
                builder: (context, state) =>
                    const SetupWizardPage(mode: SetupWizardMode.settings),
              ),
```

- [ ] **Step 4: Add the Settings tile and delete the old page**

In `settings_page.dart`, inside the Manage section's `Card > Column` (after the tank-presets `ListTile` + `Divider`), add:

```dart
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.auto_fix_high),
                  title: Text(context.l10n.settings_manage_setupAssistant),
                  subtitle: Text(
                    context.l10n.settings_manage_setupAssistant_subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/setup-assistant'),
                ),
```

Then:
```bash
git rm lib/features/onboarding/presentation/pages/welcome_page.dart
```
Confirm nothing references it: `rg -n "WelcomePage|onboarding/presentation" lib test` → expected: no matches.

- [ ] **Step 5: Remove the orphaned l10n keys**

In each of the 11 `lib/l10n/arb/app_*.arb` files, delete the 10 `onboarding_welcome_*` entries and the `@onboarding_welcome_errorCreatingProfile` metadata block. Run `flutter gen-l10n`. Then `rg -n "onboarding_welcome" lib` → expected: no matches.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/setup_wizard/ test/core/router/`
Expected: all PASS (including the pre-existing router config tests, which override `hasAnyDiversProvider` to true and never touched WelcomePage).

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/core/router lib/features/settings lib/l10n test/features/setup_wizard
git rm -q lib/features/onboarding/presentation/pages/welcome_page.dart 2>/dev/null || true
git commit -m "feat(setup): route first run and settings entry to the setup wizard"
```

---

### Task 13: Documentation updates

**Files:**
- Modify: `docs/developer/navigation.md` (First-Run Guard section ~L395-407 + Onboarding route entry ~L329-334: `/welcome` now renders SetupWizardPage; add `/settings/setup-assistant`)
- Modify: `docs/ARCHITECTURE.md` (~L240) and `docs/developer/architecture.md` (~L160): replace `onboarding/ — First-run experience` with `setup_wizard/ — First-run setup wizard and Settings re-entry`
- Modify: `docs/guide/README.md` (~L33) and `docs/guide/first-dive.md` (~L7-10): describe the new first-run flow (fork; fresh path name/units/appearance/backup-sync/finish; existing-data restore/sync/folder options; everything skippable)
- Modify: `FEATURE_ROADMAP.md`: add a completed entry under the appropriate release section: `- [x] Setup wizard for new databases (units, appearance, backup/sync, restore/adopt paths) — discussion #523`

**Interfaces:** none (prose only).

- [ ] **Step 1: Apply the edits above**

Keep each doc's existing voice and formatting; update code samples in navigation.md that show the redirect (the redirect logic itself is unchanged — only the page it lands on). Do not document placeholder internals; describe user-visible behavior.

- [ ] **Step 2: Verify no stale references**

Run: `rg -n "WelcomePage|name-only|onboarding/" docs FEATURE_ROADMAP.md | rg -v "setup_wizard|setup wizard"`
Expected: no hits describing the old flow as current (historical spec/plan docs under docs/superpowers/ are exempt — leave them).

- [ ] **Step 3: Commit**

```bash
git add docs FEATURE_ROADMAP.md
git commit -m "docs: describe the setup wizard first-run flow"
```

---

### Task 14: Full verification sweep

**Files:** none new (fixes only, if the sweep finds issues).

- [ ] **Step 1: Format check**

Run: `dart format .`
Expected: `0 changed` (any change means a prior task missed formatting — commit the fix).

- [ ] **Step 2: Whole-project analyze**

Run: `flutter analyze`
Expected: `No issues found!` — run WITHOUT piping through head/tail (piping masks failures). Fix anything reported.

- [ ] **Step 3: Targeted test sweep (never the whole suite)**

Run, in order:
```bash
flutter test test/features/setup_wizard/
flutter test test/features/import_wizard/
flutter test test/core/router/
flutter test test/features/settings/presentation/pages/settings_page_test.dart
flutter test test/features/settings/presentation/providers/settings_notifier_real_test.dart
flutter test test/features/divers/
flutter test test/features/backup/
```
Expected: all PASS. The settings/backup/divers suites guard the engines the wizard now calls.

- [ ] **Step 4: Desktop smoke run (manual, macOS)**

Run: `flutter run -d macos`
Walk: fresh sandbox DB (or use the wizard from Settings → Manage → Setup assistant): fork renders → fresh path → name → units (imperial toggle) → appearance (dark + language preview) → backup toggle → finish → dashboard; confirm Settings → Units shows the chosen units. This validates the layout-bounds note in Task 6 on a real window. Report results; do not mark the task complete on test output alone.

- [ ] **Step 5: Final commit (if fixes were made)**

```bash
git add -u
git commit -m "chore: verification fixes for setup wizard"
```






# Startup Migration Progress Indicator

**Issue:** [#186](https://github.com/submersion-app/submersion/issues/186)
**Date:** 2026-04-08

## Problem

When a database migration occurs at startup, the app shows nothing while the
migration runs. The user sees a blank/frozen screen and may force-quit the app,
potentially corrupting the database mid-migration.

## Solution

Restructure the app startup so `runApp()` is called immediately with a
`StartupWrapper` widget. The widget shows a branded splash screen on every
launch and displays a determinate progress bar when a database migration is
detected.

## Startup Flow

### Current

```
main() -> SharedPreferences -> LocationService -> DB init (BLOCKS) -> runApp()
```

### Proposed

```
main() -> SharedPreferences -> LocationService -> runApp(StartupWrapper)
  -> shows splash immediately
  -> kicks off async init (DB, LocalCache, Notifications, Background, TileCache, Species)
  -> if migration detected: shows progress bar with step count
  -> on success: crossfade transition to SubmersionRestart (normal app)
  -> on error: shows error screen with message + close button
```

Pre-database setup (SharedPreferences, LocationService, bookmark resolution,
file access checks) remains synchronous in `main()` because these operations
are fast and require no progress feedback. Only the database initialization and
subsequent services are deferred to the widget lifecycle.

## Migration Progress Reporting

### Data model

An immutable `MigrationProgress` class:

- `currentStep` (int) -- which migration step just completed
- `totalSteps` (int) -- total steps that will execute for this upgrade

### Step counting

The migration strategy uses sequential `if (from < N)` blocks (versions 2-62,
skipping 44). A static `const List<int> migrationVersions` in `AppDatabase`
lists every version that has a migration block. When adding a new migration,
the developer must append the new version number to this list and add the
corresponding progress callback call after the migration block.

To calculate total steps: count entries in `migrationVersions` that are greater
than the user's stored schema version. After each block completes, the callback
fires with an incremented `currentStep`.

Example: upgrading from v55 to v62 fires thresholds 56, 57, 58, 59, 60, 61, 62
= 7 total steps. Progress reports: 1/7, 2/7, ... 7/7.

### Callback mechanism

- `AppDatabase` receives an optional `void Function(int currentStep, int totalSteps)?`
  parameter named `onMigrationProgress`, stored as an instance field
- Called from within `onUpgrade` after each migration block completes
- `DatabaseService.initialize()` accepts the same callback and passes it through
  to the `AppDatabase` constructor

### Version pre-check

`DatabaseService` exposes a `getStoredSchemaVersion(String dbPath)` method that
reads `PRAGMA user_version` via raw sqlite3 (reusing logic from the existing
`_assertSchemaVersionCompatible`). This lets `StartupWrapper` determine upfront
whether a migration is needed and how many steps to expect.

## Splash and Progress UI

### New file

`lib/core/presentation/pages/startup_page.dart`

### Widget: StartupWrapper

A `StatefulWidget` (not ConsumerWidget -- Riverpod is not available at this
stage) that manages a 4-state lifecycle:

| State          | UI                                                                   |
| -------------- | -------------------------------------------------------------------- |
| `initializing` | App icon centered, "Submersion" text below -- brief splash           |
| `migrating`    | Same layout + progress bar and "Upgrading database... step N of M"   |
| `ready`        | Crossfade transition (~300ms) to the normal app (SubmersionRestart)  |
| `error`        | Error icon, failure message, and "Close" button to exit the app      |

### Visual layout

```
        [App Icon - assets/icon/icon.png]
              "Submersion"

    -- only visible during migrating state: --
        [LinearProgressIndicator]
     "Upgrading database... step 3 of 7"
```

- Icon and app name are vertically centered in all states
- Progress section slides/fades in below the app name using `AnimatedSize` or
  `AnimatedSwitcher` when migration begins
- `LinearProgressIndicator` uses `value: currentStep / totalSteps` (determinate)
- On completion, the splash crossfades to the normal app

### Minimum splash duration

On non-migration startups, enforce a minimum ~1 second display using
`Future.wait` of both the actual initialization and
`Future.delayed(Duration(seconds: 1))`. This prevents a jarring flash.

### Theming

The splash renders before the user's theme preference is loaded. Use
`MediaQuery.platformBrightnessOf(context)` to match the system light/dark
setting. Styling is minimal: background color, icon, and text only.

## Error Handling

### Migration failure

On any initialization error (including migration failure):

- Display error icon, "Database upgrade failed" heading, error message text
- "Close" button calls `SystemNavigator.pop()` (mobile) or `exit(0)` (desktop)
- On next launch, Drift resumes migration from the last successful version step

### Version mismatch

The existing `DatabaseVersionMismatchException` handling moves into the
`StartupWrapper` error state with its specific "Update Required" messaging
(schema vN vs app vM). This consolidates all startup error display into one
place.

## Testing Strategy

### Unit tests

1. **MigrationProgress** -- verify currentStep/totalSteps fraction, edge cases
2. **Step counting** -- given a `from` version, verify correct totalSteps from
   `migrationVersions` list. Cases: fresh install (0 steps via onCreate),
   one version behind (1 step), many versions behind (correct count, skipping v44)
3. **getStoredSchemaVersion()** -- test with real sqlite3 file: new DB returns
   null, existing DB returns correct version

### Widget tests

4. **StartupPage states** -- verify each state renders correctly: initializing
   shows icon + name (no progress bar), migrating shows progress bar with step
   text, error shows message + close button, ready renders child app widget
5. **Progress updates** -- verify progress callback updates displayed step count
   and progress bar value

### Not tested

- Actual migration SQL (covered by existing migration tests)
- Crossfade animation timing (visual polish)
- Platform exit calls (untestable platform APIs)

## Files Changed

| File                                                | Change     |
| --------------------------------------------------- | ---------- |
| `lib/main.dart`                                     | Modified   |
| `lib/core/services/database_service.dart`           | Modified   |
| `lib/core/database/database.dart`                   | Modified   |
| `lib/core/presentation/pages/startup_page.dart`     | New        |
| `lib/core/domain/entities/migration_progress.dart`  | New        |
| `test/core/presentation/pages/startup_page_test.dart`   | New    |
| `test/core/services/database_service_test.dart`     | Modified   |
| `test/core/database/migration_progress_test.dart`   | New        |

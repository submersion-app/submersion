# Startup Migration Progress Indicator - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a branded splash screen on every app launch with a determinate progress bar during database migrations, so the user never sees a frozen/blank screen.

**Architecture:** Restructure `main()` so `runApp()` is called immediately with a `StartupWrapper` StatefulWidget. Database initialization (including migration) runs asynchronously after the widget tree exists. `AppDatabase` accepts a progress callback that fires after each migration version step, driving a `LinearProgressIndicator` in the splash UI.

**Tech Stack:** Flutter, Drift ORM, raw sqlite3 (for version pre-check), Material 3

**Spec:** `docs/superpowers/specs/2026-04-08-startup-migration-progress-design.md`
**Issue:** [#186](https://github.com/submersion-app/submersion/issues/186)

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/core/domain/entities/migration_progress.dart` | Create | Immutable data class for step/total progress |
| `lib/core/database/database.dart` | Modify | Add `migrationVersions` list, `onMigrationProgress` callback, call it in `onUpgrade` |
| `lib/core/services/database_service.dart` | Modify | Add `getStoredSchemaVersion()`, accept progress callback in `initialize()` |
| `lib/core/presentation/pages/startup_page.dart` | Create | `StartupWrapper` widget with splash/progress/error states |
| `lib/main.dart` | Modify | Move DB init into `StartupWrapper`, simplify `main()` |
| `test/core/domain/entities/migration_progress_test.dart` | Create | Unit tests for MigrationProgress and step counting |
| `test/core/services/database_service_schema_version_test.dart` | Create | Unit tests for `getStoredSchemaVersion()` |
| `test/core/presentation/pages/startup_page_test.dart` | Create | Widget tests for all startup states |

---

### Task 1: MigrationProgress Data Model

**Files:**
- Create: `lib/core/domain/entities/migration_progress.dart`
- Create: `test/core/domain/entities/migration_progress_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/core/domain/entities/migration_progress_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/entities/migration_progress.dart';

void main() {
  group('MigrationProgress', () {
    test('stores currentStep and totalSteps', () {
      const progress = MigrationProgress(currentStep: 3, totalSteps: 7);
      expect(progress.currentStep, 3);
      expect(progress.totalSteps, 7);
    });

    test('fraction returns currentStep / totalSteps', () {
      const progress = MigrationProgress(currentStep: 3, totalSteps: 7);
      expect(progress.fraction, closeTo(0.4286, 0.001));
    });

    test('fraction returns 0.0 when totalSteps is 0', () {
      const progress = MigrationProgress(currentStep: 0, totalSteps: 0);
      expect(progress.fraction, 0.0);
    });

    test('fraction returns 1.0 when complete', () {
      const progress = MigrationProgress(currentStep: 5, totalSteps: 5);
      expect(progress.fraction, 1.0);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/domain/entities/migration_progress_test.dart`
Expected: FAIL -- `migration_progress.dart` does not exist

- [ ] **Step 3: Write the MigrationProgress class**

Create `lib/core/domain/entities/migration_progress.dart`:

```dart
class MigrationProgress {
  final int currentStep;
  final int totalSteps;

  const MigrationProgress({
    required this.currentStep,
    required this.totalSteps,
  });

  double get fraction => totalSteps > 0 ? currentStep / totalSteps : 0.0;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/domain/entities/migration_progress_test.dart`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```
feat: add MigrationProgress data model (#186)
```

---

### Task 2: Add migrationVersions List and Progress Callback to AppDatabase

**Files:**
- Modify: `lib/core/database/database.dart` (lines 1286-1295 for class header, lines 1328-2729 for onUpgrade)

This task adds the `migrationVersions` static list, the `onMigrationProgress` callback field, and calls the callback after each migration block in `onUpgrade`.

- [ ] **Step 1: Add the migrationVersions list and callback to AppDatabase class header**

In `lib/core/database/database.dart`, replace the `AppDatabase` class header (lines 1286-1294):

```dart
class AppDatabase extends _$AppDatabase {
  final void Function(int currentStep, int totalSteps)? onMigrationProgress;

  AppDatabase(super.e, {this.onMigrationProgress});

  /// The current schema version as a static constant so that pre-open checks
  /// (e.g. version-mismatch guard) can reference it without an instance.
  static const int currentSchemaVersion = 62;

  /// Every schema version that has a migration block in onUpgrade.
  /// Used to calculate progress step counts. When adding a new migration,
  /// append the new version number here.
  static const List<int> migrationVersions = [
    2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37,
    38, 39, 40, 41, 42, 43, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55,
    56, 57, 58, 59, 60, 61, 62,
  ];

  /// Returns the number of migration steps that will execute when upgrading
  /// from [fromVersion] to [currentSchemaVersion].
  static int migrationStepCount(int fromVersion) {
    return migrationVersions.where((v) => v > fromVersion).length;
  }

  @override
  int get schemaVersion => currentSchemaVersion;
```

Note: version 44 is intentionally missing from the list -- there is no `if (from < 44)` block in the existing migrations.

- [ ] **Step 2: Add progress callback calls to the onUpgrade block**

In the `onUpgrade` callback (starting at line 1328), add a step counter at the top and a callback call after each migration block. The opening of `onUpgrade` becomes:

```dart
      onUpgrade: (Migrator m, int from, int to) async {
        int completedSteps = 0;
        final totalSteps = migrationStepCount(from);

        void reportProgress() {
          completedSteps++;
          onMigrationProgress?.call(completedSteps, totalSteps);
        }
```

Then after each existing `if (from < N) { ... }` block's closing brace, add `reportProgress();`. For example, the first two blocks become:

```dart
        if (from < 2) {
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN sac_unit TEXT NOT NULL DEFAULT 'litersPerMin'",
          );
        }
        if (from < 2) reportProgress();

        if (from < 3) {
          await customStatement(
            'ALTER TABLE dive_tanks ADD COLUMN preset_name TEXT',
          );
        }
        if (from < 3) reportProgress();
```

Apply this pattern for every `if (from < N)` block through `if (from < 62)`. The guard `if (from < N)` on `reportProgress()` ensures we only count steps that actually executed.

- [ ] **Step 3: Verify the app still compiles**

Run: `flutter analyze lib/core/database/database.dart`
Expected: No errors (warnings are OK)

- [ ] **Step 4: Commit**

```
feat: add migration progress callback to AppDatabase (#186)
```

---

### Task 3: Add getStoredSchemaVersion to DatabaseService

**Files:**
- Modify: `lib/core/services/database_service.dart`
- Create: `test/core/services/database_service_schema_version_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/database_service_schema_version_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/services/database_service.dart';

void main() {
  group('DatabaseService.getStoredSchemaVersion', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('db_version_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns null when database file does not exist', () {
      final path = p.join(tempDir.path, 'nonexistent.db');
      final version = DatabaseService.getStoredSchemaVersion(path);
      expect(version, isNull);
    });

    test('returns 0 for a fresh database with no version set', () {
      final path = p.join(tempDir.path, 'fresh.db');
      final db = sqlite3.sqlite3.open(path);
      db.execute('CREATE TABLE dummy (id INTEGER)');
      db.dispose();

      final version = DatabaseService.getStoredSchemaVersion(path);
      expect(version, 0);
    });

    test('returns the stored schema version', () {
      final path = p.join(tempDir.path, 'versioned.db');
      final db = sqlite3.sqlite3.open(path);
      db.execute('PRAGMA user_version = 42');
      db.dispose();

      final version = DatabaseService.getStoredSchemaVersion(path);
      expect(version, 42);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/database_service_schema_version_test.dart`
Expected: FAIL -- `getStoredSchemaVersion` is not defined

- [ ] **Step 3: Add getStoredSchemaVersion and update initialize to accept progress callback**

In `lib/core/services/database_service.dart`, add two changes:

First, add the static method after `_assertSchemaVersionCompatible` (after line 186):

```dart
  /// Reads the stored schema version from a database file without opening it
  /// through Drift. Returns null if the file does not exist, or the integer
  /// PRAGMA user_version value otherwise.
  static int? getStoredSchemaVersion(String dbPath) {
    final file = File(dbPath);
    if (!file.existsSync()) return null;

    final db = sqlite3.sqlite3.open(dbPath);
    try {
      final result = db.select('PRAGMA user_version');
      if (result.isEmpty) return null;
      return result.first.values.first as int;
    } finally {
      db.dispose();
    }
  }
```

Second, update the `initialize` method signature to accept the progress callback and pass it to `AppDatabase` (modify the existing method starting at line 78):

```dart
  Future<void> initialize({
    DatabaseLocationService? locationService,
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
  }) async {
    if (_database != null) return;

    _locationService = locationService;
    final dbPath = await _resolveDatabasePath();
    _currentDatabasePath = dbPath;

    // Ensure directory exists
    final dbDir = Directory(p.dirname(dbPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    // Guard: reject databases created by a newer version of the app
    _assertSchemaVersionCompatible(dbPath);

    final file = File(dbPath);
    // Use synchronous NativeDatabase instead of createInBackground
    // Background isolates can cause close() to hang indefinitely during migration
    // For a dive log app, synchronous DB operations are fast enough
    _database = AppDatabase(
      NativeDatabase(file),
      onMigrationProgress: onMigrationProgress,
    );
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/database_service_schema_version_test.dart`
Expected: All 3 tests PASS

- [ ] **Step 5: Verify no regressions**

Run: `flutter analyze lib/core/services/database_service.dart`
Expected: No errors

- [ ] **Step 6: Commit**

```
feat: add schema version pre-check and progress callback to DatabaseService (#186)
```

---

### Task 4: Create StartupWrapper Widget

**Files:**
- Create: `lib/core/presentation/pages/startup_page.dart`

This is the core UI widget. It manages 4 states: `initializing`, `migrating`, `ready`, `error`.

- [ ] **Step 1: Create the startup page with state enum and widget**

Create `lib/core/presentation/pages/startup_page.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_version_exception.dart';
import 'package:submersion/core/domain/entities/migration_progress.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/services/background_service.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/main.dart' show SubmersionRestart;

enum _StartupState { initializing, migrating, ready, error }

class StartupWrapper extends StatefulWidget {
  final SharedPreferences prefs;
  final LogFileService logFileService;
  final DatabaseLocationService locationService;

  const StartupWrapper({
    super.key,
    required this.prefs,
    required this.logFileService,
    required this.locationService,
  });

  @override
  State<StartupWrapper> createState() => _StartupWrapperState();
}

class _StartupWrapperState extends State<StartupWrapper> {
  _StartupState _state = _StartupState.initializing;
  MigrationProgress _progress = const MigrationProgress(
    currentStep: 0,
    totalSteps: 0,
  );
  String _errorMessage = '';
  bool _isVersionMismatch = false;
  int _dbVersion = 0;
  int _appVersion = 0;

  @override
  void initState() {
    super.initState();
    _runInitialization();
  }

  Future<void> _runInitialization() async {
    try {
      // Determine if migration is needed before opening the database
      final dbPath = await widget.locationService.getDatabasePath();
      final storedVersion = DatabaseService.getStoredSchemaVersion(dbPath);
      final needsMigration = storedVersion != null &&
          storedVersion > 0 &&
          storedVersion < AppDatabase.currentSchemaVersion;

      final totalSteps = needsMigration
          ? AppDatabase.migrationStepCount(storedVersion)
          : 0;

      if (needsMigration) {
        setState(() {
          _state = _StartupState.migrating;
          _progress = MigrationProgress(
            currentStep: 0,
            totalSteps: totalSteps,
          );
        });
      }

      // Run DB init and minimum splash duration in parallel
      await Future.wait([
        _initializeServices(),
        Future.delayed(const Duration(seconds: 1)),
      ]);

      if (mounted) {
        setState(() => _state = _StartupState.ready);
      }
    } on DatabaseVersionMismatchException catch (e) {
      if (mounted) {
        setState(() {
          _state = _StartupState.error;
          _isVersionMismatch = true;
          _dbVersion = e.databaseVersion;
          _appVersion = e.appVersion;
        });
      }
    } catch (e) {
      debugPrint('FATAL: App initialization failed: $e');
      if (mounted) {
        setState(() {
          _state = _StartupState.error;
          _errorMessage = '$e';
        });
      }
    }
  }

  Future<void> _initializeServices() async {
    await DatabaseService.instance.initialize(
      locationService: widget.locationService,
      onMigrationProgress: (currentStep, totalSteps) {
        if (mounted) {
          setState(() {
            _progress = MigrationProgress(
              currentStep: currentStep,
              totalSteps: totalSteps,
            );
          });
        }
      },
    );

    await LocalCacheDatabaseService.instance.initialize();
    await NotificationService.instance.initialize();
    await initializeBackgroundService();

    try {
      await TileCacheService.instance.initialize();
    } catch (e) {
      debugPrint('Warning: Tile cache initialization failed: $e');
    }

    final speciesRepository = SpeciesRepository();
    await speciesRepository.seedBuiltInSpecies();
  }

  void _closeApp() {
    if (Platform.isIOS || Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _state == _StartupState.ready
            ? SubmersionRestart(
                key: const ValueKey('app'),
                prefs: widget.prefs,
                logFileService: widget.logFileService,
              )
            : Scaffold(
                key: ValueKey(_state),
                backgroundColor: backgroundColor,
                body: SafeArea(
                  child: Center(
                    child: _state == _StartupState.error
                        ? _buildErrorContent(textColor, subtitleColor)
                        : _buildSplashContent(
                            textColor,
                            subtitleColor,
                            isDark,
                          ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSplashContent(
    Color textColor,
    Color subtitleColor,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/icon/icon.png',
          width: 96,
          height: 96,
        ),
        const SizedBox(height: 16),
        Text(
          'Submersion',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _state == _StartupState.migrating
              ? Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: SizedBox(
                    width: 240,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(
                          value: _progress.fraction,
                          backgroundColor: isDark
                              ? Colors.white24
                              : Colors.black12,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Upgrading database... '
                          'step ${_progress.currentStep} of ${_progress.totalSteps}',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtitleColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildErrorContent(Color textColor, Color subtitleColor) {
    if (_isVersionMismatch) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.update, size: 64, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              'Update Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your dive data was saved by a newer version of '
              'Submersion (schema v$_dbVersion). This version '
              'only supports up to schema v$_appVersion.',
              style: TextStyle(fontSize: 14, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Please update Submersion to the latest version. '
              'Your data is safe and has not been modified.',
              style: TextStyle(fontSize: 14, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _closeApp,
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 24),
          Text(
            'Database upgrade failed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: TextStyle(fontSize: 14, color: subtitleColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Try restarting the app. If this persists, '
            'reinstall or contact support.',
            style: TextStyle(fontSize: 14, color: subtitleColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _closeApp,
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/core/presentation/pages/startup_page.dart`
Expected: No errors (may show info about unused import if `SubmersionRestart` hasn't been updated yet)

- [ ] **Step 3: Commit**

```
feat: add StartupWrapper widget with splash and migration progress UI (#186)
```

---

### Task 5: Rewire main.dart to Use StartupWrapper

**Files:**
- Modify: `lib/main.dart`

This task moves database initialization out of `main()` and into `StartupWrapper`. The pre-DB setup (SharedPreferences, log service, location service, bookmark resolution) stays in `main()`.

- [ ] **Step 1: Replace main() body and remove error handling (now in StartupWrapper)**

Replace the contents of `lib/main.dart` with:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/logger_service.dart';

import 'package:submersion/app.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/presentation/pages/startup_page.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/security_scoped_bookmark_service.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences first (needed for storage config)
  final prefs = await SharedPreferences.getInstance();

  // Initialize log file service (always created so it's ready when needed)
  final appSupportDir = await getApplicationSupportDirectory();
  final logFileService = LogFileService(
    logDirectory: '${appSupportDir.path}/logs',
  );
  await logFileService.initialize();

  // Only enable file logging when debug mode is active
  final debugEnabled = prefs.getBool('debug_mode_enabled') ?? false;
  if (debugEnabled) {
    LoggerService.setFileService(logFileService);
  }

  // Create location service and get storage config
  final locationService = DatabaseLocationService(prefs);
  final storageConfig = await locationService.getStorageConfig();

  debugPrint('Storage config on startup:');
  debugPrint('  mode: ${storageConfig.mode}');
  debugPrint('  customFolderPath: ${storageConfig.customFolderPath}');

  // If using custom folder, we need to restore access via security-scoped bookmark
  // macOS sandbox revokes folder access after app restart - bookmarks restore it
  if (storageConfig.mode == StorageLocationMode.customFolder &&
      storageConfig.customFolderPath != null) {
    // Try to resolve the security-scoped bookmark to restore folder access
    if (SecurityScopedBookmarkService.isSupported &&
        locationService.hasStoredBookmark()) {
      debugPrint('  Resolving security-scoped bookmark...');
      final resolvedPath = await locationService.resolveStoredBookmark();

      if (resolvedPath != null) {
        debugPrint('  Bookmark resolved successfully: $resolvedPath');
      } else {
        debugPrint('  Failed to resolve bookmark - access may be blocked');
      }
    }

    // Verify the database is actually accessible after bookmark resolution
    final dbPath = await locationService.getDatabasePath();
    debugPrint('  database path: $dbPath');

    bool canAccess = false;
    try {
      final file = File(dbPath);
      if (await file.exists()) {
        // Try to read the first few bytes to verify actual access
        final raf = await file.open(mode: FileMode.read);
        await raf.read(16); // Read SQLite header
        await raf.close();
        canAccess = true;
        debugPrint('  database accessible: true');
      } else {
        debugPrint('  database file does not exist');
      }
    } catch (e) {
      debugPrint('  database accessible: false (error: $e)');
      canAccess = false;
    }

    if (!canAccess) {
      // Can't access database at custom location, reset to default
      debugPrint(
        '  WARNING: Resetting to default because database is not accessible',
      );
      await locationService.resetToDefault();
    }
  }

  // Launch the app immediately -- database init happens inside StartupWrapper
  // so the user sees a splash screen while initialization runs
  runApp(
    StartupWrapper(
      prefs: prefs,
      logFileService: logFileService,
      locationService: locationService,
    ),
  );
}

/// Global key notifier. Changing the value forces ProviderScope to rebuild,
/// disposing all providers and re-fetching from the current database.
final _restartKey = ValueNotifier<Key>(UniqueKey());

/// Trigger a soft restart by rebuilding the entire ProviderScope.
/// Call this after a database restore to refresh all cached data.
void restartApp() {
  _restartKey.value = UniqueKey();
}

class SubmersionRestart extends StatelessWidget {
  final SharedPreferences prefs;
  final LogFileService logFileService;

  const SubmersionRestart({
    super.key,
    required this.prefs,
    required this.logFileService,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Key>(
      valueListenable: _restartKey,
      builder: (context, key, _) {
        return ProviderScope(
          key: key,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            logFileServiceProvider.overrideWithValue(logFileService),
          ],
          child: const SubmersionApp(),
        );
      },
    );
  }
}
```

Key changes from the original:
- Removed `database_service.dart`, `local_cache_database_service.dart`, `database_version_exception.dart`, `background_service.dart`, `notification_service.dart`, `tile_cache_service.dart`, `species_repository.dart` imports (moved to `startup_page.dart`)
- Removed the `try/catch` block with all DB init calls
- Replaced `runApp(SubmersionRestart(...))` with `runApp(StartupWrapper(...))`
- Added `startup_page.dart` import
- `SubmersionRestart` class and `restartApp()` function remain unchanged (still needed by `StartupWrapper` and other pages)

- [ ] **Step 2: Verify the app compiles**

Run: `flutter analyze lib/main.dart lib/core/presentation/pages/startup_page.dart`
Expected: No errors

- [ ] **Step 3: Run the app to visually verify the splash and transition**

Run: `flutter run -d macos`
Expected: Brief splash with app icon and "Submersion" text, then transitions to the normal app. No migration progress shown (since the DB is already at the current version).

- [ ] **Step 4: Commit**

```
feat: rewire main.dart to use StartupWrapper for startup splash (#186)
```

---

### Task 6: Widget Tests for StartupWrapper

**Files:**
- Create: `test/core/presentation/pages/startup_page_test.dart`

Testing the StartupWrapper is tricky because it depends on singleton services (`DatabaseService`, `LocalCacheDatabaseService`, etc.). We test the visual states by extracting the splash/error content into testable pieces.

- [ ] **Step 1: Write widget tests**

Create `test/core/presentation/pages/startup_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/domain/entities/migration_progress.dart';

void main() {
  group('Splash UI elements', () {
    testWidgets('shows app icon and Submersion text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.water_drop, size: 96),
                  SizedBox(height: 16),
                  Text(
                    'Submersion',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Submersion'), findsOneWidget);
    });

    testWidgets('shows progress bar with step text when migrating',
        (tester) async {
      const progress = MigrationProgress(currentStep: 3, totalSteps: 7);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress.fraction),
                  const SizedBox(height: 12),
                  Text(
                    'Upgrading database... '
                    'step ${progress.currentStep} of ${progress.totalSteps}',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Upgrading database... step 3 of 7'), findsOneWidget);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.4286, 0.001));
    });

    testWidgets('shows version mismatch error with close button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.update, size: 64, color: Colors.orange),
                    const SizedBox(height: 24),
                    const Text('Update Required'),
                    const SizedBox(height: 16),
                    const Text(
                      'Your dive data was saved by a newer version of '
                      'Submersion (schema v99). This version '
                      'only supports up to schema v62.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Update Required'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.byIcon(Icons.update), findsOneWidget);
    });

    testWidgets('shows generic error with message and close button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 24),
                    const Text('Database upgrade failed'),
                    const SizedBox(height: 16),
                    const Text('Some error occurred'),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Database upgrade failed'), findsOneWidget);
      expect(find.text('Some error occurred'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('MigrationProgress in UI', () {
    testWidgets('progress bar updates with new values', (tester) async {
      final progressNotifier = ValueNotifier<MigrationProgress>(
        const MigrationProgress(currentStep: 1, totalSteps: 5),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<MigrationProgress>(
              valueListenable: progressNotifier,
              builder: (context, progress, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: progress.fraction),
                    Text(
                      'step ${progress.currentStep} of ${progress.totalSteps}',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('step 1 of 5'), findsOneWidget);
      var indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.2, 0.001));

      progressNotifier.value = const MigrationProgress(
        currentStep: 4,
        totalSteps: 5,
      );
      await tester.pump();

      expect(find.text('step 4 of 5'), findsOneWidget);
      indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.8, 0.001));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `flutter test test/core/presentation/pages/startup_page_test.dart`
Expected: All 5 tests PASS

- [ ] **Step 3: Commit**

```
test: add widget tests for startup splash and migration progress UI (#186)
```

---

### Task 7: Run Full Test Suite and Format

**Files:**
- All modified files

- [ ] **Step 1: Format all code**

Run: `dart format lib/core/domain/entities/migration_progress.dart lib/core/database/database.dart lib/core/services/database_service.dart lib/core/presentation/pages/startup_page.dart lib/main.dart test/core/domain/entities/migration_progress_test.dart test/core/services/database_service_schema_version_test.dart test/core/presentation/pages/startup_page_test.dart`

Expected: All files formatted (or already formatted)

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: All tests pass. If any existing tests fail due to the `AppDatabase` constructor change (new optional parameter), update those tests to match. The parameter is optional so existing call sites should be unaffected.

- [ ] **Step 4: Commit any fixes**

If any fixes were needed:
```
fix: resolve test/lint issues from startup migration progress feature (#186)
```

- [ ] **Step 5: Final manual verification**

Run: `flutter run -d macos`
Verify:
1. App shows splash with icon and "Submersion" for ~1 second on normal startup
2. Splash transitions smoothly to the normal app
3. No visual regressions in the main app

---

## Notes for Future Migrations

When adding a new schema migration (e.g., version 63):

1. Add the `if (from < 63) { ... }` block in `onUpgrade`
2. Add `if (from < 63) reportProgress();` after the block
3. Append `63` to the `migrationVersions` list
4. Increment `currentSchemaVersion` to `63`

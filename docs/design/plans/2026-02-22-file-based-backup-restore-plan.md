# File-Based Backup & Restore Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the backup page to support exporting backups to arbitrary file locations, restoring from arbitrary files, configurable auto-backup location, and history pruning based on file existence.

**Architecture:** Extend the existing `BackupService` with new export/import/validate methods. Add a `backupLocation` field to `BackupSettings` and `BackupPreferences`. Redesign `BackupSettingsPage` with an action-first card layout (export card, import card, history list, collapsible auto-backup settings). Use existing `file_picker` and `share_plus` packages.

**Tech Stack:** Flutter, Drift ORM, Riverpod, file_picker (^10.3.9), share_plus (^12.0.1), path_provider

---

## Task 1: Add `backupLocation` to Domain Entity

**Files:**

- Modify: `lib/features/backup/domain/entities/backup_settings.dart`
- Test: `test/features/backup/domain/entities/backup_record_test.dart` (existing file, add new group)

**Step 1: Write the failing test**

Create a new test file for BackupSettings (the existing test file is for BackupRecord). Add to `test/features/backup/domain/entities/backup_settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';

void main() {
  group('BackupSettings', () {
    test('defaults backupLocation to null', () {
      const settings = BackupSettings();
      expect(settings.backupLocation, isNull);
    });

    test('copyWith preserves backupLocation', () {
      const settings = BackupSettings(backupLocation: '/custom/path');
      final copied = settings.copyWith(enabled: true);
      expect(copied.backupLocation, '/custom/path');
    });

    test('copyWith overrides backupLocation', () {
      const settings = BackupSettings(backupLocation: '/old/path');
      final copied = settings.copyWith(backupLocation: '/new/path');
      expect(copied.backupLocation, '/new/path');
    });

    test('includes backupLocation in Equatable props', () {
      const a = BackupSettings(backupLocation: '/path/a');
      const b = BackupSettings(backupLocation: '/path/b');
      const c = BackupSettings(backupLocation: '/path/a');
      expect(a, isNot(equals(b)));
      expect(a, equals(c));
    });
  });
}
```dart
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/domain/entities/backup_settings_test.dart -v`
Expected: FAIL -- `BackupSettings` has no `backupLocation` parameter.

**Step 3: Write minimal implementation**

In `lib/features/backup/domain/entities/backup_settings.dart`, add the `backupLocation` field:

- Add `final String? backupLocation;` to the class
- Add `this.backupLocation,` to the constructor
- Add `String? backupLocation,` to `copyWith` parameter list
- Add `backupLocation: backupLocation ?? this.backupLocation,` to the `copyWith` return
- Add `backupLocation,` to the `props` list

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/backup/domain/entities/backup_settings_test.dart -v`
Expected: PASS

**Step 5: Commit**

```bash
git add test/features/backup/domain/entities/backup_settings_test.dart lib/features/backup/domain/entities/backup_settings.dart
git commit -m "feat(backup): add backupLocation field to BackupSettings"
```text
---

## Task 2: Add `backupLocation` Persistence to BackupPreferences

**Files:**

- Modify: `lib/features/backup/data/repositories/backup_preferences.dart`
- Test: `test/features/backup/data/repositories/backup_preferences_test.dart`

**Step 1: Write the failing test**

Add to the existing `BackupPreferences settings` group in `test/features/backup/data/repositories/backup_preferences_test.dart`:

```dart
    test('getSettings returns null backupLocation by default', () {
      final settings = backupPreferences.getSettings();
      expect(settings.backupLocation, isNull);
    });

    test('setBackupLocation persists value', () async {
      await backupPreferences.setBackupLocation('/custom/backup/dir');

      final settings = backupPreferences.getSettings();
      expect(settings.backupLocation, '/custom/backup/dir');
    });

    test('setBackupLocation with null clears value', () async {
      await backupPreferences.setBackupLocation('/custom/backup/dir');
      await backupPreferences.setBackupLocation(null);

      final settings = backupPreferences.getSettings();
      expect(settings.backupLocation, isNull);
    });
```dart
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/repositories/backup_preferences_test.dart -v`
Expected: FAIL -- `setBackupLocation` not defined.

**Step 3: Write minimal implementation**

In `lib/features/backup/data/repositories/backup_preferences.dart`:

- Add constant: `static const String _backupLocationKey = 'backup_location';`
- Add to `getSettings()`: include `backupLocation: _prefs.getString(_backupLocationKey),` in the return
- Add method:

```dart
  Future<void> setBackupLocation(String? path) async {
    if (path == null) {
      await _prefs.remove(_backupLocationKey);
    } else {
      await _prefs.setString(_backupLocationKey, path);
    }
  }
```text
**Step 4: Run test to verify it passes**

Run: `flutter test test/features/backup/data/repositories/backup_preferences_test.dart -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/backup/data/repositories/backup_preferences.dart test/features/backup/data/repositories/backup_preferences_test.dart
git commit -m "feat(backup): add backupLocation persistence to BackupPreferences"
```text
---

## Task 3: Add `validateBackupFile` to BackupService

**Files:**

- Modify: `lib/features/backup/data/services/backup_service.dart`
- Test: `test/features/backup/data/services/backup_service_test.dart`

**Step 1: Write the failing test**

Add a new group to `test/features/backup/data/services/backup_service_test.dart`:

```dart
    group('validateBackupFile', () {
      test('returns false for non-existent file', () async {
        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        final result = await service.validateBackupFile('/nonexistent/file.sqlite');
        expect(result.isValid, false);
        expect(result.error, contains('not found'));
      });

      test('returns false for wrong extension', () async {
        // Create a temp file with wrong extension
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');
        final badFile = File('${tempDir.path}/not_a_backup.txt');
        await badFile.writeAsString('not a database');

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          final result = await service.validateBackupFile(badFile.path);
          expect(result.isValid, false);
          expect(result.error, contains('extension'));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart -v`
Expected: FAIL -- `validateBackupFile` not defined, `BackupValidationResult` not defined.

**Step 3: Write minimal implementation**

Add to `lib/features/backup/data/services/backup_service.dart`:

After the `BackupException` class at the bottom of the file, add:

```dart
/// Result of validating a backup file
class BackupValidationResult {
  final bool isValid;
  final String? error;
  final int? sizeBytes;

  const BackupValidationResult({
    required this.isValid,
    this.error,
    this.sizeBytes,
  });

  const BackupValidationResult.valid({this.sizeBytes})
      : isValid = true,
        error = null;

  const BackupValidationResult.invalid(String this.error)
      : isValid = false,
        sizeBytes = null;
}
```text
Add to the `BackupService` class (in the Backup section):

```dart
  /// Validate whether a file is a valid Submersion backup.
  ///
  /// Checks: file exists, has correct extension, is a valid SQLite database,
  /// and contains expected Submersion tables.
  Future<BackupValidationResult> validateBackupFile(String filePath) async {
    final file = File(filePath);

    // Check file exists
    if (!await file.exists()) {
      return const BackupValidationResult.invalid('File not found');
    }

    // Check extension
    final ext = p.extension(filePath).toLowerCase();
    if (ext != '.sqlite' && ext != '.db') {
      return BackupValidationResult.invalid(
        'Invalid file extension "$ext". Expected .sqlite or .db',
      );
    }

    // Check file size
    final sizeBytes = await file.length();
    if (sizeBytes == 0) {
      return const BackupValidationResult.invalid('File is empty');
    }

    // Try opening as SQLite and check for expected tables
    try {
      final testDb = AppDatabase(NativeDatabase(file, logStatements: false));
      try {
        // Verify it's a valid SQLite database
        await testDb.customSelect('SELECT 1').getSingle();

        // Check for expected Submersion tables
        final tables = await testDb
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('dives', 'dive_sites')",
            )
            .get();

        if (tables.isEmpty) {
          return const BackupValidationResult.invalid(
            'File does not appear to be a Submersion backup (missing expected tables)',
          );
        }

        return BackupValidationResult.valid(sizeBytes: sizeBytes);
      } finally {
        await testDb.close();
      }
    } catch (e) {
      return BackupValidationResult.invalid(
        'File is not a valid database: $e',
      );
    }
  }
```dart
Note: You'll need to add `import 'package:drift/native.dart';` at the top of backup_service.dart.

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/backup/data/services/backup_service.dart test/features/backup/data/services/backup_service_test.dart
git commit -m "feat(backup): add validateBackupFile with SQLite and table checks"
```text
---

## Task 4: Add `exportBackupToPath` to BackupService

**Files:**

- Modify: `lib/features/backup/data/services/backup_service.dart`
- Test: `test/features/backup/data/services/backup_service_test.dart`

**Step 1: Write the failing test**

Add a new group to the test file:

```dart
    group('exportBackupToPath', () {
      test('copies database to specified path', () async {
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');
        final destPath = '${tempDir.path}/my_backup.sqlite';

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          final record = await service.exportBackupToPath(destPath);

          expect(fakeDb.lastBackupPath, destPath);
          expect(fakeDb.backupCallCount, 1);
          expect(record.localPath, destPath);
          expect(record.filename, 'my_backup.sqlite');
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('records export in history', () async {
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');
        final destPath = '${tempDir.path}/my_backup.sqlite';

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          await service.exportBackupToPath(destPath);

          final history = preferences.getHistory();
          expect(history, hasLength(1));
          expect(history.first.localPath, destPath);
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart -v`
Expected: FAIL -- `exportBackupToPath` not defined.

**Step 3: Write minimal implementation**

Add to `BackupService` class:

```dart
  /// Export a backup to a user-specified file path.
  ///
  /// Records the export in backup history with the actual destination path.
  Future<BackupRecord> exportBackupToPath(String destinationPath) async {
    _log.info('Exporting backup to: $destinationPath');

    await _dbAdapter.backup(destinationPath);

    final filename = p.basename(destinationPath);
    final counts = await _getDiveSiteCounts();

    // Get size of the backup file
    final backupFile = File(destinationPath);
    final sizeBytes = await backupFile.exists() ? await backupFile.length() : 0;

    final record = BackupRecord(
      id: _uuid.v4(),
      filename: filename,
      timestamp: DateTime.now(),
      sizeBytes: sizeBytes,
      location: BackupLocation.local,
      diveCount: counts.diveCount,
      siteCount: counts.siteCount,
      localPath: destinationPath,
    );

    await _preferences.addRecord(record);
    await _preferences.setLastBackupTime(record.timestamp);

    _log.info('Export completed: $filename');
    return record;
  }
```text
**Step 4: Run test to verify it passes**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/backup/data/services/backup_service.dart test/features/backup/data/services/backup_service_test.dart
git commit -m "feat(backup): add exportBackupToPath for user-chosen export location"
```text
---

## Task 5: Add `exportBackupToTemp` to BackupService

**Files:**

- Modify: `lib/features/backup/data/services/backup_service.dart`
- Test: `test/features/backup/data/services/backup_service_test.dart`

**Step 1: Write the failing test**

```dart
    group('exportBackupToTemp', () {
      test('copies database to temp directory', () async {
        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        final tempFile = await service.exportBackupToTemp();

        expect(fakeDb.backupCallCount, 1);
        expect(fakeDb.lastBackupPath, contains('submersion_backup_'));
        expect(fakeDb.lastBackupPath, endsWith('.sqlite'));
        expect(tempFile.path, fakeDb.lastBackupPath);
      });

      test('does not record in history', () async {
        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        await service.exportBackupToTemp();

        final history = preferences.getHistory();
        expect(history, isEmpty);
      });
    });
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart -v`
Expected: FAIL -- `exportBackupToTemp` not defined.

**Step 3: Write minimal implementation**

Add to `BackupService` class:

```dart
  /// Export a backup to a temporary file for sharing.
  ///
  /// The file is NOT recorded in backup history since its destination
  /// is ephemeral (share sheet, AirDrop, email, etc.).
  /// Returns the temporary [File] for use with share sheet.
  Future<File> exportBackupToTemp() async {
    _log.info('Exporting backup to temp for sharing');

    final filename = _generateFilename();
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, filename);

    await _dbAdapter.backup(tempPath);

    _log.info('Temp export completed: $filename');
    return File(tempPath);
  }
```text
**Step 4: Run test to verify it passes**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/backup/data/services/backup_service.dart test/features/backup/data/services/backup_service_test.dart
git commit -m "feat(backup): add exportBackupToTemp for share sheet export"
```text
---

## Task 6: Add `restoreFromFile` to BackupService

**Files:**

- Modify: `lib/features/backup/data/services/backup_service.dart`
- Test: `test/features/backup/data/services/backup_service_test.dart`

**Step 1: Write the failing test**

```dart
    group('restoreFromFile', () {
      test('throws BackupException for non-existent file', () async {
        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        expect(
          () => service.restoreFromFile('/nonexistent/file.sqlite'),
          throwsA(isA<BackupException>()),
        );
      });

      test('creates safety backup before restoring', () async {
        // Create a temp file to restore from
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');
        final backupFile = File('${tempDir.path}/test.sqlite');
        await backupFile.writeAsString('fake db content');

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          // restoreFromFile calls performBackup internally for the safety backup,
          // then calls restore. The fake adapter tracks calls in order.
          await service.restoreFromFile(backupFile.path);

          // First call is the safety backup, second is the actual restore target
          expect(fakeDb.backupCallCount, 1); // safety backup
          expect(fakeDb.restoreCallCount, 1); // restore
          expect(fakeDb.lastRestorePath, backupFile.path);
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart -v`
Expected: FAIL -- `restoreFromFile` not defined.

**Step 3: Write minimal implementation**

Add to `BackupService` class in the Restore section:

```dart
  /// Restore the database from an arbitrary file path.
  ///
  /// Validates the file first, creates a safety backup, then restores.
  /// Throws [BackupException] if the file is invalid or not found.
  Future<void> restoreFromFile(String filePath) async {
    _log.info('Starting restore from file: $filePath');

    final file = File(filePath);
    if (!await file.exists()) {
      throw const BackupException('Backup file not found');
    }

    // Create safety backup first
    _log.info('Creating safety backup before file restore');
    await performBackup(isAutomatic: true);

    // Restore using DatabaseService
    await _dbAdapter.restore(filePath);

    _log.info('Restore from file completed: ${p.basename(filePath)}');
  }
```text
**Step 4: Run test to verify it passes**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/backup/data/services/backup_service.dart test/features/backup/data/services/backup_service_test.dart
git commit -m "feat(backup): add restoreFromFile for arbitrary file restore"
```text
---

## Task 7: Update `performBackup` to Use Configurable Location

**Files:**

- Modify: `lib/features/backup/data/services/backup_service.dart`
- Test: `test/features/backup/data/services/backup_service_test.dart`

**Step 1: Write the failing test**

```dart
    group('performBackup with custom location', () {
      test('uses custom backup location from settings', () async {
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');

        await preferences.setBackupLocation(tempDir.path);

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          await service.performBackup();

          expect(fakeDb.lastBackupPath, startsWith(tempDir.path));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('falls back to default location when no custom location', () async {
        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        await service.performBackup();

        // Default location uses the _localBackupFolder path
        expect(fakeDb.lastBackupPath, contains('Submersion'));
        expect(fakeDb.lastBackupPath, contains('Backups'));
      });
    });
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart -v`
Expected: FAIL -- `performBackup` still uses hardcoded path; `setBackupLocation` exists on preferences but `performBackup` doesn't read it.

**Step 3: Write minimal implementation**

Modify `performBackup()` in `BackupService`:

Replace the `localDir` assignment:

```dart
    // Old:
    final localDir = await getLocalBackupsDirectory();

    // New:
    final localDir = await getBackupsDirectory();
```text
Add a new method `getBackupsDirectory()` that checks settings:

```dart
  /// Get the active backups directory (custom or default), creating it if needed.
  Future<String> getBackupsDirectory() async {
    final settings = _preferences.getSettings();
    if (settings.backupLocation != null) {
      final customDir = Directory(settings.backupLocation!);
      if (!await customDir.exists()) {
        await customDir.create(recursive: true);
      }
      return customDir.path;
    }
    return getLocalBackupsDirectory();
  }
```text
**Step 4: Run test to verify it passes**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/backup/data/services/backup_service.dart test/features/backup/data/services/backup_service_test.dart
git commit -m "feat(backup): use configurable backup location in performBackup"
```text
---

## Task 8: Update `getBackupHistory` to Prune Stale Entries

**Files:**

- Modify: `lib/features/backup/data/services/backup_service.dart`
- Test: `test/features/backup/data/services/backup_service_test.dart`

Note: `getBackupHistory()` is currently synchronous. It must become `async` to check file existence. This will affect `backupHistoryProvider` (already a `FutureProvider`, so it's fine) and `pruneOldBackups` which calls `getBackupHistory()`.

**Step 1: Write the failing test**

```dart
    group('getBackupHistory with pruning', () {
      test('removes records where local file is gone and no cloud backup', () async {
        await preferences.addRecord(
          BackupRecord(
            id: 'exists',
            filename: 'exists.sqlite',
            timestamp: DateTime(2025, 6, 1),
            sizeBytes: 1000,
            location: BackupLocation.local,
            diveCount: 5,
            siteCount: 2,
            localPath: '/this/file/does/not/exist.sqlite',
          ),
        );
        await preferences.addRecord(
          BackupRecord(
            id: 'has-cloud',
            filename: 'cloud.sqlite',
            timestamp: DateTime(2025, 7, 1),
            sizeBytes: 1000,
            location: BackupLocation.both,
            diveCount: 10,
            siteCount: 3,
            localPath: '/also/missing.sqlite',
            cloudFileId: 'cloud-123',
          ),
        );

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        final history = await service.getValidatedBackupHistory();

        // 'exists' should be pruned (local-only, file missing)
        // 'has-cloud' should be kept (has cloud backup)
        expect(history, hasLength(1));
        expect(history.first.id, 'has-cloud');
      });

      test('keeps records where local file exists', () async {
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');
        final realFile = File('${tempDir.path}/real.sqlite');
        await realFile.writeAsString('data');

        await preferences.addRecord(
          BackupRecord(
            id: 'real',
            filename: 'real.sqlite',
            timestamp: DateTime(2025, 6, 1),
            sizeBytes: 1000,
            location: BackupLocation.local,
            diveCount: 5,
            siteCount: 2,
            localPath: realFile.path,
          ),
        );

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        try {
          final history = await service.getValidatedBackupHistory();
          expect(history, hasLength(1));
          expect(history.first.id, 'real');
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('keeps records with no localPath (legacy)', () async {
        await preferences.addRecord(
          BackupRecord(
            id: 'legacy',
            filename: 'legacy.sqlite',
            timestamp: DateTime(2025, 6, 1),
            sizeBytes: 1000,
            location: BackupLocation.local,
            diveCount: 5,
            siteCount: 2,
            // localPath is null
          ),
        );

        final service = BackupService(
          dbAdapter: fakeDb,
          preferences: preferences,
        );

        final history = await service.getValidatedBackupHistory();
        expect(history, hasLength(1));
      });
    });
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart -v`
Expected: FAIL -- `getValidatedBackupHistory` not defined.

**Step 3: Write minimal implementation**

Add to `BackupService` class (in the History & Management section):

```dart
  /// Get backup history with stale entry pruning.
  ///
  /// Checks each record's local file existence. Removes records where:
  /// - localPath is set but file no longer exists
  /// - AND there is no cloud backup (cloudFileId is null)
  ///
  /// Records with no localPath (legacy) or with cloud backups are kept.
  Future<List<BackupRecord>> getValidatedBackupHistory() async {
    final history = _preferences.getHistory();
    final validRecords = <BackupRecord>[];
    var pruned = false;

    for (final record in history) {
      if (record.localPath != null && record.cloudFileId == null) {
        final file = File(record.localPath!);
        if (!await file.exists()) {
          _log.info('Pruning stale backup record: ${record.filename}');
          pruned = true;
          continue;
        }
      }
      validRecords.add(record);
    }

    if (pruned) {
      await _preferences.setHistory(validRecords);
    }

    validRecords.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return validRecords;
  }
```text
**Step 4: Run test to verify it passes**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/backup/data/services/backup_service.dart test/features/backup/data/services/backup_service_test.dart
git commit -m "feat(backup): add getValidatedBackupHistory with stale entry pruning"
```dart
---

## Task 9: Add Provider Methods

**Files:**

- Modify: `lib/features/backup/presentation/providers/backup_providers.dart`

**Step 1: Add `setBackupLocation` to `BackupSettingsNotifier`**

In the `BackupSettingsNotifier` class, add:

```dart
  Future<void> setBackupLocation(String? path) async {
    await _prefs.setBackupLocation(path);
    state = state.copyWith(backupLocation: path);
  }
```text
**Step 2: Add new operations to `BackupOperationNotifier`**

Add these methods to the `BackupOperationNotifier` class:

```dart
  /// Export backup to a user-chosen file path
  Future<void> exportToPath(String destinationPath) async {
    if (state.status == BackupOperationStatus.inProgress) return;

    state = const BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: 'Exporting backup...',
    );

    try {
      final record = await _service.exportBackupToPath(destinationPath);
      state = BackupOperationState(
        status: BackupOperationStatus.success,
        message: 'Backup exported: ${record.formattedSize}',
        lastRecord: record,
      );
      _ref.read(backupSettingsProvider.notifier).refresh();
      _ref.invalidate(backupHistoryProvider);
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: 'Export failed: $e',
      );
    }
  }

  /// Export backup to temp file for sharing
  Future<File?> exportForSharing() async {
    if (state.status == BackupOperationStatus.inProgress) return null;

    state = const BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: 'Preparing backup for sharing...',
    );

    try {
      final file = await _service.exportBackupToTemp();
      state = const BackupOperationState(
        status: BackupOperationStatus.success,
        message: 'Backup ready for sharing',
      );
      return file;
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: 'Export failed: $e',
      );
      return null;
    }
  }

  /// Restore from an arbitrary file
  Future<void> restoreFromFile(String filePath) async {
    if (state.status == BackupOperationStatus.inProgress) return;

    state = const BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: 'Validating backup file...',
    );

    try {
      // Validate first
      final validation = await _service.validateBackupFile(filePath);
      if (!validation.isValid) {
        state = BackupOperationState(
          status: BackupOperationStatus.error,
          message: validation.error ?? 'Invalid backup file',
        );
        return;
      }

      state = const BackupOperationState(
        status: BackupOperationStatus.inProgress,
        message: 'Restoring backup...',
      );

      await _service.restoreFromFile(filePath);
      state = const BackupOperationState(
        status: BackupOperationStatus.success,
        message: 'Restore completed. Please restart the app.',
      );
      _ref.invalidate(backupHistoryProvider);
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: 'Restore failed: $e',
      );
    }
  }
```text
**Step 3: Update `backupHistoryProvider` to use validated history**

Change:

```dart
final backupHistoryProvider = FutureProvider<List<BackupRecord>>((ref) async {
  final service = ref.watch(backupServiceProvider);
  return service.getBackupHistory();
});
```text
To:

```dart
final backupHistoryProvider = FutureProvider<List<BackupRecord>>((ref) async {
  final service = ref.watch(backupServiceProvider);
  return service.getValidatedBackupHistory();
});
```dart
**Step 4: Add `import 'dart:io';`** at the top of the file (needed for `File` return type).

**Step 5: Run existing tests to verify no regressions**

Run: `flutter test test/features/backup/ -v`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/features/backup/presentation/providers/backup_providers.dart
git commit -m "feat(backup): add export/import/location methods to providers"
```diff
---

## Task 10: Add Localization Strings

**Files:**

- Modify: `lib/l10n/arb/app_en.arb`

**Step 1: Add new backup strings to `app_en.arb`**

Add these strings in the backup section (after the existing `backup_` entries), keeping alphabetical order:

```json
  "backup_export_title": "Export Backup",
  "backup_export_subtitle": "Save your dive data to a file",
  "backup_export_bottomSheet_title": "Export Backup",
  "backup_export_saveToFile": "Save to File",
  "backup_export_saveToFile_subtitle": "Choose where to save the backup file",
  "backup_export_share": "Share",
  "backup_export_share_subtitle": "Send via AirDrop, email, or other apps",
  "backup_export_success": "Backup exported successfully",
  "backup_import_title": "Restore from File",
  "backup_import_subtitle": "Import a backup from any location",
  "backup_import_invalidFile": "This file does not appear to be a valid Submersion backup",
  "backup_import_validating": "Validating backup file...",
  "backup_location_title": "Backup Location",
  "backup_location_change": "Change",
  "backup_location_default": "Default location",
  "backup_section_auto": "Automatic Backups",
```text
**Step 2: Run l10n generation**

Run: `flutter gen-l10n` or rely on it being generated automatically.

**Step 3: Commit**

```bash
git add lib/l10n/arb/app_en.arb
git commit -m "feat(backup): add l10n strings for file-based backup/restore"
```text
---

## Task 11: Create Export Bottom Sheet Widget

**Files:**

- Create: `lib/features/backup/presentation/widgets/export_bottom_sheet.dart`

**Step 1: Create the widget**

```dart
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Bottom sheet presenting export options: Save to File and Share.
///
/// Share option is hidden on Windows and Linux (no share sheet support).
class ExportBottomSheet extends StatelessWidget {
  final VoidCallback onSaveToFile;
  final VoidCallback? onShare;

  const ExportBottomSheet({
    super.key,
    required this.onSaveToFile,
    this.onShare,
  });

  /// Shows the bottom sheet and returns nothing (actions are callbacks).
  static void show(
    BuildContext context, {
    required VoidCallback onSaveToFile,
    required VoidCallback onShare,
  }) {
    final showShare = Platform.isIOS || Platform.isMacOS || Platform.isAndroid;

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ExportBottomSheet(
        onSaveToFile: () {
          Navigator.of(context).pop();
          onSaveToFile();
        },
        onShare: showShare
            ? () {
                Navigator.of(context).pop();
                onShare();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.l10n.backup_export_bottomSheet_title,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),

            // Save to File
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: Text(context.l10n.backup_export_saveToFile),
              subtitle: Text(context.l10n.backup_export_saveToFile_subtitle),
              onTap: onSaveToFile,
            ),

            // Share (platform-conditional)
            if (onShare != null)
              ListTile(
                leading: const Icon(Icons.share),
                title: Text(context.l10n.backup_export_share),
                subtitle: Text(context.l10n.backup_export_share_subtitle),
                onTap: onShare,
              ),
          ],
        ),
      ),
    );
  }
}
```text
**Step 2: Commit**

```bash
git add lib/features/backup/presentation/widgets/export_bottom_sheet.dart
git commit -m "feat(backup): add ExportBottomSheet widget"
```text
---

## Task 12: Redesign BackupSettingsPage

**Files:**

- Modify: `lib/features/backup/presentation/pages/backup_settings_page.dart`

This is the largest task. The page gets a full redesign. Key imports to add at top:

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
```dart
**Step 1: Rewrite the page**

Replace the entire `BackupSettingsPage` body with the 4-section layout:

- `_buildExportCard()` -- tapping opens `ExportBottomSheet.show()`. "Save to File" calls `FilePicker.platform.saveFile()` with `dialogTitle`, `fileName`, and `allowedExtensions: ['sqlite']`. On success, calls `ref.read(backupOperationProvider.notifier).exportToPath(path)`. "Share" calls `exportForSharing()` then `Share.shareXFiles([XFile(file.path)])`.

- `_buildImportCard()` -- tapping calls `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['sqlite', 'db'])`. On file selected, shows `RestoreConfirmationDialog` (reuse existing), then calls `ref.read(backupOperationProvider.notifier).restoreFromFile(filePath)`.

- `_buildHistorySection()` -- reuse existing `_buildHistorySection` and `_buildHistoryTile` largely as-is, but remove the restore-from-record popup action (now handled by file import) -- actually keep it, users may still want to restore from a history entry.

- `_buildAutoBackupSection()` -- wrap in `ExpansionTile` with the on/off toggle as the trailing widget. Inside: backup location tile (shows path, tap to change via `FilePicker.platform.getDirectoryPath()`), frequency dropdown, retention dropdown, cloud toggle.

The full widget code is too long for this plan. Follow the design doc section "Page Layout" for exact structure. Key patterns:

For the export card and import card, use `Card` with `InkWell`:

```dart
Widget _buildActionCard({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
  required bool enabled,
}) {
  final theme = Theme.of(context);
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
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
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    ),
  );
}
```text
For the auto-backup location tile:

```dart
ListTile(
  title: Text(context.l10n.backup_location_title),
  subtitle: Text(
    settings.backupLocation ?? context.l10n.backup_location_default,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
  trailing: TextButton(
    onPressed: () async {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: context.l10n.backup_location_title,
      );
      if (path != null) {
        ref.read(backupSettingsProvider.notifier).setBackupLocation(path);
      }
    },
    child: Text(context.l10n.backup_location_change),
  ),
),
```typescript
**Step 2: Run the app to visually verify**

Run: `flutter run -d macos`

Navigate to Settings > Data > Backup. Verify:

- Two action cards appear at top
- History list shows below
- Auto backup settings appear in collapsible section
- Export bottom sheet opens with Save/Share options
- File picker opens for both export and import

**Step 3: Commit**

```bash
git add lib/features/backup/presentation/pages/backup_settings_page.dart
git commit -m "feat(backup): redesign BackupSettingsPage with file-based actions"
```dart
---

## Task 13: Update Existing Tests

**Files:**

- Modify: `test/features/settings/presentation/pages/settings_page_test.dart` (if it references backup page)

**Step 1: Run all backup tests**

Run: `flutter test test/features/backup/ -v`

Fix any compilation errors caused by:

- `getBackupHistory()` now being async (if any test called it synchronously)
- New required parameters

**Step 2: Run full test suite**

Run: `flutter test`
Expected: PASS

**Step 3: Format code**

Run: `dart format lib/features/backup/ test/features/backup/`

**Step 4: Analyze**

Run: `flutter analyze`
Expected: No issues

**Step 5: Commit**

```bash
git add -A
git commit -m "test(backup): fix tests for file-based backup changes"
```

---

## Task 14: Final Integration Verification

**Step 1: Run full test suite**

Run: `flutter test`

**Step 2: Run analyzer**

Run: `flutter analyze`

**Step 3: Format check**

Run: `dart format --set-exit-if-changed lib/ test/`

**Step 4: Manual smoke test on macOS**

1. Open app, navigate to Settings > Data > Backup
2. Tap "Export Backup" card
3. Choose "Save to File", pick Downloads folder -- verify file appears
4. Choose "Share" -- verify share sheet opens
5. Tap "Restore from File" card
6. Pick the file just exported -- verify confirmation dialog, then restore succeeds
7. Delete the exported file from Finder
8. Return to backup page -- verify history no longer shows the deleted entry
9. Expand "Automatic Backups" section
10. Tap "Change" on backup location -- pick a custom folder
11. Trigger a manual backup from history -- verify it goes to the custom folder

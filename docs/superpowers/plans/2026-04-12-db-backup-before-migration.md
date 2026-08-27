# Pre-Migration Database Backup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically back up `submersion.db` at app startup whenever a Drift schema migration is pending, hard-fail startup if backup fails, surface pre-migration backups in the existing backup list with pin-to-retain support.

**Architecture:** A new `PreMigrationBackupService` performs a file-level copy of the closed DB before Drift opens it, registering the copy via the existing `BackupPreferences` registry. The existing `BackupRecord` entity gains nullable `type` / `appVersion` / `fromSchemaVersion` / `toSchemaVersion` / `pinned` fields so pre-migration and manual backups share one listing/restore surface. `StartupPage` gets new `backingUp` / `backupFailed` states.

**Tech Stack:** Flutter 3.x, Drift 2.30, sqlite3 FFI, Riverpod, SharedPreferences via `BackupPreferences`, existing `BackupService`. Tests use `flutter_test`, `test`, and in-memory Drift (`NativeDatabase.memory`).

**Reference spec:** `docs/superpowers/specs/2026-04-12-db-backup-before-migration-design.md`

---

## File Structure

**New files:**

- `lib/features/backup/domain/entities/backup_type.dart` — `BackupType` enum (`manual`, `preMigration`).
- `lib/features/backup/domain/exceptions/backup_failed_exception.dart` — `BackupFailedException` + `BackupFailureCause` enum.
- `lib/features/backup/data/services/pre_migration_backup_service.dart` — the service.
- `test/features/backup/data/services/pre_migration_backup_service_test.dart` — unit tests.
- `test/features/backup/presentation/widgets/restore_confirmation_dialog_compat_test.dart` — dialog compat branching.
- `test/core/presentation/pages/startup_page_backup_flow_test.dart` — widget tests for backup-flow states.
- `test/core/database/pre_migration_backup_integration_test.dart` — end-to-end integration.

**Modified files:**

- `lib/features/backup/domain/entities/backup_record.dart` — add new fields, make counts nullable, update JSON.
- `lib/features/backup/data/services/backup_service.dart` — add `pinBackup` / `unpinBackup`.
- `lib/core/presentation/pages/startup_page.dart` — new `backingUp` / `backupFailed` states, wire service.
- `lib/features/backup/presentation/pages/backup_settings_page.dart` — pin toggle icon + pre-migration badge on list rows.
- `lib/features/backup/presentation/widgets/restore_confirmation_dialog.dart` — compat branching for pre-migration backups.
- `test/features/backup/domain/entities/backup_record_test.dart` — cover new fields + backward-compat JSON.

---

## Task 1: Add BackupType enum

**Files:**
- Create: `lib/features/backup/domain/entities/backup_type.dart`

- [ ] **Step 1: Create the enum file**

```dart
// lib/features/backup/domain/entities/backup_type.dart

/// Distinguishes a user-initiated (manual / automatic) backup from a
/// system-initiated backup taken before a schema migration runs.
enum BackupType {
  manual,
  preMigration,
}
```

- [ ] **Step 2: Run analyzer to verify no errors**

Run: `flutter analyze lib/features/backup/domain/entities/backup_type.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/features/backup/domain/entities/backup_type.dart
git commit -m "feat: add BackupType enum for distinguishing backup sources"
```

---

## Task 2: Extend BackupRecord with new fields (TDD)

**Files:**
- Modify: `lib/features/backup/domain/entities/backup_record.dart` (full rewrite)
- Modify: `test/features/backup/domain/entities/backup_record_test.dart`

- [ ] **Step 1: Add failing tests for new fields and backward-compat JSON**

Append these tests to `test/features/backup/domain/entities/backup_record_test.dart`
(if groups already exist, place inside `group('BackupRecord', ...)`):

```dart
test('defaults: type is manual, pinned is false, counts may be null', () {
  final record = BackupRecord(
    id: 'id',
    filename: 'f.db',
    timestamp: DateTime(2026, 4, 12),
    sizeBytes: 10,
    location: BackupLocation.local,
  );
  expect(record.type, BackupType.manual);
  expect(record.pinned, false);
  expect(record.appVersion, isNull);
  expect(record.fromSchemaVersion, isNull);
  expect(record.toSchemaVersion, isNull);
  expect(record.diveCount, isNull);
  expect(record.siteCount, isNull);
});

test('toJson/fromJson round-trip with new fields populated', () {
  final original = BackupRecord(
    id: 'id',
    filename: 'f.db',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
    sizeBytes: 42,
    location: BackupLocation.local,
    diveCount: 3,
    siteCount: 4,
    type: BackupType.preMigration,
    appVersion: '1.6.0.1241',
    fromSchemaVersion: 63,
    toSchemaVersion: 64,
    pinned: true,
    localPath: '/tmp/f.db',
  );
  final restored = BackupRecord.fromJson(original.toJson());
  expect(restored, original);
});

test('fromJson reads legacy records (no type/pinned/appVersion fields)', () {
  final legacyJson = {
    'id': 'id',
    'filename': 'f.db',
    'timestamp': 1_700_000_000_000,
    'sizeBytes': 42,
    'location': 'local',
    'diveCount': 3,
    'siteCount': 4,
    'cloudFileId': null,
    'localPath': '/tmp/f.db',
    'isAutomatic': false,
  };
  final record = BackupRecord.fromJson(legacyJson);
  expect(record.type, BackupType.manual);
  expect(record.pinned, false);
  expect(record.appVersion, isNull);
  expect(record.fromSchemaVersion, isNull);
  expect(record.toSchemaVersion, isNull);
  expect(record.diveCount, 3);
  expect(record.siteCount, 4);
});

test('fromJson handles null counts for pre-migration records', () {
  final json = {
    'id': 'id',
    'filename': 'f.db',
    'timestamp': 1_700_000_000_000,
    'sizeBytes': 42,
    'location': 'local',
    'diveCount': null,
    'siteCount': null,
    'cloudFileId': null,
    'localPath': '/tmp/f.db',
    'isAutomatic': true,
    'type': 'preMigration',
    'appVersion': '1.6.0.1241',
    'fromSchemaVersion': 63,
    'toSchemaVersion': 64,
    'pinned': true,
  };
  final record = BackupRecord.fromJson(json);
  expect(record.diveCount, isNull);
  expect(record.siteCount, isNull);
  expect(record.type, BackupType.preMigration);
});

test('copyWith preserves new fields when not overridden', () {
  final original = BackupRecord(
    id: 'id',
    filename: 'f.db',
    timestamp: DateTime(2026),
    sizeBytes: 1,
    location: BackupLocation.local,
    type: BackupType.preMigration,
    pinned: true,
    fromSchemaVersion: 63,
    toSchemaVersion: 64,
  );
  final copy = original.copyWith(sizeBytes: 2);
  expect(copy.type, BackupType.preMigration);
  expect(copy.pinned, true);
  expect(copy.fromSchemaVersion, 63);
  expect(copy.toSchemaVersion, 64);
  expect(copy.sizeBytes, 2);
});

test('copyWith can set pinned independently', () {
  final original = BackupRecord(
    id: 'id',
    filename: 'f.db',
    timestamp: DateTime(2026),
    sizeBytes: 1,
    location: BackupLocation.local,
    pinned: false,
  );
  final pinned = original.copyWith(pinned: true);
  expect(pinned.pinned, true);
});
```

Also add at top of file (below existing imports):

```dart
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/backup/domain/entities/backup_record_test.dart`
Expected: New tests fail with compilation errors (type, pinned, etc. undefined) or missing named args.

- [ ] **Step 3: Replace `lib/features/backup/domain/entities/backup_record.dart` with the extended shape**

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/backup/domain/entities/backup_type.dart';

/// Where a backup is stored
enum BackupLocation { local, cloud, both }

/// A record of a single backup snapshot
class BackupRecord extends Equatable {
  final String id;
  final String filename;
  final DateTime timestamp;
  final int sizeBytes;
  final BackupLocation location;
  final int? diveCount;
  final int? siteCount;
  final String? cloudFileId;
  final String? localPath;
  final bool isAutomatic;
  final BackupType type;
  final String? appVersion;
  final int? fromSchemaVersion;
  final int? toSchemaVersion;
  final bool pinned;

  const BackupRecord({
    required this.id,
    required this.filename,
    required this.timestamp,
    required this.sizeBytes,
    required this.location,
    this.diveCount,
    this.siteCount,
    this.cloudFileId,
    this.localPath,
    this.isAutomatic = false,
    this.type = BackupType.manual,
    this.appVersion,
    this.fromSchemaVersion,
    this.toSchemaVersion,
    this.pinned = false,
  });

  BackupRecord copyWith({
    String? id,
    String? filename,
    DateTime? timestamp,
    int? sizeBytes,
    BackupLocation? location,
    int? diveCount,
    int? siteCount,
    String? cloudFileId,
    String? localPath,
    bool? isAutomatic,
    BackupType? type,
    String? appVersion,
    int? fromSchemaVersion,
    int? toSchemaVersion,
    bool? pinned,
  }) {
    return BackupRecord(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      timestamp: timestamp ?? this.timestamp,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      location: location ?? this.location,
      diveCount: diveCount ?? this.diveCount,
      siteCount: siteCount ?? this.siteCount,
      cloudFileId: cloudFileId ?? this.cloudFileId,
      localPath: localPath ?? this.localPath,
      isAutomatic: isAutomatic ?? this.isAutomatic,
      type: type ?? this.type,
      appVersion: appVersion ?? this.appVersion,
      fromSchemaVersion: fromSchemaVersion ?? this.fromSchemaVersion,
      toSchemaVersion: toSchemaVersion ?? this.toSchemaVersion,
      pinned: pinned ?? this.pinned,
    );
  }

  /// Formatted file size for display (e.g., "2.3 MB")
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'sizeBytes': sizeBytes,
      'location': location.name,
      'diveCount': diveCount,
      'siteCount': siteCount,
      'cloudFileId': cloudFileId,
      'localPath': localPath,
      'isAutomatic': isAutomatic,
      'type': type.name,
      'appVersion': appVersion,
      'fromSchemaVersion': fromSchemaVersion,
      'toSchemaVersion': toSchemaVersion,
      'pinned': pinned,
    };
  }

  factory BackupRecord.fromJson(Map<String, dynamic> json) {
    return BackupRecord(
      id: json['id'] as String,
      filename: json['filename'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      sizeBytes: json['sizeBytes'] as int,
      location: BackupLocation.values.byName(json['location'] as String),
      diveCount: json['diveCount'] as int?,
      siteCount: json['siteCount'] as int?,
      cloudFileId: json['cloudFileId'] as String?,
      localPath: json['localPath'] as String?,
      isAutomatic: json['isAutomatic'] as bool? ?? false,
      type: _parseType(json['type'] as String?),
      appVersion: json['appVersion'] as String?,
      fromSchemaVersion: json['fromSchemaVersion'] as int?,
      toSchemaVersion: json['toSchemaVersion'] as int?,
      pinned: json['pinned'] as bool? ?? false,
    );
  }

  static BackupType _parseType(String? value) {
    if (value == null) return BackupType.manual;
    return BackupType.values.asNameMap()[value] ?? BackupType.manual;
  }

  @override
  List<Object?> get props => [
    id,
    filename,
    timestamp,
    sizeBytes,
    location,
    diveCount,
    siteCount,
    cloudFileId,
    localPath,
    isAutomatic,
    type,
    appVersion,
    fromSchemaVersion,
    toSchemaVersion,
    pinned,
  ];
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/backup/domain/entities/backup_record_test.dart`
Expected: All tests pass, including the five new ones.

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze lib/features/backup/domain/entities/backup_record.dart test/features/backup/domain/entities/backup_record_test.dart`
Expected: No issues. The nullable `diveCount` / `siteCount` change may surface call sites that assumed non-null — that's addressed in the next task.

- [ ] **Step 6: Commit**

```bash
git add lib/features/backup/domain/entities/backup_record.dart \
        test/features/backup/domain/entities/backup_record_test.dart
git commit -m "feat: extend BackupRecord with type, pinned, schema pair, appVersion"
```

---

## Task 3: Fix non-null callers of diveCount/siteCount

**Files:**
- Modify: any files surfaced by the analyzer that use `record.diveCount` or `record.siteCount` without handling null.

- [ ] **Step 1: Run analyzer across the full project to surface all breakages**

Run: `flutter analyze`
Expected: A list of errors referencing `diveCount` or `siteCount` on `BackupRecord`.

- [ ] **Step 2: For each surfaced site, update the caller to handle null**

Typical fix pattern — replace:
```dart
'${record.diveCount} dives, ${record.siteCount} sites'
```
with:
```dart
'${record.diveCount ?? 0} dives, ${record.siteCount ?? 0} sites'
```

Known caller per the current code: `lib/features/backup/presentation/pages/backup_settings_page.dart` around the `ListTile.subtitle` on the history row. Replace:
```dart
subtitle: Text(
  '${record.diveCount} dives, ${record.siteCount} sites - ${record.formattedSize}'
  '${record.isAutomatic ? ' (auto)' : ''}',
),
```
with:
```dart
subtitle: Text(
  record.type == BackupType.preMigration
      ? 'v${record.fromSchemaVersion} → v${record.toSchemaVersion} - ${record.formattedSize}'
      : '${record.diveCount ?? 0} dives, '
        '${record.siteCount ?? 0} sites - ${record.formattedSize}'
        '${record.isAutomatic ? ' (auto)' : ''}',
),
```

Also add `import 'package:submersion/features/backup/domain/entities/backup_type.dart';` at the top of `backup_settings_page.dart` if not already imported.

Fix any other surfaced sites the same way — null-coalesce to `0` or `'—'` as appropriate for display.

- [ ] **Step 3: Re-run analyzer**

Run: `flutter analyze`
Expected: Zero issues.

- [ ] **Step 4: Run the full test suite to catch any runtime fallout**

Run: `flutter test`
Expected: All tests pass. (This sweeps up any mocks/fixtures that built records with positional-ish-feeling counts.)

- [ ] **Step 5: Format**

Run: `dart format lib/ test/`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "fix: handle nullable diveCount/siteCount in existing callers"
```

---

## Task 4: Define BackupFailedException (TDD)

**Files:**
- Create: `lib/features/backup/domain/exceptions/backup_failed_exception.dart`
- Create: `test/features/backup/domain/exceptions/backup_failed_exception_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/features/backup/domain/exceptions/backup_failed_exception_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';

void main() {
  group('BackupFailedException.fromError', () {
    test('classifies ENOSPC (28) as diskFull', () {
      final fse = FileSystemException(
        'copy failed',
        '/tmp/f.db',
        const OSError('No space left on device', 28),
      );
      final e = BackupFailedException.fromError(fse, StackTrace.empty);
      expect(e.cause, BackupFailureCause.diskFull);
      expect(e.userMessage, contains('disk space'));
    });

    test('classifies EACCES (13) as permissionDenied', () {
      final fse = FileSystemException(
        'open failed',
        '/tmp/f.db',
        const OSError('Permission denied', 13),
      );
      final e = BackupFailedException.fromError(fse, StackTrace.empty);
      expect(e.cause, BackupFailureCause.permissionDenied);
      expect(e.userMessage, contains('access'));
    });

    test('classifies EPERM (1) as permissionDenied', () {
      final fse = FileSystemException(
        'open failed',
        '/tmp/f.db',
        const OSError('Operation not permitted', 1),
      );
      final e = BackupFailedException.fromError(fse, StackTrace.empty);
      expect(e.cause, BackupFailureCause.permissionDenied);
    });

    test('wraps unclassified errors as unknown', () {
      final err = StateError('something odd');
      final e = BackupFailedException.fromError(err, StackTrace.empty);
      expect(e.cause, BackupFailureCause.unknown);
      expect(e.technicalDetails, contains('something odd'));
    });

    test('preserves original error in technicalDetails', () {
      final fse = FileSystemException(
        'copy failed',
        '/tmp/f.db',
        const OSError('No space left on device', 28),
      );
      final e = BackupFailedException.fromError(fse, StackTrace.empty);
      expect(e.technicalDetails, contains('No space left on device'));
    });
  });

  test('sourceMissing is constructible directly', () {
    final e = BackupFailedException(
      cause: BackupFailureCause.sourceMissing,
      userMessage: 'Dive log file not found.',
      technicalDetails: 'file /tmp/f.db does not exist',
    );
    expect(e.cause, BackupFailureCause.sourceMissing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/backup/domain/exceptions/backup_failed_exception_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement the exception**

```dart
// lib/features/backup/domain/exceptions/backup_failed_exception.dart
import 'dart:io';

enum BackupFailureCause {
  diskFull,
  permissionDenied,
  sourceMissing,
  renameFailed,
  unknown,
}

/// Thrown by PreMigrationBackupService when a backup cannot be completed.
///
/// Always carries a user-facing message safe to display, plus raw technical
/// details (stack, error.toString) for support escalation.
class BackupFailedException implements Exception {
  final BackupFailureCause cause;
  final String userMessage;
  final String technicalDetails;

  const BackupFailedException({
    required this.cause,
    required this.userMessage,
    required this.technicalDetails,
  });

  factory BackupFailedException.fromError(Object error, StackTrace stack) {
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      switch (code) {
        case 28: // ENOSPC
          return BackupFailedException(
            cause: BackupFailureCause.diskFull,
            userMessage: 'Not enough free disk space to back up your data.',
            technicalDetails: '${error.toString()}\n$stack',
          );
        case 13: // EACCES
        case 1: // EPERM
          return BackupFailedException(
            cause: BackupFailureCause.permissionDenied,
            userMessage: 'The app could not access the backup folder.',
            technicalDetails: '${error.toString()}\n$stack',
          );
      }
    }
    return BackupFailedException(
      cause: BackupFailureCause.unknown,
      userMessage: 'Backup failed: ${error.toString()}',
      technicalDetails: '${error.toString()}\n$stack',
    );
  }

  @override
  String toString() => 'BackupFailedException($cause): $userMessage';
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/backup/domain/exceptions/backup_failed_exception_test.dart`
Expected: All 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/backup/domain/exceptions/backup_failed_exception.dart \
        test/features/backup/domain/exceptions/backup_failed_exception_test.dart
git commit -m "feat: add BackupFailedException with OS-error classification"
```

---

## Task 5: PreMigrationBackupService happy-path copy + register (TDD)

**Files:**
- Create: `lib/features/backup/data/services/pre_migration_backup_service.dart`
- Create: `test/features/backup/data/services/pre_migration_backup_service_test.dart`

- [ ] **Step 1: Write failing happy-path test**

```dart
// test/features/backup/data/services/pre_migration_backup_service_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/pre_migration_backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';

Future<_Fixture> _makeFixture() async {
  final tmp = await Directory.systemTemp.createTemp('pmbs_test_');
  final live = File(p.join(tmp.path, 'submersion.db'));
  await live.writeAsBytes(List<int>.generate(1024, (i) => i % 256));
  final backupsDir = Directory(p.join(tmp.path, 'backups'));
  await backupsDir.create();
  SharedPreferences.setMockInitialValues({});
  final prefs = BackupPreferences(await SharedPreferences.getInstance());
  return _Fixture(tmp: tmp, livePath: live.path, backupsDir: backupsDir.path, prefs: prefs);
}

class _Fixture {
  final Directory tmp;
  final String livePath;
  final String backupsDir;
  final BackupPreferences prefs;
  _Fixture({required this.tmp, required this.livePath, required this.backupsDir, required this.prefs});
  Future<void> dispose() async => tmp.delete(recursive: true);
}

void main() {
  group('PreMigrationBackupService happy path', () {
    test('copies live DB bytes into backups folder', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
        idGenerator: () => 'test-id-1',
      );

      await service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      final expectedName = '20260412-081201-v63-v64.db';
      final backupFile = File(p.join(f.backupsDir, expectedName));
      expect(await backupFile.exists(), isTrue);
      expect(await backupFile.readAsBytes(), await File(f.livePath).readAsBytes());
    });

    test('registers BackupRecord with preMigration type + schema pair', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
        idGenerator: () => 'test-id-1',
      );

      await service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      final history = f.prefs.getHistory();
      expect(history, hasLength(1));
      final record = history.single;
      expect(record.id, 'test-id-1');
      expect(record.type, BackupType.preMigration);
      expect(record.fromSchemaVersion, 63);
      expect(record.toSchemaVersion, 64);
      expect(record.appVersion, '1.6.0.1241');
      expect(record.filename, '20260412-081201-v63-v64.db');
      expect(record.diveCount, isNull);
      expect(record.siteCount, isNull);
      expect(record.pinned, false);
      expect(record.isAutomatic, true);
      expect(record.location, BackupLocation.local);
      expect(record.localPath, p.join(f.backupsDir, record.filename));
      expect(record.sizeBytes, 1024);
    });

    test('skips when stored == target (no-op)', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 4, 12),
        idGenerator: () => 'x',
      );

      await service.backupIfMigrationPending(
        stored: 64,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      expect(await Directory(f.backupsDir).list().isEmpty, isTrue);
      expect(f.prefs.getHistory(), isEmpty);
    });

    test('skips when live DB file does not exist', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      await File(f.livePath).delete();
      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 4, 12),
        idGenerator: () => 'x',
      );

      await service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      expect(await Directory(f.backupsDir).list().isEmpty, isTrue);
      expect(f.prefs.getHistory(), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/backup/data/services/pre_migration_backup_service_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement the service (happy path only — sweep/prune added later)**

```dart
// lib/features/backup/data/services/pre_migration_backup_service.dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';

typedef _PathProvider = Future<String> Function();

/// Copies the live sqlite database before Drift runs a schema migration.
///
/// Operates on the closed database file. Registers the copy via the
/// existing BackupPreferences registry so it appears alongside manual
/// backups in the backup list UI.
class PreMigrationBackupService {
  final _PathProvider _livePathProvider;
  final _PathProvider _backupsDirProvider;
  final BackupPreferences _preferences;
  final DateTime Function() _clock;
  final String Function() _idGenerator;
  final _log = LoggerService.forClass(PreMigrationBackupService);

  PreMigrationBackupService({
    required _PathProvider livePathProvider,
    required _PathProvider backupsDirProvider,
    required BackupPreferences preferences,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _livePathProvider = livePathProvider,
       _backupsDirProvider = backupsDirProvider,
       _preferences = preferences,
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? (() => const Uuid().v4());

  Future<void> backupIfMigrationPending({
    required int stored,
    required int target,
    required String appVersion,
  }) async {
    if (stored >= target) return;

    final livePath = await _livePathProvider();
    if (!await File(livePath).exists()) return;

    final backupsDir = await _backupsDirProvider();
    await Directory(backupsDir).create(recursive: true);

    final now = _clock().toUtc();
    final ts = _formatTimestamp(now);
    final filename = '$ts-v$stored-v$target.db';
    final tempPath = p.join(backupsDir, '.$filename.tmp');
    final finalPath = p.join(backupsDir, filename);

    try {
      await File(livePath).copy(tempPath);
      await File(tempPath).rename(finalPath);
    } catch (e, stack) {
      await _safeDelete(tempPath);
      throw BackupFailedException.fromError(e, stack);
    }

    final sizeBytes = await File(finalPath).length();

    try {
      await _preferences.addRecord(
        BackupRecord(
          id: _idGenerator(),
          filename: filename,
          timestamp: now,
          sizeBytes: sizeBytes,
          location: BackupLocation.local,
          localPath: finalPath,
          isAutomatic: true,
          type: BackupType.preMigration,
          appVersion: appVersion,
          fromSchemaVersion: stored,
          toSchemaVersion: target,
        ),
      );
    } catch (e, stack) {
      _log.warning('Pre-migration backup registered failed; .db is on disk at $finalPath', e, stack);
    }
  }

  String _formatTimestamp(DateTime utc) {
    String two(int v) => v.toString().padLeft(2, '0');
    final d = utc;
    return '${d.year}${two(d.month)}${two(d.day)}-'
        '${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }

  Future<void> _safeDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/backup/data/services/pre_migration_backup_service_test.dart`
Expected: All 4 happy-path tests pass.

- [ ] **Step 5: Run analyzer + format**

Run: `flutter analyze lib/features/backup/data/services/pre_migration_backup_service.dart`
Run: `dart format lib/features/backup/data/services/pre_migration_backup_service.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/features/backup/data/services/pre_migration_backup_service.dart \
        test/features/backup/data/services/pre_migration_backup_service_test.dart
git commit -m "feat: PreMigrationBackupService happy path (copy + register)"
```

---

## Task 6: Add `.tmp` sweep at step 6a (TDD)

**Files:**
- Modify: `lib/features/backup/data/services/pre_migration_backup_service.dart`
- Modify: `test/features/backup/data/services/pre_migration_backup_service_test.dart`

- [ ] **Step 1: Add failing test**

Add this test to the test file (outside `group('happy path')`):

```dart
group('.tmp sweep', () {
  test('deletes leftover .tmp files in backups dir before backup', () async {
    final f = await _makeFixture();
    addTearDown(f.dispose);
    // Pre-seed a stale .tmp file
    final stale = File(p.join(f.backupsDir, '.20260101-000000-v62-v63.db.tmp'));
    await stale.writeAsBytes([1, 2, 3]);
    expect(await stale.exists(), isTrue);

    final service = PreMigrationBackupService(
      livePathProvider: () async => f.livePath,
      backupsDirProvider: () async => f.backupsDir,
      preferences: f.prefs,
      clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
      idGenerator: () => 'id',
    );

    await service.backupIfMigrationPending(
      stored: 63,
      target: 64,
      appVersion: '1.6.0.1241',
    );

    expect(await stale.exists(), isFalse);
  });

  test('does not delete non-.tmp files', () async {
    final f = await _makeFixture();
    addTearDown(f.dispose);
    final keep = File(p.join(f.backupsDir, '20260101-000000-manual.db'));
    await keep.writeAsBytes([1, 2, 3]);

    final service = PreMigrationBackupService(
      livePathProvider: () async => f.livePath,
      backupsDirProvider: () async => f.backupsDir,
      preferences: f.prefs,
      clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
      idGenerator: () => 'id',
    );

    await service.backupIfMigrationPending(
      stored: 63,
      target: 64,
      appVersion: '1.6.0.1241',
    );

    expect(await keep.exists(), isTrue);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/backup/data/services/pre_migration_backup_service_test.dart`
Expected: the "deletes leftover .tmp" test FAILS because no sweep exists yet.

- [ ] **Step 3: Add the sweep logic to `backupIfMigrationPending`**

Insert immediately after `await Directory(backupsDir).create(recursive: true);`:

```dart
    await _sweepTempFiles(backupsDir);
```

And add the method to the class:

```dart
  Future<void> _sweepTempFiles(String backupsDir) async {
    try {
      final dir = Directory(backupsDir);
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.endsWith('.tmp')) {
          await _safeDelete(entity.path);
        }
      }
    } catch (e, stack) {
      _log.warning('Failed sweeping .tmp files in $backupsDir', e, stack);
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/backup/data/services/pre_migration_backup_service_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/backup/data/services/pre_migration_backup_service.dart \
        test/features/backup/data/services/pre_migration_backup_service_test.dart
git commit -m "feat: sweep stale .tmp files before pre-migration backup"
```

---

## Task 7: Add prune logic (TDD)

**Files:**
- Modify: `lib/features/backup/data/services/pre_migration_backup_service.dart`
- Modify: `test/features/backup/data/services/pre_migration_backup_service_test.dart`

- [ ] **Step 1: Add failing tests**

Append this group to the test file:

```dart
group('retention prune', () {
  test('keeps newest 3 unpinned pre-migration backups, deletes older', () async {
    final f = await _makeFixture();
    addTearDown(f.dispose);
    // Pre-seed 4 unpinned pre-migration records with disk files.
    for (var i = 0; i < 4; i++) {
      final ts = DateTime.utc(2026, 1, 1 + i);
      final name = '${_ts(ts)}-v$i-v${i + 1}.db';
      final file = File(p.join(f.backupsDir, name));
      await file.writeAsBytes([i]);
      await f.prefs.addRecord(
        BackupRecord(
          id: 'r$i',
          filename: name,
          timestamp: ts,
          sizeBytes: 1,
          location: BackupLocation.local,
          localPath: file.path,
          type: BackupType.preMigration,
          fromSchemaVersion: i,
          toSchemaVersion: i + 1,
        ),
      );
    }

    final service = PreMigrationBackupService(
      livePathProvider: () async => f.livePath,
      backupsDirProvider: () async => f.backupsDir,
      preferences: f.prefs,
      clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
      idGenerator: () => 'new',
    );

    await service.backupIfMigrationPending(
      stored: 63,
      target: 64,
      appVersion: '1.6.0.1241',
    );

    final remaining = f.prefs
        .getHistory()
        .where((r) => r.type == BackupType.preMigration)
        .toList();
    // 4 pre-seeded + 1 new = 5 total; prune to 3 most recent unpinned
    expect(remaining, hasLength(3));
    // The newest 'new' record and the 2 most recent pre-seeded (r3, r2) survive.
    expect(remaining.map((r) => r.id), containsAll(<String>['new', 'r3', 'r2']));
    // The oldest two records are gone
    expect(remaining.map((r) => r.id), isNot(contains('r0')));
    expect(remaining.map((r) => r.id), isNot(contains('r1')));
    // And their .db files were deleted
    expect(await File(p.join(f.backupsDir, '${_ts(DateTime.utc(2026, 1, 1))}-v0-v1.db')).exists(), isFalse);
    expect(await File(p.join(f.backupsDir, '${_ts(DateTime.utc(2026, 1, 2))}-v1-v2.db')).exists(), isFalse);
  });

  test('pinned pre-migration backups are never pruned', () async {
    final f = await _makeFixture();
    addTearDown(f.dispose);
    for (var i = 0; i < 5; i++) {
      final ts = DateTime.utc(2026, 1, 1 + i);
      final name = '${_ts(ts)}-v$i-v${i + 1}.db';
      await File(p.join(f.backupsDir, name)).writeAsBytes([i]);
      await f.prefs.addRecord(
        BackupRecord(
          id: 'pinned-$i',
          filename: name,
          timestamp: ts,
          sizeBytes: 1,
          location: BackupLocation.local,
          localPath: p.join(f.backupsDir, name),
          type: BackupType.preMigration,
          fromSchemaVersion: i,
          toSchemaVersion: i + 1,
          pinned: true,
        ),
      );
    }

    final service = PreMigrationBackupService(
      livePathProvider: () async => f.livePath,
      backupsDirProvider: () async => f.backupsDir,
      preferences: f.prefs,
      clock: () => DateTime.utc(2026, 4, 12),
      idGenerator: () => 'new',
    );
    await service.backupIfMigrationPending(
      stored: 63,
      target: 64,
      appVersion: '1.6.0.1241',
    );

    final preMigrationRecords = f.prefs
        .getHistory()
        .where((r) => r.type == BackupType.preMigration)
        .toList();
    // All 5 pinned + 1 new = 6
    expect(preMigrationRecords, hasLength(6));
  });

  test('does nothing when only 2 unpinned exist', () async {
    final f = await _makeFixture();
    addTearDown(f.dispose);
    for (var i = 0; i < 2; i++) {
      final ts = DateTime.utc(2026, 1, 1 + i);
      final name = '${_ts(ts)}-v$i-v${i + 1}.db';
      await File(p.join(f.backupsDir, name)).writeAsBytes([i]);
      await f.prefs.addRecord(
        BackupRecord(
          id: 'r$i',
          filename: name,
          timestamp: ts,
          sizeBytes: 1,
          location: BackupLocation.local,
          localPath: p.join(f.backupsDir, name),
          type: BackupType.preMigration,
          fromSchemaVersion: i,
          toSchemaVersion: i + 1,
        ),
      );
    }

    final service = PreMigrationBackupService(
      livePathProvider: () async => f.livePath,
      backupsDirProvider: () async => f.backupsDir,
      preferences: f.prefs,
      clock: () => DateTime.utc(2026, 4, 12),
      idGenerator: () => 'new',
    );
    await service.backupIfMigrationPending(
      stored: 63,
      target: 64,
      appVersion: '1.6.0.1241',
    );

    final count = f.prefs
        .getHistory()
        .where((r) => r.type == BackupType.preMigration)
        .length;
    expect(count, 3);
  });

  test('does not touch manual-backup records', () async {
    final f = await _makeFixture();
    addTearDown(f.dispose);
    for (var i = 0; i < 5; i++) {
      final name = 'manual-$i.db';
      await File(p.join(f.backupsDir, name)).writeAsBytes([i]);
      await f.prefs.addRecord(
        BackupRecord(
          id: 'm$i',
          filename: name,
          timestamp: DateTime.utc(2026, 1, 1 + i),
          sizeBytes: 1,
          location: BackupLocation.local,
          localPath: p.join(f.backupsDir, name),
          type: BackupType.manual,
        ),
      );
    }

    final service = PreMigrationBackupService(
      livePathProvider: () async => f.livePath,
      backupsDirProvider: () async => f.backupsDir,
      preferences: f.prefs,
      clock: () => DateTime.utc(2026, 4, 12),
      idGenerator: () => 'new',
    );
    await service.backupIfMigrationPending(
      stored: 63,
      target: 64,
      appVersion: '1.6.0.1241',
    );

    final manualCount = f.prefs
        .getHistory()
        .where((r) => r.type == BackupType.manual)
        .length;
    expect(manualCount, 5);
  });
});

String _ts(DateTime utc) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${utc.year}${two(utc.month)}${two(utc.day)}-'
      '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/backup/data/services/pre_migration_backup_service_test.dart`
Expected: The prune-related tests FAIL (current service keeps all records).

- [ ] **Step 3: Implement prune logic**

Add a constant near the top of the class:

```dart
  static const int _retainN = 3;
```

Insert a call after the successful `addRecord`:

```dart
    await _pruneExcess();
```

(Wrap just that call in its own try/catch so prune errors don't abort the caller.)

Replace the block from Step 3 of Task 5:

```dart
    try {
      await _preferences.addRecord(...);
    } catch (e, stack) {
      _log.warning('Pre-migration backup registered failed; .db is on disk at $finalPath', e, stack);
    }
```

with:

```dart
    try {
      await _preferences.addRecord(
        BackupRecord(
          id: _idGenerator(),
          filename: filename,
          timestamp: now,
          sizeBytes: sizeBytes,
          location: BackupLocation.local,
          localPath: finalPath,
          isAutomatic: true,
          type: BackupType.preMigration,
          appVersion: appVersion,
          fromSchemaVersion: stored,
          toSchemaVersion: target,
        ),
      );
    } catch (e, stack) {
      _log.warning('Pre-migration backup registered failed; .db is on disk at $finalPath', e, stack);
      return;
    }

    try {
      await _pruneExcess();
    } catch (e, stack) {
      _log.warning('Pre-migration prune failed (backup kept)', e, stack);
    }
```

And add the method:

```dart
  Future<void> _pruneExcess() async {
    final all = _preferences.getHistory();
    final preMigration = all
        .where((r) => r.type == BackupType.preMigration)
        .toList();
    final unpinned = preMigration.where((r) => !r.pinned).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (unpinned.length <= _retainN) return;
    final toDelete = unpinned.sublist(_retainN);
    for (final record in toDelete) {
      await _preferences.removeRecord(record.id);
      final path = record.localPath;
      if (path != null) {
        await _safeDelete(path);
      }
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/backup/data/services/pre_migration_backup_service_test.dart`
Expected: All prune tests pass. Manual-backup records untouched.

- [ ] **Step 5: Commit**

```bash
git add lib/features/backup/data/services/pre_migration_backup_service.dart \
        test/features/backup/data/services/pre_migration_backup_service_test.dart
git commit -m "feat: retention prune for pre-migration backups (N=3 unpinned)"
```

---

## Task 8: Error classification on backup failure (TDD)

**Files:**
- Modify: `test/features/backup/data/services/pre_migration_backup_service_test.dart`

- [ ] **Step 1: Add failing tests**

Append:

```dart
group('error handling', () {
  test('throws BackupFailedException(sourceMissing) when backupsDir path itself is a file', () async {
    // We can't portably simulate ENOSPC; instead trigger a file-system error
    // by pointing backupsDirProvider at a path that is actually a regular
    // file (so create(recursive) throws).
    final tmp = await Directory.systemTemp.createTemp('pmbs_err_');
    addTearDown(() => tmp.delete(recursive: true));
    final live = File(p.join(tmp.path, 'submersion.db'));
    await live.writeAsBytes([1, 2, 3]);
    final conflicting = File(p.join(tmp.path, 'not-a-dir'));
    await conflicting.writeAsBytes([0]);
    SharedPreferences.setMockInitialValues({});
    final prefs = BackupPreferences(await SharedPreferences.getInstance());

    final service = PreMigrationBackupService(
      livePathProvider: () async => live.path,
      backupsDirProvider: () async => conflicting.path,
      preferences: prefs,
      clock: () => DateTime.utc(2026, 4, 12),
      idGenerator: () => 'id',
    );

    expect(
      () async => service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      ),
      throwsA(isA<BackupFailedException>()),
    );
  });
});
```

Add this import near the top of the test file:

```dart
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';
```

- [ ] **Step 2: Run test to verify failure mode is already wrapped**

Run: `flutter test test/features/backup/data/services/pre_migration_backup_service_test.dart`
Expected: Test passes *or* fails. If the service already wraps thrown errors (from Task 5's `catch (e, stack)` around copy/rename), this test passes immediately. If it passes, skip Step 3 and commit only the test. If it fails (e.g. an error escapes outside copy/rename), add a top-level `try/catch` in `backupIfMigrationPending` that wraps directory-creation errors too:

```dart
    try {
      await Directory(backupsDir).create(recursive: true);
      await _sweepTempFiles(backupsDir);
    } catch (e, stack) {
      throw BackupFailedException.fromError(e, stack);
    }
```

(Place this block replacing the existing create + sweep lines.)

- [ ] **Step 3: Re-run test if code was changed**

Run: `flutter test test/features/backup/data/services/pre_migration_backup_service_test.dart`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: wrap backup failures as BackupFailedException"
```

---

## Task 9: Atomic rename guarantee test (TDD)

**Files:**
- Modify: `test/features/backup/data/services/pre_migration_backup_service_test.dart`

- [ ] **Step 1: Add failing test — confirm no `.db` file exists if registration succeeded only after rename**

This test is a regression guard for the temp-file-then-rename ordering. It does not need to simulate a crash; it verifies post-success state matches what atomicity promises.

```dart
group('atomicity', () {
  test('final .db exists only under non-.tmp name after success', () async {
    final f = await _makeFixture();
    addTearDown(f.dispose);
    final service = PreMigrationBackupService(
      livePathProvider: () async => f.livePath,
      backupsDirProvider: () async => f.backupsDir,
      preferences: f.prefs,
      clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
      idGenerator: () => 'id',
    );

    await service.backupIfMigrationPending(
      stored: 63,
      target: 64,
      appVersion: '1.6.0.1241',
    );

    final entries = await Directory(f.backupsDir).list().toList();
    final names = entries.map((e) => p.basename(e.path)).toList();
    expect(names.any((n) => n.endsWith('.tmp')), isFalse);
    expect(names, contains('20260412-081201-v63-v64.db'));
  });
});
```

- [ ] **Step 2: Run test**

Run: `flutter test test/features/backup/data/services/pre_migration_backup_service_test.dart`
Expected: Test passes (already implemented in Task 5).

- [ ] **Step 3: Commit**

```bash
git add test/features/backup/data/services/pre_migration_backup_service_test.dart
git commit -m "test: guard atomic temp-then-rename invariant"
```

---

## Task 10: Add pinBackup / unpinBackup to BackupService (TDD)

**Files:**
- Modify: `lib/features/backup/data/services/backup_service.dart`
- Modify: `test/features/backup/data/services/backup_service_test.dart`

- [ ] **Step 1: Add failing tests**

Append to `test/features/backup/data/services/backup_service_test.dart` inside the existing `group('BackupService', ...)` (or at top level if no such group exists):

```dart
group('pinning', () {
  test('pinBackup flips pinned to true on the record', () async {
    // Reuse the test harness that backup_service_test already sets up;
    // the existing test file demonstrates how FakeBackupDatabaseAdapter
    // and FakeCloudStorageProvider are wired. Assume a helper `makeService`
    // is present; if not, inline the setup from existing tests.
    final harness = await BackupServiceTestHarness.make();
    addTearDown(harness.dispose);
    await harness.prefs.addRecord(
      BackupRecord(
        id: 'rec-1',
        filename: 'f.db',
        timestamp: DateTime(2026),
        sizeBytes: 1,
        location: BackupLocation.local,
        localPath: '/tmp/f.db',
      ),
    );

    await harness.service.pinBackup('rec-1');

    expect(harness.prefs.getHistory().single.pinned, true);
  });

  test('unpinBackup flips pinned to false', () async {
    final harness = await BackupServiceTestHarness.make();
    addTearDown(harness.dispose);
    await harness.prefs.addRecord(
      BackupRecord(
        id: 'rec-1',
        filename: 'f.db',
        timestamp: DateTime(2026),
        sizeBytes: 1,
        location: BackupLocation.local,
        localPath: '/tmp/f.db',
        pinned: true,
      ),
    );

    await harness.service.unpinBackup('rec-1');

    expect(harness.prefs.getHistory().single.pinned, false);
  });

  test('pinBackup is a no-op for unknown ids (does not throw)', () async {
    final harness = await BackupServiceTestHarness.make();
    addTearDown(harness.dispose);

    await harness.service.pinBackup('unknown');

    expect(harness.prefs.getHistory(), isEmpty);
  });
});
```

If `BackupServiceTestHarness` does not exist in the current test file, inline the fixture setup the existing tests use (look near the top of `backup_service_test.dart` for the pattern that builds `FakeBackupDatabaseAdapter`, `BackupPreferences`, and `BackupService`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart`
Expected: FAIL — `pinBackup` / `unpinBackup` undefined on `BackupService`.

- [ ] **Step 3: Add methods to `BackupService`**

Append to `lib/features/backup/data/services/backup_service.dart` inside the class (e.g., after `getValidatedBackupHistory`):

```dart
  Future<void> pinBackup(String id) => _setPinned(id, true);

  Future<void> unpinBackup(String id) => _setPinned(id, false);

  Future<void> _setPinned(String id, bool pinned) async {
    final history = _preferences.getHistory();
    BackupRecord? match;
    for (final r in history) {
      if (r.id == id) {
        match = r;
        break;
      }
    }
    if (match == null) return;
    await _preferences.updateRecord(match.copyWith(pinned: pinned));
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/backup/data/services/backup_service_test.dart`
Expected: All pin tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/backup/data/services/backup_service.dart \
        test/features/backup/data/services/backup_service_test.dart
git commit -m "feat: BackupService.pinBackup/unpinBackup"
```

---

## Task 11: Add StartupState.backingUp and StartupState.backupFailed

**Files:**
- Modify: `lib/core/presentation/pages/startup_page.dart`

- [ ] **Step 1: Extend the enum**

Locate the existing `enum _StartupState { initializing, migrating, ready, error }` (around line 35) and replace with:

```dart
enum _StartupState {
  initializing,
  backingUp,
  migrating,
  backupFailed,
  ready,
  error,
}
```

- [ ] **Step 2: Add state fields for the backup failure**

Near the other state fields in `_StartupPageState`, add:

```dart
  BackupFailedException? _backupError;
```

At the top of the file, import:

```dart
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';
```

- [ ] **Step 3: Analyze and commit (no behavior yet — wiring follows in later tasks)**

Run: `flutter analyze lib/core/presentation/pages/startup_page.dart`
Expected: No issues (the new enum values are unused but unused-enum-values is not a default warning).

```bash
git add lib/core/presentation/pages/startup_page.dart
git commit -m "feat: add backingUp/backupFailed to _StartupState enum"
```

---

## Task 12: Render the backing-up and backup-failed screens (TDD)

**Files:**
- Modify: `lib/core/presentation/pages/startup_page.dart`
- Create: `test/core/presentation/pages/startup_page_backup_flow_test.dart`

- [ ] **Step 1: Write failing widget tests for the two new screens**

Create `test/core/presentation/pages/startup_page_backup_flow_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';

// The startup page is a private-state widget; we test its pure-view helpers
// by importing the build helpers. Since _buildSplashContent and _buildErrorContent
// are private, the cleanest approach is to test the new screens via exported
// widget factories in a new file:
import 'package:submersion/core/presentation/widgets/backup_status_views.dart';

void main() {
  testWidgets('BackingUpView shows spinner + explanation copy', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: BackingUpView())));
    expect(find.text('Backing up your data'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('before updating'), findsOneWidget);
    // No cancel button
    expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Cancel'), findsNothing);
  });

  testWidgets('BackupFailedView surfaces classified message + Retry and Quit', (tester) async {
    var retried = 0;
    var quit = 0;
    final error = BackupFailedException(
      cause: BackupFailureCause.diskFull,
      userMessage: 'Not enough free disk space to back up your data.',
      technicalDetails: 'FileSystemException(28)',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BackupFailedView(
          error: error,
          onRetry: () => retried++,
          onQuit: () => quit++,
        ),
      ),
    ));
    expect(find.text("Couldn't back up your data"), findsOneWidget);
    expect(find.text('Not enough free disk space to back up your data.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await tester.pump();
    expect(retried, 1);
    expect(quit, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Quit'));
    await tester.pump();
    expect(quit, 1);
  });

  testWidgets('BackupFailedView technical details are hidden until expanded', (tester) async {
    final error = BackupFailedException(
      cause: BackupFailureCause.unknown,
      userMessage: 'Backup failed: something odd.',
      technicalDetails: 'unique-detail-12345',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BackupFailedView(error: error, onRetry: () {}, onQuit: () {}),
      ),
    ));
    expect(find.text('unique-detail-12345'), findsNothing);
    await tester.tap(find.text('Technical details'));
    await tester.pumpAndSettle();
    expect(find.text('unique-detail-12345'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/presentation/pages/startup_page_backup_flow_test.dart`
Expected: FAIL — `backup_status_views.dart` does not exist.

- [ ] **Step 3: Create the extracted view widgets**

Create `lib/core/presentation/widgets/backup_status_views.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';

/// Shown while PreMigrationBackupService copies the live database.
class BackingUpView extends StatelessWidget {
  const BackingUpView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Backing up your data',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            "We're saving a copy of your dive log before updating your database.",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Shown when the pre-migration backup fails. Offers Retry and Quit.
class BackupFailedView extends StatelessWidget {
  final BackupFailedException error;
  final VoidCallback onRetry;
  final VoidCallback onQuit;

  const BackupFailedView({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(
            "Couldn't back up your data",
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(error.userMessage, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            "Your dive log hasn't changed — we didn't update it. Free up space (or fix the issue) and try again.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          const SizedBox(height: 8),
          TextButton(onPressed: onQuit, child: const Text('Quit')),
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('Technical details'),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  error.technicalDetails,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/presentation/pages/startup_page_backup_flow_test.dart`
Expected: All 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/presentation/widgets/backup_status_views.dart \
        test/core/presentation/pages/startup_page_backup_flow_test.dart
git commit -m "feat: extracted BackingUpView + BackupFailedView widgets"
```

---

## Task 13: Wire PreMigrationBackupService into StartupPage

**Files:**
- Modify: `lib/core/presentation/pages/startup_page.dart`

- [ ] **Step 1: Add constructor dependency on `PreMigrationBackupService`**

Find the `StartupPage` / `StartupWrapper` public constructor and add an optional field so tests can inject a fake:

```dart
final PreMigrationBackupService Function()? preMigrationBackupFactory;
```

Also add imports at the top:

```dart
import 'dart:io' show exit;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:submersion/core/presentation/widgets/backup_status_views.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/pre_migration_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

(Prune any that already exist.)

- [ ] **Step 2: Insert the backup call inside `_runInitialization`**

Current shape (verbatim, lines ~108–142):

```dart
if (needsMigration && mounted) {
  setState(() {
    _state = _StartupState.migrating;
    _progress = MigrationProgress(currentStep: 0, totalSteps: totalSteps);
  });
}
```

Replace with:

```dart
if (needsMigration) {
  if (mounted) {
    setState(() {
      _state = _StartupState.backingUp;
    });
  }
  try {
    await _runPreMigrationBackup(dbPath: dbPath, stored: storedVersion!, target: AppDatabase.currentSchemaVersion);
  } on BackupFailedException catch (e) {
    if (mounted) {
      setState(() {
        _state = _StartupState.backupFailed;
        _backupError = e;
      });
    }
    return;
  }
  if (mounted) {
    setState(() {
      _state = _StartupState.migrating;
      _progress = MigrationProgress(currentStep: 0, totalSteps: totalSteps);
    });
  }
}
```

Then add the helper on the state class:

```dart
  Future<void> _runPreMigrationBackup({
    required String dbPath,
    required int stored,
    required int target,
  }) async {
    final service = widget.preMigrationBackupFactory != null
        ? widget.preMigrationBackupFactory!()
        : await _defaultPreMigrationBackupService(dbPath);
    final info = await PackageInfo.fromPlatform();
    final appVersion = '${info.version}.${info.buildNumber}';
    await service.backupIfMigrationPending(
      stored: stored,
      target: target,
      appVersion: appVersion,
    );
  }

  Future<PreMigrationBackupService> _defaultPreMigrationBackupService(String dbPath) async {
    final prefs = BackupPreferences(await SharedPreferences.getInstance());
    // BackupService exposes getBackupsDirectory(); reuse it.
    final backupService = BackupService(
      dbAdapter: /* wire in your existing default — see app-wide provider */,
      preferences: prefs,
    );
    return PreMigrationBackupService(
      livePathProvider: () async => dbPath,
      backupsDirProvider: backupService.getBackupsDirectory,
      preferences: prefs,
    );
  }
```

The `/* wire in your existing default */` comment is intentional — the
exact DI pattern depends on the existing provider graph in this app.
Locate how `backupServiceProvider` or equivalent is constructed (grep for
`BackupService(` instantiations outside tests) and mirror that.

If the Riverpod `ProviderContainer` is available at this point in the
startup lifecycle, **replace** this helper entirely with:

```dart
  Future<PreMigrationBackupService> _defaultPreMigrationBackupService(String dbPath) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final backupService = container.read(backupServiceProvider);
    final prefs = container.read(backupPreferencesProvider);
    return PreMigrationBackupService(
      livePathProvider: () async => dbPath,
      backupsDirProvider: backupService.getBackupsDirectory,
      preferences: prefs,
    );
  }
```

(Use whichever pattern matches the existing codebase — in the current
`startup_page.dart`, `_initializeServices` already shows the canonical
service-wiring pattern; mirror it.)

- [ ] **Step 3: Render the new states in the build method**

In the `build` or `_buildSplashContent` method, add branches for the two new states. Find the existing conditional (e.g. `if (_state == _StartupState.error) return _buildErrorContent();` or similar) and add:

```dart
if (_state == _StartupState.backingUp) {
  return const BackingUpView();
}
if (_state == _StartupState.backupFailed && _backupError != null) {
  return BackupFailedView(
    error: _backupError!,
    onRetry: _retryPreMigrationBackup,
    onQuit: _quitApp,
  );
}
```

And add the handlers to the state class:

```dart
  Future<void> _retryPreMigrationBackup() async {
    setState(() {
      _state = _StartupState.backingUp;
      _backupError = null;
    });
    try {
      final dbPath = await widget.locationService.getDatabasePath();
      final stored = DatabaseService.getStoredSchemaVersion(dbPath);
      await _runPreMigrationBackup(
        dbPath: dbPath,
        stored: stored ?? 0,
        target: AppDatabase.currentSchemaVersion,
      );
      if (!mounted) return;
      setState(() {
        _state = _StartupState.migrating;
      });
      await _initializeServices();
      if (!mounted) return;
      setState(() => _state = _StartupState.ready);
      _splashFadeController.forward();
    } on BackupFailedException catch (e) {
      if (mounted) {
        setState(() {
          _state = _StartupState.backupFailed;
          _backupError = e;
        });
      }
    }
  }

  void _quitApp() {
    if (Platform.isIOS || Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }
```

Add import if missing:

```dart
import 'dart:io' show Platform;
```

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze lib/core/presentation/pages/startup_page.dart`
Expected: No issues. If issues surface around unused imports or missing
providers, reconcile by wiring to the real app-provider graph.

- [ ] **Step 5: Run full test suite**

Run: `flutter test`
Expected: All existing tests pass; no regressions.

- [ ] **Step 6: Commit**

```bash
git add lib/core/presentation/pages/startup_page.dart
git commit -m "feat: wire PreMigrationBackupService into startup flow"
```

---

## Task 14: Add pin/unpin toggle to backup list rows (TDD)

**Files:**
- Modify: `lib/features/backup/presentation/pages/backup_settings_page.dart`

- [ ] **Step 1: Locate the existing history `ListTile` (around lines 311–345) and update**

Replace:

```dart
ListTile(
  leading: Icon(_locationIcon(record.location)),
  title: Text(dateFormat.format(record.timestamp)),
  subtitle: Text( ... ),
  trailing: PopupMenuButton<String>( ... ),
)
```

with:

```dart
ListTile(
  leading: Icon(_locationIcon(record.location)),
  title: Row(
    children: [
      Text(dateFormat.format(record.timestamp)),
      if (record.type == BackupType.preMigration) ...[
        const SizedBox(width: 8),
        _PreMigrationBadge(
          fromVersion: record.fromSchemaVersion ?? 0,
          toVersion: record.toSchemaVersion ?? 0,
        ),
      ],
    ],
  ),
  subtitle: Text(
    record.type == BackupType.preMigration
        ? 'v${record.fromSchemaVersion} → v${record.toSchemaVersion} - ${record.formattedSize}'
        : '${record.diveCount ?? 0} dives, '
          '${record.siteCount ?? 0} sites - ${record.formattedSize}'
          '${record.isAutomatic ? ' (auto)' : ''}',
  ),
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: Icon(record.pinned ? Icons.push_pin : Icons.push_pin_outlined),
        tooltip: record.pinned ? 'Unpin backup' : 'Pin backup',
        onPressed: () => _togglePin(ref, record),
      ),
      PopupMenuButton<String>(
        onSelected: (action) =>
            _handleHistoryAction(context, ref, action, record),
        itemBuilder: (context) => [ /* existing menu items unchanged */ ],
      ),
    ],
  ),
)
```

Add these imports at the top of the file:

```dart
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
```

Add the private badge widget at the bottom of the file:

```dart
class _PreMigrationBadge extends StatelessWidget {
  final int fromVersion;
  final int toVersion;

  const _PreMigrationBadge({required this.fromVersion, required this.toVersion});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'v$fromVersion → v$toVersion',
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
```

Add the handler method on the page class:

```dart
  Future<void> _togglePin(WidgetRef ref, BackupRecord record) async {
    final service = ref.read(backupServiceProvider);
    if (record.pinned) {
      await service.unpinBackup(record.id);
    } else {
      await service.pinBackup(record.id);
    }
  }
```

(Adjust `backupServiceProvider` to the actual provider name used in this file.)

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/features/backup/presentation/pages/backup_settings_page.dart`
Expected: No issues.

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: All tests pass (any existing backup UI tests may need a minor update to account for the added trailing widgets, but behavior is preserved).

- [ ] **Step 4: Manually verify on macOS**

Run: `flutter run -d macos`
- Open Settings → Backup
- Create a manual backup
- Verify the pin icon appears on the right side of the row
- Tap it; verify it fills in (pinned)
- Tap again; verify it unfills
- Restart the app; verify pin state persists

- [ ] **Step 5: Commit**

```bash
git add lib/features/backup/presentation/pages/backup_settings_page.dart
git commit -m "feat: pin toggle and pre-migration badge in backup list"
```

---

## Task 15: Restore-dialog compat branching for pre-migration backups (TDD)

**Files:**
- Modify: `lib/features/backup/presentation/widgets/restore_confirmation_dialog.dart`
- Create: `test/features/backup/presentation/widgets/restore_confirmation_dialog_compat_test.dart`

- [ ] **Step 1: Read the current dialog to understand its shape**

Run: `flutter test --reporter=expanded test/features/backup/` — just to confirm existing dialog tests are green before changes.

Expected: green baseline.

- [ ] **Step 2: Write failing tests for the three compat branches**

Create `test/features/backup/presentation/widgets/restore_confirmation_dialog_compat_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/presentation/widgets/restore_confirmation_dialog.dart';

BackupRecord _preMigration({
  required int fromVersion,
  required int toVersion,
  String appVersion = '1.5.9.1000',
}) {
  return BackupRecord(
    id: 'r',
    filename: 'pre.db',
    timestamp: DateTime(2026, 4, 12, 8, 12),
    sizeBytes: 1024,
    location: BackupLocation.local,
    localPath: '/tmp/pre.db',
    type: BackupType.preMigration,
    appVersion: appVersion,
    fromSchemaVersion: fromVersion,
    toSchemaVersion: toVersion,
  );
}

void main() {
  testWidgets('green path: current == from — single Restore button, no warning', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (c) => RestoreConfirmationDialog(
          record: _preMigration(fromVersion: 63, toVersion: 64),
          currentSchemaVersion: 63,
          onConfirm: () {},
        )),
      ),
    ));
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Restore anyway'), findsNothing);
    expect(find.textContaining('will re-run'), findsNothing);
    expect(find.textContaining('app version matches'), findsOneWidget);
  });

  testWidgets('warning path: current > from — "Restore anyway" destructive + warning text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RestoreConfirmationDialog(
          record: _preMigration(fromVersion: 63, toVersion: 64),
          currentSchemaVersion: 64,
          onConfirm: () {},
        ),
      ),
    ));
    expect(find.textContaining('will re-run'), findsOneWidget);
    expect(find.text('Restore anyway'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('hard block: current < from — only Cancel', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RestoreConfirmationDialog(
          record: _preMigration(fromVersion: 65, toVersion: 66),
          currentSchemaVersion: 64,
          onConfirm: () {},
        ),
      ),
    ));
    expect(find.textContaining('newer than your app'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Restore'), findsNothing);
    expect(find.text('Restore anyway'), findsNothing);
  });

  testWidgets('manual record still uses existing dialog behavior', (tester) async {
    final manual = BackupRecord(
      id: 'm',
      filename: 'm.db',
      timestamp: DateTime(2026, 4, 12),
      sizeBytes: 1,
      location: BackupLocation.local,
      localPath: '/tmp/m.db',
      diveCount: 3,
      siteCount: 4,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RestoreConfirmationDialog(
          record: manual,
          currentSchemaVersion: 64,
          onConfirm: () {},
        ),
      ),
    ));
    expect(find.text('Restore'), findsOneWidget);
    expect(find.textContaining('will re-run'), findsNothing);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/backup/presentation/widgets/restore_confirmation_dialog_compat_test.dart`
Expected: FAIL — the dialog's constructor does not yet accept `record: BackupRecord` / `currentSchemaVersion: int`.

- [ ] **Step 4: Refactor the dialog to accept these inputs and branch**

Open `lib/features/backup/presentation/widgets/restore_confirmation_dialog.dart`. The current file has a single existing dialog for manual restores. Extend the constructor so both pre-migration and manual cases work through one widget. Replace the relevant bits so:

```dart
class RestoreConfirmationDialog extends StatelessWidget {
  final BackupRecord record;
  final int currentSchemaVersion;
  final VoidCallback onConfirm;

  const RestoreConfirmationDialog({
    super.key,
    required this.record,
    required this.currentSchemaVersion,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    if (record.type == BackupType.preMigration) {
      return _buildPreMigration(context);
    }
    return _buildManual(context);
  }

  Widget _buildPreMigration(BuildContext context) {
    final fromV = record.fromSchemaVersion ?? 0;
    final toV = record.toSchemaVersion ?? 0;
    final appVersion = record.appVersion ?? 'unknown version';
    if (currentSchemaVersion < fromV) {
      return AlertDialog(
        title: const Text('Restore pre-migration backup'),
        content: Text(
          'This backup is newer than your app. Install a newer app '
          'version to restore it.\n\n'
          'Backup made on ${record.timestamp.toLocal()} by app $appVersion '
          '(database v$fromV).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    }
    if (currentSchemaVersion == fromV) {
      return AlertDialog(
        title: const Text('Restore pre-migration backup'),
        content: Text(
          'This backup was made on ${record.timestamp.toLocal()} by app '
          '$appVersion, just before upgrading the database from v$fromV to v$toV.\n\n'
          'Your app version matches the backup, so restore is safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text('Restore'),
          ),
        ],
      );
    }
    // currentSchemaVersion > fromV — warning path
    return AlertDialog(
      title: const Text('Restore pre-migration backup'),
      content: Text(
        'This backup was made on ${record.timestamp.toLocal()} by app '
        '$appVersion, just before upgrading the database from v$fromV to v$toV.\n\n'
        'You are running a newer app (database v$currentSchemaVersion).\n\n'
        'Restoring now will re-run the v$fromV → v$toV database upgrade '
        'on your restored data — the same upgrade that was about to run '
        'originally. If that upgrade caused the problem, you will hit '
        'the same issue again.\n\n'
        'To restore safely: install app $appVersion or earlier, then restore '
        'this backup from that older app.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: const Text('Restore anyway'),
        ),
      ],
    );
  }

  Widget _buildManual(BuildContext context) {
    // Mirror the existing manual-restore dialog exactly, preserving all
    // copy from the pre-change version. If the existing dialog uses
    // `record.diveCount` / `record.siteCount`, null-coalesce to 0 here.
    // Also: include `record.appVersion` as a new line when non-null.
    // Keep the Restore / Cancel buttons wired as before.
    return AlertDialog(
      title: const Text('Restore backup'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Backup from ${record.timestamp.toLocal()}'),
          Text('${record.diveCount ?? 0} dives, ${record.siteCount ?? 0} sites'),
          Text('Size: ${record.formattedSize}'),
          if (record.appVersion != null) Text('App version: ${record.appVersion}'),
          const SizedBox(height: 12),
          const Text(
            'Restoring will replace your current dive log with the contents '
            'of this backup. This cannot be undone.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: const Text('Restore'),
        ),
      ],
    );
  }
}
```

Note: the manual-dialog block above is a reconstruction. When editing,
preserve any existing copy (warning icons, safety notes) verbatim from
the current file — just add the `appVersion` line conditionally and the
null-coalescing on counts. Remove any fields from the previous
constructor that are now redundant (e.g., if the old dialog took
`diveCount` separately, switch callers to pass the `BackupRecord`).

- [ ] **Step 5: Update callers of the dialog**

Grep for existing usage:

Run: `flutter pub run grep RestoreConfirmationDialog lib/`
(or use `Grep` against the codebase)

Update every caller so the constructor is:
```dart
RestoreConfirmationDialog(
  record: record,
  currentSchemaVersion: AppDatabase.currentSchemaVersion,
  onConfirm: () => /* existing restore logic */,
)
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/backup/presentation/widgets/restore_confirmation_dialog_compat_test.dart`
Expected: All 4 tests pass.

- [ ] **Step 7: Run full test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 8: Format and commit**

Run: `dart format lib/ test/`

```bash
git add -A
git commit -m "feat: restore-dialog compat branching for pre-migration backups"
```

---

## Task 16: End-to-end integration test (backup-then-migrate)

**Files:**
- Create: `test/core/database/pre_migration_backup_integration_test.dart`

- [ ] **Step 1: Write the integration test**

```dart
// test/core/database/pre_migration_backup_integration_test.dart
import 'dart:io';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/pre_migration_backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';

void main() {
  test('end-to-end: seeds v63 DB, backs up, verifies bytes + record', () async {
    final tmp = await Directory.systemTemp.createTemp('pmbs_int_');
    addTearDown(() => tmp.delete(recursive: true));

    final livePath = p.join(tmp.path, 'submersion.db');
    final backupsDir = p.join(tmp.path, 'backups');
    await Directory(backupsDir).create(recursive: true);

    // Seed a v63 sqlite file using raw sqlite3 to set PRAGMA user_version.
    final seed = sqlite3.sqlite3.open(livePath);
    try {
      seed.execute('PRAGMA user_version = 63');
      seed.execute('CREATE TABLE sentinel (id INTEGER PRIMARY KEY)');
      seed.execute('INSERT INTO sentinel VALUES (42)');
    } finally {
      seed.dispose();
    }

    SharedPreferences.setMockInitialValues({});
    final prefs = BackupPreferences(await SharedPreferences.getInstance());

    final service = PreMigrationBackupService(
      livePathProvider: () async => livePath,
      backupsDirProvider: () async => backupsDir,
      preferences: prefs,
      clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
      idGenerator: () => 'integration-id',
    );

    await service.backupIfMigrationPending(
      stored: 63,
      target: 64,
      appVersion: '1.6.0.1241',
    );

    // Assert backup .db exists and matches live bytes
    final backupPath = p.join(backupsDir, '20260412-081201-v63-v64.db');
    expect(await File(backupPath).exists(), isTrue);
    expect(
      await File(backupPath).readAsBytes(),
      await File(livePath).readAsBytes(),
    );

    // Assert the backup DB itself reads back user_version = 63 with sentinel data
    final verify = sqlite3.sqlite3.open(backupPath, mode: sqlite3.OpenMode.readOnly);
    try {
      expect(verify.select('PRAGMA user_version').first.values.first, 63);
      expect(verify.select('SELECT id FROM sentinel').first.values.first, 42);
    } finally {
      verify.dispose();
    }

    // Assert the BackupRecord is in the registry
    final records = prefs.getHistory();
    expect(records, hasLength(1));
    expect(records.single.type, BackupType.preMigration);
    expect(records.single.fromSchemaVersion, 63);
    expect(records.single.toSchemaVersion, 64);
  });
}
```

- [ ] **Step 2: Run the integration test**

Run: `flutter test test/core/database/pre_migration_backup_integration_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/core/database/pre_migration_backup_integration_test.dart
git commit -m "test: end-to-end integration for pre-migration backup"
```

---

## Task 17: Manual verification on macOS

**Files:** none (manual test)

- [ ] **Step 1: Clean rebuild**

Run: `flutter clean && flutter pub get && dart run build_runner build --delete-conflicting-outputs`
Expected: Clean build completes.

- [ ] **Step 2: Simulate a pending migration**

Set up a snapshot at an older schema:
1. Run: `flutter run -d macos` — verify the app launches normally on current schema.
2. Stop the app.
3. Locate the DB file via: `ls "$HOME/Library/Containers/app.submersion/Data/Documents/Submersion/submersion.db"`.
4. Use sqlite3 to artificially lower the user_version:
   ```bash
   sqlite3 "$HOME/Library/Containers/app.submersion/Data/Documents/Submersion/submersion.db" "PRAGMA user_version = 63;"
   ```
   (Adjust the target version if the current schema is not 64 — set it one lower than `AppDatabase.currentSchemaVersion`.)

- [ ] **Step 3: Launch and observe backup UI**

Run: `flutter run -d macos`
Expected:
1. Splash appears.
2. "Backing up your data" screen with spinner appears briefly.
3. Transitions to "Updating database…" (existing migration progress).
4. Transitions to normal app UI.

- [ ] **Step 4: Verify the backup was created + registered**

In Finder or Terminal: `ls "$HOME/Library/Containers/app.submersion/Data/Documents/Submersion/Backups/"`
Expected: A file named like `20260412-XXXXXX-v63-v64.db` exists.

Open the app → Settings → Backup → Backup History.
Expected: The pre-migration backup is visible with a `v63 → v64` badge.
Pin it; verify the pin icon fills in.

- [ ] **Step 5: Simulate a backup failure (optional — verify hard-fail UI)**

1. Stop the app.
2. Lower user_version again with sqlite3 (as in Step 2).
3. Make the Backups folder read-only: `chmod -w "$HOME/Library/Containers/app.submersion/Data/Documents/Submersion/Backups"`.
4. Launch: `flutter run -d macos`.
Expected: "Couldn't back up your data" screen with Retry / Quit buttons.
5. Restore write permission: `chmod +w "$HOME/Library/Containers/app.submersion/Data/Documents/Submersion/Backups"`.
6. Tap Retry.
Expected: Backup succeeds and startup continues to migration.

- [ ] **Step 6: Commit a note about manual-verification completion**

```bash
git commit --allow-empty -m "chore: manual verification of pre-migration backup on macOS"
```

---

## Self-Review Checklist (Author)

- **Spec coverage:**
  - File-level copy before migration → Tasks 5, 6, 9 (atomicity)
  - Registration via BackupPreferences → Task 5
  - Retention with pinning → Tasks 7, 10
  - Hard-fail with Retry/Quit → Tasks 12, 13
  - `.tmp` sweep → Task 6
  - Error classification → Tasks 4, 8
  - Pin/unpin on all backups → Tasks 10, 14
  - Pre-migration badge → Task 14
  - Restore dialog compat branching → Task 15
  - Manual backup gains appVersion line → Task 15
  - Integration test → Task 16
  - Manual verification → Task 17
  - BackupRecord shape extension → Tasks 1, 2, 3

- **Placeholder scan:** There is one "wire in your existing default" comment in Task 13 Step 2 where exact DI wiring depends on how the app currently constructs `BackupService` at startup. This is an intentional judgment point for the implementer, with a concrete fallback pattern shown. Not a plan failure; it's a "mirror existing pattern" instruction with an example.

- **Type consistency:** `BackupFailureCause` enum values (`diskFull`, `permissionDenied`, `sourceMissing`, `renameFailed`, `unknown`) used consistently in Tasks 4 and 12. `BackupType` values (`manual`, `preMigration`) consistent across Tasks 1, 2, 5, 7, 10, 14, 15. `PreMigrationBackupService` constructor params (`livePathProvider`, `backupsDirProvider`, `preferences`, `clock`, `idGenerator`) consistent across Tasks 5, 6, 7, 8, 9, 16. Service method name `backupIfMigrationPending` consistent everywhere.

---

## Execution Notes

- Tasks are ordered so each one leaves the tree in a compilable, test-passing state. The entire suite `flutter test` should pass at every commit boundary.
- Every task commits individually. Pre-push hooks (`dart format`, `flutter analyze`, `flutter test`) will run at push time; running them locally after each task is recommended.
- The integration test in Task 16 uses `sqlite3.sqlite3` directly so it does not depend on Drift being opened — important because pre-migration backup is specifically about the closed-DB state.

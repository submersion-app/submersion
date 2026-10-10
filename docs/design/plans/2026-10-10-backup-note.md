# Backup Notes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in one session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver attach an optional note to a backup from Backup Now and Export Backup, store it on the history record and inside the backup file, and show it in history, the restore dialog and the Unrecognized backups page.

**Architecture:** A new `backup_note_stamp.dart` owns the only SQLite code for notes: it writes a `backup_info` table into a freshly made plaintext backup copy and reads it back. `BackupDatabaseAdapter.backup` takes the note and the real adapter stamps the copy it just produced, so every route (Backup Now, encrypted `.sbe`, SAF, Export to path, Share) carries the note before encryption or streaming. The note is threaded from two new UI entry points (a dialog and a field in the export sheet) through the notifier and service, and is displayed from the record or read back from the file.

**Tech Stack:** Flutter, Riverpod, `sqlite3` (raw handle via `DatabaseService.openRaw`), Drift (live database), `characters`, ARB l10n.

**Spec:** `docs/design/specs/2026-10-10-backup-note-design.md`

## Global Constraints

- Issue: #3204. Release: v1.8.2.
- Table name `backup_info`, columns `key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL`, note row key `note`.
- Notes are trimmed, blank becomes null, capped at 200 characters (grapheme clusters), fixed at creation (no editing).
- Every stamp runs `DROP TABLE IF EXISTS backup_info` first, note or not.
- Notes are written with bound parameters only.
- Automatic, pre-migration and pre-downgrade backups get no note.
- Reading a note never throws; an encrypted, corrupt, missing or table-less file reads as null.
- A failed stamp fails the backup; a failed post-restore drop is only logged.
- No em dashes anywhere. Paths via `p.join`. Temp space via `Directory.systemTemp`.
- New user-facing strings in `app_en.arb` and all 10 other locale ARBs.
- After every task: `dart format .`, `flutter analyze`, the task's tests.

## Refinement over the spec

The spec has `BackupTarget.write` and the service stamp "right after `adapter.backup(...)`". The plan moves the stamp one level down, into `DefaultBackupDatabaseAdapter.backup(path, {note})`. Behaviour is identical (the stamp still runs on the plaintext copy before any encryption or streaming), but the 18 test fakes that write non-SQLite placeholder bytes keep working, since they implement `backup` themselves and only record the note. The stamp function itself is covered directly by its own tests.

## Review Focus

- A note containing an apostrophe, quotes, a semicolon or SQL keywords: stored verbatim (bound parameter), never breaks the backup. Owned by Task 2.
- A note of 200+ characters including emoji: capped without splitting a grapheme, so the stored text is valid UTF-16. Owned by Task 2.
- Restoring a noted backup and then taking an automatic backup: the new file has no note. Owned by Task 2 (stamp drops inherited table) and Task 4 (restore drops live table).
- Import of a non-SQLite or `.sbe` file: the restore dialog still opens, with no note. Owned by Task 9 (the existing page test's `picked.db` holds the text `db`).
- Backup Now dialog cancelled: no backup runs. Owned by Task 7.

---

### Task 1: `BackupRecord.note`

**Files:**
- Modify: `lib/features/backup/domain/entities/backup_record.dart`
- Test: `test/features/backup/domain/entities/backup_record_test.dart`

**Interfaces:**
- Produces: `BackupRecord({..., String? note})`, field `final String? note`, `copyWith({..., String? note})`, JSON key `'note'`.

- [ ] **Step 1: Write the failing tests** (append inside `main()`):

```dart
  group('note', () {
    final base = BackupRecord(
      id: 'n',
      filename: 'n.db',
      timestamp: DateTime(2026, 10, 10, 9),
      sizeBytes: 10,
      location: BackupLocation.local,
      note: 'Before the Cozumel trip',
    );

    test('survives a JSON round trip', () {
      final restored = BackupRecord.fromJson(base.toJson());
      expect(restored.note, 'Before the Cozumel trip');
      expect(restored, base);
    });

    test('history written before notes existed loads with no note', () {
      final json = base.toJson()..remove('note');
      expect(BackupRecord.fromJson(json).note, isNull);
    });

    test('copyWith keeps or replaces the note', () {
      expect(base.copyWith(pinned: true).note, 'Before the Cozumel trip');
      expect(base.copyWith(note: 'Other').note, 'Other');
    });

    test('records differing only by note are not equal', () {
      expect(base == base.copyWith(note: 'Other'), isFalse);
    });
  });
```

- [ ] **Step 2: Run, expect FAIL** (`note` is not a parameter):
`flutter test test/features/backup/domain/entities/backup_record_test.dart`

- [ ] **Step 3: Implement.** In `backup_record.dart`:
  - Add `/// Optional text the diver typed when making the backup. Also stored inside the file (see backup_note_stamp.dart).` above a new `final String? note;` after `pinned`.
  - Constructor: `this.note,` after `this.pinned = false,`.
  - `copyWith`: parameter `String? note,` and `note: note ?? this.note,`.
  - `toJson`: `'note': note,`.
  - `fromJson`: `note: json['note'] as String?,`.
  - `props`: add `note` after `pinned`.

- [ ] **Step 4: Run, expect PASS.** Same command.

- [ ] **Step 5: Commit**

```bash
git add lib/features/backup/domain/entities/backup_record.dart test/features/backup/domain/entities/backup_record_test.dart
git commit -m "feat(backup): carry an optional note on BackupRecord"
```

---

### Task 2: Note stamp and read

**Files:**
- Create: `lib/features/backup/data/services/backup_note_stamp.dart`
- Test: `test/features/backup/data/services/backup_note_stamp_test.dart`

**Interfaces:**
- Produces:
  - `const int maxBackupNoteLength = 200;`
  - `const String backupInfoTable = 'backup_info';`
  - `String? normalizeBackupNote(String? note)`
  - `void stampBackupNote(String path, String? note)` (throws on failure)
  - `Future<String?> readBackupNote(String path)` (never throws)

- [ ] **Step 1: Write the failing tests**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/features/backup/data/services/backup_note_stamp.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('backup_note_stamp_test');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// A minimal plaintext database standing in for a VACUUM INTO copy.
  String makeCopy([String name = 'copy.db']) {
    final path = p.join(dir.path, name);
    final db = sqlite3.sqlite3.open(path);
    db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
    db.close();
    return path;
  }

  bool hasInfoTable(String path) {
    final db = sqlite3.sqlite3.open(path, mode: sqlite3.OpenMode.readOnly);
    try {
      return db.select(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        [backupInfoTable],
      ).isNotEmpty;
    } finally {
      db.close();
    }
  }

  group('normalizeBackupNote', () {
    test('trims and turns blank into null', () {
      expect(normalizeBackupNote(null), isNull);
      expect(normalizeBackupNote('   '), isNull);
      expect(normalizeBackupNote('  Before trip \n'), 'Before trip');
    });

    test('caps at the limit without splitting an emoji', () {
      final long = '${'a' * (maxBackupNoteLength - 1)}\u{1F42C}tail';
      final capped = normalizeBackupNote(long)!;
      expect(capped.endsWith('\u{1F42C}'), isTrue);
      expect(capped.runes.last, 0x1F42C);
    });
  });

  group('stamp and read', () {
    test('a stamped note reads back', () async {
      final path = makeCopy();
      stampBackupNote(path, 'Before the Cozumel trip');
      expect(await readBackupNote(path), 'Before the Cozumel trip');
    });

    test('quotes and SQL text are stored verbatim', () async {
      final path = makeCopy();
      const note = "Diver's log; DROP TABLE dives; -- \"x\"";
      stampBackupNote(path, note);
      expect(await readBackupNote(path), note);
      final db = sqlite3.sqlite3.open(path);
      expect(db.select('SELECT COUNT(*) AS c FROM dives').single['c'], 0);
      db.close();
    });

    test('stamping no note removes an inherited table', () async {
      final path = makeCopy();
      stampBackupNote(path, 'Old note');
      stampBackupNote(path, null);
      expect(hasInfoTable(path), isFalse);
      expect(await readBackupNote(path), isNull);
    });

    test('restamping replaces the inherited note', () async {
      final path = makeCopy();
      stampBackupNote(path, 'Old note');
      stampBackupNote(path, 'New note');
      expect(await readBackupNote(path), 'New note');
    });

    test('a blank note stamps no table', () async {
      final path = makeCopy();
      stampBackupNote(path, '   ');
      expect(hasInfoTable(path), isFalse);
    });

    test('stamping a missing file throws', () {
      expect(
        () => stampBackupNote(p.join(dir.path, 'missing.db'), 'x'),
        throwsA(anything),
      );
    });
  });

  group('readBackupNote never throws', () {
    test('missing file', () async {
      expect(await readBackupNote(p.join(dir.path, 'missing.db')), isNull);
    });

    test('a file that is not a database', () async {
      final path = p.join(dir.path, 'garbage.db');
      File(path).writeAsStringSync('not a database');
      expect(await readBackupNote(path), isNull);
    });

    test('an encrypted backup artifact', () async {
      // SBE1 magic followed by padding: recognised as encrypted, never opened.
      final path = p.join(dir.path, 'enc.sbe');
      File(path).writeAsBytesSync([0x53, 0x42, 0x45, 0x31, ...List.filled(256, 0)]);
      expect(await readBackupNote(path), isNull);
    });

    test('a database without the table', () async {
      expect(await readBackupNote(makeCopy()), isNull);
    });
  });
}
```

The fixture's first four bytes are `SyncEnvelope.magic` (`SBE1`, `lib/core/services/sync/crypto/sync_envelope.dart:17`) and it is longer than the 25-byte fixed header `BackupCrypto.isEncryptedBackup` requires, so it is recognised as encrypted and never opened.

- [ ] **Step 2: Run, expect FAIL** (file missing):
`flutter test test/features/backup/data/services/backup_note_stamp_test.dart`

- [ ] **Step 3: Implement** `backup_note_stamp.dart`:

```dart
import 'dart:io';

import 'package:characters/characters.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/backup/data/services/backup_crypto.dart';

/// Longest note a diver can attach to a backup, in user-perceived characters.
const int maxBackupNoteLength = 200;

/// Table that carries a backup's note inside the backup file itself.
///
/// It is not part of the Drift schema and exists only in backup copies: the
/// copy is stamped right after it is made, and a restore drops it from the
/// live database. The note lives in the file, not only in the history record,
/// so it survives a share, a SAF folder, a cloud upload and a reinstall.
const String backupInfoTable = 'backup_info';

const String _noteKey = 'note';

/// Trims [note], turns a blank one into null and caps it at
/// [maxBackupNoteLength] grapheme clusters, so an emoji is never split.
String? normalizeBackupNote(String? note) {
  final trimmed = note?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final characters = trimmed.characters;
  if (characters.length <= maxBackupNoteLength) return trimmed;
  return characters.take(maxBackupNoteLength).toString().trimRight();
}

/// Writes [note] into the plaintext backup copy at [path].
///
/// Always drops the table first. A copy of a database that was itself restored
/// from a noted backup would otherwise carry that old note forward, including
/// into an automatic backup that has no note of its own.
///
/// Throws when the copy cannot be opened or written: the caller is making a
/// backup, and one that silently lacks the note the diver typed is worse than
/// a reported failure.
void stampBackupNote(String path, String? note) {
  final normalized = normalizeBackupNote(note);
  final db = DatabaseService.openRaw(path);
  try {
    db.execute('DROP TABLE IF EXISTS $backupInfoTable');
    if (normalized == null) return;
    db.execute(
      'CREATE TABLE $backupInfoTable '
      '(key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)',
    );
    db.execute(
      'INSERT INTO $backupInfoTable (key, value) VALUES (?, ?)',
      [_noteKey, normalized],
    );
  } finally {
    db.close();
  }
}

/// The note stamped into the backup at [path], or null.
///
/// Null covers every file that cannot answer: missing, an encrypted `.sbe`
/// (unreadable before decryption), a SQLCipher copy, a non-database, and a
/// backup made before notes existed. Never throws, since every caller is
/// showing a file and must carry on without the note.
Future<String?> readBackupNote(String path) async {
  try {
    if (!await File(path).exists()) return null;
    if (await BackupCrypto.isEncryptedBackup(path)) return null;
    final db = DatabaseService.openRaw(path, mode: sqlite3.OpenMode.readOnly);
    try {
      final table = db.select(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        [backupInfoTable],
      );
      if (table.isEmpty) return null;
      final rows = db.select(
        'SELECT value FROM $backupInfoTable WHERE key = ?',
        [_noteKey],
      );
      if (rows.isEmpty) return null;
      return normalizeBackupNote(rows.first['value'] as String?);
    } finally {
      db.close();
    }
  } catch (_) {
    return null;
  }
}
```

`characters` is already a direct dependency (`pubspec.yaml:143`, used by `weight_label.dart` for the same grapheme-safe cap), so no pubspec change is needed.

- [ ] **Step 4: Run, expect PASS.** Same command.

- [ ] **Step 5: Commit**

```bash
git add lib/features/backup/data/services/backup_note_stamp.dart test/features/backup/data/services/backup_note_stamp_test.dart
git commit -m "feat(backup): stamp and read a note inside a backup file"
```

---

### Task 3: The database adapter takes the note

**Files:**
- Modify: `lib/features/backup/data/services/backup_database_adapter.dart`
- Modify (signature only): every `implements BackupDatabaseAdapter` under `test/` (18 files, listed by the grep in Step 1)
- Test: `test/features/backup/data/services/backup_service_test.dart` (fake records the note)

**Interfaces:**
- Consumes: `stampBackupNote` (Task 2).
- Produces: `Future<void> backup(String destinationPath, {String? note})` on `BackupDatabaseAdapter`; `FakeBackupDatabaseAdapter.lastBackupNote` in `backup_service_test.dart`.

- [ ] **Step 1: Change the interface and the real adapter.**

```dart
  /// Writes a portable plaintext copy of the live database to
  /// [destinationPath], with [note] stamped into it (see
  /// `stampBackupNote`). The stamp always runs, so a copy never inherits a
  /// note from a database that was restored from a noted backup.
  Future<void> backup(String destinationPath, {String? note});
```

and in `DefaultBackupDatabaseAdapter`:

```dart
  @override
  Future<void> backup(String destinationPath, {String? note}) async {
    await _dbAdapter.backup(destinationPath);
    stampBackupNote(destinationPath, note);
  }
```

with `import 'package:submersion/features/backup/data/services/backup_note_stamp.dart';`.

- [ ] **Step 2: Update every fake's signature** with a script (keeps each fake's own parameter name):

```bash
grep -rl "implements BackupDatabaseAdapter" test | xargs python3.14 -c '
import re, sys
for path in sys.argv[1:]:
    src = open(path, newline="").read()
    out = re.sub(r"Future<void> backup\(String (\w+)\)", r"Future<void> backup(String \1, {String? note})", src)
    if out != src:
        open(path, "w", newline="").write(out)
        print("updated", path)
'
```

Then `grep -rn "Future<void> backup(" test | grep -v "String? note"` must print nothing. Some fakes may declare it across lines; fix any leftovers by hand.

- [ ] **Step 3: Make the main fake record the note.** In `test/features/backup/data/services/backup_service_test.dart`, `FakeBackupDatabaseAdapter` gets `String? lastBackupNote;` and its `backup` sets `lastBackupNote = note;` next to `lastBackupPath = destinationPath;`.

- [ ] **Step 4: Run** `flutter analyze` (no errors) and `flutter test test/features/backup test/core/services/background_service_backup_test.dart test/features/settings` (all PASS; nothing changed behaviourally yet).

- [ ] **Step 5: Commit**

```bash
git add lib/features/backup/data/services/backup_database_adapter.dart test
git commit -m "feat(backup): stamp the note when the database copy is made"
```

---

### Task 4: Service and targets thread the note; restore drops the table

**Files:**
- Modify: `lib/features/backup/data/services/backup_service.dart`
- Modify: `lib/features/backup/data/services/backup_target.dart`
- Test: `test/features/backup/data/services/backup_service_test.dart`
- Test: `test/features/backup/data/services/backup_target_test.dart`
- Test: `test/features/backup/data/services/backup_encryption_backup_test.dart`
- Modify (override signatures): `test/features/settings/presentation/widgets/sync_library_flows_progress_test.dart:58`, `test/features/settings/presentation/pages/cloud_sync_page_test.dart:137`, `test/features/backup/presentation/providers/backup_providers_backup_test.dart:49`, `test/features/backup/presentation/providers/backup_export_saf_test.dart:50`, `test/features/backup/presentation/pages/backup_settings_page_test.dart:768`

**Interfaces:**
- Consumes: `backup(path, {note})` (Task 3), `normalizeBackupNote`, `backupInfoTable` (Task 2), `BackupRecord.note` (Task 1).
- Produces:
  - `Future<BackupRecord> performBackup({bool isAutomatic = false, String? note})`
  - `Future<BackupRecord> exportBackupToPath(String destinationPath, {String? note})`
  - `Future<File> exportBackupToTemp({String? note})`
  - `BackupTarget.write(BackupDatabaseAdapter adapter, String fileName, {String? note})`

- [ ] **Step 1: Write the failing service tests** in `backup_service_test.dart`.

Inside `group('exportBackupToPath', ...)`:

```dart
      test('passes the note to the copy and records it', () async {
        final tempDir = await Directory.systemTemp.createTemp('backup_test_');
        final destPath = p.join(tempDir.path, 'my_backup.db');
        final service = BackupService(dbAdapter: fakeDb, preferences: preferences);
        try {
          final record = await service.exportBackupToPath(
            destPath,
            note: '  Before the Cozumel trip ',
          );
          expect(fakeDb.lastBackupNote, 'Before the Cozumel trip');
          expect(record.note, 'Before the Cozumel trip');
          expect(preferences.getHistory().single.note, 'Before the Cozumel trip');
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
```

Inside `group('exportBackupToTemp', ...)`:

```dart
      test('passes the note to the copy', () async {
        final service = BackupService(dbAdapter: fakeDb, preferences: preferences);
        await service.exportBackupToTemp(note: 'Shared with my buddy');
        expect(fakeDb.lastBackupNote, 'Shared with my buddy');
      });
```

A new group after `group('restore re-baselines sync', ...)`:

```dart
    group('backup notes', () {
      test('Backup Now passes the note to the copy and records it', () async {
        final service = BackupService(dbAdapter: fakeDb, preferences: preferences);
        final record = await service.performBackup(note: 'Before merging sites');
        expect(fakeDb.lastBackupNote, 'Before merging sites');
        expect(record.note, 'Before merging sites');
        expect(preferences.getHistory().single.note, 'Before merging sites');
      });

      test('an automatic backup carries no note', () async {
        final service = BackupService(dbAdapter: fakeDb, preferences: preferences);
        final record = await service.performBackup(isAutomatic: true);
        expect(fakeDb.lastBackupNote, isNull);
        expect(record.note, isNull);
      });

      test('a restore drops the note table from the live database', () async {
        final live = createTestDatabase();
        addTearDown(live.close);
        await live.customStatement(
          'CREATE TABLE backup_info (key TEXT PRIMARY KEY NOT NULL, '
          'value TEXT NOT NULL)',
        );
        final adapter = _LiveDatabaseAdapter(live);
        final service = BackupService(
          dbAdapter: adapter,
          preferences: preferences,
          syncRepository: _SpySyncRepository(),
        );
        final src = File(
          p.join(
            _isolatedTempDir.path,
            'note_restore_${DateTime.now().microsecondsSinceEpoch}.db',
          ),
        );
        await src.writeAsString('db');
        addTearDown(() async {
          if (await src.exists()) await src.delete();
        });

        await service.restoreFromFile(src.path);

        final rows = await live
            .customSelect(
              "SELECT 1 FROM sqlite_master WHERE type = 'table' "
              "AND name = 'backup_info'",
            )
            .get();
        expect(rows, isEmpty);
      });
    });
```

Add near the other test doubles:

```dart
/// A fake whose live database is real, for checks on what a restore leaves in
/// it.
class _LiveDatabaseAdapter extends FakeBackupDatabaseAdapter {
  _LiveDatabaseAdapter(this.live);

  final AppDatabase live;

  @override
  AppDatabase get database => live;
}
```

and `import '../../../../helpers/test_database.dart';`.

- [ ] **Step 2: Write the failing target tests** in `backup_target_test.dart`. Give `_FakeAdapter` a `String? lastNote;` set in `backup` (`lastNote = note;`), then:

```dart
  test('filesystem target hands the note to the copy', () async {
    final dir = Directory.systemTemp.createTempSync('target_note');
    addTearDown(() => dir.deleteSync(recursive: true));
    final db = p.join(dir.path, 'live.db');
    File(db).writeAsStringSync('live');
    final adapter = _FakeAdapter(db);

    await FilesystemBackupTarget(dir.path).write(adapter, 'b.db', note: 'n');

    expect(adapter.lastNote, 'n');
  });

  test('SAF target hands the note to the staged copy', () async {
    final dir = Directory.systemTemp.createTempSync('target_note_saf');
    addTearDown(() => dir.deleteSync(recursive: true));
    final db = p.join(dir.path, 'live.db');
    File(db).writeAsStringSync('live');
    final adapter = _FakeAdapter(db);

    await SafBackupTarget(
      'content://tree/x',
      _FakeSafPort(),
      tempDir: () async => dir,
    ).write(adapter, 'b.db', note: 'n');

    expect(adapter.lastNote, 'n');
  });
```

- [ ] **Step 3: Write the failing encryption test** in `backup_encryption_backup_test.dart`. Add a recording fake beside `_FakeBackupDatabaseAdapter`:

```dart
class _NoteRecordingAdapter extends _FakeBackupDatabaseAdapter {
  String? lastNote;
  String? lastPath;

  @override
  Future<void> backup(String destinationPath, {String? note}) async {
    lastNote = note;
    lastPath = destinationPath;
    await super.backup(destinationPath, note: note);
  }
}
```

and a test next to `'exportBackupToTemp encrypts to .sbe when enabled'`:

```dart
  test('backup encryption ON: the note is stamped into the plaintext copy '
      'before it is encrypted', () async {
    await enableBackupEncryption();
    final adapter = _NoteRecordingAdapter();
    final service = BackupService(
      dbAdapter: adapter,
      preferences: preferences,
      backupEncryptionKeyStore: backupKeyStore,
    );

    final record = await service.performBackup(note: 'Encrypted trip');

    expect(adapter.lastNote, 'Encrypted trip');
    expect(adapter.lastPath, endsWith('.db'));
    expect(record.filename, endsWith('.sbe'));
    expect(record.note, 'Encrypted trip');
  });
```

This mirrors the file's `buildService()` (`dbAdapter`, `preferences`, `cloudProvider: cloud`, `backupEncryptionKeyStore`) minus the cloud provider, which this test does not need.

- [ ] **Step 4: Run, expect FAIL** (unknown `note` parameters):
`flutter test test/features/backup/data/services/backup_service_test.dart test/features/backup/data/services/backup_target_test.dart test/features/backup/data/services/backup_encryption_backup_test.dart`

- [ ] **Step 5: Implement in `backup_target.dart`.** Abstract:

```dart
  /// Writes a backup named [fileName] using [adapter] to produce the bytes,
  /// with [note] stamped into the copy.
  Future<BackupWriteResult> write(
    BackupDatabaseAdapter adapter,
    String fileName, {
    String? note,
  });
```

`FilesystemBackupTarget.write(adapter, fileName, {String? note})` calls `await adapter.backup(dest, note: note);`. `SafBackupTarget.write(adapter, fileName, {String? note})` calls `await adapter.backup(staged, note: note);`.

- [ ] **Step 6: Implement in `backup_service.dart`.**
  - Import `backup_note_stamp.dart`.
  - `performBackup({bool isAutomatic = false, String? note})`: compute `final normalizedNote = normalizeBackupNote(note);` and call `_performBackupInto(lease.target, isAutomatic: isAutomatic, note: normalizedNote)`. Doc comment: add "[note] is the diver's optional description, stamped into the file and kept on the record."
  - `_performBackupInto(BackupTarget target, {required bool isAutomatic, String? note})`: plaintext branch `target.write(_dbAdapter, filename, note: note)`; encrypted branch `_dbAdapter.backup(tempPlain, note: note)`; record gets `note: note`.
  - `exportBackupToPath(String destinationPath, {String? note})`: `final normalizedNote = normalizeBackupNote(note);`, both `_dbAdapter.backup(...)` calls pass `note: normalizedNote`, record gets `note: normalizedNote`.
  - `exportBackupToTemp({String? note})`: both `_dbAdapter.backup(...)` calls pass `note: normalizeBackupNote(note)`.
  - In `_replaceDatabaseAndRebaselineSync`, right after `await _dbAdapter.restore(...)`: `await _dropBackupNoteFromLiveDatabase();`, and add:

```dart
  /// A restored backup brings its `backup_info` table into the live database.
  /// Left there, a raw byte copy (the pre-migration backup) would carry that
  /// old note forward. Best effort: every new backup copy drops the table
  /// anyway, so a failure here is logged rather than failing the restore.
  Future<void> _dropBackupNoteFromLiveDatabase() async {
    try {
      await _dbAdapter.database.customStatement(
        'DROP TABLE IF EXISTS $backupInfoTable',
      );
    } catch (e, st) {
      _log.warning(
        'Could not drop the backup note table after restore',
        error: e,
        stackTrace: st,
      );
    }
  }
```

- [ ] **Step 7: Update the five overriding test fakes** listed under Files so they compile: `performBackup({bool isAutomatic = false, String? note})`, `exportBackupToPath(String destinationPath, {String? note})`, `exportBackupToTemp({String? note})`. In `backup_providers_backup_test.dart`, `_FakeBackupService` also gets `String? lastNote;` and sets it in `performBackup`. In `backup_settings_page_test.dart`, `_RecordingRestoreService` gets `String? exportedNote;` set in `exportBackupToPath`. In `backup_export_saf_test.dart`, `_TempExportingBackupService` gets `String? lastNote;` set in `exportBackupToTemp`.

- [ ] **Step 8: Run, expect PASS:** the three test files from Step 4, then `flutter analyze` and `flutter test test/features/backup test/features/settings test/core/services/background_service_backup_test.dart`.

- [ ] **Step 9: Commit**

```bash
git add lib/features/backup/data/services test/features/backup test/features/settings
git commit -m "feat(backup): thread the note through backups and exports"
```

---

### Task 5: Notifier threads the note

**Files:**
- Modify: `lib/features/backup/presentation/providers/backup_providers.dart`
- Test: `test/features/backup/presentation/providers/backup_providers_backup_test.dart`
- Test: `test/features/backup/presentation/providers/backup_export_saf_test.dart`

**Interfaces:**
- Consumes: service signatures (Task 4).
- Produces: `performBackup({String? note})`, `exportToPath(String destinationPath, {String? note})`, `exportForSharing({String? note})`, `exportToSafTree({required String treeUri, required String fileName, String? note})`.

- [ ] **Step 1: Failing tests.** In `backup_providers_backup_test.dart`:

```dart
  test('Backup Now hands the note to the service', () async {
    final container = makeContainer();
    await container
        .read(backupOperationProvider.notifier)
        .performBackup(note: 'Before the trip');
    expect(service.lastNote, 'Before the trip');
  });
```

In `backup_export_saf_test.dart`:

```dart
  test('hands the note to the exported artifact', () async {
    final container = makeContainer();
    await container.read(backupOperationProvider.notifier).exportToSafTree(
      treeUri: 'content://tree/primary%3ABackups',
      fileName: 'submersion_backup_2026-08-16.db',
      note: 'For the dive shop',
    );
    expect(service.lastNote, 'For the dive shop');
  });
```

- [ ] **Step 2: Run, expect FAIL.**
`flutter test test/features/backup/presentation/providers/backup_providers_backup_test.dart test/features/backup/presentation/providers/backup_export_saf_test.dart`

- [ ] **Step 3: Implement.** In `BackupOperationNotifier`: add the `note` parameters above and pass them: `_service.performBackup(note: note)`, `_service.exportBackupToPath(destinationPath, note: note)`, `_service.exportBackupToTemp(note: note)` in both `exportForSharing` and `exportToSafTree`. Doc comments on each mention the optional note.

- [ ] **Step 4: Run, expect PASS.** Same command.

- [ ] **Step 5: Commit**

```bash
git add lib/features/backup/presentation/providers/backup_providers.dart test/features/backup/presentation/providers
git commit -m "feat(backup): pass the note from the backup notifier"
```

---

### Task 6: Strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and `app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces: `backup_note_dialog_title`, `backup_note_label`, `backup_note_hint`, `backup_note_dialog_confirm`.

- [ ] **Step 1: Insert the keys after `"backup_backupNow"` in every ARB** (ARBs are feature-grouped; anchor on that key):

```bash
python3.14 - <<'EOF'
import pathlib
strings = {
  "en": ("Back up now", "Note (optional)", "e.g. Before the Cozumel trip", "Back Up"),
  "ar": ("نسخ احتياطي الآن", "ملاحظة (اختيارية)", "مثال: قبل رحلة كوزوميل", "نسخ احتياطي"),
  "de": ("Jetzt sichern", "Notiz (optional)", "z. B. Vor der Cozumel-Reise", "Sichern"),
  "es": ("Hacer copia ahora", "Nota (opcional)", "p. ej., Antes del viaje a Cozumel", "Hacer copia"),
  "fr": ("Sauvegarder maintenant", "Note (facultative)", "p. ex. Avant le voyage à Cozumel", "Sauvegarder"),
  "he": ("גיבוי עכשיו", "הערה (לא חובה)", "לדוגמה: לפני הטיול לקוזומל", "גיבוי"),
  "hu": ("Mentés most", "Megjegyzés (nem kötelező)", "pl. A cozumeli út előtt", "Mentés"),
  "it": ("Esegui backup ora", "Nota (facoltativa)", "es. Prima del viaggio a Cozumel", "Esegui backup"),
  "nl": ("Nu back-up maken", "Notitie (optioneel)", "bijv. Voor de reis naar Cozumel", "Back-up maken"),
  "pt": ("Fazer backup agora", "Nota (opcional)", "ex.: Antes da viagem a Cozumel", "Fazer backup"),
  "zh": ("立即备份", "备注（可选）", "例如：去科苏梅尔旅行之前", "备份"),
}
keys = ["backup_note_dialog_title", "backup_note_label", "backup_note_hint", "backup_note_dialog_confirm"]
for loc, vals in strings.items():
    path = pathlib.Path(f"lib/l10n/arb/app_{loc}.arb")
    lines = path.read_text(encoding="utf-8").split("\n")
    idx = next(i for i, l in enumerate(lines) if l.lstrip().startswith('"backup_backupNow"'))
    indent = lines[idx][: len(lines[idx]) - len(lines[idx].lstrip())]
    new = [f'{indent}"{k}": "{v}",' for k, v in zip(keys, vals)]
    lines[idx + 1 : idx + 1] = new
    path.write_text("\n".join(lines), encoding="utf-8")
    print("updated", path)
EOF
```

Before running, compare each locale's existing `backup_backupNow` value: if a locale already words "Backup Now" differently (for example de "Jetzt sichern" vs "Backup jetzt erstellen"), reuse that wording for `backup_note_dialog_title` and its verb for `backup_note_dialog_confirm` so the button and the dialog match.

- [ ] **Step 2: Regenerate and check:** `flutter gen-l10n`, then `python3.14 -c "import json,glob;[json.load(open(f,encoding='utf-8')) for f in glob.glob('lib/l10n/arb/*.arb')]"` (all parse), then `flutter analyze`.

- [ ] **Step 3: Run the l10n guards:** `flutter test test/l10n` (or the directory holding the ARB key-parity tests; find it with `grep -rl "app_en.arb" test | head`).

- [ ] **Step 4: Commit**

```bash
git add lib/l10n
git commit -m "feat(backup): strings for backup notes"
```

---

### Task 7: Note field, Backup Now dialog and wiring

**Files:**
- Create: `lib/features/backup/presentation/widgets/backup_note_field.dart`
- Create: `lib/features/backup/presentation/widgets/backup_note_dialog.dart`
- Modify: `lib/features/backup/presentation/pages/backup_settings_page.dart` (Backup Now `onPressed`)
- Test: `test/features/backup/presentation/widgets/backup_note_dialog_test.dart`
- Test: `test/features/backup/presentation/pages/backup_settings_page_test.dart`

**Interfaces:**
- Consumes: `maxBackupNoteLength`, `normalizeBackupNote` (Task 2), strings (Task 6), `performBackup({note})` (Task 5).
- Produces: `BackupNoteField({required TextEditingController controller, bool autofocus, ValueChanged<String>? onSubmitted})`; `BackupNoteResult(String? note)`; `static Future<BackupNoteResult?> BackupNoteDialog.show(BuildContext)`.

- [ ] **Step 1: Failing dialog tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/presentation/widgets/backup_note_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<BackupNoteResult? Function()> open(WidgetTester tester) async {
    BackupNoteResult? result;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await BackupNoteDialog.show(context);
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () {
      expect(closed, isTrue);
      return result;
    };
  }

  testWidgets('Cancel returns null so no backup runs', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result(), isNull);
  });

  testWidgets('Back Up with an empty field backs up without a note', (
    tester,
  ) async {
    final result = await open(tester);
    await tester.tap(find.text('Back Up'));
    await tester.pumpAndSettle();
    expect(result(), isNotNull);
    expect(result()!.note, isNull);
  });

  testWidgets('the typed note is returned trimmed', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byType(TextField), '  Before the trip  ');
    await tester.tap(find.text('Back Up'));
    await tester.pumpAndSettle();
    expect(result()!.note, 'Before the trip');
  });

  testWidgets('Enter submits', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byType(TextField), 'Quick');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result()!.note, 'Quick');
  });

  testWidgets('the field shows the label and caps its length', (tester) async {
    await open(tester);
    expect(find.text('Note (optional)'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, 200);
  });
}
```

- [ ] **Step 2: Failing page test** in `backup_settings_page_test.dart`, inside `group('BackupSettingsPage restore flows', ...)` (its `buildApp` already overrides `backupServiceProvider` with `_RecordingRestoreService`). Give `_RecordingRestoreService` a `performBackup` override:

```dart
  String? backedUpNote;

  @override
  Future<BackupRecord> performBackup({
    bool isAutomatic = false,
    String? note,
  }) async {
    calls.add('performBackup');
    backedUpNote = note;
    return BackupRecord(
      id: 'now',
      filename: 'now.db',
      timestamp: DateTime(2026, 10, 10),
      sizeBytes: 1,
      location: BackupLocation.local,
      diveCount: 0,
      siteCount: 0,
    );
  }

  @override
  Future<bool> isCloudBackupBlockedByEncryptionLock() async => false;
```

and the tests:

```dart
    testWidgets('Backup Now asks for a note and backs up with it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Backup Now'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Before the trip');
      await tester.tap(find.text('Back Up'));
      await tester.pumpAndSettle();

      expect(service.calls, contains('performBackup'));
      expect(service.backedUpNote, 'Before the trip');
    });

    testWidgets('cancelling the Backup Now dialog backs nothing up', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Backup Now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(service.calls, isNot(contains('performBackup')));
    });
```

If `find.text('Backup Now')` is off screen even at 2400 logical pixels, add `await tester.ensureVisible(find.text('Backup Now'));` before the tap.

- [ ] **Step 3: Run, expect FAIL.**
`flutter test test/features/backup/presentation/widgets/backup_note_dialog_test.dart test/features/backup/presentation/pages/backup_settings_page_test.dart`

- [ ] **Step 4: Implement `backup_note_field.dart`:**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/backup/data/services/backup_note_stamp.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The optional note field shared by the Backup Now dialog and the export
/// sheet, so both offer the same label, hint and length limit.
class BackupNoteField extends StatelessWidget {
  const BackupNoteField({
    super.key,
    required this.controller,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLength: maxBackupNoteLength,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: context.l10n.backup_note_label,
        hintText: context.l10n.backup_note_hint,
      ),
    );
  }
}
```

- [ ] **Step 5: Implement `backup_note_dialog.dart`:**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/backup/data/services/backup_note_stamp.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_note_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the Backup Now dialog decided. [BackupNoteDialog.show] returns null
/// when the diver cancels; a result whose [note] is null means "back up
/// without a note".
class BackupNoteResult {
  const BackupNoteResult(this.note);

  final String? note;
}

/// Asks for an optional note before a manual backup.
class BackupNoteDialog extends StatefulWidget {
  const BackupNoteDialog({super.key});

  static Future<BackupNoteResult?> show(BuildContext context) =>
      showDialog<BackupNoteResult>(
        context: context,
        builder: (_) => const BackupNoteDialog(),
      );

  @override
  State<BackupNoteDialog> createState() => _BackupNoteDialogState();
}

class _BackupNoteDialogState extends State<BackupNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(
    context,
  ).pop(BackupNoteResult(normalizeBackupNote(_controller.text)));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.backup_note_dialog_title),
      content: BackupNoteField(
        controller: _controller,
        autofocus: true,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.backup_note_dialog_confirm),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Wire Backup Now** in `backup_settings_page.dart`. Replace the `onPressed` body `() => ref.read(backupOperationProvider.notifier).performBackup()` with `() => _handleBackupNow(context, ref)`, and add near `_handleExport`:

```dart
  /// Backup Now asks for an optional note first; cancelling backs nothing up.
  Future<void> _handleBackupNow(BuildContext context, WidgetRef ref) async {
    final result = await BackupNoteDialog.show(context);
    if (result == null) return;
    await ref
        .read(backupOperationProvider.notifier)
        .performBackup(note: result.note);
  }
```

Import `backup_note_dialog.dart`.

- [ ] **Step 7: Run, expect PASS.** Same command as Step 3, plus `flutter test test/architecture`.

- [ ] **Step 8: Commit**

```bash
git add lib/features/backup/presentation test/features/backup/presentation
git commit -m "feat(backup): ask for an optional note on Backup Now"
```

---

### Task 8: Export sheet note field and wiring

**Files:**
- Modify: `lib/features/backup/presentation/widgets/export_bottom_sheet.dart`
- Modify: `lib/features/backup/presentation/pages/backup_settings_page.dart` (`_handleExport`)
- Test: `test/features/backup/presentation/widgets/export_bottom_sheet_test.dart` (new)
- Test: `test/features/backup/presentation/pages/backup_settings_page_test.dart`

**Interfaces:**
- Consumes: `BackupNoteField` (Task 7), notifier signatures (Task 5).
- Produces: `ExportBottomSheet({required ValueChanged<String?> onSaveToFile, ValueChanged<String?>? onShare})`; `static void show(BuildContext, {required ValueChanged<String?> onSaveToFile, required ValueChanged<String?> onShare})`.

- [ ] **Step 1: Failing sheet tests** (`export_bottom_sheet_test.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/presentation/widgets/export_bottom_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget host(Widget sheet) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: sheet),
  );

  testWidgets('Save to File receives the trimmed note', (tester) async {
    String? saved = 'unset';
    await tester.pumpWidget(
      host(ExportBottomSheet(onSaveToFile: (note) => saved = note)),
    );
    await tester.enterText(find.byType(TextField), ' For the shop ');
    await tester.tap(find.text('Save to File'));
    expect(saved, 'For the shop');
  });

  testWidgets('Share receives the note', (tester) async {
    String? shared = 'unset';
    await tester.pumpWidget(
      host(
        ExportBottomSheet(
          onSaveToFile: (_) {},
          onShare: (note) => shared = note,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Buddy copy');
    await tester.tap(find.text('Share'));
    expect(shared, 'Buddy copy');
  });

  testWidgets('an untouched field gives no note', (tester) async {
    String? saved = 'unset';
    await tester.pumpWidget(
      host(ExportBottomSheet(onSaveToFile: (note) => saved = note)),
    );
    await tester.tap(find.text('Save to File'));
    expect(saved, isNull);
  });
}
```

- [ ] **Step 2: Failing page test.** In `backup_settings_page_test.dart`, after `'save-to-file picks a folder and streams into it'`:

```dart
    testWidgets('save-to-file carries the typed note', (tester) async {
      mockPicker.directoryPathResult = tempDir.path;

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export Backup'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'For the dive shop');

      await tester.runAsync(() async {
        await tester.tap(find.text('Save to File'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(service.exportedNote, 'For the dive shop');
    });
```

- [ ] **Step 3: Run, expect FAIL.**
`flutter test test/features/backup/presentation/widgets/export_bottom_sheet_test.dart test/features/backup/presentation/pages/backup_settings_page_test.dart`

- [ ] **Step 4: Implement the sheet.** Convert `ExportBottomSheet` to a `StatefulWidget` holding a `TextEditingController` (disposed in `dispose`). Callbacks become `ValueChanged<String?>`; tapping a tile calls `widget.onSaveToFile(normalizeBackupNote(_controller.text))` / `widget.onShare!(...)`. Between the title `Padding` and the first `ListTile`, add:

```dart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BackupNoteField(controller: _controller),
            ),
```

Wrap the sheet's `SafeArea` child in `Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), ...)` so the keyboard does not cover the field, and in `show` pass `isScrollControlled: true` to `showModalBottomSheet`. `show` wraps the callbacks as today: `onSaveToFile: (note) { Navigator.of(context).pop(); onSaveToFile(note); }`, same for share. Update the class doc: "Bottom sheet presenting export options (Save to File and Share) with an optional note for the exported backup."

- [ ] **Step 5: Wire `_handleExport`.** `onSaveToFile: (note) async { ... }` passes `note: note` to `notifier.exportToSafTree(...)` and `notifier.exportToPath(p.join(dir, fileName), note: note)`. `onShare: (note) async { ... exportForSharing(note: note) ... }`.

- [ ] **Step 6: Run, expect PASS.** Same command as Step 3.

- [ ] **Step 7: Commit**

```bash
git add lib/features/backup/presentation test/features/backup/presentation
git commit -m "feat(backup): optional note in the Export Backup sheet"
```

---

### Task 9: Show the note in history and the restore dialog

**Files:**
- Modify: `lib/features/backup/presentation/widgets/backup_history_tile.dart`
- Modify: `lib/features/backup/presentation/widgets/restore_confirmation_dialog.dart`
- Modify: `lib/features/backup/presentation/pages/backup_settings_page.dart` (`_handleImport`)
- Modify: `lib/features/setup_wizard/presentation/widgets/steps/restore_step.dart` (`_pickAndRestore`, the other file-restore entry, same treatment)
- Test: `test/features/backup/presentation/widgets/backup_history_tile_test.dart`
- Test: `test/features/backup/presentation/widgets/restore_confirmation_dialog_test.dart`
- Test: `test/features/backup/presentation/pages/backup_settings_page_test.dart`

**Interfaces:**
- Consumes: `BackupRecord.note` (Task 1), `readBackupNote`, `stampBackupNote` (Task 2).

- [ ] **Step 1: Failing history tile tests.** Add a `String? note` parameter to the `_manual` fixture (passed to `BackupRecord(note: note)`), then:

```dart
    testWidgets('a noted backup shows its note above the counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(note: 'Before the Cozumel trip'),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
          ),
        ),
      );
      expect(find.text('Before the Cozumel trip'), findsOneWidget);
      expect(find.textContaining('5 dives, 3 sites'), findsOneWidget);
      final noteY = tester.getTopLeft(find.text('Before the Cozumel trip')).dy;
      final countsY = tester.getTopLeft(find.textContaining('5 dives')).dy;
      expect(noteY, lessThan(countsY));
    });

    testWidgets('a backup without a note shows only the counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
          ),
        ),
      );
      expect(
        find.byWidgetPredicate((w) => w is Text && w.maxLines == 2),
        findsNothing,
        reason: 'only a note line is capped at two lines',
      );
    });
```

- [ ] **Step 2: Failing restore dialog test.** Give `pumpAndOpen` an optional `BackupRecord? withRecord` and use `withRecord ?? record`, then:

```dart
  testWidgets('the details card shows the backup note', (tester) async {
    await pumpAndOpen(
      tester,
      offerReplace: false,
      withRecord: record.copyWith(note: 'Before the Cozumel trip'),
    );
    expect(find.text('Before the Cozumel trip'), findsOneWidget);
  });
```

- [ ] **Step 3: Failing import test** in `backup_settings_page_test.dart`, in the restore flows group:

```dart
    testWidgets('restore-from-file shows the note inside the picked file', (
      tester,
    ) async {
      // Built synchronously: real file IO in a testWidgets body never
      // completes (fake-async zone).
      final noted = p.join(tempDir.path, 'noted.db');
      final db = sqlite3.sqlite3.open(noted);
      db.execute('CREATE TABLE dives (id TEXT)');
      db.close();
      stampBackupNote(noted, 'Before the Cozumel trip');
      mockPicker.pickFilesResult = [FakePlatformFile(noted, name: 'noted.db')];

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tapImportCard(tester);

      expect(find.text('Restore Backup'), findsOneWidget);
      expect(find.text('Before the Cozumel trip'), findsOneWidget);
    });
```

Add imports for `package:path/path.dart as p` and `package:sqlite3/sqlite3.dart as sqlite3` if missing, and `backup_note_stamp.dart`. The existing `'restore-from-file confirms via the dialog...'` test (its `picked.db` holds the text `db`) is the regression check that a non-database still opens the dialog with no note.

- [ ] **Step 4: Run, expect FAIL.**
`flutter test test/features/backup/presentation/widgets/backup_history_tile_test.dart test/features/backup/presentation/widgets/restore_confirmation_dialog_test.dart test/features/backup/presentation/pages/backup_settings_page_test.dart`

- [ ] **Step 5: Implement the history tile.** Extract the existing `switch` into `final summary = Text(switch (record.type) { ... });`, then:

```dart
      isThreeLine: record.note != null,
      subtitle: record.note == null
          ? summary
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.note!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                summary,
              ],
            ),
```

- [ ] **Step 6: Implement the restore dialog.** In `_buildManual`, after the date `Text` and before `const SizedBox(height: 4)`:

```dart
                  if (record.note != null) ...[
                    const SizedBox(height: 4),
                    Text(record.note!, style: theme.textTheme.bodyMedium),
                  ],
```

- [ ] **Step 7: Read the note on import.** In `_handleImport` (backup settings page) and `_pickAndRestore` (setup wizard restore step), read `final note = await readBackupNote(filePath);` (`picked.path` in the wizard) alongside the existing `length`/`lastModified` reads and pass `note: note` to the temporary `BackupRecord`. Import `backup_note_stamp.dart`.

- [ ] **Step 8: Run, expect PASS.** Same command as Step 4, plus `flutter test test/features/setup_wizard`.

- [ ] **Step 9: Commit**

```bash
git add lib/features/backup/presentation lib/features/setup_wizard test/features/backup/presentation
git commit -m "feat(backup): show a backup's note in history and before restore"
```

---

### Task 10: Show the note on the Unrecognized backups page

**Files:**
- Modify: `lib/features/backup/data/services/orphaned_backup_scan.dart`
- Modify: `lib/features/backup/presentation/pages/unrecognized_backups_page.dart` (`_EntryTile` or the row widget at line ~210)
- Test: `test/features/backup/data/services/orphaned_backup_scan_test.dart`
- Test: `test/features/backup/presentation/pages/unrecognized_backups_page_test.dart`

**Interfaces:**
- Consumes: `readBackupNote`, `stampBackupNote` (Task 2).
- Produces: `UnrecognizedBackup({..., String? note})`; `OrphanedBackupScan({..., Future<String?> Function(String path) readNote = readBackupNote})`.

- [ ] **Step 1: Failing scan test:**

```dart
  test('a plaintext forgotten backup reports its note', () async {
    final name = buildBackupFilename(
      timestamp: '2026-08-31_120000',
      deviceId: thisDevice,
    );
    final path = p.join(backups.path, name);
    final db = sqlite3.sqlite3.open(path);
    db.execute('CREATE TABLE dives (id TEXT)');
    db.close();
    stampBackupNote(path, 'Before the Cozumel trip');

    final found = await build().find();

    expect(found.single.note, 'Before the Cozumel trip');
  });

  test('a file that cannot be read has no note', () async {
    await writeBackup(deviceId: thisDevice, timestamp: '2026-08-31_120000');
    final found = await build().find();
    expect(found.single.note, isNull);
  });
```

(imports: `package:sqlite3/sqlite3.dart as sqlite3`, `backup_note_stamp.dart`).

- [ ] **Step 2: Failing page test.** Give the `entry` helper a `String? note` passed to `UnrecognizedBackup(note: note)`, then:

```dart
  testWidgets('a file with a note shows it', (tester) async {
    await tester.pumpWidget(
      harness(
        entries: () async => [entry(name: 'a.db', note: 'Old laptop backup')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old laptop backup'), findsOneWidget);
  });
```

- [ ] **Step 3: Run, expect FAIL.**
`flutter test test/features/backup/data/services/orphaned_backup_scan_test.dart test/features/backup/presentation/pages/unrecognized_backups_page_test.dart`

- [ ] **Step 4: Implement.**
  - `UnrecognizedBackup`: `this.note,` in the constructor and `/// The note stamped into the file, when it is a readable plaintext backup.` above `final String? note;`.
  - `OrphanedBackupScan`: constructor parameter `Future<String?> Function(String path) readNote = readBackupNote` stored as `_readNote`; in `find()` pass `note: await _readNote(entity.path)` to `UnrecognizedBackup`.
  - Page row: subtitle becomes a `Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [if (entry.note != null) Text(entry.note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium), Text(l10n.backup_unrecognized_fileDetail(...))])` and `isThreeLine: entry.note != null`.

- [ ] **Step 5: Run, expect PASS.** Same command, plus `flutter test test/features/settings/presentation/pages/storage_usage_page_test.dart`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/backup test/features/backup
git commit -m "feat(backup): show embedded notes on the Unrecognized backups page"
```

---

### Task 11: Whole-branch verification

- [ ] `dart format .` (no diff left)
- [ ] `flutter analyze` (no issues)
- [ ] `flutter test test/architecture test/shared` (new files under `lib/` pass the guards)
- [ ] `flutter test test/features/backup test/features/settings test/features/setup_wizard test/core/services` (all green)
- [ ] No em dash (U+2014) added on this branch: `git diff origin/main | python3.14 -c "import sys; bad=[l for l in sys.stdin if l.startswith('+') and chr(0x2014) in l]; print(''.join(bad)); sys.exit(1 if bad else 0)"` exits 0
- [ ] Commit any formatting fixes: `git commit -m "style(backup): format"` only if `dart format` changed files.

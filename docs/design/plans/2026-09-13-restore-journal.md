# Restore Journal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Never delete a `.pre-restore` that may be the only copy of the diver's database, and offer recovery of it on the next launch.

**Architecture:** A new file-only `RestoreJournal` writes a `<db>.restore-pending` marker before a restore moves the live file aside and removes it once the outcome is settled; a `.pre-restore` is deleted only when no marker exists and the live file opens at this schema, and is otherwise renamed to a timestamped name. `DatabaseService.restore()` and its missing-source sweep consult the journal, and `StartupWrapper` asks it, before anything is opened, whether a restore was interrupted, showing a new `InterruptedRestoreView` when one was.

**Tech Stack:** Flutter, Dart, Drift/SQLite (sqlite3 package), flutter_test, gen-l10n ARB localization (11 locales).

**Spec:** `docs/superpowers/specs/2026-09-13-restore-journal-design.md` (issue #1901)

## Global Constraints

- Never write the em-dash character, nor an en-dash or double hyphen used as sentence punctuation, in code, comments, ARB strings, commit messages or PR text.
- No tool or model attribution anywhere: no co-author trailers, no session links, no "Generated with" lines, and none of the names listed in the Attribution section of the project instructions.
- No emojis in code, comments or docs.
- Imports grouped: dart, flutter, packages, local.
- Marker path: `<db>.restore-pending`, content `{"startedAt": "<UTC ISO-8601>"}`.
- Quarantine name: `<path>.<yyyyMMddTHHmmssZ>` (UTC), sidecars `<that>-wal` / `<that>-shm`, collision suffix `-1`, `-2`, ...
- Rejected live file on recovery: `<db>.restore-rejected.<yyyyMMddTHHmmssZ>`.
- Test seam name and shape copied from PR #1856: `Set<String>? debugFailDeleteFor` on `DatabaseService`, checked before the existence test in `_deleteIfExists`, cleared by `resetForTesting`.
- Commit only on this feature branch; commit messages end with `Refs #1901`. The PR body says `Closes #1901` and `Refs #1856`.
- Run `dart format .` before every commit.
- Worktree is already initialized (submodules, `pub get`, `build_runner`). If a DB-touching test fails with `database.g.dart: No such file or directory`, run `bash scripts/setup.sh`.

---

## File Structure

| File | Status | Responsibility |
| --- | --- | --- |
| `lib/core/services/restore_journal.dart` | Create | Marker, classification, quarantine, startup detection, recover / keep-current. Files only. |
| `test/core/services/restore_journal_test.dart` | Create | Unit tests against real temp files with a fake schema reader and clock. |
| `lib/core/services/database_service.dart` | Modify | `debugFailDeleteFor` seam, `restoreJournalFor`, journal use in `restore()` and `_sweepRestoreTempFiles`. |
| `test/core/services/database_service_isolate_test.dart` | Modify | Integration tests through the real `restore()`. |
| `lib/l10n/arb/app_*.arb` (11 files) + generated `app_localizations*.dart` | Modify | `startup_interruptedRestore_*` strings. |
| `lib/core/presentation/widgets/interrupted_restore_view.dart` | Create | The recovery screen. |
| `test/core/presentation/widgets/interrupted_restore_view_test.dart` | Create | View tests. |
| `lib/core/presentation/pages/startup_page.dart` | Modify | New state, detection before the schema probe, two actions, `restoreJournalFactory` seam. |
| `test/core/presentation/pages/startup_page_test.dart` | Modify | Fake journal, default in the builder helper, flow tests. |

---

### Task 1: `RestoreJournal` core (marker, classification, quarantine)

**Files:**
- Create: `lib/core/services/restore_journal.dart`
- Test: `test/core/services/restore_journal_test.dart`

**Interfaces:**
- Consumes: `AppDatabase.currentSchemaVersion` (`lib/core/database/database.dart`, a `static const int`).
- Produces:
  - `typedef RestoreSchemaReader = int? Function(String path);`
  - `typedef RestoreFileDeleter = Future<void> Function(String path);`
  - `enum PreRestoreState { none, stale, precious }`
  - `class RestoreJournal` with constructor `RestoreJournal(String dbPath, {required RestoreSchemaReader readSchemaVersion, RestoreFileDeleter? deleteFile, DateTime Function()? now})`, and members `String dbPath`, `String get markerPath`, `String get asidePath`, `List<String> get asideFiles`, `bool get hasMarker`, `Future<void> begin()`, `Future<void> commit()`, `PreRestoreState classifyPreRestore()`, `Future<String> quarantine(String path, {String? prefix})`.

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/restore_journal_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/restore_journal.dart';

void main() {
  const current = AppDatabase.currentSchemaVersion;
  final clock = DateTime.utc(2026, 9, 13, 10, 30, 5);

  late Directory dir;
  late String db;

  // What the fake schema reader reports per path. A path absent from the map
  // reads as null, which is what the real reader returns for a missing file.
  late Map<String, int?> versions;
  // Paths the fake reader cannot open (it throws, as a corrupt or locked file
  // does with the real reader).
  late Set<String> unreadable;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('restore-journal-test');
    db = p.join(dir.path, 'submersion.db');
    versions = {};
    unreadable = {};
  });

  tearDown(() => dir.deleteSync(recursive: true));

  RestoreJournal journal() => RestoreJournal(
    db,
    readSchemaVersion: (path) {
      if (unreadable.contains(path)) throw StateError('cannot open $path');
      return versions[path];
    },
    now: () => clock,
  );

  void touch(String path, [String content = 'x']) =>
      File(path).writeAsStringSync(content);
  bool exists(String path) => File(path).existsSync();
  String read(String path) => File(path).readAsStringSync();

  group('classifyPreRestore', () {
    test('none when nothing is aside', () {
      touch(db);
      versions[db] = current;
      expect(journal().classifyPreRestore(), PreRestoreState.none);
    });

    test('precious whenever the marker exists, even beside a healthy '
        'live file', () {
      touch(db);
      versions[db] = current;
      touch('$db.pre-restore');
      touch('$db.restore-pending');
      expect(journal().classifyPreRestore(), PreRestoreState.precious);
    });

    test('stale without a marker when the live file opens at this schema', () {
      touch(db);
      versions[db] = current;
      touch('$db.pre-restore');
      expect(journal().classifyPreRestore(), PreRestoreState.stale);
    });

    for (final (label, arrange) in <(String, void Function())>[
      ('the live file is missing', () {}),
      ('the live file cannot be opened', () {
        touch(db);
        unreadable.add(db);
      }),
      ('the live file reports no version', () {
        touch(db);
        versions[db] = null;
      }),
      ('the live file reports version 0', () {
        touch(db);
        versions[db] = 0;
      }),
      ('the live file is newer than this build', () {
        touch(db);
        versions[db] = current + 1;
      }),
    ]) {
      test('precious without a marker when $label', () {
        touch('$db.pre-restore');
        arrange();
        expect(journal().classifyPreRestore(), PreRestoreState.precious);
      });
    }

    test('an orphaned aside sidecar counts as something aside', () {
      // Left alone, it would pair with the next swap's aside copy.
      touch(db);
      versions[db] = current;
      touch('$db.pre-restore-wal');
      expect(journal().classifyPreRestore(), PreRestoreState.stale);
    });
  });

  group('quarantine', () {
    test('moves the file and its sidecars to a UTC timestamped name', () async {
      touch('$db.pre-restore', 'main');
      touch('$db.pre-restore-wal', 'wal');
      touch('$db.pre-restore-shm', 'shm');

      final kept = await journal().quarantine('$db.pre-restore');

      expect(kept, '$db.pre-restore.20260913T103005Z');
      expect(read(kept), 'main');
      expect(read('$kept-wal'), 'wal');
      expect(read('$kept-shm'), 'shm');
      expect(exists('$db.pre-restore'), isFalse);
      expect(exists('$db.pre-restore-wal'), isFalse);
      expect(exists('$db.pre-restore-shm'), isFalse);
    });

    test('never overwrites an earlier quarantined copy', () async {
      touch('$db.pre-restore.20260913T103005Z', 'earlier');
      touch('$db.pre-restore', 'later');

      final kept = await journal().quarantine('$db.pre-restore');

      expect(kept, '$db.pre-restore.20260913T103005Z-1');
      expect(read('$db.pre-restore.20260913T103005Z'), 'earlier');
      expect(read(kept), 'later');
    });

    test('names the copy after the prefix when one is given', () async {
      touch(db, 'rejected');

      final kept = await journal().quarantine(
        db,
        prefix: '$db.restore-rejected',
      );

      expect(kept, '$db.restore-rejected.20260913T103005Z');
      expect(read(kept), 'rejected');
      expect(exists(db), isFalse);
    });

    test('moves orphaned sidecars even when the main file is gone', () async {
      touch('$db.pre-restore-wal', 'wal');

      final kept = await journal().quarantine('$db.pre-restore');

      expect(read('$kept-wal'), 'wal');
      expect(exists('$db.pre-restore-wal'), isFalse);
    });
  });

  group('marker', () {
    test('begin records the start time; commit removes the marker', () async {
      final j = journal();

      await j.begin();
      expect(j.hasMarker, isTrue);
      expect(jsonDecode(read(j.markerPath)), {
        'startedAt': '2026-09-13T10:30:05.000Z',
      });

      await j.commit();
      expect(j.hasMarker, isFalse);
    });

    test('commit deletes through the injected deleter', () async {
      final deleted = <String>[];
      final j = RestoreJournal(
        db,
        readSchemaVersion: (_) => null,
        deleteFile: (path) async => deleted.add(path),
      );

      await j.commit();

      expect(deleted, ['$db.restore-pending']);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/services/restore_journal_test.dart`
Expected: FAIL to compile, `Target of URI doesn't exist: 'package:submersion/core/services/restore_journal.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/core/services/restore_journal.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:submersion/core/database/database.dart';

/// Reads `PRAGMA user_version` from the database file at a path. Returns null
/// for a missing file; may throw for a file SQLite cannot open.
typedef RestoreSchemaReader = int? Function(String path);

/// Deletes the file at a path if it exists.
typedef RestoreFileDeleter = Future<void> Function(String path);

/// What an existing `.pre-restore` copy is, as far as the journal can prove.
enum PreRestoreState {
  /// Nothing is aside: no `.pre-restore` and no `.pre-restore-wal`/`-shm`.
  none,

  /// Provably a leftover of a restore that completed. Safe to delete.
  stale,

  /// May be the only copy of the diver's database. Never deleted.
  precious,
}

/// The on-disk journal that tells a restore's leftover from a stranded
/// original (issue #1901).
///
/// `DatabaseService.restore` moves the live database aside to `.pre-restore`
/// before swapping a backup in. When the swap and reopen succeed that copy is
/// garbage, but several failure paths leave it as the ONLY copy of the
/// diver's data, with the database closed. Nothing on disk used to say which,
/// so every later reader guessed "garbage".
///
/// The marker file is the missing commit record: [begin] writes it before the
/// live file moves, and [commit] removes it once the outcome is settled. A
/// marker beside a `.pre-restore` means "never settled". Without a marker (a
/// leftover from a build that predates the journal) the live file is probed
/// instead, which is weaker but still catches a rejected live file.
///
/// File operations only; never opens a drift connection. Every failure mode
/// costs disk space or an extra prompt, never data: nothing classified
/// [PreRestoreState.precious] is ever deleted here.
class RestoreJournal {
  RestoreJournal(
    this.dbPath, {
    required RestoreSchemaReader readSchemaVersion,
    RestoreFileDeleter? deleteFile,
    DateTime Function()? now,
  }) : _readSchemaVersion = readSchemaVersion,
       _deleteFile = deleteFile ?? _deleteIfExists,
       _now = now ?? DateTime.now;

  final String dbPath;
  final RestoreSchemaReader _readSchemaVersion;
  final RestoreFileDeleter _deleteFile;
  final DateTime Function() _now;

  static const _sidecarSuffixes = ['-wal', '-shm'];

  String get markerPath => '$dbPath.restore-pending';

  String get asidePath => '$dbPath.pre-restore';

  /// The aside copy and its sidecars, in the order a cleanup deletes them.
  List<String> get asideFiles => _withSidecars(asidePath);

  bool get hasMarker => File(markerPath).existsSync();

  /// Opens this restore's journal entry. Flushed, because the marker is only
  /// worth anything if it survives the crash it exists for.
  Future<void> begin() async {
    final startedAt = _now().toUtc().toIso8601String();
    await File(
      markerPath,
    ).writeAsString(jsonEncode({'startedAt': startedAt}), flush: true);
  }

  /// Settles the journal entry: from here on a `.pre-restore` is provably a
  /// leftover.
  Future<void> commit() => _deleteFile(markerPath);

  /// Whether the aside copy may be deleted. See [PreRestoreState].
  PreRestoreState classifyPreRestore() {
    if (!_anyExists(asidePath)) return PreRestoreState.none;
    if (hasMarker) return PreRestoreState.precious;
    return _opensHere(dbPath) ? PreRestoreState.stale : PreRestoreState.precious;
  }

  /// Moves [path] and its sidecars to `<prefix or path>.<UTC timestamp>`,
  /// never over an existing file, and returns the new main path.
  ///
  /// Tolerates a missing main file so an orphaned sidecar can be moved out of
  /// the way too. Main file first, then sidecars, matching the order the
  /// restore swap itself uses.
  Future<String> quarantine(String path, {String? prefix}) async {
    final base = '${prefix ?? path}.${_stamp(_now().toUtc())}';
    var target = base;
    for (var n = 1; _anyExists(target); n++) {
      target = '$base-$n';
    }
    final main = File(path);
    if (main.existsSync()) await main.rename(target);
    for (final suffix in _sidecarSuffixes) {
      final sidecar = File('$path$suffix');
      if (sidecar.existsSync()) await sidecar.rename('$target$suffix');
    }
    return target;
  }

  /// True only for a file this build can open: present, readable, and at a
  /// schema in `1..currentSchemaVersion`. Version 0 is a zero-byte or foreign
  /// file, never a Submersion database, so it does not count.
  bool _opensHere(String path) {
    if (!File(path).existsSync()) return false;
    final int? version;
    try {
      version = _readSchemaVersion(path);
    } catch (_) {
      return false;
    }
    return version != null &&
        version >= 1 &&
        version <= AppDatabase.currentSchemaVersion;
  }

  bool _anyExists(String path) =>
      _withSidecars(path).any((candidate) => File(candidate).existsSync());

  static List<String> _withSidecars(String path) => [
    path,
    for (final suffix in _sidecarSuffixes) '$path$suffix',
  ];

  static String _stamp(DateTime utc) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
        '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  static Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/services/restore_journal_test.dart`
Expected: PASS, all tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/core/services/restore_journal.dart test/core/services/restore_journal_test.dart
flutter analyze lib/core/services/restore_journal.dart test/core/services/restore_journal_test.dart
git add lib/core/services/restore_journal.dart test/core/services/restore_journal_test.dart
git commit -m "feat(restore): add a restore journal that tells a leftover from a stranded original

Refs #1901"
```

---

### Task 2: `RestoreJournal` startup API (`findInterrupted`, `recover`, `keepCurrent`)

**Files:**
- Modify: `lib/core/services/restore_journal.dart`
- Test: `test/core/services/restore_journal_test.dart`

**Interfaces:**
- Consumes: everything Task 1 produced.
- Produces:
  - `class InterruptedRestore { const InterruptedRestore({required DateTime? startedAt, required bool liveExists}); final DateTime? startedAt; final bool liveExists; }`
  - `RestoreJournal.findInterrupted()` returning `InterruptedRestore?` (synchronous)
  - `RestoreJournal.recover()` returning `Future<void>`
  - `RestoreJournal.keepCurrent()` returning `Future<void>`

- [ ] **Step 1: Write the failing tests**

Append these groups inside `main()` of `test/core/services/restore_journal_test.dart`, after the `marker` group:

```dart
  group('findInterrupted', () {
    // The state an unsettled restore leaves: the original aside (openable
    // here), a rejected file live, and the marker.
    void stranded({bool marker = true, bool live = true}) {
      touch('$db.pre-restore');
      versions['$db.pre-restore'] = current;
      if (live) {
        touch(db);
        versions[db] = current + 1;
      }
      if (marker) {
        touch(
          '$db.restore-pending',
          jsonEncode({'startedAt': '2026-09-13T10:30:05.000Z'}),
        );
      }
    }

    test('reports a stranded original with its start time', () {
      stranded();
      final found = journal().findInterrupted();
      expect(found, isNotNull);
      expect(found!.startedAt, DateTime.utc(2026, 9, 13, 10, 30, 5));
      expect(found.liveExists, isTrue);
    });

    test('reports an empty live path', () {
      stranded(live: false);
      expect(journal().findInterrupted()!.liveExists, isFalse);
    });

    test('finds a leftover from a build without the journal, undated', () {
      stranded(marker: false);
      final found = journal().findInterrupted();
      expect(found, isNotNull);
      expect(found!.startedAt, isNull);
    });

    test('an unreadable marker still counts, undated', () {
      stranded();
      touch('$db.restore-pending', 'not json');
      expect(journal().findInterrupted()!.startedAt, isNull);
    });

    test('nothing when the aside copy is stale', () {
      touch(db);
      versions[db] = current;
      touch('$db.pre-restore');
      versions['$db.pre-restore'] = current;
      expect(journal().findInterrupted(), isNull);
    });

    test('nothing when this build cannot open the aside copy', () {
      // An offer that fails the same way the database just did would repeat
      // the dead end; the restore guard still protects the file.
      stranded();
      versions['$db.pre-restore'] = current + 1;
      expect(journal().findInterrupted(), isNull);
      expect(exists('$db.pre-restore'), isTrue);
    });

    test('clears a marker with nothing aside', () {
      touch('$db.restore-pending');
      expect(journal().findInterrupted(), isNull);
      expect(exists('$db.restore-pending'), isFalse);
    });
  });

  group('recover', () {
    test('puts the original back and keeps the rejected file', () async {
      touch('$db.pre-restore', 'original');
      touch('$db.pre-restore-wal', 'original-wal');
      touch(db, 'rejected');
      touch('$db-wal', 'rejected-wal');
      touch('$db.restore-pending');

      await journal().recover();

      expect(read(db), 'original');
      expect(read('$db-wal'), 'original-wal');
      expect(read('$db.restore-rejected.20260913T103005Z'), 'rejected');
      expect(read('$db.restore-rejected.20260913T103005Z-wal'), 'rejected-wal');
      expect(exists('$db.pre-restore'), isFalse);
      expect(exists('$db.pre-restore-wal'), isFalse);
      expect(exists('$db.restore-pending'), isFalse);
    });

    test('with an empty live path, only moves the original back', () async {
      touch('$db.pre-restore', 'original');
      touch('$db.restore-pending');

      await journal().recover();

      expect(read(db), 'original');
      expect(
        dir.listSync().map((e) => p.basename(e.path)),
        isNot(contains(startsWith('submersion.db.restore-rejected'))),
      );
      expect(exists('$db.restore-pending'), isFalse);
    });

    test('finishes after a crash that already moved the rejected file '
        'away', () async {
      touch('$db.pre-restore', 'original');
      touch(db, 'rejected');
      touch('$db.restore-pending');
      final j = journal();
      // Step 1 ran, then the app died before the original moved back.
      await j.quarantine(db, prefix: '$db.restore-rejected');

      await j.recover();

      expect(read(db), 'original');
      expect(read('$db.restore-rejected.20260913T103005Z'), 'rejected');
      expect(exists('$db.restore-pending'), isFalse);
    });
  });

  group('keepCurrent', () {
    test('keeps the original under a timestamped name and settles the '
        'journal', () async {
      touch('$db.pre-restore', 'original');
      touch(db, 'current');
      touch('$db.restore-pending');

      await journal().keepCurrent();

      expect(read(db), 'current');
      expect(read('$db.pre-restore.20260913T103005Z'), 'original');
      expect(exists('$db.pre-restore'), isFalse);
      expect(exists('$db.restore-pending'), isFalse);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/services/restore_journal_test.dart`
Expected: FAIL to compile, `The method 'findInterrupted' isn't defined for the type 'RestoreJournal'` (and likewise `recover`, `keepCurrent`).

- [ ] **Step 3: Write the implementation**

In `lib/core/services/restore_journal.dart`, add this class directly after the `PreRestoreState` enum:

```dart
/// An interrupted restore found at startup: the previous database is still
/// aside, may be the only copy, and this build can open it.
class InterruptedRestore {
  const InterruptedRestore({required this.startedAt, required this.liveExists});

  /// When the unsettled restore began, or null when unknown (a leftover from a
  /// build without the journal, or an unreadable marker).
  final DateTime? startedAt;

  /// Whether a file sits at the live path now. False means only recovery
  /// makes sense: keeping "what is there" would be an empty library.
  final bool liveExists;
}
```

Then add these members to `RestoreJournal`, directly after `quarantine`:

```dart
  /// Asks, before anything is opened, whether an earlier restore stopped with
  /// the diver's previous database still aside.
  ///
  /// Null unless the aside copy is [PreRestoreState.precious] AND this build
  /// can open it. A marker with nothing aside is an orphan and is cleared.
  /// Synchronous on purpose, like the startup page's other pre-open probes:
  /// the async form left widget tests pumping until their timeout.
  InterruptedRestore? findInterrupted() {
    if (!File(asidePath).existsSync()) {
      _clearOrphanMarker();
      return null;
    }
    if (classifyPreRestore() != PreRestoreState.precious) return null;
    if (!_opensHere(asidePath)) return null;
    return InterruptedRestore(
      startedAt: _readStartedAt(),
      liveExists: File(dbPath).existsSync(),
    );
  }

  /// Puts the aside copy back as the live database. The database must be
  /// closed.
  ///
  /// Whatever is live now is kept as `.restore-rejected.<timestamp>`, not
  /// deleted: it may be the backup the diver meant to restore. Safe to retry:
  /// after a crash between the two moves the live path is empty, so the first
  /// step has nothing to do.
  Future<void> recover() async {
    if (_anyExists(dbPath)) {
      await quarantine(dbPath, prefix: '$dbPath.restore-rejected');
    }
    await File(asidePath).rename(dbPath);
    for (final suffix in _sidecarSuffixes) {
      final sidecar = File('$asidePath$suffix');
      if (sidecar.existsSync()) await sidecar.rename('$dbPath$suffix');
    }
    await commit();
  }

  /// Keeps what is live now and moves the aside copy out of the way under a
  /// timestamped name, then settles the journal.
  Future<void> keepCurrent() async {
    await quarantine(asidePath);
    await commit();
  }

  DateTime? _readStartedAt() {
    try {
      final decoded = jsonDecode(File(markerPath).readAsStringSync());
      if (decoded is! Map) return null;
      final raw = decoded['startedAt'];
      return raw is String ? DateTime.tryParse(raw) : null;
    } catch (_) {
      // No marker (a legacy leftover) or unreadable content: the offer still
      // stands, it just cannot name a date.
      return null;
    }
  }

  void _clearOrphanMarker() {
    try {
      final marker = File(markerPath);
      if (marker.existsSync()) marker.deleteSync();
    } catch (_) {
      // Best-effort: an orphan marker is harmless, because every reader
      // requires a `.pre-restore` beside it before it means anything.
    }
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/services/restore_journal_test.dart`
Expected: PASS, all tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/core/services/restore_journal.dart test/core/services/restore_journal_test.dart
flutter analyze lib/core/services/restore_journal.dart test/core/services/restore_journal_test.dart
git add lib/core/services/restore_journal.dart test/core/services/restore_journal_test.dart
git commit -m "feat(restore): detect, recover or keep an interrupted restore's original

Refs #1901"
```

---

### Task 3: Guard `restore()` and the sweep with the journal

**Files:**
- Modify: `lib/core/services/database_service.dart` (imports near line 20; `resetForTesting` at 132-144; `restore()` at 870-1015; helpers at 1017-1051)
- Test: `test/core/services/database_service_isolate_test.dart`

**Interfaces:**
- Consumes: `RestoreJournal`, `PreRestoreState` from Tasks 1-2.
- Produces:
  - `@visibleForTesting Set<String>? debugFailDeleteFor` on `DatabaseService`
  - `RestoreJournal restoreJournalFor(String dbPath)` on `DatabaseService` (Task 5 calls it from the startup page)

- [ ] **Step 1: Add the `debugFailDeleteFor` seam (test infrastructure, no behavior change)**

In `lib/core/services/database_service.dart`, in `resetForTesting()`, after `debugOnRestoreWindowOpen = null;` add:

```dart
    debugFailDeleteFor = null;
```

Replace the existing `_deleteIfExists` method:

```dart
  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
```

with:

```dart
  /// Test seam: paths on which EVERY [_deleteIfExists] call raises instead of
  /// deleting, until the set is cleared, simulating a locked-file condition
  /// that outlasts the restore (e.g. a cloud-sync provider materializing or
  /// evicting the file) that real permission errors on desktop otherwise
  /// need flaky OS-level setup to reproduce. It raises before the existence
  /// check, so a path behaves as present-but-locked whether or not the file
  /// is there. [resetForTesting] also clears it.
  @visibleForTesting
  Set<String>? debugFailDeleteFor;

  Future<void> _deleteIfExists(String path) async {
    if (debugFailDeleteFor?.contains(path) ?? false) {
      throw FileSystemException('debug: simulated delete failure', path);
    }
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
```

This is PR #1856's seam verbatim, so the two branches merge cleanly on it.

- [ ] **Step 2: Write the failing tests**

In `test/core/services/database_service_isolate_test.dart`, add these top-level helpers directly after the `_FakePathProvider` class:

```dart
/// Arranges what a restore that never settled leaves behind: the diver's
/// original at `.pre-restore`, a database this build rejects (one schema too
/// new) at the live path, and, unless [withMarker] is false (a build without
/// the journal), the restore-pending marker. The database must be closed.
void _strandOriginal(String dbPath, {bool withMarker = true}) {
  File(dbPath).renameSync('$dbPath.pre-restore');
  for (final suffix in ['-wal', '-shm']) {
    final sidecar = File('$dbPath$suffix');
    if (sidecar.existsSync()) sidecar.renameSync('$dbPath.pre-restore$suffix');
  }
  final rejected = sqlite3.sqlite3.open(dbPath);
  rejected.execute('CREATE TABLE placeholder (x)');
  rejected.execute(
    'PRAGMA user_version = ${AppDatabase.currentSchemaVersion + 1}',
  );
  rejected.close();
  if (withMarker) {
    File(
      '$dbPath.restore-pending',
    ).writeAsStringSync('{"startedAt":"2026-09-13T10:00:00.000Z"}');
  }
}

/// Main files of every quarantined copy named `<db><infix>...`, excluding
/// their sidecars.
List<String> _quarantinedCopies(String dbPath, String infix) {
  final prefix = '${p.basename(dbPath)}$infix';
  return Directory(p.dirname(dbPath))
      .listSync()
      .whereType<File>()
      .map((f) => f.path)
      .where(
        (path) =>
            p.basename(path).startsWith(prefix) &&
            !path.endsWith('-wal') &&
            !path.endsWith('-shm'),
      )
      .toList();
}

/// Diver names stored in the database file at [path].
List<String> _diverNames(String path) {
  final raw = sqlite3.sqlite3.open(path);
  try {
    return raw
        .select('SELECT name FROM divers')
        .map((row) => row['name'] as String)
        .toList();
  } finally {
    raw.close();
  }
}
```

Then add these tests inside `main()`, directly after the test named `'a failed swap rolls back the WAL sidecar too, not just the main file'`:

```dart
  test('a restore keeps a stranded original instead of deleting it '
      '(#1901)', () async {
    // The startup downgrade restore runs in exactly this state: the rejected
    // file live, nothing open, and the diver's ONLY copy at .pre-restore. The
    // swap used to start by deleting that copy as a "stale leftover".
    final defaultPath = p.join(tempDir.path, 'Submersion', 'submersion.db');
    await DatabaseService.instance.initialize(
      locationService: _FakeLocation(defaultPath),
    );
    await DatabaseService.instance.database
        .customSelect('SELECT 1')
        .getSingle();
    final backupPath = p.join(tempDir.path, 'backup.db');
    await DatabaseService.instance.backup(backupPath);
    final now = DateTime.now();
    await DiverRepository().createDiver(
      domain.Diver(id: '', name: 'Original', createdAt: now, updatedAt: now),
    );
    await DatabaseService.instance.close(strict: true);
    _strandOriginal(defaultPath);

    await DatabaseService.instance.restore(backupPath);

    final kept = _quarantinedCopies(defaultPath, '.pre-restore.');
    expect(kept, hasLength(1), reason: 'the original must be kept aside');
    expect(_diverNames(kept.single), contains('Original'));
    // The restore itself still happened.
    final divers = await DiverRepository().getAllDivers();
    expect(divers.map((d) => d.name), isNot(contains('Original')));
    expect(File('$defaultPath.restore-pending').existsSync(), isFalse);
  });

  test('a stranded original from a build without the journal is kept too, '
      'through the live-file probe', () async {
    final defaultPath = p.join(tempDir.path, 'Submersion', 'submersion.db');
    await DatabaseService.instance.initialize(
      locationService: _FakeLocation(defaultPath),
    );
    await DatabaseService.instance.database
        .customSelect('SELECT 1')
        .getSingle();
    final backupPath = p.join(tempDir.path, 'backup.db');
    await DatabaseService.instance.backup(backupPath);
    final now = DateTime.now();
    await DiverRepository().createDiver(
      domain.Diver(id: '', name: 'Original', createdAt: now, updatedAt: now),
    );
    await DatabaseService.instance.close(strict: true);
    _strandOriginal(defaultPath, withMarker: false);

    await DatabaseService.instance.restore(backupPath);

    final kept = _quarantinedCopies(defaultPath, '.pre-restore.');
    expect(kept, hasLength(1));
    expect(_diverNames(kept.single), contains('Original'));
  });

  test('a newer-schema rollback that stops leaves the journal open, and the '
      'next restore keeps the original', () async {
    final defaultPath = p.join(tempDir.path, 'Submersion', 'submersion.db');
    await DatabaseService.instance.initialize(
      locationService: _FakeLocation(defaultPath),
    );
    await DatabaseService.instance.database
        .customSelect('SELECT 1')
        .getSingle();
    final validBackup = p.join(tempDir.path, 'valid.db');
    await DatabaseService.instance.backup(validBackup);
    final newerBackup = p.join(tempDir.path, 'newer.db');
    File(validBackup).copySync(newerBackup);
    final raw = sqlite3.sqlite3.open(newerBackup);
    raw.execute(
      'PRAGMA user_version = ${AppDatabase.currentSchemaVersion + 1}',
    );
    raw.close();
    final now = DateTime.now();
    await DiverRepository().createDiver(
      domain.Diver(id: '', name: 'Keep Me', createdAt: now, updatedAt: now),
    );

    // Every delete the newer-schema rollback could start with fails, so it
    // stops with the original aside. On main the first strict delete is the
    // live file; after #1856 it is the -wal. Failing all three covers both.
    DatabaseService.instance.debugFailDeleteFor = {
      defaultPath,
      '$defaultPath-wal',
      '$defaultPath-shm',
    };
    await expectLater(
      DatabaseService.instance.restore(newerBackup),
      throwsA(isA<FileSystemException>()),
    );
    expect(File('$defaultPath.pre-restore').existsSync(), isTrue);
    expect(
      File('$defaultPath.restore-pending').existsSync(),
      isTrue,
      reason: 'the original is stranded, so the restore never settled',
    );

    DatabaseService.instance.debugFailDeleteFor = null;
    await DatabaseService.instance.restore(validBackup);

    final kept = _quarantinedCopies(defaultPath, '.pre-restore.');
    expect(kept, hasLength(1));
    expect(_diverNames(kept.single), contains('Keep Me'));
  });

  test('a missing-source sweep leaves a possibly precious .pre-restore '
      'alone', () async {
    final defaultPath = p.join(tempDir.path, 'Submersion', 'submersion.db');
    await DatabaseService.instance.initialize(
      locationService: _FakeLocation(defaultPath),
    );
    await DatabaseService.instance.database
        .customSelect('SELECT 1')
        .getSingle();
    File('$defaultPath.pre-restore').writeAsStringSync('the only copy');
    File('$defaultPath.restore-pending').writeAsStringSync('{}');
    File('$defaultPath.restore-staging').writeAsStringSync('stale');

    await expectLater(
      DatabaseService.instance.restore(p.join(tempDir.path, 'missing.db')),
      throwsA(isA<RestoreSourceMissingException>()),
    );

    expect(
      File('$defaultPath.pre-restore').readAsStringSync(),
      'the only copy',
    );
    expect(File('$defaultPath.restore-pending').existsSync(), isTrue);
    expect(File('$defaultPath.restore-staging').existsSync(), isFalse);
  });

  test('a locked stale leftover aborts the restore before the database '
      'closes', () async {
    final defaultPath = p.join(tempDir.path, 'Submersion', 'submersion.db');
    await DatabaseService.instance.initialize(
      locationService: _FakeLocation(defaultPath),
    );
    await DatabaseService.instance.database
        .customSelect('SELECT 1')
        .getSingle();
    final backupPath = p.join(tempDir.path, 'backup.db');
    await DatabaseService.instance.backup(backupPath);
    final now = DateTime.now();
    await DiverRepository().createDiver(
      domain.Diver(id: '', name: 'Keep Me', createdAt: now, updatedAt: now),
    );
    final asidePath = '$defaultPath.pre-restore';
    File(asidePath).writeAsStringSync('stale');
    DatabaseService.instance.debugFailDeleteFor = {asidePath};
    var windowOpened = false;
    DatabaseService.instance.debugOnRestoreWindowOpen = (_) =>
        windowOpened = true;

    await expectLater(
      DatabaseService.instance.restore(backupPath),
      throwsA(isA<FileSystemException>()),
    );

    expect(
      windowOpened,
      isFalse,
      reason: 'the leftover must be settled while the database is still open',
    );
    final divers = await DiverRepository().getAllDivers();
    expect(divers.map((d) => d.name), contains('Keep Me'));
    expect(File('$defaultPath.restore-staging').existsSync(), isFalse);
    expect(File('$defaultPath.restore-pending').existsSync(), isFalse);
  });

  test('the journal is open during the swap and settled after success', () async {
    final defaultPath = p.join(tempDir.path, 'Submersion', 'submersion.db');
    await DatabaseService.instance.initialize(
      locationService: _FakeLocation(defaultPath),
    );
    await DatabaseService.instance.database
        .customSelect('SELECT 1')
        .getSingle();
    final backupPath = p.join(tempDir.path, 'backup.db');
    await DatabaseService.instance.backup(backupPath);
    var markerDuringWindow = false;
    DatabaseService.instance.debugOnRestoreWindowOpen = (_) {
      markerDuringWindow = File('$defaultPath.restore-pending').existsSync();
    };

    await DatabaseService.instance.restore(backupPath);

    expect(markerDuringWindow, isTrue);
    expect(File('$defaultPath.restore-pending').existsSync(), isFalse);
  });
```

Also add one assertion to each of the two existing rollback tests, so a successful rollback is shown to settle the journal:

- In `'a failed swap rolls back to the original database (no data loss)'`, after `expect(File('$defaultPath.pre-restore').existsSync(), isFalse);` add:

```dart
      expect(File('$defaultPath.restore-pending').existsSync(), isFalse);
```

- In `'a newer-schema file rejected at the post-swap reopen rolls back (no data loss)'`, after `expect(File('$defaultPath.pre-restore').existsSync(), isFalse);` add:

```dart
    expect(File('$defaultPath.restore-pending').existsSync(), isFalse);
```

- [ ] **Step 3: Run the tests to verify the new ones fail**

Run: `flutter test test/core/services/database_service_isolate_test.dart`
Expected: the six new tests FAIL (the two stranded-original tests find no quarantined copy; the rollback-stops test finds no marker; the sweep test finds `.pre-restore` deleted; the locked-leftover test sees `windowOpened` true; the lifecycle test sees no marker during the window). The two amended rollback tests and every pre-existing test PASS.

- [ ] **Step 4: Implement the journal in `restore()`**

1. Add the import (keep the local imports alphabetical), after `restore_source_missing_exception.dart`:

```dart
import 'package:submersion/core/services/restore_journal.dart';
```

2. Add `restoreJournalFor` directly above the `restore()` doc comment (`/// Swap the live database for [backupPath].`):

```dart
  /// The restore journal for the database at [dbPath], probing with the live
  /// key and deleting through [_deleteIfExists] (so [debugFailDeleteFor]
  /// reaches it). Public for the startup screen, which must ask the same
  /// question before anything is opened.
  RestoreJournal restoreJournalFor(String dbPath) => RestoreJournal(
    dbPath,
    readSchemaVersion: (path) =>
        getStoredSchemaVersion(path, keyHex: databaseKeyHex),
    deleteFile: _deleteIfExists,
  );

```

3. In `restore()`, replace:

```dart
    try {
      await backupFile.copy(stagingPath);
    } catch (_) {
      await _deleteIfExists(stagingPath);
      rethrow;
    }

```

with:

```dart
    try {
      await backupFile.copy(stagingPath);
    } catch (_) {
      await _deleteIfExists(stagingPath);
      rethrow;
    }

    // Settle whatever an EARLIER restore left aside, then open this restore's
    // journal entry. Both run while the live database is still open, so a
    // failure here is a plain abort with nothing to roll back. The order
    // matters: a marker written first could pair with an old leftover after a
    // crash, and the next launch would offer to "recover" a database the
    // diver replaced long ago (issue #1901).
    final journal = restoreJournalFor(destinationPath);
    try {
      await _settleLeftoverPreRestore(journal);
      await journal.begin();
    } catch (_) {
      await _bestEffortDelete(stagingPath);
      rethrow;
    }

```

4. Replace:

```dart
    final asidePath = '$destinationPath.pre-restore';
    await _deleteIfExists(asidePath);
    final destFile = File(destinationPath);
```

with:

```dart
    // Nothing to delete here: _settleLeftoverPreRestore already cleared or
    // quarantined this path while the database was still open.
    final asidePath = journal.asidePath;
    final destFile = File(destinationPath);
```

5. In the swap's `catch (_)` block, replace:

```dart
        await _moveIfExists('$asidePath-shm', '$destinationPath-shm');
      }
      await _deleteIfExists(stagingPath);
      await initialize();
      rethrow;
    }
```

with:

```dart
        await _moveIfExists('$asidePath-shm', '$destinationPath-shm');
      }
      await _commitIfNothingAside(journal);
      await _deleteIfExists(stagingPath);
      await initialize();
      rethrow;
    }
```

6. In the `on DatabaseVersionMismatchException` handler, replace:

```dart
        await _moveIfExists('$asidePath-shm', '$destinationPath-shm');
      }
      await initialize();
      rethrow;
    }
```

with:

```dart
        await _moveIfExists('$asidePath-shm', '$destinationPath-shm');
      }
      await _commitIfNothingAside(journal);
      await initialize();
      rethrow;
    }
```

7. Replace the success tail:

```dart
    await _bestEffortDelete(asidePath);
    await _bestEffortDelete('$asidePath-wal');
    await _bestEffortDelete('$asidePath-shm');
  }
```

with:

```dart
    //
    // The journal is settled FIRST: this is the commit point, after which the
    // aside copy is provably a leftover. Best-effort; a marker that survives
    // only costs one unnecessary recovery prompt at the next launch.
    await _bestEffortCommit(journal);
    await _bestEffortDelete(asidePath);
    await _bestEffortDelete('$asidePath-wal');
    await _bestEffortDelete('$asidePath-shm');
  }
```

(The `//` line continues the existing comment block that ends "...swept by the next restore (including a no-op one).")

8. Add these helpers directly after `_bestEffortDelete`:

```dart
  /// Deletes a provably stale `.pre-restore` left by an earlier restore, or
  /// moves a possibly precious one to a timestamped name. Throws on failure,
  /// which aborts the restore before the database is closed.
  Future<void> _settleLeftoverPreRestore(RestoreJournal journal) async {
    switch (journal.classifyPreRestore()) {
      case PreRestoreState.none:
        return;
      case PreRestoreState.stale:
        for (final path in journal.asideFiles) {
          await _deleteIfExists(path);
        }
      case PreRestoreState.precious:
        final kept = await journal.quarantine(journal.asidePath);
        _log.warning(
          'An earlier restore never settled, and its aside copy may be the '
          'only copy of the previous database; kept it at $kept instead of '
          'deleting it',
        );
    }
  }

  /// Settles the journal once a rollback has put everything back: the marker
  /// protects the aside copy, and with nothing aside there is nothing left to
  /// protect. A rollback that could not finish leaves the marker, so the next
  /// launch offers recovery.
  Future<void> _commitIfNothingAside(RestoreJournal journal) async {
    if (journal.classifyPreRestore() == PreRestoreState.none) {
      await _bestEffortCommit(journal);
    }
  }

  Future<void> _bestEffortCommit(RestoreJournal journal) async {
    try {
      await journal.commit();
    } catch (e, stack) {
      _log.warning(
        'Could not clear the restore marker; the next launch may offer to '
        'recover the previous database',
        error: e,
        stackTrace: stack,
      );
    }
  }
```

9. Replace the whole `_sweepRestoreTempFiles` method, from its three-line doc comment (first line `/// Best-effort removal of the temp files a [restore] may leave behind`) through its closing brace (the body is one `_bestEffortDelete` of `.restore-staging` followed by unconditional `_bestEffortDelete`s of `.pre-restore`, `.pre-restore-wal` and `.pre-restore-shm`). Read the method first so the Edit tool's `old_string` matches it byte for byte (its doc comment contains a pre-existing dash character this plan does not reproduce). Replace it with:

```dart
  /// Best-effort removal of the temp files a [restore] may leave behind.
  /// Touches only restore temp files, never the live database, and deletes a
  /// `.pre-restore` (with its sidecars) only when the journal proves it stale.
  /// That matters at startup, where nothing is open and a stranded original
  /// may be the only copy of the diver's data (issue #1901).
  Future<void> _sweepRestoreTempFiles(String destinationPath) async {
    await _bestEffortDelete('$destinationPath.restore-staging');
    final journal = restoreJournalFor(destinationPath);
    final PreRestoreState state;
    try {
      state = journal.classifyPreRestore();
    } catch (_) {
      return;
    }
    if (state != PreRestoreState.stale) return;
    for (final path in journal.asideFiles) {
      await _bestEffortDelete(path);
    }
  }
```

(The new doc comment contains no dash punctuation, per the Global Constraints.)

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/core/services/database_service_isolate_test.dart test/core/services/restore_journal_test.dart`
Expected: PASS, all tests, including the pre-existing sweep tests (their `'stale'` files sit beside a healthy open database, so the probe classifies them stale).

- [ ] **Step 6: Run the rest of the services tests that exercise restore**

Run: `flutter test test/core/services/ test/features/backup/`
Expected: PASS. (No test implements or extends `DatabaseService`, so the new public member breaks no fakes.)

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format lib/core/services/database_service.dart test/core/services/database_service_isolate_test.dart
flutter analyze lib/core/services test/core/services
git add lib/core/services/database_service.dart test/core/services/database_service_isolate_test.dart
git commit -m "fix(restore): never delete a .pre-restore that may be the only copy

restore() settled an earlier restore's aside copy by deleting it, and the
missing-source sweep did the same, even when that copy was the user's
original stranded by a rollback that could not finish. Both now consult the
restore journal: a provably stale leftover is deleted, anything else is kept
under a timestamped name. The leftover is settled before close(), so a
failure there no longer strands a closed database.

Refs #1901"
```

---

### Task 4: `InterruptedRestoreView` and its strings

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb` files, then regenerate `lib/l10n/arb/app_localizations*.dart`
- Create: `lib/core/presentation/widgets/interrupted_restore_view.dart`
- Test: `test/core/presentation/widgets/interrupted_restore_view_test.dart`

**Interfaces:**
- Consumes: `InterruptedRestore` (Task 2), `StartupRestoreStatus` (`lib/core/presentation/startup_restore_status.dart`).
- Produces: `InterruptedRestoreView({Key? key, required InterruptedRestore interrupted, required Color textColor, required Color subtitleColor, required VoidCallback onRecover, required VoidCallback onKeepCurrent, required VoidCallback onClose, StartupRestoreStatus status = StartupRestoreStatus.idle, String? error})`, with button keys `ValueKey('interruptedRestore_recover')` and `ValueKey('interruptedRestore_keep')`. Generated getters `context.l10n.startup_interruptedRestore_title`, `..._body`, `..._bodyWithDate(String date)`, `..._recoverAction`, `..._recoverNote`, `..._keepAction`, `..._keepNote`, `..._failed`.

- [ ] **Step 1: Add the strings to all 11 ARB files**

In every file, insert the block for that locale on new lines immediately AFTER the line that starts with `  "startup_versionMismatch_restore_warning":`. Every inserted line ends with a comma, because more keys follow. Only `app_en.arb` gets the `@startup_interruptedRestore_bodyWithDate` metadata. Use the Edit tool anchored on that one line in each file (the non-English files are grouped by feature, not alphabetical).

`app_en.arb`:

```json
  "startup_interruptedRestore_title": "A restore did not finish",
  "startup_interruptedRestore_bodyWithDate": "Submersion was restoring a backup on {date} when it stopped. Your dive log from before that restore is still on this device, and this version can open it.",
  "@startup_interruptedRestore_bodyWithDate": {
    "description": "Startup screen after a restore stopped with the previous database still aside. The date is when the restore began, preformatted.",
    "placeholders": {
      "date": {
        "type": "String",
        "example": "Sat, Sep 13 10:30 AM"
      }
    }
  },
  "startup_interruptedRestore_body": "Submersion was restoring a backup when it stopped. Your dive log from before that restore is still on this device, and this version can open it.",
  "startup_interruptedRestore_recoverAction": "Recover my previous dive log",
  "startup_interruptedRestore_recoverNote": "The file that is in its place now is kept beside it, not deleted.",
  "startup_interruptedRestore_keepAction": "Keep what is there now",
  "startup_interruptedRestore_keepNote": "Your previous dive log is kept as a file in the database folder.",
  "startup_interruptedRestore_failed": "Recovery did not complete. Nothing was deleted; both files are still on this device.",
```

`app_de.arb`:

```json
  "startup_interruptedRestore_title": "Eine Wiederherstellung wurde nicht abgeschlossen",
  "startup_interruptedRestore_bodyWithDate": "Submersion hat am {date} eine Sicherung wiederhergestellt, als der Vorgang abbrach. Dein Tauchlogbuch von vor dieser Wiederherstellung ist noch auf diesem Gerät, und diese Version kann es öffnen.",
  "startup_interruptedRestore_body": "Submersion hat eine Sicherung wiederhergestellt, als der Vorgang abbrach. Dein Tauchlogbuch von vor dieser Wiederherstellung ist noch auf diesem Gerät, und diese Version kann es öffnen.",
  "startup_interruptedRestore_recoverAction": "Mein vorheriges Tauchlogbuch wiederherstellen",
  "startup_interruptedRestore_recoverNote": "Die Datei, die jetzt an seiner Stelle liegt, wird daneben aufbewahrt und nicht gelöscht.",
  "startup_interruptedRestore_keepAction": "Den jetzigen Stand behalten",
  "startup_interruptedRestore_keepNote": "Dein vorheriges Tauchlogbuch wird als Datei im Datenbankordner aufbewahrt.",
  "startup_interruptedRestore_failed": "Die Wiederherstellung wurde nicht abgeschlossen. Es wurde nichts gelöscht; beide Dateien sind noch auf diesem Gerät.",
```

`app_es.arb`:

```json
  "startup_interruptedRestore_title": "Una restauración no terminó",
  "startup_interruptedRestore_bodyWithDate": "Submersion estaba restaurando una copia de seguridad el {date} cuando se detuvo. Tu cuaderno de buceo de antes de esa restauración sigue en este dispositivo y esta versión puede abrirlo.",
  "startup_interruptedRestore_body": "Submersion estaba restaurando una copia de seguridad cuando se detuvo. Tu cuaderno de buceo de antes de esa restauración sigue en este dispositivo y esta versión puede abrirlo.",
  "startup_interruptedRestore_recoverAction": "Recuperar mi cuaderno de buceo anterior",
  "startup_interruptedRestore_recoverNote": "El archivo que ocupa ahora su lugar se conserva a su lado; no se elimina.",
  "startup_interruptedRestore_keepAction": "Conservar lo que hay ahora",
  "startup_interruptedRestore_keepNote": "Tu cuaderno de buceo anterior se conserva como archivo en la carpeta de la base de datos.",
  "startup_interruptedRestore_failed": "La recuperación no se completó. No se eliminó nada; ambos archivos siguen en este dispositivo.",
```

`app_fr.arb`:

```json
  "startup_interruptedRestore_title": "Une restauration ne s’est pas terminée",
  "startup_interruptedRestore_bodyWithDate": "Submersion restaurait une sauvegarde le {date} lorsque l’opération s’est arrêtée. Votre carnet de plongée d’avant cette restauration est toujours sur cet appareil, et cette version peut l’ouvrir.",
  "startup_interruptedRestore_body": "Submersion restaurait une sauvegarde lorsque l’opération s’est arrêtée. Votre carnet de plongée d’avant cette restauration est toujours sur cet appareil, et cette version peut l’ouvrir.",
  "startup_interruptedRestore_recoverAction": "Récupérer mon carnet de plongée précédent",
  "startup_interruptedRestore_recoverNote": "Le fichier qui se trouve maintenant à sa place est conservé à côté, pas supprimé.",
  "startup_interruptedRestore_keepAction": "Conserver ce qui s’y trouve maintenant",
  "startup_interruptedRestore_keepNote": "Votre carnet de plongée précédent est conservé sous forme de fichier dans le dossier de la base de données.",
  "startup_interruptedRestore_failed": "La récupération n’a pas abouti. Rien n’a été supprimé. Les deux fichiers sont toujours sur cet appareil.",
```

`app_it.arb`:

```json
  "startup_interruptedRestore_title": "Un ripristino non è stato completato",
  "startup_interruptedRestore_bodyWithDate": "Submersion stava ripristinando un backup il {date} quando si è interrotto. Il tuo diario di immersione di prima di quel ripristino è ancora su questo dispositivo e questa versione può aprirlo.",
  "startup_interruptedRestore_body": "Submersion stava ripristinando un backup quando si è interrotto. Il tuo diario di immersione di prima di quel ripristino è ancora su questo dispositivo e questa versione può aprirlo.",
  "startup_interruptedRestore_recoverAction": "Recupera il mio diario di immersione precedente",
  "startup_interruptedRestore_recoverNote": "Il file che ora si trova al suo posto viene conservato accanto, non eliminato.",
  "startup_interruptedRestore_keepAction": "Mantieni quello che c'è ora",
  "startup_interruptedRestore_keepNote": "Il tuo diario di immersione precedente viene conservato come file nella cartella del database.",
  "startup_interruptedRestore_failed": "Il recupero non è stato completato. Non è stato eliminato nulla; entrambi i file sono ancora su questo dispositivo.",
```

`app_nl.arb`:

```json
  "startup_interruptedRestore_title": "Een terugzetactie is niet voltooid",
  "startup_interruptedRestore_bodyWithDate": "Submersion was op {date} een back-up aan het terugzetten toen het stopte. Je duiklogboek van vóór die terugzetactie staat nog op dit apparaat, en deze versie kan het openen.",
  "startup_interruptedRestore_body": "Submersion was een back-up aan het terugzetten toen het stopte. Je duiklogboek van vóór die terugzetactie staat nog op dit apparaat, en deze versie kan het openen.",
  "startup_interruptedRestore_recoverAction": "Mijn vorige duiklogboek herstellen",
  "startup_interruptedRestore_recoverNote": "Het bestand dat nu op zijn plaats staat, wordt ernaast bewaard en niet verwijderd.",
  "startup_interruptedRestore_keepAction": "Houden wat er nu staat",
  "startup_interruptedRestore_keepNote": "Je vorige duiklogboek wordt als bestand in de databasemap bewaard.",
  "startup_interruptedRestore_failed": "Het herstel is niet voltooid. Er is niets verwijderd; beide bestanden staan nog op dit apparaat.",
```

`app_pt.arb`:

```json
  "startup_interruptedRestore_title": "Um restauro não terminou",
  "startup_interruptedRestore_bodyWithDate": "O Submersion estava a restaurar uma cópia de segurança em {date} quando parou. O seu diário de mergulho de antes desse restauro continua neste dispositivo e esta versão consegue abri-lo.",
  "startup_interruptedRestore_body": "O Submersion estava a restaurar uma cópia de segurança quando parou. O seu diário de mergulho de antes desse restauro continua neste dispositivo e esta versão consegue abri-lo.",
  "startup_interruptedRestore_recoverAction": "Recuperar o meu diário de mergulho anterior",
  "startup_interruptedRestore_recoverNote": "O ficheiro que está agora no seu lugar é guardado ao lado, não eliminado.",
  "startup_interruptedRestore_keepAction": "Manter o que está agora",
  "startup_interruptedRestore_keepNote": "O seu diário de mergulho anterior fica guardado como ficheiro na pasta da base de dados.",
  "startup_interruptedRestore_failed": "A recuperação não foi concluída. Nada foi eliminado; ambos os ficheiros continuam neste dispositivo.",
```

`app_hu.arb`:

```json
  "startup_interruptedRestore_title": "Egy visszaállítás nem fejeződött be",
  "startup_interruptedRestore_bodyWithDate": "A Submersion éppen egy biztonsági másolatot állított vissza ({date}), amikor leállt. A visszaállítás előtti merülési naplód még ezen az eszközön van, és ez a verzió meg tudja nyitni.",
  "startup_interruptedRestore_body": "A Submersion éppen egy biztonsági másolatot állított vissza, amikor leállt. A visszaállítás előtti merülési naplód még ezen az eszközön van, és ez a verzió meg tudja nyitni.",
  "startup_interruptedRestore_recoverAction": "Előző merülési naplóm visszaállítása",
  "startup_interruptedRestore_recoverNote": "A most a helyén lévő fájl mellette megmarad, nem törlődik.",
  "startup_interruptedRestore_keepAction": "A mostani állapot megtartása",
  "startup_interruptedRestore_keepNote": "Az előző merülési naplód fájlként megmarad az adatbázis mappájában.",
  "startup_interruptedRestore_failed": "A helyreállítás nem fejeződött be. Semmi sem törlődött; mindkét fájl még ezen az eszközön van.",
```

`app_ar.arb`:

```json
  "startup_interruptedRestore_title": "لم تكتمل عملية استعادة",
  "startup_interruptedRestore_bodyWithDate": "كان Submersion يستعيد نسخة احتياطية في {date} عندما توقف. لا يزال سجل الغوص الخاص بك من قبل تلك الاستعادة على هذا الجهاز، ويمكن لهذا الإصدار فتحه.",
  "startup_interruptedRestore_body": "كان Submersion يستعيد نسخة احتياطية عندما توقف. لا يزال سجل الغوص الخاص بك من قبل تلك الاستعادة على هذا الجهاز، ويمكن لهذا الإصدار فتحه.",
  "startup_interruptedRestore_recoverAction": "استرداد سجل الغوص السابق",
  "startup_interruptedRestore_recoverNote": "يُحتفظ بالملف الموجود مكانه الآن بجانبه، ولا يُحذف.",
  "startup_interruptedRestore_keepAction": "الإبقاء على الموجود حاليًا",
  "startup_interruptedRestore_keepNote": "يُحتفظ بسجل الغوص السابق كملف في مجلد قاعدة البيانات.",
  "startup_interruptedRestore_failed": "لم تكتمل عملية الاسترداد. لم يُحذف أي شيء؛ لا يزال الملفان على هذا الجهاز.",
```

`app_he.arb`:

```json
  "startup_interruptedRestore_title": "שחזור לא הושלם",
  "startup_interruptedRestore_bodyWithDate": "Submersion הייתה באמצע שחזור גיבוי ב-{date} כשהתהליך נעצר. יומן הצלילה שלך מלפני השחזור עדיין נמצא במכשיר הזה, והגרסה הזו יכולה לפתוח אותו.",
  "startup_interruptedRestore_body": "Submersion הייתה באמצע שחזור גיבוי כשהתהליך נעצר. יומן הצלילה שלך מלפני השחזור עדיין נמצא במכשיר הזה, והגרסה הזו יכולה לפתוח אותו.",
  "startup_interruptedRestore_recoverAction": "שחזור יומן הצלילה הקודם שלי",
  "startup_interruptedRestore_recoverNote": "הקובץ שנמצא עכשיו במקומו נשמר לצידו ואינו נמחק.",
  "startup_interruptedRestore_keepAction": "להשאיר את מה שיש עכשיו",
  "startup_interruptedRestore_keepNote": "יומן הצלילה הקודם שלך נשמר כקובץ בתיקיית מסד הנתונים.",
  "startup_interruptedRestore_failed": "השחזור לא הושלם. שום דבר לא נמחק; שני הקבצים עדיין נמצאים במכשיר הזה.",
```

`app_zh.arb`:

```json
  "startup_interruptedRestore_title": "有一次恢复未完成",
  "startup_interruptedRestore_bodyWithDate": "Submersion 在 {date} 恢复备份时中断了。恢复之前的潜水日志仍在此设备上，且此版本可以打开它。",
  "startup_interruptedRestore_body": "Submersion 在恢复备份时中断了。恢复之前的潜水日志仍在此设备上，且此版本可以打开它。",
  "startup_interruptedRestore_recoverAction": "恢复我之前的潜水日志",
  "startup_interruptedRestore_recoverNote": "当前位于其位置的文件会保留在旁边，不会被删除。",
  "startup_interruptedRestore_keepAction": "保留当前内容",
  "startup_interruptedRestore_keepNote": "您之前的潜水日志将作为文件保留在数据库文件夹中。",
  "startup_interruptedRestore_failed": "恢复未完成。没有删除任何内容；两个文件仍在此设备上。",
```

- [ ] **Step 2: Regenerate and validate the localizations**

Run: `flutter gen-l10n`
Expected: exits 0; `git status --short lib/l10n/arb/` lists the 11 ARB files and the 12 `app_localizations*.dart` files as modified. Then run `for f in lib/l10n/arb/app_*.arb; do python3 -m json.tool "$f" > /dev/null || echo "BAD $f"; done` and expect no `BAD` output.

- [ ] **Step 3: Write the failing view tests**

Create `test/core/presentation/widgets/interrupted_restore_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/presentation/startup_restore_status.dart';
import 'package:submersion/core/presentation/widgets/interrupted_restore_view.dart';
import 'package:submersion/core/services/restore_journal.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget host(Widget child) => MaterialApp(
  // Pinned: flutter_test forwards the HOST machine's locale list, so an
  // unpinned MaterialApp resolves to a translated UI on a non-English dev
  // machine and every English assertion below finds nothing.
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // Mirrors StartupWrapper's terminal-screen host: a bare SafeArea > Center.
  home: Scaffold(
    body: SafeArea(child: Center(child: child)),
  ),
);

InterruptedRestoreView buildView({
  InterruptedRestore interrupted = const InterruptedRestore(
    startedAt: null,
    liveExists: true,
  ),
  VoidCallback? onRecover,
  VoidCallback? onKeepCurrent,
  StartupRestoreStatus status = StartupRestoreStatus.idle,
  String? error,
}) => InterruptedRestoreView(
  interrupted: interrupted,
  textColor: Colors.black,
  subtitleColor: Colors.black54,
  onRecover: onRecover ?? () {},
  onKeepCurrent: onKeepCurrent ?? () {},
  onClose: () {},
  status: status,
  error: error,
);

const recoverKey = ValueKey('interruptedRestore_recover');
const keepKey = ValueKey('interruptedRestore_keep');

void main() {
  testWidgets('offers both choices when a file is at the live path', (
    tester,
  ) async {
    await tester.pumpWidget(host(buildView()));

    expect(find.text('A restore did not finish'), findsOneWidget);
    expect(find.byKey(recoverKey), findsOneWidget);
    expect(find.byKey(keepKey), findsOneWidget);
    expect(
      find.text(
        'The file that is in its place now is kept beside it, not deleted.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Your previous dive log is kept as a file in the database folder.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('offers only recovery when the live path is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        buildView(
          interrupted: const InterruptedRestore(
            startedAt: null,
            liveExists: false,
          ),
        ),
      ),
    );

    expect(find.byKey(recoverKey), findsOneWidget);
    expect(find.byKey(keepKey), findsNothing);
    expect(find.textContaining('kept beside it'), findsNothing);
  });

  testWidgets('names the day the restore started when it is known', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        buildView(
          // Noon UTC stays on the same calendar day in any host time zone
          // within twelve hours of UTC.
          interrupted: InterruptedRestore(
            startedAt: DateTime.utc(2026, 9, 13, 12),
            liveExists: true,
          ),
        ),
      ),
    );

    expect(find.textContaining('restoring a backup on '), findsOneWidget);
    expect(find.textContaining('Sep 13'), findsOneWidget);
  });

  testWidgets('says nothing about a date when it is unknown', (tester) async {
    await tester.pumpWidget(host(buildView()));

    expect(
      find.text(
        'Submersion was restoring a backup when it stopped. Your dive log '
        'from before that restore is still on this device, and this version '
        'can open it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('each action calls back', (tester) async {
    var recovered = 0;
    var kept = 0;
    await tester.pumpWidget(
      host(
        buildView(
          onRecover: () => recovered++,
          onKeepCurrent: () => kept++,
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(recoverKey));
    await tester.tap(find.byKey(recoverKey));
    await tester.ensureVisible(find.byKey(keepKey));
    await tester.tap(find.byKey(keepKey));

    expect(recovered, 1);
    expect(kept, 1);
  });

  testWidgets('disables both actions while one runs', (tester) async {
    await tester.pumpWidget(
      host(buildView(status: StartupRestoreStatus.running)),
    );

    expect(
      tester.widget<FilledButton>(find.byKey(recoverKey)).onPressed,
      isNull,
    );
    expect(tester.widget<OutlinedButton>(find.byKey(keepKey)).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the failure and the error text', (tester) async {
    await tester.pumpWidget(
      host(
        buildView(
          status: StartupRestoreStatus.failed,
          error: 'FileSystemException: locked',
        ),
      ),
    );

    expect(
      find.text(
        'Recovery did not complete. Nothing was deleted; both files are '
        'still on this device.',
      ),
      findsOneWidget,
    );
    expect(find.text('FileSystemException: locked'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `flutter test test/core/presentation/widgets/interrupted_restore_view_test.dart`
Expected: FAIL to compile, `Target of URI doesn't exist: 'package:submersion/core/presentation/widgets/interrupted_restore_view.dart'`.

- [ ] **Step 5: Write the view**

Create `lib/core/presentation/widgets/interrupted_restore_view.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/presentation/startup_restore_status.dart';
import 'package:submersion/core/services/restore_journal.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Startup screen shown when an earlier restore stopped with the diver's
/// previous database still aside (issue #1901).
///
/// Shown BEFORE anything is opened: a missing live file would otherwise be
/// created fresh and empty, and a rejected one would route to the
/// version-mismatch screen, neither of which describes what happened.
///
/// Recovery is the primary action because the aside copy is the database
/// the diver was using before the restore. Keeping what is there now is
/// offered only when something is there; with an empty live path it would
/// mean an empty library. Neither action deletes a database file.
class InterruptedRestoreView extends StatelessWidget {
  const InterruptedRestoreView({
    super.key,
    required this.interrupted,
    required this.textColor,
    required this.subtitleColor,
    required this.onRecover,
    required this.onKeepCurrent,
    required this.onClose,
    this.status = StartupRestoreStatus.idle,
    this.error,
  });

  final InterruptedRestore interrupted;
  final Color textColor;
  final Color subtitleColor;
  final VoidCallback onRecover;
  final VoidCallback onKeepCurrent;
  final VoidCallback onClose;
  final StartupRestoreStatus status;
  final String? error;

  /// Formatted through [MaterialLocalizations], like StartupRestoreCard: the
  /// diver's saved locale is not readable yet, so the resolved system locale
  /// the splash MaterialApp carries is the only source of formatting.
  static String _formatStartedAt(BuildContext context, DateTime startedAt) {
    final local = startedAt.toLocal();
    final l = MaterialLocalizations.of(context);
    final date = l.formatMediumDate(local);
    final time = l.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final running = status == StartupRestoreStatus.running;
    final bodyStyle = TextStyle(fontSize: 14, color: subtitleColor);
    final captionStyle = TextStyle(fontSize: 12, color: subtitleColor);
    final startedAt = interrupted.startedAt;

    // Scrolls itself, exactly as VersionMismatchView does: StartupWrapper
    // hosts terminal screens in a bare SafeArea > Center.
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restore_page, size: 64, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              l10n.startup_interruptedRestore_title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              startedAt == null
                  ? l10n.startup_interruptedRestore_body
                  : l10n.startup_interruptedRestore_bodyWithDate(
                      _formatStartedAt(context, startedAt),
                    ),
              style: bodyStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('interruptedRestore_recover'),
              onPressed: running ? null : onRecover,
              child: Text(l10n.startup_interruptedRestore_recoverAction),
            ),
            if (interrupted.liveExists) ...[
              const SizedBox(height: 8),
              Text(
                l10n.startup_interruptedRestore_recoverNote,
                style: captionStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const ValueKey('interruptedRestore_keep'),
                onPressed: running ? null : onKeepCurrent,
                child: Text(l10n.startup_interruptedRestore_keepAction),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.startup_interruptedRestore_keepNote,
                style: captionStyle,
                textAlign: TextAlign.center,
              ),
            ],
            if (running) ...[
              const SizedBox(height: 16),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
            if (status == StartupRestoreStatus.failed) ...[
              const SizedBox(height: 16),
              Text(
                l10n.startup_interruptedRestore_failed,
                style: bodyStyle,
                textAlign: TextAlign.center,
              ),
              if (error != null && error!.isNotEmpty) ...[
                const SizedBox(height: 4),
                SelectableText(
                  error!,
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: running ? null : onClose,
              child: Text(l10n.common_action_close),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/core/presentation/widgets/interrupted_restore_view_test.dart`
Expected: PASS, all tests.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format lib/core/presentation/widgets/interrupted_restore_view.dart test/core/presentation/widgets/interrupted_restore_view_test.dart
flutter analyze lib/core/presentation lib/l10n test/core/presentation/widgets
git add lib/l10n/arb/ lib/core/presentation/widgets/interrupted_restore_view.dart test/core/presentation/widgets/interrupted_restore_view_test.dart
git commit -m "feat(startup): add the interrupted-restore screen and its strings

Refs #1901"
```

---

### Task 5: Detect an interrupted restore at startup and wire the actions

**Files:**
- Modify: `lib/core/presentation/pages/startup_page.dart` (imports; `_StartupState` at 106-117; `StartupWrapper` fields and constructor at 159-186; `_StartupWrapperState` fields near 228; `_runInitialization` at 292; new methods after `_restoreAtStartup` at ~1216; `build` home condition at 1380-1385; `_buildErrorContent` at 1508)
- Test: `test/core/presentation/pages/startup_page_test.dart`

**Interfaces:**
- Consumes: `RestoreJournal.findInterrupted()`, `.recover()`, `.keepCurrent()`, `InterruptedRestore` (Task 2); `DatabaseService.instance.restoreJournalFor(String)` (Task 3); `InterruptedRestoreView` and its button keys (Task 4).
- Produces: `StartupWrapper.restoreJournalFactory` of type `RestoreJournal Function(String dbPath)?`, annotated `@visibleForTesting`.

- [ ] **Step 1: Write the failing tests**

In `test/core/presentation/pages/startup_page_test.dart`:

1. Add imports (keep each group alphabetical):

```dart
import 'package:submersion/core/presentation/widgets/interrupted_restore_view.dart';
import 'package:submersion/core/services/restore_journal.dart';
```

2. Add this fake after `_RecordingPreDowngradeService`:

```dart
/// A [RestoreJournal] that touches no files: startup asks it whether a
/// restore was interrupted, and it records what the diver chose.
class _FakeRestoreJournal extends RestoreJournal {
  _FakeRestoreJournal({this.found, this.error})
    : super('/tmp/test.db', readSchemaVersion: _noVersion);

  static int? _noVersion(String _) => null;

  InterruptedRestore? found;
  final Object? error;
  final List<String> calls = [];

  @override
  InterruptedRestore? findInterrupted() {
    calls.add('find');
    return found;
  }

  @override
  Future<void> recover() async {
    calls.add('recover');
    if (error != null) throw error!;
    found = null;
  }

  @override
  Future<void> keepCurrent() async {
    calls.add('keep');
    if (error != null) throw error!;
    found = null;
  }
}
```

3. In `_buildStartupWrapper`, add the parameter after `restoreOverride,`:

```dart
  RestoreJournal Function(String dbPath)? restoreJournalFactory,
```

and pass it through after `restoreOverride: restoreOverride,`:

```dart
    // Default to a journal that finds nothing, so widget tests never stat
    // real files beside the fixture path. Tests of the recovery screen pass
    // their own.
    restoreJournalFactory: restoreJournalFactory ?? (_) => _FakeRestoreJournal(),
```

4. Add these tests at the end of the `'StartupWrapper lifecycle'` group:

```dart
    testWidgets('an interrupted restore is offered before the database is '
        'probed or opened', (tester) async {
      var probes = 0;
      var inits = 0;
      final journal = _FakeRestoreJournal(
        found: const InterruptedRestore(startedAt: null, liveExists: true),
      );

      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) {
            probes++;
            return (needsMigration: false, totalSteps: 0);
          },
          initializerOverride: (_) async {
            inits++;
          },
          restoreJournalFactory: (_) => journal,
        ),
      );
      await tester.pump();

      expect(find.byType(InterruptedRestoreView), findsOneWidget);
      expect(probes, 0, reason: 'nothing may touch the live file first');
      expect(inits, 0, reason: 'opening would create an empty database');
      expect(journal.calls, ['find']);
    });

    testWidgets('recovering settles the restore, then startup resumes from '
        'the top', (tester) async {
      var inits = 0;
      final journal = _FakeRestoreJournal(
        found: const InterruptedRestore(startedAt: null, liveExists: true),
      );

      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) {
            inits++;
            return Completer<void>().future;
          },
          restoreJournalFactory: (_) => journal,
        ),
      );
      await tester.pump();

      final recover = find.byKey(const ValueKey('interruptedRestore_recover'));
      await tester.ensureVisible(recover);
      await tester.tap(recover);
      await tester.pump();
      await tester.pump();

      expect(journal.calls, ['find', 'recover', 'find']);
      expect(inits, 1);
      expect(find.byType(InterruptedRestoreView), findsNothing);

      // Drain the 1-second splash delay timer.
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('keeping the current database settles the restore the same '
        'way', (tester) async {
      var inits = 0;
      final journal = _FakeRestoreJournal(
        found: const InterruptedRestore(startedAt: null, liveExists: true),
      );

      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) {
            inits++;
            return Completer<void>().future;
          },
          restoreJournalFactory: (_) => journal,
        ),
      );
      await tester.pump();

      final keep = find.byKey(const ValueKey('interruptedRestore_keep'));
      await tester.ensureVisible(keep);
      await tester.tap(keep);
      await tester.pump();
      await tester.pump();

      expect(journal.calls, ['find', 'keep', 'find']);
      expect(inits, 1);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('a failed recovery stays on the screen with the error', (
      tester,
    ) async {
      var inits = 0;
      final journal = _FakeRestoreJournal(
        found: const InterruptedRestore(startedAt: null, liveExists: true),
        error: StateError('still locked'),
      );

      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) async {
            inits++;
          },
          restoreJournalFactory: (_) => journal,
        ),
      );
      await tester.pump();

      final recover = find.byKey(const ValueKey('interruptedRestore_recover'));
      await tester.ensureVisible(recover);
      await tester.tap(recover);
      await tester.pump();
      await tester.pump();

      expect(find.byType(InterruptedRestoreView), findsOneWidget);
      expect(find.textContaining('still locked'), findsOneWidget);
      expect(journal.calls, ['find', 'recover']);
      expect(inits, 0);
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/presentation/pages/startup_page_test.dart`
Expected: FAIL to compile, `No named parameter with the name 'restoreJournalFactory'`.

- [ ] **Step 3: Implement the wiring in `startup_page.dart`**

1. Imports (alphabetical within the local group):

```dart
import 'package:submersion/core/presentation/startup_restore_status.dart';
import 'package:submersion/core/presentation/widgets/interrupted_restore_view.dart';
import 'package:submersion/core/services/restore_journal.dart';
```

(Skip the `startup_restore_status.dart` line if the file already imports it; `StartupRestoreStatus` is already used there, so check with `grep -n startup_restore_status lib/core/presentation/pages/startup_page.dart` first.)

2. Add `interruptedRestore` to `_StartupState`, directly after `locked,`:

```dart
  interruptedRestore,
```

3. Add the field to `StartupWrapper`, after the `restoreOverride` field:

```dart
  /// Optional override for the restore journal consulted before anything is
  /// opened (used in tests, which must not stat or move real files).
  @visibleForTesting
  final RestoreJournal Function(String dbPath)? restoreJournalFactory;
```

and to the constructor, after `this.restoreOverride,`:

```dart
    this.restoreJournalFactory,
```

4. Add the state field after `BackupRecord? _downgradeBackup;`:

```dart
  /// An earlier restore that stopped with the diver's previous database still
  /// aside, found before anything was opened. Null otherwise (issue #1901).
  InterruptedRestore? _interruptedRestore;
```

5. In `_runInitialization`, directly after `await _resolveSecurityGate(dbPath);` insert:

```dart

      // An earlier restore that never settled left the previous database
      // aside. Checked after the security gate (probing an encrypted file
      // needs the key) and before the schema probe on purpose: a missing live
      // file would otherwise be created fresh by onCreate, and a rejected one
      // would route to the version-mismatch screen, neither of which is what
      // happened.
      final interrupted = _restoreJournal(dbPath).findInterrupted();
      if (interrupted != null) {
        if (mounted) {
          setState(() {
            _interruptedRestore = interrupted;
            _state = _StartupState.interruptedRestore;
          });
        }
        return;
      }
```

6. Add these methods directly after `_restoreAtStartup`:

```dart
  RestoreJournal _restoreJournal(String dbPath) =>
      widget.restoreJournalFactory?.call(dbPath) ??
      DatabaseService.instance.restoreJournalFor(dbPath);

  /// Puts the database from before the interrupted restore back.
  Future<void> _recoverInterruptedRestore() =>
      _settleInterruptedRestore((journal) => journal.recover());

  /// Keeps what is live now; the previous database stays on disk under a
  /// timestamped name.
  Future<void> _keepCurrentDatabase() =>
      _settleInterruptedRestore((journal) => journal.keepCurrent());

  /// Shared body of both interrupted-restore actions: run [action] with the
  /// database closed, then resume startup from the top, like
  /// [_restoreAtStartup], so the security gate, migrations and the
  /// version-mismatch screen all run as on a normal launch. A failure keeps
  /// the diver on this screen; neither action deletes a database file.
  Future<void> _settleInterruptedRestore(
    Future<void> Function(RestoreJournal journal) action,
  ) async {
    if (_restoreStatus == StartupRestoreStatus.running) return;
    setState(() {
      _restoreStatus = StartupRestoreStatus.running;
      _restoreError = null;
    });
    try {
      final dbPath = await widget.locationService.getDatabasePath();
      await action(_restoreJournal(dbPath));
      if (!mounted) return;
      setState(() {
        _restoreStatus = StartupRestoreStatus.idle;
        _interruptedRestore = null;
        _state = _StartupState.initializing;
      });
      await _runInitialization();
    } catch (e) {
      debugPrint('Interrupted restore could not be settled: $e');
      if (!mounted) return;
      setState(() {
        _restoreStatus = StartupRestoreStatus.failed;
        _restoreError = '$e';
      });
    }
  }
```

7. In `build`, extend the `home:` condition so the new state uses the terminal-screen scaffold:

```dart
                home:
                    (_state == _StartupState.error ||
                        _state == _StartupState.interruptedRestore ||
                        _state == _StartupState.backupFailed ||
                        _state == _StartupState.recoveryRequired ||
                        _state == _StartupState.recovering ||
                        _state == _StartupState.recoveryFailed)
```

8. At the top of `_buildErrorContent`, before the `backupFailed` check, insert:

```dart
    final interrupted = _interruptedRestore;
    if (_state == _StartupState.interruptedRestore && interrupted != null) {
      return InterruptedRestoreView(
        interrupted: interrupted,
        textColor: textColor,
        subtitleColor: subtitleColor,
        onRecover: _recoverInterruptedRestore,
        onKeepCurrent: _keepCurrentDatabase,
        onClose: _closeApp,
        status: _restoreStatus,
        error: _restoreError,
      );
    }

```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/presentation/pages/startup_page_test.dart`
Expected: PASS, all tests (new and pre-existing).

- [ ] **Step 5: Run the other startup test files**

Run: `flutter test test/core/presentation/`
Expected: PASS. Files that build `StartupWrapper` directly (for example `startup_lock_gate_test.dart`) use the real journal against their fixture paths; nothing is aside there, so `findInterrupted()` returns null and they behave as before.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/core/presentation/pages/startup_page.dart test/core/presentation/pages/startup_page_test.dart
flutter analyze lib/core/presentation test/core/presentation
git add lib/core/presentation/pages/startup_page.dart test/core/presentation/pages/startup_page_test.dart
git commit -m "feat(startup): offer to recover the database an interrupted restore left aside

The journal is consulted after the security gate and before the schema
probe, so a missing live file is never replaced by a fresh empty database
and a rejected one no longer lands on the version-mismatch screen.

Refs #1901"
```

---

### Task 6: Whole-branch verification

**Files:** none new.

- [ ] **Step 1: Format the whole project**

Run: `dart format .`
Expected: `Formatted N files (0 changed)` for files outside this branch; if anything changed, it is in this branch's files; stage and amend it into the relevant commit, or commit it as `style: format`.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: `No issues found!` (CI treats infos as fatal).

- [ ] **Step 3: Check the generated localizations are current**

Run: `flutter gen-l10n && git status --short lib/l10n/`
Expected: no output (nothing to regenerate).

- [ ] **Step 4: Scan the branch for forbidden text**

Run: `git diff origin/main -- . ':!lib/l10n/arb/app_localizations*.dart' | grep -n "^+.*$(printf '\342\200\224')"; echo "exit $?"`
(macOS grep has no `-P`, so the em-dash byte sequence is built with `printf`.)
Expected: `exit 1` (no matches). Then search the same added lines, and `git log origin/main..HEAD --format=%B`, case-insensitively for co-author trailers, session links, "Generated with" lines and every name listed in the Attribution section of the project instructions. Expected: no matches.

- [ ] **Step 5: Run the affected test directories once**

Run: `flutter test test/core/services/ test/core/presentation/ test/features/backup/`
Expected: PASS. (The full suite runs in the pre-push hook and in CI; one local run of the affected directories is enough.)

- [ ] **Step 6: Report**

Summarize for the user: commits on the branch, tests added, and anything skipped. Opening the PR (body `Closes #1901` and `Refs #1856`, no attribution) and the comment on #1856 about the overlapping seam happen after the user reviews, through superpowers:finishing-a-development-branch.

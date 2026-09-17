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

  /// The aside copy while a restore is unsettled (the marker is present, or
  /// nothing is live), otherwise null.
  ///
  /// Until it is settled, that copy is the database the diver actually has,
  /// so startup must judge encryption by ITS header. The live path may be
  /// missing or hold a plaintext restored file, and reading either as "the
  /// database is not encrypted" switches encryption off and drops the key
  /// that the encrypted original needs.
  String? get pendingAsidePath {
    if (!File(asidePath).existsSync()) return null;
    return hasMarker || !File(dbPath).existsSync() ? asidePath : null;
  }

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
    return _opensHere(dbPath)
        ? PreRestoreState.stale
        : PreRestoreState.precious;
  }

  /// Moves [path] and its sidecars to `<prefix or path>.<UTC timestamp>`,
  /// never over an existing file, and returns the new main path.
  ///
  /// Tolerates a missing main file so an orphaned sidecar can be moved out of
  /// the way too. The files move as a unit (see [_moveTogether]).
  Future<String> quarantine(String path, {String? prefix}) async {
    final base = '${prefix ?? path}.${_stamp(_now().toUtc())}';
    var target = base;
    for (var n = 1; _anyExists(target); n++) {
      target = '$base-$n';
    }
    await _moveTogether(_withSidecars(path), _withSidecars(target));
    return target;
  }

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
    await _moveTogether(_withSidecars(asidePath), _withSidecars(dbPath));
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

  /// Renames each existing file in [from] onto the matching path in [to], as
  /// a unit: when one rename fails, the ones already done are moved back
  /// (best-effort) and the error is rethrown, so a database is never left
  /// split from its `-wal`/`-shm`. Main file first, then sidecars, matching
  /// the order the restore swap itself uses.
  static Future<void> _moveTogether(List<String> from, List<String> to) async {
    final moved = <(String, String)>[];
    try {
      for (var i = 0; i < from.length; i++) {
        final source = File(from[i]);
        if (!source.existsSync()) continue;
        await source.rename(to[i]);
        moved.add((from[i], to[i]));
      }
    } catch (_) {
      for (final (source, target) in moved.reversed) {
        try {
          await File(target).rename(source);
        } catch (_) {
          // Nothing better to do: the original error below is what the
          // caller needs, and every file still exists under one of its names.
        }
      }
      rethrow;
    }
  }

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

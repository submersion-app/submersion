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
    return _opensHere(dbPath)
        ? PreRestoreState.stale
        : PreRestoreState.precious;
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

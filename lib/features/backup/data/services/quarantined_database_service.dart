import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/backup/data/services/backup_schema_probe.dart';
import 'package:submersion/features/backup/domain/entities/quarantined_database.dart';

/// Reads the schema version a database copy holds, trying [keyHex] first.
/// Returns null when the copy does not open at all; never throws.
typedef QuarantineSchemaProbe =
    int? Function(String path, {required String? keyHex});

int? _defaultProbe(String path, {required String? keyHex}) =>
    probeBackupSchemaVersion(path, keyHex: keyHex);

/// One file name that belongs to a quarantined copy.
typedef QuarantinedName = ({
  /// The copy's database file name, with any sidecar suffix removed.
  String mainName,
  QuarantineKind kind,
  DateTime quarantinedAt,

  /// `-wal` or `-shm` for a sidecar, null for the database file itself.
  String? sidecar,
});

const _kindTags = {
  'pre-restore': QuarantineKind.preRestore,
  'restore-rejected': QuarantineKind.restoreRejected,
};

/// Parses [fileName] as a copy `RestoreJournal.quarantine` wrote beside the
/// live database named [databaseFileName], or returns null.
///
/// The shape is `<db>.<tag>.<yyyyMMddTHHmmssZ>[-<n>][-wal|-shm]`, where `-<n>`
/// is the collision suffix the journal adds when a name is taken. The
/// unstamped `<db>.pre-restore` is NOT a match: that is an unsettled restore's
/// aside copy, which belongs to the journal and the startup recovery screen.
QuarantinedName? parseQuarantinedName(
  String databaseFileName,
  String fileName,
) {
  final match = RegExp(
    '^(${RegExp.escape(databaseFileName)}'
    r'\.(pre-restore|restore-rejected)'
    r'\.(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z(?:-\d+)?)'
    r'(-wal|-shm)?$',
  ).firstMatch(fileName);
  if (match == null) return null;

  int part(int group) => int.parse(match.group(group)!);
  return (
    mainName: match.group(1)!,
    kind: _kindTags[match.group(2)]!,
    quarantinedAt: DateTime.utc(
      part(3),
      part(4),
      part(5),
      part(6),
      part(7),
      part(8),
    ),
    sidecar: match.group(9),
  );
}

/// Finds and deletes the database copies a restore set aside next to the
/// live database instead of deleting them (issue #1923).
///
/// The restore journal never deletes a copy it cannot prove disposable, so
/// these accumulate until the diver acts. This is the only code that removes
/// them, and only when asked: nothing here prunes automatically.
///
/// Restoring one is not here. It goes through `BackupService`, like every
/// other restore, so it gets the same safety backup and sync re-baseline.
class QuarantinedDatabaseService {
  QuarantinedDatabaseService({
    required Future<String> Function() databasePath,
    required String? Function() keyHex,
    QuarantineSchemaProbe probe = _defaultProbe,
  }) : _databasePath = databasePath,
       _keyHex = keyHex,
       _probe = probe;

  final Future<String> Function() _databasePath;
  final String? Function() _keyHex;
  final QuarantineSchemaProbe _probe;

  static const _sidecarSuffixes = ['-wal', '-shm'];

  /// Every quarantined copy in the database folder, newest first.
  ///
  /// Each copy is probed with the live key (then without one, for a copy
  /// taken before protection was turned on), so an encrypted install still
  /// reads its own copies. A copy that opens neither way is reported as
  /// [QuarantinedDatabaseStatus.unreadable] rather than as damaged: without
  /// the key it was written with, the two look the same.
  Future<List<QuarantinedDatabase>> find() async {
    final dbPath = await _databasePath();
    final directory = Directory(p.dirname(dbPath));
    if (!await directory.exists()) return const [];

    final dbName = p.basename(dbPath);
    final groups = <String, ({QuarantinedName name, List<String> files})>{};
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = parseQuarantinedName(dbName, p.basename(entity.path));
      if (name == null) continue;
      groups
          .putIfAbsent(name.mainName, () => (name: name, files: []))
          .files
          .add(entity.path);
    }

    final copies = [
      for (final group in groups.values)
        await _describe(
          p.join(directory.path, group.name.mainName),
          group.name,
          group.files,
        ),
    ]..sort((a, b) => b.quarantinedAt.compareTo(a.quarantinedAt));
    return copies;
  }

  /// Deletes [copy]'s database file and its `-wal`/`-shm` sidecars.
  ///
  /// The set is derived from [QuarantinedDatabase.path] again rather than
  /// taken from [QuarantinedDatabase.files], so a sidecar that appeared since
  /// the list was read goes too. The database file goes first: a sidecar
  /// left behind by a failure is an incomplete copy that can still be
  /// deleted, whereas a database left without its `-wal` would have lost
  /// whatever that journal held.
  ///
  /// Throws [ArgumentError] for anything that is not a quarantined copy in
  /// the database folder, so no caller can reach the live database through
  /// here.
  Future<void> delete(QuarantinedDatabase copy) async {
    final dbPath = await _databasePath();
    final name = parseQuarantinedName(
      p.basename(dbPath),
      p.basename(copy.path),
    );
    if (name == null ||
        name.sidecar != null ||
        !p.equals(p.dirname(copy.path), p.dirname(dbPath))) {
      throw ArgumentError.value(
        copy.path,
        'copy',
        'is not a quarantined database copy',
      );
    }
    for (final path in [
      copy.path,
      for (final suffix in _sidecarSuffixes) '${copy.path}$suffix',
    ]) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<QuarantinedDatabase> _describe(
    String mainPath,
    QuarantinedName name,
    List<String> files,
  ) async {
    var sizeBytes = 0;
    for (final path in files) {
      sizeBytes += await File(path).length();
    }

    final int? schemaVersion;
    final QuarantinedDatabaseStatus status;
    if (!files.contains(mainPath)) {
      schemaVersion = null;
      status = QuarantinedDatabaseStatus.incomplete;
    } else {
      schemaVersion = _probe(mainPath, keyHex: _keyHex());
      status = _statusFor(schemaVersion);
    }

    return QuarantinedDatabase(
      path: mainPath,
      kind: name.kind,
      quarantinedAt: name.quarantinedAt,
      files: List.unmodifiable(files),
      sizeBytes: sizeBytes,
      status: status,
      schemaVersion: schemaVersion,
    );
  }

  /// The same rule the restore journal uses for "this build can open it":
  /// version 0 is a zero-byte or foreign file, never a Submersion database.
  static QuarantinedDatabaseStatus _statusFor(int? version) {
    if (version == null || version < 1) {
      return QuarantinedDatabaseStatus.unreadable;
    }
    if (version > AppDatabase.currentSchemaVersion) {
      return QuarantinedDatabaseStatus.needsNewerApp;
    }
    return QuarantinedDatabaseStatus.restorable;
  }
}

import 'package:path/path.dart' as p;

/// Why a restore kept a database copy instead of deleting it (issue #1923).
enum QuarantineKind {
  /// `<db>.pre-restore.<stamp>`: the database from before a restore, kept
  /// because nothing could prove the restore that replaced it had finished.
  preRestore,

  /// `<db>.restore-rejected.<stamp>`: the file that was live when the diver
  /// chose to recover the previous dive log instead.
  restoreRejected,
}

/// What this build can do with a quarantined copy.
enum QuarantinedDatabaseStatus {
  /// Opens here at a schema this build supports, so it can be restored.
  restorable,

  /// A Submersion database from a newer build than this one.
  needsNewerApp,

  /// Does not open here: damaged, not a Submersion database, or encrypted
  /// with a key this install does not hold. The three cannot be told apart
  /// without the key, so none of them is claimed.
  unreadable,

  /// Only `-wal`/`-shm` journal files remain; the database file is gone.
  incomplete,
}

/// A database copy the restore journal set aside next to the live database
/// rather than deleting, because it could not prove the copy was disposable.
///
/// [files] are the parts of the copy that exist on disk: the database file
/// and whichever of its `-wal`/`-shm` sidecars sit beside it. They are
/// listed, restored and deleted as one unit.
class QuarantinedDatabase {
  const QuarantinedDatabase({
    required this.path,
    required this.kind,
    required this.quarantinedAt,
    required this.files,
    required this.sizeBytes,
    required this.status,
    this.schemaVersion,
  });

  /// The database file's path. May not exist when [status] is
  /// [QuarantinedDatabaseStatus.incomplete].
  final String path;

  final QuarantineKind kind;

  /// When the copy was set aside, in UTC, as recorded in its file name.
  final DateTime quarantinedAt;

  final List<String> files;

  /// Combined size of [files].
  final int sizeBytes;

  final QuarantinedDatabaseStatus status;

  /// The schema version the copy holds, when it could be read.
  final int? schemaVersion;

  String get filename => p.basename(path);

  bool get isRestorable => status == QuarantinedDatabaseStatus.restorable;

  QuarantinedDatabase copyWith({
    String? path,
    QuarantineKind? kind,
    DateTime? quarantinedAt,
    List<String>? files,
    int? sizeBytes,
    QuarantinedDatabaseStatus? status,
    int? schemaVersion,
  }) => QuarantinedDatabase(
    path: path ?? this.path,
    kind: kind ?? this.kind,
    quarantinedAt: quarantinedAt ?? this.quarantinedAt,
    files: files ?? this.files,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    status: status ?? this.status,
    schemaVersion: schemaVersion ?? this.schemaVersion,
  );
}

/// Which build wrote this database file, and when.
///
/// # The storage contract is FROZEN
///
/// Every other schema artefact in this project is read by code that is newer
/// than the file. This one is the opposite: it exists so that an **older**
/// build can say something useful about a file a **newer** build wrote, which
/// is the situation the version-mismatch guard is in (issue #1568). The
/// reader therefore ships before the writer it has to understand.
///
/// Two rules follow, and neither may be relaxed:
///
/// 1. **The shape never changes.** One table, `database_provenance`, with a
///    `key TEXT PRIMARY KEY, value TEXT` pair. New facts are new keys, never
///    new columns and never a new table, because a build that shipped today
///    only knows how to `SELECT key, value FROM database_provenance`.
/// 2. **Every value is parsed defensively.** A key this build does not know is
///    ignored; a value it cannot parse degrades to null rather than throwing.
///    A future build may write a timestamp format, a train name, or a version
///    string that did not exist when this parser was written.
///
/// The file deliberately imports neither drift nor sqlite3: it is the shared
/// vocabulary, so it stays readable from the raw pre-drift probe
/// (`DatabaseService.readProvenance`) and from the drift-side recorder alike.
library;

/// The frozen key vocabulary. Add keys, never rename or repurpose one.
class DatabaseProvenanceKeys {
  DatabaseProvenanceKeys._();

  /// The one table name, frozen with the shape.
  static const String tableName = 'database_provenance';

  // The build that opened this file most recently.
  static const String appVersion = 'app_version';
  static const String releaseTrain = 'release_train';
  static const String schemaVersion = 'schema_version';
  static const String writtenAt = 'written_at';
  static const String installId = 'install_id';

  // The build before that one, rotated in only when it actually differed.
  static const String previousAppVersion = 'previous_app_version';
  static const String previousReleaseTrain = 'previous_release_train';
  static const String previousSchemaVersion = 'previous_schema_version';
  static const String previousWrittenAt = 'previous_written_at';
  static const String previousInstallId = 'previous_install_id';

  // The build that last ran the upgrade ladder on this file. This is the
  // entry the mismatch screen needs: "which build put the file on the rung
  // this app cannot open" is a different question from "which build touched
  // it last", and only the first one names a build worth downloading.
  static const String upgradeAppVersion = 'upgrade_app_version';
  static const String upgradeReleaseTrain = 'upgrade_release_train';
  static const String upgradeSchemaVersion = 'upgrade_to_schema_version';
  static const String upgradeFromSchemaVersion = 'upgrade_from_schema_version';
  static const String upgradeWrittenAt = 'upgrade_written_at';
  static const String upgradeInstallId = 'upgrade_install_id';
}

/// One "a build touched this file" fact. Every field is nullable: a partial
/// row from a future build is more useful than no row at all.
class DatabaseProvenanceEntry {
  const DatabaseProvenanceEntry({
    this.appVersion,
    this.releaseTrain,
    this.schemaVersion,
    this.fromSchemaVersion,
    this.writtenAt,
    this.installId,
  });

  /// Four-segment app version as `formatAppVersion` produces it (`1.7.7.8064`).
  /// Free text on read: a future build may format it differently.
  final String? appVersion;

  /// Release train the writing build came off (`stable`, `beta`). Free text
  /// for the same reason: a train that does not exist yet must still render.
  final String? releaseTrain;

  /// The `user_version` rung the file was on when this entry was written.
  final int? schemaVersion;

  /// Upgrade entries only: the rung the ladder started from.
  final int? fromSchemaVersion;

  /// Always UTC. Null when the stored value did not parse as a timestamp.
  final DateTime? writtenAt;

  /// The `sync_metadata.device_id` of the writing install. Travels with the
  /// file, so a value that differs from the reading device's own id means the
  /// file arrived here by backup, restore, or a file copy.
  final String? installId;

  /// True when nothing at all was recorded, which is how a database written
  /// before this table existed reads back.
  bool get isEmpty =>
      appVersion == null &&
      releaseTrain == null &&
      schemaVersion == null &&
      fromSchemaVersion == null &&
      writtenAt == null &&
      installId == null;

  @override
  String toString() =>
      'DatabaseProvenanceEntry(appVersion: $appVersion, '
      'releaseTrain: $releaseTrain, schemaVersion: $schemaVersion, '
      'fromSchemaVersion: $fromSchemaVersion, writtenAt: $writtenAt, '
      'installId: $installId)';
}

/// Everything the `database_provenance` table holds, parsed.
class DatabaseProvenanceRecord {
  const DatabaseProvenanceRecord({
    this.lastOpen,
    this.previousOpen,
    this.lastUpgrade,
  });

  /// The build that opened the file most recently.
  final DatabaseProvenanceEntry? lastOpen;

  /// The last build BEFORE [lastOpen] that differed from it.
  final DatabaseProvenanceEntry? previousOpen;

  /// The build that last ran the schema upgrade ladder.
  final DatabaseProvenanceEntry? lastUpgrade;

  bool get isEmpty =>
      lastOpen == null && previousOpen == null && lastUpgrade == null;

  /// Parse raw `key -> value` rows. Never throws: unknown keys are ignored,
  /// unparseable values degrade to null, and an entry with nothing usable in
  /// it is dropped rather than surfaced as a row of nulls.
  static DatabaseProvenanceRecord parse(Map<String, String> rows) {
    DatabaseProvenanceEntry? entry(
      String appVersionKey,
      String trainKey,
      String schemaKey,
      String writtenAtKey,
      String installIdKey, {
      String? fromSchemaKey,
    }) {
      final result = DatabaseProvenanceEntry(
        appVersion: _text(rows[appVersionKey]),
        releaseTrain: _text(rows[trainKey]),
        schemaVersion: _int(rows[schemaKey]),
        fromSchemaVersion: fromSchemaKey == null
            ? null
            : _int(rows[fromSchemaKey]),
        writtenAt: _timestamp(rows[writtenAtKey]),
        installId: _text(rows[installIdKey]),
      );
      return result.isEmpty ? null : result;
    }

    return DatabaseProvenanceRecord(
      lastOpen: entry(
        DatabaseProvenanceKeys.appVersion,
        DatabaseProvenanceKeys.releaseTrain,
        DatabaseProvenanceKeys.schemaVersion,
        DatabaseProvenanceKeys.writtenAt,
        DatabaseProvenanceKeys.installId,
      ),
      previousOpen: entry(
        DatabaseProvenanceKeys.previousAppVersion,
        DatabaseProvenanceKeys.previousReleaseTrain,
        DatabaseProvenanceKeys.previousSchemaVersion,
        DatabaseProvenanceKeys.previousWrittenAt,
        DatabaseProvenanceKeys.previousInstallId,
      ),
      lastUpgrade: entry(
        DatabaseProvenanceKeys.upgradeAppVersion,
        DatabaseProvenanceKeys.upgradeReleaseTrain,
        DatabaseProvenanceKeys.upgradeSchemaVersion,
        DatabaseProvenanceKeys.upgradeWrittenAt,
        DatabaseProvenanceKeys.upgradeInstallId,
        fromSchemaKey: DatabaseProvenanceKeys.upgradeFromSchemaVersion,
      ),
    );
  }

  /// A blank or whitespace-only value carries no information and is treated
  /// as absent, so a future build that writes an empty string for something
  /// it could not determine does not produce an empty-looking UI string.
  static String? _text(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _int(String? raw) {
    final text = _text(raw);
    return text == null ? null : int.tryParse(text);
  }

  /// ISO-8601 in, UTC out. `DateTime.tryParse` accepts both the `Z` form this
  /// writer produces and an offset form a future writer might, and returns
  /// null on anything else.
  static DateTime? _timestamp(String? raw) {
    final text = _text(raw);
    if (text == null) return null;
    return DateTime.tryParse(text)?.toUtc();
  }

  @override
  String toString() =>
      'DatabaseProvenanceRecord(lastOpen: $lastOpen, '
      'previousOpen: $previousOpen, lastUpgrade: $lastUpgrade)';
}

import 'dart:io' show Platform;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:submersion/core/database/database_provenance.dart';
import 'package:submersion/core/utils/app_version.dart';
import 'package:submersion/core/utils/build_train.dart';

/// Writes the `database_provenance` rows described by [DatabaseProvenanceKeys].
///
/// Called once per successful open. Everything it does is best-effort by
/// contract: provenance is a diagnostic, and losing it must never cost a
/// diver their launch. [record] therefore swallows its own failures, and a
/// database on a read-only volume simply keeps whatever it already had.
class DatabaseProvenanceRecorder {
  DatabaseProvenanceRecorder._();

  /// How long [record] waits for the app version before giving up on it and
  /// recording the rest of the entry without it.
  ///
  /// Same reasoning as `LogEnvironment.versionLookupTimeout`: a platform
  /// channel that never answers is as damaging as one that throws, and
  /// `PackageInfo.fromPlatform` never completes under `testWidgets` or in a
  /// headless isolate with no plugin registrant.
  static const Duration versionLookupTimeout = Duration(seconds: 2);

  /// Seam for the version lookup, so tests can drive it without a plugin.
  @visibleForTesting
  static Future<PackageInfo> Function() packageInfoLoader =
      PackageInfo.fromPlatform;

  /// Restores the production loader. Call from a test `tearDown` that
  /// overrode [packageInfoLoader].
  @visibleForTesting
  static void resetPackageInfoLoader() {
    packageInfoLoader = PackageInfo.fromPlatform;
  }

  /// Record that this build opened a database now sitting at [schemaVersion].
  ///
  /// [upgradedFrom] is the rung the file was on before this open, and is
  /// non-null whenever THIS open is what put the file on [schemaVersion].
  /// That is two cases, not one: the upgrade ladder ran (the rung it started
  /// from), or the file was created by this open (zero, since it was on no
  /// rung at all beforehand). `DatabaseService._openDatabase` passes both.
  ///
  /// Either way it stamps the `upgrade_*` entry, which is the one the
  /// version-mismatch screen needs: it names the build that put the file on a
  /// rung the running app cannot open, and creation and upgrade have the same
  /// answer to that question. Null means this open found the file already on
  /// [schemaVersion] and left the existing `upgrade_*` entry alone.
  ///
  /// [now] and [installIdOverride] exist so a test can assert on exact
  /// values; production passes neither.
  static Future<void> record(
    DatabaseConnectionUser db, {
    required int schemaVersion,
    int? upgradedFrom,
    DateTime? now,
    String? installIdOverride,
  }) async {
    try {
      final timestamp = (now ?? DateTime.now()).toUtc();
      final appVersion = await _resolveAppVersion();
      final installId = installIdOverride ?? await _resolveInstallId(db);
      final existing = await _readRows(db);

      final writes = <String, String?>{
        DatabaseProvenanceKeys.appVersion: appVersion,
        DatabaseProvenanceKeys.releaseTrain: BuildTrain.current,
        DatabaseProvenanceKeys.schemaVersion: '$schemaVersion',
        DatabaseProvenanceKeys.writtenAt: timestamp.toIso8601String(),
        DatabaseProvenanceKeys.installId: installId,
      };

      // Rotate only when the outgoing entry describes a DIFFERENT build,
      // train, install or rung. Rotating on every open would overwrite the
      // one genuinely interesting predecessor -- the build that came before
      // the current one -- with a copy of the current one on the very next
      // launch, which is exactly the fact #1568 needs and would lose.
      if (_describesADifferentOpen(existing, writes)) {
        writes[DatabaseProvenanceKeys.previousAppVersion] =
            existing[DatabaseProvenanceKeys.appVersion];
        writes[DatabaseProvenanceKeys.previousReleaseTrain] =
            existing[DatabaseProvenanceKeys.releaseTrain];
        writes[DatabaseProvenanceKeys.previousSchemaVersion] =
            existing[DatabaseProvenanceKeys.schemaVersion];
        writes[DatabaseProvenanceKeys.previousWrittenAt] =
            existing[DatabaseProvenanceKeys.writtenAt];
        writes[DatabaseProvenanceKeys.previousInstallId] =
            existing[DatabaseProvenanceKeys.installId];
      }

      if (upgradedFrom != null) {
        writes[DatabaseProvenanceKeys.upgradeAppVersion] = appVersion;
        writes[DatabaseProvenanceKeys.upgradeReleaseTrain] = BuildTrain.current;
        writes[DatabaseProvenanceKeys.upgradeSchemaVersion] = '$schemaVersion';
        writes[DatabaseProvenanceKeys.upgradeFromSchemaVersion] =
            '$upgradedFrom';
        writes[DatabaseProvenanceKeys.upgradeWrittenAt] = timestamp
            .toIso8601String();
        writes[DatabaseProvenanceKeys.upgradeInstallId] = installId;
      }

      await db.transaction(() async {
        for (final entry in writes.entries) {
          final value = entry.value;
          // A key we could not determine is left as it was rather than
          // written blank: the previous launch's answer beats no answer.
          if (value == null) continue;
          await db.customStatement(
            'INSERT OR REPLACE INTO '
            '${DatabaseProvenanceKeys.tableName} (key, value) VALUES (?, ?)',
            [entry.key, value],
          );
        }
      });
    } on Object {
      // Best-effort by contract; see the class doc.
    }
  }

  /// True when the entry already on the file is worth keeping as the
  /// predecessor of the one about to be written.
  static bool _describesADifferentOpen(
    Map<String, String> existing,
    Map<String, String?> incoming,
  ) {
    if (existing.isEmpty) return false;
    for (final key in const [
      DatabaseProvenanceKeys.appVersion,
      DatabaseProvenanceKeys.releaseTrain,
      DatabaseProvenanceKeys.schemaVersion,
      DatabaseProvenanceKeys.installId,
    ]) {
      // A fact this open could not determine is UNKNOWN, not different. It is
      // also not written, so treating it as a difference would rotate the real
      // predecessor away and replace it with a duplicate of the entry that is
      // staying put -- which is precisely what a headless open with no plugin
      // registrant (and so no app version) would do on every background task.
      final value = incoming[key];
      if (value == null) continue;
      if (existing[key] != value) return true;
    }
    return false;
  }

  static Future<Map<String, String>> _readRows(
    DatabaseConnectionUser db,
  ) async {
    try {
      final rows = await db
          .customSelect(
            'SELECT key, value FROM ${DatabaseProvenanceKeys.tableName}',
          )
          .get();
      return {
        for (final row in rows)
          if (row.data['key'] is String && row.data['value'] is String)
            row.data['key'] as String: row.data['value'] as String,
      };
    } on Object {
      return const {};
    }
  }

  /// The install id is `sync_metadata.device_id`, which already exists, is
  /// stable for the life of the install, and travels inside the file. Read
  /// only, never minted: creating a device id has sync consequences that a
  /// diagnostic write has no business triggering.
  static Future<String?> _resolveInstallId(DatabaseConnectionUser db) async {
    try {
      final rows = await db
          .customSelect(
            'SELECT device_id FROM sync_metadata '
            "WHERE device_id IS NOT NULL AND device_id != '' LIMIT 1",
          )
          .get();
      if (rows.isEmpty) return null;
      final value = rows.first.data['device_id'];
      return value is String && value.isNotEmpty ? value : null;
    } on Object {
      return null;
    }
  }

  /// Null rather than a placeholder when the platform will not say: the
  /// reader treats an absent key and a blank one alike, and writing nothing
  /// leaves the previous launch's answer in place.
  static Future<String?> _resolveAppVersion() async {
    try {
      final info = await packageInfoLoader().timeout(versionLookupTimeout);
      final formatted = formatAppVersion(info);
      return formatted.trim().isEmpty ? null : formatted;
    } on Object {
      return null;
    }
  }

  /// Whether a caller inside `_openDatabase` should record at all.
  ///
  /// Recording issues statements, and under `flutter test` the first
  /// statement is what forces drift's lazy open -- the laziness a whole class
  /// of tests depends on (see `DatabaseService.initialize`). Tests that want
  /// the real thing set [enabledInTests].
  static bool get shouldRecordOnOpen =>
      enabledInTests || !Platform.environment.containsKey('FLUTTER_TEST');

  /// Opt a test into the production recording path.
  @visibleForTesting
  static bool enabledInTests = false;
}

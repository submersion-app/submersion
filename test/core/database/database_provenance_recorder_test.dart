import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_provenance.dart';
import 'package:submersion/core/database/database_provenance_recorder.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../helpers/test_database.dart';

PackageInfo _info(String version, String build) => PackageInfo(
  appName: 'Submersion',
  packageName: 'app.submersion',
  version: version,
  buildNumber: build,
);

Future<DatabaseProvenanceRecord> _read(AppDatabase db) async {
  final rows = await db
      .customSelect('SELECT key, value FROM database_provenance')
      .get();
  return DatabaseProvenanceRecord.parse({
    for (final row in rows)
      row.data['key'] as String: row.data['value'] as String,
  });
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    DatabaseProvenanceRecorder.packageInfoLoader = () async =>
        _info('1.7.7', '8064');
  });

  tearDown(() async {
    DatabaseProvenanceRecorder.resetPackageInfoLoader();
    await tearDownTestDatabase();
  });

  test('records the opening build, the rung, and the time', () async {
    await DatabaseProvenanceRecorder.record(
      db,
      schemaVersion: 194,
      now: DateTime.utc(2026, 9, 5, 10),
      installIdOverride: 'device-a',
    );

    final record = await _read(db);
    expect(record.lastOpen!.appVersion, '1.7.7.8064');
    expect(record.lastOpen!.schemaVersion, 194);
    expect(record.lastOpen!.installId, 'device-a');
    expect(record.lastOpen!.writtenAt, DateTime.utc(2026, 9, 5, 10));
    // No ladder ran, so nothing claims to have upgraded the file.
    expect(record.lastUpgrade, isNull);
    expect(record.previousOpen, isNull);
  });

  test('records the release train the build came off', () async {
    await DatabaseProvenanceRecorder.record(db, schemaVersion: 194);
    final record = await _read(db);
    // The test binary carries no BUILD_TRAIN define, so it is a stable build.
    expect(record.lastOpen!.releaseTrain, 'stable');
  });

  test('stamps the upgrade entry when the ladder ran', () async {
    await DatabaseProvenanceRecorder.record(
      db,
      schemaVersion: 194,
      upgradedFrom: 191,
      now: DateTime.utc(2026, 9, 5, 10),
      installIdOverride: 'device-a',
    );

    final record = await _read(db);
    expect(record.lastUpgrade!.appVersion, '1.7.7.8064');
    expect(record.lastUpgrade!.schemaVersion, 194);
    expect(record.lastUpgrade!.fromSchemaVersion, 191);
    expect(record.lastUpgrade!.writtenAt, DateTime.utc(2026, 9, 5, 10));
  });

  test(
    'a later open by the same build leaves the upgrade entry alone',
    () async {
      // This is the fact the mismatch screen needs: the build that put the file
      // on its current rung, not the build that touched it most recently.
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 194,
        upgradedFrom: 191,
        now: DateTime.utc(2026, 9, 5, 10),
        installIdOverride: 'device-a',
      );
      DatabaseProvenanceRecorder.packageInfoLoader = () async =>
          _info('1.7.8', '8200');
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 194,
        now: DateTime.utc(2026, 9, 6, 10),
        installIdOverride: 'device-a',
      );

      final record = await _read(db);
      expect(record.lastOpen!.appVersion, '1.7.8.8200');
      expect(record.lastUpgrade!.appVersion, '1.7.7.8064');
      expect(record.lastUpgrade!.fromSchemaVersion, 191);
    },
  );

  test('stamps the upgrade entry when this open created the file', () async {
    // Creation and upgrade have the same answer to "which build put this file
    // on the rung it is on", so a fresh file records an upgrade FROM zero
    // rather than no upgrade at all. DatabaseService._openDatabase passes
    // this case.
    await DatabaseProvenanceRecorder.record(
      db,
      schemaVersion: 194,
      upgradedFrom: 0,
      now: DateTime.utc(2026, 9, 5, 10),
      installIdOverride: 'device-a',
    );

    final record = await _read(db);
    expect(record.lastUpgrade!.appVersion, '1.7.7.8064');
    expect(record.lastUpgrade!.schemaVersion, 194);
    expect(record.lastUpgrade!.fromSchemaVersion, 0);
  });

  test('rotates the outgoing entry when the build changed', () async {
    await DatabaseProvenanceRecorder.record(
      db,
      schemaVersion: 191,
      now: DateTime.utc(2026, 8, 1),
      installIdOverride: 'device-a',
    );
    DatabaseProvenanceRecorder.packageInfoLoader = () async =>
        _info('1.7.8', '8200');
    await DatabaseProvenanceRecorder.record(
      db,
      schemaVersion: 194,
      now: DateTime.utc(2026, 9, 5),
      installIdOverride: 'device-a',
    );

    final record = await _read(db);
    expect(record.lastOpen!.appVersion, '1.7.8.8200');
    expect(record.previousOpen!.appVersion, '1.7.7.8064');
    expect(record.previousOpen!.schemaVersion, 191);
    expect(record.previousOpen!.writtenAt, DateTime.utc(2026, 8, 1));
  });

  test(
    'a relaunch of the same build does not overwrite the predecessor',
    () async {
      // Rotating on every open would replace the one genuinely interesting
      // predecessor with a copy of the current build on the very next launch.
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 191,
        now: DateTime.utc(2026, 8, 1),
        installIdOverride: 'device-a',
      );
      DatabaseProvenanceRecorder.packageInfoLoader = () async =>
          _info('1.7.8', '8200');
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 194,
        now: DateTime.utc(2026, 9, 5),
        installIdOverride: 'device-a',
      );
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 194,
        now: DateTime.utc(2026, 9, 6),
        installIdOverride: 'device-a',
      );

      final record = await _read(db);
      expect(record.lastOpen!.writtenAt, DateTime.utc(2026, 9, 6));
      expect(record.previousOpen!.appVersion, '1.7.7.8064');
    },
  );

  test('rotates when the file moved to another install', () async {
    // A restored backup: same build, different device. Keeping the outgoing
    // install id is what makes the restored-backup case distinguishable from
    // the same-machine case.
    await DatabaseProvenanceRecorder.record(
      db,
      schemaVersion: 194,
      now: DateTime.utc(2026, 8, 1),
      installIdOverride: 'device-a',
    );
    await DatabaseProvenanceRecorder.record(
      db,
      schemaVersion: 194,
      now: DateTime.utc(2026, 9, 5),
      installIdOverride: 'device-b',
    );

    final record = await _read(db);
    expect(record.lastOpen!.installId, 'device-b');
    expect(record.previousOpen!.installId, 'device-a');
  });

  test(
    'an unavailable app version leaves the previous answer in place',
    () async {
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 194,
        now: DateTime.utc(2026, 8, 1),
        installIdOverride: 'device-a',
      );
      // A headless isolate has no plugin registrant, so the lookup throws.
      DatabaseProvenanceRecorder.packageInfoLoader = () async =>
          throw StateError('no plugin registrant');
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 194,
        now: DateTime.utc(2026, 9, 5),
        installIdOverride: 'device-a',
      );

      final record = await _read(db);
      expect(record.lastOpen!.appVersion, '1.7.7.8064');
      expect(record.lastOpen!.writtenAt, DateTime.utc(2026, 9, 5));
      // Unknown is not "different": rotating here would replace the real
      // predecessor with a duplicate of the entry that is staying put, on
      // every single background task.
      expect(record.previousOpen, isNull);
    },
  );

  test('a version lookup that never answers does not hang the open', () async {
    DatabaseProvenanceRecorder.packageInfoLoader = () =>
        Completer<PackageInfo>().future;
    final elapsed = Stopwatch()..start();
    await DatabaseProvenanceRecorder.record(
      db,
      schemaVersion: 194,
      now: DateTime.utc(2026, 9, 5),
      installIdOverride: 'device-a',
    ).timeout(const Duration(seconds: 20));
    elapsed.stop();

    // Non-vacuity: without this the test would pass just as happily against a
    // loader that answered instantly, proving nothing about the timeout.
    expect(
      elapsed.elapsed,
      greaterThanOrEqualTo(DatabaseProvenanceRecorder.versionLookupTimeout),
    );

    final record = await _read(db);
    expect(record.lastOpen!.appVersion, isNull);
    expect(record.lastOpen!.schemaVersion, 194);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test(
    'picks up the install id from sync_metadata when not overridden',
    () async {
      await DatabaseService.instance.database.customStatement(
        'INSERT OR REPLACE INTO sync_metadata '
        '(id, device_id, sync_version, created_at, updated_at) '
        "VALUES ('global', 'device-from-sync', 1, 1, 1)",
      );
      await DatabaseProvenanceRecorder.record(db, schemaVersion: 194);

      final record = await _read(db);
      expect(record.lastOpen!.installId, 'device-from-sync');
    },
  );

  test('a missing table costs the open nothing', () async {
    await db.customStatement('DROP TABLE database_provenance');
    await expectLater(
      DatabaseProvenanceRecorder.record(db, schemaVersion: 194),
      completes,
    );
  });
}

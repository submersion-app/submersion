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

Future<Map<String, String>> _rawRows(AppDatabase db) async {
  final rows = await db
      .customSelect('SELECT key, value FROM database_provenance')
      .get();
  return {
    for (final row in rows)
      row.data['key'] as String: row.data['value'] as String,
  };
}

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

  test('records no train at all when the build carries no stamp', () async {
    await DatabaseProvenanceRecorder.record(db, schemaVersion: 194);
    final record = await _read(db);
    // The test binary sets no BUILD_TRAIN define, which is also true of every
    // build shipping today until #1592 stamps the beta workflow. Defaulting
    // to 'stable' here would have a beta-written dive log claim the stable
    // train and send a stranded diver to the stable releases page, which is
    // the dead end #1568 is about. Absent says "unknown"; defaulted lies.
    expect(record.lastOpen!.releaseTrain, isNull);
  });

  test('records the train when the build was stamped with one', () async {
    await DatabaseProvenanceRecorder.record(
      db,
      schemaVersion: 194,
      upgradedFrom: 191,
      releaseTrainOverride: 'beta',
    );
    final record = await _read(db);
    expect(record.lastOpen!.releaseTrain, 'beta');
    expect(record.lastUpgrade!.releaseTrain, 'beta');
  });

  test(
    'an unstamped open cannot erase the train that ran the upgrade',
    () async {
      // The fact #1568 turns on: a beta build upgraded this file. Later opens
      // must not be able to launder that away, or the mismatch screen is back
      // to guessing which repository hosts the build the diver needs.
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 194,
        upgradedFrom: 191,
        now: DateTime.utc(2026, 8, 1),
        installIdOverride: 'device-a',
        releaseTrainOverride: 'beta',
      );
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 194,
        now: DateTime.utc(2026, 9, 5),
        installIdOverride: 'device-a',
      );

      final record = await _read(db);
      // The current open genuinely does not know its train, and says so.
      expect(record.lastOpen!.releaseTrain, isNull);
      // The upgrade entry is a different event and keeps its own answer.
      expect(record.lastUpgrade!.releaseTrain, 'beta');
      expect(record.lastUpgrade!.fromSchemaVersion, 191);
      // No rotation: an unknown train is not evidence of a different build, so
      // it does not count as a difference. Weakening that would have every
      // headless open rotate a near-duplicate over the real predecessor.
      expect(record.previousOpen, isNull);
    },
  );

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
    'an unavailable app version is recorded as unknown, not inherited',
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
      // Keeping 1.7.7.8064 here would be a hybrid: it would claim that build
      // performed the 9/5 open. It also would not stay put -- the next open
      // that differs rotates it into previous_*, freezing the lie into a
      // snapshot.
      expect(record.lastOpen!.appVersion, isNull);
      // Everything this open DID know stays true.
      expect(record.lastOpen!.writtenAt, DateTime.utc(2026, 9, 5));
      expect(record.lastOpen!.schemaVersion, 194);
      expect(record.lastOpen!.installId, 'device-a');
      // Unknown is still not "different": rotating here would replace the real
      // predecessor with a near-duplicate of the entry that is staying put, on
      // every single background task.
      expect(record.previousOpen, isNull);
    },
  );

  test(
    'a foreground launch restores the version a headless open cleared',
    () async {
      // The price of never inheriting is that a headless open leaves the build
      // unknown. It has to be temporary, or the file loses the answer to the
      // question it exists to answer.
      DatabaseProvenanceRecorder.packageInfoLoader = () async =>
          throw StateError('no plugin registrant');
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 194,
        now: DateTime.utc(2026, 9, 5),
        installIdOverride: 'device-a',
      );
      DatabaseProvenanceRecorder.packageInfoLoader = () async =>
          _info('1.7.7', '8064');
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 194,
        now: DateTime.utc(2026, 9, 6),
        installIdOverride: 'device-a',
      );

      final record = await _read(db);
      expect(record.lastOpen!.appVersion, '1.7.7.8064');
    },
  );

  group('a snapshot block is one event, never a hybrid of two', () {
    test('a later upgrade does not inherit the earlier build', () async {
      // The sharp case: the file is upgraded by 1.7.7, then upgraded again by
      // a build whose version cannot be resolved. Keeping the standing
      // upgrade_app_version while taking the new rungs and timestamp would
      // say 1.7.7 performed the second upgrade, which never happened -- and
      // the mismatch screen would send the diver after the wrong build.
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 194,
        upgradedFrom: 191,
        now: DateTime.utc(2026, 8, 1),
        installIdOverride: 'device-a',
      );
      DatabaseProvenanceRecorder.packageInfoLoader = () async =>
          throw StateError('no plugin registrant');
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 200,
        upgradedFrom: 194,
        now: DateTime.utc(2026, 9, 5),
        installIdOverride: 'device-a',
      );

      final record = await _read(db);
      // Incomplete is fine; misattributed is not.
      expect(record.lastUpgrade!.appVersion, isNull);
      expect(record.lastUpgrade!.schemaVersion, 200);
      expect(record.lastUpgrade!.fromSchemaVersion, 194);
      expect(record.lastUpgrade!.writtenAt, DateTime.utc(2026, 9, 5));
    });

    test('a rotation does not inherit an older predecessor build', () async {
      // Same defect one block over: rotating an outgoing entry that carries
      // no app version must not leave the build from the rotation before it
      // standing next to this one's rung and timestamp.
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 191,
        now: DateTime.utc(2026, 7, 1),
        installIdOverride: 'device-a',
      );
      DatabaseProvenanceRecorder.packageInfoLoader = () async =>
          throw StateError('no plugin registrant');
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 194,
        now: DateTime.utc(2026, 8, 1),
        installIdOverride: 'device-b',
      );
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 200,
        now: DateTime.utc(2026, 9, 5),
        installIdOverride: 'device-c',
      );

      final record = await _read(db);
      // The rotated-out entry is the device-b open, which never resolved a
      // version. It must not borrow device-a's.
      expect(record.previousOpen!.installId, 'device-b');
      expect(record.previousOpen!.schemaVersion, 194);
      expect(record.previousOpen!.appVersion, isNull);
    });
  });

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

  group('a value that says nothing is never stored', () {
    // The parser reads blank as absent, so a blank row and a missing row give
    // the same record. These assert on the RAW rows, because the difference
    // they are about is invisible through the parser.
    test('a blank train is deleted rather than persisted', () async {
      // An empty --dart-define=BUILD_TRAIN= is present but empty, so the
      // stamp check passes and the train is the empty string.
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 194,
        releaseTrainOverride: '   ',
      );

      expect(await _rawRows(db), isNot(contains('release_train')));
    });

    test('a whitespace install id is deleted rather than persisted', () async {
      // Past the `device_id != ''` guard on the read, which catches empty but
      // not whitespace.
      await DatabaseProvenanceRecorder.record(
        db,
        schemaVersion: 194,
        installIdOverride: ' \t ',
      );

      expect(await _rawRows(db), isNot(contains('install_id')));
    });

    test(
      'a blank value a future build stored is not rotated forward',
      () async {
        // Rotation copies the existing rows verbatim, so a blank one written by
        // a build this code has never met would otherwise propagate into the
        // previous_* block.
        await db.customStatement(
          "INSERT OR REPLACE INTO database_provenance (key, value) "
          "VALUES ('release_train', '   ')",
        );
        await DatabaseProvenanceRecorder.record(
          db,
          schemaVersion: 194,
          now: DateTime.utc(2026, 8, 1),
          installIdOverride: 'device-a',
        );
        await DatabaseProvenanceRecorder.record(
          db,
          schemaVersion: 200,
          now: DateTime.utc(2026, 9, 5),
          installIdOverride: 'device-a',
        );

        final raw = await _rawRows(db);
        expect(raw, isNot(contains('previous_release_train')));
        expect(raw, isNot(contains('release_train')));
      },
    );

    test(
      'a stored value is trimmed so the table agrees with the parse',
      () async {
        await DatabaseProvenanceRecorder.record(
          db,
          schemaVersion: 194,
          installIdOverride: '  device-a  ',
        );

        expect((await _rawRows(db))['install_id'], 'device-a');
        expect((await _read(db)).lastOpen!.installId, 'device-a');
      },
    );

    test('whitespace alone does not count as a different open', () async {
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
        installIdOverride: '  device-a  ',
      );

      // A spurious rotation here would push the real predecessor out.
      expect((await _read(db)).previousOpen, isNull);
    });
  });

  test('a missing table costs the open nothing', () async {
    await db.customStatement('DROP TABLE database_provenance');
    await expectLater(
      DatabaseProvenanceRecorder.record(db, schemaVersion: 194),
      completes,
    );
  });
}

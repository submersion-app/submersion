import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/pre_downgrade_backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';

class Fixture {
  final Directory tmp;
  final String livePath;
  final String backupsDir;
  final BackupPreferences prefs;

  Fixture({
    required this.tmp,
    required this.livePath,
    required this.backupsDir,
    required this.prefs,
  });

  Future<void> dispose() async => tmp.delete(recursive: true);
}

Future<Fixture> makeFixture({bool createLive = true}) async {
  final tmp = await Directory.systemTemp.createTemp('pdbs_test_');
  final live = File(p.join(tmp.path, 'submersion.db'));
  if (createLive) {
    await live.writeAsBytes(List<int>.generate(2048, (i) => i % 256));
  }
  final backupsDir = Directory(p.join(tmp.path, 'backups'));
  await backupsDir.create();
  SharedPreferences.setMockInitialValues({});
  final prefs = BackupPreferences(await SharedPreferences.getInstance());
  return Fixture(
    tmp: tmp,
    livePath: live.path,
    backupsDir: backupsDir.path,
    prefs: prefs,
  );
}

PreDowngradeBackupService buildService(
  Fixture f, {
  String? backupsDir,
  String? fallbackDir,
  Future<int> Function(String path)? sizeReader,
}) {
  return PreDowngradeBackupService(
    livePathProvider: () async => f.livePath,
    backupsDirProvider: () async => backupsDir ?? f.backupsDir,
    fallbackBackupsDirProvider: fallbackDir == null
        ? null
        : () async => fallbackDir,
    preferences: f.prefs,
    clock: () => DateTime.utc(2026, 9, 5, 8, 12, 1),
    idGenerator: () => 'kept-1',
    sizeReader: sizeReader,
  );
}

void main() {
  test('copies the newer database into the backups folder', () async {
    final f = await makeFixture();
    addTearDown(f.dispose);

    final record = await buildService(
      f,
    ).preserve(storedSchemaVersion: 191, appVersion: '1.8.0.7300');

    expect(record.localPath, isNotNull);
    final copied = File(record.localPath!);
    expect(copied.existsSync(), isTrue);
    expect(
      copied.readAsBytesSync(),
      File(f.livePath).readAsBytesSync(),
      reason: 'the preserved copy must be the newer database byte for byte',
    );
    // Names the schema it holds, so a later mismatch can tell that THIS build
    // still cannot open it.
    expect(p.basename(copied.path), '20260905-081201000-v191-newer.db');
  });

  test(
    'registers the copy pinned, so no retention path can prune it',
    () async {
      final f = await makeFixture();
      addTearDown(f.dispose);

      await buildService(
        f,
      ).preserve(storedSchemaVersion: 191, appVersion: '1.8.0.7300');

      final history = f.prefs.getHistory();
      expect(history, hasLength(1));
      final record = history.single;
      expect(record.type, BackupType.preDowngrade);
      expect(record.pinned, isTrue);
      expect(record.fromSchemaVersion, 191);
      expect(
        record.toSchemaVersion,
        isNull,
        reason: 'nothing was migrated; this copy is where the file stopped',
      );
      expect(record.location, BackupLocation.local);
      expect(record.appVersion, '1.8.0.7300');
    },
  );

  test('a type an older build cannot name still keeps its pin', () {
    // The forward-compat contract this record depends on. An older build has
    // no `preDowngrade` in its enum, so BackupRecord._parseType falls back to
    // manual -- which is where that build's manual retention would find it.
    // `pinned` is the one flag every retention path honours, and it has to
    // survive the round trip that loses the type.
    final decoded = BackupRecord.fromJson({
      'id': 'kept-1',
      'filename': 'newer.db',
      'timestamp': DateTime.utc(2026, 9, 5).millisecondsSinceEpoch,
      'sizeBytes': 2048,
      'location': 'local',
      'type': 'aTypeFromTheFuture',
      'pinned': true,
      'fromSchemaVersion': 191,
    });

    expect(decoded.type, BackupType.manual);
    expect(decoded.pinned, isTrue);
  });

  test(
    'falls back to the default location when the preferred one fails',
    () async {
      final f = await makeFixture();
      addTearDown(f.dispose);
      final fallback = p.join(f.tmp.path, 'fallback');

      final record = await buildService(
        f,
        // A path under a FILE, so directory creation cannot succeed.
        backupsDir: p.join(f.livePath, 'nope'),
        fallbackDir: fallback,
      ).preserve(storedSchemaVersion: 191, appVersion: '1.8.0.7300');

      expect(p.dirname(record.localPath!), fallback);
      expect(File(record.localPath!).existsSync(), isTrue);
    },
  );

  test('a stat failure after the copy does not abort the restore', () async {
    final f = await makeFixture();
    addTearDown(f.dispose);

    // The bytes are already aside by this point, which is the whole
    // guarantee this service owes its caller. Throwing here would strand the
    // diver on the mismatch screen next to a copy they cannot see -- and it
    // is the caller's abort-on-throw contract that makes that a real cost.
    final record = await buildService(
      f,
      sizeReader: (_) async => throw const FileSystemException('stat failed'),
    ).preserve(storedSchemaVersion: 191, appVersion: '1.8.0.7300');

    // 0 is what the non-nullable field carries for "not measured"; the
    // service logs that it shows as "0 B" rather than claiming unknown.
    expect(record.sizeBytes, 0);
    expect(record.formattedSize, '0 B');
    expect(File(record.localPath!).existsSync(), isTrue);
    // Still registered, so the diver can find it in the backup list.
    final history = f.prefs.getHistory();
    expect(history.single.type, BackupType.preDowngrade);
    expect(history.single.pinned, isTrue);
  });

  test('throws when there is no database to preserve', () async {
    final f = await makeFixture(createLive: false);
    addTearDown(f.dispose);

    // The caller is about to restore over this path. A missing live database
    // means its picture of the world is wrong, so it must not proceed.
    await expectLater(
      buildService(f).preserve(storedSchemaVersion: 191, appVersion: '1.8.0'),
      throwsA(isA<BackupFailedException>()),
    );
    expect(f.prefs.getHistory(), isEmpty);
  });

  test('throws when the live path cannot even be resolved', () async {
    final f = await makeFixture();
    addTearDown(f.dispose);

    await expectLater(
      PreDowngradeBackupService(
        livePathProvider: () async => throw StateError('no location service'),
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
      ).preserve(storedSchemaVersion: 191, appVersion: '1.8.0'),
      throwsA(isA<BackupFailedException>()),
    );
    expect(f.prefs.getHistory(), isEmpty);
  });

  test('throws when the fallback location fails too', () async {
    final f = await makeFixture();
    addTearDown(f.dispose);

    // Both paths are under a FILE, so neither directory can be created.
    // Nothing was copied aside, so the caller must abandon the restore.
    await expectLater(
      buildService(
        f,
        backupsDir: p.join(f.livePath, 'nope'),
        fallbackDir: p.join(f.livePath, 'also-nope'),
      ).preserve(storedSchemaVersion: 191, appVersion: '1.8.0'),
      throwsA(isA<BackupFailedException>()),
    );
    expect(f.prefs.getHistory(), isEmpty);
  });

  test('the default id generator produces a UUID-shaped id', () async {
    final f = await makeFixture();
    addTearDown(f.dispose);

    final record = await PreDowngradeBackupService(
      livePathProvider: () async => f.livePath,
      backupsDirProvider: () async => f.backupsDir,
      preferences: f.prefs,
    ).preserve(storedSchemaVersion: 191, appVersion: '1.8.0');

    expect(
      record.id,
      matches(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      ),
    );
  });

  test('throws when the copy cannot be written anywhere', () async {
    final f = await makeFixture();
    addTearDown(f.dispose);

    await expectLater(
      buildService(
        f,
        backupsDir: p.join(f.livePath, 'nope'),
      ).preserve(storedSchemaVersion: 191, appVersion: '1.8.0'),
      throwsA(isA<BackupFailedException>()),
    );
    expect(f.prefs.getHistory(), isEmpty);
  });
}

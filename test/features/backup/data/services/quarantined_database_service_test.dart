import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/backup/data/services/quarantined_database_service.dart';
import 'package:submersion/features/backup/domain/entities/quarantined_database.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quarantined_db_test_');
    dbPath = p.join(tempDir.path, 'submersion.db');
    await File(dbPath).writeAsString('live');
  });

  tearDown(() => tempDir.delete(recursive: true));

  /// Writes [name] in the database folder with [bytes] bytes of content.
  Future<String> writeFile(String name, {int bytes = 10}) async {
    final path = p.join(tempDir.path, name);
    await File(path).writeAsBytes(List.filled(bytes, 1));
    return path;
  }

  /// A service whose probe answers from [versions] by file name, recording
  /// every path and key it was asked about.
  QuarantinedDatabaseService serviceWith({
    Map<String, int?> versions = const {},
    String? keyHex,
    List<(String, String?)>? probed,
  }) => QuarantinedDatabaseService(
    databasePath: () async => dbPath,
    keyHex: () => keyHex,
    probe: (path, {required keyHex}) {
      probed?.add((path, keyHex));
      return versions[p.basename(path)];
    },
  );

  group('parseQuarantinedName', () {
    test('reads a pre-restore copy and its UTC timestamp', () {
      final parsed = parseQuarantinedName(
        'submersion.db',
        'submersion.db.pre-restore.20260926T134501Z',
      );

      expect(parsed, isNotNull);
      expect(parsed!.mainName, 'submersion.db.pre-restore.20260926T134501Z');
      expect(parsed.kind, QuarantineKind.preRestore);
      expect(parsed.quarantinedAt, DateTime.utc(2026, 9, 26, 13, 45, 1));
      expect(parsed.sidecar, isNull);
    });

    test('reads a rejected copy with a collision suffix and a sidecar', () {
      final parsed = parseQuarantinedName(
        'submersion.db',
        'submersion.db.restore-rejected.20260101T000000Z-2-wal',
      );

      expect(parsed, isNotNull);
      expect(
        parsed!.mainName,
        'submersion.db.restore-rejected.20260101T000000Z-2',
      );
      expect(parsed.kind, QuarantineKind.restoreRejected);
      expect(parsed.sidecar, '-wal');
    });

    test('ignores the live database, the unsettled aside copy and other '
        'restore temp files', () {
      for (final name in [
        'submersion.db',
        'submersion.db-wal',
        'submersion.db.pre-restore',
        'submersion.db.pre-restore-wal',
        'submersion.db.restore-pending',
        'submersion.db.restore-staging',
        'other.db.pre-restore.20260926T134501Z',
        'submersion.db.pre-restore.20260926T134501Z.bak',
        'submersion.db.pre-restore.2026-09-26',
      ]) {
        expect(
          parseQuarantinedName('submersion.db', name),
          isNull,
          reason: name,
        );
      }
    });

    test('treats the database file name literally, not as a pattern', () {
      expect(
        parseQuarantinedName(
          'submersion.db',
          'submersionXdb.pre-restore.20260926T134501Z',
        ),
        isNull,
      );
    });
  });

  group('find', () {
    test('returns nothing when no copy was set aside', () async {
      expect(await serviceWith().find(), isEmpty);
    });

    test('groups a copy with its sidecars and totals their size', () async {
      final main = await writeFile(
        'submersion.db.pre-restore.20260926T134501Z',
        bytes: 100,
      );
      final wal = await writeFile(
        'submersion.db.pre-restore.20260926T134501Z-wal',
        bytes: 20,
      );
      final shm = await writeFile(
        'submersion.db.pre-restore.20260926T134501Z-shm',
        bytes: 3,
      );

      final copies = await serviceWith(versions: {p.basename(main): 70}).find();

      expect(copies, hasLength(1));
      final copy = copies.single;
      expect(copy.path, main);
      expect(copy.kind, QuarantineKind.preRestore);
      expect(copy.quarantinedAt, DateTime.utc(2026, 9, 26, 13, 45, 1));
      expect(copy.files, unorderedEquals([main, wal, shm]));
      expect(copy.sizeBytes, 123);
      expect(copy.schemaVersion, 70);
      expect(copy.status, QuarantinedDatabaseStatus.restorable);
    });

    test('lists copies newest first', () async {
      await writeFile('submersion.db.pre-restore.20250101T000000Z');
      await writeFile('submersion.db.restore-rejected.20260601T120000Z');
      await writeFile('submersion.db.pre-restore.20260301T000000Z');

      final copies = await serviceWith().find();

      expect(copies.map((c) => c.quarantinedAt), [
        DateTime.utc(2026, 6, 1, 12),
        DateTime.utc(2026, 3, 1),
        DateTime.utc(2025, 1, 1),
      ]);
    });

    test('classifies each copy by what this build can do with it', () async {
      const current = AppDatabase.currentSchemaVersion;
      await writeFile('submersion.db.pre-restore.20260101T000000Z');
      await writeFile('submersion.db.pre-restore.20260102T000000Z');
      await writeFile('submersion.db.pre-restore.20260103T000000Z');
      await writeFile('submersion.db.pre-restore.20260104T000000Z');
      await writeFile('submersion.db.pre-restore.20260105T000000Z-wal');

      final copies = await serviceWith(
        versions: {
          'submersion.db.pre-restore.20260101T000000Z': current,
          'submersion.db.pre-restore.20260102T000000Z': current + 1,
          'submersion.db.pre-restore.20260103T000000Z': null,
          // Version 0 is a zero-byte or foreign file, never a Submersion
          // database, exactly as the restore journal treats it.
          'submersion.db.pre-restore.20260104T000000Z': 0,
        },
      ).find();

      final byDay = {for (final c in copies) c.quarantinedAt.day: c};
      expect(byDay[1]!.status, QuarantinedDatabaseStatus.restorable);
      expect(byDay[2]!.status, QuarantinedDatabaseStatus.needsNewerApp);
      expect(byDay[2]!.schemaVersion, current + 1);
      expect(byDay[3]!.status, QuarantinedDatabaseStatus.unreadable);
      expect(byDay[4]!.status, QuarantinedDatabaseStatus.unreadable);
      expect(byDay[5]!.status, QuarantinedDatabaseStatus.incomplete);
      expect(byDay[5]!.path, endsWith('.20260105T000000Z'));
    });

    test('never probes a sidecar-only copy', () async {
      await writeFile('submersion.db.pre-restore.20260105T000000Z-wal');
      final probed = <(String, String?)>[];

      await serviceWith(probed: probed).find();

      expect(probed, isEmpty);
    });

    test('probes with the live key', () async {
      final main = await writeFile(
        'submersion.db.pre-restore.20260101T000000Z',
      );
      final probed = <(String, String?)>[];

      await serviceWith(keyHex: 'abc123', probed: probed).find();

      expect(probed, [(main, 'abc123')]);
    });

    test('ignores directories that happen to match the name', () async {
      await Directory(
        p.join(tempDir.path, 'submersion.db.pre-restore.20260101T000000Z'),
      ).create();

      expect(await serviceWith().find(), isEmpty);
    });

    test('returns nothing when the database folder does not exist', () async {
      final service = QuarantinedDatabaseService(
        databasePath: () async =>
            p.join(tempDir.path, 'missing', 'submersion.db'),
        keyHex: () => null,
      );

      expect(await service.find(), isEmpty);
    });

    test('reads a real database copy with the default probe', () async {
      final path = p.join(
        tempDir.path,
        'submersion.db.restore-rejected.20260101T000000Z',
      );
      final db = sqlite3.sqlite3.open(path);
      db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
      db.execute('PRAGMA user_version = 60');
      db.close();

      final copies = await QuarantinedDatabaseService(
        databasePath: () async => dbPath,
        keyHex: () => null,
      ).find();

      expect(copies.single.schemaVersion, 60);
      expect(copies.single.status, QuarantinedDatabaseStatus.restorable);
    });
  });

  group('delete', () {
    test('removes the copy and both sidecars, and nothing else', () async {
      await writeFile('submersion.db.pre-restore.20260101T000000Z');
      await writeFile('submersion.db.pre-restore.20260101T000000Z-wal');
      await writeFile('submersion.db.pre-restore.20260101T000000Z-shm');
      final other = await writeFile(
        'submersion.db.pre-restore.20260202T000000Z',
      );
      final service = serviceWith();
      final copy = (await service.find()).firstWhere(
        (c) => c.quarantinedAt.month == 1,
      );

      await service.delete(copy);

      final left = tempDir.listSync().map((e) => p.basename(e.path)).toSet();
      expect(left, {'submersion.db', p.basename(other)});
    });

    test('removes a sidecar-only copy', () async {
      await writeFile('submersion.db.pre-restore.20260105T000000Z-shm');
      final service = serviceWith();

      await service.delete((await service.find()).single);

      expect(await service.find(), isEmpty);
    });

    test('removes sidecars that appeared after the list was read', () async {
      await writeFile('submersion.db.pre-restore.20260101T000000Z');
      final service = serviceWith();
      final copy = (await service.find()).single;
      await writeFile('submersion.db.pre-restore.20260101T000000Z-wal');

      await service.delete(copy);

      expect(await service.find(), isEmpty);
    });

    test('refuses a path that is not a quarantined copy', () async {
      final service = serviceWith();
      final live = QuarantinedDatabase(
        path: dbPath,
        kind: QuarantineKind.preRestore,
        quarantinedAt: DateTime.utc(2026),
        files: [dbPath],
        sizeBytes: 4,
        status: QuarantinedDatabaseStatus.restorable,
      );

      await expectLater(service.delete(live), throwsArgumentError);
      expect(File(dbPath).existsSync(), isTrue);
    });

    test('refuses a quarantined name outside the database folder', () async {
      final elsewhere = await Directory.systemTemp.createTemp('elsewhere_');
      addTearDown(() => elsewhere.delete(recursive: true));
      final path = p.join(
        elsewhere.path,
        'submersion.db.pre-restore.20260101T000000Z',
      );
      await File(path).writeAsString('x');
      final copy = QuarantinedDatabase(
        path: path,
        kind: QuarantineKind.preRestore,
        quarantinedAt: DateTime.utc(2026),
        files: [path],
        sizeBytes: 1,
        status: QuarantinedDatabaseStatus.restorable,
      );

      await expectLater(serviceWith().delete(copy), throwsArgumentError);
      expect(File(path).existsSync(), isTrue);
    });
  });
}

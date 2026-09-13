import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/restore_journal.dart';

void main() {
  const current = AppDatabase.currentSchemaVersion;
  final clock = DateTime.utc(2026, 9, 13, 10, 30, 5);

  late Directory dir;
  late String db;

  // What the fake schema reader reports per path. A path absent from the map
  // reads as null, which is what the real reader returns for a missing file.
  late Map<String, int?> versions;
  // Paths the fake reader cannot open (it throws, as a corrupt or locked file
  // does with the real reader).
  late Set<String> unreadable;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('restore-journal-test');
    db = p.join(dir.path, 'submersion.db');
    versions = {};
    unreadable = {};
  });

  tearDown(() => dir.deleteSync(recursive: true));

  RestoreJournal journal() => RestoreJournal(
    db,
    readSchemaVersion: (path) {
      if (unreadable.contains(path)) throw StateError('cannot open $path');
      return versions[path];
    },
    now: () => clock,
  );

  void touch(String path, [String content = 'x']) =>
      File(path).writeAsStringSync(content);
  bool exists(String path) => File(path).existsSync();
  String read(String path) => File(path).readAsStringSync();

  group('classifyPreRestore', () {
    test('none when nothing is aside', () {
      touch(db);
      versions[db] = current;
      expect(journal().classifyPreRestore(), PreRestoreState.none);
    });

    test('precious whenever the marker exists, even beside a healthy '
        'live file', () {
      touch(db);
      versions[db] = current;
      touch('$db.pre-restore');
      touch('$db.restore-pending');
      expect(journal().classifyPreRestore(), PreRestoreState.precious);
    });

    test('stale without a marker when the live file opens at this schema', () {
      touch(db);
      versions[db] = current;
      touch('$db.pre-restore');
      expect(journal().classifyPreRestore(), PreRestoreState.stale);
    });

    for (final (label, arrange) in <(String, void Function())>[
      ('the live file is missing', () {}),
      (
        'the live file cannot be opened',
        () {
          touch(db);
          unreadable.add(db);
        },
      ),
      (
        'the live file reports no version',
        () {
          touch(db);
          versions[db] = null;
        },
      ),
      (
        'the live file reports version 0',
        () {
          touch(db);
          versions[db] = 0;
        },
      ),
      (
        'the live file is newer than this build',
        () {
          touch(db);
          versions[db] = current + 1;
        },
      ),
    ]) {
      test('precious without a marker when $label', () {
        touch('$db.pre-restore');
        arrange();
        expect(journal().classifyPreRestore(), PreRestoreState.precious);
      });
    }

    test('an orphaned aside sidecar counts as something aside', () {
      // Left alone, it would pair with the next swap's aside copy.
      touch(db);
      versions[db] = current;
      touch('$db.pre-restore-wal');
      expect(journal().classifyPreRestore(), PreRestoreState.stale);
    });
  });

  group('quarantine', () {
    test('moves the file and its sidecars to a UTC timestamped name', () async {
      touch('$db.pre-restore', 'main');
      touch('$db.pre-restore-wal', 'wal');
      touch('$db.pre-restore-shm', 'shm');

      final kept = await journal().quarantine('$db.pre-restore');

      expect(kept, '$db.pre-restore.20260913T103005Z');
      expect(read(kept), 'main');
      expect(read('$kept-wal'), 'wal');
      expect(read('$kept-shm'), 'shm');
      expect(exists('$db.pre-restore'), isFalse);
      expect(exists('$db.pre-restore-wal'), isFalse);
      expect(exists('$db.pre-restore-shm'), isFalse);
    });

    test('never overwrites an earlier quarantined copy', () async {
      touch('$db.pre-restore.20260913T103005Z', 'earlier');
      touch('$db.pre-restore', 'later');

      final kept = await journal().quarantine('$db.pre-restore');

      expect(kept, '$db.pre-restore.20260913T103005Z-1');
      expect(read('$db.pre-restore.20260913T103005Z'), 'earlier');
      expect(read(kept), 'later');
    });

    test('names the copy after the prefix when one is given', () async {
      touch(db, 'rejected');

      final kept = await journal().quarantine(
        db,
        prefix: '$db.restore-rejected',
      );

      expect(kept, '$db.restore-rejected.20260913T103005Z');
      expect(read(kept), 'rejected');
      expect(exists(db), isFalse);
    });

    test('moves orphaned sidecars even when the main file is gone', () async {
      touch('$db.pre-restore-wal', 'wal');

      final kept = await journal().quarantine('$db.pre-restore');

      expect(read('$kept-wal'), 'wal');
      expect(exists('$db.pre-restore-wal'), isFalse);
    });
  });

  group('marker', () {
    test('begin records the start time; commit removes the marker', () async {
      final j = journal();

      await j.begin();
      expect(j.hasMarker, isTrue);
      expect(jsonDecode(read(j.markerPath)), {
        'startedAt': '2026-09-13T10:30:05.000Z',
      });

      await j.commit();
      expect(j.hasMarker, isFalse);
    });

    test('commit deletes through the injected deleter', () async {
      final deleted = <String>[];
      final j = RestoreJournal(
        db,
        readSchemaVersion: (_) => null,
        deleteFile: (path) async => deleted.add(path),
      );

      await j.commit();

      expect(deleted, ['$db.restore-pending']);
    });
  });
}

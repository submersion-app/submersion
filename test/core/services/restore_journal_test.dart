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

    test('moves nothing when a sidecar cannot follow the main file', () async {
      // A directory where the -wal must go makes that one rename fail. The
      // main file had already moved; it must come back rather than leave the
      // database split from its journal.
      touch('$db.pre-restore', 'main');
      touch('$db.pre-restore-wal', 'wal');
      Directory('$db.pre-restore.20260913T103005Z-wal').createSync();

      await expectLater(
        journal().quarantine('$db.pre-restore'),
        throwsA(isA<FileSystemException>()),
      );

      expect(read('$db.pre-restore'), 'main');
      expect(read('$db.pre-restore-wal'), 'wal');
      expect(exists('$db.pre-restore.20260913T103005Z'), isFalse);
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

  group('pendingAsidePath', () {
    test('null when nothing is aside', () {
      touch(db);
      expect(journal().pendingAsidePath, isNull);
    });

    test('the aside copy while the marker says the restore is unsettled', () {
      touch(db);
      touch('$db.pre-restore');
      touch('$db.restore-pending');
      expect(journal().pendingAsidePath, '$db.pre-restore');
    });

    test('the aside copy when nothing is live, marker or not', () {
      touch('$db.pre-restore');
      expect(journal().pendingAsidePath, '$db.pre-restore');
    });

    test('null for an unmarked leftover beside a live file', () {
      touch(db);
      touch('$db.pre-restore');
      expect(journal().pendingAsidePath, isNull);
    });
  });

  group('findInterrupted', () {
    // The state an unsettled restore leaves: the original aside (openable
    // here), a rejected file live, and the marker.
    void stranded({bool marker = true, bool live = true}) {
      touch('$db.pre-restore');
      versions['$db.pre-restore'] = current;
      if (live) {
        touch(db);
        versions[db] = current + 1;
      }
      if (marker) {
        touch(
          '$db.restore-pending',
          jsonEncode({'startedAt': '2026-09-13T10:30:05.000Z'}),
        );
      }
    }

    test('reports a stranded original with its start time', () {
      stranded();
      final found = journal().findInterrupted();
      expect(found, isNotNull);
      expect(found!.startedAt, DateTime.utc(2026, 9, 13, 10, 30, 5));
      expect(found.liveExists, isTrue);
    });

    test('reports an empty live path', () {
      stranded(live: false);
      expect(journal().findInterrupted()!.liveExists, isFalse);
    });

    test('finds a leftover from a build without the journal, undated', () {
      stranded(marker: false);
      final found = journal().findInterrupted();
      expect(found, isNotNull);
      expect(found!.startedAt, isNull);
    });

    test('an unreadable marker still counts, undated', () {
      stranded();
      touch('$db.restore-pending', 'not json');
      expect(journal().findInterrupted()!.startedAt, isNull);
    });

    test('nothing when the aside copy is stale', () {
      touch(db);
      versions[db] = current;
      touch('$db.pre-restore');
      versions['$db.pre-restore'] = current;
      expect(journal().findInterrupted(), isNull);
    });

    test('nothing when this build cannot open the aside copy', () {
      // An offer that fails the same way the database just did would repeat
      // the dead end; the restore guard still protects the file.
      stranded();
      versions['$db.pre-restore'] = current + 1;
      expect(journal().findInterrupted(), isNull);
      expect(exists('$db.pre-restore'), isTrue);
    });

    test('clears a marker with nothing aside', () {
      touch('$db.restore-pending');
      expect(journal().findInterrupted(), isNull);
      expect(exists('$db.restore-pending'), isFalse);
    });
  });

  group('recover', () {
    test('puts the original back and keeps the rejected file', () async {
      touch('$db.pre-restore', 'original');
      touch('$db.pre-restore-wal', 'original-wal');
      touch(db, 'rejected');
      touch('$db-wal', 'rejected-wal');
      touch('$db.restore-pending');

      await journal().recover();

      expect(read(db), 'original');
      expect(read('$db-wal'), 'original-wal');
      expect(read('$db.restore-rejected.20260913T103005Z'), 'rejected');
      expect(read('$db.restore-rejected.20260913T103005Z-wal'), 'rejected-wal');
      expect(exists('$db.pre-restore'), isFalse);
      expect(exists('$db.pre-restore-wal'), isFalse);
      expect(exists('$db.restore-pending'), isFalse);
    });

    test('with an empty live path, only moves the original back', () async {
      touch('$db.pre-restore', 'original');
      touch('$db.restore-pending');

      await journal().recover();

      expect(read(db), 'original');
      expect(
        dir.listSync().map((e) => p.basename(e.path)),
        isNot(contains(startsWith('submersion.db.restore-rejected'))),
      );
      expect(exists('$db.restore-pending'), isFalse);
    });

    test('leaves the original aside, whole, when its -wal cannot follow it '
        'back', () async {
      touch('$db.pre-restore', 'original');
      touch('$db.pre-restore-wal', 'original-wal');
      touch('$db.restore-pending');
      Directory('$db-wal').createSync();

      await expectLater(
        journal().recover(),
        throwsA(isA<FileSystemException>()),
      );

      expect(read('$db.pre-restore'), 'original');
      expect(read('$db.pre-restore-wal'), 'original-wal');
      expect(exists(db), isFalse);
      expect(
        exists('$db.restore-pending'),
        isTrue,
        reason: 'still unsettled, so the next launch offers recovery again',
      );
    });

    test('finishes after a crash that already moved the rejected file '
        'away', () async {
      touch('$db.pre-restore', 'original');
      touch(db, 'rejected');
      touch('$db.restore-pending');
      final j = journal();
      // Step 1 ran, then the app died before the original moved back.
      await j.quarantine(db, prefix: '$db.restore-rejected');

      await j.recover();

      expect(read(db), 'original');
      expect(read('$db.restore-rejected.20260913T103005Z'), 'rejected');
      expect(exists('$db.restore-pending'), isFalse);
    });
  });

  group('keepCurrent', () {
    test('keeps the original under a timestamped name and settles the '
        'journal', () async {
      touch('$db.pre-restore', 'original');
      touch(db, 'current');
      touch('$db.restore-pending');

      await journal().keepCurrent();

      expect(read(db), 'current');
      expect(read('$db.pre-restore.20260913T103005Z'), 'original');
      expect(exists('$db.pre-restore'), isFalse);
      expect(exists('$db.restore-pending'), isFalse);
    });
  });
}

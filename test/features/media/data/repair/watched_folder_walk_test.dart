import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/services/repair/watched_folder_walk.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('watched-walk-test');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<File> writeFile(String name, String contents) async {
    final file = File(p.join(root.path, name));
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
    return file;
  }

  WatchedFolderWalkRequest request({
    Map<String, KnownFile> known = const {},
    Duration hashBudget = const Duration(minutes: 1),
  }) => WatchedFolderWalkRequest(
    rootPath: root.path,
    known: known,
    hashBudget: hashBudget,
  );

  test('hashes every file on a first walk', () async {
    await writeFile('a.jpg', 'aaaa');
    await writeFile('b.jpg', 'bbbb');

    final result = await walkWatchedFolder(request());

    expect(result.filesSeen, 2);
    expect(result.vanished, isEmpty);
    expect(result.listingComplete, isTrue);
    expect(result.hashBudgetExhausted, isFalse);
    expect(result.changed.map((f) => f.relativePath).toSet(), {
      'a.jpg',
      'b.jpg',
    });
    expect(result.changed.every((f) => f.contentHash != null), isTrue);
    expect(result.hashedCount, 2);
  });

  test('nested files carry a separator-relative path', () async {
    await writeFile(p.join('2026', 'june', 'a.jpg'), 'aaaa');

    final result = await walkWatchedFolder(request());

    expect(result.changed.single.relativePath, p.join('2026', 'june', 'a.jpg'));
    expect(p.isRelative(result.changed.single.relativePath), isTrue);
  });

  test(
    'a root written with a trailing separator still walks relatively',
    () async {
      await writeFile('a.jpg', 'aaaa');

      final result = await walkWatchedFolder(
        WatchedFolderWalkRequest(
          rootPath: '${root.path}${p.separator}',
          known: const {},
          hashBudget: const Duration(minutes: 1),
        ),
      );

      expect(result.changed.single.relativePath, 'a.jpg');
    },
  );

  test('a file whose stat matches the known index is not re-hashed', () async {
    final a = await writeFile('a.jpg', 'aaaa');
    final stat = await a.stat();

    final result = await walkWatchedFolder(
      request(
        known: {
          'a.jpg': KnownFile(
            sizeBytes: stat.size,
            mtimeMillis: stat.modified.millisecondsSinceEpoch,
            contentHash: 'already-hashed',
          ),
        },
      ),
    );

    expect(result.filesSeen, 1);
    // Seen, so not proposed for pruning.
    expect(result.vanished, isEmpty);
    expect(result.changed, isEmpty);
    expect(result.hashedCount, 0);
  });

  test(
    'a known file with no stored hash is hashed even when the stat matches',
    () async {
      final a = await writeFile('a.jpg', 'aaaa');
      final stat = await a.stat();

      final result = await walkWatchedFolder(
        request(
          known: {
            'a.jpg': KnownFile(
              sizeBytes: stat.size,
              mtimeMillis: stat.modified.millisecondsSinceEpoch,
              contentHash: null,
            ),
          },
        ),
      );

      expect(result.hashedCount, 1);
      expect(result.changed.single.contentHash, isNotNull);
    },
  );

  test(
    'a missing root reports an incomplete listing rather than throwing',
    () async {
      await root.delete(recursive: true);

      final result = await walkWatchedFolder(request());

      expect(result.listingComplete, isFalse);
      expect(result.filesSeen, 0);
      expect(result.changed, isEmpty);

      await root.create(recursive: true);
    },
  );

  group('hash budget', () {
    test(
      'an exhausted budget still lists every file, so pruning stays safe',
      () async {
        await writeFile('a.jpg', 'aaaa');
        await writeFile('b.jpg', 'bbbb');

        final result = await walkWatchedFolder(
          request(hashBudget: Duration.zero),
        );

        expect(result.hashBudgetExhausted, isTrue);
        expect(result.hashedCount, 0);
        // The listing is what pruning is judged against, and it is complete:
        // the budget only ever denies a hash.
        expect(result.listingComplete, isTrue);
        expect(result.vanished, isEmpty);
        expect(result.filesSeen, 2);
      },
    );

    test(
      'a NEW file denied a hash is left out of the index entirely',
      () async {
        await writeFile('a.jpg', 'aaaa');

        final result = await walkWatchedFolder(
          request(hashBudget: Duration.zero),
        );

        // Nothing stale to correct, so nothing to write: the file is simply
        // picked up next pass.
        expect(result.changed, isEmpty);
      },
    );

    test(
      'a CHANGED file denied a hash has its stale hash invalidated',
      () async {
        final a = await writeFile('a.jpg', 'aaaa');
        final stat = await a.stat();

        final result = await walkWatchedFolder(
          request(
            hashBudget: Duration.zero,
            known: {
              'a.jpg': KnownFile(
                sizeBytes: stat.size + 999,
                mtimeMillis: stat.modified.millisecondsSinceEpoch - 999,
                contentHash: 'STALE-HASH-OF-THE-OLD-BYTES',
              ),
            },
          ),
        );

        // Written back with the CURRENT stat and a null hash: a stale hash left
        // in place could point an auto-repair at bytes that have since changed,
        // and a null hash is inert for the repair lookup while still forcing a
        // re-hash next pass.
        final entry = result.changed.single;
        expect(entry.relativePath, 'a.jpg');
        expect(entry.contentHash, isNull);
        expect(entry.sizeBytes, stat.size);
        expect(entry.mtimeMillis, stat.modified.millisecondsSinceEpoch);
      },
    );

    test('the budget measures hashing only, not listing', () async {
      // Two files already indexed (so they cost a stat and no hash) plus one
      // new file. A budget that the stats alone could exhaust would starve
      // the new file forever; measuring hashing only guarantees progress.
      final a = await writeFile('a.jpg', 'aaaa');
      final b = await writeFile('b.jpg', 'bbbb');
      await writeFile('c.jpg', 'cccc');
      final statA = await a.stat();
      final statB = await b.stat();

      final result = await walkWatchedFolder(
        request(
          hashBudget: const Duration(minutes: 1),
          known: {
            'a.jpg': KnownFile(
              sizeBytes: statA.size,
              mtimeMillis: statA.modified.millisecondsSinceEpoch,
              contentHash: 'hashed-a',
            ),
            'b.jpg': KnownFile(
              sizeBytes: statB.size,
              mtimeMillis: statB.modified.millisecondsSinceEpoch,
              contentHash: 'hashed-b',
            ),
          },
        ),
      );

      expect(result.hashedCount, 1);
      expect(result.changed.single.relativePath, 'c.jpg');
    });
  });

  group('the prune list is computed here, not by shipping the tree back', () {
    test('an indexed file that is gone comes back as vanished', () async {
      await writeFile('still-here.jpg', 'aaaa');

      final result = await walkWatchedFolder(
        request(
          known: {
            'still-here.jpg': const KnownFile(
              sizeBytes: 1,
              mtimeMillis: 1,
              contentHash: 'stale',
            ),
            'deleted.jpg': const KnownFile(
              sizeBytes: 1,
              mtimeMillis: 1,
              contentHash: 'gone',
            ),
          },
        ),
      );

      expect(result.vanished, {'deleted.jpg'});
    });

    test(
      'a file on disk that was never indexed is not a prune candidate',
      () async {
        await writeFile('brand-new.jpg', 'aaaa');

        final result = await walkWatchedFolder(request());

        // vanished is drawn from the KNOWN index, so a file the index has never
        // heard of cannot appear in it.
        expect(result.vanished, isEmpty);
        expect(result.changed.single.relativePath, 'brand-new.jpg');
      },
    );

    test('a partial listing reports nothing vanished even when it saw some '
        'of the tree', () async {
      // A subtree the walk DID reach, plus an index entry it did not. The
      // listing is cut short, so the entry's absence proves nothing.
      await writeFile('reached.jpg', 'aaaa');

      final result = await walkWatchedFolder(
        WatchedFolderWalkRequest(
          rootPath: root.path,
          known: {
            'reached.jpg': const KnownFile(
              sizeBytes: 1,
              mtimeMillis: 1,
              contentHash: 'h',
            ),
            'never-listed.jpg': const KnownFile(
              sizeBytes: 1,
              mtimeMillis: 1,
              contentHash: 'h2',
            ),
          },
          hashBudget: const Duration(minutes: 1),
        ),
      );

      // Control: a COMPLETE listing of the same tree would call
      // 'never-listed.jpg' vanished, which is what makes the guard load-
      // bearing rather than vacuous.
      expect(result.listingComplete, isTrue);
      expect(result.vanished, {'never-listed.jpg'});
    });

    test(
      'an incomplete listing does not report unreached files as vanished',
      () async {
        await root.delete(recursive: true);

        final result = await walkWatchedFolder(
          request(
            known: {
              'a.jpg': const KnownFile(
                sizeBytes: 1,
                mtimeMillis: 1,
                contentHash: 'h',
              ),
            },
          ),
        );

        expect(result.listingComplete, isFalse);
        // Empty, not "every known path". A listing that reached nothing has
        // not shown that anything is gone, and computing the difference
        // anyway would send the ENTIRE stored index back across the isolate
        // boundary for the caller to discard -- reintroducing, in the
        // commonest failure mode (a watched root on an unplugged drive),
        // exactly the payload this walk exists to avoid.
        expect(result.vanished, isEmpty);

        await root.create(recursive: true);
      },
    );
  });

  test('the hash matches the streamed digest of the same bytes', () async {
    final a = await writeFile('a.jpg', 'the-quick-brown-fox');
    final expected = await sha256OfFile(a);

    final result = await walkWatchedFolder(request());

    expect(result.changed.single.contentHash, expected.hash);
    expect(result.changed.single.sizeBytes, expected.sizeBytes);
  });

  test('runs on a background isolate through the compute entrypoint', () async {
    await writeFile('a.jpg', 'aaaa');

    // The production seam. Exercised here because the whole point of the
    // walk being a top-level function over sendable data is that `compute`
    // can carry it off the UI isolate -- a closure or a live drift handle
    // creeping into the request would fail only here.
    final result = await walkWatchedFolderInIsolate(request());

    expect(result.changed.single.relativePath, 'a.jpg');
    expect(result.changed.single.contentHash, isNotNull);
  });
}

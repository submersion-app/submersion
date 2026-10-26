import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';

import '../../../../helpers/git_cli.dart';

GitStoredObject _blob(String text, {int pad = 0}) {
  final body = Uint8List.fromList(utf8.encode(text + ' ' * pad));
  return GitStoredObject(
    id: hashGitObject(GitObjectType.blob, body),
    type: GitObjectType.blob,
    body: body,
  );
}

void main() {
  group('MemoryGitObjectStore', () {
    test('returns what was put and reports presence', () async {
      final store = MemoryGitObjectStore();
      final a = _blob('a');
      expect(await store.has(a.id), isFalse);
      await store.put(a);
      expect(await store.has(a.id), isTrue);
      final back = (await store.get(a.id))!;
      expect(back.type, GitObjectType.blob);
      expect(back.body, a.body);
    });
  });

  group('FileGitObjectStore', () {
    test('survives a new instance on the same directory', () async {
      final dir = tempDirForTest('git_store_');
      final a = _blob('persisted');
      await FileGitObjectStore(dir).put(a);
      final back = await FileGitObjectStore(dir).get(a.id);
      expect(back?.body, a.body);
      expect(back?.type, GitObjectType.blob);
    });

    test('a put never evicts, so what was just fetched can be read', () async {
      final dir = tempDirForTest('git_store_');
      // Each object is about 1 KB on disk; the cap holds two of them.
      final store = FileGitObjectStore(dir, maxBytes: 2100);
      final objects = [for (final t in 'abc'.split('')) _blob(t, pad: 1000)];
      for (final o in objects) {
        await store.put(o);
      }
      for (final o in objects) {
        expect(await store.has(o.id), isTrue);
      }
    });

    test(
      'trim evicts the least recently used objects above maxBytes',
      () async {
        final dir = tempDirForTest('git_store_');
        final store = FileGitObjectStore(dir, maxBytes: 2100);
        final a = _blob('a', pad: 1000);
        final b = _blob('b', pad: 1000);
        final c = _blob('c', pad: 1000);
        await store.put(a);
        await store.put(b);
        await store.get(a.id); // a is now more recent than b
        await store.put(c);
        await store.trim();
        expect(await store.has(a.id), isTrue);
        expect(await store.has(b.id), isFalse);
        expect(await store.has(c.id), isTrue);
      },
    );

    test('trim keeps what it is told to keep, however old', () async {
      final dir = tempDirForTest('git_store_');
      final store = FileGitObjectStore(dir, maxBytes: 2100);
      final a = _blob('a', pad: 1000);
      final b = _blob('b', pad: 1000);
      final c = _blob('c', pad: 1000);
      for (final o in [a, b, c]) {
        await store.put(o);
      }
      await store.trim(keep: () async => {a.id});
      expect(await store.has(a.id), isTrue);
      expect(await store.has(b.id), isFalse);
      expect(await store.has(c.id), isTrue);
    });

    test('the first scan clears only temp files left long ago', () async {
      final dir = tempDirForTest('git_store_');
      Directory(joinPath(dir, 'ab')).createSync();
      // One being written by another store right now, one from a crash.
      final writing = File(p.join(dir.path, 'ab', 'cdef.1a2b.tmp'))
        ..writeAsStringSync('partial');
      final stale = File(p.join(dir.path, 'ab', 'cdef.3c4d.tmp'))
        ..writeAsStringSync('partial')
        ..setLastModifiedSync(DateTime.now().subtract(const Duration(days: 1)));
      await FileGitObjectStore(dir).has(_blob('x').id);
      expect(writing.existsSync(), isTrue);
      expect(stale.existsSync(), isFalse);
    });

    test(
      'an empty object file counts as missing, so it is fetched again',
      () async {
        final dir = tempDirForTest('git_store_');
        final a = _blob('a');
        await FileGitObjectStore(dir).put(a);
        File(
          p.join(dir.path, a.id.hex.substring(0, 2), a.id.hex.substring(2)),
        ).writeAsBytesSync(const []);
        final store = FileGitObjectStore(dir);
        expect(await store.get(a.id), isNull);
        expect(await store.has(a.id), isFalse);
        await store.put(a);
        expect((await store.get(a.id))?.body, a.body);
      },
    );

    test('concurrent first uses count the directory once', () async {
      final dir = tempDirForTest('git_store_');
      final a = _blob('a', pad: 1000);
      final b = _blob('b', pad: 1000);
      await FileGitObjectStore(dir).put(a);
      await FileGitObjectStore(dir).put(b);
      final store = FileGitObjectStore(dir, maxBytes: 2100);
      // Both callers trigger the first scan; a double count would make trim
      // think the store is over its bound and evict.
      await Future.wait([store.has(a.id), store.has(b.id)]);
      await store.trim();
      expect(await store.has(a.id), isTrue);
      expect(await store.has(b.id), isTrue);
    });
  });

  group('FileGitObjectStore, two stores on one directory', () {
    test('concurrent puts of one object all land', () async {
      final dir = tempDirForTest('git_store_');
      final first = FileGitObjectStore(dir);
      final second = FileGitObjectStore(dir);
      final a = _blob('a', pad: 1000);
      await Future.wait([
        for (var i = 0; i < 4; i++) ...[first.put(a), second.put(a)],
      ]);
      expect((await first.get(a.id))?.body, a.body);
      expect((await second.get(a.id))?.body, a.body);
      final leftovers = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'));
      expect(leftovers, isEmpty);
    });

    test(
      'an object one evicts reads as missing in the other, then comes back',
      () async {
        final dir = tempDirForTest('git_store_');
        final a = _blob('a', pad: 1000);
        final b = _blob('b', pad: 1000);
        final c = _blob('c', pad: 1000);
        final evicting = FileGitObjectStore(dir, maxBytes: 2100);
        final reading = FileGitObjectStore(dir);
        for (final o in [a, b, c]) {
          await evicting.put(o);
        }
        // The reader indexes all three before the other store evicts one.
        for (final o in [a, b, c]) {
          expect(await reading.has(o.id), isTrue);
        }
        await evicting.trim(keep: () async => {b.id, c.id});
        expect(await evicting.has(a.id), isFalse);

        // Its index is stale, but it reports the object missing, and the
        // read is a miss, not an error.
        expect(await reading.has(a.id), isFalse);
        expect(await reading.get(a.id), isNull);
        expect((await reading.get(b.id))?.body, b.body);

        // Fetched again, it is readable in both.
        await reading.put(a);
        expect((await reading.get(a.id))?.body, a.body);
        expect((await evicting.get(a.id))?.body, a.body);
      },
    );
  });

  test(
    'a put adopts what another store wrote instead of rewriting it',
    () async {
      final dir = tempDirForTest('git_store_');
      final a = _blob('a');
      final reader = FileGitObjectStore(dir);
      await reader.has(a.id); // scanned before the other store writes
      await FileGitObjectStore(dir).put(a);
      final file = File(
        p.join(dir.path, a.id.hex.substring(0, 2), a.id.hex.substring(2)),
      );
      // Whole seconds: some file systems keep no finer modification times.
      final written = DateTime(2020);
      file.setLastModifiedSync(written);
      await reader.put(a);
      expect(file.lastModifiedSync(), written);
      expect((await reader.get(a.id))?.body, a.body);
    },
  );

  group('FileGitObjectStore.shared', () {
    test('is one instance per directory', () {
      final dir = tempDirForTest('git_store_');
      final store = FileGitObjectStore.shared(dir);
      expect(FileGitObjectStore.shared(dir), same(store));
      expect(
        FileGitObjectStore.shared(Directory(p.join(dir.path, '.'))),
        same(store),
      );
      expect(
        FileGitObjectStore.shared(tempDirForTest('git_store_')),
        isNot(same(store)),
      );
    });

    test('refuses a different bound for a directory it already has', () {
      final dir = tempDirForTest('git_store_');
      FileGitObjectStore.shared(dir);
      expect(
        () => FileGitObjectStore.shared(dir, maxBytes: 4096),
        throwsArgumentError,
      );
    });

    test('scans the directory once however many callers share it', () async {
      final dir = tempDirForTest('git_store_');
      final a = _blob('a');
      await FileGitObjectStore.shared(dir).put(a);
      // Only a scan deletes a temp file left long ago, so one placed after
      // the first use survives every later caller of the shared store.
      final stale = File(p.join(dir.path, 'ab', 'cdef.3c4d.tmp'))
        ..createSync(recursive: true)
        ..setLastModifiedSync(DateTime.now().subtract(const Duration(days: 1)));
      expect(await FileGitObjectStore.shared(dir).has(a.id), isTrue);
      expect(stale.existsSync(), isTrue);
      // A store of its own scans, as the control.
      expect(await FileGitObjectStore(dir).has(a.id), isTrue);
      expect(stale.existsSync(), isFalse);
    });
  });
}

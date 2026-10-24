import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';

import '../../../../helpers/git_cli.dart';

Uint8List _random(int length, int seed) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(length, (_) => r.nextInt(256)));
}

/// Adds [body] to [writer] in pieces of [piece] bytes.
void _addInPieces(GitObjectWriter writer, Uint8List body, int piece) {
  for (var i = 0; i < body.length; i += piece) {
    writer.add(Uint8List.sublistView(body, i, min(i + piece, body.length)));
  }
}

Future<Uint8List> _collect(Stream<List<int>> stream) async {
  final out = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    out.add(chunk);
  }
  return out.takeBytes();
}

void main() {
  test('GitObjectHasher gives the id hashGitObject gives', () {
    final body = _random(10000, 1);
    final hasher = GitObjectHasher(GitObjectType.blob, body.length);
    for (var i = 0; i < body.length; i += 333) {
      hasher.add(Uint8List.sublistView(body, i, min(i + 333, body.length)));
    }
    expect(hasher.close(), hashGitObject(GitObjectType.blob, body));
  });

  test('GitObjectHasher refuses a body of another size', () {
    final hasher = GitObjectHasher(GitObjectType.blob, 10)..add([1, 2, 3]);
    expect(hasher.close, throwsFormatException);
  });

  final stores = <String, GitObjectStore Function()>{
    'MemoryGitObjectStore': MemoryGitObjectStore.new,
    'FileGitObjectStore': () =>
        FileGitObjectStore(tempDirForTest('git_store_streams_')),
  };

  for (final MapEntry(key: name, value: makeStore) in stores.entries) {
    group(name, () {
      test(
        'an object written in pieces reads back whole and in pieces',
        () async {
          final store = makeStore();
          final body = _random(50000, 2);
          final writer = store.create(GitObjectType.blob, body.length);
          _addInPieces(writer, body, 4096);
          final id = await writer.close();

          expect(id, hashGitObject(GitObjectType.blob, body));
          expect(await store.has(id), isTrue);
          expect((await store.get(id))!.body, body);

          final reader = (await store.open(id))!;
          try {
            expect(reader.type, GitObjectType.blob);
            expect(reader.length, body.length);
            expect(
              reader.readSync(100, 10),
              Uint8List.sublistView(body, 100, 110),
            );
            expect(
              reader.readSync(body.length - 5, 10),
              Uint8List.sublistView(body, body.length - 5),
            );
            expect(await _collect(reader.openRead()), body);
          } finally {
            await reader.close();
          }
        },
      );

      test('an object put whole can be opened', () async {
        final store = makeStore();
        final body = _random(300, 3);
        final object = GitStoredObject(
          id: hashGitObject(GitObjectType.tree, body),
          type: GitObjectType.tree,
          body: body,
        );
        await store.put(object);
        final reader = (await store.open(object.id))!;
        try {
          expect(reader.type, GitObjectType.tree);
          expect(await _collect(reader.openRead()), body);
        } finally {
          await reader.close();
        }
      });

      test('a missing object opens as null', () async {
        final store = makeStore();
        expect(
          await store.open(hashGitObject(GitObjectType.blob, [1, 2])),
          isNull,
        );
      });

      test('a writer given the wrong number of bytes stores nothing', () async {
        final store = makeStore();
        final body = _random(1000, 4);
        final writer = store.create(GitObjectType.blob, body.length + 1)
          ..add(body);
        await expectLater(writer.close(), throwsFormatException);
        expect(
          await store.has(hashGitObject(GitObjectType.blob, body)),
          isFalse,
        );
      });

      test('an aborted writer stores nothing', () async {
        final store = makeStore();
        final body = _random(1000, 5);
        final writer = store.create(GitObjectType.blob, body.length)..add(body);
        await writer.abort();
        expect(
          await store.has(hashGitObject(GitObjectType.blob, body)),
          isFalse,
        );
      });
    });
  }

  test('FileGitObjectStore refuses to open an object with a damaged type '
      'byte, and can still delete it', () async {
    final dir = tempDirForTest('git_store_streams_');
    final store = FileGitObjectStore(dir);
    final body = _random(100, 10);
    final id = await (store.create(
      GitObjectType.blob,
      body.length,
    )..add(body)).close();
    final objectFile = File(
      p.join(dir.path, id.hex.substring(0, 2), id.hex.substring(2)),
    )..writeAsBytesSync([0x0f, ...body]);
    await expectLater(store.open(id), throwsFormatException);
    // The handle was closed, so the file is not held open (which on Windows
    // would block this delete).
    objectFile.deleteSync();
  });

  group('FileGitObjectStore writers', () {
    test(
      'leave no temp file behind, whether closed, refused or aborted',
      () async {
        final dir = tempDirForTest('git_store_streams_');
        final store = FileGitObjectStore(dir);
        final body = _random(1000, 6);
        final ok = store.create(GitObjectType.blob, body.length)..add(body);
        await ok.close();
        final refused = store.create(GitObjectType.blob, 5)..add(body);
        await expectLater(refused.close(), throwsFormatException);
        final aborted = store.create(GitObjectType.blob, body.length)
          ..add(body);
        await aborted.abort();
        final leftovers = dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.tmp'));
        expect(leftovers, isEmpty);
      },
    );

    test('count toward the bound, so trim can evict what they wrote', () async {
      final dir = tempDirForTest('git_store_streams_');
      final store = FileGitObjectStore(dir, maxBytes: 1500);
      final a = _random(1000, 7);
      final b = _random(1000, 8);
      final aId = await (store.create(
        GitObjectType.blob,
        a.length,
      )..add(a)).close();
      final bId = await (store.create(
        GitObjectType.blob,
        b.length,
      )..add(b)).close();
      await store.trim();
      expect(await store.has(aId), isFalse);
      expect(await store.has(bId), isTrue);
    });

    test('of an object already stored keep the one there', () async {
      final dir = tempDirForTest('git_store_streams_');
      final store = FileGitObjectStore(dir);
      final body = _random(1000, 9);
      final first = await (store.create(
        GitObjectType.blob,
        body.length,
      )..add(body)).close();
      final second = await (store.create(
        GitObjectType.blob,
        body.length,
      )..add(body)).close();
      expect(second, first);
      expect((await store.get(first))!.body, body);
    });
  });
}

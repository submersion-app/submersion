import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_objects.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_reader.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_writer.dart';
import 'package:submersion/core/utils/off_isolate.dart';

import '../../../../helpers/git_cli.dart';

Future<Uint8List> _collect(Stream<List<int>> stream) async {
  final out = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    out.add(chunk);
  }
  return out.takeBytes();
}

/// A blob, a tree holding it, and a parentless commit of that tree.
({List<PackEntrySource> entries, List<GitObjectId> ids}) _threeObjects() {
  final blob = Uint8List.fromList(utf8.encode('{"dives": 1}\n'));
  final blobId = hashGitObject(GitObjectType.blob, blob);
  final tree = encodeTree([
    GitTreeEntry(name: 'index.json', mode: kGitModeFile, id: blobId),
  ]);
  final treeId = hashGitObject(GitObjectType.tree, tree);
  final commit = GitCommit(
    tree: treeId,
    parents: const [],
    authorName: 'Submersion 1234abcd',
    authorEmail: 'sync@submersion.invalid',
    when: DateTime.utc(2026, 10, 18),
    message: 'Sync from Submersion 1234abcd',
  ).encode();
  return (
    entries: [
      PackEntrySource.bytes(GitObjectType.blob, blob),
      PackEntrySource.bytes(GitObjectType.tree, tree),
      PackEntrySource.bytes(GitObjectType.commit, commit),
    ],
    ids: [blobId, treeId, hashGitObject(GitObjectType.commit, commit)],
  );
}

File _bigFile(Directory dir) {
  final r = Random(3511);
  final bytes = Uint8List(3 * 1024 * 1024);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = r.nextInt(256);
  }
  return File(joinPath(dir, 'backup.db'))..writeAsBytesSync(bytes);
}

void main() {
  test('a written pack reads back to the same objects', () async {
    final three = _threeObjects();
    final pack = await _collect(writePack(three.entries));
    final ids = await readPack(pack, MemoryGitObjectStore());
    expect(ids, three.ids);
  });

  test('a file-backed blob streams and hashes like the bytes', () async {
    final dir = tempDirForTest('git_pack_');
    final file = _bigFile(dir);
    final id = await hashFileBlob(file);
    expect(id, hashGitObject(GitObjectType.blob, file.readAsBytesSync()));
    final pack = await _collect(
      writePack([
        PackEntrySource.file(GitObjectType.blob, file, file.lengthSync()),
      ]),
    );
    final store = MemoryGitObjectStore();
    expect(await readPack(pack, store), [id]);
    expect((await store.get(id))!.body.length, 3 * 1024 * 1024);
  });

  test('stock git index-pack accepts the pack', () async {
    final three = _threeObjects();
    final pack = await _collect(writePack(three.entries));
    final repo = await initTempRepo(bare: true);
    // A file argument, so binary bytes never pass through a text stdin.
    final packFile = File(joinPath(repo, 'in.pack'))..writeAsBytesSync(pack);
    await runGit(repo, ['index-pack', packFile.path]);
    final verify = await runGit(repo, ['verify-pack', '-v', packFile.path]);
    for (final id in three.ids) {
      expect(verify, contains(id.hex));
    }
    expect(verify, contains('blob'));
    expect(verify, contains('tree'));
    expect(verify, contains('commit'));
  }, skip: skipUnlessGit());

  group('a large write', () {
    // git hash-object on 300 KiB of zeros.
    const zerosBlobId = '1e23bd3e28ee6c2f5727e3767dbf9745eae94486';
    final zeros = Uint8List(300 * 1024);

    late int hops;
    Future<R> counting<R>(FutureOr<R> Function() work) {
      hops++;
      return Isolate.run(work);
    }

    setUp(() => hops = 0);

    List<PackEntrySource> largeEntries() {
      final blob = Uint8List.fromList(
        List.generate(kOffIsolateMinBytes, (i) => (i * 31) % 251),
      );
      return [
        PackEntrySource.bytes(GitObjectType.blob, blob),
        PackEntrySource.bytes(GitObjectType.blob, Uint8List.fromList([1, 2])),
      ];
    }

    test('hashes to the id git gives it, on another isolate', () async {
      final id = await hashGitObjectOffIsolate(
        GitObjectType.blob,
        zeros,
        runner: counting,
      );
      expect(id.hex, zerosBlobId);
      expect(hops, 1);
    });

    test('a small blob hashes here', () async {
      final id = await hashGitObjectOffIsolate(
        GitObjectType.blob,
        Uint8List.fromList(utf8.encode('hello\n')),
        runner: counting,
      );
      expect(id.hex, 'ce013625030ba8dba906f756967f9e9ca394464a');
      expect(hops, 0);
    });

    test('packs on another isolate, to the same bytes', () async {
      final entries = largeEntries();
      final prepared = await preparePack(entries, runner: counting);
      expect(hops, 1);
      expect(await _collect(prepared), await _collect(writePack(entries)));
    });

    test('a pack built off-isolate reads back', () async {
      final entries = largeEntries();
      final bytes = await _collect(await preparePack(entries));
      final ids = await readPack(bytes, MemoryGitObjectStore());
      expect(ids, hasLength(2));
    });

    test('a small pack streams as it did', () async {
      final blob = Uint8List.fromList([1, 2, 3]);
      final entries = [PackEntrySource.bytes(GitObjectType.blob, blob)];
      final prepared = await preparePack(entries, runner: counting);
      expect(hops, 0);
      expect(await _collect(prepared), await _collect(writePack(entries)));
    });

    test('a file-backed entry streams, however large', () async {
      final dir = await Directory.systemTemp.createTemp('pack_prepare');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'large.bin'));
      await file.writeAsBytes(zeros);
      final entries = [
        PackEntrySource.file(GitObjectType.blob, file, zeros.length),
      ];
      final prepared = await preparePack(entries, runner: counting);
      expect(hops, 0);
      expect(await readPack(await _collect(prepared), MemoryGitObjectStore()), [
        GitObjectId.fromHex(zerosBlobId),
      ]);
    });

    test('a failed isolate packs here instead', () async {
      final entries = largeEntries();
      final prepared = await preparePack(
        entries,
        runner: <R>(work) async => throw IsolateSpawnException('no isolate'),
      );
      expect(await _collect(prepared), await _collect(writePack(entries)));
    });
  });
}

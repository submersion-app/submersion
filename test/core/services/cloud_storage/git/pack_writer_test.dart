import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_objects.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_reader.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_writer.dart';

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
}

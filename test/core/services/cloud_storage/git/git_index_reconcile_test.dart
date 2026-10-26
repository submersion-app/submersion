import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/git/git_branch_files.dart';
import 'package:submersion/core/services/cloud_storage/git/git_index_reconcile.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_objects.dart';
import 'package:submersion/core/services/cloud_storage/git/git_tree_editor.dart';

Future<GitObjectId> _putTree(
  GitObjectStore store,
  List<GitTreeEntry> entries,
) async {
  final body = encodeTree(entries);
  final id = hashGitObject(GitObjectType.tree, body);
  await store.put(
    GitStoredObject(id: id, type: GitObjectType.tree, body: body),
  );
  return id;
}

GitObjectId _blobId(String text) =>
    hashGitObject(GitObjectType.blob, Uint8List.fromList(utf8.encode(text)));

void main() {
  test('an executable file is indexed like a regular one', () async {
    final store = MemoryGitObjectStore();
    final blob = _blobId('#!/bin/sh');
    final root = await _putTree(store, [
      GitTreeEntry(name: 'run.sh', mode: 0x81ED, id: blob),
    ]);
    final index = await reconcileGitIndex(
      store,
      root,
      GitIndex.empty,
      tipMs: 42,
    );
    expect(index.entries['run.sh']!.blobId, blob);
    expect(index.entries['run.sh']!.modifiedMs, 42);
  });

  test('a tree the store lacks is GitObjectMissing', () async {
    final store = MemoryGitObjectStore();
    final missing = _blobId('not stored');
    final root = await _putTree(store, [
      GitTreeEntry(name: 'Submersion Sync', mode: kGitModeTree, id: missing),
    ]);
    await expectLater(
      reconcileGitIndex(store, root, GitIndex.empty, tipMs: 0),
      throwsA(isA<GitObjectMissing>().having((e) => e.id, 'id', missing)),
    );
  });
}

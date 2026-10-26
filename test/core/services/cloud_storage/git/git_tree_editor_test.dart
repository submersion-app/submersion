import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_objects.dart';
import 'package:submersion/core/services/cloud_storage/git/git_tree_editor.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_writer.dart';

({GitObjectId id, PackEntrySource? source}) _put(String text) {
  final body = Uint8List.fromList(utf8.encode(text));
  return (
    id: hashGitObject(GitObjectType.blob, body),
    source: PackEntrySource.bytes(GitObjectType.blob, body),
  );
}

Future<List<GitTreeEntry>> _entries(
  GitObjectStore store,
  GitObjectId id,
) async => decodeTree((await store.get(id))!.body);

void main() {
  test('a put into an empty root creates the intermediate directory', () async {
    final store = MemoryGitObjectStore();
    final edit = await editTree(
      store,
      null,
      puts: {'Submersion Sync/a.json': _put('a')},
      deletes: const {},
    );
    final root = await _entries(store, edit.root);
    expect(root.single.name, 'Submersion Sync');
    expect(root.single.isTree, isTrue);
    final dir = await _entries(store, root.single.id);
    expect(dir.single.name, 'a.json');
    // The blob, the subtree and the root all travel in the pack.
    expect(edit.newObjects, hasLength(3));
  });

  test('deleting the last file in a directory removes the directory', () async {
    final store = MemoryGitObjectStore();
    final first = await editTree(
      store,
      null,
      puts: {'Submersion Sync/a.json': _put('a'), 'README.md': _put('r')},
      deletes: const {},
    );
    final second = await editTree(
      store,
      first.root,
      puts: const {},
      deletes: {'Submersion Sync/a.json'},
    );
    final root = await _entries(store, second.root);
    expect(root.map((e) => e.name), ['README.md']);
  });

  test('an untouched subtree keeps its id and is not re-sent', () async {
    final store = MemoryGitObjectStore();
    final first = await editTree(
      store,
      null,
      puts: {
        'Submersion Sync/a.json': _put('a'),
        'Submersion Backups/b.db': _put('b'),
      },
      deletes: const {},
    );
    final before = {
      for (final e in await _entries(store, first.root)) e.name: e.id,
    };
    final second = await editTree(
      store,
      first.root,
      puts: {'Submersion Sync/c.json': _put('c')},
      deletes: const {},
    );
    final after = {
      for (final e in await _entries(store, second.root)) e.name: e.id,
    };
    expect(after['Submersion Backups'], before['Submersion Backups']);
    expect(after['Submersion Sync'], isNot(before['Submersion Sync']));
    // New blob, new Submersion Sync tree, new root.
    expect(second.newObjects, hasLength(3));
  });

  test('a path with an empty or dot segment is rejected', () async {
    final store = MemoryGitObjectStore();
    for (final bad in ['a//b', '../x', 'a/./b', '/abs', 'trailing/']) {
      await expectLater(
        editTree(store, null, puts: {bad: _put('x')}, deletes: const {}),
        throwsArgumentError,
        reason: bad,
      );
    }
  });
}

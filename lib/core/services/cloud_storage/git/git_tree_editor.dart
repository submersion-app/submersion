import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_objects.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_writer.dart';

/// An object the local store should hold is not there: evicted, or removed
/// by another store on the same directory. The caller fetches it again.
final class GitObjectMissing implements Exception {
  const GitObjectMissing(this.id);

  final GitObjectId id;

  @override
  String toString() => 'GitObjectMissing($id)';
}

/// A file to place at a path: its blob id, and where to read the blob from
/// when it must travel in the pack (null when the host already has it).
typedef GitTreePut = ({GitObjectId id, PackEntrySource? source});

List<String> _segments(String path) {
  final parts = path.split('/');
  if (parts.any((s) => s.isEmpty || s == '.' || s == '..')) {
    throw ArgumentError.value(path, 'path', 'not a relative file path');
  }
  return parts;
}

/// Applies [puts] and [deletes] (slash-separated paths) to the tree [root]
/// (null for an empty tree) and returns the new root.
///
/// Intermediate directories are created as needed and removed once empty;
/// unchanged subtrees keep their ids. [newObjects] holds every blob and tree
/// the result introduces, ready to pack; new trees are also put into [store]
/// so the next edit can read them. Throws [GitObjectMissing] for an existing
/// tree that [store] does not hold.
Future<({GitObjectId root, List<PackEntrySource> newObjects})> editTree(
  GitObjectStore store,
  GitObjectId? root, {
  required Map<String, GitTreePut> puts,
  required Set<String> deletes,
}) async {
  final newObjects = <PackEntrySource>[];
  final added = <GitObjectId>{};
  final changes = <List<String>, GitTreePut?>{
    for (final MapEntry(:key, :value) in puts.entries) _segments(key): value,
    for (final path in deletes) _segments(path): null,
  };
  for (final put in puts.values) {
    final source = put.source;
    if (source != null && added.add(put.id)) newObjects.add(source);
  }

  Future<GitObjectId?> edit(
    GitObjectId? treeId,
    Map<List<String>, GitTreePut?> here,
    bool isRoot,
  ) async {
    final entries = <String, GitTreeEntry>{};
    if (treeId != null) {
      final stored = await store.get(treeId);
      if (stored == null) {
        throw GitObjectMissing(treeId);
      }
      for (final e in decodeTree(stored.body)) {
        entries[e.name] = e;
      }
    }
    final files = <String, GitTreePut?>{};
    final dirs = <String, Map<List<String>, GitTreePut?>>{};
    for (final MapEntry(:key, :value) in here.entries) {
      if (key.length == 1) {
        files[key.first] = value;
      } else {
        (dirs[key.first] ??= {})[key.sublist(1)] = value;
      }
    }
    for (final MapEntry(:key, :value) in files.entries) {
      if (value == null) {
        if (entries[key]?.isTree == false) entries.remove(key);
      } else {
        entries[key] = GitTreeEntry(
          name: key,
          mode: kGitModeFile,
          id: value.id,
        );
      }
    }
    for (final MapEntry(:key, :value) in dirs.entries) {
      final existing = entries[key];
      final childId = await edit(
        existing != null && existing.isTree ? existing.id : null,
        value,
        false,
      );
      if (childId == null) {
        entries.remove(key);
      } else {
        entries[key] = GitTreeEntry(name: key, mode: kGitModeTree, id: childId);
      }
    }
    if (entries.isEmpty && !isRoot) return null;
    final body = encodeTree(entries.values);
    final id = hashGitObject(GitObjectType.tree, body);
    if (id == treeId) return id;
    if (added.add(id)) {
      await store.put(
        GitStoredObject(id: id, type: GitObjectType.tree, body: body),
      );
      newObjects.add(PackEntrySource.bytes(GitObjectType.tree, body));
    }
    return id;
  }

  final newRoot = await edit(root, changes, true);
  return (root: newRoot!, newObjects: newObjects);
}

/// The entry at [path] under [root], or null when nothing is there.
Future<GitTreeEntry?> lookupTreePath(
  GitObjectStore store,
  GitObjectId root,
  String path,
) async {
  var treeId = root;
  final parts = _segments(path);
  for (var i = 0; i < parts.length; i++) {
    final stored = await store.get(treeId);
    if (stored == null) {
      throw GitObjectMissing(treeId);
    }
    GitTreeEntry? found;
    for (final e in decodeTree(stored.body)) {
      if (e.name == parts[i]) {
        found = e;
        break;
      }
    }
    if (found == null) return null;
    if (i == parts.length - 1) return found;
    if (!found.isTree) return null;
    treeId = found.id;
  }
  return null;
}

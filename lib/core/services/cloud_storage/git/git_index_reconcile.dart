import 'package:submersion/core/services/cloud_storage/git/git_branch_files.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_objects.dart';
import 'package:submersion/core/services/cloud_storage/git/git_tree_editor.dart';

/// Tree entry mode of an executable file (octal 100755).
const int _kGitModeExecutable = 0x81ED;

/// [index] made to describe exactly the files in the tree at [root], so a
/// file another tool added, edited or removed on the branch is listed as it
/// is. An entry whose blob matches the tree is kept as written. Any other
/// file gets [tipMs] as its time and an unknown size, since the branch is
/// fetched without blobs. Entries for paths the tree lacks are dropped.
///
/// Only regular files count; Submersion's own folder and root README are
/// never files. Throws [GitObjectMissing] when the store lacks a tree.
Future<GitIndex> reconcileGitIndex(
  GitObjectStore store,
  GitObjectId root,
  GitIndex index, {
  required int tipMs,
}) async {
  final entries = <String, GitIndexEntry>{};
  Future<void> walk(GitObjectId treeId, String prefix) async {
    final stored = await store.get(treeId);
    if (stored == null) throw GitObjectMissing(treeId);
    for (final e in decodeTree(stored.body)) {
      final path = '$prefix${e.name}';
      if (e.isTree) {
        if (path != kGitOwnFolder) await walk(e.id, '$path/');
        continue;
      }
      if (e.mode != kGitModeFile && e.mode != _kGitModeExecutable) continue;
      if (path == kGitReadmePath) continue;
      final known = index.entries[path];
      entries[path] = known != null && known.blobId == e.id
          ? known
          : GitIndexEntry(blobId: e.id, size: null, modifiedMs: tipMs);
    }
  }

  await walk(root, '');
  return GitIndex(Map.unmodifiable(entries));
}

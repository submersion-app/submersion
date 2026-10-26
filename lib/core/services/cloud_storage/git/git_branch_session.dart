import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/git/git_branch_files.dart';
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git/git_http_transport.dart';
import 'package:submersion/core/services/cloud_storage/git/git_index_reconcile.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_objects.dart';
import 'package:submersion/core/services/cloud_storage/git/git_tree_editor.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_writer.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Who a commit says it is from. [messageLabel] goes in the message
/// (`Sync from <label>`).
final class GitCommitIdentity {
  const GitCommitIdentity({required this.name, required this.messageLabel});

  final String name;
  final String messageLabel;
}

/// The branch as this device last saw it.
final class GitBranchSnapshot {
  const GitBranchSnapshot({
    required this.tip,
    required this.rootTree,
    required this.index,
    required this.meta,
    required this.isDefaultBranch,
    required this.indexBlobSize,
    required this.metaBlobSize,
  });

  final GitObjectId tip;
  final GitObjectId rootTree;
  final GitIndex index;
  final GitBranchMeta meta;

  /// True when the branch is (or is becoming) the repository's default.
  final bool isDefaultBranch;
  final int indexBlobSize;
  final int metaBlobSize;

  GitBranchSnapshot _withIndex(GitIndex index) => GitBranchSnapshot(
    tip: tip,
    rootTree: rootTree,
    index: index,
    meta: meta,
    isDefaultBranch: isDefaultBranch,
    indexBlobSize: indexBlobSize,
    metaBlobSize: metaBlobSize,
  );
}

/// A file to write, from memory or from disk.
final class GitPut {
  GitPut.bytes(Uint8List data) : _data = data, _file = null;
  GitPut.file(File file) : _data = null, _file = file;

  final Uint8List? _data;
  final File? _file;

  /// How many bytes there are.
  Future<int> length() async => _data?.length ?? await _file!.length();

  /// The first [n] bytes, or all of them when there are fewer.
  Future<Uint8List> head(int n) async {
    final data = _data;
    if (data != null) {
      return Uint8List.sublistView(data, 0, min(n, data.length));
    }
    final raf = await _file!.open();
    try {
      return await raf.read(n);
    } finally {
      await raf.close();
    }
  }
}

/// One commit's worth of change. [deletes] maps each path to the blob id the
/// device saw when it decided to delete it; a delete whose path now holds a
/// different blob (a peer rewrote it) is dropped. A null id deletes whatever
/// the path holds, for a caller that never listed it (backup pruning).
final class GitChange {
  GitChange({this.puts = const {}, this.deletes = const {}});

  final Map<String, GitPut> puts;
  final Map<String, GitObjectId?> deletes;
}

typedef _PreparedPut = ({GitObjectId id, int size, PackEntrySource source});

/// Turns file operations into commits on one branch Submersion owns.
///
/// Safety rules: Submersion writes only to a branch it created, recognised
/// by [kGitMetaPath]. A missing branch is created; any other existing branch
/// is refused with [GitErrorCode.branchHasOtherContent] and never written.
class GitBranchSession {
  GitBranchSession({
    required this.transport,
    required this.store,
    required this.branch,
    required this.identity,
    DateTime Function()? clock,
    Duration Function(int attempt)? retryDelay,
    this.maxAttempts = 4,
    this.resetThresholdBytes = kGitHistoryResetThresholdBytes,
  }) : _clock = clock ?? DateTime.now,
       _retryDelay = retryDelay ?? _jitter;

  final GitHttpTransport transport;
  final GitObjectStore store;
  final String branch;
  final Future<GitCommitIdentity> Function() identity;
  final int maxAttempts;
  final int resetThresholdBytes;
  final DateTime Function() _clock;
  final Duration Function(int attempt) _retryDelay;

  GitBranchSnapshot? _current;
  GitBranchSnapshot? get current => _current;

  /// Looks at the remote tip, numbered in the order they were taken: a read
  /// is numbered before its request goes out, a push once it has landed. A
  /// snapshot from an earlier look never replaces a later one, so a slow
  /// read cannot undo a commit that landed while it ran.
  int _looks = 0;
  int _appliedLook = 0;

  static final Random _random = Random();
  static final _log = LoggerService.forClass(GitBranchSession);
  static Duration _jitter(int attempt) =>
      Duration(milliseconds: 200 * attempt + _random.nextInt(300));

  int _look() => ++_looks;

  /// Makes [snap] current unless a later look already applied one, then
  /// trims the store around what is current. Returns the current snapshot.
  Future<GitBranchSnapshot> _apply(GitBranchSnapshot snap, int look) async {
    final current = _current;
    if (current != null && look < _appliedLook) return current;
    _appliedLook = look;
    _current = snap;
    try {
      await store.trim(keep: () => _keepFor(snap));
    } on FileSystemException {
      // Only the cache is affected; what was read or pushed stands.
    }
    return snap;
  }

  /// What [snap] cannot do without: its commit, every tree under its root,
  /// and the index and meta blobs. A tree the store lost is skipped here and
  /// fetched again when next needed.
  Future<Set<GitObjectId>> _keepFor(GitBranchSnapshot snap) async {
    final keep = <GitObjectId>{snap.tip};
    Future<void> walk(GitObjectId treeId, String prefix) async {
      if (!keep.add(treeId)) return;
      final stored = await store.get(treeId);
      if (stored == null) return;
      for (final e in decodeTree(stored.body)) {
        final path = '$prefix${e.name}';
        if (e.isTree) {
          await walk(e.id, '$path/');
        } else if (path == kGitIndexPath || path == kGitMetaPath) {
          keep.add(e.id);
        }
      }
    }

    await walk(snap.rootTree, '');
    return keep;
  }

  /// Runs [read], and once more after fetching [tip]'s commit and trees
  /// again when the store lost an object [read] needed. A commit or tree
  /// that cannot be parsed (another tool's, or damaged) is a [GitException].
  Future<T> _refetchingOnce<T>(
    GitObjectId tip,
    Future<T> Function() read,
  ) async {
    try {
      try {
        return await read();
      } on GitObjectMissing {
        await transport.fetch([tip], store, blobless: true);
      }
      try {
        return await read();
      } on GitObjectMissing catch (e) {
        throw GitException(
          'Object ${e.id} is missing after a fetch.',
          code: GitErrorCode.unexpected,
          cause: e,
        );
      }
    } on FormatException catch (e) {
      throw GitException(
        'The branch $branch holds a commit or folder Submersion cannot read.',
        code: GitErrorCode.unexpected,
        cause: e,
      );
    }
  }

  // ---- Reading --------------------------------------------------------------

  /// Opens the branch: adopts it when it is Submersion's, creates it when it
  /// does not exist, refuses it otherwise.
  Future<GitBranchSnapshot> open() async {
    final look = _look();
    final refs = await transport.lsRefs(branch);
    final tip = refs.branchTip;
    if (tip != null) {
      return _apply(
        await _load(tip, isDefault: refs.headSymref == 'refs/heads/$branch'),
        look,
      );
    }
    try {
      final created = await _create(isDefault: refs.isEmpty);
      return await _apply(created, _look());
    } on GitException catch (e) {
      // Another device created it first; adopt theirs.
      if (e.code != GitErrorCode.staleTip) rethrow;
      final lookAgain = _look();
      final again = await transport.lsRefs(branch);
      if (again.branchTip == null) rethrow;
      return _apply(
        await _load(
          again.branchTip!,
          isDefault: again.headSymref == 'refs/heads/$branch',
        ),
        lookAgain,
      );
    }
  }

  /// Checks the branch without writing anything: whether it exists, whether
  /// creating it would make it the repository's default (an empty
  /// repository), and, when it exists, that it is Submersion's. Throws
  /// [GitErrorCode.branchHasOtherContent] for any other branch.
  Future<({bool exists, bool willBecomeDefault})> inspect() async {
    final refs = await transport.lsRefs(branch);
    final tip = refs.branchTip;
    if (tip == null) return (exists: false, willBecomeDefault: refs.isEmpty);
    await _load(tip, isDefault: refs.headSymref == 'refs/heads/$branch');
    return (exists: true, willBecomeDefault: false);
  }

  /// Re-reads the tip; fetches only when it moved. Returns the current
  /// snapshot, which is newer than what this read found when a commit
  /// landed while it ran.
  Future<GitBranchSnapshot> refresh() async {
    final known = _current;
    if (known == null) return open();
    final look = _look();
    final refs = await transport.lsRefs(branch);
    final tip = refs.branchTip;
    if (tip == null) {
      if (look < _appliedLook) return _current ?? open();
      _current = null;
      return open();
    }
    if (tip == known.tip) return _current ?? known;
    return _apply(
      await _load(
        tip,
        isDefault:
            known.isDefaultBranch || refs.headSymref == 'refs/heads/$branch',
        have: known.tip,
      ),
      look,
    );
  }

  /// Reads [tip]'s snapshot, fetching what is missing. [have] is a tip this
  /// device already holds whole; telling the host about it means only the
  /// objects that changed travel, which matters most on hosts without
  /// partial-clone filters, where every blob would come again.
  Future<GitBranchSnapshot> _load(
    GitObjectId tip, {
    required bool isDefault,
    GitObjectId? have,
  }) async {
    if (!await store.has(tip)) {
      await transport.fetch(
        [tip],
        store,
        blobless: true,
        haves: have != null && await store.has(have) ? {have} : const {},
      );
    }
    return _refetchingOnce(tip, () => _read(tip, isDefault: isDefault));
  }

  Future<GitBranchSnapshot> _read(
    GitObjectId tip, {
    required bool isDefault,
  }) async {
    final commit = GitCommit.decode(await _objectBody(tip));
    final meta = await lookupTreePath(store, commit.tree, kGitMetaPath);
    if (meta == null || meta.isTree) {
      throw GitException(
        'The branch $branch already holds other content.',
        code: GitErrorCode.branchHasOtherContent,
      );
    }
    final metaBytes = await _blob(meta.id, tip);
    final indexEntry = await lookupTreePath(store, commit.tree, kGitIndexPath);
    // A missing or damaged index is rebuilt from the tree below, so no file
    // disappears. A newer version's is refused: the next commit would write
    // it back in this version's format, losing what the newer one adds.
    var read = GitIndex.empty;
    var indexBlobSize = 0;
    if (indexEntry != null && !indexEntry.isTree) {
      final indexBytes = await _blob(indexEntry.id, tip);
      indexBlobSize = indexBytes.length;
      try {
        read = GitIndex.decode(indexBytes);
      } on GitIndexTooNew catch (e) {
        throw GitException(
          'The file index on the branch $branch is from a newer version.',
          code: GitErrorCode.indexUnreadable,
          cause: e,
        );
      } on FormatException catch (e) {
        _log.warning(
          'Rebuilding the damaged file index on $branch from its tree: $e',
        );
        read = GitIndex.empty;
      }
    }
    return GitBranchSnapshot(
      tip: tip,
      rootTree: commit.tree,
      index: await reconcileGitIndex(
        store,
        commit.tree,
        read,
        tipMs: commit.landedAt.millisecondsSinceEpoch,
      ),
      meta: GitBranchMeta.decode(metaBytes),
      isDefaultBranch: isDefault,
      indexBlobSize: indexBlobSize,
      metaBlobSize: metaBytes.length,
    );
  }

  Future<Uint8List> _objectBody(GitObjectId id) async {
    final stored = await store.get(id);
    if (stored == null) throw GitObjectMissing(id);
    return stored.body;
  }

  /// Makes sure a blob is in the store, fetching it on demand. Hosts that
  /// refuse single-blob wants get a full fetch of [tip] instead.
  Future<void> _ensureBlob(GitObjectId id, GitObjectId tip) async {
    if (await store.has(id)) return;
    try {
      await transport.fetchBlobs([id], store);
    } on GitException catch (e) {
      if (e.code != GitErrorCode.unexpected) rethrow;
    }
    if (!await store.has(id)) {
      await transport.fetch([tip], store);
    }
  }

  /// A blob's bytes, fetched on demand.
  Future<Uint8List> _blob(GitObjectId id, GitObjectId tip) async {
    await _ensureBlob(id, tip);
    return _objectBody(id);
  }

  /// The blob [path] holds in [snap].
  Future<GitObjectId> _fileBlob(GitBranchSnapshot snap, String path) async {
    final entry = await lookupTreePath(store, snap.rootTree, path);
    if (entry == null || entry.isTree) {
      throw GitException(
        '$path is not on the branch.',
        code: GitErrorCode.notFound,
      );
    }
    return entry.id;
  }

  Future<Uint8List> readFile(String path) async {
    final snap = _current ?? await open();
    return _refetchingOnce(snap.tip, () async {
      final id = await _fileBlob(snap, path);
      final bytes = await _blob(id, snap.tip);
      _learnSize(path, id, bytes.length);
      return bytes;
    });
  }

  /// Records the size of a file whose index entry lacked one, so the next
  /// commit writes it. Only while the snapshot still holds that blob there.
  void _learnSize(String path, GitObjectId blobId, int size) {
    final current = _current;
    final known = current?.index.entries[path];
    if (current == null || known == null) return;
    if (known.size != null || known.blobId != blobId) return;
    _current = current._withIndex(
      GitIndex(
        Map.unmodifiable({
          ...current.index.entries,
          path: known.copyWith(size: size),
        }),
      ),
    );
  }

  /// Writes the file to [destination] whole, or not at all. It is copied
  /// from the store a piece at a time, so it is never held in memory.
  Future<void> readFileTo(String path, File destination) async {
    final snap = _current ?? await open();
    final tmp = File('${destination.path}.part');
    try {
      await _refetchingOnce(snap.tip, () async {
        final id = await _fileBlob(snap, path);
        await _ensureBlob(id, snap.tip);
        final reader = await store.open(id);
        if (reader == null) throw GitObjectMissing(id);
        try {
          final out = await tmp.open(mode: FileMode.writeOnly);
          try {
            await for (final chunk in reader.openRead()) {
              await out.writeFrom(chunk);
            }
            await out.flush();
          } finally {
            await out.close();
          }
          _learnSize(path, id, reader.length);
        } finally {
          await reader.close();
        }
      });
      await tmp.rename(destination.path);
    } catch (_) {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }

  // ---- Writing --------------------------------------------------------------

  Future<GitBranchSnapshot> _create({required bool isDefault}) async {
    const meta = GitBranchMeta();
    final metaBytes = meta.encode();
    final indexBytes = GitIndex.empty.encode();
    final edit = await editTree(
      store,
      null,
      puts: {
        kGitReadmePath: await _bytesPut(
          Uint8List.fromList(utf8.encode(kGitReadmeText)),
        ),
        kGitMetaPath: await _bytesPut(metaBytes),
        kGitIndexPath: await _bytesPut(indexBytes),
      },
      deletes: const {},
    );
    final who = await identity();
    final commitId = await _pushCommit(
      tree: edit.root,
      parents: const [],
      message: 'Create Submersion sync branch',
      who: who,
      objects: edit.newObjects,
      oldTip: null,
    );
    return GitBranchSnapshot(
      tip: commitId,
      rootTree: edit.root,
      index: GitIndex.empty,
      meta: meta,
      isDefaultBranch: isDefault,
      indexBlobSize: indexBytes.length,
      metaBlobSize: metaBytes.length,
    );
  }

  /// A small blob of ours: kept in the store too, so reading it back needs
  /// no fetch.
  Future<GitTreePut> _bytesPut(Uint8List body) async {
    final id = hashGitObject(GitObjectType.blob, body);
    await store.put(
      GitStoredObject(id: id, type: GitObjectType.blob, body: body),
    );
    return (id: id, source: PackEntrySource.bytes(GitObjectType.blob, body));
  }

  Future<GitObjectId> _pushCommit({
    required GitObjectId tree,
    required List<GitObjectId> parents,
    required String message,
    required GitCommitIdentity who,
    required List<PackEntrySource> objects,
    required GitObjectId? oldTip,
  }) async {
    final commit = GitCommit(
      tree: tree,
      parents: parents,
      authorName: who.name,
      authorEmail: kGitCommitEmail,
      when: _clock().toUtc(),
      message: message,
    ).encode();
    final commitId = hashGitObject(GitObjectType.commit, commit);
    await transport.push(
      branch: branch,
      oldTip: oldTip,
      newTip: commitId,
      pack: writePack([
        ...objects,
        PackEntrySource.bytes(GitObjectType.commit, commit),
      ]),
      packBytes: objects.fold(commit.length, (sum, o) => sum + o.size),
    );
    await store.put(
      GitStoredObject(id: commitId, type: GitObjectType.commit, body: commit),
    );
    return commitId;
  }

  Future<Map<String, _PreparedPut>> _prepare(Map<String, GitPut> puts) async {
    final out = <String, _PreparedPut>{};
    for (final MapEntry(:key, :value) in puts.entries) {
      final data = value._data;
      if (data != null) {
        // Kept like the branch's own files: a host's thin pack may later send
        // a peer's edit of this file as a delta against it.
        final put = await _bytesPut(data);
        out[key] = (id: put.id, size: data.length, source: put.source!);
      } else {
        final file = value._file!;
        final size = await file.length();
        out[key] = (
          id: await hashFileBlob(file),
          size: size,
          source: PackEntrySource.file(GitObjectType.blob, file, size),
        );
      }
    }
    return out;
  }

  static bool _landed(
    GitBranchSnapshot snap,
    Map<String, _PreparedPut> puts,
    Set<String> deletes,
  ) {
    for (final MapEntry(:key, :value) in puts.entries) {
      if (snap.index.entries[key]?.blobId != value.id) return false;
    }
    for (final path in deletes) {
      if (snap.index.entries.containsKey(path)) return false;
    }
    return true;
  }

  /// Commits [change] on the current tip and pushes it. A stale tip is
  /// refetched and the same change rebuilt on it, up to [maxAttempts]. After
  /// any other push failure the tip is re-read, and a change that already
  /// landed (its reply was lost) counts as done.
  Future<GitBranchSnapshot> commit(
    GitChange change, {
    required String messagePrefix,
  }) async {
    final prepared = await _prepare(change.puts);
    for (var attempt = 1; ; attempt++) {
      final snap = _current ?? await open();
      // A path the change also puts is replaced, not deleted.
      final deletes = <String>{
        for (final MapEntry(:key, :value) in change.deletes.entries)
          if (!prepared.containsKey(key) &&
              snap.index.entries.containsKey(key) &&
              (value == null || snap.index.entries[key]!.blobId == value))
            key,
      };
      final changedPuts = {
        for (final MapEntry(:key, :value) in prepared.entries)
          if (snap.index.entries[key]?.blobId != value.id) key: value,
      };
      if (deletes.isEmpty && changedPuts.isEmpty) return snap;

      final nowMs = _clock().toUtc().millisecondsSinceEpoch;
      final entries = Map<String, GitIndexEntry>.of(snap.index.entries);
      var freed = snap.indexBlobSize + snap.metaBlobSize;
      for (final path in deletes) {
        freed += entries.remove(path)?.size ?? 0;
      }
      for (final MapEntry(:key, :value) in changedPuts.entries) {
        freed += entries[key]?.size ?? 0;
        entries[key] = GitIndexEntry(
          blobId: value.id,
          size: value.size,
          modifiedMs: nowMs,
        );
      }
      final index = GitIndex(Map.unmodifiable(entries));
      final meta = snap.meta.copyWith(
        deletedBytesSinceReset: snap.meta.deletedBytesSinceReset + freed,
      );
      final indexBytes = index.encode();
      final metaBytes = meta.encode();
      final treePuts = <String, GitTreePut>{
        for (final MapEntry(:key, :value) in changedPuts.entries)
          key: (id: value.id, source: value.source),
        kGitIndexPath: await _bytesPut(indexBytes),
        kGitMetaPath: await _bytesPut(metaBytes),
      };
      final edit = await _refetchingOnce(
        snap.tip,
        () => editTree(store, snap.rootTree, puts: treePuts, deletes: deletes),
      );
      final who = await identity();
      try {
        final tip = await _pushCommit(
          tree: edit.root,
          parents: [snap.tip],
          message: '$messagePrefix from ${who.messageLabel}',
          who: who,
          objects: edit.newObjects,
          oldTip: snap.tip,
        );
        return await _apply(
          GitBranchSnapshot(
            tip: tip,
            rootTree: edit.root,
            index: index,
            meta: meta,
            isDefaultBranch: snap.isDefaultBranch,
            indexBlobSize: indexBytes.length,
            metaBlobSize: metaBytes.length,
          ),
          _look(),
        );
      } on GitException catch (e) {
        if (e.code == GitErrorCode.tooLarge && e.sizeBytes == null) {
          final biggest = changedPuts.values.fold<int>(
            0,
            (m, p) => p.size > m ? p.size : m,
          );
          throw GitException(
            e.message,
            code: e.code,
            statusCode: e.statusCode,
            host: e.host,
            sizeBytes: biggest == 0 ? null : biggest,
            serverReason: e.serverReason,
            cause: e.cause,
          );
        }
        if (e.code == GitErrorCode.staleTip) {
          if (attempt >= maxAttempts) rethrow;
          await Future<void>.delayed(_retryDelay(attempt));
          await refresh();
          continue;
        }
        final GitBranchSnapshot now;
        try {
          now = await refresh();
        } on Object {
          throw e;
        }
        if (_landed(now, changedPuts, deletes)) return now;
        rethrow;
      }
    }
  }

  /// Replaces the branch history with one parentless commit of the current
  /// files once enough bytes were deleted since the last reset (or always,
  /// with [force]). When a peer moves the tip first, a due reset returns
  /// false and waits for the next sync; a forced one (a privacy purge the
  /// diver asked for) is rebuilt on the new tip, up to [maxAttempts], then
  /// throws [GitErrorCode.staleTip]. Throws [GitErrorCode.protectedBranch]
  /// when the host refuses the rewrite itself.
  Future<bool> resetHistoryIfDue({bool force = false}) async {
    for (var attempt = 1; ; attempt++) {
      var snap = _current ?? await open();
      if (!force && snap.meta.deletedBytesSinceReset < resetThresholdBytes) {
        return false;
      }
      // Nothing deleted or replaced since the last reset (or since the
      // branch was made): the history is the current files already. Checked
      // against the host, since a peer may have committed since.
      if (force && snap.meta.deletedBytesSinceReset == 0) {
        snap = await refresh();
        if (snap.meta.deletedBytesSinceReset == 0) return false;
      }
      final meta = GitBranchMeta(
        formatVersion: snap.meta.formatVersion,
        lastResetAtMs: _clock().toUtc().millisecondsSinceEpoch,
      );
      final metaBytes = meta.encode();
      final metaPut = await _bytesPut(metaBytes);
      final edit = await _refetchingOnce(
        snap.tip,
        () => editTree(
          store,
          snap.rootTree,
          puts: {kGitMetaPath: metaPut},
          deletes: const {},
        ),
      );
      final who = await identity();
      try {
        final tip = await _pushCommit(
          tree: edit.root,
          parents: const [],
          message: 'Reset history from ${who.messageLabel}',
          who: who,
          objects: edit.newObjects,
          oldTip: snap.tip,
        );
        await _apply(
          GitBranchSnapshot(
            tip: tip,
            rootTree: edit.root,
            index: snap.index,
            meta: meta,
            isDefaultBranch: snap.isDefaultBranch,
            indexBlobSize: snap.indexBlobSize,
            metaBlobSize: metaBytes.length,
          ),
          _look(),
        );
        return true;
      } on GitException catch (e) {
        if (e.code != GitErrorCode.staleTip) rethrow;
        final now = await refresh();
        // The tip did not move, so no peer raced us: the host refused the
        // history rewrite itself (receive.denyNonFastForwards, or a branch
        // rule worded as a non-fast-forward).
        if (now.tip == snap.tip) {
          throw GitException(
            'The Git host refused to reset the branch history.',
            code: GitErrorCode.protectedBranch,
            serverReason: e.serverReason,
            cause: e,
          );
        }
        if (!force) return false;
        if (attempt >= maxAttempts) {
          throw GitException(
            'Other devices kept changing the branch, so its history was not '
            'reset.',
            code: GitErrorCode.staleTip,
            cause: e,
          );
        }
        await Future<void>.delayed(_retryDelay(attempt));
      }
    }
  }
}

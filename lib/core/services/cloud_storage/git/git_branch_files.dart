import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';

/// The marker that makes a branch Submersion's, plus shared reset
/// bookkeeping. Submersion never writes to a branch that lacks it.
const String kGitMetaPath = '$kGitOwnFolder/branch.json';

/// The folder holding Submersion's own bookkeeping files, which are never
/// listed as files.
const String kGitOwnFolder = '.submersion';

/// Path to size and modified time for every file, since Git trees record
/// neither.
const String kGitIndexPath = '$kGitOwnFolder/index.json';

const String kGitReadmePath = 'README.md';

/// Deleted or replaced bytes after which a device resets the branch history.
const int kGitHistoryResetThresholdBytes = 256 * 1024 * 1024;

/// Every commit's author email. The `.invalid` domain is reserved, so it can
/// never match a real account on any host.
const String kGitCommitEmail = 'sync@submersion.invalid';

const String kGitReadmeText =
    '# Submersion sync\n'
    '\n'
    'This branch is written by the Submersion dive log app. It holds the '
    "app's sync files and cloud backups.\n"
    '\n'
    'Do not edit it by hand. Submersion resets the history of this branch '
    'now and then to keep the repository small; your other branches are '
    'never touched.\n';

/// One file's entry in the index.
final class GitIndexEntry {
  const GitIndexEntry({
    required this.blobId,
    required this.size,
    required this.modifiedMs,
  });

  final GitObjectId blobId;

  /// Null until the blob is fetched, for a file another tool put on the
  /// branch: Git trees record no sizes.
  final int? size;

  /// The writing device's clock when it uploaded the file, in UTC epoch ms.
  final int modifiedMs;

  GitIndexEntry copyWith({int? size}) => GitIndexEntry(
    blobId: blobId,
    size: size ?? this.size,
    modifiedMs: modifiedMs,
  );
}

/// An index written by a newer Submersion: reading it as this version's
/// would drop what the newer format adds, so the branch is left alone.
final class GitIndexTooNew implements Exception {
  const GitIndexTooNew(this.version);

  final int version;

  @override
  String toString() => 'GitIndexTooNew($version)';
}

/// The file index stored at [kGitIndexPath].
final class GitIndex {
  const GitIndex(this.entries);

  static const GitIndex empty = GitIndex({});

  final Map<String, GitIndexEntry> entries;

  /// UTF-8 JSON with sorted keys, so identical content always produces the
  /// same blob.
  Uint8List encode() {
    final paths = entries.keys.toList()..sort();
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': 1,
          'files': {
            for (final path in paths)
              path: {
                'blob': entries[path]!.blobId.hex,
                // Always an int, which readers that predate unknown sizes
                // require; they ignore sizeKnown.
                'size': entries[path]!.size ?? 0,
                'mtime': entries[path]!.modifiedMs,
                if (entries[path]!.size == null) 'sizeKnown': false,
              },
          },
        }),
      ),
    );
  }

  /// Throws [GitIndexTooNew] for a newer format version and
  /// [FormatException] for an index that is not one at all. A malformed
  /// entry is skipped: the session rebuilds it from the branch's tree.
  static GitIndex decode(Uint8List bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on Object catch (e) {
      throw FormatException('Unreadable Git index: $e');
    }
    if (json is! Map<String, Object?>) {
      throw const FormatException('Git index is not an object');
    }
    final version = json['version'];
    if (version is int && version > 1) throw GitIndexTooNew(version);
    if (version != 1) {
      throw FormatException('Git index version $version is not supported');
    }
    final files = json['files'];
    if (files is! Map<String, Object?>) {
      throw const FormatException('Git index has no files map');
    }
    final entries = <String, GitIndexEntry>{};
    for (final MapEntry(:key, :value) in files.entries) {
      if (value is! Map<String, Object?>) continue;
      final blob = value['blob'];
      final size = value['size'];
      final mtime = value['mtime'];
      if (blob is! String || size is! int || mtime is! int) continue;
      if (size < 0 || mtime < 0) continue;
      final GitObjectId blobId;
      try {
        blobId = GitObjectId.fromHex(blob);
      } on FormatException {
        continue;
      }
      entries[key] = GitIndexEntry(
        blobId: blobId,
        size: value['sizeKnown'] == false ? null : size,
        modifiedMs: mtime,
      );
    }
    return GitIndex(Map.unmodifiable(entries));
  }
}

/// The marker and reset bookkeeping stored at [kGitMetaPath].
final class GitBranchMeta {
  const GitBranchMeta({
    this.formatVersion = 1,
    this.deletedBytesSinceReset = 0,
    this.lastResetAtMs,
  });

  final int formatVersion;
  final int deletedBytesSinceReset;
  final int? lastResetAtMs;

  GitBranchMeta copyWith({int? deletedBytesSinceReset, int? lastResetAtMs}) =>
      GitBranchMeta(
        formatVersion: formatVersion,
        deletedBytesSinceReset:
            deletedBytesSinceReset ?? this.deletedBytesSinceReset,
        lastResetAtMs: lastResetAtMs ?? this.lastResetAtMs,
      );

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'app': 'submersion',
        'formatVersion': formatVersion,
        'deletedBytesSinceReset': deletedBytesSinceReset,
        'lastResetAt': lastResetAtMs,
      }),
    ),
  );

  /// Tolerant: a field that is missing or malformed reads as its default, so
  /// a marker written by a newer version still identifies the branch.
  static GitBranchMeta decode(Uint8List bytes) {
    Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on Object {
      json = null;
    }
    if (json is! Map<String, Object?>) return const GitBranchMeta();
    final version = json['formatVersion'];
    final deleted = json['deletedBytesSinceReset'];
    final reset = json['lastResetAt'];
    return GitBranchMeta(
      formatVersion: version is int ? version : 1,
      deletedBytesSinceReset: deleted is int ? deleted : 0,
      lastResetAtMs: reset is int ? reset : null,
    );
  }
}

import 'dart:io';

import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';

/// How a photo was located (or not) during import.
enum PhotoResolutionKind {
  /// [ImportImageRef.originalPath] exists as-is on this machine.
  directPath,

  /// Found under the user-selected rootDir by peeling path components
  /// off the front of [ImportImageRef.originalPath] and reattaching
  /// the rest beneath rootDir.
  rebased,

  /// Found by scanning rootDir for a file with the same basename.
  filenameMatch,

  /// Not found by any strategy.
  miss,
}

/// Result of trying to locate a photo referenced by an import.
///
/// Only the source path is stored; file bytes are NOT held in memory.
/// Downstream writers stream from [resolvedPath] at write time to keep
/// peak memory bounded regardless of batch size — a 261-photo MacDive
/// import would otherwise hold hundreds of MB of JPEG bytes in state.
class ResolvedPhoto {
  /// The source reference this result corresponds to.
  final ImportImageRef ref;

  /// How the photo was found (or [PhotoResolutionKind.miss]).
  final PhotoResolutionKind kind;

  /// Absolute path on the local filesystem if found; null otherwise.
  /// The file is NOT opened by the resolver; callers stream/copy at
  /// write time.
  final String? resolvedPath;

  /// Optional human-readable message (e.g. "access denied"). The
  /// wizard shows this to the user for diagnosis when a miss is
  /// surprising.
  final String? errorMessage;

  const ResolvedPhoto({
    required this.ref,
    required this.kind,
    this.resolvedPath,
    this.errorMessage,
  });
}

/// Attempts to locate the photos referenced by an import on the local
/// filesystem.
///
/// Strategy order:
///   1. Try [ImportImageRef.originalPath] directly.
///   2. If [rootDir] is non-null, try rebasing by peeling path components
///      off the front and prepending rootDir. Longest matching tail wins.
///   3. If still not found and rootDir is non-null, fall back to a
///      filename-based search — scan rootDir recursively once per
///      [resolveAll] call, index by basename, look up each ref's
///      basename.
///
/// Each ref first gets direct + rebase attempts. Only if at least one
/// ref still misses AND rootDir is set do we pay the recursive-scan
/// cost to build the filename index. This keeps well-organised imports
/// (where direct-path or rebase resolves everything) fast.
///
/// Empty input returns empty output without scanning.
class PhotoResolver {
  /// Optional user-selected root directory for rebased / filename lookups.
  /// When null, only the direct-path strategy applies.
  final String? rootDir;

  const PhotoResolver({required this.rootDir});

  /// Resolves every ref in [refs]. Output order matches input order.
  Future<List<ResolvedPhoto>> resolveAll(List<ImportImageRef> refs) async {
    if (refs.isEmpty) return const [];

    // First pass: direct path and rebased resolution only. Track which
    // refs still need the filename-match fallback.
    final results = <ResolvedPhoto>[];
    final missIndexes = <int>[];
    for (var i = 0; i < refs.length; i++) {
      final resolved = await _resolveDirectOrRebased(refs[i]);
      results.add(resolved);
      if (resolved.kind == PhotoResolutionKind.miss) {
        missIndexes.add(i);
      }
    }

    // Second pass: only build the recursive filename index if at least
    // one ref still needs it AND we have a rootDir to search under.
    if (rootDir == null || missIndexes.isEmpty) {
      return results;
    }
    final filenameIndex = await _indexByFilename(rootDir!);
    for (final index in missIndexes) {
      final retry = _resolveByFilename(refs[index], filenameIndex);
      if (retry != null) results[index] = retry;
    }
    return results;
  }

  Future<ResolvedPhoto> _resolveDirectOrRebased(ImportImageRef ref) async {
    final direct = File(ref.originalPath);
    if (await direct.exists()) {
      return ResolvedPhoto(
        ref: ref,
        kind: PhotoResolutionKind.directPath,
        resolvedPath: ref.originalPath,
      );
    }

    if (rootDir == null) {
      return ResolvedPhoto(ref: ref, kind: PhotoResolutionKind.miss);
    }

    final rebased = _tryRebase(ref.originalPath, rootDir!);
    if (rebased != null) {
      return ResolvedPhoto(
        ref: ref,
        kind: PhotoResolutionKind.rebased,
        resolvedPath: rebased,
      );
    }

    return ResolvedPhoto(ref: ref, kind: PhotoResolutionKind.miss);
  }

  ResolvedPhoto? _resolveByFilename(
    ImportImageRef ref,
    Map<String, List<String>> filenameIndex,
  ) {
    final candidates = filenameIndex[ref.filename] ?? const <String>[];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return ResolvedPhoto(
          ref: ref,
          kind: PhotoResolutionKind.filenameMatch,
          resolvedPath: candidate,
        );
      }
    }
    return null;
  }

  /// Rebase strategy: peel components off the front of [original] and
  /// try prepending [root] to the remainder. Longest matching tail wins.
  /// Always preserves at least one directory component beyond the
  /// basename — a rebase that reduces to bare basename is handled by
  /// the separate filename-match strategy instead, to keep the two
  /// strategies distinct.
  /// Example: original = /Users/other/Photos/Diving/a.jpg, root = `<tmp>`
  /// tries in order (first existing file wins):
  ///   `<tmp>`/Users/other/Photos/Diving/a.jpg
  ///   `<tmp>`/other/Photos/Diving/a.jpg
  ///   `<tmp>`/Photos/Diving/a.jpg
  ///   `<tmp>`/Diving/a.jpg
  /// (Does not try `<tmp>`/a.jpg — that's filename-match territory.)
  String? _tryRebase(String original, String root) {
    final parts = original
        .split(RegExp(r'[\\/]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    // Need at least 2 parts to rebase (1 directory + basename). With
    // only the basename, defer to filename-match.
    if (parts.length < 2) return null;
    final normalisedRoot = root.endsWith('/') || root.endsWith(r'\')
        ? root.substring(0, root.length - 1)
        : root;
    // Stop before reaching just-the-basename (parts.length - 1).
    for (var start = 0; start < parts.length - 1; start++) {
      final candidate = '$normalisedRoot/${parts.sublist(start).join('/')}';
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  /// Recursively indexes every file under [root] by basename. Key is
  /// filename (e.g. `shark.jpg`); value is a list of absolute paths
  /// because multiple files under the root may share a basename.
  Future<Map<String, List<String>>> _indexByFilename(String root) async {
    final index = <String, List<String>>{};
    final dir = Directory(root);
    if (!await dir.exists()) return index;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          final sep = Platform.pathSeparator;
          final idx = entity.path.lastIndexOf(sep);
          final name = idx >= 0 ? entity.path.substring(idx + 1) : entity.path;
          index.putIfAbsent(name, () => <String>[]).add(entity.path);
        }
      }
    } catch (_) {
      // Permission errors mid-walk — return whatever we got. The
      // wizard surfaces the misses; we don't fail the whole batch.
    }
    return index;
  }
}

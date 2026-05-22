import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/data/services/directory_scanner.dart';
import 'package:submersion/features/universal_import/data/value_objects/scanned_file.dart';

/// How a photo was located (or not) during resolution.
enum PhotoResolutionKind {
  /// Found by grafting the recorded path tail onto the picked root.
  rebased,

  /// Found by matching the recorded basename against the scanned index.
  filenameMatch,

  /// The recorded reference is a non-image extension; skipped + counted.
  skippedNonImage,

  /// Not found by any strategy.
  miss,
}

/// Result of resolving one [ImportImageRef] against a scanned folder.
/// Carries the matched [ScannedFile] (handle, NOT bytes) when found.
class ResolvedPhoto {
  final ImportImageRef ref;
  final PhotoResolutionKind kind;
  final ScannedFile? scannedFile;

  const ResolvedPhoto({
    required this.ref,
    required this.kind,
    this.scannedFile,
  });
}

/// Resolves recorded photo paths to actual files under a user-picked
/// folder. Enumerates the folder exactly once via [scanner], builds a
/// basename -> [ScannedFile] index from that single stream, then resolves
/// each ref using a longest-shared-tail heuristic to prefer path-rebased
/// matches over bare filename matches. Outputs handles only — no bytes
/// are read.
class PhotoResolver {
  final DirectoryScanner scanner;
  final GrantedFolder folder;

  const PhotoResolver({required this.scanner, required this.folder});

  static const _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'heic',
    'heif',
    'gif',
    'tif',
    'tiff',
    'webp',
    'bmp',
  };

  Future<List<ResolvedPhoto>> resolveAll(List<ImportImageRef> refs) async {
    if (refs.isEmpty) return const [];

    // Single scan: build a basename -> list of ScannedFile index.
    final byBasename = <String, List<ScannedFile>>{};
    await for (final file in scanner.scan(folder)) {
      byBasename.putIfAbsent(file.basename, () => <ScannedFile>[]).add(file);
    }

    final results = <ResolvedPhoto>[];
    for (final ref in refs) {
      results.add(_resolveOne(ref, byBasename));
    }
    return results;
  }

  ResolvedPhoto _resolveOne(
    ImportImageRef ref,
    Map<String, List<ScannedFile>> byBasename,
  ) {
    if (!_isImage(ref.filename)) {
      return ResolvedPhoto(ref: ref, kind: PhotoResolutionKind.skippedNonImage);
    }

    final candidates = byBasename[ref.filename] ?? const <ScannedFile>[];
    if (candidates.isEmpty) {
      return ResolvedPhoto(ref: ref, kind: PhotoResolutionKind.miss);
    }

    // Rebase preference: among same-basename candidates, prefer the one
    // whose desktop path shares the longest trailing path segment run with
    // the recorded path. A shared tail beyond the basename is a "rebase";
    // a bare-basename-only match is "filenameMatch".
    final recordedSegments = _segments(ref.originalPath);
    ScannedFile? best;
    var bestSharedTail = 0;
    for (final candidate in candidates) {
      final candPath = candidate.handle.localPath ?? candidate.basename;
      final shared = _sharedTailLength(recordedSegments, _segments(candPath));
      if (best == null || shared > bestSharedTail) {
        best = candidate;
        bestSharedTail = shared;
      }
    }

    return ResolvedPhoto(
      ref: ref,
      kind: bestSharedTail >= 2
          ? PhotoResolutionKind.rebased
          : PhotoResolutionKind.filenameMatch,
      scannedFile: best,
    );
  }

  bool _isImage(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0) return false;
    return _imageExtensions.contains(filename.substring(dot + 1).toLowerCase());
  }

  List<String> _segments(String path) => path
      .split(RegExp(r'[\\/]+'))
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  /// Number of trailing segments [a] and [b] share (counting the basename).
  int _sharedTailLength(List<String> a, List<String> b) {
    var i = a.length - 1;
    var j = b.length - 1;
    var shared = 0;
    while (i >= 0 && j >= 0 && a[i] == b[j]) {
      shared++;
      i--;
      j--;
    }
    return shared;
  }
}

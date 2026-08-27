import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;

import 'package:submersion/features/media/data/services/pdf_page_renderer.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// Produces and caches page-1 renders of PDF attachments so the media grid
/// shows the document instead of a generic icon.
///
/// The store-side [ThumbnailGenerator] already renders page 1 for upload, but
/// only a device that cannot resolve the PDF locally ever sees that JPEG: a
/// row whose own source resolves hands back the raw PDF, which no Image
/// widget can decode, and the tile falls through to the icon placeholder
/// (issue #1019). This is the local counterpart, so the tile looks the same
/// on the device that attached the file as on every other one.
///
/// Same failure contract as [VideoThumbnailService]: null on every failure
/// path, leaving the caller with its placeholder.
class PdfThumbnailService {
  PdfThumbnailService({
    required Future<Directory> Function() cacheDir,
    PdfThumbRenderer? renderer,
    Duration renderBudget = const Duration(seconds: 15),
  }) : _cacheDir = cacheDir,
       _renderer = renderer ?? PdfPageRenderer.renderFirstPageJpeg,
       _renderBudget = renderBudget;

  final Future<Directory> Function() _cacheDir;
  final PdfThumbRenderer _renderer;

  /// Ceiling on one page render.
  ///
  /// Not a performance budget -- a 512 px page takes milliseconds. It bounds
  /// the one pdfrx failure that is neither a throw nor a null: when the
  /// engine cannot initialise, the crash happens inside its worker isolate
  /// and the calling future simply never completes. Without this the tile
  /// would shimmer forever instead of falling back to the icon.
  final Duration _renderBudget;
  Directory? _resolvedDir;

  /// Matches [ThumbnailGenerator.maxDimension] so a locally rendered tile and
  /// one served from the store are the same picture.
  ///
  /// Deliberately NOT the caller's tile size, which is what the video poster
  /// path keys on: a pdfium render is far more expensive than a poster
  /// fetch, and sizing per tile would re-render the same document once per
  /// grid geometry. 512 px covers every tile in the app; the decode down to
  /// the tile is Flutter's job.
  static const int maxDimension = 512;

  /// Page-1 JPEG for [item], or null when one cannot be produced.
  ///
  /// [source] is called only on a cache miss. It is a callback rather than a
  /// resolved value because resolving is the expensive half on the platforms
  /// that matter here: an Android SAF read or a bookmark read pulls the
  /// whole PDF across a platform channel, and a warm cache must not pay for
  /// it on every tile that scrolls into view.
  Future<Uint8List?> thumbFor(
    MediaItem item, {
    required Future<MediaSourceData> Function() source,
  }) async {
    if (!item.isPdf) return null;

    final dir = await _resolveCacheDir();
    final cacheFile = dir == null
        ? null
        : File(p.join(dir.path, '${cacheKeyFor(item)}.jpg'));
    if (cacheFile != null && await cacheFile.exists()) {
      try {
        return await cacheFile.readAsBytes();
      }
      // coverage:ignore-start
      // Reading back a file this class just wrote fails only on a permission
      // or I/O error, which flutter_test's tmpdir fixtures cannot produce.
      // Dropping the entry keeps the failure self-healing instead of
      // re-throwing on every render; regeneration runs either way.
      on FileSystemException {
        try {
          await cacheFile.delete();
        } on FileSystemException {
          // Leave it; the regenerate below still runs.
        }
      }
      // coverage:ignore-end
    }

    final Uint8List? jpeg;
    try {
      jpeg = await switch (await source()) {
        FileData(file: final f) => _render(file: f),
        BytesData(bytes: final b) => _render(bytes: b),
        NetworkData() || UnavailableData() => Future.value(null),
      };
    } on Object {
      // A resolver that throws, or a render that ran out of time, is the
      // caller's placeholder -- not an error escaping into a grid tile
      // mid-scroll.
      return null;
    }
    if (jpeg == null) return null;

    if (dir != null && cacheFile != null) {
      try {
        await dir.create(recursive: true);
        await cacheFile.writeAsBytes(jpeg, flush: true);
      } on FileSystemException {
        // Caching is best-effort; the freshly rendered bytes still return.
      }
    }
    return jpeg;
  }

  static const int _jpegQuality = 80;

  Future<Uint8List?> _render({File? file, Uint8List? bytes}) => _renderer(
    file: file,
    bytes: bytes,
    maxDimension: maxDimension,
    quality: _jpegQuality,
  ).timeout(_renderBudget);

  /// Cache key for [item]'s page-1 render.
  ///
  /// Keys on content when the row knows it ([MediaItem.contentHash], stamped
  /// by the upload pipeline) and on row identity plus its update stamp
  /// otherwise. The fallback is weaker than the video path's path+mtime+size
  /// because a document has no path to stat on the platform this matters
  /// most on: Android stores a SAF content URI. Replacing the bytes behind a
  /// URI without touching the row therefore keeps a stale tile until the row
  /// is next written -- a thumbnail being one revision behind, which is the
  /// cheaper wrong answer than a channel read per tile.
  @visibleForTesting
  static String cacheKeyFor(MediaItem item) {
    final signature =
        item.contentHash ??
        '${item.id}|${item.updatedAt.millisecondsSinceEpoch}';
    return sha1.convert(utf8.encode('$signature|$maxDimension')).toString();
  }

  /// Resolves (and memoises) the cache directory, or null when it cannot be
  /// determined. A host without a usable support directory renders without a
  /// cache rather than losing the thumbnail entirely.
  Future<Directory?> _resolveCacheDir() async {
    final cached = _resolvedDir;
    if (cached != null) return cached;
    try {
      return _resolvedDir = await _cacheDir();
    } on Object {
      return null;
    }
  }
}

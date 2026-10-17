import 'dart:collection';
import 'dart:io';

import 'package:flutter/painting.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Remembers which file each media tile last drew, so a tile coming back
/// into view can ask the image cache for its decoded image straight away
/// (issue #3337).
///
/// A tile finds its file asynchronously (a resolver, sometimes a disk
/// lookup), and until that answers it has nothing to hand an [Image], so it
/// showed the placeholder even when the decoded image was sitting in memory.
/// The image cache is keyed by file and decode width, both of which this
/// remembers, which is enough to look the image up on the first frame.
///
/// It is also the only record of which image-cache entries belong to which
/// row, which is what lets unlinking a photo take its decoded images out of
/// memory ([evictItems]).
///
/// Holds paths and numbers, never pixels: the image cache owns those and
/// keeps its own budget.
class MediaTileImageMemo {
  MediaTileImageMemo({this.maxItems = 5000}) : assert(maxItems > 0);

  /// Rows remembered before the one seen longest ago is forgotten.
  final int maxItems;

  /// Insertion-ordered, re-inserted on every use, so the first key is the
  /// row seen longest ago.
  final LinkedHashMap<String, List<_Drawn>> _drawn = LinkedHashMap();

  /// The provider a tile draws [file] with at [cacheWidth]. One definition,
  /// so the key a tile caches under and the key looked up here cannot drift.
  static ImageProvider providerFor(File file, int? cacheWidth) =>
      ResizeImage.resizeIfNeeded(cacheWidth, null, FileImage(file));

  /// Notes that [item]'s tile drew [file] at [cacheWidth].
  void remember(
    MediaItem item, {
    required bool thumbnail,
    required int cacheWidth,
    required File file,
  }) {
    final drawn = _drawn.remove(item.id) ?? <_Drawn>[];
    drawn.removeWhere(
      (d) => d.thumbnail == thumbnail && d.cacheWidth == cacheWidth,
    );
    drawn.add(
      _Drawn(
        pointer: _pointerOf(item),
        thumbnail: thumbnail,
        cacheWidth: cacheWidth,
        path: file.path,
      ),
    );
    _drawn[item.id] = drawn;
    while (_drawn.length > maxItems) {
      _drawn.remove(_drawn.keys.first);
    }
  }

  /// The provider for [item]'s tile if its decoded image is in memory now,
  /// otherwise null.
  ///
  /// Null too when the row points somewhere else than it did when the tile
  /// was drawn: a re-linked row must not flash its old picture.
  ImageProvider? cachedProvider(
    MediaItem item, {
    required bool thumbnail,
    required int cacheWidth,
  }) {
    final drawn = _drawn[item.id];
    if (drawn == null) return null;
    final pointer = _pointerOf(item);
    for (final d in drawn) {
      if (d.thumbnail != thumbnail ||
          d.cacheWidth != cacheWidth ||
          d.pointer != pointer) {
        continue;
      }
      final provider = providerFor(File(d.path), cacheWidth);
      final status = PaintingBinding.instance.imageCache.statusForKey(
        _keyOf(provider),
      );
      // Pending is tracked but has no pixels yet: showing it would swap the
      // placeholder for a blank tile.
      return status.tracked && !status.pending ? provider : null;
    }
    return null;
  }

  /// Takes every decoded image remembered for [ids] out of the image cache,
  /// and forgets the rows.
  Future<void> evictItems(Iterable<String> ids) async {
    for (final id in ids) {
      final drawn = _drawn.remove(id);
      if (drawn == null) continue;
      for (final d in drawn) {
        final file = File(d.path);
        await providerFor(file, d.cacheWidth).evict();
        // The undecorated key too, in case anything drew the file unsized.
        await FileImage(file).evict();
      }
    }
  }

  /// A [FileImage] key, and so a [ResizeImage] key over one, is obtained
  /// synchronously; the callback has run by the time `then` returns.
  static Object _keyOf(ImageProvider provider) {
    late final Object key;
    provider.obtainKey(ImageConfiguration.empty).then((k) => key = k);
    return key;
  }

  static String _pointerOf(MediaItem item) =>
      '${item.sourceType.name}\u0000${item.localPath ?? ''}'
      '\u0000${item.filePath ?? ''}\u0000${item.bookmarkRef ?? ''}'
      '\u0000${item.contentHash ?? ''}';
}

class _Drawn {
  const _Drawn({
    required this.pointer,
    required this.thumbnail,
    required this.cacheWidth,
    required this.path,
  });

  /// Where the row pointed when the tile was drawn.
  final String pointer;
  final bool thumbnail;
  final int cacheWidth;
  final String path;
}

/// One memo for the whole app: a tile scrolled out of one gallery is as
/// likely to come back in another.
// no-tick: holds no query result; what it remembers is checked against the
// image cache on every read.
final mediaTileImageMemoProvider = Provider<MediaTileImageMemo>(
  (ref) => MediaTileImageMemo(),
);

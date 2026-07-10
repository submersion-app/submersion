import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:image/image.dart' as img;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

/// Best-effort thumbnail production for the upload pipeline (design spec
/// section 9 step 4). Gallery sources hand back pre-compressed thumbnail
/// bytes; file sources are decoded and resized here. Re-encoding drops
/// EXIF (including GPS) from the thumb. Failure never blocks the
/// original's upload: every error path returns null.
class ThumbnailGenerator {
  ThumbnailGenerator({
    required MediaSourceResolverRegistry registry,
    required MediaCacheStore cache,
  }) : _registry = registry,
       _cache = cache;

  final MediaSourceResolverRegistry _registry;
  final MediaCacheStore _cache;
  final _log = LoggerService.forClass(ThumbnailGenerator);

  static const int maxDimension = 512;
  static const int jpegQuality = 80;

  Future<File?> generateFor(MediaItem item) async {
    try {
      final resolver = _registry.resolverFor(item.sourceType);
      final data = await resolver.resolveThumbnail(
        item,
        target: Size(maxDimension.toDouble(), maxDimension.toDouble()),
      );
      switch (data) {
        case BytesData(bytes: final b):
          final staged = await _cache.stagingFile();
          await staged.writeAsBytes(b, flush: true);
          return staged;
        case FileData(file: final f):
          return _resizeToJpeg(await f.readAsBytes(), item.originalFilename);
        case NetworkData():
        case UnavailableData():
          return null;
      }
    } on Exception catch (e) {
      _log.warning('Thumbnail generation failed for ${item.id}: $e');
      return null;
    }
  }

  Future<File?> _resizeToJpeg(Uint8List bytes, String? name) async {
    // Decode by declared extension when known: the generic decoder probes
    // every format and permissive ones (TGA) accept arbitrary bytes.
    final decoded = name != null && name.contains('.')
        ? img.decodeNamedImage(name, bytes)
        : img.decodeImage(bytes);
    if (decoded == null) return null;
    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final resized = longest > maxDimension
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxDimension : null,
            height: decoded.height > decoded.width ? maxDimension : null,
          )
        : decoded;
    final staged = await _cache.stagingFile();
    await staged.writeAsBytes(
      img.encodeJpg(resized, quality: jpegQuality),
      flush: true,
    );
    return staged;
  }
}

import 'dart:io';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

/// A produced rendition: [file] holds the compressed bytes, [ext] is its
/// output format (jpg | mp4), [sizeBytes] its length.
class CompressionResult {
  const CompressionResult({
    required this.file,
    required this.ext,
    required this.sizeBytes,
  });
  final File file;
  final String ext;
  final int sizeBytes;
}

/// Produces a compressed rendition, or null to mean "upload the original
/// instead" (already under the level's ceiling, or an undecodable input).
abstract class MediaCompressor {
  Future<CompressionResult?> compress(
    MediaItem item,
    File source,
    MediaUploadQuality level,
  );
}

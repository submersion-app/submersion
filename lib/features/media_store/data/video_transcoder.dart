import 'dart:io';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_compressor.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

/// Video transcoding seam. Implementations write the rendition to
/// '<output>.tmp' and rename to [output] on success (an existing [output]
/// is always complete), report progress as a 0..1 fraction when the engine
/// supports it, and throw on genuine engine failure. Returning null means
/// "upload the original instead" (engine unavailable, probe failure, or the
/// source is within the level's ceiling).
abstract class VideoTranscoder {
  Future<CompressionResult?> transcode(
    MediaItem item,
    File source,
    MediaUploadQuality level, {
    required File output,
    void Function(double fraction)? onProgress,
  });
}

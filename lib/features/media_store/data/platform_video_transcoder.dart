import 'dart:io';

import 'package:submersion_transcoder/submersion_transcoder.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_compressor.dart';
import 'package:submersion/features/media_store/data/quality_presets.dart';
import 'package:submersion/features/media_store/data/video_transcoder.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

/// The app-side adapter between the upload pipeline's [VideoTranscoder] seam
/// and the platform's [TranscodeEngine] (spec section 9). Maps quality
/// presets to engine-agnostic targets, applies the ceiling rule, and
/// translates "no engine / probe failure / within ceiling" into null so the
/// pipeline uploads the original.
class PlatformVideoTranscoder implements VideoTranscoder {
  PlatformVideoTranscoder({
    TranscodeEngine? engine,
    bool useDefaultEngine = true,
  }) : _engine = engine ?? (useDefaultEngine ? engineForThisPlatform() : null);

  final TranscodeEngine? _engine;
  final _log = LoggerService.forClass(PlatformVideoTranscoder);

  /// Whether this platform can transcode video right now (used by the
  /// settings hint; on Linux this reflects ffmpeg's presence on PATH).
  Future<bool> isAvailable() async {
    final engine = _engine;
    if (engine == null) return false;
    return engine.isAvailable();
  }

  @override
  Future<CompressionResult?> transcode(
    MediaItem item,
    File source,
    MediaUploadQuality level, {
    required File output,
    void Function(double fraction)? onProgress,
  }) async {
    final preset = videoPresetFor(level);
    if (preset == null) return null; // original: no transcode
    final engine = _engine;
    if (engine == null || !await engine.isAvailable()) return null;
    final probe = await engine.probe(source);
    if (probe == null) {
      _log.warning('Video probe failed for ${item.id}; uploading original');
      return null;
    }
    if (videoWithinCeiling(probe, preset)) return null;
    try {
      await engine.transcode(
        source: source,
        output: output,
        target: TranscodeTarget(
          maxHeight: preset.maxHeight,
          videoBitrateKbps: preset.videoBitrateKbps,
          audioBitrateKbps: preset.audioBitrateKbps,
        ),
        probe: probe,
        onProgress: onProgress,
      );
    } on TranscodeException catch (e) {
      // isAvailable() only proves ffmpeg is on PATH -- it may lack the H.264
      // encoder (libx264), so transcode always throws. Falling back to the
      // original (spec: "platforms without their engine upload originals")
      // keeps the media flowing instead of failing the queue entry forever.
      _log.warning('Transcode failed for ${item.id}; uploading original: $e');
      return null;
    }
    return CompressionResult(
      file: output,
      ext: 'mp4',
      sizeBytes: await output.length(),
    );
  }
}

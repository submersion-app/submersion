import 'dart:convert';

/// Source-video metadata used by the ceiling rule and progress reporting.
class VideoProbe {
  const VideoProbe({
    required this.width,
    required this.height,
    required this.durationMs,
    required this.overallBitrateKbps,
  });
  final int width;
  final int height;
  final int durationMs;
  final int overallBitrateKbps;
}

/// Parses `ffprobe -print_format json -show_format -show_streams` output.
/// Returns null when there is no probeable video stream with integer
/// dimensions (malformed JSON, a non-map root, `streams` not a list, or
/// missing/non-int width/height) — the caller uploads the original. A missing
/// or malformed `format` object is tolerated: duration and bitrate degrade to
/// 0 rather than failing. Parsed defensively with type checks so an unexpected
/// shape never throws TypeError/CastError.
VideoProbe? parseFfprobeJson(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;

  final streams = decoded['streams'];
  if (streams is! List) return null;
  Map<String, dynamic>? video;
  for (final stream in streams) {
    if (stream is Map<String, dynamic> && stream['codec_type'] == 'video') {
      video = stream;
      break;
    }
  }
  if (video == null) return null;

  final width = video['width'];
  final height = video['height'];
  if (width is! int || height is! int) return null;

  final format = decoded['format'];
  final formatMap = format is Map<String, dynamic>
      ? format
      : const <String, dynamic>{};
  final durationSec = double.tryParse('${formatMap['duration']}') ?? 0;
  var bitRateBps = int.tryParse('${formatMap['bit_rate']}') ?? 0;
  if (bitRateBps <= 0 && durationSec > 0) {
    // ffprobe reports bit_rate as "N/A" for some containers; derive it from
    // total size / duration so a high-bitrate source isn't read as 0 and
    // wrongly judged already-within-ceiling (which would skip transcoding).
    final sizeBytes = int.tryParse('${formatMap['size']}') ?? 0;
    if (sizeBytes > 0) {
      bitRateBps = (sizeBytes * 8 / durationSec).round();
    }
  }
  return VideoProbe(
    width: width,
    height: height,
    durationMs: (durationSec * 1000).round(),
    overallBitrateKbps: (bitRateBps / 1000).round(),
  );
}

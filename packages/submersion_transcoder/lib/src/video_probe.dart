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
/// Returns null for anything that is not a probeable video (malformed JSON,
/// an unexpected JSON shape, no video stream, missing dimensions) — the
/// caller uploads the original. Parsed defensively with type checks so an
/// unexpected shape falls back rather than throwing TypeError/CastError.
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
  final bitRateBps = int.tryParse('${formatMap['bit_rate']}') ?? 0;
  return VideoProbe(
    width: width,
    height: height,
    durationMs: (durationSec * 1000).round(),
    overallBitrateKbps: (bitRateBps / 1000).round(),
  );
}

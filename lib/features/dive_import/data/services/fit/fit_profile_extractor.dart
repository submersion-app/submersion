import 'package:fit_tool/fit_tool.dart';

/// One profile sample, including the Garmin-recorded decompression values.
class FitSample {
  const FitSample({
    required this.timestampMs,
    required this.depth,
    this.temperature,
    this.heartRate,
    this.ceiling,
    this.ndlSeconds,
    this.ttsSeconds,
    this.cns,
  });

  final int timestampMs; // Unix milliseconds.
  final double depth; // meters
  final double? temperature; // celsius
  final int? heartRate; // bpm
  final double? ceiling; // meters (record.nextStopDepth)
  final int? ndlSeconds; // record.ndlTime
  final int? ttsSeconds; // record.timeToSurface
  final double? cns; // percent (record.cnsLoad)
}

/// Extracts per-sample dive profile data from `record` messages, including the
/// Garmin-recorded deco values (ceiling/TTS/NDL/CNS) which are imported as
/// recorded, never recomputed. Records without depth or timestamp are skipped.
class FitProfileExtractor {
  const FitProfileExtractor._();

  static List<FitSample> extract(List<RecordMessage> records) {
    final samples = <FitSample>[];
    for (final r in records) {
      final depth = r.depth;
      final ts = r.timestamp;
      if (depth == null || ts == null) continue;
      samples.add(
        FitSample(
          timestampMs: ts,
          depth: depth,
          temperature: r.temperature?.toDouble(),
          heartRate: r.heartRate,
          ceiling: r.nextStopDepth,
          ndlSeconds: r.ndlTime,
          ttsSeconds: r.timeToSurface,
          cns: r.cnsLoad?.toDouble(),
        ),
      );
    }
    return samples;
  }
}

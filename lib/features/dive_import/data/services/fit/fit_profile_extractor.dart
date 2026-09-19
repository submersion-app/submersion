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
    this.n2Load,
  });

  final int timestampMs; // Unix milliseconds.
  final double depth; // meters
  final double? temperature; // celsius
  final int? heartRate; // bpm
  final double? ceiling; // meters (record.nextStopDepth)
  final int? ndlSeconds; // record.ndlTime
  final int? ttsSeconds; // record.timeToSurface
  final double? cns; // percent (record.cnsLoad)
  final int? n2Load; // percent, aggregate N2 tissue loading (record.n2Load)
}

/// Extracts per-sample dive profile data from `record` messages, including the
/// Garmin-recorded deco values (ceiling/TTS/NDL/CNS/N2 loading) which are
/// imported as recorded, never recomputed. Records without depth or timestamp
/// are skipped.
class FitProfileExtractor {
  const FitProfileExtractor._();

  /// Upper bound for a plausible `n2_load` percent. fit_tool already reads
  /// the uint16 invalid sentinel (0xFFFF) as null; anything above this is a
  /// corrupt or unknown encoding and is dropped rather than stored.
  static const _maxN2LoadPercent = 1000;

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
          n2Load: _validN2Load(r.n2Load),
        ),
      );
    }
    return samples;
  }

  static int? _validN2Load(int? value) =>
      value == null || value < 0 || value > _maxN2LoadPercent ? null : value;
}

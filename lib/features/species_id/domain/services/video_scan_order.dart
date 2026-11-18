/// Where a video's scan goes next, following where the diver is watching
/// (issue #4709). Pure functions.
library;

import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/scanned_ranges.dart';

/// Where the diver moved the playhead: a seek once it settled, or a pause.
/// [sequence] rises with each report, so a scan can tell a new one from
/// one it has already followed.
class PlayheadReport extends Equatable {
  const PlayheadReport({
    required this.ms,
    required this.seek,
    required this.sequence,
  });

  final int ms;

  /// True for a seek; false for a pause, which moves the scan only onto
  /// video not yet scanned.
  final bool seek;
  final int sequence;

  PlayheadReport copyWith({int? ms, bool? seek, int? sequence}) =>
      PlayheadReport(
        ms: ms ?? this.ms,
        seek: seek ?? this.seek,
        sequence: sequence ?? this.sequence,
      );

  @override
  List<Object?> get props => [ms, seek, sequence];
}

/// One stretch of video for the scan to cover next.
typedef VideoChunk = ({int startMs, int endMs});

/// The next chunk to scan, or null when the whole video is scanned.
///
/// With a [report] it starts at the first gap at or after the playhead.
/// A pause on scanned video counts as no report, except for a scan that has
/// not run a chunk yet ([runEndMs] null), which starts from wherever the
/// diver last was rather than from the start. Otherwise it carries on
/// from where the last chunk ended ([runEndMs]), and once nothing is left
/// after that, fills the first gap from the start. A chunk is [chunkMs]
/// long when it carries on from [runEndMs], and [firstChunkMs] when the
/// scan has just opened or moved, so labels appear soon. It ends early at
/// the next scanned stretch or the end of the video. With [durationMs]
/// null (not read yet) the video is taken to run on.
VideoChunk? nextVideoChunk({
  required ScannedRanges scanned,
  required int? durationMs,
  required int? runEndMs,
  required PlayheadReport? report,
  int chunkMs = 10000,
  int firstChunkMs = 2000,
}) {
  int? gapFrom(int ms) => scanned.firstGapAtOrAfter(ms, durationMs: durationMs);
  final heard =
      report != null &&
          (report.seek || runEndMs == null || !scanned.covers(report.ms))
      ? report
      : null;
  int? start;
  var length = chunkMs;
  if (heard != null) {
    start = gapFrom(heard.ms);
    if (start != null && start != runEndMs) length = firstChunkMs;
  }
  if (start == null && runEndMs != null) {
    start = gapFrom(runEndMs);
    length = chunkMs;
  }
  if (start == null) {
    start = gapFrom(0);
    length = runEndMs == null ? firstChunkMs : chunkMs;
  }
  if (start == null) return null;
  var end = start + length;
  final next = scanned.stretchStartAfter(start);
  if (next != null) end = math.min(end, next);
  if (durationMs != null) end = math.min(end, durationMs);
  return (startMs: start, endMs: end);
}

/// Whether [report], arriving while [running] is scanned, should drop it:
/// it points the scan at video not yet scanned outside the running chunk.
/// A pause on scanned video never does.
bool reportMovesScan(
  PlayheadReport report, {
  required ScannedRanges scanned,
  required int? durationMs,
  required VideoChunk running,
}) {
  if (!report.seek && scanned.covers(report.ms)) return false;
  final gap = scanned.firstGapAtOrAfter(report.ms, durationMs: durationMs);
  if (gap == null) return false;
  return gap < running.startMs || gap >= running.endMs;
}

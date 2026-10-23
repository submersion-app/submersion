import 'package:submersion_transcoder/submersion_transcoder.dart';

import 'package:submersion/features/media/domain/color/color_matrix.dart';

/// The colour correction a shared video carries (issue #3521): [matrixAt]
/// (the matrix the viewer draws [durationSeconds]-long clip with at each
/// moment) sampled every [stepSeconds] and at the end, for an encoder to
/// blend between. Dense rather than one key per sampled frame, because the
/// depth limit makes the colour bend between them.
///
/// Null when it is identity throughout: the original is shared as it is.
/// One key when it never changes, or when the clip has no length to sample.
ColorTimeline? sampleColorTimeline({
  required double? durationSeconds,
  required ColorMatrix Function(double seconds) matrixAt,
  double stepSeconds = 0.5,
}) {
  final duration = durationSeconds ?? 0;
  final times = <int>[0];
  if (duration > stepSeconds) {
    final totalMs = (duration * 1000).round();
    final stepMs = (stepSeconds * 1000).round();
    for (var ms = stepMs; ms < totalMs; ms += stepMs) {
      times.add(ms);
    }
    times.add(totalMs);
  }
  final matrices = [for (final ms in times) matrixAt(ms / 1000)];
  if (matrices.every((m) => m.isIdentity)) return null;
  if (matrices.every((m) => m == matrices.first)) {
    return ColorTimeline([
      ColorTimelineKey(timeMs: 0, matrix: matrices.first.values),
    ]);
  }
  return ColorTimeline([
    for (var i = 0; i < times.length; i++)
      ColorTimelineKey(timeMs: times[i], matrix: matrices[i].values),
  ]);
}

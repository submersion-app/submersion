import 'dart:math' as math;

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Samples at or deeper than this fraction of max depth are still the
/// working part of the dive. Matches the cut the dive-to-plan converter
/// applies, so logged TTS is read at the same moment the plan's TTS starts.
const double _workingLevelFraction = 0.5;

/// TTS of a logged dive, in seconds, at the end of the working portion —
/// the same instant [PlanOutcome.ttsAtBottom] measures for a replan.
///
/// Prefers the computer's own sample ([DiveProfilePoint.tts]) at that cut,
/// then the highest computer TTS on the working portion, then a calculated
/// [ttsCurve] at the cut, then the clock time they actually took to surface.
/// Null when the profile cannot support any of those.
int? loggedTtsSeconds({
  required List<DiveProfilePoint> profile,
  List<int>? ttsCurve,
}) {
  if (profile.isEmpty) return null;

  final sorted = [...profile]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final maxDepth = sorted.fold(0.0, (m, p) => math.max(m, p.depth));
  if (maxDepth <= 0) return null;

  final threshold = maxDepth * _workingLevelFraction;
  var workingEnd = 0;
  for (var i = sorted.length - 1; i >= 0; i--) {
    if (sorted[i].depth >= threshold) {
      workingEnd = i;
      break;
    }
  }

  final atCut = sorted[workingEnd].tts;
  if (atCut != null && atCut > 0) return atCut;

  var maxComputer = 0;
  for (var i = 0; i <= workingEnd; i++) {
    final tts = sorted[i].tts;
    if (tts != null && tts > maxComputer) maxComputer = tts;
  }
  if (maxComputer > 0) return maxComputer;

  if (ttsCurve != null &&
      workingEnd < ttsCurve.length &&
      ttsCurve[workingEnd] > 0) {
    return ttsCurve[workingEnd];
  }

  final remaining = sorted.last.timestamp - sorted[workingEnd].timestamp;
  return remaining > 0 ? remaining : null;
}

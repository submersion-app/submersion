part of 'gas_analysis_service.dart';

/// How [GasAnalysisService.calculatePhaseSegments] splits a dive into phases,
/// kept beside the service so the main file stays under the size limit.
extension _PhaseClassification on GasAnalysisService {
  /// Classify a profile point into a dive phase
  DivePhase _classifyPhase(
    List<DiveProfilePoint> profile,
    int index,
    double maxDepth,
  ) {
    final point = profile[index];
    final depth = point.depth;

    // Safety stop detection: 3-6m depth
    if (depth >= GasAnalysisService.safetyStopMinDepth &&
        depth <= GasAnalysisService.safetyStopMaxDepth) {
      // Check if we're stable at this depth (could be safety stop)
      // Look at surrounding points
      int stableCount = 0;
      for (
        int i = math.max(0, index - 10);
        i < math.min(profile.length, index + 10);
        i++
      ) {
        if (profile[i].depth >= GasAnalysisService.safetyStopMinDepth &&
            profile[i].depth <= GasAnalysisService.safetyStopMaxDepth) {
          stableCount++;
        }
      }
      // If we have many points in safety stop range, it's likely a safety stop
      if (stableCount > 15) {
        return DivePhase.safetyStop;
      }
    }

    // Bottom: within 15% of max depth
    final bottomThreshold = maxDepth * 0.85;
    if (depth >= bottomThreshold) {
      return DivePhase.bottom;
    }

    // Calculate rate of depth change
    double depthRate = 0;
    if (index > 0) {
      final prevPoint = profile[index - 1];
      final timeDiff = point.timestamp - prevPoint.timestamp;
      if (timeDiff > 0) {
        depthRate = (depth - prevPoint.depth) / (timeDiff / 60.0); // m/min
      }
    }

    // Descent: significant depth increase
    if (depthRate > 3.0) {
      return DivePhase.descent;
    }

    // Ascent: significant depth decrease
    if (depthRate < -1.0) {
      return DivePhase.ascent;
    }

    // Default based on position in dive
    // If before max depth, likely descent/bottom; after, likely ascent
    final maxDepthIndex = profile.indexWhere((p) => p.depth == maxDepth);
    if (index <= maxDepthIndex) {
      return depth < bottomThreshold ? DivePhase.descent : DivePhase.bottom;
    } else {
      return DivePhase.ascent;
    }
  }

  /// Merge small segments into adjacent ones
  List<({int start, int end, DivePhase phase})> _mergeSmallSegments(
    List<({int start, int end, DivePhase phase})> segments,
  ) {
    if (segments.length <= 1) return segments;

    final merged = <({int start, int end, DivePhase phase})>[];
    var current = segments.first;

    for (int i = 1; i < segments.length; i++) {
      final next = segments[i];
      final currentDuration = current.end - current.start;

      if (currentDuration < GasAnalysisService.minSegmentDuration) {
        // Merge into next segment
        current = (start: current.start, end: next.end, phase: next.phase);
      } else {
        merged.add(current);
        current = next;
      }
    }

    // Add the last segment
    merged.add(current);

    return merged;
  }
}

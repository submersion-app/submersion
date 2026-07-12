import 'dart:ui';

/// One labelled, colored depth-time series to compare on the shared scale.
/// Adapter-neutral: produced identically for a dive's primary source or a
/// single computer-source of one dive.
class ComparisonProfile {
  final String id;
  final String label;
  final Color color;
  final List<double> times; // seconds from descent, ascending
  final List<double> depths; // meters, same length as times
  final double maxDepthMeters;

  const ComparisonProfile({
    required this.id,
    required this.label,
    required this.color,
    required this.times,
    required this.depths,
    required this.maxDepthMeters,
  });
}

/// How the profiles are arranged in the scene.
enum CompareLayout { sideBySide, overlay }

/// Max profiles rendered at once, for legibility. Beyond this the caller keeps
/// the first [kMaxComparisonProfiles] and shows a "showing N of M" note.
const int kMaxComparisonProfiles = 8;

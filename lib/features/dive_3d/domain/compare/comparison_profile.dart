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

/// A selection of dives ready to compare: the [profiles] to show, and how many
/// of the selected dives could have been shown.
///
/// The two differ once a selection passes [kMaxComparisonProfiles], because
/// only the shown dives are loaded: [comparableCount] is what a "showing N of
/// M" note reads, since [profiles] alone cannot say what was left behind.
class DiveComparison {
  final List<ComparisonProfile> profiles;
  final int comparableCount;

  const DiveComparison({required this.profiles, required this.comparableCount});
}

/// How the profiles are arranged in the scene.
enum CompareLayout { sideBySide, overlay }

/// Max profiles rendered at once, for legibility. Beyond this the first
/// [kMaxComparisonProfiles] are kept and a "showing N of M" note appears.
const int kMaxComparisonProfiles = 8;
